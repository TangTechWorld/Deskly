"use client";
import { Button } from "./ui/button";

export function ScrollToTopButton() {
  return (
    <Button
      size="lg"
      variant="secondary"
      onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
    >
      Get Started for Free
    </Button>
  );
}
