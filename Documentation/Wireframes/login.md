# SmartPOS — Wireframe: Login

**Screen:** Login  
**Route:** `/login`  
**Role:** All (public route)

---

## Purpose

The Login page is the entry point for all users. It authenticates a user
against the system and issues JWT tokens. After successful login, the user is
redirected to their role-specific dashboard.

---

## Wireframe

```
                    ┌─────────────────────────────────────┐
                    │              SmartPOS              │
                    │           [Company Logo]           │
                    │              Login                  │
                    └─────────────────────────────────────┘
                              ┌───────────────────────────┐
                              │        Username           │
                              │  ┌─────────────────────┐ │
                              │  │ admin               │ │
                              │  │                     │ │
                              │  └─────────────────────┘ │
                              └───────────────────────────┘
                              ┌───────────────────────────┐
                              │        Password           │
                              │  ┌─────────────────────┐ │
                              │  │ ***************** │ │
                              │  │  [SHOW]            ││ │
                              │  └─────────────────────┘ │
                              └───────────────────────────┘
                              ┌──────────────┐ ┌─────────────┐
                              │ [ ] Remember │ │ CAPTCHA     │
                              │   Me         │ │ [Image]     │
                              └──────────────┘ └─────────────┘
                              ┌───────────────────────────┐
                              │        LOGIN             │
                              │    [Primary Button]      │
                              │                           │
                              └───────────────────────────┘
                              ┌───────────────────────────┐
                              │ Invalid username or      │
                              │ password.                 │
                              │ (appears on error only)  │
                              └───────────────────────────┘
```

---

## UI Components

| Component | Type | Attributes |
|-----------|------|------------|
| Logo / App Name | Static | Centered at top |
| Username Input | Form Input | `type="text"`, `required`, autofocus, `autocomplete="username"` |
| Password Input | Form Input | `type="password"`, `required`, `autocomplete="current-password"` |
| Show Password Toggle | Icon Button | Toggles password visibility |
| Remember Me Checkbox | Checkbox | Extends refresh token TTL |
| CAPTCHA | Component | Appears after 3 failed attempts |
| Login Button | Primary Button | Disabled while submitting |
| Error Message | Alert | Red background, `role="alert"` |

---

## Actions

| Action | Trigger | Validation | Result |
|--------|---------|------------|--------|
| Submit form | Click Login / Enter key | Username ≥ 3 chars; password ≥ 8 chars | POST `/api/v1/auth/login` |
| Show/hide password | Click eye icon | — | Toggles password field type |
| Remember Me | Click checkbox | — | Sets `remember_me` flag |
| CAPTCHA verify | After 3 failures | Must pass | Enables login button |

---

## Validation Rules

- Username: 3–50 characters, alphanumeric + underscore.
- Password: ≥ 8 characters, must meet complexity (validated on backend).
- Rate limiting: 5 failed attempts per 15 minutes per IP.
- Account lockout after 5 consecutive failures.

---

## Navigation

- **On success:** Redirect to `/admin/dashboard` (Admin) or `/cashier/dashboard` (Cashier).
- **Forgot password:** (Future enhancement — not in Phase 1)
- **No other navigation links** — this is the entry point.

---

## Responsive Behavior

| Screen Size | Layout |
|-------------|--------|
| Mobile (sm < 640px) | Centered card, max-width 90vw, padding 1rem |
| Tablet (md 768px) | Centered card, max-width 400px |
| Desktop (lg 1024px+) | Centered card, max-width 480px, vertically centered |

---

## Accessibility

- Username input has `aria-label="Username"` and is autofocused.
- Password toggle button has `aria-label="Show password"` / `"Hide password"`.
- Error message has `role="alert"` and `aria-live="polite"`.
- Form can be submitted via Enter key.
- Color contrast meets WCAG 2.1 AA.
