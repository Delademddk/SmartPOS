import { createBrowserRouter, Navigate } from "react-router-dom";
import { AdminLayout } from "@/layouts/AdminLayout";
import { AuthLayout } from "@/layouts/AuthLayout";
import { ProtectedRoute } from "@/components/ui/ProtectedRoute";
import { NotFoundPage } from "@/components/ui/NotFoundPage";
import { LoginPage } from "@/pages/auth/LoginPage";
import { DashboardPage } from "@/pages/admin/DashboardPage";
import { UsersPage } from "@/pages/admin/UsersPage";
import { ProductsPage } from "@/pages/products/ProductsPage";
import { CategoriesPage } from "@/pages/categories/CategoriesPage";
import { SuppliersPage } from "@/pages/suppliers/SuppliersPage";
import { InventoryPage } from "@/pages/inventory/InventoryPage";
import { SalesPage } from "@/pages/sales/SalesPage";
import { POSPage } from "@/pages/pos/POSPage";
import { ReturnsPage } from "@/pages/returns/ReturnsPage";
import { CreditsPage } from "@/pages/credits/CreditsPage";
import { PaymentsPage } from "@/pages/payments/PaymentsPage";
import { ReportsPage } from "@/pages/reports/ReportsPage";
import { SettingsPage } from "@/pages/settings/SettingsPage";
import { AuditPage } from "@/pages/audit/AuditPage";
import { NotificationsPage } from "@/pages/notifications/NotificationsPage";
import { ProfilePage } from "@/pages/shared/ProfilePage";
import { ROLES } from "@/constants";

export const router = createBrowserRouter([
  {
    path: "/login",
    element: <AuthLayout />,
    children: [
      { index: true, element: <LoginPage /> },
    ],
  },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <AdminLayout />,
        children: [
          { path: "/dashboard", element: <DashboardPage /> },
          { path: "/products", element: <ProductsPage /> },
          { path: "/categories", element: <CategoriesPage /> },
          { path: "/suppliers", element: <SuppliersPage /> },
          { path: "/inventory", element: <InventoryPage /> },
          { path: "/sales", element: <SalesPage /> },
          { path: "/sales/:saleId", element: <SalesPage /> },
          { path: "/pos", element: <POSPage /> },
          { path: "/returns", element: <ReturnsPage /> },
          { path: "/credits", element: <CreditsPage /> },
          { path: "/payments", element: <PaymentsPage /> },
          { path: "/notifications", element: <NotificationsPage /> },
          { path: "/profile", element: <ProfilePage /> },
          {
            path: "/users",
            element: <ProtectedRoute allowedRoles={[ROLES.ADMIN]} />,
            children: [{ index: true, element: <UsersPage /> }],
          },
          {
            path: "/reports",
            element: <ProtectedRoute allowedRoles={[ROLES.ADMIN]} />,
            children: [{ index: true, element: <ReportsPage /> }],
          },
          {
            path: "/settings",
            element: <ProtectedRoute allowedRoles={[ROLES.ADMIN]} />,
            children: [{ index: true, element: <SettingsPage /> }],
          },
          {
            path: "/audit",
            element: <ProtectedRoute allowedRoles={[ROLES.ADMIN]} />,
            children: [{ index: true, element: <AuditPage /> }],
          },
        ],
      },
    ],
  },
  { path: "/", element: <Navigate to="/dashboard" replace /> },
  { path: "*", element: <NotFoundPage /> },
]);
