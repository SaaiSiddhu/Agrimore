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
    target_not_found: ["invalid-argument", "That record could not be found"],
    link_not_found: ["failed-precondition", "That record is not linked to this case"],
    source_not_found: ["not-found", "That ticket, incident or exception could not be found"],
    source_actor_missing: ["invalid-argument", "That record has no rider it could be linked through"],
  };
  const [code, message] = table[reason] ?? ["internal", "Could not complete that"];
  throw new HttpsError(code as never, message, { reason });
}

// ── link / unlink an existing record (ADMR-65) ──
//
// linkedRecords did not exist on a case at all until this phase -- ADMR-61
// designed the shape but deliberately shipped without it to stay reviewable.
// Extends the SAME constrained-reference discipline every field on this
// file already uses: never an arbitrary client-supplied path, always
// validated against the record's own real collection first.

export const LINK_RECORD_TYPES = [
  "order",
  "rider_ticket",
  "rider_incident",
  "delivery_exception",
  "user",
  "seller",
  "rider",
  "associate",
] as const;
export type LinkRecordType = (typeof LINK_RECORD_TYPES)[number];
export type LinkedRecord = { type: LinkRecordType; id: string };

const LINK_COLLECTION: Record<LinkRecordType, string> = {
  order: "orders",
  rider_ticket: "rider_support_tickets",
  rider_incident: "rider_incidents",
  delivery_exception: "delivery_exceptions",
  user: "users",
  seller: "sellers",
  rider: "delivery_partners",
  associate: "employees",
};

function parseLinkedRecord(v: unknown): LinkedRecord | undefined {
  if (typeof v !== "object" || v === null) return undefined;
  const r = v as Record<string, unknown>;
  if (!(LINK_RECORD_TYPES as readonly string[]).includes(r.type as string)) return undefined;
  if (typeof r.id !== "string" || !r.id.trim()) return undefined;
  return { type: r.type as LinkRecordType, id: r.id.trim() };
}

function sameLinkedRecord(a: LinkedRecord, b: LinkedRecord): boolean {
  return a.type === b.type && a.id === b.id;
}

export type LinkSupportCaseRecordVerdict =
  | { kind: "linked" }
  | { kind: "already_linked" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "target_not_found" };

export async function linkSupportCaseRecordCore(
  db: Db,
  adminUid: string,
  caseId: string,
  linkInput: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<LinkSupportCaseRecordVerdict> {
  const link = parseLinkedRecord(linkInput);
  if (!link || typeof expectedVersion !== "number") {
    return { kind: "refused", reason: "bad_request" };
  }
  // Checked once, outside the transaction, since it never changes once
  // true -- mirrors createSupportCaseCore's own assertActorExists call.
  const targetSnap = await db.collection(LINK_COLLECTION[link.type]).doc(link.id).get();
  if (!targetSnap.exists) {
    return { kind: "refused", reason: "target_not_found" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  const result = await db.runTransaction(async (tx): Promise<LinkSupportCaseRecordVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const current = snap.data()!;
    if (current.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const existing: LinkedRecord[] = Array.isArray(current.linkedRecords) ? current.linkedRecords : [];
    // Idempotent: two admins linking the same record at once both succeed,
    // neither sees a spurious error for something that's already true.
    if (existing.some((e) => sameLinkedRecord(e, link))) {
      return { kind: "already_linked" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, { linkedRecords: [...existing, link], updatedAt: at, version: FieldValue.increment(1) });
    return { kind: "linked" };
  });
  if (result.kind === "linked") {
    await writeEvent(db, caseId, "link_added", adminUid, Timestamp.fromMillis(nowMs), { link });
  }
  return result;
}

export type UnlinkSupportCaseRecordVerdict =
  | { kind: "unlinked" }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "version_mismatch" | "link_not_found" };

export async function unlinkSupportCaseRecordCore(
  db: Db,
  adminUid: string,
  caseId: string,
  linkInput: unknown,
  expectedVersion: unknown,
  nowMs: number
): Promise<UnlinkSupportCaseRecordVerdict> {
  const link = parseLinkedRecord(linkInput);
  if (!link || typeof expectedVersion !== "number") {
    return { kind: "refused", reason: "bad_request" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  const result = await db.runTransaction(async (tx): Promise<UnlinkSupportCaseRecordVerdict> => {
    const snap = await tx.get(caseRef);
    if (!snap.exists) return { kind: "refused", reason: "not_found" };
    const current = snap.data()!;
    if (current.version !== expectedVersion) return { kind: "refused", reason: "version_mismatch" };
    const existing: LinkedRecord[] = Array.isArray(current.linkedRecords) ? current.linkedRecords : [];
    if (!existing.some((e) => sameLinkedRecord(e, link))) {
      // A genuine mistake worth surfacing -- never silently ignored.
      return { kind: "refused", reason: "link_not_found" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.update(caseRef, {
      linkedRecords: existing.filter((e) => !sameLinkedRecord(e, link)),
      updatedAt: at,
      version: FieldValue.increment(1),
    });
    return { kind: "unlinked" };
  });
  if (result.kind === "unlinked") {
    await writeEvent(db, caseId, "link_removed", adminUid, Timestamp.fromMillis(nowMs), { link });
  }
  return result;
}

// ── create from an existing operational record (ADMR-65) ──
//
// Restricted to the three real per-rider operational records -- the only
// ones with a real riderId to derive a primaryActor from (no customer/
// seller/associate equivalent exists anywhere in this codebase, per
// ADMR-61's own architecture-decision inventory). A DETERMINISTIC case
// document id keyed by the source, not a random one, is what actually
// makes this idempotent under concurrency -- mirroring
// riderSupport.ts's own `${riderId}_${requestId}` doc-id convention, the
// original reference this whole file was modeled on. A query-based dedup
// check (e.g. `linkedRecords array-contains {...}`) reads and writes
// different keys on each concurrent call, so two racing calls could both
// see "no existing case" and both create one; a shared deterministic key
// forces Firestore's own transaction contention detection to serialize
// them for real.

const SOURCE_TYPES = ["rider_ticket", "rider_incident", "delivery_exception"] as const;
type SourceType = (typeof SOURCE_TYPES)[number];
const SOURCE_COLLECTION: Record<SourceType, string> = {
  rider_ticket: "rider_support_tickets",
  rider_incident: "rider_incidents",
  delivery_exception: "delivery_exceptions",
};

function sourceCaseId(sourceType: SourceType, sourceId: string): string {
  return `src_${sourceType}_${sourceId}`;
}

export type CreateSupportCaseFromSourceVerdict =
  | { kind: "created"; caseId: string }
  | { kind: "existed"; caseId: string }
  | { kind: "refused"; reason: "bad_request" | "source_not_found" | "source_actor_missing" };

export async function createSupportCaseFromSourceCore(
  db: Db,
  adminUid: string,
  data: unknown,
  nowMs: number
): Promise<CreateSupportCaseFromSourceVerdict> {
  const d = (data ?? {}) as Record<string, unknown>;
  const sourceTypeRaw = typeof d.sourceType === "string" ? d.sourceType : "";
  const sourceId = typeof d.sourceId === "string" ? d.sourceId.trim() : "";
  const title = typeof d.title === "string" ? d.title.trim() : "";
  const category = typeof d.category === "string" ? d.category.trim() : "";
  if (
    !(SOURCE_TYPES as readonly string[]).includes(sourceTypeRaw) ||
    !sourceId || !title || title.length > MAX_TITLE || !category
  ) {
    return { kind: "refused", reason: "bad_request" };
  }
  const sourceType = sourceTypeRaw as SourceType;
  const link: LinkedRecord = { type: sourceType, id: sourceId };
  const caseRef = db.collection("support_cases").doc(sourceCaseId(sourceType, sourceId));

  const result = await db.runTransaction(async (tx): Promise<CreateSupportCaseFromSourceVerdict> => {
    const existingSnap = await tx.get(caseRef);
    if (existingSnap.exists) {
      return { kind: "existed", caseId: caseRef.id };
    }
    const sourceSnap = await tx.get(db.collection(SOURCE_COLLECTION[sourceType]).doc(sourceId));
    if (!sourceSnap.exists) {
      return { kind: "refused", reason: "source_not_found" };
    }
    const riderId = sourceSnap.data()?.riderId;
    if (typeof riderId !== "string" || !riderId.trim()) {
      return { kind: "refused", reason: "source_actor_missing" };
    }
    const primaryActor: ActorRef = { type: "rider", id: riderId.trim() };
    const actorSnap = await tx.get(db.collection(ACTOR_COLLECTION.rider).doc(primaryActor.id));
    if (!actorSnap.exists) {
      return { kind: "refused", reason: "source_actor_missing" };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.set(caseRef, {
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
      linkedRecords: [link],
      version: 1,
    });
    return { kind: "created", caseId: caseRef.id };
  });
  if (result.kind === "created") {
    await writeEvent(db, result.caseId, "created", adminUid, Timestamp.fromMillis(nowMs), {
      title,
      category,
      fromSource: link,
    });
  }
  return result;
}

// ── link/unlink/create-from-source callables ──

export const linkSupportCaseRecord = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await linkSupportCaseRecordCore(admin.firestore(), adminUid, caseId, d.link, d.expectedVersion, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, alreadyLinked: v.kind === "already_linked" };
});

export const unlinkSupportCaseRecord = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await unlinkSupportCaseRecordCore(admin.firestore(), adminUid, caseId, d.link, d.expectedVersion, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true };
});

export const createSupportCaseFromSource = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const v = await createSupportCaseFromSourceCore(admin.firestore(), adminUid, request.data, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, caseId: v.caseId, alreadyExisted: v.kind === "existed" };
});

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
