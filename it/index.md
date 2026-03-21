---
layout: landing
title: "FLwatch – Grafici di glucosio e insulina per iPhone e Apple Watch"
description: "FLwatch è un’app gratuita e open source che mostra grafici di glucosio, insulina attiva (insulin-on-board) e attività con widget su iPhone e Apple Watch utilizzando i dati di LibreLinkUp."
lang: it
permalink: /it/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Grafico del sensore di glucosio"
---

***Attenzione: FLwatch è un progetto altamente sperimentale. Usa questa app con cautela e con la massima attenzione. Non prendere decisioni mediche basandoti su questo software. Viene fornito senza alcuna garanzia ed è usato a tuo rischio.***

Questo software è gratuito e open source. È nato da esigenze personali, ma dovrebbe poter essere utile a tutti.

### In breve
- Mostra grafici di glucosio, insulina attiva e attività su iPhone e Apple Watch
- Include widget, complicazioni, Live Activities, mirroring nello Smart Stack di Apple Watch ed esportazione in Apple Health
- Supporta la registrazione manuale dell’insulina e un calcolatore integrato carboidrati-insulina
- Richiede iOS 18 e watchOS 10.5
- Per il beta testing, FLwatch è disponibile anche su TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Utilizza le credenziali di un account follower LibreLinkUp, non le credenziali LibreView

### Avvio rapido {#usage}
1. Installa FLwatch dall’[App Store]({{ site.appstore_url }}).

   {% include appstore_badge.html %}
2. Assicurati che l’app watchOS sia installata sul tuo Apple Watch, idealmente prima di aprire l’app iOS.
3. Crea e verifica una connessione LibreLinkUp in cui tu sei il tuo stesso follower.
4. Inserisci in FLwatch le credenziali dell’account follower LibreLinkUp nella scheda `Connect`.
5. Attendi fino a un minuto perché i dati compaiano.

Se l’app watchOS è installata, le impostazioni e le credenziali inserite nell’app iOS vengono trasferite all’app dell’orologio.

- @TypeOneCallum ha realizzato un utilissimo [video tutorial di configurazione](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB). Guardarlo può rendere l’impostazione molto più semplice.

### Configurare LibreLinkUp
Per far funzionare FLwatch, devi prima invitare te stesso per diventare il tuo stesso follower.

*Le credenziali LibreView non funzionano.*

1. Nell’app LibreLink o Libre 3, vai in Share / Connected Apps.
2. Apri Connect / Manage LibreLinkUp.
3. Tocca `Add Connection` e inserisci l’indirizzo e-mail che vuoi usare per l’account follower.
4. Accetta l’invito inviato a quell’indirizzo e-mail.
5. Installa l’[app LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sul tuo iPhone e completa lì la configurazione dell’account follower invitato.
6. Verifica di poter vedere il tuo grafico della glicemia in LibreLinkUp.
7. Apri FLwatch e inserisci lì le credenziali dell’account follower.

L’indirizzo e-mail dell’account follower può essere lo stesso usato per LibreView.

Può essere utile anche la [guida passo passo di LibreLinkUp](https://www.librelinkup.com/articles/getting-started).

Al momento FLwatch supporta un solo paziente seguito per ogni account follower.

L’app LibreLinkUp può poi essere chiusa o persino disinstallata. Potrebbe però servire di nuovo in futuro per accettare nuovi Termini di utilizzo o nuove Informative sulla privacy, oppure semplicemente per verificare che l’account e la connessione continuino a funzionare.

### Collegare FLwatch
- Inserisci le credenziali del tuo account follower LibreLinkUp nella scheda `Connect` di FLwatch.
- Se l’app watchOS è installata, le credenziali vengono trasferite all’app dell’orologio.
- Se necessario, puoi trasferire di nuovo le credenziali premendo ancora una volta il pulsante `Connect`.
- Il recupero e la visualizzazione dei dati possono richiedere fino a un minuto.

### Funzioni relative all’insulina
Per usare il calcolo dell’insulina, tocca l’etichetta `IOB` nella schermata principale.

Tipi di insulina attualmente supportati:
- Insulina ad azione rapida, come Novolog e Novorapid
- Insulina ad azione ultra-rapida, come Fiasp e Lyumjev

FLwatch supporta anche la registrazione manuale dell’insulina e include un calcolatore integrato carboidrati-insulina.

Su richiesta possono essere aggiunti altri tipi di insulina.

### Suggerimenti per Apple Watch e Siri
- Per mantenere il grafico del glucosio visibile sull’orologio per un’ora, apri sull’orologio o nell’app `Watch` dell’iPhone il percorso `Impostazioni > Generali > Torna all’orologio`, scorri fino a FLwatch e scegli `Dopo 1 ora`. In questo modo FLwatch resta più a lungo in primo piano e riceve un numero ragionevole di aggiornamenti, ad esempio circa una volta al minuto.
- Il modo più semplice per avviare l’app sul telefono o sull’orologio è posizionare un widget o una complicazione sulla schermata Home, sulla schermata di blocco, sul quadrante o in un altro punto comodo e toccarlo.
- Le Live Activities su iPhone possono essere riportate anche nello Smart Stack di Apple Watch per un accesso rapido.
- Siri e Comandi rapidi possono essere usati per leggere ad alta voce o mostrare il valore attuale del glucosio.
- Siri e Comandi rapidi possono essere usati anche per la registrazione vocale delle dosi di insulina o per registrare rapidamente una dose di insulina sull’orologio.
- Per aprire l’app a mani libere con Siri, puoi creare sull’iPhone un comando rapido che apra semplicemente FLwatch. Per esempio, potresti chiamarlo `grafico del glucosio` oppure `glicemia`. Attiva l’opzione per mostrare il comando rapido anche sull’orologio. In questo modo, pronunciando quella frase a Siri, FLwatch si aprirà direttamente. Lo stesso funziona anche sull’iPhone.

### Funzionalità {#features}
#### Monitoraggio
* Grafico del glucosio su telefono e orologio
* Grafico interattivo sul telefono per mostrare i singoli valori con un tocco
* Modalità schermo sempre acceso sul telefono

#### Insulina
* Supporta insuline bolus ad azione rapida e ad azione ultra-rapida
* Calcolo dell’insulina attiva (IOB)
* Grafico dell’insulina attiva
* Grafico dell’attività dell’insulina
* Registrazione manuale dell’insulina
* Calcolatore integrato carboidrati-insulina

#### Integrazione di sistema
* Widget iOS e widget della schermata di blocco con e senza grafico/i
* Live Activities su iPhone, incluso il mirroring nello Smart Stack di Apple Watch
* Widget per la modalità StandBy
* Widget e complicazioni watchOS
* Supporto a CarPlay tramite widget e Live Activities
* Esportazione delle dosi di insulina e dei dati del glucosio in Apple Health
* Supporto per Siri e Comandi rapidi per mostrare il glucosio, leggerlo ad alta voce e registrare rapidamente dosi di insulina

### Note tecniche
FLwatch usa il modello esponenziale dell’insulina di LoopKit. Il modello usa tre parametri: `actionDuration`, `peakActivityTime` e `delay`.

- Per l’insulina ad azione rapida, i parametri sono 360, 75 e 10 minuti.
- Per l’insulina ad azione ultra-rapida, i parametri sono 360, 55 e 10 minuti.

### Da fare
- Implementare l’attività di allenamento

### Supporto e feedback {#support}
Per ricevere supporto, apri una [issue su GitHub](https://github.com/poml88/FLwatch/issues), avvia una [discussione su GitHub](https://github.com/poml88/FLwatch/discussions) oppure invia un’e-mail a **flwatch [at] cmdline [dot] net**.

I feedback sono molto benvenuti e possono essere inviati tramite gli stessi canali.

### Donazioni
Le donazioni sono sempre molto gradite.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Crediti
Dai anche un’occhiata a questi progetti:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tutti i nomi di prodotti e aziende, marchi commerciali, marchi di servizio, marchi registrati e marchi di servizio registrati sono di proprietà dei rispettivi titolari. Il loro utilizzo ha esclusivamente scopo informativo e non implica alcuna affiliazione né approvazione da parte loro. Nota: questa app non ha alcun collegamento con Abbott Diabetes Care Inc. e non è approvata da tale azienda.
