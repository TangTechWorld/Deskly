"use client";
import { currentUser } from "@/utils/mockdata";
import { Users } from "lucide-react";
import Image from "next/image";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      {/* Header */}
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Users className="w-6 h-6 text-blue-600" />
              <span className="text-lg font-semibold">SpatialHub</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2">
                <Image
                  src={currentUser.avatar_url}
                  alt={currentUser.name}
                  width={32}
                  height={32}
                  className="w-8 h-8 rounded-full"
                  unoptimized
                />
                <span className="text-sm">{currentUser.name}</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main content */}
      {children}
    </div>
  );
}
