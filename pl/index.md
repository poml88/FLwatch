---
layout: landing
title: "FLwatch – Glukoza i insulina na iPhonie i Apple Watch"
description: "FLwatch wyświetla odczyty glukozy z sensorów FreeStyle Libre i Dexcom oraz oferuje rejestrowanie insuliny, alerty, widgety i Live Activities na iPhonie i Apple Watch."
lang: pl
permalink: /pl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glukoza i insulina"
---

<div class="notice-note">
<strong>Nie używaj do podejmowania decyzji terapeutycznych.</strong>
<br>
Informacji dostarczanych przez FLwatch i jego rozszerzenia nie wolno wykorzystywać do podejmowania decyzji dotyczących leczenia lub dawkowania insuliny. Zawsze polegaj na swoim systemie monitorowania glukozy i konsultuj decyzje medyczne z lekarzem lub innym pracownikiem ochrony zdrowia.
</div>

FLwatch wyświetla na iPhonie i Apple Watch odczyty glukozy z sensorów Abbott FreeStyle Libre 2, Libre 3 i Libre 3+, a także Dexcom G6, G7 i ONE+.

Pozwala również rejestrować dawki insuliny i przedstawia osobne wykresy aktywnej insuliny oraz aktywności insuliny, pomagając lepiej zrozumieć zależność między insuliną a glukozą.

FLwatch powstał jako osobisty projekt wspierający mnie w zarządzaniu własną cukrzycą. Udostępniłem go publicznie, bezpłatnie i jako open source, mając nadzieję, że przyda się również innym.

### W skrócie

- Wykresy glukozy, aktywnej insuliny i aktywności insuliny na iPhonie i Apple Watch
- Połączenie bezpośrednio przez Bluetooth, LibreLinkUp lub Dexcom Share
- Konfigurowalne alerty glukozy i sensora
- Widgety ekranu początkowego, ekranu blokady i StandBy oraz widgety i komplikacje Apple Watch
- Obsługa Live Activities, CarPlay, Siri i Skrótów
- Eksport do Apple Health oraz eksport do Nightscout przy bezpośrednim połączeniu z sensorem FreeStyle Libre 3 lub FreeStyle Libre 3+
- Wymaga iOS 18 oraz watchOS 10.5

### Obsługiwane sensory i połączenia

| Producent | Sensory | Połączenie |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 | LibreLinkUp |
| Abbott | FreeStyle Libre 3 i FreeStyle Libre 3+ | Bezpośrednio przez Bluetooth lub LibreLinkUp |
| Dexcom | G6, G7 i ONE+ | Dexcom Share |

### Funkcje {#features}

#### Monitorowanie glukozy

- Wykres glukozy na iPhonie i Apple Watch
- Interaktywny wykres na iPhonie — stuknij, aby sprawdzić poszczególne odczyty
- Opcjonalna korekta kalibracji dla bezpośrednio połączonych sensorów FreeStyle Libre 3 i FreeStyle Libre 3+
- Sprawdzanie bieżącego poziomu glukozy i trendu za pomocą Siri lub Skrótów
- Opcjonalny tryb stale włączonego ekranu umożliwiający szybki podgląd

#### Alerty

- Konfigurowalne alerty niskiego i wysokiego poziomu glukozy na iPhonie, Apple Watch i w CarPlay
- Dodatkowe alerty krytycznie niskiego poziomu glukozy i utraty sygnału dla bezpośrednio połączonych sensorów FreeStyle Libre 3 i FreeStyle Libre 3+
- Powiadomienia o rozgrzewaniu, pozostałym czasie działania, wygaśnięciu i konieczności wymiany bezpośrednio połączonych sensorów FreeStyle Libre 3 i FreeStyle Libre 3+
- Opcjonalne alerty krytyczne i osobne przedziały „Nie przeszkadzać” dla każdego typu alertu

Alerty FLwatch są dostarczane w miarę możliwości i nie są gwarantowane. Mogą być opóźnione lub pominięte. Przed podjęciem działania zawsze potwierdź odczyt glukozy.

#### Rejestrowanie insuliny

- Rejestrowanie dawek insuliny na iPhonie lub za pomocą Siri i Skrótów na iPhonie i Apple Watch
- Podstawowy kalkulator węglowodanów i insuliny wykorzystujący wielkość porcji oraz konfigurowalny stosunek insuliny do węglowodanów
- Obliczanie i wykres aktywnej insuliny (IOB)
- Wykres aktywności insuliny
- Obsługa szybko i bardzo szybko działających insulin bolusowych

#### Widgety, Live Activities i CarPlay

- Widgety ekranu początkowego z wykresami i bez nich
- Widgety ekranu blokady i StandBy
- Live Activities do szybkiego sprawdzania aktualizacji poziomu glukozy
- Natywna aplikacja na Apple Watch z szerokim wyborem widgetów i komplikacji tarczy zegarka
- Wykres glukozy bezpośrednio na Apple Watch
- Odzwierciedlanie Live Activities w Smart Stack od watchOS 11
- Widok CarPlay pokazujący bieżący poziom glukozy i IOB
- Wykresy glukozy w CarPlay za pośrednictwem widgetów i Live Activities

#### Eksport danych

- Eksport odczytów glukozy i zarejestrowanych dawek insuliny do Apple Health
- Przy bezpośrednim połączeniu Bluetooth z sensorem FreeStyle Libre 3 lub FreeStyle Libre 3+ eksport odczytów glukozy i zarejestrowanych dawek insuliny na własny serwer Nightscout

{% include screenshots.html %}

### Szybki start {#usage}

1. Zainstaluj FLwatch z [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Upewnij się, że aplikacja watchOS jest zainstalowana na Apple Watch, najlepiej przed uruchomieniem aplikacji na iPhonie.
3. Przy pierwszym uruchomieniu FLwatch poprosi o wybranie systemu CGM: `FreeStyle Libre` przez LibreLinkUp, `Dexcom` przez Dexcom Share lub `FreeStyle Libre 3 (Bluetooth)` w celu bezpośredniego połączenia z sensorem.
4. Po dokonaniu wyboru FLwatch automatycznie otworzy odpowiedni ekran `Połącz`. Postępuj zgodnie z wyświetlanymi instrukcjami i odpowiednimi wskazówkami poniżej.
5. Po nawiązaniu połączenia poczekaj do minuty na pojawienie się pierwszych danych glukozy.

Wybrany system CGM możesz później zmienić w sekcji `Ustawienia`.

Jeśli aplikacja watchOS jest zainstalowana, ustawienia i dane logowania do połączeń w chmurze wprowadzone w aplikacji na iPhonie są przesyłane do aplikacji na Apple Watch. Możesz przesłać je ponownie, stukając jeszcze raz `Połącz`.

### Bezpośrednie połączenie z FreeStyle Libre 3 i FreeStyle Libre 3+

W nowej instalacji wybierz `FreeStyle Libre 3 (Bluetooth)` w selektorze CGM. FLwatch automatycznie otworzy ekran połączenia Bluetooth.

Przed parowaniem:

- Dla większości użytkowników z już aktywowanym sensorem zalecany jest tryb `Równoległy`. Pozostawia on ważne dotychczasowe dane połączenia FreeStyle Libre 3 zapisane w sensorze, ułatwiając późniejszy powrót do aplikacji FreeStyle Libre 3.
- Zaloguj się na konto LibreView użyte do aktywacji sensora, a następnie stuknij `Pobierz identyfikator konta` w FLwatch. W przypadku parowania równoległego informacje o koncie muszą odpowiadać kontu, za pomocą którego aktywowano sensor. Jest to inne konto niż konto obserwatora LibreLinkUp używane do połączenia w chmurze.
- Tylko jedna aplikacja powinna mieć dostęp do sensora w danym momencie. Przed użyciem FLwatch całkowicie zamknij aplikację FreeStyle Libre 3 i wyłącz jej dostęp do Bluetooth w ustawieniach iOS. Przełączanie między aplikacjami może potrwać od dwóch do trzech minut.
- Gdy FLwatch poprosi o skanowanie, przyłóż górną część iPhone’a do sensora i trzymaj nieruchomo do zakończenia parowania NFC.

Tryb `Nowy` jest przeznaczony wyłącznie dla fabrycznie nowego, nieużywanego sensora. Natychmiast rozpoczyna okres użytkowania sensora i nie można tego cofnąć. Większość użytkowników powinna aktywować sensor w aplikacji FreeStyle Libre 3, a następnie sparować go z FLwatch w trybie `Równoległy`.

Po sparowaniu trzymaj iPhone’a w pobliżu sensora. Odczyty glukozy są odbierane bezpośrednio przez Bluetooth mniej więcej raz na minutę, bez konta obserwatora ani połączenia w chmurze. Bezpośrednie połączenie umożliwia również korektę kalibracji, alerty krytycznie niskiego poziomu glukozy i utraty sygnału, powiadomienia o stanie sensora oraz eksport do Nightscout.

Te funkcje połączenia bezpośredniego nie są dostępne dla sensorów FreeStyle Libre 2.

### Konfiguracja LibreLinkUp

LibreLinkUp może dostarczać odczyty glukozy z sensorów FreeStyle Libre 2, FreeStyle Libre 3 i FreeStyle Libre 3+. Aby używać go z FLwatch, zaproś samego siebie jako własnego obserwatora.

*Dane logowania LibreView nie działają. Użyj danych logowania konta obserwatora LibreLinkUp.*

<div class="notice-note">
<strong>Filmowa instrukcja konfiguracji LibreLinkUp</strong>
<br>
@TypeOneCallum przygotował bardzo pomocny <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">film pokazujący krok po kroku konfigurację FLwatch</a>. Jeśli konfigurujesz LibreLinkUp po raz pierwszy, warto zacząć właśnie od niego.
</div>

1. W aplikacji FreeStyle LibreLink lub FreeStyle Libre 3 przejdź do Udostępnianie / Połączone aplikacje.
2. Otwórz Połącz / Zarządzaj LibreLinkUp.
3. Stuknij `Dodaj połączenie` i wpisz adres e-mail, którego chcesz użyć dla konta obserwatora.
4. Zaakceptuj zaproszenie wysłane na ten adres e-mail.
5. Zainstaluj [aplikację LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) na iPhonie i dokończ konfigurację zaproszonego konta obserwatora.
6. Upewnij się, że w LibreLinkUp widzisz własny wykres glukozy.
7. Otwórz FLwatch i wpisz dane logowania konta obserwatora na karcie `Połącz`.

Adres e-mail konta obserwatora może być taki sam jak adres używany w LibreView. Jeśli konto obserwatora ma więcej niż jedno połączenie, po zalogowaniu wybierz osobę, której odczyty ma wyświetlać FLwatch.

Aplikację LibreLinkUp można następnie zamknąć lub odinstalować. Może być potrzebna później do zaakceptowania zaktualizowanych warunków korzystania lub polityki prywatności albo do sprawdzenia, czy konto i połączenie nadal działają.

[Przewodnik LibreLinkUp krok po kroku](https://www.librelinkup.com/articles/getting-started) zawiera dodatkowe informacje.

<div class="notice-note">
<strong>Zgodność z API LibreLinkUp</strong>
<br>
FLwatch obecnie obsługuje API LibreLinkUp 4.x. API LibreLinkUp 5.0.0 nie jest jeszcze obsługiwane. Jeśli API 4.x zostanie w przyszłości wyłączone, dane glukozy z LibreLinkUp w FLwatch mogą przestać działać bez ostrzeżenia. Funkcje związane z IOB i inne metody połączenia będą nadal działać.
</div>

### Konfiguracja Dexcom Share

Sensory Dexcom G6, Dexcom G7 i Dexcom ONE+ mogą dostarczać odczyty glukozy przez Dexcom Share.

1. Włącz Share w aplikacji Dexcom. Dexcom wymaga zaproszenia co najmniej jednego obserwatora, zanim będzie można włączyć Share.
2. W nowej instalacji wybierz `Dexcom` w selektorze CGM. FLwatch automatycznie otworzy ekran połączenia Dexcom Share.
3. Zaloguj się za pomocą adresu e-mail i hasła do konta Dexcom używanego przez osobę noszącą sensor — tego samego konta, którego używa aplikacja Dexcom na iPhonie tej osoby — i stuknij `Połącz`. FLwatch automatycznie wykryje region konta.

Nie używaj danych logowania obserwatora. Dexcom Share udostępnia aplikacjom innych firm odczyty osoby noszącej sensor tylko wtedy, gdy używane jest jej konto.

Jeśli aplikacja na Apple Watch nie była zainstalowana podczas łączenia, zainstaluj ją i ponownie stuknij `Połącz`, aby przesłać dane logowania. Połączenie Dexcom Share używane przez FLwatch jest nieoficjalne i może zostać zmienione lub ograniczone bez ostrzeżenia.

### Heartbeat Bluetooth dla połączeń w chmurze

Podczas korzystania z LibreLinkUp lub Dexcom Share do działania alertów FLwatch niskiego i wysokiego poziomu glukozy potrzebna jest funkcja heartbeat Bluetooth. Włącz ją w `Ustawienia > Heartbeat Bluetooth` i wybierz znajdujący się w pobliżu nadajnik sensora. FLwatch nie może dostarczać tych alertów przez połączenie w chmurze, gdy heartbeat jest wyłączony; nadal używaj alertów producenta sensora jako podstawowych alertów.

Bezpośrednie połączenie Bluetooth z FreeStyle Libre 3 i FreeStyle Libre 3+ nie korzysta z tego ustawienia.

### Funkcje związane z insuliną

Aby skonfigurować obliczanie insuliny lub zarejestrować dawkę, stuknij etykietę `IOB` na ekranie głównym.

Obecnie obsługiwane typy insuliny:

- Insulina szybko działająca, taka jak Novolog i Novorapid
- Insulina bardzo szybko działająca, taka jak Fiasp i Lyumjev

Wbudowany kalkulator wykorzystuje wielkość porcji i konfigurowalny stosunek insuliny do węglowodanów. Na życzenie można dodać kolejne typy insuliny.

### Wskazówki dotyczące Apple Watch, Siri i Skrótów

- Aby wykres glukozy pozostał widoczny na Apple Watch przez godzinę, otwórz Ustawienia na zegarku lub aplikację `Watch` na iPhonie. Przejdź do `Ogólne > Powrót do zegarka`, wybierz FLwatch, a następnie `Po 1 godzinie`.
- Umieść widget lub komplikację na ekranie początkowym, ekranie blokady lub tarczy zegarka, aby szybko otwierać FLwatch.
- Live Activities na iPhonie mogą być odzwierciedlane w Smart Stack na Apple Watch od watchOS 11.
- Siri i Skróty mogą wyświetlać lub odczytywać bieżący poziom glukozy oraz rejestrować dawki insuliny.
- Aby korzystać bez użycia rąk, utwórz skrót otwierający FLwatch, nadaj mu nazwę, na przykład `wykres glukozy`, i w razie potrzeby włącz `Pokaż na Apple Watch`.

### Uwagi techniczne

FLwatch korzysta z wykładniczego modelu insuliny z LoopKit. Model używa trzech parametrów: `actionDuration`, `peakActivityTime` i `delay`.

- Dla insuliny szybko działającej parametry wynoszą 360, 75 i 10 minut.
- Dla insuliny bardzo szybko działającej parametry wynoszą 360, 55 i 10 minut.

### Stan projektu

FLwatch to eksperymentalny projekt open source. Korzystaj z niego ostrożnie. Jest udostępniany bez gwarancji i używasz go na własne ryzyko.

FLwatch jest również dostępny do testów beta w [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Wsparcie i opinie {#support}

Jeśli potrzebujesz pomocy, otwórz [zgłoszenie na GitHubie](https://github.com/poml88/FLwatch/issues), rozpocznij [dyskusję na GitHubie](https://github.com/poml88/FLwatch/discussions) albo napisz na adres **flwatch [at] cmdline [dot] net**.

Opinie są bardzo mile widziane i możesz przesyłać je tymi samymi kanałami.

### Darowizny

Darowizny są zawsze mile widziane.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="Logo PayPal" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Logo Buy Me a Coffee" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Podziękowania

Zobacz też te projekty:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Wszystkie nazwy produktów, znaki towarowe i zarejestrowane znaki towarowe należą do ich właścicieli. Ich użycie służy wyłącznie identyfikacji i nie oznacza powiązania z właścicielami znaków ani ich poparcia.

FLwatch nie jest powiązany z Abbott Diabetes Care Inc. ani Dexcom, Inc. i nie jest wspierany przez te firmy.
