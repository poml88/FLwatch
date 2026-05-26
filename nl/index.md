---
layout: landing
title: "FLwatch – glucose- en insulinegrafieken voor iPhone en Apple Watch"
description: "FLwatch is een gratis open-source-app die glucose-, insulin-on-board- en activiteitsgrafieken met widgets op iPhone en Apple Watch toont met LibreLinkUp-gegevens."
lang: nl
permalink: /nl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Glucosesensorgrafiek"
---

***Waarschuwing: FLwatch is een sterk experimenteel project. Gebruik deze app met voorzichtigheid en uiterste zorg. Neem geen medische beslissingen op basis van deze software. De software wordt zonder enige garantie geleverd en gebruik is volledig op eigen risico.***

<div class="notice-note">
<strong>Belangrijke opmerking</strong>
<br>
FLwatch ondersteunt momenteel de LibreLinkUp API 4.x. Abbott heeft API 5.0.0 uitgebracht, die nog niet wordt ondersteund.
<br>
Als Abbott API 4.x in de toekomst uitschakelt, kunnen de glucosegegevens in FLwatch zonder waarschuwing stoppen met werken. Functies die met IOB te maken hebben blijven wel werken.
</div>

Deze software is gratis en open source. Ze is ontwikkeld vanuit een persoonlijke behoefte, maar iedereen zou er baat bij moeten kunnen hebben.

### In het kort
- Toont glucose-, insulin-on-board- en activiteitsgrafieken op iPhone en Apple Watch
- Bevat widgets, complicaties, Live Activities, mirroring naar de Smart Stack van Apple Watch en export naar Apple Health
- Ondersteunt handmatige insulineregistratie en een ingebouwde koolhydraten-naar-insulinecalculator
- Vereist iOS 18 en watchOS 10.5
- Voor bètatests is FLwatch ook beschikbaar via TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Ondersteunt Freestyle Libre 2- en 3-sensoren via LibreLinkUp (alleen API-versie 4.x) — gebruikt de inloggegevens van een LibreLinkUp-volgeraccount, niet die van LibreView
- Ondersteunt Dexcom G6-, G7- en ONE+-sensoren via Dexcom Share — log in met het e-mailadres en wachtwoord van het Dexcom-account waarop de sensor is ingesteld (dezelfde inloggegevens als de Dexcom-app op de telefoon van de drager). „Share" moet zijn ingeschakeld in de Dexcom-app, wat vereist dat ten minste één volger wordt uitgenodigd. Log niet in met een volgeraccount — Dexcom stelt alleen de metingen van de drager beschikbaar aan apps van derden.

### Snel starten {#usage}
1. Installeer FLwatch vanuit de [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Zorg ervoor dat de watchOS-app op je Apple Watch is geïnstalleerd, idealiter voordat je de iOS-app opent.
3. Maak een LibreLinkUp-volgerverbinding voor jezelf aan en controleer of die werkt.
4. Voer in FLwatch op het tabblad `Connect` de inloggegevens van het LibreLinkUp-volgeraccount in.
5. Wacht maximaal een minuut totdat de gegevens verschijnen.

Als de watchOS-app is geïnstalleerd, worden instellingen en inloggegevens uit de iOS-app overgezet naar de watch-app.

- @TypeOneCallum heeft een erg nuttige [video-uitleg voor de installatie](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) gemaakt. Die maakt het instellen een stuk eenvoudiger.

### LibreLinkUp instellen
Om FLwatch te laten werken, moet je jezelf eerst uitnodigen om je eigen volger te worden.

*LibreView-inloggegevens werken niet.*

1. Ga in de LibreLink- of Libre 3-app naar Share / Connected Apps.
2. Open Connect / Manage LibreLinkUp.
3. Tik op `Add Connection` en voer het e-mailadres in dat je voor het volgeraccount wilt gebruiken.
4. Accepteer de uitnodiging die naar dat e-mailadres is gestuurd.
5. Installeer de [LibreLinkUp-app](https://apps.apple.com/us/app/librelinkup/id1234323923) op je iPhone en rond daar de configuratie van het uitgenodigde volgeraccount af.
6. Controleer of je in LibreLinkUp je eigen glucosegrafiek kunt zien.
7. Open FLwatch en voer daar de inloggegevens van het volgeraccount in.

Het e-mailadres van het volgeraccount mag hetzelfde zijn als dat van LibreView.

Ook de [stapsgewijze gids van LibreLinkUp](https://www.librelinkup.com/articles/getting-started) kan nuttig zijn.

Op dit moment ondersteunt FLwatch slechts één gevolgde patiënt per volgeraccount.

De LibreLinkUp-app kan daarna worden gesloten of zelfs verwijderd. Mogelijk heb je die later toch weer nodig om nieuwe gebruiksvoorwaarden of privacyvoorwaarden te accepteren, of gewoon om te controleren of het account en de verbinding nog werken.

### FLwatch verbinden
- Voer op het tabblad `Connect` in FLwatch de inloggegevens van je LibreLinkUp-volgeraccount in.
- Als de watchOS-app is geïnstalleerd, worden de inloggegevens overgezet naar de watch-app.
- Indien nodig kun je de inloggegevens opnieuw overzetten door nogmaals op de knop `Connect` te drukken.
- Het ophalen en tonen van gegevens kan tot een minuut duren.

### Insulinefuncties
Tik op het startscherm op het label `IOB` om de insulineberekening te gebruiken.

Momenteel ondersteunde insulinetypen:
- Snelwerkende insuline, zoals Novolog en Novorapid
- Ultrasnelwerkende insuline, zoals Fiasp en Lyumjev

FLwatch ondersteunt ook handmatige insulineregistratie en bevat een ingebouwde koolhydraten-naar-insulinecalculator.

Meer insulinetypen kunnen op verzoek worden toegevoegd.

### Tips voor Watch en Siri
- Om de glucosegrafiek een uur lang zichtbaar te houden op de watch, open je op de watch of in de `Watch`-app op de iPhone `Instellingen > Algemeen > Keer terug naar klok`, scroll je naar FLwatch en kies je `Na 1 uur`. Zo blijft FLwatch langer op de voorgrond en krijgt het een redelijk aantal updates, bijvoorbeeld ongeveer elke minuut.
- De eenvoudigste manier om de app op de telefoon of watch te starten, is door een widget of complicatie op je beginscherm, vergrendelscherm, wijzerplaat of een andere handige plek te zetten en daarop te tikken.
- Live Activities op de iPhone kunnen ook worden gespiegeld naar de Smart Stack van Apple Watch voor snelle toegang.
- Siri en Opdrachten kunnen worden gebruikt om de huidige glucosewaarde te laten voorlezen of weer te geven.
- Siri en Opdrachten kunnen ook worden gebruikt voor spraakgestuurde registratie van insulinedoses of voor het snel registreren van insulinedoses op de watch.
- Om de app handsfree met Siri te openen, kun je op de iPhone een opdracht maken die simpelweg FLwatch opent. Je kunt die bijvoorbeeld `glucosegrafiek` of `bloedsuiker` noemen. Zet de optie aan om de opdracht ook op de watch te tonen. Daarna kun je die zin tegen Siri zeggen en wordt FLwatch direct geopend. Hetzelfde werkt ook op de iPhone.

### Functies {#features}
#### Monitoring
* Glucosegrafiek op telefoon en watch
* Interactieve grafiek op de telefoon om afzonderlijke waarden met een tik te bekijken
* Altijd-aan-schermmodus op de telefoon

#### Insuline
* Ondersteuning voor snelwerkende en ultrasnelwerkende bolusinsulines
* Berekening van insulin on board (IOB)
* IOB-grafiek
* Grafiek van insulineactiviteit
* Handmatige insulineregistratie
* Ingebouwde koolhydraten-naar-insulinecalculator

#### Systeemintegratie
* iOS-widgets en widgets voor het vergrendelscherm met en zonder grafiek(en)
* Live Activities op iPhone, inclusief mirroring naar de Smart Stack van Apple Watch
* Widget voor StandBy-modus
* watchOS-widgets en complicaties
* CarPlay-ondersteuning via widgets en Live Activities
* Export van insulinedoses en glucosegegevens naar Apple Health
* Ondersteuning voor Siri en Opdrachten om glucose weer te geven, voor te lezen en insulinedoses snel vast te leggen

### Technische notities
FLwatch gebruikt het exponentiële insulinemodel van LoopKit. Dat model gebruikt drie parameters: `actionDuration`, `peakActivityTime` en `delay`.

- Voor snelwerkende insuline zijn de parameters 360, 75 en 10 minuten.
- Voor ultrasnelwerkende insuline zijn de parameters 360, 55 en 10 minuten.

### ToDo
- Workout-activiteit implementeren

### Ondersteuning en feedback {#support}
Voor ondersteuning kun je een [GitHub-issue](https://github.com/poml88/FLwatch/issues) openen, een [GitHub-discussie](https://github.com/poml88/FLwatch/discussions) starten of een e-mail sturen naar **flwatch [at] cmdline [dot] net**.

Feedback is zeer welkom en kan via dezelfde kanalen worden gestuurd.

### Donaties
Donaties zijn altijd welkom.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Credits
Bekijk ook deze projecten:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle product- en bedrijfsnamen, handelsmerken, servicemerken, geregistreerde handelsmerken en geregistreerde servicemerken zijn eigendom van hun respectieve houders. Het gebruik ervan is uitsluitend informatief en impliceert geen verbondenheid of goedkeuring. Let op: deze app heeft geen enkele band met Abbott Diabetes Care Inc. of Dexcom, Inc. en wordt niet door deze bedrijven ondersteund.
