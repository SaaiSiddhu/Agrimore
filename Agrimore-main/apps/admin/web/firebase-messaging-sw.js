// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyDrQIYzWcC1RAaS474r_a9I9caY3cCVTSc",
  authDomain: "agrimore-66a4e.firebaseapp.com",
  databaseURL: "https://agrimore-66a4e-default-rtdb.firebaseio.com",
  projectId: "agrimore-66a4e",
  storageBucket: "agrimore-66a4e.firebasestorage.app",
  messagingSenderId: "1082819024270",
  appId: "1:1082819024270:web:fa2a015928e81bf1e640df",
  measurementId: "G-73B1F06XC3"
});

// Retrieve Firebase Messaging instance
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'agrimore-admin-notification',
    requireInteraction: false,
    data: payload.data || {},
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function (event) {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event.notification);

  event.notification.close();

  event.waitUntil(
    clients.openWindow('/')
  );
});
