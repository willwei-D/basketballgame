import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { collection, addDoc, serverTimestamp, doc, writeBatch } from 'firebase/firestore'
import { db } from '../firebase/config'
import { useAuth } from '../contexts/AuthContext'
import NavBar from '../components/NavBar'
import { extractWordsFromPDF } from '../utils/pdfParser'
import { enrichWithGemini } from '../utils/gemini'

const WORDS_PER_DAY_MIN = 30

export default function Upload() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const inputRef = useRef()

  const [file, setFile] = useState(null)
  const [daysInput, setDaysInput] = useState('')
  const [status, setStatus] = useState('idle')   // idle | scanning | preview | processing | done | error
  const [statusMsg, setStatusMsg] = useState('')
  const [progress, setProgress] = useState(0)
  const [wordCount, setWordCount] = useState(null)
  const [previewWords, setPreviewWords] = useState([])

  const days = parseInt(daysInput) || 0
  const calcWpd = (total, d) => d > 0 ? Math.max(WORDS_PER_DAY_MIN, Math.ceil(total / d)) : null
  const wpd = wordCount && days > 0 ? calcWpd(wordCount, days) : null
  const actualDays = wordCount && wpd ? Math.ceil(wordCount / wpd) : null
  const adjustedMsg = wpd && actualDays && actualDays !== days
    ? `每天最少 ${WORDS_PER_DAY_MIN} 個，實際需 ${actualDays} 天`
    : null

  const handleFile = async (f) => {
    if (!f || f.type !== 'application/pdf') { alert('請選擇 PDF 檔案'); return }
    setFile(f)
    setStatus('scanning')
    setStatusMsg('🔍 掃描 PDF 單字中...')
    setWordCount(null)
    setPreviewWords([])

    try {
      const words = await extractWordsFromPDF(f)
      setWordCount(words.length)
      setPreviewWords(words.slice(0, 5))
      setStatus('preview')
    } catch (e) {
      setStatus('error')
      setStatusMsg('掃描失敗：' + e.message)
    }
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
      setStatusMsg('📄 解析所有單字...')
      const rawWords = await extractWordsFromPDF(file)
      setProgress(30)

      if (rawWords.length === 0) {
        setStatus('error')
        setStatusMsg('無法偵測到單字，請確認 PDF 包含英文單字')
        return
      }

      setStatusMsg(`🤖 AI 生成 ${rawWords.length} 個單字的繁體中文翻譯與詞性...`)
      const enriched = await enrichWithGemini(rawWords, (done, total) => {
        setProgress(30 + Math.round((done / total) * 60))
        setStatusMsg(`🤖 AI 處理中 ${done}/${total}...`)
      })
      setProgress(92)

      setStatusMsg('💾 儲存至雲端...')
      const total = enriched.length
      const finalWpd = calcWpd(total, days > 0 ? days : 7)
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
            position: w.position,
            isHard: false,
            hardSwipes: 0,
            order: i + j,
          })
        })
        await batch.commit()
        const savedSoFar = Math.min(i + CHUNK, enriched.length)
        setProgress(92 + Math.round((savedSoFar / enriched.length) * 8))
        setStatusMsg(`💾 儲存中 ${savedSoFar} / ${enriched.length}...`)
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
  const canUpload = file && days > 0 && !busy && status !== 'scanning'

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      <div style={s.header}>
        <button style={s.back} onClick={() => navigate('/')}>← 返回</button>
        <h1 style={s.title}>上傳 PDF</h1>
        <div style={{ width: 40 }} />
      </div>

      <div className="scrollable" style={{ padding: '20px 16px 100px' }}>

        {/* Drop zone */}
        <div
          style={{ ...s.dropzone, ...(file ? s.dropzoneActive : {}) }}
          onDrop={handleDrop}
          onDragOver={e => e.preventDefault()}
          onClick={() => !busy && status !== 'scanning' && inputRef.current.click()}
        >
          <input ref={inputRef} type="file" accept=".pdf" hidden onChange={e => handleFile(e.target.files[0])} />
          {!file ? (
            <>
              <p style={{ fontSize: '48px' }}>☁️</p>
              <p style={s.dropText}>點擊或拖曳上傳 PDF</p>
              <p style={s.dropSub}>自動掃描所有英文單字，不限格式</p>
            </>
          ) : (
            <>
              <p style={{ fontSize: '32px' }}>📄</p>
              <p style={s.fileName}>{file.name}</p>
              <p style={s.fileSize}>{(file.size / 1024 / 1024).toFixed(2)} MB</p>
            </>
          )}
        </div>

        {/* 掃描中 */}
        {status === 'scanning' && (
          <div style={s.scanBox}>
            <p style={{ fontSize: '14px', color: 'var(--warning)' }}>⏳ {statusMsg}</p>
          </div>
        )}

        {/* 預覽結果 */}
        {status === 'preview' && previewWords.length > 0 && (
          <div style={s.previewBox}>
            <div style={s.previewHeader}>
              <span style={s.previewCount}>
                偵測到 <strong style={{ color: 'var(--primary-light)' }}>{wordCount}</strong> 個單字
              </span>
              <span style={s.previewSub}>預覽前 5 筆</span>
            </div>
            {previewWords.map((w, i) => (
              <div key={i} style={s.previewItem}>
                <span style={s.previewWord}>{w.word}</span>
                <span style={s.previewTrans}>{w.translation || '—'}</span>
              </div>
            ))}
          </div>
        )}

        {/* 天數輸入 */}
        {(status === 'preview' || busy || status === 'done') && (
          <div style={s.section}>
            <label style={s.label}>想在幾天內背完？</label>
            <div style={s.inputRow}>
              <input
                style={s.daysInput}
                type="number"
                min="1"
                placeholder="輸入天數"
                value={daysInput}
                onChange={e => setDaysInput(e.target.value)}
                disabled={busy}
              />
              <span style={s.daysUnit}>天</span>
            </div>

            {daysInput && days > 0 && wordCount && (
              <div style={s.planBox}>
                <div style={s.planRow}>
                  <span>每天需背</span>
                  <strong style={{ color: 'var(--primary-light)', fontSize: '22px' }}>{wpd} 個單字</strong>
                </div>
                {adjustedMsg
                  ? <p style={s.capNote}>⚠️ {adjustedMsg}</p>
                  : <div style={s.planRow}>
                      <span>實際天數</span>
                      <strong style={{ color: 'var(--success)' }}>{actualDays} 天</strong>
                    </div>
                }
              </div>
            )}
          </div>
        )}

        {/* 進度條 */}
        {(busy || status === 'done' || status === 'error') && (
          <div style={s.progressWrap}>
            <div style={s.progressTrack}>
              <div style={{
                ...s.progressFill, width: `${progress}%`,
                background: status === 'error' ? 'var(--danger)' : 'var(--primary)'
              }} />
            </div>
            <p style={{
              ...s.progressLabel,
              color: status === 'error' ? 'var(--danger)' : status === 'done' ? 'var(--success)' : 'var(--text-secondary)'
            }}>{statusMsg}</p>
          </div>
        )}

        {/* 上傳按鈕 */}
        {status !== 'idle' && status !== 'scanning' && (
          <button
            style={{ ...s.uploadBtn, opacity: canUpload ? 1 : 0.5 }}
            onClick={handleUpload}
            disabled={!canUpload}
          >
            {busy ? '處理中...' : '🚀 開始生成字卡'}
          </button>
        )}

      </div>
      <NavBar active="upload" />
    </div>
  )
}

const s = {
  header: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 16px 12px', borderBottom: '1px solid var(--border)' },
  back: { background: 'none', color: 'var(--primary-light)', fontSize: '15px' },
  title: { fontSize: '18px', fontWeight: 700 },
  dropzone: { border: '2px dashed var(--border)', borderRadius: '20px', padding: '32px 24px', textAlign: 'center', cursor: 'pointer', transition: 'all 0.2s' },
  dropzoneActive: { border: '2px dashed var(--primary)', background: 'rgba(79,70,229,0.08)' },
  fileName: { fontSize: '15px', fontWeight: 600, marginTop: '8px', wordBreak: 'break-all' },
  fileSize: { fontSize: '13px', color: 'var(--text-secondary)', marginTop: '4px' },
  dropText: { fontSize: '16px', fontWeight: 600, marginTop: '12px' },
  dropSub: { fontSize: '13px', color: 'var(--text-secondary)', marginTop: '6px' },
  scanBox: { marginTop: '16px', padding: '16px', background: 'rgba(245,158,11,0.1)', borderRadius: '12px', border: '1px solid rgba(245,158,11,0.2)', textAlign: 'center' },
  previewBox: { marginTop: '16px', background: 'var(--bg-card)', borderRadius: '20px', padding: '16px', border: '1px solid var(--border)' },
  previewHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' },
  previewCount: { fontSize: '14px' },
  previewSub: { fontSize: '12px', color: 'var(--text-secondary)' },
  previewItem: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '9px 12px', background: 'var(--bg-surface)', borderRadius: '10px', marginBottom: '6px' },
  previewWord: { fontSize: '15px', fontWeight: 600 },
  previewTrans: { fontSize: '14px', color: 'var(--primary-light)' },
  section: { marginTop: '20px' },
  label: { fontSize: '15px', fontWeight: 600, display: 'block', marginBottom: '10px' },
  inputRow: { display: 'flex', alignItems: 'center', gap: '10px' },
  daysInput: { flex: 1, padding: '14px 16px', borderRadius: '12px', fontSize: '22px', fontWeight: 700, background: 'var(--bg-card)', color: 'var(--text-primary)', border: '2px solid var(--primary)', textAlign: 'center' },
  daysUnit: { fontSize: '18px', fontWeight: 600, color: 'var(--text-secondary)' },
  planBox: { marginTop: '14px', background: 'rgba(79,70,229,0.12)', borderRadius: '14px', padding: '16px', border: '1px solid rgba(79,70,229,0.3)' },
  planRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '14px', padding: '3px 0' },
  capNote: { fontSize: '12px', color: 'var(--warning)', marginTop: '8px' },
  progressWrap: { marginTop: '20px' },
  progressTrack: { height: '8px', background: 'var(--bg-surface)', borderRadius: '4px', overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: '4px', transition: 'width 0.4s ease' },
  progressLabel: { fontSize: '13px', marginTop: '10px', textAlign: 'center', lineHeight: 1.6 },
  uploadBtn: { width: '100%', marginTop: '20px', padding: '16px', borderRadius: '16px', fontSize: '16px', fontWeight: 700, background: 'var(--primary)', color: '#fff', boxShadow: '0 4px 16px rgba(79,70,229,0.4)' },
}
