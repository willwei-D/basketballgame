import { useNavigate } from 'react-router-dom'

const tabs = [
  { key: 'home', icon: '🏠', label: '首頁', path: '/' },
  { key: 'upload', icon: '＋', label: '上傳', path: '/upload' },
]

export default function NavBar({ active }) {
  const navigate = useNavigate()

  return (
    <nav style={s.nav}>
      {tabs.map(t => (
        <button
          key={t.key}
          style={{ ...s.tab, ...(active === t.key ? s.tabActive : {}) }}
          onClick={() => navigate(t.path)}
        >
          <span style={s.icon}>{t.icon}</span>
          <span style={s.label}>{t.label}</span>
        </button>
      ))}
    </nav>
  )
}

const s = {
  nav: {
    display: 'flex', background: 'var(--bg-card)', borderTop: '1px solid var(--border)',
    padding: '8px 0 env(safe-area-inset-bottom, 8px)',
  },
  tab: {
    flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
    gap: '3px', padding: '8px', background: 'none',
    color: 'var(--text-secondary)', transition: 'color 0.2s',
  },
  tabActive: { color: 'var(--primary-light)' },
  icon: { fontSize: '22px' },
  label: { fontSize: '11px', fontWeight: 500 },
}
