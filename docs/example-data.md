# Beispiel-Daten

Diese Beispieldaten dienen als Startpunkt fuer Tests, Preview und manuelle Plausibilitaetspruefung.

## Zweck

- reproduzierbare Demos
- Testfaelle fuer die Draw Engine
- ein gemeinsames Datenmodell fuer UI und Fachlogik

## Beispiel-Seed

```text
20260827
```

## Beispiel-Teams

| Team | Pot | Verband | Gruppe |
| --- | --- | --- | --- |
| Atlas FC | 1 | A | G1 |
| Boreal United | 1 | B | G2 |
| Cinder City | 1 | C | G3 |
| Delta SC | 1 | D | G4 |
| Aurora FC | 2 | A | G1 |
| Bergen IF | 2 | B | G2 |
| Corvus Town | 2 | C | G3 |
| Dune Athletic | 2 | D | G4 |
| Argon FC | 3 | A | G1 |
| Blackridge | 3 | B | G2 |
| Cedar Vale | 3 | C | G3 |
| Drift FC | 3 | D | G4 |
| Alpine FC | 4 | A | G1 |
| Brookside | 4 | B | G2 |
| Cliffside | 4 | C | G3 |
| Dawn SC | 4 | D | G4 |

## Beispiel fuer erwartete Sperren

- Atlas FC darf nicht gegen Aurora FC antreten, wenn gleiche Verbandszugehoerigkeit gesperrt ist.
- Boreal United darf nicht gegen Bergen IF antreten, wenn gleiche Verbandszugehoerigkeit gesperrt ist.
- Ein Team darf nie gegen sich selbst oder gegen eine bereits gezogene Mannschaft gelost werden.

## Notiz fuer spaetere Erweiterung

Wenn die App eine konkrete UEFA-Runde abbildet, sollten die echten Regeln je Runde getrennt dokumentiert werden. Diese Datei bleibt dann die neutrale Beispieldatenquelle.

