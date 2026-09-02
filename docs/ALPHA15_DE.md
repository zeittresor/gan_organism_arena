# Alpha15 — Körper, Optionen und Zellzyklen

Die Welt und alle bisherigen Steuerelemente bleiben der Kern der Anwendung. Dieses Paket erweitert alpha14; MCP und VKLP sind weiterhin freiwillige Zusatzmodule.

## Optionen und Profile

F10 enthält getrennte Schalter für MCP-Zugriff, VKLP-Zugriff und VKLP-Einsendungen sowie die VKLP-Dienstadresse. Beide Zugänge sind anfangs ausgeschaltet. Ein aktivierter Zugang startet den lokalen Weltkanal; erst eine konkrete Client-Anfrage liest oder verändert Daten. Das Abschalten sperrt folgende Anfragen auch laufender Adapter. Ein vom gesperrten Protokoll angeforderter Schrittbetrieb geht wieder in normalen Lauf über. Es gibt weder automatischen Reset noch eine automatisch eingeschränkte Bedienoberfläche.

Alle 53 Optionen und Aktionen erklären sich per Tooltip. Die Einträge selbst werden übersetzt. „Einstellungen speichern“ schreibt ein benanntes JSON-Profil, „Einstellungen laden“ öffnet eine Dateiauswahl und prüft erst die gesamte Datei. Unpassende Datentypen, ungültige Auswahlwerte und Werte außerhalb der Grenzen werden zurückgewiesen, ohne Teiländerungen anzuwenden. Die laufenden Optionen werden weiterhin automatisch gespeichert. Ein Profil enthält Einstellungen einschließlich Freigaben, keinen Simulationsspielstand und keine Sitzungstoken oder API-Schlüssel.

Menüsprache, Sprechsprache und Systemstimme sind getrennt wählbar. „Wie Menüsprache“ folgt der Oberfläche. Gedanken, Erinnerungsfragmente, HUD, Körperbezeichnungen und neue Zustandsanzeigen sind auf Englisch, Deutsch und Französisch verfügbar. Der Sprachtest verwendet dieselbe Stimme wie die Wesen. Fehlt eine Stimme in der gewählten Sprache, meldet die Oberfläche das und zeigt Gedanken als Text. Die Sprachausgabe verwendet [Godots native TTS-Schnittstelle](https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html).

## Bewegliche, verbundene Anatomie

Ein gerichteter, kreisfreier Verbindungsbaum verbindet jedes sichtbare Gewebeteil mit seinem Körper. Bewegung verändert Gelenkwinkel und erhält Segmentlängen. Verbindendes Gewebe wird zwischen den tatsächlich bewegten Endpunkten gezeichnet. Die Flexibilität des axialen Körpers hängt unter anderem von Muskulatur, Schwanz, Panzerung und Holzgewebe ab. Flügelbewegung, Beintakt und Schwimmbewegung unterscheiden sich. Der Zellmodus bleibt eine auseinandergezogene Gewebedarstellung und verändert keine Kontaktkörper.

Der Kontaktlöser arbeitet mit konservativen, gegliederten Körperhüllen und einer kleinen Nachgiebigkeit von 0,015 Welteinheiten. Paarung misst den Abstand der Hüllen statt nur den Abstand der Körperursprünge. Bodenproben berücksichtigen gedrehte Gewebeausdehnung und die Höhe des Geländes unter dem Körper. Schwerkraft führt nicht fliegende Landwesen zurück zum Boden; Wurzeln dürfen im Boden liegen. Geburten werden anschließend räumlich getrennt.

Die Hüllen sind keine Dreiecksnetz-Kollision und kein vollständig deformierbares Muskel-/Hautmodell; flache oder sehr verzweigte Formen können dadurch etwas mehr Platz beanspruchen. Selbstkollisionen innerhalb eines Individuums und vollständige Fuß-Inverskinematik sind noch nicht implementiert. Die Zellzahl bleibt begrenzt; hinzu kommen höchstens `Zellzahl - 1` Gewebeverbindungen. OBJ exportiert die aktuelle bewegte Geometrie einschließlich dieser Verbindungen.

Ungewöhnliche oder komisch wirkende Körper sind zulässig. Es gibt keine Schönheitsbewertung und kein Ziel, bekannte Erdspezies nachzubilden. Energie, Fortpflanzungsfähigkeit, Anatomie und Umweltbedingungen bestimmen den Erfolg.

## DNA, Mitose und Meiose

Jedes Wesen besitzt 88 diploide quantitative Genorte, acht rezessive Lastorte und ein vererbtes Geschlechtschromosomenpaar. Die quantitativen Gene bilden sechs Chromosomenpaare mit maximal 16 Genorten pro Paar. „DNA der Auswahl exportieren“ speichert die beiden Homologe, komplementäre Stränge, Genpositionen und ergänzende Genomdaten. KI-Abfragen enthalten dieselben Daten.

Die Buchstaben A/C/G/T sind ein **fiktiver regulatorischer Code**: zehn Basen kodieren einen Allelwert. Die Sequenzdarstellung hat höchstens etwa 0,00000048 Quantisierungsfehler. Sie ist kein reales Protein-Codonsystem und modelliert weder vollständige Proteinfaltung noch biochemische Genregulation. Punktmutationen ändern einzelne Basen und damit einen tatsächlich exprimierten Allelwert; weitere bisherige Genmutationen und Körperbauänderungen bleiben möglich. Die Sequenzen sind folglich mit der vererbbaren Funktion verbunden, keine unabhängigen Zufallstexte.

Mitose und Meiose sind unterschiedliche Prozesse. Mitose erhält die Ploidie und dient dem Aufbau beziehungsweise Ersatz somatischer Zellen; Meiose reduziert die Chromosomensätze für die sexuelle Fortpflanzung. Diese grundlegende Unterscheidung entspricht den Definitionen des NHGRI zu [Mitose](https://www.genome.gov/genetics-glossary/Mitosis) und [Meiose](https://www.genome.gov/genetics-glossary/Meiosis).

Im Modell bezahlt Wachstum zusätzliche somatische Zellen. Verletzungen senken Bewegungsleistung; bezahlte Ersatzteilungen reparieren Gewebe. Diese aggregierte somatische Zellzahl ist von den wenigen sichtbaren Grafikzellen getrennt. Klonale Nachkommen kopieren beide Homologe, abgesehen von auftretenden Mutationen.

Meiose erstellt vier haploide Produkte. Rekombination tauscht entsprechende Abschnitte zwischen Nichtschwesterchromatiden aus; ohne Mutation bleibt jedes Elternallel am jeweiligen Genort im Verhältnis 2:2 erhalten. Eier und Spermien tragen gespeicherte haploide Genome. Die Eizellroute führt ein funktionelles Produkt und drei Polkörper; die Spermienroute kann mehrere Produkte in den durch Energiereserven begrenzten Vorrat übernehmen. Bei Befruchtung wird pro Nachwuchs ein Ei und ein Spermium verbraucht; aus ihren Allelen entsteht das diploide Nachkommengenom.

Ein stark ausgeprägter erblicher asexueller Antrieb erlaubt klonale Vermehrung. Ein mittlerer Bereich erlaubt gleichzeitig Budgets für Knospen und für sexuelle Keimzellen, ein noch höherer Bereich investiert ausschließlich in klonale Fortpflanzung. Auch rein sexuell fortpflanzende Wesen wachsen selbstverständlich mitotisch. Die Parameter und Entwicklungszeiten sind experimentelle Modellannahmen, keine Kalibrierung auf eine reale Spezies.

## Augen und Gefühlszustände

Vier zusätzliche Genorte steuern Augenfokussierung, Facettenaugen, Fühler und affektive Plastizität. Einfache gerichtete Augen besitzen Augenkörper, farbige Iris und dunkle Pupille. Ihre Blickrichtung folgt Nahrung, Beute oder Paarungspartnern und ist begrenzt, damit sie nicht durch den Kopf nach hinten sehen. Alternative Körper können facettierte Augen und angeschlossene Fühler ausbilden; Merkmalskombinationen bleiben erblich veränderlich.

Niedrige kognitive Entwicklung verwendet Reflexe. Mit zunehmender modellierter Intelligenz/Komplexität können Valenz, Aktivierung und Bindung stärker werden. Nahrung, Atemnot, Verletzungen, Gefahr und Nähe beeinflussen sie. Die Zustände verändern Annäherung, Erkundung und Fluchtsteuerung und können in späteren Sprachstufen in Gedanken erscheinen. „Emotion“ bezeichnet hier messbare Verhaltenszustände; daraus folgt keine Behauptung subjektiven Bewusstseins.

## Prüfung

Die Paketprüfung und der Installer laden alle neuen Skripte. Der Selbsttest umfasst Verbindungsgraphen und Segmentlängen über sieben Körperpläne und drei Grafikbudgets, Überlappung/Kontakt, Bodenkontakt, Augenrichtung, affektabhängiges Verhalten, Sprachwahl, DNA-Kodierung, meiotische Allelerhaltung und kombinierte Fortpflanzung. Zusätzlich laufen die bisherigen Ökologie-, Oberflächen-, Lebenszyklus-, Biologie- und Versuchstests.

Die lokale Prüfung führt übersetzten GDScript-Quellcode mit Ersatzobjekten aus und ergänzt ihn um eine GDScript-Grammatikprüfung sowie echte Python-/Protokolltests. Ein nativer Godot-/Windows-Grafiklauf und die tatsächliche Windows-Stimmenausgabe waren in dieser Build-Umgebung nicht verfügbar. Genaue Ergebnisse stehen in `BUILD_VERIFICATION.txt` und `TESTING.md`.
