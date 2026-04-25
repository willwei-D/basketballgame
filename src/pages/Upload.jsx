import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { collection, addDoc, serverTimestamp, doc, writeBatch } from 'firebase/firestore'
import { db } from '../firebase/config'
import { useAuth } from '../contexts/AuthContext'
import NavBar from '../components/NavBar'
import { extractWordsFromPDF } from '../utils/pdfParser'
import { enrichWithGemini } from '../utils/gemini'

const WORDS_PER_DAY_MIN = 20
const WORDS_PER_DAY_MAX = 100

export default function Upload() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const inputRef = useRef()

  const [file, setFile] = useState(null)
  const [days, setDays] = useState(7)
  const [estimatedWords, setEstimatedWords] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [status, setStatus] = useState('idle')
  const [statusMsg, setStatusMsg] = useState('')
  const [progress, setProgress] = useState(0)

  // Calculate words per day with min/max limits
  const calcWpd = (total, d) => {
    const raw = Math.ceil(total / d)
    return Math.min(WORDS_PER_DAY_MAX, Math.max(WORDS_PER_DAY_MIN, raw))
  }

  const wpd = estimatedWords ? calcWpd(estimatedWords, days) : null
  const actualDays = estimatedWords && wpd ? Math.ceil(estimatedWords / wpd) : null

  const handleFile = async (f) => {
    if (!f || f.type !== 'application/pdf') { alert('請選擇 PDF 檔案'); return }
    setFile(f)
    setEstimatedWords(null)

    // Quick word count scan
    setScanning(true)
    try {
      const words = await extractWordsFromPDF(f)
      setEstimatedWords(words.length)
    } catch (e) {
      console.error(e)
    }
    setScanning(false)
  }

  const handleDrop = (e) => {
    e.preventDefault()
    handleFile(e.dataTransfer.files[0])
  }

  const handleUpload = async () => {
    if (!file) return
    setStatus('processing')
    setProgress(10)

    try {
      setStatusMsg('📄 解析 PDF 文字與座標...')
      const rawWords = await extractWordsFromPDF(file)
      setProgress(40)

      if (rawWords.length === 0) {
        setStatus('error')
        setStatusMsg('無法偵測到單字，請確認 PDF 包含英文單字')
        return
      }

      setStatusMsg(`🤖 AI 生成 ${rawWords.length} 個單字的解釋...`)
      const enriched = await enrichWithGemini(rawWords, (done, total) => {
        setProgress(40 + Math.round((done / total) * 50))
        setStatusMsg(`🤖 AI 處理中 ${done}/${total}...`)
      })
      setProgress(92)

      setStatusMsg('💾 儲存至雲端...')
      const total = enriched.length
      const finalWpd = calcWpd(total, days)
      const finalDays = Math.ceil(total / finalWpd)

      const projectRef = await addDoc(collection(db, 'projects'), {
        userId: user.uid,
        pdfName: file.name,
        createdAt: serverTimestamp(),
        totalWords: total,
        daysToComplete: finalDays,
        wordsPerDay: finalWpd,
        hardWordCount: 0,
        lastHardWordDate: null,
      })

      const CHUNK = 400
      for (let i = 0; i < enriched.length; i += CHUNK) {
        const batch = writeBatch(db)
        enriched.slice(i, i + CHUNK).forEach((w, j) => {
          const wordRef = doc(collection(db, 'projects', projectRef.id, 'words'))
          batch.set(wordRef, {
            word: w.word,
            translation: w.translation || '',
            pos: w.pos || '',
            definition: w.definition || '',
            example: w.example || '',
            position: w.position,
            isHard: false,
            hardSwipes: 0,
            order: i + j,
          })
        })
        await batch.commit()
      }

      setProgress(100)
      setStatus('done')
      setStatusMsg(`✅ 完成！共 ${total} 個單字，每天 ${finalWpd} 個，共 ${finalDays} 天`)
      setTimeout(() => navigate('/'), 2200)
    } catch (e) {
      console.error(e)
      setStatus('error')
      setStatusMsg('發生錯誤：' + e.message)
    }
  }

  const busy = status === 'processing'

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      <div style={s.header}>
        <button style={s.back} onClick={() => navigate('/')}>← 返回</button>
        <h1 style={s.title}>上傳 PDF</h1>
        <div style={{ width: 40 }} />
      </div>

      <div className="scrollable" style={{ padding: '24px 16px 100px' }}>
        {/* Drop zone */}
        <div
          style={{ ...s.dropzone, ...(file ? s.dropzoneActive : {}) }}
          onDrop={handleDrop}
          onDragOver={e => e.preventDefault()}
          onClick={() => !busy && inputRef.current.click()}
        >
          <input ref={inputRef} type="file" accept=".pdf" hidden onChange={e => handleFile(e.target.files[0])} />
          {file ? (
            <>
              <p style={{ fontSize: '36px' }}>📄</p>
              <p style={s.fileName}>{file.name}</p>
              <p style={s.fileSize}>{(file.size / 1024 / 1024).toFixed(2)} MB</p>
              {scanning && <p style={s.scanning}>🔍 掃描單字數量中...</p>}
              {estimatedWords && !scanning && (
                <p style={s.wordCount}>偵測到約 <strong>{estimatedWords}</strong> 個單字</p>
              )}
            </>
          ) : (
            <>
              <p style={{ fontSize: '48px' }}>☁️</p>
              <p style={s.dropText}>點擊或拖曳上傳 PDF</p>
              <p style={s.dropSub}>直接在瀏覽器解析，不上傳雲端</p>
            </>
          )}
        </div>

        {/* Days setting */}
        <div style={s.section}>
          <label style={s.label}>想在幾天內背完？</label>
          <div style={s.daysGrid}>
            {[5, 7, 10, 14, 21, 30].map(d => {
              const preview = estimatedWords ? calcWpd(estimatedWords, d) : null
              const previewDays = estimatedWords && preview ? Math.ceil(estimatedWords / preview) : d
              return (
                <button
                  key={d}
                  style={{ ...s.dayChip, ...(days === d ? s.dayChipActive : {}) }}
                  onClick={() => setDays(d)}
                  disabled={busy}
                >
                  <span style={s.dayNum}>{d} 天</span>
                  {preview && (
                    <span style={s.dayPreview}>{preview} 字/天</span>
                  )}
                </button>
              )
            })}
          </div>

          {wpd && (
            <div style={s.planBox}>
              <div style={s.planRow}>
                <span>每天背</span>
                <strong style={{ color: 'var(--primary-light)' }}>{wpd} 個單字</strong>
              </div>
              <div style={s.planRow}>
                <span>實際天數</span>
                <strong style={{ color: 'var(--primary-light)' }}>{actualDays} 天</strong>
              </div>
              {wpd === WORDS_PER_DAY_MAX && (
                <p style={s.capNote}>⚠️ 已設上限每天最多 {WORDS_PER_DAY_MAX} 個</p>
              )}
            </div>
          )}
        </div>

        {/* Progress */}
        {(busy || status === 'done' || status === 'error') && (
          <div style={s.progressWrap}>
            <div style={s.progressTrack}>
              <div style={{
                ...s.progressFill,
                width: `${progress}%`,
                background: status === 'error' ? 'var(--danger)' : 'var(--primary)'
              }} />
            </div>
            <p style={{
              ...s.progressLabel,
              color: status === 'error' ? 'var(--danger)' : status === 'done' ? 'var(--success)' : 'var(--text-secondary)'
            }}>
              {statusMsg}
            </p>
          </div>
        )}

        <button
          style={{ ...s.uploadBtn, opacity: (!file || busy || scanning) ? 0.5 : 1 }}
          onClick={handleUpload}
          disabled={!file || busy || scanning}
        >
          {busy ? '處理中...' : scanning ? '掃描中...' : '🚀 開始分析並儲存'}
        </button>
      </div>

      <NavBar active="upload" />
    </div>
  )
}

const s = {
  header: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 16px 12px', borderBottom: '1px solid var(--border)' },
  back: { background: 'none', color: 'var(--primary-light)', fontSize: '15px' },
  title: { fontSize: '18px', fontWeight: 700 },
  dropzone: { border: '2px dashed var(--border)', borderRadius: '20px', padding: '36px 24px', textAlign: 'center', cursor: 'pointer', transition: 'all 0.2s' },
  dropzoneActive: { border: '2px dashed var(--primary)', background: 'rgba(79,70,229,0.08)' },
  fileName: { fontSize: '15px', fontWeight: 600, marginTop: '8px', wordBreak: 'break-all' },
  fileSize: { fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' },
  scanning: { fontSize: '13px', color: 'var(--warning)', marginTop: '8px' },
  wordCount: { fontSize: '14px', color: 'var(--success)', marginTop: '8px' },
  dropText: { fontSize: '16px', fontWeight: 600, marginTop: '12px' },
  dropSub: { fontSize: '13px', color: 'var(--text-secondary)', marginTop: '6px' },
  section: { marginTop: '24px' },
  label: { fontSize: '15px', fontWeight: 600, display: 'block', marginBottom: '12px' },
  daysGrid: { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' },
  dayChip: {
    padding: '12px 8px', borderRadius: '12px', fontSize: '13px',
    background: 'var(--bg-card)', color: 'var(--text-secondary)',
    border: '1px solid var(--border)', display: 'flex', flexDirection: 'column',
    alignItems: 'center', gap: '4px',
  },
  dayChipActive: { background: 'var(--primary)', color: '#fff', border: '1px solid var(--primary)' },
  dayNum: { fontSize: '15px', fontWeight: 700 },
  dayPreview: { fontSize: '11px', opacity: 0.85 },
  planBox: {
    marginTop: '16px', background: 'rgba(79,70,229,0.1)', borderRadius: '14px',
    padding: '14px 16px', border: '1px solid rgba(79,70,229,0.3)',
  },
  planRow: { display: 'flex', justifyContent: 'space-between', fontSize: '14px', padding: '3px 0' },
  capNote: { fontSize: '12px', color: 'var(--warning)', marginTop: '8px' },
  progressWrap: { marginTop: '24px' },
  progressTrack: { height: '8px', background: 'var(--bg-surface)', borderRadius: '4px', overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: '4px', transition: 'width 0.4s ease' },
  progressLabel: { fontSize: '13px', marginTop: '10px', textAlign: 'center', lineHeight: 1.5 },
  uploadBtn: { width: '100%', marginTop: '24px', padding: '16px', borderRadius: '16px', fontSize: '16px', fontWeight: 700, background: 'var(--primary)', color: '#fff', boxShadow: '0 4px 16px rgba(79,70,229,0.4)' },
}
