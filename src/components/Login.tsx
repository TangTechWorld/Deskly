"use client";
import { createUser, getUserById } from "@/services/userService";
import { getAppServices } from "@/utils/supabase";
import { setCurrentUser } from "@/utils/user-store";
import { Session } from "@supabase/supabase-js";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { ConfirmProfileDialog } from "./ConfirmProfileDialog";
import { OAuthDialog } from "./OAuthDialog";

export function Login({ children }: { children: React.ReactNode }) {
  const [oauthDialogOpen, setOAuthDialogOpen] = useState(false);
  const [profileDialogOpen, setProfileDialogOpen] = useState(false);
  const [name, setName] = useState("");
  const [avatarLogo, setAvatarLogo] = useState("");
  const [pendingUserId, setPendingUserId] = useState<string | null>(null);
  const [isConfirmingProfile, setIsConfirmingProfile] = useState(false);
  const resolvedSessionIdRef = useRef<string | null>(null);
  const { supabase } = getAppServices();
  const router = useRouter();

  const resolveSessionUser = useCallback(
    async (sessionFromAuth?: Session) => {
      const session =
        sessionFromAuth ?? (await supabase.auth.getSession()).data.session;

      if (session === null) {
        return false;
      }

      const userRecord = await getUserById(session.user.id);

      if (userRecord !== null) {
        setCurrentUser({
          id: userRecord.id,
          name: userRecord.name,
          imageUrl: userRecord.image_url,
        });
        setOAuthDialogOpen(false);
        router.replace("/orgs");
        return true;
      }

      const nextName =
        typeof session.user.user_metadata["full_name"] === "string"
          ? session.user.user_metadata["full_name"]
          : "";
      const nextImageUrl =
        typeof session.user.user_metadata["avatar_url"] === "string"
          ? session.user.user_metadata["avatar_url"]
          : "";

      setName(nextName);
      setAvatarLogo(nextImageUrl);
      setPendingUserId(session.user.id);
      setOAuthDialogOpen(false);
      setProfileDialogOpen(true);

      return false;
    },
    [router, supabase],
  );

  const openLogin = async () => {
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (session === null) {
      setOAuthDialogOpen(true);
      return;
    }

    await resolveSessionUser(session);
  };

  const confirmProfile = async () => {
    if (
      pendingUserId === null ||
      name.trim().length === 0 ||
      isConfirmingProfile
    ) {
      return;
    }

    setIsConfirmingProfile(true);
    const createdUser = await createUser({
      id: pendingUserId,
      name: name.trim(),
      image_url: avatarLogo.trim(),
    });

    setIsConfirmingProfile(false);

    if (createdUser === null) {
      return;
    }

    setCurrentUser({
      id: createdUser.id,
      name: createdUser.name,
      imageUrl: createdUser.image_url,
    });
    setProfileDialogOpen(false);
    router.replace("/orgs");
  };

  const handleLogin = async (provider: "google" | "github") => {
    await supabase.auth.signInWithOAuth({ provider });
  };

  const handleLogout = async () => {
    setCurrentUser(null);
    setProfileDialogOpen(false);
    setOAuthDialogOpen(false);
    await supabase.auth.signOut();
  };

  useEffect(() => {
    const checkAuth = async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (session === null) {
        return;
      }

      if (resolvedSessionIdRef.current === session.user.id) {
        return;
      }

      resolvedSessionIdRef.current = session.user.id;
      await resolveSessionUser(session);
    };

    void checkAuth();
  }, [resolveSessionUser, supabase]);

  return (
    <>
      <span onClick={() => void openLogin()}>{children}</span>
      <OAuthDialog
        open={oauthDialogOpen}
        onOpenChange={setOAuthDialogOpen}
        onGoogleClick={() => handleLogin("google")}
        onGithubClick={() => handleLogin("github")}
      />
      <ConfirmProfileDialog
        open={profileDialogOpen}
        onOpenChange={setProfileDialogOpen}
        name={name}
        onNameChange={setName}
        avatarLogo={avatarLogo}
        onAvatarChange={(imageUrl) => {
          setAvatarLogo(imageUrl);
        }}
        isSubmitting={isConfirmingProfile}
        onConfirm={confirmProfile}
        onLogout={handleLogout}
      />
    </>
  );
}
