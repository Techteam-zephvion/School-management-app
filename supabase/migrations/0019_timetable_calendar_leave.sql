-- Phase 11: timetable, calendar & leave (doc 05 §5/§10, doc 06 Phase 11).

-- ---- periods (timetable slots) ----
create table public.periods (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  section_id uuid not null references public.sections (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),  -- 0 = Monday
  period_no int not null check (period_no between 1 and 12),
  start_time time,
  end_time time,
  subject_id uuid references public.subjects (id) on delete set null,
  staff_id uuid references public.staff (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (section_id, academic_year_id, weekday, period_no)
);
create index periods_section_idx on public.periods (section_id, academic_year_id);
create index periods_staff_idx on public.periods (staff_id);

-- ---- events / calendar (holidays block attendance) ----
create table public.events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  title text not null,
  description text,
  start_date date not null,
  end_date date not null,
  is_holiday boolean not null default false,
  section_id uuid references public.sections (id) on delete cascade,  -- null = school-wide
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index events_school_dates_idx on public.events (school_id, start_date, end_date);

-- ---- leave requests ----
create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  requested_by uuid references public.profiles (id) on delete set null,
  from_date date not null,
  to_date date not null,
  reason text,
  status leave_status not null default 'pending',
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (to_date >= from_date)
);
create index leave_requests_school_idx on public.leave_requests (school_id, status);
create index leave_requests_student_idx on public.leave_requests (student_id);

create trigger set_updated_at before update on public.periods
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.leave_requests
  for each row execute function public.set_updated_at();

-- On approval, upsert daily attendance = 'excused' across the leave range for the
-- student's active section. SECURITY DEFINER so the reviewer needn't hold direct
-- attendance-write rights for every day.
create or replace function public.apply_leave_excused()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_section uuid;
  d date;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    select e.section_id into v_section
    from public.enrollments e
    where e.student_id = new.student_id and e.status = 'active'
    limit 1;
    if v_section is not null then
      for d in select generate_series(new.from_date, new.to_date, interval '1 day')::date loop
        insert into public.attendance (school_id, student_id, section_id, date, subject_id, status, marked_by)
        values (new.school_id, new.student_id, v_section, d, null, 'excused', new.reviewed_by)
        on conflict (student_id, date) where subject_id is null
        do update set status = 'excused', marked_by = excluded.marked_by;
      end loop;
    end if;
  end if;
  return new;
end;
$$;
create trigger apply_leave_excused after update on public.leave_requests
  for each row execute function public.apply_leave_excused();

grant select, insert, update, delete on public.periods to anon, authenticated, service_role;
grant select, insert, update, delete on public.events to anon, authenticated, service_role;
grant select, insert, update, delete on public.leave_requests to anon, authenticated, service_role;

alter table public.periods enable row level security;
alter table public.events enable row level security;
alter table public.leave_requests enable row level security;

-- periods: members of the school read; admin writes
create policy periods_select on public.periods
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy periods_write on public.periods
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- events: members read; any staff (admin/teacher) writes
create policy events_select on public.events
for select using (school_id in (select private.auth_school_ids()) or private.is_platform_admin());
create policy events_write on public.events
for all using (
  private.has_role(school_id, 'school_admin') or private.has_role(school_id, 'teacher') or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin') or private.has_role(school_id, 'teacher') or private.is_platform_admin()
);

-- leave_requests: staff of school, the requester, or the child's parent may read
create policy leave_requests_select on public.leave_requests
for select using (
  school_id in (select private.auth_staff_school_ids())
  or requested_by = auth.uid()
  or student_id in (select private.my_children())
  or private.is_platform_admin()
);
-- the caller files for their own child (parent) or as staff of the school
create policy leave_requests_insert on public.leave_requests
for insert with check (
  requested_by = auth.uid()
  and (
    student_id in (select private.my_children())
    or school_id in (select private.auth_staff_school_ids())
  )
);
-- reviewed only by the class teacher of the student's section or an admin
create policy leave_requests_update on public.leave_requests
for update using (
  private.has_role(school_id, 'school_admin')
  or student_id in (select private.my_class_student_ids())
  or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin')
  or student_id in (select private.my_class_student_ids())
  or private.is_platform_admin()
);
-- the requester may withdraw their own pending request; admin may delete any
create policy leave_requests_delete on public.leave_requests
for delete using (
  requested_by = auth.uid() or private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);
