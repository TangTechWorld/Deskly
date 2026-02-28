import { Building2, Plus } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "../components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "../components/ui/dialog";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { ImageUploader } from "./ImageUploader";

export function OrgPopup({
  open,
  isNew,
  id,
}: {
  open: boolean;
  isNew: boolean;
  id?: string;
}) {
  const [newOrgName, setNewOrgName] = useState("");
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(open);
  const [orgLogo, setOrgLogo] = useState("");
  const [orgLogoFile, setOrgLogoFile] = useState<File | null>(null);
  const router = useRouter();

  const handleCreateOrg = () => {
    if (newOrgName.trim()) {
      // In a real app, this would create the organization in the database
      console.log("Creating organization:", newOrgName);
      setIsCreateDialogOpen(false);
      setNewOrgName("");
      setOrgLogo("");
      setOrgLogoFile(null);
      // Simulate navigation to new org
      router.replace("/org/org-new/map");
    }
  };

  return (
    <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Plus className="w-4 h-4" />
          Create Organization
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create New Organization</DialogTitle>
          <DialogDescription>
            Set up a new workspace for your team.
          </DialogDescription>
        </DialogHeader>
        <div className="py-4">
          <div>
            <Label htmlFor="org-name">Organization Name</Label>
            <Input
              id="org-name"
              value={newOrgName}
              onChange={(e) => setNewOrgName(e.target.value)}
              placeholder="e.g., Acme Design Studio"
              className="mt-2"
            />
          </div>

          <div>
            <ImageUploader
              value={orgLogo}
              onChange={(imageUrl, file) => {
                setOrgLogo(imageUrl);
                if (file) {
                  setOrgLogoFile(file);
                }
              }}
              label="Organization Logo"
              previewSize="md"
              previewShape="square"
              fallbackIcon={<Building2 className="w-12 h-12 text-gray-400" />}
              fallbackText="No logo"
            />
          </div>
        </div>
        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => setIsCreateDialogOpen(false)}
          >
            Cancel
          </Button>
          <Button onClick={handleCreateOrg}>Create</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
