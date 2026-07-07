-- Phase 12: audit logs for sensitive actions (doc 05 §11/§13).
-- Written by SECURITY DEFINER triggers on payments / results-publish / role
-- changes; read by the school's admin (or a platform admin).

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity text,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_school_idx on public.audit_logs (school_id, created_at desc);

grant select, insert, update, delete on public.audit_logs to anon, authenticated, service_role;
alter table public.audit_logs enable row level security;

-- read-only for the school's admin / platform admin; rows come from triggers
create policy audit_logs_select on public.audit_logs
for select using (
  private.has_role(school_id, 'school_admin') or private.is_platform_admin()
);

create or replace function private.write_audit(
  p_school uuid, p_action text, p_entity text, p_entity_id uuid, p_meta jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.audit_logs (school_id, actor_id, action, entity, entity_id, meta)
  values (p_school, auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_meta, '{}'::jsonb));
$$;

-- ---- a captured payment ----
create or replace function public.audit_payment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'captured' then
    perform private.write_audit(new.school_id, 'payment_recorded', 'payment', new.id,
      jsonb_build_object('amount', new.amount, 'method', new.method, 'invoice_id', new.invoice_id));
  end if;
  return new;
end $$;
create trigger audit_payment after insert on public.payments
  for each row execute function public.audit_payment();

-- ---- results published ----
create or replace function public.audit_results()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_published and not coalesce(old.is_published, false) then
    perform private.write_audit(new.school_id, 'results_published', 'exam_term', new.id,
      jsonb_build_object('term', new.name));
  end if;
  return new;
end $$;
create trigger audit_results after update on public.exam_terms
  for each row execute function public.audit_results();

-- ---- a member's role changed ----
create or replace function public.audit_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    perform private.write_audit(new.school_id, 'role_changed', 'school_member', new.id,
      jsonb_build_object('user_id', new.user_id, 'from', old.role, 'to', new.role));
  end if;
  return new;
end $$;
create trigger audit_role_change after update on public.school_members
  for each row execute function public.audit_role_change();
