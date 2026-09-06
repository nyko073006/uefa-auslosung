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

> **Achtung, zwei Dinge heissen DrawEngine.** Engine und App sind parallel auf
> getrennten Branches entstanden. Seit diesem Merge liegen beide nebeneinander:
>
> - `DrawEngine/` - das **echte**, fertige Package (swift-tools 6.0, Swift Testing)
> - `Packages/DrawEngine/` - ein **8-Zeilen-Platzhalter** aus dem App-Geruest
>   (`isReady: Bool`), auf den die Wurzel-`Package.swift` zeigt (swift-tools 5.10, XCTest)
>
> Die App laeuft heute nicht auf der echten Engine, sondern auf `MockDrawEngine`
> hinter dem Protokoll `DrawEnginePort`. Die Zusammenfuehrung steht noch aus:
> `DomainStubs.swift` faellt weg, ein Adapter bildet die Engine auf den Port ab,
> und die Wurzel-`Package.swift` zieht auf das echte Package um. Offen ist dabei
> die Ablehnungs-Frage, siehe "Offene Fragen".

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

- Welche Teile duerfen vereinfacht werden? **Teilantwort:** Was heute vereinfacht
  *ist*, listet `draw-regeln.md` Abschnitt 2 ("Getroffene Annahmen und
  Vereinfachungen"). Ob diese Liste dem Anspruch des Projekts genuegt, ist eine
  Produktentscheidung und weiterhin offen.
- **Wer erklaert die Ablehnungen?** `DrawEnginePort` erwartet einen `trace` mit
  abgelehnten Kandidaten samt Begruendungstext. Die Engine liefert das **nicht**,
  sie gibt nur die gefundene Loesung als Ereignisfolge aus. Fuer Phase 4
  ("Regelablehnungen erklaeren") ist zu entscheiden, ob die Engine um
  Ablehnungs-Ereignisse erweitert wird oder die Oberflaeche die Begruendung selbst
  aus den Fachregeln ableitet. Vier weitere waehrend der Implementierung
  aufgekommene Fragen stehen in `draw-regeln.md` Abschnitt 6.

## Geklaerte Fragen

- Welche UEFA-Regelmenge soll exakt simuliert werden?
  Geklaert: genau sechs Regeln, einzeln hergeleitet in
  [`DrawEngine/Docs/draw-regeln.md`](../DrawEngine/Docs/draw-regeln.md), Abschnitt 1.
- Soll die App nur iPhone oder auch iPad unterstuetzen?
  Geklaert: iPhone zuerst, iPad-tauglich ueber adaptive Grids, keine eigenen
  Split-View-Layouts. Details in `ui-architecture.md`.

