import { useState } from 'react'
import { motion, useMotionValue, useTransform, useAnimation } from 'framer-motion'

const SWIPE_THRESHOLD = 100

export default function FlashCard({ word, onSwipeLeft, onSwipeRight, remaining }) {
  const [flipped, setFlipped] = useState(false)
  const x = useMotionValue(0)
  const controls = useAnimation()

  const rotate = useTransform(x, [-200, 200], [-25, 25])
  const leftOpacity = useTransform(x, [-SWIPE_THRESHOLD, 0], [1, 0])
  const rightOpacity = useTransform(x, [0, SWIPE_THRESHOLD], [0, 1])
  const cardOpacity = useTransform(x, [-200, -100, 0, 100, 200], [0.5, 1, 1, 1, 0.5])

  const handleDragEnd = async (_, info) => {
    const offset = info.offset.x
    if (offset < -SWIPE_THRESHOLD) {
      await controls.start({ x: -500, opacity: 0, transition: { duration: 0.3 } })
      setFlipped(false)
      onSwipeLeft()
      controls.set({ x: 0, opacity: 1 })
    } else if (offset > SWIPE_THRESHOLD) {
      await controls.start({ x: 500, opacity: 0, transition: { duration: 0.3 } })
      setFlipped(false)
      onSwipeRight()
      controls.set({ x: 0, opacity: 1 })
    } else {
      controls.start({ x: 0, transition: { type: 'spring', stiffness: 300, damping: 20 } })
    }
  }

  return (
    <div style={s.container}>
      {/* Swipe hint labels */}
      <motion.div style={{ ...s.hint, ...s.hintLeft, opacity: leftOpacity }}>
        ✗ 不會
      </motion.div>
      <motion.div style={{ ...s.hint, ...s.hintRight, opacity: rightOpacity }}>
        ✓ 會了
      </motion.div>

      {/* Card */}
      <motion.div
        drag="x"
        dragConstraints={{ left: 0, right: 0 }}
        dragElastic={0.8}
        onDragEnd={handleDragEnd}
        animate={controls}
        style={{ x, rotate, opacity: cardOpacity, cursor: 'grab' }}
        onClick={() => setFlipped(!flipped)}
        whileTap={{ cursor: 'grabbing' }}
      >
        <motion.div
          style={{
            ...s.card,
            background: flipped
              ? 'linear-gradient(135deg, #1e1b4b 0%, #1A1A2E 100%)'
              : 'linear-gradient(135deg, var(--bg-card) 0%, var(--bg-surface) 100%)',
          }}
          animate={{ rotateY: flipped ? 180 : 0 }}
          transition={{ duration: 0.4 }}
        >
          {!flipped ? (
            // Front: English word
            <div style={s.front}>
              <p style={s.remaining}>{remaining} 個剩餘</p>
              <p style={s.word}>{word.word}</p>
              <p style={s.tapHint}>點擊查看解釋</p>
              <div style={s.swipeGuide}>
                <span style={{ color: 'var(--danger)' }}>← 不會</span>
                <span style={{ color: 'var(--success)' }}>會了 →</span>
              </div>
            </div>
          ) : (
            // Back: POS + Chinese translation only (all pre-loaded, no API call here)
            <div style={{ ...s.front, transform: 'rotateY(180deg)', gap: '20px' }}>
              {word.pos && <span style={s.pos}>{word.pos}</span>}
              {word.translation
                ? <p style={s.translation}>{word.translation}</p>
                : <p style={s.noData}>（無翻譯）</p>
              }
            </div>
          )}
        </motion.div>
      </motion.div>
    </div>
  )
}

const s = {
  container: {
    position: 'relative', display: 'flex', justifyContent: 'center',
    alignItems: 'center', flex: 1, padding: '0 16px', userSelect: 'none',
  },
  hint: {
    position: 'absolute', top: '50%', transform: 'translateY(-50%)',
    fontSize: '22px', fontWeight: 800, letterSpacing: '1px',
    padding: '12px 20px', borderRadius: '12px', pointerEvents: 'none', zIndex: 10,
  },
  hintLeft: { left: '24px', color: 'var(--danger)', border: '3px solid var(--danger)', background: 'rgba(239,68,68,0.1)' },
  hintRight: { right: '24px', color: 'var(--success)', border: '3px solid var(--success)', background: 'rgba(16,185,129,0.1)' },
  card: {
    width: 'min(340px, calc(100vw - 48px))',
    minHeight: '420px',
    borderRadius: '28px',
    padding: '32px 28px',
    border: '1px solid var(--border)',
    boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
    display: 'flex', flexDirection: 'column', justifyContent: 'center',
  },
  front: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', textAlign: 'center' },
  remaining: { fontSize: '13px', color: 'var(--text-secondary)', alignSelf: 'flex-end' },
  word: { fontSize: '42px', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-1px' },
  tapHint: { fontSize: '13px', color: 'var(--text-secondary)' },
  swipeGuide: {
    display: 'flex', justifyContent: 'space-between', width: '100%',
    marginTop: '24px', fontSize: '14px', fontWeight: 600,
  },
  backWord: { fontSize: '28px', fontWeight: 800, color: 'var(--text-primary)' },
  pos: {
    fontSize: '12px', fontWeight: 600, background: 'rgba(79,70,229,0.3)',
    color: 'var(--primary-light)', padding: '3px 10px', borderRadius: '20px',
  },
  translation: { fontSize: '22px', fontWeight: 700, color: 'var(--primary-light)' },
  section: { width: '100%', textAlign: 'left', marginTop: '8px' },
  posEmpty: { fontSize: '13px', color: 'var(--text-secondary)', fontStyle: 'italic' },
  noData: { fontSize: '15px', color: 'var(--text-secondary)', fontStyle: 'italic' },
}
