const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`

const BATCH_SIZE = 15

export async function enrichWithGemini(words, onProgress) {
  const enriched = []

  for (let i = 0; i < words.length; i += BATCH_SIZE) {
    const batch = words.slice(i, i + BATCH_SIZE)
    const results = await processBatch(batch)
    enriched.push(...results)
    onProgress?.(Math.min(i + BATCH_SIZE, words.length), words.length)

    // Small delay between batches to respect rate limits
    if (i + BATCH_SIZE < words.length) {
      await new Promise(r => setTimeout(r, 800))
    }
  }

  return enriched
}

async function processBatch(words) {
  if (!GEMINI_API_KEY || GEMINI_API_KEY === '你的_Gemini_API_Key_貼這裡') {
    // No API key: return words without AI enrichment
    return words.map(w => ({ ...w, pos: '', definition: '', example: '' }))
  }

  const wordList = words.map((w, i) =>
    `${i + 1}. "${w.word}"${w.translation ? ` (中文: ${w.translation})` : ''}`
  ).join('\n')

  const prompt = `For each English word below, provide part of speech (pos), simple one-sentence English definition (definition), and a natural example sentence (example).

Words:
${wordList}

Respond ONLY with a valid JSON array, no markdown fence, no extra text:
[{"word":"...","pos":"noun","definition":"...","example":"..."}]`

  try {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 2048 },
      }),
    })

    const data = await res.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '[]'
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    const parsed = JSON.parse(clean)

    return words.map((orig, i) => ({
      ...orig,
      pos: parsed[i]?.pos || '',
      definition: parsed[i]?.definition || '',
      example: parsed[i]?.example || '',
    }))
  } catch (e) {
    console.error('Gemini error:', e)
    return words.map(w => ({ ...w, pos: '', definition: '', example: '' }))
  }
}
