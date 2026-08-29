---
layout: landing
title: "FLwatch – Glucosio e insulina su iPhone e Apple Watch"
description: "FLwatch porta su iPhone e Apple Watch le letture di glucosio FreeStyle Libre e Dexcom, il monitoraggio dell’insulina, avvisi, widget e attività in tempo reale."
lang: it
permalink: /it/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glucosio e insulina"
---

<div class="notice-note">
<strong>Non usare per prendere decisioni terapeutiche.</strong>
<br>
Le informazioni fornite da FLwatch e dalle sue estensioni non devono essere usate per prendere decisioni terapeutiche o relative al dosaggio dell’insulina. Affidati sempre al tuo sistema di monitoraggio del glucosio e consulta un professionista sanitario per qualsiasi decisione medica.
</div>

FLwatch mostra su iPhone e Apple Watch le letture di glucosio dei sensori Abbott FreeStyle Libre 2, Libre 2+, Libre 3 e Libre 3+, oltre a quelle dei sensori Dexcom G6, G7 e ONE+.

Consente inoltre di registrare le dosi di insulina e visualizza grafici dedicati all’insulina attiva e all’attività dell’insulina, aiutandoti a comprendere meglio l’interazione tra insulina e glucosio.

FLwatch è nato come progetto personale per aiutarmi nella gestione del diabete. L’ho reso pubblico, gratuito e open source nella speranza che possa essere utile anche ad altri.

### In breve

- Grafici del glucosio, dell’insulina attiva e dell’attività dell’insulina su iPhone e Apple Watch
- Connessioni tramite Bluetooth diretto, LibreLinkUp e Dexcom Share
- Avvisi configurabili relativi al glucosio e al sensore
- Widget e complicazioni per schermata Home, schermata di blocco, StandBy e Apple Watch
- Supporto per attività in tempo reale, CarPlay, Siri e Comandi rapidi
- Esportazione in Apple Health e, con una connessione diretta a un sensore FreeStyle Libre 3 o FreeStyle Libre 3+, esportazione in Nightscout
- Richiede iOS 18 e watchOS 10.5

### Sensori e connessioni supportati

| Produttore | Sensori | Connessione |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 e FreeStyle Libre 2+ | LibreLinkUp |
| Abbott | FreeStyle Libre 3 e FreeStyle Libre 3+ | Bluetooth diretto o LibreLinkUp |
| Dexcom | G6, G7 e ONE+ | Dexcom Share |

### Funzionalità {#features}

#### Monitoraggio del glucosio

- Grafico del glucosio su iPhone e Apple Watch
- Grafico interattivo su iPhone — tocca per esaminare le singole letture
- Offset di calibrazione facoltativo per i sensori FreeStyle Libre 3 e FreeStyle Libre 3+ connessi direttamente
- Controllo del glucosio attuale e dell’andamento tramite Siri o Comandi rapidi
- Modalità schermo sempre attivo facoltativa per una consultazione rapida

#### Avvisi

- Avvisi configurabili di glucosio basso e alto su iPhone, Apple Watch e CarPlay
- Avvisi aggiuntivi di glucosio criticamente basso e perdita del segnale per i sensori FreeStyle Libre 3 e FreeStyle Libre 3+ connessi direttamente
- Notifiche relative a riscaldamento, durata residua, scadenza e sostituzione dei sensori FreeStyle Libre 3 e FreeStyle Libre 3+ connessi direttamente
- Avvisi critici facoltativi e intervalli «Non disturbare» separati per ogni tipo di avviso

Gli avvisi di FLwatch vengono inviati secondo disponibilità e non sono garantiti. Potrebbero arrivare in ritardo o non arrivare. Conferma sempre la lettura del glucosio prima di agire.

#### Monitoraggio dell’insulina

- Registrazione delle dosi di insulina su iPhone o tramite Siri e Comandi rapidi su iPhone e Apple Watch
- Calcolatore di base per carboidrati e insulina basato sulla dimensione della porzione e su un rapporto insulina/carboidrati configurabile
- Calcolo e grafico dell’insulina attiva (IOB)
- Grafico dell’attività dell’insulina
- Supporto per insuline in bolo ad azione rapida e ultrarapida

#### Widget, attività in tempo reale e CarPlay

- Widget per la schermata Home, con e senza grafici
- Widget per la schermata di blocco e StandBy
- Attività in tempo reale per consultare rapidamente gli aggiornamenti del glucosio
- App nativa per Apple Watch con numerosi widget e complicazioni per i quadranti
- Grafico del glucosio direttamente su Apple Watch
- Duplicazione delle attività in tempo reale nello Smart Stack a partire da watchOS 11
- Vista CarPlay con glucosio attuale e IOB
- Grafici del glucosio in CarPlay tramite widget e attività in tempo reale

#### Esportazione dei dati

- Esportazione delle letture di glucosio e delle dosi di insulina registrate in Apple Health
- Con una connessione Bluetooth diretta a un sensore FreeStyle Libre 3 o FreeStyle Libre 3+, esportazione delle letture di glucosio e delle dosi di insulina registrate sul proprio server Nightscout

{% include screenshots.html %}

### Avvio rapido {#usage}

1. Installa FLwatch dall’[App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Assicurati che l’app watchOS sia installata sul tuo Apple Watch, preferibilmente prima di avviare l’app per iPhone.
3. Al primo avvio, FLwatch ti chiede di scegliere il tuo CGM: `FreeStyle Libre` tramite LibreLinkUp, `Dexcom` tramite Dexcom Share oppure `FreeStyle Libre 3 (Bluetooth)` per una connessione diretta al sensore.
4. Dopo la selezione, FLwatch apre automaticamente la schermata `Connetti` corrispondente. Segui le istruzioni visualizzate e le indicazioni pertinenti riportate di seguito.
5. Una volta stabilita la connessione, attendi fino a un minuto per la comparsa dei primi dati del glucosio.

Puoi cambiare in seguito il CGM selezionato nelle `Impostazioni`.

Se l’app watchOS è installata, le impostazioni e le credenziali per le connessioni cloud inserite nell’app per iPhone vengono trasferite all’app per Apple Watch. Puoi trasferirle nuovamente in seguito toccando ancora una volta `Connetti`.

### Connessione diretta a FreeStyle Libre 3 e FreeStyle Libre 3+

In una nuova installazione, scegli `FreeStyle Libre 3 (Bluetooth)` nel selettore CGM. FLwatch apre automaticamente la schermata di connessione Bluetooth.

Prima dell’abbinamento:

- Per la maggior parte degli utenti con un sensore già attivato, è consigliata la modalità `Parallela`. In questo modo le credenziali di connessione FreeStyle Libre 3 già presenti nel sensore restano valide ed è più facile tornare in seguito all’app FreeStyle Libre 3.
- Accedi con l’account LibreView usato per attivare il sensore, quindi tocca `Ottieni ID account` in FLwatch. Per l’abbinamento in parallelo, le informazioni dell’account devono corrispondere a quelle dell’account che ha attivato il sensore. Questo account è diverso dall’account follower LibreLinkUp usato per una connessione cloud.
- Solo un’app alla volta deve accedere al sensore. Prima di usare FLwatch, chiudi completamente l’app FreeStyle Libre 3 e disattivane l’accesso Bluetooth nelle impostazioni di iOS. Il passaggio da un’app all’altra può richiedere da due a tre minuti.
- Quando FLwatch ti chiede di eseguire la scansione, tieni la parte superiore dell’iPhone contro il sensore senza muoverlo finché l’abbinamento NFC non è terminato.

La modalità `Nuovo` è riservata esclusivamente a un sensore nuovo e mai utilizzato. Avvia immediatamente il periodo di utilizzo del sensore e non può essere annullata. La maggior parte degli utenti dovrebbe attivare il sensore nell’app FreeStyle Libre 3 e poi abbinarlo a FLwatch in modalità `Parallela`.

Dopo l’abbinamento, tieni l’iPhone vicino al sensore. Le letture di glucosio vengono ricevute direttamente tramite Bluetooth circa una volta al minuto, senza account follower né connessione cloud. Una connessione diretta abilita inoltre l’offset di calibrazione, gli avvisi di glucosio criticamente basso e perdita del segnale, le notifiche sullo stato del sensore e l’esportazione in Nightscout.

Queste funzionalità di connessione diretta non sono disponibili per i sensori FreeStyle Libre 2 e FreeStyle Libre 2+.

### Configurare LibreLinkUp

LibreLinkUp può fornire le letture di glucosio dei sensori FreeStyle Libre 2, FreeStyle Libre 2+, FreeStyle Libre 3 e FreeStyle Libre 3+. Per usarlo con FLwatch, invita te stesso come follower.

*Le credenziali LibreView non funzionano. Usa le credenziali di un account follower LibreLinkUp.*

<div class="notice-note">
<strong>Videoguida alla configurazione di LibreLinkUp</strong>
<br>
@TypeOneCallum ha creato un utilissimo <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">video passo passo per configurare FLwatch</a>. Se stai configurando LibreLinkUp per la prima volta, è un ottimo punto di partenza.
</div>

1. Nell’app FreeStyle LibreLink o FreeStyle Libre 3, vai in Condividi / App connesse.
2. Apri Connetti / Gestisci LibreLinkUp.
3. Tocca `Aggiungi connessione` e inserisci l’indirizzo e-mail che vuoi usare per l’account follower.
4. Accetta l’invito inviato a quell’indirizzo e-mail.
5. Installa l’[app LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sul tuo iPhone e completa la configurazione dell’account follower invitato.
6. Verifica che in LibreLinkUp sia visibile il tuo grafico del glucosio.
7. Apri FLwatch e inserisci le credenziali dell’account follower nella scheda `Connetti`.

L’indirizzo e-mail dell’account follower può essere lo stesso usato per LibreView. Se l’account follower ha più di una connessione, dopo l’accesso scegli la persona di cui FLwatch deve mostrare le letture.

L’app LibreLinkUp può quindi essere chiusa o disinstallata. Potrebbe servirti di nuovo in seguito per accettare termini di utilizzo o informative sulla privacy aggiornati, oppure per verificare che l’account e la connessione funzionino ancora.

La [guida passo passo di LibreLinkUp](https://www.librelinkup.com/articles/getting-started) offre ulteriore assistenza.

<div class="notice-note">
<strong>Compatibilità con l’API LibreLinkUp</strong>
<br>
FLwatch supporta attualmente l’API 4.x di LibreLinkUp. L’API 5.0.0 di LibreLinkUp non è ancora supportata. Se in futuro l’API 4.x verrà disattivata, i dati del glucosio di LibreLinkUp in FLwatch potrebbero smettere di funzionare senza preavviso. Le funzionalità relative all’IOB e gli altri metodi di connessione continueranno a funzionare.
</div>

### Configurare Dexcom Share

I sensori Dexcom G6, Dexcom G7 e Dexcom ONE+ possono fornire letture di glucosio tramite Dexcom Share.

1. Attiva Share nell’app Dexcom. Dexcom richiede almeno un invito a un follower prima di poter attivare Share.
2. In una nuova installazione, scegli `Dexcom` nel selettore CGM. FLwatch apre automaticamente la schermata di connessione Dexcom Share.
3. Accedi con l’indirizzo e-mail e la password dell’account Dexcom usato da chi indossa il sensore — lo stesso account usato nell’app Dexcom sull’iPhone di tale persona — e tocca `Connetti`. FLwatch rileva automaticamente la regione dell’account.

Non usare le credenziali di un follower. Dexcom Share rende disponibili alle app di terze parti solo le letture della persona che indossa il sensore quando viene usato l’account di quest’ultima.

Se l’app per Apple Watch non era installata al momento della connessione, installala e tocca di nuovo `Connetti` per trasferire le credenziali. La connessione Dexcom Share usata da FLwatch non è ufficiale e può essere modificata o limitata senza preavviso.

### Heartbeat Bluetooth per le connessioni cloud

Quando usi LibreLinkUp o Dexcom Share, gli avvisi di FLwatch per glucosio basso e alto richiedono l’heartbeat Bluetooth. Attivalo in `Impostazioni > Heartbeat Bluetooth` e seleziona il trasmettitore del sensore nelle vicinanze. Quando l’heartbeat è disattivato, FLwatch non può inviare questi avvisi con una connessione cloud; continua a usare come avvisi principali quelli del produttore del sensore.

La connessione Bluetooth diretta a FreeStyle Libre 3 e FreeStyle Libre 3+ non usa questa impostazione.

### Funzioni relative all’insulina

Per configurare il calcolo dell’insulina o registrare una dose, tocca l’etichetta `IOB` nella schermata Home.

Tipi di insulina attualmente supportati:

- Insulina ad azione rapida, come Novolog e Novorapid
- Insulina ad azione ultrarapida, come Fiasp e Lyumjev

Il calcolatore integrato usa la dimensione della porzione e un rapporto insulina/carboidrati configurabile. Su richiesta possono essere aggiunti altri tipi di insulina.

### Suggerimenti per Apple Watch, Siri e Comandi rapidi

- Per mantenere il grafico del glucosio visibile su Apple Watch per un’ora, apri le impostazioni sull’orologio o l’app `Watch` su iPhone. Vai in `Generali > Torna all’orologio`, scegli FLwatch e seleziona `Dopo 1 ora`.
- Posiziona un widget o una complicazione sulla schermata Home, sulla schermata di blocco o sul quadrante per accedere rapidamente a FLwatch.
- Le attività in tempo reale di iPhone possono essere duplicate nello Smart Stack di Apple Watch a partire da watchOS 11.
- Siri e Comandi rapidi possono mostrare o leggere ad alta voce il glucosio attuale e registrare dosi di insulina.
- Per accedere a mani libere, crea un comando rapido che apra FLwatch, assegnagli un nome come `grafico del glucosio` e abilita `Mostra su Apple Watch` se lo desideri.

### Note tecniche

FLwatch usa il modello esponenziale dell’insulina di LoopKit. Il modello utilizza tre parametri: `actionDuration`, `peakActivityTime` e `delay`.

- Per l’insulina ad azione rapida, i parametri sono 360, 75 e 10 minuti.
- Per l’insulina ad azione ultrarapida, i parametri sono 360, 55 e 10 minuti.

### Stato del progetto

FLwatch è un progetto open source sperimentale. Usalo con cautela. Viene fornito senza alcuna garanzia e l’utilizzo è a tuo rischio.

FLwatch è disponibile anche per il beta testing su [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Supporto e feedback {#support}

Per ricevere supporto, apri una [issue su GitHub](https://github.com/poml88/FLwatch/issues), avvia una [discussione su GitHub](https://github.com/poml88/FLwatch/discussions) oppure invia un’e-mail a **flwatch [at] cmdline [dot] net**.

I feedback sono molto graditi e possono essere inviati tramite gli stessi canali.

### Donazioni

Le donazioni sono sempre molto gradite.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="Logo PayPal" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Logo Buy Me a Coffee" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Crediti

Dai un’occhiata anche a questi progetti:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tutti i nomi dei prodotti, i marchi commerciali e i marchi registrati appartengono ai rispettivi proprietari. Il loro uso in questa pagina serve unicamente a identificarli e non implica alcuna affiliazione o approvazione da parte dei titolari dei marchi.

FLwatch non è affiliato ad Abbott Diabetes Care Inc. né a Dexcom, Inc. e non è approvato da nessuna delle due società.
