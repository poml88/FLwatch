---
layout: landing
title: "FLwatch - Glucose & Insulin Graphs for iPhone & Apple Watch"
description: "FLwatch is a free open-source app showing glucose, insulin-on-board and activity graphs with widgets on iPhone and Apple Watch using LibreLinkUp data."
lang: en
permalink: /en/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Glucose Sensor Graph"
---

***Warning: FLwatch is a highly experimental project. Use it with caution and extreme care. Do not make medical decisions based on this software. It comes with no warranty and is used at your own risk.***

<div class="notice-note">
<strong>Important note</strong>
<br>
FLwatch currently supports the LibreLinkUp 4.x API. Abbott has released API 5.0.0, which is not yet supported.
<br>
If Abbott disables API 4.x in the future, glucose data in FLwatch may stop working without notice. IOB-related features will still continue to work.
</div>

FLwatch is free and open source. It is being developed out of personal needs, but everyone should be able to benefit from it.

### At a Glance
- Shows glucose, insulin-on-board, and activity graphs on iPhone and Apple Watch
- Includes widgets, complications, Live Activities, Watch Smart Stack mirroring, and Apple Health export
- Supports manual insulin logging and a built-in carb-to-insulin calculator
- Requires iOS 18 and watchOS 10.5
- Beta testing: FLwatch is also available on TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Supports Freestyle Libre 2 and 3 sensors via LibreLinkUp (only API version 4.x) — uses LibreLinkUp follower account credentials, not LibreView credentials
- Supports Dexcom G6, G7 and ONE+ sensors via Dexcom Share — sign in with the email and password of the Dexcom account the sensor is set up on (the same login as the Dexcom app on the wearer's phone). Share must be turned on in the Dexcom app, which requires inviting at least one follower. Do not sign in with a follower's login — Dexcom only exposes the wearer's own readings to third-party apps.

### Quick Start {#usage}
1. Install FLwatch from the [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Make sure the watchOS app is installed on your Apple Watch, ideally before starting the iOS app.
3. Create and verify a LibreLinkUp follower connection for yourself.
4. Enter the LibreLinkUp follower credentials in FLwatch on the Connect tab.
5. Wait up to a minute for data to appear.

If the watchOS app is installed, settings and credentials entered in the iOS app are transferred to the watch app.

- @TypeOneCallum made a very helpful [setup tutorial video](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB). Watching it can make setup much easier.

### Set Up LibreLinkUp
To make FLwatch work, you need to invite yourself to become your own follower.

*LibreView credentials do not work.*

1. In the LibreLink or Libre 3 app, go to Share / Connected Apps.
2. Open Connect / Manage LibreLinkUp.
3. Tap `Add Connection` and enter the email address you want to use for the follower account.
4. Accept the invitation sent to that email address.
5. Install the [LibreLinkUp app](https://apps.apple.com/us/app/librelinkup/id1234323923) on your phone and complete the setup for that invited follower account.
6. Confirm that you can see your own blood glucose graph in LibreLinkUp.
7. Open FLwatch and enter the follower account credentials there.

The email address for the follower account can be the same as the one used for LibreView.

There is also a [step-by-step guide from LibreLinkUp](https://www.librelinkup.com/articles/getting-started) that may be useful.

Only one followed patient per follower account is currently supported by FLwatch.

The LibreLinkUp app can then be closed or even uninstalled. You may still need it later to accept updated Terms of Use or Privacy Policies, or to check that the account and connection still work.

### Connect FLwatch
- Enter your LibreLinkUp follower credentials in FLwatch on the `Connect` tab.
- If the watchOS app is installed, the credentials are transferred to the watch app.
- If needed, you can transfer the credentials again by pressing the `Connect` button once more.
- Data may take up to one minute to be fetched and displayed.

### Insulin Features
To use insulin calculation, tap the `IOB` label on the home screen.

Currently supported insulin types:
- Rapid-acting insulin, such as Novolog and Novorapid
- Fast rapid-acting insulin, such as Fiasp and Lyumjev

FLwatch also supports manual insulin logging and includes a built-in carb-to-insulin calculator.

More insulin types can be added on request.

### Watch and Siri Tips
- To keep the glucose graph visible on the watch for one hour, open the watch settings or the iPhone `Watch` app, then go to `Settings > General > Return to Clock`, scroll down to FLwatch, and choose `After 1 hour`. This lets FLwatch stay in the foreground longer and receive a reasonable number of updates, for example about once per minute.
- The easiest way to start the phone or watch app is to place a widget or complication on your Home Screen, Lock Screen, watch face, or similar location and tap it.
- Live Activities on iPhone can also be mirrored into the watch Smart Stack for quick access.
- Siri and Shortcuts can be used to read out or display the current blood glucose value.
- Siri and Shortcuts can also be used for voice recording of insulin doses or for quick insulin dose recording on the watch.
- To open the app hands-free with Siri, create a shortcut on the phone that simply opens FLwatch. For example, you could name it `glucose graph` or `blood sugar`. Enable the option to show the shortcut on the watch. Then saying that phrase to Siri can open FLwatch directly. The same also works on the phone.

### Features {#features}
#### Monitoring
* Blood glucose graph on phone and watch
* Interactive chart on phone to display individual values on tap
* Phone screen always-on mode

#### Insulin
* Supports rapid-acting and fast rapid-acting bolus insulins
* Insulin on board calculation (IOB)
* Insulin on board graph
* Insulin activity graph
* Manual insulin logging
* Built-in carb-to-insulin calculator

#### System Integration
* iOS widgets and lock screen widgets with and without graph(s)
* Live Activities on iPhone, including Watch Smart Stack and CarPlay mirroring
* StandBy mode widget
* watchOS widgets and complications
* CarPlay support via CarPlay app, widgets and Live Activities
* Export insulin doses and glucose data to Apple Health
* Siri and Shortcuts support for glucose display, glucose readout, and quick insulin dose recording
* Bluetooth heartbeat enables updates nearly every minute and low glucose alarms on iPhone, watch and CarPlay

### Technical Notes
FLwatch uses the exponential insulin model from LoopKit. The model uses three parameters: `actionDuration`, `peakActivityTime`, and `delay`.

- For rapid-acting insulin, the parameters are 360, 75, and 10 minutes.
- For fast rapid-acting insulin, the parameters are 360, 55, and 10 minutes.

### ToDo
- Implement workout activity

### Support and Feedback {#support}
For support, please open a [GitHub issue](https://github.com/poml88/FLwatch/issues), start a [GitHub discussion](https://github.com/poml88/FLwatch/discussions), or email **flwatch [at] cmdline [dot] net**.

Feedback is very welcome and can be sent through the same channels.

### Donations
Donations are always very welcome.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Credits
Please have a look at these projects as well:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

All product and company names, trademarks, service marks, registered trademarks, and registered service marks are the property of their respective holders. Their use is for information purposes and does not imply any affiliation with or endorsement by them. Please note: this app has no connection with and is not endorsed by Abbott Diabetes Care Inc. or Dexcom, Inc.
