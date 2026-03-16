---
layout: landing
title: "FLwatch – Grafici di glucosio e insulina per iPhone e Apple Watch"
description: "FLwatch è un’app gratuita e open source che mostra grafici di glucosio, insulina attiva (insulin-on-board) e attività con widget su iPhone e Apple Watch utilizzando i dati di LibreLinkUp."
lang: it
permalink: /it/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Grafico del sensore di glucosio"
---
 

***Attenzione, questo progetto è altamente sperimentale! Si prega di utilizzare questa app con cautela ed estrema attenzione. Non prendere decisioni avventate basandoti sul software. Non utilizzare questo software se non sei sicuro. Non utilizzare questa app per decisioni mediche. Non è fornita alcuna garanzia. Utilizzala a tuo rischio e pericolo!***

Questo software è gratuito e open source. È stato sviluppato per esigenze personali, ma tutti dovrebbero poterne beneficiare.

### Utilizzo {#usage}
***Installazione:*** Assicurarsi che l'app watchOS sia installata, idealmente prima di avviare l'app iOS. A seconda della configurazione, l'app watchOS viene installata automaticamente o deve essere installata tramite l'app “Watch” sul telefono.
- @TypeOneCallum ha realizzato un ottimo [video tutorial di configurazione](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) (Grazie!). Guardandolo, la configurazione sarà molto più semplice.
- L'app richiede iOS 18 e watchOS 10.5
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Le impostazioni vengono effettuate nell'app iOS e poi trasferite all'app watchOS. Questo funziona solo se l'app watchOS è installata sull'orologio.
- ***Stabilire la connessione tra le app:*** Per far funzionare il tutto, devi prima invitarti a diventare tuo follower. *Le credenziali LibreView non funzionano.* Per farlo, nell'app LibreLink / Libre 3, in Condividi / App connesse, è presente la voce Connetti / Gestisci LibreLinkUp. Tocca “Aggiungi connessione” e inserisci l'indirizzo e-mail che desideri utilizzare per l'account follower; un invito verrà inviato a quell'indirizzo (l'indirizzo e-mail può essere lo stesso di LibreView). Quindi, per configurare l'account follower LibreLinkUp, installa l'[app LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sul telefono e segui le istruzioni utilizzando l'indirizzo e-mail che hai appena invitato. È disponibile una [guida passo passo](https://www.librelinkup.com/articles/getting-started) che potrebbe esserti utile. Assicurati di poter visualizzare il tuo grafico della glicemia nell'app LibreLinkUp. Infine, apri FLwatch e inserisci le credenziali dell'account follower, come indicato di seguito. Attualmente FLwatch supporta un solo paziente seguito per ogni account follower.
- L'app LibreLinkUp può quindi essere chiusa o disinstallata, ma potrebbe essere necessaria in seguito per accettare i nuovi Termini di utilizzo, le Informative sulla privacy o semplicemente per verificare che l'account/la connessione funzioni.
- Per connetterti al tuo account follower LibreLinkUp, inserisci le tue credenziali in FLwatch nella scheda “Connetti”. Se l'app watchOS è installata, le credenziali vengono trasferite all'app dell'orologio. È possibile ritrasferire le credenziali premendo nuovamente il pulsante “Connetti”.
- Il recupero e la visualizzazione dei dati possono richiedere fino a un minuto.
- Per utilizzare il calcolo dell'insulina, toccare l'etichetta IOB nella schermata iniziale. I tipi di insulina attualmente supportati sono: ad azione rapida (Novolog, Novorapid, ...) e ad azione ultra rapida (Fiasp, Lyumjev, ...). Su richiesta è possibile aggiungere altri tipi di insulina. *Fammi sapere.*
  - L'app utilizza il modello esponenziale di LoopKit. Il modello prevede tre parametri: actionDuration, peakActivityTime e delay. Per l'insulina ad azione rapida i parametri sono 360, 75 e 10 minuti, per l'insulina ad azione ultra rapida i parametri sono 360, 55 e 10 minuti.
- È possibile impostare la visualizzazione del grafico del glucosio per un'ora sull'orologio: sull'orologio o nell'app “Watch” del telefono, andare su Impostazioni — Generali — Torna all'orologio, scorrere verso il basso e toccare FLwatch, quindi selezionare “Dopo 1 ora”. In questo modo, FLwatch rimane in primo piano per 1 ora e riceve un numero ragionevole di aggiornamenti (ad esempio ogni minuto).
- Il modo più semplice per avviare l'app sul telefono o sull'orologio è posizionare un widget/complicazione sulla schermata iniziale, sulla schermata di blocco, sul quadrante dell'orologio o in qualsiasi altro punto e toccarlo.
- Per utilizzare Siri per aprire l'app in modalità vivavoce, puoi creare un collegamento sul telefono chiamato, ad esempio, “grafico del glucosio” o ‘glicemia’. Questo collegamento apre semplicemente FLwatch. Seleziona l'opzione di collegamento “mostra sull'orologio”. Ora, se attivi Siri, basta dire “grafico del glucosio” e, voilà, viene visualizzata l'app FLwatch e il suo grafico.
Lo stesso funziona sul telefono.

### Caratteristiche {#features}
* grafico della glicemia sul telefono e sull'orologio
* grafico interattivo sul telefono per visualizzare i valori individuali con un tocco
* modalità schermo del telefono sempre acceso
* supporta insuline ad azione rapida e ad azione rapida veloce
* calcolo dell'insulina a bordo (IOB)
* grafico dell'insulina a bordo
* grafico dell'attività dell'insulina
* widget iOS e widget della schermata di blocco con e senza grafico/i
* Live Activities
* widget in modalità standby
* widget watchOS / complicazioni
* supporto CarPlay tramite widget e Live Activities
* esportazione delle dosi di insulina e dei dati del glucosio in Apple Health

### Da fare
- Implementare l'attività di allenamento

### Assistenza e feedback {#support}
Per assistenza, apri una segnalazione, avvia una discussione o invia un'e-mail a **flwatch [ a t ] cmdline [ d o t ] net**. I feedback sono molto graditi, utilizza gli stessi metodi utilizzati per l'assistenza.

### Donazioni... 
...sono sempre molto gradite! 
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

Dai un'occhiata anche a questi progetti:

### Crediti: 
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tutti i nomi di prodotti e aziende, marchi commerciali, marchi di servizio, marchi registrati e marchi di servizio registrati sono di proprietà dei rispettivi titolari. Il loro utilizzo ha scopo puramente informativo e non implica alcuna affiliazione o approvazione da parte loro. Nota: questa app non ha alcun legame con Abbott Diabetes Care Inc. e non è da essa approvata.
