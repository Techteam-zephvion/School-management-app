-- Phase 7: exams, marks & results (doc 05 §7, doc 06 Phase 7).
-- exam_terms -> exam_subjects (subject + max per class per term) -> marks.
-- Admin manages terms/subjects and publishes; the assigned subject teacher
-- enters marks; parents see results only once the term is published.

create table public.grade_scales (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  min_percent numeric not null,
  max_percent numeric not null,
  grade_label text not null,
  gpa numeric,
  created_at timestamptz not null default now(),
  unique (school_id, grade_label)
);
create index grade_scales_school_idx on public.grade_scales (school_id, min_percent desc);

create table public.exam_terms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  academic_year_id uuid not null references public.academic_years (id) on delete cascade,
  name text not null,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index exam_terms_school_idx on public.exam_terms (school_id, academic_year_id);

create table public.exam_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  term_id uuid not null references public.exam_terms (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  max_marks numeric not null default 100,
  weightage numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (term_id, class_id, subject_id)
);
create index exam_subjects_term_idx on public.exam_subjects (term_id);

create table public.marks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  term_id uuid not null references public.exam_terms (id) on delete cascade,
  exam_subject_id uuid not null references public.exam_subjects (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  marks_obtained numeric not null,
  grade text,
  entered_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exam_subject_id, student_id)
);
create index marks_student_term_idx on public.marks (student_id, term_id);
create index marks_exam_subject_idx on public.marks (exam_subject_id);

create trigger set_updated_at before update on public.exam_terms
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.exam_subjects
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.marks
  for each row execute function public.set_updated_at();

-- Enforce 0 <= obtained <= max, keep school/term consistent with the exam
-- subject, and compute the grade from the school's grade scale.
create or replace function public.check_marks_bound()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_max numeric;
  v_school uuid;
  v_term uuid;
  v_pct numeric;
begin
  select max_marks, school_id, term_id into v_max, v_school, v_term
  from public.exam_subjects where id = new.exam_subject_id;
  if v_max is null then
    raise exception 'Unknown exam subject';
  end if;
  if new.marks_obtained < 0 or new.marks_obtained > v_max then
    raise exception 'Marks % must be between 0 and %', new.marks_obtained, v_max;
  end if;
  new.school_id := v_school;
  new.term_id := v_term;
  v_pct := (new.marks_obtained / v_max) * 100;
  select grade_label into new.grade
  from public.grade_scales
  where school_id = v_school and min_percent <= v_pct
  order by min_percent desc
  limit 1;
  return new;
end;
$$;

create trigger check_marks_bound before insert or update on public.marks
  for each row execute function public.check_marks_bound();

-- Who may enter a mark: admin, or the teacher assigned to that subject in the
-- student's section. SECURITY DEFINER to read exam_subjects/teacher_assignments/
-- enrollments/staff past their RLS.
create or replace function private.can_enter_marks(p_exam_subject uuid, p_student uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.exam_subjects es
    where es.id = p_exam_subject
      and (
        private.has_role(es.school_id, 'school_admin')
        or private.is_platform_admin()
        or exists (
          select 1 from public.teacher_assignments ta
          join public.staff st on st.id = ta.staff_id
          join public.enrollments e
            on e.section_id = ta.section_id and e.student_id = p_student and e.status = 'active'
          where ta.subject_id = es.subject_id and st.user_id = auth.uid()
        )
      )
  );
$$;

grant execute on function private.can_enter_marks(uuid, uuid) to authenticated, anon;

grant select, insert, update, delete on public.grade_scales to anon, authenticated, service_role;
grant select, insert, update, delete on public.exam_terms to anon, authenticated, service_role;
grant select, insert, update, delete on public.exam_subjects to anon, authenticated, service_role;
grant select, insert, update, delete on public.marks to anon, authenticated, service_role;

alter table public.grade_scales enable row level security;
alter table public.exam_terms enable row level security;
alter table public.exam_subjects enable row level security;
alter table public.marks enable row level security;

-- ---- grade_scales: members read; admin writes ----
create policy grade_scales_select on public.grade_scales
for select using (
  school_id in (select private.auth_school_ids()) or private.is_platform_admin()
);
create policy grade_scales_write on public.grade_scales
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- exam_terms: staff read all; parent reads only when published ----
create policy exam_terms_select on public.exam_terms
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or (
    is_published
    and school_id in (select sm.school_id from public.school_members sm where sm.user_id = auth.uid() and sm.status = 'active')
  )
);
create policy exam_terms_write on public.exam_terms
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- exam_subjects: staff read all; parent reads only for published terms ----
create policy exam_subjects_select on public.exam_subjects
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or exists (select 1 from public.exam_terms t where t.id = term_id and t.is_published)
);
create policy exam_subjects_write on public.exam_subjects
for all using (private.has_role(school_id, 'school_admin') or private.is_platform_admin())
with check (private.has_role(school_id, 'school_admin') or private.is_platform_admin());

-- ---- marks: staff read all; parent reads own child only when published ----
create policy marks_select on public.marks
for select using (
  school_id in (select private.auth_staff_school_ids())
  or private.is_platform_admin()
  or (
    student_id in (select private.my_children())
    and exists (select 1 from public.exam_terms t where t.id = term_id and t.is_published)
  )
);
create policy marks_write on public.marks
for all
using (private.can_enter_marks(exam_subject_id, student_id))
with check (private.can_enter_marks(exam_subject_id, student_id));

-- ---- default grade scale for every existing school ----
insert into public.grade_scales (school_id, min_percent, max_percent, grade_label)
select s.id, b.minp, b.maxp, b.label
from public.schools s
cross join (values (90,100,'A+'),(80,89,'A'),(70,79,'B+'),(60,69,'B'),(50,59,'C'),(40,49,'D'),(0,39,'F'))
  as b(minp, maxp, label)
on conflict (school_id, grade_label) do nothing;
