// ============================================================
//  Unified admin support cases (ADMR-61)
// ============================================================
//
// The investigation layer, not a competing source of truth. Modelled
// directly on rider_support_tickets (../delivery/riderSupport.ts) --
// the only real, live support pattern anywhere in this codebase before
// this phase: idempotent creation, a simple real lifecycle, server-
// stamped actor identity, a required note on resolve, and critically a
// CONSTRAINED, TYPED reference schema (riderSupport.ts's own
// `relatedTo: {type, id}`), never an arbitrary client-supplied path.
//
// rider_support_tickets / rider_incidents / delivery_exceptions keep
// their own status fields as authoritative for their own domain -- a
// case's own status describes the INVESTIGATION, never the underlying
// operational record, and no command here ever mutates them.
//
// Admin-only for this first release (firestore.rules: allow read: if
// isAdmin(); allow write: if false on all three collections below,
// matching every other admin-mutated collection in this codebase) --
// no participant-visible communication yet.
//
// This phase deliberately ships six commands only: create, assign,
// change status, add note, resolve, reopen. Link/unlink, create-from-
// an-existing-ticket, and evidence upload are a closely-following
// phase so this one stays reviewable.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { resolveIsAdmin } from "./complianceGate";

type Db = FirebaseFirestore.Firestore;

export const SUPPORT_CASE_ACTOR_TYPES = ["customer", "seller", "rider", "associate"] as const;
export type SupportCaseActorType = (typeof SUPPORT_CASE_ACTOR_TYPES)[number];

export const SUPPORT_CASE_STATUSES = ["open", "in_progress", "waiting", "resolved"] as const;
export type SupportCaseStatus = (typeof SUPPORT_CASE_STATUSES)[number];

export const MAX_TITLE = 200;
export const MAX_TEXT = 2000;
const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

export type ActorRef = { type: SupportCaseActorType; id: string };

// The real collection backing each actor type. No arbitrary client-
// supplied path is ever trusted -- every actor is resolved against its
// OWN real collection, server-side, before a case can reference it.
const ACTOR_COLLECTION: Record<SupportCaseActorType, string> = {
  customer: "users",
  seller: "sellers",
  rider: "delivery_partners",
  associate: "employees",
};

export function parseActorRef(v: unknown): ActorRef | undefined {
  if (typeof v !== "object" || v === null) return undefined;
  const r = v as Record<string, unknown>;
  if (!(SUPPORT_CASE_ACTOR_TYPES as readonly string[]).includes(r.type as string)) return undefined;
  if (typeof r.id !== "string" || !r.id.trim()) return undefined;
  return { type: r.type as SupportCaseActorType, id: r.id.trim() };
}

async function assertActorExists(db: Db, actor: ActorRef): Promise<boolean> {
  const snap = await db.collection(ACTOR_COLLECTION[actor.type]).doc(actor.id).get();
  return snap.exists;
}

async function requireAdmin(
  request: { auth?: { uid: string; token: Record<string, unknown> } }
): Promise<string> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
  const ok = await resolveIsAdmin(admin.firestore(), request.auth.uid, request.auth.token.admin === true);
  if (!ok) throw new HttpsError("permission-denied", "Admins only");
  return request.auth.uid;
}

async function writeEvent(
  db: Db,
  caseId: string,
  type: string,
  actorUid: string,
  at: Timestamp,
  details: Record<string, unknown> = {}
): Promise<void> {
  await db.collection("support_case_events").add({ caseId, type, actorUid, at, details });
}

// ── create ──

export type CreateSupportCaseVerdict =
  | { kind: "created"; caseId: string }
  | { kind: "refused"; reason: "bad_request" | "actor_not_found" };

export async function createSupportCaseCore(
  db: Db,
  adminUid: string,
  data: unknown,
  nowMs: number
): Promise<CreateSupportCaseVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const title = typeof d.title === "string" ? d.title.trim() : "";
  const category = typeof d.category === "string" ? d.category.trim() : "";
  const primaryActor = parseActorRef(d.primaryActor);
  if (!title || title.length > MAX_TITLE || !category || !primaryActor) {
    return { kind: "refused", reason: "bad_request" };
  }
  if (!(await assertActorExists(db, primaryActor))) {
    return { kind: "refused", reason: "actor_not_found" };
  }
  const caseRef = db.collection("support_cases").doc();
  const at = Timestamp.fromMillis(nowMs);
  await caseRef.set({
    caseId: caseRef.id,
    title,
    category,
    primaryActor,
    status: "open" as SupportCaseStatus,
    waitingReason: null,
    assignedTo: null,
    createdBy: adminUid,
    createdAt: at,
    updatedAt: at,
    resolutionSummary: null,
    resolvedAt: null,
    resolvedBy: null,
    reopenedAt: null,
    reopenedBy: null,
    reopenReason: null,
    version: 1,
  });
  await writeEvent(db, caseRef.id, "created", adminUid, at, { title, category, primaryActor });
  return { kind: "created", caseId: caseRef.id };
}

// ── assign ──

export type AssignSupportCaseVerdict =
  | { kind: "assigned" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "assignee_not_admin" };

export async function assignSupportCaseCore(
  db: Db,
  adminUid: string,
  caseId: string,
  assigneeUid: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<AssignSupportCaseVerdict> {
  const assignee = typeof assigneeUid === "string" ? assigneeUid.trim() : "";
  if (!assignee || typeof expectedVersion !== "number") {
    return { kind: "refused", reason: "bad_request" };
  }
  const assigneeSnap = await db.collection("users").doc(assignee).get();
  if (assigneeSnap.data()?.role !== "admin") {
    return { kind: "refused", reason: "assignee_not_admin" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  return db.runTransaction(async (tx): Promise<AssignSupportCaseVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    if (snap.data()!.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, { assignedTo: assignee, updatedAt: at, version: FieldValue.increment(1) });
    return { kind: "assigned" };
  }).then(async (v) => {
    if (v.kind === "assigned") await writeEvent(db, caseId, "assigned", adminUid, Timestamp.fromMillis(nowMs), { assignee });
    return v;
  });
}

// ── change status ──

export type ChangeSupportCaseStatusVerdict =
  | { kind: "changed" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "already_resolved" };

export async function changeSupportCaseStatusCore(
  db: Db,
  adminUid: string,
  caseId: string,
  status: unknown,
  waitingReason: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<ChangeSupportCaseStatusVerdict> {
  if (!(SUPPORT_CASE_STATUSES as readonly string[]).includes(status as string) || status === "resolved") {
    // "resolved" has its own command (resolveSupportCase), which requires
    // a resolution summary -- this command never sets it directly.
    return { kind: "refused", reason: "bad_request" };
  }
  const reason = typeof waitingReason === "string" ? waitingReason.trim() : "";
  if (status === "waiting" && (reason.length < 3 || reason.length > MAX_TEXT)) {
    return { kind: "refused", reason: "bad_request" };
  }
  if (typeof expectedVersion !== "number") return { kind: "refused", reason: "bad_request" };
  const caseRef = db.collection("support_cases").doc(caseId);
  const result = await db.runTransaction(async (tx): Promise<ChangeSupportCaseStatusVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const current = snap.data()!;
    if (current.status === "resolved") return { kind: "refused", reason: "already_resolved" };
    if (current.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, {
      status,
      waitingReason: status === "waiting" ? reason : null,
      updatedAt: at,
      version: FieldValue.increment(1),
    });
    return { kind: "changed" };
  });
  if (result.kind === "changed") {
    await writeEvent(db, caseId, "status_changed", adminUid, Timestamp.fromMillis(nowMs), { status, waitingReason: status === "waiting" ? reason : null });
  }
  return result;
}

// ── add note ──

export type AddSupportCaseNoteVerdict =
  | { kind: "added"; noteId: string }
  | { kind: "refused"; reason: "not_found" | "bad_request" };

export async function addSupportCaseNoteCore(
  db: Db,
  adminUid: string,
  caseId: string,
  text: unknown,
  nowMs: number
): Promise<AddSupportCaseNoteVerdict> {
  const body = typeof text === "string" ? text.trim() : "";
  if (!body || body.length > MAX_TEXT) return { kind: "refused", reason: "bad_request" };
  const caseRef = db.collection("support_cases").doc(caseId);
  const caseSnap = await caseRef.get();
  if (!caseSnap.exists) return { kind: "refused", reason: "not_found" };
  const at = Timestamp.fromMillis(nowMs);
  const noteRef = db.collection("support_case_notes").doc();
  await noteRef.set({ noteId: noteRef.id, caseId, authorUid: adminUid, text: body, createdAt: at });
  await caseRef.update({ updatedAt: at });
  await writeEvent(db, caseId, "note_added", adminUid, at, { noteId: noteRef.id });
  return { kind: "added", noteId: noteRef.id };
}

// ── resolve ──

export type ResolveSupportCaseVerdict =
  | { kind: "resolved" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "already_resolved" };

export async function resolveSupportCaseCore(
  db: Db,
  adminUid: string,
  caseId: string,
  resolutionSummary: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<ResolveSupportCaseVerdict> {
  const summary = typeof resolutionSummary === "string" ? resolutionSummary.trim() : "";
  if (summary.length < 3 || summary.length > MAX_TEXT || typeof expectedVersion !== "number") {
    return { kind: "refused", reason: "bad_request" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  const result = await db.runTransaction(async (tx): Promise<ResolveSupportCaseVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const current = snap.data()!;
    if (current.status === "resolved") return { kind: "refused", reason: "already_resolved" };
    if (current.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, {
      status: "resolved",
      resolutionSummary: summary,
      resolvedAt: at,
      resolvedBy: adminUid,
      updatedAt: at,
      version: FieldValue.increment(1),
    });
    return { kind: "resolved" };
  });
  if (result.kind === "resolved") {
    await writeEvent(db, caseId, "resolved", adminUid, Timestamp.fromMillis(nowMs), { resolutionSummary: summary });
  }
  return result;
}

// ── reopen ──

export type ReopenSupportCaseVerdict =
  | { kind: "reopened" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "not_resolved" };

export async function reopenSupportCaseCore(
  db: Db,
  adminUid: string,
  caseId: string,
  reason: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<ReopenSupportCaseVerdict> {
  const text = typeof reason === "string" ? reason.trim() : "";
  if (text.length < 3 || text.length > MAX_TEXT || typeof expectedVersion !== "number") {
    return { kind: "refused", reason: "bad_request" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  const result = await db.runTransaction(async (tx): Promise<ReopenSupportCaseVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const current = snap.data()!;
    if (current.status !== "resolved") return { kind: "refused", reason: "not_resolved" };
    if (current.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, {
      status: "open",
      reopenedAt: at,
      reopenedBy: adminUid,
      reopenReason: text,
      updatedAt: at,
      version: FieldValue.increment(1),
    });
    return { kind: "reopened" };
  });
  if (result.kind === "reopened") {
    await writeEvent(db, caseId, "reopened", adminUid, Timestamp.fromMillis(nowMs), { reason: text });
  }
  return result;
}

// ── callables ──

function refuse(reason: string): never {
  const table: Record<string, [string, string]> = {
    bad_request: ["invalid-argument", "The request could not be read"],
    actor_not_found: ["invalid-argument", "That customer, seller, rider or associate was not found"],
    assignee_not_admin: ["invalid-argument", "That user is not an admin"],
    not_found: ["not-found", "Case not found"],
    version_mismatch: ["failed-precondition", "This case changed since you last viewed it. Refresh and try again."],
    already_resolved: ["failed-precondition", "This case is already resolved"],
    not_resolved: ["failed-precondition", "Only a resolved case can be reopened"],
  };
  const [code, message] = table[reason] ?? ["internal", "Could not complete that"];
  throw new HttpsError(code as never, message, { reason });
}

export const createSupportCase = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const v = await createSupportCaseCore(admin.firestore(), adminUid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, caseId: v.caseId };
});

export const assignSupportCase = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await assignSupportCaseCore(admin.firestore(), adminUid, caseId, d.assigneeUid, d.expectedVersion, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true };
});

export const changeSupportCaseStatus = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await changeSupportCaseStatusCore(
    admin.firestore(), adminUid, caseId, d.status, d.waitingReason, d.expectedVersion, Date.now()
  );
  if (v.kind === "refused") refuse(v.reason);
  return { success: true };
});

export const addSupportCaseNote = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await addSupportCaseNoteCore(admin.firestore(), adminUid, caseId, d.text, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, noteId: v.noteId };
});

export const resolveSupportCase = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await resolveSupportCaseCore(admin.firestore(), adminUid, caseId, d.resolutionSummary, d.expectedVersion, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true };
});

export const reopenSupportCase = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await reopenSupportCaseCore(admin.firestore(), adminUid, caseId, d.reason, d.expectedVersion, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true };
});
