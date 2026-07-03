-- Phase 1: RLS helper functions (doc 05 §12) + baseline policies for identity/tenancy tables
-- Helpers live in a `private` schema (not exposed via PostgREST) and are SECURITY DEFINER
-- so they bypass RLS on the tables they read -- otherwise policies that call them would
-- recurse into school_members' own RLS policy.

create schema if not exists private;

create or replace function private.auth_school_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select school_id from public.school_members
  where user_id = auth.uid() and status = 'active';
$$;

create or replace function private.has_role(p_school uuid, p_role app_role)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.school_members
    where user_id = auth.uid()
      and school_id = p_school
      and role = p_role
      and status = 'active'
  );
$$;

create or replace function private.is_platform_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select is_platform_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

grant usage on schema private to authenticated, anon;
grant execute on function private.auth_school_ids() to authenticated, anon;
grant execute on function private.has_role(uuid, app_role) to authenticated, anon;
grant execute on function private.is_platform_admin() to authenticated, anon;

-- ---- table grants ----
-- Newer Supabase local/cloud defaults do NOT auto-expose new tables to the API
-- roles (see config.toml `api.auto_expose_new_tables`) -- grants are required
-- for anon/authenticated/service_role to reach a table at all. RLS below is
-- still the real authorization boundary; these grants just make the table
-- reachable through PostgREST.
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on public.schools to anon, authenticated, service_role;
grant select, insert, update, delete on public.profiles to anon, authenticated, service_role;
grant select, insert, update, delete on public.school_members to anon, authenticated, service_role;
grant select, insert, update, delete on public.academic_years to anon, authenticated, service_role;

-- ---- enable RLS, deny by default ----
alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.school_members enable row level security;
alter table public.academic_years enable row level security;

-- ---- schools ----
create policy schools_select on public.schools
for select using (
  id in (select private.auth_school_ids())
  or private.is_platform_admin()
);

create policy schools_insert on public.schools
for insert with check (private.is_platform_admin());

create policy schools_update on public.schools
for update using (
  private.has_role(id, 'school_admin') or private.is_platform_admin()
) with check (
  private.has_role(id, 'school_admin') or private.is_platform_admin()
);

-- ---- profiles ----
-- own row always visible/editable; also visible to anyone sharing a school (staff directories,
-- guardian names, message participant lookups, etc.)
create policy profiles_select_self on public.profiles
for select using (id = auth.uid());

create policy profiles_select_school_peers on public.profiles
for select using (
  id in (
    select user_id from public.school_members
    where school_id in (select private.auth_school_ids())
  )
);

create policy profiles_insert_self on public.profiles
for insert with check (id = auth.uid());

create policy profiles_update_self on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

-- ---- school_members ----
-- a user must see their own membership row even before it is 'active' (invited state,
-- school picker, accept-invite flow) -- auth_school_ids() alone would not surface it.
create policy school_members_select_own on public.school_members
for select using (user_id = auth.uid());

create policy school_members_select_school on public.school_members
for select using (school_id in (select private.auth_school_ids()));

create policy school_members_insert on public.school_members
for insert with check (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);

create policy school_members_update on public.school_members
for update using (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);

create policy school_members_delete on public.school_members
for delete using (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);

-- ---- academic_years ----
create policy academic_years_select on public.academic_years
for select using (
  school_id in (select private.auth_school_ids()) or private.is_platform_admin()
);

create policy academic_years_write on public.academic_years
for all using (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);
