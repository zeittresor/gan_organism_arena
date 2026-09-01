# Neue Lebensweisen — 1.0.0-alpha12

Die Evolution hat kein Ziel wie „Mensch“, „intelligenter“ oder „größer“. Gene für Körperbau, Atmung, Bewegung, Ernährung und Verhalten werden gemeinsam vererbt, gekreuzt und mutiert. Kleine, sesshafte oder scheue Formen können ebenso überleben wie schnelle Jäger. Welche Linien tatsächlich entstehen, hängt vom Ausgangszustand, den Ressourcen und dem Habitat ab. Nicht jede Möglichkeit erscheint in jedem Lauf.

## Größere Welt

Der Ausgangsraum misst jetzt **144 × 86,4 × 144** statt **72 × 43,2 × 72** Einheiten. Alle drei Richtungen sind verdoppelt, das Volumen ist achtmal so groß. Die Grundmenge verteilter Nahrung wurde von 180 auf 540 erhöht; Nahrung liegt im Wasser und auf zugänglichen Böden. Die Populations- und Körperzellenlimits bleiben begrenzt.

Beim Übernehmen einer alten `settings/config.json` werden die alten Weltdimensionen einmal verdoppelt, mindestens auf die neuen Standardmaße. Eine gespeicherte Schema-Kennung verhindert erneutes Verdoppeln beim nächsten Start. Die restlichen Optionen bleiben erhalten. Neue Installationen starten direkt mit der größeren Welt.

## Was die Anpassungen bewirken

| Möglichkeit | Voraussetzungen und Folgen |
|---|---|
| Schneller Schwimmer | Muskulatur, Flossen, Schwanz und Wasseranpassung erhöhen den Vortrieb. Große beziehungsweise aufwendige Körper kosten mehr Energie. |
| Amphibische Lebensweise | Ausreichende Wasser- und Luftatmung sowie Bodenbewegung. Feuchtigkeit, Aufenthaltsdauer und Neugier steuern den Wechsel zwischen Wasser und Land. |
| Land-Spezialist | Gute Lungen können schwache Kiemen nicht ersetzen. Unter Wasser sinkt der Atemvorrat; das Wesen sucht rechtzeitig Land beziehungsweise Luft. |
| Fliegen | Genügend Flügelfläche, Stützkraft, leichte Struktur beziehungsweise geringe Körperlast, Luftatmung, Reife, Übung und Ausdauer. Nur Habitat 8/9 bietet den benötigten offenen Himmel. |
| Rudeljagd | Kooperations- und Rudelanlagen; nahe Mitglieder teilen ein Beuteziel, treiben oder flankieren es. Ein Teil tatsächlich erbeuteter Energie kann geteilt werden. |
| Jagdtaktiken | Verfolgen, vorausschauendes Abfangen und Lauerpositionen. Erfolgreiche Aktionen verbessern begrenzte persönliche Fertigkeiten und Taktikbewertungen. |
| Werkzeuggebrauch | Manipulierbare Gliedmaßen, neuronale Anlagen, Reife und Werkzeugneigung. Werkzeuge werden an den sichtbaren steinigen Nahrungsvorkommen aufgenommen; sie öffnen begrenzte Vorräte und verschleißen. |
| Aufrechter Gang | Tragfähige Gliedmaßen, Balance und neuronale Koordination. Auf Land erhält der Körper eine aufrechte Form und einen bewegten Beingang. |
| Kleine insektenartige Formen | Kleine Körpergröße, mehrere Gliedmaßen und stützende Außenstruktur. Größe und Körperlast beeinflussen Energiebedarf und Flugfähigkeit. |
| Scheu und Verstecken | Bedrohung plus Rückzugsneigung führt zur Flucht oder hinter Deckung. Versteckte, getarnte Wesen werden aus geringerer Entfernung erkannt. |
| Putzer | Kleine, spezialisierte Wesen entfernen Aufwuchs und Parasiten von größeren Wirten. Das ist von schädigendem Parasitismus getrennt. |
| Parasitismus | Kontakt zu einem größeren Wirt ermöglicht Energieentzug, belastet aber den Wirt und kann ihn töten. |
| Sesshafte Formen | Verwurzelungsneigung plus Photosynthese oder Filtration. Der Körper siedelt sich auf dem tatsächlichen Boden an und driftet nicht mehr herum. |
| Pflanzen und Bäume | Blatt-/Filterstrukturen, Verzweigung und auf Land ausreichend Holz- und Stützanlagen. Licht, Wassertiefe und lokale Konkurrenz beeinflussen den Ertrag. Pflanzen können abgeweidet werden. |

Diese Eigenschaften sind kombinierbar. „Insektenartig“ oder „baumartig“ bezeichnet hier eine sichtbare Ähnlichkeit, keine feste irdische Art oder wissenschaftliche Abstammungslinie. Individuelles Lernen und genetische Evolution sind getrennt: Nachkommen erben Anlagen; erlernte Jagd-, Flug- und Werkzeugfertigkeiten beginnen neu.

## Haut, Federn und weitere Körpermerkmale

Neun zusätzliche Gene bestimmen die Körperhülle: `skin_thickness`, `scale_cover`, `feather_cover`, `fur_cover`, `mucus_cover`, `membrane_cover`, `horn_drive`, `beak_drive` und `pattern_drive`. Sie werden zufällig initialisiert, vererbt, gekreuzt und mutiert. Mischformen sind ausdrücklich möglich; es gibt keine feste Abfolge von „Fisch“ zu „Vogel“ oder „Säugetier“.

| Merkmal | Sichtbare Form und Wirkung |
|---|---|
| Haut | Grundhülle mobiler Körper; größere Dicke erhöht Schutz und mindert Austrocknung, erschwert aber Hautatmung. |
| Schuppen | Flache Platten; zusätzlicher Bissschutz, weniger Wasserverlust, geringere Hautdurchlässigkeit. |
| Federn | Fahnen mit kontrastierenden Schäften, am Körper oder an vorhandenen Flügeln. Wärmedämmung und bessere Flügelwirkung, aber zusätzlicher Wasserwiderstand und laufende Energiekosten. Federn allein ermöglichen keinen Flug. |
| Fell / Borsten | Feine Bündel; Isolierung hilft bei Kälte, kann im Warmen belasten und unter Wasser bremsen. Nässe schwächt die Isolierung. |
| Schleim | Glänzendere Oberflächen und dünne Auflagen; vermindert Austrocknung und einen Teil des Wasserwiderstands. |
| Hautmembranen | Dünne, breite Flächen; können vorhandene Flugstrukturen unterstützen, ersetzen aber keine anatomischen Flugvoraussetzungen. |
| Hörner / Stacheln | Gestufte, zugespitzte Fortsätze bei ausreichender Stützanlage; zusätzlicher Schutz und höhere Fluglast. |
| Schnabel | Zweiteilige Kopfstruktur; verstärkt den Biss. Übertragene Beuteenergie bleibt auf tatsächlich entzogene Energie begrenzt. |
| Pigmentmuster | Genetisch bestimmte Flecken beziehungsweise Streifen in der natürlichen Ansicht. Sie haben hier keinen zusätzlichen Tarnbonus. |

Körperhüllen kosten laufend Energie. Ein vereinfachter Temperaturgradient mit kühlerem tiefem Wasser und regionalen Landunterschieden schafft Vor- und Nachteile für Isolierung. Das ist ein Spielmodell, keine physikalische Wärmebilanz. Verwurzelte Formen verwenden Pflanzen-/Filtergewebe, Baumstämme erhalten Rindenfärbung; tierische Hüllen werden ihnen nicht aufgeklebt.

Die Darstellung verwendet stilisierte, skalierte 3D-Zellen, keine fotorealistischen Texturen. Hüllen und Körper teilen sich das bisherige Zellbudget. Bei kleinen Budgets werden Details reduziert; neue Mischformen erhöhen nicht unbegrenzt die Anzahl gerenderter Zellen. Die Auswahlansicht trennt **Körperhülle** von Verhaltensanpassungen und zeigt die örtliche Temperatur.

## Beobachten

- **5–9:** Habitat wechseln. 5 ist ein geschlossenes Aquarium, 6 ergänzt Inseln, 7 Küsten, 8/9 offenen Luftraum.
- **Tab** oder **linke Maustaste:** Wesen auswählen. Die Anzeige zeigt Anpassungen, Tätigkeit, Sauerstoff, Ausdauer, Feuchtigkeit, Körperhülle, Umgebungstemperatur und Fertigkeiten.
- **Rechte Maustaste:** folgen. **Mausrad:** zoomen. **Shift + Mausrad:** Beobachtergeschwindigkeit.
- **F10:** Optionen. **F1:** Hilfe. **G:** ein neues Zufallswesen einsetzen.

Automatisches Nachbesetzen ist standardmäßig ausgeschaltet. Aussterben bleibt möglich. Wer den bisherigen Rettungsmechanismus möchte, kann ihn in den Optionen aktivieren. An der Populationsgrenze werden keine Wesen anhand von Intelligenz oder Komplexität zwangsweise aussortiert: Nachwuchs braucht einen freien Platz nach natürlichen Todesfällen. Der Grenzwert ist weiterhin ein Leistungsbudget.

## Technische Grenzen

Es handelt sich um ein regelbasiertes Modell künstlichen Lebens mit kombinierbaren Genen und Körperbauregeln. Es erfindet keine beliebigen neuen physikalischen Fähigkeiten außerhalb dieser Regeln. Atmung, Leichtbau, Nahrung, Werkzeuggebrauch und Lernen sind vereinfachte Simulationsmechaniken. Die Verhaltensauswahl ist kein LLM oder allgemeines intelligentes Planungsverfahren.

Die Landschaft und die Bodenabfragen verwenden dasselbe triangulierte Höhenfeld. Körperkontakt, Flug und Uferbewegung sind vereinfachte Bewegungsregeln; keine vollständige Mehrkörper- oder Strömungssimulation.
