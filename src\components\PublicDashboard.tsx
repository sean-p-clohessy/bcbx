import { useCallback,useEffect,useMemo,useState } from 'react'
import type { ActivityRow,LeaderboardRow } from '../types'
import { compactMoney,money,relativeTime } from '../lib/format'
import { configured,rpc } from '../lib/supabase'
import { ErrorState,Loading } from './Loading'
import { ValueChip } from './ValueChip'

const demoLeaders:LeaderboardRow[]=[
 {learner_id:'1',display_name:'Jessica T.',credits:22,portfolio_value:1100000,month_value:150000,first_achieved_at:new Date().toISOString()},
 {learner_id:'2',display_name:'Liam P.',credits:19,portfolio_value:950000,month_value:100000,first_achieved_at:new Date().toISOString()},
 {learner_id:'3',display_name:'Amelia R.',credits:17,portfolio_value:850000,month_value:50000,first_achieved_at:new Date().toISOString()},
 {learner_id:'4',display_name:'Oliver S.',credits:13,portfolio_value:650000,month_value:100000,first_achieved_at:new Date().toISOString()},
]
const demoActivity:ActivityRow[]=[
 {investment_id:'1',learner_name:'Jessica T.',staff_ticker:'SCAP',business_value:'Initiative',amount:50000,created_at:new Date(Date.now()-120000).toISOString()},
 {investment_id:'2',learner_name:'Liam P.',staff_ticker:'JHBX',business_value:'Professionalism',amount:50000,created_at:new Date(Date.now()-900000).toISOString()},
 {investment_id:'3',learner_name:'Amelia R.',staff_ticker:'MGBX',business_value:'Progress',amount:50000,created_at:new Date(Date.now()-3600000).toISOString()},
]
export function PublicDashboard(){
 const [leaders,setLeaders]=useState<LeaderboardRow[]>([]),[activity,setActivity]=useState<ActivityRow[]>([]),[loading,setLoading]=useState(true),[error,setError]=useState('')
 const load=useCallback(async()=>{setLoading(true);setError('');try{if(!configured){setLeaders(demoLeaders);setActivity(demoActivity)}else{const [l,a]=await Promise.all([rpc<LeaderboardRow[]>('public_leaderboard'),rpc<ActivityRow[]>('public_recent_activity',{result_limit:20})]);setLeaders(l||[]);setActivity(a||[])}}catch(e){setError(e instanceof Error?e.message:'Unknown error')}finally{setLoading(false)}},[])
 useEffect(()=>{void load();if(!configured)return;const id=window.setInterval(load,60000);return()=>clearInterval(id)},[load])
 const stats=useMemo(()=>({top:[...leaders].sort((a,b)=>b.month_value-a.month_value)[0],members:leaders.filter(x=>x.portfolio_value>=1_000_000).length,count:leaders.reduce((n,x)=>n+x.credits,0),total:leaders.reduce((n,x)=>n+x.portfolio_value,0)}),[leaders])
 if(loading)return <Loading/>; if(error)return <ErrorState message={error} onRetry={load}/>
 return <>
  {!configured&&<div className="demo-banner">Preview data — connect Supabase to use the live database.</div>}
  <section className="hero"><div><p className="eyebrow">Millionaires Club</p><h1>Live Rich List</h1><p className="hero-copy">Track your progress to £1,000,000 through BCBX investments.</p></div><div className="market-status"><span/> LIVE MARKET</div></section>
  <div className="ticker" aria-label="Recent BCBX investments"><div className="ticker-track">{activity.length?activity.concat(activity).map((x,i)=><span key={`${x.investment_id}-${i}`}><b>{x.staff_ticker}</b> invested £50K in {x.learner_name} <i>• {x.business_value}</i></span>):<span>The BCBX market is opening soon.</span>}</div></div>
  <section className="stats-grid" aria-label="Market summary">
   <article><span>Top Earner This Month</span><strong>{stats.top?.display_name||'—'}</strong><em>{stats.top?`+${compactMoney(stats.top.month_value)}`:'No investments yet'}</em></article>
   <article><span>Millionaires Club Members</span><strong>{stats.members}</strong><em>£1M+ portfolios</em></article>
   <article><span>Investments Awarded</span><strong>{stats.count}</strong><em>£50K each</em></article>
   <article><span>Total BCBX Investment</span><strong>{money(stats.total)}</strong><em>Fictional recognition value</em></article>
  </section>
  <div className="dashboard-grid">
   <section className="panel leaderboard"><div className="panel-heading"><div><p className="eyebrow">Race to a Million</p><h2>The Rich List</h2></div><span>Updated live</span></div>
    {leaders.length?<div className="table-wrap"><table><thead><tr><th>Rank</th><th>Learner</th><th>Portfolio Value</th><th>Credits</th><th>Change This Month</th></tr></thead><tbody>{leaders.map((x,i)=><tr key={x.learner_id} className={i<3?`rank-${i+1}`:''}><td><span className="rank">{i+1}</span></td><td><b>{x.display_name}</b>{x.portfolio_value>=1_000_000&&<small>Millionaires Club</small>}</td><td className="money">{money(x.portfolio_value)}</td><td>{x.credits}</td><td className="positive">+{money(x.month_value)}</td></tr>)}</tbody></table></div>:<Empty/>}
   </section>
   <aside className="side-stack"><section className="panel"><div className="panel-heading"><h2>This Month’s Top Earners</h2></div>{leaders.filter(x=>x.month_value>0).sort((a,b)=>b.month_value-a.month_value).slice(0,5).map((x,i)=><div className="top-earner" key={x.learner_id}><span>{i+1}</span><b>{x.display_name}</b><em>+{compactMoney(x.month_value)}</em></div>)}</section>
   <section className="panel"><div className="panel-heading"><h2>Recent Investments</h2></div>{activity.slice(0,6).map(x=><article className="activity" key={x.investment_id}><div><b>{x.staff_ticker}</b> invested <strong>£50K</strong> in <b>{x.learner_name}</b></div><footer><ValueChip name={x.business_value}/><time>{relativeTime(x.created_at)}</time></footer></article>)}</section></aside>
  </div>
  <section id="how" className="explainer"><p className="eyebrow">How it works</p><h2>Every investment matters.</h2><div>{['Demonstrate one of our Business Values','Your lecturer invests £50K in you','Your portfolio grows','Reach £250K, £500K and £750K milestones','Reach £1M and join the Millionaires Club'].map((x,i)=><article key={x}><span>0{i+1}</span><p>{x}</p></article>)}</div><strong>There is no limit. Keep earning investment and keep climbing the Rich List.</strong></section>
  <section id="milestones" className="milestones">{[['£250K','First Milestone'],['£500K','Half Million'],['£750K','Final Stretch'],['£1M','Millionaires Club']].map(([a,b])=><article key={a}><strong>{a}</strong><span>{b}</span></article>)}</section>
 </>
}
function Empty(){return <div className="empty"><h3>The BCBX market is opening soon.</h3><p>No investments have been recorded yet. Make the first investment from the staff dashboard.</p></div>}
