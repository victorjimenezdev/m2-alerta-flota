use axum::{Json, Router, extract::State, http::StatusCode, routing::post};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use chrono::{SecondsFormat, Utc};
use lettre::{Message, SmtpTransport, Transport, message::Mailbox};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use std::{env, error::Error, thread, time::Duration};

type Failure = Box<dyn Error + Send + Sync>;

#[derive(Deserialize, Serialize)]
struct Coordinates {
    latitude: f64,
    longitude: f64,
}

#[derive(Deserialize, Serialize, PartialEq)]
enum Kind {
    Emergency,
    Position,
}

#[derive(Deserialize, Serialize)]
struct Event {
    #[serde(rename = "type")]
    kind: Kind,
    vehicle_plate: String,
    coordinates: Coordinates,
    status: String,
}

fn now() -> String {
    Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true)
}

fn record(path: &str, event: Event, received: String) -> Result<i64, Failure> {
    let db = Connection::open(path)?;
    let pending = event.kind == Kind::Emergency;
    db.execute(
        "INSERT INTO events(payload, received, pending) VALUES (?1, ?2, ?3)",
        params![serde_json::to_string(&event)?, received, pending],
    )?;
    let id = db.last_insert_rowid();
    if pending {
        println!("{received} emergency_received id={id}");
    }
    Ok(id)
}

async fn receive(
    State(path): State<String>,
    Json(event): Json<Event>,
) -> Result<String, StatusCode> {
    if event.vehicle_plate.trim().is_empty()
        || event.status.trim().is_empty()
        || !(-90.0..=90.0).contains(&event.coordinates.latitude)
        || !(-180.0..=180.0).contains(&event.coordinates.longitude)
    {
        return Err(StatusCode::UNPROCESSABLE_ENTITY);
    }
    let received = now();
    tokio::task::spawn_blocking(move || record(&path, event, received))
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .map(|id| id.to_string())
        .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)
}

enum Delivery {
    Test(SmtpTransport),
    Gmail(String),
}

struct Mailer {
    delivery: Delivery,
    from: Mailbox,
    to: Mailbox,
}

impl Mailer {
    fn configure() -> Result<Self, Failure> {
        let local = env::var("MAIL_MODE").as_deref() == Ok("local-test");
        let (delivery, from, to) = if local {
            (
                Delivery::Test(
                    SmtpTransport::builder_dangerous("127.0.0.1")
                        .port(1025)
                        .timeout(Some(Duration::from_secs(10)))
                        .build(),
                ),
                "fleet@example.invalid".into(),
                "receiver@example.invalid".into(),
            )
        } else {
            let from = env::var("GMAIL_FROM")?;
            let to = env::var("ALERT_TO")?;
            let recipient: Mailbox = to.parse()?;
            if !recipient.email.domain().eq_ignore_ascii_case("gmail.com") {
                return Err("Gmail recipient required".into());
            }
            (Delivery::Gmail(env::var("GMAIL_ACCESS_TOKEN")?), from, to)
        };
        Ok(Self {
            delivery,
            from: from.parse()?,
            to: to.parse()?,
        })
    }

    fn deliver_one(&self, db: &Connection) -> Result<bool, Failure> {
        let next = db.query_row("SELECT id, payload, received FROM events WHERE pending=1 AND retry_at<=unixepoch() ORDER BY id LIMIT 1", [],
            |r| Ok((r.get::<_,i64>(0)?, r.get::<_,String>(1)?, r.get::<_,String>(2)?))).optional()?;
        let Some((id, payload, received)) = next else {
            return Ok(false);
        };
        let event: Event = serde_json::from_str(&payload)?;
        let message = Message::builder()
            .from(self.from.clone())
            .to(self.to.clone())
            .subject(format!("Fleet Emergency alert #{id}"))
            .body(format!(
                "Emergency event received at {received} UTC.\nVehicle: {}\nStatus: {}\n",
                event.vehicle_plate, event.status
            ))?;
        let result: Result<&str, Failure> = match &self.delivery {
            Delivery::Test(smtp) => smtp
                .send(&message)
                .map(|_| "smtp_accepted")
                .map_err(Into::into),
            Delivery::Gmail(token) => {
                ureq::post("https://gmail.googleapis.com/gmail/v1/users/me/messages/send")
                    .config()
                    .timeout_global(Some(Duration::from_secs(10)))
                    .build()
                    .header("Authorization", format!("Bearer {token}"))
                    .send_json(
                        serde_json::json!({"raw": URL_SAFE_NO_PAD.encode(message.formatted())}),
                    )
                    .map(|_| "gmail_accepted")
                    .map_err(Into::into)
            }
        };
        if let Err(error) = result {
            db.execute("UPDATE events SET retry_at=unixepoch()+5 WHERE id=?1", [id])?;
            eprintln!(
                "{} delivery_failed id={id} retry_in_seconds=5 error={error}",
                now()
            );
            return Ok(false);
        }
        let accepted = now();
        println!("{accepted} {} id={id}", result?);
        db.execute(
            "UPDATE events SET pending=0, accepted=?1 WHERE id=?2",
            params![accepted, id],
        )?;
        Ok(true)
    }
}

#[tokio::main(worker_threads = 2)]
async fn main() -> Result<(), Failure> {
    let mailer = Mailer::configure()?;
    let path = env::var("EVENT_DB").unwrap_or_else(|_| "events.sqlite".into());
    let db = Connection::open(&path)?;
    db.execute_batch("PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY, payload TEXT NOT NULL,
        received TEXT NOT NULL, pending INTEGER NOT NULL, accepted TEXT, retry_at INTEGER NOT NULL DEFAULT 0);
        CREATE INDEX IF NOT EXISTS alerts ON events(id) WHERE pending=1;")?;
    let listener = tokio::net::TcpListener::bind(
        env::var("LISTEN").unwrap_or_else(|_| "127.0.0.1:8082".into()),
    )
    .await?;
    println!("{} listening {}", now(), listener.local_addr()?);
    thread::spawn(move || {
        loop {
            match mailer.deliver_one(&db) {
                Ok(true) => continue,
                Ok(false) => (),
                Err(error) => eprintln!("{} outbox_error {error}", now()),
            }
            thread::sleep(Duration::from_millis(100));
        }
    });
    axum::serve(
        listener,
        Router::new()
            .route("/events", post(receive))
            .with_state(path),
    )
    .await?;
    Ok(())
}
