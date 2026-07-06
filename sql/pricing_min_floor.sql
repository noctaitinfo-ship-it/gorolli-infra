-- ============================================================
-- GoRolli — PRICING MIN FLOOR: räbu-hinnad ei saa KUNAGI live olla
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina. Idempotentne.
-- Põrandad = äpi enda soovituslikud madalaimad (trailer_pricing _applyLowest):
--   1-3h >= 5, päev >= 12, nädal >= 60, kuu >= 180 (EUR).
-- Kehtib ainult EUR-profiilidele (tulevased muud valuutad ei ole piiratud).
-- Mõjub KOHE: pärast käivitamist näitab Hinnakujunduse ekraan (refresh)
-- ja kliendi kaart juba parandatud hindu — deploy pole vaja.
-- ============================================================

-- 1) IGAVENE VALVUR: enne igat insertit/updatet tõsta alla-põranda hinnad üles
create or replace function public.gorolli_pricing_min_floor()
returns trigger language plpgsql as $$
begin
  if new.trailer_id is not null
     and lower(coalesce(new.currency, 'eur')) = 'eur' then
    if coalesce(new.short_rental_price, 0) > 0 and new.short_rental_price < 5 then
      new.short_rental_price := 5;
    end if;
    if coalesce(new.hourly_rate, 0) > 0 and new.hourly_rate < 5 then
      new.hourly_rate := 5;
    end if;
    if coalesce(new.daily_rate, 0) > 0 and new.daily_rate < 12 then
      new.daily_rate := 12;
    end if;
    if coalesce(new.weekly_rate, 0) > 0 and new.weekly_rate < 60 then
      new.weekly_rate := 60;
    end if;
    if coalesce(new.monthly_rate, 0) > 0 and new.monthly_rate < 180 then
      new.monthly_rate := 180;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_pricing_min_floor on public.pricing_profiles;
create trigger trg_pricing_min_floor
  before insert or update on public.pricing_profiles
  for each row execute function public.gorolli_pricing_min_floor();

-- 2) PARANDA OLEMASOLEV RÄBU KOHE (kõik trailer-profiilid, EUR)
update public.pricing_profiles
   set short_rental_price = case when coalesce(short_rental_price,0) > 0 and short_rental_price < 5 then 5 else short_rental_price end,
       hourly_rate        = case when coalesce(hourly_rate,0)        > 0 and hourly_rate        < 5 then 5 else hourly_rate end,
       daily_rate         = case when coalesce(daily_rate,0)         > 0 and daily_rate         < 12 then 12 else daily_rate end,
       weekly_rate        = case when coalesce(weekly_rate,0)        > 0 and weekly_rate        < 60 then 60 else weekly_rate end,
       monthly_rate       = case when coalesce(monthly_rate,0)       > 0 and monthly_rate       < 180 then 180 else monthly_rate end,
       updated_at         = now()
 where trailer_id is not null
   and lower(coalesce(currency, 'eur')) = 'eur'
   and (   (coalesce(short_rental_price,0) > 0 and short_rental_price < 5)
        or (coalesce(hourly_rate,0)        > 0 and hourly_rate        < 5)
        or (coalesce(daily_rate,0)         > 0 and daily_rate         < 12)
        or (coalesce(weekly_rate,0)        > 0 and weekly_rate        < 60)
        or (coalesce(monthly_rate,0)       > 0 and monthly_rate       < 180));

-- 3) Kaardi "alates" hind sünkroonis aktiivse profiiliga
update public.trailers t
   set price_per_hr = pp.short_rental_price
  from public.pricing_profiles pp
 where pp.trailer_id = t.id
   and coalesce(pp.is_active, true) = true
   and coalesce(pp.short_rental_price, 0) > 0
   and t.price_per_hr is distinct from pp.short_rental_price;

-- 4) KONTROLL: ühtegi alla-põranda AKTIIVSET hinda ei tohi jääda (oodatud: 0 rida)
select id, trailer_id, name, short_rental_price, daily_rate, weekly_rate, monthly_rate
  from public.pricing_profiles
 where trailer_id is not null and coalesce(is_active,true) = true
   and lower(coalesce(currency,'eur')) = 'eur'
   and (   (coalesce(short_rental_price,0) > 0 and short_rental_price < 5)
        or (coalesce(daily_rate,0)   > 0 and daily_rate   < 12)
        or (coalesce(weekly_rate,0)  > 0 and weekly_rate  < 60)
        or (coalesce(monthly_rate,0) > 0 and monthly_rate < 180));
