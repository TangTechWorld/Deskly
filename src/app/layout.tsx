import type { Metadata } from "next";
// @ts-expect-error CSS import side effects
import "./globals.css";

export const metadata: Metadata = {
  title: "Deskly",
  description: "Spatial presence layer for link-based collaboration",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
