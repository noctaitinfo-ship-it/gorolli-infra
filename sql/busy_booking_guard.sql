-- ============================================================
-- GoRolli — SERVERIPOOLNE FANTOOMI-KAITSE (busy booking guard)
-- 2026-07-06. Käivita Supabase SQL Editoris KOHE.
-- Hõivatud-kuva (busy_display) haagisele EI SAA broneeringut luua
-- ÜKSKÕIK millise kliendiversiooni / API-kutse kaudu. Päris haagiseid
-- (busy_display=false) see ei puuduta kuidagi.
-- ============================================================
create or replace function public.gorolli_block_busy_trailer_booking()
returns trigger language plpgsql as $$
declare
  v_busy boolean;
begin
  select (coalesce(busy_display,false) and not coalesce(is_available,false))
    into v_busy
    from public.trailers where id = new.trailer_id;
  if coalesce(v_busy, false) then
    raise exception 'GOROLLI_BUSY_TRAILER: trailer % is busy-display only, booking blocked', new.trailer_id
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

drop trigger if exists trg_block_busy_trailer_booking on public.bookings;
create trigger trg_block_busy_trailer_booking
  before insert on public.bookings
  for each row execute function public.gorolli_block_busy_trailer_booking();

-- KORISTUS: kustuta juba tekkinud fantoomi-testbroneeringud (ilma makseta read)
delete from public.bookings b
 using public.trailers t
 where b.trailer_id = t.id
   and coalesce(t.busy_display,false) = true
   and coalesce(t.is_available,false) = false
   and coalesce(b.payment_status,'') <> 'paid';

-- KONTROLL (peab andma vea 'GOROLLI_BUSY_TRAILER' kui proovid käsitsi):
-- insert into public.bookings (trailer_id, host_uid, status)
--   select id, host_uid, 'requested' from public.trailers
--    where busy_display limit 1;  -- ÄRA päriselt jooksuta, see ongi blokk-test
