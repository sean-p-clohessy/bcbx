import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok',{headers:corsHeaders})
  try {
    const url=Deno.env.get('SUPABASE_URL')!, anon=Deno.env.get('SUPABASE_ANON_KEY')!, service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const caller=createClient(url,anon,{global:{headers:{Authorization:request.headers.get('Authorization')??''}}})
    const {data:{user},error:authError}=await caller.auth.getUser()
    if(authError||!user) throw new Error('You must be signed in.')
    const admin=createClient(url,service)
    const {data:staff}=await admin.from('staff').select('role,active').eq('auth_user_id',user.id).maybeSingle()
    if(!staff?.active||staff.role!=='admin') throw new Error('Administrator access required.')
    const body=await request.json()
    if(body.action==='set-password'){
      const targetId=String(body.auth_user_id??''), password=String(body.password??'')
      if(!/^[0-9a-f-]{36}$/i.test(targetId)||password.length<8) throw new Error('Choose a password of at least 8 characters.')
      if(targetId===user.id) throw new Error('Change your own password from Account.')
      const {data:target}=await admin.from('staff').select('id,display_name,active').eq('auth_user_id',targetId).maybeSingle()
      if(!target) throw new Error('That staff login is not linked. Recreate the account to repair it.')
      const {error}=await admin.auth.admin.updateUserById(targetId,{password,email_confirm:true,user_metadata:{display_name:target.display_name}})
      if(error) throw error
      return Response.json({ok:true},{headers:corsHeaders})
    }
    const email=String(body.email??'').trim().toLowerCase(), displayName=String(body.display_name??'').trim(), ticker=String(body.ticker??'').trim().toUpperCase(), role=body.role==='admin'?'admin':'staff', password=String(body.password??'')
    if(!email.endsWith('@boston.ac.uk')||!displayName||!/^[A-Z]{3,6}$/.test(ticker)||password.length<8) throw new Error('Enter a Boston College email, display name, 3–6 letter ticker and password of at least 8 characters.')
    const {data:created,error:createError}=await admin.auth.admin.createUser({email,password,email_confirm:true})
    if(createError) throw createError
    const {error:staffError}=await admin.from('staff').upsert({email,display_name:displayName,ticker,role,active:true,auth_user_id:created.user.id},{onConflict:'email'})
    if(staffError){await admin.auth.admin.deleteUser(created.user.id);throw staffError}
    return Response.json({ok:true},{headers:corsHeaders})
  }catch(error){return Response.json({error:error instanceof Error?error.message:'Unable to create staff account.'},{status:400,headers:corsHeaders})}
})
