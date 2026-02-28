"use client";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { User } from "lucide-react";
import { ImageUploader } from "./ImageUploader";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";

interface ConfirmProfileDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  name: string;
  onNameChange: (name: string) => void;
  avatarLogo: string;
  onAvatarChange: (imageUrl: string, file?: File) => void;
  isSubmitting: boolean;
  onConfirm: () => Promise<void>;
  onLogout: () => Promise<void>;
}

export function ConfirmProfileDialog({
  open,
  onOpenChange,
  name,
  onNameChange,
  avatarLogo,
  onAvatarChange,
  isSubmitting,
  onConfirm,
  onLogout,
}: ConfirmProfileDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="text-2xl">Confirm your profile</DialogTitle>
          <DialogDescription>
            Please confirm your details before continuing to your organizations.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="name">Name</Label>
            <Input
              id="name"
              value={name}
              onChange={(event) => onNameChange(event.target.value)}
              placeholder="Your full name"
            />
          </div>
          <div className="space-y-2">
            <ImageUploader
              value={avatarLogo}
              onChange={(imageUrl, file) => {
                onAvatarChange(imageUrl, file);
              }}
              label="Avatar"
              previewSize="md"
              previewShape="square"
              fallbackIcon={<User className="w-12 h-12 text-gray-400" />}
              fallbackText="No avatar"
            />
          </div>
          <div className="text-center">
            <Button
              className="w-full"
              onClick={() => void onConfirm()}
              disabled={name.trim().length === 0 || isSubmitting}
            >
              {isSubmitting ? "Saving..." : "Confirm and Continue"}
            </Button>
            <Button
              variant="link"
              className="hover:text-blue-700 transition-colors"
              onClick={() => void onLogout()}
            >
              Logout
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
