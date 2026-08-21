# SmartPOS — Wireframe: Inventory

**Screen:** Inventory  
**Route:** `/admin/inventory`  
**Role:** Administrator

---

## Purpose

The Inventory page provides a real-time view of all product stock levels with
color-coded status indicators. It enables quick identification of low-stock and
out-of-stock items and provides a direct path to restock.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header                                                   │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Inventory                         [Export] [View Movements]  ││
  │  │                                                               ││
  │  │  Search: [________________]  Filter: [Category ▼]              ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Status | SKU     | Name          | Stock | Threshold     │││
  │  │  │ ────────────────────────────────────────────────────────── │││
  │  │  │ ✓ IN   | PRD-001 | Laptop Pro    | 15    | 10            │││
  │  │  │ ⚠ LOW  | PRD-004 | Keyboard      | 8     | 10            │││
  │  │  │ ✗ OUT  | PRD-003 | USB-C Cable   | 0     | 10            │││
  │  │  │ ✓ IN   | PRD-002 | Wireless Mo.. | 5     | 5              │││
  │  │  │ ⚠ LOW  | PRD-005 | Webcam        | 3     | 10            │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  [Restock] shown on hover or per-row                    ││
  │  │                                                               ││
  │  │  Legend:    ✓ In Stock  ⚠ Low Stock  ✗ Out of Stock          ││
  │  │                                                               ││
  │  │  [Refresh]   Total: 56 products | In Stock: 32 | Low: 12 | Out: 12││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Stock Movement History (Separate Page or Tab)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Stock Movement History  [Export]                                   │
  │  Filter: [Product] [Type] [Date Range]                              │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │ Date/Time     | Product     | Type    | Qty | User   | Ref     ││
  │  │ ─────────────────────────────────────────────────────────────── ││
  │  │ Aug 7 10:30   | Laptop Pro  | sale    | -2  | John   | SALE-321││
  │  │ Aug 7 11:00   | Keyboard    | restock | +50 | Admin  | REC-001 ││
  │  │ Aug 6 09:15   | Mouse       | return  | +1  | John   | RTN-022 ││
  │  │ Aug 5 14:20   | USB Cable   | adj     | -3  | Admin  | Damaged ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Restock Modal

```
┌─────────────────────────────────────────┐
│ Restock: Wireless Mouse          [X]   │
├─────────────────────────────────────────┤
│ Current Stock: 5                        │
│ Threshold: 10                           │
│                                         │
│ Quantity to Add *  [________]           │
│ Reference #      [PO-2026-001]          │
│ Notes            [________________]     │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   [Cancel]        [Restock]       │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Inventory Table | Table | Color-coded status, sortable columns |
| Status Badge | Badge | Green/Yellow/Red based on stock vs threshold |
| Restock Button | Button | Per-row or mass (for low-stock only) |
| View Movements Button | Link/Button | Navigates to movement history |
| Search / Filter | Input + Select | Filter by product name, category |
| Legend | Component | Status color legend |
| Summary Bar | Component | Counts of each status |
| Restock Modal | Modal | Form for restock entry |
| Movement Table | Table | History of all stock changes |
| Refresh Button | Button | Manual refresh |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Restock | Click "Restock" on row | Quantity > 0 | Increments stock; logs movement |
| View Movements | Click button | — | Navigates to history table |
| Search products | Type in search | — | Filters inventory |
| Filter | Select category | — | Filters inventory |
| Sort table | Click column header | — | Sorts table |
| Export | Click Export | — | Downloads file |
| Refresh | Click button | — | Re-fetches data |

---

## Validation Rules

| Field | Rule (Restock) |
|-------|----------------|
| Quantity | Integer > 0; required |
| Reference # | Optional; max 50 chars |
| Notes | Optional; max 500 chars |

---

## Business Rules Enforced

- BR-INV-02: Inventory increases after restocking.
- BR-INV-04: Every movement is logged.
- BR-INV-06: Low stock triggers notification.
- BR-INV-05: Stock cannot go negative (enforced at DB level).

---

## Navigation

- "View Movements" → `/admin/inventory/movements` (or tab).
- Click product name → `/admin/products/{id}`.
- Restock opens modal (no navigation).

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Full table; restock column visible |
| Tablet (md) | Columns compact; restock via dropdown |
| Mobile (sm) | Horizontal-scrollable; status badges prominent |

---

## Accessibility

- Status badges have `aria-label="In Stock"`, `"Low Stock"`, `"Out of Stock"`.
- Restock button: `aria-label="Restock product PRD-002"`.
- Table has `<caption>`.
- Color is not the sole indicator — text badges also used.
- Modal: `aria-modal`, focus trap, Escape to close.
