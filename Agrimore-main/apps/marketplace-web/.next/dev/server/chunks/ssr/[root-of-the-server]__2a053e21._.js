module.exports = [
"[externals]/util [external] (util, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("util", () => require("util"));

module.exports = mod;
}),
"[externals]/crypto [external] (crypto, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("crypto", () => require("crypto"));

module.exports = mod;
}),
"[externals]/process [external] (process, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("process", () => require("process"));

module.exports = mod;
}),
"[externals]/tls [external] (tls, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("tls", () => require("tls"));

module.exports = mod;
}),
"[externals]/fs [external] (fs, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("fs", () => require("fs"));

module.exports = mod;
}),
"[externals]/os [external] (os, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("os", () => require("os"));

module.exports = mod;
}),
"[externals]/net [external] (net, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("net", () => require("net"));

module.exports = mod;
}),
"[externals]/events [external] (events, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("events", () => require("events"));

module.exports = mod;
}),
"[externals]/stream [external] (stream, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("stream", () => require("stream"));

module.exports = mod;
}),
"[externals]/path [external] (path, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("path", () => require("path"));

module.exports = mod;
}),
"[externals]/http2 [external] (http2, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("http2", () => require("http2"));

module.exports = mod;
}),
"[externals]/http [external] (http, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("http", () => require("http"));

module.exports = mod;
}),
"[externals]/url [external] (url, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("url", () => require("url"));

module.exports = mod;
}),
"[externals]/dns [external] (dns, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("dns", () => require("dns"));

module.exports = mod;
}),
"[externals]/zlib [external] (zlib, cjs)", ((__turbopack_context__, module, exports) => {

const mod = __turbopack_context__.x("zlib", () => require("zlib"));

module.exports = mod;
}),
"[project]/Agrimore-main/apps/marketplace-web/src/lib/firebase/config.ts [app-ssr] (ecmascript)", ((__turbopack_context__) => {
"use strict";

__turbopack_context__.s([
    "firebaseApp",
    ()=>firebaseApp,
    "firebaseAuth",
    ()=>firebaseAuth,
    "firebaseStorage",
    ()=>firebaseStorage,
    "firestore",
    ()=>firestore,
    "getFirebaseApp",
    ()=>getFirebaseApp,
    "getFirebaseAuth",
    ()=>getFirebaseAuth,
    "getFirebaseStorage",
    ()=>getFirebaseStorage,
    "getFirestoreDb",
    ()=>getFirestoreDb,
    "isFirebaseReady",
    ()=>isFirebaseReady
]);
// Firebase configuration for Next.js
// Uses the same Firebase project as Flutter apps
// Only initializes on client side to avoid SSR issues
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$app$2f$dist$2f$index$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/app/dist/index.mjs [app-ssr] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$firestore$2f$dist$2f$index$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/firestore/dist/index.mjs [app-ssr] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$auth$2f$dist$2f$index$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/auth/dist/index.mjs [app-ssr] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$storage$2f$dist$2f$index$2e$mjs__$5b$app$2d$ssr$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/storage/dist/index.mjs [app-ssr] (ecmascript) <locals>");
;
;
;
;
const firebaseConfig = {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    databaseURL: process.env.NEXT_PUBLIC_FIREBASE_DATABASE_URL,
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
    measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID
};
// Check if we're in a browser environment and have valid config
const isClient = ("TURBOPACK compile-time value", "undefined") !== 'undefined';
const hasValidConfig = firebaseConfig.apiKey && firebaseConfig.projectId;
let app = null;
let db = null;
let auth = null;
let storage = null;
// Initialize Firebase only on client side with valid config
function initializeFirebase() {
    if ("TURBOPACK compile-time truthy", 1) {
        return {
            app: null,
            db: null,
            auth: null,
            storage: null
        };
    }
    //TURBOPACK unreachable
    ;
}
function getFirebaseApp() {
    if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
    ;
    return app;
}
function getFirestoreDb() {
    if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
    ;
    return db;
}
function getFirebaseAuth() {
    if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
    ;
    return auth;
}
function getFirebaseStorage() {
    if ("TURBOPACK compile-time falsy", 0) //TURBOPACK unreachable
    ;
    return storage;
}
const firebaseApp = app;
const firestore = db;
const firebaseAuth = auth;
const firebaseStorage = storage;
function isFirebaseReady() {
    return Boolean(isClient && hasValidConfig && app);
}
}),
];

//# sourceMappingURL=%5Broot-of-the-server%5D__2a053e21._.js.map