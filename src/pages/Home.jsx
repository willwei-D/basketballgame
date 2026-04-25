import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { collection, query, where, getDocs } from 'firebase/firestore'
import { db } from '../firebase/config'
import { useAuth } from '../contexts/AuthContext'
import NavBar from '../components/NavBar'

export default function Home() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadProjects()
  }, [])

  const loadProjects = async () => {
    try {
      const q = query(
        collection(db, 'projects'),
        where('userId', '==', user.uid)
      )
      const snap = await getDocs(q)
      const list = snap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
      setProjects(list)
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  const today = new Date().toISOString().split('T')[0]

  const getDayIndex = (project) => {
    if (!project.createdAt) return 1
    const created = project.createdAt.toDate()
    const createdDay = created.toISOString().split('T')[0]
    const diff = Math.floor((new Date(today) - new Date(createdDay)) / 86400000)
    return Math.min(diff + 1, project.daysToComplete)
  }

  const getHardWordCount = (project) => project.hardWordCount || 0

  const getReviewDue = (project) => {
    if (!project.lastHardWordDate) return false
    const last = project.lastHardWordDate.toDate()
    const diff = Math.floor((new Date() - last) / 86400000)
    return diff >= 3 && getHardWordCount(project) > 0
  }

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div style={s.header}>
        <div>
          <p style={s.greeting}>早安 👋</p>
          <p style={s.email}>{user.email}</p>
        </div>
        <button style={s.logoutBtn} onClick={logout}>登出</button>
      </div>

      <div className="scrollable" style={{ padding: '0 16px 100px' }}>
        {/* Upload button */}
        <button style={s.uploadBtn} onClick={() => navigate('/upload')}>
          <span style={{ fontSize: '20px' }}>＋</span>
          <span>上傳新 PDF</span>
        </button>

        {/* Projects */}
        <h2 style={s.sectionTitle}>我的學習專案</h2>

        {loading ? (
          <p style={s.hint}>載入中...</p>
        ) : projects.length === 0 ? (
          <div style={s.emptyState}>
            <p style={{ fontSize: '48px' }}>📖</p>
            <p style={{ color: 'var(--text-secondary)', marginTop: '12px' }}>
              還沒有專案，上傳第一個 PDF 開始學習吧！
            </p>
          </div>
        ) : (
          projects.map(p => {
            const dayIdx = getDayIndex(p)
            const reviewDue = getReviewDue(p)
            const hardCount = getHardWordCount(p)
            const progress = Math.round((dayIdx / p.daysToComplete) * 100)

            return (
              <div key={p.id} style={s.card}>
                <div style={s.cardHeader}>
                  <span style={s.pdfIcon}>📄</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={s.cardTitle}>{p.pdfName}</p>
                    <p style={s.cardSub}>第 {dayIdx} 天 / 共 {p.daysToComplete} 天</p>
                  </div>
                </div>

                {/* Progress bar */}
                <div style={s.progressTrack}>
                  <div style={{ ...s.progressFill, width: `${progress}%` }} />
                </div>
                <p style={s.progressText}>{progress}% 完成</p>

                {/* Today's task */}
                <button
                  style={s.studyBtn}
                  onClick={() => navigate(`/study/${p.id}/${dayIdx}`)}
                >
                  📝 今日任務（第 {dayIdx} 天）— {p.wordsPerDay} 個單字
                </button>

                {/* Hard words review reminder */}
                {reviewDue && (
                  <button
                    style={s.reviewBtn}
                    onClick={() => navigate(`/review/${p.id}`)}
                  >
                    🔁 複習提醒：{hardCount} 個難詞需要複習
                  </button>
                )}
              </div>
            )
          })
        )}
      </div>

      <NavBar active="home" />
    </div>
  )
}

const s = {
  header: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '20px 16px 12px', borderBottom: '1px solid var(--border)',
  },
  greeting: { fontSize: '20px', fontWeight: 700 },
  email: { fontSize: '13px', color: 'var(--text-secondary)', marginTop: '2px' },
  logoutBtn: {
    background: 'none', color: 'var(--text-secondary)', fontSize: '13px',
    padding: '6px 12px', border: '1px solid var(--border)', borderRadius: '8px',
  },
  uploadBtn: {
    width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center',
    gap: '8px', padding: '16px', marginTop: '16px', borderRadius: '16px',
    background: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%)',
    color: '#fff', fontSize: '16px', fontWeight: 600,
    boxShadow: '0 4px 16px rgba(79,70,229,0.4)',
  },
  sectionTitle: { fontSize: '17px', fontWeight: 700, margin: '24px 0 12px' },
  hint: { color: 'var(--text-secondary)', textAlign: 'center', marginTop: '40px' },
  emptyState: { textAlign: 'center', padding: '60px 20px' },
  card: {
    background: 'var(--bg-card)', borderRadius: '20px', padding: '20px',
    marginBottom: '16px', border: '1px solid var(--border)',
  },
  cardHeader: { display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' },
  pdfIcon: { fontSize: '28px' },
  cardTitle: { fontSize: '15px', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
  cardSub: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' },
  progressTrack: { height: '6px', background: 'var(--bg-surface)', borderRadius: '3px', overflow: 'hidden' },
  progressFill: { height: '100%', background: 'var(--primary)', borderRadius: '3px', transition: 'width 0.6s ease' },
  progressText: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '6px', marginBottom: '12px' },
  studyBtn: {
    width: '100%', padding: '12px', borderRadius: '12px', fontSize: '14px',
    fontWeight: 600, background: 'var(--primary)', color: '#fff', marginBottom: '8px',
  },
  reviewBtn: {
    width: '100%', padding: '12px', borderRadius: '12px', fontSize: '14px',
    fontWeight: 600, background: 'rgba(245,158,11,0.15)', color: 'var(--warning)',
    border: '1px solid rgba(245,158,11,0.3)',
  },
}
