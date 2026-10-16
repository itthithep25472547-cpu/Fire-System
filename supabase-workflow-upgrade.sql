-- Run once in Supabase Dashboard > SQL Editor after reviewing.
-- Existing authenticated users are assigned staff on first login; ADMIN_EMAILS users are promoted by the manage-users Edge Function.

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  updated_at timestamptz not null default now()
);

create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.user_roles where user_id = auth.uid()
$$;

revoke all on function public.current_app_role() from public, anon;
grant execute on function public.current_app_role() to authenticated, service_role;

alter table public.user_roles enable row level security;
revoke all on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;

drop policy if exists "user_roles_read_own_or_admin" on public.user_roles;
create policy "user_roles_read_own_or_admin"
  on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.current_app_role() = 'admin');

-- Replace the prior all-authenticated CRUD policies with role-based access.
drop policy if exists "authenticated users can manage policies" on public.fire_insurance_policies;
drop policy if exists "policies_read_staff_admin" on public.fire_insurance_policies;
drop policy if exists "policies_insert_staff_admin" on public.fire_insurance_policies;
drop policy if exists "policies_update_staff_admin" on public.fire_insurance_policies;
drop policy if exists "policies_delete_admin" on public.fire_insurance_policies;
create policy "policies_read_staff_admin" on public.fire_insurance_policies
  for select to authenticated using (public.current_app_role() in ('admin', 'staff'));
create policy "policies_insert_staff_admin" on public.fire_insurance_policies
  for insert to authenticated with check (public.current_app_role() in ('admin', 'staff'));
create policy "policies_update_staff_admin" on public.fire_insurance_policies
  for update to authenticated using (public.current_app_role() in ('admin', 'staff'))
  with check (public.current_app_role() in ('admin', 'staff'));
create policy "policies_delete_admin" on public.fire_insurance_policies
  for delete to authenticated using (public.current_app_role() = 'admin');

drop policy if exists "authenticated users can manage notices" on public.fire_insurance_notices;
drop policy if exists "notices_read_staff_admin" on public.fire_insurance_notices;
drop policy if exists "notices_insert_staff_admin" on public.fire_insurance_notices;
drop policy if exists "notices_update_staff_admin" on public.fire_insurance_notices;
drop policy if exists "notices_delete_admin" on public.fire_insurance_notices;
create policy "notices_read_staff_admin" on public.fire_insurance_notices
  for select to authenticated using (public.current_app_role() in ('admin', 'staff'));
create policy "notices_insert_staff_admin" on public.fire_insurance_notices
  for insert to authenticated with check (public.current_app_role() in ('admin', 'staff'));
create policy "notices_update_staff_admin" on public.fire_insurance_notices
  for update to authenticated using (public.current_app_role() in ('admin', 'staff'))
  with check (public.current_app_role() in ('admin', 'staff'));
create policy "notices_delete_admin" on public.fire_insurance_notices
  for delete to authenticated using (public.current_app_role() = 'admin');

create table if not exists public.email_send_logs (
  id uuid primary key default gen_random_uuid(),
  policy_id text,
  notice_id text,
  policy_number text,
  expiry_date date,
  recipient_email text not null,
  subject text not null,
  language text not null default 'th' check (language in ('th', 'en')),
  send_type text not null default 'manual' check (send_type in ('manual', 'scheduled')),
  days_before integer,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  provider_message_id text,
  error_message text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create index if not exists email_send_logs_created_at_idx
  on public.email_send_logs (created_at desc);
create index if not exists email_send_logs_policy_idx
  on public.email_send_logs (policy_id, expiry_date, days_before);
create unique index if not exists email_send_logs_scheduled_once_idx
  on public.email_send_logs (policy_id, expiry_date, days_before)
  where send_type = 'scheduled' and status = 'sent';

alter table public.email_send_logs enable row level security;
revoke all on public.email_send_logs from anon, authenticated;
grant select on public.email_send_logs to authenticated;
grant all on public.email_send_logs to service_role;
drop policy if exists "email_logs_read_staff_admin" on public.email_send_logs;
create policy "email_logs_read_staff_admin" on public.email_send_logs
  for select to authenticated
  using (public.current_app_role() in ('admin', 'staff'));
