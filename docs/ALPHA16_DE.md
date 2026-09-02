# Alpha16: schnellere Simulation und einstellbare Kontakte

Die zugesandten alpha15-Protokolle zeigen 4–5 FPS bei 15–16 Organismen, ohne GDScript-Fehler. Die nativen Parser-, Biologie- und Installationstests waren erfolgreich. Diese Ausgabe konzentriert sich deshalb auf vermeidbare Rechenarbeit.

## F10: Kontaktgenauigkeit

Der neue Schieberegler reicht von **0 bis 100**, Standard **85**. Er wirkt sofort auf vorhandene und später geborene Wesen. Die Einstellung wird automatisch gespeichert und gehört zu den exportierbaren Einstellungsprofilen. Erklärende Tooltips gibt es auf Deutsch, Englisch und Französisch.

Die Zahl bezeichnet eine Qualitätsstufe, keine gemessene Trefferquote. Auch bei 0 bleiben Körperkontakt, Bodenunterstützung und Weltgrenzen aktiv.

| Wert | Max. Korrekturdurchläufe | Tolerierte Körperüberschneidung, Welteinheiten | Bodenprüfung pro sichtbarem Körperteil |
| --- | ---: | ---: | --- |
| 0 | 2 | 0,180 | Mittelpunkt mit Körperausdehnung |
| 40 | 4 | 0,114 | Mittelpunkt mit Körperausdehnung |
| 85 (Standard) | 7 | 0,040 | Mittelpunkt mit Körperausdehnung |
| 100 | 8 | 0,015 | Mittelpunkt plus vier Randpunkte |

Die zusätzlichen Randprüfungen beginnen bei 90. Gerade an Hängen können niedrigere Werte kleine Überschneidungen an den Rändern zulassen. Die Korrekturdurchläufe enden früher, wenn keine Überschneidung mehr erkannt wird. Ein niedrigerer Wert hilft daher besonders bei Kontaktansammlungen oder Bodennähe; er garantiert keine bestimmte FPS-Zahl.

## Eingesparte Arbeit

- Geländekacheln speichern ihre maximale Höhe. Schwimmt oder fliegt der gesamte Körper sicher darüber, entfallen die einzelnen Bodenabfragen.
- Unveränderte Pose, Position, Ausrichtung, Gelände und Qualitätsstufe erlauben die Wiederverwendung der Bodenprüfung. Wachstum, Gelenkbewegung, Geländewechsel und Einstellungen machen diesen Zwischenspeicher ungültig. Eine seitliche Wandkorrektur erzwingt eine neue Prüfung des veränderten Bodenbereichs.
- Detaillierte Körperhüllen werden erst für nahe Wesen aufgebaut. Wiederholte Kontaktprüfungen verwenden dieselbe Hülle, solange Pose und Ausrichtung gleich bleiben.
- Im normalen Bildablauf folgt die Kontaktauflösung der Bewegung. Die nachfolgenden Entscheidungstakte benötigen keinen zweiten vollständigen Durchlauf. Neue Geburten erhalten weiterhin einen zusätzlichen Kontaktdurchlauf; explizite Experiment-Schritte lösen Kontakte ebenfalls auf.
- Formskalen, Verbindungsstärken und unveränderte Farben werden wiederverwendet. Die Energieansicht aktualisiert ihre Farben weiterhin bei Energieänderungen. Grafikpuffer werden nur bei geänderter Instanzanzahl dimensioniert.
- Außerhalb des Kamerablickfelds laufen Gelenkbewegung, Körperkontakt, Stoffwechsel, Fortpflanzung und Evolution weiter. Nur die Übertragung der animierten Geometrie entfällt. Beim Eintritt ins Sichtfeld und vor einem OBJ-Export wird die aktuelle Pose übertragen. Die Sichtprüfung berücksichtigt den gesamten Körperradius und einen Bewegungsrand.

Die bisherigen Populations-, Körperzell- und Simulationstakt-Vorgaben bleiben erhalten. MCP und VKLP bleiben unabhängige optionale Schnittstellen. Beobachtungen enthalten jetzt auch die aktive Kontaktqualitätsstufe, da physikalische Näherungen Versuchsergebnisse beeinflussen können.

Die Grafikanbindung nutzt die dokumentierten [MultiMesh-Eigenschaften](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) und die [Kamera-Sichtebenen](https://docs.godotengine.org/en/stable/classes/class_camera3d.html#class-camera3d-method-get-frustum).

## Vergleich und praktische Prüfung

Die Vergleichsmessung führt dieselbe übersetzte GDScript-Logik mit Python-Ersatzobjekten aus: Seed 1337, 16 Organismen, 540 Nahrungspunkte, Küste der Größe 146, zwölf Bilder mit je 1/12 Simulationssekunde. Beide Versionen enden bei 1.792 Körperzellen. Es wurden alle Wesen für Grafikübertragungen berücksichtigt; Einsparungen durch das Kamerablickfeld sind darin noch nicht enthalten.

| Messgröße | Alpha15 | Alpha16, 85 | Alpha16, 100 |
| --- | ---: | ---: | ---: |
| Aufrufe der Geländehöhenfunktion | 424.788 | 23.411 | 107.983 |
| Übertragene Instanzfarben | 46.240 | 3.568 | 3.568 |
| Übertragene Instanztransformationen | 46.240 | 46.240 | 46.240 |
| CPU-Zeit im instrumentierten Quellcode-Test | 39,78 s | 16,45 s | 18,68 s |

Bei Standardqualität sind das rund **94,5 % weniger Geländehöhenabfragen** und **92,3 % weniger Farbübertragungen**. Die absoluten Zeiten enthalten Übersetzung, Ersatzobjekte und Profiling-Aufwand. Sie sind ausdrücklich **keine Godot-Laufzeiten, GPU-Messungen oder Windows-FPS-Prognosen**.

Das Laufzeitlog enthält alle zehn Sekunden zusätzlich `perf_detail`: durchschnittliche CPU-Zeit für Bewegung einschließlich Animation/Boden, Biologietakte und Kontaktauflösung, den höchsten Welt-Bildaufwand sowie Draw Calls, Primitive, Bodenprüfungen, Cachetreffer und übersprungene Grafikübertragungen. Diese Angaben helfen, einen verbleibenden Engpass auf dem tatsächlichen Rechner zu erkennen. `frame_ms` stammt aus Godots Prozesszeit-Monitor und misst keine isolierte GPU-Zeit.

Zum Vergleich dieselbe Auflösung, Ansicht und eine ähnliche Population verwenden. Zunächst Standard 85 testen; bei Bedarf 40 ausprobieren und anschließend 100 vergleichen. Nach mindestens etwa 20 Sekunden enthält `logs/latest_runtime.log` mehrere Messungen. Die nativen Installer-Prüfungen bleiben aktiv.

Die erfolgreich abgeschlossenen Quellcode-, Profil-, Sichtbarkeits- und Fortpflanzungstests stehen in `BUILD_VERIFICATION.txt`. Alpha16 konnte hier nicht mit einem nativen Windows-Godot ausgeführt werden.
