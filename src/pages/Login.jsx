import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'

export default function Login() {
  const { loginWithGoogle } = useAuth()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleGoogle = async () => {
    setError('')
    setLoading(true)
    try {
      await loginWithGoogle()
    } catch (err) {
      if (err.code !== 'auth/popup-closed-by-user') {
        setError('登入失敗，請再試一次')
      }
    }
    setLoading(false)
  }

  return (
    <div style={s.page}>
      <div style={s.card}>
        <div style={s.logo}>📚</div>
        <h1 style={s.title}>AI Vocab Master</h1>
        <p style={s.sub}>PDF 智慧字卡學習器</p>

        <button style={s.googleBtn} onClick={handleGoogle} disabled={loading}>
          {loading ? (
            <span>登入中...</span>
          ) : (
            <>
              <GoogleIcon />
              <span>使用 Google 帳號登入</span>
            </>
          )}
        </button>

        {error && <p style={s.error}>{error}</p>}

        <p style={s.hint}>登入後即可上傳 PDF 開始學習</p>
      </div>
    </div>
  )
}

function GoogleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
    </svg>
  )
}

const s = {
  page: {
    height: '100%', display: 'flex', alignItems: 'center',
    justifyContent: 'center', padding: '24px',
    background: 'linear-gradient(135deg, #0F0F1A 0%, #1A1A2E 100%)',
  },
  card: {
    width: '100%', maxWidth: '380px', textAlign: 'center',
    background: 'var(--bg-card)', borderRadius: '24px',
    padding: '48px 32px', border: '1px solid var(--border)',
    boxShadow: 'var(--shadow)',
  },
  logo: { fontSize: '56px', marginBottom: '16px' },
  title: { fontSize: '26px', fontWeight: 700, marginBottom: '6px' },
  sub: { fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '40px' },
  googleBtn: {
    width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center',
    gap: '12px', padding: '15px 24px', borderRadius: '14px', fontSize: '15px',
    fontWeight: 600, background: '#fff', color: '#1f1f1f',
    boxShadow: '0 2px 12px rgba(0,0,0,0.3)', transition: 'opacity 0.2s',
  },
  error: { color: 'var(--danger)', fontSize: '13px', marginTop: '16px' },
  hint: { fontSize: '12px', color: 'var(--text-secondary)', marginTop: '24px' },
}
