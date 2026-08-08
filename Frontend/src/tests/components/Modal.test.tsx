import { render, screen, fireEvent } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { Modal } from "@/components/ui/Modal";

describe("Modal", () => {
  it("renders when isOpen is true", () => {
    render(
      <Modal isOpen={true} onClose={() => {}} title="Test Modal">
        <p>Modal content</p>
      </Modal>,
    );
    expect(screen.getByText("Test Modal")).toBeInTheDocument();
    expect(screen.getByText("Modal content")).toBeInTheDocument();
  });

  it("does not render when isOpen is false", () => {
    render(
      <Modal isOpen={false} onClose={() => {}} title="Test Modal">
        <p>Modal content</p>
      </Modal>,
    );
    expect(screen.queryByText("Test Modal")).not.toBeInTheDocument();
  });

  it("calls onClose when close button is clicked", () => {
    const onClose = vi.fn();
    render(
      <Modal isOpen={true} onClose={onClose} title="Test Modal">
        <p>Content</p>
      </Modal>,
    );
    fireEvent.click(screen.getByRole("button"));
    expect(onClose).toHaveBeenCalled();
  });

  it("renders footer when provided", () => {
    render(
      <Modal
        isOpen={true}
        onClose={() => {}}
        title="Test"
        footer={<button>Save</button>}
      >
        <p>Content</p>
      </Modal>,
    );
    expect(screen.getByText("Save")).toBeInTheDocument();
  });
});
