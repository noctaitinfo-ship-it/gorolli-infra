-- ============================================================
-- GoRolli — FANTOOMIDE ASUKOHAPARANDUS (välja veekogudest)
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina.
-- 1) View: busy-ridadel TÄPSED koordinaadid (privaatsushägu jääb AINULT
--    päris haagistele — fantoomil pole aadressi, mida kaitsta; hägu oligi
--    see, mis punkte vette nihutas).
-- 2) Kõigi stardikuulutuste koordinaadid genereeritakse UUESTI linna
--    keskpunktist väikeste nihetega (max ~1.1 km) — kesklinn on maa.
-- ============================================================

-- 1) View: hägu ainult päris haagistele
create or replace view public.public_trailers_map as
select
  t.id, t.trailername, t.model, t.trailer_type, t.thumbnail, t.photos,
  t.main_category, t.subtype, t.is_available, t.delivery_available,
  t.verified, t.insurance_status, t.description, t.capacity_kg, t.dimensions_m,
  case when coalesce(t.busy_display,false) then t.latitude::float8
       else round(t.latitude::numeric, 2)::float8 end  as latitude,
  case when coalesce(t.busy_display,false) then t.longitude::float8
       else round(t.longitude::numeric, 2)::float8 end as longitude,
  coalesce(pp.currency, t.currency, 'EUR') as currency,
  pp.short_rental_price, pp.daily_rate, pp.weekly_rate, pp.monthly_rate,
  t.price_per_hr,
  (coalesce(t.busy_display,false) and not coalesce(t.is_available,false)) as is_busy
from public.trailers t
left join public.pricing_profiles pp
       on pp.trailer_id = t.id and pp.is_active = true
where lower(coalesce(t.status, '')) = 'active'
  and (
    ( coalesce(t.is_available, false) = true
      and not exists (
        select 1 from public.bookings b
        where b.trailer_id = t.id
          and lower(coalesce(b.status, '')) in ('paid_confirmed', 'in_progress')
          and b.start_at <= now()
          and b.end_at   >  now())
    )
    or (coalesce(t.busy_display,false) = true and coalesce(t.is_available,false) = false)
  );

grant select on public.public_trailers_map to anon, authenticated;

-- 2) Koordinaadid uuesti: kesklinn + väike nihe (≤ ~1.1 km)
with centers(loc, clat, clng) as (values
  ('Aarhus',56.1629,10.2039),
  ('Abidjan',5.3600,-4.0083),
  ('Abu Dhabi',24.4539,54.3773),
  ('Abuja',9.0765,7.3986),
  ('Accra',5.6037,-0.1870),
  ('Adelaide',-34.9285,138.6007),
  ('Amsterdam',52.3676,4.9041),
  ('Antwerpen',51.2194,4.4025),
  ('Athina',37.9838,23.7275),
  ('Atlanta',33.7490,-84.3880),
  ('Auckland',-36.8509,174.7645),
  ('Bangalore',12.9716,77.5946),
  ('Bangkok',13.7563,100.5018),
  ('Barcelona',41.3874,2.1686),
  ('Basel',47.5596,7.5886),
  ('Belo Horizonte',-19.9167,-43.9345),
  ('Bergen',60.3913,5.3221),
  ('Berlin',52.5200,13.4050),
  ('Bern',46.9480,7.4474),
  ('Birmingham',52.4862,-1.8904),
  ('Bologna',44.4949,11.3426),
  ('Braga',41.5454,-8.4265),
  ('Brasília',-15.8267,-47.9218),
  ('Bratislava',48.1486,17.1077),
  ('Brisbane',-27.4698,153.0251),
  ('Brno',49.1951,16.6068),
  ('Bruxelles',50.8503,4.3517),
  ('București',44.4268,26.1025),
  ('Budapest',47.4979,19.0402),
  ('Calgary',51.0447,-114.0719),
  ('Cape Town',-33.9249,18.4241),
  ('Chicago',41.8781,-87.6298),
  ('Christchurch',-43.5321,172.6362),
  ('Ciudad de México',19.4326,-99.1332),
  ('Cluj-Napoca',46.7712,23.6236),
  ('Cork',51.8985,-8.4756),
  ('Dallas',32.7767,-96.7970),
  ('Daugavpils',55.8747,26.5362),
  ('Debrecen',47.5316,21.6273),
  ('Delhi',28.7041,77.1025),
  ('Den Haag',52.0705,4.3007),
  ('Dubai',25.2048,55.2708),
  ('Dublin',53.3498,-6.2603),
  ('Durban',-29.8587,31.0218),
  ('Edmonton',53.5461,-113.4938),
  ('Eindhoven',51.4416,5.4697),
  ('Firenze',43.7696,11.2558),
  ('Frankfurt',50.1109,8.6821),
  ('Gdańsk',54.3520,18.6466),
  ('Gent',51.0543,3.7174),
  ('Genève',46.2044,6.1432),
  ('Gibraltar',36.1408,-5.3536),
  ('Glasgow',55.8642,-4.2518),
  ('Graz',47.0707,15.4395),
  ('Guadalajara',20.6597,-103.3496),
  ('Göteborg',57.7089,11.9746),
  ('Hamburg',53.5511,9.9937),
  ('Helsinki',60.1699,24.9384),
  ('Hong Kong',22.3193,114.1694),
  ('Houston',29.7604,-95.3698),
  ('Iași',47.1585,27.6014),
  ('Jakarta',-6.2088,106.8456),
  ('Johannesburg',-26.2041,28.0473),
  ('Kaunas',54.8985,23.9036),
  ('Klaipėda',55.7033,21.1443),
  ('Košice',48.7164,21.2611),
  ('Kraków',50.0647,19.9450),
  ('Kuala Lumpur',3.1390,101.6869),
  ('Kumasi',6.6885,-1.6244),
  ('Köln',50.9375,6.9603),
  ('København',55.6761,12.5683),
  ('Lagos',6.5244,3.3792),
  ('Lausanne',46.5197,6.6323),
  ('Leeds',53.8008,-1.5491),
  ('Limerick',52.6638,-8.6267),
  ('Linz',48.3069,14.2858),
  ('Lisboa',38.7223,-9.1393),
  ('Liverpool',53.4084,-2.9916),
  ('Liège',50.6326,5.5797),
  ('Ljubljana',46.0569,14.5058),
  ('London',51.5074,-0.1278),
  ('Los Angeles',34.0522,-118.2437),
  ('Luxembourg',49.6116,6.1319),
  ('Lyon',45.7640,4.8357),
  ('Madrid',40.4168,-3.7038),
  ('Malmö',55.6050,13.0038),
  ('Manchester',53.4808,-2.2426),
  ('Maribor',46.5547,15.6459),
  ('Marseille',43.2965,5.3698),
  ('Melbourne',-37.8136,144.9631),
  ('Miami',25.7617,-80.1918),
  ('Milano',45.4642,9.1900),
  ('Mombasa',-4.0435,39.6682),
  ('Monterrey',25.6866,-100.3161),
  ('Montréal',45.5019,-73.5674),
  ('Mumbai',19.0760,72.8777),
  ('Málaga',36.7213,-4.4214),
  ('München',48.1351,11.5820),
  ('Nagoya',35.1815,136.9066),
  ('Nairobi',-1.2921,36.8219),
  ('Nantes',47.2184,-1.5536),
  ('Napoli',40.8518,14.2681),
  ('Narva',59.3772,28.1903),
  ('New York',40.7128,-74.0060),
  ('Nice',43.7102,7.2620),
  ('Nicosia',35.1856,33.3823),
  ('Odense',55.4038,10.4024),
  ('Osaka',34.6937,135.5023),
  ('Oslo',59.9139,10.7522),
  ('Ostrava',49.8209,18.2625),
  ('Ottawa',45.4215,-75.6972),
  ('Oulu',65.0121,25.4651),
  ('Paris',48.8566,2.3522),
  ('Patras',38.2466,21.7346),
  ('Perth',-31.9505,115.8605),
  ('Philadelphia',39.9526,-75.1652),
  ('Phoenix',33.4484,-112.0740),
  ('Plovdiv',42.1354,24.7453),
  ('Plzeň',49.7384,13.3736),
  ('Porto',41.1579,-8.6291),
  ('Poznań',52.4064,16.9252),
  ('Praha',50.0755,14.4378),
  ('Pärnu',58.3859,24.4971),
  ('Riga',56.9496,24.1052),
  ('Rijeka',45.3271,14.4422),
  ('Rio de Janeiro',-22.9068,-43.1729),
  ('Roma',41.9028,12.4964),
  ('Rotterdam',51.9244,4.4777),
  ('Salzburg',47.8095,13.0550),
  ('San Antonio',29.4241,-98.4936),
  ('San Diego',32.7157,-117.1611),
  ('Seattle',47.6062,-122.3321),
  ('Sevilla',37.3891,-5.9845),
  ('Sharjah',25.3463,55.4209),
  ('Singapore',1.3521,103.8198),
  ('Sofia',42.6977,23.3219),
  ('Split',43.5081,16.4402),
  ('Stavanger',58.9700,5.7331),
  ('Stockholm',59.3293,18.0686),
  ('Stuttgart',48.7758,9.1829),
  ('Surabaya',-7.2575,112.7521),
  ('Sydney',-33.8688,151.2093),
  ('Szeged',46.2530,20.1414),
  ('São Paulo',-23.5505,-46.6333),
  ('Tampere',61.4978,23.7610),
  ('Tartu',58.3780,26.7290),
  ('Thessaloniki',40.6401,22.9444),
  ('Timișoara',45.7489,21.2087),
  ('Tokyo',35.6762,139.6503),
  ('Torino',45.0703,7.6869),
  ('Toronto',43.6532,-79.3832),
  ('Toulouse',43.6047,1.4442),
  ('Trondheim',63.4305,10.3951),
  ('Turku',60.4518,22.2666),
  ('Uppsala',59.8586,17.6389),
  ('Utrecht',52.0907,5.1214),
  ('Vaduz',47.1410,9.5209),
  ('Valencia',39.4699,-0.3763),
  ('Valletta',35.8989,14.5146),
  ('Vancouver',49.2827,-123.1207),
  ('Varna',43.2141,27.9147),
  ('Vilnius',54.6872,25.2797),
  ('Warszawa',52.2297,21.0122),
  ('Wellington',-41.2866,174.7756),
  ('Wien',48.2082,16.3738),
  ('Wrocław',51.1079,17.0385),
  ('Yokohama',35.4437,139.6380),
  ('Zagreb',45.8150,15.9819),
  ('Zaragoza',41.6488,-0.8891),
  ('Zürich',47.3769,8.5417),
  ('Łódź',51.7592,19.4560)
),
offs(i, dlat, dlng) as (values
  (0, 0.0060, 0.0040), (1, -0.0040, 0.0080), (2, 0.0080, -0.0040),
  (3, -0.0060, -0.0060), (4, 0.0100, 0.0030), (5, 0.0030, -0.0090)
),
ranked as (
  select t.id, t.location_name,
         (row_number() over (partition by t.location_name order by t.id) - 1) % 6 as rn
    from public.trailers t
   where t.model = 'GoRolli Start EU'
)
update public.trailers t
   set latitude  = c.clat + o.dlat,
       longitude = c.clng + o.dlng,
       updated_at = now()
  from ranked r
  join centers c on c.loc = r.location_name
  join offs o    on o.i = r.rn
 where t.id = r.id;

-- 3) SILMAKONTROLL: klikitav nimekiri — ava link, vaata kas maa peal.
--    Kui mõni üksik on ikka vees, nihuta ühe reaga (šabloon all).
select t.id, t.location_name, t.trailername,
       'https://maps.google.com/?q=' || t.latitude || ',' || t.longitude as kaardilink
  from public.trailers t
 where t.model = 'GoRolli Start EU'
 order by t.location_name, t.id;

-- ÜKSIKU PARANDUSE ŠABLOON:
-- update public.trailers set latitude=56.9500, longitude=24.1100, updated_at=now() where id=<ID>;
