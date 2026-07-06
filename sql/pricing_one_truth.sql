-- ============================================================
-- GoRolli — PRICING ONE TRUTH: esmane sisestus = profiil = kliendi hind
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina. Idempotentne.
--
-- PROBLEEM, mida see lahendab:
--   * Haagise lisamine külvab hinnad trailer-profiili 'Default' (õige).
--   * Avalehe "aktiveeri hinnad" dialoog lõi VEEL ühe tühja profiili
--     ('<nimi>Pricing') -> topeltprofiilid; valikuloogika (uusim id) võis
--     lasta räbu-profiilil päris hinnad üle trumbata.
-- UUS GARANTII:
--   * Igal haagisel on AINULT ÜKS aktiivne trailer-profiil.
--   * PÄRIS hindadega uus profiil võidab (esmane sisestus = tõde);
--     TÜHI uus profiil ei tohi kunagi olemasolevat tõde varjutada.
--   * trailers.price_per_hr hoitakse profiili short-hinnaga sünkroonis
--     (kaardi "alates" hind = sama tõde).
--   * Hilisemad muudatused: Hinnakujunduse ekraan (kirjutab profiili JA
--     sünkroonib price_per_hr tagasi — see loogika oli äpis juba olemas).
-- ============================================================

-- 1) TURVAVÕRK edaspidiseks: üks aktiivne profiil haagise kohta ------------------
create or replace function public.gorolli_pricing_one_active()
returns trigger language plpgsql as $$
begin
  if new.trailer_id is not null then
    if coalesce(new.short_rental_price,0) > 0 or coalesce(new.hourly_rate,0) > 0
       or coalesce(new.daily_rate,0) > 0 or coalesce(new.weekly_rate,0) > 0
       or coalesce(new.monthly_rate,0) > 0 then
      -- Uus PÄRIS hindadega profiil = uus tõde -> vanad aktiivsed maha.
      update public.pricing_profiles
         set is_active = false, updated_at = now()
       where trailer_id = new.trailer_id
         and coalesce(is_active, true) = true;
      new.is_active := true;
    else
      -- TÜHI profiil ei tohi olemasolevat aktiivset tõde varjutada.
      if exists (select 1 from public.pricing_profiles
                  where trailer_id = new.trailer_id
                    and coalesce(is_active, true) = true) then
        new.is_active := false;
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_pricing_one_active on public.pricing_profiles;
create trigger trg_pricing_one_active
  before insert on public.pricing_profiles
  for each row execute function public.gorolli_pricing_one_active();

-- 2) KORISTUS PRAEGU: topelt-aktiivsed -> jäta parim, ülejäänud passiivseks -------
-- Paremus: (a) kõik 4 hinda olemas, (b) wizard'i 'Default' (= esmane sisestus),
-- (c) viimati muudetud. MITTE MIDAGI ei kustutata.
with ranked as (
  select id,
         row_number() over (
           partition by trailer_id
           order by
             (coalesce(short_rental_price,0) > 0 and coalesce(daily_rate,0) > 0
              and coalesce(weekly_rate,0) > 0 and coalesce(monthly_rate,0) > 0) desc,
             (name = 'Default') desc,
             updated_at desc nulls last,
             id desc
         ) as rn
  from public.pricing_profiles
  where trailer_id is not null
    and coalesce(is_active, true) = true
)
update public.pricing_profiles p
   set is_active = false, updated_at = now()
  from ranked r
 where p.id = r.id and r.rn > 1;

-- 3) ORVUD: haagis ilma trailer-profiilita -> loo 'Default' haagise hinnast ------
insert into public.pricing_profiles
  (trailer_id, host_id, name, is_active, currency,
   hourly_rate, short_rental_price, daily_rate, weekly_rate, monthly_rate,
   created_at, updated_at)
select t.id, t.host_id, 'Default', true, coalesce(t.currency, 'EUR'),
       coalesce(t.price_per_hr, 0), coalesce(t.price_per_hr, 0), 0, 0, 0,
       now(), now()
from public.trailers t
where t.host_id is not null
  and not exists (select 1 from public.pricing_profiles pp
                   where pp.trailer_id = t.id);

-- 4) SÜNKROON: kaardi "alates" hind = aktiivse profiili short-hind ----------------
update public.trailers t
   set price_per_hr = pp.short_rental_price
  from public.pricing_profiles pp
 where pp.trailer_id = t.id
   and coalesce(pp.is_active, true) = true
   and coalesce(pp.short_rental_price, 0) > 0
   and t.price_per_hr is distinct from pp.short_rental_price;

-- 5) KONTROLL ---------------------------------------------------------------------
-- a) Topelt-aktiivseid ei tohi enam olla (oodatud: 0 rida):
-- select trailer_id, count(*) from public.pricing_profiles
--  where trailer_id is not null and coalesce(is_active,true)=true
--  group by trailer_id having count(*) > 1;
-- b) Iga haagise KEHTIV hind (mida ekraan näitab JA klient maksab):
-- select t.id, t.trailername, t.price_per_hr,
--        pp.name, pp.short_rental_price, pp.daily_rate, pp.weekly_rate, pp.monthly_rate
--   from public.trailers t
--   left join public.pricing_profiles pp
--     on pp.trailer_id = t.id and coalesce(pp.is_active,true)=true
--  order by t.id;
