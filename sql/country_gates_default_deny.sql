-- ============================================================
-- GoRolli — COUNTRY GATES: DEFAULT DENY (tundmatu riik = blokeeritud)
-- 2026-07-03. Käivita Supabase SQL Editoris ÜHE plokina.
-- JÄRJEKORD: 1) sql/country_config.sql  2) sql/country_config_46_markets.sql
--            3) SEE FAIL  4) supabase functions deploy release-payout connect-onboard
--
-- Asendab senise "GLOBAL LAUNCH = no row -> ALLOW" poliitika:
--   * country_config reata riik  -> booking/makse/payout/host KEELATUD
--   * ainult country_status='ACTIVE' (= market_status 'live') + lülitid lubavad
--   * beta (WAITLIST) ja blocked (DISABLED) EI saa maksta/broneerida/payout'ida
--   * selge viga: "Country is not enabled yet"
-- Funktsioonide nimed/signatuurid EI muutu -> trigger ja kliendid töötavad edasi.
-- EI puuduta: payments-authorize EUR-guardi, Checkouti, Adaptive Pricingut,
-- valuutasid, UI-d, logineid, verifyEmaili, Cloudflare'i.
-- ============================================================

-- 1) Broneeringu/makse gate — DEFAULT DENY --------------------------------------
-- Tundmatu/tühi riik või puuduv config-rida -> FALSE.
-- Läbi laseb AINULT: ACTIVE + booking_enabled + payments_enabled + stripe_supported.
create or replace function public.gorolli_country_can_take_paid_booking(p_country text)
returns boolean language sql stable as $$
  select coalesce((
    select (c.country_status = 'ACTIVE'
        and c.booking_enabled
        and c.payments_enabled
        and c.stripe_supported)
    from public.country_config c
    where c.country_code = upper(coalesce(p_country,''))
  ), false);
$$;

-- 2) Payout gate — DEFAULT DENY --------------------------------------------------
create or replace function public.gorolli_country_can_payout(p_country text)
returns boolean language sql stable as $$
  select coalesce((
    select (c.country_status = 'ACTIVE' and c.payouts_enabled)
    from public.country_config c
    where c.country_code = upper(coalesce(p_country,''))
  ), false);
$$;

-- 3) Kliendi pre-check (jsonb) — tundmatu riik -> blokeeritud selge põhjusega ----
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
    'country_status', coalesce(v_cfg.country_status, 'DISABLED'),   -- tundmatu -> DISABLED
    'market_status',  coalesce(v_cfg.market_status,  'blocked'),    -- tundmatu -> blocked
    'currency', lower(coalesce(v_cfg.currency, 'eur')),             -- kuva-fallback
    'reason', case when v_can then 'OK' else 'Country is not enabled yet' end
  );
end $$;

grant execute on function public.gorolli_booking_gate_for_host(text) to anon, authenticated;

-- 4) KÕVA jõustamine: bookings BEFORE INSERT — selge veatekst --------------------
create or replace function public.gorolli_enforce_booking_country_gate()
returns trigger language plpgsql as $$
declare
  v_country text;
begin
  select country_code into v_country from public.hosts where host_uid = new.host_uid;

  if not public.gorolli_country_can_take_paid_booking(v_country) then
    raise exception
      'GOROLLI_COUNTRY_GATE_BLOCKED: Country is not enabled yet (%)',
      coalesce(nullif(v_country,''), 'unknown')
      using errcode = 'check_violation';
  end if;

  return new;
end $$;

drop trigger if exists trg_enforce_booking_country_gate on public.bookings;
create trigger trg_enforce_booking_country_gate
  before insert on public.bookings
  for each row execute function public.gorolli_enforce_booking_country_gate();

-- 5) KONTROLL --------------------------------------------------------------------
-- select public.gorolli_country_can_take_paid_booking('EE');  -- true  (live)
-- select public.gorolli_country_can_take_paid_booking('SE');  -- false (beta: lülitid off)
-- select public.gorolli_country_can_take_paid_booking('IN');  -- false (blocked)
-- select public.gorolli_country_can_take_paid_booking('XX');  -- false (TUNDMATU -> DENY!)
-- select public.gorolli_country_can_take_paid_booking(null);  -- false
-- select public.gorolli_country_can_payout('EE');             -- true
-- select public.gorolli_country_can_payout('XX');             -- false
-- select public.gorolli_booking_gate_for_host('<tundmatu-riigi-host>');
--   -- {"can_book": false, "market_status": "blocked", "reason": "Country is not enabled yet", ...}
