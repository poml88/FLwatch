# FLwatch App #


![Exported PNG image6](https://github.com/user-attachments/assets/68ec6106-4866-442d-8e78-bc80ddba2608)![Exported PNG image1 Kopie](https://github.com/user-attachments/assets/68a92ba6-c590-4b3f-87ad-9ab77c36cb8c)

-----------------------------------

**Click here to use Google Translate to translate this page into your language. Thank you.**\
**:cn: [点击此处使用Google翻译将此页面翻译成您的语言。感谢您的使用。](https://github-com.translate.goog/poml88/FLwatch?_x_tr_sl=en&_x_tr_tl=zh-CN#usage)**\
**:fr: [Cliquez ici pour utiliser Google Translate afin de traduire cette page dans votre langue. Merci.](https://github-com.translate.goog/poml88/FLwatch?_x_tr_sl=en&_x_tr_tl=fr#usage)**\
**:de: [Klicken Sie hier, um diese Seite mit Google Translate in Ihre Sprache zu übersetzen. Vielen Dank.](https://github-com.translate.goog/poml88/FLwatch?_x_tr_sl=en&_x_tr_tl=de#usage)**\
**:jp: [ここをクリックして、このページをあなたの言語に翻訳するためにGoogle翻訳をご利用ください。ありがとうございます。](https://github-com.translate.goog/poml88/FLwatch?_x_tr_sl=en&_x_tr_tl=ja#usage)**\
**:es: [Haga clic aquí para utilizar Google Translate y traducir esta página a su idioma. Gracias.](https://github-com.translate.goog/poml88/FLwatch?_x_tr_sl=en&_x_tr_tl=es#usage)**

-----------------------------------



***Warning, This project is highly experimental! Please use this app with caution and extreme care. Do not make careless decisions based on software. Do not use this software if you are unsure. Don't use this App for medical decisions. It comes without absolutely no warranty. Use it at your own risk!***

This software is free and open source. It is being developed out of personal needs, but everyone should be able to benefit from it.

### Usage ###
***Installation:*** Make sure that the watchOS app is installed, ideally before starting the iOS app. Depending on your configuration, the watchOS app is either installed automatically, or has to be installed via the "Watch" app on the phone.
- The app needs iOS 17.5 and watchOS 10.5
- TestFlight: https://testflight.apple.com/join/HwgkwcGz
- AppStore: https://apps.apple.com/app/flwatch/id6670172928
- Settings are made in the iOS app and are then transferred to the watchOS app. This only works if the watchOS app is installed on the watch.
- ***Establishing the connection between the apps:*** To make things work, you have to first invite yourself to become your own follower. *LibreView credentials do not work.* To do this, in the LibreLink / Libre 3 app under Share / Connected Apps, there is a Connect / Manage LibreLinkUp item. Tap "Add Connection" and enter the email address you would like to use for the follower account, and an invitation is sent to that address (the email address can be the same as for LibreView). Then, to set up the LibreLinkUp follower account, install the [LibreLinkUp App](https://apps.apple.com/us/app/librelinkup/id1234323923) on the phone and follow the instructions using the email address you just invited. There is a [Step by Step Guide](https://www.librelinkup.com/articles/getting-started) you might find useful. Make sure you can see your own blood glucose graph in the LibreLinkUp app. Lastly, open FLwatch and enter the credentials of the follower account, see below. Only one followed patient per follower account is currently supported by FLwatch.
- The LibreLinkUp app can then be closed or uninstalled, but maybe needed later to accept new Terms of Use, Privacy Policies, or just to check that the account / connection works.
- To connect to your LibreLinkUp follower account, enter your credentials in FLwatch on the connect tab. If the watchOS app is installed, the credentials are transferred to the watch app. It is possible to re-transfer the credentials by pressing the "connect" button again.
- It can take up to a minute for the data to be fetched and displayed.
- To use the insulin calculation, tap on the IOB label on the home screen. Supported insulin types are currently: rapid acting (Novolog, Novorapid, ...) and fast rapid acting (Fiasp, Lyumjev, ...). More insulins can be added on request. *Please let me know.*
  - The app is using the exponetial model from LoopKit. The model takes three paramters: actionDuration, peakActivityTime, and delay. For rapid acting insulin the parameters are 360, 75, and 10 minutes, for fast rapid acting insulin the parameters are 360, 55, and 10 minutes.
- There is a setting to keep the glucose graph for one hour displayed on the watch: Either on the watch, or in the phone "Watch" app, go to Settings -- General -- Return to Clock scroll down and tap on FLwatch and choose "After 1 hour". Like this, FLwatch stays for 1 hour in the foreground and gets a reasonable number of updates (like every minute).
- The easiest way to start the phone or watch app is by placing a widget / complication on your homescreen, lockscreen, watchface, or whereever and tap it.
- To use Siri to open the app handsfree you can create a shortcut on the phone called for example „glucose graph“ or "blood sugar". This shortcut just opens FLwatch. Select the shortcut option „show on watch“. Now, if you activate Siri, you just say „glucose graph“ and, voila, it shows the app FLwatch and its graph.
Same works on the phone.

### Features ###
* blood glucose graph on phone and watch
* interactive chart on phone to display individual values on tap
* phone screen always on mode
* supports rapid acting and fast rapid acting bolus insulins
* insulin on board calculation (IOB)
* insulin on board graph
* insulin activity graph
* iOS widgets and lock screen widgets
* stand by mode widget
* watchOS widgets / complications

### ToDo ###
- Widget with BG graph

### Support and Feedback ###
For support please open an issue, start a discussion or email **flwatch [ a t ] cmdline [ d o t ] net**. Feedback is very welcome, please use the same methods as for support.

### Donations... ###
...are always very welcome! [paypal.me/lovemyhusky](paypal.me/lovemyhusky)

Please have a look at these projects as well:

### Credits: ###
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

All product and company names, trademarks, service marks, registered trademarks, and registered service marks are the property of their respective holders. Their use is for information purposes and does not imply any affiliation with or endorsement by them. Please note: this app has no connection with and is not endorsed by Abbott Diabetes Care Inc.

