#import "diagrama.typ": flujo
#set document(title: "Demostración del sistema de alerta", author: "Victor Jimenez")
#set page(width: 280mm, height: 158mm, margin: (x: 19mm, y: 14mm), numbering: "1")
#set text(font: "Arial", size: 18pt, lang: "es")
#set par(leading: 0.55em)
#show heading.where(level: 1): set text(size: 26pt)
= Una emergencia entre 1.000 eventos
*Módulo 2 · Sistema de alerta para flota vehicular*

Estudiante: Victor Jimenez

El generador de carga k6 simula las posiciones y emergencias de la flota durante una ventana de 30 segundos. Cuando llega un evento de tipo Emergency, el operador necesita saber qué vehículo requiere atención.

*Durante la demo:* seguir una placa desde la petición hasta el buzón y comprobar cuánto tarda el aviso.
#pagebreak()
= Dónde se separan las dos rutas
#flujo

El endpoint confirma después de guardar. Una posición queda registrada; una emergencia queda además pendiente de envío. El trabajador convierte ese evento en un mensaje con placa, estado e instante UTC.
#pagebreak()
= Tácticas para sostener la carga
- La carga exige una media de 33,33 solicitudes/s. El endpoint local recibe directamente y evita depender de la capacidad de ráfaga de una puerta de enlace.
- Desempeño: introducir concurrencia permite enviar el aviso mientras llegan posiciones. Un índice parcial dirige al trabajador hacia las emergencias pendientes.
- Disponibilidad: SQLite conserva cada emergencia pendiente para recuperarla al reiniciar. Ante un fallo del proveedor, el trabajador reintenta después de cinco segundos. Una caída entre aceptación y registro puede duplicar el aviso.
#pagebreak()
= Evidencia del ensayo local
#table(columns: (1fr, 1fr), inset: 7pt, [Carga de k6], [1.000 respuestas HTTP 200], [Base de datos], [999 posiciones + 1 emergencia], [Ventana de recepción], [24,198 s], [Duración HTTP, percentil 95], [12,08 ms], [Aceptación del correo local], [53 ms desde la recepción])

Estos tiempos corresponden al receptor local. La llegada a Gmail se mide durante la demo.
#pagebreak()
= Demostración en vivo
+ Iniciar el servicio con Gmail autorizado y una base nueva. En otra terminal, ejecutar `cargo run --locked -- load-test`.
+ Mostrar las 1.000 iteraciones, el 100 % de comprobaciones exitosas y cero fallos HTTP. Anotar la hora del último envío y el identificador de emergencia. Con el script docente, tomar el identificador del log del servicio. Comprobar los conteos en SQLite.
+ Localizar el mismo identificador en `emergency_received`, `gmail_accepted` y el asunto del mensaje.
+ Abrir «Mostrar original» en Gmail. Comparar el último envío de k6 con la recepción en el buzón. El objetivo es menos de 30 s; la franja superior exige menos de 15 s.
