-- ============================================================
-- GoRolli — 10 STARDIKUULUTUST (host: info@kimm.ee, Tallinn, default-hinnad)
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina.
-- * Kuulutused lähevad SINU hosti-konto alla (leitakse emailiga).
-- * requires_approval = TRUE: iga broneering tuleb sulle kinnitamiseks,
--   midagi ei broneeru ega maksta automaatselt.
-- * Hinnad: default-miinimumid 5 / 12 / 60 / 180 EUR (min-floor valvab).
-- * Fotod: Unsplash (vabalitsents, äriline kasutus lubatud) — võid host-äpis
--   igal ajal oma piltidega asendada.
-- * KUSTUTAMINE: vt faili lõpus olevat plokki.
-- ============================================================
do $$
declare
  v_host_id  bigint;
  v_host_uid text;
  v_tid      bigint;
  r          record;
begin
  -- 1) täpne email
  select id, host_uid into v_host_id, v_host_uid
    from public.hosts
   where lower(trim(coalesce(email,''))) = 'info@kimm.ee'
   order by id limit 1;

  -- 2) fallback: email/nimi sisaldab 'kimm'
  if v_host_id is null then
    select id, host_uid into v_host_id, v_host_uid
      from public.hosts
     where lower(coalesce(email,'')) like '%kimm%'
        or lower(coalesce(full_name,'')) like '%kimm%'
     order by id limit 1;
  end if;

  -- 3) fallback: kui tabelis ongi ainult ÜKS host, kasuta seda
  if v_host_id is null and (select count(*) from public.hosts) = 1 then
    select id, host_uid into v_host_id, v_host_uid
      from public.hosts limit 1;
  end if;

  if v_host_id is null then
    raise exception E'Hosti ei leitud. Vaata olemasolevad: %\nAsenda vajadusel plokis v_host_id käsitsi.',
      (select string_agg(format('id=%s email=%s nimi=%s', id, coalesce(email,'-'), coalesce(full_name,'-')), '; ')
         from public.hosts);
  end if;

  for r in
    select * from (values
      ('Madelhaagis 750 kg','Lahtine veohaagis','open_utility','open_flatbed','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',59.437,24.754,'Kesklinn, Tallinn',750,'2.6 × 1.5','1','hall'),
      ('Presskattega kerghaagis','Lahtine veohaagis','open_utility','soft_cover','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',59.406,24.681,'Mustamäe, Tallinn',500,'2.3 × 1.25','1','sinine'),
      ('Võrkäärtega haagis','Lahtine veohaagis','open_utility','mesh_sides','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',59.38,24.68,'Nõmme, Tallinn',600,'2.4 × 1.3','1','hõbe'),
      ('Kinnine furgoonhaagis','Kinnine veohaagis','closed_cargo','box_low','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',59.436,24.86,'Lasnamäe, Tallinn',750,'2.5 × 1.4 × 1.2','1','valge'),
      ('Kõrge furgoon','Kinnine veohaagis','closed_cargo','box_high','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',59.427,24.65,'Haabersti, Tallinn',1000,'3.0 × 1.5 × 1.8','1','valge'),
      ('Tööriistahaagis','Kinnine veohaagis','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',59.427,24.72,'Kristiine, Tallinn',750,'2.2 × 1.3 × 1.4','1','must'),
      ('Autoveohaagis 2700 kg','Sõidukivedu','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',59.422,24.794,'Ülemiste, Tallinn',2700,'4.5 × 2.0','2','hall'),
      ('Matkahaagis','Karavan','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',59.468,24.84,'Pirita, Tallinn',900,'3.6 × 2.0','1','valge'),
      ('Põlluplatvorm','Põllu / raske','agri_heavy','farm_platform','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',59.451,24.709,'Põhja-Tallinn, Tallinn',2000,'4.0 × 1.9','2','roheline'),
      ('Kallutatav kallurhaagis','Põllu / raske','agri_heavy','tipper_trailer','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',59.432,24.82,'Peterburi tee, Tallinn',1500,'3.1 × 1.6','2','kollane')
    ) as t(nm, tp, mc, sub, photo, lat, lng, loc, kg, dim, ax, col)
  loop
    -- topeltkäivituse kaitse: sama nimega stardikuulutust teist korda ei loo
    if exists (select 1 from public.trailers
                where host_id = v_host_id and trailername = r.nm
                  and description like 'GoRolli stardikuulutus%%') then
      continue;
    end if;

    insert into public.trailers
      (host_id, host_uid, trailername, model, trailer_type,
       main_category, subtype, description,
       capacity_kg, dimensions_m, axles, color,
       thumbnail, photos,
       latitude, longitude, location_name,
       price_per_hr, currency, requires_approval, has_insurance,
       status, is_available, verified, created_at, updated_at)
    values
      (v_host_id, v_host_uid, r.nm, 'GoRolli Start', r.tp,
       r.mc, r.sub, 'GoRolli stardikuulutus. Broneeringu kinnitab host enne tasumist.',
       r.kg, r.dim, r.ax, r.col,
       r.photo, jsonb_build_object('mainView', r.photo),
       r.lat, r.lng, r.loc,
       5, 'EUR', true, false,
       'active', true, true, now(), now())
    returning id into v_tid;

    insert into public.pricing_profiles
      (trailer_id, host_id, name, currency, is_active,
       short_rental_price, hourly_rate, daily_rate, weekly_rate, monthly_rate,
       min_hours, min_days, created_at, updated_at)
    values
      (v_tid, v_host_id, 'Default', 'EUR', true,
       5, 5, 12, 60, 180, 1, 1, now(), now());
  end loop;
end $$;

-- KONTROLL: 10 kuulutust + aktiivne profiil default-hindadega
select t.id, t.trailername, t.main_category, t.location_name, t.price_per_hr,
       pp.short_rental_price, pp.daily_rate, pp.weekly_rate, pp.monthly_rate
  from public.trailers t
  join public.pricing_profiles pp
    on pp.trailer_id = t.id and coalesce(pp.is_active,true)=true
 where t.description like 'GoRolli stardikuulutus%'
 order by t.id;

-- KUSTUTAMINE (kui tahad stardikuulutused eemaldada — eemalda kommentaarid):
-- delete from public.pricing_profiles where trailer_id in
--   (select id from public.trailers where description like 'GoRolli stardikuulutus%');
-- delete from public.trailers where description like 'GoRolli stardikuulutus%';
