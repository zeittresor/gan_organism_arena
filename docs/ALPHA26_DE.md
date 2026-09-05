# Alpha26: kleinere, vielfältigere und nahtlose Texturen

Die drei bisherigen PNG-Dateien waren mit 1254×1254 Pixeln unnötig groß, obwohl die Laufzeit sie auf 128×128 verkleinert. Alpha26 liefert deshalb zehn austauschbare 256×256-Vorlagen mit zusammen ungefähr 708 KB: sechs Körpermuster und vier Geländeoberflächen.

Alle Dateien besitzen identische gegenüberliegende Randpixel; die angrenzenden Bereiche werden weich überblendet. Dadurch können sie wiederholt und bilinear gefiltert werden, ohne eine harte Kachelnaht zu erzeugen. Die Geländeauswahl hängt vom Habitat ab.

Gründer erhalten anhand ihres Saatwerts und ihrer Hüllenmerkmale eine gewichtete Kombination aus zwei Körpervorlagen. Bei sexueller Fortpflanzung werden sowohl diese Vorlagenanteile als auch – bei aktivierter Darstellung – die tatsächlichen Pixelbilder beider Eltern je zur Hälfte kombiniert. Ein Enkel erbt daher die bereits gemischte Textur seiner Eltern weiter. Klone erhalten eine unabhängige Kopie.

Die Funktion bleibt standardmäßig ausgeschaltet. Solange sie ausgeschaltet ist, werden keine PNGs geladen und keine Bild- oder GPU-Ressourcen erzeugt. Bei aktiver Funktion bleiben Laufzeitbilder auf 128×128 begrenzt und werden nur bei Bedarf erzeugt.
