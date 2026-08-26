import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
export const configured = Boolean(url && key)
export const supabase = configured ? createClient(url!, key!, { auth: { persistSession:true, autoRefreshToken:true, detectSessionInUrl:true, flowType:'pkce' } }) : null

// The PKCE callback uses ?code= rather than a fragment, leaving the hash router intact.
export const authRedirectUrl = () => `${window.location.origin}${import.meta.env.BASE_URL}`

export async function rpc<T>(name:string, args:Record<string,unknown> = {}):Promise<T> {
  if (!supabase) throw new Error('Supabase is not configured. Add the VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY environment variables.')
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw error
  return data as T
}
