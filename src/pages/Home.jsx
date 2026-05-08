import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { collection, query, where, getDocs, doc, deleteDoc, writeBatch } from 'firebase/firestore'
import { db } from '../firebase/config'
import { useAuth } from '../contexts/AuthContext'
import NavBar from '../components/NavBar'

export default function Home() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)
  const [deleteTarget, setDeleteTarget] = useState(null) // 待刪除的專案
  const [deleting, setDeleting] = useState(false)

  useEffect(() => { loadProjects() }, [])

  const loadProjects = async () => {
    try {
      const q = query(collection(db, 'projects'), where('userId', '==', user.uid))
      const snap = await getDocs(q)
      const list = snap.docs
        .map(d => ({ id: d.id, ...d.data() }))
        .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0))
      setProjects(list)
    } catch (e) { console.error(e) }
    setLoading(false)
  }

  const handleDelete = async () => {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      // 刪除 words 子集合
      const wordsSnap = await getDocs(collection(db, 'projects', deleteTarget.id, 'words'))
      const CHUNK = 400
      for (let i = 0; i < wordsSnap.docs.length; i += CHUNK) {
        const batch = writeBatch(db)
        wordsSnap.docs.slice(i, i + CHUNK).forEach(d => batch.delete(d.ref))
        await batch.commit()
      }
      // 刪除專案文件
      await deleteDoc(doc(db, 'projects', deleteTarget.id))
      setProjects(prev => prev.filter(p => p.id !== deleteTarget.id))
    } catch (e) {
      console.error(e)
      alert('刪除失敗，請再試一次')
    }
    setDeleting(false)
    setDeleteTarget(null)
  }

  const today = new Date().toISOString().split('T')[0]

  const getDayIndex = (project) => {
    if (!project.createdAt) return 1
    const created = project.createdAt.toDate()
    const diff = Math.floor((new Date(today) - new Date(created.toISOString().split('T')[0])) / 86400000)
    return Math.min(diff + 1, project.daysToComplete)
  }

  const getReviewDue = (p) => {
    if (!p.lastHardWordDate) return false
    const diff = Math.floor((new Date() - p.lastHardWordDate.toDate()) / 86400000)
    return diff >= 3 && (p.hardWordCount || 0) > 0
  }

  return (
    <div className="page" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div style={s.header}>
        <div>
          <p style={s.greeting}>📚 AI Vocab Master</p>
          <p style={s.email}>{user.email}</p>
        </div>
        <button style={s.logoutBtn} onClick={logout}>登出</button>
      </div>

      <div className="scrollable" style={{ padding: '0 16px 100px' }}>
        <button style={s.uploadBtn} onClick={() => navigate('/upload')}>
          <span style={{ fontSize: '20px' }}>＋</span>
          <span>上傳新 PDF</span>
        </button>

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
            const progress = Math.round((dayIdx / p.daysToComplete) * 100)

            return (
              <div key={p.id} style={s.card}>
                {/* Card header */}
                <div style={s.cardHeader}>
                  <span style={s.pdfIcon}>📄</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={s.cardTitle}>{p.pdfName}</p>
                    <p style={s.cardSub}>第 {dayIdx} 天 / 共 {p.daysToComplete} 天・{p.totalWords} 個單字</p>
                  </div>
                  {/* 刪除按鈕 */}
                  <button style={s.deleteBtn} onClick={() => setDeleteTarget(p)}>🗑</button>
                </div>

                {/* Progress bar */}
                <div style={s.progressTrack}>
                  <div style={{ ...s.progressFill, width: `${progress}%` }} />
                </div>
                <p style={s.progressText}>{progress}% 完成</p>

                <button style={s.openBtn} onClick={() => navigate(`/project/${p.id}`)}>
                  📅 查看所有天數
                </button>
                <button style={s.studyBtn} onClick={() => navigate(`/study/${p.id}/${dayIdx}`)}>
                  📝 今日任務（第 {dayIdx} 天）— {p.wordsPerDay} 個單字
                </button>

                {reviewDue && (
                  <button style={s.reviewBtn} onClick={() => navigate(`/review/${p.id}`)}>
                    🔁 複習提醒：{p.hardWordCount} 個難詞需要複習
                  </button>
                )}
              </div>
            )
          })
        )}
      </div>

      {/* 刪除確認彈窗 */}
      {deleteTarget && (
        <div style={s.overlay}>
          <div style={s.dialog}>
            <p style={s.dialogTitle}>🗑 刪除專案</p>
            <p style={s.dialogMsg}>
              確定要刪除「<strong>{deleteTarget.pdfName}</strong>」嗎？
              <br />所有單字記錄將一併刪除，無法復原。
            </p>
            <div style={s.dialogBtns}>
              <button style={s.cancelBtn} onClick={() => setDeleteTarget(null)} disabled={deleting}>
                取消
              </button>
              <button style={s.confirmBtn} onClick={handleDelete} disabled={deleting}>
                {deleting ? '刪除中...' : '確定刪除'}
              </button>
            </div>
          </div>
        </div>
      )}

      <NavBar active="home" />
    </div>
  )
}

const s = {
  header: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 16px 12px', borderBottom: '1px solid var(--border)' },
  greeting: { fontSize: '18px', fontWeight: 700 },
  email: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' },
  logoutBtn: { background: 'none', color: 'var(--text-secondary)', fontSize: '13px', padding: '6px 12px', border: '1px solid var(--border)', borderRadius: '8px' },
  uploadBtn: { width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', padding: '16px', marginTop: '16px', borderRadius: '16px', background: 'linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%)', color: '#fff', fontSize: '16px', fontWeight: 600, boxShadow: '0 4px 16px rgba(79,70,229,0.4)' },
  sectionTitle: { fontSize: '17px', fontWeight: 700, margin: '24px 0 12px' },
  hint: { color: 'var(--text-secondary)', textAlign: 'center', marginTop: '40px' },
  emptyState: { textAlign: 'center', padding: '60px 20px' },
  card: { background: 'var(--bg-card)', borderRadius: '20px', padding: '20px', marginBottom: '16px', border: '1px solid var(--border)' },
  cardHeader: { display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' },
  pdfIcon: { fontSize: '28px' },
  cardTitle: { fontSize: '15px', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
  cardSub: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' },
  deleteBtn: { background: 'rgba(239,68,68,0.15)', fontSize: '16px', padding: '8px 10px', flexShrink: 0, borderRadius: '10px', border: '1px solid rgba(239,68,68,0.3)', color: 'var(--danger)', lineHeight: 1 },
  progressTrack: { height: '6px', background: 'var(--bg-surface)', borderRadius: '3px', overflow: 'hidden' },
  progressFill: { height: '100%', background: 'var(--primary)', borderRadius: '3px', transition: 'width 0.6s ease' },
  progressText: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '6px', marginBottom: '12px' },
  openBtn: { width: '100%', padding: '11px', borderRadius: '12px', fontSize: '14px', fontWeight: 600, background: 'var(--bg-surface)', color: 'var(--text-primary)', border: '1px solid var(--border)', marginBottom: '8px' },
  studyBtn: { width: '100%', padding: '12px', borderRadius: '12px', fontSize: '14px', fontWeight: 600, background: 'var(--primary)', color: '#fff', marginBottom: '8px' },
  reviewBtn: { width: '100%', padding: '12px', borderRadius: '12px', fontSize: '14px', fontWeight: 600, background: 'rgba(245,158,11,0.15)', color: 'var(--warning)', border: '1px solid rgba(245,158,11,0.3)' },
  // Dialog
  overlay: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '24px' },
  dialog: { background: 'var(--bg-card)', borderRadius: '24px', padding: '28px 24px', width: '100%', maxWidth: '340px', border: '1px solid var(--border)' },
  dialogTitle: { fontSize: '18px', fontWeight: 700, marginBottom: '12px' },
  dialogMsg: { fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.7, marginBottom: '24px' },
  dialogBtns: { display: 'flex', gap: '10px' },
  cancelBtn: { flex: 1, padding: '13px', borderRadius: '12px', fontSize: '15px', fontWeight: 600, background: 'var(--bg-surface)', color: 'var(--text-primary)', border: '1px solid var(--border)' },
  confirmBtn: { flex: 1, padding: '13px', borderRadius: '12px', fontSize: '15px', fontWeight: 600, background: 'var(--danger)', color: '#fff' },
}
