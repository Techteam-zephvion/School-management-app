-- Fix: bus_locations had a `for all` write policy, whose USING clause also
-- governs SELECT — so any school staff could READ a bus's live location, not
-- just the class teacher / parent the tracking rule intends. Split it into
-- insert/update/delete so reads are governed only by bus_locations_select
-- (admin, a rider's class teacher, or a rider's parent via my_trackable_route_ids).

drop policy if exists bus_locations_write on public.bus_locations;

create policy bus_locations_insert on public.bus_locations
for insert with check (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);
create policy bus_locations_update on public.bus_locations
for update using (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
) with check (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);
create policy bus_locations_delete on public.bus_locations
for delete using (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);
