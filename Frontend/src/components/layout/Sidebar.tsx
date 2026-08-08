import { NavLink, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Users,
  Package,
  FolderTree,
  Truck,
  Warehouse,
  ShoppingCart,
  CreditCard,
  UserCheck,
  RotateCcw,
  BarChart3,
  Settings,
  Shield,
  Bell,
  X,
} from "lucide-react";
import { cn } from "@/utils/cn";
import { useAuth } from "@/hooks/useAuth";
import { ROLES } from "@/constants";

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

interface NavItem {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  adminOnly?: boolean;
}

const navItems: NavItem[] = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard, adminOnly: true },
  { to: "/pos", label: "Point of Sale", icon: ShoppingCart },
  { to: "/products", label: "Products", icon: Package },
  { to: "/categories", label: "Categories", icon: FolderTree },
  { to: "/suppliers", label: "Suppliers", icon: Truck },
  { to: "/inventory", label: "Inventory", icon: Warehouse },
  { to: "/sales", label: "Sales", icon: CreditCard },
  { to: "/returns", label: "Returns", icon: RotateCcw },
  { to: "/credits", label: "Credit Sales", icon: UserCheck },
  { to: "/users", label: "Users", icon: Users, adminOnly: true },
  { to: "/reports", label: "Reports", icon: BarChart3, adminOnly: true },
  { to: "/settings", label: "Settings", icon: Settings, adminOnly: true },
  { to: "/audit", label: "Audit Logs", icon: Shield, adminOnly: true },
  { to: "/notifications", label: "Notifications", icon: Bell },
];

export function Sidebar({ isOpen, onClose }: SidebarProps) {
  const location = useLocation();
  const { isAdmin } = useAuth();

  const filteredItems = navItems.filter((item) => !item.adminOnly || isAdmin);

  return (
    <>
      {isOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/50 lg:hidden"
          onClick={onClose}
        />
      )}

      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex w-64 flex-col bg-white border-r border-gray-200 transition-transform duration-200",
          "lg:translate-x-0 lg:static",
          isOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex h-16 items-center justify-between px-6 border-b border-gray-200">
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-600">
              <ShoppingCart className="h-5 w-5 text-white" />
            </div>
            <span className="text-lg font-bold text-gray-900">SmartPOS</span>
          </div>
          <button onClick={onClose} className="lg:hidden p-1 rounded hover:bg-gray-100">
            <X className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
          {filteredItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.to || location.pathname.startsWith(item.to + "/");
            return (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={onClose}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-primary-50 text-primary-700"
                    : "text-gray-600 hover:bg-gray-50 hover:text-gray-900",
                )}
              >
                <Icon className={cn("h-5 w-5 flex-shrink-0", isActive ? "text-primary-600" : "text-gray-400")} />
                {item.label}
              </NavLink>
            );
          })}
        </nav>
      </aside>
    </>
  );
}
