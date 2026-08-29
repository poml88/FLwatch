---
layout: landing
title: "FLwatch - Glucose & Insulin on iPhone and Apple Watch"
description: "FLwatch brings FreeStyle Libre and Dexcom glucose readings, insulin tracking, alerts, widgets, and Live Activities to iPhone and Apple Watch."
lang: en
permalink: /en/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - Glucose & Insulin"
---

<div class="notice-note">
<strong>Not for treatment decisions.</strong>
<br>
The information provided by FLwatch and its extensions must not be used for treatment or insulin-dosing decisions. Always rely on your glucose monitoring system and consult a healthcare professional when making medical decisions.
</div>

FLwatch displays glucose readings from Abbott FreeStyle Libre 2, Libre 2+, Libre 3, and Libre 3+ sensors, as well as Dexcom G6, G7, and ONE+ sensors, on your iPhone and Apple Watch.

It also lets you record insulin doses and visualizes insulin on board and insulin activity with dedicated graphs, helping you better understand how insulin and glucose levels interact.

FLwatch began as a personal project to support my own diabetes management. I made it publicly available, free and open source, in the hope that it can be useful to others too.

### At a Glance

- Glucose, insulin-on-board, and insulin-activity graphs on iPhone and Apple Watch
- Direct Bluetooth, LibreLinkUp, and Dexcom Share connection options
- Configurable glucose and sensor alerts
- Home Screen, Lock Screen, StandBy, and Apple Watch widgets and complications
- Live Activities, CarPlay, Siri, and Shortcuts support
- Apple Health export, plus Nightscout export with a direct FreeStyle Libre 3 or FreeStyle Libre 3+ connection
- Requires iOS 18 and watchOS 10.5

### Supported Sensors and Connections

| Manufacturer | Sensors | Connection |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 and FreeStyle Libre 2+ | LibreLinkUp |
| Abbott | FreeStyle Libre 3 and FreeStyle Libre 3+ | Direct Bluetooth or LibreLinkUp |
| Dexcom | G6, G7, and ONE+ | Dexcom Share |

### Features {#features}

#### Glucose Monitoring

- Blood glucose graph on iPhone and Apple Watch
- Interactive chart on iPhone — tap to inspect individual readings
- Optional calibration offset for directly connected FreeStyle Libre 3 and FreeStyle Libre 3+ sensors
- Check your current glucose and trend using Siri or Shortcuts
- Optional always-on display mode for quick viewing

#### Alerts

- Configurable low- and high-glucose alerts on iPhone, Apple Watch, and CarPlay
- Additional critical-low and signal-loss alerts for directly connected FreeStyle Libre 3 and FreeStyle Libre 3+ sensors
- Sensor warm-up status, remaining life, expiry, and replacement notifications for directly connected FreeStyle Libre 3 and FreeStyle Libre 3+ sensors
- Optional Critical Alerts and separate Do Not Disturb times for each alert type

FLwatch alerts are provided on a best-effort basis and are not guaranteed. They may be delayed or missed. Always confirm your glucose reading before taking action.

#### Insulin Tracking

- Record insulin doses on iPhone or with Siri and Shortcuts on iPhone and Apple Watch
- Basic carbohydrate and insulin calculator using portion size and a configurable insulin-to-carbohydrate ratio
- Insulin on Board (IOB) calculation and graph
- Insulin activity graph
- Support for rapid-acting and fast rapid-acting bolus insulins

#### Widgets, Live Activities, and CarPlay

- Home Screen widgets, with and without graphs
- Lock Screen and StandBy widgets
- Live Activities for quick glucose updates
- Native Apple Watch app with a wide range of widgets and watch face complications
- Glucose graph directly on Apple Watch
- Live Activity mirroring to the Smart Stack on watchOS 11 or later
- CarPlay view showing current glucose and IOB
- Glucose graphs in CarPlay through widgets and Live Activities

#### Data Sharing

- Export glucose readings and recorded insulin doses to Apple Health
- With a direct FreeStyle Libre 3 or FreeStyle Libre 3+ Bluetooth connection, export glucose readings and recorded insulin doses to your own Nightscout server

{% include screenshots.html %}

### Quick Start {#usage}

1. Install FLwatch from the [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Make sure the watchOS app is installed on your Apple Watch, ideally before starting the iPhone app.
3. On first launch, FLwatch asks you to choose your CGM: `FreeStyle Libre` through LibreLinkUp, `Dexcom` through Dexcom Share, or `FreeStyle Libre 3 (Bluetooth)` for a direct sensor connection.
4. After you make a selection, FLwatch automatically opens the matching `Connect` screen. Follow the instructions shown there and the relevant notes below.
5. Once connected, allow up to one minute for the first glucose data to appear.

You can change the selected CGM later in `Settings`.

If the watchOS app is installed, cloud-connection settings and credentials entered in the iPhone app are transferred to the Apple Watch app. You can transfer them again later by pressing the `Connect` button once more.

### Direct FreeStyle Libre 3 and FreeStyle Libre 3+ Connection

On a fresh installation, choose `FreeStyle Libre 3 (Bluetooth)` in the CGM picker. FLwatch then opens the Bluetooth connection screen automatically.

Before pairing:

- For most users with an already activated sensor, `Parallel` is the recommended mode. It keeps the sensor's existing FreeStyle Libre 3 connection credentials valid, making it easier to switch back to the FreeStyle Libre 3 app later.
- Sign in with the LibreView account used to activate the sensor, then tap `Get Account ID` in FLwatch. Parallel pairing requires the account information to match the activating account. This is different from the LibreLinkUp follower account used for a cloud connection.
- Only one app should access the sensor at a time. Before using FLwatch, fully close the FreeStyle Libre 3 app and turn off its Bluetooth access in iOS Settings. Switching between apps can take two to three minutes.
- When FLwatch asks you to scan, hold the top of your iPhone against the sensor and keep it still until NFC pairing finishes.

The `Fresh` mode is only for a brand-new, unused sensor. It starts the sensor's wear period immediately and cannot be undone. Most users should activate the sensor in the FreeStyle Libre 3 app and then pair it with FLwatch using `Parallel` mode.

Once paired, keep your iPhone near the sensor. Glucose readings are received directly over Bluetooth about once a minute, without a follower account or cloud connection. A direct connection also enables calibration offset, critical-low and signal-loss alerts, sensor-status notifications, and Nightscout export.

These direct-connection features are not available for FreeStyle Libre 2 or FreeStyle Libre 2+ sensors.

### Set Up LibreLinkUp

LibreLinkUp can provide glucose readings from FreeStyle Libre 2, FreeStyle Libre 2+, FreeStyle Libre 3, and FreeStyle Libre 3+ sensors. To use it with FLwatch, invite yourself to become your own follower.

*LibreView credentials do not work. Use the credentials of a LibreLinkUp follower account.*

<div class="notice-note">
<strong>LibreLinkUp video setup guide</strong>
<br>
@TypeOneCallum has created a very helpful <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">step-by-step FLwatch setup video</a>. If you are setting up LibreLinkUp for the first time, this is a good place to start.
</div>

1. In the FreeStyle LibreLink or FreeStyle Libre 3 app, go to Share / Connected Apps.
2. Open Connect / Manage LibreLinkUp.
3. Tap `Add Connection` and enter the email address you want to use for the follower account.
4. Accept the invitation sent to that email address.
5. Install the [LibreLinkUp app](https://apps.apple.com/us/app/librelinkup/id1234323923) on your iPhone and complete the setup for that invited follower account.
6. Confirm that you can see your own blood glucose graph in LibreLinkUp.
7. Open FLwatch and enter the follower account credentials on the `Connect` tab.

The email address for the follower account can be the same as the one used for LibreView. If the follower account has more than one connection, choose the person whose readings FLwatch should display after signing in.

The LibreLinkUp app can then be closed or uninstalled. You may still need it later to accept updated terms or privacy policies, or to verify that the account and connection still work.

[LibreLinkUp's step-by-step guide](https://www.librelinkup.com/articles/getting-started) provides further help.

<div class="notice-note">
<strong>LibreLinkUp API compatibility</strong>
<br>
FLwatch currently supports the LibreLinkUp 4.x API. LibreLinkUp API 5.0.0 is not yet supported. If API 4.x is disabled in the future, LibreLinkUp glucose data in FLwatch may stop working without notice. IOB-related features and other connection methods will continue to work.
</div>

### Set Up Dexcom Share

Dexcom G6, Dexcom G7, and Dexcom ONE+ sensors can provide glucose readings through Dexcom Share.

1. Turn on Share in the Dexcom app. Dexcom requires at least one follower invitation before Share can be enabled.
2. On a fresh installation, choose `Dexcom` in the CGM picker. FLwatch automatically opens the Dexcom Share connection screen.
3. Sign in with the email address and password of the Dexcom account used by the sensor wearer — the same account used in the Dexcom app on the wearer's phone — and press `Connect`. FLwatch detects the account region automatically.

Do not use a follower's login. Dexcom Share only exposes the wearer's own readings to third-party apps when the wearer's account is used.

If the Apple Watch app was not installed when you connected, install it and press `Connect` again to transfer the credentials. The Dexcom Share connection used by FLwatch is unofficial and may be changed or restricted without notice.

### Bluetooth Heartbeat for Cloud Connections

When using LibreLinkUp or Dexcom Share, FLwatch low- and high-glucose alerts require the Bluetooth Heartbeat. Enable it in `Settings > Bluetooth Heartbeat` and select your nearby sensor transmitter. FLwatch cannot deliver these cloud-connection alerts while the heartbeat is off; continue to use the sensor manufacturer's alerts as your primary alerts.

The direct FreeStyle Libre 3 and FreeStyle Libre 3+ Bluetooth connection does not use this setting.

### Insulin Features

To configure insulin calculation or record a dose, tap the `IOB` label on the home screen.

Currently supported insulin types:

- Rapid-acting insulin, such as Novolog and Novorapid
- Fast rapid-acting insulin, such as Fiasp and Lyumjev

The built-in calculator uses portion size and a configurable insulin-to-carbohydrate ratio. More insulin types can be added on request.

### Apple Watch, Siri, and Shortcuts Tips

- To keep the glucose graph visible on Apple Watch for one hour, open Settings on the watch or the `Watch` app on iPhone. Go to `General > Return to Clock`, choose FLwatch, and select `After 1 hour`.
- Place a widget or complication on your Home Screen, Lock Screen, or watch face for quick access to FLwatch.
- Live Activities on iPhone can be mirrored into the Apple Watch Smart Stack on watchOS 11 or later.
- Siri and Shortcuts can display or read out your current glucose value and record insulin doses.
- For hands-free access, create a shortcut that opens FLwatch, give it a phrase such as `glucose graph`, and enable `Show on Apple Watch` if desired.

### Technical Notes

FLwatch uses the exponential insulin model from LoopKit. The model uses three parameters: `actionDuration`, `peakActivityTime`, and `delay`.

- For rapid-acting insulin, the parameters are 360, 75, and 10 minutes.
- For fast rapid-acting insulin, the parameters are 360, 55, and 10 minutes.

### Project Status

FLwatch is an experimental open-source project. Use it with caution. It comes with no warranty and is used at your own risk.

FLwatch is also available for beta testing on [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Support and Feedback {#support}

For support, please open a [GitHub issue](https://github.com/poml88/FLwatch/issues), start a [GitHub discussion](https://github.com/poml88/FLwatch/discussions), or email **flwatch [at] cmdline [dot] net**.

Feedback is very welcome and can be sent through the same channels.

### Donations

Donations are always very welcome.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="PayPal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Buy Me a Coffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Credits

Please have a look at these projects as well:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

All product names, trademarks, and registered trademarks are the property of their respective owners. Their use here is for identification purposes only and does not imply affiliation with or endorsement by the trademark holders.

FLwatch is not affiliated with or endorsed by Abbott Diabetes Care Inc. or Dexcom, Inc.
