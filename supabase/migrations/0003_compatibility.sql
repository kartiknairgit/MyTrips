-- Flight Compatibility Report — consent-based, two-user comparison.
--
-- Design constraint: RLS means neither user can ever read the other's raw
-- flights table. This feature works by having BOTH users explicitly accept
-- a comparison request; only then does a SECURITY DEFINER function compute
-- an overlap score, returning aggregated numbers to both parties — never
-- either user's raw flight list.

create type compat_status as enum ('pending', 'accepted', 'declined');

create table if not exists compat_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users (id) on delete cascade,
  target_id uuid not null references auth.users (id) on delete cascade,
  status compat_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> target_id)
);

alter table compat_requests enable row level security;

-- Each side can only see requests they're part of.
create policy "compat: read own requests" on compat_requests
  for select using (auth.uid() = requester_id or auth.uid() = target_id);

create policy "compat: create as requester" on compat_requests
  for insert with check (auth.uid() = requester_id);

-- Only the target can accept/decline; requester can't self-approve.
create policy "compat: target responds" on compat_requests
  for update using (auth.uid() = target_id)
  with check (auth.uid() = target_id);

-- ============================================================
-- Compatibility score — only computable once BOTH sides consented.
-- ============================================================

create or replace function get_compat_report(request_id uuid)
returns table (
  shared_airports int,
  shared_routes int,
  shared_airlines int,
  compatibility_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  req compat_requests;
begin
  select * into req from compat_requests where id = request_id;

  if req is null then
    raise exception 'Request not found';
  end if;

  if auth.uid() not in (req.requester_id, req.target_id) then
    raise exception 'Not a party to this request';
  end if;

  if req.status <> 'accepted' then
    raise exception 'Both users must accept before a report can be generated';
  end if;

  return query
  with a_airports as (
    select distinct iata_code from user_top_airports where user_id = req.requester_id
  ),
  b_airports as (
    select distinct iata_code from user_top_airports where user_id = req.target_id
  ),
  a_routes as (
    select distinct route_pair from user_top_routes where user_id = req.requester_id
  ),
  b_routes as (
    select distinct route_pair from user_top_routes where user_id = req.target_id
  ),
  a_airlines as (
    select distinct airline_iata from flights where user_id = req.requester_id
  ),
  b_airlines as (
    select distinct airline_iata from flights where user_id = req.target_id
  )
  select
    (select count(*) from a_airports where iata_code in (select iata_code from b_airports)),
    (select count(*) from a_routes where route_pair in (select route_pair from b_routes)),
    (select count(*) from a_airlines where airline_iata in (select airline_iata from b_airlines)),
    -- Playful, not scientific: weighted overlap normalised to 0-100.
    round(least(100, (
      (select count(*) from a_airports where iata_code in (select iata_code from b_airports)) * 10 +
      (select count(*) from a_routes where route_pair in (select route_pair from b_routes)) * 15 +
      (select count(*) from a_airlines where airline_iata in (select airline_iata from b_airlines)) * 5
    ))::numeric, 1);
end;
$$;

revoke all on function get_compat_report from public;
grant execute on function get_compat_report to authenticated;
