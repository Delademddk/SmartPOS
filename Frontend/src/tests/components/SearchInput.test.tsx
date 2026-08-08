import { render, screen, fireEvent } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { SearchInput } from "@/components/ui/SearchInput";

describe("SearchInput", () => {
  it("renders with placeholder", () => {
    render(<SearchInput value="" onChange={() => {}} placeholder="Search products..." />);
    expect(screen.getByPlaceholderText("Search products...")).toBeInTheDocument();
  });

  it("displays the current value", () => {
    render(<SearchInput value="test" onChange={() => {}} />);
    expect(screen.getByDisplayValue("test")).toBeInTheDocument();
  });

  it("calls onChange when typing", () => {
    const onChange = vi.fn();
    render(<SearchInput value="" onChange={onChange} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "hello" } });
  });

  it("shows clear button when value is present", () => {
    render(<SearchInput value="test" onChange={() => {}} />);
    expect(screen.getByRole("button")).toBeInTheDocument();
  });
});
