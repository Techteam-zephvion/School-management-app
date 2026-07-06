-- Phase 8: fees (offline-first) — doc 05 §8, doc 06 Phase 8.
-- fee_structures (+ fee_items line items) -> generate invoices per student ->
-- record payments. Triggers keep totals and invoice status consistent, and
-- guarantee a payment never exceeds the invoice balance. Online (Razorpay) is
-- v1.1: the payments table already carries razorpay_* + status for the webhook.

create table public.fee_structures (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  class_id uuid references public.classes (id) on delete cascade,  -- null = all classes
  name text not null,
  total_amount numeric not null default 0,
  due_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index fee_structures_school_idx on public.fee_structures (school_id, academic_year_id);

create table public.fee_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  fee_structure_id uuid not null references public.fee_structures (id) on delete cascade,
  label text not null,
  amount numeric not null check (amount >= 0),
  created_at timestamptz not null default now()
);
create index fee_items_structure_idx on public.fee_items (fee_structure_id);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  fee_structure_id uuid not null references public.fee_structures (id) on delete cascade,
  amount_total numeric not null,
  amount_paid numeric not null default 0,
  status invoice_status not null default 'unpaid',
  due_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, fee_structure_id)
);
create index invoices_student_idx on public.invoices (student_id);
create index invoices_school_status_idx on public.invoices (school_id, status);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  amount numeric not null check (amount > 0),
  method text not null default 'cash',
  status payment_status not null default 'captured',
  razorpay_order_id text,
  razorpay_payment_id text unique,
  recorded_by uuid references public.profiles (id) on delete set null,
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index payments_invoice_idx on public.payments (invoice_id);

create trigger set_updated_at before update on public.fee_structures
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.invoices
  for each row execute function public.set_updated_at();

-- ---- a structure's total is the sum of its line items ----
create or replace function public.recompute_structure_total()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_structure uuid := coalesce(new.fee_structure_id, old.fee_structure_id);
begin
  update public.fee_structures
  set total_amount = coalesce((select sum(amount) from public.fee_items where fee_structure_id = v_structure), 0)
  where id = v_structure;
  return null;
end;
$$;
create trigger recompute_structure_total
  after insert or update or delete on public.fee_items
  for each row execute function public.recompute_structure_total();

-- ---- invoice status derived from amount_paid vs total and due date ----
create or replace function public.recompute_invoice()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.amount_paid >= new.amount_total then
    new.status := 'paid';
  elsif new.due_date < current_date then
    new.status := 'overdue';
  elsif new.amount_paid > 0 then
    new.status := 'partial';
  else
    new.status := 'unpaid';
  end if;
  return new;
end;
$$;
create trigger recompute_invoice before insert or update on public.invoices
  for each row execute function public.recompute_invoice();

-- ---- a captured payment must not exceed the remaining balance ----
create or replace function public.check_payment_bound()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_total numeric;
  v_paid numeric;
begin
  if new.status = 'captured' then
    select amount_total, amount_paid into v_total, v_paid
    from public.invoices where id = new.invoice_id;
    if v_total is null then
      raise exception 'Unknown invoice';
    end if;
    if new.amount > (v_total - v_paid) then
      raise exception 'Payment % exceeds the balance %', new.amount, (v_total - v_paid);
    end if;
  end if;
  return new;
end;
$$;
create trigger check_payment_bound before insert or update on public.payments
  for each row execute function public.check_payment_bound();

-- ---- a captured payment increments the invoice's paid amount ----
create or replace function public.apply_payment()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'captured' then
    update public.invoices set amount_paid = amount_paid + new.amount where id = new.invoice_id;
  elsif tg_op = 'UPDATE' and new.status = 'captured' and old.status is distinct from 'captured' then
    update public.invoices set amount_paid = amount_paid + new.amount where id = new.invoice_id;
  end if;
  return new;
end;
$$;
create trigger apply_payment after insert or update on public.payments
  for each row execute function public.apply_payment();

grant select, insert, update, delete on public.fee_structures to anon, authenticated, service_role;
grant select, insert, update, delete on public.fee_items to anon, authenticated, service_role;
grant select, insert, update, delete on public.invoices to anon, authenticated, service_role;
grant select, insert, update, delete on public.payments to anon, authenticated, service_role;

alter table public.fee_structures enable row level security;
alter table public.fee_items enable row level security;
alter table public.invoices enable row level security;
alter table public.payments enable row level security;

-- ---- fee_structures: staff read all; parent reads their child's applicable ----
create policy fee_structures_select on public.fee_structures
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or (
    school_id in (select sm.school_id from public.school_members sm where sm.user_id = auth.uid() and sm.status = 'active')
    and (class_id is null or class_id in (select private.my_children_class_ids()))
  )
);
create policy fee_structures_write on public.fee_structures
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- fee_items: staff read; admin write (parents get the amount off the invoice) ----
create policy fee_items_select on public.fee_items
for select using (
  school_id in (select private.auth_staff_school_ids()) or private.is_platform_admin()
);
create policy fee_items_write on public.fee_items
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- invoices: staff read all; parent reads own child; admin writes ----
create policy invoices_select on public.invoices
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or student_id in (select private.my_children())
);
create policy invoices_write on public.invoices
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- payments: staff read all; parent reads own child's; admin records ----
create policy payments_select on public.payments
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or exists (
    select 1 from public.invoices i
    where i.id = invoice_id and i.student_id in (select private.my_children())
  )
);
create policy payments_write on public.payments
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());
