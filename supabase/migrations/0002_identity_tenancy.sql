-- Phase 1: core identity & tenancy tables (doc 05 §2)

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  logo_url text,
  address text,
  city text,
  state text,
  pincode text,
  phone text,
  email text,
  timezone text not null default 'Asia/Kolkata',
  currency text not null default 'INR',
  status member_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 1:1 with auth.users
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  email text,
  avatar_url text,
  is_platform_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- tenant-scoped role: a user <-> school link
create table public.school_members (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role app_role not null,
  status member_status not null default 'invited',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, user_id)
);

create index school_members_user_id_idx on public.school_members (user_id);
create index school_members_school_id_role_idx on public.school_members (school_id, role);

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- exactly one active academic year per school (hard constraint)
create unique index academic_years_one_active_per_school
  on public.academic_years (school_id)
  where (is_active);

-- ---- triggers ----

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.schools
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.school_members
  for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.academic_years
  for each row execute function public.set_updated_at();

-- auth.users -> profiles
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, email, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone',
    new.email,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- enforce a single active academic year per school (auto-deactivate the others)
create or replace function public.enforce_one_active_academic_year()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_active then
    update public.academic_years
    set is_active = false
    where school_id = new.school_id
      and id <> new.id
      and is_active = true;
  end if;
  return new;
end;
$$;

create trigger one_active_year
  before insert or update of is_active on public.academic_years
  for each row execute function public.enforce_one_active_academic_year();
