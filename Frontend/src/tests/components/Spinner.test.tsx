import { render } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { Spinner } from "@/components/feedback/Spinner";

describe("Spinner", () => {
  it("renders with default size", () => {
    const { container } = render(<Spinner />);
    expect(container.firstChild).toBeTruthy();
  });

  it("renders with sm size", () => {
    const { container } = render(<Spinner size="sm" />);
    const spinner = container.firstChild as HTMLElement;
    expect(spinner.className).toContain("h-4");
  });

  it("renders with lg size", () => {
    const { container } = render(<Spinner size="lg" />);
    const spinner = container.firstChild as HTMLElement;
    expect(spinner.className).toContain("h-12");
  });

  it("applies custom className", () => {
    const { container } = render(<Spinner className="my-custom-class" />);
    const spinner = container.firstChild as HTMLElement;
    expect(spinner.className).toContain("my-custom-class");
  });
});
