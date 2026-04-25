const functions = require('firebase-functions')
const admin = require('firebase-admin')
const vision = require('@google-cloud/vision')
const { GoogleGenerativeAI } = require('@google/generative-ai')

admin.initializeApp()
const db = admin.firestore()
const storage = admin.storage()

const visionClient = new vision.ImageAnnotatorClient()
const genAI = new GoogleGenerativeAI(functions.config().gemini.key)

// ─────────────────────────────────────────────
// Triggered when a project doc is created with status = 'processing'
// ─────────────────────────────────────────────
exports.processPDF = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .firestore.document('projects/{projectId}')
  .onCreate(async (snap, context) => {
    const project = snap.data()
    if (project.status !== 'processing') return

    const { projectId } = context.params
    const projectRef = db.collection('projects').doc(projectId)

    try {
      // ── Step 1: Download PDF from Storage ──
      const bucket = storage.bucket()
      const file = bucket.file(project.storagePath)
      const [pdfBuffer] = await file.download()

      // ── Step 2: OCR with Google Cloud Vision ──
      const [result] = await visionClient.documentTextDetection({
        image: { content: pdfBuffer.toString('base64') },
        imageContext: {
          languageHints: ['en', 'zh-TW'],
        },
      })

      // ── Step 3: Extract words with coordinates ──
      const rawPairs = extractWordPairs(result)

      if (rawPairs.length === 0) {
        await projectRef.update({ status: 'error', errorMsg: '無法偵測到單字，請確認 PDF 格式' })
        return
      }

      // ── Step 4: Deduplicate ──
      const unique = deduplicateWords(rawPairs)

      // ── Step 5: Generate AI data (Gemini) ──
      const enriched = await enrichWithGemini(unique)

      // ── Step 6: Save to Firestore ──
      const batch = db.batch()
      const wordsRef = projectRef.collection('words')

      enriched.forEach((w, i) => {
        const wordDoc = wordsRef.doc()
        batch.set(wordDoc, {
          word: w.word,
          translation: w.translation || '',
          pos: w.pos || '',
          definition: w.definition || '',
          example: w.example || '',
          position: w.position,
          isHard: false,
          hardSwipes: 0,
          order: i,
        })
      })

      await batch.commit()

      const wordsPerDay = Math.max(20, Math.ceil(enriched.length / project.daysToComplete))
      const actualDays = Math.ceil(enriched.length / wordsPerDay)

      await projectRef.update({
        status: 'ready',
        totalWords: enriched.length,
        wordsPerDay,
        daysToComplete: actualDays,
      })

    } catch (err) {
      console.error('processPDF error:', err)
      await projectRef.update({ status: 'error', errorMsg: err.message })
    }
  })

// ─────────────────────────────────────────────
// Extract English-Chinese word pairs from Vision API result
// Sorted by: page → y coordinate → x coordinate
// ─────────────────────────────────────────────
function extractWordPairs(visionResult) {
  const pairs = []
  const pages = visionResult.fullTextAnnotation?.pages || []

  pages.forEach((page, pageIndex) => {
    const blocks = []

    page.blocks?.forEach(block => {
      let blockText = ''
      block.paragraphs?.forEach(para => {
        para.words?.forEach(w => {
          const text = w.symbols?.map(s => s.text).join('') || ''
          blockText += text + ' '
        })
      })

      const verts = block.boundingBox?.vertices || []
      const x = verts[0]?.x || 0
      const y = verts[0]?.y || 0

      blocks.push({ text: blockText.trim(), x, y, page: pageIndex })
    })

    // Sort blocks top-to-bottom, left-to-right within same y-band
    blocks.sort((a, b) => {
      const yDiff = a.y - b.y
      if (Math.abs(yDiff) > 15) return yDiff
      return a.x - b.x
    })

    // Try to detect English word + Chinese translation pairs
    for (let i = 0; i < blocks.length; i++) {
      const b = blocks[i]
      const isEnglish = /^[a-zA-Z\s\-']+$/.test(b.text)
      const hasChinese = /[\u4e00-\u9fff]/.test(b.text)

      if (isEnglish && b.text.trim().length > 1) {
        // Look for nearby Chinese block
        const nextBlock = blocks[i + 1]
        const translation = nextBlock && /[\u4e00-\u9fff]/.test(nextBlock.text)
          ? nextBlock.text.trim()
          : ''

        pairs.push({
          word: b.text.trim().toLowerCase(),
          translation,
          position: { page: pageIndex, x: b.x, y: b.y },
        })

        if (translation) i++ // Skip next block (consumed as translation)
      } else if (hasChinese) {
        // Might be "English 中文" in same block
        const match = b.text.match(/^([a-zA-Z\s\-']+)\s+([\u4e00-\u9fff].*)$/)
        if (match) {
          pairs.push({
            word: match[1].trim().toLowerCase(),
            translation: match[2].trim(),
            position: { page: pageIndex, x: b.x, y: b.y },
          })
        }
      }
    }
  })

  return pairs
}

function deduplicateWords(pairs) {
  const seen = new Set()
  return pairs.filter(p => {
    if (seen.has(p.word)) return false
    seen.add(p.word)
    return true
  })
}

// ─────────────────────────────────────────────
// Enrich words with Gemini API (pos, definition, example)
// Processes in batches of 10 to avoid rate limits
// ─────────────────────────────────────────────
async function enrichWithGemini(words) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' })
  const BATCH = 10
  const enriched = []

  for (let i = 0; i < words.length; i += BATCH) {
    const batch = words.slice(i, i + BATCH)
    const prompt = buildGeminiPrompt(batch)

    try {
      const result = await model.generateContent(prompt)
      const text = result.response.text()
      const parsed = parseGeminiResponse(text, batch)
      enriched.push(...parsed)
    } catch (e) {
      console.error(`Gemini batch ${i} error:`, e)
      // Fallback: add words without AI data
      enriched.push(...batch.map(w => ({ ...w, pos: '', definition: '', example: '' })))
    }

    // Respect rate limits
    if (i + BATCH < words.length) {
      await new Promise(r => setTimeout(r, 1000))
    }
  }

  return enriched
}

function buildGeminiPrompt(words) {
  const wordList = words.map((w, i) =>
    `${i + 1}. "${w.word}"${w.translation ? ` (中文: ${w.translation})` : ''}`
  ).join('\n')

  return `For each English word below, provide: part of speech (pos), simple one-sentence English definition (definition), and a natural example sentence (example).

Words:
${wordList}

Respond ONLY with a JSON array, no markdown, no extra text:
[{"word":"...","pos":"...","definition":"...","example":"..."}]`
}

function parseGeminiResponse(text, originalWords) {
  try {
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    const parsed = JSON.parse(clean)
    return originalWords.map((orig, i) => ({
      ...orig,
      pos: parsed[i]?.pos || '',
      definition: parsed[i]?.definition || '',
      example: parsed[i]?.example || '',
    }))
  } catch {
    return originalWords.map(w => ({ ...w, pos: '', definition: '', example: '' }))
  }
}
