import * as pdfjsLib from 'pdfjs-dist'

pdfjsLib.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@3.11.174/build/pdf.worker.min.js`

export async function extractWordsFromPDF(file) {
  const arrayBuffer = await file.arrayBuffer()
  const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise

  const allItems = []

  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum)
    const content = await page.getTextContent()

    content.items.forEach(item => {
      if (!item.str?.trim()) return
      const x = item.transform[4]
      const y = item.transform[5]
      allItems.push({ text: item.str.trim(), x, y, page: pageNum })
    })
  }

  allItems.sort((a, b) => {
    if (a.page !== b.page) return a.page - b.page
    const yDiff = b.y - a.y
    if (Math.abs(yDiff) > 5) return yDiff
    return a.x - b.x
  })

  return parseWordPairs(allItems)
}

function parseWordPairs(items) {
  const pairs = []
  const seen = new Set()

  for (let i = 0; i < items.length; i++) {
    const item = items[i]
    const text = item.text

    const mixedMatch = text.match(/^([a-zA-Z][a-zA-Z\s\-']*)\s+([\u4e00-\u9fff][\u4e00-\u9fff\s、，。！？]*)$/)
    if (mixedMatch) {
      const word = mixedMatch[1].trim().toLowerCase()
      if (!seen.has(word) && word.length >= 2) {
        seen.add(word)
        pairs.push({
          word,
          translation: mixedMatch[2].trim(),
          position: { page: item.page, x: item.x, y: item.y },
        })
      }
      continue
    }

    const isEnglish = /^[a-zA-Z][a-zA-Z\-']{1,}$/.test(text)
    if (isEnglish && text.length >= 2) {
      const word = text.toLowerCase()
      if (seen.has(word)) continue

      let translation = ''
      for (let j = i + 1; j < Math.min(i + 5, items.length); j++) {
        const next = items[j]
        if (/[\u4e00-\u9fff]/.test(next.text) && next.page === item.page) {
          translation = next.text.trim()
          i = j
          break
        }
        if (/^[a-zA-Z]{2,}$/.test(next.text)) break
      }

      seen.add(word)
      pairs.push({
        word,
        translation,
        position: { page: item.page, x: item.x, y: item.y },
      })
    }
  }

  return pairs
}
