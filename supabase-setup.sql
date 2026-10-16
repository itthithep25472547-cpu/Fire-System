-- Run this script in Supabase Dashboard > SQL Editor.
create table if not exists public.fire_insurance_policies (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fire_insurance_notices (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fire_insurance_policies enable row level security;
alter table public.fire_insurance_notices enable row level security;

grant select, insert, update, delete on public.fire_insurance_policies to authenticated;
grant select, insert, update, delete on public.fire_insurance_notices to authenticated;

drop policy if exists "authenticated users can manage policies" on public.fire_insurance_policies;
create policy "authenticated users can manage policies"
  on public.fire_insurance_policies for all to authenticated
  using (true) with check (true);

drop policy if exists "authenticated users can manage notices" on public.fire_insurance_notices;
create policy "authenticated users can manage notices"
  on public.fire_insurance_notices for all to authenticated
  using (true) with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'fire_insurance_policies'
  ) then
    alter publication supabase_realtime add table public.fire_insurance_policies;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'fire_insurance_notices'
  ) then
    alter publication supabase_realtime add table public.fire_insurance_notices;
  end if;
end $$;
