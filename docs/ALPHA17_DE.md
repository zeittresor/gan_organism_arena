# Alpha17 – ruhigere Fortbewegung und anatomische Gelenke

Version 1.0.0-alpha17, 2026-09-02. Auf Basis von Alpha16.

Die Lebewesen wenden mit begrenzter Drehgeschwindigkeit und Winkelbeschleunigung. Ihre eigene Antriebskraft folgt der Körperausrichtung; eine Kehrtwende beschreibt deshalb einen Bogen. Körperlänge, Muskelentwicklung, Panzerung und Flugzustand beeinflussen die Wendigkeit. Schwerkraft, Sprünge und Kontaktimpulse bleiben getrennt vom Bewegungsziel. Ein seitlicher Stoß richtet den Körper nicht sofort neu aus.

Nahrungsziele werden kurz beibehalten und erst bei einem deutlich besseren Ziel gewechselt. Verbrauchte oder versetzte Nahrung wird sofort verworfen. Auch Jäger bevorzugen ihr weiterhin geeignetes bisheriges Beutetier. Gefahrenreaktionen bleiben möglich; sie müssen nicht auf die nächste Nahrungssuche warten. Vor einem gerichteten Sprung richtet sich das Wesen zunächst aus. Nahezu senkrechte Schwimmrichtungen und Ziele genau hinter dem Körper verursachen keine wechselnden Links-/Rechtsentscheidungen mehr.

Die Animationsphase wird fortlaufend integriert. Zuvor wurde die gesamte verstrichene Zeit mit dem jeweils aktuellen Tempo multipliziert: Eine kleine Tempoänderung konnte nach längerer Laufzeit einen großen Sprung in der Gliedmaßenstellung erzeugen. Passende Gelenkstellungen bleiben nun auch beim erneuten Aufbau eines wachsenden Körpers erhalten.

## Welche Stellen sich bewegen können

- **Starre Teile:** Knochen, Horn, Schnabel, Schuppen, Federkiele und verholzte Abschnitte behalten ihre Form. Fest verbundene Teile übernehmen dieselbe räumliche Ausrichtung. Sie erhalten keine unabhängige Biegeanimation.
- **Gelenke mit Knorpel:** Bewegungen erfolgen zwischen starren Abschnitten um vorbereitete Gelenkachsen. Wirbelsäulensegmente haben kleine Bewegungsbereiche; Gliedmaßen können ausgeprägtere Gelenke besitzen. Schäfte zwischen Gelenken bleiben starr.
- **Flexible Verbindungen von Außenskeletten:** Segmentierte Panzer und entsprechende Beine nutzen bewegliche Verbindungen zwischen starren Teilen. Das Modell verlangt dafür nicht fälschlich überall Knorpel.
- **Muskulöse Weichkörper:** Geeignete Körperbau- und Stützmerkmale erlauben verteilte Biegung als schematischer muskulärer Hydrostat. So sind bewegliche Arme und andere knochenlose Formen möglich.

Gelenke haben einen Gewebetyp, eine Achse, einen maximalen Winkel, Muskelkapazität sowie eine begrenzte Bewegungsgeschwindigkeit und Beschleunigung. Ohne aktive Muskelkapazität gibt es keinen aktiven Gelenkhub oder eigenen Antrieb; äußere Kräfte können das Wesen weiterhin bewegen. Die Form jedes einzelnen starren Elements bleibt dabei unverändert. Die Bodenkontrolle berücksichtigt die tatsächlich gedrehte Form der Elemente.

Diese Zuordnung entsteht aus vorhandenen erblichen Körperbau-, Stütz-, Muskel-, Panzer- und Holzmerkmalen. Kreuzung und Mutation können ungewöhnliche Kombinationen erzeugen. Es gibt keinen Zwang zu einer bestimmten irdischen Art. Die 88 diploiden Merkmale, Fortpflanzungsmechanismen und bisherigen Einstellungen bleiben erhalten.

## Beobachten und prüfen

Die Auswahlansicht zeigt die Anzahl der Knorpelgelenke, flexiblen Panzerverbindungen, muskulösen Weichsegmente und aktiv angetriebenen Verbindungen. In der **Zellansicht (Taste 2)** markieren türkise Punkte Gelenke und rote Punkte die beweglichen Weichsegmente. In der natürlichen Ansicht bleiben die Verbindungen körperlich zusammenhängend.

Die optionalen KI-Abfragen enthalten jetzt außerdem `anatomy` und `locomotion`. Die ausführliche Organismusabfrage liefert `joints` mit Zell-/Elternindizes, Gewebemodus, Achse, Winkelgrenze in Radiant, aktuellem Winkel und Muskelkapazität. Dafür müssen keine Schnittstellen aktiviert werden, solange man die Welt nur normal benutzt.

Auf Windows besonders gut sichtbar: einem Tier mit Rechtsklick folgen, eine Kehrtwende beobachten, danach Zellansicht und Küste vergleichen. Schwimmen, ein Ziel hinter dem Körper, Bodenkontakt und gegebenenfalls Flug sollten ohne sofortiges Umklappen ablaufen. Kleine Berührungsabweichungen bleiben über den Kontaktregler in F10 einstellbar.

## Aufwand und Aussagekraft

Die Gelenkzuordnung wird beim Körperaufbau vorbereitet. Die bestehende Pose-Aktualisierung mit höchstens 20 Hz, das Körperteilbudget, Kontakt-Caches, räumliche Vorprüfungen und das Auslassen unsichtbarer Grafikaktualisierungen bleiben bestehen. Im Quellcode-Vergleichsszenario bleiben Anzahl der Körperteile und Grafikschreiboperationen gleich. Die neue Gelenkmechanik benötigt zusätzliche Rechenarbeit; daraus lässt sich keine Windows-FPS-Zahl ableiten.

Das ist ein ausführbares, vererbungsabhängiges mechanisches Körpermodell. Es ist noch keine biomechanische Vollsimulation: einzelne Muskelbündel, Sehnenzugkräfte, Gelenkbelastung und Bruch, Fuß-Inverskinematik und Selbstkollision sind nicht separat simuliert. Knorpel- und Muskelparameter sind dimensionslose Modellwerte, keine aus realen Tierarten gemessenen Materialkennlinien. Neue Formen entstehen innerhalb der implementierten Körpergrammatik, nicht durch die Entdeckung beliebiger neuer Naturgesetze.

Die neuen Bewegungs- und Gelenktests werden vom Windows-Installer gemeinsam mit den bisherigen Prüfungen ausgeführt. Der aktuelle Build wurde hier mit Quellcode- und Integrationstests geprüft; native Godot-/Windows-Darstellung und GPU-Leistung konnten hier nicht ausgeführt werden. Einzelheiten: [TESTING.md](TESTING.md).
