# Alpha19 — Bodenanpassung, Auftrieb und Planetengravitation

Die eingesandten Alpha18-Logs zeigen einen erfolgreichen Installer einschließlich nativer Parser-, Selbsttest- und Startprüfung. Es gibt darin keine Skriptfehler oder echten Warnungen. Das Bild und die Körperlogik weisen auf ein anderes Problem: Eine einzige hohe Kontaktstelle konnte den langen, vertikal starren Körper insgesamt anheben. Die bisherige Einteilung „im Wasser“ verwendete außerdem den Organismusmittelpunkt anstelle des eingetauchten Körpers.

## Beweglicher Rücken statt schwebender Stange

Vorhandene axiale Knorpel-, flexible Panzer- und Hydrostat-Verbindungen erhalten einen begrenzten vertikalen Freiheitsgrad. Die Mechanik berücksichtigt die geerbten Stütz-, Panzer- und Holzanteile. Knochen und starre Schäfte behalten ihre Form; die Bewegung erfolgt an ihren Verbindungen. Ein Körper mit wenig aktivem Muskelgewebe kann unter äußerer Last passiv nachgeben.

Die Höhen des Untergrunds und die Ausdehnung tragender Gewebe bestimmen ein geglättetes Stützprofil. Die Körperachse neigt sich langsam entlang des Hangs, die einzelnen Verbindungen folgen örtlichen Höhenunterschieden. Zielwinkel werden entlang einer gemeinsamen Zielkette berechnet, bevor die sichtbaren Gelenke gedämpft nachziehen. Das verhindert, dass sich verzögerte Korrekturen über viele Wirbel aufschaukeln. Zusammenhängende Segmente behalten ihre Länge; regelmäßige Körperneubauten übernehmen die aktuelle Haltung.

Tragende Rumpf-, Haut-, Panzer-, Bein-, Wurzel- und Rindenelemente begrenzen Bodenkontakt. Federn, Borsten und ähnliche Aufsätze wirken nicht als starre Stelzen für das gesamte Tier. Kleine Berührungen weicher Aufsätze bleiben möglich. Der vorhandene Kontaktgenauigkeitsregler bleibt erhalten (Standard 85).

## Wasser und Schwerkraft

Das Modell schätzt den eingetauchten Volumenanteil aus den strukturellen Körperellipsoiden. Eine teilweise trockene Körperhälfte erhält damit nicht mehr den Auftrieb eines vollständig eingetauchten Tiers. Geerbte Auftriebs- und Panzermerkmale beeinflussen die mittlere Dichte. Vollständig trockene Körper fallen auch bei einer kurzfristig veralteten Wasser-Klassifikation. Eine frei fallende Puppe behält ihre Fallgeschwindigkeit; fehlender eigener Antrieb bedeutet keine Aufhebung der Schwerkraft.

Flugunterstützung setzt Flugfähigkeit, Muskeln, Energiereserven, Ausdauer und ausreichend Tragkraft voraus. Ein altes Flugzustandsflag allein lässt einen Körper nicht schweben.

## Neue Option: Planetengravitation

Unter **F10 → Planetengravitation (× Erde)** lässt sich die Beschleunigung von **0,20 bis 2,50** einstellen; **1,00** ist der Standard. Der Regler wirkt nach dem Schließen des Optionsmenüs beim Fortsetzen der Simulation. Die Einstellung wird regulär gespeichert und ist Bestandteil der speicher- und ladbaren Einstellungsprofile.

Schwächere Gravitation senkt die Fallbeschleunigung und ermöglicht bei gleicher Absprunggeschwindigkeit höhere Sprünge. Stärkere Gravitation verlangt mehr Tragkraft beim Fliegen. Gewicht und Auftrieb skalieren gemeinsam: Die Dichte eines Tiers ändert sich durch den Regler nicht. Dies ist eine Welteigenschaft für Experimente, kein Geschwindigkeitsregler. Die Simulationsgeschwindigkeit bleibt eine eigene Option.

Die optionale Experiment-/MCP-Schnittstelle erlaubt denselben Wert als `gravity_scale`. Beobachtungen enthalten den effektiven Wert, den eingetauchten Anteil und die Stützausrichtung; Detaildaten enthalten die vertikalen Gelenkwinkel und -grenzen. Das Modellkennzeichen lautet nun `arena-biology-4`, das Beobachtungsschema bleibt kompatibel erweitert. Normales Spielen benötigt keine Schnittstelle.

## Rechenaufwand und Aussagegrenzen

Stützproben werden abhängig von der Kontaktqualität in Abständen von 0,05–0,20 Simulationssekunden aktualisiert. Ortswechsel, Geländeänderungen und Körperneubauten können frühere Proben verwerfen. Die sichtbare Bewegung wird weiter gedämpft aktualisiert. Vollständig von anderen Kontaktsphären umschlossene Sphären werden entfernt; ihre besetzte Raumregion bleibt enthalten.

Im identischen Quellcode-Vergleich mit 16 Organismen, 1.792 Geweben, Kontaktqualität 85 und zwölf Schritten sank die Zahl der Geländeabfragen von 23.195 auf 13.829. Die instrumentierte CPU-Zeit betrug hier 19,326 s für Alpha18 und 18,071 s für Alpha19. Diese Python-Ersatzumgebung ist erheblich langsamer als Godot; ihre Zeiten sind ausdrücklich keine FPS-Prognose. Grafik-Uploadzahlen und Gewebebudget blieben gleich.

Das Verfahren ist ein beschränktes kinematisches Gelenkmodell mit Volumenauftrieb. Es löst keine vollständige Flüssigkeitssimulation, keine inneren Gewebespannungen und keine vollständige Fuß-Inverskinematik. Steile Absätze und ungewöhnliche Körper können weiterhin sichtbare Abstände oder leichte Berührungen erzeugen. Ziel ist eine plausible, bewegliche Körperanpassung bei überschaubarem Rechenaufwand. Die Alpha19-Darstellung und Windows-FPS konnten hier nicht nativ geprüft werden; die Installer-Prüfungen sind weiterhin aktiv.
