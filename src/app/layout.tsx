import { Login } from "@/components/Login";
import { Button } from "@/components/ui/button";
import type { Metadata } from "next";
import Link from "next/dist/client/link";
import Image from "next/image";
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
      <body className="antialiased">
        <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
          <header className="container mx-auto px-4 py-6">
            <nav className="flex items-center justify-between">
              <Link href="/" className="mx-2">
                <div className="flex items-center gap-2">
                  <Image
                    src="/logo.svg"
                    alt="Deskly Logo"
                    width={32}
                    height={32}
                    className="w-8 h-8 text-blue-600"
                  />
                  <span className="text-xl font-semibold">Deskly</span>
                </div>
              </Link>
              <div className="flex gap-3">
                <Login>
                  <Button size="lg">Get Started</Button>
                </Login>
              </div>
            </nav>
          </header>

          {children}

          <footer className="border-t pt-12 pb-8">
            <div className="container mx-auto px-4">
              <div className="grid md:grid-cols-4 gap-8">
                <div>
                  <div className="flex items-center gap-2 mb-4">
                    <Image
                      src="/logo.svg"
                      alt="Deskly Logo"
                      width={32}
                      height={32}
                      className="w-8 h-8 text-blue-600"
                    />
                    <span className="font-semibold">Deskly</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Spatial presence layer for link-based collaboration.
                  </p>
                </div>
                <div>
                  <h4 className="font-semibold mb-4">Legal</h4>
                  <div className="flex flex-wrap gap-4 text-sm text-gray-600">
                    <Link
                      href="/legal/terms"
                      className="hover:text-blue-700 transition-colors"
                    >
                      Terms
                    </Link>
                    <span className="text-gray-300">|</span>
                    <Link
                      href="/legal/privacy"
                      className="hover:text-blue-700 transition-colors"
                    >
                      Privacy Policy
                    </Link>
                    <span className="text-gray-300">|</span>
                    <Link
                      href="/legal/copyright"
                      className="hover:text-blue-700 transition-colors"
                    >
                      Copyright
                    </Link>
                  </div>
                </div>
                <div>
                  <h4 className="font-semibold mb-4">Source</h4>
                  <a
                    href="https://github.com/TangTechWorld/Deskly"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-2 text-sm text-gray-600 hover:text-blue-700 transition-colors"
                  >
                    <svg className="w-5 h-5" viewBox="0 0 24 24">
                      <path
                        fill="currentColor"
                        d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.865 8.17 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.463-1.11-1.463-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.578 9.578 0 0112 6.836c.85.004 1.705.114 2.504.336 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.578.688.48C19.138 20.167 22 16.418 22 12c0-5.523-4.477-10-10-10z"
                      />
                    </svg>
                    GitHub
                  </a>
                </div>
              </div>
              <div className="border-t mt-8 pt-8 text-center text-sm text-gray-600">
                © 2026 Deskly. All rights reserved.
              </div>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
