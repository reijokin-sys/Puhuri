// SPDX-License-Identifier: AGPL-3.0-or-later
//! Notifications through Lomiri.
//!
//! The service is a plain process (not a click), so it talks to the session
//! bus directly. `gdbus` is used on purpose instead of a D-Bus crate: it is
//! one subprocess, it keeps the cross build free of an extra dependency tree,
//! and every device we target ships it. If it is ever missing, the caller
//! still gets the event - only the popup is lost.

use std::process::{Command, Stdio};

pub const APP_NAME: &str = "Puhuri";
const APP_ICON: &str =
    "/opt/click.ubuntu.com/fi.reijo.puhuri/current/assets/puhuri.png";
const DEFAULT_SOUND: &str =
    "/usr/share/sounds/lomiri/notifications/Sintonia.ogg";
const NOTIFICATION_TIMEOUT_MS: &str = "10000";

fn notification_sound() -> String {
    if let Ok(sound) = std::env::var("PUHURI_NOTIFICATION_SOUND") {
        let sound = sound.trim();
        if !sound.is_empty() {
            return sound.to_string();
        }
    }
    if let Ok(output) = Command::new("gsettings")
        .args(["get", "com.lomiri.touch.sound", "incoming-message-sound"])
        .stderr(Stdio::null())
        .output()
    {
        let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let value = value.trim_matches('\'').trim_matches('"');
        if !value.is_empty() && std::path::Path::new(value).exists() {
            return value.to_string();
        }
    }
    DEFAULT_SOUND.to_string()
}

fn notify_arguments(summary: &str, body: &str, sound: &str) -> Vec<String> {
    vec![
        "call".to_string(),
        "--session".to_string(),
        "--dest".to_string(),
        "org.freedesktop.Notifications".to_string(),
        "--object-path".to_string(),
        "/org/freedesktop/Notifications".to_string(),
        "--method".to_string(),
        "org.freedesktop.Notifications.Notify".to_string(),
        APP_NAME.to_string(),
        "0".to_string(),
        APP_ICON.to_string(),
        summary.to_string(),
        body.to_string(),
        "[]".to_string(),
        format!("{{'sound-file': <'{sound}'>}}"),
        NOTIFICATION_TIMEOUT_MS.to_string(),
    ]
}

pub fn notify(summary: &str, body: &str) -> bool {
    let sound = notification_sound();
    match Command::new("gdbus")
        .args(notify_arguments(summary, body, &sound))
        .output()
    {
        Ok(output) if output.status.success() => true,
        Ok(output) => {
            eprintln!("puhurid: ilmoituksen lähetys epäonnistui: {}",
                      String::from_utf8_lossy(&output.stderr).trim());
            false
        }
        Err(error) => {
            eprintln!("puhurid: ilmoituksen gdbus-käynnistys epäonnistui: {error}");
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn notification_payload_has_visible_timeout_icon_and_sound() {
        let args = notify_arguments(
            "Maija",
            "Moi",
            "/usr/share/sounds/lomiri/notifications/Sintonia.ogg",
        );

        assert!(
            args.iter()
                .any(|arg| arg == "/opt/click.ubuntu.com/fi.reijo.puhuri/current/assets/puhuri.png"),
            "ilmoituksella ei ole sovelluskuvaketta: {args:?}"
        );
        assert!(
            args.iter().any(|arg| arg == "{'sound-file': <'/usr/share/sounds/lomiri/notifications/Sintonia.ogg'>}"),
            "äänihint puuttuu: {args:?}"
        );
        assert_eq!(
            args.last().map(String::as_str),
            Some("10000"),
            "ilmoitus katoaa liian nopeasti: {args:?}"
        );
    }
}
