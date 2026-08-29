---
layout: landing
title: "FLwatch – Glukose & Insulin auf iPhone und Apple Watch"
description: "FLwatch bringt Glukosewerte von FreeStyle Libre und Dexcom, Insulinerfassung, Warnungen, Widgets und Live-Aktivitäten auf iPhone und Apple Watch."
lang: de
permalink: /de/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glukose & Insulin"
---

<div class="notice-note">
<strong>Nicht für Therapieentscheidungen.</strong>
<br>
Die von FLwatch und seinen Erweiterungen bereitgestellten Informationen dürfen nicht für Therapieentscheidungen oder Entscheidungen zur Insulindosierung verwendet werden. Verlassen Sie sich stets auf Ihr Glukosemesssystem und ziehen Sie für medizinische Entscheidungen medizinisches Fachpersonal hinzu.
</div>

FLwatch zeigt Glukosewerte von Abbott FreeStyle Libre 2-, Libre 3- und Libre 3+-Sensoren sowie von Dexcom G6-, G7- und ONE+-Sensoren auf Ihrem iPhone und Ihrer Apple Watch an.

Sie können außerdem Insulindosen erfassen. Eigene Diagramme für Insulin on Board und Insulinaktivität helfen Ihnen, das Zusammenspiel von Insulin und Glukose besser zu verstehen.

FLwatch entstand als persönliches Projekt, um mich bei meinem eigenen Diabetesmanagement zu unterstützen. Ich habe es kostenlos und als Open Source öffentlich zugänglich gemacht, in der Hoffnung, dass es auch anderen nützlich sein kann.

### Auf einen Blick

- Diagramme für Glukose, Insulin on Board und Insulinaktivität auf iPhone und Apple Watch
- Verbindungsoptionen über direktes Bluetooth, LibreLinkUp und Dexcom Share
- Konfigurierbare Glukose- und Sensorwarnungen
- Widgets und Komplikationen für Home-Bildschirm, Sperrbildschirm, StandBy und Apple Watch
- Unterstützung für Live-Aktivitäten, CarPlay, Siri und Kurzbefehle
- Export nach Apple Health sowie zu Nightscout bei einer direkten Verbindung mit einem FreeStyle Libre 3- oder FreeStyle Libre 3+-Sensor
- Benötigt iOS 18 und watchOS 10.5

### Unterstützte Sensoren und Verbindungen

| Hersteller | Sensoren | Verbindung |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 | LibreLinkUp |
| Abbott | FreeStyle Libre 3 und FreeStyle Libre 3+ | Direktes Bluetooth oder LibreLinkUp |
| Dexcom | G6, G7 und ONE+ | Dexcom Share |

### Funktionen {#features}

#### Glukoseüberwachung

- Glukosekurve auf iPhone und Apple Watch
- Interaktives Diagramm auf dem iPhone — tippen Sie auf einzelne Messwerte, um sie genauer anzusehen
- Optionaler Kalibrierungs-Offset für direkt verbundene FreeStyle Libre 3- und FreeStyle Libre 3+-Sensoren
- Abfrage des aktuellen Glukosewerts und Trends mit Siri oder Kurzbefehlen
- Optionaler Always-On-Anzeigemodus für einen schnellen Überblick

#### Warnungen

- Konfigurierbare Warnungen bei niedrigem und hohem Glukosewert auf iPhone, Apple Watch und CarPlay
- Zusätzliche Warnungen bei kritisch niedrigem Glukosewert und Signalverlust für direkt verbundene FreeStyle Libre 3- und FreeStyle Libre 3+-Sensoren
- Hinweise zu Aufwärmstatus, verbleibender Laufzeit, Ablauf und Austausch direkt verbundener FreeStyle Libre 3- und FreeStyle Libre 3+-Sensoren
- Optionale kritische Hinweise und separate „Nicht stören“-Zeiträume für jede Warnungsart

FLwatch-Hinweise werden nach bestem Bemühen zugestellt und sind nicht garantiert. Sie können verspätet eintreffen oder ausbleiben. Bestätigen Sie immer Ihren Glukosewert, bevor Sie handeln.

#### Insulinerfassung

- Insulindosen auf dem iPhone oder mit Siri und Kurzbefehlen auf iPhone und Apple Watch erfassen
- Einfacher Kohlenhydrat- und Insulinrechner anhand der Portionsgröße und eines konfigurierbaren Insulin-Kohlenhydrat-Verhältnisses
- Berechnung und Diagramm für Insulin on Board (IOB)
- Insulinaktivitätsdiagramm
- Unterstützung für schnell wirkende und sehr schnell wirkende Bolusinsuline

#### Widgets, Live-Aktivitäten und CarPlay

- Home-Bildschirm-Widgets mit und ohne Diagramme
- Widgets für Sperrbildschirm und StandBy
- Live-Aktivitäten für schnelle Glukoseaktualisierungen
- Native Apple Watch-App mit zahlreichen Widgets und Zifferblatt-Komplikationen
- Glukosekurve direkt auf der Apple Watch
- Spiegelung von Live-Aktivitäten in den Smart Stack ab watchOS 11
- CarPlay-Ansicht mit aktuellem Glukosewert und IOB
- Glukosekurven in CarPlay über Widgets und Live-Aktivitäten

#### Datenexport

- Glukosewerte und erfasste Insulindosen nach Apple Health exportieren
- Bei einer direkten Bluetooth-Verbindung mit einem FreeStyle Libre 3- oder FreeStyle Libre 3+-Sensor Glukosewerte und erfasste Insulindosen auf den eigenen Nightscout-Server exportieren

{% include screenshots.html %}

### Schnellstart {#usage}

1. Installieren Sie FLwatch aus dem [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Stellen Sie sicher, dass die watchOS-App auf Ihrer Apple Watch installiert ist, idealerweise bevor Sie die iPhone-App starten.
3. Beim ersten Start fordert FLwatch Sie auf, Ihr CGM auszuwählen: `FreeStyle Libre` über LibreLinkUp, `Dexcom` über Dexcom Share oder `FreeStyle Libre 3 (Bluetooth)` für eine direkte Sensorverbindung.
4. Nach der Auswahl öffnet FLwatch automatisch den passenden Bildschirm `Verbinden`. Folgen Sie den dort angezeigten Anweisungen und den entsprechenden Hinweisen weiter unten.
5. Warten Sie nach dem Verbinden bis zu einer Minute, bis die ersten Glukosedaten angezeigt werden.

Sie können das ausgewählte CGM später in den `Einstellungen` ändern.

Wenn die watchOS-App installiert ist, werden die in der iPhone-App eingegebenen Einstellungen und Zugangsdaten für Cloud-Verbindungen an die Apple Watch-App übertragen. Sie können sie später erneut übertragen, indem Sie noch einmal auf `Verbinden` tippen.

### Direkte Verbindung mit FreeStyle Libre 3 und FreeStyle Libre 3+

Wählen Sie bei einer Neuinstallation in der CGM-Auswahl `FreeStyle Libre 3 (Bluetooth)`. FLwatch öffnet daraufhin automatisch den Bildschirm für die Bluetooth-Verbindung.

Vor dem Koppeln:

- Für die meisten Benutzer mit einem bereits aktivierten Sensor wird der Modus `Parallel` empfohlen. Dabei bleiben die vorhandenen FreeStyle Libre 3-Verbindungsdaten des Sensors gültig, sodass Sie später leichter zur FreeStyle Libre 3-App zurückwechseln können.
- Melden Sie sich mit dem LibreView-Konto an, mit dem der Sensor aktiviert wurde, und tippen Sie anschließend in FLwatch auf `Konto-ID abrufen`. Für die parallele Kopplung müssen die Kontoinformationen mit dem Konto übereinstimmen, mit dem der Sensor aktiviert wurde. Dieses Konto ist nicht dasselbe wie das LibreLinkUp-Follower-Konto für eine Cloud-Verbindung.
- Nur eine App sollte gleichzeitig auf den Sensor zugreifen. Beenden Sie vor der Verwendung von FLwatch die FreeStyle Libre 3-App vollständig und deaktivieren Sie deren Bluetooth-Zugriff in den iOS-Einstellungen. Der Wechsel zwischen den Apps kann zwei bis drei Minuten dauern.
- Wenn FLwatch Sie zum Scannen auffordert, halten Sie die Oberseite Ihres iPhones an den Sensor und bewegen Sie es nicht, bis die NFC-Kopplung abgeschlossen ist.

Der Modus `Neu` ist ausschließlich für einen fabrikneuen, unbenutzten Sensor vorgesehen. Er startet sofort die Tragedauer des Sensors und kann nicht rückgängig gemacht werden. Die meisten Benutzer sollten den Sensor in der FreeStyle Libre 3-App aktivieren und ihn anschließend im Modus `Parallel` mit FLwatch koppeln.

Lassen Sie Ihr iPhone nach dem Koppeln in der Nähe des Sensors. Die Glukosewerte werden ungefähr einmal pro Minute direkt über Bluetooth empfangen — ohne Follower-Konto oder Cloud-Verbindung. Eine direkte Verbindung ermöglicht außerdem einen Kalibrierungs-Offset, Warnungen bei kritisch niedrigem Glukosewert und Signalverlust, Sensorstatus-Hinweise sowie den Nightscout-Export.

Diese Funktionen der direkten Verbindung sind für FreeStyle Libre 2-Sensoren nicht verfügbar.

### LibreLinkUp einrichten

LibreLinkUp kann Glukosewerte von FreeStyle Libre 2-, FreeStyle Libre 3- und FreeStyle Libre 3+-Sensoren bereitstellen. Um LibreLinkUp mit FLwatch zu verwenden, laden Sie sich selbst als eigenen Follower ein.

*LibreView-Zugangsdaten funktionieren nicht. Verwenden Sie die Zugangsdaten eines LibreLinkUp-Follower-Kontos.*

<div class="notice-note">
<strong>Videoanleitung zur Einrichtung von LibreLinkUp</strong>
<br>
@TypeOneCallum hat ein sehr hilfreiches <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">Schritt-für-Schritt-Video zur Einrichtung von FLwatch</a> erstellt. Wenn Sie LibreLinkUp zum ersten Mal einrichten, ist dies ein guter Ausgangspunkt.
</div>

1. Öffnen Sie in der FreeStyle LibreLink- oder FreeStyle Libre 3-App den Bereich Teilen / Verbundene Apps.
2. Öffnen Sie LibreLinkUp verbinden / verwalten.
3. Tippen Sie auf `Verbindung hinzufügen` und geben Sie die E-Mail-Adresse ein, die Sie für das Follower-Konto verwenden möchten.
4. Nehmen Sie die Einladung an, die an diese E-Mail-Adresse gesendet wurde.
5. Installieren Sie die [LibreLinkUp-App](https://apps.apple.com/us/app/librelinkup/id1234323923) auf Ihrem iPhone und richten Sie das eingeladene Follower-Konto dort vollständig ein.
6. Vergewissern Sie sich, dass Sie in LibreLinkUp Ihre eigene Glukosekurve sehen können.
7. Öffnen Sie FLwatch und geben Sie die Zugangsdaten des Follower-Kontos auf der Registerkarte `Verbinden` ein.

Die E-Mail-Adresse des Follower-Kontos kann mit der für LibreView verwendeten Adresse übereinstimmen. Wenn das Follower-Konto mehr als eine Verbindung hat, wählen Sie nach der Anmeldung die Person aus, deren Werte FLwatch anzeigen soll.

Anschließend kann die LibreLinkUp-App geschlossen oder deinstalliert werden. Möglicherweise benötigen Sie sie später erneut, um aktualisierte Nutzungsbedingungen oder Datenschutzrichtlinien zu akzeptieren oder um zu prüfen, ob das Konto und die Verbindung weiterhin funktionieren.

Die [Schritt-für-Schritt-Anleitung von LibreLinkUp](https://www.librelinkup.com/articles/getting-started) bietet weitere Hilfe.

<div class="notice-note">
<strong>Kompatibilität mit der LibreLinkUp-API</strong>
<br>
FLwatch unterstützt derzeit die LibreLinkUp-API 4.x. LibreLinkUp API 5.0.0 wird noch nicht unterstützt. Falls API 4.x zukünftig deaktiviert wird, funktionieren LibreLinkUp-Glukosedaten in FLwatch möglicherweise ohne Vorwarnung nicht mehr. IOB-bezogene Funktionen und andere Verbindungsmethoden funktionieren weiterhin.
</div>

### Dexcom Share einrichten

Dexcom G6-, Dexcom G7- und Dexcom ONE+-Sensoren können Glukosewerte über Dexcom Share bereitstellen.

1. Aktivieren Sie Share in der Dexcom-App. Dexcom erfordert mindestens eine Follower-Einladung, bevor Share aktiviert werden kann.
2. Wählen Sie bei einer Neuinstallation in der CGM-Auswahl `Dexcom`. FLwatch öffnet automatisch den Bildschirm für die Dexcom Share-Verbindung.
3. Melden Sie sich mit der E-Mail-Adresse und dem Passwort des Dexcom-Kontos an, das der Sensorträger verwendet — also mit demselben Konto wie in der Dexcom-App auf dem iPhone des Trägers — und tippen Sie auf `Verbinden`. FLwatch erkennt die Kontoregion automatisch.

Verwenden Sie nicht die Zugangsdaten eines Followers. Dexcom Share stellt Drittanbieter-Apps nur dann die eigenen Werte des Sensorträgers zur Verfügung, wenn dessen Konto verwendet wird.

Falls die Apple Watch-App beim Verbinden noch nicht installiert war, installieren Sie sie und tippen Sie erneut auf `Verbinden`, um die Zugangsdaten zu übertragen. Die von FLwatch verwendete Dexcom Share-Verbindung ist inoffiziell und kann ohne Vorankündigung geändert oder eingeschränkt werden.

### Bluetooth-Heartbeat für Cloud-Verbindungen

Bei der Verwendung von LibreLinkUp oder Dexcom Share benötigen die FLwatch-Warnungen für niedrige und hohe Glukosewerte den Bluetooth-Heartbeat. Aktivieren Sie ihn unter `Einstellungen > Bluetooth-Heartbeat` und wählen Sie den Sensor-Transmitter in Ihrer Nähe aus. Solange der Heartbeat ausgeschaltet ist, kann FLwatch diese Warnungen bei einer Cloud-Verbindung nicht zustellen. Verwenden Sie die Warnungen des Sensorherstellers weiterhin als primäre Warnungen.

Die direkte Bluetooth-Verbindung mit FreeStyle Libre 3 und FreeStyle Libre 3+ verwendet diese Einstellung nicht.

### Insulin-Funktionen

Um die Insulinberechnung zu konfigurieren oder eine Dosis zu erfassen, tippen Sie auf dem Home-Bildschirm auf die Bezeichnung `IOB`.

Derzeit unterstützte Insulintypen:

- Schnell wirkendes Insulin wie Novolog und Novorapid
- Sehr schnell wirkendes Insulin wie Fiasp und Lyumjev

Der integrierte Rechner verwendet die Portionsgröße und ein konfigurierbares Insulin-Kohlenhydrat-Verhältnis. Weitere Insulintypen können auf Anfrage ergänzt werden.

### Tipps für Apple Watch, Siri und Kurzbefehle

- Um die Glukosekurve eine Stunde lang auf der Apple Watch sichtbar zu halten, öffnen Sie die Einstellungen auf der Uhr oder die App `Watch` auf dem iPhone. Gehen Sie zu `Allgemein > Zurück zur Uhr`, wählen Sie FLwatch und anschließend `Nach 1 Stunde`.
- Platzieren Sie ein Widget oder eine Komplikation auf dem Home-Bildschirm, Sperrbildschirm oder Zifferblatt, um schnell auf FLwatch zuzugreifen.
- Live-Aktivitäten auf dem iPhone können ab watchOS 11 in den Smart Stack der Apple Watch gespiegelt werden.
- Siri und Kurzbefehle können Ihren aktuellen Glukosewert anzeigen oder vorlesen und Insulindosen erfassen.
- Für den freihändigen Zugriff können Sie einen Kurzbefehl erstellen, der FLwatch öffnet. Geben Sie ihm einen Namen wie `Glukosekurve` und aktivieren Sie bei Bedarf `Auf Apple Watch zeigen`.

### Technische Hinweise

FLwatch verwendet das exponentielle Insulinmodell von LoopKit. Das Modell nutzt drei Parameter: `actionDuration`, `peakActivityTime` und `delay`.

- Für schnell wirkendes Insulin lauten die Parameter 360, 75 und 10 Minuten.
- Für sehr schnell wirkendes Insulin lauten die Parameter 360, 55 und 10 Minuten.

### Projektstatus

FLwatch ist ein experimentelles Open-Source-Projekt. Verwenden Sie es mit Vorsicht. Es wird ohne Gewähr bereitgestellt und die Nutzung erfolgt auf eigene Gefahr.

FLwatch ist für Betatests auch über [TestFlight](https://testflight.apple.com/join/HwgkwcGz) verfügbar.

### Support und Feedback {#support}

Für Support öffnen Sie bitte ein [GitHub-Issue](https://github.com/poml88/FLwatch/issues), starten Sie eine [GitHub-Diskussion](https://github.com/poml88/FLwatch/discussions) oder senden Sie eine E-Mail an **flwatch [at] cmdline [dot] net**.

Feedback ist sehr willkommen und kann über dieselben Kanäle gesendet werden.

### Spenden

Spenden sind immer sehr willkommen.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="PayPal-Logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Buy Me a Coffee-Logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Danksagungen

Bitte schauen Sie sich auch diese Projekte an:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle Produktnamen, Marken und eingetragenen Marken sind Eigentum ihrer jeweiligen Inhaber. Ihre Verwendung dient ausschließlich der Identifikation und bedeutet weder eine Verbindung mit den Markeninhabern noch deren Unterstützung.

FLwatch steht in keiner Verbindung zu Abbott Diabetes Care Inc. oder Dexcom, Inc. und wird von diesen Unternehmen nicht unterstützt.
