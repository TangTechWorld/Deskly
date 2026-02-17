import z from "zod";

const ConfigSchema = z.object({
  SUPABASE_URL: z.url(),
  SUPABASE_KEY: z.string(),
});

const config = {
  SUPABASE_URL: process.env["NEXT_PUBLIC_SUPABASE_URL"] ?? "",
  SUPABASE_KEY:
    process.env["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY"] ?? "",
};

export const env = Object.freeze(ConfigSchema.parse(config));
