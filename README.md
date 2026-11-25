# Módulo 2 · Sistema de alerta para flota vehicular

**Estudiante: Victor Jimenez**

El servicio recibe posiciones y emergencias en `POST /events`. Cada respuesta 200 identifica un evento guardado en SQLite. Un trabajador independiente busca emergencias pendientes y entrega el aviso a la API de Gmail por HTTPS. Durante el ensayo, el trabajador envía el aviso a un receptor SMTP local.

## Demostración en vivo

La demo utiliza Rust y Cargo (edición 2024), el generador de carga k6 y el lector de SQLite, sqlite3. Abra dos terminales en la carpeta del proyecto. Compile con `cargo build --locked`. Conserve una base distinta por ejecución para comparar los 1.000 eventos de cada prueba. El servicio escucha en la interfaz local del equipo.

Para la prueba con Gmail, autorice una cuenta remitente con el siguiente alcance OAuth (`https://www.googleapis.com/auth/gmail.send`). Un token de acceso vigente sirve durante la sesión. Para obtenerlo con un cliente OAuth propio, active Gmail API en su proyecto, configure su cuenta como usuario de prueba cuando corresponda y autorice ese alcance. El [OAuth 2.0 Playground de Google](https://developers.google.com/oauthplayground/) permite seleccionar el alcance, autorizar y canjear el código por un token. Para un cliente propio de tipo web, registre primero la URL de redirección que muestra el Playground y seleccione el cliente en su configuración. Guarde el token en el archivo local de configuración. La [referencia de Gmail](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send) describe el permiso de envío.

Copie la plantilla con `cp .env.example .env` y edite `.env` en la carpeta del proyecto. Para enviar a Gmail, cambie `MAIL_MODE` a `gmail`. Complete `GMAIL_FROM` con la cuenta autorizada, `ALERT_TO` con el destinatario y `GMAIL_ACCESS_TOKEN` con el token. Git ignora el archivo local. Para renovar el token, actualice el archivo y reinicie el servicio con la misma base.

Ejecute `cargo run --locked` desde la carpeta del proyecto.

En la segunda terminal, ejecute `cargo run --locked -- load-test`. El script local reproduce la carga publicada de 10 usuarios virtuales y 1.000 iteraciones, con un máximo de 30 s. Emite una emergencia en la última iteración asignada. El lanzador usa LISTEN del mismo archivo para construir la URL de k6. El script del docente puede sustituir al local cuando esté disponible.

1. Compruebe los tres umbrales de k6: 1.000 iteraciones completas, 100 % de comprobaciones exitosas y cero peticiones fallidas. Anote el identificador y la hora UTC de la solicitud de emergencia.
2. Compare el identificador con las líneas `emergency_received` y `gmail_accepted` del servicio. El identificador debe coincidir en ambas líneas.
3. Abra el mensaje en el buzón de destino. En «Mostrar original», identifique el instante de recepción con zona horaria y conserve esa evidencia junto al registro de k6. Use el mensaje de la ejecución actual. La meta es recibirlo antes de 30 s desde la entrada de la emergencia. La franja superior exige menos de 15 s. Registre también la diferencia respecto del último envío de k6.
4. Consulte la base usada por el servidor con la consulta siguiente. Deben aparecer 999 posiciones, una emergencia y un envío aceptado para el script incluido.

```sql
SELECT json_extract(payload,'$.type') AS type, count(*) AS total,
       count(accepted) AS accepted
FROM events GROUP BY 1;
```

## Ensayo local y evidencia

Inicie un receptor de prueba que escuche en 127.0.0.1:1025. En la máquina del ensayo se utilizó `/usr/bin/python3 -u -m smtpd -n -c DebuggingServer 127.0.0.1:1025` con Python 3.9. En la copia local de .env deje MAIL_MODE=local-test y defina EVENT_DB=ensayo.sqlite. En otra terminal ejecute `cargo run --locked` y lance k6 desde una tercera. Para repetir con conteos independientes, cambie el nombre de la base.

En `logs/` están el resumen de k6, las marcas UTC del servicio, el mensaje capturado por el receptor local y los conteos de SQLite. Los identificadores pueden variar porque las solicitudes se procesan de forma concurrente. El [informe](docs/informe.typ) y la [presentación](docs/presentacion.typ) están en formato editable. Para generar los PDF, siga la [guía de compilación](docs/REGENERAR.md).
