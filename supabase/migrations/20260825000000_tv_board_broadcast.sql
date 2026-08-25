-- Realtime pings for the public TV board.
--
-- The board runs on the anon key and has no grant on any table, so
-- `postgres_changes` can never deliver a row to it (Realtime evaluates RLS
-- as the subscribing role and filters everything out). Instead these
-- triggers broadcast a contentless ping on the `tv-board` topic, and the
-- board answers each ping by re-calling `tv_active_sessions()`.
--
-- The payload deliberately carries NO session data: the topic is public, and
-- the board refetches through the allow-listed RPC anyway. Never move real
-- fields into it.

create or replace function public.tv_board_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    perform realtime.send(
      jsonb_build_object('at', now()),
      'change',
      'tv-board',
      false  -- public topic; payload is contentless
    );
  exception when others then
    -- CRITICAL: the staff app writes these tables constantly. A failure to
    -- deliver the TV board's ping must never roll back its transaction, so
    -- swallow anything Realtime throws. Worst case the board misses one
    -- update and resyncs on the next change or on reconnect.
    null;
  end;
  return null;
end;
$$;

-- Statement-level, not row-level: one ping per statement is enough, and it
-- keeps a bulk update from emitting hundreds of broadcasts.
drop trigger if exists tv_board_notify on public.sessions;
create trigger tv_board_notify
  after insert or update or delete on public.sessions
  for each statement execute function public.tv_board_notify();

drop trigger if exists tv_board_notify on public.session_service_lines;
create trigger tv_board_notify
  after insert or update or delete on public.session_service_lines
  for each statement execute function public.tv_board_notify();
