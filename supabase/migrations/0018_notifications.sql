-- Phase 10: notifications & push (doc 05 §9/§13, doc 06 Phase 10).
-- notify_on_event triggers fan a notification row out to each recipient whenever
-- an event happens (homework, absence, notice, result publish, message, fee).
-- Mobile registers Expo tokens in `devices` and a send-push function delivers
-- the push (built with the RN app); the notification rows are the source of truth.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  type notif_type not null,
  title text not null,
  body text,
  deeplink text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  expo_push_token text not null,
  platform text,
  last_seen timestamptz not null default now(),
  unique (user_id, expo_push_token)
);

grant select, insert, update, delete on public.notifications to anon, authenticated, service_role;
grant select, insert, update, delete on public.devices to anon, authenticated, service_role;

alter table public.notifications enable row level security;
alter table public.devices enable row level security;

-- own rows only (triggers create rows via SECURITY DEFINER; service role bypasses)
create policy notifications_select on public.notifications for select using (user_id = auth.uid());
create policy notifications_update on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on public.notifications for delete using (user_id = auth.uid());

create policy devices_all on public.devices for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Insert one notification per recipient (deduped). SECURITY DEFINER so triggers
-- can write rows for users other than the one who caused the event.
create or replace function private.push_notifications(
  p_school uuid,
  p_users uuid[],
  p_type notif_type,
  p_title text,
  p_body text,
  p_deeplink text
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (school_id, user_id, type, title, body, deeplink)
  select p_school, u, p_type, p_title, p_body, p_deeplink
  from (select distinct unnest(p_users) as u) x
  where u is not null;
$$;

-- ---- homework -> guardians of the section ----
create or replace function public.notify_homework()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  select array_agg(distinct sg.guardian_user_id)
  into v_users
  from public.enrollments e
  join public.student_guardians sg on sg.student_id = e.student_id
  where e.section_id = new.section_id and e.status = 'active';
  perform private.push_notifications(new.school_id, v_users, 'homework', 'New homework', new.title, 'schoolerp://homework/' || new.id);
  return new;
end $$;
create trigger notify_homework after insert on public.homework
  for each row execute function public.notify_homework();

-- ---- absence -> that student's guardians ----
create or replace function public.notify_absence()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  select array_agg(guardian_user_id) into v_users from public.student_guardians where student_id = new.student_id;
  perform private.push_notifications(new.school_id, v_users, 'attendance', 'Marked absent',
    to_char(new.date, 'DD Mon'), 'schoolerp://attendance');
  return new;
end $$;
create trigger notify_absence after insert on public.attendance
  for each row when (new.status = 'absent') execute function public.notify_absence();

-- ---- announcements: school-wide on insert, targeted on target insert ----
create or replace function public.notify_announcement_school()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  if new.audience = 'school' then
    select array_agg(distinct sg.guardian_user_id) into v_users
    from public.students st join public.student_guardians sg on sg.student_id = st.id
    where st.school_id = new.school_id;
    perform private.push_notifications(new.school_id, v_users, 'notice', new.title, left(new.body, 120), 'schoolerp://notices/' || new.id);
  end if;
  return new;
end $$;
create trigger notify_announcement_school after insert on public.announcements
  for each row execute function public.notify_announcement_school();

create or replace function public.notify_announcement_target()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_title text; v_body text; v_school uuid; v_ann uuid; v_users uuid[];
begin
  select title, left(body, 120), school_id into v_title, v_body, v_school
  from public.announcements where id = new.announcement_id;
  v_ann := new.announcement_id;
  select array_agg(distinct sg.guardian_user_id) into v_users
  from public.student_guardians sg
  where (new.student_id is not null and sg.student_id = new.student_id)
     or (new.section_id is not null and sg.student_id in (
          select student_id from public.enrollments where section_id = new.section_id and status = 'active'))
     or (new.class_id is not null and sg.student_id in (
          select e.student_id from public.enrollments e join public.sections s on s.id = e.section_id
          where s.class_id = new.class_id and e.status = 'active'));
  perform private.push_notifications(v_school, v_users, 'notice', v_title, v_body, 'schoolerp://notices/' || v_ann);
  return new;
end $$;
create trigger notify_announcement_target after insert on public.announcement_targets
  for each row execute function public.notify_announcement_target();

-- ---- exam term published -> guardians of students with marks in it ----
create or replace function public.notify_results_published()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  if new.is_published and not coalesce(old.is_published, false) then
    select array_agg(distinct sg.guardian_user_id) into v_users
    from public.marks m join public.student_guardians sg on sg.student_id = m.student_id
    where m.term_id = new.id;
    perform private.push_notifications(new.school_id, v_users, 'result', 'Results published', new.name, 'schoolerp://exams/' || new.id);
  end if;
  return new;
end $$;
create trigger notify_results_published after update on public.exam_terms
  for each row execute function public.notify_results_published();

-- ---- new message -> the other thread participants ----
create or replace function public.notify_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  select array_agg(tp.user_id) into v_users
  from public.thread_participants tp
  where tp.thread_id = new.thread_id and tp.user_id <> new.sender_id;
  perform private.push_notifications(new.school_id, v_users, 'message', 'New message', left(new.body, 120), 'schoolerp://messages/' || new.thread_id);
  return new;
end $$;
create trigger notify_message after insert on public.messages
  for each row execute function public.notify_message();

-- ---- new invoice -> that student's guardians ----
create or replace function public.notify_invoice()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_users uuid[];
begin
  select array_agg(guardian_user_id) into v_users from public.student_guardians where student_id = new.student_id;
  perform private.push_notifications(new.school_id, v_users, 'fee', 'New invoice',
    'Amount due: ' || new.amount_total::text, 'schoolerp://fees');
  return new;
end $$;
create trigger notify_invoice after insert on public.invoices
  for each row execute function public.notify_invoice();

-- realtime so the notification bell updates live
alter publication supabase_realtime add table public.notifications;
