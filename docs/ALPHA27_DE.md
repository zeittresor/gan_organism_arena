# Alpha27: weniger Kachelmuster, Übergänge und anatomische Paarung

Neue Welten starten standardmäßig mit zehn Lebewesen. Dafür wird pro Lauf ein
Pool aus sieben kanonischen aquatischen Grundformen und sieben neuen, per
Meiose/Crossover gemischten Formen erzeugt. Zehn verschiedene Einträge werden
ohne Wiederholung ausgewählt; derselbe Lauf-Seed bleibt reproduzierbar, ein neuer
Start erzeugt einen anderen anfänglichen Genpool.

Die technisch geschlossenen Kanten aus Alpha26 verhinderten sichtbare Nähte, konnten aber große wiederkehrende Motive innerhalb einer PNG-Datei nicht verbergen. Alpha27 entfernt deshalb die auffälligen großflächigen Wellen und Flecken aus den vier bisherigen Geländevorlagen. Zusätzlich mischt der Geländeshader pro Region deterministisch versetzte, um 90° gedrehte und gespiegelte Abtastungen. Benachbarte Regionen werden weich überblendet. Eine einzelne kleine Quelldatei erscheint dadurch in der gerenderten Welt nicht mehr als starres Kachelraster.

Vier neue Geländetypen ergänzen die regionalen Grundtexturen: Tiefenboden, nasse Uferzone, Strandsand und Gras. Ihre Gewichte folgen der tatsächlichen Höhe relativ zur Wasserlinie. Unter Wasser geht der Tiefenboden über die nasse Uferzone in Sand über; oberhalb der Wasserlinie mischt sich Sand in die zum Habitat passende Landoberfläche und – je nach Habitat – Gras.

Die optionale Bibliothek enthält nun 33 austauschbare 256×256-PNGs unter 3 MiB: acht Gelände-, sechs vererbbare Hüllen-, fünfzehn spezialisierte Gewebe- und vier Materialvorlagen. Knochen, Nervengewebe, Augen, Flossen, Blätter, Rinde/Wurzeln, Flügel, Federn, Hörner, Schnäbel, Klauen/Gliedmaßen, Panzer, Fortpflanzungsoberflächen und Ornamente erhalten thematische Atlasplätze. Ein adaptiver Platz fängt unbekannte spätere Gewebetypen ab. Holz, Stein, Metall und Stoff liegen für Werkzeuge, Rüstungen oder Kleidung bereit; sichtbar werden sie, sobald das entsprechende Objekt in der Simulation existiert. Der aktuelle getragene Gegenstand nutzt Holz.

Die eigentliche vererbbare Körperhülle bleibt ein 50/50-Pixelgemisch der Eltern und wird über weitere Generationen fortgeführt. Die neuen Gewebekategorien ersetzen diese Erbinformation nicht: Pigment und Körperbau bleiben genetisch, während der Gewebetyp die passende Mikrooberfläche auswählt. Jedes Körpersegment verwendet außerdem einen stabilen eigenen Ausschnitt mit Drehung/Spiegelung. Diese Werte werden aus Genom-Saat und Segmentnummer abgeleitet und verbrauchen keinen biologischen Zufall.

Bei der Paarung verfolgen Partner nicht mehr fortlaufend den Mittelpunkt beziehungsweise Kopf des anderen. Ein Paar erhält einen stabilen gemeinsamen Kopplungsort, zwei körpergrößenabhängige Andockpunkte und eine gemeinsame seitliche Ausrichtung. Interne Befruchtung prüft zusätzlich die Nähe der schematischen Fortpflanzungsregionen. Kurzzeitige Lücken durch die weiche Kollision lassen den bereits erreichten Kopplungsfortschritt nur langsam zurückgehen. Der vollständige Ablauf von Annäherung über Kopplung und Schwangerschaft bis zur Geburt wird als Produktionsintegration geprüft.

Aquatische Gründer werden außerdem ausdrücklich als solche markiert. Sie und ihre
ersten drei Nachkommengenerationen bleiben an Wasseratmung und Schwimmen gebunden;
erst danach können ausreichende Lungen-, Stütz- und Laufmerkmale den Landübergang
freischalten. Eine beschädigte oder unvollständige optionale PNG-Datei deaktiviert
nur die Texturüberlagerung und fällt sicher auf die ursprüngliche Vertex-Farb-
Darstellung zurück, statt die Anwendung beim Umschalten zu beenden.
