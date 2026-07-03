-- A newly-invited user accepting their invite must flip their own school_members
-- row from 'invited' -> 'active'. They are not yet a school_admin, so the
-- school_members UPDATE policy (which requires school_admin) blocks a direct
-- update. This SECURITY DEFINER RPC activates only the CALLER's own invited
-- rows -- it cannot touch anyone else's membership or any other status.
create or replace function public.activate_my_memberships()
returns void
language sql
security definer
set search_path = public
as $$
  update public.school_members
  set status = 'active'
  where user_id = auth.uid()
    and status = 'invited';
$$;

grant execute on function public.activate_my_memberships() to authenticated;
