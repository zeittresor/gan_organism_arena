# Alpha21 — Korrektur des Installer-Selbsttests

Alpha20 brach bei vier Prüfungen ausgeblendeter Körperverbindungen ab. Der Test las Grafikdaten zurück, obwohl der Installer ohne Grafikdarstellung läuft. Die bisherige lokale Testnachbildung erkannte diesen Unterschied nicht.

Alpha21 vergibt ausschließlich für sichtbare Verbindungen Zeicheninstanzen. Die Körperhaltung wird zusätzlich in CPU-Daten gehalten, die Zeichnung und OBJ-Export gemeinsam verwenden. Damit ist der Export von der betreffenden Grafik-Rückabfrage unabhängig. Der Wechsel zwischen natürlicher Ansicht und Zellansicht wird mitgeprüft; die innere Anatomie bleibt in der Zellansicht verfügbar.

Die Verbesserungen für bewegliche Körperglieder, Uferhaltung und Kopfaufsätze aus Alpha20 sind enthalten. Die Installationsprüfungen bleiben aktiv. Bitte das ZIP in einen eigenen Ordner entpacken und install_windows.bat ausführen. Der Installer kann das gültige Godot-Archiv einer früheren Version wiederverwenden.

Die Quellcodeprüfungen und ein gezielter Exporttest bestehen. Ein nativer Windows-/Godot-Lauf war hier nicht möglich; Einzelheiten stehen in TESTING.md und BUILD_VERIFICATION.txt.
