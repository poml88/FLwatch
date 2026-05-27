---
layout: landing
title: "FLwatch – Gráficas de glucosa e insulina para iPhone y Apple Watch"
description: "FLwatch es una aplicación gratuita y de código abierto que muestra gráficas de glucosa, insulina activa (insulin-on-board) y actividad con widgets en iPhone y Apple Watch utilizando datos de LibreLinkUp."
lang: es
permalink: /es/
image: /assets/images/app-preview-optimized.png
hero_title: "FLwatch Gráfico glucosa sensor"
---

***Advertencia: FLwatch es un proyecto altamente experimental. Utilice esta aplicación con precaución y extremo cuidado. No tome decisiones médicas basándose en este software. Se ofrece sin ninguna garantía y se utiliza bajo su propia responsabilidad.***

<div class="notice-note">
<strong>Nota importante</strong>
<br>
FLwatch actualmente es compatible con la API 4.x de LibreLinkUp. Abbott ha lanzado la API 5.0.0, que aún no es compatible.
<br>
Si Abbott desactiva la API 4.x en el futuro, los datos de glucosa en FLwatch podrían dejar de funcionar sin previo aviso. Las funciones relacionadas con IOB seguirán funcionando.
</div>

Este software es gratuito y de código abierto. Se ha desarrollado a partir de necesidades personales, pero todo el mundo debería poder beneficiarse de él.

### Resumen rápido
- Muestra gráficas de glucosa, insulina activa y actividad en iPhone y Apple Watch
- Incluye widgets, complicaciones, Live Activities, reflejo en la pila inteligente del Apple Watch y exportación a Apple Health
- Admite registro manual de insulina y una calculadora integrada de carbohidratos a insulina
- Requiere iOS 18 y watchOS 10.5
- Para pruebas beta, FLwatch también está disponible en TestFlight: [https://testflight.apple.com/join/HwgkwcGz](https://testflight.apple.com/join/HwgkwcGz)
- Compatible con sensores Freestyle Libre 2 y 3 mediante LibreLinkUp (solo versión 4.x de la API) — utiliza credenciales de una cuenta seguidora de LibreLinkUp, no credenciales de LibreView
- Compatible con sensores Dexcom G6, G7 y ONE+ mediante Dexcom Share — inicie sesión con el correo y la contraseña de la cuenta Dexcom en la que está configurado el sensor (las mismas credenciales que la aplicación Dexcom en el teléfono del portador). «Share» debe estar activado en la aplicación Dexcom, lo que requiere invitar al menos a un seguidor. No inicie sesión con una cuenta de seguidor — Dexcom solo expone las lecturas del portador a aplicaciones de terceros.

### Inicio rápido {#usage}
1. Instale FLwatch desde la [App Store]({{ site.appstore_url }}). {% include appstore_badge.html %}
2. Asegúrese de que la aplicación para watchOS esté instalada en su Apple Watch, idealmente antes de abrir la aplicación para iOS.
3. Cree y verifique una conexión de LibreLinkUp como su propio seguidor.
4. Introduzca en FLwatch las credenciales de la cuenta seguidora de LibreLinkUp en la pestaña `Connect`.
5. Espere hasta un minuto para que aparezcan los datos.

Si la aplicación para watchOS está instalada, los ajustes y las credenciales introducidos en la aplicación para iOS se transfieren a la aplicación del reloj.

- @TypeOneCallum hizo un muy útil [video tutorial de configuración](https://youtu.be/LLTnRuR9p-0?si=7pR8ZvmEVUktW4ZB). Verlo puede hacer que la configuración sea mucho más sencilla.

### Configurar LibreLinkUp
Para que FLwatch funcione, primero tiene que invitarse a sí mismo para convertirse en su propio seguidor.

*Las credenciales de LibreView no funcionan.*

1. En la aplicación LibreLink o Libre 3, vaya a Share / Connected Apps.
2. Abra Connect / Manage LibreLinkUp.
3. Pulse `Add Connection` e introduzca la dirección de correo electrónico que desea usar para la cuenta seguidora.
4. Acepte la invitación enviada a esa dirección de correo.
5. Instale la [aplicación LibreLinkUp](https://apps.apple.com/us/app/librelinkup/id1234323923) en su iPhone y complete allí la configuración de la cuenta seguidora invitada.
6. Confirme que puede ver su propia gráfica de glucosa en LibreLinkUp.
7. Abra FLwatch e introduzca allí las credenciales de la cuenta seguidora.

La dirección de correo de la cuenta seguidora puede ser la misma que utiliza para LibreView.

También puede resultar útil esta [guía paso a paso de LibreLinkUp](https://www.librelinkup.com/articles/getting-started).

Actualmente, FLwatch solo admite un paciente seguido por cada cuenta seguidora.

Después, la aplicación LibreLinkUp puede cerrarse o incluso desinstalarse. Aun así, puede volver a ser necesaria más adelante para aceptar nuevos Términos de uso o Políticas de privacidad, o simplemente para comprobar que la cuenta y la conexión siguen funcionando.

### Conectar FLwatch
- Introduzca las credenciales de su cuenta seguidora de LibreLinkUp en la pestaña `Connect` de FLwatch.
- Si la aplicación para watchOS está instalada, las credenciales se transfieren a la aplicación del reloj.
- Si es necesario, puede volver a transferir las credenciales pulsando de nuevo el botón `Connect`.
- La obtención y visualización de los datos puede tardar hasta un minuto.

### Funciones de insulina
Para usar el cálculo de insulina, pulse la etiqueta `IOB` en la pantalla principal.

Tipos de insulina compatibles actualmente:
- Insulina de acción rápida, como Novolog y Novorapid
- Insulina de acción ultrarrápida, como Fiasp y Lyumjev

FLwatch también admite el registro manual de insulina e incluye una calculadora integrada de carbohidratos a insulina.

Se pueden añadir más tipos de insulina bajo petición.

### Consejos para el reloj y Siri
- Para mantener la gráfica de glucosa visible en el reloj durante una hora, abra en el reloj o en la app `Watch` del iPhone la ruta `Ajustes > General > Volver al reloj`, desplácese hasta FLwatch y elija `Después de 1 hora`. Así, FLwatch permanece más tiempo en primer plano y recibe un número razonable de actualizaciones, por ejemplo aproximadamente cada minuto.
- La forma más sencilla de iniciar la aplicación en el teléfono o en el reloj es colocar un widget o una complicación en la pantalla de inicio, la pantalla de bloqueo, la esfera del reloj u otro lugar cómodo y pulsarlo.
- Las Live Activities del iPhone también pueden reflejarse en la pila inteligente del Apple Watch para acceder a ellas rápidamente.
- Siri y Atajos pueden utilizarse para leer en voz alta o mostrar el valor actual de glucosa.
- Siri y Atajos también pueden utilizarse para el registro por voz de dosis de insulina o para registrar rápidamente dosis de insulina en el reloj.
- Para abrir la aplicación con Siri sin usar las manos, puede crear en el iPhone un atajo que simplemente abra FLwatch. Por ejemplo, podría llamarlo `gráfico de glucosa` o `azúcar en sangre`. Active la opción para mostrar el atajo también en el reloj. Entonces, al decir esa frase a Siri, FLwatch se abrirá directamente. Lo mismo también funciona en el iPhone.

### Características {#features}
#### Monitorización
* Gráfica de glucosa en el teléfono y el reloj
* Gráfica interactiva en el teléfono para mostrar valores individuales al tocar
* Modo de pantalla siempre encendida en el teléfono

#### Insulina
* Compatible con insulinas bolus de acción rápida y ultrarrápida
* Cálculo de insulina activa (IOB)
* Gráfica de insulina activa
* Gráfica de actividad de la insulina
* Registro manual de insulina
* Calculadora integrada de carbohidratos a insulina

#### Integración con el sistema
* Widgets de iOS y widgets de pantalla de bloqueo con y sin gráfica(s)
* Live Activities en iPhone, incluida la duplicación en la pila inteligente del Apple Watch y en CarPlay
* Widget del modo En reposo
* Widgets y complicaciones de watchOS
* Compatibilidad con CarPlay mediante la app de CarPlay, widgets y Live Activities
* Exportación de dosis de insulina y datos de glucosa a Apple Health
* Compatibilidad con Siri y Atajos para mostrar la glucosa, leer la glucosa en voz alta y registrar rápidamente dosis de insulina
* El Bluetooth heartbeat permite actualizaciones casi cada minuto y alarmas de glucosa baja en iPhone, Apple Watch y CarPlay

### Notas técnicas
FLwatch utiliza el modelo exponencial de insulina de LoopKit. El modelo usa tres parámetros: `actionDuration`, `peakActivityTime` y `delay`.

- Para la insulina de acción rápida, los parámetros son 360, 75 y 10 minutos.
- Para la insulina de acción ultrarrápida, los parámetros son 360, 55 y 10 minutos.

### Tareas pendientes
- Implementar actividad de entrenamiento

### Asistencia y comentarios {#support}
Para obtener ayuda, abra un [issue en GitHub](https://github.com/poml88/FLwatch/issues), inicie una [discusión en GitHub](https://github.com/poml88/FLwatch/discussions) o envíe un correo electrónico a **flwatch [at] cmdline [dot] net**.

Los comentarios son muy bienvenidos y pueden enviarse por los mismos canales.

### Donaciones
Las donaciones siempre son bienvenidas.

- <img src="/assets/img/pp_cc_mark_37x23.jpg" alt="paypal logo" height="40"> [paypal.me/lovemyhusky](https://paypal.me/lovemyhusky)
- <img src="/assets/img/bmc-logo-50.png" alt="buymeacoffee logo" height="40"> [buymeacoffee.com/poml88](https://buymeacoffee.com/poml88)

{% include screenshots.html %}

### Créditos
Eche también un vistazo a estos proyectos:

[DiaBLE](https://github.com/gui-dos/DiaBLE), [LoopKit](https://github.com/LoopKit), [GlucoseDirect](https://github.com/creepymonster/GlucoseDirect), [Nightguard](https://github.com/nightscout/nightguard), [Nightscout LibreLink Up Uploader](https://github.com/timoschlueter/nightscout-librelink-up)

Todos los nombres de productos y empresas, marcas comerciales, marcas de servicio, marcas registradas y marcas de servicio registradas son propiedad de sus respectivos titulares. Su uso tiene fines informativos y no implica ninguna afiliación ni respaldo por parte de ellos. Nota: esta aplicación no tiene ninguna relación con Abbott Diabetes Care Inc. ni con Dexcom, Inc. ni cuenta con su respaldo.
