-- ══════════════════════════════════════════════
-- SANAD — Complete Database Setup v4
-- ⚠ يمسح كل البيانات القديمة ويبني من الصفر
-- ══════════════════════════════════════════════

-- ── STEP 1: حذف الجداول (السياسات تتمسح تلقائياً) ──

drop table if exists public.audit_log         cascade;
drop table if exists public.tasks             cascade;
drop table if exists public.tickets           cascade;
drop table if exists public.office_financials cascade;
drop table if exists public.brokers           cascade;
drop table if exists public.notifications     cascade;
drop table if exists public.services          cascade;
drop table if exists public.projects          cascade;
drop table if exists public.profiles          cascade;

-- ── STEP 2: حذف سياسات Storage فقط ──

drop policy if exists "storage_read"   on storage.objects;
drop policy if exists "storage_insert" on storage.objects;
drop policy if exists "storage_delete" on storage.objects;

-- ── STEP 3: إنشاء الجداول ──

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
  sanad_id         text unique,
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
  neighborhood     text,
  block            text,
  plot             text,
  address          text,
  latitude         numeric,
  longitude        numeric,
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
  lead_source      text,
  broker_id        uuid,
  note             text,
  is_compound      boolean default false,
  total_units      integer,
  compound_models  jsonb default '[]',
  stages_data      jsonb default '[]',
  health_score     integer default 0,
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

create table public.brokers (
  id                   uuid default gen_random_uuid() primary key,
  name                 text not null,
  phone                text,
  city                 text,
  notes                text,
  status               text default 'active',
  total_projects       integer default 0,
  total_contracts      numeric default 0,
  paid_commission      numeric default 0,
  remaining_commission numeric default 0,
  created_by           uuid references auth.users,
  created_at           timestamptz default now()
);

create table public.office_financials (
  id             uuid default gen_random_uuid() primary key,
  proj_id        uuid references public.projects on delete set null,
  proj_name      text,
  office_id      text,
  contract_value numeric default 0,
  collected      numeric default 0,
  expenses       numeric default 0,
  contract_date  date,
  notes          text,
  created_by     uuid references auth.users,
  created_at     timestamptz default now()
);

create table public.tickets (
  id          uuid default gen_random_uuid() primary key,
  title       text,
  type        text,
  proj_id     uuid references public.projects on delete set null,
  priority    text default 'low',
  status      text default 'open',
  assigned_to uuid references auth.users,
  due_date    date,
  description text,
  comments    jsonb default '[]',
  created_by  uuid references auth.users,
  created_at  timestamptz default now()
);

create table public.tasks (
  id          uuid default gen_random_uuid() primary key,
  title       text not null,
  proj_id     uuid references public.projects on delete set null,
  assigned_to uuid references auth.users,
  due_date    date,
  priority    text default 'low',
  status      text default 'جديدة',
  progress    integer default 0,
  notes       text,
  created_by  uuid references auth.users,
  created_at  timestamptz default now()
);

create table public.audit_log (
  id          uuid default gen_random_uuid() primary key,
  user_id     uuid references auth.users,
  user_name   text,
  action      text,
  entity      text,
  entity_id   uuid,
  details     text,
  created_at  timestamptz default now()
);

-- ── STEP 4: Row Level Security ──

alter table public.profiles          enable row level security;
alter table public.projects          enable row level security;
alter table public.services          enable row level security;
alter table public.notifications     enable row level security;
alter table public.brokers           enable row level security;
alter table public.office_financials enable row level security;
alter table public.tickets           enable row level security;
alter table public.tasks             enable row level security;
alter table public.audit_log         enable row level security;

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
create policy "notifications_read"   on public.notifications for select using (auth.uid() = user_id);
create policy "notifications_insert" on public.notifications for insert with check (auth.role() = 'authenticated');
create policy "notifications_update" on public.notifications for update using (auth.uid() = user_id);
create policy "notifications_delete" on public.notifications for delete using (auth.uid() = user_id);

-- brokers
create policy "brokers_read"   on public.brokers for select using (auth.role() = 'authenticated');
create policy "brokers_insert" on public.brokers for insert with check (auth.role() = 'authenticated');
create policy "brokers_update" on public.brokers for update using (auth.role() = 'authenticated');
create policy "brokers_delete" on public.brokers for delete using (auth.role() = 'authenticated');

-- office_financials
create policy "fin_read"   on public.office_financials for select using (auth.role() = 'authenticated');
create policy "fin_insert" on public.office_financials for insert with check (auth.role() = 'authenticated');
create policy "fin_update" on public.office_financials for update using (auth.role() = 'authenticated');

-- tickets
create policy "tickets_read"   on public.tickets for select using (auth.role() = 'authenticated');
create policy "tickets_insert" on public.tickets for insert with check (auth.role() = 'authenticated');
create policy "tickets_update" on public.tickets for update using (auth.role() = 'authenticated');

-- tasks
create policy "tasks_read"   on public.tasks for select using (auth.role() = 'authenticated');
create policy "tasks_insert" on public.tasks for insert with check (auth.role() = 'authenticated');
create policy "tasks_update" on public.tasks for update using (auth.role() = 'authenticated');

-- audit_log
create policy "audit_log_read"   on public.audit_log for select using (auth.role() = 'authenticated');
create policy "audit_log_insert" on public.audit_log for insert with check (auth.role() = 'authenticated');

-- ── STEP 5: Storage Bucket ──

insert into storage.buckets (id, name, public)
values ('sanad-docs', 'sanad-docs', true)
on conflict (id) do nothing;

create policy "storage_read"   on storage.objects for select using (bucket_id = 'sanad-docs');
create policy "storage_insert" on storage.objects for insert with check (bucket_id = 'sanad-docs' and auth.role() = 'authenticated');
create policy "storage_delete" on storage.objects for delete using (bucket_id = 'sanad-docs' and auth.role() = 'authenticated');

-- ── STEP 6: Realtime ──

alter publication supabase_realtime add table public.projects;
alter publication supabase_realtime add table public.services;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.tickets;
alter publication supabase_realtime add table public.tasks;

-- ── STEP 7: Admin ──

insert into public.profiles (id, full_name, role, status, created_at)
select id, 'عبدالله إسماعيل', 'admin', 'active', now()
from auth.users
where email = 'curve@outlook.sa'
on conflict (id) do update
  set role = 'admin', status = 'active', full_name = 'عبدالله إسماعيل';

-- ══════════════════════════════════════════════
-- ✅ تم — سجّل دخول بـ curve@outlook.sa
-- ══════════════════════════════════════════════
