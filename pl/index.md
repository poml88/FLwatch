---
layout: landing
title: "FLwatch – wykresy glukozy i insuliny dla iPhone'a i Apple Watch"
description: "FLwatch to darmowa aplikacja open source, która pokazuje wykresy glukozy, insulin-on-board i aktywności wraz z widgetami na iPhonie i Apple Watch, korzystając z danych LibreLinkUp."
lang: pl
permalink: /pl/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Wykres sensora glukozy"
---

***Ostrzeżenie: ten projekt jest bardzo eksperymentalny. Korzystaj z tej aplikacji ostrożnie i z najwyższą uwagą. Nie podejmuj pochopnych decyzji na podstawie oprogramowania. Nie używaj tego programu, jeśli masz wątpliwości. Nie korzystaj z tej aplikacji do podejmowania decyzji medycznych. Nie daje ona żadnej gwarancji. Używasz jej wyłącznie na własne ryzyko.***

To darmowe oprogramowanie open source. Powstaje z osobistej potrzeby, ale każdy powinien móc z niego skorzystać.

### Użycie {#usage}
***Instalacja:*** Upewnij się, że aplikacja watchOS jest zainstalowana, najlepiej jeszcze przed uruchomieniem aplikacji iOS. W zależności od konfiguracji aplikacja watchOS zostanie zainstalowana automatycznie albo trzeba ją zainstalować przez aplikację `Watch` na telefonie.
- @TypeOneCallum przygotował bardzo dobry [film instruktażowy konfiguracji](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) (dziękuję!). Obejrzenie go znacznie ułatwia konfigurację.
- Aplikacja wymaga iOS 17.5 i watchOS 10.5.
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Ustawienia są konfigurowane w aplikacji iOS, a następnie przesyłane do aplikacji watchOS. Działa to tylko wtedy, gdy aplikacja watchOS jest zainstalowana na zegarku.
- ***Łączenie aplikacji:*** Żeby wszystko zadziałało, najpierw musisz zaprosić siebie jako własnego obserwatora. *Dane logowania LibreView nie działają.* W aplikacji LibreLink / Libre 3 w sekcji Share / Connected Apps znajdziesz opcję połączenia lub zarządzania LibreLinkUp. Stuknij `Add Connection` i wpisz adres e-mail, który chcesz wykorzystać do konta obserwatora. Na ten adres zostanie wysłane zaproszenie. Może to być ten sam adres co w LibreView. Następnie zainstaluj [aplikację LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) na telefonie i wykonaj instrukcje, używając zaproszonego adresu e-mail. Pomocny może być też ten [przewodnik krok po kroku](https://www.librelinkup.com/articles/getting-started). Upewnij się, że w aplikacji LibreLinkUp widzisz własny wykres poziomu glukozy. Na koniec otwórz FLwatch i wpisz dane konta obserwatora, jak opisano poniżej. Obecnie FLwatch obsługuje tylko jednego obserwowanego pacjenta na jedno konto obserwatora.
- Potem aplikację LibreLinkUp można zamknąć lub odinstalować, ale może być jeszcze potrzebna do zaakceptowania nowych warunków korzystania, polityki prywatności albo po prostu do sprawdzenia, czy konto i połączenie nadal działają.
- Aby połączyć się z kontem LibreLinkUp obserwatora, wpisz swoje dane logowania w FLwatch na karcie `Connect`. Jeśli aplikacja watchOS jest zainstalowana, dane zostaną przesłane do aplikacji na zegarku. Można je przesłać ponownie, naciskając jeszcze raz przycisk `Connect`.
- Pobranie i wyświetlenie danych może potrwać do minuty.
- Aby korzystać z obliczeń insuliny, stuknij etykietę IOB na ekranie głównym. Obecnie obsługiwane są typy insuliny: szybko działająca (Novolog, Novorapid, ...) oraz ultraszybko działająca (Fiasp, Lyumjev, ...). Inne insuliny mogą zostać dodane na prośbę. *Po prostu daj znać.*
  - Aplikacja korzysta z wykładniczego modelu z LoopKit. Model ma trzy parametry: `actionDuration`, `peakActivityTime` i `delay`. Dla insuliny szybko działającej wartości wynoszą 360, 75 i 10 minut, a dla ultraszybko działającej 360, 55 i 10 minut.
- Dostępne jest ustawienie, które pozwala utrzymać wykres glukozy na ekranie zegarka przez jedną godzinę: na zegarku lub w aplikacji `Watch` na telefonie przejdź do Ustawienia -> Ogólne -> Powrót do zegarka, przewiń w dół, stuknij `FLwatch` i wybierz `Po 1 godzinie`. Dzięki temu FLwatch pozostaje na pierwszym planie przez godzinę i otrzymuje sensowną liczbę aktualizacji, na przykład co minutę.
- Najłatwiej uruchamiać aplikację na telefonie albo zegarku, dodając widget lub komplikację na ekranie początkowym, ekranie blokady, tarczy zegarka albo w innym wygodnym miejscu i stukając w ten element.
- Aby otwierać aplikację bez użycia rąk przez Siri, możesz utworzyć na telefonie skrót o nazwie na przykład `wykres glukozy` albo `cukier we krwi`. Taki skrót po prostu otwiera FLwatch. Wybierz dla niego opcję `pokaż na Apple Watch`. Potem wystarczy uruchomić Siri i wypowiedzieć nazwę skrótu, a otworzy się FLwatch z wykresem.
To samo działa również na telefonie.

### Funkcje {#features}
* Wykres poziomu glukozy na telefonie i zegarku
* Interaktywny wykres na telefonie do podglądu pojedynczych wartości po stuknięciu
* Tryb stale włączonego ekranu na telefonie
* Obsługa szybko działających i ultraszybko działających insulin bolusowych
* Obliczanie insulin on board (IOB)
* Wykres IOB
* Wykres aktywności insuliny
* Widgety iOS oraz widgety ekranu blokady z wykresem i bez niego
* Live Activities
* Widget trybu czuwania
* Widgety / komplikacje watchOS
* Obsluga CarPlay przez widgety i Live Activities

### ToDo
- Wdrożyć aktywność treningową

### Wsparcie i opinie {#support}
Jeśli potrzebujesz pomocy, otwórz issue, rozpocznij dyskusję albo napisz na **flwatch [ a t ] cmdline [ d o t ] net**. Opinie są bardzo mile widziane; możesz użyć tych samych kanałów kontaktu.

### Darowizny...
...są zawsze mile widziane.
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

Zobacz też te projekty:

### Podziękowania
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Wszystkie nazwy produktów i firm, znaki towarowe, znaki usługowe, zarejestrowane znaki towarowe i zarejestrowane znaki usługowe należą do ich odpowiednich właścicieli. Ich użycie ma charakter wyłącznie informacyjny i nie oznacza żadnego powiązania ani poparcia. Uwaga: ta aplikacja nie jest powiązana z Abbott Diabetes Care Inc. ani przez tę firmę wspierana.
