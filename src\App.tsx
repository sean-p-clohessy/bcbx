import { useEffect,useState } from 'react'
import { Logo } from './components/Logo'
import { PublicDashboard } from './components/PublicDashboard'
import { StaffArea } from './components/StaffArea'
import { supabase } from './lib/supabase'
import './styles.css'
const route=()=>window.location.hash.startsWith('#/staff')?'staff':'public'
export default function App(){const [page,setPage]=useState(route());useEffect(()=>{const f=()=>setPage(route());const finishCallback=()=>{if(new URLSearchParams(location.search).has('code')){history.replaceState({},'',`${location.pathname}#/staff`);f()}};addEventListener('hashchange',f);if(supabase)void supabase.auth.getSession().then(({data})=>{if(data.session)finishCallback()});const {data}=supabase?.auth.onAuthStateChange((event)=>{if(event==='SIGNED_IN')finishCallback()})||{data:null};return()=>{removeEventListener('hashchange',f);data?.subscription.unsubscribe()}},[]);return <div className="app"><header><Logo/><nav>{page==='public'?<><a href="#/">Rich List</a><a href="#how">How It Works</a><a href="#milestones">Milestones</a><a className="staff-link" href="#/staff">Staff portal</a></>:<a href="#/">← Public Rich List</a>}</nav></header><main>{page==='public'?<PublicDashboard/>:<StaffArea/>}</main><footer><Logo/><p>BCBX investments are fictional and used for learner recognition only.</p><p>Formal praise records remain in ProMonitor.</p></footer></div>}
