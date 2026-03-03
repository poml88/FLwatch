---
layout: landing
title: "FLwatch – 适用于 iPhone 和 Apple Watch 的血糖与胰岛素图表"
description: "FLwatch 是一款免费的开源应用，可使用 LibreLinkUp 数据在 iPhone 和 Apple Watch 上显示血糖、胰岛素在体内残留量（Insulin-on-Board）及其作用曲线，并支持小组件。"
lang: zh-Hans
permalink: /zh-Hans/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch：血糖传感器图表"
---


***警告：本项目具有高度实验性！使用本应用时请务必谨慎小心。切勿基于软件做出草率决定。如有疑虑请勿使用。本应用不可用于医疗决策。完全不提供任何形式的担保。使用风险自负！***

本软件为免费开源项目。虽源于个人需求开发，但旨在惠及所有用户。

### 使用指南 {#usage}
***安装说明：***请确保已安装watchOS应用程序，建议在启动iOS应用前完成安装。根据设备配置，watchOS应用可能自动安装，或需通过手机端“Watch”应用手动安装。
- 需iOS 17.5及watchOS 10.5系统
- TestFlight测试版：[https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- 设置在iOS应用中完成后会同步至watchOS应用。此功能仅在手表已安装watchOS应用时生效。
- ***建立应用间连接：*** 需先邀请自己成为自己的关注者。*LibreView凭证无法使用*。操作步骤：在LibreLink/Libre 3应用的“共享/关联应用”菜单中，选择“连接/管理LibreLinkUp”项。点击“添加连接”，输入用于追踪者账户的邮箱地址，系统将向该地址发送邀请（邮箱可与LibreView账户相同）。随后需在手机上安装[LibreLinkUp应用](https://apps.apple.com/us/app/librelinkup/id1234323923)，使用刚邀请的邮箱地址按指引设置LibreLinkUp追踪者账户。您可参考[分步指南](https://www.librelinkup.com/articles/getting-started)。请确保在LibreLinkUp应用中能正常查看自身血糖曲线图。最后，打开FLwatch并输入追踪账户凭证（详见下文）。当前FLwatch仅支持每个追踪账户关联一名被追踪患者。
- LibreLinkUp应用可关闭或卸载，但后续可能需要重新安装以接受新版《使用条款》和《隐私政策》，或验证账户/连接功能。
- 连接LibreLinkUp追踪账户时，请在FLwatch的“连接”选项卡输入凭证。若已安装watchOS应用，凭证将同步至手表端。再次点击“连接”按钮可重新传输凭证。
- 数据获取并显示可能需要一分钟时间。
- 使用胰岛素计算功能时，请点击主界面上的IOB标签。当前支持的胰岛素类型为：速效胰岛素（诺和锐、诺和速等）和超速效胰岛素（菲斯普、利尤杰夫等）。可根据需求添加更多胰岛素类型。*如有需要请告知*
- 本应用采用LoopKit的指数模型，该模型需三个参数：作用持续时间、峰值活性时间及延迟时间。速效胰岛素参数为360、75、10分钟；超速效胰岛素参数为360、55、10分钟。
- 可设置手表持续显示血糖曲线一小时：在手表或手机“手表”应用中进入设置→通用→返回时钟界面，向下滚动点击FLwatch并选择“1小时后”。如此FLwatch将保持1小时前台运行并获得合理频率的更新（如每分钟一次）。
- 最便捷的手机/手表应用启动方式：在主屏幕、锁屏界面、表盘或其他位置放置小部件/复杂功能图标，点击即可启动。
- 通过Siri免提开启应用时，可在手机创建名为“血糖曲线”或“血糖值”的快捷指令。该指令仅需开启FLwatch应用。选择快捷指令选项中的“在手表上显示”。现在激活Siri时，只需说出“血糖曲线”，FLwatch应用及其图表便会立即显示。
此方法同样适用于手机端。

### 功能特色 
* 手机与手表端血糖曲线图
* 手机端交互式图表，轻点即可查看单次数值
* 手机屏幕常亮模式
* 支持速效与超速效胰岛素剂型
* 体内胰岛素计算（IOB）
* 体内胰岛素曲线图
* 胰岛素活性曲线图
* iOS 小组件与锁屏小组件
* 待机模式小组件
* watchOS 小组件/并发功能

### 待办事项 
- 带血糖曲线图的组件

### 支持与反馈 {#support}
如需技术支持，请提交问题、发起讨论或发送邮件至 **flwatch [ a t ] cmdline [ d o t ] net**。我们非常欢迎反馈，请通过上述支持渠道提交。

### 捐赠... 
...永远欢迎！
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

同时欢迎关注以下项目：

### 鸣谢： 
[DiaBLE](https://github.com/gui-dos/DiaBLE)、[LoopKit](https://github.com/LoopKit)、[GlucoseDirect](https://github.com/creepymonster/GlucoseDirect)、[Nightguard]( https://github.com/nightscout/nightguard)、 [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

所有产品及公司名称、商标、服务标记、注册商标及注册服务标记均为其各自所有者的财产。此处使用仅为信息目的，不暗示与之存在任何关联或获得其认可。请注意：本应用与雅培糖尿病护理公司无关，亦未获得其认可。
