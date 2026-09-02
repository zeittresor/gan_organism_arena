# Optionale KI-Anbindungen — MCP und VKLP

Die vollständige Anwendung läuft ohne diese Module. Der normale Installer und alle normalen Startdateien benötigen nur den mitgeliefert/portabel installierten Godot-Laufzeitpfad. Python 3.10+ ist ausschließlich für die optionalen Adapter erforderlich; diese verwenden nur die Python-Standardbibliothek und installieren keine Pakete.

## Kein Funktionsverlust durch Aktivierung

Eine Verbindung lässt die Welt normal weiterlaufen. Kamera, Mausrad, Wasser/Licht, Habitate, Weltgröße, Auswahl, Ansichten, Klänge, Injektion, Reset, Export und Optionen bleiben bedienbar. MCP- und VKLP-Aktivierung ändern weder Biologieparameter noch Population. Nur ein ausdrücklich aufgerufenes Werkzeug verändert die Welt. VKLP-Lesezugriffe starten nicht einmal eine Arena, falls noch keine angefordert wurde.

`arena_mode` mit `mode="stepped"` wählt ausdrücklich einen Versuch mit festen Zeitschritten. Auch dabei bleiben die bisherigen Bedienelemente verfügbar. `mode="live"` kehrt zur laufenden Welt zurück; Leertaste kann ebenfalls den Schrittbetrieb verlassen. Manuelle Änderungen werden, soweit sie den Weltzustand betreffen, als Ereignisse erfasst. Für reproduzierbare Versuche sollten keine zusätzlichen unprotokollierten externen Eingriffe erfolgen. Ein sichtbares Spielfenster wird beim Trennen der MCP-Verbindung weiterlaufen; eine ausschließlich für den Adapter gestartete Headless-Instanz wird beendet.

## MCP anschließen

1. Das Projekt normal installieren und in **F10 → MCP-Zugriff erlauben** einschalten. Python 3.10+ nur installieren/bereitstellen, wenn die Anbindung gewünscht ist.
2. In einem MCP-Client einen **stdio**-Server mit folgendem Startbefehl eintragen; den Pfad an den eigenen Ordner anpassen:

```json
{
  "mcpServers": {
    "organism-arena": {
      "command": "py",
      "args": ["-3", "E:\\YOUR_FOLDER\\GAN_Organism_Arena\\integrations\\arena_mcp.py"]
    }
  }
}
```

Alternativ kann ein Client `run_mcp.bat` über `cmd.exe /d /c` starten. Die Batchdatei ist ein Protokollprozess und öffnet beim Doppelklick keinen Chat. Ein lauffähiger Client liegt als `integrations/arena_client.py` bei. `run_ai_example.bat` führt zwei explizite, kontrollierte Nahrungsexperimente aus und exportiert deren Daten. Dadurch wird die Simulationspopulation für diese Versuche zurückgesetzt.

Der Adapter startet bei der ersten Arena-Anfrage das sichtbare Godot-Fenster oder verbindet sich wieder mit der von ihm gestarteten Sitzung desselben Projektordners. `--headless` ist eine bewusst gewählte Alternative. `--godot PFAD` erlaubt ein anderes lokal vorhandenes Godot-Programm. Es werden keine Laufzeitarchive über diese Schnittstelle heruntergeladen.

Standardport für den internen Godot-Kanal: 8766, nur `127.0.0.1`, mit zufälligem Sitzungstoken. Für parallele Instanzen verschiedene `--port`-Werte verwenden. Das lokale Token liegt für erneutes Verbinden in `runtime/arena-session-PORT.json`; diese Datei nicht teilen. Protokollmeldungen gehen nach stdout, Godot-Meldungen in `logs/ai-godot-*.log`. Bei ausgeschalteten MCP- und VKLP-Schaltern wird kein Port geöffnet. Ein aktivierter Schalter öffnet den lokalen Kanal bereits im normalen Spielstart; der Adapter kann die laufende Welt übernehmen.

Wer eine Instanz selbst startet, setzt `ARENA_API_PORT` und `ARENA_API_TOKEN` (mindestens 32 Zeichen), startet Godot mit `-- --arena-api` und verwendet den Adapter mit `--attach --port PORT` und demselben Token. `--attach` beendet die fremd gestartete Instanz nicht.

Implementiertes MCP-Profil: stdio/JSON-RPC mit Initialisierung, `notifications/initialized`, Tools und Resources; unterstützte Revisionen 2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25. Der Adapter behauptet keine Unterstützung neuerer Revisionen. Protokollgrundlage: [MCP stdio](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) und [MCP Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).

## Nutzbare Werkzeuge

| Werkzeug | Wirkung |
|---|---|
| `arena_observe` | Lebende Individuen, Brut, Umwelt und Energiereserven abfragen |
| `arena_organism` | Allele, exprimierte Gene, Eltern und Physiologie eines Individuums lesen |
| `arena_events` | Befruchtungen, Geburten, Verluste und Eingriffe ab einem Cursor lesen |
| `arena_mode` | Ausdrücklich zwischen normalem Lauf und Schrittbetrieb wechseln |
| `arena_reset` | Neue Population mit Startwert und Parametern; aktuelle Betriebsart bleibt erhalten |
| `arena_step` | Im gewählten Schrittbetrieb 1–120 Schritte à 1/12 Simulationssekunde ausführen |
| `arena_parameters` | Umwelt-/Selektionsparameter ändern, optional mit Quellenangabe |
| `arena_export` | Einen konsistenten Weltzustand einschließlich aller Genome und Modellannahmen als JSON speichern |
| `arena_claim_draft` | Einen lokalen VKLP-Entwurf mit Versuchsevidenz erzeugen |

Resources: `arena://model` beschreibt Einheiten, Annahmen und Parametergrenzen; `arena://observation` liefert den aktuellen Zustand. Das Modell bleibt dieselbe Godot-Simulation, auch bei KI-Steuerung.

Beispiel für einen eigenen KI-Client:

```python
from integrations.arena_client import ArenaClient

with ArenaClient() as arena:
    arena.call("arena_mode", mode="stepped")
    arena.call("arena_reset", seed=1337,
               parameters={"initial_organisms": 16, "nutrient_renewal": 0.5})
    arena.call("arena_step", steps=120)
    state = arena.call("arena_observe")
    genome = arena.call("arena_organism", id=state["organisms"][0]["id"])
    evidence = arena.call("arena_export")
    arena.call("arena_mode", mode="live")
```

Freie Population und Anfangsnahrung können beim Reset gesetzt werden. Während eines Laufs sind unter anderem Nachschub, Temperaturversatz, Mutationsstärke, große Mutationen, Prädations- und Gruppenstärke veränderbar. Grenzen stehen in `arena://model`. Änderungen von Individuen-/Partikelzahlen über die KI verlangen einen ausdrücklichen Reset; die bisherigen Menüsteuerungen bleiben separat verfügbar.

## VKLP in beide Richtungen

Referenz ist **[zeittresor/VKLP](https://github.com/zeittresor/VKLP)**: Verifiable Knowledge Ledger Profile, Research Prototype 0.1, konkret `service.py`, `ProposeRequest` und `Evidence`. Am 2026-09-02 mit dem GitHub-Stand abgeglichen; die getesteten Referenzdateien sind identisch (Git-Blobs models.py `1550e64638d61f5da2751bb23f776d9a12ff822b`, service.py `db2ebe1026d1dae0407cc4f1592bf55f0b3534e6`). Es wird kein andersartiges Protokoll unter demselben Namen erfunden.

Den bestehenden Dienst separat starten. In F10 VKLP erlauben und seine Dienstadresse einstellen. Beispieladresse:

```text
--vklp-url http://127.0.0.1:8787
```

`VKLP_API_KEY` enthält den vorhandenen API-Schlüssel. Für externe Dienste HTTPS verwenden. Die URL wird in **F10 → VKLP-Dienstadresse** gespeichert. **VKLP-Zugriff erlauben** gilt für jeden Zugriff; **VKLP-Einsendungen erlauben** zusätzlich für Claims. Die Werkzeuge werden konsistent angeboten, verweigerte Berechtigungen jedoch bei jedem Aufruf geprüft. Kommandozeilenargumente umgehen diese Schalter nicht. Der API-Schlüssel bleibt ausschließlich in der Umgebungsvariable.

| Richtung/Werkzeug | Konkreter Ablauf |
|---|---|
| Wissen lesen: `vklp_search`, `vklp_get_claim` | Bestehende Claims einschließlich Evidenz, Status und Voten vom Dienst abrufen |
| Wissen anwenden: `vklp_apply_claim` | Claim abrufen und ausdrücklich ausgewählte Arena-Parameter mit dieser Provenienz ändern |
| Welt → Erkenntnis: `arena_claim_draft` | Aussage auf Modell, Startwert und Versuchsschritt beziehen; JSON-Evidenz mit SHA-256 erzeugen |
| Erkenntnis einreichen: `vklp_submit_draft` | Nur mit aktivierter Einsendefreigabe und explizitem Aufruf den Entwurf an `/claims/propose` übergeben |
| Integrität: `vklp_verify_ledger` | Dienstseitige Prüfung über `/ledger/verify` abfragen |

Damit können Zusatzinformationen Versuche oder die fiktive Welt beeinflussen und neue Beobachtungen zurückfließen. `vklp_apply_claim` nimmt `claim_id`, `parameters` und optional `as_hypothesis`. Nicht akzeptierte, etwa umstrittene oder vorläufige Claims können mit `as_hypothesis=true` als gekennzeichnete Versuchshypothese verwendet werden. Es gibt keine stille Umwandlung eines Textes in Code oder eine automatische Behauptung, der Text beweise die gewählten Parameter.

Auch `arena_parameters` akzeptiert `provenance={"source": "…", "reference": "…", "status": "…"}` für Informationen aus MCP oder anderen Quellen. Einträge halten Ursache und Eingriff zusammen. Der VKLP-Adapter bewahrt die vom Dienst gelieferten Status, Minderheitsvoten und Unsicherheiten. Er erzeugt keine eigenen Validator-Unterschriften. Eine erfolgreiche Ledgerprüfung bestätigt nicht die wissenschaftliche Wahrheit einer Aussage.

Die Einreichung verwendet das tatsächliche VKLP-Format mit `claim`, `language`, `domain`, `evidence`, `proposer`, `supersedes`, `metadata`. Simulationsclaims tragen `simulation_only=true`. Eine kompakte numerische Evidenz ist im Claim enthalten; vollständige lokale JSON-Dateien werden nicht ungefragt hochgeladen. Entfernte Validatoren brauchen gegebenenfalls separat zugänglich gemachte Dateien für weitergehende Prüfung.

## Messdaten und Prüfungen

`logs/experiments/` enthält JSONL-Aufrufprotokolle mit fortlaufender Hashverkettung, JSON-Zustände mit Genomen und lokale Claim-Entwürfe. Hashprüfung:

```text
py -3 integrations/verify_transcript.py logs/experiments/run-ID.jsonl
```

Der In-Memory-Ereignispuffer der Welt hält 2048 Einträge. `arena_events` meldet abgeschnittene Vorgeschichte als `gap`; nach einem Reset müssen Revision und Cursor neu übernommen werden. Die Dateiprotokolle bleiben bestehen. Rohes Netzwerkprotokoll, Einheiten und Modellstand sind explizit versioniert; Quellcode-Hash und vollständige Versuchseinstellungen stehen in den Exporten.

Standalone-Tests: `py -3 -m unittest discover -s tests -v`. Nach Installation: `py -3 tests/live_arena_check.py --headless` prüft die echte Godot/MCP-Kette und Reproduzierbarkeit. Dieser native End-to-End-Test konnte in der Buildumgebung ohne Godot nicht ausgeführt werden. Der Python-Adapter wurde über stdio/TCP mit der übersetzten tatsächlichen Simulationslogik geprüft; VKLP wurde zusätzlich über HTTP gegen deinen originalen Dienst mit Testantworten der Validatoren geprüft.

## Direkte VKLP-Nutzung ohne MCP

Nur VKLP einschalten; MCP kann ausgeschaltet bleiben. Der direkte Python-Client verwendet das tatsächliche VKLP-HTTP-Profil und den getrennt berechtigten lokalen Weltkanal:

```text
py -3 integrations/arena_vklp.py search "aquatische Nahrungsketten"
py -3 integrations/arena_vklp.py verify
py -3 integrations/arena_vklp.py observe
py -3 integrations/arena_vklp.py export
py -3 integrations/arena_vklp.py claim "Die beobachtete Population umfasst acht Individuen."
```

`claim` erstellt standardmäßig nur einen lokalen Entwurf. `--submit` sendet ihn ausdrücklich an VKLP und benötigt zusätzlich die Einsendefreigabe. `apply CLAIM_ID --parameters '{"nutrient_renewal":0.5}'` ist eine bewusst angeforderte Parameteränderung anhand einer nachgeschlagenen Aussage; das JSON unter Windows passend zur verwendeten Shell quoten. Nicht akzeptierte Aussagen benötigen zusätzlich `--as-hypothesis`.

Ausschalten wirkt auf folgende Anfragen auch bereits laufender Adapter. Falls das gesperrte Protokoll den Schrittbetrieb angefordert hatte, kehrt die Welt zum normalen Lauf zurück. Die Menüs bleiben in jeder Kombination bedienbar. Es werden beim bloßen Einschalten weder Claims abgerufen noch Daten gesendet. Einstellungen und ihre Profile enthalten keine Sitzungstoken oder VKLP-API-Schlüssel.
