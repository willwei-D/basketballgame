import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { doc, getDoc } from 'firebase/firestore'
import { db } from '../firebase/config'

export default function ProjectDetail() {
  const { projectId } = useParams()
  const navigate = useNavigate()
  const [project, setProject] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      try {
        const snap = await getDoc(doc(db, 'projects', projectId))
        if (snap.exists()) setProject({ id: snap.id, ...snap.data() })
      } catch (e) { console.error(e) }
      setLoading(false)
    }
    load()
  }, [projectId])

  if (loading) return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
      <p style={{ color: 'var(--text-secondary)' }}>載入中...</p>
    </div>
  )

  if (!project) return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
      <p style={{ color: 'var(--text-secondary)' }}>找不到專案</p>
    </div>
  )

  const today = new Date().toISOString().split('T')[0]
  const todayDayIndex = (() => {
    if (!project.createdAt) return 1
    const created = project.createdAt.toDate()
    const diff = Math.floor((new Date(today) - new Date(created.toISOString().split('T')[0])) / 86400000)
    return Math.min(diff + 1, project.daysToComplete)
  })()

  const days = Array.from({ length: project.daysToComplete }, (_, i) => i + 1)

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div style={s.header}>
        <button style={s.back} onClick={() => navigate('/')}>← 返回</button>
        <div style={s.headerCenter}>
          <p style={s.title} title={project.pdfName}>{project.pdfName}</p>
          <p style={s.sub}>共 {project.daysToComplete} 天・{project.totalWords} 個單字</p>
        </div>
        <div style={{ width: 60 }} />
      </div>

      <div className="scrollable" style={{ padding: '16px 16px 40px' }}>
        <p style={s.hint}>選擇任意一天開始學習</p>

        {days.map(day => {
          const startWord = (day - 1) * project.wordsPerDay + 1
          const endWord = Math.min(day * project.wordsPerDay, project.totalWords)
          const isToday = day === todayDayIndex
          const isCompleted = (project.completedDays || []).includes(day)

          return (
            <button
              key={day}
              style={{
                ...s.dayCard,
                ...(isCompleted ? s.dayCardDone : s.dayCardTodo),
                ...(isToday && !isCompleted ? s.dayCardToday : {}),
              }}
              onClick={() => navigate(`/study/${projectId}/${day}`)}
            >
              <div style={s.dayLeft}>
                <div style={{
                  ...s.dayBadge,
                  ...(isCompleted ? s.dayBadgeDone : isToday ? s.dayBadgeToday : {}),
                }}>
                  <span style={{ ...s.dayNum, ...(isCompleted ? { color: 'var(--success)' } : {}) }}>{day}</span>
                  <span style={s.dayLabel}>天</span>
                </div>
              </div>
              <div style={s.dayMid}>
                <p style={{ ...s.dayTitle, ...(isCompleted ? { color: '#1a1a2e' } : {}) }}>
                  第 {day} 天
                  {isToday && !isCompleted && <span style={s.todayTag}>今日</span>}
                  {isCompleted && <span style={s.doneTag}>✓ 完成</span>}
                </p>
                <p style={{ ...s.dayRange, ...(isCompleted ? { color: '#555' } : {}) }}>
                  第 {startWord}～{endWord} 個單字（共 {endWord - startWord + 1} 個）
                </p>
              </div>
              <span style={{ ...s.arrow, ...(isCompleted ? { color: '#aaa' } : {}) }}>›</span>
            </button>
          )
        })}
      </div>
    </div>
  )
}

const s = {
  header: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '20px 16px 12px', borderBottom: '1px solid var(--border)',
  },
  back: { background: 'none', color: 'var(--primary-light)', fontSize: '15px', whiteSpace: 'nowrap' },
  headerCenter: { flex: 1, textAlign: 'center', padding: '0 12px', minWidth: 0 },
  title: { fontSize: '15px', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
  sub: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' },
  hint: { fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '14px', textAlign: 'center' },

  dayCard: {
    width: '100%', display: 'flex', alignItems: 'center', gap: '14px',
    borderRadius: '16px', padding: '14px 16px',
    marginBottom: '10px', textAlign: 'left',
  },
  dayCardTodo: {
    background: '#ffffff',
    border: '1px solid #e5e7eb',
  },
  dayCardToday: {
    background: '#ffffff',
    border: '2px solid var(--primary)',
  },
  dayCardDone: {
    background: 'var(--bg-card)',
    border: '1px solid var(--border)',
    opacity: 0.7,
  },

  dayLeft: { flexShrink: 0 },
  dayBadge: {
    width: '44px', height: '44px', borderRadius: '12px',
    background: 'var(--bg-surface)', border: '1px solid var(--border)',
    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
  },
  dayBadgeToday: { background: 'var(--primary)', border: 'none' },
  dayBadgeDone: { background: 'rgba(16,185,129,0.15)', border: '1px solid rgba(16,185,129,0.3)' },
  dayNum: { fontSize: '16px', fontWeight: 800, lineHeight: 1 },
  dayLabel: { fontSize: '10px', color: 'var(--text-secondary)', lineHeight: 1 },

  dayMid: { flex: 1, minWidth: 0 },
  dayTitle: { fontSize: '15px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' },
  todayTag: {
    fontSize: '11px', fontWeight: 700, background: 'var(--primary)',
    color: '#fff', padding: '2px 8px', borderRadius: '20px',
  },
  doneTag: {
    fontSize: '11px', fontWeight: 700, background: 'rgba(16,185,129,0.15)',
    color: 'var(--success)', padding: '2px 8px', borderRadius: '20px',
    border: '1px solid rgba(16,185,129,0.3)',
  },
  dayRange: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '3px' },

  arrow: { fontSize: '22px', color: 'var(--text-secondary)', flexShrink: 0 },
}
