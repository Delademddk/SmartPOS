# SmartPOS — Wireframe: Cashier Dashboard

**Screen:** Cashier Dashboard  
**Route:** `/cashier/dashboard`  
**Role:** Cashier

---

## Purpose

The Cashier Dashboard provides a focused overview of the logged-in cashier's
personal performance. It shows personal KPIs for the current day and a list of
recent sales for quick reference. A prominent "New Sale" button provides one-
click access to the POS screen.

---

## Wireframe

```
  ┌──────────────────────────────────────────────┐
  │  Sidebar  |  Header: SmartPOS | Cashier      │
  │  ┌──────┐ │                                │
  │  │ Dash.│ │  ┌───────────────────────────┐  │
  │  │ Sales│ │  │  Today's Sales Summary     │  │
  │  │ Ret. │ │  │                            │  │
  │  │ Not. │ │  │ ┌──────┐ ┌────────┐ ┌──────┐│  │
  │  │ Set. │ │  │ │ 42   │ │$1,240  │ │ 56   ││  │
  │  │─────│ │  │ │Sales │ │Revenue │ │Items ││  │
  │  │Logout│ │  │ └──────┘ └────────┘ └──────┘│  │
  │  └──────┘ │  └───────────────────────────┘  │
  │  ┌─────────────────────────────────────────┐│
  │  │  My Recent Sales                       ││
  │  │  ┌─────────────────────────────────────┐││
  │  │  │ Receipt  | Time | Items | Total     │││
  │  │  │ ─────────────────────────────────── │││
  │  │  │ #SALE-0321|10:30AM|5|$85.99         │││
  │  │  │ #SALE-0322|11:15AM|2|$42.50         │││
  │  │  │ #SALE-0323|11:45AM|3|$27.00         │││
  │  │  └─────────────────────────────────────┘││
  │  └─────────────────────────────────────────┘│
  │                                              │
  │              [  NEW SALE  ]                  │
  │            (large primary button)            │
  │                                              │
  └──────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Sidebar | Layout | Cashier-specific navigation (Sales, Returns, Notifications, Settings) |
| Header | Layout | App name, user info, notifications bell |
| KPI Cards (3) | Component | Sales Today, Revenue Today, Items Sold |
| Recent Sales Table | Component | Last 10 sales by this cashier |
| New Sale Button | Primary Button | Prominent, large, centered |
| Refresh Timestamp | Component | "Last updated: 10:32 AM" |

---

## Actions

| Action | Trigger | Navigation |
|--------|---------|------------|
| Click "New Sale" | Button click | `/cashier/sales/new` |
| Click recent sale row | Row click | `/cashier/sales/{id}` |
| Click Notifications bell | Header icon | `/notifications` |
| Click User menu | Header dropdown | Change Password / Logout |
| Auto-refresh | Every 60s | Re-fetches KPIs and recent sales |

---

## Validation

- None (read-only dashboard).

---

## Navigation

- **Primary:** Sidebar links to cashier-specific sections.
- **Primary CTA:** "New Sale" button.
- **Secondary:** Recent sale rows link to sale details.
- **Header:** Notifications bell, user dropdown.

---

## Responsive Behavior

| Screen Size | Layout Changes |
|-------------|----------------|
| Desktop (lg+) | 3-column KPI grid; full table; large CTA button |
| Tablet (md) | 3-column KPI grid; compact table |
| Mobile (sm) | KPI cards in a horizontal scrollable row; table becomes horizontal-scrollable; CTA button full-width |

---

## Accessibility

- "New Sale" button is the first focusable element (autofocus).
- Recent Sales table has `aria-label="Your recent sales"`.
- Table headers use `<th>` scope.
- Auto-refresh updates announced via `aria-live="polite"`.
- KPI cards have `aria-label` with value and description.
