# SmartPOS Frontend

Production-ready React frontend for the SmartPOS Point of Sale & Inventory Management System.

## Tech Stack

- **React 18** with TypeScript
- **Vite** for fast builds and HMR
- **Tailwind CSS** for styling
- **React Router v6** for routing
- **TanStack Query** for server state
- **Axios** for HTTP requests
- **React Hook Form + Zod** for forms and validation
- **Lucide React** for icons

## Prerequisites

- Node.js 18+ and npm
- SmartPOS Backend running on `http://localhost:8000`

## Quick Start

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment:
   ```bash
   copy .env.example .env
   ```
   Edit `.env` if your backend runs on a different port.

3. Start development server:
   ```bash
   npm run dev
   ```

4. Open `http://localhost:5173` in your browser.

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm run format` | Format code with Prettier |
| `npm run test` | Run tests |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:coverage` | Run tests with coverage |

## Project Structure

```
src/
├── api/              # Axios client and API helpers
├── components/
│   ├── feedback/     # Spinner, PageLoader, EmptyState, ErrorBoundary
│   ├── layout/       # Sidebar, Header
│   └── ui/           # Reusable components (Modal, Badge, Button, etc.)
├── context/          # React Context (Auth)
├── hooks/            # Custom hooks (useAuth, useDebounce, usePagination)
├── layouts/          # AdminLayout, AuthLayout
├── pages/
│   ├── admin/        # Dashboard, Users
│   ├── audit/        # Audit Logs
│   ├── auth/         # Login
│   ├── categories/   # Categories CRUD
│   ├── credits/      # Credit Sales
│   ├── inventory/    # Inventory Management
│   ├── notifications/# Notification Center
│   ├── payments/     # Payment History
│   ├── pos/          # Cashier POS Interface
│   ├── products/     # Products CRUD
│   ├── reports/      # Reports
│   ├── returns/      # Returns
│   ├── sales/        # Sales List & Detail
│   ├── settings/     # Business Settings
│   └── shared/       # Profile
├── routes/           # Route definitions
├── services/         # API service functions
├── styles/           # Global CSS
├── tests/            # Test files
├── types/            # TypeScript type definitions
├── utils/            # Utility functions
└── validators/       # Zod schemas
```

## Features

- **Authentication** — JWT login with token refresh
- **Role-based access** — Admin and Cashier roles with different permissions
- **POS Interface** — Fast keyboard-friendly cashier screen
- **Product Management** — Full CRUD with categories, suppliers and product images (upload, preview, replace, remove; placeholder when none)
- **Inventory** — Stock tracking, restocking, adjustments, low stock alerts
- **Sales** — Complete sales workflow with receipts
- **Credit Sales** — Customer credit management and settlements
- **Returns** — Return processing with reason tracking
- **Reports** — Daily, monthly, inventory, profit, and more
- **Dashboard** — KPIs, charts, top products, sales trends
- **Notifications** — Real-time notification center
- **Audit Logs** — Activity, security, and error logging
- **Settings** — Business info, tax rates, application settings

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API base URL | `http://localhost:8000/api/v1` |
| `VITE_APP_NAME` | Application name | `SmartPOS` |
| `VITE_APP_ENV` | Environment | `development` |

## API Integration

All API calls go through a centralized Axios client (`src/api/client.ts`) that handles:
- JWT access token injection
- Automatic token refresh on 401
- Request/response interceptors
- Error handling

Server state is managed via TanStack Query with proper caching and invalidation.

### Product Images

Product images are uploaded as `multipart/form-data` to the existing product
create/update endpoints (`data` field = JSON payload, `image` file, optional
`remove_image=true`). `image_url` returned by the backend is treated as an
opaque URL/path: relative paths (local uploads, e.g. `/uploads/products/…`) are
prefixed with the API origin from `VITE_API_URL`, while absolute URLs (Amazon
S3 / CDN in future deployments) are used as-is — no frontend changes required
when moving to S3. Accepted formats are JPEG, PNG and WebP up to 2 MB,
validated client-side and authoritatively by the backend.

## Testing

Tests use Vitest and React Testing Library:

```bash
npm run test           # Single run
npm run test:watch     # Watch mode
npm run test:coverage  # Coverage report
```
