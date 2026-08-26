export const money = (value:number) => new Intl.NumberFormat('en-GB',{style:'currency',currency:'GBP',maximumFractionDigits:0}).format(value)
export const compactMoney = (value:number) => value >= 1_000_000 ? `£${(value/1_000_000).toFixed(value%1_000_000?1:0)}M` : `£${value/1000}K`
export const relativeTime = (iso:string) => { const seconds=Math.max(1,Math.floor((Date.now()-new Date(iso).getTime())/1000)); if(seconds<60)return `${seconds}s ago`; if(seconds<3600)return `${Math.floor(seconds/60)}m ago`; if(seconds<86400)return `${Math.floor(seconds/3600)}h ago`; return `${Math.floor(seconds/86400)}d ago` }
export const dateTime = (iso:string) => new Intl.DateTimeFormat('en-GB',{dateStyle:'medium',timeStyle:'short'}).format(new Date(iso))
