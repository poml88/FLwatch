---
layout: landing
title: "FLwatch – Graphiques de glucose et d’insuline pour iPhone et Apple Watch"
description: "FLwatch est une application open source gratuite affichant des graphiques de glucose, d’insuline active (insulin-on-board) et d’activité avec des widgets sur iPhone et Apple Watch à partir des données LibreLinkUp."
lang: fr
permalink: /fr/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch: Graphique glycémie"
---

***Attention : FLwatch est un projet hautement expérimental. Utilisez cette application avec prudence et une extrême précaution. Ne prenez pas de décisions médicales sur la base de ce logiciel. Il est fourni sans aucune garantie et s’utilise à vos propres risques.***

<div class="notice-note">
<strong>Note importante</strong>
<br>
FLwatch prend actuellement en charge l’API 4.x de LibreLinkUp. Abbott a publié l’API 5.0.0, qui n’est pas encore prise en charge.
<br>
Si Abbott désactive l’API 4.x à l’avenir, les données de glucose dans FLwatch pourraient cesser de fonctionner sans avertissement. Les fonctions liées à l’IOB continueront de fonctionner.
</div>

Ce logiciel est gratuit et open source. Il est développé pour répondre à des besoins personnels, mais tout le monde devrait pouvoir en bénéficier.

### En bref
- Affiche des graphiques de glucose, d’insuline active et d’activité sur iPhone et Apple Watch
- Inclut des widgets, des complications, les Live Activities, la recopie dans la pile intelligente de l’Apple Watch et l’export vers Apple Health
- Prend en charge la saisie manuelle des doses d’insuline et un calculateur intégré glucides-vers-insuline
- Nécessite iOS 18 et watchOS 10.5
- Pour les tests bêta, FLwatch est aussi disponible sur TestFlight : [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Prend en charge les capteurs Freestyle Libre 2 et 3 via LibreLinkUp (uniquement la version 4.x de l’API) — utilise les identifiants d’un compte suiveur LibreLinkUp, et non les identifiants LibreView
- Prend en charge les capteurs Dexcom G6, G7 et ONE+ via Dexcom Share — connectez-vous avec l’e-mail et le mot de passe du compte Dexcom sur lequel le capteur est configuré (les mêmes identifiants que l’application Dexcom sur le téléphone du porteur). « Share » doit être activé dans l’application Dexcom, ce qui nécessite d’inviter au moins un suiveur. Ne vous connectez pas avec un compte de suiveur — Dexcom n’expose que les valeurs du porteur aux applications tierces.

### Démarrage rapide {#usage}
1. Installez FLwatch depuis l’[App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Assurez-vous que l’application watchOS est installée sur votre Apple Watch, idéalement avant de lancer l’application iOS.
3. Créez et vérifiez une connexion LibreLinkUp où vous êtes votre propre suiveur.
4. Saisissez dans FLwatch les identifiants du compte suiveur LibreLinkUp dans l’onglet `Connect`.
5. Attendez jusqu’à une minute pour que les données s’affichent.

Si l’application watchOS est installée, les réglages et les identifiants saisis dans l’application iOS sont transférés vers l’application de la montre.

- @TypeOneCallum a réalisé une très utile [vidéo tutorielle d’installation](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB). La regarder peut rendre la configuration beaucoup plus simple.

### Configurer LibreLinkUp
Pour que FLwatch fonctionne, vous devez d’abord vous inviter vous-même pour devenir votre propre suiveur.

*Les identifiants LibreView ne fonctionnent pas.*

1. Dans l’application LibreLink ou Libre 3, allez dans Share / Connected Apps.
2. Ouvrez Connect / Manage LibreLinkUp.
3. Appuyez sur `Add Connection` et saisissez l’adresse e-mail que vous souhaitez utiliser pour le compte suiveur.
4. Acceptez l’invitation envoyée à cette adresse e-mail.
5. Installez l’application [LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sur votre iPhone et terminez la configuration de ce compte suiveur invité.
6. Vérifiez que vous pouvez voir votre propre courbe de glycémie dans LibreLinkUp.
7. Ouvrez FLwatch et saisissez-y les identifiants du compte suiveur.

L’adresse e-mail du compte suiveur peut être la même que celle utilisée pour LibreView.

Vous pouvez aussi consulter le [guide pas à pas de LibreLinkUp](https://www.librelinkup.com/articles/getting-started), qui peut s’avérer utile.

FLwatch ne prend actuellement en charge qu’un seul patient suivi par compte suiveur.

L’application LibreLinkUp peut ensuite être fermée ou même désinstallée. Il est toutefois possible qu’elle soit à nouveau nécessaire plus tard pour accepter de nouvelles conditions d’utilisation, de nouvelles politiques de confidentialité, ou simplement pour vérifier que le compte et la connexion fonctionnent toujours.

### Connecter FLwatch
- Saisissez les identifiants de votre compte suiveur LibreLinkUp dans l’onglet `Connect` de FLwatch.
- Si l’application watchOS est installée, les identifiants sont transférés vers l’application de la montre.
- Si nécessaire, vous pouvez transférer à nouveau les identifiants en appuyant encore une fois sur le bouton `Connect`.
- Le chargement et l’affichage des données peuvent prendre jusqu’à une minute.

### Fonctions liées à l’insuline
Pour utiliser le calcul de l’insuline, appuyez sur l’étiquette `IOB` sur l’écran d’accueil.

Types d’insuline actuellement pris en charge :
- Insuline à action rapide, comme Novolog et Novorapid
- Insuline à action ultra-rapide, comme Fiasp et Lyumjev

FLwatch prend aussi en charge la saisie manuelle des doses d’insuline et inclut un calculateur intégré glucides-vers-insuline.

D’autres types d’insuline peuvent être ajoutés sur demande.

### Conseils Apple Watch et Siri
- Pour garder le graphique de glycémie visible sur la montre pendant une heure, ouvrez sur la montre ou dans l’application `Watch` de l’iPhone le chemin `Réglages > Général > Retour à l’horloge`, faites défiler jusqu’à FLwatch et choisissez `Après 1 heure`. Ainsi, FLwatch reste plus longtemps au premier plan et reçoit un nombre raisonnable de mises à jour, par exemple environ une fois par minute.
- Le moyen le plus simple de lancer l’application sur le téléphone ou la montre est de placer un widget ou une complication sur l’écran d’accueil, l’écran verrouillé, le cadran de montre ou un autre emplacement pratique, puis d’appuyer dessus.
- Les Live Activities sur iPhone peuvent aussi être recopiées dans la pile intelligente de l’Apple Watch pour un accès rapide.
- Siri et Raccourcis peuvent être utilisés pour lire à voix haute ou afficher la glycémie actuelle.
- Siri et Raccourcis peuvent aussi servir à enregistrer vocalement des doses d’insuline ou à enregistrer rapidement une dose d’insuline sur la montre.
- Pour ouvrir l’application en mains libres avec Siri, vous pouvez créer sur l’iPhone un raccourci qui ouvre simplement FLwatch. Vous pouvez par exemple l’appeler `graphique de glucose` ou `glycémie`. Activez l’option permettant d’afficher ce raccourci aussi sur la montre. Ensuite, il suffit de prononcer cette phrase à Siri pour ouvrir FLwatch directement. Cela fonctionne aussi sur l’iPhone.

### Fonctionnalités {#features}
#### Suivi
* Graphique de glycémie sur le téléphone et la montre
* Graphique interactif sur le téléphone pour afficher les valeurs individuelles d’un simple toucher
* Mode écran toujours allumé sur le téléphone

#### Insuline
* Prise en charge des insulines bolus à action rapide et à action ultra-rapide
* Calcul de l’insuline à bord (IOB)
* Graphique de l’insuline à bord
* Graphique de l’activité de l’insuline
* Saisie manuelle des doses d’insuline
* Calculateur intégré glucides-vers-insuline

#### Intégration au système
* Widgets iOS et widgets d’écran verrouillé avec et sans graphique(s)
* Live Activities sur iPhone, y compris la recopie dans la pile intelligente de l’Apple Watch
* Widget du mode veille
* Widgets et complications watchOS
* Prise en charge de CarPlay via les widgets et les Live Activities
* Exportation des doses d’insuline et des données de glucose vers Apple Health
* Prise en charge de Siri et Raccourcis pour afficher la glycémie, la lire à voix haute et enregistrer rapidement des doses d’insuline

### Notes techniques
FLwatch utilise le modèle exponentiel d’insuline de LoopKit. Le modèle utilise trois paramètres : `actionDuration`, `peakActivityTime` et `delay`.

- Pour l’insuline à action rapide, les paramètres sont 360, 75 et 10 minutes.
- Pour l’insuline à action ultra-rapide, les paramètres sont 360, 55 et 10 minutes.

### À faire
- Implémenter l’activité d’entraînement

### Assistance et commentaires {#support}
Pour obtenir de l’aide, veuillez ouvrir une [issue GitHub](https://github.com/poml88/FLwatch/issues), lancer une [discussion GitHub](https://github.com/poml88/FLwatch/discussions) ou envoyer un e-mail à **flwatch [at] cmdline [dot] net**.

Vos commentaires sont les bienvenus et peuvent être envoyés par les mêmes canaux.

### Dons
Les dons sont toujours les bienvenus.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Crédits
N’hésitez pas à consulter également ces projets :

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tous les noms de produits et de sociétés, marques commerciales, marques de service, marques déposées et marques de service déposées sont la propriété de leurs détenteurs respectifs. Leur utilisation est à titre informatif et n’implique aucune affiliation ou recommandation de leur part. Remarque : cette application n’a aucun lien avec Abbott Diabetes Care Inc. ni avec Dexcom, Inc. et n’est pas recommandée par ces sociétés.
