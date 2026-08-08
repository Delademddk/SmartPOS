import { Outlet } from "react-router-dom";
import { ShoppingCart } from "lucide-react";

export function AuthLayout() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-primary-50 to-primary-100 px-4">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-primary-600 shadow-lg">
            <ShoppingCart className="h-8 w-8 text-white" />
          </div>
          <h1 className="mt-4 text-2xl font-bold text-gray-900">SmartPOS</h1>
          <p className="text-sm text-gray-500">Point of Sale & Inventory Management</p>
        </div>
        <Outlet />
      </div>
    </div>
  );
}
