// Mock data for the spatial presence app

export type UserStatus = "active" | "in_room" | "away" | "dnd";
export type CabinType = "desk" | "room" | "focus";
export type EventType = "ring" | "knock" | "invite_to_room";
export type UserRole = "owner" | "admin" | "member";

export interface User {
  id: string;
  name: string;
  avatar_url: string;
  email: string;
}

export interface Organization {
  id: string;
  name: string;
  created_at: string;
}

export interface OrganizationMember {
  id: string;
  organization_id: string;
  user_id: string;
  role: UserRole;
  desk_cabin_id?: string; // Assigned desk
}

export interface OrganizationInvitation {
  id: string;
  organization_id: string;
  email: string;
  message: string;
  status: "pending" | "accepted" | "declined";
}

export interface Map {
  id: string;
  organization_id: string;
  image_url: string;
  name: string;
}

export interface Cabin {
  id: string;
  map_id: string;
  name: string;
  type: CabinType;
  link_url: string;
  image_url?: string;
  x: number; // Position on map
  y: number;
}

export interface Presence {
  id: string;
  user_id: string;
  organization_id: string;
  cabin_id?: string;
  status: UserStatus;
  custom_message?: string;
  updated_at: string;
}

export interface Event {
  id: string;
  organization_id: string;
  from_user_id: string;
  to_user_id: string;
  type: EventType;
  cabin_id?: string;
  created_at: string;
}

// Current logged-in user
export const currentUser: User = {
  id: "user-1",
  name: "Alex Chen",
  email: "alex.chen@example.com",
  avatar_url:
    "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop",
};

// Mock users
export const users: User[] = [
  currentUser,
  {
    id: "user-2",
    name: "Sarah Johnson",
    email: "sarah.j@example.com",
    avatar_url:
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop",
  },
  {
    id: "user-3",
    name: "Mike Rodriguez",
    email: "mike.r@example.com",
    avatar_url:
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop",
  },
  {
    id: "user-4",
    name: "Emily Davis",
    email: "emily.d@example.com",
    avatar_url:
      "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop",
  },
  {
    id: "user-5",
    name: "James Wilson",
    email: "james.w@example.com",
    avatar_url:
      "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop",
  },
];

// Mock organizations
export const organizations: Organization[] = [
  {
    id: "org-1",
    name: "Acme Design Studio",
    created_at: "2024-01-15T10:00:00Z",
  },
  {
    id: "org-2",
    name: "TechFlow Inc",
    created_at: "2024-02-01T10:00:00Z",
  },
  {
    id: "org-3",
    name: "Creative Labs",
    created_at: "2024-03-10T10:00:00Z",
  },
];

// Mock organization members
export const organizationMembers: OrganizationMember[] = [
  {
    id: "mem-1",
    organization_id: "org-1",
    user_id: "user-1",
    role: "admin",
    desk_cabin_id: "cabin-1",
  },
  {
    id: "mem-2",
    organization_id: "org-1",
    user_id: "user-2",
    role: "member",
    desk_cabin_id: "cabin-2",
  },
  {
    id: "mem-3",
    organization_id: "org-1",
    user_id: "user-3",
    role: "member",
    desk_cabin_id: "cabin-3",
  },
  {
    id: "mem-4",
    organization_id: "org-1",
    user_id: "user-4",
    role: "member",
    desk_cabin_id: "cabin-4",
  },
  {
    id: "mem-5",
    organization_id: "org-2",
    user_id: "user-1",
    role: "member",
    desk_cabin_id: "cabin-10",
  },
  {
    id: "mem-6",
    organization_id: "org-2",
    user_id: "user-5",
    role: "owner",
    desk_cabin_id: "cabin-11",
  },
];

// Mock invitations
export const organizationInvitations: OrganizationInvitation[] = [
  {
    id: "inv-1",
    organization_id: "org-3",
    email: "alex.chen@example.com", // Current user's email
    message:
      "Join our creative team! We think you'd be a great fit for our design and innovation projects.",
    status: "pending",
  },
  {
    id: "inv-2",
    organization_id: "org-2",
    email: "newuser@example.com",
    message: "Join our awesome team!",
    status: "pending",
  },
];

// Mock maps
export const maps: Map[] = [
  {
    id: "map-1",
    organization_id: "org-1",
    name: "Main Office",
    image_url:
      "https://images.unsplash.com/photo-1497366216548-37526070297c?w=1200&h=800&fit=crop",
  },
  {
    id: "map-2",
    organization_id: "org-2",
    name: "Tech Hub Floor",
    image_url:
      "https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&h=800&fit=crop",
  },
];

// Mock cabins
export const cabins: Cabin[] = [
  // Org 1 cabins
  {
    id: "cabin-1",
    map_id: "map-1",
    name: "Alex's Desk",
    type: "desk",
    link_url: "https://meet.google.com/abc-defg-hij",
    x: 150,
    y: 200,
  },
  {
    id: "cabin-2",
    map_id: "map-1",
    name: "Sarah's Desk",
    type: "desk",
    link_url: "https://zoom.us/j/123456789",
    x: 350,
    y: 200,
  },
  {
    id: "cabin-3",
    map_id: "map-1",
    name: "Mike's Desk",
    type: "desk",
    link_url: "https://meet.google.com/xyz-1234-567",
    x: 550,
    y: 200,
  },
  {
    id: "cabin-4",
    map_id: "map-1",
    name: "Emily's Desk",
    type: "desk",
    link_url: "https://teams.microsoft.com/meet/abc",
    x: 750,
    y: 200,
  },
  {
    id: "cabin-5",
    map_id: "map-1",
    name: "Conference Room A",
    type: "room",
    link_url: "https://meet.google.com/conf-room-a",
    x: 250,
    y: 450,
  },
  {
    id: "cabin-6",
    map_id: "map-1",
    name: "Conference Room B",
    type: "room",
    link_url: "https://zoom.us/j/987654321",
    x: 650,
    y: 450,
  },
  {
    id: "cabin-7",
    map_id: "map-1",
    name: "Focus Pod 1",
    type: "focus",
    link_url: "https://meet.google.com/focus-1",
    x: 150,
    y: 550,
  },
  {
    id: "cabin-8",
    map_id: "map-1",
    name: "Focus Pod 2",
    type: "focus",
    link_url: "https://meet.google.com/focus-2",
    x: 750,
    y: 550,
  },

  // Org 2 cabins
  {
    id: "cabin-10",
    map_id: "map-2",
    name: "Alex's Station",
    type: "desk",
    link_url: "https://meet.google.com/tech-alex",
    x: 200,
    y: 250,
  },
  {
    id: "cabin-11",
    map_id: "map-2",
    name: "James's Station",
    type: "desk",
    link_url: "https://zoom.us/j/111222333",
    x: 500,
    y: 250,
  },
  {
    id: "cabin-12",
    map_id: "map-2",
    name: "Innovation Lab",
    type: "room",
    link_url: "https://meet.google.com/innovation-lab",
    x: 350,
    y: 450,
  },
];

// Mock presence
export const presence: Presence[] = [
  {
    id: "pres-1",
    user_id: "user-1",
    organization_id: "org-1",
    cabin_id: "cabin-1",
    status: "active",
    updated_at: "2026-02-15T14:30:00Z",
  },
  {
    id: "pres-2",
    user_id: "user-2",
    organization_id: "org-1",
    cabin_id: "cabin-5",
    status: "in_room",
    updated_at: "2026-02-15T14:25:00Z",
  },
  {
    id: "pres-3",
    user_id: "user-3",
    organization_id: "org-1",
    cabin_id: "cabin-3",
    status: "away",
    updated_at: "2026-02-15T14:00:00Z",
  },
  {
    id: "pres-4",
    user_id: "user-4",
    organization_id: "org-1",
    cabin_id: "cabin-4",
    status: "dnd",
    custom_message: "Deep work session",
    updated_at: "2026-02-15T14:15:00Z",
  },
];

// Mock events
export const events: Event[] = [
  {
    id: "evt-1",
    organization_id: "org-1",
    from_user_id: "user-2",
    to_user_id: "user-1",
    type: "ring",
    created_at: "2026-02-15T14:20:00Z",
  },
];

// Helper functions
export function getUserById(userId: string): User | undefined {
  return users.find((u) => u.id === userId);
}

export function getOrganizationById(orgId: string): Organization | undefined {
  return organizations.find((o) => o.id === orgId);
}

export function getMembersByOrganization(orgId: string): OrganizationMember[] {
  return organizationMembers.filter((m) => m.organization_id === orgId);
}

export function getMapByOrganization(orgId: string): Map | undefined {
  return maps.find((m) => m.organization_id === orgId);
}

export function getCabinsByMap(mapId: string): Cabin[] {
  return cabins.filter((c) => c.map_id === mapId);
}

export function getPresenceByOrganization(orgId: string): Presence[] {
  return presence.filter((p) => p.organization_id === orgId);
}

export function getUserPresence(
  userId: string,
  orgId: string,
): Presence | undefined {
  return presence.find(
    (p) => p.user_id === userId && p.organization_id === orgId,
  );
}

export function getActiveUsersInOrganization(orgId: string): number {
  return presence.filter(
    (p) => p.organization_id === orgId && p.status === "active",
  ).length;
}

export function getUsersInCabin(cabinId: string): User[] {
  const presenceInCabin = presence.filter((p) => p.cabin_id === cabinId);
  return presenceInCabin
    .map((p) => getUserById(p.user_id))
    .filter(Boolean) as User[];
}
