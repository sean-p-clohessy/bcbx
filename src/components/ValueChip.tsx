export function ValueChip({name}:{name:string}){return <span className={`value-chip value-${name.toLowerCase().replace(/[^a-z]+/g,'-')}`}>{name}</span>}
