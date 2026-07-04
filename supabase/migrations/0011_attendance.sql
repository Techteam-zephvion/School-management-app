-- Phase 4: attendance (doc 05 §5, doc 06 Phase 4).
-- Two modes on one table:
--   * daily    -> subject_id IS NULL : marked by the class teacher (or admin)
--   * subject  -> subject_id set     : marked by that subject's teacher (or admin)
-- (The doc uses period_id for the second mode; periods arrive with the timetable
--  in Phase 6, so we key subject-wise attendance off subject_id for now.)

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  section_id uuid not null references public.sections (id) on delete cascade,
  date date not null,
  subject_id uuid references public.subjects (id) on delete cascade,
  status attend_status not null,
  marked_by uuid references public.profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Idempotent marking: one daily record per student/day, one per student/day/subject.
create unique index attendance_daily_uniq
  on public.attendance (student_id, date)
  where subject_id is null;
create unique index attendance_subject_uniq
  on public.attendance (student_id, date, subject_id)
  where subject_id is not null;

create index attendance_section_date_idx on public.attendance (section_id, date);
create index attendance_student_date_idx on public.attendance (student_id, date);

create trigger set_updated_at before update on public.attendance
  for each row execute function public.set_updated_at();

-- Who may mark attendance for a (section, subject) cell:
--   admin of the school; or the class teacher of the section (daily only);
--   or the assigned subject teacher (subject only). SECURITY DEFINER so the
--   policy can read sections/staff/teacher_assignments past their own RLS.
create or replace function private.can_mark_attendance(p_section uuid, p_subject uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.sections sec
    where sec.id = p_section
      and (
        private.has_role(sec.school_id, 'school_admin')
        or private.is_platform_admin()
        or (
          p_subject is null
          and exists (
            select 1 from public.staff st
            where st.id = sec.class_teacher_staff_id and st.user_id = auth.uid()
          )
        )
        or (
          p_subject is not null
          and exists (
            select 1 from public.teacher_assignments ta
            join public.staff st on st.id = ta.staff_id
            where ta.section_id = p_section
              and ta.subject_id = p_subject
              and st.user_id = auth.uid()
          )
        )
      )
  );
$$;

grant execute on function private.can_mark_attendance(uuid, uuid) to authenticated, anon;

grant select, insert, update, delete on public.attendance to anon, authenticated, service_role;

alter table public.attendance enable row level security;

-- Read: staff of the school see all; a parent sees only their own child.
create policy attendance_select on public.attendance
for select using (
  school_id in (select private.auth_staff_school_ids())
  or student_id in (select private.my_children())
  or private.is_platform_admin()
);

-- Write (insert/update/delete): only someone authorised for that cell.
create policy attendance_write on public.attendance
for all
using (private.can_mark_attendance(section_id, subject_id))
with check (private.can_mark_attendance(section_id, subject_id));
