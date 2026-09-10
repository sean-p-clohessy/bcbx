-- BCBX operational-core upgrade. Safe to run once after the V1 migration.
alter table public.learners add column course_group text not null default '' check (length(course_group) <= 80);
alter table public.investments add column public_message text check (char_length(public_message) <= 100);
alter table public.investments add column request_id uuid;
create unique index investments_staff_request_idx on public.investments(staff_id,request_id) where request_id is not null;

drop function if exists public.staff_active_learners();
create function public.staff_active_learners()
returns setof public.learners language plpgsql stable security definer set search_path=public as $$
begin if public.current_staff() is null then raise exception 'Active staff access required'; end if;
 return query select * from public.learners where active order by display_name; end $$;

drop function if exists public.create_investment(uuid,uuid);
create function public.create_investment(target_learner_id uuid,target_business_value_id uuid,recognition_message text default null,client_request_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path=public as $$
declare actor public.staff; learner_name text; value_name text; clean_message text; existing public.investments;
begin actor:=public.current_staff(); if actor is null then raise exception 'Active staff access required'; end if;
 if client_request_id is not null then select * into existing from public.investments where staff_id=actor.id and request_id=client_request_id;
  if existing is not null then select display_name into learner_name from public.learners where id=existing.learner_id; select name into value_name from public.business_values where id=existing.business_value_id; return jsonb_build_object('learner_name',learner_name,'business_value',value_name,'duplicate',true); end if; end if;
 select display_name into learner_name from public.learners where id=target_learner_id and active; if learner_name is null then raise exception 'Choose an active learner'; end if;
 select name into value_name from public.business_values where id=target_business_value_id and active; if value_name is null then raise exception 'Choose an active Business Value'; end if;
 clean_message:=nullif(trim(recognition_message),''); if char_length(clean_message)>100 then raise exception 'Recognition message must be 100 characters or fewer'; end if;
 insert into public.investments(learner_id,staff_id,business_value_id,public_message,request_id) values(target_learner_id,actor.id,target_business_value_id,clean_message,client_request_id);
 return jsonb_build_object('learner_name',learner_name,'business_value',value_name,'duplicate',false); end $$;

drop function if exists public.public_recent_activity(integer);
create function public.public_recent_activity(result_limit integer default 20)
returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,public_message text,created_at timestamptz)
language sql stable security definer set search_path=public as $$
 select i.id,l.display_name,s.ticker,b.name,i.amount,i.public_message,i.created_at from public.investments i join public.learners l on l.id=i.learner_id join public.staff s on s.id=i.staff_id join public.business_values b on b.id=i.business_value_id where l.active order by i.created_at desc limit least(greatest(result_limit,1),100)
$$;

drop function if exists public.my_recent_investments(integer);
create function public.my_recent_investments(result_limit integer default 100)
returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,public_message text,created_at timestamptz)
language plpgsql stable security definer set search_path=public as $$ declare actor public.staff; begin actor:=public.current_staff(); if actor is null then raise exception 'Active staff access required'; end if;
 return query select i.id,l.display_name,actor.ticker,b.name,i.amount,i.public_message,i.created_at from public.investments i join public.learners l on l.id=i.learner_id join public.business_values b on b.id=i.business_value_id where i.staff_id=actor.id order by i.created_at desc limit least(greatest(result_limit,1),500); end $$;

drop function if exists public.admin_recent_investments(integer);
create function public.admin_recent_investments(result_limit integer default 500)
returns table(investment_id uuid,learner_name text,staff_ticker text,business_value text,amount integer,public_message text,created_at timestamptz)
language plpgsql stable security definer set search_path=public as $$ begin perform public.require_admin(); return query select i.id,l.display_name,s.ticker,b.name,i.amount,i.public_message,i.created_at from public.investments i join public.learners l on l.id=i.learner_id join public.staff s on s.id=i.staff_id join public.business_values b on b.id=i.business_value_id order by i.created_at desc limit least(greatest(result_limit,1),1000); end $$;

create function public.admin_save_learner(target_id uuid,new_display_name text,new_course_group text,is_active boolean) returns uuid language plpgsql security definer set search_path=public as $$
declare result_id uuid; begin perform public.require_admin(); if trim(new_display_name)!~'^.+ [A-Z]\.$' then raise exception 'Use a display name such as Jessica T.'; end if; if char_length(trim(new_course_group))>80 then raise exception 'Course/group is too long'; end if;
 if target_id is null then insert into public.learners(display_name,course_group,active) values(trim(new_display_name),trim(new_course_group),is_active) returning id into result_id; else update public.learners set display_name=trim(new_display_name),course_group=trim(new_course_group),active=is_active where id=target_id returning id into result_id; end if; return result_id; end $$;

revoke all on all functions in schema public from public,anon,authenticated;
grant execute on function public.public_leaderboard(),public.public_recent_activity(integer) to anon,authenticated;
grant execute on function public.my_staff_profile(),public.staff_active_learners(),public.staff_active_business_values(),public.create_investment(uuid,uuid,text,uuid),public.my_recent_investments(integer),public.admin_list_learners(),public.admin_add_learner(text),public.admin_set_learner_active(uuid,boolean),public.admin_save_learner(uuid,text,text,boolean),public.admin_list_staff(),public.admin_upsert_staff(text,text,text,text),public.admin_set_staff_active(uuid,boolean),public.admin_recent_investments(integer),public.admin_delete_investment(uuid) to authenticated;
