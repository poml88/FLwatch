---
layout: landing
title: "FLwatch – iPhoneとApple Watch向けの血糖値・インスリングラフ"
description: "FLwatchは、LibreLinkUpのデータを使用して、血糖値、インスリン残量（Insulin-on-Board）、インスリン作用のグラフとウィジェットをiPhoneとApple Watchに表示する無料のオープンソースアプリです。"
lang: ja
permalink: /ja/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch：血糖値センサーグラフ"
---



***警告：本プロジェクトは高度に実験的なものです！本アプリは細心の注意を払ってご利用ください。ソフトウェアに基づいて軽率な判断を下さないでください。確信が持てない場合は本ソフトウェアを使用しないでください。医療判断のために本アプリを使用しないでください。一切の保証はありません。ご自身の責任においてご利用ください！***

本ソフトウェアは無料かつオープンソースです。個人的な必要性から開発されていますが、誰もがその恩恵を受けられるべきです。

### 使用方法 {#usage}
***インストール方法:*** watchOSアプリがインストールされていることを確認してください（iOSアプリ起動前に実施が望ましい）。環境設定により、watchOSアプリは自動インストールされるか、スマートフォン上の「Watch」アプリ経由で手動インストールが必要です。
- @TypeOneCallum さんがとても分かりやすい [セットアップのチュートリアル動画](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) を作ってくれました（ありがとうございます！）。これを見るとセットアップがずっと簡単になります。
- 動作環境: iOS 18 以上、watchOS 10.5 以上
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- 設定はiOSアプリで行い、その後watchOSアプリに転送されます。これはwatchOSアプリが時計にインストールされている場合にのみ機能します。
- ***アプリ間の接続確立:*** 機能させるには、まず自分自身をフォロワーとして招待する必要があります。*LibreViewの認証情報は使用できません。* 操作手順：LibreLink / Libre 3アプリの「共有」＞「接続済みアプリ」内に「接続 / LibreLinkUpを管理」項目があります。「接続を追加」をタップし、フォロワーアカウントに使用するメールアドレスを入力すると、そのアドレスに招待状が送信されます（メールアドレスはLibreViewと同じでも構いません）。次に、LibreLinkUpフォロワーアカウントを設定するには、スマートフォンに[LibreLinkUpアプリ](https://apps.apple.com/us/app/librelinkup/id1234323923)をインストールし、先ほど招待したメールアドレスを使用して指示に従ってください。参考になるかもしれない[ステップバイステップガイド](https://www.librelinkup.com/articles/getting-started)があります。LibreLinkUpアプリで自身の血糖値グラフが表示できることを確認してください。最後に、FLwatchを開き、フォロワーアカウントの認証情報を入力します（下記参照）。現在FLwatchでは、1つのフォロワーアカウントにつき1人のフォロー対象患者のみサポートされています。
- LibreLinkUpアプリは閉じて削除しても構いませんが、新しい利用規約やプライバシーポリシーの承諾、またはアカウント/接続の確認が必要な場合に後で必要になる可能性があります。
- LibreLinkUpフォロワーアカウントに接続するには、FLwatchの「接続」タブで認証情報を入力してください。watchOSアプリがインストールされている場合、認証情報はウォッチアプリに転送されます。「接続」ボタンを再度押すことで認証情報を再転送できます。
- データの取得と表示には最大1分かかる場合があります。
- インスリン計算を使用するには、ホーム画面の「IOB」ラベルをタップしてください。現在対応しているインスリンの種類は：速効型（ノボログ、ノボラピッドなど）および超速効型（フィアースプ、リュムジェブなど）です。追加のインスリンはリクエストに応じて追加可能です。*お知らせください。*
  - 本アプリはLoopKitの指数モデルを採用しています。このモデルは3つのパラメータ（actionDuration、peakActivityTime、delay）を必要とします。速効型インスリンの場合のパラメータは360、75、10分、超速効型インスリンの場合は360、55、10分です。
- 血糖値グラフを1時間表示し続ける設定があります：  時計本体またはスマートフォンの「Watch」アプリで、設定 → 一般 → 時計に戻る を選択し、下にスクロールしてFLwatchをタップし、「1時間後」を選択してください。これにより、FLwatchは1時間フォアグラウンドに表示され、適切な頻度（例えば毎分）で更新されます。
- スマートフォンまたはウォッチアプリを起動する最も簡単な方法は、ホーム画面、ロック画面、ウォッチフェイスなどにウィジェット／コンプリケーションを配置し、それをタップすることです。
- Siriでハンズフリー操作する場合、スマートフォンに「血糖値グラフ」や「血糖値」といったショートカットを作成します。このショートカットはFLwatchを起動するだけです。「ウォッチに表示」オプションを選択してください。Siriを起動し「血糖値グラフ」と発声すると、FLwatchアプリとそのグラフが表示されます。
スマートフォンでも同様の操作が可能です。

### 機能 
* スマートフォンとウォッチでの血糖値グラフ表示
* スマートフォン上のインタラクティブチャート（タップで個別値を表示）
* スマートフォン画面常時表示モード
* 速効型および超速効型ボラスインスリン対応
* インスリンオンボード計算（IOB）
* インスリンオンボードグラフ
* インスリン活性グラフ
* グラフあり・なしのiOSウィジェットおよびロック画面ウィジェット
* Live Activities
* スタンバイモードウィジェット
* watchOSウィジェット / コンプリケーション
* ウィジェットおよびLive ActivitiesによるCarPlay対応

### 開発予定
- ワークアウトアクティビティを実装

### サポートとフィードバック {#support}
サポートが必要な場合は、イシューを開く、ディスカッションを開始する、または **flwatch [ a t ] cmdline [ d o t ] net** までメールをお送りください。フィードバックは大歓迎です。サポートと同様の方法でお寄せください。

### 寄付について... 
...いつでも大歓迎です！
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

以下のプロジェクトもぜひご覧ください：

### クレジット: 
[DiaBLE](https://github.com/gui-dos/DiaBLE)、[LoopKit](https://github.com/LoopKit)、[GlucoseDirect](https://github.com/creepymonster/GlucoseDirect)、[Nightguard]( https://github.com/nightscout/nightguard)、 [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

すべての製品名、会社名、商標、サービスマーク、登録商標、登録サービスマークは、それぞれの所有者に帰属します。それらの使用は情報提供を目的としたものであり、いかなる提携や推奨を意味するものではありません。ご注意：本アプリはアボット・ダイアベティス・ケア社とは一切関係がなく、同社の推奨を受けていません。
