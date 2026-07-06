# GoRolli MEMO — MAKSED & RIIGID (otsus + tulevikuplaan)
*Rubriik: Maksed. Kinnitatud 06.07.2026. Järgmine uuendus: kui alustame Faas 2 (valuutad).*

## OTSUS (üks lause)
**Fookus: eurotsoon. Vahendaja: ainult Stripe. Charge alati EUR. GoRolli ei ole kunagi pank (ei Payoneer/Wise vahendusmudelit). Valuutade teostamine (listingu-põhine hind) on HILISEM eraldi projekt, mis avab ~25 mitte-euro Stripe-riiki täisväärtusliku koduturuna.**

---

## RIIKIDE KAART — kus mis kehtib

**🟢 FOOKUSTURG PRAEGU — 21 eurotsooni riiki (kõik 100% automaatne):**
EE, FI, LV, LT, DE, FR, ES, IT, NL, BE, AT, IE, PT, GR, SK, SI, HR, CY, MT, LU, **BG** *(NB: Bulgaaria on EUR alates 01.01.2026 — mitte BGN!)*
Klient maksab, host saab Connect-payouti automaatselt, hinnad natiivselt EUR.

**🟡 TEHNILISELT JUBA TÄISAUTOMAATNE, äriline fookus hiljem — 23 mitte-euro Stripe-riiki:**
US, GB, SE, NO, DK, PL, CZ, HU, RO, CH, CA, AU, NZ, JP, SG, HK, MY, TH, MX, BR, AE, GI, LI
Klient maksab JUBA (näeb oma valuutat Adaptive Pricingu kaudu, charge EUR) ja host saab JUBA automaatse payouti. Faas 2 ("valuutad") teeb neist päris koduturud: hosti hinnad oma valuutas, ilma FX-vaheta.

**🟠 MÜÜK TOIMIB, PAYOUT KÄSITSI — 7 riiki:**
CI, GH, IN, ID, KE, NG, ZA — Stripe Connect neid ei toeta (lükkab ise onboardingul tagasi). Kliendi raha laekub normaalselt GoRolli EUR-saldole, ledger peab arvet; hostile maksmine käsitsi (pank/Wise ainult VÄLJAMAKSE tööriistana, mitte maksesüsteemina).

**⚪ KÕIK MUU MAAILM — VABA/AVATUD (OPEN ALL):**
Mitte ükski riik pole blokeeritud. Klient ükskõik kust maksab (~195 riiki, kaart töötab); host võib listida ka tundmatust riigist; payout seal käsitsi. Ainus blokk üldse = admini käsitsi keeld `country_status='DISABLED'` (praegu: 0 keelatud riiki).

---

## KOLM ERI ASJA (ära sega omavahel)

| Asi | Ulatus | Mis seda piirab |
|---|---|---|
| Äpi levik | ~175–190 riiki (Play/App Store) + veeb kõikjal | ei miski oluline |
| Keel (32 keelt) | ~130+ riiki | ei ole takistus |
| Klient MAKSAB | ~195 riiki | kaart töötab peaaegu kõikjal |
| Host saab raha AUTOMAATSELT | **46 Stripe Connect'i riiki** (meie listist 44) | Stripe'i litsentsid, mitte meie lülitid |
| Payout käsitsi | ülejäänud maailm | GoRolli teeb ise ülekande |

**Võtmelause:** 46 EI piira levikut, keelt ega kliendi maksmist — 46 piirab AINULT seda, kus host saab raha automaatselt kätte, ja seepärast kus haagised päriselt skaleeruvad.

---

## MIS JUBA TÖÖTAB (tehniline tõde 06.07.2026 — ära alahinda!)

- **Stripe Checkout + Adaptive Pricing on LIVE:** klient NÄEB ja MAKSAB juba OMA valuutas (NOK/JPY/PHP…) — see ei oota Faas 2. Settlement + ledger alati EUR.
- **Serveri guardid:** summa tuleb AINULT booking-realt (`payments-checkout`), kliendi saadetud currencyt ei usaldata kunagi (payments-authorize + initPayment EUR-guardid). AUD-juhtum ei saa korduda.
- **Rahavoog:** kliendi raha püsib kogu aeg Stripe'i SEES (GoRolli platvormisaldo) kuni `release-payout` kannab hostile — GoRolli ei hoia raha oma pangas ega ole pank; Stripe on litsentseeritud käitleja.
- **OPEN ALL poliitika** (`sql/country_config_open_all.sql` — kehtiv, asendab varasemad): 51 riiki configis kõik lahti; tundmatu riik lubatud.
- Kolm repot GitHubis SYNC: gorolli-client (flutterflow), gorolli-web (main), gorolli-infra (main).

---

## FAAS 2 — "VALUUTADE TEOSTAMINE" (hilisem eraldi projekt)

**Eesmärk:** ~25 mitte-euro Stripe-riiki (46 − 21 EUR) päris koduturuks: hosti hind oma valuutas (listingu-põhine), kliendile ilma FX-vaheta, kohalik usaldus. Rahvastik ~340 mln → ~1,5 mld+.

**Mida see koodis puudutab (miks eraldi projekt + täistest):**
hosti äpp (valuutavalik haagise lisamisel; praegu EUR), kliendi äpp (hinnakuva/arvutus/makse eeldab EUR-i), € sümbol kõvakodeeritud kohtades ("Kokku X €", "€/hr"), backend (arvutusfunktsioon, `currency` väli, guardide laiendus lubatud valuutade loendiga), miinimumhinnad igas valuutas (praegu 5 € → $5/£5…).

**Prioriteetsed valuutad:** USD, GBP, CAD, AUD, NZD, JPY, CHF → siis SEK, DKK, NOK, PLN, CZK, HUF, RON → siis SGD, HKD, MYR, MXN, BRL, AED. *(BGN nimekirjast VÄLJAS — Bulgaaria on juba EUR.)*

---

## MITTE TEHA (õppetunnid)

- ❌ **Payoneer/Wise VAHENDUSMUDEL** (ise raha koguda + laiali maksta) → GoRolli muutuks pangaks: litsents, KYC, maksud, teenustasud, juristid. Jäetud teadlikult kõrvale. (Wise võib jääda AINULT üksikute käsitsi-payoutide tööriistaks 🟠-riikidesse.)
- ❌ Valuuta keele järgi — vale. Valuuta käib HAAGISE ASUKOHA järgi.
- ❌ Multi-valuuta praegu, töötava launch'i kõrvalt — ennatlik risk. Teha eraldi projektina laienemisel.
- ❌ Kliendi saadetud amount/currency usaldamine — mitte kunagi (server otsustab).

---

## TEEKAART

| Faas | Turg | Valuuta | Seis |
|---|---|---|---|
| 1 — NÜÜD | Eurotsoon (21) | EUR | ✅ Valmis, launch. Ülejäänud maailm avatud boonusena (klient maksab kõikjal, 23 riigis ka auto-payout) |
| 2 — hiljem | +25 mitte-euro Stripe-riiki (US, GB, CA, AU, JP…) | listingu-põhine (USD/GBP/…) | Eraldi projekt + täistest mõlemas äpis |
| 3 — hiljem | 🟠 7 + muu maailm | EUR + käsitsi/alternatiiv-payout | Ainult kui nõudlus tõestab |

**Meeldejätmiseks:** klient maksab kõikjal juba täna oma valuutas; Faas 2 ei ava maksmist, vaid teeb 25 Stripe-riigist päris koduturud. GoRolli ei ole kunagi pank — Stripe teeb raha liigutamise ise. Täpne Stripe'i riikide nimekiri: stripe.com/global.
