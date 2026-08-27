# Regeln

Diese Datei beschreibt die fachlichen Leitplanken fuer die erste Version der Auslosungssimulation.

## Grundprinzip

Die Draw Engine muss jede Entscheidung erklaeren koennen:

- Warum ist eine Paarung erlaubt?
- Warum ist eine Paarung verboten?
- Welche Regel hat die Entscheidung ausgelost?

## Minimale Regelmenge fuer den Start

- Jede Mannschaft wird genau einmal gezogen.
- Ein Team darf nicht zweimal vorkommen.
- Die Auslosung laeuft mit einem Seed reproduzierbar.
- Sperren muessen als nachvollziehbare Regeln modelliert sein.
- UI und Regelwerk bleiben getrennt.

## Vorerst zu modellierende Sperren

- gleiche Gruppenzugehoerigkeit, falls ein Turnierabschnitt dies verlangt
- gleiche Verbandzugehoerigkeit, falls ein Turnierabschnitt dies verlangt
- pot- oder seed-basierte Einschränkungen

## Uebergreifende Anforderungen

- Jede Ablehnung braucht eine Klartext-Begruendung.
- Tests muessen gueltige und ungueltige Ziehungen abdecken.
- Vereinfachungen sind zulässig, aber muessen dokumentiert sein.

## Offene Entscheidungspunkte

- Welche exakte UEFA-Runde wird als Erstes simuliert?
- Welche Regeln sind Pflicht, welche optional?
- Soll die App eine vereinfachte oder eine streng regelkonforme Simulation liefern?

