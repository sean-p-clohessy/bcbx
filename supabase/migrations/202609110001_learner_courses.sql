-- Let administrators assign and update a learner's course while accepting
-- display-name initials with or without a trailing full stop.
create or replace function public.admin_save_learner(
  target_id uuid,
  new_display_name text,
  new_course_group text,
  is_active boolean
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  result_id uuid;
begin
  perform public.require_admin();

  if trim(new_display_name) !~ '^.+ [A-Za-z]\.?$' then
    raise exception 'Use a display name such as Jessica T or Jessica T.';
  end if;

  if nullif(trim(new_course_group), '') is null then
    raise exception 'Choose a course';
  end if;

  if char_length(trim(new_course_group)) > 80 then
    raise exception 'Course is too long';
  end if;

  if target_id is null then
    insert into public.learners(display_name, course_group, active)
    values (trim(new_display_name), trim(new_course_group), is_active)
    returning id into result_id;
  else
    update public.learners
       set display_name=trim(new_display_name),
           course_group=trim(new_course_group),
           active=is_active
     where id=target_id
     returning id into result_id;
  end if;

  return result_id;
end
$$;

grant execute on function public.admin_save_learner(uuid,text,text,boolean) to authenticated;
