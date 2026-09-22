// ============================================================
//  Process Pending Employee Commissions
// ============================================================
//
// DRY-RUN BY DEFAULT. Requires an explicit --apply flag to write anything.
//
// Scans for delivered orders that have an attributed `employeeUid` but
// whose commission has not yet been processed (`commissionPaid !== true`).
//
// Calculates commission on net goods value (subtotal - discount) based on:
//   1. employees/{uid}.commissionRate (if configured)
//   2. settings/commission (employeeRetailRate for B2C, employeeDefaultRate for B2B)
//
// In --apply mode:
//   - Updates/creates wallets/{employeeUid}
//   - Appends a record to wallet_transactions
//   - Updates orders/{orderId} with commissionPaid: true, commissionAmount, commissionPaidAt
//
// Usage:
//   node scripts/phase_process_pending_commissions.js            (dry run)
//   node scripts/phase_process_pending_commissions.js --apply    (writes)

const fs = require("fs");
const path = require("path");

const APPLY = process.argv.includes("--apply");
const PROJECT_ID = "agrimore-66a4e";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function getAccessToken() {
  const configPath = path.join(process.env.HOME, ".config/configstore/firebase-tools.json");
  if (!fs.existsSync(configPath)) {
    throw new Error(`Firebase credentials not found at ${configPath}. Run 'firebase login' first.`);
  }
  const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const token = cfg.tokens?.access_token;
  if (!token) {
    throw new Error("No access token found in firebase config.");
  }
  return token;
}

function parseFirestoreFields(fields) {
  if (!fields) return {};
  const res = {};
  for (const [k, v] of Object.entries(fields)) {
    if (v.stringValue !== undefined) res[k] = v.stringValue;
    else if (v.integerValue !== undefined) res[k] = parseInt(v.integerValue, 10);
    else if (v.doubleValue !== undefined) res[k] = v.doubleValue;
    else if (v.booleanValue !== undefined) res[k] = v.booleanValue;
    else if (v.timestampValue !== undefined) res[k] = v.timestampValue;
    else if (v.nullValue !== undefined) res[k] = null;
    else if (v.mapValue !== undefined) res[k] = parseFirestoreFields(v.mapValue.fields);
    else if (v.arrayValue !== undefined) {
      res[k] = (v.arrayValue.values || []).map(val => {
        if (val.stringValue !== undefined) return val.stringValue;
        if (val.integerValue !== undefined) return parseInt(val.integerValue, 10);
        if (val.doubleValue !== undefined) return val.doubleValue;
        if (val.mapValue !== undefined) return parseFirestoreFields(val.mapValue.fields);
        return val;
      });
    }
  }
  return res;
}

async function main() {
  console.log(`=== Process Pending Employee Commissions — ${APPLY ? "APPLY MODE (will write)" : "DRY RUN (no writes)"} ===\n`);

  const token = getAccessToken();
  const headers = {
    "Authorization": `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  // 1. Query delivered orders
  const query = {
    structuredQuery: {
      from: [{ collectionId: "orders" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "orderStatus" },
          op: "EQUAL",
          value: { stringValue: "delivered" }
        }
      }
    }
  };

  const res = await fetch(`${FIRESTORE_BASE}:runQuery`, {
    method: "POST",
    headers,
    body: JSON.stringify(query)
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Firestore query failed (${res.status}): ${errText}`);
  }

  const queryResults = await res.json();
  const deliveredOrders = [];

  for (const row of queryResults) {
    if (!row.document) continue;
    const docId = row.document.name.split("/").pop();
    const data = parseFirestoreFields(row.document.fields);
    deliveredOrders.push({ id: docId, ...data });
  }

  console.log(`Scanned ${deliveredOrders.length} delivered orders.`);

  let pendingCount = 0;
  let skippedNoEmployee = 0;
  let skippedAlreadyPaid = 0;

  for (const order of deliveredOrders) {
    if (!order.employeeUid) {
      skippedNoEmployee++;
      continue;
    }

    if (order.commissionPaid === true) {
      skippedAlreadyPaid++;
      continue;
    }

    pendingCount++;
    console.log(`\n--------------------------------------------------`);
    console.log(`Found pending commission on Order #${order.orderNumber || order.id} (doc: ${order.id})`);
    console.log(`- Attributed Employee UID: ${order.employeeUid} (Code: ${order.employeeCode || "N/A"})`);
    console.log(`- Order Mode: ${order.orderMode || "B2C"}`);
    console.log(`- Subtotal: ₹${order.subtotal ?? 0}, Discount: ₹${order.discount ?? 0}, Total: ₹${order.total ?? 0}`);

    // Fetch employee data
    const empRes = await fetch(`${FIRESTORE_BASE}/employees/${order.employeeUid}`, { headers });
    let employeeData = null;
    if (empRes.ok) {
      const empJson = await empRes.json();
      employeeData = parseFirestoreFields(empJson.fields);
    }

    let commissionRate = employeeData?.commissionRate;
    let rateSource = "employee_override";

    if (typeof commissionRate !== "number" || commissionRate <= 0) {
      // Check settings/commission
      const setRes = await fetch(`${FIRESTORE_BASE}/settings/commission`, { headers });
      if (setRes.ok) {
        const setJson = await setRes.json();
        const settingsData = parseFirestoreFields(setJson.fields);
        const rateKey = order.orderMode === "B2B" ? "employeeDefaultRate" : "employeeRetailRate";
        commissionRate = settingsData[rateKey];
        rateSource = "configured_mode_rate";
      }
    }

    if (typeof commissionRate !== "number" || commissionRate <= 0) {
      console.warn(`⚠️ Could not resolve valid commission rate for employee ${order.employeeUid}. Skipping.`);
      continue;
    }

    const grossAmount = Math.max(0, (order.subtotal || 0) - (order.discount || 0));
    const commissionAmount = Math.round(grossAmount * (commissionRate / 100) * 100) / 100;

    console.log(`- Commission Rate: ${commissionRate}% (Source: ${rateSource})`);
    console.log(`- Net Eligible Subtotal: ₹${grossAmount}`);
    console.log(`- Commission Amount to Credit: ₹${commissionAmount}`);

    if (APPLY) {
      // 1. Fetch current wallet
      const walletUrl = `${FIRESTORE_BASE}/wallets/${order.employeeUid}`;
      const walletRes = await fetch(walletUrl, { headers });
      let currentBalance = 0;
      let currentLifetime = 0;
      let walletExists = false;

      if (walletRes.ok) {
        walletExists = true;
        const walletData = parseFirestoreFields((await walletRes.json()).fields);
        currentBalance = walletData.balance || 0;
        currentLifetime = walletData.lifetimeEarnings || 0;
      }

      const balanceAfter = currentBalance + commissionAmount;
      const lifetimeAfter = currentLifetime + commissionAmount;
      const nowIso = new Date().toISOString();

      // Write/Update wallet
      const walletPatchUrl = `${walletUrl}?updateMask.fieldPaths=balance&updateMask.fieldPaths=lifetimeEarnings&updateMask.fieldPaths=userId&updateMask.fieldPaths=isActive&updateMask.fieldPaths=updatedAt${!walletExists ? "&updateMask.fieldPaths=createdAt" : ""}`;
      const walletPayload = {
        fields: {
          userId: { stringValue: order.employeeUid },
          balance: { doubleValue: balanceAfter },
          lifetimeEarnings: { doubleValue: lifetimeAfter },
          isActive: { booleanValue: true },
          updatedAt: { timestampValue: nowIso }
        }
      };
      if (!walletExists) {
        walletPayload.fields.createdAt = { timestampValue: nowIso };
      }

      const patchWalletRes = await fetch(walletPatchUrl, {
        method: "PATCH",
        headers,
        body: JSON.stringify(walletPayload)
      });
      if (!patchWalletRes.ok) {
        console.error(`Failed to update wallet: ${await patchWalletRes.text()}`);
        continue;
      }

      // Create wallet transaction
      const txPayload = {
        fields: {
          walletId: { stringValue: order.employeeUid },
          userId: { stringValue: order.employeeUid },
          type: { stringValue: "credit" },
          source: { stringValue: "commission" },
          amount: { doubleValue: commissionAmount },
          coins: { integerValue: "0" },
          balanceAfter: { doubleValue: balanceAfter },
          coinsAfter: { integerValue: "0" },
          orderId: { stringValue: order.id },
          description: { stringValue: `Commission on ${order.orderMode || "B2C"} order ${order.orderNumber || order.id}` },
          referenceId: { stringValue: order.id },
          createdAt: { timestampValue: nowIso },
          metadata: {
            mapValue: {
              fields: {
                commissionRate: { doubleValue: commissionRate },
                grossAmount: { doubleValue: grossAmount },
                orderMode: { stringValue: order.orderMode || "B2C" },
                rateSource: { stringValue: rateSource }
              }
            }
          }
        }
      };

      const createTxRes = await fetch(`${FIRESTORE_BASE}/wallet_transactions`, {
        method: "POST",
        headers,
        body: JSON.stringify(txPayload)
      });
      if (!createTxRes.ok) {
        console.error(`Failed to create wallet transaction: ${await createTxRes.text()}`);
        continue;
      }

      // Update order document
      const orderPatchUrl = `${FIRESTORE_BASE}/orders/${order.id}?updateMask.fieldPaths=commissionPaid&updateMask.fieldPaths=commissionAmount&updateMask.fieldPaths=commissionPaidAt`;
      const orderPatchPayload = {
        fields: {
          commissionPaid: { booleanValue: true },
          commissionAmount: { doubleValue: commissionAmount },
          commissionPaidAt: { timestampValue: nowIso }
        }
      };

      const patchOrderRes = await fetch(orderPatchUrl, {
        method: "PATCH",
        headers,
        body: JSON.stringify(orderPatchPayload)
      });
      if (!patchOrderRes.ok) {
        console.error(`Failed to update order: ${await patchOrderRes.text()}`);
        continue;
      }

      console.log(`✅ Successfully credited ₹${commissionAmount} to employee ${order.employeeUid} and marked order commissionPaid: true!`);
    } else {
      console.log(`ℹ️ [DRY RUN] Would credit ₹${commissionAmount} to employee wallet and update order.`);
    }
  }

  console.log(`\n================ Summary ================`);
  console.log(`Total delivered orders: ${deliveredOrders.length}`);
  console.log(`Without attributed employee: ${skippedNoEmployee}`);
  console.log(`Already paid commission: ${skippedAlreadyPaid}`);
  console.log(`Pending commission orders identified: ${pendingCount}`);
  if (!APPLY && pendingCount > 0) {
    console.log(`\nTo execute the payout and update Firestore, run:\nnode scripts/phase_process_pending_commissions.js --apply\n`);
  }
}

main().catch(console.error);
