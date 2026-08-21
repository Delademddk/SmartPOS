# SmartPOS — Wireframes Overview

This directory contains low-fidelity wireframes for every planned screen in
the SmartPOS application. Each wireframe documents:

- **Purpose** — What the screen accomplishes
- **UI Components** — The elements present on the screen
- **Actions** — User interactions and their behavior
- **Navigation** — Where the user can go from this screen
- **Responsive Behavior** — How the layout adapts across screen sizes
- **Accessibility** — Key accessibility considerations

---

## Wireframe Index

| Screen | File | Route | Role |
|--------|------|-------|------|
| Login | login.md | /login | All |
| Admin Dashboard | admin-dashboard.md | /admin/dashboard | Admin |
| Cashier Dashboard | cashier-dashboard.md | /cashier/dashboard | Cashier |
| Products | products.md | /admin/products | Admin |
| Categories | categories.md | /admin/categories | Admin |
| Suppliers | suppliers.md | /admin/suppliers | Admin |
| Inventory | inventory.md | /admin/inventory | Admin |
| Sales (POS) | sales.md | /cashier/sales/new | Cashier |
| Returns | returns.md | /cashier/returns/new, /admin/returns | Cashier, Admin |
| Reports | reports.md | /admin/reports | Admin |
| Users | users.md | /admin/users | Admin |
| Settings | settings.md | /admin/settings | Admin |
| Notifications | notifications.md | /notifications | All |

---

## Design Principles

All wireframes follow the UI philosophy from the
[Project Bible](../02_Project_Overview/README.md):

1. **Modern** — Clean, contemporary aesthetics
2. **Professional** — Appropriate for enterprise use
3. **Fast** — Keyboard-friendly, minimal clicks
4. **Minimal** — No clutter; only essential elements
5. **Responsive** — Adapts to all screen sizes
6. **Accessible** — WCAG 2.1 AA compliant
7. **Consistent** — Same spacing, typography, and component behavior across screens
8. **Reusable components** — Shared UI primitives across all screens
9. **Simple navigation** — Clear, role-aware sidebar navigation

### Cashier Workflow Priority

> "The cashier workflow must prioritize speed and minimal clicks."

This is reflected in the **Sales (POS)** wireframe:
- Product search is always visible and autofocused.
- Cart is always visible.
- Payment and completion buttons are large and prominent.
- Keyboard shortcuts are documented for every action.

---

## Notation

Wireframes use ASCII art diagrams to communicate layout at a low fidelity.
This is intentional — the wireframes communicate:

- Component layout and hierarchy
- Relative sizing and positioning
- Interactive elements and actions
- Data flow and navigation

Wireframes do **not** specify:
- Exact colors (see [17_UI_UX_Specification](../17_UI_UX_Specification/README.md#2-design-system))
- Final typography (see [17_UI_UX_Specification](../17_UI_UX_Specification/README.md#22-typography))
- Exact spacing (see [17_UI_UX_Specification](../17_UI_UX_Specification/README.md#23-spacing))

For precise visual design specifications, see
[17_UI_UX_Specification/README.md](../17_UI_UX_Specification/README.md).

---

## Related Documents

- [17_UI_UX_Specification](../17_UI_UX_Specification/README.md)
- [16_Frontend_Architecture](../16_Frontend_Architecture/README.md)
- [12_System_Architecture](../12_System_Architecture/README.md)
- [08_User_Stories](../08_User_Stories/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](../../AI/SMARTPOS_PROJECT_BIBLE.md#ui-philosophy)
