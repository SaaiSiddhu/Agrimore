import { initializeApp, getApps } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  databaseURL: process.env.NEXT_PUBLIC_FIREBASE_DATABASE_URL,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

const isClient = typeof window !== 'undefined';
const hasValidConfig = firebaseConfig.apiKey && firebaseConfig.projectId;

let app: ReturnType<typeof initializeApp> | null = null;
let db: ReturnType<typeof getFirestore> | null = null;
let auth: ReturnType<typeof getAuth> | null = null;
let storage: ReturnType<typeof getStorage> | null = null;

function initializeFirebase() {
  if (!isClient || !hasValidConfig) {
    return { app: null, db: null, auth: null, storage: null };
  }

  if (getApps().length === 0) {
    app = initializeApp(firebaseConfig);
  } else {
    app = getApps()[0];
  }
  db = getFirestore(app);
  auth = getAuth(app);
  storage = getStorage(app);
  return { app, db, auth, storage };
}

export function getFirestoreDb() {
  if (!db && isClient && hasValidConfig) initializeFirebase();
  return db;
}

export function getFirebaseAuth() {
  if (!auth && isClient && hasValidConfig) initializeFirebase();
  return auth;
}

export function getFirebaseStorage() {
  if (!storage && isClient && hasValidConfig) initializeFirebase();
  return storage;
}

export function isFirebaseReady() {
  return Boolean(isClient && hasValidConfig && app);
}
