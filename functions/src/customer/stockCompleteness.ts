// Read-only catalogue completeness primitives shared by the owner audit and
// its emulator test. This module never reads or writes Firestore itself.

export type StockIssue = "missing" | "null" | "nonnumeric" | "nonfinite" | "fractional" | "negative" | "unsafe_integer";

export function classifyStock(value: unknown): { valid: true; quantity: number } | { valid: false; issue: StockIssue } {
  if (value === undefined) return { valid: false, issue: "missing" };
  if (value === null) return { valid: false, issue: "null" };
  if (typeof value !== "number") return { valid: false, issue: "nonnumeric" };
  if (!Number.isFinite(value)) return { valid: false, issue: "nonfinite" };
  if (!Number.isInteger(value)) return { valid: false, issue: "fractional" };
  if (value < 0) return { valid: false, issue: "negative" };
  if (!Number.isSafeInteger(value)) return { valid: false, issue: "unsafe_integer" };
  return { valid: true, quantity: value };
}

export interface StockIssueRow {
  productId: string;
  skuPath: string;
  issue: StockIssue;
}

/** Summarizes raw, sellable base and variant stock without model defaults. */
export function inspectProductStock(productId: string, data: Record<string, unknown>): StockIssueRow[] {
  if (data.isActive === false || data.isDraft === true) return [];
  const rows: StockIssueRow[] = [];
  const base = classifyStock(data.stock);
  if (!base.valid) rows.push({ productId, skuPath: "stock", issue: base.issue });

  if (Array.isArray(data.variants)) {
    data.variants.forEach((rawVariant, index) => {
      const variant = typeof rawVariant === "object" && rawVariant !== null
        ? rawVariant as Record<string, unknown>
        : null;
      const result = classifyStock(variant?.stock);
      if (!result.valid) rows.push({ productId, skuPath: `variants[${index}].stock`, issue: result.issue });
    });
  }
  return rows;
}
