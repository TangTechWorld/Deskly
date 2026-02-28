import { getAppServices } from "@/utils/supabase";
import { z } from "zod";

// Zod schemas for validation
export const UserSchema = z.object({
  id: z.uuid(),
  name: z.string().min(1, "Name is required"),
  image_url: z.url("Invalid image URL").or(z.literal("")),
});

export type User = z.infer<typeof UserSchema>;

// Service functions
export async function getUserById(userId: string): Promise<User | null> {
  const { supabase } = getAppServices();

  const { data, error } = await supabase
    .from("users")
    .select("id, name, image_url")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    return null;
  }

  if (data === null) {
    return null;
  }

  try {
    return UserSchema.parse(data);
  } catch {
    return null;
  }
}

export async function createUser(input: {
  id: string;
  name: string;
  image_url: string;
}): Promise<User | null> {
  const { supabase } = getAppServices();

  // Validate input before sending to Supabase
  try {
    UserSchema.parse(input);
  } catch {
    return null;
  }

  const { data, error } = await supabase
    .from("users")
    .insert({
      id: input.id,
      name: input.name,
      image_url: input.image_url,
    })
    .select("id, name, image_url")
    .single();

  if (error) {
    return null;
  }

  if (data === null) {
    return null;
  }

  try {
    return UserSchema.parse(data);
  } catch {
    return null;
  }
}
