import { useState, useCallback } from "react";
import { DEFAULT_PAGE_SIZE } from "@/constants";

interface UsePaginationOptions {
  initialPage?: number;
  initialPageSize?: number;
}

export function usePagination({
  initialPage = 1,
  initialPageSize = DEFAULT_PAGE_SIZE,
}: UsePaginationOptions = {}) {
  const [page, setPage] = useState(initialPage);
  const [pageSize, setPageSize] = useState(initialPageSize);

  const goToPage = useCallback((newPage: number) => {
    setPage(newPage);
  }, []);

  const nextPage = useCallback(() => {
    setPage((p) => p + 1);
  }, []);

  const prevPage = useCallback(() => {
    setPage((p) => Math.max(1, p - 1));
  }, []);

  const changePageSize = useCallback((newSize: number) => {
    setPageSize(newSize);
    setPage(1);
  }, []);

  const reset = useCallback(() => {
    setPage(initialPage);
    setPageSize(initialPageSize);
  }, [initialPage, initialPageSize]);

  return {
    page,
    pageSize,
    setPage: goToPage,
    nextPage,
    prevPage,
    setPageSize: changePageSize,
    reset,
  };
}
