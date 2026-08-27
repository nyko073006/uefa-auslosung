# Zielarchitektur

Die erste Version sollte die App in klar getrennte Schichten zerlegen:

## 1. Domain

Die Domain enthaelt die Fachobjekte und die Regeln.

- `Team`
- `Pot`
- `Association`
- `Matchup`
- `DrawState`
- `DrawConstraint`

## 2. Draw Engine

Die Draw Engine fuehrt die Simulation aus und entscheidet, welches Los gezogen werden darf.

- Eingang: Teams, Toepfe, Regeln, Seed
- Ausgang: Ergebnisse, Zwischenstaende, Ablehnungen und Begruendungen

Wichtig ist, dass diese Schicht ohne UI testbar bleibt.

## 3. Presentation Layer

Die UI zeigt den Ablauf an und triggert die naechsten Schritte.

- Setup-Ansicht fuer Parameter und Teams
- Draw-Ansicht fuer die laufende Simulation
- Ergebnis-Ansicht fuer die fertige Auslosung
- Historie- oder Debug-Ansicht fuer Nachvollziehbarkeit

## 4. State Management

Ein ViewModel oder eine kleine State-Haltung verbindet UI und Engine.

- UI steuert nur Eingaben und Navigation
- Engine liefert nur fachliche Ergebnisse
- Keine Regelentscheidung direkt in der View

## 5. Tests

Die wichtigsten Tests liegen auf der Fachlogik.

- gueltige und ungueltige Paarungen
- deterministische Ergebnisse mit Seed
- Randfaelle bei gesperrten Losen
- Vollstaendigkeit einer Auslosung

