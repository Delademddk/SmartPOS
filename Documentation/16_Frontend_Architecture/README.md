# SmartPOS — Frontend Architecture

**Document ID:** DOC-FE-016  
**Version:** 1.0  
**Status:** Approved  
**Author:** SmartPOS Documentation Team  
**Date:** August 7, 2026  

---

## 1. Purpose

This document describes the **frontend architecture** for SmartPOS. It covers
the folder structure, routing strategy, layout system, component architecture,
state management, data fetching, form handling, validation, and responsive
design principles.

---

## 2. Folder Structure

The frontend follows the structure defined in the
[Project Bible](../AI/SMARTPOS_PROJECT_BIBLE.md#project-structure):

```
Frontend/
├── src/
│   ├── assets/             # Images, icons, fonts
│   ├── components/           # Reusable UI components
│   │   ├── ui/             # Primitives (Button, Input, Card, Modal, Table)
│   │   ├── layout/          # Header, Sidebar, Navigation, Footer
│   │   ├── forms/           # Form-specific components
│   │   └── common/          # Shared components (Loading, Error, Empty state)
│   ├── pages/              # Route-level page components
│   │   ├── auth/            # Login
│   │   ├── admin/           # Admin pages (products, users, reports, etc.)
│   │   ├── cashier/         # Cashier pages (sales, returns, dashboard)
│   │   └── shared/          # 404, settings, notifications
│   ├── layouts/            # Layout wrappers (AdminLayout, AuthLayout, MainLayout)
│   ├── hooks/              # Custom React hooks
│   ├── services/           # Business logic hooks (useSales, useProducts)
│   ├── api/               # Axios instance + typed endpoint functions
│   ├── context/           # React context providers (AuthContext)
│   ├── types/            # TypeScript type definitions
│   ├── utils/          # Utility functions (formatters, date utils)
│   ├── routes/        # Route definitions (protected/public routes)
│   └── public/      # Static assets (favicon, manifest)
├── package.json
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── .env.example
├── .env                   # (git-ignored)
└── README.md
```

### 2.1 Directory Purpose

| Directory | Purpose |
|-----------|---------|
| `assets/` | Static image files, icon sets, font files used across components. |
| `components/ui/` | Reusable UI primitives — `Button`, `Input`, `Select`, `Table`, `Card`, `Modal`, `Pagination`, etc. |
| `components/layout/` | `Header`, `Sidebar`, `NavigationMenu`, `Footer` — shared layout components. |
| `components/forms/` | Form-oriented components — `FormField`, `FormSelect`, `FileUpload`. |
| `components/common/` | `LoadingSpinner`, `ErrorBoundary`, `EmptyState`, `ConfirmDialog`. |
| `pages/` | One component per route — each page composes UI components and hooks. |
| `layouts/` | Layout wrappers that apply consistent structure (`AdminLayout` provides sidebar + header). |
| `hooks/` | Custom hooks like `useDebounce`, `useKeyPress`, `useMediaQuery`. |
| `services/` | Business-logic hooks — `useProducts`, `useSales`, `useUsers` — wrap API calls and TanStack Query. |
| `api/` | Axios config (base URL, interceptors) and endpoint functions (e.g., `fetchProducts()`). |
| `context/` | React context providers — primarily `AuthContext` for auth state. |
| `types/` | Shared TypeScript interfaces and enums. |
| `utils/` | Pure functions — date formatting, currency formatting, number formatting. |
| `routes/` | Route configuration with protected route wrappers. |

---

## 3. Routing Strategy

Uses **React Router v6** with role-protected routes.

### 3.1 Route Structure

```
/login                          — Public (login page)
/                               — Redirect (auth-aware)
/admin                          — Admin dashboard (Admin only)
/cashier                        — Cashier dashboard (Cashier only)
/admin/products                 — Product management (Admin)
/admin/categories               — Category management (Admin)
/admin/suppliers                — Supplier management (Admin)
/admin/inventory                — Inventory view (Admin)
/admin/inventory/movements      — Stock movement history (Admin)
/cashier/sales/new              — New sale (Cashier)
/cashier/sales                  — My sales (Cashier)
/admin/sales                    — All sales (Admin)
/cashier/returns/new            — New return (Cashier/Admin)
/admin/returns                  — Returns list (Admin)
/admin/users                    — User management (Admin)
/admin/reports                  — Reports (Admin)
/admin/notifications            — Notifications (All)
/admin/settings                 — Settings (Admin)
/admin/audit-logs               — Audit logs (Admin)
*                               — 404 Not Found
```

### 3.2 Protected Routes

```tsx
// routes/ProtectedRoute.tsx
const ProtectedRoute = ({ children, allowedRoles }) => {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" />;
  if (allowedRoles && !allowedRoles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }
  return <Outlet />;
};
```

```tsx
// routes/app.tsx
<Route path="/admin/products" element={
  <ProtectedRoute allowedRoles={["admin"]} />
} />
```

---

## 4. Component Architecture

### 4.1 Principles

1. **Atomic Design** — `ui/` primitives are atoms, `layout/` are templates,
   `pages/` are pages.
2. **Composition over inheritance** — components accept `children` and slots.
3. **Single responsibility** — each component has one job.
4. **Reusable** — components must be reusable across pages.

### 4.2 Component Hierarchy Example

```
ProductListPage
├── AdminLayout
│   ├── Header (with user menu, notifications bell)
│   ├── Sidebar (role-aware navigation)
│   └── main
│       ├── ProductTable
│       │   ├── SearchBar
│       │   └── Pagination
│       ├── ProductRow (repeated)
│       └── ActionBar (Create, Edit, Delete buttons)
```

### 4.3 UI Primitives

All primitives use **Tailwind CSS** classes — no inline styles.

| Primitive | Usage | Tailwind Classes |
|-----------|-------|------------------|
| `Button` | Primary/secondary actions | `btn btn-primary`, `btn btn-secondary` |
| `Input` | Form fields | `input w-full` |
| `Select` | Dropdowns | `select w-full` |
| `Table` | Data grids | `table-auto w-full` |
| `Card` | Container sections | `card p-4 shadow` |
| `Modal` | Dialogs | `fixed inset-0 bg-black/50` |
| `Badge` | Status indicators | `badge badge-warning` |
| `Pagination` | List pagination | `flex gap-2` |

> **No duplicated UI** — per [Project Bible](AI/SMARTPOS_PROJECT_BIBLE.md#frontend-conventions).

---

## 5. State Management

### 5.1 Strategy

| State Type | Management |
|------------|------------|
| **Server state** | TanStack Query (caching, refetching, pagination) |
| **Auth state** | React Context (`AuthContext`) + localStorage for tokens |
| **UI/form state** | React `useState` / `useReducer` |
| **Global UI state** | React Context (theme, modal stack) |

### 5.2 TanStack Query Configuration

```ts
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      cacheTime: 1000 * 60 * 10, // 10 minutes
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});
```

### 5.3 Auth Context

```ts
interface AuthContextType {
  user: User | null;
  accessToken: string | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<void>;
}
```

The `AuthContext` provides the JWT `access_token` to Axios via an interceptor.

---

## 6. Data Fetching (TanStack Query)

### 6.1 Service Hooks Pattern

Each domain has a service hook that wraps API calls:

```ts
// services/useProducts.ts
export const useProducts = () => {
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['products', { page, pageSize, search, category }],
    queryFn: () => fetchProducts({ page, pageSize, search, category }),
    keepPreviousData: true,
  });

  const createMutation = useMutation({
    mutationFn: createProduct,
    onSuccess: () => queryClient.invalidateQueries(['products']),
  });

  return { data, isLoading, error, createProduct: createMutation.mutate };
};
```

### 6.2 Query Invalidation Strategy

| Action | Queries Invalidated |
|--------|---------------------|
| Create product | `['products']` |
| Update product | `['products', product.id], ['products']` |
| Create sale | `['inventory'], ['sales'], ['dashboard']` |
| Restock | `['inventory'], ['products'], ['stock_movements'], ['notifications']` |

---

## 7. API Client (Axios)

### 7.1 Axios Instance with Interceptors

```ts
// api/client.ts
const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 10000,
});

// Request interceptor — add JWT
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Response interceptor — handle token expiry
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401 && !error.config._retry) {
      // Attempt token refresh
      ...
    }
    return Promise.reject(error);
  }
);
```

---

## 8. Form Handling & Validation

### 8.1 Stack

- **React Hook Form** — form state and submission.
- **Zod** — schema-based validation.

### 8.2 Pattern

```tsx
const schema = z.object({
  sku: z.string().min(1).max(50),
  name: z.string().min(1).max(255),
  price: z.number().min(0),
  ...
});

type Schema = z.infer<typeof schema>;

const {
  register,
  handleSubmit,
  formState: { errors, isSubmitting },
} = useForm<Schema>({
  resolver: zodResolver(schema),
});
```

### 8.3 Validation Rules (Consistent with Backend)

| Field | Rule |
|-------|------|
| `username` | 3–50 chars, alphanumeric + underscore |
| `email` | Valid email regex |
| `password` | ≥ 8 chars, ≥ 1 uppercase, ≥ 1 lowercase, ≥ 1 digit, ≥ 1 special |
| `product.sku` | 1–50 chars, unique |
| `product.price` | ≥ 0 |
| `sale.quantity` | Integer > 0 |

All frontend validation mirrors the backend Pydantic schemas.

---

## 9. Responsive Design

### 9.1 Breakpoint Strategy (Tailwind)

| Breakpoint | Width | Use Case |
|------------|-------|----------|
| `sm` | 640px | Small devices (landscape phones) |
| `md` | 768px | Tablets |
| `lg` | 1024px | Laptops |
| `xl` | 1280px | Desktops |
| `2xl` | 1536px | Large desktops |

### 9.2 Layout Adjustments

| Screen | Sidebar | Content |
|--------|---------|---------|
| `md` and below | Collapsed to icons-only or hamburger menu | Full width |
| `lg` and above | Expanded (250px) | Flexible content area |

### 9.3 Sales Interface

The cashier sales interface is optimized for speed:
- Product search is pinned to the top, keyboard-focused.
- Cart is always visible on the right (or bottom on mobile).
- Payment buttons are large and clearly labeled.
- Receipt prints automatically or is downloadable.

---

## 10. Accessibility

| Requirement | Implementation |
|-------------|----------------|
| Keyboard navigation | All interactive elements are `tabindex` orderable |
| Focus indicators | Tailwind `focus:ring-2 focus:ring-blue-500` |
| ARIA labels | `aria-label`, `aria-labelledby`, `aria-describedby` |
| Color contrast | WCAG 2.1 AA compliant color palette |
| Screen readers | `role`, `aria-live` for dynamic content |

> **Related:** [06_Non_Functional_Requirements — §7](../06_Non_Functional_Requirements/README.md#7-accessibility)

---

## 11. Error & Loading States

### 11.1 Patterns

| State | Component | Behavior |
|-------|-----------|----------|
| Loading | `LoadingSpinner` | Centered spinner overlay |
| Error | `ErrorBoundary` + `ErrorMessage` | User-friendly message + retry button |
| Empty | `EmptyState` | Illustration + descriptive text |
| Success | `SuccessToast` | Auto-dismiss notification |

### 11.2 TanStack Query States

```tsx
if (isLoading) return <LoadingSpinner />;
if (isError) return <ErrorMessage error={error} onRetry={refetch} />;
if (!data?.data?.length) return <EmptyState />;
return <ProductTable data={data.data} />;
```

---

## 12. Build & Configuration

### 12.1 Vite Config

```ts
// vite.config.ts
export default defineConfig({
  server: {
    port: 5173,
    cors: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
```

### 12.2 Environment Variables

```env
VITE_API_BASE_URL=http://localhost:8000/api/v1
VITE_APP_NAME=SmartPOS
VITE_CURRENCY_SYMBOL=$
```

> Only variables prefixed with `VITE_` are exposed to the browser.

---

## 13. Tooling

| Tool | Purpose |
|------|---------|
| Vite | Build tool and dev server |
| ESLint | Code linting |
| Prettier | Code formatting |
| TypeScript | Static typing |
| Tailwind CSS | Styling engine |
| Vitest | Component and unit testing |
| Playwright | End-to-end testing |

---

## 14. Related Documents

- [12_System_Architecture](../12_System_Architecture/README.md)
- [16_Frontend_Architecture](../17_UI_UX_Specification/README.md)
- [15_Backend_Architecture](../15_Backend_Architecture/README.md)
- [21_Project_Structure](../21_Project_Structure/README.md)
- [22_Coding_Standards](../22_Coding_Standards/README.md)
- [19_Testing_Strategy](../19_Testing_Strategy/README.md)
- [SMARTPOS_PROJECT_BIBLE.md](..//../AI/SMARTPOS_PROJECT_BIBLE.md)

---

## 15. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-08-07 | SmartPOS Documentation Team | Initial release |
