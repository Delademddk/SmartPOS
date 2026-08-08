import { useNavigate } from "react-router-dom";
import { Home } from "lucide-react";

export function NotFoundPage() {
  const navigate = useNavigate();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-gray-50 px-4">
      <div className="text-center">
        <p className="text-6xl font-bold text-primary-600">404</p>
        <h1 className="mt-4 text-2xl font-bold text-gray-900">Page not found</h1>
        <p className="mt-2 text-gray-500">
          The page you are looking for does not exist or has been moved.
        </p>
        <button
          onClick={() => navigate("/")}
          className="btn-primary mt-6"
        >
          <Home className="h-4 w-4" />
          Go Home
        </button>
      </div>
    </div>
  );
}
