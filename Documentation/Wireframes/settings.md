# SmartPOS — Wireframe: Settings

**Screen:** Settings  
**Route:** `/admin/settings`  
**Role:** Administrator

---

## Purpose

The Settings page provides a centralized key-value configuration store for
the SmartPOS application. Administrators can view and update application-
wide settings such as currency symbol, low-stock thresholds, receipt
footers, and other configurable business options.

---

## Wireframe

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Sidebar | Header: SmartPOS | Admin                                │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │  Settings                                                     ││
  │  │                                                               ││
  │  │  ┌────────────────────────────────────────────────────────────┐││
  │  │  │ Key                    | Value             | Type  | Desc  │││
  │  │  │ ────────────────────────────────────────────────────────── │││
  │  │  │ currency_symbol        | $                 | str   | Currency display ││
  │  │  │ low_stock_threshold_d  | 10                | int   | Default threshold││
  │  │  │ receipt_footer         | "Thank you..."    | str   | Footer on receipts ││
  │  │  │ date_format            | YYYY-MM-DD        | str   | Date display    ││
  │  │  │ enable_notifications   | true              | bool  | Enable notif   ││
  │  │  │ timezone               | UTC               | str   | System timezone ││
  │  │  │ tax_rate               | 5.0               | num   | Default tax rate ││
  │  │  └────────────────────────────────────────────────────────────┘││
  │  │                                                               ││
  │  │  Click any value to edit inline.                              ││
  │  │  Changes are saved immediately (with undo option).            ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Inline Edit Modal (for complex types)

```
┌──────────────────────────────────────────────┐
│ Edit Setting: receipt_footer          [X]    │
├──────────────────────────────────────────────┤
│ Current Value: "Thank you for shopping!"     │
│ New Value:                                          │
│ [__________________________________________] │
│ (multi-line textarea for long strings)        │
│                                              │
│  ┌─────────────────────────────────────────┐ │
│  │   [Cancel]      [Save]                  │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## UI Components

| Component | Type | Description |
|-----------|------|-------------|
| Settings Table | Table | Key, Value (editable), Type, Description |
| Inline Editor | Component | Click value → becomes editable field |
| Boolean Toggle | Toggle | For boolean settings (true/false switch) |
| Save Button | Button | Per row or global |
| Undo Snackbar | Component | Appears after save with "Undo" option |
| Toast | Component | Success/error messages |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Edit value | Click value cell | Type validation | Becomes editable |
| Save | Click Save / Enter | Type matches declared type | Persists to DB; shows toast |
| Undo | Click "Undo" in snackbar | — | Reverts last change |
| Cancel edit | Click Cancel / Escape | — | Reverts without saving |
| Boolean toggle | Click toggle switch | — | Immediately saves |

---

## Settings Definition Table

| Key | Default Value | Type | Description |
|-----|---------------|------|-------------|
| `currency_symbol` | `$` | string | Currency symbol for all monetary displays |
| `low_stock_threshold_default` | `10` | integer | Default low-stock threshold for new products |
| `receipt_footer` | `Thank you for shopping with us!` | string | Footer text printed on receipts |
| `date_format` | `YYYY-MM-DD` | string | Display format for dates |
| `time_format` | `HH:mm` | string | Display format for times |
| `enable_notifications` | `true` | boolean | Enable or disable in-app notifications |
| `timezone` | `UTC` | string | System timezone |
| `tax_rate` | `5.0` | number | Default sales tax rate (percentage) |
| `enable_audit_logging` | `true` | boolean | Log all user actions |
| `session_timeout_minutes` | `60` | integer | Idle timeout before auto-logout |

---

## Validation Rules

| Rule | Enforcement |
|------|-------------|
| Type must match | `data_type` column compared against value |
| Key must exist | Only existing keys can be updated |
| Integer values | Must be parseable as integer |
| Boolean values | `true` / `false` only |
| Numeric values | Must be parseable as float |
| String values | Max 1000 chars |

---

## Business Rules Enforced

- BR-SET-01: Settings are key-value pairs with a declared type.
- All setting changes are logged in the audit trail.
- Changes are immediately effective (no restart required).

---

## Navigation

- No sub-pages; all settings are on this page.
- Settings table supports filtering by category or search by key.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Desktop (lg+) | Full table with all columns |
| Tablet (md) | Description column truncated; edits via modal |
| Mobile (sm) | Single-column card layout per setting |

---

## Accessibility

- Each editable value has `aria-label` with key name.
- Boolean toggles have `aria-checked` state.
- Save buttons: `aria-label="Save currency_symbol"`.
- Undo snackbar: `aria-live="polite"`.
- Table has `<caption>System Settings</caption>`.
