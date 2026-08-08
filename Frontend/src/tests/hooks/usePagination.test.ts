import { renderHook, act } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { usePagination } from "@/hooks/usePagination";

describe("usePagination", () => {
  it("returns default values", () => {
    const { result } = renderHook(() => usePagination());
    expect(result.current.page).toBe(1);
    expect(result.current.pageSize).toBe(50);
  });

  it("returns custom initial values", () => {
    const { result } = renderHook(() =>
      usePagination({ initialPage: 3, initialPageSize: 25 }),
    );
    expect(result.current.page).toBe(3);
    expect(result.current.pageSize).toBe(25);
  });

  it("goes to next page", () => {
    const { result } = renderHook(() => usePagination());
    act(() => result.current.nextPage());
    expect(result.current.page).toBe(2);
  });

  it("goes to previous page", () => {
    const { result } = renderHook(() =>
      usePagination({ initialPage: 3 }),
    );
    act(() => result.current.prevPage());
    expect(result.current.page).toBe(2);
  });

  it("does not go below page 1", () => {
    const { result } = renderHook(() => usePagination());
    act(() => result.current.prevPage());
    expect(result.current.page).toBe(1);
  });

  it("sets specific page", () => {
    const { result } = renderHook(() => usePagination());
    act(() => result.current.setPage(5));
    expect(result.current.page).toBe(5);
  });

  it("changes page size and resets to page 1", () => {
    const { result } = renderHook(() =>
      usePagination({ initialPage: 5 }),
    );
    act(() => result.current.setPageSize(25));
    expect(result.current.pageSize).toBe(25);
    expect(result.current.page).toBe(1);
  });

  it("resets to initial values", () => {
    const { result } = renderHook(() =>
      usePagination({ initialPage: 1, initialPageSize: 25 }),
    );
    act(() => {
      result.current.setPage(10);
      result.current.setPageSize(50);
    });
    act(() => result.current.reset());
    expect(result.current.page).toBe(1);
    expect(result.current.pageSize).toBe(25);
  });
});
