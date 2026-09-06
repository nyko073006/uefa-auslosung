# Roadmap

## Phase 1 - Fachliche Klärung

- Auslosungsregeln dokumentieren
- Vereinfachungen explizit benennen
- Begriffe und Datenmodell festziehen

## Phase 2 - Simulationskern

- [x] Domain-Modelle bauen
- [x] Seeded Randomness einrichten
- [x] Draw Engine mit Tests absichern

**Umgesetzt** als eigenstaendiges, UI-freies Swift-Package unter `DrawEngine/`
(121 Tests gruen, deterministisch ueber Seed). Regelmenge, Annahmen, Algorithmus,
Determinismus-Vertrag und Fehlerfaelle stehen vollstaendig in
[`DrawEngine/Docs/draw-regeln.md`](../DrawEngine/Docs/draw-regeln.md); die
oeffentliche API und die SPM-Einbindung in
[`DrawEngine/README.md`](../DrawEngine/README.md).

## Phase 3 - SwiftUI-Shell

- Projektstruktur fuer SwiftUI anlegen
- Setup-, Draw- und Ergebnis-Views bauen
- Basisnavigation definieren

## Phase 4 - Nachvollziehbarkeit

- Zwischenstaende anzeigen
- Regelablehnungen erklaeren
- Debug-Ansicht fuer Testfaelle hinzufuegen

## Phase 5 - Feinschliff

- Animationen und polierte Darstellung
- Zusatzergebnisse und Export
- Letzter Testlauf vor Release

## Offene Fragen

- ~~Welche UEFA-Regelmenge soll exakt simuliert werden?~~ **Beantwortet.** Es sind
  genau sechs Regeln, einzeln hergeleitet in
  [`DrawEngine/Docs/draw-regeln.md`](../DrawEngine/Docs/draw-regeln.md), Abschnitt 1.
- Welche Teile duerfen vereinfacht werden? **Teilantwort:** Was heute vereinfacht
  *ist*, listet `draw-regeln.md` Abschnitt 2 ("Getroffene Annahmen und
  Vereinfachungen"). Ob diese Liste dem Anspruch des Projekts genuegt, ist eine
  Produktentscheidung und weiterhin offen.
- Soll die App nur iPhone oder auch iPad unterstuetzen? Weiterhin offen. Betrifft
  das Package nicht (`Package.swift`: iOS 17 / macOS 14 als Minimum), nur die
  Oberflaeche.

Bei der Implementierung sind fuenf weitere Fragen aufgekommen, gesammelt in
`draw-regeln.md` Abschnitt 6. Eine davon betrifft **Phase 4** unmittelbar: Die
Engine liefert heute **keine** Ablehnungen oder Begruendungen, sie gibt nur die
gefundene Loesung als Ereignisfolge aus. Fuer "Regelablehnungen erklaeren" ist
vorher zu klaeren, ob die Ereignisliste erweitert wird oder die Oberflaeche die
Begruendung selbst aus den Fachregeln ableitet.

