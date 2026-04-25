import { initializeApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider } from 'firebase/auth'
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager
} from 'firebase/firestore'

const firebaseConfig = {
  apiKey: "AIzaSyD37pK90I4JVtBgQiI7suoesKZYSEmxhRM",
  authDomain: "vocab-flashcard-58f90.firebaseapp.com",
  projectId: "vocab-flashcard-58f90",
  storageBucket: "vocab-flashcard-58f90.firebasestorage.app",
  messagingSenderId: "772978379347",
  appId: "1:772978379347:web:7bc37e32a8c40137f294a6",
  measurementId: "G-MY9WGDRYH2"
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const googleProvider = new GoogleAuthProvider()

// 離線緩存（新 API）
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager()
  })
})

export default app
