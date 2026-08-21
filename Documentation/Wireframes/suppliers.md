# SmartPOS — Wireframe: Suppliers

**Screen:** Suppliers  
**Route:** `/admin/suppliers`  
**Role:** Administrator

---

## Purpose

The Suppliers page allows Administrators to manage the supplier database — the
entities that provide products to the business. Admins can create, edit, and
soft-delete suppliers, and view associated details.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header                                                   │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Suppliers                        [Create Supplier] [Export]  ││
  │  │                                                               ││
  │  │  Search: [_________________________] [Sort ▼]                 ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Name            | Contact    | Email          | Phone      │││
  │  │  │ ──────────────────────────────────────────────────────────── │││
  │  │  │ Global Dist.    | John Smith | john@dist.com  | 555-0101   │││
  │  │  │ Local Market    | Jane Doe   | jane@l.com     | 555-0202   │││
  │  │  │ Tech Wholesale  | Bob Lee    | b@tech.com     | 555-0303   │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  Page [1] [2] [3] ... [Next]  | Showing 1-20 of 15            ││
  │  │  (note: 15 < 20, so single page)                             ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Create Supplier Modal

```
┌─────────────────────────────────────────┐
│ Create Supplier            [X]          │
├─────────────────────────────────────────┤
│ Name *       [____________________]    │
│ Contact Person [____________________]   │
│ Email        [____________________]    │
│ Phone        [____________________]    │
│ Address      [____________________]    │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   [Cancel]        [Save Supplier] │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Create Button | Primary Button | Opens create modal |
| Search Input | Input | Filter by name or contact |
| Suppliers Table | Table | Columns: Name, Contact, Email, Phone, Actions |
| Edit Button | Icon Button | Per-row |
| Delete Button | Icon Button | Per-row, soft-delete |
| Export Button | Secondary Button | Download CSV/Excel |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Create supplier | Fill form → Save | Name unique; email format valid | Inserts supplier |
| Edit supplier | Click pencil | Name unique | Updates supplier |
| Delete supplier | Click trash → confirm | No products reference supplier | Soft-delete |
| Search | Type in search | — | Filters table |
| Export | Click Export | — | Downloads file |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Name | 1–255 chars; required; unique |
| Contact Person | Optional; max 100 chars |
| Email | Optional; valid email format |
| Phone | Optional; max 30 chars |
| Address | Optional; max 500 chars |

---

## Navigation

- All actions open modals.
- Clicking a supplier name navigates to an edit page (alternative to modal).

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Full table with all columns |
| Tablet (md) | Email column may hide; actions compact |
| Mobile (sm) | Horizontal-scrollable table; modal full-screen |

---

## Accessibility

- Table has `<caption>`.
- Contact and Email fields have `aria-label`.
- Action buttons: `aria-label="Edit supplier Global Distributors"`.
- Modal: `aria-modal`, focus trap, Escape to close.
