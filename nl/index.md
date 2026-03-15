---
layout: landing
title: "FLwatch – Glucose- en insulinegrafieken voor iPhone en Apple Watch"
description: "FLwatch is een gratis open-source-app die glucose-, insulin-on-board- en activiteitsgrafieken met widgets op iPhone en Apple Watch toont met LibreLinkUp-gegevens."
lang: nl
permalink: /nl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Glucosesensorgrafiek"
---

***Waarschuwing: dit project is zeer experimenteel. Gebruik deze app met voorzichtigheid en uiterste zorg. Neem geen ondoordachte beslissingen op basis van software. Gebruik deze software niet als je twijfelt. Gebruik deze app niet voor medische beslissingen. Er is absoluut geen garantie. Gebruik is volledig op eigen risico.***

Deze software is gratis en open source. Ze is ontwikkeld vanuit persoonlijke behoeften, maar iedereen zou er baat bij moeten kunnen hebben.

### Gebruik {#usage}
***Installatie:*** Zorg ervoor dat de watchOS-app is geïnstalleerd, idealiter voordat je de iOS-app start. Afhankelijk van je configuratie wordt de watchOS-app automatisch geïnstalleerd of moet die via de app `Watch` op de telefoon worden geïnstalleerd.
- @TypeOneCallum heeft een erg goede [video-handleiding voor de setup](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) gemaakt (dank je). Als je die bekijkt, wordt de installatie een stuk eenvoudiger.
- De app vereist iOS 17.5 en watchOS 10.5.
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- De instellingen worden in de iOS-app gedaan en daarna naar de watchOS-app overgezet. Dit werkt alleen als de watchOS-app op het horloge is geïnstalleerd.
- ***De verbinding tussen de apps opzetten:*** Om alles te laten werken, moet je jezelf eerst uitnodigen als je eigen volger. *LibreView-inloggegevens werken niet.* In de LibreLink- of Libre 3-app vind je onder Delen / Verbonden apps de optie om LibreLinkUp te verbinden of te beheren. Tik op `Verbinding toevoegen` en vul het e-mailadres in dat je voor het volgeraccount wilt gebruiken. Naar dat adres wordt vervolgens een uitnodiging gestuurd. Dat e-mailadres mag hetzelfde zijn als voor LibreView. Om het LibreLinkUp-volgeraccount in te stellen, installeer je daarna de [LibreLinkUp-app](https://apps.apple.com/us/app/librelinkup/id1234323923) op je telefoon en volg je de stappen met het e-mailadres dat je net hebt uitgenodigd. Mogelijk helpt ook deze [stap-voor-stap-handleiding](https://www.librelinkup.com/articles/getting-started). Zorg ervoor dat je je eigen bloedglucosegrafiek in de LibreLinkUp-app kunt zien. Open daarna FLwatch en vul de gegevens van het volgeraccount in, zoals hieronder beschreven. Momenteel ondersteunt FLwatch slechts een gevolgde patiënt per volgeraccount.
- Daarna kan de LibreLinkUp-app worden gesloten of verwijderd, maar mogelijk heb je die later nog nodig om nieuwe gebruiksvoorwaarden of privacyvoorwaarden te accepteren, of gewoon om te controleren of het account en de verbinding nog werken.
- Om verbinding te maken met je LibreLinkUp-volgeraccount voer je je inloggegevens in FLwatch in op het tabblad `Verbinden`. Als de watchOS-app is geïnstalleerd, worden de gegevens doorgestuurd naar de Watch-app. Je kunt de gegevens opnieuw overzetten door nogmaals op de knop `Verbinden` te tikken.
- Het kan tot een minuut duren voordat de gegevens zijn opgehaald en weergegeven.
- Om de insulineberekening te gebruiken, tik je op het IOB-label op het startscherm. Ondersteunde insulinetypen zijn momenteel snelwerkend (Novolog, Novorapid, ...) en ultrasnelwerkend (Fiasp, Lyumjev, ...). Meer insulines kunnen op verzoek worden toegevoegd. *Laat het gerust weten.*
  - De app gebruikt het exponentiële model van LoopKit. Dat model heeft drie parameters: `actionDuration`, `peakActivityTime` en `delay`. Voor snelwerkende insuline zijn die waarden 360, 75 en 10 minuten; voor ultrasnelwerkende insuline 360, 55 en 10 minuten.
- Er is een instelling om de glucosegrafiek een uur lang op het horloge zichtbaar te houden: ga op het horloge of in de telefoon-app `Watch` naar Instellingen -> Algemeen -> Terug naar klok, scrol omlaag, tik op `FLwatch` en kies `Na 1 uur`. Zo blijft FLwatch een uur op de voorgrond en krijgt het een redelijk aantal updates, bijvoorbeeld elke minuut.
- De makkelijkste manier om de telefoon- of horloge-app te starten is door een widget of complicatie op je beginscherm, vergrendelscherm, wijzerplaat of een andere plek te zetten en daarop te tikken.
- Om de app handsfree met Siri te openen kun je op de telefoon een opdracht aanmaken met bijvoorbeeld de naam `glucosegrafiek` of `bloedsuiker`. Die opdracht opent simpelweg FLwatch. Kies daarbij de optie `toon op Apple Watch`. Als je daarna Siri activeert en `glucosegrafiek` zegt, wordt FLwatch met de grafiek geopend.
Hetzelfde werkt ook op de telefoon.

### Functies {#features}
* Bloedglucosegrafiek op telefoon en horloge
* Interactieve grafiek op de telefoon om individuele waarden via tikken te bekijken
* Altijd-aan-modus op het telefoonscherm
* Ondersteuning voor snelwerkende en ultrasnelwerkende bolusinsulines
* Berekening van insulin on board (IOB)
* IOB-grafiek
* Grafiek van insulineactiviteit
* iOS-widgets en lockscreen-widgets met en zonder grafiek(en)
* Live Activities
* Widget voor de stand-bymodus
* watchOS-widgets / complicaties
* CarPlay-ondersteuning via widgets en Live Activities

### Nog te doen
- Trainingsactiviteit implementeren

### Ondersteuning en feedback {#support}
Voor ondersteuning kun je een issue openen, een discussie starten of een e-mail sturen naar **flwatch [ a t ] cmdline [ d o t ] net**. Feedback is zeer welkom; gebruik daarvoor gerust dezelfde contactmogelijkheden.

### Donaties...
...zijn altijd welkom.
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

Bekijk ook deze projecten:

### Met dank aan
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle product- en bedrijfsnamen, handelsmerken, servicemerken, geregistreerde handelsmerken en geregistreerde servicemerken zijn eigendom van hun respectieve houders. Gebruik daarvan is uitsluitend informatief en impliceert geen verbondenheid met of goedkeuring door die partijen. Let op: deze app heeft geen enkele band met Abbott Diabetes Care Inc. en wordt niet door dat bedrijf ondersteund.
