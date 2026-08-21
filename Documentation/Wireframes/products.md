# SmartPOS — Wireframe: Products

**Screen:** Products (List & CRUD)  
**Route:** `/admin/products`  
**Role:** Administrator

---

## Purpose

The Products page allows Administrators to view the complete product catalog,
search and filter products, and perform CRUD operations (create, edit, delete,
adjust stock). It serves as the central hub for all product management.

---

## Wireframe (List View)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header                                                   │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Products                           [Create Product] [Export] ││
  │  │                                                               ││
  │  │  Search: [_________________________] [Filter ▼] [Sort ▼]       ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ SKU     | Name            | Price   | Stock | Category    │││
  │  │  │ ──────────────────────────────────────────────────────────── │││
  │  │  │ PRD-001 | Laptop Pro      | $1,299  | 15    | Electronics │││
  │  │  │ PRD-002 | Wireless Mouse  | $49.99  | 5     | Accessories │││
  │  │  │ PRD-003 | USB-C Cable     | $19.99  | 0     | Accessories │││ ← Out of Stock │
  │  │  │ PRD-004 | Keyboard        | $79.99  | 8     | Accessories │││ ← Low Stock    │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  Page [1] [2] [3] ... [Next]  | Showing 1-20 of 86            ││
  │  └─────────────────────────────────────────────────────────────────┘│
  │                                                                     │
  │  Filter Panel (drawer, slides from right):                          │
  │  ┌─────────────────────────────────────────┐                        │
  │  │  Filter by Category: [All ▼]            │                        │
  │  │  Filter by Supplier: [All ▼]            │                        │
  │  │  Stock Status: [All ▼]                  │                        │
  │  │    ☐ In Stock                           │                        │
  │  │    ☐ Low Stock                          │                        │
  │  │    ☐ Out of Stock                       │                        │
  │  │  [Apply Filters] [Clear]                │                        │
  │  └─────────────────────────────────────────┘                        │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Create Product Button | Primary Button | Opens create/edit modal or navigates to form page |
| Export Button | Secondary Button | Downloads CSV/Excel |
| Search Input | Input | Debounced search by SKU/name |
| Filter Button | Button | Opens filter drawer |
| Sort Button | Button | Opens sort dropdown |
| Products Table | Table | Columns: SKU, Name, Price, Stock, Category, Actions |
| Stock Status Badge | Badge | Green (In Stock), Yellow (Low), Red (Out) |
| Action Buttons | Buttons per row | Edit (pencil), Stock Adjust (adjust), Delete (trash) |
| Pagination | Pagination | Page numbers, total count |
| Filter Drawer | Modal/Drawer | Category, supplier, stock status filters |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Search products | Type in search box | Min 2 chars | Filters table |
| Create product | Click "Create Product" | — | Opens form modal/page |
| Edit product | Click pencil icon | — | Opens form with data |
| Delete product | Click trash icon | Confirm modal | Soft-delete; 409 if referenced by sales |
| Adjust stock | Click adjust icon | — | Opens stock adjustment modal |
| Sort table | Click column header | — | Sorts by column |
| Filter | Click "Filter" → apply | — | Filters table |
| Export | Click "Export" | — | Downloads file |
| Pagination | Click page number | — | Loads page |

---

## Create/Edit Product Form (Modal)

```
┌─────────────────────────────────────────┐
│ Create Product              [X]        │
├─────────────────────────────────────────┤
│ SKU *         [____________________]   │
│ Name *        [____________________]   │
│ Description   [____________________]   │
│ Price *       [$______.____]          │
│ Cost          [$______.____]          │
│ Stock Qty     [________]              │
│ Low Stock Thresh [________]          │
│ Category *    [Select Category ▼]    │
│ Supplier *    [Select Supplier ▼]    │
│ ┌───────────────────────────────────┐ │
│ │   [Cancel]        [Save Product]  │ │
│ └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

Fields marked `*` are required.

---

## Validation Rules

| Field | Rule |
|-------|------|
| SKU | 1–50 chars; alphanumeric + `-_`; unique |
| Name | 1–255 chars; required |
| Price | Decimal ≥ 0; required |
| Cost | Decimal ≥ 0 |
| Stock Quantity | Integer ≥ 0; default 0 |
| Low Stock Threshold | Integer ≥ 0 |
| Category | Must be valid ID or null |
| Supplier | Must be valid ID or null |

---

## Navigation

- Create/Edit: Opens modal (no page navigation).
- Edit: Can also click product name to go to detail page.
- Delete: Confirmation modal; no navigation until action.
- Stock Adjust: Opens modal (no page navigation).

---

## Responsive Behavior

| Screen Size | Layout Changes |
|-------------|----------------|
| Desktop (lg+) | Full table with all columns; modal centered |
| Tablet (md) | Columns "Stock" and "Category" may collapse; modal full-width |
| Mobile (sm) | Table becomes horizontal-scrollable; modal full-screen |

---

## Accessibility

- Search input has `aria-label="Search products"`.
- Table has `aria-label="Product list"`.
- Stock status badges have `aria-label="In Stock"` / `"Low Stock"` / `"Out of Stock"`.
- Delete button has `aria-label="Delete product PRD-001"`.
- Modal has `aria-modal="true"`, focus trap enabled, Escape to close.
- Form fields have visible focus indicators.
