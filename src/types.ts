export type Role = 'staff' | 'admin'
export interface LeaderboardRow { learner_id:string; display_name:string; credits:number; portfolio_value:number; month_value:number; first_achieved_at:string|null }
export interface ActivityRow { investment_id:string; learner_name:string; staff_ticker:string; business_value:string; amount:number; created_at:string }
export interface BusinessValue { id:string; name:string; description:string; active:boolean; sort_order:number }
export interface Learner { id:string; display_name:string; active:boolean; created_at?:string }
export interface StaffProfile { id:string; email:string; display_name:string; ticker:string; role:Role; active:boolean }
export interface StaffInvestment extends ActivityRow { business_value_id?:string }
export interface AdminStaff { id:string; email:string; display_name:string; ticker:string; role:Role; active:boolean; auth_user_id:string|null }
