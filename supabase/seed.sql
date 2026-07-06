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

insert into public.academic_years (id, school_id, name, start_date, end_date, is_active)
values (
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-000000000001',
  '2025-26',
  '2025-06-01',
  '2026-04-30',
  true
)
on conflict do nothing;

-- Demo academic structure so a fresh `db reset` boots a usable school.
insert into public.classes (id, school_id, name, sort_order)
values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'Grade 5', 5),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000001', 'Grade 6', 6)
on conflict (school_id, name) do nothing;

insert into public.subjects (id, school_id, name, code)
values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000001', 'Mathematics', 'MATH'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000001', 'Science', 'SCI'),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-000000000001', 'English', 'ENG')
on conflict (school_id, name) do nothing;

insert into public.class_subjects (school_id, class_id, subject_id)
values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d1'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d2'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000d3')
on conflict (class_id, subject_id) do nothing;

insert into public.sections (school_id, class_id, name, academic_year_id)
values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 'A', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 'B', '00000000-0000-0000-0000-0000000000a1')
on conflict (class_id, name, academic_year_id) do nothing;

-- Default grade scale (migrations backfill existing schools, but the seeded
-- school is created here after migrations run, so seed it too).
insert into public.grade_scales (school_id, min_percent, max_percent, grade_label)
values
  ('00000000-0000-0000-0000-000000000001', 90, 100, 'A+'),
  ('00000000-0000-0000-0000-000000000001', 80, 89, 'A'),
  ('00000000-0000-0000-0000-000000000001', 70, 79, 'B+'),
  ('00000000-0000-0000-0000-000000000001', 60, 69, 'B'),
  ('00000000-0000-0000-0000-000000000001', 50, 59, 'C'),
  ('00000000-0000-0000-0000-000000000001', 40, 49, 'D'),
  ('00000000-0000-0000-0000-000000000001', 0, 39, 'F')
on conflict (school_id, grade_label) do nothing;
