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
// ADMR-66 (reliability hardening): createSupportCase and addSupportCaseNote
// now require a client-generated requestId, bound into a deterministic
// document id -- mirroring the real, already-shipped
// functions/src/customer/requestEmployeePayout.ts:63's own
// `${actorUid}_${requestId}` convention exactly (ADMR-43). A retry with the
// SAME requestId and the SAME payload returns the original outcome
// (alreadyApplied: true), never a duplicate; the SAME requestId with a
// DIFFERENT payload is refused (request_id_conflict), never silently
// overwritten. Every command's required audit event now writes INSIDE its
// own transaction (writeEventTx) -- previously every event was written
// AFTER the transaction had already resolved, so a mutation could commit
// with no audit trail at all if the process died, or the event write
// itself failed, in the gap between the two calls. assign/changeStatus/
// resolve/reopen/link/unlink deliberately do NOT gain a new requestId:
// their existing expectedVersion contract already correctly handles a
// stale competing edit (first wins, second gets version_mismatch, proven
// since ADMR-61's own c07/c08), and link/unlink's own idempotent
// array-membership check already makes a same-link replay safe with no
// new mechanism needed.
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { resolveIsAdmin } from "./complianceGate";

type Db = FirebaseFirestore.Firestore;
type Tx = FirebaseFirestore.Transaction;

export const SUPPORT_CASE_ACTOR_TYPES = ["customer", "seller", "rider", "associate"] as const;
export type SupportCaseActorType = (typeof SUPPORT_CASE_ACTOR_TYPES)[number];

export const SUPPORT_CASE_STATUSES = ["open", "in_progress", "waiting", "resolved"] as const;
export type SupportCaseStatus = (typeof SUPPORT_CASE_STATUSES)[number];

export const MAX_TITLE = 200;
export const MAX_TEXT = 2000;
const REQUEST_ID = /^[A-Za-z0-9_-]{8,64}$/;

export type ActorRef = { type: SupportCaseActorType; id: string };

function sameActorRef(a: ActorRef | undefined, b: ActorRef): boolean {
  return !!a && a.type === b.type && a.id === b.id;
}

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

// ADMR-66: writes INSIDE the caller's own open transaction -- every command
// below now calls this before returning from its own runTransaction body, so
// a mutation and its required audit event commit atomically, or neither
// does.
function writeEventTx(
  tx: Tx,
  db: Db,
  caseId: string,
  type: string,
  actorUid: string,
  at: Timestamp,
  details: Record<string, unknown> = {}
): void {
  const ref = db.collection("support_case_events").doc();
  tx.set(ref, { caseId, type, actorUid, at, details });
}

// ── create ──

export type CreateSupportCaseVerdict =
  | { kind: "created"; caseId: string; alreadyApplied: boolean }
  | {
      kind: "refused";
      reason: "bad_request" | "actor_not_found" | "request_id_conflict" | "initial_link_target_not_found";
    };

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
  const requestId = typeof d.requestId === "string" ? d.requestId.trim() : "";
  // ADMR-67: an optional link recorded in the SAME write as creation --
  // e.g. Order 360's own "raise a case" records the order relationship
  // atomically, never a separate create-then-link step (the "create case,
  // then maybe link it later" partial-success trap).
  let initialLink: LinkedRecord | undefined;
  if (d.initialLink !== undefined && d.initialLink !== null) {
    initialLink = parseLinkedRecord(d.initialLink);
    if (!initialLink) return { kind: "refused", reason: "bad_request" };
  }
  if (!title || title.length > MAX_TITLE || !category || !primaryActor || !REQUEST_ID.test(requestId)) {
    return { kind: "refused", reason: "bad_request" };
  }
  // Both checked once, outside the transaction, since neither changes
  // once true -- mirrors linkSupportCaseRecordCore's own targetSnap check.
  if (!(await assertActorExists(db, primaryActor))) {
    return { kind: "refused", reason: "actor_not_found" };
  }
  if (initialLink) {
    const targetSnap = await db.collection(LINK_COLLECTION[initialLink.type]).doc(initialLink.id).get();
    if (!targetSnap.exists) return { kind: "refused", reason: "initial_link_target_not_found" };
  }
  const caseRef = db.collection("support_cases").doc(`req_${adminUid}_${requestId}`);
  return db.runTransaction(async (tx): Promise<CreateSupportCaseVerdict> => {
    const existing = await tx.get(caseRef);
    if (existing.exists) {
      const prior = existing.data()!;
      const priorLinks: LinkedRecord[] = Array.isArray(prior.linkedRecords) ? prior.linkedRecords : [];
      const samePayload =
        prior.title === title &&
        prior.category === category &&
        sameActorRef(prior.primaryActor as ActorRef | undefined, primaryActor) &&
        // A call that doesn't ask about a link is compatible with any prior
        // state; a call that DOES specify one requires it to already be
        // among the case's own links (allows other links added later by
        // separate calls without treating a legitimate replay as a conflict).
        (initialLink === undefined || priorLinks.some((l) => sameLinkedRecord(l, initialLink!)));
      if (!samePayload) {
        return { kind: "refused", reason: "request_id_conflict" };
      }
      // Idempotent replay -- the SAME request already succeeded. Return
      // its original result; never create a second case.
      return { kind: "created", caseId: caseRef.id, alreadyApplied: true };
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
      linkedRecords: initialLink ? [initialLink] : [],
      version: 1,
    });
    writeEventTx(tx, db, caseRef.id, "created", adminUid, at, {
      title,
      category,
      primaryActor,
      ...(initialLink ? { initialLink } : {}),
    });
    return { kind: "created", caseId: caseRef.id, alreadyApplied: false };
  });
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
    writeEventTx(tx, db, caseId, "assigned", adminUid, at, { assignee });
    return { kind: "assigned" };
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
  return db.runTransaction(async (tx): Promise<ChangeSupportCaseStatusVerdict> => {
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
    writeEventTx(tx, db, caseId, "status_changed", adminUid, at, {
      status,
      waitingReason: status === "waiting" ? reason : null,
    });
    return { kind: "changed" };
  });
}

// ── add note ──

export type AddSupportCaseNoteVerdict =
  | { kind: "added"; noteId: string; alreadyApplied: boolean }
  | { kind: "refused"; reason: "not_found" | "bad_request" | "request_id_conflict" };

export async function addSupportCaseNoteCore(
  db: Db,
  adminUid: string,
  caseId: string,
  text: unknown,
  requestIdInput: unknown,
  nowMs: number
): Promise<AddSupportCaseNoteVerdict> {
  const body = typeof text === "string" ? text.trim() : "";
  const requestId = typeof requestIdInput === "string" ? requestIdInput.trim() : "";
  if (!body || body.length > MAX_TEXT || !REQUEST_ID.test(requestId)) {
    return { kind: "refused", reason: "bad_request" };
  }
  const caseRef = db.collection("support_cases").doc(caseId);
  const noteRef = db.collection("support_case_notes").doc(`${caseId}_${requestId}`);
  return db.runTransaction(async (tx): Promise<AddSupportCaseNoteVerdict> => {
    const [caseSnap, existingNote] = await Promise.all([tx.get(caseRef), tx.get(noteRef)]);
    if (!caseSnap.exists) return { kind: "refused", reason: "not_found" };
    if (existingNote.exists) {
      const prior = existingNote.data()!;
      if (prior.text !== body) return { kind: "refused", reason: "request_id_conflict" };
      // Idempotent replay -- never a second note, never a second event.
      return { kind: "added", noteId: noteRef.id, alreadyApplied: true };
    }
    const at = Timestamp.fromMillis(nowMs);
    tx.set(noteRef, { noteId: noteRef.id, caseId, authorUid: adminUid, text: body, createdAt: at });
    // Deliberately does NOT bump `version` -- a note is additive
    // commentary, never gated by or gating the assign/status/resolve/
    // reopen optimistic-concurrency contract. Proven by a real test: a
    // concurrent note-add and status-change never conflict with each
    // other, each using the version they actually captured.
    tx.update(caseRef, { updatedAt: at });
    writeEventTx(tx, db, caseId, "note_added", adminUid, at, { noteId: noteRef.id });
    return { kind: "added", noteId: noteRef.id, alreadyApplied: false };
  });
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
  return db.runTransaction(async (tx): Promise<ResolveSupportCaseVerdict> => {
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
    writeEventTx(tx, db, caseId, "resolved", adminUid, at, { resolutionSummary: summary });
    return { kind: "resolved" };
  });
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
  return db.runTransaction(async (tx): Promise<ReopenSupportCaseVerdict> => {
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
    writeEventTx(tx, db, caseId, "reopened", adminUid, at, { reason: text });
    return { kind: "reopened" };
  });
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
    request_id_conflict: ["invalid-argument", "This request id was already used with different details — retry with a new one"],
    initial_link_target_not_found: ["invalid-argument", "That record could not be found"],
    no_file: ["failed-precondition", "Upload the file first, then try again"],
    not_allowed_type: ["invalid-argument", "Only images and PDF documents can be attached as evidence"],
    too_large: ["invalid-argument", "That file is too large (10MB max)"],
    content_mismatch: ["invalid-argument", "That file's real content doesn't match its claimed type"],
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
  return db.runTransaction(async (tx): Promise<LinkSupportCaseRecordVerdict> => {
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
    writeEventTx(tx, db, caseId, "link_added", adminUid, at, { link });
    return { kind: "linked" };
  });
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
  return db.runTransaction(async (tx): Promise<UnlinkSupportCaseRecordVerdict> => {
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
    writeEventTx(tx, db, caseId, "link_removed", adminUid, at, { link });
    return { kind: "unlinked" };
  });
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

  return db.runTransaction(async (tx): Promise<CreateSupportCaseFromSourceVerdict> => {
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
    writeEventTx(tx, db, caseRef.id, "created", adminUid, at, { title, category, fromSource: link });
    return { kind: "created", caseId: caseRef.id };
  });
}

// ── private evidence attachments (ADMR-71, hardened ADMR-72) ──
//
// Private Storage-based evidence (photos, documents) on a case. Mirrors
// riderExceptions.ts's own storageLookup exactly -- a fixed, deterministic
// path is checked against the REAL uploaded object via the Admin SDK
// (.exists() then .getMetadata()), never trusting a client-claimed size or
// contentType. Evidence is append-only (no edit, no delete command),
// mirroring notes' own established rationale: an investigation trail
// should not be alterable after the fact.
//
// ADMR-72 hardening. ADMR-71's own path/doc-id were keyed by caseId+requestId
// only, and storage.rules' `allow write:` (create+update+delete combined)
// let ANY admin overwrite or delete an ALREADY-FINALIZED object at that same
// path -- nothing bound the object's identity after the one metadata lookup
// at finalize time, and two different admins could collide on a coincidental
// requestId with no per-uploader isolation at all (unlike this file's own
// createSupportCaseCore, which already keys its deterministic id by
// req_${adminUid}_${requestId}). Fixed by:
//   1. The Storage path itself embeds the uploader's own uid
//      (support_case_evidence/{caseId}/{adminUid}_{requestId}), mirroring
//      product_images/{sellerId}_{fileName}'s own uid-prefix convention.
//   2. storage.rules (see that file) now allows CREATE only, gated by that
//      same uid prefix AND `resource == null` -- this codebase's own
//      write-once precedent (delivery_document_submissions, DLVDOC2) --
//      with update/delete both explicitly false. Once created, the object
//      can never be overwritten or removed by any client, closing the
//      overwrite-after-finalize gap at the infrastructure level, not just
//      by convention.
//   3. The Firestore evidence doc id also embeds adminUid
//      (${caseId}_${adminUid}_${requestId}), closing the cross-admin
//      collision.
//   4. The real object's `generation` and `md5Hash` (confirmed present and
//      changing-on-overwrite against the real Storage emulator) are
//      recorded as its verified content identity -- a GCS-native, zero-
//      extra-infra proof of exactly which bytes were checked. The
//      requestId-conflict check (comparing originalFileName) is a display-
//      label safeguard now, not a bytes-integrity one -- the write-once rule
//      already makes a bytes swap under the same path impossible via any
//      client path.
// Residual, disclosed risk (shared with every write-once path in this
// codebase, including DLVDOC2): a privileged Admin-SDK/console actor
// bypasses client rules entirely and could still overwrite the underlying
// object out of band. No client-side rule can ever prevent that; the
// recorded generation/md5Hash at least make such a tamper DETECTABLE by a
// future audit, not something this phase claims to prevent.

export const MAX_EVIDENCE_BYTES = 10 * 1024 * 1024;

// ADMR-72 (section 5): a Storage object's own `contentType` metadata is a
// label the UPLOADING CLIENT set at putData time -- it is not independently
// verified against the actual bytes. Restricted from a broad "any image/*"
// to the exact 3 formats the client ever offers, each checked against its
// real file-signature (magic bytes), so a client cannot claim "image/png"
// for an arbitrary (e.g. HTML/script) payload. This is a format check, NOT
// malware/content scanning -- no such scanning is claimed or implemented.
const EVIDENCE_SIGNATURES: Record<string, (b: Buffer) => boolean> = {
  "image/png": (b) =>
    b.length >= 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47 &&
    b[4] === 0x0d && b[5] === 0x0a && b[6] === 0x1a && b[7] === 0x0a,
  "image/jpeg": (b) => b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  "application/pdf": (b) => b.length >= 5 && b.subarray(0, 5).toString("latin1") === "%PDF-",
};

export type ObjectInfo = {
  size: number;
  contentType: string;
  generation: string;
  md5Hash: string;
  headerBytes: Buffer;
} | null;
export type ObjectLookup = (path: string) => Promise<ObjectInfo>;

export const storageLookup: ObjectLookup = async (path) => {
  const file = admin.storage().bucket().file(path);
  const [exists] = await file.exists();
  if (!exists) return null;
  const [meta] = await file.getMetadata();
  const size = Number(meta.size ?? 0);
  // Only as many header bytes as the longest signature above needs (8).
  // Reading a small fixed prefix, not the whole object, keeps this cheap
  // regardless of the file's real size.
  const headerBytes = size > 0
    ? (await file.download({ start: 0, end: Math.min(size, 8) - 1 }))[0]
    : Buffer.alloc(0);
  return {
    size,
    contentType: String(meta.contentType ?? ""),
    generation: String(meta.generation ?? ""),
    md5Hash: String(meta.md5Hash ?? ""),
    headerBytes,
  };
};

export function evidencePath(caseId: string, adminUid: string, requestId: string): string {
  return `support_case_evidence/${caseId}/${adminUid}_${requestId}`;
}

export type AttachSupportCaseEvidenceVerdict =
  | { kind: "attached"; evidenceId: string; alreadyApplied: boolean }
  | {
      kind: "refused";
      reason:
        | "bad_request" | "not_found" | "no_file" | "not_allowed_type" | "too_large"
        | "content_mismatch" | "request_id_conflict";
    };

export async function attachSupportCaseEvidenceCore(
  db: Db,
  adminUid: string,
  caseId: string,
  requestIdInput: unknown,
  originalFileNameInput: unknown,
  lookup: ObjectLookup,
  nowMs: number
): Promise<AttachSupportCaseEvidenceVerdict> {
  const requestId = typeof requestIdInput === "string" ? requestIdInput.trim() : "";
  const originalFileName =
    typeof originalFileNameInput === "string" ? originalFileNameInput.trim().slice(0, 200) : "";
  if (!caseId || !REQUEST_ID.test(requestId)) {
    return { kind: "refused", reason: "bad_request" };
  }
  const path = evidencePath(caseId, adminUid, requestId);
  const caseRef = db.collection("support_cases").doc(caseId);
  const evidenceRef = db.collection("support_case_evidence").doc(`${caseId}_${adminUid}_${requestId}`);

  // Checked once, outside the transaction -- mirrors linkSupportCaseRecordCore's
  // own precedent for an external existence check that cannot itself race
  // Firestore's transaction retry mechanics. Safe to do unconditionally here
  // (even the write-once object itself cannot change once this reads it),
  // and skipped entirely on a replay (the evidence doc already exists) so a
  // retry never re-reads Storage.
  const existingBefore = await evidenceRef.get();
  let info: ObjectInfo = null;
  if (!existingBefore.exists) {
    info = await lookup(path);
  }

  return db.runTransaction(async (tx): Promise<AttachSupportCaseEvidenceVerdict> => {
    const [caseSnap, existing] = await Promise.all([tx.get(caseRef), tx.get(evidenceRef)]);
    if (!caseSnap.exists) return { kind: "refused", reason: "not_found" };
    if (existing.exists) {
      const prior = existing.data()!;
      if (prior.originalFileName !== originalFileName) {
        return { kind: "refused", reason: "request_id_conflict" };
      }
      // Idempotent replay -- never a second evidence record, never a second event.
      return { kind: "attached", evidenceId: evidenceRef.id, alreadyApplied: true };
    }
    if (!info) return { kind: "refused", reason: "no_file" };
    const signatureCheck = EVIDENCE_SIGNATURES[info.contentType];
    if (!signatureCheck) return { kind: "refused", reason: "not_allowed_type" };
    if (info.size <= 0 || info.size > MAX_EVIDENCE_BYTES) return { kind: "refused", reason: "too_large" };
    if (!signatureCheck(info.headerBytes)) return { kind: "refused", reason: "content_mismatch" };
    const at = Timestamp.fromMillis(nowMs);
    tx.set(evidenceRef, {
      evidenceId: evidenceRef.id,
      caseId,
      storagePath: path,
      size: info.size,
      contentType: info.contentType,
      generation: info.generation,
      md5Hash: info.md5Hash,
      originalFileName,
      uploadedBy: adminUid,
      uploadedAt: at,
    });
    // Deliberately does NOT bump `version` -- same rationale as a note:
    // additive evidence never gates or is gated by the assign/status/
    // resolve/reopen optimistic-concurrency contract.
    tx.update(caseRef, { updatedAt: at });
    writeEventTx(tx, db, caseId, "evidence_attached", adminUid, at, {
      evidenceId: evidenceRef.id,
      contentType: info.contentType,
      size: info.size,
    });
    return { kind: "attached", evidenceId: evidenceRef.id, alreadyApplied: false };
  });
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
  return { success: true, caseId: v.caseId, alreadyApplied: v.alreadyApplied };
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
  const v = await addSupportCaseNoteCore(admin.firestore(), adminUid, caseId, d.text, d.requestId, Date.now());
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, noteId: v.noteId, alreadyApplied: v.alreadyApplied };
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

export const attachSupportCaseEvidence = onCall({ minInstances: 0, memory: "256MiB" }, async (request) => {
  const adminUid = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const caseId = typeof d.caseId === "string" ? d.caseId.trim() : "";
  if (!caseId) throw new HttpsError("invalid-argument", "caseId is required");
  const v = await attachSupportCaseEvidenceCore(
    admin.firestore(), adminUid, caseId, d.requestId, d.originalFileName, storageLookup, Date.now()
  );
  if (v.kind === "refused") refuse(v.reason);
  return { success: true, evidenceId: v.evidenceId, alreadyApplied: v.alreadyApplied };
});
