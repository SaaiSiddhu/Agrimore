const admin = require('firebase-admin');

admin.initializeApp();

const email = 'admin@agrimore.com';
const password = 'AdminPassword123!';

async function createAdmin() {
  try {
    console.log('Creating user in Firebase Auth...');
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      emailVerified: true,
      displayName: 'Agrimore Admin',
    });
    
    console.log(`Successfully created user: ${userRecord.uid}`);
    
    console.log('Adding user to Firestore...');
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      name: 'Agrimore Admin',
      role: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('Admin user successfully created and configured!');
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      console.log('User already exists, updating password and role...');
      const userRecord = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(userRecord.uid, { password: password });
      await admin.firestore().collection('users').doc(userRecord.uid).set({
        email: email,
        name: 'Agrimore Admin',
        role: 'admin',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      console.log('Admin user updated!');
    } else {
      console.error('Error creating new user:', error);
    }
  }
}

createAdmin();
