// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyCIZR_aJ6nwFJoGN2F5CILAp_zEoOIoE8c",
  authDomain: "agrii-mate.firebaseapp.com",
  projectId: "agrii-mate",
  storageBucket: "agrii-mate.firebasestorage.app",
  messagingSenderId: "240895353385",
  appId: "1:240895353385:web:f8b4dede2e20925e6b7238",
  measurementId: "G-24L77Y66VG"
});

// Retrieve Firebase Messaging instance
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'agroconnect-notification',
    requireInteraction: false,
    data: payload.data || {},
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event.notification);
  
  event.notification.close();
  
  event.waitUntil(
    clients.openWindow('/')
  );
});
