-- ============================================================
-- GoRolli — TESTLINNAD: Rīga + Helsinki + Tampere, +20 fantoomi igasse (60 tk)
-- 2026-07-06. Käivita Supabase SQL Editoris (soovitavalt PÄRAST
-- sql/fix_phantom_locations.sql — siis kuvatakse täpsed koordinaadid).
-- Laiali PÄRIS linnaosade kaupa (maismaa-punktid), kohalikus keeles,
-- nimes linnaosa. Hõivatud-kuva: EI broneeritav, raha ei liigu,
-- aegumine +180 päeva, kustutusvõti model='GoRolli Start EU'.
-- ============================================================
do $$
declare
  v_host_id  bigint;
  v_host_uid text;
  v_tid      bigint;
  r          record;
begin
  select id, host_uid into v_host_id, v_host_uid from public.hosts
   where lower(trim(coalesce(email,''))) in ('info@kimm.ee','margus@kimm.ee')
   order by id limit 1;
  if v_host_id is null then
    select id, host_uid into v_host_id, v_host_uid from public.hosts
     where lower(coalesce(email,'')) like '%kimm%' or lower(coalesce(full_name,'')) like '%kimm%'
     order by id limit 1;
  end if;
  if v_host_id is null and (select count(*) from public.hosts)=1 then
    select id, host_uid into v_host_id, v_host_uid from public.hosts limit 1;
  end if;
  if v_host_id is null then
    raise exception 'Hosti ei leitud';
  end if;

  for r in
    select * from (values
      ('Platformas piekabe 750 kg — Purvciems','Platformas piekabe 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',56.9550,24.1980,'Purvciems, Rīga',750,'2.6 × 1.5','1','hall','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Piekabe ar tentu — Ziepniekkalns','Piekabe ar tentu','open_utility','soft_cover','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',56.9080,24.0770,'Ziepniekkalns, Rīga',500,'2.3 × 1.25','1','sinine','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Slēgtā piekabe — Teika','Slēgtā piekabe','closed_cargo','box_low','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',56.9700,24.1740,'Teika, Rīga',750,'2.5 × 1.4 × 1.2','1','valge','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Instrumentu piekabe — Āgenskalns','Instrumentu piekabe','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',56.9360,24.0620,'Āgenskalns, Rīga',750,'2.2 × 1.3 × 1.4','1','must','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Auto piekabe 2700 kg — Imanta','Auto piekabe 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',56.9560,24.0140,'Imanta, Rīga',2700,'4.5 × 2.0','2','punane','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Kempinga piekabe — Jugla','Kempinga piekabe','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',56.9880,24.2540,'Jugla, Rīga',900,'3.6 × 2.0','1','roheline','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Platformas piekabe 750 kg — Ķengarags','Platformas piekabe 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',56.8990,24.1880,'Ķengarags, Rīga',750,'2.6 × 1.5','1','hall','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Piekabe ar tentu — Sarkandaugava','Piekabe ar tentu','open_utility','soft_cover','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',56.9910,24.1210,'Sarkandaugava, Rīga',500,'2.3 × 1.25','1','sinine','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Slēgtā piekabe — Mežciems','Slēgtā piekabe','closed_cargo','box_low','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',56.9640,24.2270,'Mežciems, Rīga',750,'2.5 × 1.4 × 1.2','1','valge','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Instrumentu piekabe — Pļavnieki','Instrumentu piekabe','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',56.9380,24.2220,'Pļavnieki, Rīga',750,'2.2 × 1.3 × 1.4','1','must','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Auto piekabe 2700 kg — Zolitūde','Auto piekabe 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',56.9410,23.9960,'Zolitūde, Rīga',2700,'4.5 × 2.0','2','punane','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Kempinga piekabe — Čiekurkalns','Kempinga piekabe','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',56.9840,24.1650,'Čiekurkalns, Rīga',900,'3.6 × 2.0','1','roheline','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Platformas piekabe 750 kg — Torņakalns','Platformas piekabe 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',56.9270,24.0900,'Torņakalns, Rīga',750,'2.6 × 1.5','1','hall','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Piekabe ar tentu — Dārzciems','Piekabe ar tentu','open_utility','soft_cover','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',56.9330,24.1900,'Dārzciems, Rīga',500,'2.3 × 1.25','1','sinine','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Slēgtā piekabe — Vecmīlgrāvis','Slēgtā piekabe','closed_cargo','box_low','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',57.0230,24.1120,'Vecmīlgrāvis, Rīga',750,'2.5 × 1.4 × 1.2','1','valge','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Instrumentu piekabe — Bieriņi','Instrumentu piekabe','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',56.9160,24.0410,'Bieriņi, Rīga',750,'2.2 × 1.3 × 1.4','1','must','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Auto piekabe 2700 kg — Dreiliņi','Auto piekabe 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',56.9490,24.2580,'Dreiliņi, Rīga',2700,'4.5 × 2.0','2','punane','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Kempinga piekabe — Iļģuciems','Kempinga piekabe','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',56.9660,24.0410,'Iļģuciems, Rīga',900,'3.6 × 2.0','1','roheline','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Platformas piekabe 750 kg — Šampēteris','Platformas piekabe 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',56.9330,24.0300,'Šampēteris, Rīga',750,'2.6 × 1.5','1','hall','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Piekabe ar tentu — Grīziņkalns','Piekabe ar tentu','open_utility','soft_cover','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',56.9600,24.1450,'Grīziņkalns, Rīga',500,'2.3 × 1.25','1','sinine','Pašlaik aizņemts. Drīzumā šajā apkaimē būs jaunas piekabes.'),
      ('Lavaperäkärry 750 kg — Kamppi','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',60.1680,24.9310,'Kamppi, Helsinki',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Kallio','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',60.1840,24.9500,'Kallio, Helsinki',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Töölö','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',60.1770,24.9210,'Töölö, Helsinki',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Pasila','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',60.1990,24.9330,'Pasila, Helsinki',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Vallila','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',60.1940,24.9620,'Vallila, Helsinki',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Herttoniemi','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',60.1940,25.0300,'Herttoniemi, Helsinki',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Itäkeskus','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',60.2110,25.0140,'Itäkeskus, Helsinki',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Vuosaari','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',60.2080,25.1440,'Vuosaari, Helsinki',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Malmi','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',60.2510,25.0110,'Malmi, Helsinki',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Oulunkylä','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',60.2290,24.9680,'Oulunkylä, Helsinki',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Munkkiniemi','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',60.1980,24.8770,'Munkkiniemi, Helsinki',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Pitäjänmäki','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',60.2230,24.8590,'Pitäjänmäki, Helsinki',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Haaga','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',60.2180,24.8960,'Haaga, Helsinki',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Kannelmäki','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',60.2400,24.8810,'Kannelmäki, Helsinki',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Myllypuro','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',60.2230,25.0700,'Myllypuro, Helsinki',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Kontula','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',60.2350,25.0850,'Kontula, Helsinki',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Viikki','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',60.2260,25.0170,'Viikki, Helsinki',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Arabianranta','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',60.2050,24.9780,'Arabianranta, Helsinki',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Käpylä','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',60.2140,24.9490,'Käpylä, Helsinki',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Malminkartano','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',60.2480,24.8630,'Malminkartano, Helsinki',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Keskusta','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',61.4980,23.7610,'Keskusta, Tampere',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Hervanta','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',61.4510,23.8510,'Hervanta, Tampere',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Kaleva','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',61.5040,23.7960,'Kaleva, Tampere',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Lielahti','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',61.5190,23.6700,'Lielahti, Tampere',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Tesoma','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',61.5140,23.6350,'Tesoma, Tampere',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Linnainmaa','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',61.5140,23.8730,'Linnainmaa, Tampere',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Härmälä','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',61.4680,23.7360,'Härmälä, Tampere',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Pispala','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',61.5040,23.7220,'Pispala, Tampere',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Nekala','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',61.4800,23.7830,'Nekala, Tampere',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Koivistonkylä','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',61.4680,23.8060,'Koivistonkylä, Tampere',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Atala','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',61.5230,23.9010,'Atala, Tampere',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Kaukajärvi','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',61.4720,23.8850,'Kaukajärvi, Tampere',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Vuores','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',61.4260,23.7900,'Vuores, Tampere',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Peltolammi','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1724338501967-f857f2cfd72d?q=80&w=1200&auto=format&fit=crop',61.4560,23.7620,'Peltolammi, Tampere',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Umpikärry — Annala','Umpikärry','closed_cargo','box_low','https://images.unsplash.com/photo-1745095369853-133e0dceca02?q=80&w=1200&auto=format&fit=crop',61.4620,23.8380,'Annala, Tampere',750,'2.5 × 1.4 × 1.2','1','valge','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Työkalukärry — Kalkku','Työkalukärry','closed_cargo','tool_cargo','https://images.unsplash.com/photo-1772852336286-933f5b460e33?q=80&w=1200&auto=format&fit=crop',61.4980,23.6110,'Kalkku, Tampere',750,'2.2 × 1.3 × 1.4','1','must','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Autonkuljetuskärry 2700 kg — Petsamo','Autonkuljetuskärry 2700 kg','vehicle_transport','car_transporter','https://images.unsplash.com/photo-1767651871489-146f3815f310?q=80&w=1200&auto=format&fit=crop',61.5110,23.7810,'Petsamo, Tampere',2700,'4.5 × 2.0','2','punane','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Matkailukärry — Rahola','Matkailukärry','leisure_camper','camping_trailer','https://images.unsplash.com/photo-1637417494980-c9b1992df445?q=80&w=1200&auto=format&fit=crop',61.5050,23.6560,'Rahola, Tampere',900,'3.6 × 2.0','1','roheline','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Lavaperäkärry 750 kg — Multisilta','Lavaperäkärry 750 kg','open_utility','open_flatbed','https://images.unsplash.com/photo-1499147463149-adc471bbc639?q=80&w=1200&auto=format&fit=crop',61.4460,23.7480,'Multisilta, Tampere',750,'2.6 × 1.5','1','hall','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.'),
      ('Kuomukärry — Amuri','Kuomukärry','open_utility','soft_cover','https://images.unsplash.com/photo-1495433488004-859bdc27b1f4?q=80&w=1200&auto=format&fit=crop',61.5010,23.7440,'Amuri, Tampere',500,'2.3 × 1.25','1','sinine','Tällä hetkellä varattu. Uusia peräkärryjä tulossa alueelle pian.')
    ) as t(nm, tp, mc, sub, photo, lat, lng, loc, kg, dim, ax, col, descr)
  loop
    if exists (select 1 from public.trailers
                where host_id=v_host_id and trailername=r.nm and location_name=r.loc
                  and model='GoRolli Start EU') then
      continue;
    end if;

    insert into public.trailers
      (host_id, host_uid, trailername, model, trailer_type, main_category, subtype,
       description, capacity_kg, dimensions_m, axles, color, thumbnail, photos,
       latitude, longitude, location_name, price_per_hr, currency,
       requires_approval, has_insurance, status, is_available,
       busy_display, starter_expires_at, verified, created_at, updated_at)
    values
      (v_host_id, v_host_uid, r.nm, 'GoRolli Start EU', r.tp, r.mc, r.sub,
       r.descr, r.kg, r.dim, r.ax, r.col, r.photo, jsonb_build_object('mainView', r.photo),
       r.lat, r.lng, r.loc, 5, 'EUR',
       true, false, 'active', false,
       true, now() + interval '180 days', true, now(), now())
    returning id into v_tid;

    insert into public.pricing_profiles
      (trailer_id, host_id, name, currency, is_active,
       short_rental_price, hourly_rate, daily_rate, weekly_rate, monthly_rate,
       min_hours, min_days, created_at, updated_at)
    values
      (v_tid, v_host_id, 'Default', 'EUR', true, 5, 5, 12, 60, 180, 1, 1, now(), now());
  end loop;
end $$;

-- KONTROLL: testlinnade tihedus
select split_part(location_name, ', ', 2) as linn, count(*)
  from public.trailers
 where model='GoRolli Start EU'
   and location_name like any(array['%, Rīga','%, Helsinki','%, Tampere'])
 group by 1 order by 1;   -- oodatud: Helsinki 20, Rīga 20, Tampere 20 (+ vanad kesklinna omad eraldi)
