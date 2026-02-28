import { create } from "zustand";

export interface AppUserProfile {
  id: string;
  name: string;
  imageUrl: string;
}

interface UserStoreState {
  currentUser: AppUserProfile | null;
  setCurrentUser: (user: AppUserProfile | null) => void;
}

export const useUserStore = create<UserStoreState>()((set) => ({
  currentUser: null,
  setCurrentUser: (user) => {
    set({ currentUser: user });
  },
}));

export function getCurrentUser() {
  return useUserStore.getState().currentUser;
}

export function setCurrentUser(user: AppUserProfile | null) {
  useUserStore.getState().setCurrentUser(user);
}

export function useCurrentUser() {
  return useUserStore((state) => state.currentUser);
}
