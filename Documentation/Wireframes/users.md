# SmartPOS — Wireframe: Users

**Screen:** Users (List, Create, Deactivate, Reset Password)  
**Route:** `/admin/users`  
**Role:** Administrator

---

## Purpose

The Users page allows Administrators to manage all user accounts. Administrators
can create new users, deactivate accounts, and reset passwords. The page
also serves as a directory of all system users with their roles and status.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Admin                                │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Users                             [Create User] [Export CSV]  ││
  │  │                                                               ││
  │  │  Search: [________________]                                   ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Username  | Full Name    | Email      | Role   | Status    │││
  │  │  │ ────────────────────────────────────────────────────────── │││
  │  │  │ admin     | Admin User   | a@s.com    | Admin  | Active ✓ │││
  │  │  │ cashier1  | John Smith   | j@s.com    | Cashier| Active ✓ │││
  │  │  │ cashier2  | Jane Doe     | ja@s.com   | Cashier| Inactive ✗│││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  Actions per row:                                              ││
  │  │  [Reset Password] [Deactivate]  (Admin actions)                ││
  │  │                                                               ││
  │  │  [1] [2] ... [Next]  | Showing 1-20 of 22                     ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Create User Modal

```
┌──────────────────────────────────────────────┐
│ Create User                        [X]      │
├──────────────────────────────────────────────┤
│ Username *   [admin_new]                     │
│ Full Name *  [________________]              │
│ Email *      [admin_new@company.com]         │
│ Phone        [________________]              │
│ Role *       [Admin ▼]                       │
│                                              │
│ Note: A temporary password will be generated │
│ and must be changed on first login.         │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │   [Cancel]      [Create User]           │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## Reset Password Confirmation Modal

```
┌──────────────────────────────────────────────┐
│ Reset Password: admin_new            [X]    │
├──────────────────────────────────────────────┤
│ A new temporary password has been generated: │
│                                              │
│   TempPassword123!                           │
│                                              │
│ Please provide this to the user to log in.   │
│ They will be required to change it on first  │
│ login.                                       │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │   [Close]                               │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## Deactivate Confirmation Modal

```
┌──────────────────────────────────────────────┐
│ Confirm Deactivation              [X]        │
├──────────────────────────────────────────────┤
│ Are you sure you want to deactivate user      │
│ "cashier2" (Jane Doe)?                        │
│                                              │
│ This user will no longer be able to log in.  │
│ Their existing sessions will remain active    │
│ until token expiry.                           │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │   [Cancel]      [Deactivate User]       │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Create User Button | Primary Button | Opens create modal |
| Export Button | Secondary Button | Downloads CSV |
| Search Input | Input | Filter by username, name, email |
| Users Table | Table | Columns: Username, Full Name, Email, Role, Status, Actions |
| Status Badge | Badge | Green (Active) / Gray (Inactive) |
| Reset Password Button | Button | Per-row; generates temp password |
| Deactivate Button | Button | Per-row; opens confirmation |
| Modals | Modal | Create, Reset Password, Deactivate confirmations |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Create User | Fill form → Create | Username unique; email valid; role valid | User created; temp password shown |
| Reset Password | Click "Reset Password" | Cannot reset own password | New temp password shown |
| Deactivate | Click "Deactivate" → confirm | Cannot deactivate self | User marked inactive |
| Search | Type in search | — | Filters table |
| Sort | Click column header | — | Sorts table |
| Export | Click Export | — | Downloads file |
| Pagination | Click page number | — | Loads page |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Username | 3–50 chars, alphanumeric + underscore, unique |
| Full Name | 1–255 chars, required |
| Email | Valid email format, unique |
| Phone | Optional, max 30 chars |
| Role | Must be "admin" or "cashier" |
| Password complexity | ≥ 8 chars, upper, lower, digit, special |

---

## Business Rules Enforced

- BR-USR-01: Username must be unique.
- BR-USR-02: Cannot deactivate self.
- BR-USR-03: Password complexity enforced.
- BR-AUTH-01: Passwords always hashed.
- BR-CROSS-01: Soft deletes used.

---

## Navigation

- Create → modal (no page navigation).
- Reset Password → modal (no page navigation).
- Deactivate → model (no page navigation).

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Full table with all columns |
| Tablet (md) | Email column may hide; action buttons compact |
| Mobile (sm) | Horizontal-scrollable; action buttons in dropdown menu |

---

## Accessibility

- Table has `<caption>`.
- Status badges have `aria-label="Active"` / `"Inactive"`.
- Action buttons: `aria-label="Reset password for admin"`.
- Modal: `aria-modal="true"`, focus trap, Escape to close.
- Password display: `aria-live="polite"` for copy-to-clipboard confirmation.
