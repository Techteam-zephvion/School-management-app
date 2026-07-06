-- Fix: editing a fee structure's items after invoices are generated left the
-- invoices' amount_total stale, so a newly added item never showed up as extra
-- balance for students (even fully-paid ones). Make recompute_structure_total
-- also push the new total onto every invoice for that structure; the
-- recompute_invoice BEFORE-UPDATE trigger then re-derives each invoice's status
-- (a previously 'paid' invoice becomes 'partial'/'overdue' with the new balance).
create or replace function public.recompute_structure_total()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_structure uuid := coalesce(new.fee_structure_id, old.fee_structure_id);
  v_total numeric;
begin
  v_total := coalesce((select sum(amount) from public.fee_items where fee_structure_id = v_structure), 0);
  update public.fee_structures set total_amount = v_total where id = v_structure;
  update public.invoices set amount_total = v_total where fee_structure_id = v_structure;
  return null;
end;
$$;
