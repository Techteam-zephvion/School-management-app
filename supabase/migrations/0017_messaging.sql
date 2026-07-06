-- Phase 9: realtime messaging (doc 05 §9, doc 06 Phase 9).
-- 1:1(+) threads between staff and a student's guardian(s), scoped per student.
-- Only participants read a thread and its messages; only a participant sends.

create table public.message_threads (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid references public.students (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  subject text,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index message_threads_school_idx on public.message_threads (school_id, last_message_at desc);

create table public.thread_participants (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (thread_id, user_id)
);
create index thread_participants_user_idx on public.thread_participants (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  thread_id uuid not null references public.message_threads (id) on delete cascade,
  sender_id uuid references public.profiles (id) on delete set null,
  body text not null,
  attachment_url text,
  created_at timestamptz not null default now()
);
create index messages_thread_idx on public.messages (thread_id, created_at);

create table public.message_reads (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  unique (message_id, user_id)
);
create index message_reads_user_idx on public.message_reads (user_id);

-- thread ids the caller participates in (SECURITY DEFINER so policies that use
-- it don't recurse into thread_participants' own RLS).
create or replace function private.my_thread_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select thread_id from public.thread_participants where user_id = auth.uid();
$$;
grant execute on function private.my_thread_ids() to authenticated, anon;

-- a new message bumps the thread's last_message_at (SECURITY DEFINER to update
-- the thread regardless of the sender's RLS on message_threads).
create or replace function public.bump_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.message_threads set last_message_at = new.created_at where id = new.thread_id;
  return new;
end;
$$;
create trigger bump_thread after insert on public.messages
  for each row execute function public.bump_thread();

-- Staff starts (or reuses) a thread with a student's guardian(s) and posts the
-- first message. SECURITY DEFINER: validates the caller is active staff of the
-- student's school, then writes thread + participants + message atomically.
create or replace function public.start_thread_with_guardians(
  p_student uuid,
  p_subject text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_school uuid;
  v_thread uuid;
  v_guardians int;
begin
  if coalesce(btrim(p_body), '') = '' then
    raise exception 'Message cannot be empty';
  end if;
  select school_id into v_school from public.students where id = p_student;
  if v_school is null then
    raise exception 'Student not found';
  end if;
  if not exists (
    select 1 from public.school_members
    where user_id = v_caller and school_id = v_school and status = 'active'
      and role in ('school_admin', 'teacher')
  ) then
    raise exception 'Not authorized to message this student''s guardians';
  end if;

  select count(*) into v_guardians from public.student_guardians where student_id = p_student;
  if v_guardians = 0 then
    raise exception 'This student has no linked guardians yet';
  end if;

  -- reuse an existing thread the caller has for this student, else create one
  select mt.id into v_thread
  from public.message_threads mt
  join public.thread_participants tp on tp.thread_id = mt.id and tp.user_id = v_caller
  where mt.student_id = p_student
  limit 1;

  if v_thread is null then
    insert into public.message_threads (school_id, student_id, created_by, subject)
    values (v_school, p_student, v_caller, nullif(btrim(p_subject), ''))
    returning id into v_thread;

    insert into public.thread_participants (thread_id, user_id)
    values (v_thread, v_caller)
    on conflict do nothing;
    insert into public.thread_participants (thread_id, user_id)
    select v_thread, guardian_user_id from public.student_guardians where student_id = p_student
    on conflict do nothing;
  end if;

  insert into public.messages (school_id, thread_id, sender_id, body)
  values (v_school, v_thread, v_caller, btrim(p_body));

  return v_thread;
end;
$$;
grant execute on function public.start_thread_with_guardians(uuid, text, text) to authenticated;

grant select, insert, update, delete on public.message_threads to anon, authenticated, service_role;
grant select, insert, update, delete on public.thread_participants to anon, authenticated, service_role;
grant select, insert, update, delete on public.messages to anon, authenticated, service_role;
grant select, insert, update, delete on public.message_reads to anon, authenticated, service_role;

alter table public.message_threads enable row level security;
alter table public.thread_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

-- ---- threads: participants only ----
create policy message_threads_select on public.message_threads
for select using (id in (select private.my_thread_ids()) or private.is_platform_admin());

-- ---- participants: visible to co-participants ----
create policy thread_participants_select on public.thread_participants
for select using (thread_id in (select private.my_thread_ids()) or private.is_platform_admin());

-- ---- messages: participants read; a participant sends as themselves ----
create policy messages_select on public.messages
for select using (thread_id in (select private.my_thread_ids()) or private.is_platform_admin());
create policy messages_insert on public.messages
for insert with check (
  sender_id = auth.uid() and thread_id in (select private.my_thread_ids())
);

-- ---- read receipts: own rows ----
create policy message_reads_select on public.message_reads
for select using (user_id = auth.uid());
create policy message_reads_insert on public.message_reads
for insert with check (user_id = auth.uid());

-- ---- realtime on messages ----
alter publication supabase_realtime add table public.messages;
