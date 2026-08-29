---
layout: landing
title: "FLwatch – iPhoneとApple Watchのグルコース＆インスリン"
description: "FLwatchは、FreeStyle LibreとDexcomのグルコース値、インスリン記録、アラート、ウィジェット、ライブアクティビティをiPhoneとApple Watchで利用できるようにします。"
lang: ja
permalink: /ja/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – グルコース＆インスリン"
---

<div class="notice-note">
<strong>治療方針の決定には使用しないでください。</strong>
<br>
FLwatchおよびその拡張機能が提供する情報を、治療やインスリン投与量の決定に使用しないでください。医療上の判断を行う際は、必ずご使用のグルコースモニタリングシステムを確認し、医療従事者に相談してください。
</div>

FLwatchは、Abbott FreeStyle Libre 2、Libre 2+、Libre 3、Libre 3+センサー、およびDexcom G6、G7、ONE+センサーのグルコース値をiPhoneとApple Watchに表示します。

インスリン投与量を記録できるほか、体内残存インスリンとインスリン作用を専用のグラフで可視化し、インスリンとグルコース値の関係をより深く理解するのに役立ちます。

FLwatchは、自身の糖尿病管理を支援するための個人的なプロジェクトとして始まりました。ほかの方にも役立つことを願い、無料のオープンソースソフトウェアとして一般公開しています。

### 概要

- iPhoneとApple Watchでグルコース、体内残存インスリン、インスリン作用のグラフを表示
- Bluetoothによる直接接続、LibreLinkUp、Dexcom Shareによる接続に対応
- グルコースとセンサーに関するアラートを設定可能
- ホーム画面、ロック画面、StandBy、Apple Watch向けのウィジェットとコンプリケーション
- ライブアクティビティ、CarPlay、Siri、ショートカットに対応
- Apple Healthへの書き出し、およびFreeStyle Libre 3またはFreeStyle Libre 3+への直接接続時のNightscoutへの書き出し
- iOS 18およびwatchOS 10.5が必要

### 対応センサーと接続方法

| メーカー | センサー | 接続方法 |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2およびFreeStyle Libre 2+ | LibreLinkUp |
| Abbott | FreeStyle Libre 3およびFreeStyle Libre 3+ | Bluetoothによる直接接続またはLibreLinkUp |
| Dexcom | G6、G7、ONE+ | Dexcom Share |

### 機能 {#features}

#### グルコースモニタリング

- iPhoneとApple Watchでグルコースグラフを表示
- iPhoneのインタラクティブグラフ — タップして個々の測定値を確認
- 直接接続したFreeStyle Libre 3およびFreeStyle Libre 3+センサー向けのオプションのキャリブレーションオフセット
- Siriまたはショートカットで現在のグルコース値とトレンドを確認
- すばやく確認するためのオプションの常時表示モード

#### アラート

- iPhone、Apple Watch、CarPlayで低グルコースと高グルコースのアラートを設定可能
- 直接接続したFreeStyle Libre 3およびFreeStyle Libre 3+センサー向けの重度の低グルコースアラートと信号消失アラート
- 直接接続したFreeStyle Libre 3およびFreeStyle Libre 3+センサーのウォームアップ状態、残り使用期間、期限切れ、交換に関する通知
- オプションの重大な通知と、アラートの種類ごとに設定できる個別の「おやすみモード」時間帯

FLwatchの通知は可能な範囲で配信されるものであり、配信を保証するものではありません。遅延したり届かなかったりする場合があります。行動する前に、必ずグルコース値を確認してください。

#### インスリン記録

- iPhoneで、またはiPhoneとApple WatchのSiriおよびショートカットを使ってインスリン投与量を記録
- 分量と設定可能なインスリン/炭水化物比を使用する基本的な炭水化物・インスリン計算機
- 体内残存インスリン（IOB）の計算とグラフ
- インスリン作用グラフ
- 速効型および超速効型ボーラスインスリンに対応

#### ウィジェット、ライブアクティビティ、CarPlay

- グラフあり・なしのホーム画面ウィジェット
- ロック画面およびStandBy用ウィジェット
- グルコース値をすばやく更新できるライブアクティビティ
- 多彩なウィジェットと文字盤コンプリケーションを備えたApple Watchネイティブアプリ
- Apple Watch上でグルコースグラフを直接表示
- watchOS 11以降でライブアクティビティをスマートスタックにミラーリング
- 現在のグルコース値とIOBを表示するCarPlay画面
- ウィジェットとライブアクティビティによるCarPlayでのグルコースグラフ表示

#### データの書き出し

- グルコース値と記録したインスリン投与量をApple Healthに書き出し
- FreeStyle Libre 3またはFreeStyle Libre 3+センサーにBluetoothで直接接続している場合、グルコース値と記録したインスリン投与量を自分のNightscoutサーバーに書き出し

{% include screenshots.html %}

### クイックスタート {#usage}

1. [App Store]({{ site.appstore_url }})からFLwatchをインストールします。 {% include appstore_badge.html %}
2. Apple WatchにwatchOSアプリがインストールされていることを確認します。できればiPhoneアプリを起動する前に済ませてください。
3. 初回起動時に、FLwatchが使用するCGMの選択を求めます。LibreLinkUp経由の`FreeStyle Libre`、Dexcom Share経由の`Dexcom`、またはセンサーに直接接続する`FreeStyle Libre 3 (Bluetooth)`から選択します。
4. 選択すると、FLwatchは対応する`接続`画面を自動的に開きます。画面に表示される手順と、以下の該当する注意事項に従ってください。
5. 接続後、最初のグルコースデータが表示されるまで最大1分ほどかかることがあります。

選択したCGMは、後から`設定`で変更できます。

watchOSアプリがインストールされている場合、iPhoneアプリに入力したクラウド接続の設定と認証情報がApple Watchアプリに転送されます。後から`接続`をもう一度タップして再転送することもできます。

### FreeStyle Libre 3およびFreeStyle Libre 3+への直接接続

新規インストール時は、CGM選択画面で`FreeStyle Libre 3 (Bluetooth)`を選択します。FLwatchがBluetooth接続画面を自動的に開きます。

ペアリングの前に：

- すでに有効化されたセンサーを使用する場合は、ほとんどの方に`並列`モードをおすすめします。センサーに保存されているFreeStyle Libre 3の接続認証情報が引き続き有効になるため、後でFreeStyle Libre 3アプリに戻りやすくなります。
- センサーの有効化に使用したLibreViewアカウントでサインインし、FLwatchで`アカウントIDを取得`をタップします。並列ペアリングでは、アカウント情報がセンサーの有効化に使用したアカウントと一致している必要があります。これはクラウド接続に使用するLibreLinkUpフォロワーアカウントとは別のものです。
- センサーに同時にアクセスするアプリは1つだけにしてください。FLwatchを使用する前にFreeStyle Libre 3アプリを完全に終了し、iOSの設定で同アプリのBluetoothアクセスをオフにします。アプリの切り替えには2〜3分かかる場合があります。
- FLwatchにスキャンを求められたら、iPhoneの上部をセンサーに当て、NFCペアリングが完了するまで動かさないでください。

`新品`モードは、未使用の新品センサー専用です。センサーの装着期間が直ちに開始され、この操作は取り消せません。ほとんどの方は、FreeStyle Libre 3アプリでセンサーを有効化してから、`並列`モードでFLwatchとペアリングしてください。

ペアリング後は、iPhoneをセンサーの近くに置いてください。フォロワーアカウントやクラウド接続を使わず、Bluetooth経由で約1分ごとにグルコース値を直接受信します。直接接続では、キャリブレーションオフセット、重度の低グルコースアラート、信号消失アラート、センサー状態の通知、Nightscoutへの書き出しも利用できます。

これらの直接接続機能は、FreeStyle Libre 2センサーおよびFreeStyle Libre 2+センサーでは利用できません。

### LibreLinkUpの設定

LibreLinkUpでは、FreeStyle Libre 2、FreeStyle Libre 2+、FreeStyle Libre 3、FreeStyle Libre 3+センサーのグルコース値を取得できます。FLwatchで使用するには、自分自身をフォロワーとして招待します。

*LibreViewの認証情報は使用できません。LibreLinkUpフォロワーアカウントの認証情報を使用してください。*

<div class="notice-note">
<strong>LibreLinkUp設定動画ガイド</strong>
<br>
@TypeOneCallumが、とても役立つ<a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">FLwatch設定のステップバイステップ動画</a>を作成しています。LibreLinkUpを初めて設定する場合は、まずこちらをご覧ください。
</div>

1. FreeStyle LibreLinkまたはFreeStyle Libre 3アプリで、`共有 / 接続済みアプリ`を開きます。
2. `接続 / LibreLinkUpを管理`を開きます。
3. `接続を追加`をタップし、フォロワーアカウントに使用するメールアドレスを入力します。
4. そのメールアドレスに届いた招待を承認します。
5. iPhoneに[LibreLinkUpアプリ](https://apps.apple.com/us/app/librelinkup/id1234323923)をインストールし、招待されたフォロワーアカウントの設定を完了します。
6. LibreLinkUpで自分のグルコースグラフが表示されることを確認します。
7. FLwatchを開き、`接続`タブにフォロワーアカウントの認証情報を入力します。

フォロワーアカウントのメールアドレスは、LibreViewで使用しているものと同じでも構いません。フォロワーアカウントに複数の接続がある場合は、サインイン後にFLwatchで値を表示する人を選択します。

設定後はLibreLinkUpアプリを終了またはアンインストールできます。ただし、更新された利用規約やプライバシーポリシーへの同意、またはアカウントと接続が引き続き機能しているかの確認に、後から再び必要になる場合があります。

[LibreLinkUpのステップバイステップガイド](https://www.librelinkup.com/articles/getting-started)も参考になります。

<div class="notice-note">
<strong>LibreLinkUp APIの互換性</strong>
<br>
FLwatchは現在、LibreLinkUp 4.x APIをサポートしています。LibreLinkUp API 5.0.0はまだサポートされていません。今後API 4.xが無効になった場合、FLwatchでLibreLinkUpのグルコースデータを予告なく取得できなくなる可能性があります。IOB関連機能とその他の接続方法は引き続き利用できます。
</div>

### Dexcom Shareの設定

Dexcom G6、Dexcom G7、Dexcom ONE+センサーでは、Dexcom Share経由でグルコース値を取得できます。

1. DexcomアプリでShareをオンにします。Dexcomでは、Shareを有効にする前に少なくとも1人のフォロワーを招待する必要があります。
2. 新規インストール時は、CGM選択画面で`Dexcom`を選択します。FLwatchがDexcom Share接続画面を自動的に開きます。
3. センサー装着者が使用しているDexcomアカウントのメールアドレスとパスワード、つまり装着者のiPhone上のDexcomアプリと同じアカウントでサインインし、`接続`をタップします。FLwatchがアカウントの地域を自動的に検出します。

フォロワーの認証情報は使用しないでください。Dexcom Shareでは、センサー装着者本人のアカウントを使用した場合に限り、装着者本人の測定値がサードパーティ製アプリに提供されます。

接続時にApple Watchアプリがインストールされていなかった場合は、インストールしてから`接続`をもう一度タップし、認証情報を転送してください。FLwatchが使用するDexcom Share接続は非公式であり、予告なく変更または制限される場合があります。

### クラウド接続用のBluetoothハートビート

LibreLinkUpまたはDexcom Shareを使用する場合、FLwatchの低グルコースおよび高グルコースアラートにはBluetoothハートビートが必要です。`設定 > Bluetoothハートビート`で有効にし、近くにあるセンサーのトランスミッターを選択してください。ハートビートがオフの間、FLwatchはクラウド接続でこれらのアラートを配信できません。センサーメーカーのアラートを引き続き主要なアラートとして使用してください。

FreeStyle Libre 3およびFreeStyle Libre 3+へのBluetooth直接接続では、この設定を使用しません。

### インスリン機能

インスリン計算の設定や投与量の記録を行うには、ホーム画面の`IOB`ラベルをタップします。

現在サポートされているインスリンの種類：

- 速効型インスリン（Novolog、Novorapidなど）
- 超速効型インスリン（Fiasp、Lyumjevなど）

内蔵の計算機では、分量と設定可能なインスリン/炭水化物比を使用します。その他のインスリンの種類もご要望に応じて追加できます。

### Apple Watch、Siri、ショートカットのヒント

- Apple Watchでグルコースグラフを1時間表示し続けるには、Apple Watchの設定またはiPhoneの`Watch`アプリを開きます。`一般 > 時計に戻る`でFLwatchを選択し、`1時間後`を選びます。
- ホーム画面、ロック画面、または文字盤にウィジェットやコンプリケーションを配置すると、FLwatchにすばやくアクセスできます。
- iPhoneのライブアクティビティは、watchOS 11以降でApple Watchのスマートスタックにミラーリングできます。
- Siriとショートカットで、現在のグルコース値を表示または読み上げたり、インスリン投与量を記録したりできます。
- ハンズフリーでアクセスするには、FLwatchを開くショートカットを作成し、`グルコースグラフ`などの名前を付け、必要に応じて`Apple Watchに表示`を有効にします。

### 技術メモ

FLwatchはLoopKitの指数インスリンモデルを使用しています。このモデルでは、`actionDuration`、`peakActivityTime`、`delay`の3つのパラメータを使用します。

- 速効型インスリンのパラメータは360、75、10分です。
- 超速効型インスリンのパラメータは360、55、10分です。

### プロジェクトの状況

FLwatchは実験的なオープンソースプロジェクトです。十分に注意してご利用ください。いかなる保証もなく提供されており、使用はすべて自己責任です。

FLwatchは[TestFlight](https://testflight.apple.com/join/HwgkwcGz)でもベータテスト用に提供されています。

### サポートとフィードバック {#support}

サポートが必要な場合は、[GitHub issue](https://github.com/poml88/FLwatch/issues)を開くか、[GitHub Discussions](https://github.com/poml88/FLwatch/discussions)を開始するか、**flwatch [at] cmdline [dot] net**までメールしてください。

フィードバックも歓迎しています。同じ連絡手段をご利用ください。

### 寄付

ご寄付はいつでも歓迎しています。

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="PayPalロゴ" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Buy Me a Coffeeロゴ" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### クレジット

以下のプロジェクトもぜひご覧ください：

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

すべての製品名、商標、登録商標は、それぞれの所有者に帰属します。ここでの使用は識別のみを目的としており、商標所有者との提携や商標所有者による承認を意味するものではありません。

FLwatchはAbbott Diabetes Care Inc.およびDexcom, Inc.のいずれとも提携しておらず、両社の承認も受けていません。
