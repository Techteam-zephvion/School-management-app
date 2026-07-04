-- A class teacher may add students, but only into the section(s) they are the
-- class teacher of (user request). Admins keep full control. Implemented as
-- additive INSERT policies so class teachers gain insert-only rights -- update
-- and delete of students/enrollments stay admin-only via the existing *_write
-- policies.

-- Section ids where the caller is the class teacher (via their staff row).
-- SECURITY DEFINER to read sections/staff without tripping their own RLS.
create or replace function private.class_teacher_section_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select sec.id
  from public.sections sec
  join public.staff st on st.id = sec.class_teacher_staff_id
  where st.user_id = auth.uid();
$$;

grant execute on function private.class_teacher_section_ids() to authenticated, anon;

-- True when the caller is a class teacher of at least one section in the school.
create or replace function private.is_class_teacher_of_school(p_school uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.sections sec
    join public.staff st on st.id = sec.class_teacher_staff_id
    where st.user_id = auth.uid() and sec.school_id = p_school
  );
$$;

grant execute on function private.is_class_teacher_of_school(uuid) to authenticated, anon;

-- A class teacher can create student records in their school...
create policy students_insert_class_teacher on public.students
for insert with check (private.is_class_teacher_of_school(school_id));

-- ...and enrol them, but only into a section they class-teach.
create policy enrollments_insert_class_teacher on public.enrollments
for insert with check (section_id in (select private.class_teacher_section_ids()));
