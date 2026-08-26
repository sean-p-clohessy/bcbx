-- BCBX V1. Run in a new Supabase project using the SQL editor or Supabase CLI.
create extension if not exists pgcrypto;

create type public.staff_role as enum ('staff','admin');
create table public.learners (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (display_name ~ '^.+ [A-Z]\\.$'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.staff (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  email text unique not null check (email = lower(email)),
  display_name text not null,
  ticker text unique not null check (ticker ~ '^[A-Z]{3,6}$'),
  role public.staff_role not null default 'staff',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.business_values (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  description text not null,
  active boolean not null default true,
  sort_order integer not null unique
);
create table public.investments (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.learners(id) on delete restrict,
  staff_id uuid not null references public.staff(id) on delete restrict,
  business_value_id uuid not null references public.business_values(id) on delete restrict,
  amount integer not null default 50000 check (amount = 50000),
  created_at timestamptz not null default now()
);
create table public.investment_corrections (
  id uuid primary key default gen_random_uuid(),
  investment_id uuid not null,
  learner_id uuid not null,
  staff_id uuid not null,
  business_value_id uuid not null,
  amount integer not null,
  original_created_at timestamptz not null,
  deleted_by uuid not null references public.staff(id),
  deleted_at timestamptz not null default now()
);
create index investments_learner_created_idx on public.investments(learner_id,created_at);
create index investments_staff_created_idx on public.investments(staff_id,created_at desc);

insert into public.business_values(name,description,sort_order) values
('Initiative','Spot opportunities, take action and show initiative beyond what is expected.',1),
('Excellence','Produce high-quality work and demonstrate excellent knowledge and understanding.',2),
('Professionalism','Show outstanding professionalism, reliability and communication, and represent the department positively.',3),
('Leadership & Contribution','Support and inspire others, lead by example and make a positive contribution to the team or class.',4),
('Progress','Make significant improvement and demonstrate determination to develop skills and performance.',5),
('Going Beyond','Take part in additional activities, competitions, projects, employer opportunities or experiences beyond normal expectations.',6);

alter table public.learners enable row level security;
alter table public.staff enable row level security;
alter table public.business_values enable row level security;
alter table public.investments enable row level security;
alter table public.investment_corrections enable row level security;

-- No direct table grants are required. All application access is through narrow functions.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

create or replace function public.current_staff()
returns public.staff language sql stable security definer set search_path=public as $$
  select s from public.staff s where s.auth_user_id=auth.uid() and s.active limit 1
$$;

create or replace function public.my_staff_profile()
returns table(id uuid,email text,display_name text,ticker text,role public.staff_role,active boolean)
language sql stable security definer set search_path=public as $$
  select s.id,s.email,s.display_name,s.ticker,s.role,s.active from public.staff s where s.auth_user_id=auth.uid()
$$;

create or replace function public.public_leaderboard()
returns table(learner_id uuid,display_name text,credits bigint,portfolio_value bigint,month_value bigint,first_achieved_at timestamptz)
language sql stable security definer set search_path=public as $$
  with totals as (
    select l.id,l.display_name,count(i.id) credits,coalesce(sum(i.amount),0)::bigint portfolio_value,
      coalesce(sum(i.amount) filter(where i.created_at>=date_trunc('month',now())),0)::bigint month_value,
      max(i.created_at) first_achieved_at
    from public.learners l left join public.investments i on i.learner_id=l.id
    where l.active group by l.id,l.display_name
  ) select * from totals order by portfolio_value desc,first_achieved_at asc nulls last,display_name asc
$$;

create or replace function public.public_recent_activity(result_limit integer default 20)
returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,created_at timestamptz)
language sql stable security definer set search_path=public as $$
 select i.id,l.display_name,s.ticker,b.name,i.amount,i.created_at from public.investments i
 join public.learners l on l.id=i.learner_id join public.staff s on s.id=i.staff_id join public.business_values b on b.id=i.business_value_id
 order by i.created_at desc limit least(greatest(result_limit,1),100)
$$;

create or replace function public.staff_active_learners()
returns setof public.learners language plpgsql stable security definer set search_path=public as $$
begin if public.current_staff() is null then raise exception 'Active staff access required'; end if;
 return query select * from public.learners where active order by display_name; end $$;
create or replace function public.staff_active_business_values()
returns setof public.business_values language plpgsql stable security definer set search_path=public as $$
begin if public.current_staff() is null then raise exception 'Active staff access required'; end if;
 return query select * from public.business_values where active order by sort_order; end $$;

create or replace function public.create_investment(target_learner_id uuid,target_business_value_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=public as $$
declare actor public.staff; learner_name text; value_name text;
begin actor:=public.current_staff(); if actor is null then raise exception 'Active staff access required'; end if;
 select display_name into learner_name from public.learners where id=target_learner_id and active;
 if learner_name is null then raise exception 'Choose an active learner'; end if;
 select name into value_name from public.business_values where id=target_business_value_id and active;
 if value_name is null then raise exception 'Choose an active Business Value'; end if;
 insert into public.investments(learner_id,staff_id,business_value_id) values(target_learner_id,actor.id,target_business_value_id);
 return jsonb_build_object('learner_name',learner_name,'business_value',value_name); end $$;

create or replace function public.my_recent_investments(result_limit integer default 50)
returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,created_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
declare actor public.staff; begin actor:=public.current_staff(); if actor is null then raise exception 'Active staff access required'; end if;
 return query select i.id,l.display_name,actor.ticker,b.name,i.amount,i.created_at from public.investments i join public.learners l on l.id=i.learner_id join public.business_values b on b.id=i.business_value_id where i.staff_id=actor.id order by i.created_at desc limit least(greatest(result_limit,1),100); end $$;

create or replace function public.require_admin() returns public.staff language plpgsql stable security definer set search_path=public as $$
declare actor public.staff; begin actor:=public.current_staff(); if actor is null or actor.role<>'admin' then raise exception 'Administrator access required'; end if; return actor; end $$;
create or replace function public.admin_list_learners() returns setof public.learners language plpgsql stable security definer set search_path=public as $$ begin perform public.require_admin(); return query select * from public.learners order by display_name; end $$;
create or replace function public.admin_add_learner(new_display_name text) returns uuid language plpgsql security definer set search_path=public as $$ declare new_id uuid; begin perform public.require_admin(); insert into public.learners(display_name) values(trim(new_display_name)) returning id into new_id; return new_id; end $$;
create or replace function public.admin_set_learner_active(learner_id uuid,is_active boolean) returns void language plpgsql security definer set search_path=public as $$ begin perform public.require_admin(); update public.learners set active=is_active where id=learner_id; end $$;
create or replace function public.admin_list_staff() returns table(id uuid,email text,display_name text,ticker text,role public.staff_role,active boolean,auth_user_id uuid) language plpgsql stable security definer set search_path=public as $$ begin perform public.require_admin(); return query select s.id,s.email,s.display_name,s.ticker,s.role,s.active,s.auth_user_id from public.staff s order by s.ticker; end $$;
create or replace function public.admin_upsert_staff(staff_email text,staff_display_name text,staff_ticker text,staff_role text) returns uuid language plpgsql security definer set search_path=public as $$ declare result_id uuid; begin perform public.require_admin(); if staff_role not in ('staff','admin') then raise exception 'Invalid role'; end if; insert into public.staff(email,display_name,ticker,role,auth_user_id) values(lower(trim(staff_email)),trim(staff_display_name),upper(trim(staff_ticker)),staff_role::public.staff_role,(select id from auth.users where lower(email)=lower(trim(staff_email)))) on conflict(email) do update set display_name=excluded.display_name,ticker=excluded.ticker,role=excluded.role,auth_user_id=coalesce(public.staff.auth_user_id,excluded.auth_user_id) returning id into result_id; return result_id; end $$;
create or replace function public.admin_set_staff_active(target_staff_id uuid,is_active boolean) returns void language plpgsql security definer set search_path=public as $$ declare actor public.staff; begin actor:=public.require_admin(); if actor.id=target_staff_id and not is_active then raise exception 'You cannot deactivate your own account'; end if; update public.staff set active=is_active where id=target_staff_id; end $$;
create or replace function public.admin_recent_investments(result_limit integer default 100) returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,created_at timestamptz) language plpgsql stable security definer set search_path=public as $$ begin perform public.require_admin(); return query select i.id,l.display_name,s.ticker,b.name,i.amount,i.created_at from public.investments i join public.learners l on l.id=i.learner_id join public.staff s on s.id=i.staff_id join public.business_values b on b.id=i.business_value_id order by i.created_at desc limit least(greatest(result_limit,1),500); end $$;
create or replace function public.admin_delete_investment(target_investment_id uuid) returns void language plpgsql security definer set search_path=public as $$ declare actor public.staff; target public.investments; begin actor:=public.require_admin(); select * into target from public.investments where id=target_investment_id for update; if target is null then raise exception 'Investment not found'; end if; insert into public.investment_corrections(investment_id,learner_id,staff_id,business_value_id,amount,original_created_at,deleted_by) values(target.id,target.learner_id,target.staff_id,target.business_value_id,target.amount,target.created_at,actor.id); delete from public.investments where id=target.id; end $$;

-- Link an already-approved staff record when that exact email first authenticates.
create or replace function public.link_approved_staff() returns trigger language plpgsql security definer set search_path=public as $$ begin update public.staff set auth_user_id=new.id where lower(email)=lower(new.email) and auth_user_id is null; return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.link_approved_staff();

-- PostgreSQL grants EXECUTE to PUBLIC on new functions by default; reset that before the allow-list.
revoke all on all functions in schema public from public,anon,authenticated;
grant execute on function public.public_leaderboard() to anon,authenticated;
grant execute on function public.public_recent_activity(integer) to anon,authenticated;
grant execute on function public.my_staff_profile(),public.staff_active_learners(),public.staff_active_business_values(),public.create_investment(uuid,uuid),public.my_recent_investments(integer),public.admin_list_learners(),public.admin_add_learner(text),public.admin_set_learner_active(uuid,boolean),public.admin_list_staff(),public.admin_upsert_staff(text,text,text,text),public.admin_set_staff_active(uuid,boolean),public.admin_recent_investments(integer),public.admin_delete_investment(uuid) to authenticated;

-- Keep internal helper functions inaccessible to API roles.
comment on table public.learners is 'Minimal learner data only: UUID, public display name and active state.';
comment on table public.investment_corrections is 'Immutable minimal audit record for admin-deleted erroneous investments; contains no narrative.';
