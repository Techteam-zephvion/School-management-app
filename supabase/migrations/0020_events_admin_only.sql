-- Only the admin manages holidays/events; teachers (incl. class teachers) may
-- only read them. Tighten events write from any-staff to school_admin only.
drop policy if exists events_write on public.events;
create policy events_write on public.events
for all using (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
) with check (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);
