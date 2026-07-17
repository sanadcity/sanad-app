-- ══════════════════════════════════════════════
-- SANAD — Database Setup
-- يتناسب مع sanad-v02.html
-- ⚠ يمسح كل البيانات القديمة ويبني من الصفر
-- ══════════════════════════════════════════════

-- ── 1: حذف الجداول القديمة ──

drop table if exists public.notifications     cascade;
drop table if exists public.services          cascade;
drop table if exists public.projects          cascade;
drop table if exists public.profiles          cascade;

-- ── 2: حذف سياسات Storage ──

drop policy if exists "storage_read"   on storage.objects;
drop policy if exists "storage_insert" on storage.objects;
drop policy if exists "storage_delete" on storage.objects;

-- ── 3: إنشاء الجداول ──

create table public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  full_name   text,
  phone       text,
  role        text default 'client',
  status      text default 'active',
  job_title   text,
  office_id   text,
  avatar_url  text,
  office_logo text,
  created_at  timestamptz default now()
);

create table public.projects (
  id               uuid default gen_random_uuid() primary key,
  project_code     text unique,
  created_by       uuid references auth.users,
  owner_name       text not null,
  national_id      text,
  agents           jsonb default '[]',
  owner_email      text,
  type             text default 'normal',
  activity         text default 'سكني',
  gov              text,
  city             text,
  district         text,
  plot             text,
  address          text,
  area             numeric,
  authority_code   text,
  floors           integer,
  has_elevator     boolean default false,
  has_basement     boolean default false,
  has_pool         boolean default false,
  has_pergola      boolean default false,
  dev_status       text default 'قيد التخطيط',
  market_status    text default 'غير محدد',
  price_per_meter  numeric,
  note             text,
  is_compound      boolean default false,
  total_units      integer,
  compound_models  jsonb default '[]',
  stages_data      jsonb default '[]',
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

create table public.services (
  id          uuid default gen_random_uuid() primary key,
  proj_id     uuid references public.projects on delete set null,
  proj_owner  text,
  service     text,
  name        text not null,
  phone       text not null,
  note        text,
  status      text default 'pending',
  created_by  uuid references auth.users,
  created_at  timestamptz default now()
);

create table public.notifications (
  id         uuid default gen_random_uuid() primary key,
  user_id    uuid references auth.users on delete cascade,
  msg        text not null,
  type       text default 'info',
  proj_id    uuid references public.projects on delete set null,
  read       boolean default false,
  created_at timestamptz default now()
);

-- ── 4: Row Level Security ──

alter table public.profiles      enable row level security;
alter table public.projects      enable row level security;
alter table public.services      enable row level security;
alter table public.notifications enable row level security;

-- profiles
create policy "profiles_read"   on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- projects
create policy "projects_read"   on public.projects for select using (auth.role() = 'authenticated');
create policy "projects_insert" on public.projects for insert with check (auth.role() = 'authenticated');
create policy "projects_update" on public.projects for update using (auth.role() = 'authenticated');
create policy "projects_delete" on public.projects for delete using (auth.role() = 'authenticated');

-- services
create policy "services_read"   on public.services for select using (auth.role() = 'authenticated');
create policy "services_insert" on public.services for insert with check (auth.role() = 'authenticated');
create policy "services_update" on public.services for update using (auth.role() = 'authenticated');

-- notifications
create policy "notif_read"   on public.notifications for select using (auth.uid() = user_id);
create policy "notif_insert" on public.notifications for insert with check (auth.role() = 'authenticated');
create policy "notif_update" on public.notifications for update using (auth.uid() = user_id);
create policy "notif_delete" on public.notifications for delete using (auth.uid() = user_id);

-- ── 5: Storage Bucket ──

insert into storage.buckets (id, name, public)
values ('sanad-docs', 'sanad-docs', true)
on conflict (id) do nothing;

create policy "storage_read"   on storage.objects for select using (bucket_id = 'sanad-docs');
create policy "storage_insert" on storage.objects for insert with check (bucket_id = 'sanad-docs' and auth.role() = 'authenticated');
create policy "storage_delete" on storage.objects for delete using (bucket_id = 'sanad-docs' and auth.role() = 'authenticated');

-- ── 6: Realtime ──

alter publication supabase_realtime add table public.projects;
alter publication supabase_realtime add table public.services;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.notifications;

-- ── 7: Admin Profile ──

insert into public.profiles (id, full_name, role, status, created_at)
select id, 'عبدالله إسماعيل', 'admin', 'active', now()
from auth.users
where email = 'curve@outlook.sa'
on conflict (id) do update
  set role = 'admin', status = 'active', full_name = 'عبدالله إسماعيل';

-- ══════════════════════════════════════════════
-- ✅ تم — سجّل دخول بـ curve@outlook.sa
-- ══════════════════════════════════════════════
