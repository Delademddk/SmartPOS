# SmartPOS — Wireframe: Categories

**Screen:** Categories  
**Route:** `/admin/categories`  
**Role:** Administrator

---

## Purpose

The Categories page allows Administrators to manage the hierarchical category
structure used to organize products. Categories can have parent-child
relationships, forming a tree structure (e.g., "Electronics" → "Computers").

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header                                                   │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Categories                         [Create Category]          ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Name         | Parent        | Description  | Actions       │││
  │  │  │ ──────────────────────────────────────────────────────────── │││
  │  │  │ Electronics  | —             | Consumer elec| [✎][✕]      │││
  │  │  │   └─ Computers| Electronics   | Desktop & lap│ [✎][✕]      │││
  │  │  │   └─ Phones   | Electronics   | Mobile devices│[✎][✕]      │││
  │  │  │ Food         | —             | Groceries    | [✎][✕]      │││
  │  │  │ Supplies     | —             | Office items | [✎][✕]      │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  [Load More]                                                  ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Create Category Modal

```
┌─────────────────────────────────────────┐
│ Create Category              [X]        │
├─────────────────────────────────────────┤
│ Name *       [____________________]    │
│ Parent       [Select Parent ▼]          │
│ Description  [____________________]    │
│                                         │
│ Parent options:                         │
│  — (none)                             │
│  Electronics                           │
│  Food                                  │
│  Supplies                              │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   [Cancel]        [Save Category] │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Create Button | Primary Button | Opens create modal |
| Categories Tree Table | Table | Hierarchical display with indentation |
| Edit Button | Icon Button | Per-row, opens edit modal |
| Delete Button | Icon Button | Per-row, opens confirmation modal |
| Parent Selector | Select | Dropdown of existing categories (no circular refs) |
| Description Field | Textarea | Optional |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Create category | Click "Create Category" → fill form → Save | Name unique at parent level | Inserts new category |
| Edit category | Click pencil icon | Name uniqueness | Updates category |
| Delete category | Click trash icon → confirm | No child categories or products | Soft-delete |
| Select parent | Choose from dropdown | Prevents circular hierarchy | Sets parent_id |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Name | 1–100 chars; required; unique at the same parent level |
| Parent | Must not be self or descendant (prevents circular hierarchy) |
| Description | Optional; max 500 chars |

---

## Navigation

- All actions open modals (no page navigation).
- No sub-pages for individual categories.

---

## Responsive Behavior

| Screen Size | Layout Changes |
|-------------|----------------|
| Desktop (lg+) | Full tree table with all columns |
| Tablet (md) | Description column may be hidden; action buttons compact |
| Mobile (sm) | Table horizontal-scrollable; modal full-screen |

---

## Accessibility

- Table has `caption` describing content.
- Tree indentation uses `aria-level` for screen readers.
- Action buttons have `aria-label="Edit category Electronics"`.
- Modal has `aria-modal="true"`, focus trap, Escape to close.
