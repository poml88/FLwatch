---
layout: landing
title: "FLwatch – 适用于 iPhone 和 Apple Watch 的血糖与胰岛素图表"
description: "FLwatch 是一款免费的开源应用，可使用 LibreLinkUp 数据在 iPhone 和 Apple Watch 上显示血糖、胰岛素在体内残留量（Insulin-on-Board）及其作用曲线，并支持小组件。"
lang: zh-Hans
permalink: /zh-Hans/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch：血糖传感器图表"
---

***警告：FLwatch 是一个高度实验性的项目。使用本应用时请务必谨慎小心。请勿基于本软件做出医疗决策。本软件不提供任何保证，使用风险由您自行承担。***

本软件为免费开源项目。它源于个人需求开发，但希望能够让更多人受益。

### 快速了解
- 可在 iPhone 和 Apple Watch 上显示血糖、体内胰岛素残留量（IOB）和活动图表
- 支持小组件、复杂功能、Live Activities、Apple Watch 智能叠放镜像，以及导出到 Apple Health
- 支持手动记录胰岛素，并内置碳水化合物换算胰岛素计算器
- 需要 iOS 18 和 watchOS 10.5
- 如需参与 Beta 测试，FLwatch 也提供 TestFlight 版本：[https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- 使用 LibreLinkUp 关注者账户凭据，而不是 LibreView 凭据

### 快速开始 {#usage}
1. 通过 [App Store]({{ site.appstore_url }}) 安装 FLwatch。 {% include appstore_badge.html %}
2. 请确保 Apple Watch 上已安装 watchOS 应用，最好在首次打开 iOS 应用之前完成。
3. 创建并确认一个 LibreLinkUp 关注关系，使您成为自己的关注者。
4. 在 FLwatch 的 `Connect` 标签页中输入 LibreLinkUp 关注者账户凭据。
5. 等待最多约一分钟，数据即可显示出来。

如果已安装 watchOS 应用，则在 iOS 应用中输入的设置和凭据会传输到手表应用中。

- @TypeOneCallum 制作了一段非常有帮助的[设置教程视频](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB)。观看后会让设置过程容易很多。

### 设置 LibreLinkUp
要让 FLwatch 正常工作，您首先需要邀请自己成为自己的关注者。

*LibreView 凭据无法使用。*

1. 在 LibreLink 或 Libre 3 应用中，进入 Share / Connected Apps。
2. 打开 Connect / Manage LibreLinkUp。
3. 点击 `Add Connection`，输入您希望用于关注者账户的电子邮箱地址。
4. 接受发送到该电子邮箱地址的邀请。
5. 在 iPhone 上安装 [LibreLinkUp 应用](https://apps.apple.com/us/app/librelinkup/id1234323923)，并完成该受邀关注者账户的设置。
6. 确认您可以在 LibreLinkUp 中看到自己的血糖图表。
7. 打开 FLwatch，并在其中输入该关注者账户的凭据。

关注者账户的邮箱地址可以与 LibreView 使用相同的地址。

您也可以参考 [LibreLinkUp 的分步指南](https://www.librelinkup.com/articles/getting-started)。

目前，FLwatch 每个关注者账户仅支持一个被关注患者。

之后，LibreLinkUp 应用可以关闭，甚至卸载。不过，后续您可能仍需要它来接受新的使用条款或隐私政策，或者只是确认账户和连接仍然正常工作。

### 连接 FLwatch
- 在 FLwatch 的 `Connect` 标签页中输入您的 LibreLinkUp 关注者账户凭据。
- 如果已安装 watchOS 应用，凭据会传输到手表应用。
- 如有需要，您可以再次按下 `Connect` 按钮重新传输凭据。
- 数据获取和显示可能需要最多约一分钟。

### 胰岛素功能
要使用胰岛素计算功能，请点击主界面上的 `IOB` 标签。

当前支持的胰岛素类型：
- 速效胰岛素，例如 Novolog 和 Novorapid
- 超速效胰岛素，例如 Fiasp 和 Lyumjev

FLwatch 还支持手动记录胰岛素，并内置碳水化合物换算胰岛素计算器。

如有需要，也可以按请求添加更多胰岛素类型。

### Apple Watch 与 Siri 提示
- 如果希望血糖图表在手表上持续显示一小时，请在手表或 iPhone 上的 `Watch` 应用中打开 `设置 > 通用 > 返回时钟`，向下滚动到 FLwatch，并选择 `1 小时后`。这样 FLwatch 会更长时间保持在前台，并获得合理数量的更新，例如大约每分钟一次。
- 在手机或手表上启动应用的最简单方式，是将小组件或复杂功能放在主屏幕、锁屏界面、表盘或其他方便的位置，然后轻点启动。
- iPhone 上的 Live Activities 也可以镜像到 Apple Watch 的智能叠放中，便于快速访问。
- Siri 和快捷指令可用于朗读或显示当前血糖值。
- Siri 和快捷指令也可用于通过语音记录胰岛素剂量，或在手表上快速记录胰岛素剂量。
- 如果想通过 Siri 免提打开应用，您可以在 iPhone 上创建一个仅用于打开 FLwatch 的快捷指令，例如命名为 `血糖图表` 或 `血糖值`。启用该快捷指令在手表上显示的选项后，只需对 Siri 说出这句话即可直接打开 FLwatch。iPhone 上也同样适用。

### 功能 {#features}
#### 监测
* 手机和手表端血糖图表
* 手机端交互式图表，轻点即可查看单个数值
* 手机屏幕常亮模式

#### 胰岛素
* 支持速效和超速效餐时胰岛素
* 体内胰岛素残留量（IOB）计算
* IOB 图表
* 胰岛素活性图表
* 手动记录胰岛素
* 内置碳水化合物换算胰岛素计算器

#### 系统集成
* 带图表和不带图表的 iOS 小组件与锁屏小组件
* iPhone 上的 Live Activities，包括镜像到 Apple Watch 智能叠放
* StandBy 模式小组件
* watchOS 小组件和复杂功能
* 通过小组件和 Live Activities 支持 CarPlay
* 将胰岛素剂量和血糖数据导出到 Apple Health
* 支持 Siri 和快捷指令，用于显示血糖、朗读血糖，以及快速记录胰岛素剂量

### 技术说明
FLwatch 使用 LoopKit 的指数型胰岛素模型。该模型使用三个参数：`actionDuration`、`peakActivityTime` 和 `delay`。

- 对于速效胰岛素，参数分别为 360、75 和 10 分钟。
- 对于超速效胰岛素，参数分别为 360、55 和 10 分钟。

### 待办事项
- 实现锻炼活动

### 支持与反馈 {#support}
如果需要帮助，请提交 [GitHub issue](https://github.com/poml88/FLwatch/issues)、发起 [GitHub discussion](https://github.com/poml88/FLwatch/discussions)，或发送邮件至 **flwatch [at] cmdline [dot] net**。

我们也非常欢迎反馈，您可以通过相同渠道提交。

### 捐赠
我们始终欢迎捐赠支持。

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### 鸣谢
也欢迎查看以下项目：

[DiaBLE](https://github.com/gui-dos/DiaBLE)、[LoopKit](https://github.com/LoopKit)、[GlucoseDirect](https://github.com/creepymonster/GlucoseDirect)、[Nightguard](https://github.com/nightscout/nightguard)、[Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

所有产品及公司名称、商标、服务标记、注册商标及注册服务标记均为其各自所有者的财产。此处使用仅为信息目的，不暗示与之存在任何关联或获得其认可。请注意：本应用与 Abbott Diabetes Care Inc. 无关，亦未获得其认可。
