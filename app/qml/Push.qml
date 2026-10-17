/*
 * Puhuri - natiivi XMPP-viestinsovellus Ubuntu Touchille
 * Copyright (C) 2026 Reijo Kinnunen
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Lomirin push-asiakas (UBports push). Tämä on oma tiedostonsa, koska
 * `import Ubuntu.PushNotifications` ei ole olemassa kuin puhelimessa: kun
 * moduulia ei ole, Loader ei lataa tätä eikä mikään hajoa.
 */

import QtQuick 2.7
import Ubuntu.PushNotifications 0.1

Item {
    id: push

    /// Lomiri antaa laitteen tokenin tällä tunnisteella. Sen pitää olla
    /// "paketti_sovellus", sama jonka sovelluksen apparmor-profiili näkee.
    property string appId: "fi.reijo.puhuri_puhuri"
    property string token: client.token
    property string status: client.status

    /// Not `tokenChanged` - Qt already makes that one for the `token`
    /// property, and re-declaring it is an error.
    signal pushTokenChanged(string token)
    signal pushError(string message)

    PushClient {
        id: client
        appId: push.appId
        onTokenChanged: push.pushTokenChanged(token)
        onError: push.pushError(error)
    }
}
