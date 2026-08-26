export function Loading({label='Opening the BCBX market…'}:{label?:string}){return <div className="state"><span className="spinner"/><p>{label}</p></div>}
export function ErrorState({message,onRetry}:{message:string;onRetry?:()=>void}){return <div className="state error"><h2>Market data unavailable</h2><p>{message}</p>{onRetry&&<button onClick={onRetry}>Try again</button>}</div>}
