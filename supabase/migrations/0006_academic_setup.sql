-- Phase 2: school & academic structure (doc 05 §3, doc 06 Phase 2).
-- classes -> sections (per academic year) ; subjects ; class_subjects mapping ;
-- staff (employment record) ; teacher_assignments (subject teaching allocations).

-- ---- classes (grade levels) ----
create table public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name)
);

-- ---- subjects ----
create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name)
);

-- ---- staff (teacher/admin employment record; links to a member/profile) ----
create table public.staff (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  employee_no text,
  designation text,
  joined_on date,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, user_id)
);

-- ---- sections (a class's division for an academic year) ----
create table public.sections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  name text not null,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  class_teacher_staff_id uuid references public.staff (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, name, academic_year_id)
);

-- ---- class_subjects (which subjects a class studies) ----
create table public.class_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, subject_id)
);

-- ---- teacher_assignments (subject teaching allocations) ----
create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  staff_id uuid not null references public.staff (id) on delete cascade,
  section_id uuid not null references public.sections (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (staff_id, section_id, subject_id, academic_year_id)
);

-- ---- indexes ----
create index classes_school_idx on public.classes (school_id, sort_order);
create index subjects_school_idx on public.subjects (school_id);
create index staff_user_idx on public.staff (user_id);
create index staff_school_idx on public.staff (school_id);
create index sections_class_idx on public.sections (class_id);
create index sections_year_idx on public.sections (academic_year_id);
create index sections_class_teacher_idx on public.sections (class_teacher_staff_id);
create index class_subjects_class_idx on public.class_subjects (class_id);
create index teacher_assignments_section_idx on public.teacher_assignments (section_id);
create index teacher_assignments_staff_idx on public.teacher_assignments (staff_id);

-- ---- updated_at triggers ----
create trigger set_updated_at before update on public.classes
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.subjects
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.staff
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.sections
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.class_subjects
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.teacher_assignments
  for each row execute function public.set_updated_at();

-- ---- keep a staff record in sync for every teacher/admin member ----
-- A staff row is what class-teacher and subject-teacher assignments reference, so
-- one must exist as soon as a teacher/admin is added -- even before they accept
-- their invite. SECURITY DEFINER so it can write staff regardless of who inserted
-- the membership (admin via RLS, or the service-role invite function).
create or replace function public.ensure_staff_record()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role in ('teacher', 'school_admin') then
    insert into public.staff (school_id, user_id)
    values (new.school_id, new.user_id)
    on conflict (school_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger ensure_staff_on_member
  after insert or update of role on public.school_members
  for each row execute function public.ensure_staff_record();

-- backfill staff for members that already exist
insert into public.staff (school_id, user_id)
select school_id, user_id from public.school_members
where role in ('teacher', 'school_admin')
on conflict (school_id, user_id) do nothing;

-- ---- grants (new tables are not auto-exposed; see 0003 note) ----
grant select, insert, update, delete on public.classes to anon, authenticated, service_role;
grant select, insert, update, delete on public.subjects to anon, authenticated, service_role;
grant select, insert, update, delete on public.staff to anon, authenticated, service_role;
grant select, insert, update, delete on public.sections to anon, authenticated, service_role;
grant select, insert, update, delete on public.class_subjects to anon, authenticated, service_role;
grant select, insert, update, delete on public.teacher_assignments to anon, authenticated, service_role;

-- ---- RLS: members of the school read; school_admin writes ----
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.staff enable row level security;
alter table public.sections enable row level security;
alter table public.class_subjects enable row level security;
alter table public.teacher_assignments enable row level security;

-- classes
create policy classes_select on public.classes
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy classes_write on public.classes
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- subjects
create policy subjects_select on public.subjects
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy subjects_write on public.subjects
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- staff
create policy staff_select on public.staff
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy staff_write on public.staff
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- sections
create policy sections_select on public.sections
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy sections_write on public.sections
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- class_subjects
create policy class_subjects_select on public.class_subjects
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy class_subjects_write on public.class_subjects
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- teacher_assignments
create policy teacher_assignments_select on public.teacher_assignments
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy teacher_assignments_write on public.teacher_assignments
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());
