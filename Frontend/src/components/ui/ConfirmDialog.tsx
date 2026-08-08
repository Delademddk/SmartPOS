import { AlertTriangle } from "lucide-react";
import { Modal } from "./Modal";

interface ConfirmDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmLabel?: string;
  isLoading?: boolean;
  variant?: "danger" | "warning";
}

export function ConfirmDialog({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = "Confirm",
  isLoading = false,
  variant = "danger",
}: ConfirmDialogProps) {
  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <button onClick={onClose} className="btn-secondary" disabled={isLoading}>
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={isLoading}
            className={variant === "danger" ? "btn-danger" : "btn-primary"}
          >
            {isLoading ? "Processing..." : confirmLabel}
          </button>
        </>
      }
    >
      <div className="flex gap-4">
        <div className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full ${
          variant === "danger" ? "bg-red-100" : "bg-yellow-100"
        }`}>
          <AlertTriangle className={`h-5 w-5 ${
            variant === "danger" ? "text-red-600" : "text-yellow-600"
          }`} />
        </div>
        <p className="text-sm text-gray-600">{message}</p>
      </div>
    </Modal>
  );
}
