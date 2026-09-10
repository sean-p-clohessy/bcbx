begin;
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='learners' and column_name='course_group') then raise exception 'FAIL course_group missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='investments' and column_name='request_id') then raise exception 'FAIL request_id missing'; end if;
 if has_table_privilege('anon','public.staff','select') then raise exception 'FAIL anon can read staff'; end if;
 if has_table_privilege('authenticated','public.investments','insert') then raise exception 'FAIL browser can bypass investment RPC'; end if;
end $$;
select 'PASS: operational columns and direct-table isolation' as result;
rollback;
