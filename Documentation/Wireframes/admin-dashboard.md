# SmartPOS — Wireframe: Admin Dashboard

**Screen:** Admin Dashboard  
**Route:** `/admin/dashboard`  
**Role:** Administrator

---

## Purpose

The Admin Dashboard provides a high-level overview of business health through
key performance indicators (KPIs), charts, and quick links. It auto-refreshes
every 60 seconds and allows drill-down into detailed reports.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar        Header: SmartPOS | Admin | [🔔2] [User ▼]           │
  │  ┌──────────────┐                                                    │
  │  │ Dashboard   │        ┌──────────────────────────────────────────┐│
  │  │ Products    │        │  Welcome back, Admin!                    ││
  │  │ Categories  │        │  Aug 7, 2026                              ││
  │  │ Suppliers   │        └──────────────────────────────────────────┘│
  │  │ Inventory   │        ┌──────┐  ┌────────┐  ┌──────────┐  ┌──────┐│
  │  │ Sales       │        │156   │  │$3,420  │  │ 3        │  │12    ││
  │  │ Returns     │        │Sales │  │Revenue │  │Low Stock│  │Users ││
  │  │ Credit Sales│        │Today │  │Today   │  │Items    │  │Act.  ││
  │  │ Users       │        └──────┘  └────────┘  └──────────┘  └──────┘│
  │  │ Reports     │                                                    │
  │  │ Notifications│        ┌──────────────────────┐ ┌───────────────┐ │
  │  │ Settings    │        │ Sales Trend (Chart) │ │ Top Products │ │
  │  │ Audit Logs  │        │ Last 7 days         │ │               │ │
  │  │────────────│        │ [Chart Area]        │ │ • Laptop Pro│ │
  │  │  Logout     │        └──────────────────────┘ │ • Mouse     │ │
  │  └────────────┘                                  │ • Keyboard   │ │
  │                                                  └───────────────┘ │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Sidebar | Layout | Collapsible navigation with role-aware menu |
| Header | Layout | App name, user info, notifications bell, user dropdown |
| Welcome Card | Component | Personalized greeting + date |
| KPI Cards (4) | Component | Sales Today, Revenue Today, Low Stock Count, Active Users |
| Sales Trend Chart | Component | Line/bar chart of daily sales (last 7 days) |
| Top Products | Component | Table or list of best-selling products |
| Refresh Indicator | Component | "Last updated: 10:32 AM" |

---

## Actions

| Action | Trigger | Navigation |
|--------|---------|------------|
| Click "Low Stock Items" | KPI card click | `/admin/inventory` |
| Click KPI "Revenue" | KPI card click | `/admin/reports` (Sales Summary) |
| Click chart data point | Point click | `/admin/reports?filter=date` |
| Click "Top Products" row | Row click | `/admin/products/{id}` |
| Click Notifications bell | Header icon | `/admin/notifications` (dropdown) |
| Click User menu | Header dropdown | Profile / Change Password / Logout |
| Auto-refresh | Every 60s | Re-fetches dashboard data |

---

## Validation

- None (read-only dashboard).

---

## Navigation

- **Primary:** Sidebar links to all admin sections.
- **Secondary:** KPI cards link to related pages.
- **Header:** Notifications bell, user dropdown.

---

## Responsive Behavior

| Screen Size | Layout Changes |
|-------------|----------------|
| Desktop (lg+) | 4-column KPI grid; two charts side-by-side |
| Tablet (md) | 2-column KPI grid; charts stacked vertically |
| Mobile (sm) | 1-column KPI (scrollable); single chart with tab selector |

---

## Accessibility

- KPI cards have `aria-label` describing value and label.
- Charts include alternative text summarizing the trend.
- Auto-refresh updates are announced via `aria-live="polite"`.
- Sidebar navigation is keyboard-navigable (`Tab` + `Enter`).
