# Puhurin teemamoduulit (luotu tiedosto)

Tämä hakemisto on **generoitu**, ei käsin kirjoitettu:

```sh
tools/sync-teemat.sh
```

Skripti kopioi Puhurin kaksi omaa teemaa ja niiden perusteeman
teemat-projektista (`../ubuntu-touch-teemat`) ja nimeää ne uudelleen:

| Hakemisto | Lähde | Teema |
| --- | --- | --- |
| `PuhuriPunainen/` | `RevontuliSininen` | Revontuli punainen (oletus) |
| `PuhuriVihrea/` | `RevontuliPurppura` | Revontuli vihreä |
| `PuhuriPerus/` | `Revontuli` | perusteema, jonka päälle kaksi varianttia rakentuvat |

**Älä muokkaa näitä tiedostoja käsin** - muutos katoaa seuraavalla
`sync-teemat.sh`-ajolla. Värit muutetaan teemat-projektissa ja kopio uusitaan
täällä (ks. `docs/TEEMAT.md` ja `docs/TEEMAT-TOTEUTUS.md`).

## Lisenssi

Nämä tiedostot ovat **Canonical Ltd.:n Lomiri-teemojen johdannaisia** ja
lisenssiltään **LGPL-3.0-or-later** (jokaisen `.qml`-tiedoston alussa on
Canonicalin oma LGPL-teksti, SPDX-merkintä ja päivätty merkintä siitä, mitä
tässä kopiossa on muutettu: moduulin, tyyppien ja tiedostojen nimet on
nimetty uudelleen, ja värit tulevat `../ubuntu-touch-teemat`-projektista).
**LGPL-3.0:n teksti on tässä hakemistossa** (`LICENSE.LGPL-3.0`), ja koko
sovelluksen lisenssitilanne on `THIRD_PARTY_NOTICES.md`:ssä.

LGPL-3.0 on yhteensopiva sovelluksen AGPL-3.0-or-later-lisenssin kanssa
(LGPL-3 §3 -> GPL-3, ja AGPL-3 §13 sallii yhdistämisen GPL-3:n kanssa).

Moduulit ovat klikin **juuressa**, ei `qml/`-hakemistossa, koska teemalaturi
etsii ne QML-importtien poluilta ja `qmlscene` löytää ne työhakemistosta, joka
klikillä on klikin juuri. Tämä on mitattu puhelimessa 16.10.2026.
