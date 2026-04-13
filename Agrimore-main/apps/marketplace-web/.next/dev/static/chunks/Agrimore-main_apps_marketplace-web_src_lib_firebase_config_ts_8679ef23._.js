(globalThis.TURBOPACK || (globalThis.TURBOPACK = [])).push([typeof document === "object" ? document.currentScript : undefined,
"[project]/Agrimore-main/apps/marketplace-web/src/lib/firebase/config.ts [app-client] (ecmascript)", ((__turbopack_context__) => {
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
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = /*#__PURE__*/ __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/next/dist/build/polyfills/process.js [app-client] (ecmascript)");
// Firebase configuration for Next.js
// Uses the same Firebase project as Flutter apps
// Only initializes on client side to avoid SSR issues
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$app$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/app/dist/esm/index.esm.js [app-client] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$app$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/@firebase/app/dist/esm/index.esm.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$firestore$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/firestore/dist/esm/index.esm.js [app-client] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$firestore$2f$dist$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/@firebase/firestore/dist/index.esm.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$auth$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/auth/dist/esm/index.esm.js [app-client] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$auth$2f$dist$2f$esm$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/@firebase/auth/dist/esm/index.js [app-client] (ecmascript)");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$firebase$2f$storage$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__$3c$locals$3e$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/firebase/storage/dist/esm/index.esm.js [app-client] (ecmascript) <locals>");
var __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$storage$2f$dist$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__ = __turbopack_context__.i("[project]/Agrimore-main/apps/marketplace-web/node_modules/@firebase/storage/dist/index.esm.js [app-client] (ecmascript)");
;
;
;
;
const firebaseConfig = {
    apiKey: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    databaseURL: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_DATABASE_URL,
    projectId: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    storageBucket: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_APP_ID,
    measurementId: __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f$next$2f$dist$2f$build$2f$polyfills$2f$process$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["default"].env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID
};
// Check if we're in a browser environment and have valid config
const isClient = ("TURBOPACK compile-time value", "object") !== 'undefined';
const hasValidConfig = firebaseConfig.apiKey && firebaseConfig.projectId;
let app = null;
let db = null;
let auth = null;
let storage = null;
// Initialize Firebase only on client side with valid config
function initializeFirebase() {
    if (!isClient || !hasValidConfig) {
        return {
            app: null,
            db: null,
            auth: null,
            storage: null
        };
    }
    if ((0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$app$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getApps"])().length === 0) {
        app = (0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$app$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["initializeApp"])(firebaseConfig);
    } else {
        app = (0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$app$2f$dist$2f$esm$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getApps"])()[0];
    }
    db = (0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$firestore$2f$dist$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getFirestore"])(app);
    auth = (0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$auth$2f$dist$2f$esm$2f$index$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getAuth"])(app);
    storage = (0, __TURBOPACK__imported__module__$5b$project$5d2f$Agrimore$2d$main$2f$apps$2f$marketplace$2d$web$2f$node_modules$2f40$firebase$2f$storage$2f$dist$2f$index$2e$esm$2e$js__$5b$app$2d$client$5d$__$28$ecmascript$29$__["getStorage"])(app);
    return {
        app,
        db,
        auth,
        storage
    };
}
function getFirebaseApp() {
    if (!app && isClient && hasValidConfig) {
        initializeFirebase();
    }
    return app;
}
function getFirestoreDb() {
    if (!db && isClient && hasValidConfig) {
        initializeFirebase();
    }
    return db;
}
function getFirebaseAuth() {
    if (!auth && isClient && hasValidConfig) {
        initializeFirebase();
    }
    return auth;
}
function getFirebaseStorage() {
    if (!storage && isClient && hasValidConfig) {
        initializeFirebase();
    }
    return storage;
}
const firebaseApp = app;
const firestore = db;
const firebaseAuth = auth;
const firebaseStorage = storage;
function isFirebaseReady() {
    return Boolean(isClient && hasValidConfig && app);
}
if (typeof globalThis.$RefreshHelpers$ === 'object' && globalThis.$RefreshHelpers !== null) {
    __turbopack_context__.k.registerExports(__turbopack_context__.m, globalThis.$RefreshHelpers$);
}
}),
]);

//# sourceMappingURL=Agrimore-main_apps_marketplace-web_src_lib_firebase_config_ts_8679ef23._.js.map