import { readFileSync, existsSync } from 'node:fs';
import admin from 'firebase-admin';
import { config, isFirebaseConfigured } from '../config.js';

let initialized = false;

export function initFirebase(): void {
  if (initialized || !isFirebaseConfigured) {
    return;
  }

  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
  if (credPath && existsSync(credPath)) {
    const serviceAccount = JSON.parse(readFileSync(credPath, 'utf8')) as admin.ServiceAccount;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: config.FIREBASE_PROJECT_ID || serviceAccount.projectId,
    });
  } else {
    // Falls back to ADC. createCustomToken needs a real service-account key;
    // without one, child invite join will fail while verifyIdToken may still work.
    console.warn('firebase_admin_no_service_account_file', {
      credPath: credPath || null,
      hint: 'Set GOOGLE_APPLICATION_CREDENTIALS to the service account JSON path',
    });
    admin.initializeApp({
      projectId: config.FIREBASE_PROJECT_ID,
    });
  }

  initialized = true;
}

export function getFirebaseAuth(): admin.auth.Auth | null {
  if (!isFirebaseConfigured) {
    return null;
  }
  initFirebase();
  return admin.auth();
}

export function getFirebaseMessaging(): admin.messaging.Messaging | null {
  if (!isFirebaseConfigured) {
    return null;
  }
  initFirebase();
  return admin.messaging();
}

export function isMessagingAvailable(): boolean {
  return isFirebaseConfigured;
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

  try {
    const decoded = await auth.verifyIdToken(idToken);
    return {
      uid: decoded.uid,
      phone: typeof decoded.phone_number === 'string' ? decoded.phone_number : undefined,
    };
  } catch (error) {
    const code =
      error && typeof error === 'object' && 'code' in error
        ? String((error as { code?: string }).code)
        : 'unknown';
    console.error('verify_id_token_failed', { code });
    throw error;
  }
}

export async function verifyAppCheckToken(token: string): Promise<void> {
  if (!isFirebaseConfigured) return; // local dev without a project — skip
  initFirebase();
  await admin.appCheck().verifyToken(token);
}

export async function createChildCustomToken(
  firebaseUid: string,
): Promise<{ customToken: string | null; firebaseUid: string }> {
  const auth = getFirebaseAuth();
  if (!auth) {
    return { customToken: `dev-custom:${firebaseUid}`, firebaseUid };
  }
  try {
    const customToken = await auth.createCustomToken(firebaseUid, { role: 'child' });
    return { customToken, firebaseUid };
  } catch (error) {
    console.error('create_custom_token_failed', {
      firebaseUid,
      message: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

export async function ensureFirebaseUser(params: {
  uid: string;
  phone?: string;
  displayName: string;
}): Promise<string> {
  const auth = getFirebaseAuth();
  if (!auth) {
    return params.uid;
  }

  try {
    await auth.getUser(params.uid);
    return params.uid;
  } catch {
    const createRequest: admin.auth.CreateRequest = {
      uid: params.uid,
      displayName: params.displayName,
    };
    // Only set phone when valid E.164 — undefined can make Admin SDK throw.
    if (params.phone && params.phone.startsWith('+')) {
      createRequest.phoneNumber = params.phone;
    }
    const created = await auth.createUser(createRequest);
    return created.uid;
  }
}
