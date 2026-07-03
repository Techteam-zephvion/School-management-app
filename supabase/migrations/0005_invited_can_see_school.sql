-- An invited-but-not-yet-active user needs to see the name of the school that
-- invited them (the accept-invite screen greets them with it, mirroring the
-- invite email). auth_school_ids() only returns ACTIVE memberships, so the
-- existing schools_select policy hides the school until they activate --
-- chicken-and-egg. This helper returns the caller's school_ids for ANY
-- membership status; a matching additive SELECT policy closes the gap.
create or replace function private.my_member_school_ids()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select school_id from public.school_members
  where user_id = auth.uid();
$$;

grant execute on function private.my_member_school_ids() to authenticated, anon;

-- Additive (permissive) policy -- OR'd with schools_select. Reveals only the
-- school's row to someone who holds a membership of any status for it; it does
-- not widen access to any other tenant data.
create policy schools_select_invited on public.schools
for select using (
  id in (select private.my_member_school_ids())
);
