import type { ReactNode } from "react";
import { cn } from "@/utils/cn";

export interface Column<T> {
  key: string;
  header: string;
  className?: string;
  render?: (item: T, index: number) => ReactNode;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  onRowClick?: (item: T) => void;
  keyExtractor: (item: T) => string | number;
  emptyMessage?: string;
}

export function DataTable<T>({
  columns,
  data,
  onRowClick,
  keyExtractor,
  emptyMessage = "No data available",
}: DataTableProps<T>) {
  if (!data.length) {
    return (
      <div className="table-container">
        <div className="py-12 text-center text-sm text-gray-500">{emptyMessage}</div>
      </div>
    );
  }

  return (
    <div className="table-container overflow-x-auto">
      <table className="table">
        <thead>
          <tr>
            {columns.map((col) => (
              <th key={col.key} className={col.className}>
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((item, index) => (
            <tr
              key={keyExtractor(item)}
              onClick={() => onRowClick?.(item)}
              className={cn(onRowClick && "cursor-pointer")}
            >
              {columns.map((col) => (
                <td key={col.key} className={col.className}>
                  {col.render
                    ? col.render(item, index)
                    : String((item as Record<string, unknown>)[col.key] ?? "")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
