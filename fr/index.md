---
layout: landing
title: "FLwatch – Graphiques de glucose et d’insuline pour iPhone et Apple Watch"
description: "FLwatch est une application open source gratuite affichant des graphiques de glucose, d’insuline active (insulin-on-board) et d’activité avec des widgets sur iPhone et Apple Watch à partir des données LibreLinkUp."
lang: fr
permalink: /fr/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch: Graphique glycémie"
---


***Attention, ce projet est hautement expérimental ! Veuillez utiliser cette application avec prudence et extrême précaution. Ne prenez pas de décisions irréfléchies sur la base du logiciel. N'utilisez pas ce logiciel si vous n'êtes pas sûr. N'utilisez pas cette application pour prendre des décisions médicales. Elle est fournie sans aucune garantie. Utilisez-la à vos propres risques !***

Ce logiciel est gratuit et open source. Il est développé pour répondre à des besoins personnels, mais tout le monde devrait pouvoir en bénéficier.

### Utilisation {#usage}
***Installation :*** Assurez-vous que l'application watchOS est installée, idéalement avant de lancer l'application iOS. Selon votre configuration, l'application watchOS est soit installée automatiquement, soit doit être installée via l'application « Watch » sur le téléphone.
- @TypeOneCallum a réalisé une excellente [vidéo tutorielle d’installation](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) (Merci !). Regardez-la et la configuration sera beaucoup plus simple.
- L'application nécessite iOS 17.5 et watchOS 10.5
- TestFlight : [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Les paramètres sont définis dans l'application iOS, puis transférés vers l'application watchOS. Cela ne fonctionne que si l'application watchOS est installée sur la montre.
- ***Établissement de la connexion entre les applications :*** Pour que cela fonctionne, vous devez d'abord vous inviter à devenir votre propre abonné. *Les identifiants LibreView ne fonctionnent pas.* Pour ce faire, dans l'application LibreLink / Libre 3, sous Partager / Applications connectées, vous trouverez un élément Connecter / Gérer LibreLinkUp. Appuyez sur « Ajouter une connexion » et saisissez l'adresse e-mail que vous souhaitez utiliser pour le compte de suiveur. Une invitation sera envoyée à cette adresse (l'adresse e-mail peut être la même que celle utilisée pour LibreView). Ensuite, pour configurer le compte de suiveur LibreLinkUp, installez l'application [LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) sur votre téléphone et suivez les instructions en utilisant l'adresse e-mail que vous venez d'inviter. Vous trouverez peut-être utile le [guide étape par étape](https://www.librelinkup.com/articles/getting-started). Assurez-vous que vous pouvez voir votre propre graphique de glycémie dans l'application LibreLinkUp. Enfin, ouvrez FLwatch et entrez les identifiants du compte suiveur, voir ci-dessous. FLwatch ne prend actuellement en charge qu'un seul patient suivi par compte suiveur.
- L'application LibreLinkUp peut ensuite être fermée ou désinstallée, mais elle pourra être nécessaire ultérieurement pour accepter les nouvelles conditions d'utilisation, les politiques de confidentialité ou simplement pour vérifier que le compte/la connexion fonctionne.
- Pour vous connecter à votre compte suiveur LibreLinkUp, saisissez vos identifiants dans FLwatch dans l'onglet « Connect ». Si l'application watchOS est installée, les identifiants sont transférés vers l'application de la montre. Il est possible de retransférer les identifiants en appuyant à nouveau sur le bouton « connecter ».
- Le téléchargement et l'affichage des données peuvent prendre jusqu'à une minute.
- Pour utiliser le calcul de l'insuline, appuyez sur l'étiquette IOB sur l'écran d'accueil. Les types d'insuline actuellement pris en charge sont : à action rapide (Novolog, Novorapid, ...) et à action ultra-rapide (Fiasp, Lyumjev, ...). D'autres insulines peuvent être ajoutées sur demande. *N'hésitez pas à me le faire savoir.*
  - L'application utilise le modèle exponentiel de LoopKit. Le modèle prend en compte trois paramètres : actionDuration, peakActivityTime et delay. Pour l'insuline à action rapide, les paramètres sont 360, 75 et 10 minutes, pour l'insuline à action ultra-rapide, les paramètres sont 360, 55 et 10 minutes.
- Il existe un paramètre permettant de conserver le graphique de glycémie pendant une heure sur la montre : sur la montre ou dans l'application « Watch » du téléphone, allez dans Paramètres — Général — Retour à l'horloge, faites défiler vers le bas et appuyez sur FLwatch, puis choisissez « Après 1 heure ». Ainsi, FLwatch reste pendant 1 heure au premier plan et reçoit un nombre raisonnable de mises à jour (par exemple toutes les minutes).
- Le moyen le plus simple de lancer l'application sur le téléphone ou la montre est de placer un widget/une complication sur votre écran d'accueil, votre écran de verrouillage, votre cadran de montre ou n'importe où ailleurs, puis d'appuyer dessus.
- Pour utiliser Siri afin d'ouvrir l'application en mode mains libres, vous pouvez créer un raccourci sur le téléphone appelé, par exemple, « graphique de glucose » ou « glycémie ». Ce raccourci ouvre simplement FLwatch. Sélectionnez l'option de raccourci « afficher sur la montre ». Désormais, si vous activez Siri, il vous suffit de dire « graphique de glucose » et, voilà, l'application FLwatch et son graphique s'affichent.
Cela fonctionne de la même manière sur le téléphone.

### Fonctionnalités 
* Graphique de glycémie sur le téléphone et la montre
* Graphique interactif sur le téléphone pour afficher les valeurs individuelles d'un simple toucher
* Mode écran toujours allumé sur le téléphone
* Prise en charge des insulines à action rapide et à action ultra-rapide
* Calcul de l'insuline à bord (IOB)
* Graphique de l'insuline à bord
* Graphique de l'activité de l'insuline
* Widgets iOS et widgets d'écran de verrouillage
* Widget en mode veille
* Widgets watchOS / complications

### À faire 
- Widget avec graphique de glycémie

### Assistance et commentaires {#support}
Pour obtenir de l'aide, veuillez ouvrir un ticket, lancer une discussion ou envoyer un e-mail à **flwatch [ a t ] cmdline [ d o t ] net**. Vos commentaires sont les bienvenus, veuillez utiliser les mêmes méthodes que pour l'assistance.

### Dons... 
...sont toujours les bienvenus !
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

N'hésitez pas à consulter également ces projets :

### Crédits : 
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Tous les noms de produits et de sociétés, marques commerciales, marques de service, marques déposées et marques de service déposées sont la propriété de leurs détenteurs respectifs. Leur utilisation est à titre informatif et n'implique aucune affiliation ou recommandation de leur part. Remarque : cette application n'a aucun lien avec Abbott Diabetes Care Inc. et n'est pas recommandée par cette société.
