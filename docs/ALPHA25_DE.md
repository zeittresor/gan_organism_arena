# Alpha25 — nachvollziehbare Vererbung und Evolutionsverlauf

## Vererbung verbessert

Größere regulatorische Mutationen verändern jetzt je betroffenem Genort eine einzelne Genkopie. Die andere, vom Elternteil geerbte Kopie bleibt erhalten. Zuvor schrieb dieser Vorgang den veränderten Merkmalswert in beide Kopien zurück und verlor dabei Erbvariation. Eine neue Anlage kann nun zunächst verborgen bleiben, bei weiterer Vererbung wieder zusammentreffen und erst dann sichtbar werden. Größere Mutationen garantieren deshalb keinen sofortigen Wechsel der Körpergrundform.

Kleine Mutationen und größere Eingriffe zählen nur dann als Genänderung, wenn sich ein Allel tatsächlich ändert. Der DNA-Export enthält die betroffene Genposition, Kopie, alten/neuen Wert und Änderungsart. Beim sexuellen Nachwuchs werden Änderungen aus Ei und Spermium übernommen; spätere regulatorische Änderungen werden ergänzt. Die Zähler gelten jeweils für neu entstandene Änderungen dieses Nachkommens, nicht kumuliert über alle Vorfahren. Auch klonale Linien können veränderte rezessive Lasten erben oder neu erwerben.

Die ursprüngliche Reihenfolge der 88 Genorte ist wiederhergestellt. Körpergrundform und neue Pigmentgene werden am Ende angehängt, damit zusätzliche Gene nicht die gesamte vorhandene Kopplungs- und Dominanzzuordnung verschieben. Der DNA-Export kennzeichnet die Karte als `arena.loci/3`; die Modellkennung ist `arena-biology-8`. Gleiche Zufallsstarts sind zwischen verschiedenen Programmversionen nicht als identische Experimente zu verstehen.

## Mehr vererbbare Farben

Neben dem Farbton sind nun Sättigung und Helligkeit eigene diploide Genorte. Insgesamt besitzt ein Genom 91 regulatorische Genorte. Haut, Fell, Schuppen, Federn und Panzer beziehen ihre Farbabstufungen weiterhin aus dieser Grundpigmentierung. Farbtonmischungen am Übergang Rot/Rot bleiben korrekt; auch exakt gegenüberliegende Farbtöne ergeben unabhängig von der Reihenfolge der Eltern dieselbe Mischung.

Die Farbregeln sind ein fiktives Pigmentmodell. Sie ermöglichen erbliche Unterschiede in den tatsächlich verwendeten Körperfarben, ohne eine bestimmte irdische Pigmentchemie vorzugeben. Änderungen der Erbanlagen allein gewähren weiterhin keine Flug-, Lauf- oder Atmungsfähigkeit: Anatomie, Lebensstadium, Energie und Habitat bleiben ausschlaggebend.

## Neue Funktionen in F10

- **Evolutionsübersicht:** natürliche sexuelle und klonale Geburten, Anfangswesen, manuelle Einsätze und automatische Nachbesetzungen werden getrennt gezählt. Dazu kommen Todesfälle, höchste erreichte/aktuell lebende Generation, verwurzelte Wesen und die letzten Abstammungen.
- **Erste neue Körpergrundformen:** angezeigt werden erstmalige Formen, die durch Fortpflanzung entstanden sind. Manuell eingesetzte Formen werden nicht als evolutionäre Entdeckung verbucht. Das zählt Grundformen des Generators und ist keine wissenschaftliche Bestimmung neuer Arten.
- **Evolutionsverlauf exportieren:** JSON in `exports/evolution` mit Elternbeziehungen, Geburts-/Todeszeit, Herkunft, Generation, Körpergrundform, Pigment und Mutationszählern. Es werden die letzten 2.048 Geburtseinträge aufbewahrt; Gesamtzähler und erste Formbeobachtungen bleiben für den Lauf erhalten. Verworfene Einträge sind ausgewiesen. Der Export ist eine Beobachtung, kein ladbarer Weltspielstand.
- **Neue Fortpflanzungen erlauben:** unabhängig vom automatischen Nachbesetzen abschaltbar. Neue Balz/Befruchtung und Klonen pausieren; vorhandene Embryonen entwickeln sich weiter.
- Kleine Mutationen lassen sich jetzt auch im Regler auf null stellen. Für völlig mutationsfreie Fortpflanzung müssen beide Mutationsregler auf null stehen. Der Regler für größere Mutationen zeigt drei Nachkommastellen, sodass der Standardwert 0,014 korrekt erkennbar ist.

Alle neuen Texte, Tooltips und die aktualisierte Hilfe sind auf Deutsch, Englisch und Französisch vorhanden.

## Nachbesetzen und Laufzeit

Das Einschalten oder Ändern der Nachbesetzung bereinigt zuerst bereits tote Organismen. Es wirkt sofort, auch im pausierten Zustand und bei einem ausdrücklich gesteuerten Schnittstellenversuch ohne zusätzlichen Simulationsschritt. Bestehende ausgeschaltete Einstellungen bleiben bei der Migration ausgeschaltet. Standardmäßig bleibt das Ziel bei fünf jungen aquatischen Wesen. Populationsgrenze und reservierte Embryoplätze gelten weiterhin; eine vorübergehende Unterbesetzung wird in der Übersicht sichtbar.

Die Abstammungsaufzeichnung läuft bei Geburten, Einsätzen und Todesfällen. Sie berechnet nicht laufend alle DNA-Werte erneut und fügt keine Körpergeometrie hinzu. Ihr Speicher ist begrenzt. Ein Neustart der Welt beginnt eine neue Aufzeichnung. Optionales MCP/VKLP erhält die gleichen Evolutionsdaten in Datenaufnahmen und Evidenzexporten; Freigaben bleiben unabhängig und standardmäßig aus.

Die vorhandenen sieben Körpergrammatiken lassen viele vererbte Mischformen zu, bleiben aber endlich. Diese Version fügt keine beliebig neue Geometriegrammatik hinzu. Sie verbessert die Vererbung innerhalb dieses Systems und macht tatsächliche Entwicklungen und künstliche Nachbesetzungen nachvollziehbar.

Prüfungen und ihre Ausführungsgrenzen stehen in `TESTING.md` und `BUILD_VERIFICATION.txt`. Der Windows-Installer behält seine nativen Parse-, Selbsttest- und Startprüfungen bei.
# Optionale und vererbbare Texturen

PNG-Texturen für Gelände und Körper lassen sich in den Optionen zuschalten; standardmäßig bleibt die Funktion aus. Die mitgelieferten Dateien unter `textures/` können ausgetauscht und mit F9 neu geladen werden. Bei sexueller Fortpflanzung wird aus den tatsächlich verwendeten Elternbildern einmalig ein eigenes 128×128-Mischbild für das Jungtier erzeugt. Klone erhalten eine unabhängige Kopie. So bleibt das Muster über weitere Generationen und nach dem Tod der Eltern erhalten. Die Berechnung erfolgt bei Entstehung oder erstmaliger Anzeige eines Wesens und nicht in jedem Bild.
