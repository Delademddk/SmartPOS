# SmartPOS — Wireframe: Returns

**Screen:** New Return & Returns List  
**Routes:** `/cashier/returns/new` (New Return), `/admin/returns` (List)  
**Role:** Cashier, Administrator

---

## Purpose

The Returns pages allow users to process returns against previously completed
sales. Returns restore inventory and generate refunds. Cashiers can process
returns for their own sales; Admins can process returns for any sale and view
all return records.

---

## Wireframe: New Return (Cashier)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Cashier  [Back]                      │
  │                                                                     │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  New Return                                                     ││
  │  │                                                               ││
  │  │  Search by Receipt #: [________________] [🔍]                  ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Matching Sales:                                            │││
  │  │  │ ┌────────────────────────────────────────────────────────┐│││
  │  │  │ │ Receipt  | Date     | Customer  | Total | Status        ││││
  │  │  │ │ ────────────────────────────────────────────────────── ││││
  │  │  │ │ SALE-521| Aug 6   | —         | $89.99| Completed [Sel] ││││
  │  │  │ │ SALE-522| Aug 7   | Walker Co | $42.50| Completed [Sel] ││││
  │  │  │ └────────────────────────────────────────────────────────┘│││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Items in SALE-522:                                          │││
  │  │  │ ┌────────────────────────────────────────────────────────┐│││
  │  │  │ │ [✓] Wireless Mouse  | Sold: 2 | Returned: 0 | Return: [1▼]││││
  │  │  │ │ [ ] USB-C Cable     | Sold: 1 | Returned: 1 | Return: [0] ││││
  │  │  │ └────────────────────────────────────────────────────────┘│││
  │  │  │                                                           │││
  │  │  │ Reason: [Defective / Wrong Item / Other ▼]               │││
  │  │  │ Notes:   [_______________________________________]       │││
  │  │  │ Refund Method: [Cash] [Card] [Store Credit]               │││
  │  │  │                                                           │││
  │  │  │ Refund Amount: $49.99                                     │││
  │  │  │ [Process Return (Enter / Ctrl+Return)]                   │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Wireframe: Returns List (Admin)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Admin                                │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Returns                                       [Export CSV]   ││
  │  │                                                               ││
  │  │  Filters: [Date From] [Date To] [Cashier] [Product]            ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Return ID | Receipt  | Date   | Cashier | Items | Refund   │││
  │  │  │ ────────────────────────────────────────────────────────── │││
  │  │  │ RTN-001  | SALE-522 | Aug 6  | John    | 1     | $49.99  │││
  │  │  │ RTN-002  | SALE-519 | Aug 5  | Jane    | 2     | $120.00 │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  [1] [2] [3] ... [Next]  | Showing 1-20 of 22                 ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Receipt Search | Input + Button | Search for original sale by receipt number |
| Matching Sales | Table/List | Selectable list of matching sales |
| Return Items List | List | Items with checkboxes and quantity selectors |
| Return Quantity Selector | Input/Select | Max = sold - already returned |
| Reason Dropdown | Select | Predefined reasons + "Other" |
| Notes Field | Textarea | Optional explanation |
| Refund Method | Toggle | Cash, Card, or Store Credit |
| Refund Amount | Display | Calculated total |
| Process Return Button | Primary Button | Triggers API call |
| Returns Table | Table | Admin view of all returns |
| Filters | Form | Date, cashier, product filters |
| Export | Button | CSV/PDF export |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Search receipt | Type + click search | Min 3 chars | Lists matching sales |
| Select sale | Click row / select checkbox | Must not be voided | Loads items |
| Select items | Check/uncheck checkboxes | — | Marks for return |
| Set return qty | Edit quantity | ≤ available-to-return | Validates |
| Choose reason | Select from dropdown | Required | Sets reason |
| Choose refund method | Click toggle | Required | Sets method |
| Process Return | Click button | All validations | Creates return; restores stock; logs movement; prints receipt |
| Export | Click Export | — | Downloads file |
| Filter list | Apply filters | — | Filters table |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Receipt search | Min 3 characters |
| Return quantity | Must be ≤ (sold quantity - already returned) |
| Reason | Required |
| Refund method | Required |
| Items selected | At least one item must be selected |

---

## Business Rules Enforced

- BR-RET-01: Return must reference a valid, non-voided sale.
- BR-RET-02: Return quantity cannot exceed available-to-return quantity.
- BR-RET-03: Returns restore inventory.
- BR-RET-04: Returns create a new record (original sale not modified).
- BR-RET-05: Refund amount = returned items' `price × quantity`.
- BR-INV-04: Stock movement logged for each return.

---

## Navigation

- "Back" → previous page.
- Return detail (Admin) → click Return ID to view details.
- Process Return → confirmation screen with receipt option.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Two-panel: search + items on left, cart/totals on right |
| Tablet (md) | Items table stacked; refund section below |
| Mobile (sm) | Single-column; items as accordion rows; refund fixed at bottom |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Enter` (in receipt search) | Search |
| `Ctrl+Return` | Process return |
| `Escape` | Clear selection / close modal |

---

## Accessibility

- Search input has `aria-label="Search by receipt number"`.
- Items table has `<caption>Items in sale SALE-522</caption>`.
- Quantity inputs have `aria-label="Return quantity for Wireless Mouse"`.
- Process Return button: `aria-label="Process return, refund $49.99"`.
- Refund amount: `aria-live="polite"` for dynamic updates.
