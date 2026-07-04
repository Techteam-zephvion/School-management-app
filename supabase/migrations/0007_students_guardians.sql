-- Phase 3: students, enrollments, guardian links (doc 05 §4, doc 06 Phase 3).
-- student_guardians is the key that lets a parent see exactly their children;
-- my_children() (SECURITY DEFINER) reads it and is used across later RLS.

-- ---- students ----
create table public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  admission_no text not null,
  first_name text not null,
  last_name text,
  dob date,
  gender gender,
  photo_url text,
  blood_group text,
  address text,
  status enroll_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, admission_no)
);

-- ---- enrollments (student <-> section for an academic year) ----
create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  section_id uuid not null references public.sections (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  roll_no text,
  status enroll_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- At most one ACTIVE enrollment per student per academic year.
create unique index enrollments_one_active_per_year
  on public.enrollments (student_id, academic_year_id)
  where status = 'active';

-- ---- student_guardians (parent link) ----
create table public.student_guardians (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  guardian_user_id uuid not null references public.profiles (id) on delete cascade,
  relation text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, guardian_user_id)
);

-- ---- indexes ----
create index students_school_idx on public.students (school_id);
create index enrollments_student_idx on public.enrollments (student_id);
create index enrollments_section_idx on public.enrollments (section_id);
create index enrollments_year_idx on public.enrollments (academic_year_id);
create index student_guardians_guardian_idx on public.student_guardians (guardian_user_id);
create index student_guardians_student_idx on public.student_guardians (student_id);

-- ---- updated_at triggers ----
create trigger set_updated_at before update on public.students
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.enrollments
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.student_guardians
  for each row execute function public.set_updated_at();

-- ---- my_children(): the student_ids the caller is a guardian of (doc 05 §12) ----
-- SECURITY DEFINER so it bypasses student_guardians' own RLS (a policy calling
-- it must not recurse) and so students/enrollments policies can trust it.
create or replace function private.my_children()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select student_id from public.student_guardians
  where guardian_user_id = auth.uid();
$$;

grant execute on function private.my_children() to authenticated, anon;

-- Schools where the caller is STAFF (admin/teacher). auth_school_ids() also
-- returns schools a user belongs to as a *parent*, which must NOT grant the
-- broad "staff of school" read over students/guardians -- a parent is limited
-- to their own children (doc 05 §12).
create or replace function private.auth_staff_school_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select school_id from public.school_members
  where user_id = auth.uid()
    and status = 'active'
    and role in ('school_admin', 'teacher');
$$;

grant execute on function private.auth_staff_school_ids() to authenticated, anon;

-- ---- grants (new tables are not auto-exposed; see 0003 note) ----
grant select, insert, update, delete on public.students to anon, authenticated, service_role;
grant select, insert, update, delete on public.enrollments to anon, authenticated, service_role;
grant select, insert, update, delete on public.student_guardians to anon, authenticated, service_role;

-- ---- RLS ----
alter table public.students enable row level security;
alter table public.enrollments enable row level security;
alter table public.student_guardians enable row level security;

-- students: staff of the school read all; a parent reads only their children.
create policy students_select on public.students
for select using (
  school_id in (select private.auth_staff_school_ids())
  or id in (select private.my_children())
  or private.is_platform_admin()
);
create policy students_write on public.students
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- enrollments: same read scope (parent sees their child's enrollment).
create policy enrollments_select on public.enrollments
for select using (
  school_id in (select private.auth_staff_school_ids())
  or student_id in (select private.my_children())
  or private.is_platform_admin()
);
create policy enrollments_write on public.enrollments
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- student_guardians: staff of the school, or the guardian themselves (a parent
-- must not read other families' guardian links in the same school).
create policy student_guardians_select on public.student_guardians
for select using (
  school_id in (select private.auth_staff_school_ids())
  or guardian_user_id = auth.uid()
  or private.is_platform_admin()
);
create policy student_guardians_write on public.student_guardians
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());
