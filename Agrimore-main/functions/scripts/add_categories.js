const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

const sampleCategories = [
    {
        name: 'Seeds',
        description: 'Quality seeds for farming',
        icon: 'seed',
        imageUrl: '',
        isActive: true,
        displayOrder: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
        name: 'Fertilizers',
        description: 'Organic and chemical fertilizers',
        icon: 'fertilizer',
        imageUrl: '',
        isActive: true,
        displayOrder: 2,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
        name: 'Pesticides',
        description: 'Crop protection products',
        icon: 'pesticide',
        imageUrl: '',
        isActive: true,
        displayOrder: 3,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
        name: 'Farm Equipment',
        description: 'Tools and machinery for farming',
        icon: 'equipment',
        imageUrl: '',
        isActive: true,
        displayOrder: 4,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
        name: 'Irrigation',
        description: 'Irrigation systems and supplies',
        icon: 'irrigation',
        imageUrl: '',
        isActive: true,
        displayOrder: 5,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
        name: 'Organic Products',
        description: 'Certified organic farming products',
        icon: 'organic',
        imageUrl: '',
        isActive: true,
        displayOrder: 6,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
];

async function addCategories() {
    console.log('🌱 Adding sample categories to Firestore...');

    const batch = db.batch();

    for (const category of sampleCategories) {
        const docRef = db.collection('categories').doc();
        batch.set(docRef, category);
        console.log(`  ➕ ${category.name}`);
    }

    await batch.commit();
    console.log('✅ Sample categories added successfully!');
}

addCategories()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('❌ Error:', err);
        process.exit(1);
    });
