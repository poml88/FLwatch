---
layout: landing
title: "FLwatch – Glucose en insuline op iPhone en Apple Watch"
description: "FLwatch toont glucosewaarden van FreeStyle Libre en Dexcom en biedt insulineregistratie, waarschuwingen, widgets en Live Activities op iPhone en Apple Watch."
lang: nl
permalink: /nl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glucose en insuline"
---

<div class="notice-note">
<strong>Niet gebruiken voor behandelbeslissingen.</strong>
<br>
De informatie van FLwatch en de bijbehorende uitbreidingen mag niet worden gebruikt voor behandelbeslissingen of beslissingen over insulinedosering. Vertrouw altijd op je glucosemonitoringsysteem en raadpleeg een zorgprofessional wanneer je medische beslissingen neemt.
</div>

FLwatch toont op je iPhone en Apple Watch de glucosewaarden van de Abbott-sensoren FreeStyle Libre 2, FreeStyle Libre 2+, FreeStyle Libre 3 en FreeStyle Libre 3+ en van de Dexcom-sensoren G6, G7 en ONE+.

Je kunt er ook insulinedoses mee registreren. Aparte grafieken voor actieve insuline en insulineactiviteit helpen je om de wisselwerking tussen insuline en glucose beter te begrijpen.

FLwatch begon als een persoonlijk project ter ondersteuning van mijn eigen diabetesmanagement. Ik heb het gratis en als open source openbaar gemaakt, in de hoop dat het ook voor anderen nuttig kan zijn.

### In het kort

- Grafieken voor glucose, actieve insuline en insulineactiviteit op iPhone en Apple Watch
- Verbindingsmogelijkheden via een directe Bluetooth-verbinding, LibreLinkUp en Dexcom Share
- Work-outmodus voor alle ondersteunde CGM-aanbieders, met Bluetooth-metingen van Libre 3 en Libre 3+ **rechtstreeks op Apple Watch** tijdens work-outs
- Instelbare glucose- en sensorwaarschuwingen
- Widgets en complicaties voor het beginscherm, vergrendelscherm, StandBy en Apple Watch
- Ondersteuning voor Live Activities, CarPlay, Siri en Opdrachten
- Export naar Apple Health en, bij een directe verbinding met een FreeStyle Libre 3- of FreeStyle Libre 3+-sensor, naar Nightscout
- Vereist iOS 18 en watchOS 10.5

### Ondersteunde sensoren en verbindingen

| Fabrikant | Sensoren | Verbinding |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 en FreeStyle Libre 2+ | LibreLinkUp |
| Abbott | FreeStyle Libre 3 en FreeStyle Libre 3+ | Rechtstreeks via Bluetooth naar iPhone; **rechtstreeks via Bluetooth naar Apple Watch** tijdens FLwatch-work-outs; of LibreLinkUp |
| Dexcom | G6, G7 en ONE+ | Dexcom Share |

### Functies {#features}

#### Glucosemonitoring

- Glucosegrafiek op iPhone en Apple Watch
- Interactieve grafiek op iPhone — tik om afzonderlijke metingen te bekijken
- Optionele kalibratiecorrectie voor rechtstreeks verbonden FreeStyle Libre 3- en FreeStyle Libre 3+-sensoren
- Controle van je huidige glucosewaarde en trend via Siri of Opdrachten
- Optionele altijd-aan-weergave voor snel aflezen

#### Waarschuwingen

- Instelbare waarschuwingen voor lage en hoge glucose op iPhone, Apple Watch en CarPlay
- Extra waarschuwingen voor kritiek lage glucose en signaalverlies bij rechtstreeks verbonden FreeStyle Libre 3- en FreeStyle Libre 3+-sensoren
- Meldingen over de opwarmstatus, resterende levensduur, het verlopen en vervangen van rechtstreeks verbonden FreeStyle Libre 3- en FreeStyle Libre 3+-sensoren
- Optionele kritieke meldingen en afzonderlijke periodes voor ‘Niet storen’ per waarschuwingstype

Stel de gewone waarschuwingen in op het tabblad Meldingen op iPhone (belpictogram).

FLwatch-meldingen worden naar beste vermogen afgeleverd en zijn niet gegarandeerd. Ze kunnen vertraagd zijn of uitblijven. Controleer altijd je glucosewaarde voordat je actie onderneemt.

#### Insulineregistratie

- Insulinedoses registreren op iPhone of met Siri en Opdrachten op iPhone en Apple Watch
- Eenvoudige koolhydraten- en insulinecalculator op basis van de portiegrootte en een instelbare insuline-koolhydraatverhouding
- Berekening en grafiek van actieve insuline (IOB)
- Insulineactiviteitsgrafiek
- Ondersteuning voor snelwerkende en zeer snelwerkende bolusinsuline

#### Widgets, Live Activities en CarPlay

- Beginschermwidgets met en zonder grafieken
- Widgets voor het vergrendelscherm en StandBy
- Live Activities voor snelle glucose-updates
- Native Apple Watch-app met diverse widgets en wijzerplaatcomplicaties
- Glucosegrafiek rechtstreeks op Apple Watch
- Spiegeling van Live Activities naar de Slimme stapel vanaf watchOS 11
- CarPlay-weergave met de huidige glucosewaarde en IOB
- Glucosegrafieken in CarPlay via widgets en Live Activities

#### Work-outs op Apple Watch

- Work-outmodus voor alle ondersteunde CGM-aanbieders, met een glucosegrafiek en instelbare waarschuwing voor lage glucose tijdens de work-out
- Extra waarschuwingen voor kritiek lage glucose, snelle daling en ontbrekende metingen, met een sluimerfunctie van 15 minuten voor glucosemeldingen
- Rechtstreekse Bluetooth-metingen van FreeStyle Libre 3 en FreeStyle Libre 3+ zolang er een work-out in FLwatch loopt
- Work-outweergave met glucose, trend, hartslag, verstreken tijd en actieve insuline wanneer beschikbaar
- Afstand voor ondersteunde buitenactiviteiten

Work-outs met LibreLinkUp of Dexcom Share vereisen internettoegang op het horloge en voortdurende uploads van glucosemetingen door de telefoon van de sensordrager.

#### Gegevensexport

- Glucosewaarden en geregistreerde insulinedoses naar Apple Health exporteren
- Bij een directe Bluetooth-verbinding met een FreeStyle Libre 3- of FreeStyle Libre 3+-sensor glucosewaarden en geregistreerde insulinedoses naar je eigen Nightscout-server exporteren

Stel deze exports in onder `Instellingen > Gegevens delen` op iPhone. De export van glucose en insuline naar Apple Health kan afzonderlijk worden ingeschakeld.

{% include screenshots.html %}

### Snel starten {#usage}

1. Installeer FLwatch vanuit de [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Zorg dat de watchOS-app op je Apple Watch is geïnstalleerd, bij voorkeur voordat je de iPhone-app opent.
3. Wanneer je FLwatch voor het eerst opent, wordt je gevraagd je CGM te kiezen: `FreeStyle Libre` via LibreLinkUp, `Dexcom` via Dexcom Share of `FreeStyle Libre 3 (Bluetooth)` voor een directe sensorverbinding.
4. Nadat je een keuze hebt gemaakt, opent FLwatch automatisch het bijbehorende scherm `Verbinden`. Volg de instructies op dat scherm en de relevante aanwijzingen hieronder.
5. Nadat de verbinding tot stand is gebracht, kan het tot een minuut duren voordat de eerste glucosegegevens verschijnen.

Je kunt de gekozen CGM later wijzigen in `Instellingen`.

Als de watchOS-app is geïnstalleerd, worden de in de iPhone-app ingevoerde instellingen en inloggegevens voor cloudverbindingen overgezet naar de Apple Watch-app. Je kunt ze later opnieuw overzetten door nogmaals op `Verbinden` te tikken.

### Directe verbinding met FreeStyle Libre 3 en FreeStyle Libre 3+ {#direct-sensor-setup}

#### Instellen op iPhone

Kies bij een nieuwe installatie `FreeStyle Libre 3 (Bluetooth)` in de CGM-kiezer. FLwatch opent dan automatisch het scherm voor de Bluetooth-verbinding.

Voor een al geactiveerde sensor wordt de modus `Parallel` aanbevolen. De bestaande verbindingsgegevens van de Abbott-app op de sensor blijven geldig, zodat je later gemakkelijker naar die app kunt terugschakelen.

Kies bij `Gestart met` de app en versie **waarmee deze sensor is geactiveerd**, ook als je de Abbott-app sindsdien hebt bijgewerkt:

| Optie in FLwatch | Sensor geactiveerd met |
| --- | --- |
| `FreeStyle Libre 3` | De FreeStyle Libre 3-app, inclusief FreeStyle Libre 3 – US |
| `Libre by Abbott` | Libre by Abbott versie 1.4.0 of nieuwer |
| `Libre by Abbott V ≤ 1.3.0` | Libre by Abbott versie 1.3.0 of ouder |

<div class="notice-note">
<strong>Libre by Abbott: de ontvanger-ID ophalen meldt je af</strong>
<br>
Bij Libre by Abbott versie 1.4.0 of nieuwer word je afgemeld bij de Abbott-app als je de ontvanger-ID ophaalt. Versie 1.4.0 heeft geen knop om af of aan te melden. Je moet de Abbott-app daarom verwijderen en opnieuw installeren om weer aan te melden. De ontvanger-ID blijft gelijk en FLwatch slaat deze op, dus je hoeft deze maar één keer voor hetzelfde account op te halen.
</div>

Deze drie opties gebruiken verschillende ontvanger-ID’s, dus de keuze moet overeenkomen met de manier waarop de sensor is geactiveerd. Meld je aan met het LibreView-account dat door die app is gebruikt en tik op `Ontvanger-ID ophalen`. Gebruik het LibreView-account van de sensordrager, niet een LibreLinkUp-volgeraccount.

- Er mag maar één app tegelijk toegang hebben tot de sensor. Sluit de Abbott-app volledig af voordat je FLwatch gebruikt en schakel de Bluetooth-toegang van die app uit in de iOS-instellingen. Wisselen tussen apps kan twee tot drie minuten duren.
- Wanneer FLwatch je vraagt te scannen, houd je de bovenkant van je iPhone tegen de sensor en beweeg je het toestel niet totdat de NFC-koppeling is voltooid.

Als het koppelen mislukt met fout `0xB1`, controleer dan de keuze bij `Gestart met` en het LibreView-account. Sensoren die met een FreeStyle Libre 3-reader zijn geactiveerd, kunnen niet met FLwatch worden gekoppeld.

De modus `Nieuw` is uitsluitend bedoeld voor een volledig nieuwe, ongebruikte sensor. Deze start onmiddellijk de draagtijd van de sensor en kan niet worden teruggedraaid. De meeste gebruikers moeten de sensor in hun Abbott-app activeren en daarna in de modus `Parallel` met FLwatch koppelen.

Als je bij het activeren van een nieuwe sensor `Alleen FLwatch` kiest, kan geen enkele Abbott-app die sensor later gebruiken. Kies opnieuw `Alleen FLwatch` als je de sensor opnieuw moet koppelen; voor deze optie is geen LibreView-account nodig.

Houd je iPhone na het koppelen in de buurt van de sensor. De glucosewaarden worden ongeveer eenmaal per minuut rechtstreeks via Bluetooth ontvangen, zonder volgeraccount of cloudverbinding. Een directe verbinding maakt ook kalibratiecorrectie, waarschuwingen voor kritiek lage glucose en signaalverlies, sensorstatusmeldingen en export naar Nightscout mogelijk.

Stel de optionele offset in onder `Instellingen > Sensorkalibratie`. Deze past alleen een lokale correctie toe op nieuw ontvangen metingen in FLwatch; de sensor wordt niet opnieuw gekalibreerd en de bestaande geschiedenis wordt niet gewijzigd.

Deze functies voor directe verbinding zijn niet beschikbaar voor sensoren van het type FreeStyle Libre 2 en FreeStyle Libre 2+.

#### Apple Watch tijdens work-outs {#direct-to-watch}

Met Libre 3 en Libre 3+ kan FLwatch tijdens een work-out metingen rechtstreeks op Apple Watch ontvangen, zodat je je iPhone thuis kunt laten. Na de eerste configuratie vereisen rechtstreekse Bluetooth-metingen geen internettoegang of Apple Watch met mobiele verbinding.

1. Koppel de sensor op iPhone zoals hierboven beschreven. Houd iPhone en horloge dicht bij elkaar, met FLwatch op beide geïnstalleerd. Controleer op het scherm `Verbinden` op iPhone of `Rechtstreeks naar Apple Watch` de status `Gereed voor directe sensorverbinding` toont.
2. Open FLwatch op Apple Watch en veeg naar `Work-out`. Kies je activiteit, pas `Laag tijdens work-out` aan en bekijk `Work-outmeldingen`. Sta Bluetooth-toegang en de gevraagde Gezondheid-machtigingen toe.
3. Tik op `Start` en houd het horloge dicht bij de sensor. Controleer of er een nieuwe glucosemeting verschijnt voordat je je iPhone achterlaat.

De rechtstreekse horlogeverbinding werkt tijdens work-outs **die in FLwatch zijn gestart**. Een work-out starten in Apples Work-out-app activeert deze verbinding niet.

**Batterijtip:** Als je een work-out vooral start om metingen rechtstreeks op Apple Watch te blijven ontvangen, is Yoga (Binnen) meestal een goede keuze voor een laag batterijverbruik. Door de energiebesparingsmodus in te schakelen onder `Instellingen > Batterij` op Apple Watch kun je het verbruik verder verminderen.

**Draag je horloge om de arm die het dichtst bij de sensor is.** Als het signaal door je lichaam moet, kan opnieuw verbinden veel langer duren. Verbindingsonderbrekingen kunnen nog steeds metingen en glucosewaarschuwingen onderbreken. Als FLwatch `Opnieuw verbinden met sensor beperkt` toont, schakel Bluetooth uit en weer in via de **instellingen op Apple Watch** en breng het horloge vervolgens dicht bij de sensor. De link `Tips voor de sensorverbinding` op het work-outscherm van FLwatch biedt meer hulp.

Tik op `Work-out beëindigen` in FLwatch wanneer je klaar bent. De work-out wordt opgeslagen in Apple Health en de iPhone kan de sensorverbinding hervatten wanneer deze in de buurt is. `Sensor terugnemen` op iPhone brengt de metingen terug naar de telefoon, maar beëindigt de work-out niet; beëindig deze afzonderlijk op Apple Watch.

### LibreLinkUp instellen

LibreLinkUp kan glucosewaarden leveren van de sensoren FreeStyle Libre 2, FreeStyle Libre 2+, FreeStyle Libre 3 en FreeStyle Libre 3+. Om LibreLinkUp met FLwatch te gebruiken, nodig je jezelf uit als je eigen volger.

*LibreView-inloggegevens werken niet. Gebruik de inloggegevens van een LibreLinkUp-volgeraccount.*

<div class="notice-note">
<strong>Videohandleiding voor het instellen van LibreLinkUp</strong>
<br>
@TypeOneCallum heeft een zeer nuttige <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">stapsgewijze video over het instellen van FLwatch</a> gemaakt. Als je LibreLinkUp voor het eerst instelt, is dit een goed startpunt.
</div>

1. Ga in de FreeStyle LibreLink- of FreeStyle Libre 3-app naar Delen / Verbonden apps.
2. Open Verbinden / LibreLinkUp beheren.
3. Tik op `Verbinding toevoegen` en voer het e-mailadres in dat je voor het volgeraccount wilt gebruiken.
4. Accepteer de uitnodiging die naar dat e-mailadres is gestuurd.
5. Installeer de [LibreLinkUp-app](https://apps.apple.com/us/app/librelinkup/id1234323923) op je iPhone en rond de configuratie van het uitgenodigde volgeraccount af.
6. Controleer of je je eigen glucosegrafiek in LibreLinkUp kunt zien.
7. Open FLwatch en voer de inloggegevens van het volgeraccount in op het tabblad `Verbinden`.

Het e-mailadres van het volgeraccount mag hetzelfde zijn als het adres dat voor LibreView wordt gebruikt. Als het volgeraccount meer dan één verbinding heeft, kies je na het inloggen de persoon van wie FLwatch de waarden moet weergeven.

De LibreLinkUp-app kan vervolgens worden gesloten of verwijderd. Mogelijk heb je de app later nog nodig om bijgewerkte gebruiksvoorwaarden of een bijgewerkt privacybeleid te accepteren, of om te controleren of het account en de verbinding nog werken.

De [stapsgewijze handleiding van LibreLinkUp](https://www.librelinkup.com/articles/getting-started) biedt aanvullende hulp.

<div class="notice-note">
<strong>Compatibiliteit met de LibreLinkUp-API</strong>
<br>
FLwatch ondersteunt momenteel de LibreLinkUp-API 4.x. LibreLinkUp-API 5.0.0 wordt nog niet ondersteund. Als API 4.x in de toekomst wordt uitgeschakeld, kunnen LibreLinkUp-glucosegegevens in FLwatch zonder waarschuwing stoppen met werken. IOB-functies en andere verbindingsmethoden blijven werken.
</div>

### Dexcom Share instellen

Dexcom G6-, Dexcom G7- en Dexcom ONE+-sensoren kunnen via Dexcom Share glucosewaarden leveren.

1. Schakel Share in de Dexcom-app in. Dexcom vereist dat je minstens één volger uitnodigt voordat Share kan worden ingeschakeld.
2. Kies bij een nieuwe installatie `Dexcom` in de CGM-kiezer. FLwatch opent automatisch het scherm voor de Dexcom Share-verbinding.
3. Log in met het e-mailadres en wachtwoord van het Dexcom-account van de sensordrager — hetzelfde account dat wordt gebruikt in de Dexcom-app op de iPhone van de drager — en tik op `Verbinden`. FLwatch detecteert automatisch de accountregio.

Gebruik niet de inloggegevens van een volger. Dexcom Share stelt de eigen glucosewaarden van de sensordrager alleen aan apps van derden beschikbaar wanneer het account van de drager wordt gebruikt.

Als de Apple Watch-app nog niet was geïnstalleerd toen je verbinding maakte, installeer je deze en tik je nogmaals op `Verbinden` om de inloggegevens over te zetten. De Dexcom Share-verbinding die FLwatch gebruikt, is niet officieel en kan zonder kennisgeving worden gewijzigd of beperkt.

### Bluetooth-heartbeat voor cloudverbindingen

Voor de gewone waarschuwingen voor lage en hoge glucose op iPhone met LibreLinkUp of Dexcom Share schakel je de Bluetooth-heartbeat in onder `Instellingen > Bluetooth-heartbeat` en selecteer je de sensorzender in de buurt. Deze iPhone-waarschuwingen vereisen de heartbeat; blijf de waarschuwingen van de sensorfabrikant als primaire waarschuwingen gebruiken.

Tijdens een work-out die in FLwatch op Apple Watch is gestart, ververst het horloge de cloudmetingen en geeft het eigen work-outmeldingen. Hiervoor is de Bluetooth-heartbeatinstelling van de iPhone niet nodig, maar het horloge heeft internettoegang nodig en de telefoon van de sensordrager moet glucosemetingen blijven uploaden.

De directe Bluetooth-verbinding met FreeStyle Libre 3 en FreeStyle Libre 3+ gebruikt deze instelling niet.

### Insulinefuncties

Tik op het label `IOB` op het beginscherm om de insulineberekening in te stellen of een dosis te registreren.

Momenteel ondersteunde insulinetypen:

- Snelwerkende insuline, zoals Novolog en Novorapid
- Zeer snelwerkende insuline, zoals Fiasp en Lyumjev

De ingebouwde calculator gebruikt de portiegrootte en een instelbare insuline-koolhydraatverhouding. Meer insulinetypen kunnen op verzoek worden toegevoegd.

### Tips voor Apple Watch, Siri en Opdrachten

- Om de glucosegrafiek een uur lang zichtbaar te houden op Apple Watch, open je Instellingen op het horloge of de app `Watch` op de iPhone. Ga naar `Algemeen > Keer terug naar klok`, kies FLwatch en selecteer `Na 1 uur`.
- Plaats een widget of complicatie op je beginscherm, vergrendelscherm of wijzerplaat voor snelle toegang tot FLwatch.
- Live Activities op iPhone kunnen vanaf watchOS 11 worden gespiegeld naar de Slimme stapel van Apple Watch.
- Siri en Opdrachten kunnen je huidige glucosewaarde weergeven of voorlezen en insulinedoses registreren.
- Open `Instellingen > Siri-integratie` in FLwatch op iPhone voor gedetailleerde instructies en voorbeeldzinnen.
- Maak voor handsfree toegang een opdracht die FLwatch opent, geef deze een naam zoals `glucosegrafiek` en schakel desgewenst `Toon op Apple Watch` in.

### Technische notities

FLwatch gebruikt het exponentiële insulinemodel van LoopKit. Dat model gebruikt drie parameters: `actionDuration`, `peakActivityTime` en `delay`.

- Voor snelwerkende insuline zijn de parameters 360, 75 en 10 minuten.
- Voor zeer snelwerkende insuline zijn de parameters 360, 55 en 10 minuten.

### Projectstatus

FLwatch is een experimenteel open-sourceproject. Gebruik het voorzichtig. Het wordt zonder garantie geleverd en het gebruik is op eigen risico.

FLwatch is ook beschikbaar voor bètatests via [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Ondersteuning en feedback {#support}

Voor ondersteuning kun je een [GitHub-issue](https://github.com/poml88/FLwatch/issues) openen, een [GitHub-discussie](https://github.com/poml88/FLwatch/discussions) starten of een e-mail sturen naar **flwatch [at] cmdline [dot] net**.

Feedback is zeer welkom en kan via dezelfde kanalen worden gestuurd.

### Donaties

Donaties zijn altijd welkom.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="PayPal-logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Buy Me a Coffee-logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Credits

Bekijk ook deze projecten:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle productnamen, handelsmerken en geregistreerde handelsmerken zijn eigendom van hun respectieve eigenaren. Het gebruik ervan dient hier uitsluitend ter identificatie en impliceert geen verbondenheid met of goedkeuring door de merkhouders.

FLwatch is niet gelieerd aan en wordt niet ondersteund door Abbott Diabetes Care Inc. of Dexcom, Inc.
