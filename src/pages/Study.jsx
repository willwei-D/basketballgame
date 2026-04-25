import { useEffect, useState, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  collection, query, orderBy, getDocs, limit, startAfter,
  doc, updateDoc, increment, serverTimestamp, getDoc
} from 'firebase/firestore'
import { db } from '../firebase/config'
import FlashCard from '../components/FlashCard'

const HARD_THRESHOLD = 3
const WORDS_PER_CHUNK = 50

export default function Study() {
  const { projectId, day } = useParams()
  const navigate = useNavigate()
  const dayNum = Number(day)

  const [queue, setQueue] = useState([])
  const [swipeCounts, setSwipeCounts] = useState({}) // { wordId: leftSwipeCount }
  const [known, setKnown] = useState(0)
  const [loading, setLoading] = useState(true)
  const [done, setDone] = useState(false)
  const [project, setProject] = useState(null)

  useEffect(() => {
    loadWords()
  }, [projectId, dayNum])

  const loadWords = async () => {
    try {
      const projDoc = await getDoc(doc(db, 'projects', projectId))
      if (!projDoc.exists()) return
      const proj = { id: projDoc.id, ...projDoc.data() }
      setProject(proj)

      const wpd = proj.wordsPerDay
      const startIndex = (dayNum - 1) * wpd
      const endIndex = startIndex + wpd

      // Load all words sorted by position
      const wordsSnap = await getDocs(
        query(collection(db, 'projects', projectId, 'words'), orderBy('order'))
      )
      const allWords = wordsSnap.docs.map(d => ({ id: d.id, ...d.data() }))
      const dayWords = allWords.slice(startIndex, endIndex)

      setQueue(dayWords)
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  const handleSwipeLeft = useCallback(async () => {
    if (queue.length === 0) return
    const current = queue[0]
    const newCount = (swipeCounts[current.id] || 0) + 1

    setSwipeCounts(prev => ({ ...prev, [current.id]: newCount }))

    if (newCount >= HARD_THRESHOLD) {
      // Mark as hard word in Firestore
      try {
        await updateDoc(doc(db, 'projects', projectId, 'words', current.id), {
          isHard: true,
          hardSwipes: newCount,
        })
        await updateDoc(doc(db, 'projects', projectId), {
          hardWordCount: increment(1),
          lastHardWordDate: serverTimestamp(),
        })
      } catch (e) {
        console.error(e)
      }
    }

    // Move current card to end of queue
    setQueue(prev => [...prev.slice(1), prev[0]])
  }, [queue, swipeCounts, projectId])

  const handleSwipeRight = useCallback(() => {
    if (queue.length === 0) return
    setKnown(prev => prev + 1)
    setQueue(prev => {
      const next = prev.slice(1)
      if (next.length === 0) setDone(true)
      return next
    })
  }, [queue])

  if (loading) return <LoadingScreen />

  if (done || queue.length === 0) return <DoneScreen known={known} total={known + Object.keys(swipeCounts).filter(k => (swipeCounts[k] || 0) < HARD_THRESHOLD).length} navigate={navigate} />

  const current = queue[0]
  const totalToday = project?.wordsPerDay || 0
  const progress = Math.round((known / totalToday) * 100)

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div style={s.header}>
        <button style={s.back} onClick={() => navigate('/')}>✕</button>
        <div style={s.headerMid}>
          <p style={s.dayLabel}>第 {day} 天</p>
          <div style={s.progressTrack}>
            <div style={{ ...s.progressFill, width: `${progress}%` }} />
          </div>
        </div>
        <p style={s.score}>{known}/{totalToday}</p>
      </div>

      {/* Stats bar */}
      <div style={s.statsBar}>
        <div style={s.stat}>
          <span style={{ color: 'var(--success)' }}>✓</span>
          <span>{known} 會了</span>
        </div>
        <div style={s.stat}>
          <span style={{ color: 'var(--danger)' }}>✗</span>
          <span>{queue.length - 1} 待複習</span>
        </div>
        <div style={s.stat}>
          <span>🔥</span>
          <span>{Object.values(swipeCounts).filter(c => c >= HARD_THRESHOLD).length} 難詞</span>
        </div>
      </div>

      {/* Flash card */}
      <FlashCard
        key={current.id + '-' + (swipeCounts[current.id] || 0)}
        word={current}
        onSwipeLeft={handleSwipeLeft}
        onSwipeRight={handleSwipeRight}
        remaining={queue.length}
      />

      {/* Bottom buttons */}
      <div style={s.buttons}>
        <button style={s.btnLeft} onClick={handleSwipeLeft}>✗ 不會</button>
        <button style={s.btnRight} onClick={handleSwipeRight}>會了 ✓</button>
      </div>
    </div>
  )
}

function LoadingScreen() {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
      <p style={{ color: 'var(--text-secondary)' }}>載入中...</p>
    </div>
  )
}

function DoneScreen({ known, total, navigate }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)', padding: '32px', textAlign: 'center' }}>
      <p style={{ fontSize: '72px' }}>🎉</p>
      <h1 style={{ fontSize: '28px', fontWeight: 800, marginTop: '16px' }}>今天完成了！</h1>
      <p style={{ color: 'var(--text-secondary)', marginTop: '8px', fontSize: '16px' }}>你今天認識了 {known} 個單字</p>
      <div style={{ marginTop: '40px', display: 'flex', gap: '12px', width: '100%', maxWidth: '320px' }}>
        <button
          style={{ flex: 1, padding: '14px', borderRadius: '14px', fontWeight: 600, fontSize: '15px', background: 'var(--primary)', color: '#fff' }}
          onClick={() => navigate('/')}
        >
          回首頁
        </button>
      </div>
    </div>
  )
}

const s = {
  header: {
    display: 'flex', alignItems: 'center', gap: '12px',
    padding: '16px', borderBottom: '1px solid var(--border)',
  },
  back: { background: 'none', color: 'var(--text-secondary)', fontSize: '18px', width: '32px' },
  headerMid: { flex: 1 },
  dayLabel: { fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '6px' },
  progressTrack: { height: '6px', background: 'var(--bg-surface)', borderRadius: '3px', overflow: 'hidden' },
  progressFill: { height: '100%', background: 'var(--primary)', borderRadius: '3px', transition: 'width 0.4s ease' },
  score: { fontSize: '13px', color: 'var(--text-secondary)', whiteSpace: 'nowrap' },
  statsBar: {
    display: 'flex', justifyContent: 'space-around', padding: '10px 16px',
    borderBottom: '1px solid var(--border)',
  },
  stat: { display: 'flex', gap: '6px', fontSize: '13px', alignItems: 'center' },
  buttons: { display: 'flex', gap: '12px', padding: '16px', borderTop: '1px solid var(--border)' },
  btnLeft: {
    flex: 1, padding: '16px', borderRadius: '16px', fontSize: '16px', fontWeight: 700,
    background: 'rgba(239,68,68,0.15)', color: 'var(--danger)', border: '2px solid rgba(239,68,68,0.3)',
  },
  btnRight: {
    flex: 1, padding: '16px', borderRadius: '16px', fontSize: '16px', fontWeight: 700,
    background: 'rgba(16,185,129,0.15)', color: 'var(--success)', border: '2px solid rgba(16,185,129,0.3)',
  },
}
