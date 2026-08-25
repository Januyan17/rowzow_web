-- Add `customer_name` to the public TV board's session feed.
--
-- Postgres cannot change a function's return type with CREATE OR REPLACE, so
-- adding a column requires DROP + CREATE. Nothing else calls this function
-- (the staff app talks to the tables directly), so the brief gap only
-- affects the board.
--
-- SAFETY: the column list below IS the security boundary. This function is
-- SECURITY DEFINER, so it reads straight past RLS, and the board it feeds is
-- public on the internet. `session_service_lines.metadata` also contains
-- `planned_price`, `grace_period_minutes`, `allow_overtime` and more — never
-- select `metadata` wholesale, only the individual keys named here.

drop function if exists public.tv_active_sessions();

create function public.tv_active_sessions()
returns table (
  service_type              text,
  ps5_station_indices       int[],
  start_time                timestamptz,
  planned_duration_minutes  int,
  paused_at                 timestamptz,
  total_paused_seconds      int,
  ps5_units                 int,
  theatre_persons           int,
  customer_name             text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.service_type::text,

    -- metadata->'ps5_station_indices' is a JSON array of ints. Guard on
    -- jsonb_typeof: a missing key yields no rows, but a JSON scalar would
    -- raise, and this function must never error on a public screen.
    coalesce(
      (
        select array_agg(e::int order by ord)
        from jsonb_array_elements_text(
               case
                 when jsonb_typeof(l.metadata->'ps5_station_indices') = 'array'
                   then l.metadata->'ps5_station_indices'
                 else '[]'::jsonb
               end
             ) with ordinality as t(e, ord)
      ),
      '{}'::int[]
    ) as ps5_station_indices,

    l.start_time,
    nullif(l.metadata->>'planned_duration_minutes', '')::int,

    -- The staff app records a live pause as metadata.pause_time and clears
    -- it on resume; the board reads it as `paused_at`.
    nullif(l.metadata->>'pause_time', '')::timestamptz,

    coalesce(nullif(l.metadata->>'total_paused_seconds', '')::int, 0),
    coalesce(nullif(l.metadata->>'ps5_units', '')::int, 1),
    coalesce(nullif(l.metadata->>'theatre_persons', '')::int, 0),

    -- LEFT JOIN, so a walk-in with no customer row still appears on the
    -- board (the client renders the station label alone when this is null).
    c.name
  from public.sessions s
  join public.session_service_lines l on l.session_id = s.id
  left join public.customers c on c.id = s.customer_id
  where s.status = 'active'
    and l.end_time is null;
$$;

revoke all on function public.tv_active_sessions() from public;
grant execute on function public.tv_active_sessions() to anon, authenticated;
