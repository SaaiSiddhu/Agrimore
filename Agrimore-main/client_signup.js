const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, setDoc } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc",
  authDomain: "agrimore-66a4e.firebaseapp.com",
  projectId: "agrimore-66a4e",
  storageBucket: "agrimore-66a4e.firebasestorage.app",
  messagingSenderId: "1082819024270",
  appId: "1:1082819024270:web:fa2a015928e81bf1e640df"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function createAdminUser() {
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, "srieswaran@agrimore.com", "Admin@2005!!!!");
    const user = userCredential.user;
    
    await setDoc(doc(db, "users", user.uid), {
      email: user.email,
      name: "Agrimore Admin Test",
      role: "admin",
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    console.log("SUCCESS! Admin created. Email: srieswaran@agrimore.com Password: Admin@2005!!!!");
    process.exit(0);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

createAdminUser();
