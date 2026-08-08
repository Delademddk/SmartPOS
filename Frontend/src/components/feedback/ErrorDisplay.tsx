import { AlertTriangle } from "lucide-react";
import type { ReactNode } from "react";

interface ErrorDisplayProps {
  title?: string;
  message: string;
  action?: ReactNode;
}

export function ErrorDisplay({
  title = "Something went wrong",
  message,
  action,
}: ErrorDisplayProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-4">
      <div className="rounded-full bg-red-50 p-4 mb-4">
        <AlertTriangle className="h-8 w-8 text-red-500" />
      </div>
      <h3 className="text-lg font-medium text-gray-900 mb-1">{title}</h3>
      <p className="text-sm text-gray-500 mb-4 text-center max-w-sm">{message}</p>
      {action}
    </div>
  );
}
