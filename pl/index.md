---
layout: landing
title: "FLwatch – wykresy glukozy i insuliny dla iPhone'a i Apple Watch"
description: "FLwatch to darmowa aplikacja open source, która pokazuje wykresy glukozy, insulin-on-board i aktywności wraz z widgetami na iPhonie i Apple Watch, korzystając z danych LibreLinkUp."
lang: pl
permalink: /pl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Wykres sensora glukozy"
---

***Ostrzeżenie: FLwatch to projekt o bardzo eksperymentalnym charakterze. Korzystaj z tej aplikacji ostrożnie i z najwyższą uwagą. Nie podejmuj decyzji medycznych na podstawie tego oprogramowania. Jest ono udostępniane bez jakiejkolwiek gwarancji i używasz go wyłącznie na własne ryzyko.***

<div class="notice-note">
<strong>Ważna uwaga</strong>
<br>
FLwatch obecnie obsługuje API LibreLinkUp 4.x. Abbott udostępnił API 5.0.0, które nie jest jeszcze obsługiwane.
<br>
Jeśli Abbott w przyszłości wyłączy API 4.x, dane glukozy w FLwatch mogą przestać działać bez ostrzeżenia. Funkcje związane z IOB nadal będą działać.
</div>

To darmowe oprogramowanie open source. Powstało z osobistej potrzeby, ale powinno być dostępne dla wszystkich.

### W skrócie
- Wyświetla wykresy glukozy, insulin-on-board i aktywności na iPhonie oraz Apple Watch
- Oferuje widgety, komplikacje, Live Activities, odzwierciedlenie w Smart Stack na Apple Watch i eksport do Apple Health
- Obsługuje ręczne rejestrowanie insuliny oraz wbudowany kalkulator węglowodanów do insuliny
- Wymaga iOS 18 oraz watchOS 10.5
- Do testów beta FLwatch jest dostępny także przez TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Obsługuje sensory Freestyle Libre 2 i 3 przez LibreLinkUp (tylko API w wersji 4.x) — korzysta z danych logowania konta obserwatora LibreLinkUp, a nie z danych LibreView
- Obsługuje sensory Dexcom G6, G7 i ONE+ przez Dexcom Share — zaloguj się adresem e-mail i hasłem konta Dexcom, na którym skonfigurowano sensor (te same dane logowania co aplikacja Dexcom na telefonie osoby noszącej sensor). „Share" musi być włączone w aplikacji Dexcom, co wymaga zaproszenia co najmniej jednego obserwatora. Nie loguj się przy użyciu konta obserwatora — Dexcom udostępnia aplikacjom innych firm wyłącznie odczyty osoby noszącej sensor.

### Szybki start {#usage}
1. Zainstaluj FLwatch z [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Upewnij się, że aplikacja watchOS jest zainstalowana na Apple Watch, najlepiej jeszcze przed uruchomieniem aplikacji iOS.
3. Utwórz i sprawdź połączenie LibreLinkUp, w którym obserwujesz samego siebie.
4. Wprowadź w FLwatch dane logowania konta obserwatora LibreLinkUp na karcie `Connect`.
5. Poczekaj do minuty, aż dane się pojawią.

Jeśli aplikacja watchOS jest zainstalowana, ustawienia i dane logowania wpisane w aplikacji iOS są przesyłane do aplikacji na zegarku.

- @TypeOneCallum przygotował bardzo pomocny [film z instrukcją konfiguracji](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB). Obejrzenie go może znacznie ułatwić konfigurację.

### Konfiguracja LibreLinkUp
Aby FLwatch działał, musisz najpierw zaprosić samego siebie, aby zostać własnym obserwatorem.

*Dane logowania LibreView nie działają.*

1. W aplikacji LibreLink lub Libre 3 przejdź do Share / Connected Apps.
2. Otwórz Connect / Manage LibreLinkUp.
3. Stuknij `Add Connection` i wpisz adres e-mail, którego chcesz użyć dla konta obserwatora.
4. Zaakceptuj zaproszenie wysłane na ten adres e-mail.
5. Zainstaluj [aplikację LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) na iPhonie i dokończ konfigurację zaproszonego konta obserwatora.
6. Upewnij się, że w LibreLinkUp widzisz własny wykres glukozy.
7. Otwórz FLwatch i wpisz tam dane logowania konta obserwatora.

Adres e-mail konta obserwatora może być taki sam jak w LibreView.

Pomocny może być także [przewodnik krok po kroku LibreLinkUp](https://www.librelinkup.com/articles/getting-started).

Obecnie FLwatch obsługuje tylko jednego obserwowanego pacjenta na jedno konto obserwatora.

Aplikację LibreLinkUp można potem zamknąć lub nawet odinstalować. Może się jednak później przydać do zaakceptowania nowych warunków korzystania lub polityki prywatności albo po prostu do sprawdzenia, czy konto i połączenie nadal działają.

### Łączenie FLwatch
- Wprowadź dane logowania konta obserwatora LibreLinkUp na karcie `Connect` w FLwatch.
- Jeśli aplikacja watchOS jest zainstalowana, dane logowania zostaną przesłane do aplikacji zegarka.
- W razie potrzeby możesz ponownie przesłać dane logowania, naciskając jeszcze raz przycisk `Connect`.
- Pobranie i wyświetlenie danych może potrwać do minuty.

### Funkcje związane z insuliną
Aby skorzystać z obliczeń insuliny, stuknij etykietę `IOB` na ekranie głównym.

Obecnie obsługiwane typy insuliny:
- Insulina szybko działająca, taka jak Novolog i Novorapid
- Insulina ultraszybko działająca, taka jak Fiasp i Lyumjev

FLwatch obsługuje także ręczne rejestrowanie insuliny i zawiera wbudowany kalkulator węglowodanów do insuliny.

Na życzenie można dodać kolejne typy insuliny.

### Wskazówki dotyczące Watch i Siri
- Aby utrzymać wykres glukozy widoczny na zegarku przez godzinę, otwórz na zegarku lub w aplikacji `Watch` na iPhonie ścieżkę `Ustawienia > Ogólne > Powrót do zegarka`, przewiń do FLwatch i wybierz `Po 1 godzinie`. Dzięki temu FLwatch dłużej pozostaje na pierwszym planie i otrzymuje rozsądną liczbę aktualizacji, na przykład mniej więcej co minutę.
- Najłatwiej uruchamiać aplikację na telefonie lub zegarku, dodając widget albo komplikację na ekranie początkowym, ekranie blokady, tarczy zegarka albo w innym wygodnym miejscu i stukając ten element.
- Live Activities na iPhonie mogą być także odzwierciedlane w Smart Stack na Apple Watch, aby zapewnić szybki dostęp.
- Siri i Skróty mogą służyć do odczytywania na głos lub wyświetlania bieżącej wartości glukozy.
- Siri i Skróty można także wykorzystać do głosowego rejestrowania dawek insuliny albo do szybkiego zapisywania dawek insuliny na zegarku.
- Aby otwierać aplikację bez użycia rąk przez Siri, możesz utworzyć na iPhonie skrót, który po prostu otwiera FLwatch. Możesz nazwać go na przykład `wykres glukozy` albo `cukier we krwi`. Włącz opcję wyświetlania skrótu także na zegarku. Potem wystarczy wypowiedzieć tę frazę do Siri, aby FLwatch otworzył się bezpośrednio. To samo działa też na iPhonie.

### Funkcje {#features}
#### Monitorowanie
* Wykres glukozy na telefonie i zegarku
* Interaktywny wykres na telefonie do podglądu pojedynczych wartości po stuknięciu
* Tryb stale włączonego ekranu na telefonie

#### Insulina
* Obsługa szybko działających i ultraszybko działających insulin bolusowych
* Obliczanie insulin on board (IOB)
* Wykres IOB
* Wykres aktywności insuliny
* Ręczne rejestrowanie insuliny
* Wbudowany kalkulator węglowodanów do insuliny

#### Integracja systemowa
* Widgety iOS oraz widgety ekranu blokady z wykresem i bez niego
* Live Activities na iPhonie, w tym odzwierciedlenie w Smart Stack na Apple Watch oraz w CarPlay
* Widget trybu StandBy
* Widgety i komplikacje watchOS
* Obsługa CarPlay przez aplikację CarPlay, widgety i Live Activities
* Eksport dawek insuliny i danych glukozy do Apple Health
* Obsługa Siri i Skrótów do wyświetlania glukozy, odczytu glukozy na głos i szybkiego zapisywania dawek insuliny
* Heartbeat Bluetooth umożliwia aktualizacje niemal co minutę oraz alarmy niskiej glukozy na iPhonie, Apple Watch i w CarPlay

### Uwagi techniczne
FLwatch korzysta z wykładniczego modelu insuliny z LoopKit. Model używa trzech parametrów: `actionDuration`, `peakActivityTime` i `delay`.

- Dla insuliny szybko działającej parametry wynoszą 360, 75 i 10 minut.
- Dla insuliny ultraszybko działającej parametry wynoszą 360, 55 i 10 minut.

### ToDo
- Wdrożyć aktywność treningową

### Wsparcie i opinie {#support}
Jeśli potrzebujesz pomocy, otwórz [issue na GitHubie](https://github.com/poml88/FLwatch/issues), rozpocznij [dyskusję na GitHubie](https://github.com/poml88/FLwatch/discussions) albo napisz na **flwatch [at] cmdline [dot] net**.

Opinie są bardzo mile widziane i możesz przesyłać je tymi samymi kanałami.

### Darowizny
Darowizny są zawsze mile widziane.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Podziękowania
Zobacz też te projekty:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Wszystkie nazwy produktów i firm, znaki towarowe, znaki usługowe, zarejestrowane znaki towarowe i zarejestrowane znaki usługowe należą do ich odpowiednich właścicieli. Ich użycie ma charakter wyłącznie informacyjny i nie oznacza żadnego powiązania ani poparcia. Uwaga: ta aplikacja nie jest powiązana z Abbott Diabetes Care Inc. ani z Dexcom, Inc., ani przez te firmy wspierana.
