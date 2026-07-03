-- Local dev seed (doc 05 §16). Auth users can't be created via plain SQL against
-- GoTrue's schema reliably across versions, so the bootstrap school_admin is created
-- by scripts/seed-admin.mjs (uses the Admin API) -- run that after `supabase db reset`.

insert into public.schools (id, name, slug, address, city, state, pincode, phone, email)
values (
  '00000000-0000-0000-0000-000000000001',
  'Greenwood High School',
  'greenwood-high',
  '12 MG Road',
  'Bengaluru',
  'Karnataka',
  '560001',
  '+91-80-12345678',
  'contact@greenwood.edu'
)
on conflict (id) do nothing;

insert into public.academic_years (school_id, name, start_date, end_date, is_active)
values (
  '00000000-0000-0000-0000-000000000001',
  '2025-26',
  '2025-06-01',
  '2026-04-30',
  true
)
on conflict do nothing;
