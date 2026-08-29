---
layout: landing
title: "FLwatch – Glucose et insuline sur iPhone et Apple Watch"
description: "FLwatch affiche les mesures de glucose des capteurs FreeStyle Libre et Dexcom et propose le suivi de l’insuline, des alertes, des widgets et des activités en direct sur iPhone et Apple Watch."
lang: fr
permalink: /fr/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glucose et insuline"
---

<div class="notice-note">
<strong>Ne pas utiliser pour prendre des décisions thérapeutiques.</strong>
<br>
Les informations fournies par FLwatch et ses extensions ne doivent pas être utilisées pour prendre des décisions thérapeutiques ou concernant les doses d’insuline. Fiez-vous toujours à votre système de mesure du glucose et consultez un professionnel de santé pour toute décision médicale.
</div>

FLwatch affiche sur votre iPhone et votre Apple Watch les mesures de glucose des capteurs Abbott FreeStyle Libre 2, Libre 2+, Libre 3 et Libre 3+, ainsi que des capteurs Dexcom G6, G7 et ONE+.

L’application vous permet également d’enregistrer vos doses d’insuline. Des graphiques dédiés à l’insuline active et à l’activité de l’insuline vous aident à mieux comprendre l’interaction entre l’insuline et le glucose.

FLwatch est né d’un projet personnel destiné à m’aider dans la gestion de mon propre diabète. Je l’ai rendu public, gratuit et open source dans l’espoir qu’il puisse également être utile à d’autres personnes.

### En bref

- Graphiques de glucose, d’insuline active et d’activité de l’insuline sur iPhone et Apple Watch
- Connexions possibles par Bluetooth direct, LibreLinkUp et Dexcom Share
- Alertes de glycémie et de capteur configurables
- Widgets et complications pour l’écran d’accueil, l’écran verrouillé, le mode En veille et l’Apple Watch
- Prise en charge des activités en direct, de CarPlay, de Siri et de Raccourcis
- Exportation vers Apple Health, ainsi que vers Nightscout avec une connexion directe à un capteur FreeStyle Libre 3 ou FreeStyle Libre 3+
- Nécessite iOS 18 et watchOS 10.5

### Capteurs et connexions pris en charge

| Fabricant | Capteurs | Connexion |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 et FreeStyle Libre 2+ | LibreLinkUp |
| Abbott | FreeStyle Libre 3 et FreeStyle Libre 3+ | Bluetooth direct ou LibreLinkUp |
| Dexcom | G6, G7 et ONE+ | Dexcom Share |

### Fonctionnalités {#features}

#### Suivi du glucose

- Courbe de glycémie sur iPhone et Apple Watch
- Graphique interactif sur iPhone — touchez une mesure pour l’examiner individuellement
- Décalage d’étalonnage facultatif pour les capteurs FreeStyle Libre 3 et FreeStyle Libre 3+ connectés directement
- Consultation du glucose actuel et de sa tendance avec Siri ou Raccourcis
- Mode d’affichage permanent facultatif pour une consultation rapide

#### Alertes

- Alertes configurables de glycémie basse et élevée sur iPhone, Apple Watch et CarPlay
- Alertes supplémentaires de glycémie très basse et de perte du signal pour les capteurs FreeStyle Libre 3 et FreeStyle Libre 3+ connectés directement
- Notifications concernant le démarrage, l’autonomie restante, l’expiration et le remplacement des capteurs FreeStyle Libre 3 et FreeStyle Libre 3+ connectés directement
- Alertes critiques facultatives et plages « Ne pas déranger » distinctes pour chaque type d’alerte

Les alertes FLwatch sont envoyées dans la mesure du possible et ne sont pas garanties. Elles peuvent être retardées ou manquées. Confirmez toujours votre glycémie avant d’agir.

#### Suivi de l’insuline

- Enregistrement des doses d’insuline sur l’iPhone, ou avec Siri et Raccourcis sur l’iPhone et l’Apple Watch
- Calculateur simple de glucides et d’insuline fondé sur la taille de la portion et un rapport insuline/glucides configurable
- Calcul et graphique de l’insuline active (IOB)
- Graphique de l’activité de l’insuline
- Prise en charge des insulines bolus à action rapide et à action ultra-rapide

#### Widgets, activités en direct et CarPlay

- Widgets d’écran d’accueil, avec ou sans graphique
- Widgets pour l’écran verrouillé et le mode En veille
- Activités en direct pour consulter rapidement les nouvelles mesures de glucose
- Application Apple Watch native avec de nombreux widgets et complications de cadran
- Courbe de glycémie directement sur l’Apple Watch
- Recopie des activités en direct dans la Smart Stack à partir de watchOS 11
- Vue CarPlay affichant le glucose actuel et l’IOB
- Courbes de glycémie dans CarPlay grâce aux widgets et aux activités en direct

#### Exportation des données

- Exportation des mesures de glucose et des doses d’insuline enregistrées vers Apple Health
- Avec une connexion Bluetooth directe à un capteur FreeStyle Libre 3 ou FreeStyle Libre 3+, exportation des mesures de glucose et des doses d’insuline enregistrées vers votre propre serveur Nightscout

{% include screenshots.html %}

### Démarrage rapide {#usage}

1. Installez FLwatch depuis l’[App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Assurez-vous que l’application watchOS est installée sur votre Apple Watch, idéalement avant de lancer l’application iPhone.
3. Au premier lancement, FLwatch vous demande de choisir votre CGM : `FreeStyle Libre` via LibreLinkUp, `Dexcom` via Dexcom Share ou `FreeStyle Libre 3 (Bluetooth)` pour une connexion directe au capteur.
4. Une fois votre choix effectué, FLwatch ouvre automatiquement l’écran `Se connecter` correspondant. Suivez les instructions qui y sont affichées ainsi que les remarques pertinentes ci-dessous.
5. Une fois la connexion établie, attendez jusqu’à une minute pour que les premières données de glucose apparaissent.

Vous pourrez modifier ultérieurement le CGM sélectionné dans les `Paramètres`.

Si l’application watchOS est installée, les réglages et les identifiants de connexion au cloud saisis dans l’application iPhone sont transférés vers l’application Apple Watch. Vous pouvez les transférer à nouveau ultérieurement en appuyant une nouvelle fois sur `Se connecter`.

### Connexion directe aux capteurs FreeStyle Libre 3 et FreeStyle Libre 3+

Lors d’une nouvelle installation, choisissez `FreeStyle Libre 3 (Bluetooth)` dans le sélecteur de CGM. FLwatch ouvre alors automatiquement l’écran de connexion Bluetooth.

Avant le jumelage :

- Pour la plupart des utilisateurs dont le capteur est déjà activé, le mode `Parallèle` est recommandé. Les identifiants de connexion FreeStyle Libre 3 déjà enregistrés dans le capteur restent ainsi valides, ce qui facilite le retour ultérieur à l’application FreeStyle Libre 3.
- Connectez-vous avec le compte LibreView utilisé pour activer le capteur, puis touchez `Obtenir l’identifiant du compte` dans FLwatch. Pour le jumelage parallèle, les informations du compte doivent correspondre à celles du compte ayant servi à activer le capteur. Ce compte est différent du compte suiveur LibreLinkUp utilisé pour une connexion au cloud.
- Une seule application doit accéder au capteur à la fois. Avant d’utiliser FLwatch, fermez complètement l’application FreeStyle Libre 3 et désactivez son accès au Bluetooth dans les réglages iOS. Le passage d’une application à l’autre peut prendre deux à trois minutes.
- Lorsque FLwatch vous demande d’effectuer un scan, placez le haut de votre iPhone contre le capteur et maintenez-le immobile jusqu’à la fin du jumelage NFC.

Le mode `Neuf` est exclusivement réservé à un capteur neuf et jamais utilisé. Il démarre immédiatement la durée de port du capteur et cette opération est irréversible. La plupart des utilisateurs doivent activer le capteur dans l’application FreeStyle Libre 3, puis le jumeler avec FLwatch en mode `Parallèle`.

Une fois le jumelage terminé, gardez votre iPhone à proximité du capteur. Les mesures de glucose sont reçues directement par Bluetooth environ une fois par minute, sans compte suiveur ni connexion au cloud. Une connexion directe permet également d’utiliser le décalage d’étalonnage, les alertes de glycémie très basse et de perte du signal, les notifications d’état du capteur et l’exportation vers Nightscout.

Ces fonctionnalités de connexion directe ne sont pas disponibles avec les capteurs FreeStyle Libre 2 et FreeStyle Libre 2+.

### Configurer LibreLinkUp

LibreLinkUp peut fournir les mesures de glucose des capteurs FreeStyle Libre 2, FreeStyle Libre 2+, FreeStyle Libre 3 et FreeStyle Libre 3+. Pour l’utiliser avec FLwatch, invitez-vous vous-même comme suiveur.

*Les identifiants LibreView ne fonctionnent pas. Utilisez ceux d’un compte suiveur LibreLinkUp.*

<div class="notice-note">
<strong>Guide vidéo de configuration de LibreLinkUp</strong>
<br>
@TypeOneCallum a créé une <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">vidéo détaillée de configuration de FLwatch</a> très utile. Si vous configurez LibreLinkUp pour la première fois, c’est un excellent point de départ.
</div>

1. Dans l’application FreeStyle LibreLink ou FreeStyle Libre 3, accédez à Partager / Applications connectées.
2. Ouvrez Se connecter / Gérer LibreLinkUp.
3. Touchez `Ajouter une connexion` et saisissez l’adresse e-mail que vous souhaitez utiliser pour le compte suiveur.
4. Acceptez l’invitation envoyée à cette adresse e-mail.
5. Installez l’application [LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sur votre iPhone et terminez la configuration du compte suiveur invité.
6. Vérifiez que votre propre courbe de glycémie est visible dans LibreLinkUp.
7. Ouvrez FLwatch et saisissez les identifiants du compte suiveur dans l’onglet `Se connecter`.

L’adresse e-mail du compte suiveur peut être la même que celle utilisée pour LibreView. Si le compte suiveur comporte plusieurs connexions, sélectionnez après la connexion la personne dont FLwatch doit afficher les mesures.

L’application LibreLinkUp peut ensuite être fermée ou désinstallée. Vous pourrez toutefois en avoir à nouveau besoin pour accepter des conditions d’utilisation ou des politiques de confidentialité mises à jour, ou pour vérifier que le compte et la connexion fonctionnent toujours.

Le [guide pas à pas de LibreLinkUp](https://www.librelinkup.com/articles/getting-started) fournit une aide supplémentaire.

<div class="notice-note">
<strong>Compatibilité avec l’API LibreLinkUp</strong>
<br>
FLwatch prend actuellement en charge l’API 4.x de LibreLinkUp. L’API 5.0.0 de LibreLinkUp n’est pas encore prise en charge. Si l’API 4.x est désactivée à l’avenir, les données de glucose LibreLinkUp dans FLwatch pourraient cesser de fonctionner sans préavis. Les fonctionnalités liées à l’IOB et les autres modes de connexion continueront de fonctionner.
</div>

### Configurer Dexcom Share

Les capteurs Dexcom G6, Dexcom G7 et Dexcom ONE+ peuvent fournir des mesures de glucose par l’intermédiaire de Dexcom Share.

1. Activez Share dans l’application Dexcom. Dexcom exige qu’au moins un suiveur soit invité avant de pouvoir activer Share.
2. Lors d’une nouvelle installation, choisissez `Dexcom` dans le sélecteur de CGM. FLwatch ouvre automatiquement l’écran de connexion Dexcom Share.
3. Connectez-vous avec l’adresse e-mail et le mot de passe du compte Dexcom utilisé par le porteur du capteur — le même compte que celui utilisé dans l’application Dexcom sur l’iPhone du porteur — puis appuyez sur `Se connecter`. FLwatch détecte automatiquement la région du compte.

N’utilisez pas les identifiants d’un suiveur. Dexcom Share ne transmet aux applications tierces que les propres mesures du porteur lorsque le compte de celui-ci est utilisé.

Si l’application Apple Watch n’était pas installée lors de la connexion, installez-la et appuyez à nouveau sur `Se connecter` pour transférer les identifiants. La connexion Dexcom Share utilisée par FLwatch n’est pas officielle et peut être modifiée ou restreinte sans préavis.

### Heartbeat Bluetooth pour les connexions au cloud

Avec LibreLinkUp ou Dexcom Share, les alertes FLwatch de glycémie basse et élevée nécessitent le heartbeat Bluetooth. Activez-le sous `Paramètres > Heartbeat Bluetooth` et sélectionnez le transmetteur de capteur situé à proximité. FLwatch ne peut pas envoyer ces alertes avec une connexion au cloud lorsque le heartbeat est désactivé ; continuez à utiliser les alertes du fabricant du capteur comme alertes principales.

La connexion Bluetooth directe aux capteurs FreeStyle Libre 3 et FreeStyle Libre 3+ n’utilise pas ce réglage.

### Fonctions liées à l’insuline

Pour configurer le calcul de l’insuline ou enregistrer une dose, touchez l’étiquette `IOB` sur l’écran d’accueil.

Types d’insuline actuellement pris en charge :

- Insuline à action rapide, comme Novolog et Novorapid
- Insuline à action ultra-rapide, comme Fiasp et Lyumjev

Le calculateur intégré utilise la taille de la portion et un rapport insuline/glucides configurable. D’autres types d’insuline peuvent être ajoutés sur demande.

### Conseils pour l’Apple Watch, Siri et Raccourcis

- Pour garder la courbe de glycémie visible sur l’Apple Watch pendant une heure, ouvrez les réglages de la montre ou l’application `Watch` sur l’iPhone. Accédez à `Général > Retour à l’horloge`, choisissez FLwatch, puis `Après 1 heure`.
- Placez un widget ou une complication sur l’écran d’accueil, l’écran verrouillé ou le cadran pour accéder rapidement à FLwatch.
- Les activités en direct de l’iPhone peuvent être recopiées dans la Smart Stack de l’Apple Watch à partir de watchOS 11.
- Siri et Raccourcis peuvent afficher ou lire votre glycémie actuelle et enregistrer des doses d’insuline.
- Pour un accès mains libres, créez un raccourci qui ouvre FLwatch, attribuez-lui un nom tel que `courbe de glycémie` et activez `Afficher sur Apple Watch` si vous le souhaitez.

### Notes techniques

FLwatch utilise le modèle exponentiel d’insuline de LoopKit. Ce modèle utilise trois paramètres : `actionDuration`, `peakActivityTime` et `delay`.

- Pour l’insuline à action rapide, les paramètres sont 360, 75 et 10 minutes.
- Pour l’insuline à action ultra-rapide, les paramètres sont 360, 55 et 10 minutes.

### État du projet

FLwatch est un projet open source expérimental. Utilisez-le avec prudence. Il est fourni sans garantie et son utilisation se fait à vos propres risques.

FLwatch est également disponible pour les tests bêta sur [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Assistance et commentaires {#support}

Pour obtenir de l’aide, veuillez ouvrir une [issue GitHub](https://github.com/poml88/FLwatch/issues), lancer une [discussion GitHub](https://github.com/poml88/FLwatch/discussions) ou envoyer un e-mail à **flwatch [at] cmdline [dot] net**.

Vos commentaires sont les bienvenus et peuvent être envoyés par les mêmes canaux.

### Dons

Les dons sont toujours les bienvenus.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="Logo PayPal" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Logo Buy Me a Coffee" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Crédits

N’hésitez pas à consulter également ces projets :

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tous les noms de produits, marques commerciales et marques déposées appartiennent à leurs propriétaires respectifs. Leur utilisation ici sert uniquement à les identifier et n’implique aucune affiliation avec les détenteurs des marques ni aucune approbation de leur part.

FLwatch n’est affilié ni à Abbott Diabetes Care Inc. ni à Dexcom, Inc. et n’est approuvé par aucune de ces sociétés.
