-- DEMO DATA ONLY. Do not run in production, or clear it before launch.
insert into public.learners(display_name) values ('Jessica T.'),('Liam P.'),('Amelia R.'),('Oliver S.'),('Sophia R.'),('Noah D.'),('Ethan W.'),('Mia K.');
insert into public.staff(email,display_name,ticker,role) values
('scap@example.invalid','Demo Staff A','SCAP','staff'),('scbx@example.invalid','Demo Staff B','SCBX','staff'),
('jhbx@example.invalid','Demo Staff C','JHBX','staff'),('mgbx@example.invalid','Demo Staff D','MGBX','staff'),
('ksbx@example.invalid','Demo Staff E','KSBX','staff'),('lsmx@example.invalid','Demo Staff F','LSMX','staff'),('dmbx@example.invalid','Demo Staff G','DMBX','staff');
do $$ declare learners uuid[]; staffers uuid[]; values_ uuid[]; n integer; li integer; begin
 select array_agg(id order by display_name) into learners from public.learners;
 select array_agg(id order by ticker) into staffers from public.staff;
 select array_agg(id order by sort_order) into values_ from public.business_values;
 -- 22, 19, 17, 13, 10, 8, 5 and 2 investments: covers milestones and £1M+.
 for li in 1..8 loop for n in 1..(array[17,5,22,19,2,8,13,10])[li] loop
  insert into public.investments(learner_id,staff_id,business_value_id,created_at) values(learners[li],staffers[1+((n+li)%array_length(staffers,1))],values_[1+((n+li)%6)],now()-make_interval(days => case when n<=li%4+1 then n else 35+n end,hours => n));
 end loop; end loop; end $$;
