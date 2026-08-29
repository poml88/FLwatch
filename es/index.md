---
layout: landing
title: "FLwatch – Glucosa e insulina en iPhone y Apple Watch"
description: "FLwatch lleva las lecturas de glucosa de FreeStyle Libre y Dexcom, el seguimiento de la insulina, alertas, widgets y actividades en directo al iPhone y al Apple Watch."
lang: es
permalink: /es/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch – Glucosa e insulina"
---

<div class="notice-note">
<strong>No debe utilizarse para tomar decisiones terapéuticas.</strong>
<br>
La información que proporcionan FLwatch y sus extensiones no debe utilizarse para tomar decisiones sobre el tratamiento o las dosis de insulina. Confíe siempre en su sistema de monitorización de glucosa y consulte a un profesional sanitario para tomar decisiones médicas.
</div>

FLwatch muestra en su iPhone y Apple Watch las lecturas de glucosa de los sensores Abbott FreeStyle Libre 2, Libre 3 y Libre 3+, así como de los sensores Dexcom G6, G7 y ONE+.

También permite registrar dosis de insulina y muestra gráficas específicas de insulina activa y de actividad de la insulina, que le ayudan a comprender mejor cómo interactúan la insulina y la glucosa.

FLwatch nació como un proyecto personal para ayudarme a gestionar mi propia diabetes. Lo publiqué de forma gratuita y como código abierto con la esperanza de que también pudiera resultar útil a otras personas.

### Resumen rápido

- Gráficas de glucosa, insulina activa y actividad de la insulina en iPhone y Apple Watch
- Opciones de conexión mediante Bluetooth directo, LibreLinkUp y Dexcom Share
- Alertas configurables de glucosa y del sensor
- Widgets y complicaciones para la pantalla de inicio, la pantalla de bloqueo, el modo En reposo y el Apple Watch
- Compatibilidad con actividades en directo, CarPlay, Siri y Atajos
- Exportación a Apple Health, además de exportación a Nightscout con una conexión directa a un sensor FreeStyle Libre 3 o FreeStyle Libre 3+
- Requiere iOS 18 y watchOS 10.5

### Sensores y conexiones compatibles

| Fabricante | Sensores | Conexión |
| --- | --- | --- |
| Abbott | FreeStyle Libre 2 | LibreLinkUp |
| Abbott | FreeStyle Libre 3 y FreeStyle Libre 3+ | Bluetooth directo o LibreLinkUp |
| Dexcom | G6, G7 y ONE+ | Dexcom Share |

### Características {#features}

#### Monitorización de glucosa

- Gráfica de glucosa en iPhone y Apple Watch
- Gráfica interactiva en el iPhone: pulse para consultar lecturas individuales
- Ajuste de calibración opcional para sensores FreeStyle Libre 3 y FreeStyle Libre 3+ conectados directamente
- Consulta de la glucosa actual y su tendencia mediante Siri o Atajos
- Modo de pantalla siempre activa opcional para una consulta rápida

#### Alertas

- Alertas configurables de glucosa baja y alta en iPhone, Apple Watch y CarPlay
- Alertas adicionales de glucosa críticamente baja y pérdida de señal para sensores FreeStyle Libre 3 y FreeStyle Libre 3+ conectados directamente
- Notificaciones sobre el calentamiento, la vida útil restante, la caducidad y la sustitución de los sensores FreeStyle Libre 3 y FreeStyle Libre 3+ conectados directamente
- Alertas críticas opcionales y periodos de «No molestar» independientes para cada tipo de alerta

Las alertas de FLwatch se entregan en la medida de lo posible y no están garantizadas. Pueden retrasarse o no llegar. Confirme siempre su lectura de glucosa antes de actuar.

#### Seguimiento de la insulina

- Registro de dosis de insulina en el iPhone o mediante Siri y Atajos en el iPhone y el Apple Watch
- Calculadora básica de carbohidratos e insulina basada en el tamaño de la porción y una relación insulina/carbohidratos configurable
- Cálculo y gráfica de la insulina activa (IOB)
- Gráfica de actividad de la insulina
- Compatibilidad con insulinas de bolo de acción rápida y ultrarrápida

#### Widgets, actividades en directo y CarPlay

- Widgets de la pantalla de inicio, con y sin gráficas
- Widgets para la pantalla de bloqueo y el modo En reposo
- Actividades en directo para consultar rápidamente las actualizaciones de glucosa
- Aplicación nativa para Apple Watch con numerosos widgets y complicaciones para las esferas
- Gráfica de glucosa directamente en el Apple Watch
- Duplicación de las actividades en directo en la Pila Inteligente a partir de watchOS 11
- Vista de CarPlay con la glucosa actual y la IOB
- Gráficas de glucosa en CarPlay mediante widgets y actividades en directo

#### Exportación de datos

- Exportación de las lecturas de glucosa y las dosis de insulina registradas a Apple Health
- Con una conexión Bluetooth directa a un sensor FreeStyle Libre 3 o FreeStyle Libre 3+, exportación de las lecturas de glucosa y las dosis de insulina registradas a su propio servidor Nightscout

{% include screenshots.html %}

### Inicio rápido {#usage}

1. Instale FLwatch desde el [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Asegúrese de que la aplicación para watchOS esté instalada en su Apple Watch, preferiblemente antes de abrir la aplicación para iPhone.
3. La primera vez que se inicia, FLwatch le pide que elija su CGM: `FreeStyle Libre` mediante LibreLinkUp, `Dexcom` mediante Dexcom Share o `FreeStyle Libre 3 (Bluetooth)` para una conexión directa con el sensor.
4. Tras realizar la selección, FLwatch abre automáticamente la pantalla `Conectar` correspondiente. Siga las instrucciones que aparecen en ella y las indicaciones pertinentes que se incluyen a continuación.
5. Una vez establecida la conexión, espere hasta un minuto para que aparezcan los primeros datos de glucosa.

Puede cambiar el CGM seleccionado más adelante en `Configuración`.

Si la aplicación para watchOS está instalada, los ajustes y las credenciales para las conexiones a la nube introducidos en la aplicación para iPhone se transfieren a la aplicación del Apple Watch. Puede volver a transferirlos más adelante pulsando de nuevo `Conectar`.

### Conexión directa con FreeStyle Libre 3 y FreeStyle Libre 3+

En una instalación nueva, seleccione `FreeStyle Libre 3 (Bluetooth)` en el selector de CGM. FLwatch abrirá automáticamente la pantalla de conexión Bluetooth.

Antes del emparejamiento:

- Para la mayoría de los usuarios con un sensor ya activado, se recomienda el modo `Paralelo`. Este mantiene válidas las credenciales de conexión de FreeStyle Libre 3 que ya tiene el sensor, lo que facilita volver más adelante a la aplicación FreeStyle Libre 3.
- Inicie sesión con la cuenta de LibreView que se utilizó para activar el sensor y, a continuación, pulse `Obtener ID de cuenta` en FLwatch. Para el emparejamiento en paralelo, la información de la cuenta debe coincidir con la cuenta que activó el sensor. Esta cuenta es diferente de la cuenta de seguidor de LibreLinkUp utilizada para una conexión a la nube.
- Solo una aplicación debe acceder al sensor a la vez. Antes de utilizar FLwatch, cierre por completo la aplicación FreeStyle Libre 3 y desactive su acceso a Bluetooth en los ajustes de iOS. Cambiar de una aplicación a otra puede tardar entre dos y tres minutos.
- Cuando FLwatch le pida que escanee, mantenga la parte superior del iPhone contra el sensor sin moverlo hasta que finalice el emparejamiento NFC.

El modo `Nuevo` solo debe utilizarse con un sensor completamente nuevo y sin usar. Inicia de inmediato el periodo de uso del sensor y no se puede deshacer. La mayoría de los usuarios deben activar el sensor en la aplicación FreeStyle Libre 3 y emparejarlo después con FLwatch mediante el modo `Paralelo`.

Una vez emparejado, mantenga el iPhone cerca del sensor. Las lecturas de glucosa se reciben directamente por Bluetooth aproximadamente una vez por minuto, sin una cuenta de seguidor ni conexión a la nube. Una conexión directa también permite utilizar el ajuste de calibración, las alertas de glucosa críticamente baja y pérdida de señal, las notificaciones del estado del sensor y la exportación a Nightscout.

Estas funciones de conexión directa no están disponibles para los sensores FreeStyle Libre 2.

### Configurar LibreLinkUp

LibreLinkUp puede proporcionar lecturas de glucosa de los sensores FreeStyle Libre 2, FreeStyle Libre 3 y FreeStyle Libre 3+. Para utilizarlo con FLwatch, invítese a sí mismo como su propio seguidor.

*Las credenciales de LibreView no funcionan. Utilice las credenciales de una cuenta de seguidor de LibreLinkUp.*

<div class="notice-note">
<strong>Videoguía para configurar LibreLinkUp</strong>
<br>
@TypeOneCallum ha creado un <a href="https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB">vídeo paso a paso para configurar FLwatch</a> muy útil. Si configura LibreLinkUp por primera vez, este es un buen punto de partida.
</div>

1. En la aplicación FreeStyle LibreLink o FreeStyle Libre 3, vaya a Compartir / Aplicaciones conectadas.
2. Abra Conectar / Gestionar LibreLinkUp.
3. Pulse `Añadir conexión` e introduzca la dirección de correo electrónico que desea utilizar para la cuenta de seguidor.
4. Acepte la invitación enviada a esa dirección de correo electrónico.
5. Instale la [aplicación LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) en su iPhone y complete la configuración de la cuenta de seguidor invitada.
6. Confirme que puede ver su propia gráfica de glucosa en LibreLinkUp.
7. Abra FLwatch e introduzca las credenciales de la cuenta de seguidor en la pestaña `Conectar`.

La dirección de correo electrónico de la cuenta de seguidor puede ser la misma que la utilizada para LibreView. Si la cuenta de seguidor tiene más de una conexión, elija después de iniciar sesión a la persona cuyas lecturas debe mostrar FLwatch.

A continuación, puede cerrar o desinstalar la aplicación LibreLinkUp. Es posible que vuelva a necesitarla más adelante para aceptar condiciones de uso o políticas de privacidad actualizadas, o para comprobar que la cuenta y la conexión siguen funcionando.

La [guía paso a paso de LibreLinkUp](https://www.librelinkup.com/articles/getting-started) ofrece más ayuda.

<div class="notice-note">
<strong>Compatibilidad con la API de LibreLinkUp</strong>
<br>
FLwatch es compatible actualmente con la API 4.x de LibreLinkUp. La API 5.0.0 de LibreLinkUp todavía no es compatible. Si la API 4.x se desactiva en el futuro, los datos de glucosa de LibreLinkUp en FLwatch podrían dejar de funcionar sin previo aviso. Las funciones relacionadas con la IOB y los demás métodos de conexión seguirán funcionando.
</div>

### Configurar Dexcom Share

Los sensores Dexcom G6, Dexcom G7 y Dexcom ONE+ pueden proporcionar lecturas de glucosa mediante Dexcom Share.

1. Active Share en la aplicación Dexcom. Dexcom exige que se invite al menos a un seguidor antes de poder activar Share.
2. En una instalación nueva, seleccione `Dexcom` en el selector de CGM. FLwatch abrirá automáticamente la pantalla de conexión de Dexcom Share.
3. Inicie sesión con la dirección de correo electrónico y la contraseña de la cuenta Dexcom utilizada por el portador del sensor —la misma cuenta que se utiliza en la aplicación Dexcom del iPhone del portador— y pulse `Conectar`. FLwatch detecta automáticamente la región de la cuenta.

No utilice las credenciales de un seguidor. Dexcom Share solo facilita a las aplicaciones de terceros las lecturas del propio portador cuando se utiliza la cuenta de este.

Si la aplicación para Apple Watch no estaba instalada cuando realizó la conexión, instálela y pulse de nuevo `Conectar` para transferir las credenciales. La conexión de Dexcom Share que utiliza FLwatch no es oficial y puede modificarse o restringirse sin previo aviso.

### Latido de Bluetooth para conexiones a la nube

Al utilizar LibreLinkUp o Dexcom Share, las alertas de FLwatch para niveles bajos y altos de glucosa requieren el latido de Bluetooth. Actívelo en `Configuración > Latido de Bluetooth` y seleccione el transmisor de sensor cercano. FLwatch no puede enviar estas alertas con una conexión a la nube mientras el latido esté desactivado; siga utilizando las alertas del fabricante del sensor como alertas principales.

La conexión Bluetooth directa con FreeStyle Libre 3 y FreeStyle Libre 3+ no utiliza este ajuste.

### Funciones de insulina

Para configurar el cálculo de insulina o registrar una dosis, pulse la etiqueta `IOB` en la pantalla de inicio.

Tipos de insulina compatibles actualmente:

- Insulina de acción rápida, como Novolog y Novorapid
- Insulina de acción ultrarrápida, como Fiasp y Lyumjev

La calculadora integrada utiliza el tamaño de la porción y una relación insulina/carbohidratos configurable. Se pueden añadir más tipos de insulina bajo petición.

### Consejos para Apple Watch, Siri y Atajos

- Para mantener la gráfica de glucosa visible en el Apple Watch durante una hora, abra los ajustes del reloj o la aplicación `Watch` en el iPhone. Vaya a `General > Volver al reloj`, seleccione FLwatch y elija `Después de 1 hora`.
- Coloque un widget o una complicación en la pantalla de inicio, la pantalla de bloqueo o la esfera para acceder rápidamente a FLwatch.
- Las actividades en directo del iPhone pueden duplicarse en la Pila Inteligente del Apple Watch a partir de watchOS 11.
- Siri y Atajos pueden mostrar o leer en voz alta su valor actual de glucosa y registrar dosis de insulina.
- Para acceder sin usar las manos, cree un atajo que abra FLwatch, asígnele una frase como `gráfica de glucosa` y active `Mostrar en Apple Watch` si lo desea.

### Notas técnicas

FLwatch utiliza el modelo exponencial de insulina de LoopKit. El modelo usa tres parámetros: `actionDuration`, `peakActivityTime` y `delay`.

- Para la insulina de acción rápida, los parámetros son 360, 75 y 10 minutos.
- Para la insulina de acción ultrarrápida, los parámetros son 360, 55 y 10 minutos.

### Estado del proyecto

FLwatch es un proyecto experimental de código abierto. Utilícelo con precaución. Se ofrece sin garantía y se utiliza bajo su propia responsabilidad.

FLwatch también está disponible para pruebas beta en [TestFlight](https://testflight.apple.com/join/HwgkwcGz).

### Asistencia y comentarios {#support}

Para obtener ayuda, abra una [incidencia en GitHub](https://github.com/poml88/FLwatch/issues), inicie un [debate en GitHub](https://github.com/poml88/FLwatch/discussions) o envíe un correo electrónico a **flwatch [at] cmdline [dot] net**.

Sus comentarios son bienvenidos y pueden enviarse por los mismos canales.

### Donaciones

Las donaciones son siempre bienvenidas.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="Logotipo de PayPal" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="Logotipo de Buy Me a Coffee" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

### Créditos

También puede consultar estos proyectos:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Todos los nombres de productos, marcas comerciales y marcas registradas son propiedad de sus respectivos titulares. Su uso aquí tiene únicamente fines de identificación y no implica afiliación ni respaldo por parte de los titulares de las marcas.

FLwatch no tiene ninguna relación con Abbott Diabetes Care Inc. ni con Dexcom, Inc. y no cuenta con el respaldo de estas empresas.
