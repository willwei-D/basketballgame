import * as pdfjsLib from 'pdfjs-dist'

pdfjsLib.GlobalWorkerOptions.workerSrc =
  `https://unpkg.com/pdfjs-dist@3.11.174/build/pdf.worker.min.js`

// ─────────────────────────────────────────────────────────
// 取得所有頁面的文字區塊（含座標）
// ─────────────────────────────────────────────────────────
async function getRawItems(file) {
  const arrayBuffer = await file.arrayBuffer()
  const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise
  const allItems = []

  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum)
    const content = await page.getTextContent()
    content.items.forEach(item => {
      const text = item.str?.trim()
      if (!text) return
      allItems.push({
        text,
        x: Math.round(item.transform[4]),
        y: Math.round(item.transform[5]),
        page: pageNum,
        fontSize: Math.round(Math.abs(item.transform[3])),
      })
    })
  }

  // 依照 page → y 由大到小（上到下）→ x 由小到大（左到右）
  allItems.sort((a, b) => {
    if (a.page !== b.page) return a.page - b.page
    if (Math.abs(b.y - a.y) > 3) return b.y - a.y
    return a.x - b.x
  })

  return allItems
}

// ─────────────────────────────────────────────────────────
// 主要函式：不管格式，逐一掃描所有文字抓英中配對
// ─────────────────────────────────────────────────────────
export async function extractWordsFromPDF(file) {
  const items = await getRawItems(file)
  const pairs = []
  const seen = new Set()

  for (let i = 0; i < items.length; i++) {
    const item = items[i]

    // ── 只處理英文單字 ──
    const wordMatch = item.text.match(/^([a-zA-Z][a-zA-Z\-']{1,})$/)
    if (!wordMatch) {
      // 也嘗試從同一格子裡抓「英文 中文」組合
      const inlineMatch = item.text.match(
        /^(\d+[.\s]*)?([a-zA-Z][a-zA-Z\-']{1,})\s+([一-鿿][一-鿿、，；。\s（）()…]*)/
      )
      if (inlineMatch) {
        const word = inlineMatch[2].toLowerCase()
        if (!seen.has(word)) {
          seen.add(word)
          pairs.push({
            word,
            translation: inlineMatch[3].trim(),
            position: { page: item.page, x: item.x, y: item.y },
          })
        }
      }
      continue
    }

    const word = wordMatch[1].toLowerCase()
    if (seen.has(word) || word.length < 2) continue

    // ── 尋找配對的中文翻譯 ──
    const translation = findTranslation(items, i)

    seen.add(word)
    pairs.push({
      word,
      translation,
      position: { page: item.page, x: item.x, y: item.y },
    })
  }

  return pairs
}

// ─────────────────────────────────────────────────────────
// 從周圍的 items 找中文翻譯
// 策略：同行 > 右側同行 > 下一行
// ─────────────────────────────────────────────────────────
function findTranslation(items, engIdx) {
  const eng = items[engIdx]
  const LINE_THRESHOLD = 6   // y 差值在此範圍內視為同行
  const NEXT_LINE_THR  = 30  // y 差值在此範圍內視為下一行

  const isChinese = (text) => /[一-鿿]/.test(text)

  // 1️⃣ 同行（向後找最近的中文）
  for (let j = engIdx + 1; j < Math.min(engIdx + 8, items.length); j++) {
    const candidate = items[j]
    if (candidate.page !== eng.page) break
    if (Math.abs(candidate.y - eng.y) > LINE_THRESHOLD) break
    if (isChinese(candidate.text)) {
      return cleanTranslation(candidate.text)
    }
  }

  // 2️⃣ 右側同行（x 比英文大，y 差距稍寬）
  const sameLine = items.filter(it =>
    it.page === eng.page &&
    Math.abs(it.y - eng.y) <= LINE_THRESHOLD &&
    it.x > eng.x &&
    isChinese(it.text)
  )
  if (sameLine.length > 0) {
    sameLine.sort((a, b) => a.x - b.x)
    return cleanTranslation(sameLine[0].text)
  }

  // 3️⃣ 下一行（y 稍小，x 差不多）
  const nextLine = items.filter(it =>
    it.page === eng.page &&
    (eng.y - it.y) > LINE_THRESHOLD &&
    (eng.y - it.y) <= NEXT_LINE_THR &&
    Math.abs(it.x - eng.x) < 80 &&
    isChinese(it.text)
  )
  if (nextLine.length > 0) {
    nextLine.sort((a, b) => (eng.y - a.y) - (eng.y - b.y))
    return cleanTranslation(nextLine[0].text)
  }

  return ''
}

function cleanTranslation(text) {
  return text
    .replace(/^\d+[.\s]+/, '')   // 移除前面的編號
    .replace(/[a-zA-Z]/g, '')    // 移除英文字母
    .trim()
}

// 快速預覽用（只掃前 3 頁）
export async function previewWords(file) {
  const items = await getRawItems(file)
  const preview3pages = items.filter(i => i.page <= 3)
  const full = await extractWordsFromFile(preview3pages, items)
  const allWords = await extractWordsFromPDF(file)
  return { preview: allWords.slice(0, 5), wordCount: allWords.length }
}

async function extractWordsFromFile(sampleItems, allItems) {
  return []
}
