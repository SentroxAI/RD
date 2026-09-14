-- RD Lot Register shared backend
-- Run this in Supabase SQL Editor, then create agent users in Authentication.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  agent_id text not null unique,
  display_name text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.profiles(id) on delete cascade,
  account_number text not null,
  name text not null,
  monthly_amount numeric(12,2) not null check (monthly_amount > 0),
  month_paid_upto integer,
  next_due_date text not null default '',
  details text not null default '',
  created_at timestamptz not null default now(),
  unique (agent_id, account_number)
);

alter table public.members add column if not exists month_paid_upto integer;
alter table public.members add column if not exists next_due_date text not null default '';

create table if not exists public.payments (
  member_id uuid not null references public.members(id) on delete cascade,
  payment_year integer not null check (payment_year between 2000 and 2200),
  payment_month integer not null check (payment_month between 0 and 11),
  paid boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (member_id, payment_year, payment_month)
);

alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.payments enable row level security;

drop policy if exists "agents read own profile" on public.profiles;
drop policy if exists "agents create own profile" on public.profiles;
drop policy if exists "agents update own profile" on public.profiles;
drop policy if exists "agents read own members" on public.members;
drop policy if exists "agents create own members" on public.members;
drop policy if exists "agents update own members" on public.members;
drop policy if exists "agents delete own members" on public.members;
drop policy if exists "agents read own payments" on public.payments;
drop policy if exists "agents create own payments" on public.payments;
drop policy if exists "agents update own payments" on public.payments;
drop policy if exists "agents delete own payments" on public.payments;

create policy "agents read own profile" on public.profiles for select using (id = auth.uid());
create policy "agents create own profile" on public.profiles for insert with check (id = auth.uid());
create policy "agents update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "agents read own members" on public.members for select using (agent_id = auth.uid());
create policy "agents create own members" on public.members for insert with check (agent_id = auth.uid());
create policy "agents update own members" on public.members for update using (agent_id = auth.uid()) with check (agent_id = auth.uid());
create policy "agents delete own members" on public.members for delete using (agent_id = auth.uid());
create policy "agents read own payments" on public.payments for select using (exists (select 1 from public.members m where m.id = member_id and m.agent_id = auth.uid()));
create policy "agents create own payments" on public.payments for insert with check (exists (select 1 from public.members m where m.id = member_id and m.agent_id = auth.uid()));
create policy "agents update own payments" on public.payments for update using (exists (select 1 from public.members m where m.id = member_id and m.agent_id = auth.uid()));
create policy "agents delete own payments" on public.payments for delete using (exists (select 1 from public.members m where m.id = member_id and m.agent_id = auth.uid()));

-- After creating an auth user, add its profile:
-- insert into public.profiles (id, agent_id, display_name)
-- values ('AUTH_USER_UUID', 'POST-OFFICE-AGENT-ID', 'Agent name');
