---
layout: landing
title: "FLwatch – iPhone和Apple Watch上的葡萄糖与胰岛素"
description: "FLwatch将FreeStyle Libre和Dexcom葡萄糖读数、胰岛素记录、警报、小组件和实时活动带到iPhone和Apple Watch。"
lang: zh-Hans
permalink: /zh-Hans/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – 葡萄糖与胰岛素"
---

<div class="notice-note">
<strong>不可用于治疗决策。</strong>
<br>
FLwatch及其扩展提供的信息不得用于治疗或胰岛素剂量决策。做出医疗决策时，请始终以您的葡萄糖监测系统为准，并咨询医疗专业人员。
</div>

FLwatch可在iPhone和Apple Watch上显示Abbott FreeStyle Libre 2、Libre 3和Libre 3+传感器以及Dexcom G6、G7和ONE+传感器的葡萄糖读数。

它还可以记录胰岛素剂量，并通过专门的图表显示体内活性胰岛素和胰岛素活性，帮助您更好地了解胰岛素与葡萄糖之间的相互作用。

FLwatch最初是一个用于辅助我管理自身糖尿病的个人项目。我将其作为免费开源软件公开发布，希望它也能对其他人有所帮助。

### 快速了解

- 在iPhone和Apple Watch上显示葡萄糖、体内活性胰岛素和胰岛素活性图表
- 支持蓝牙直连、LibreLinkUp和Dexcom Share连接
- 可配置葡萄糖和传感器警报
- 支持主屏幕、锁定屏幕、StandBy和Apple Watch小组件与复杂功能
- 支持实时活动、CarPlay、Siri和快捷指令
- 支持导出到Apple Health；蓝牙直连FreeStyle Libre 3或FreeStyle Libre 3+时，还可导出到Nightscout
- 需要iOS 18和watchOS 10.5

### 支持的传感器和连接方式

| 制造商 | 传感器 | 连接方式 |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 | LibreLinkUp |
| Abbott | FreeStyle Libre 3和FreeStyle Libre 3+ | 蓝牙直连或LibreLinkUp |
| Dexcom | G6、G7和ONE+ | Dexcom Share |

### 功能 {#features}

#### 葡萄糖监测

- 在iPhone和Apple Watch上显示葡萄糖图表
- iPhone交互式图表 — 轻点即可查看单条读数
- 为蓝牙直连的FreeStyle Libre 3和FreeStyle Libre 3+传感器提供可选的校准偏移
- 使用Siri或快捷指令查看当前葡萄糖值和趋势
- 可选的屏幕常亮模式，便于快速查看

#### 警报

- 可在iPhone、Apple Watch和CarPlay上配置低葡萄糖和高葡萄糖警报
- 为蓝牙直连的FreeStyle Libre 3和FreeStyle Libre 3+传感器提供葡萄糖严重偏低和信号丢失警报
- 提供蓝牙直连FreeStyle Libre 3和FreeStyle Libre 3+传感器的预热状态、剩余使用时间、到期和更换通知
- 可选的关键警报，并可为每种警报类型单独设置“勿扰模式”时段

FLwatch警报会尽力送达，但不作保证。警报可能延迟或遗漏。采取行动前，请务必确认葡萄糖读数。

#### 胰岛素记录

- 在iPhone上记录胰岛素剂量，或在iPhone和Apple Watch上通过Siri与快捷指令进行记录
- 根据份量和可配置的胰岛素/碳水化合物比率进行计算的基础碳水化合物与胰岛素计算器
- 体内活性胰岛素（IOB）计算和图表
- 胰岛素活性图表
- 支持速效型和超速效型餐时胰岛素

#### 小组件、实时活动和CarPlay

- 带图表和不带图表的主屏幕小组件
- 锁定屏幕和StandBy小组件
- 用于快速查看葡萄糖更新的实时活动
- 原生Apple Watch应用，提供丰富的小组件和表盘复杂功能
- 直接在Apple Watch上显示葡萄糖图表
- 在watchOS 11或更高版本中将实时活动镜像到智能叠放
- 显示当前葡萄糖值和IOB的CarPlay视图
- 通过小组件和实时活动在CarPlay中显示葡萄糖图表

#### 数据导出

- 将葡萄糖读数和已记录的胰岛素剂量导出到Apple Health
- 蓝牙直连FreeStyle Libre 3或FreeStyle Libre 3+传感器时，将葡萄糖读数和已记录的胰岛素剂量导出到您自己的Nightscout服务器

{% include screenshots.html %}

### 快速开始 {#usage}

1. 从[App Store]({{ site.appstore_url }})安装FLwatch。 {% include appstore_badge.html %}
2. 请确保Apple Watch上已安装watchOS应用，最好在启动iPhone应用之前完成。
3. 首次启动时，FLwatch会要求您选择CGM：通过LibreLinkUp连接的`FreeStyle Libre`、通过Dexcom Share连接的`Dexcom`，或用于蓝牙直连传感器的`FreeStyle Libre 3 (Bluetooth)`。
4. 选择后，FLwatch会自动打开对应的`连接`界面。请按照界面上显示的说明以及下方相关提示进行操作。
5. 连接后，首批葡萄糖数据最多可能需要一分钟才会显示。

您可以稍后在`设置`中更改所选的CGM。

如果已安装watchOS应用，在iPhone应用中输入的云连接设置和凭据会传输到Apple Watch应用。您可以稍后再次轻点`连接`来重新传输。

### 蓝牙直连FreeStyle Libre 3和FreeStyle Libre 3+

全新安装时，请在CGM选择器中选择`FreeStyle Libre 3 (Bluetooth)`。FLwatch随后会自动打开蓝牙连接界面。

配对前：

- 对于大多数使用已激活传感器的用户，建议选择`并行`模式。该模式会保留传感器现有FreeStyle Libre 3连接凭据的有效性，方便您稍后切换回FreeStyle Libre 3应用。
- 使用激活传感器时所用的LibreView账户登录，然后在FLwatch中轻点`获取账户ID`。并行配对要求账户信息与激活传感器时所用的账户一致。该账户不同于云连接所使用的LibreLinkUp关注者账户。
- 同一时间只能有一个应用访问传感器。使用FLwatch前，请彻底关闭FreeStyle Libre 3应用，并在iOS设置中关闭该应用的蓝牙访问权限。在应用之间切换可能需要两到三分钟。
- 当FLwatch提示扫描时，请将iPhone顶部贴近传感器并保持不动，直至NFC配对完成。

`全新`模式仅适用于从未使用过的全新传感器。它会立即开始计算传感器的佩戴周期，且无法撤销。大多数用户应先在FreeStyle Libre 3应用中激活传感器，然后使用`并行`模式与FLwatch配对。

配对后，请将iPhone保持在传感器附近。葡萄糖读数约每分钟通过蓝牙直接接收一次，无需关注者账户或云连接。蓝牙直连还可启用校准偏移、葡萄糖严重偏低和信号丢失警报、传感器状态通知以及Nightscout导出。

FreeStyle Libre 2传感器不支持这些蓝牙直连功能。

### 设置LibreLinkUp

LibreLinkUp可以提供FreeStyle Libre 2、FreeStyle Libre 3和FreeStyle Libre 3+传感器的葡萄糖读数。要与FLwatch配合使用，请邀请自己成为自己的关注者。

*LibreView凭据无法使用。请使用LibreLinkUp关注者账户的凭据。*

<div class="notice-note">
<strong>LibreLinkUp设置视频指南</strong>
<br>
@TypeOneCallum制作了一段非常有帮助的<a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">FLwatch分步设置视频</a>。如果您是第一次设置LibreLinkUp，可以先从这段视频开始。
</div>

1. 在FreeStyle LibreLink或FreeStyle Libre 3应用中，前往`共享 / 已连接的应用`。
2. 打开`连接 / 管理LibreLinkUp`。
3. 轻点`添加连接`，并输入您希望用于关注者账户的电子邮件地址。
4. 接受发送到该电子邮件地址的邀请。
5. 在iPhone上安装[LibreLinkUp应用](https://apps.apple.com/us/app/librelinkup/id1234323923)，并完成受邀关注者账户的设置。
6. 确认您可以在LibreLinkUp中看到自己的葡萄糖图表。
7. 打开FLwatch，并在`连接`标签页中输入关注者账户的凭据。

关注者账户的电子邮件地址可以与LibreView所用的地址相同。如果关注者账户有多个连接，请在登录后选择FLwatch应显示其读数的人员。

之后可以关闭或卸载LibreLinkUp应用。以后您可能仍需使用该应用来接受更新后的使用条款或隐私政策，或确认账户和连接仍然有效。

[LibreLinkUp分步指南](https://www.librelinkup.com/articles/getting-started)提供了更多帮助。

<div class="notice-note">
<strong>LibreLinkUp API兼容性</strong>
<br>
FLwatch目前支持LibreLinkUp 4.x API。LibreLinkUp API 5.0.0尚不受支持。如果API 4.x将来被停用，FLwatch中的LibreLinkUp葡萄糖数据可能会在没有任何提示的情况下停止工作。IOB相关功能和其他连接方式仍可继续使用。
</div>

### 设置Dexcom Share

Dexcom G6、Dexcom G7和Dexcom ONE+传感器可以通过Dexcom Share提供葡萄糖读数。

1. 在Dexcom应用中开启Share。Dexcom要求至少邀请一名关注者，才能开启Share。
2. 全新安装时，请在CGM选择器中选择`Dexcom`。FLwatch会自动打开Dexcom Share连接界面。
3. 使用传感器佩戴者的Dexcom账户电子邮件地址和密码登录，也就是佩戴者iPhone上Dexcom应用所使用的同一账户，然后轻点`连接`。FLwatch会自动检测账户所在地区。

请勿使用关注者的登录凭据。只有使用传感器佩戴者本人的账户时，Dexcom Share才会向第三方应用提供该佩戴者本人的读数。

如果连接时尚未安装Apple Watch应用，请安装后再次轻点`连接`以传输凭据。FLwatch使用的Dexcom Share连接并非官方连接，可能会在不另行通知的情况下更改或受到限制。

### 云连接的蓝牙心跳

使用LibreLinkUp或Dexcom Share时，FLwatch的低葡萄糖和高葡萄糖警报需要蓝牙心跳。请在`设置 > 蓝牙心跳`中将其开启，并选择附近的传感器发射器。蓝牙心跳关闭时，FLwatch无法通过云连接发送这些警报；请继续将传感器制造商提供的警报作为主要警报。

蓝牙直连FreeStyle Libre 3和FreeStyle Libre 3+时不使用此设置。

### 胰岛素功能

要配置胰岛素计算或记录剂量，请轻点主屏幕上的`IOB`标签。

当前支持的胰岛素类型：

- 速效型胰岛素，例如Novolog和Novorapid
- 超速效型胰岛素，例如Fiasp和Lyumjev

内置计算器使用份量和可配置的胰岛素/碳水化合物比率。如有需要，可以添加更多胰岛素类型。

### Apple Watch、Siri和快捷指令提示

- 要让葡萄糖图表在Apple Watch上持续显示一小时，请打开手表上的设置或iPhone上的`Watch`应用。前往`通用 > 返回时钟`，选择FLwatch，然后选择`1小时后`。
- 将小组件或复杂功能放在主屏幕、锁定屏幕或表盘上，即可快速访问FLwatch。
- 从watchOS 11开始，iPhone上的实时活动可以镜像到Apple Watch的智能叠放中。
- Siri和快捷指令可以显示或朗读当前葡萄糖值，也可以记录胰岛素剂量。
- 如需免提访问，请创建一个用于打开FLwatch的快捷指令，将其命名为`葡萄糖图表`等名称，并根据需要启用`在Apple Watch上显示`。

### 技术说明

FLwatch使用LoopKit的指数型胰岛素模型。该模型使用三个参数：`actionDuration`、`peakActivityTime`和`delay`。

- 速效型胰岛素的参数为360、75和10分钟。
- 超速效型胰岛素的参数为360、55和10分钟。

### 项目状态

FLwatch是一个实验性的开源项目。请谨慎使用。本软件不提供任何保证，使用风险由您自行承担。

FLwatch也可通过[TestFlight](https://testflight.apple.com/join/HwgkwcGz)参与Beta测试。

### 支持与反馈 {#support}

如果需要帮助，请提交[GitHub issue](https://github.com/poml88/FLwatch/issues)、发起[GitHub discussion](https://github.com/poml88/FLwatch/discussions)，或发送电子邮件至**flwatch [at] cmdline [dot] net**。

我们也非常欢迎反馈，您可以通过相同渠道提交。

### 捐赠

我们始终欢迎捐赠支持。

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="PayPal标志" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Buy Me a Coffee标志" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### 鸣谢

也欢迎查看以下项目：

[DiaBLE](https://github.com/gui-dos/DiaBLE)、[LoopKit](https://github.com/LoopKit)、[GlucoseDirect](https://github.com/creepymonster/GlucoseDirect)、[Nightguard](https://github.com/nightscout/nightguard)、[Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

所有产品名称、商标和注册商标均为其各自所有者的财产。此处使用这些名称仅用于识别，不代表与商标持有人存在关联，也不代表获得其认可。

FLwatch与Abbott Diabetes Care Inc.和Dexcom, Inc.均无关联，也未获得这些公司的认可。
