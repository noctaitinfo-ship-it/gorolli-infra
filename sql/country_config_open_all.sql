-- ============================================================
-- GoRolli — OPEN ALL: GLOBAALNE AVAMINE, AUTOMAATNE ARVELDUS
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina.
-- ASENDAB default-deny poliitika (country_gates_default_deny.sql).
--
-- UUS ÄRIOTSUS:
--   * KÕIK country_config riigid: kõik lülitid LAHTI (booking, payments,
--     payouts, host, client, connect) — automaatne arveldus igal pool.
--   * TUNDMATU riik (rida puudub): booking + makse LUBATUD, alati EUR-is.
--     Raha laekub GoRolli kontole; hostile makstakse edasi (Stripe payout
--     kui võimalik, muidu käsitsi). Blokeerib AINULT admini selge keeld
--     (country_status='DISABLED' või lüliti false).
--   * Charge jääb ALATI EUR-i — seda hoiavad SERVERI guardid
--     (payments-checkout arvutab booking-realt, payments-authorize +
--     initPayment EUR-guardid). Siin midagi muuta pole vaja.
-- ============================================================

-- 1) KÕIK konfitud riigid: lülitid lahti, live/ACTIVE, auto payout ----------------
update public.country_config set
  market_status            = 'live',
  country_status           = 'ACTIVE',
  client_enabled           = true,
  host_enabled             = true,
  booking_enabled          = true,
  payments_enabled         = true,
  payouts_enabled          = true,
  stripe_supported         = true,
  stripe_connect_supported = true,
  notes                    = 'Global EUR live market. Auto payout enabled.',
  updated_at               = now();

-- 2) Booking/makse gate — DEFAULT ALLOW -------------------------------------------
-- Tundmatu/tühi riik või puuduv rida -> LUBATUD (charge on niikuinii EUR).
-- Blokeerib AINULT admini selge keeld.
create or replace function public.gorolli_country_can_take_paid_booking(p_country text)
returns boolean language sql stable as $$
  select case
    when p_country is null or btrim(p_country) = '' then true
    else coalesce((
      select not (
            c.country_status = 'DISABLED'
         or c.booking_enabled  = false
         or c.payments_enabled = false
         or c.stripe_supported = false
      )
      from public.country_config c
      where c.country_code = upper(p_country)
    ), true)
  end;
$$;

-- 3) Payout gate — DEFAULT ALLOW ---------------------------------------------------
create or replace function public.gorolli_country_can_payout(p_country text)
returns boolean language sql stable as $$
  select case
    when p_country is null or btrim(p_country) = '' then true
    else coalesce((
      select not (c.country_status = 'DISABLED' or c.payouts_enabled = false)
      from public.country_config c
      where c.country_code = upper(p_country)
    ), true)
  end;
$$;

-- 4) Kliendi pre-check — tundmatu riik = lubatud, EUR ------------------------------
create or replace function public.gorolli_booking_gate_for_host(p_host_uid text)
returns jsonb language plpgsql stable as $$
declare
  v_country text;
  v_cfg public.country_config%rowtype;
  v_can  boolean;
begin
  select country_code into v_country from public.hosts where host_uid = p_host_uid;
  select * into v_cfg from public.country_config
    where country_code = upper(coalesce(v_country,''));

  v_can := public.gorolli_country_can_take_paid_booking(v_country);
  return jsonb_build_object(
    'can_book', v_can,
    'country_code', coalesce(v_cfg.country_code, upper(coalesce(v_country,''))),
    'country_status', coalesce(v_cfg.country_status, 'ACTIVE'),   -- tundmatu -> lubatud
    'market_status',  coalesce(v_cfg.market_status,  'live'),
    'currency', 'eur',                                            -- charge ALATI eur
    'reason', case when v_can then 'OK' else 'Country is disabled by admin' end
  );
end $$;

grant execute on function public.gorolli_booking_gate_for_host(text) to anon, authenticated;

-- 5) bookings BEFORE INSERT trigger — blokeerib AINULT admini keelu ----------------
create or replace function public.gorolli_enforce_booking_country_gate()
returns trigger language plpgsql as $$
declare
  v_country text;
begin
  select country_code into v_country from public.hosts where host_uid = new.host_uid;

  if not public.gorolli_country_can_take_paid_booking(v_country) then
    raise exception
      'GOROLLI_COUNTRY_GATE_BLOCKED: Country is disabled by admin (%)',
      coalesce(nullif(v_country,''), 'unknown')
      using errcode = 'check_violation';
  end if;

  return new;
end $$;

drop trigger if exists trg_enforce_booking_country_gate on public.bookings;
create trigger trg_enforce_booking_country_gate
  before insert on public.bookings
  for each row execute function public.gorolli_enforce_booking_country_gate();

-- 6) KONTROLL -----------------------------------------------------------------------
-- select count(*) from public.country_config where payouts_enabled;            -- 51 (kõik)
-- select count(*) from public.country_config where market_status <> 'live';    -- 0
-- select public.gorolli_country_can_take_paid_booking('EE');   -- true
-- select public.gorolli_country_can_take_paid_booking('US');   -- true
-- select public.gorolli_country_can_take_paid_booking('NG');   -- true
-- select public.gorolli_country_can_take_paid_booking('XX');   -- true  (TUNDMATU -> LUBATUD)
-- select public.gorolli_country_can_payout('XX');              -- true  (Stripe otsustab päriselt)
-- PÄRAST SEDA: supabase functions deploy release-payout connect-onboard
