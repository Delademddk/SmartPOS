import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { EmptyState } from "@/components/feedback/EmptyState";

describe("EmptyState", () => {
  it("renders title", () => {
    render(<EmptyState title="No items found" />);
    expect(screen.getByText("No items found")).toBeInTheDocument();
  });

  it("renders description when provided", () => {
    render(
      <EmptyState title="No items" description="Create your first item to get started." />,
    );
    expect(screen.getByText("Create your first item to get started.")).toBeInTheDocument();
  });

  it("renders action when provided", () => {
    render(
      <EmptyState title="Empty" action={<button>Add Item</button>} />,
    );
    expect(screen.getByText("Add Item")).toBeInTheDocument();
  });
});
