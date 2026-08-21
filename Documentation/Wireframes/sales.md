# SmartPOS — Wireframe: Sales (POS Interface)

**Screen:** New Sale  
**Route:** `/cashier/sales/new`  
**Role:** Cashier

---

## Purpose

The Sales (POS) page is the **core cashier workflow**. It is designed for
**maximum speed and minimum clicks** — the primary goal of the UI philosophy.
The cashier can search products, add to cart, apply discounts, process
payment, and print/email receipts — all in a focused, keyboard-friendly
interface.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Cashier | [Back]                      │
  │                                                                     │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  New Sale                                             [Receipt] ││
  │  │                                                               ││
  │  │ ┌──────┐ ┌────────────────────────────────────────────┐      ││
  │  │ │[🔍]   | Search products (min 2 chars) ...            │      ││
  │  │ │      | [Enter for first match]                      │      ││
  │  │ └──────┘ └────────────────────────────────────────────┘      ││
  │  │                                                               ││
  │  │ ┌────────────────────────────────────────────────────────────┐││
  │  │ │ Results:                                                   │││
  │  │ │ PRD-001 | Laptop Pro    | $1,299 | Stock: 15      [ADD]  │││
  │  │ │ PRD-002 | Wireless Mouse| $49.99 | Stock: 5       [ADD]  │││
  │  │ │ PRD-003 | USB-C Cable   | $19.99 | Stock: 0 ✗     [ADD]  │││
  │  │ └────────────────────────────────────────────────────────────┘││
  │  │                                                              ││
  │  │ ┌────────────────────────────────────────────────────────────┐││
  │  │ │ CART                                                       │││
  │  │ │ ┌────────────────────────────────────────────────────────┐│││
  │  │ │ │ Product       | Qty  | Price   | Total  | [✕]          │││
  │  │ │ │ ────────────────────────────────────────────────────── ││││
  │  │ │ │ Laptop Pro    | [ 2 ]| $1,299  | $2,598 | [✕]          │││
  │  │ │ │ Wireless Mo.. | [ 1 ]| $49.99  | $49.99 | [✕]          │││
  │  │ │ └────────────────────────────────────────────────────────┘│││
  │  │ │                                                          │││
  │  │ │ Subtotal:     $2,647.99                                  │││
  │  │ │ Discount:     [-$50.00]  [Apply Coupon]                   │││
  │  │ │ Tax:          $132.40 (5%)                                │││
  │  │ │ Total:        $2,728.39                                   │││
  │  │ │                                                          │││
  │  │ │ Payment: [Cash] [Card] [Credit]                          │││
  │  │ │ Tendered: [$2,800.00]                                     │││
  │  │ │ Change:   $71.61                                        │││
  │  │ │                                                          │││
  │  │ │ [Complete Sale]  (Ctrl+Enter)                            │││
  │  │ │ [Cancel Sale]                                            │││
  │  │ └────────────────────────────────────────────────────────────┘││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Product Search | Input | Auto-focus; debounced (250ms) |
| Results List | List | Matching products with ADD buttons |
| Cart Table | Table | Items, quantities, prices, totals |
| Subtotal/Discount/Tax/Total | Component | Calculated totals |
| Payment Selector | Toggle/Buttons | Cash / Card / Credit |
| Tendered Input | Input | Amount customer pays |
| Change Display | Component | Auto-calculated |
| Complete Sale Button | Primary Button | Large, prominent |
| Cancel Button | Secondary Button | Clears cart |
| Receipt Modal | Modal | Generated after sale completion |

---

## Actions

| Action | Trigger | Keyboard Shortcut | Validation | Result |
|--------|---------|--------------------|------------|--------|
| Search | Type in search | — | Min 2 chars | Filters results |
| Add to cart | Click [ADD] | Enter (in search) adds first match | Stock check | Adds item to cart |
| Change quantity | Edit qty in cart | — | Qty ≤ stock | Updates total |
| Remove item | Click [✕] | — | — | Removes from cart |
| Apply discount | Click "Apply Coupon" | — | Valid amount/code | Reduces subtotal |
| Select payment | Click Cash/Card/Credit | — | Required | Sets payment method |
| Enter tendered | Type amount | — | ≥ total (non-credit) | Calculates change |
| Complete sale | Click button | Ctrl+Enter | All validations | Creates sale; prints receipt |
| Cancel sale | Click button | — | Confirmation | Clears cart |
| Toggle password visibility | Click eye icon on search | — | — | Shows/hides |

---

## Validation Rules

| Rule | Enforcement |
|------|-------------|
| Product stock ≥ requested quantity | Real-time in cart |
| Tendered ≥ total (non-credit) | On Complete Sale click |
| At least one item in cart | Complete Sale button disabled |
| Payment method selected | Complete Sale button disabled |
| Discount ≤ subtotal | On apply |

---

## Business Rules Enforced

- BR-SALE-01: Inventory decreases after sales.
- BR-SALE-02: Every sale creates transaction records.
- BR-SALE-03: Stock sufficiency checked before completion.
- BR-SALE-04: Receipt numbers are sequential.
- BR-CR-02: Credit sales still decrement inventory.
- BR-04: Every inventory movement is logged.

---

## Navigation

- Click "Back" → previous page or dashboard.
- After sale completion → "Print Receipt" modal or auto-print.
- After cancellation → dashboard or confirmation modal.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Split: search/results (60%), cart (40%) |
| Tablet (md) | Search on top (60%), cart below (full width) |
| Mobile (sm) | Tabbed: "Search" and "Cart" tabs; cart slides up as full-width panel |

---

## Keyboard Shortcuts (Cashier Optimization)

| Key | Action |
|-----|--------|
| `/` or `Ctrl+K` | Focus product search |
| `Enter` (in search) | Add first result to cart |
| `Ctrl+Enter` | Complete sale |
| `Escape` | Clear search / cancel selection |
| `Backspace` (empty search) | Remove last item from cart |
| `Tab` | Navigate between fields |
| `+` / `-` (in qty cell) | Increase/decrease quantity |

---

## Accessibility

- Search input autofocused with `aria-label="Search products"`.
- Cart table has `<caption>Current sale items</caption>`.
- Payment buttons have `aria-pressed` state.
- Complete Sale button is large and has `aria-label="Complete sale, total $2,728.39"`.
- Change amount has `aria-live="polite"` for dynamic updates.
- Keyboard shortcuts documented with `aria-keyshortcuts`.
