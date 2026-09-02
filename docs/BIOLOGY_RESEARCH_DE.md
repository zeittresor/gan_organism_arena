# Biologisches Modell — alpha14

Die Welt ist das Hauptprogramm. Die folgenden Mechanismen laufen auch ohne MCP, VKLP, Netzwerk oder Python. Küste, Wasserstart, freie Kamera mit Mausrad, alle Ansichten, Habitate 5–9, Größenänderung, zufälliges Licht mit L, Klänge, Körperexport und Einstellungen aus alpha13 bleiben vorhanden.

## Vererbung statt Vermischen einzelner Merkmalszahlen

84 kontinuierliche Merkmalsloci besitzen jetzt jeweils zwei Allele. Bei sexueller Fortpflanzung liefert jedes Elternteil einen haploiden Satz. Benachbarte Loci liegen in Gruppen von höchstens 16 auf einer künstlichen Kopplungskarte. An Chromosomengrenzen wird ein Homolog unabhängig gewählt; zwischen benachbarten Loci beträgt die Wechselwahrscheinlichkeit 0,06. Diese Zahlen sind Parameter einer fiktiven Genetik, keine gemessenen irdischen Rekombinationskarten.

Ohne Mutation werden die vorhandenen Allele weitergegeben: Ein heterozygoter Elternteil erzeugt keine beliebigen Zwischenallele. Ein Teil der Merkmale zeigt partielle Dominanz; andere werden additiv exprimiert. Zwei heterozygote Eltern können deshalb die Genotypverteilung 1:2:1 erzeugen. Mutation verändert einzelne Allele; große Bauplanänderungen sind getrennt steuerbar und standardmäßig seltener als zuvor (0,014 statt 0,14 je Reproduktionsereignis).

Acht weitere, unabhängig segregierende Modellloci tragen rezessive Belastungen. Eine einzelne schädliche Kopie bleibt ohne diesen Effekt, zwei Kopien senken die genetische Gesundheit um 0,09 pro Locus. Verwandte Tiere erhalten keinen pauschalen Strafwert für ihre Familiennummer. Sie können jedoch dieselben verborgenen Allele weitergeben. Heterozygotie misst den Anteil unterschiedlicher Allelpaare an den 84 Merkmalsloci; sie ist keine allgemeine Fitnessnote.

Bei getrennten Geschlechtsrollen bestimmt eine vererbte XX/XY-artige Modellkonstellation die Rolle. Hermaphroditismus bleibt ein erbliches Merkmal. Diese Konvention bildet nicht alle natürlichen Geschlechtsbestimmungssysteme ab. Gelerntes Jagdverhalten und Werkzeugerfahrung werden nicht als erworbene Keimbahnmutationen vererbt.

## Entwicklung, Nahrung und Fortpflanzungsreserven

Alter allein macht ein Individuum nicht mehr erwachsen. Nach laufenden Erhaltungskosten investiert es überschüssige Energie in Entwicklung. Sauerstoff, genetische Gesundheit und Temperatur beeinflussen deren Geschwindigkeit. Unterhalb der Reserve von 0,22 steht dafür keine Energie zur Verfügung. Vollständige Entwicklung kostet je nach Größengen 0,24–0,44 Reserveeinheiten. Körpergröße, Larven-/Puppenstadien und reife Fortpflanzungsanatomie hängen an diesem Entwicklungsfortschritt.

Erwachsene produzieren kostenpflichtig getrennte Ei- und Spermienreserven. Hermaphroditen teilen ihr Produktionsbudget auf. Gametenbildung wandelt 85 Prozent des Aufwands in gespeicherte Reserve um; ein kleiner Anteil alter Gameten wird resorbiert. Fortpflanzung benötigt passende Rollen, kompatible Körper, räumlichen Kontakt, genügend Energie und tatsächlich aufgebaute Gameten. Eier kosten 0,26, ein Spermienbeitrag 0,055 und ein klonaler Propagulus 0,32 Einheiten. Die Anzahl möglicher Nachkommen wird durch Eierreserven und freie Populationsplätze begrenzt. Klone erhalten keine kostenlose Ersatzfortpflanzung bei fehlendem Partner.

Embryonen beginnen mit den eingezahlten Reserven. Furchung, Gastrulation, Organogenese und spätes Wachstum sind als Entwicklungsphasen auslesbar. Entwicklung verbraucht Reserven; Temperatur, Sauerstoff und Gesundheitszustand beeinflussen die Dauer. Die Temperaturfunktion verwendet ein experimentelles Q10 von 1,6. Versorgung durch das tragende Individuum, Eiablage, Eiaustrocknung, Fraß, Verlust, Geburt und Elternpflege bleiben aktiv. Die Phasennamen sind abstrakte Zustände, keine Simulation einzelner embryonaler Zellen.

Nahrungspartikel enthalten endliche Reserven. Nach dem Fressen entstehen nicht sofort neue volle Partikel: Die Reserve baut sich durch konfigurierbaren Nachschub wieder auf. Aufgenommene Nahrung und eingebrachter Partikelnachschub können beobachtet werden. Licht, pflanzliche Produktion und andere ökologische Nahrungsquellen bleiben weitere Eingänge. Das System behauptet daher keinen geschlossenen Kohlenstoff-/Stickstoffkreislauf.

## Was sich untersuchen lässt

Beobachtbar sind Segregation und Rekombination, rezessive Belastungen, Unterschiede zwischen Alter und Entwicklungsreife, Hunger und Wachstumsstillstand, Fortpflanzungsaufwand, temperaturabhängige Inkubation, Elternversorgung, Konkurrenz und Nachkommenerfolg. Eine Population muss nicht zwangsläufig Landgang, Flug oder hohe kognitive Werte entwickeln. Zufällige Verluste und Aussterben sind mögliche Ergebnisse; automatische Rettung bleibt optional.

Für belastbare Aussagen innerhalb des Modells mehrere Startwerte, ausreichend lange Beobachtung und gleiche Ausgangsbedingungen verwenden. Hypothesen aus externem Wissen können Versuche anregen. Ergebnisse belegen zunächst Zusammenhänge dieses Modells. Die Morphologie besitzt weiterhin sieben Topologiegrundformen mit variablen Anhängen und Oberflächen; molekulare Genregulation, echte Hormonsysteme und zellbasierte Embryologie sind keine schon implementierten Leistungen. Die vorhandenen Komplexitäts-/Intelligenzanzeigen bleiben Simulationswerte, keine validierten Intelligenztests.

## Fachliche Orientierung und Implementierung

- Chromosomenkopplung und Rekombination: [OpenStax Biology 2e, 13.1](https://openstax.org/books/biology-2e/pages/13-1-chromosomal-theory-and-genetic-linkage). Implementierung: `game/genome.gd`.
- Energieaufnahme und Allokation über den Lebenszyklus: [DEB Laboratory, Vrije Universiteit Amsterdam](https://www.bio.vu.nl/thb/deb/). Unsere Allokation ist daran orientiert, aber kein kalibriertes Standard-DEB-Modell. Implementierung: `game/physiology.gd`, `organism.gd`, `reproduction_system.gd`.
- Reproduzierbare Experimente und optionale Anbindungen: `docs/AI_INTERFACES_DE.md`.

Alle konkreten Koeffizienten und Genotyp-Körper-Zuordnungen sind ausdrücklich experimentelle Modellannahmen. Sie stehen im Quellcode und können in kontrollierten Vergleichen untersucht werden.
