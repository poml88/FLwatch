---
layout: landing
title: "FLwatch – iPhone と Apple Watch 向けの血糖値・インスリングラフ"
description: "FLwatch は、LibreLinkUp のデータを使って iPhone と Apple Watch に血糖値、insulin-on-board、活動グラフをウィジェット付きで表示する無料のオープンソースアプリです。"
lang: ja
permalink: /ja/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch - グルコースセンサーグラフ"
---

<div class="notice-note">
<strong>重要なお知らせ</strong>
<br>
FLwatch は現在、LibreLinkUp 4.x API をサポートしています。Abbott は API 5.0.0 を公開しましたが、まだサポートされていません。
<br>
将来 Abbott が API 4.x を無効にした場合、FLwatch の血糖データは予告なく動作しなくなる可能性があります。IOB 関連の機能は引き続き動作します。
</div>

***警告: FLwatch は非常に実験的なプロジェクトです。十分に注意してご利用ください。このソフトウェアに基づいて医療上の判断を行わないでください。いかなる保証もなく提供されており、使用はすべて自己責任です。***

このソフトウェアは無料のオープンソースです。個人的な必要性から開発されていますが、誰でも利用できるようにすることを目指しています。

### 概要
- iPhone と Apple Watch で血糖値、insulin-on-board、活動グラフを表示します
- ウィジェット、コンプリケーション、Live Activities、Apple Watch の Smart Stack へのミラーリング、Apple Health への書き出しに対応しています
- 手動でのインスリン記録と、内蔵の炭水化物対インスリン計算機をサポートしています
- iOS 18 と watchOS 10.5 が必要です
- ベータテスト用に、FLwatch は TestFlight でも利用できます: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- LibreView の認証情報ではなく、LibreLinkUp のフォロワーアカウントの認証情報を使用します

### クイックスタート {#usage}
1. [App Store]({{ site.appstore_url }}) から FLwatch をインストールします。 {% include appstore_badge.html %}
2. Apple Watch に watchOS アプリがインストールされていることを確認します。できれば iOS アプリを起動する前に済ませてください。
3. 自分自身をフォロワーとして設定し、LibreLinkUp 接続が機能することを確認します。
4. FLwatch の `Connect` タブで、LibreLinkUp フォロワーアカウントの認証情報を入力します。
5. データが表示されるまで最大 1 分ほど待ちます。

watchOS アプリがインストールされている場合、iOS アプリで入力した設定や認証情報は watch アプリへ転送されます。

- @TypeOneCallum によるとても分かりやすい[設定チュートリアル動画](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB)があります。視聴すると設定がかなり簡単になります。

### LibreLinkUp の設定
FLwatch を動作させるには、まず自分自身を自分のフォロワーとして招待する必要があります。

*LibreView の認証情報は使えません。*

1. LibreLink または Libre 3 アプリで Share / Connected Apps を開きます。
2. Connect / Manage LibreLinkUp を開きます。
3. `Add Connection` をタップし、フォロワーアカウントに使いたいメールアドレスを入力します。
4. そのメールアドレスに届いた招待を承認します。
5. iPhone に [LibreLinkUp アプリ](https://apps.apple.com/us/app/librelinkup/id1234323923) をインストールし、招待したフォロワーアカウントの設定を完了します。
6. LibreLinkUp で自分自身の血糖値グラフが見えることを確認します。
7. FLwatch を開き、そこにフォロワーアカウントの認証情報を入力します。

フォロワーアカウントのメールアドレスは LibreView と同じでも構いません。

[LibreLinkUp のステップバイステップガイド](https://www.librelinkup.com/articles/getting-started) も参考になります。

現在、FLwatch は 1 つのフォロワーアカウントにつき 1 人の被フォロー患者のみをサポートしています。

その後、LibreLinkUp アプリは閉じたりアンインストールしたりできます。ただし、後で新しい利用規約やプライバシーポリシーへの同意、またはアカウントや接続の確認のために再び必要になることがあります。

### FLwatch の接続
- FLwatch の `Connect` タブで、LibreLinkUp フォロワーアカウントの認証情報を入力します。
- watchOS アプリがインストールされていれば、認証情報は watch アプリへ転送されます。
- 必要であれば、`Connect` ボタンをもう一度押すことで認証情報を再転送できます。
- データの取得と表示には最大 1 分ほどかかることがあります。

### インスリン機能
インスリン計算を使うには、ホーム画面の `IOB` ラベルをタップしてください。

現在サポートされているインスリンの種類:
- 速効型インスリン: Novolog、Novorapid など
- 超速効型インスリン: Fiasp、Lyumjev など

FLwatch は手動でのインスリン記録にも対応しており、炭水化物対インスリン計算機も内蔵しています。

他のインスリン種類も要望に応じて追加できます。

### Watch と Siri のヒント
- Apple Watch で血糖値グラフを 1 時間表示し続けるには、Watch 本体または iPhone の `Watch` アプリで `設定 > 一般 > 時計に戻る` を開き、FLwatch を選んで `1 時間後` を選択してください。こうすると FLwatch がより長く前面に残り、たとえば約 1 分ごとなど、適切な回数の更新を受けられます。
- iPhone または Watch でアプリを最も簡単に起動する方法は、ホーム画面、ロック画面、文字盤などの使いやすい場所にウィジェットやコンプリケーションを置いてタップすることです。
- iPhone の Live Activities は Apple Watch の Smart Stack にもミラーリングでき、すばやく確認できます。
- Siri とショートカットを使って、現在の血糖値を読み上げたり表示したりできます。
- Siri とショートカットは、インスリン量の音声記録や、Watch での素早いインスリン量記録にも使えます。
- Siri でハンズフリー起動したい場合は、FLwatch を開くだけのショートカットを iPhone に作成できます。たとえば `血糖グラフ` や `血糖値` のような名前にできます。そのショートカットを Watch にも表示する設定を有効にしてください。そうすれば、そのフレーズを Siri に話しかけるだけで FLwatch を直接開けます。iPhone でも同様に使えます。

### 機能 {#features}
#### モニタリング
* iPhone と Apple Watch の血糖値グラフ
* タップで個別の値を確認できる iPhone 上のインタラクティブグラフ
* iPhone の常時表示モード

#### インスリン
* 速効型および超速効型ボーラスインスリンに対応
* insulin on board (IOB) の計算
* IOB グラフ
* インスリン活性グラフ
* 手動インスリン記録
* 内蔵の炭水化物対インスリン計算機

#### システム連携
* グラフあり・なしの iOS ウィジェットとロック画面ウィジェット
* iPhone の Live Activities と、Apple Watch Smart Stack へのミラーリング
* StandBy モード用ウィジェット
* watchOS ウィジェットとコンプリケーション
* ウィジェットと Live Activities を通じた CarPlay 対応
* インスリン量と血糖値データの Apple Health への書き出し
* 血糖値の表示、読み上げ、インスリン量の素早い記録に対応する Siri とショートカットのサポート

### 技術メモ
FLwatch は LoopKit の指数インスリンモデルを使用しています。このモデルでは `actionDuration`、`peakActivityTime`、`delay` の 3 つのパラメータを使います。

- 速効型インスリンのパラメータは 360、75、10 分です。
- 超速効型インスリンのパラメータは 360、55、10 分です。

### ToDo
- ワークアウトアクティビティを実装する

### サポートとフィードバック {#support}
サポートが必要な場合は、[GitHub issue](https://github.com/poml88/FLwatch/issues) を開くか、[GitHub Discussions](https://github.com/poml88/FLwatch/discussions) を始めるか、**flwatch [at] cmdline [dot] net** までメールしてください。

フィードバックも歓迎しており、同じ連絡手段をご利用いただけます。

### 寄付
ご寄付はいつでも歓迎しています。

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### クレジット
こちらのプロジェクトもぜひご覧ください:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

すべての製品名、会社名、商標、サービスマーク、登録商標、登録サービスマークは、それぞれの所有者に帰属します。ここでの使用は情報提供のみを目的としており、提携や承認を意味するものではありません。ご注意ください: このアプリは Abbott Diabetes Care Inc. とは一切関係がなく、同社の承認も受けていません。
