import { createClient } from '@supabase/supabase-js';

/**
 * يتم جلب هذه القيم من متغيرات البيئة.
 * في بيئة Vite، نستخدم import.meta.env.VITE_...
 * في بيئة Node.js (Backend)، نستخدم process.env....
 */
const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL as string) || 
                    (window as any)._env_?.SUPABASE_URL;

const supabaseAnonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY as string) || 
                        (window as any)._env_?.SUPABASE_ANON_KEY;

const finalUrl = supabaseUrl || 'https://placeholder-if-missing.supabase.co';
const finalKey = supabaseAnonKey || 'placeholder-key';

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn("Supabase credentials missing. Check Docker build ARGs.");
}

export const supabase = createClient(finalUrl, finalKey);
