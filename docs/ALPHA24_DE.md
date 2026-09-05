# Alpha24 – Populationssicherung, Elternmischung und neue DNA-Baupläne

## Automatische Nachbesetzung

Die bisherige Funktion war tatsächlich unvollständig: Sie wurde ausschließlich innerhalb der Schleife ausgelöst, die in genau diesem Simulationsschritt verstorbene Organismen entfernte. War die Liste bereits leer, fehlte ein neues Todesereignis als Auslöser. Außerdem entstand pro erkanntem Tod höchstens ein Gründer.

Alpha24 trennt beide Aufgaben. Nach jeder Bereinigung prüft die Welt unabhängig vom vorherigen Zustand den lebenden Bestand. **Automatic reseed** ist bei einer neuen oder einmalig migrierten Installation standardmäßig aktiv. Der neue F10-Regler **Ziel der automatischen Nachbesetzung** steht auf 5 und kann zwischen 1 und 80 gewählt werden. Der wirksame Zielwert bleibt auf die Populationsgrenze begrenzt. Reservierte Embryonen blockieren weiterhin Plätze, zählen aber nicht als bereits lebende Tiere. Wird die Funktion abgeschaltet, ist vollständiges Aussterben weiterhin ein zulässiges Versuchsergebnis.

Eine Nachbesetzung füllt den gesamten verfügbaren Fehlbestand in derselben Prüfung. Jeder Ersatz ist ein neuer, unverwandter Organismus mit eigener zufällig erzeugter diploider DNA, beginnt im Stadium `hatchling` mit Alter 0 und wird in zugänglichem Wasser platziert. Ereignisse unterscheiden einzelne `founder_injection`-Datensätze samt Grund von der zusammenfassenden `population_rescue`-Meldung.

## Neue Formen müssen entstehen

Automatisch eingesetzte Ahnen stammen nur noch aus drei breit aquatischen Grundtopologien: länglich, stromlinienförmig oder flach/ray-artig. Ihre Größe liegt zunächst in einem mittleren Bereich. Gallertartig-radiale, verzweigte, krustentierartige und cephalopodenartige Topologien werden von dieser Sicherung nicht fertig eingesetzt. Sie können in späteren Generationen durch Rekombination oder Makromutation auftreten. Der manuelle G-Befehl bleibt absichtlich ein freier Sandbox-Eingriff.

Der Bauplan war vorher vererbbar, aber technisch noch ein separates Kategorienfeld. Nun ist `body_plan_code` der 89. quantitative diploide Genort. Er erscheint in den A/C/G/T-artigen Chromosomen des DNA-Exports, wird bei der Meiose getrennt und aus je einem elterlichen Allel wieder zusammengesetzt. Eine Makromutation verändert den gespeicherten Code dauerhaft. Erst die Genexpression ordnet seinen Wert einer der sieben prozeduralen Körpergrammatiken zu; anschließend erzeugen Entwicklung, Anatomie und Physik den tatsächlichen Körper.

Damit kann eine Population Formen hervorbringen, die in ihren Ahnen nicht vorkamen. Die sieben Grammatiken und ihre kontinuierlichen Genkombinationen können sehr viele neue Mischformen, winzige oder massive Körper, verschiedene Hüllen und Lebensweisen erzeugen. Das ist dennoch keine unbegrenzte generative Geometrie und garantiert weder „Qualle“, „Wal“ noch eine andere irdische Art. Eine Form bleibt nur erhalten, wenn Atmung, Stützgewebe, Energiebedarf, Nahrung, Fortbewegung und Habitat zusammen funktionieren.

## Vererbung und Pigment

Bei sexueller Fortpflanzung enthält das Kind weiterhin für jeden diploiden Genort ein reales Ei-Allel und ein reales Spermien-Allel. Neue Prüfungen verfolgen dies beispielhaft für Stütz-/Skelettneigung, Gliedmaßen, Muskeln, Haut, Schale, Fell sowie Aggression und Neugier. Erlernte Erinnerungen oder Fertigkeiten werden nicht in die Keimbahn geschrieben.

Haut, Schuppen, Panzer/Schale, Federn und Fell leiten ihre sichtbaren Varianten von einer gemeinsamen vererbten Grundpigmentierung ab. Der Farbton wird jetzt auf dem geschlossenen HSV-Farbkreis gemischt: 0,97 und 0,03 liegen beide nahe Rot und ergeben daher wieder Rot statt des linearen, biologisch unplausiblen Cyan-Mittels.

## Optionen und Schnittstellen

Schalter und Zielwert besitzen vollständige EN/DE/FR-Bezeichnungen und Tooltips, werden in normalen Einstellungen sowie Profilen gespeichert und gelten live – auch wenn die Welt beim Einschalten bereits leer ist. Optional angebundene KI-Systeme sehen `auto_reseed` und `minimum_population` und können beide nur durch einen ausdrücklichen Parameteraufruf beeinflussen. Das Aktivieren von MCP oder VKLP allein verändert weiterhin keine Funktion und reduziert weder Bedienung noch Simulation.

Modellkennung: `arena-biology-7`; Beobachtungsschema: weiterhin additiv kompatibel `arena.observation/1`.
