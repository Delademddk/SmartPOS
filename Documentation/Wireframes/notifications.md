# SmartPOS — Wireframe: Notifications

**Screen:** Notifications  
**Route:** `/notifications` (accessible via header bell icon)  
**Role:** All users

---

## Purpose

The Notifications page displays all in-app notifications for the current
user. Notifications include low-stock alerts, sale events, return events, and
system messages. Users can filter by read/unread, mark individual or all
notifications as read, and click through to related detail pages.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | [🔔3] Cashier                          │
  │                                                                     │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Notifications                              [Mark All Read]   ││
  │  │  Filter: [All ▼]  [Unread Only]                                ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ ⚠  Low Stock Alert                              [Just now] │││
  │  │  │    "Wireless Mouse (PRD-002) is at 5 units,              │││
  │  │  │     below threshold of 10. Restock soon!"                │││
  │  │  │    [Mark Read] [View Inventory]                           │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ 💰  New Sale: $89.99                            [2h ago] │││
  │  │  │    "Sale #SALE-521 completed by John Doe."                 │││
  │  │  │    [Mark Read] [View Sale]                                │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ 🔄  Return Processed                            [4h ago] │││
  │  │  │    "Return #RTN-022 for $49.99 processed."                │││
  │  │  │    [Mark Read]                                            │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ ✓  You marked all notifications as read             [Yesterday] │││
  │  │  │    (older notifications below)                          │││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  [Load More...]                                               ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Notification Detail (Dropdown from Header Bell)

```
┌─────────────────────────────────────────────┐
│ 🔔 Notifications (3 unread)               │
├─────────────────────────────────────────────┤
│ ⚠ Low Stock: Wireless Mouse    • Just now │
│ 💰 New Sale: $89.99            • 2h ago    │
│ 🔄 Return Processed            • 4h ago    │
├─────────────────────────────────────────────┤
│         [View All →]                        │
└─────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Filter Dropdown | Select | All / Unread Only / Read Only |
| Mark All Read Button | Button | Marks all as read |
| Notification Card | Component | Title, message, timestamp, actions |
| Status Icon | Icon | Visual indicator (warning, info, success) |
| Timestamp | Component | Relative time ("Just now", "2h ago") |
| Mark Read Button | Button | Per notification |
| View Link | Link | Navigate to related detail page |
| Load More Button | Button | Paginated loading |
| Empty State | Component | "No notifications found" with icon |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| View all | Click "View All" from dropdown | — | Navigates to full Notifications page |
| Mark as read | Click "Mark Read" on card | — | Sets `is_read = true` |
| Mark all read | Click "Mark All Read" | — | Sets all to `is_read = true` |
| View related record | Click "View Inventory" / "View Sale" | — | Navigates to related page |
| Filter | Select from dropdown | — | Filters notification list |
| Load more | Click "Load More" | — | Loads next page |

---

## Validation

- None (read-only notifications except `is_read` state).

---

## Notification Types

| Type | Icon | Color | Trigger | Navigation Target |
|------|------|-------|---------|-------------------|
| Low Stock | ⚠️ | Warning (yellow) | BR-INV-06 | `/admin/inventory` |
| Sale Completed | 💰 | Info (blue) | Sale created | `/admin/sales/{id}` |
| Return Processed | 🔄 | Success (green) | Return created | `/admin/returns/{id}` |
| Credit Sale | 📝 | Info (blue) | Credit sale created | `/admin/credit-balances` |
| System | 🔧 | Info (gray) | Config change, maintenance | `/admin/settings` |

---

## Business Rules Enforced

- BR-NOT-01: Low-stock notifications created automatically.
- BR-NOT-02: Notifications are user-specific.
- BR-NOT-03: Duplicate notifications avoided (no repeat while still low).
- BR-INV-06: Low-stock triggers notification when `stock ≤ threshold`.

---

## Navigation

- Click "View Inventory" → `/admin/inventory`.
- Click "View Sale" → `/admin/sales/{id}`.
- Click notification card → navigates to related detail (if applicable).
- No sub-pages; all notifications on this page.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Two-column: notification cards full-width; action links inline |
| Tablet (md) | Cards full-width; compact timestamps |
| Mobile (sm) | Cards full-width; action buttons below message; icons prominent |

---

## Accessibility

- Each notification card has `aria-label` describing type and title.
- "Mark Read" button: `aria-label="Mark notification as read"`.
- "View" link: `aria-label="View sale SALE-521"`.
- Timestamps have `aria-label` with full date/time.
- Filter dropdown: `aria-label="Filter notifications"`.
- Empty state: `aria-live="polite"` for dynamic updates.
- Notification list container: `role="feed"` / `aria-relevant="additions"`.
