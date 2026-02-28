"use client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  currentUser,
  getActiveUsersInOrganization,
  getMembersByOrganization,
  organizationInvitations,
  organizations,
  type Organization,
  type OrganizationInvitation,
} from "@/utils/mockdata";
import { Building2, Check, Mail, Plus, Users, X } from "lucide-react";
import { useState } from "react";

export default function OrganizationSelector() {
  const navigate = (_s: string) => {};
  const [newOrgName, setNewOrgName] = useState("");
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);

  // Get organizations the user is a member of
  const userOrgs = organizations.filter((org) => {
    return getMembersByOrganization(org.id).some(
      (m) => m.user_id === currentUser.id,
    );
  });

  // Get pending invitations for the user
  const pendingInvitations = organizationInvitations.filter(
    (inv) => inv.email === currentUser.email && inv.status === "pending",
  );

  const handleSelectOrg = (orgId: string) => {
    navigate(`/org/${orgId}/map`);
  };

  const handleCreateOrg = () => {
    if (newOrgName.trim()) {
      // In a real app, this would create the organization in the database
      console.log("Creating organization:", newOrgName);
      setIsCreateDialogOpen(false);
      setNewOrgName("");
      // Simulate navigation to new org
      navigate("/org/org-new/map");
    }
  };

  const handleAcceptInvitation = (invitation: OrganizationInvitation) => {
    console.log("Accepting invitation:", invitation.id);
    // In real app, would update invitation status and add user to org
  };

  const handleDeclineInvitation = (invitation: OrganizationInvitation) => {
    console.log("Declining invitation:", invitation.id);
    // In real app, would update invitation status
  };

  return (
    <div className="container mx-auto px-4 py-12">
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Select an Organization</h1>
          <p className="text-gray-600">
            Choose which organization to connect to. You can switch anytime.
          </p>
        </div>

        {/* Pending Invitations */}
        {pendingInvitations.length > 0 && (
          <div className="mb-8">
            <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
              <Mail className="w-5 h-5" />
              Pending Invitations
            </h2>
            <div className="space-y-3">
              {pendingInvitations.map((invitation) => {
                const org = organizations.find(
                  (o) => o.id === invitation.organization_id,
                );
                return (
                  <Card key={invitation.id} className="border-blue-200">
                    <CardHeader>
                      <div className="flex items-start justify-between">
                        <div>
                          <CardTitle className="text-lg">{org?.name}</CardTitle>
                          <CardDescription>
                            {invitation.message}
                          </CardDescription>
                        </div>
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            onClick={() => handleAcceptInvitation(invitation)}
                            className="gap-1"
                          >
                            <Check className="w-4 h-4" />
                            Accept
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => handleDeclineInvitation(invitation)}
                            className="gap-1"
                          >
                            <X className="w-4 h-4" />
                            Decline
                          </Button>
                        </div>
                      </div>
                    </CardHeader>
                  </Card>
                );
              })}
            </div>
          </div>
        )}

        {/* Organizations */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Your Organizations</h2>
            <Dialog
              open={isCreateDialogOpen}
              onOpenChange={setIsCreateDialogOpen}
            >
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
                  <Label htmlFor="org-name">Organization Name</Label>
                  <Input
                    id="org-name"
                    value={newOrgName}
                    onChange={(e) => setNewOrgName(e.target.value)}
                    placeholder="e.g., Acme Design Studio"
                    className="mt-2"
                  />
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
          </div>

          {userOrgs.length === 0 ? (
            <Card>
              <CardContent className="py-12 text-center">
                <Building2 className="w-12 h-12 mx-auto mb-4 text-gray-400" />
                <p className="text-gray-600 mb-4">
                  You&apos;re not part of any organizations yet.
                </p>
                <Button onClick={() => setIsCreateDialogOpen(true)}>
                  Create Your First Organization
                </Button>
              </CardContent>
            </Card>
          ) : (
            <div className="grid md:grid-cols-2 gap-4">
              {userOrgs.map((org) => (
                <OrganizationCard
                  key={org.id}
                  organization={org}
                  onClick={() => handleSelectOrg(org.id)}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function OrganizationCard({
  organization,
  onClick,
}: {
  organization: Organization;
  onClick: () => void;
}) {
  const memberCount = getMembersByOrganization(organization.id).length;
  const activeCount = getActiveUsersInOrganization(organization.id);

  return (
    <Card
      className="cursor-pointer hover:shadow-lg transition-shadow hover:border-blue-300"
      onClick={onClick}
    >
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-500 rounded-lg flex items-center justify-center">
              <Building2 className="w-6 h-6 text-white" />
            </div>
            <div>
              <CardTitle>{organization.name}</CardTitle>
              <CardDescription className="flex items-center gap-2 mt-1">
                <Users className="w-4 h-4" />
                {memberCount} members
              </CardDescription>
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="flex items-center justify-between">
          <Badge variant="secondary" className="gap-1">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            {activeCount} active
          </Badge>
          <Button variant="ghost" size="sm">
            Open →
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
