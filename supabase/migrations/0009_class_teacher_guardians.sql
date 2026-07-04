-- Extend the class-teacher powers (0008): a class teacher may also link/unlink
-- guardians, but only for students actively enrolled in a section they
-- class-teach. Admins keep full control via the existing student_guardians_write.

-- Student ids actively enrolled in a section the caller class-teaches.
-- SECURITY DEFINER to read enrollments/sections/staff past their own RLS.
create or replace function private.my_class_student_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select e.student_id
  from public.enrollments e
  join public.sections sec on sec.id = e.section_id
  join public.staff st on st.id = sec.class_teacher_staff_id
  where st.user_id = auth.uid()
    and e.status = 'active';
$$;

grant execute on function private.my_class_student_ids() to authenticated, anon;

-- Additive: a class teacher can link a guardian to one of their students...
create policy student_guardians_insert_class_teacher on public.student_guardians
for insert with check (student_id in (select private.my_class_student_ids()));

-- ...and unlink one (e.g. a mistaken invite) for their students.
create policy student_guardians_delete_class_teacher on public.student_guardians
for delete using (student_id in (select private.my_class_student_ids()));
