extends RefCounted

# Language-independent state keys; fictional thought narration, not biological evidence.
const STATES = ["hunger", "fear", "hunt", "social", "curious", "reproduce", "observe"]
const CATALOG: Dictionary = {
    "de": {
        "states": [
            "Hunger",
            "Gefahr",
            "Jagd",
            "Nähe",
            "Neugier",
            "Fortpflanzung",
            "Beobachtung"
        ],
        "syllables": [
            [
                "na-ma",
                "Futter-aa",
                "mm-na"
            ],
            [
                "ka-Gefahr",
                "weg-weg",
                "nein-ka"
            ],
            [
                "such-ra",
                "geh-ka",
                "Beute-ta"
            ],
            [
                "Sippe-la",
                "nah-wir",
                "komm-la"
            ],
            [
                "was-oo",
                "neu-ka",
                "seh-na"
            ],
            [
                "neu-Sippe",
                "mach-la",
                "wachs-wir"
            ],
            [
                "sehen",
                "bewegen",
                "hier"
            ]
        ],
        "tokens": [
            [
                "ENERGIE NIEDRIG",
                "FUTTER NAH?",
                "FUTTER SUCHEN"
            ],
            [
                "GEFAHR NAH",
                "WEG BEWEGEN",
                "VERSTECKEN / WENDEN"
            ],
            [
                "BEUTE VERFOLGEN",
                "ABSTAND VERKÜRZEN",
                "RAUM BEANSPRUCHEN"
            ],
            [
                "SIPPE NAH",
                "FAMILIE FOLGEN",
                "RAUM TEILEN"
            ],
            [
                "NEUES SIGNAL",
                "LICHT UNTERSUCHEN",
                "UNBEKANNTE FORM"
            ],
            [
                "ENERGIE HOCH / FORTPFLANZEN",
                "NACHWUCHS ZEUGEN",
                "MUSTER WEITERGEBEN"
            ],
            [
                "TREIBEN / SCHAUEN",
                "RUHIGES WASSER",
                "UMGEBUNG PRÜFEN"
            ]
        ],
        "phrases": [
            [
                "Ich brauche Energie in der Nähe.",
                "Dort suchen, wo es viel Nahrung gibt.",
                "Ich sollte fressen, bevor ich weiterziehe."
            ],
            [
                "Etwas in der Nähe wirkt gefährlich.",
                "Von dieser Bewegung wegdrehen.",
                "Abstand halten und Energie bewahren."
            ],
            [
                "Dieses schwächere Signal könnte nützlich sein.",
                "Vorsichtig nähern, dann die Nahrung nehmen.",
                "Ich kann diesen Bereich behaupten."
            ],
            [
                "Meine Verwandten sind in der Nähe.",
                "Bei den vertrauten Signalen bleiben.",
                "Gemeinsam sind wir vielleicht sicherer."
            ],
            [
                "Dieses Muster habe ich noch nicht untersucht.",
                "Ich möchte die unbekannte Bewegung erkunden.",
                "In dieser Richtung verändert sich die Umgebung."
            ],
            [
                "Ich habe genug Energie für die Fortpflanzung.",
                "Ein Nachkomme könnte hier überleben.",
                "Dieses Körpermuster könnte ich weitergeben."
            ],
            [
                "Die Strömung ist hier ruhig.",
                "Beim Treiben beobachte ich weiter.",
                "In der Nähe verändert sich nichts Dringendes."
            ]
        ],
        "memory": "Ich erinnere mich an %s, und das beeinflusst meinen nächsten Schritt.",
        "body": "Mein Körper erreicht Komplexität %.1f, mein Denkvermögen %.2f.",
        "compare": "Ich vergleiche die Gegenwart mit früheren Ereignissen: %s. Der Unterschied ist bedeutsam.",
        "motive": "Ich unterscheide Hunger, Gefahr, Verwandtschaft und Neues; gerade bestimmt %s meine Entscheidung.",
        "variation": "Meine Nachkommen müssen mir nicht genau gleichen; Variation kann andere Lösungen für diese Umwelt ermöglichen.",
        "composition": "Meine Signale werden zusammengesetzt: Ich verbinde ein Objekt, eine Richtung und eine Absicht statt nur einen Ruf auszugeben.",
        "perspective": "Ich beginne einzuschätzen, was andere Wesen wahrnehmen; Zusammenarbeit und Täuschung werden verschiedene Möglichkeiten.",
        "clauses": [
            "meine Energie beträgt %.2f",
            "meine Körperkomplexität beträgt %.1f",
            "mein aktueller Antrieb ist %s",
            "meine letzte Erinnerung ist %s",
            "ich habe %d Nachkommen",
            "ich gehöre zu %s, Generation %d",
            "meine Neugier beträgt %.2f",
            "mein Sozialtrieb beträgt %.2f"
        ],
        "integrate": "Ich verbinde mehrere Beobachtungen: ",
        "and": ", und ",
        "memories": [
            "keine prägende Erfahrung",
            "instabile Entwicklung",
            "Erschöpfung",
            "Atemnot oder Erschöpfung",
            "einen Angriff",
            "Nahrungsaufnahme",
            "eine erfolglose Befruchtung",
            "eine befruchtete Brut",
            "die Geburt eines Nachkommen",
            "den Verlust einer Brut",
            "eine frühere Begegnung"
        ]
    },
    "fr": {
        "states": [
            "la faim",
            "le danger",
            "la chasse",
            "la proximité",
            "la curiosité",
            "la reproduction",
            "l’observation"
        ],
        "syllables": [
            [
                "na-ma",
                "nourriture-aa",
                "mm-na"
            ],
            [
                "ka-danger",
                "va-va",
                "non-ka"
            ],
            [
                "cherche-ra",
                "bouge-ka",
                "proie-ta"
            ],
            [
                "famille-la",
                "près-nous",
                "viens-la"
            ],
            [
                "quoi-oo",
                "neuf-ka",
                "vois-na"
            ],
            [
                "nouvelle-famille",
                "fais-la",
                "crois-nous"
            ],
            [
                "voir",
                "bouger",
                "ici"
            ]
        ],
        "tokens": [
            [
                "ÉNERGIE BASSE",
                "NOURRITURE PROCHE ?",
                "CHERCHER À MANGER"
            ],
            [
                "DANGER PROCHE",
                "S’ÉLOIGNER",
                "SE CACHER / TOURNER"
            ],
            [
                "SUIVRE LA PROIE",
                "RÉDUIRE LA DISTANCE",
                "OCCUPER L’ESPACE"
            ],
            [
                "FAMILLE PROCHE",
                "SUIVRE LA FAMILLE",
                "PARTAGER L’ESPACE"
            ],
            [
                "NOUVEAU SIGNAL",
                "EXAMINER LA LUMIÈRE",
                "FORME INCONNUE"
            ],
            [
                "ÉNERGIE HAUTE / REPRODUCTION",
                "ENGENDRER DES PETITS",
                "TRANSMETTRE LE MOTIF"
            ],
            [
                "DÉRIVER / OBSERVER",
                "EAU CALME",
                "EXAMINER AUTOUR"
            ]
        ],
        "phrases": [
            [
                "Il me faut de l’énergie à proximité.",
                "Chercher là où la nourriture est abondante.",
                "Je devrais manger avant d’aller plus loin."
            ],
            [
                "Quelque chose paraît dangereux à proximité.",
                "S’écarter de ce mouvement.",
                "Garder ses distances et économiser l’énergie."
            ],
            [
                "Ce signal plus faible peut être utile.",
                "Approcher prudemment, puis prendre la nourriture.",
                "Je peux occuper cette zone."
            ],
            [
                "Ma famille est proche.",
                "Rester près des signaux familiers.",
                "Ensemble, nous sommes peut-être plus en sécurité."
            ],
            [
                "Je n’ai pas encore examiné ce motif.",
                "Je veux explorer ce mouvement inconnu.",
                "Le milieu change dans cette direction."
            ],
            [
                "J’ai assez d’énergie pour me reproduire.",
                "Un descendant pourrait survivre ici.",
                "Je pourrais transmettre cette forme corporelle."
            ],
            [
                "Les courants sont calmes ici.",
                "Je continue d’observer en dérivant.",
                "Rien d’urgent ne change à proximité."
            ]
        ],
        "memory": "Je me souviens de %s, et cela influence mon prochain choix.",
        "body": "La complexité de mon corps atteint %.1f et ma cognition %.2f.",
        "compare": "Je compare le présent aux événements passés : %s. La différence compte.",
        "motive": "Je distingue faim, danger, famille et nouveauté ; actuellement, %s guide ma décision.",
        "variation": "Mes descendants ne doivent pas me ressembler exactement ; la variation peut apporter de nouvelles solutions dans ce milieu.",
        "composition": "Mes signaux deviennent composés : je combine un objet, une direction et une intention au lieu de produire un seul appel.",
        "perspective": "Je commence à imaginer ce que perçoivent les autres ; coopération et tromperie deviennent des possibilités distinctes.",
        "clauses": [
            "mon énergie vaut %.2f",
            "ma complexité corporelle vaut %.1f",
            "ma motivation actuelle est %s",
            "mon dernier souvenir est %s",
            "j’ai engendré %d descendants",
            "j’appartiens à %s, génération %d",
            "ma curiosité vaut %.2f",
            "ma sociabilité vaut %.2f"
        ],
        "integrate": "Je relie plusieurs observations : ",
        "and": ", et ",
        "memories": [
            "aucune expérience marquante",
            "un développement instable",
            "l’épuisement",
            "une difficulté respiratoire ou un épuisement",
            "une attaque",
            "un repas",
            "une fécondation infructueuse",
            "une couvée fécondée",
            "la naissance d’un descendant",
            "la perte d’une couvée",
            "une rencontre passée"
        ]
    }
}

static func options(org, state: String, language: String) -> Array:
    var catalog: Dictionary = CATALOG.get(language, CATALOG["de"])
    var index: int = maxi(0, STATES.find(state))
    var stage: int = org.language_stage
    if stage <= 0: return org._proto_sounds(state)
    if stage == 1: return catalog["syllables"][index].duplicate()
    if stage == 2: return catalog["tokens"][index].duplicate()
    var result: Array = catalog["phrases"][index].duplicate()
    if stage < 4: return result
    var memory: String = memory_text(org._memory_fragment(), catalog)
    result.append(catalog["memory"] % memory)
    result.append(catalog["body"] % [org.complexity, org.intelligence])
    if stage < 5: return result
    result.append(catalog["compare"] % memory)
    result.append(catalog["motive"] % catalog["states"][index])
    result.append(catalog["variation"])
    if stage >= 6: result.append(catalog["composition"])
    if stage >= 7: result.append(catalog["perspective"])
    var templates: Array = catalog["clauses"]
    var clauses: Array = [templates[0] % org.energy, templates[1] % org.complexity, templates[2] % catalog["states"][index], templates[3] % memory, templates[4] % org.children, templates[5] % [org.family_name, org.genome.generation], templates[6] % org.curiosity_state, templates[7] % org.social_state]
    var count: int = clampi(2 + int((stage - 5) / 2), 2, 6)
    var start: int = abs((org.thought_counter * 3 + org.organism_id) % clauses.size())
    var composed: String = catalog["integrate"]
    for i in range(count):
        if i > 0: composed += str(catalog["and"]) if i == count - 1 else "; "
        composed += clauses[(start + i) % clauses.size()]
    result.append(composed + ".")
    return result

static func memory_text(event: String, catalog: Dictionary) -> String:
    var keys: Array = ["no strong event yet", "unstable development", "energy collapse", "respiration or energy collapse", "attacked by", "fed", "fertilization unsuccessful", "fertilized brood:", "offspring born:", "brood lost"]
    for i in range(keys.size()):
        if event.begins_with(keys[i]):
            var suffix: String = event.trim_prefix(keys[i]).strip_edges()
            return str(catalog["memories"][i]) + (" #" + suffix if suffix.is_valid_int() else "")
    return catalog["memories"][10]
