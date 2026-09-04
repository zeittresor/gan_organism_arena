# Alpha20 — bewegliche Körper an Ufern und korrigierte Verbindungen

Die vier eingesandten Alpha19-Bilder zeigen zwei verbleibende Fehler: Lange Körper wirken an Hängen weiter wie starre Balken, und unter einem Tier erscheinen lange polygonale Streifen. Im ausgewählten Beispiel ist der Organismus kein flugfähiges Tier: Die Anzeige nennt 0 % Flugentwicklung, „Wasser suchen“ und verbrauchten Sauerstoff. Die Haltung ist deshalb nicht als erfolgreich entwickelter Flug zu deuten.

## Gelenke und Stützverhalten

Die bisherige vertikale Winkelkorrektur verwendete eine lineare Näherung an einem halben Segmenthebel. An steilen Übergängen konnten sich benachbarte Wirbel dadurch in entgegengesetzte Richtungen korrigieren. Ihre Winkel wurden teilweise groß, während der Rumpf insgesamt trotzdem fast gerade blieb.

Axiale Verbindungen verwenden jetzt ihren proximalen Befestigungspunkt und eine direkte Tangentenberechnung. Zusammenhängende starre Segmente behalten ihre Länge; das begrenzte Gelenk dreht das jeweils folgende Segment. Die vertikale Beweglichkeit beträgt vor den geerbten Versteifungsfaktoren maximal 0,35 Radiant bei axialen Knorpelverbindungen beziehungsweise 0,50 Radiant bei weichen Hydrostatverbindungen. Holz- und Panzeranteile reduzieren sie weiterhin. Knochen und feste Schäfte selbst werden nicht verbogen.

Die mittlere Lage der Körpermasse und der tatsächlichen Kontaktstellen beeinflussen bei schlangenförmigen Körpern zusätzlich die gedämpfte Stützneigung. Ein einzelner Schwanzkontakt hält einen weit herausragenden Vorderkörper damit nicht mehr wie eine starre Einspannung. Die bestehende Schwerkraft und der anteilige Volumenauftrieb bleiben aktiv.

Beim Auf- und Abwärtsschwimmen wird die Drehung außerdem zeitversetzt von mehreren hinteren Gelenken aufgenommen. Die Gelenke haben weiterhin begrenzte Winkelgeschwindigkeiten und entspannen sich nach dem Manöver. Dadurch ist auch im freien Wasser eine lokale Biegung möglich. Die Kopf- und Schwanzanker für vorhandene Folge-, Werkzeug- und Interaktionsfunktionen werden aus der aktuellen Gelenkpose berechnet.

## Polygonstreifen

Bei kopfseitigen Hörnern und Schnäbeln konnte ein zufällig ausgewähltes Gewebe am Rumpf oder an einer Extremität als Befestigungspunkt übrig bleiben, obwohl der Aufsatz am Kopf erzeugt wurde. Die Darstellung zog dann eine lange Verbindungsfläche zwischen diesen weit auseinanderliegenden Punkten. Solche Kopfaufsätze werden jetzt am Kopf befestigt.

Zusätzlich erhielten selbst ausgeblendete innere Gewebe noch einen minimalen Verbindungsradius. Diese vermeintlich unsichtbaren Verbindungen konnten als dünne Linien sichtbar bleiben. Ihr Geometrieanteil ist nun vollständig null und wird auch vom bestehenden OBJ-Exporter ausgelassen. In der wissenschaftlichen Zellansicht bleiben die inneren Gewebe sichtbar.

## Prüfung und Grenzen

Ein neuer Selbsttest deckt einen scharfkantigen Bergkamm, ein steiles Ufer, das Zurückkehren des Vorderkörpers ins Wasser, voneinander abweichende Segmentorientierungen, Schwimmmanöver, die tatsächlichen Verbindungs-Transforms und dynamische Kopfanker ab. Er läuft auch im Windows-Installer; ein Fehler bricht die Installation ab.

Die lokale Quellcode-Ausführung besteht alle 11.243 benannten Prüfungen und den bisherigen Morphologie-/Genom-/Sprachtest. Sie ersetzt jedoch keine native Godot-Ausführung. Die aktuelle Windows-Darstellung konnte hier nicht geprüft werden. Auch Alpha20 ist ein kinematisches Körpermodell mit angenähertem Auftrieb, keine vollständige Gewebe-, Flüssigkeits- oder Fuß-Inverskinematik. Sehr scharfe Geländeabsätze, ungewöhnliche Proportionen und weiche Aufsätze können weiterhin kleine Abstände oder Berührungen erzeugen.

Der identische instrumentierte Quellcode-Vergleich mit 16 Organismen und 1.792 Geweben ergab 35,296 CPU-Sekunden für Alpha19 und 35,505 für Alpha20. Geländeabfragen und Grafik-Uploadzahlen blieben gleich. Dies ist ein Vergleich in einer Python-Ersatzumgebung und keine native FPS-Messung; die Zeiten sind auch nicht mit früheren Messungen in einer anderen Auslastungssituation gleichzusetzen.

Alle bisherigen Optionen einschließlich Kontaktgenauigkeit, Planetengravitation, Sprachwahl, Einstellungsprofilen sowie optionalem MCP/VKLP bleiben vorhanden. Das Beobachtungsschema ist weiterhin `arena.observation/1`; das Modellkennzeichen lautet wegen der geänderten Mechanik jetzt `arena-biology-5`.
