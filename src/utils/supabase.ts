import { createClient } from "@supabase/supabase-js";
import { env } from "./config";

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_KEY);

export default supabase;
