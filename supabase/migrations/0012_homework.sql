-- Phase 5: homework (doc 05 §6, doc 06 Phase 5). A homework item is always for a
-- (section, subject). It can be posted by an admin, the section's class teacher
-- (any subject), or the assigned subject teacher for that subject.

create table public.homework (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  section_id uuid not null references public.sections (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null,
  title text not null,
  description text,
  due_date date not null,
  attachment_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index homework_section_due_idx on public.homework (section_id, due_date);

create trigger set_updated_at before update on public.homework
  for each row execute function public.set_updated_at();

-- Sections a parent's child is actively enrolled in (for the read policy).
create or replace function private.my_children_section_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select e.section_id
  from public.enrollments e
  where e.student_id in (select private.my_children())
    and e.status = 'active';
$$;

grant execute on function private.my_children_section_ids() to authenticated, anon;

-- Who may create/edit homework for a (section, subject).
create or replace function private.can_assign_homework(p_section uuid, p_subject uuid)
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
        -- class teacher of the section: any subject for their class
        or exists (
          select 1 from public.staff st
          where st.id = sec.class_teacher_staff_id and st.user_id = auth.uid()
        )
        -- assigned subject teacher for this exact subject in this section
        or exists (
          select 1 from public.teacher_assignments ta
          join public.staff st on st.id = ta.staff_id
          where ta.section_id = p_section
            and ta.subject_id = p_subject
            and st.user_id = auth.uid()
        )
      )
  );
$$;

grant execute on function private.can_assign_homework(uuid, uuid) to authenticated, anon;

grant select, insert, update, delete on public.homework to anon, authenticated, service_role;

alter table public.homework enable row level security;

-- Read: staff of the school; or a parent whose child is in that section.
create policy homework_select on public.homework
for select using (
  school_id in (select private.auth_staff_school_ids())
  or section_id in (select private.my_children_section_ids())
  or private.is_platform_admin()
);

-- Write: admin, the class teacher, or the assigned subject teacher.
create policy homework_write on public.homework
for all
using (private.can_assign_homework(section_id, subject_id))
with check (private.can_assign_homework(section_id, subject_id));

-- ---- attachments: private `homework` storage bucket ----
insert into storage.buckets (id, name, public)
values ('homework', 'homework', false)
on conflict (id) do nothing;

-- Objects are keyed by school: `homework/<school_id>/<uuid>-<filename>`. Any
-- active member of that school (staff or a parent) may read; staff upload.
create policy "homework read for school members" on storage.objects
for select to authenticated using (
  bucket_id = 'homework'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active'
  )
);

create policy "homework upload for staff" on storage.objects
for insert to authenticated with check (
  bucket_id = 'homework'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active' and role in ('school_admin', 'teacher')
  )
);

create policy "homework delete for staff" on storage.objects
for delete to authenticated using (
  bucket_id = 'homework'
  and (storage.foldername(name))[1] in (
    select school_id::text from public.school_members
    where user_id = auth.uid() and status = 'active' and role in ('school_admin', 'teacher')
  )
);
