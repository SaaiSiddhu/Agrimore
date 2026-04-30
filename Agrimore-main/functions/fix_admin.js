/**
 * fix_admin.js — Sets admin role via Firebase REST API (no service account needed)
 * Uses the Firebase Auth REST API + Firestore REST API
 * Run: node fix_admin.js
 */

const https = require('https');

const PROJECT_ID = 'agrimore-66a4e';
const API_KEY = 'AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc';
const ADMIN_EMAIL = 'admin@agrimore.com';
const ADMIN_PASSWORD = 'AdminPassword123!';

function httpsPost(url, data) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };
    const req = https.request(options, (res) => {
      let d = '';
      res.on('data', chunk => d += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(d)); }
        catch { resolve(d); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function httpsPatch(url, data, idToken) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'Authorization': `Bearer ${idToken}`,
      },
    };
    const req = https.request(options, (res) => {
      let d = '';
      res.on('data', chunk => d += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(d)); }
        catch { resolve(d); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  console.log('🔐 Signing in as admin...');
  
  // Sign in with email/password to get idToken + uid
  const signInRes = await httpsPost(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, returnSecureToken: true }
  );

  if (signInRes.error) {
    // User doesn't exist yet — create first
    if (signInRes.error.message === 'EMAIL_NOT_FOUND' || signInRes.error.message === 'INVALID_LOGIN_CREDENTIALS') {
      console.log('📝 Admin not found, creating new account...');
      const signUpRes = await httpsPost(
        `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
        { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, displayName: 'Agrimore Admin', returnSecureToken: true }
      );
      if (signUpRes.error) {
        console.error('❌ Sign up failed:', signUpRes.error.message);
        process.exit(1);
      }
      console.log(`✅ Created auth user: ${signUpRes.localId}`);
      await setAdminRole(signUpRes.localId, signUpRes.idToken);
    } else {
      console.error('❌ Sign in failed:', signInRes.error.message);
      process.exit(1);
    }
    return;
  }

  const uid = signInRes.localId;
  const idToken = signInRes.idToken;
  console.log(`✅ Signed in as: ${signInRes.email} (uid: ${uid})`);
  
  await setAdminRole(uid, idToken);
}

async function setAdminRole(uid, idToken) {
  console.log('🔧 Setting role: admin in Firestore...');

  // Firestore REST patch - set role field
  const firestoreUrl = 
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}?updateMask.fieldPaths=role&updateMask.fieldPaths=name&updateMask.fieldPaths=email`;

  const patchBody = {
    fields: {
      role: { stringValue: 'admin' },
      name: { stringValue: 'Agrimore Admin' },
      email: { stringValue: ADMIN_EMAIL },
    }
  };

  const patchRes = await httpsPatch(firestoreUrl, patchBody, idToken);
  
  if (patchRes.error) {
    // If patch fails (doc doesn't exist), use set instead
    console.log('⚠️ Patch failed (doc may not exist), using SET...');
    const setUrl =
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`;
    const setBody = {
      fields: {
        uid: { stringValue: uid },
        email: { stringValue: ADMIN_EMAIL },
        name: { stringValue: 'Agrimore Admin' },
        role: { stringValue: 'admin' },
        createdAt: { timestampValue: new Date().toISOString() },
        updatedAt: { timestampValue: new Date().toISOString() },
      }
    };
    const setRes = await httpsPatch(setUrl, setBody, idToken);
    if (setRes.error) {
      console.error('❌ Firestore set failed:', JSON.stringify(setRes.error));
      process.exit(1);
    }
    console.log('✅ Firestore user document created with role: admin');
  } else {
    console.log('✅ Firestore role updated to: admin');
  }

  // Also add email to settings/access.adminEmails allowlist
  console.log('📋 Updating settings/access.adminEmails allowlist...');
  const settingsUrl =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/settings/access?updateMask.fieldPaths=adminEmails`;
  const settingsBody = {
    fields: {
      adminEmails: {
        arrayValue: {
          values: [{ stringValue: ADMIN_EMAIL }]
        }
      }
    }
  };
  const settingsRes = await httpsPatch(settingsUrl, settingsBody, idToken);
  if (settingsRes.error) {
    console.warn('⚠️ Could not update settings/access (may need admin token). Error:', settingsRes.error.message);
    console.log('💡 Manually add to Firestore: settings/access → adminEmails: ["admin@agrimore.com"]');
  } else {
    console.log('✅ settings/access.adminEmails updated!');
  }

  console.log('\n🎉 DONE! Admin setup complete:');
  console.log(`   Email:    ${ADMIN_EMAIL}`);
  console.log(`   Password: ${ADMIN_PASSWORD}`);
  console.log(`   Role:     admin`);
  console.log('\n   Login at: https://agrimore-66a4e-bb1da.web.app');
}

main().catch(console.error);
