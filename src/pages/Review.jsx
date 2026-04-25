import { useEffect, useState, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { collection, query, where, getDocs, doc, updateDoc, increment } from 'firebase/firestore'
import { db } from '../firebase/config'
import FlashCard from '../components/FlashCard'

export default function Review() {
  const { projectId } = useParams()
  const navigate = useNavigate()
  const [queue, setQueue] = useState([])
  const [known, setKnown] = useState(0)
  const [loading, setLoading] = useState(true)
  const [done, setDone] = useState(false)

  useEffect(() => {
    loadHardWords()
  }, [projectId])

  const loadHardWords = async () => {
    try {
      const snap = await getDocs(
        query(
          collection(db, 'projects', projectId, 'words'),
          where('isHard', '==', true)
        )
      )
      const words = snap.docs.map(d => ({ id: d.id, ...d.data() }))
      setQueue(words)
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  const handleSwipeLeft = useCallback(() => {
    if (queue.length === 0) return
    setQueue(prev => [...prev.slice(1), prev[0]])
  }, [queue])

  const handleSwipeRight = useCallback(async () => {
    if (queue.length === 0) return
    const current = queue[0]

    try {
      // Clear the hard word flag
      await updateDoc(doc(db, 'projects', projectId, 'words', current.id), {
        isHard: false,
        hardSwipes: 0,
      })
      await updateDoc(doc(db, 'projects', projectId), {
        hardWordCount: increment(-1),
      })
    } catch (e) {
      console.error(e)
    }

    setKnown(prev => prev + 1)
    setQueue(prev => {
      const next = prev.slice(1)
      if (next.length === 0) setDone(true)
      return next
    })
  }, [queue, projectId])

  if (loading) {
    return (
      <div style={center}>
        <p style={{ color: 'var(--text-secondary)' }}>載入難詞...</p>
      </div>
    )
  }

  if (done || queue.length === 0) {
    return (
      <div style={{ ...center, flexDirection: 'column', gap: '16px', padding: '32px', textAlign: 'center' }}>
        <p style={{ fontSize: '64px' }}>💪</p>
        <h1 style={{ fontSize: '26px', fontWeight: 800 }}>難詞複習完成！</h1>
        <p style={{ color: 'var(--text-secondary)' }}>已掌握 {known} 個原本的難詞</p>
        <button
          style={{ padding: '14px 32px', borderRadius: '14px', fontWeight: 600, fontSize: '15px', background: 'var(--primary)', color: '#fff', marginTop: '24px' }}
          onClick={() => navigate('/')}
        >
          回首頁
        </button>
      </div>
    )
  }

  const current = queue[0]
  const total = queue.length + known

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      <div style={s.header}>
        <button style={s.back} onClick={() => navigate('/')}>✕</button>
        <div style={s.headerMid}>
          <p style={s.label}>🔁 難詞複習</p>
          <div style={s.track}>
            <div style={{ ...s.fill, width: `${(known / total) * 100}%` }} />
          </div>
        </div>
        <p style={s.counter}>{known}/{total}</p>
      </div>

      <div style={s.banner}>
        <p style={{ fontSize: '13px', color: 'var(--warning)' }}>
          ⚠️ 這些單字你之前左滑超過 3 次
        </p>
      </div>

      <FlashCard
        key={current.id}
        word={current}
        onSwipeLeft={handleSwipeLeft}
        onSwipeRight={handleSwipeRight}
        remaining={queue.length}
      />

      <div style={s.buttons}>
        <button style={s.btnLeft} onClick={handleSwipeLeft}>✗ 還不熟</button>
        <button style={s.btnRight} onClick={handleSwipeRight}>會了 ✓</button>
      </div>
    </div>
  )
}

const center = { height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }

const s = {
  header: {
    display: 'flex', alignItems: 'center', gap: '12px',
    padding: '16px', borderBottom: '1px solid var(--border)',
  },
  back: { background: 'none', color: 'var(--text-secondary)', fontSize: '18px', width: '32px' },
  headerMid: { flex: 1 },
  label: { fontSize: '13px', color: 'var(--warning)', marginBottom: '6px', fontWeight: 600 },
  track: { height: '6px', background: 'var(--bg-surface)', borderRadius: '3px', overflow: 'hidden' },
  fill: { height: '100%', background: 'var(--warning)', borderRadius: '3px', transition: 'width 0.4s ease' },
  counter: { fontSize: '13px', color: 'var(--text-secondary)', whiteSpace: 'nowrap' },
  banner: { padding: '10px 16px', background: 'rgba(245,158,11,0.1)', borderBottom: '1px solid rgba(245,158,11,0.2)' },
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
