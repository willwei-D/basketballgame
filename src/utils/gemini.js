const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`

const BATCH_SIZE = 25   // 每批 25 個，減少批次數量
const MAX_RETRY = 1
const CONCURRENT = 3    // 同時跑 3 個 API 請求

export async function enrichWithGemini(words, onProgress) {
  const enriched = new Array(words.length)
  const batches = []

  for (let i = 0; i < words.length; i += BATCH_SIZE) {
    batches.push({ start: i, words: words.slice(i, i + BATCH_SIZE) })
  }

  let done = 0

  // 每次同時跑 CONCURRENT 批
  for (let i = 0; i < batches.length; i += CONCURRENT) {
    const chunk = batches.slice(i, i + CONCURRENT)
    const results = await Promise.all(
      chunk.map(b => processBatchWithRetry(b.words))
    )
    chunk.forEach((b, idx) => {
      results[idx].forEach((w, j) => { enriched[b.start + j] = w })
    })
    done += chunk.reduce((s, b) => s + b.words.length, 0)
    onProgress?.(Math.min(done, words.length), words.length)

    if (i + CONCURRENT < batches.length) {
      await new Promise(r => setTimeout(r, 300))
    }
  }

  return enriched
}

async function processBatchWithRetry(words, attempt = 0) {
  const results = await processBatch(words)

  // 若有 pos 空白的，最多重試一次
  const missingPos = results.filter(w => !w.pos)
  if (missingPos.length > 0 && attempt < MAX_RETRY) {
    await new Promise(r => setTimeout(r, 500))
    const retried = await processBatch(missingPos)
    return results.map(r => {
      if (r.pos) return r
      const fix = retried.find(x => x.word === r.word)
      return fix?.pos ? { ...r, pos: fix.pos, translation: fix.translation || r.translation } : r
    })
  }

  return results
}

async function processBatch(words) {
  if (!GEMINI_API_KEY) {
    return words.map(w => ({ ...w, pos: '', translation: w.translation || '' }))
  }

  const wordList = words.map((w, i) =>
    `${i + 1}. ${w.word}${w.translation ? `（參考：${w.translation}）` : ''}`
  ).join('\n')

  const prompt = `你是英文詞典。以下每個英文單字請提供 pos（繁體中文詞性）和 translation（繁體中文翻譯）。

pos 只能是：名詞、動詞、形容詞、副詞、介系詞、連接詞、代名詞、感嘆詞、片語
translation 要精準，2～8字，最常用的意思

重要：每個單字都必須有 pos 和 translation，不可空白。
只回傳純 JSON 陣列，不要 markdown 或說明文字。

${wordList}

範例格式：[{"word":"run","pos":"動詞","translation":"跑；運行"},{"word":"fast","pos":"形容詞","translation":"快速的"}]`

  try {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.1, maxOutputTokens: 2048 },
      }),
    })

    const data = await res.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '[]'
    const clean = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    const parsed = JSON.parse(clean)

    return words.map((orig, i) => ({
      ...orig,
      pos: parsed[i]?.pos || '',
      translation: parsed[i]?.translation || orig.translation || '',
    }))
  } catch (e) {
    console.error('Gemini batch error:', e)
    return words.map(w => ({ ...w, pos: '', translation: w.translation || '' }))
  }
}
