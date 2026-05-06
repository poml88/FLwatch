---
layout: landing
title: "FLwatch – Glukose- & Insulin-Diagramme für iPhone & Apple Watch"
description: "FLwatch ist eine kostenlose Open-Source-App, die Glukose-, Insulin-on-Board- und Aktivitätsdiagramme mit Widgets auf iPhone und Apple Watch mithilfe von LibreLinkUp-Daten anzeigt."
lang: de
permalink: /de/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch: Glukose Sensor Graph"
---

<div class="notice-note">
<strong>Wichtiger Hinweis</strong>
<br>
FLwatch unterstützt derzeit die LibreLinkUp-API 4.x. Abbott hat API 5.0.0 veröffentlicht, die noch nicht unterstützt wird.
<br>
Falls Abbott API 4.x in Zukunft deaktiviert, funktionieren die Glukosedaten in FLwatch möglicherweise ohne Vorwarnung nicht mehr. IOB-bezogene Funktionen funktionieren weiterhin.
</div>

***Warnung: FLwatch ist ein hochgradig experimentelles Projekt. Verwenden Sie die App mit Vorsicht und äußerster Sorgfalt. Treffen Sie keine medizinischen Entscheidungen auf Grundlage dieser Software. Sie wird ohne jede Gewähr bereitgestellt und die Nutzung erfolgt auf eigene Gefahr.***

Diese Software ist kostenlos und Open Source. Sie wurde aus persönlichen Bedürfnissen heraus entwickelt, aber jeder sollte davon profitieren können.

### Auf einen Blick
- Zeigt Glukose-, Insulin-on-Board- und Aktivitätsdiagramme auf iPhone und Apple Watch
- Enthält Widgets, Komplikationen, Live Activities, Watch-Smart-Stack-Spiegelung und Export nach Apple Health
- Unterstützt manuelle Insulinerfassung und einen integrierten Kohlenhydrat-zu-Insulin-Rechner
- Benötigt iOS 18 und watchOS 10.5
- Für Betatests ist FLwatch auch über TestFlight verfügbar: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Verwendet Zugangsdaten eines LibreLinkUp-Follower-Kontos, nicht LibreView-Anmeldedaten

### Schnellstart {#usage}
1. Installieren Sie FLwatch aus dem [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Stellen Sie sicher, dass die watchOS-App auf Ihrer Apple Watch installiert ist, idealerweise bevor Sie die iOS-App starten.
3. Richten Sie eine LibreLinkUp-Follower-Verbindung für sich selbst ein und prüfen Sie, dass sie funktioniert.
4. Geben Sie die Zugangsdaten des LibreLinkUp-Follower-Kontos in FLwatch auf der Registerkarte `Connect` ein.
5. Warten Sie bis zu einer Minute, bis die Daten angezeigt werden.

Wenn die watchOS-App installiert ist, werden Einstellungen und Zugangsdaten aus der iOS-App an die Watch-App übertragen.

- @TypeOneCallum hat ein sehr hilfreiches [Setup-Tutorial-Video](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) erstellt. Wenn Sie es ansehen, wird die Einrichtung deutlich einfacher.

### LibreLinkUp Einrichten
Damit FLwatch funktioniert, müssen Sie sich zunächst selbst als eigenen Follower einladen.

*LibreView-Anmeldedaten funktionieren nicht.*

1. Öffnen Sie in der LibreLink- oder Libre-3-App den Bereich Teilen / Verbundene Apps.
2. Öffnen Sie LibreLinkUp verbinden / verwalten.
3. Tippen Sie auf `Verbindung hinzufügen` und geben Sie die E-Mail-Adresse ein, die Sie für das Follower-Konto verwenden möchten.
4. Nehmen Sie die Einladung an, die an diese E-Mail-Adresse gesendet wurde.
5. Installieren Sie die [LibreLinkUp-App](https://apps.apple.com/us/app/librelinkup/id1234323923) auf Ihrem iPhone und richten Sie das eingeladene Follower-Konto dort ein.
6. Vergewissern Sie sich, dass Sie in LibreLinkUp Ihre eigene Glukosekurve sehen können.
7. Öffnen Sie FLwatch und geben Sie dort die Zugangsdaten des Follower-Kontos ein.

Die E-Mail-Adresse für das Follower-Konto kann dieselbe sein wie die für LibreView.

Zusätzlich gibt es eine [Schritt-für-Schritt-Anleitung von LibreLinkUp](https://www.librelinkup.com/articles/getting-started), die hilfreich sein kann.

Derzeit unterstützt FLwatch nur einen gefolgten Patienten pro Follower-Konto.

Die LibreLinkUp-App kann danach geschlossen oder sogar deinstalliert werden. Möglicherweise wird sie später noch benötigt, um neue Nutzungsbedingungen oder Datenschutzrichtlinien zu akzeptieren oder zu prüfen, ob Konto und Verbindung weiterhin funktionieren.

### FLwatch Verbinden
- Geben Sie die Zugangsdaten Ihres LibreLinkUp-Follower-Kontos in FLwatch auf der Registerkarte `Connect` ein.
- Wenn die watchOS-App installiert ist, werden die Zugangsdaten an die Watch-App übertragen.
- Bei Bedarf können Sie die Zugangsdaten erneut übertragen, indem Sie die Schaltfläche `Connect` noch einmal drücken.
- Es kann bis zu einer Minute dauern, bis die Daten abgerufen und angezeigt werden.

### Insulin-Funktionen
Um die Insulinberechnung zu verwenden, tippen Sie auf dem Startbildschirm auf die Bezeichnung `IOB`.

Derzeit unterstützte Insulintypen:
- Schnell wirkendes Insulin wie Novolog und Novorapid
- Sehr schnell wirkendes Insulin wie Fiasp und Lyumjev

FLwatch unterstützt außerdem die manuelle Erfassung von Insulindosen und enthält einen integrierten Kohlenhydrat-zu-Insulin-Rechner.

Weitere Insulintypen können auf Anfrage ergänzt werden.

### Watch- und Siri-Tipps
- Um die Glukosekurve auf der Uhr eine Stunde lang sichtbar zu halten, öffnen Sie auf der Uhr oder in der iPhone-App `Watch` den Pfad `Einstellungen > Allgemein > Zurück zur Uhr`, scrollen Sie zu FLwatch und wählen Sie `Nach 1 Stunde`. Dadurch bleibt FLwatch länger im Vordergrund und erhält eine sinnvolle Zahl von Aktualisierungen, zum Beispiel etwa jede Minute.
- Am einfachsten starten Sie die App auf dem iPhone oder der Uhr, indem Sie ein Widget oder eine Komplikation auf dem Home-Bildschirm, Sperrbildschirm, Zifferblatt oder an einer anderen gut erreichbaren Stelle platzieren und darauf tippen.
- Live Activities auf dem iPhone können auch im Smart Stack der Apple Watch gespiegelt werden, um schnell darauf zuzugreifen.
- Siri und Kurzbefehle können verwendet werden, um den aktuellen Glukosewert vorlesen oder anzeigen zu lassen.
- Siri und Kurzbefehle können außerdem für die Spracheingabe von Insulindosen oder für eine schnelle Erfassung von Insulindosen auf der Uhr verwendet werden.
- Um die App freihändig mit Siri zu öffnen, können Sie auf dem iPhone einen Kurzbefehl erstellen, der einfach FLwatch öffnet. Sie könnten ihn zum Beispiel `Glukosekurve` oder `Blutzucker` nennen. Aktivieren Sie die Option, den Kurzbefehl auch auf der Uhr anzuzeigen. Wenn Sie dann diesen Ausdruck zu Siri sagen, wird FLwatch direkt geöffnet. Das Gleiche funktioniert auch auf dem iPhone.

### Funktionen {#features}
#### Überwachung
* Glukose-Diagramm auf iPhone und Apple Watch
* Interaktives Diagramm auf dem iPhone zur Anzeige einzelner Werte per Fingertipp
* Always-On-Modus des iPhone-Bildschirms

#### Insulin
* Unterstützt schnell wirkende und sehr schnell wirkende Bolusinsuline
* Berechnung von Insulin on Board (IOB)
* Insulin-on-Board-Diagramm
* Insulinaktivitätsdiagramm
* Manuelle Erfassung von Insulindosen
* Integrierter Kohlenhydrat-zu-Insulin-Rechner

#### Systemintegration
* iOS-Widgets und Sperrbildschirm-Widgets mit und ohne Diagramm(e)
* Live Activities auf dem iPhone inklusive Smart-Stack-Spiegelung auf der Apple Watch
* Widget für den StandBy-Modus
* watchOS-Widgets und Komplikationen
* CarPlay-Unterstützung über Widgets und Live Activities
* Export von Insulindosen und Glukosedaten nach Apple Health
* Unterstützung für Siri und Kurzbefehle zur Anzeige des Glukosewerts, zum Vorlesen des Glukosewerts und zur schnellen Erfassung von Insulindosen

### Technische Hinweise
FLwatch verwendet das exponentielle Insulinmodell von LoopKit. Das Modell nutzt drei Parameter: `actionDuration`, `peakActivityTime` und `delay`.

- Für schnell wirkendes Insulin lauten die Parameter 360, 75 und 10 Minuten.
- Für sehr schnell wirkendes Insulin lauten die Parameter 360, 55 und 10 Minuten.

### ToDo
- Trainingsaktivität implementieren

### Support und Feedback {#support}
Für Support öffnen Sie bitte ein [GitHub-Issue](https://github.com/poml88/FLwatch/issues), starten Sie eine [GitHub-Diskussion](https://github.com/poml88/FLwatch/discussions) oder senden Sie eine E-Mail an **flwatch [at] cmdline [dot] net**.

Feedback ist sehr willkommen und kann über dieselben Kanäle gesendet werden.

### Spenden
Spenden sind immer sehr willkommen.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Danksagungen
Bitte schauen Sie sich auch diese Projekte an:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle Produkt- und Firmennamen, Marken, Dienstleistungsmarken, eingetragenen Marken und eingetragenen Dienstleistungsmarken sind Eigentum ihrer jeweiligen Inhaber. Ihre Verwendung dient ausschließlich Informationszwecken und bedeutet keine Zugehörigkeit zu oder Billigung durch diese. Bitte beachten Sie: Diese App steht in keiner Verbindung zu Abbott Diabetes Care Inc. und wird von diesem Unternehmen nicht unterstützt.
