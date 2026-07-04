-- Phase 6: notices / announcements (doc 05 §9, doc 06 Phase 6).
-- audience: school (whole school), class, section, or individual (one student).
-- Admin may target anything; a teacher only section/individual (enforced by the
-- audience check in RLS + section-ownership check in the server action).
-- Parents see notices aimed at their children and record read receipts.

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null,
  audience notice_audience not null,
  title text not null,
  body text not null,
  attachment_url text,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Who a notice targets (school-wide notices have no rows). school_id is
-- denormalized so staff read policies stay simple.
create table public.announcement_targets (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid references public.classes (id) on delete cascade,
  section_id uuid references public.sections (id) on delete cascade,
  student_id uuid references public.students (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.announcement_reads (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  unique (announcement_id, user_id)
);

create index announcements_school_pub_idx on public.announcements (school_id, published_at desc);
create index announcement_targets_ann_idx on public.announcement_targets (announcement_id);
create index announcement_targets_section_idx on public.announcement_targets (section_id);
create index announcement_targets_student_idx on public.announcement_targets (student_id);
create index announcement_reads_ann_idx on public.announcement_reads (announcement_id);

create trigger set_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();

-- Class ids of the caller's children's active sections (for the read policy).
create or replace function private.my_children_class_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select sec.class_id
  from public.enrollments e
  join public.sections sec on sec.id = e.section_id
  where e.student_id in (select private.my_children()) and e.status = 'active';
$$;

grant execute on function private.my_children_class_ids() to authenticated, anon;

-- Announcement ids a parent may see: school-wide notices for a school they
-- belong to, plus any notice targeting their child / section / class.
-- SECURITY DEFINER so the announcements read policy can call it without
-- recursing into the same table's RLS.
create or replace function private.my_announcement_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select a.id from public.announcements a
  where a.audience = 'school'
    and a.school_id in (
      select sm.school_id from public.school_members sm
      where sm.user_id = auth.uid() and sm.status = 'active'
    )
  union
  select t.announcement_id from public.announcement_targets t
  where t.student_id in (select private.my_children())
     or t.section_id in (select private.my_children_section_ids())
     or t.class_id in (select private.my_children_class_ids());
$$;

grant execute on function private.my_announcement_ids() to authenticated, anon;

grant select, insert, update, delete on public.announcements to anon, authenticated, service_role;
grant select, insert, update, delete on public.announcement_targets to anon, authenticated, service_role;
grant select, insert, update, delete on public.announcement_reads to anon, authenticated, service_role;

alter table public.announcements enable row level security;
alter table public.announcement_targets enable row level security;
alter table public.announcement_reads enable row level security;

-- ---- announcements ----
create policy announcements_select on public.announcements
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or id in (select private.my_announcement_ids())
);

-- Admin posts to any audience; a teacher only to a section or an individual.
create policy announcements_insert on public.announcements
for insert with check (
  private.is_platform_admin()
  or private.has_role(school_id, 'school_admin')
  or (private.has_role(school_id, 'teacher') and audience in ('section', 'individual'))
);

create policy announcements_update on public.announcements
for update using (
  private.is_platform_admin() or private.has_role(school_id, 'school_admin') or created_by = auth.uid()
) with check (
  private.is_platform_admin() or private.has_role(school_id, 'school_admin') or created_by = auth.uid()
);

create policy announcements_delete on public.announcements
for delete using (
  private.is_platform_admin() or private.has_role(school_id, 'school_admin') or created_by = auth.uid()
);

-- ---- announcement_targets (staff-scoped; parents read notices, not targets) ----
create policy announcement_targets_select on public.announcement_targets
for select using (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);
create policy announcement_targets_write on public.announcement_targets
for all using (
  private.has_role(school_id, 'school_admin') or private.has_role(school_id, 'teacher') or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin') or private.has_role(school_id, 'teacher') or private.is_platform_admin()
);

-- ---- announcement_reads (own row; staff can see receipts for their school) ----
create policy announcement_reads_select on public.announcement_reads
for select using (
  user_id = auth.uid()
  or school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
);
create policy announcement_reads_insert on public.announcement_reads
for insert with check (user_id = auth.uid());
create policy announcement_reads_delete on public.announcement_reads
for delete using (user_id = auth.uid());

-- ---- attachments: private `notices` storage bucket ----
insert into storage.buckets (id, name, public)
values ('notices', 'notices', false)
on conflict (id) do nothing;

create policy "notices read for school members" on storage.objects
for select to authenticated using (
  bucket_id = 'notices'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active'
  )
);
create policy "notices upload for staff" on storage.objects
for insert to authenticated with check (
  bucket_id = 'notices'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active' and role in ('school_admin', 'teacher')
  )
);
create policy "notices delete for staff" on storage.objects
for delete to authenticated using (
  bucket_id = 'notices'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active' and role in ('school_admin', 'teacher')
  )
);
