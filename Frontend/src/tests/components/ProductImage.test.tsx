import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { ProductImage } from "@/components/ui/ProductImage";

describe("ProductImage", () => {
  it("renders an image with the resolved relative URL and alt text", () => {
    render(<ProductImage imageUrl="/uploads/products/abc.png" alt="Coca Cola" />);
    const img = screen.getByRole("img", { name: "Coca Cola" });
    expect(img).toHaveAttribute("src", "http://localhost:8000/uploads/products/abc.png");
  });

  it("renders an absolute URL as-is", () => {
    render(<ProductImage imageUrl="https://s3.example.com/cola.jpg" alt="Coca Cola" />);
    const img = screen.getByRole("img", { name: "Coca Cola" });
    expect(img).toHaveAttribute("src", "https://s3.example.com/cola.jpg");
  });

  it("renders a placeholder with a meaningful label when no image exists", () => {
    render(<ProductImage imageUrl={null} alt="Coca Cola" />);
    const placeholder = screen.getByRole("img", { name: "Coca Cola" });
    expect(placeholder.tagName).toBe("DIV");
    expect(placeholder).not.toHaveAttribute("src");
  });

  it("renders a placeholder when imageUrl is undefined", () => {
    render(<ProductImage alt="Coca Cola" />);
    expect(screen.getByRole("img", { name: "Coca Cola" })).toBeInTheDocument();
  });
});
