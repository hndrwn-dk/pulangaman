import admin from 'firebase-admin';
import { config, isFirebaseConfigured } from '../config.js';

let initialized = false;

export function initFirebase(): void {
  if (initialized || !isFirebaseConfigured) {
    return;
  }

  admin.initializeApp({
    projectId: config.FIREBASE_PROJECT_ID,
  });
  initialized = true;
}

export function getFirebaseAuth(): admin.auth.Auth | null {
  if (!isFirebaseConfigured) {
    return null;
  }
  initFirebase();
  return admin.auth();
}

export async function verifyIdToken(idToken: string): Promise<{ uid: string; phone?: string }> {
  const auth = getFirebaseAuth();
  if (!auth) {
    // Dev stub: accept tokens shaped like "dev:<firebaseUid>"
    if (idToken.startsWith('dev:')) {
      return { uid: idToken.slice(4), phone: undefined };
    }
    throw new Error('Firebase is not configured');
  }

  const decoded = await auth.verifyIdToken(idToken);
  return {
    uid: decoded.uid,
    phone: typeof decoded.phone_number === 'string' ? decoded.phone_number : undefined,
  };
}
