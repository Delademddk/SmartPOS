import { describe, it, expect } from "vitest";
import {
  ACCEPTED_IMAGE_TYPES,
  MAX_IMAGE_FILE_SIZE,
  resolveImageUrl,
  validateProductImage,
} from "@/utils/image";

describe("resolveImageUrl", () => {
  it("returns null for empty values", () => {
    expect(resolveImageUrl(null)).toBeNull();
    expect(resolveImageUrl(undefined)).toBeNull();
    expect(resolveImageUrl("")).toBeNull();
  });

  it("returns absolute URLs unchanged", () => {
    expect(resolveImageUrl("https://cdn.example.com/cola.jpg")).toBe(
      "https://cdn.example.com/cola.jpg",
    );
    expect(resolveImageUrl("http://localhost:8000/uploads/products/a.png")).toBe(
      "http://localhost:8000/uploads/products/a.png",
    );
  });

  it("returns data and blob URLs unchanged", () => {
    expect(resolveImageUrl("data:image/png;base64,abc")).toBe("data:image/png;base64,abc");
    expect(resolveImageUrl("blob:http://localhost:5173/abc")).toBe("blob:http://localhost:5173/abc");
  });

  it("prefixes relative paths with the API origin", () => {
    expect(resolveImageUrl("/uploads/products/abc.png")).toBe(
      "http://localhost:8000/uploads/products/abc.png",
    );
  });

  it("prefixes relative paths without a leading slash", () => {
    expect(resolveImageUrl("uploads/products/abc.png")).toBe(
      "http://localhost:8000/uploads/products/abc.png",
    );
  });
});

describe("validateProductImage", () => {
  it("accepts supported image types within size", () => {
    for (const type of ACCEPTED_IMAGE_TYPES) {
      const file = new File([new Uint8Array(8)], "photo", { type });
      expect(validateProductImage(file)).toBeNull();
    }
  });

  it("rejects unsupported file types", () => {
    const file = new File([new Uint8Array(8)], "photo.gif", { type: "image/gif" });
    expect(validateProductImage(file)).toMatch(/Unsupported file type/);
  });

  it("rejects files with an unknown type", () => {
    const file = new File([new Uint8Array(8)], "photo", { type: "" });
    expect(validateProductImage(file)).toMatch(/Unsupported file type/);
  });

  it("rejects files larger than the maximum", () => {
    const file = new File([new Uint8Array(MAX_IMAGE_FILE_SIZE + 1)], "big.png", {
      type: "image/png",
    });
    expect(validateProductImage(file)).toMatch(/too large/);
  });

  it("accepts files exactly at the maximum size", () => {
    const file = new File([new Uint8Array(MAX_IMAGE_FILE_SIZE)], "big.png", {
      type: "image/png",
    });
    expect(validateProductImage(file)).toBeNull();
  });
});
