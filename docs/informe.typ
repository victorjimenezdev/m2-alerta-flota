#include "estilo.typ"
#import "diagrama.typ": flujo
#set document(title: "Sistema de alerta para flota vehicular", author: "Victor Camilo Jimenez Vargas")
#set text(font: "Times New Roman", size: 11pt, lang: "es")
#set page(paper: "a4", margin: 23mm, numbering: "1")
= Sistema de alerta para flota vehicular
*Módulo 2 · Reto de arquitectura* \
Estudiante: Victor Camilo Jimenez Vargas \
Diplomado en Arquitectura de Software y Cloud Computing · 24 de noviembre de 2026

Este informe evalúa si una sola instancia puede registrar la carga de la flota y avisar a tiempo de una emergencia. La prueba permite seguir el evento desde el generador de carga k6 hasta el receptor local de correo. La llegada al buzón personal requiere una medición adicional durante la demostración.

== Qué plazo gobierna el diseño

El reto exige procesar 1.000 eventos en 30 segundos y que el aviso de emergencia llegue a Gmail antes de 30 segundos. La puntuación máxima por entrega corresponde a menos de 15 segundos (Pontificia Universidad Javeriana Cali, s. f.-a, pp. 1 a 3 y 6). Priorizo el desempeño porque la utilidad del aviso depende de cuándo lo recibe el destinatario. Guardar todos los eventos conserva el historial, pero por sí solo dice poco sobre el tiempo que espera el operador.

== Recorrido de un evento

#flujo

Un solo proceso recibe el JSON de la flota. Valida el tipo de evento, la placa, el estado y el rango de las coordenadas. Cada solicitud obtiene un identificador después de que SQLite confirma la escritura. Las posiciones terminan su recorrido allí. Una emergencia queda marcada como pendiente en esa misma operación, de modo que una interrupción entre la respuesta HTTP y el envío deja trabajo recuperable.

El trabajador consulta las alertas pendientes cada 100 ms cuando está ocioso. El mensaje identifica la placa, el estado y la hora de recepción del evento. En la ruta de demostración, el trabajador codifica el mensaje en base64url y usa el método de envío de Gmail con el permiso OAuth de envío (Google, 2026). En el ensayo sustituí el proveedor por un receptor SMTP local para observar el mensaje sin depender de una cuenta externa.

== Decisiones y tácticas

El endpoint recibe las solicitudes directamente. El promedio exigido supera 33 solicitudes por segundo. El reto limita la puerta de enlace (API Gateway) a 15 solicitudes por segundo si se usa ese componente (Pontificia Universidad Javeriana Cali, s. f.-a, p. 3). Cubrir la diferencia exigiría capacidad de ráfaga. La conexión directa permite ensayar la capacidad del proceso sin introducir esa condición. La demostración se ejecuta en la interfaz local y utiliza una sola instancia, dentro del máximo de diez.

Separar la recepción y la notificación introduce concurrencia. Aunque el proveedor tarde en responder, el receptor puede seguir registrando posiciones. La consulta indexada selecciona únicamente emergencias pendientes. La presentación del módulo vincula el desempeño con la gestión del trabajo y la introducción de concurrencia (Pontificia Universidad Javeriana Cali, s. f.-b).

#pagebreak()
== Recuperación y límites

La persistencia y el reintento son tácticas de recuperación. Una respuesta de error del proveedor deja la alerta pendiente y habilita otro intento transcurridos cinco segundos. Así, una interrupción transitoria del correo puede resolverse sin volver a transmitir el evento del vehículo. La base persiste al reiniciar el proceso con el mismo archivo. Si el proveedor acepta el mensaje y el proceso cae antes de registrar esa aceptación, el siguiente intento puede duplicarlo. El identificador común permite investigar ese caso. En una prueba separada se apagó el receptor local. Tras dos rechazos y un reinicio del servicio, el trabajador entregó al receptor el mismo aviso pendiente (logs/recovery-local.log). La caída del equipo interrumpe la recepción.

== Qué mostró la ejecución

El generador local reprodujo las 1.000 iteraciones compartidas entre diez usuarios virtuales del ejemplo docente. Envió 999 posiciones y una emergencia. El reloj del mismo equipo registró las horas de k6 y del servicio. El identificador 999 corresponde a la emergencia en esta ejecución; el orden de confirmación de escrituras puede variar por concurrencia.

#table(columns: (1.1fr, 1.35fr),
  [Observación], [Resultado],
  [Carga aceptada], [1.000 respuestas HTTP 200 y cero fallidas],
  [Comprobación en SQLite], [999 posiciones, una emergencia y cero pendientes],
  [Primera y última recepción], [22:20:05.994 a 22:20:30.192 UTC (24,198 s)],
  [Duración HTTP, percentil 95], [12,08 ms],
  [Última iteración y recepción de emergencia], [22:20:30.192 UTC en ambos registros],
  [Aceptación del receptor SMTP local], [22:20:30.245 UTC (53 ms tras la recepción)],
)

El registro del receptor conserva el asunto de emergencia, la placa ABC-099 y el estado PANIC. Los archivos de k6, del servidor y del receptor permiten seguir el mismo aviso. Los 53 ms describen el transporte de prueba dentro del equipo. Para evaluar la rúbrica de entrega a Gmail se necesitan dos observaciones adicionales: la confirmación de la API y la cabecera de recepción del mensaje en el buzón. Durante la demo, el presentador debe comparar ambas horas con el último envío de k6 y conservar la hora de entrada de la emergencia.

== Conclusión

La base conserva los 1.000 eventos recibidos en 24,198 segundos. Una sola instancia atendió la carga dentro de los 30 segundos exigidos. El trabajador emitió el aviso de la única emergencia. La prueba acredita la recepción y el aviso local. La llamada HTTPS con OAuth a Gmail y la llegada al buzón quedaron fuera de la medición.

#pagebreak()
#align(center, strong[Referencias])
#set par(hanging-indent: 1.27cm, leading: 1em, spacing: 1em)
Google. (2026, 15 de abril). _Method: users.messages.send_. Google for Developers. #linebreak() #text(size: 9pt)[#link("https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send")]

Pontificia Universidad Javeriana Cali. (s. f.-a). _Actividad - Reto 2: Descripción del reto_ [Guía de actividad]. Brightspace. #linebreak() #text(size: 9pt)[#link("https://educacioncontinua.javerianacali.edu.co/d2l/le/content/407729/fullscreen/3125257/View")]

Pontificia Universidad Javeriana Cali. (s. f.-b). _Desempeño (performance)_ [Presentación interactiva]. Genially. #link("https://view.genially.com/683a077a59f7371b934a61fa")
