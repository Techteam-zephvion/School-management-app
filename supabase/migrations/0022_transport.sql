-- Transport module: bus routes, stops, student assignments (roster), live
-- location, and an auto-billed per-route bus fee. Live tracking is scoped to the
-- class teacher of a rider's section and (later, in the RN app) the rider's
-- parent; admins manage everything.

-- ---- bus routes ----
create table public.bus_routes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  description text,
  fee_amount numeric not null default 0 check (fee_amount >= 0),
  driver_name text,
  driver_phone text,
  vehicle_no text,
  capacity int check (capacity is null or capacity >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index bus_routes_school_idx on public.bus_routes (school_id);

-- ---- bus stops (ordered along a route) ----
create table public.bus_stops (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  route_id uuid not null references public.bus_routes (id) on delete cascade,
  name text not null,
  seq int not null default 0,
  pickup_time time,
  lat numeric,
  lng numeric,
  created_at timestamptz not null default now(),
  unique (route_id, name)
);
create index bus_stops_route_idx on public.bus_stops (route_id, seq);

-- ---- student transport assignment (the roster). One active bus per student. ----
create table public.student_transport (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  route_id uuid not null references public.bus_routes (id) on delete cascade,
  stop_id uuid references public.bus_stops (id) on delete set null,
  fee_amount numeric not null default 0,  -- snapshot of the route fee at assignment
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id)
);
create index student_transport_route_idx on public.student_transport (route_id);
create index student_transport_student_idx on public.student_transport (student_id);

-- ---- live bus location (latest position per route) ----
create table public.bus_locations (
  route_id uuid primary key references public.bus_routes (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  lat numeric not null,
  lng numeric not null,
  heading numeric,
  speed numeric,
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

-- ---- fees hook: mark the auto-managed per-year "Transport" container so the
-- normal fees UI/generation ignores it (its invoices are per-student amounts). ----
alter table public.fee_structures add column is_transport boolean not null default false;

create trigger set_updated_at before update on public.bus_routes
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.student_transport
  for each row execute function public.set_updated_at();

-- Routes I'm allowed to live-track: any route carrying a student in my class
-- (class teacher) or one of my children (parent). Admins see all via has_role.
create or replace function private.my_trackable_route_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select distinct st.route_id
  from public.student_transport st
  where st.active
    and (
      st.student_id in (select private.my_class_student_ids())
      or st.student_id in (select private.my_children())
    );
$$;
grant execute on function private.my_trackable_route_ids() to authenticated, anon;

grant select, insert, update, delete on public.bus_routes to anon, authenticated, service_role;
grant select, insert, update, delete on public.bus_stops to anon, authenticated, service_role;
grant select, insert, update, delete on public.student_transport to anon, authenticated, service_role;
grant select, insert, update, delete on public.bus_locations to anon, authenticated, service_role;

alter table public.bus_routes enable row level security;
alter table public.bus_stops enable row level security;
alter table public.student_transport enable row level security;
alter table public.bus_locations enable row level security;

-- bus_routes: school staff read all; a parent reads a route their child rides; admin writes
create policy bus_routes_select on public.bus_routes
for select using (
  school_id in (select private.auth_staff_school_ids())
  or id in (select private.my_trackable_route_ids())
  or private.is_platform_admin()
);
create policy bus_routes_write on public.bus_routes
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- bus_stops: same visibility as their route; admin writes
create policy bus_stops_select on public.bus_stops
for select using (
  school_id in (select private.auth_staff_school_ids())
  or route_id in (select private.my_trackable_route_ids())
  or private.is_platform_admin()
);
create policy bus_stops_write on public.bus_stops
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- student_transport (roster): staff of school, the class teacher of the rider's
-- section, or the rider's parent may read; only admin writes.
create policy student_transport_select on public.student_transport
for select using (
  school_id in (select private.auth_staff_school_ids())
  or student_id in (select private.my_class_student_ids())
  or student_id in (select private.my_children())
  or private.is_platform_admin()
);
create policy student_transport_write on public.student_transport
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- bus_locations: admin + anyone allowed to track the route may read; any school
-- staff (the driver-share page) may write.
create policy bus_locations_select on public.bus_locations
for select using (
  private.has_role(school_id, 'school_admin')
  or route_id in (select private.my_trackable_route_ids())
  or private.is_platform_admin()
);
create policy bus_locations_write on public.bus_locations
for all using (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
) with check (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);

-- live updates for the tracking map
alter publication supabase_realtime add table public.bus_locations;
