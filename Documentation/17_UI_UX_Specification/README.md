# SmartPOS — UI/UX Specification

**Document ID:** DOC-UIUX-017  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document is the complete **UI/UX specification** for SmartPOS. It
describes every planned screen/page in the application, including its purpose,
components, user actions, validation rules, navigation, responsive behavior,
and accessibility considerations.

> **Reference:** [Project Bible — UI Philosophy](../AI/SMARTPOS_PROJECT_BIBLE.md#ui-philosophy)
> — Modern, Clean, Professional, Fast, Minimal, Responsive, Accessible,
> Consistent spacing, Consistent typography, Reusable components, Simple
> navigation, Keyboard-friendly sales interface.

---

## 2. Design System

### 2.1 Color Palette

| Variable | Value | Usage |
|----------|-------|-------|
| `--color-primary` | `#2563EB` (blue-600) | Primary buttons, links, active states |
| `--color-primary-hover` | `#1D4ED8` (blue-700) | Hover states |
| `--color-success` | `#16A34A` (green-600) | Success messages, positive indicators |
| `--color-warning` | `#D97706` (amber-600) | Low stock, warnings |
| `--color-error` | `#DC2626` (red-600) | Errors, negative indicators |
| `--color-bg` | `#F9FAFB` (gray-50) | Page background |
| `--color-card` | `#FFFFFF` (white) | Card backgrounds |
| `--color-border` | `#E5E7EB` (gray-200) | Borders, dividers |
| `--color-text` | `#1F2937` (gray-800) | Primary text |
| `--color-text-muted` | `#6B7280` (gray-500) | Secondary text, placeholders |
| `--color-sidebar` | `#1F2937` (gray-800) | Sidebar background |
| `--color-sidebar-hover` | `#374151` (gray-700) | Sidebar item hover |

### 2.2 Typography

| Element | Font Size | Font Weight | Line Height |
|---------|-----------|-------------|-------------|
| Page title | 24px (1.5rem) | 600 | 1.25 |
| Section heading | 20px (1.25rem) | 600 | 1.3 |
| Card title | 18px (1.125rem) | 600 | 1.3 |
| Body text | 14px (0.875rem) | 400 | 1.5 |
| Label | 14px (0.875rem) | 500 | 1.4 |
| Caption | 12px (0.75rem) | 400 | 1.4 |
| Button text | 14px (0.875rem) | 500 | 1.4 |

### 2.3 Spacing

Consistent spacing using Tailwind's scale: `0.5rem` base unit. All margins and
padding use multiples of 4 (4, 8, 12, 16, 24, 32, ...).

### 2.4 Layout

- **Admin pages:** Two-column layout with fixed sidebar (250px) and main content
  area.
- **Auth pages:** Centered card on full-screen background.
- **Sales page (Cashier):** Split layout — product search/cart on left (60%),
  product list on right (40%) on desktop; stacked on mobile.

---

## 3. Accessibility Guidelines

| Guideline | Implementation |
|-----------|----------------|
| Keyboard navigation | All interactive elements reachable via Tab; Enter/Space activate buttons |
| Focus rings | `focus:ring-2 focus:ring-blue-500 focus:outline-none` |
| ARIA labels | All icons and non-text elements have `aria-label` or are decorative (`aria-hidden`) |
| Color contrast | Minimum 4.5:1 for text, 3:1 for large text |
| Semantic HTML | `<button>`, `<nav>`, `<header>`, `<main>`, `<section>` used appropriately |
| Form labels | Every input has a `<label>` or `aria-label` |
| Live regions | `aria-live="polite"` for dynamic content updates |

> **Standards:** WCAG 2.1 Level AA compliance required.

---

## 4. Login Page

| Field | Value |
|-------|-------|
| **Route** | `/login` |
| **Purpose** | Authenticate user and issue JWT tokens |
| **Allowed Roles** | All (public route) |

### Components

```
┌─────────────────────────────────────────┐
│              Logo                       │
│            SmartPOS                     │
│                                         │
│  [Username]  ________                   │
│             |        |                  │
│             |________|                  │
│                                         │
│  [Password]  ________                   │
│             |        |  [SHOW]          │
│             |________|                  │
│                                         │
│  [ ] Remember Me                        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │           LOGIN                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Error: Invalid username or password     │
│  (appears on failed login)               │
└─────────────────────────────────────────┘
```

### Actions

| Action | Behavior | Validation |
|--------|----------|------------|
| Submit form | POST `/auth/login` | Username ≥ 3 chars; password ≥ 8 chars; loading state during request |
| Toggle password visibility | Show/hide password | — |
| Remember Me | Extends refresh token TTL | — |
| Failed login (3+) | Triggers rate limit + CAPTCHA | System-enforced |

### Navigation

- On success → redirect to role-specific dashboard.
- No navigation links (login is entry point).

### Responsive Behavior

- Mobile: centered card with max-width 400px, padded.
- Desktop: same card centered vertically and horizontally.

### Accessibility

- Username/password inputs have `autofocus` and `autocomplete`.
- Password toggle button has `aria-label="Show password"`.
- Error message has `role="alert"`.
- Form is submitted via Enter key.

---

## 5. Admin Dashboard

| Field | Value |
|-------|-------|
| **Route** | `/admin/dashboard` |
| **Purpose** | Provide a high-level overview of business KPIs for the Administrator |
| **Allowed Roles** | Administrator only |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Sidebar | Header                                          │
│           ┌───────────────────────────────────────────────┐ │
│           │  Welcome back, Admin!                         │ │
│           │  Today's Date: Aug 7, 2026                    │ │
│           │                                               │ │
│           │  ┌───────────┐  ┌───────────┐  ┌───────────┐  │ │
│           │  │ Total     │  │ Revenue   │  │ Low Stock │  │ │
│           │  │ Sales     │  │ Today     │  │ Items     │  │ │
│           │  │ 156       │  │ $3,420    │  │ 3         │  │ │
│           │  └───────────┘  └───────────┘  └───────────┘  │ │
│           │                                               │ │
│           │  ┌───────────────────────┐  ┌───────────────┐ │ │
│           │  │ Sales Trend (Chart)   │  │ Top Products  │ │ │
│           │  │ [Last 7 days]         │  │               │ │ │
│           │  │ ┌─────────────────┐   │  │ • Product A   │ │ │
│           │  │ │      ███        │   │  │ • Product B   │ │ │
│           │  │ │    ██████       │   │  │ • Product C   │ │ │
│           │  │ │  █████████      │   │  │               │ │ │
│           │  │ └─────────────────┘   │  └───────────────┘ │ │
│           │  └───────────────────────┘                    │ │
│           └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Click a KPI card | Navigate to relevant detail (e.g., "Low Stock Items" → Inventory page) |
| Click chart data point | Filter report by selected date |
| Click "View All Sales" | Navigate to Admin Sales page |

### Navigation

- Sidebar links: Dashboard, Products, Categories, Suppliers, Inventory,
  Sales, Returns, Credit Sales, Users, Reports, Notifications, Settings,
  Audit Logs, Logout.

### Responsive Behavior

- Desktop: 4-column KPI grid, two charts side by side.
- Tablet (md): 2-column KPI grid, charts stacked.
- Mobile (sm): 1-column KPI, single chart at a time (selectable via tabs).

### Accessibility

- All KPI cards have `aria-label` with value and label.
- Chart has alternative text describing the trend.
- Auto-refresh updates announced via `aria-live`.

---

## 6. Cashier Dashboard

| Field | Value |
|-------|-------|
| **Route** | `/cashier/dashboard` |
| **Purpose** | Provide personal sales KPIs for the Cashier |
| **Allowed Roles** | Cashier only |

### Components

```
┌─────────────────────────────────────────────────────┐
│  ┌───────────┐  ┌───────────┐  ┌───────────┐      │
│  │ Sales     │  │ Revenue   │  │ Items     │      │
│  │ Today     │  │ Today     │  │ Sold      │      │
│  │ 42        │  │ $1,240    │  │ 56        │      │
│  └───────────┘  └───────────┘  └───────────┘      │
│                                                     │
│  My Recent Sales                                    │
│  ┌───────────────────────────────────────────────┐  │
│  │ Receipt | Time    | Items | Total | Method   │  │
│  │ #0001   | 10:30   | 5     | $85   | Card    │  │
│  │ #0002   | 11:15   | 2     | $42   | Cash    │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  [New Sale] (prominent primary button)              │
└─────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Click "New Sale" | Navigate to `/cashier/sales/new` |
| Click a recent sale row | Navigate to sale details |

### Responsive Behavior

- Mobile: KPI cards stack; sales table becomes horizontal-scrollable.
- Tablet: KPI cards in a row; sales list below.

### Accessibility

- "New Sale" button is the first focusable element.
- Sales table uses `<caption>` describing content.

---

## 7. Products Page

| Field | Value |
|-------|-------|
| **Route** | `/admin/products` |
| **Purpose** | Manage all products (CRUD) |
| **Allowed Roles** | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Header: "Products"  [Create Product] [Export CSV]          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Search: [__________________________] [Filter] [Sort]   ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │ SKU     | Name        | Price   | Stock | Category   ││
│  │ ─────────────────────────────────────────────────────── ││
│  │ PRD-001 | Laptop Pro  | $1,299  | 15    | Electronics ││
│  │ PRD-002 | Wireless M...| $49.99 | 0     | Electronics ││ ← Low Stock │
│  │         |             |        |       |             ││
│  └─────────────────────────────────────────────────────────┘│
│  [1] [2] [3] ... [Next]  (pagination)                       │
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Create Product | Opens modal with product form |
| Edit (per row) | Opens product in edit form |
| Delete (per row) | Soft-delete with confirmation |
| Search | Filters products by name/SKU |
| Adjust Stock | Opens stock adjustment modal |
| Sort | Click column header |
| Export | Downloads current page as CSV |

### Validation

- SKU: 1–50 chars, alphanumeric + `-_`, unique
- Name: 1–255 chars, required
- Price: ≥ 0, required
- Cost: ≥ 0
- Stock: ≥ 0
- Category/Supplier: must be valid IDs

### Navigation

- Clicking "Create Product" opens modal (no page navigation).
- Clicking a product name navigates to the edit page.

### Responsive Behavior

- Desktop: full table with all columns.
- Mobile: columns shrink to priority (SKU, name, price); action buttons
  compact.

### Accessibility

- Search input has `aria-label="Search products"`.
- Table has `<caption>`.
- Delete button has `aria-label="Delete product PRD-001"`.

---

## 8. Categories Page

| Field | Value |
|-------|-------|
| Route | `/admin/categories` |
| Purpose | Manage product categories (CRUD, hierarchical) |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────┐
│  [Create Category]                          │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ Name           | Parent    | Actions   ││
│  │ ─────────────────────────────────────── ││
│  │ Electronics    | —         | [✎][✕]    ││
│  │   └─ Computers  | Electronics | [✎][✕]  ││
│  │ Food           | —         | [✎][✕]    ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Create | Opens modal; supports optional parent for hierarchy |
| Edit | Inline edit or modal |
| Delete | Soft-delete with confirmation |

### Validation

- Name: 1–100 chars, unique at the same parent level.
- Parent: must not create circular reference (e.g., A → B → A).

### Responsive Behavior

- Mobile: indented tree view collapses to two levels.

---

## 9. Suppliers Page

| Field | Value |
|-------|-------|
| Route | `/admin/suppliers` |
| Purpose | Manage suppliers (CRUD) |
| Allowed Roles | Administrator |

### Components

```
┌────────────────────────────────────────────────────────┐
│  [Create Supplier]                                       │
│                                                        │
│  ┌────────────────────────────────────────────────────┐│
│  │ Name          | Contact    | Email     | Phone     ││
│  │ ────────────────────────────────────────────────── ││
│  │ Global Dist.  | John Smith | j@g.com  | 555-0101  ││
│  │ Local Market  | Jane Doe   | j@l.com  | 555-0202  ││
│  └────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────┘
```

### Validation

- Name: 1–255 chars, unique.
- Email: valid format (optional).
- Phone: optional, max 30 chars.

---

## 10. Inventory Page

| Field | Value |
|-------|-------|
| Route | `/admin/inventory` |
| Purpose | View real-time stock levels with status indicators |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  [Filter: Category] [Search] [Restock]                       │
│  ┌──────────────────────────────────────────────────────────┐│
│  │ SKU    | Name         | Stock  | Threshold | Status      ││
│  │ ──────────────────────────────────────────────────────── ││
│  │ PRD-001| Laptop Pro   | 15     | 10        | In Stock ✓ ││
│  │ PRD-002| Wireless Mouse| 5     | 10        | Low Stock ⚠││
│  │ PRD-003| USB Cable    | 0      | 10        | Out of Stock ✗││
│  └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Restock | Opens restock modal (product pre-selected) |
| Search | Filters by product name/SKU |
| Filter by category | Limits results |
| Click product | Navigate to product edit page |
| Color coding | Green = in stock, Yellow = low, Red = out of stock |

### Stock Status Logic

| Condition | Status | Color |
|-----------|--------|-------|
| `stock_quantity == 0` | Out of Stock | Red |
| `0 < stock_quantity ≤ threshold` | Low Stock | Yellow |
| `stock_quantity > threshold` | In Stock | Green |

---

## 11. Sales — New Sale (Cashier)

| Field | Value |
|-------|-------|
| Route | `/cashier/sales/new` |
| Purpose | Process a new sale quickly via keyboard/mouse |
| Allowed Roles | Cashier |

### Components (Split Layout)

```
┌─────────────────────────────────────────────────────────────┐
│ [← Back]     New Sale                                       │
│                                                             │
│ ┌──────────────────────────┐  ┌───────────────────────────┐ │
│ │ Product Search           │  │ Cart                      │ │
│ │ [Search by name/SKU/bar] │  │ ┌─────────────────────────┐ │ │
│ │ ┌──────────────────────┐ │  │ │ Product A  Qty: [2 ] x$ │ │ │
│ │ │ Search Results       │ │  │ │ Product B  Qty: [1 ] x$ │ │ │
│ │ │ PRD-001 Laptop Pro   │ │  │ │                         │ │ │
│ │ │   $1,299  Stock: 15  │ │  │ │ Subtotal:    $XXXX.XX   │ │ │
│ │ │ PRD-002 Wireless Mo..│ │  │ │ Tax:         $XX.XX     │ │ │
│ │ │   $49.99   Stock: 5  │ │  │ │ Discount:    -$XX.XX    │ │ │
│ │ └──────────────────────┘ │  │ │ Total:       $XXXX.XX   │ │ │
│ │                          │  │ └─────────────────────────┘ │ │
│ │ ┌──────────────────────┐ │  │ │ Payment: [Cash ] [Card]   │ │ │
│ │ │ Barcode Scan         │ │  │ │ Tendered: [$_______]      │ │ │
│ │ │ [__________]         │ │  │ │ Change:   $XX.XX          │ │ │
│ │ └──────────────────────┘ │  │ │ [Complete Sale]           │ │ │
│ └──────────────────────────┘  └───────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Search product | Debounced (250 ms) search; Enter to add first result to cart |
| Scan barcode | Input field auto-focuses; scans add to cart |
| Add to cart | Increases quantity if already in cart |
| Change quantity | Inline edit; validates against stock |
| Apply discount | Opens discount modal (percentage or fixed) |
| Complete sale | Validates stock, creates sale, prints receipt |
| Cancel sale | Clears cart with confirmation |

### Validation

- Each item's quantity must be ≤ available stock.
- Payment amount must cover total (unless credit sale).
- All fields required before completing.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `/` or `Ctrl+K` | Focus product search |
| `Enter` (in search) | Add first result to cart |
| `Ctrl+Enter` | Complete sale |
| `Escape` | Cancel current selection / close modal |
| `Backspace` (empty search) | Remove last item from cart |

### Responsive Behavior

- Desktop: split layout as shown.
- Tablet: cart collapses to a bottom panel; search takes top 60%.
- Mobile: tabs for "Search" and "Cart"; cart full-width panel slides up.

### Accessibility

- Search input autofocused, `aria-label="Search products"`.
- Cart table has `<caption>`.
- Complete Sale button is a large, high-contrast primary button.
- Error messages announced with `role="alert"`.

---

## 12. Returns — New Return

| Field | Value |
|-------|-------|
| Route | `/cashier/returns/new` (Cashier & Admin) |
| Purpose | Process a return against a prior sale |
| Allowed Roles | Cashier, Administrator |

### Components

```
┌─────────────────────────────────────────────────┐
│  New Return                                     │
│  ┌─────────────────────────────────────────────┐ │
│  │ Search by Receipt #: [__________________] │ │
│  └─────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────┐ │
│  │ Receipt #SALE-0001  | John Doe  | $85.99   │ │
│  │ ─────────────────────────────────────────── │ │
│  │ [✓] Laptop Pro    Qty: [1] x $1,299       │ │
│  │ [✓] Wireless Mouse Qty: [2] x $49.99       │ │
│  │                                             │ │
│  │ Reason: [______________________________]   │ │
│  │ Refund: [Cash] [Card]                      │ │
│  │ Refund Amount: $149.97                     │ │
│  │ [Process Return]                           │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Validation

- Receipt must exist and not be voided.
- Return quantity ≤ sold quantity minus already-returned.
- Reason required.
- Refund method must match original payment method (configurable rule).

---

## 13. Sales — List (Admin) & My Sales (Cashier)

### Admin Sales List (`/admin/sales`)

```
┌──────────────────────────────────────────────────────────────┐
│  All Sales                                                   │
│  Filters: [Date From] [Date To] [Cashier] [Payment Method]   │
│  ┌──────────────────────────────────────────────────────────┐│
│  │ Receipt  | Date       | Cashier   | Items | Total | Mtd ││
│  │ ───────────────────────────────────────────────────────── ││
│  │ SALE-001 | 10:30 AM   | John      | 5     | $85   | Card││
│  │ SALE-002 | 11:15 AM   | Jane      | 2     | $42   | Cash││
│  └──────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

### Cashier My Sales (`/cashier/sales`)

Same layout, but data filtered by the logged-in cashier's `user_id`. 

### Actions

| Action | Behavior |
|--------|----------|
| Filter | Date range, cashier, payment method |
| Sort | Click column header |
| Export | CSV or Excel |
| View details | Click receipt number → sale detail page |
| Void (Admin only) | Click "Void" button → confirmation modal |

---

## 14. Returns List (Admin)

| Route | `/admin/returns` |
|------|------------------|
| Purpose | View all returns with details |

### Components

Same table structure as Sales list, with columns: Return ID, Original Receipt,
Date, Cashier, Items, Refund Amount, Reason.

### Actions

- Filter by date, cashier, product.
- Export.
- View return detail.

---

## 15. Users Page

| Field | Value |
|-------|-------|
| Route | `/admin/users` |
| Purpose | Manage user accounts |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  [Create User]                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Username  | Full Name  | Email    | Role  | Status      ││
│  │ ─────────────────────────────────────────────────────── ││
│  │ admin     | Admin User | a@a.com  | Admin | Active ✓   ││
│  │ cashier1  | Jane Doe   | j@j.com  | Cashier | Active ✓ ││
│  │ ─────────────────────────────────────────────────────── ││
│  └─────────────────────────────────────────────────────────┘│
│  Actions per row: [✎] [Reset Password] [Deactivate]         │
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Create User | Opens modal (username, name, email, role) |
| Edit (Admin only) | Currently deactivated users can be reactivated |
| Reset Password | Generates new temp password, shown to admin |
| Deactivate | Soft-deactivate; cannot deactivate self |

### Validation

- Username: 3–50 chars, unique.
- Email: valid format, unique.
- Role: admin or cashier only.

---

## 16. Reports Page

| Field | Value |
|-------|-------|
| Route | `/admin/reports` |
| Purpose | Generate and export reports |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Reports                                                    │
│                                                             │
│  ┌──────────────────┐  ┌───────────────────────────────────┐ │
│  │ Report Type      │  │ [Sales Summary] [Inventory Health]│ │
│  │ [Dropdown ▼]     │  │ [Stock Movements] [User Activity] │ │
│  └──────────────────┘  └───────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Date Range: [From ______] [To ______]                   │ │
│  │ Additional Filters: [Category] [Product] [User]         │ │
│  │ [Generate Report]                                       │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Report Results                                          │ │
│  │ [Column 1] [Column 2] ... [Export ▼]                    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Report Types

| Report | Key Metrics |
|--------|-------------|
| Sales Summary | Total sales, revenue, items sold, by payment method |
| Inventory Health | All products with stock, threshold, status |
| Stock Movements | All movements with product, type, user, timestamp |
| User Activity | All actions by user, action type, resource |

### Export Options

- Excel (.xlsx)
- PDF
- CSV

---

## 17. Settings Page

| Field | Value |
|-------|-------|
| Route | `/admin/settings` |
| Purpose | Manage application-wide settings |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Settings                                                   │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Key                | Value          | Type | Description ││
│  │ ─────────────────────────────────────────────────────── ││
│  │ currency_symbol    | $              | str  | Currency to display ││
│  │ low_stock_threshold| 10             | int  | Default low-stock threshold ││
│  │ receipt_footer     | "Thank you for..." | str | Receipt footer text ││
│  │ date_format        | YYYY-MM-DD     | str  | Date display format ││
│  │ enable_notifications| true          | bool | Enable in-app notifications ││
│  │ timezone           | UTC            | str  | System timezone ││
│  └─────────────────────────────────────────────────────────┘│
│  Click a value to edit inline. [Save] button per row.       │
└─────────────────────────────────────────────────────────────┘
```

### Actions

| Action | Behavior |
|--------|----------|
| Edit value | Inline editable cell; validates type |
| Save | Persists to database; logs audit |
| Cancel | Reverts unsaved changes |

---

## 18. Notifications

| Field | Value |
|-------|-------|
| Route | `/notifications` (accessible from header bell icon) |
| Purpose | View in-app notifications |
| Allowed Roles | All users (view own notifications) |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Notifications                                              │
|  ┌─────────────────────────────────────────────────────────┐│
│  │ [✓] Low Stock Alert: Wireless Mouse (SKU: PRD-002)     ││
│  │   2 hours ago                                           ││
│  │                                                         ││
│  │ [ ] You have a new credit sale: Customer: John Doe      ││
│  │   $85.99 on 11:15 AM                                      ││
│  └─────────────────────────────────────────────────────────┘│
│  [Mark All Read]  [Load More]                               │
└─────────────────────────────────────────────────────────────┘
```

### Notification Types

| Type | Icon | Audience | Trigger |
|------|------|----------|---------|
| Low Stock | ⚠️ | Admin | Stock ≤ threshold |
| Sale Completed | 💰 | Admin | Sale created |
| Return Processed | 🔄 | Admin | Return processed |
| Credit Sale | 📝 | Admin | Credit sale created |
| System | 🔧 | Admin | Configuration change |

### Actions

| Action | Behavior |
|--------|----------|
| Click notification | Navigate to related detail page |
| Mark as read | Updates `is_read` flag |
| Mark all read | Bulk update |
| Delete (optional) | Soft-delete notification |

---

## 19. Audit Logs (Admin)

| Field | Value |
|-------|-------|
| Route | `/admin/audit-logs` |
| Purpose | View immutable audit trail |
| Allowed Roles | Administrator |

### Components

```
┌─────────────────────────────────────────────────────────────┐
│  Audit Log                                                  │
│  Filters: [Date] [User] [Action Type] [Resource Type]        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Timestamp | User   | Action      | Resource | Details  ││
│  │ ─────────────────────────────────────────────────────── ││
│  │ 10:30 AM  | John   | SALE_CREATED | sale    | {"items":5} ││
│  │ 11:15 AM  | Jane   | PRODUCT_UPDATED | product | {"field":"price"} ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 20. Shared Layout Components

### 20.1 Header

| Element | Purpose |
|---------|---------|
| Logo | Navigate to dashboard |
| Current user name | Display logged-in user |
| Notifications bell | Shows unread count; dropdown preview |
| User menu | Dropdown: Profile, Change Password, Logout |

### 20.2 Sidebar (Admin)

| Item | Route |
|------|-------|
| Dashboard | `/admin/dashboard` |
| Products | `/admin/products` |
| Categories | `/admin/categories` |
| Suppliers | `/admin/suppliers` |
| Inventory | `/admin/inventory` |
| Stock Movements | `/admin/inventory/movements` |
| Sales | `/admin/sales` |
| Returns | `/admin/returns` |
| Credit Sales | `/admin/credit-balances` |
| Users | `/admin/users` |
| Reports | `/admin/reports` |
| Notifications | `/admin/notifications` |
| Settings | `/admin/settings` |
| Audit Logs | `/admin/audit-logs` |
| Logout | (action) |

### 20.3 Sidebar (Cashier)

| Item | Route |
|------|-------|
| Dashboard | `/cashier/dashboard` |
| New Sale | `/cashier/sales/new` |
| My Sales | `/cashier/sales` |
| New Return | `/cashier/returns/new` |
| Notifications | `/notifications` |
| Settings | `/admin/settings` (read-only) |
| Logout | (action) |

---

## 21. Responsive Behavior Summary

| Page | Mobile | Tablet | Desktop |
|------|--------|--------|---------|
| Login | Centered card | Centered card | Centered card |
| Admin Dashboard | 1-col KPIs, 1 chart | 2-col KPIs, stacked | 4-col KPIs, 2 charts |
| Cashier Dashboard | KPI row, recent sales list | KPI row, recent sales | KPI row, recent sales + chart |
| Products | Table scroll-x | Full table | Full table |
| Sales (POS) | Tabbed search/cart | Split 50/50 | Split 60/40 |
| Users | Table scroll-x | Full table | Full table |
| Reports | Stacked filters/results | Side-by-side | Side-by-side |
| Settings | Table scroll-x | Full table | Full table |
| Audit Logs | Table scroll-x | Full table | Full table |

---

## 22. Accessibility Checklist (Per Page)

| Component | Requirement |
|-----------|-------------|
| All pages | `lang="en"` on `<html>` |
| Forms | Every input has `<label>` or `aria-label` |
| Tables | `<caption>` describing content; `<th>` for headers |
| Buttons | `aria-label` for icon-only buttons |
| Modals | `aria-modal="true"`, focus trap, Escape to close |
| Errors | `role="alert"` |
| Loading | `aria-busy="true"` on container |
| Navigation | Skip link at top of page |

---

## 23. Related Documents

- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)
- [06_Non_Functional_Requirements — §7 (Accessibility)](../06_Non_Functional_Requirements/README.md#7-accessibility)
- [12_System_Architecture](../12_System_Architecture/README.md)
- [05_Functional_Requirements](../05_Functional_Requirements/README.md)
- [Wireframes/README.md](../Wireframes/README.md)

---

## 24. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
