import { createClient } from "@supabase/supabase-js";
import { env } from "./config";

interface UsersTable {
  Row: {
    id: string;
    name: string;
    image_url: string;
  };
  Insert: {
    id: string;
    name: string;
    image_url: string;
  };
  Update: {
    id?: string;
    name?: string;
    image_url?: string;
  };
  Relationships: [];
}

type GenericTable = {
  Row: Record<string, unknown>;
  Insert: Record<string, unknown>;
  Update: Record<string, unknown>;
  Relationships: [];
};

export interface Database {
  public: {
    Tables: {
      users: UsersTable;
      [key: string]: GenericTable;
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}

type SupabaseClient = ReturnType<typeof createClient<Database>>;

interface AppServicesConfig {
  supabaseUrl: string;
  supabaseKey: string;
}

interface AppServices {
  supabase: SupabaseClient;
}

export function createAppServices(config: AppServicesConfig): AppServices {
  return {
    supabase: createClient<Database>(config.supabaseUrl, config.supabaseKey),
  };
}

let appServices: AppServices | null = null;

export function getAppServices(): AppServices {
  appServices ??= createAppServices({
    supabaseUrl: env.SUPABASE_URL,
    supabaseKey: env.SUPABASE_KEY,
  });

  return appServices;
}

export const supabase = getAppServices().supabase;
