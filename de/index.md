---
layout: landing
title: "FLwatch – Glukose- & Insulin-Diagramme für iPhone & Apple Watch"
description: "FLwatch ist eine kostenlose Open-Source-App, die Glukose-, Insulin-on-Board- und Aktivitätsdiagramme mit Widgets auf iPhone und Apple Watch mithilfe von LibreLinkUp-Daten anzeigt."
lang: de
permalink: /de/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch: Glukose Sensor Graph"
---


***Warnung: Dieses Projekt ist sehr experimentell! Bitte verwenden Sie diese App mit Vorsicht und äußerster Sorgfalt. Treffen Sie keine unüberlegten Entscheidungen auf Grundlage der Software. Verwenden Sie diese Software nicht, wenn Sie sich unsicher sind. Verwenden Sie diese App nicht für medizinische Entscheidungen. Es wird keinerlei Garantie übernommen. Die Verwendung erfolgt auf eigene Gefahr!***

Diese Software ist kostenlos und Open Source. Sie wurde aus persönlichen Bedürfnissen heraus entwickelt, aber jeder sollte davon profitieren können.

### Verwendung {#usage}
***Installation:*** Stellen Sie sicher, dass die watchOS-App installiert ist, idealerweise bevor Sie die iOS-App starten. Je nach Ihrer Konfiguration wird die watchOS-App entweder automatisch installiert oder muss über die „Watch”-App auf dem Telefon installiert werden.
- @TypeOneCallum hat ein wirklich tolles [Setup-Tutorial-Video](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) erstellt (Vielen Dank!). Wenn Sie es anschauen, wird die Einrichtung viel einfacher.
- Die App benötigt iOS 17.5 und watchOS 10.5
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Die Einstellungen werden in der iOS-App vorgenommen und dann an die watchOS-App übertragen. Dies funktioniert nur, wenn die watchOS-App auf der Uhr installiert ist.
- ***Herstellen der Verbindung zwischen den Apps:*** Damit alles funktioniert, müssen Sie sich zunächst selbst als Follower einladen. *LibreView-Anmeldedaten funktionieren nicht.* Dazu gibt es in der LibreLink-/Libre 3-App unter „Teilen/Verbundene Apps” den Punkt „LibreLinkUp verbinden/verwalten”. Tippen Sie auf „Verbindung hinzufügen” und geben Sie die E-Mail-Adresse ein, die Sie für das Follower-Konto verwenden möchten. Eine Einladung wird an diese Adresse gesendet (die E-Mail-Adresse kann dieselbe wie für LibreView sein). Um das LibreLinkUp-Follower-Konto einzurichten, installieren Sie anschließend die [LibreLinkUp-App](https://apps.apple.com/us/app/librelinkup/id1234323923) auf Ihrem Smartphone und folgen Sie den Anweisungen unter Verwendung der E-Mail-Adresse, die Sie gerade eingeladen haben. Es gibt eine [Schritt-für-Schritt-Anleitung](https://www.librelinkup.com/articles/getting-started), die Ihnen vielleicht hilfreich sein könnte. Vergewissern Sie sich, dass Sie Ihre eigene Blutzuckergrafik in der LibreLinkUp-App sehen können. Öffnen Sie abschließend FLwatch und geben Sie die Anmeldedaten des Follower-Kontos ein, siehe unten. Derzeit wird von FLwatch nur ein gefolgter Patient pro Follower-Konto unterstützt.
- Die LibreLinkUp-App kann dann geschlossen oder deinstalliert werden, wird aber möglicherweise später benötigt, um neue Nutzungsbedingungen und Datenschutzrichtlinien zu akzeptieren oder um zu überprüfen, ob das Konto/die Verbindung funktioniert.
- Um eine Verbindung zu Ihrem LibreLinkUp-Follower-Konto herzustellen, geben Sie Ihre Anmeldedaten in FLwatch auf der Registerkarte „Verbinden“ ein. Wenn die watchOS-App installiert ist, werden die Anmeldedaten an die Watch-App übertragen. Sie können die Anmeldedaten erneut übertragen, indem Sie erneut auf die Schaltfläche „Verbinden“ tippen.
- Es kann bis zu einer Minute dauern, bis die Daten abgerufen und angezeigt werden.
- Um die Insulinberechnung zu verwenden, tippen Sie auf dem Startbildschirm auf die IOB-Beschriftung. Derzeit werden folgende Insulintypen unterstützt: schnell wirkend (Novolog, Novorapid, ...) und sehr schnell wirkend (Fiasp, Lyumjev, ...). Weitere Insuline können auf Anfrage hinzugefügt werden. *Bitte lassen Sie es mich wissen.*
  - Die App verwendet das Exponentialmodell von LoopKit. Das Modell berücksichtigt drei Parameter: actionDuration, peakActivityTime und delay. Für schnell wirksames Insulin sind die Parameter 360, 75 und 10 Minuten, für schnell wirksames Insulin sind die Parameter 360, 55 und 10 Minuten.
- Es gibt eine Einstellung, mit der die Glukosekurve eine Stunde lang auf der Uhr angezeigt wird: Gehen Sie entweder auf der Uhr oder in der „Watch”-App des Telefons zu „Einstellungen” – „Allgemein” – „Zurück zur Uhr”, scrollen Sie nach unten, tippen Sie auf „FLwatch” und wählen Sie „Nach 1 Stunde”. Auf diese Weise bleibt FLwatch 1 Stunde lang im Vordergrund und erhält eine angemessene Anzahl von Aktualisierungen (z. B. jede Minute).
- Am einfachsten starten Sie die App auf dem Smartphone oder der Uhr, indem Sie ein Widget/eine Komplikation auf Ihrem Startbildschirm, Sperrbildschirm, Zifferblatt oder an einer anderen Stelle platzieren und darauf tippen.
- Um die App mit Siri freihändig zu öffnen, können Sie auf dem Telefon eine Verknüpfung erstellen, die Sie beispielsweise „Glukosediagramm“ oder „Blutzucker“ nennen. Diese Verknüpfung öffnet einfach FLwatch. Wählen Sie die Verknüpfungsoption „Auf der Uhr anzeigen“. Wenn Sie nun Siri aktivieren, sagen Sie einfach „Glukosediagramm“ und schon werden die App FLwatch und ihr Diagramm angezeigt.
Das Gleiche funktioniert auch auf dem Telefon.


### Funktionen 
* Blutzucker-Diagramm auf Smartphone und Uhr
* Interaktives Diagramm auf dem Smartphone zur Anzeige einzelner Werte per Fingertipp
* Smartphone-Bildschirm im Always-On-Modus
* Unterstützt schnell wirkende und sehr schnell wirkende Bolusinsuline
* Berechnung der Insulin-On-Board-Menge (IOB)
* Insulin-On-Board-Diagramm
* Insulinaktivitätsdiagramm
* iOS-Widgets und Widgets für den Sperrbildschirm mit und ohne Graph(en)
* LiveActivity
* Widget für den Standby-Modus
* watchOS-Widgets / Komplikationen
* CarPlay-Unterstützung über Widgets und LiveActivity

### ToDo
- Trainingsaktivitaet implementieren

### Support und Feedback {#support}
Für Support öffnen Sie bitte ein Ticket, starten Sie eine Diskussion oder senden Sie eine E-Mail an **flwatch [ a t ] cmdline [ d o t ] net**. Feedback ist sehr willkommen, bitte nutzen Sie die gleichen Kontaktmöglichkeiten wie für den Support.

### Spenden... 
...sind immer sehr willkommen!
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

Bitte schauen Sie sich auch diese Projekte an:

### Danksagungen: 
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Alle Produkt- und Firmennamen, Marken, Dienstleistungsmarken, eingetragenen Marken und eingetragenen Dienstleistungsmarken sind Eigentum ihrer jeweiligen Inhaber. Ihre Verwendung dient ausschließlich Informationszwecken und bedeutet keine Zugehörigkeit zu oder Billigung durch diese. Bitte beachten Sie: Diese App steht in keiner Verbindung zu Abbott Diabetes Care Inc. und wird von diesem Unternehmen nicht unterstützt.
