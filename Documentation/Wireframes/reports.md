# SmartPOS — Wireframe: Reports

**Screen:** Reports  
**Route:** `/admin/reports`  
**Role:** Administrator

---

## Purpose

The Reports page allows Administrators to generate, view, and export business
reports. Reports provide aggregated insights into sales, inventory, and user
activity. Each report supports filtering, sorting, and export to Excel/PDF.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Admin                                │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Reports                                                      ││
  │  │                                                               ││
  │  │  ┌───────────────────┐  ┌──────────────────────────────────────┐││
  │  │  │ Report Type       │  │ [Sales Summary ▼]                    │││
  │  │  └───────────────────┘  └──────────────────────────────────────┘││
  │  │  ┌───────────────────┐  ┌──────────────────────────────────────┐││
  │  │  │ Date Range        │  │ [2026-08-01] to [2026-08-07] [📅]   │││
  │  │  └───────────────────┘  └──────────────────────────────────────┘││
  │  │  ┌───────────────────┐  ┌──────────────────────────────────────┐││
  │  │  │ Additional Filters│  │ [Category ▼] [Cashier ▼] [Product ▼] │││
  │  │  └───────────────────┘  └──────────────────────────────────────┘││
  │  │                         [Generate Report] [Export ▼]           ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Report Results (Sales Summary)                            │││
  │  │  │ ┌────────────────────────────────────────────────────────┐│││
  │  │  │ │ Date       | Sales  | Revenue   | Items  | Avg Sale   ││││
  │  │  │ │ ────────────────────────────────────────────────────── ││││
  │  │  │ │ Aug 1      | 15     | $1,450    | 75     | $96.67     ││││
  │  │  │ │ Aug 2      | 22     | $2,310    | 98     | $105.00    ││││
  │  │  │ │ Aug 3      | 18     | $1,920    | 86     | $106.67    │││
  │  │  │ │ ...                                                  ││││
  │  │  │ └────────────────────────────────────────────────────────┘│││
  │  │  │                                                          │││
  │  │  │ Export Options: [Excel] [PDF] [CSV]                     │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Available Reports

| Report | Key Metrics |
|--------|-------------|
| Sales Summary | Date, sales count, revenue, items sold, average sale |
| Inventory Health | Product, SKU, current stock, threshold, status |
| Stock Movements | Date, product, type, quantity, user, reference |
| Sales Detail | Receipt, date, cashier, items, total, payment method |
| Returns Report | Return ID, receipt, date, cashier, items, refund amount |
| User Activity | Date, user, action, resource, IP |
| Credit Balances | Customer, total amount, outstanding balance |

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Report Type Selector | Select/Dropdown | Choose report type |
| Date Range Picker | Date Inputs | From / To dates |
| Additional Filters | Select x3 | Category, Cashier, Product |
| Generate Button | Primary Button | Runs the report |
| Export Dropdown | Dropdown | Excel, PDF, CSV |
| Results Table | Table | Paginated, sortable |
| Pagination | Pagination | Page navigation |
| Summary Row | Component | Totals row in table |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Select report type | Click dropdown | Must select valid type | Loads appropriate filters |
| Set date range | Select dates | From ≤ To | Filters data |
| Add filters | Select from dropdowns | Valid selection | Additional filtering |
| Generate report | Click button | Valid date range | Loads results table |
| Sort results | Click column header | — | Sorts table |
| Export | Click Export → format | Valid data | Downloads file |
| Pagination | Click page numbers | — | Loads page |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Report type | Must be selected; required |
| Date range | From date must be ≤ To date; required |
| Additional filters | Optional; must reference valid entities |

---

## Business Rules Enforced

- BR-REP-01: Reports reflect committed data only (no uncommitted transactions).
- BR-REP-02: All filters applied at the database level for performance.

---

## Navigation

- No sub-pages; all actions on this page.
- Filter selection updates available options dynamically.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Filters in a row; full table |
| Tablet (md) | Filters stacked; table full-width |
| Mobile (sm) | Filters collapse into accordion; table horizontal-scroll |

---

## Accessibility

- Report type selector: `aria-label="Select report type"`.
- Date inputs have `aria-label="From date"` / `"To date"`.
- Export dropdown: `aria-haspopup="menu"`, `aria-expanded`.
- Results table: `<caption>` describing report type and date range.
- Pagination: `aria-label="Page 1 of 5"`.
- Export format options have `aria-checked` for selected state.
