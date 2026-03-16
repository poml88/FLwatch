---
layout: landing
title: "FLwatch – Gráficas de glucosa e insulina para iPhone y Apple Watch"
description: "FLwatch es una aplicación gratuita y de código abierto que muestra gráficas de glucosa, insulina activa (insulin-on-board) y actividad con widgets en iPhone y Apple Watch utilizando datos de LibreLinkUp."
lang: es
permalink: /es/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch Gráfico glucosa sensor"
---



***Advertencia: ¡Este proyecto es altamente experimental! Utilice esta aplicación con precaución y extremo cuidado. No tome decisiones imprudentes basándose en el software. No utilice este software si no está seguro. No utilice esta aplicación para tomar decisiones médicas. No ofrece absolutamente ninguna garantía. ¡Úsela bajo su propia responsabilidad!***

Este software es gratuito y de código abierto. Se ha desarrollado para satisfacer necesidades personales, pero todo el mundo debería poder beneficiarse de él.

### Uso {#usage}
***Instalación:*** Asegúrese de que la aplicación watchOS está instalada, idealmente antes de iniciar la aplicación iOS. Dependiendo de su configuración, la aplicación watchOS se instala automáticamente o debe instalarse a través de la aplicación «Watch» del teléfono.
- @TypeOneCallum hizo un excelente [video tutorial de configuración](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB) (¡Gracias!). Si lo ves, la configuración será mucho más fácil.
- La aplicación necesita iOS 18 y watchOS 10.5
- TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- La configuración se realiza en la aplicación iOS y luego se transfiere a la aplicación watchOS. Esto solo funciona si la aplicación watchOS está instalada en el reloj.
- ***Establecimiento de la conexión entre las aplicaciones:*** Para que todo funcione, primero debe invitarse a sí mismo a convertirse en su propio seguidor. *Las credenciales de LibreView no funcionan.* Para ello, en la aplicación LibreLink / Libre 3, en Compartir / Aplicaciones conectadas, hay un elemento Conectar / Administrar LibreLinkUp. Pulse «Añadir conexión» e introduzca la dirección de correo electrónico que desea utilizar para la cuenta de seguidor, y se enviará una invitación a esa dirección (la dirección de correo electrónico puede ser la misma que la de LibreView). A continuación, para configurar la cuenta de seguidor de LibreLinkUp, instala la [aplicación LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) en el teléfono y sigue las instrucciones utilizando la dirección de correo electrónico que acabas de invitar. Hay una [guía paso a paso](https://www.librelinkup.com/articles/getting-started) que puede resultarle útil. Asegúrese de que puede ver su propio gráfico de glucosa en sangre en la aplicación LibreLinkUp. Por último, abra FLwatch e introduzca las credenciales de la cuenta de seguidor, como se indica a continuación. Actualmente, FLwatch solo admite un paciente seguido por cada cuenta de seguidor.
- A continuación, puede cerrar o desinstalar la aplicación LibreLinkUp, pero es posible que la necesite más adelante para aceptar los nuevos Términos de uso, Políticas de privacidad o simplemente para comprobar que la cuenta o la conexión funcionan.
- Para conectarse a su cuenta de seguidor de LibreLinkUp, introduzca sus credenciales en FLwatch en la pestaña «Conectar». Si la aplicación watchOS está instalada, las credenciales se transfieren a la aplicación del reloj. Es posible volver a transferir las credenciales pulsando de nuevo el botón «conectar».
- La obtención y visualización de los datos puede tardar hasta un minuto.
- Para utilizar el cálculo de insulina, pulse la etiqueta IOB en la pantalla de inicio. Los tipos de insulina compatibles actualmente son: acción rápida (Novolog, Novorapid, etc.) y acción ultrarrápida (Fiasp, Lyumjev, etc.). Se pueden añadir más insulinas bajo petición. *Por favor, avíseme.*
  - La aplicación utiliza el modelo exponencial de LoopKit. El modelo tiene tres parámetros: actionDuration, peakActivityTime y delay. Para la insulina de acción rápida, los parámetros son 360, 75 y 10 minutos; para la insulina de acción ultrarrápida, los parámetros son 360, 55 y 10 minutos.
- Hay una configuración para mantener el gráfico de glucosa durante una hora en la pantalla del reloj: tanto en el reloj como en la aplicación «Watch» del teléfono, vaya a Ajustes — General — Volver al reloj, desplácese hacia abajo y pulse en FLwatch y seleccione «Después de 1 hora». De esta forma, FLwatch permanece durante 1 hora en primer plano y recibe un número razonable de actualizaciones (por ejemplo, cada minuto).
- La forma más fácil de iniciar la aplicación del teléfono o del reloj es colocando un widget/complicación en la pantalla de inicio, la pantalla de bloqueo, la esfera del reloj o donde sea, y pulsando sobre él.
- Para utilizar Siri y abrir la aplicación sin usar las manos, puedes crear un acceso directo en el teléfono llamado, por ejemplo, «gráfico de glucosa» o «azúcar en sangre». Este acceso directo solo abre FLwatch. Selecciona la opción de acceso directo «mostrar en el reloj». Ahora, si activas Siri, solo tienes que decir «gráfico de glucosa» y, voilà, aparecerá la aplicación FLwatch y su gráfico.
Lo mismo funciona en el teléfono.

### Características 
* Gráfico de glucosa en sangre en el teléfono y el reloj
* Gráfico interactivo en el teléfono para mostrar valores individuales con solo tocar la pantalla
* Modo de pantalla siempre encendida en el teléfono
* Compatible con insulinas de acción rápida y acción ultrarrápida
* Cálculo de insulina a bordo (IOB)
* Gráfico de insulina a bordo
* Gráfico de actividad de la insulina
* Widgets de iOS y widgets de pantalla de bloqueo con y sin gráfico(s)
* Live Activities
* Widget de modo de espera
* Widgets/complicaciones de watchOS
* Compatibilidad con CarPlay mediante widgets y Live Activities
* Exportación de dosis de insulina y datos de glucosa a Apple Health

### Tareas pendientes
- Implementar actividad de entrenamiento

### Asistencia y comentarios {#support}
Para obtener asistencia, abra un ticket, inicie un debate o envíe un correo electrónico a **flwatch [ a t ] cmdline [ d o t ] net**. Agradecemos cualquier comentario. Utilice los mismos métodos que para la asistencia.

### Donaciones... 
 ¡siempre son bienvenidas!
- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40">   [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40">   [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)


{% include screenshots.html %}

Echa un vistazo también a estos proyectos:

### Créditos: 
[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard]( https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Todos los nombres de productos y empresas, marcas comerciales, marcas de servicio, marcas registradas y marcas de servicio registradas son propiedad de sus respectivos titulares. Su uso tiene fines informativos y no implica ninguna afiliación ni respaldo por parte de estos. Nota: esta aplicación no tiene ninguna relación con Abbott Diabetes Care Inc. ni cuenta con su respaldo.
