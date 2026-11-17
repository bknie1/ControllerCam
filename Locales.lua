-- ControllerCam localization.
--
-- The English text is the lookup key (L["Some text"]). Translations are listed in the SAME ORDER as the
-- ENGLISH list below, one table per game locale. Anything missing falls back to English: the interface
-- (labels, situations, profile names, buttons, messages) is translated, the long profile descriptions and the
-- /ccam help text are English for now, and sit at the end of the list. Keep %s / %d / %.1f placeholders in the
-- same order when adding or fixing a language.

local ADDON, ns = ...

local ENGLISH = {
    "In a vehicle",  -- 1
    "Flying",  -- 2
    "Swimming",  -- 3
    "Mounted",  -- 4
    "In combat",  -- 5
    "In a raid",  -- 6
    "In a dungeon",  -- 7
    "In a city or inn",  -- 8
    "Everywhere else (default)",  -- 9
    "Action",  -- 10
    "Hybrid",  -- 11
    "Classic",  -- 12
    "Shooter",  -- 13
    "Tactical",  -- 14
    "Cinematic",  -- 15
    "Target focus",  -- 16
    "Raid view",  -- 17
    "Mounted cruise",  -- 18
    "Town stroll",  -- 19
    "Zoom",  -- 20
    "Controller",  -- 21
    "Facing",  -- 22
    "Shoulder",  -- 23
    "Head tracking",  -- 24
    "Targets",  -- 25
    "Smoothing",  -- 26
    "Camera distance (yards)",  -- 27
    "Maximum zoom-out factor",  -- 28
    "Stick turn speed (left/right)",  -- 29
    "Stick look speed (up/down)",  -- 30
    "Camera follows the way you move",  -- 31
    "Follow speed (left/right)",  -- 32
    "Follow speed (up/down)",  -- 33
    "Delay before follow resumes",  -- 34
    "Face movement direction (max angle)",  -- 35
    "Face movement direction in combat (max angle)",  -- 36
    "Turn character with camera",  -- 37
    "Face movement direction on a mount",  -- 38
    "Face movement direction when swimming",  -- 39
    "Face movement direction when flying",  -- 40
    "Over-the-shoulder offset",  -- 41
    "Over-the-shoulder offset by zoom",  -- 42
    "Dynamic pitch (cinematic tilt)",  -- 43
    "Head tracking strength",  -- 44
    "Head tracking while standing",  -- 45
    "Head tracking while moving",  -- 46
    "Head tracking range",  -- 47
    "Look toward your target",  -- 48
    "Target focus strength (left/right)",  -- 49
    "Target focus strength (up/down)",  -- 50
    "Look toward NPCs you talk to",  -- 51
    "Interaction focus strength (left/right)",  -- 52
    "Interaction focus strength (up/down)",  -- 53
    "Camera auto-follow (mouse and keyboard)",  -- 54
    "never",  -- 55
    "in combat",  -- 56
    "always",  -- 57
    "in combat or casting",  -- 58
    "only when moving",  -- 59
    "on",  -- 60
    "off",  -- 61
    "Profiles",  -- 62
    "Enable ControllerCam",  -- 63
    "Quick pick (use one profile everywhere):",  -- 64
    "Recommended setup",  -- 65
    "(no change)",  -- 66
    "Use everywhere",  -- 67
    "Make a copy",  -- 68
    "Save my current camera",  -- 69
    "Export",  -- 70
    "Import",  -- 71
    "Close",  -- 72
    "Delete",  -- 73
    "game default",  -- 74
    "Default",  -- 75
    "My profile",  -- 76
    "copy",  -- 77
    "forced",  -- 78
    "custom",  -- 79
    "no change",  -- 80
    "current",  -- 81
    "nothing applied yet",  -- 82
    "Now: %s (%s)",  -- 83
    "Now: nothing applied yet",  -- 84
    "Mirror the shoulder offset (other shoulder)",  -- 85
    "Keep a situation for %.1f s after it ends",  -- 86
    "Slash commands: /ccam help",  -- 87
    "Profile for each situation (the first one that applies wins, from the top):",  -- 88
    "Done.",  -- 89
    "Using '%s' everywhere.",  -- 90
    "Recommended setup applied.",  -- 91
    "Saved as '%s'.",  -- 92
    "Deleted '%s'.",  -- 93
    "enabled",  -- 94
    "disabled. Your original camera settings were restored.",  -- 95
    "Imported '%s'. /ccam use \"%s\" to try it.",  -- 96
    "That is not a ControllerCam profile string.",  -- 97
    "Nothing to import.",  -- 98
    "The string is too long to be a profile.",  -- 99
    "This profile was made with a newer version of ControllerCam. Please update the addon.",  -- 100
    "The string is damaged (checksum mismatch). Copy it again, completely.",  -- 101
    "The profile has no valid name.",  -- 102
    "Cannot import: %s (%s).",  -- 103
    "a value is outside its allowed range",  -- 104
    "a value is not valid",  -- 105
    "a curve is not valid",  -- 106
    "it contains a setting this version does not know",  -- 107
    "Installed. The Action camera is on. Try /ccam use hybrid or /ccam use classic, /ccam help lists everything.",  -- 108
    "%s is also loaded. Both change the camera and will fight each other. Disable one of them.",  -- 109
    "Camera follows terrain",  -- 110
    "your setting",  -- 111
    "The out-of-the-box feel: close third-person camera over your shoulder, head tracking, the camera follows where you run and you face where you move. Out of combat you run free, in combat you strafe.",  -- 112
    "Between Classic and Action: a medium distance, a light over-the-shoulder offset and gentle head tracking. The camera follows your movement, but you still get a wide view.",  -- 113
    "The game's own camera: every setting ControllerCam manages goes back to its default. Your camera distance and your terrain-following setting are left as they are.",  -- 114
    "A third-person shooter feel: tight camera, a strong shoulder offset, fast stick aim. You run facing your movement outside combat and strafe facing the camera in combat.",  -- 115
    "Even closer and steadier, for cover-shooter play: your character always turns with the camera, the shoulder offset is large and the camera does not drift on its own.",  -- 116
    "Slow, wide and moody, for questing and screenshots: dynamic pitch, strong head tracking and a camera that turns toward whoever you talk to.",  -- 117
    "The camera leans toward your current target and the NPCs you talk to. Good for single-target fights.",  -- 118
    "A far, steady camera for dungeons and raids: no offset, no head tracking, no camera drift and fast stick turning so you can see the whole fight.",  -- 119
    "For riding: a far camera that swings behind you as you steer. The offset is off, because mounts of different sizes make it unreliable.",  -- 120
    "For flying: a far camera that follows your climb and dive.",  -- 121
    "A relaxed, slower camera for cities: closer, calm and with head tracking.",  -- 122
    "Custom profile. Duplicate or edit it in the profile editor.",  -- 123
    "show status",  -- 124
    "list the profiles",  -- 125
    "use one profile everywhere (try: action, hybrid, classic)",  -- 126
    "the recommended setup: Action camera with calmer profiles for cities, mounts, flying, raids",  -- 127
    "choose the profile for one situation (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 128
    "use a profile now, whatever the situation",  -- 129
    "stop forcing a profile",  -- 130
    "save your current camera settings as a new profile",  -- 131
    "make an editable copy of a profile",  -- 132
    "change a setting of a custom profile (/ccam settings lists them)",  -- 133
    "shoulder offset by camera distance, e.g. /ccam curve mine 0:2 8:2 20:0",  -- 134
    "delete a custom profile",  -- 135
    "show a string you can share",  -- 136
    "add a profile from a shared string",  -- 137
    "switch the shoulder offset to the other shoulder",  -- 138
    "how long a situation is kept after it ends (default 1.5)",  -- 139
    "turn on, or turn off and restore your original camera settings",  -- 140
    "show the zoom, shoulder offset and motion settings right now (for troubleshooting)",  -- 141
    "open the options panel (Options > AddOns > ControllerCam)",  -- 142
    "show this list",  -- 143
    "'%s' matches more than one profile. Type more of the name.",  -- 144
    "No profile called '%s'. /ccam list shows them.",  -- 145
    "Camera profiles for controller play. Out of the box you get an Action camera; Hybrid and Classic are one command away.",  -- 146
    "Built-in profiles cannot be edited. Make a copy first: /ccam copy <profile>",  -- 147
    "Unknown setting. /ccam settings lists them.",  -- 148
    "That value is outside the allowed range.",  -- 149
    "That value is not valid.",  -- 150
    "Unknown situation. Use: vehicle, flying, swimming, mounted, combat, raid, dungeon, city or default.",  -- 151
    "usage: /ccam set <situation> <profile|none>",  -- 152
    "%s: no change",  -- 153
    "Forcing '%s'. /ccam auto goes back to the situations.",  -- 154
    "The camera follows your situations again.",  -- 155
    "usage: /ccam edit <profile> <setting> <value|default>",  -- 156
    "Use /ccam curve for the offset by zoom.",  -- 157
    "Shoulder offset mirrored.",  -- 158
    "Shoulder offset back to normal.",  -- 159
    "Situations are kept for %.1f seconds after they end.",  -- 160
    "usage: /ccam delay <seconds>",  -- 161
    "options panel is not available in this client",  -- 162
    "unknown command '%s'. Type /ccam help",  -- 163
    "Press Ctrl+C to copy, then Esc.",  -- 164
    "Paste a ControllerCam string here (Ctrl+V), then press Import.",  -- 165
    "Camera profiles for controller play. Pick what the camera feels like in each situation. Left-click a profile to go to the next one, right-click for the previous one.",  -- 166
    "Turn the camera control on or off. When off, your original camera settings are put back.",  -- 167
    "Close third-person camera over your shoulder, head tracking. The default.",  -- 168
    "Between Classic and Action.",  -- 169
    "The game's own camera.",  -- 170
    "Action camera with calmer profiles for cities, mounts, flying and raids.",  -- 171
    "Left-click: next profile. Right-click: previous profile. The first entry, no change, leaves the camera alone.",  -- 172
    "Stops the camera from flickering between profiles when a situation switches on and off quickly.",  -- 173
    "Swaps which shoulder the camera looks over.",  -- 174
    "Left-click: next profile. Right-click: previous profile.",  -- 175
    "Use this profile in every situation.",  -- 176
    "Makes an editable copy of this profile.",  -- 177
    "Saves the camera settings you have right now as a new profile.",  -- 178
    "Shows a string you can share.",  -- 179
    "Add a profile from a shared string.",  -- 180
    "Deletes this custom profile.",  -- 181
    "Zoom distance and offset pairs, for example 0:2 8:2 20:0. Empty = no curve. Press Enter to apply.",  -- 182
    "Use the game's default for this setting.",  -- 183
    "Settings not listed use the game default. Click a value to change it; the curve box takes zoom:offset pairs.",  -- 184
    "Built-in profiles cannot be edited. Make a copy first.",  -- 185
}

local TRANSLATIONS = {
    deDE = {
        "In einem Fahrzeug",  -- 1
        "Fliegen",  -- 2
        "Schwimmen",  -- 3
        "Auf Reittier",  -- 4
        "Im Kampf",  -- 5
        "Im Schlachtzug",  -- 6
        "In einem Dungeon",  -- 7
        "In einer Stadt oder Taverne",  -- 8
        "Überall sonst (Standard)",  -- 9
        "Action",  -- 10
        "Hybrid",  -- 11
        "Klassisch",  -- 12
        "Shooter",  -- 13
        "Taktisch",  -- 14
        "Filmisch",  -- 15
        "Zielfokus",  -- 16
        "Schlachtzugsansicht",  -- 17
        "Reittier-Reise",  -- 18
        "Stadtspaziergang",  -- 19
        "Zoom",  -- 20
        "Controller",  -- 21
        "Ausrichtung",  -- 22
        "Schulter",  -- 23
        "Kopfbewegung",  -- 24
        "Ziele",  -- 25
        "Glättung",  -- 26
        "Kameraabstand (Meter)",  -- 27
        "Maximaler Auszoom-Faktor",  -- 28
        "Stick-Drehgeschwindigkeit (links/rechts)",  -- 29
        "Stick-Blickgeschwindigkeit (oben/unten)",  -- 30
        "Kamera folgt deiner Bewegungsrichtung",  -- 31
        "Folgegeschwindigkeit (links/rechts)",  -- 32
        "Folgegeschwindigkeit (oben/unten)",  -- 33
        "Verzögerung bis das Folgen fortgesetzt wird",  -- 34
        "Bewegungsrichtung ansehen (max. Winkel)",  -- 35
        "Bewegungsrichtung im Kampf ansehen (max. Winkel)",  -- 36
        "Charakter mit der Kamera drehen",  -- 37
        "Auf Reittier in Bewegungsrichtung blicken",  -- 38
        "Beim Schwimmen in Bewegungsrichtung blicken",  -- 39
        "Beim Fliegen in Bewegungsrichtung blicken",  -- 40
        "Schulterversatz",  -- 41
        "Schulterversatz nach Zoom",  -- 42
        "Dynamische Neigung (filmisch)",  -- 43
        "Stärke der Kopfbewegung",  -- 44
        "Kopfbewegung im Stehen",  -- 45
        "Kopfbewegung in Bewegung",  -- 46
        "Reichweite der Kopfbewegung",  -- 47
        "Zum Ziel blicken",  -- 48
        "Zielfokus-Stärke (links/rechts)",  -- 49
        "Zielfokus-Stärke (oben/unten)",  -- 50
        "Zu NPCs blicken, mit denen du sprichst",  -- 51
        "Interaktionsfokus-Stärke (links/rechts)",  -- 52
        "Interaktionsfokus-Stärke (oben/unten)",  -- 53
        "Kamera-Nachführung (Maus und Tastatur)",  -- 54
        "nie",  -- 55
        "im Kampf",  -- 56
        "immer",  -- 57
        "im Kampf oder beim Zaubern",  -- 58
        "nur in Bewegung",  -- 59
        "an",  -- 60
        "aus",  -- 61
        "Profile",  -- 62
        "ControllerCam aktivieren",  -- 63
        "Schnellwahl (ein Profil überall verwenden):",  -- 64
        "Empfohlene Einrichtung",  -- 65
        "(keine Änderung)",  -- 66
        "Überall verwenden",  -- 67
        "Kopie erstellen",  -- 68
        "Meine aktuelle Kamera speichern",  -- 69
        "Exportieren",  -- 70
        "Importieren",  -- 71
        "Schließen",  -- 72
        "Löschen",  -- 73
        "Spielstandard",  -- 74
        "Standard",  -- 75
        "Mein Profil",  -- 76
        "Kopie",  -- 77
        "erzwungen",  -- 78
        "eigenes",  -- 79
        "keine Änderung",  -- 80
        "aktuell",  -- 81
        "noch nichts angewendet",  -- 82
        "Jetzt: %s (%s)",  -- 83
        "Jetzt: noch nichts angewendet",  -- 84
        "Schulterversatz spiegeln (andere Schulter)",  -- 85
        "Situation nach Ende noch %.1f s halten",  -- 86
        "Chat-Befehle: /ccam help",  -- 87
        "Profil für jede Situation (die erste zutreffende von oben gewinnt):",  -- 88
        "Erledigt.",  -- 89
        "'%s' wird überall verwendet.",  -- 90
        "Empfohlene Einrichtung angewendet.",  -- 91
        "Gespeichert als '%s'.",  -- 92
        "'%s' gelöscht.",  -- 93
        "aktiviert",  -- 94
        "deaktiviert. Deine ursprünglichen Kameraeinstellungen wurden wiederhergestellt.",  -- 95
        "'%s' importiert. Mit /ccam use \"%s\" ausprobieren.",  -- 96
        "Das ist keine ControllerCam-Profilzeichenfolge.",  -- 97
        "Nichts zu importieren.",  -- 98
        "Die Zeichenfolge ist zu lang für ein Profil.",  -- 99
        "Dieses Profil stammt von einer neueren ControllerCam-Version. Bitte aktualisiere das Addon.",  -- 100
        "Die Zeichenfolge ist beschädigt (Prüfsumme stimmt nicht). Kopiere sie erneut, vollständig.",  -- 101
        "Das Profil hat keinen gültigen Namen.",  -- 102
        "Import nicht möglich: %s (%s).",  -- 103
        "ein Wert liegt außerhalb des erlaubten Bereichs",  -- 104
        "ein Wert ist ungültig",  -- 105
        "eine Kurve ist ungültig",  -- 106
        "sie enthält eine Einstellung, die diese Version nicht kennt",  -- 107
        "Installiert. Die Action-Kamera ist aktiv. Probiere /ccam use hybrid oder /ccam use classic, /ccam help zeigt alles.",  -- 108
        "%s ist ebenfalls geladen. Beide ändern die Kamera und stören sich gegenseitig. Deaktiviere eines davon.",  -- 109
        "Kamera folgt dem Gelände",  -- 110
        "deine Einstellung",  -- 111
    },
    esES = {
        "En un vehículo",  -- 1
        "Volando",  -- 2
        "Nadando",  -- 3
        "Montado",  -- 4
        "En combate",  -- 5
        "En una banda",  -- 6
        "En una mazmorra",  -- 7
        "En una ciudad o posada",  -- 8
        "En cualquier otro lugar (predeterminado)",  -- 9
        "Acción",  -- 10
        "Híbrido",  -- 11
        "Clásico",  -- 12
        "Shooter",  -- 13
        "Táctico",  -- 14
        "Cinemático",  -- 15
        "Enfoque en el objetivo",  -- 16
        "Vista de banda",  -- 17
        "Viaje montado",  -- 18
        "Paseo por la ciudad",  -- 19
        "Zoom",  -- 20
        "Mando",  -- 21
        "Orientación",  -- 22
        "Hombro",  -- 23
        "Seguimiento de cabeza",  -- 24
        "Objetivos",  -- 25
        "Suavizado",  -- 26
        "Distancia de la cámara (yardas)",  -- 27
        "Factor máximo de alejamiento",  -- 28
        "Velocidad de giro del stick (izquierda/derecha)",  -- 29
        "Velocidad de mirada del stick (arriba/abajo)",  -- 30
        "La cámara sigue tu dirección de movimiento",  -- 31
        "Velocidad de seguimiento (izquierda/derecha)",  -- 32
        "Velocidad de seguimiento (arriba/abajo)",  -- 33
        "Retraso antes de reanudar el seguimiento",  -- 34
        "Mirar en la dirección de movimiento (ángulo máx.)",  -- 35
        "Mirar en la dirección de movimiento en combate (ángulo máx.)",  -- 36
        "Girar al personaje con la cámara",  -- 37
        "Mirar en la dirección de movimiento al montar",  -- 38
        "Mirar en la dirección de movimiento al nadar",  -- 39
        "Mirar en la dirección de movimiento al volar",  -- 40
        "Desplazamiento sobre el hombro",  -- 41
        "Desplazamiento sobre el hombro según el zoom",  -- 42
        "Inclinación dinámica (cinemática)",  -- 43
        "Intensidad del seguimiento de cabeza",  -- 44
        "Seguimiento de cabeza parado",  -- 45
        "Seguimiento de cabeza en movimiento",  -- 46
        "Rango del seguimiento de cabeza",  -- 47
        "Mirar hacia tu objetivo",  -- 48
        "Intensidad de enfoque al objetivo (izquierda/derecha)",  -- 49
        "Intensidad de enfoque al objetivo (arriba/abajo)",  -- 50
        "Mirar hacia los PNJ con los que hablas",  -- 51
        "Intensidad de enfoque de interacción (izquierda/derecha)",  -- 52
        "Intensidad de enfoque de interacción (arriba/abajo)",  -- 53
        "Seguimiento automático de cámara (ratón y teclado)",  -- 54
        "nunca",  -- 55
        "en combate",  -- 56
        "siempre",  -- 57
        "en combate o al lanzar",  -- 58
        "solo al moverte",  -- 59
        "activado",  -- 60
        "desactivado",  -- 61
        "Perfiles",  -- 62
        "Activar ControllerCam",  -- 63
        "Selección rápida (usar un perfil en todas partes):",  -- 64
        "Configuración recomendada",  -- 65
        "(sin cambios)",  -- 66
        "Usar en todas partes",  -- 67
        "Hacer una copia",  -- 68
        "Guardar mi cámara actual",  -- 69
        "Exportar",  -- 70
        "Importar",  -- 71
        "Cerrar",  -- 72
        "Eliminar",  -- 73
        "predeterminado del juego",  -- 74
        "Predet.",  -- 75
        "Mi perfil",  -- 76
        "copia",  -- 77
        "forzado",  -- 78
        "personalizado",  -- 79
        "sin cambios",  -- 80
        "actual",  -- 81
        "nada aplicado todavía",  -- 82
        "Ahora: %s (%s)",  -- 83
        "Ahora: nada aplicado todavía",  -- 84
        "Reflejar el desplazamiento (otro hombro)",  -- 85
        "Mantener una situación %.1f s tras terminar",  -- 86
        "Comandos: /ccam help",  -- 87
        "Perfil para cada situación (gana la primera que se cumple, de arriba abajo):",  -- 88
        "Hecho.",  -- 89
        "Usando '%s' en todas partes.",  -- 90
        "Configuración recomendada aplicada.",  -- 91
        "Guardado como '%s'.",  -- 92
        "'%s' eliminado.",  -- 93
        "activado",  -- 94
        "desactivado. Se restauraron tus ajustes de cámara originales.",  -- 95
        "'%s' importado. Pruébalo con /ccam use \"%s\".",  -- 96
        "Eso no es una cadena de perfil de ControllerCam.",  -- 97
        "No hay nada que importar.",  -- 98
        "La cadena es demasiado larga para ser un perfil.",  -- 99
        "Este perfil se creó con una versión más reciente de ControllerCam. Actualiza el addon.",  -- 100
        "La cadena está dañada (la suma de comprobación no coincide). Cópiala de nuevo, completa.",  -- 101
        "El perfil no tiene un nombre válido.",  -- 102
        "No se puede importar: %s (%s).",  -- 103
        "un valor está fuera del rango permitido",  -- 104
        "un valor no es válido",  -- 105
        "una curva no es válida",  -- 106
        "contiene un ajuste que esta versión no conoce",  -- 107
        "Instalado. La cámara de Acción está activa. Prueba /ccam use hybrid o /ccam use classic; /ccam help lo lista todo.",  -- 108
        "%s también está cargado. Ambos cambian la cámara y chocarán. Desactiva uno de ellos.",  -- 109
        "La cámara sigue el terreno",  -- 110
        "tu ajuste",  -- 111
    },
    frFR = {
        "Dans un véhicule",  -- 1
        "En vol",  -- 2
        "À la nage",  -- 3
        "Monté",  -- 4
        "En combat",  -- 5
        "En raid",  -- 6
        "Dans un donjon",  -- 7
        "Dans une ville ou une auberge",  -- 8
        "Partout ailleurs (par défaut)",  -- 9
        "Action",  -- 10
        "Hybride",  -- 11
        "Classique",  -- 12
        "Tir",  -- 13
        "Tactique",  -- 14
        "Cinématique",  -- 15
        "Focus sur la cible",  -- 16
        "Vue raid",  -- 17
        "Voyage monté",  -- 18
        "Balade en ville",  -- 19
        "Zoom",  -- 20
        "Manette",  -- 21
        "Orientation",  -- 22
        "Épaule",  -- 23
        "Suivi de la tête",  -- 24
        "Cibles",  -- 25
        "Lissage",  -- 26
        "Distance de la caméra (mètres)",  -- 27
        "Facteur de dézoom maximal",  -- 28
        "Vitesse de rotation du stick (gauche/droite)",  -- 29
        "Vitesse de regard du stick (haut/bas)",  -- 30
        "La caméra suit votre direction de déplacement",  -- 31
        "Vitesse de suivi (gauche/droite)",  -- 32
        "Vitesse de suivi (haut/bas)",  -- 33
        "Délai avant la reprise du suivi",  -- 34
        "Faire face à la direction du déplacement (angle max.)",  -- 35
        "Faire face à la direction du déplacement en combat (angle max.)",  -- 36
        "Tourner le personnage avec la caméra",  -- 37
        "Faire face à la direction du déplacement en monture",  -- 38
        "Faire face à la direction du déplacement en nageant",  -- 39
        "Faire face à la direction du déplacement en vol",  -- 40
        "Décalage par-dessus l'épaule",  -- 41
        "Décalage par-dessus l'épaule selon le zoom",  -- 42
        "Inclinaison dynamique (cinématique)",  -- 43
        "Intensité du suivi de la tête",  -- 44
        "Suivi de la tête à l'arrêt",  -- 45
        "Suivi de la tête en mouvement",  -- 46
        "Amplitude du suivi de la tête",  -- 47
        "Regarder vers votre cible",  -- 48
        "Force du focus sur la cible (gauche/droite)",  -- 49
        "Force du focus sur la cible (haut/bas)",  -- 50
        "Regarder les PNJ à qui vous parlez",  -- 51
        "Force du focus d'interaction (gauche/droite)",  -- 52
        "Force du focus d'interaction (haut/bas)",  -- 53
        "Suivi automatique de la caméra (souris et clavier)",  -- 54
        "jamais",  -- 55
        "en combat",  -- 56
        "toujours",  -- 57
        "en combat ou en lançant un sort",  -- 58
        "uniquement en mouvement",  -- 59
        "activé",  -- 60
        "désactivé",  -- 61
        "Profils",  -- 62
        "Activer ControllerCam",  -- 63
        "Choix rapide (un seul profil partout) :",  -- 64
        "Configuration recommandée",  -- 65
        "(aucun changement)",  -- 66
        "Utiliser partout",  -- 67
        "Faire une copie",  -- 68
        "Enregistrer ma caméra actuelle",  -- 69
        "Exporter",  -- 70
        "Importer",  -- 71
        "Fermer",  -- 72
        "Supprimer",  -- 73
        "défaut du jeu",  -- 74
        "Défaut",  -- 75
        "Mon profil",  -- 76
        "copie",  -- 77
        "forcé",  -- 78
        "personnalisé",  -- 79
        "aucun changement",  -- 80
        "actuel",  -- 81
        "rien d'appliqué pour l'instant",  -- 82
        "Maintenant : %s (%s)",  -- 83
        "Maintenant : rien d'appliqué pour l'instant",  -- 84
        "Inverser le décalage (autre épaule)",  -- 85
        "Garder une situation %.1f s après sa fin",  -- 86
        "Commandes : /ccam help",  -- 87
        "Profil pour chaque situation (la première qui s'applique l'emporte, en partant du haut) :",  -- 88
        "Terminé.",  -- 89
        "'%s' est utilisé partout.",  -- 90
        "Configuration recommandée appliquée.",  -- 91
        "Enregistré sous '%s'.",  -- 92
        "'%s' supprimé.",  -- 93
        "activé",  -- 94
        "désactivé. Vos réglages de caméra d'origine ont été restaurés.",  -- 95
        "'%s' importé. Essayez-le avec /ccam use \"%s\".",  -- 96
        "Ce n'est pas une chaîne de profil ControllerCam.",  -- 97
        "Rien à importer.",  -- 98
        "La chaîne est trop longue pour être un profil.",  -- 99
        "Ce profil a été créé avec une version plus récente de ControllerCam. Mettez l'addon à jour.",  -- 100
        "La chaîne est endommagée (somme de contrôle incorrecte). Copiez-la à nouveau, en entier.",  -- 101
        "Le profil n'a pas de nom valide.",  -- 102
        "Import impossible : %s (%s).",  -- 103
        "une valeur est hors de la plage autorisée",  -- 104
        "une valeur n'est pas valide",  -- 105
        "une courbe n'est pas valide",  -- 106
        "elle contient un réglage inconnu de cette version",  -- 107
        "Installé. La caméra Action est active. Essayez /ccam use hybrid ou /ccam use classic ; /ccam help liste tout.",  -- 108
        "%s est également chargé. Les deux modifient la caméra et se gênent. Désactivez-en un.",  -- 109
        "La caméra suit le terrain",  -- 110
        "votre réglage",  -- 111
    },
    itIT = {
        "In un veicolo",  -- 1
        "In volo",  -- 2
        "A nuoto",  -- 3
        "In sella",  -- 4
        "In combattimento",  -- 5
        "In un raid",  -- 6
        "In un dungeon",  -- 7
        "In una città o locanda",  -- 8
        "Ovunque altrove (predefinito)",  -- 9
        "Azione",  -- 10
        "Ibrido",  -- 11
        "Classico",  -- 12
        "Sparatutto",  -- 13
        "Tattico",  -- 14
        "Cinematografico",  -- 15
        "Focus sul bersaglio",  -- 16
        "Vista raid",  -- 17
        "Viaggio in sella",  -- 18
        "Passeggiata in città",  -- 19
        "Zoom",  -- 20
        "Controller",  -- 21
        "Orientamento",  -- 22
        "Spalla",  -- 23
        "Movimento della testa",  -- 24
        "Bersagli",  -- 25
        "Fluidità",  -- 26
        "Distanza della telecamera (iarde)",  -- 27
        "Fattore massimo di allontanamento",  -- 28
        "Velocità di rotazione dello stick (sinistra/destra)",  -- 29
        "Velocità di sguardo dello stick (su/giù)",  -- 30
        "La telecamera segue la direzione del movimento",  -- 31
        "Velocità di inseguimento (sinistra/destra)",  -- 32
        "Velocità di inseguimento (su/giù)",  -- 33
        "Ritardo prima della ripresa dell'inseguimento",  -- 34
        "Rivolgiti nella direzione del movimento (angolo max.)",  -- 35
        "Rivolgiti nella direzione del movimento in combattimento (angolo max.)",  -- 36
        "Ruota il personaggio con la telecamera",  -- 37
        "Rivolgiti nella direzione del movimento in sella",  -- 38
        "Rivolgiti nella direzione del movimento mentre nuoti",  -- 39
        "Rivolgiti nella direzione del movimento in volo",  -- 40
        "Scostamento sopra la spalla",  -- 41
        "Scostamento sopra la spalla in base allo zoom",  -- 42
        "Inclinazione dinamica (cinematografica)",  -- 43
        "Intensità del movimento della testa",  -- 44
        "Movimento della testa da fermo",  -- 45
        "Movimento della testa in movimento",  -- 46
        "Raggio del movimento della testa",  -- 47
        "Guarda verso il bersaglio",  -- 48
        "Intensità del focus sul bersaglio (sinistra/destra)",  -- 49
        "Intensità del focus sul bersaglio (su/giù)",  -- 50
        "Guarda verso gli NPC con cui parli",  -- 51
        "Intensità del focus di interazione (sinistra/destra)",  -- 52
        "Intensità del focus di interazione (su/giù)",  -- 53
        "Inseguimento automatico della telecamera (mouse e tastiera)",  -- 54
        "mai",  -- 55
        "in combattimento",  -- 56
        "sempre",  -- 57
        "in combattimento o durante il lancio",  -- 58
        "solo in movimento",  -- 59
        "attivo",  -- 60
        "disattivo",  -- 61
        "Profili",  -- 62
        "Attiva ControllerCam",  -- 63
        "Selezione rapida (un solo profilo ovunque):",  -- 64
        "Configurazione consigliata",  -- 65
        "(nessuna modifica)",  -- 66
        "Usa ovunque",  -- 67
        "Crea una copia",  -- 68
        "Salva la mia telecamera attuale",  -- 69
        "Esporta",  -- 70
        "Importa",  -- 71
        "Chiudi",  -- 72
        "Elimina",  -- 73
        "predefinito del gioco",  -- 74
        "Predef.",  -- 75
        "Il mio profilo",  -- 76
        "copia",  -- 77
        "forzato",  -- 78
        "personalizzato",  -- 79
        "nessuna modifica",  -- 80
        "attuale",  -- 81
        "ancora nulla applicato",  -- 82
        "Ora: %s (%s)",  -- 83
        "Ora: ancora nulla applicato",  -- 84
        "Specchia lo scostamento (altra spalla)",  -- 85
        "Mantieni una situazione per %.1f s dopo la fine",  -- 86
        "Comandi: /ccam help",  -- 87
        "Profilo per ogni situazione (vince la prima che si applica, dall'alto):",  -- 88
        "Fatto.",  -- 89
        "'%s' viene usato ovunque.",  -- 90
        "Configurazione consigliata applicata.",  -- 91
        "Salvato come '%s'.",  -- 92
        "'%s' eliminato.",  -- 93
        "attivato",  -- 94
        "disattivato. Le tue impostazioni originali della telecamera sono state ripristinate.",  -- 95
        "'%s' importato. Provalo con /ccam use \"%s\".",  -- 96
        "Questa non è una stringa di profilo ControllerCam.",  -- 97
        "Niente da importare.",  -- 98
        "La stringa è troppo lunga per essere un profilo.",  -- 99
        "Questo profilo è stato creato con una versione più recente di ControllerCam. Aggiorna l'addon.",  -- 100
        "La stringa è danneggiata (checksum non corrispondente). Copiala di nuovo, per intero.",  -- 101
        "Il profilo non ha un nome valido.",  -- 102
        "Impossibile importare: %s (%s).",  -- 103
        "un valore è fuori dall'intervallo consentito",  -- 104
        "un valore non è valido",  -- 105
        "una curva non è valida",  -- 106
        "contiene un'impostazione sconosciuta a questa versione",  -- 107
        "Installato. La telecamera Azione è attiva. Prova /ccam use hybrid o /ccam use classic; /ccam help mostra tutto.",  -- 108
        "Anche %s è caricato. Entrambi modificano la telecamera e interferiranno. Disattiva uno dei due.",  -- 109
        "La telecamera segue il terreno",  -- 110
        "la tua impostazione",  -- 111
    },
    koKR = {
        "탈것 이용 중",  -- 1
        "비행 중",  -- 2
        "수영 중",  -- 3
        "탈것 탑승 중",  -- 4
        "전투 중",  -- 5
        "공격대 안",  -- 6
        "던전 안",  -- 7
        "도시 또는 여관",  -- 8
        "그 외 모든 곳 (기본)",  -- 9
        "액션",  -- 10
        "하이브리드",  -- 11
        "클래식",  -- 12
        "슈터",  -- 13
        "전술",  -- 14
        "시네마틱",  -- 15
        "대상 집중",  -- 16
        "공격대 시점",  -- 17
        "탈것 순항",  -- 18
        "도시 산책",  -- 19
        "확대/축소",  -- 20
        "컨트롤러",  -- 21
        "방향",  -- 22
        "어깨",  -- 23
        "머리 추적",  -- 24
        "대상",  -- 25
        "부드러움",  -- 26
        "카메라 거리 (야드)",  -- 27
        "최대 축소 배율",  -- 28
        "스틱 회전 속도 (좌/우)",  -- 29
        "스틱 시선 속도 (상/하)",  -- 30
        "카메라가 이동 방향을 따라감",  -- 31
        "따라가기 속도 (좌/우)",  -- 32
        "따라가기 속도 (상/하)",  -- 33
        "따라가기 재개 전 지연",  -- 34
        "이동 방향 바라보기 (최대 각도)",  -- 35
        "전투 중 이동 방향 바라보기 (최대 각도)",  -- 36
        "카메라와 함께 캐릭터 회전",  -- 37
        "탈것에서 이동 방향 바라보기",  -- 38
        "수영 중 이동 방향 바라보기",  -- 39
        "비행 중 이동 방향 바라보기",  -- 40
        "어깨 너머 오프셋",  -- 41
        "줌에 따른 어깨 너머 오프셋",  -- 42
        "동적 피치 (시네마틱 기울기)",  -- 43
        "머리 추적 강도",  -- 44
        "정지 중 머리 추적",  -- 45
        "이동 중 머리 추적",  -- 46
        "머리 추적 범위",  -- 47
        "대상 쪽 바라보기",  -- 48
        "대상 집중 강도 (좌/우)",  -- 49
        "대상 집중 강도 (상/하)",  -- 50
        "대화 중인 NPC 쪽 바라보기",  -- 51
        "상호작용 집중 강도 (좌/우)",  -- 52
        "상호작용 집중 강도 (상/하)",  -- 53
        "카메라 자동 따라가기 (마우스와 키보드)",  -- 54
        "안 함",  -- 55
        "전투 중",  -- 56
        "항상",  -- 57
        "전투 중 또는 시전 중",  -- 58
        "이동 중에만",  -- 59
        "켜짐",  -- 60
        "꺼짐",  -- 61
        "프로필",  -- 62
        "ControllerCam 사용",  -- 63
        "빠른 선택 (모든 곳에 프로필 하나 사용):",  -- 64
        "권장 설정",  -- 65
        "(변경 없음)",  -- 66
        "모든 곳에 사용",  -- 67
        "복사본 만들기",  -- 68
        "현재 카메라 저장",  -- 69
        "내보내기",  -- 70
        "가져오기",  -- 71
        "닫기",  -- 72
        "삭제",  -- 73
        "게임 기본값",  -- 74
        "기본값",  -- 75
        "내 프로필",  -- 76
        "복사본",  -- 77
        "강제",  -- 78
        "사용자 지정",  -- 79
        "변경 없음",  -- 80
        "현재",  -- 81
        "아직 적용 안 됨",  -- 82
        "현재: %s (%s)",  -- 83
        "현재: 아직 적용 안 됨",  -- 84
        "어깨 오프셋 반전 (반대쪽 어깨)",  -- 85
        "상황 종료 후 %.1f초 유지",  -- 86
        "명령어: /ccam help",  -- 87
        "상황별 프로필 (위에서부터 처음 해당하는 것이 적용됨):",  -- 88
        "완료.",  -- 89
        "어디서나 '%s'을(를) 사용합니다.",  -- 90
        "권장 설정을 적용했습니다.",  -- 91
        "'%s'(으)로 저장했습니다.",  -- 92
        "'%s'을(를) 삭제했습니다.",  -- 93
        "사용함",  -- 94
        "사용 안 함. 원래 카메라 설정을 복원했습니다.",  -- 95
        "'%s'을(를) 가져왔습니다. /ccam use \"%s\" 로 사용해 보세요.",  -- 96
        "ControllerCam 프로필 문자열이 아닙니다.",  -- 97
        "가져올 내용이 없습니다.",  -- 98
        "문자열이 너무 길어 프로필이 될 수 없습니다.",  -- 99
        "이 프로필은 더 최신 버전의 ControllerCam으로 만들어졌습니다. 애드온을 업데이트하세요.",  -- 100
        "문자열이 손상되었습니다(체크섬 불일치). 전체를 다시 복사하세요.",  -- 101
        "프로필 이름이 올바르지 않습니다.",  -- 102
        "가져올 수 없음: %s (%s).",  -- 103
        "값이 허용 범위를 벗어났습니다",  -- 104
        "값이 올바르지 않습니다",  -- 105
        "곡선이 올바르지 않습니다",  -- 106
        "이 버전이 모르는 설정이 있습니다",  -- 107
        "설치되었습니다. 액션 카메라가 켜져 있습니다. /ccam use hybrid 또는 /ccam use classic 을 시도해 보세요. /ccam help 로 전체 명령을 볼 수 있습니다.",  -- 108
        "%s도 로드되어 있습니다. 둘 다 카메라를 바꾸므로 서로 충돌합니다. 하나를 비활성화하세요.",  -- 109
        "카메라가 지형을 따라감",  -- 110
        "내 설정",  -- 111
    },
    ptBR = {
        "Em um veículo",  -- 1
        "Voando",  -- 2
        "Nadando",  -- 3
        "Montado",  -- 4
        "Em combate",  -- 5
        "Em uma raide",  -- 6
        "Em uma masmorra",  -- 7
        "Em uma cidade ou estalagem",  -- 8
        "Em qualquer outro lugar (padrão)",  -- 9
        "Ação",  -- 10
        "Híbrido",  -- 11
        "Clássico",  -- 12
        "Tiro",  -- 13
        "Tático",  -- 14
        "Cinematográfico",  -- 15
        "Foco no alvo",  -- 16
        "Visão de raide",  -- 17
        "Cruzeiro montado",  -- 18
        "Passeio pela cidade",  -- 19
        "Zoom",  -- 20
        "Controle",  -- 21
        "Direção",  -- 22
        "Ombro",  -- 23
        "Rastreamento da cabeça",  -- 24
        "Alvos",  -- 25
        "Suavização",  -- 26
        "Distância da câmera (jardas)",  -- 27
        "Fator máximo de afastamento",  -- 28
        "Velocidade de giro do analógico (esquerda/direita)",  -- 29
        "Velocidade de olhar do analógico (cima/baixo)",  -- 30
        "A câmera segue a direção do movimento",  -- 31
        "Velocidade de acompanhamento (esquerda/direita)",  -- 32
        "Velocidade de acompanhamento (cima/baixo)",  -- 33
        "Atraso antes de retomar o acompanhamento",  -- 34
        "Olhar na direção do movimento (ângulo máx.)",  -- 35
        "Olhar na direção do movimento em combate (ângulo máx.)",  -- 36
        "Girar o personagem com a câmera",  -- 37
        "Olhar na direção do movimento na montaria",  -- 38
        "Olhar na direção do movimento ao nadar",  -- 39
        "Olhar na direção do movimento ao voar",  -- 40
        "Deslocamento sobre o ombro",  -- 41
        "Deslocamento sobre o ombro por zoom",  -- 42
        "Inclinação dinâmica (cinematográfica)",  -- 43
        "Intensidade do rastreamento da cabeça",  -- 44
        "Rastreamento da cabeça parado",  -- 45
        "Rastreamento da cabeça em movimento",  -- 46
        "Alcance do rastreamento da cabeça",  -- 47
        "Olhar para o alvo",  -- 48
        "Intensidade do foco no alvo (esquerda/direita)",  -- 49
        "Intensidade do foco no alvo (cima/baixo)",  -- 50
        "Olhar para os NPCs com quem você fala",  -- 51
        "Intensidade do foco de interação (esquerda/direita)",  -- 52
        "Intensidade do foco de interação (cima/baixo)",  -- 53
        "Acompanhamento automático da câmera (mouse e teclado)",  -- 54
        "nunca",  -- 55
        "em combate",  -- 56
        "sempre",  -- 57
        "em combate ou ao conjurar",  -- 58
        "apenas ao se mover",  -- 59
        "ligado",  -- 60
        "desligado",  -- 61
        "Perfis",  -- 62
        "Ativar ControllerCam",  -- 63
        "Escolha rápida (usar um perfil em todo lugar):",  -- 64
        "Configuração recomendada",  -- 65
        "(sem alteração)",  -- 66
        "Usar em todo lugar",  -- 67
        "Fazer uma cópia",  -- 68
        "Salvar minha câmera atual",  -- 69
        "Exportar",  -- 70
        "Importar",  -- 71
        "Fechar",  -- 72
        "Excluir",  -- 73
        "padrão do jogo",  -- 74
        "Padrão",  -- 75
        "Meu perfil",  -- 76
        "cópia",  -- 77
        "forçado",  -- 78
        "personalizado",  -- 79
        "sem alteração",  -- 80
        "atual",  -- 81
        "nada aplicado ainda",  -- 82
        "Agora: %s (%s)",  -- 83
        "Agora: nada aplicado ainda",  -- 84
        "Espelhar o deslocamento (outro ombro)",  -- 85
        "Manter uma situação por %.1f s após o fim",  -- 86
        "Comandos: /ccam help",  -- 87
        "Perfil para cada situação (vale a primeira que se aplica, de cima para baixo):",  -- 88
        "Pronto.",  -- 89
        "Usando '%s' em todo lugar.",  -- 90
        "Configuração recomendada aplicada.",  -- 91
        "Salvo como '%s'.",  -- 92
        "'%s' excluído.",  -- 93
        "ativado",  -- 94
        "desativado. Suas configurações originais de câmera foram restauradas.",  -- 95
        "'%s' importado. Experimente com /ccam use \"%s\".",  -- 96
        "Isso não é uma sequência de perfil do ControllerCam.",  -- 97
        "Nada para importar.",  -- 98
        "A sequência é longa demais para ser um perfil.",  -- 99
        "Este perfil foi criado com uma versão mais nova do ControllerCam. Atualize o addon.",  -- 100
        "A sequência está danificada (checksum não confere). Copie-a novamente, por completo.",  -- 101
        "O perfil não tem um nome válido.",  -- 102
        "Não é possível importar: %s (%s).",  -- 103
        "um valor está fora do intervalo permitido",  -- 104
        "um valor não é válido",  -- 105
        "uma curva não é válida",  -- 106
        "contém uma configuração que esta versão não conhece",  -- 107
        "Instalado. A câmera Ação está ativa. Experimente /ccam use hybrid ou /ccam use classic; /ccam help lista tudo.",  -- 108
        "%s também está carregado. Os dois alteram a câmera e vão conflitar. Desative um deles.",  -- 109
        "A câmera segue o terreno",  -- 110
        "sua configuração",  -- 111
    },
    ruRU = {
        "В транспорте",  -- 1
        "Полет",  -- 2
        "Плавание",  -- 3
        "Верхом",  -- 4
        "В бою",  -- 5
        "В рейде",  -- 6
        "В подземелье",  -- 7
        "В городе или таверне",  -- 8
        "Во всех остальных случаях (по умолчанию)",  -- 9
        "Экшен",  -- 10
        "Гибрид",  -- 11
        "Классика",  -- 12
        "Шутер",  -- 13
        "Тактика",  -- 14
        "Кинематограф",  -- 15
        "Фокус на цели",  -- 16
        "Обзор рейда",  -- 17
        "Поездка верхом",  -- 18
        "Прогулка по городу",  -- 19
        "Масштаб",  -- 20
        "Контроллер",  -- 21
        "Направление",  -- 22
        "Плечо",  -- 23
        "Движение головы",  -- 24
        "Цели",  -- 25
        "Сглаживание",  -- 26
        "Расстояние камеры (ярды)",  -- 27
        "Максимальный коэффициент отдаления",  -- 28
        "Скорость поворота стиком (влево/вправо)",  -- 29
        "Скорость наклона стиком (вверх/вниз)",  -- 30
        "Камера следует за направлением движения",  -- 31
        "Скорость слежения (влево/вправо)",  -- 32
        "Скорость слежения (вверх/вниз)",  -- 33
        "Задержка перед возобновлением слежения",  -- 34
        "Смотреть по направлению движения (макс. угол)",  -- 35
        "Смотреть по направлению движения в бою (макс. угол)",  -- 36
        "Поворачивать персонажа вместе с камерой",  -- 37
        "Смотреть по направлению движения верхом",  -- 38
        "Смотреть по направлению движения при плавании",  -- 39
        "Смотреть по направлению движения в полете",  -- 40
        "Смещение за плечо",  -- 41
        "Смещение за плечо по масштабу",  -- 42
        "Динамический наклон (кинематографический)",  -- 43
        "Сила движения головы",  -- 44
        "Движение головы на месте",  -- 45
        "Движение головы в движении",  -- 46
        "Диапазон движения головы",  -- 47
        "Смотреть на цель",  -- 48
        "Сила фокуса на цели (влево/вправо)",  -- 49
        "Сила фокуса на цели (вверх/вниз)",  -- 50
        "Смотреть на NPC, с которым вы говорите",  -- 51
        "Сила фокуса при взаимодействии (влево/вправо)",  -- 52
        "Сила фокуса при взаимодействии (вверх/вниз)",  -- 53
        "Автоследование камеры (мышь и клавиатура)",  -- 54
        "никогда",  -- 55
        "в бою",  -- 56
        "всегда",  -- 57
        "в бою или при сотворении",  -- 58
        "только в движении",  -- 59
        "вкл",  -- 60
        "выкл",  -- 61
        "Профили",  -- 62
        "Включить ControllerCam",  -- 63
        "Быстрый выбор (один профиль везде):",  -- 64
        "Рекомендуемая настройка",  -- 65
        "(без изменений)",  -- 66
        "Использовать везде",  -- 67
        "Создать копию",  -- 68
        "Сохранить текущую камеру",  -- 69
        "Экспорт",  -- 70
        "Импорт",  -- 71
        "Закрыть",  -- 72
        "Удалить",  -- 73
        "по умолчанию",  -- 74
        "По умолч.",  -- 75
        "Мой профиль",  -- 76
        "копия",  -- 77
        "принудительно",  -- 78
        "свой",  -- 79
        "без изменений",  -- 80
        "сейчас",  -- 81
        "пока ничего не применено",  -- 82
        "Сейчас: %s (%s)",  -- 83
        "Сейчас: пока ничего не применено",  -- 84
        "Отразить смещение (другое плечо)",  -- 85
        "Удерживать ситуацию %.1f с после окончания",  -- 86
        "Команды: /ccam help",  -- 87
        "Профиль для каждой ситуации (применяется первая подходящая сверху):",  -- 88
        "Готово.",  -- 89
        "'%s' используется везде.",  -- 90
        "Рекомендуемая настройка применена.",  -- 91
        "Сохранено как '%s'.",  -- 92
        "'%s' удалён.",  -- 93
        "включено",  -- 94
        "отключено. Ваши исходные настройки камеры восстановлены.",  -- 95
        "'%s' импортирован. Попробуйте: /ccam use \"%s\".",  -- 96
        "Это не строка профиля ControllerCam.",  -- 97
        "Нечего импортировать.",  -- 98
        "Строка слишком длинная для профиля.",  -- 99
        "Этот профиль создан в более новой версии ControllerCam. Обновите аддон.",  -- 100
        "Строка повреждена (контрольная сумма не совпадает). Скопируйте её снова целиком.",  -- 101
        "У профиля нет допустимого имени.",  -- 102
        "Невозможно импортировать: %s (%s).",  -- 103
        "значение вне допустимого диапазона",  -- 104
        "недопустимое значение",  -- 105
        "недопустимая кривая",  -- 106
        "содержит неизвестную этой версии настройку",  -- 107
        "Установлено. Включена камера «Экшен». Попробуйте /ccam use hybrid или /ccam use classic; /ccam help покажет все команды.",  -- 108
        "%s тоже загружен. Оба меняют камеру и будут мешать друг другу. Отключите один из них.",  -- 109
        "Камера следует за рельефом",  -- 110
        "ваша настройка",  -- 111
    },
    zhCN = {
        "载具中",  -- 1
        "飞行中",  -- 2
        "游泳中",  -- 3
        "骑乘中",  -- 4
        "战斗中",  -- 5
        "在团队副本中",  -- 6
        "在地下城中",  -- 7
        "在城市或旅店中",  -- 8
        "其他所有情况（默认）",  -- 9
        "动作",  -- 10
        "混合",  -- 11
        "经典",  -- 12
        "射击",  -- 13
        "战术",  -- 14
        "电影",  -- 15
        "目标聚焦",  -- 16
        "团队视角",  -- 17
        "骑乘巡航",  -- 18
        "城镇漫步",  -- 19
        "缩放",  -- 20
        "手柄",  -- 21
        "朝向",  -- 22
        "肩部",  -- 23
        "头部追踪",  -- 24
        "目标",  -- 25
        "平滑",  -- 26
        "镜头距离（码）",  -- 27
        "最大拉远倍率",  -- 28
        "摇杆转向速度（左/右）",  -- 29
        "摇杆俯仰速度（上/下）",  -- 30
        "镜头跟随移动方向",  -- 31
        "跟随速度（左/右）",  -- 32
        "跟随速度（上/下）",  -- 33
        "恢复跟随前的延迟",  -- 34
        "面向移动方向（最大角度）",  -- 35
        "战斗中面向移动方向（最大角度）",  -- 36
        "角色随镜头转动",  -- 37
        "骑乘时面向移动方向",  -- 38
        "游泳时面向移动方向",  -- 39
        "飞行时面向移动方向",  -- 40
        "越肩偏移",  -- 41
        "按缩放的越肩偏移",  -- 42
        "动态俯仰（电影式倾斜）",  -- 43
        "头部追踪强度",  -- 44
        "站立时头部追踪",  -- 45
        "移动时头部追踪",  -- 46
        "头部追踪范围",  -- 47
        "朝向你的目标",  -- 48
        "目标聚焦强度（左/右）",  -- 49
        "目标聚焦强度（上/下）",  -- 50
        "朝向对话的NPC",  -- 51
        "交互聚焦强度（左/右）",  -- 52
        "交互聚焦强度（上/下）",  -- 53
        "镜头自动跟随（鼠标和键盘）",  -- 54
        "从不",  -- 55
        "战斗中",  -- 56
        "总是",  -- 57
        "战斗中或施法时",  -- 58
        "仅移动时",  -- 59
        "开",  -- 60
        "关",  -- 61
        "配置",  -- 62
        "启用 ControllerCam",  -- 63
        "快速选择（所有情境使用同一配置）：",  -- 64
        "推荐设置",  -- 65
        "（不更改）",  -- 66
        "全部使用",  -- 67
        "创建副本",  -- 68
        "保存当前镜头",  -- 69
        "导出",  -- 70
        "导入",  -- 71
        "关闭",  -- 72
        "删除",  -- 73
        "游戏默认",  -- 74
        "默认",  -- 75
        "我的配置",  -- 76
        "副本",  -- 77
        "强制",  -- 78
        "自定义",  -- 79
        "不更改",  -- 80
        "当前",  -- 81
        "尚未应用",  -- 82
        "当前：%s（%s）",  -- 83
        "当前：尚未应用",  -- 84
        "镜像越肩偏移（另一侧肩膀）",  -- 85
        "情境结束后保持 %.1f 秒",  -- 86
        "命令：/ccam help",  -- 87
        "每种情境使用的配置（从上往下，第一个符合的生效）：",  -- 88
        "完成。",  -- 89
        "已在所有情境使用“%s”。",  -- 90
        "已应用推荐设置。",  -- 91
        "已保存为“%s”。",  -- 92
        "已删除“%s”。",  -- 93
        "已启用",  -- 94
        "已禁用。已还原你原来的镜头设置。",  -- 95
        "已导入“%s”。用 /ccam use \"%s\" 试试。",  -- 96
        "这不是 ControllerCam 配置字符串。",  -- 97
        "没有可导入的内容。",  -- 98
        "字符串太长，不是有效的配置。",  -- 99
        "此配置由更新版本的 ControllerCam 创建。请更新插件。",  -- 100
        "字符串已损坏（校验和不匹配）。请重新完整复制。",  -- 101
        "该配置没有有效的名称。",  -- 102
        "无法导入：%s（%s）。",  -- 103
        "有数值超出允许范围",  -- 104
        "有数值无效",  -- 105
        "有曲线无效",  -- 106
        "包含此版本不认识的设置",  -- 107
        "已安装。动作镜头已开启。试试 /ccam use hybrid 或 /ccam use classic，/ccam help 列出所有命令。",  -- 108
        "%s 也已加载。两者都会修改镜头，会互相冲突。请禁用其中一个。",  -- 109
        "镜头跟随地形",  -- 110
        "你的设置",  -- 111
    },
    zhTW = {
        "載具中",  -- 1
        "飛行中",  -- 2
        "游泳中",  -- 3
        "騎乘中",  -- 4
        "戰鬥中",  -- 5
        "在團隊副本中",  -- 6
        "在地城中",  -- 7
        "在城市或旅店中",  -- 8
        "其他所有情況（預設）",  -- 9
        "動作",  -- 10
        "混合",  -- 11
        "經典",  -- 12
        "射擊",  -- 13
        "戰術",  -- 14
        "電影",  -- 15
        "目標聚焦",  -- 16
        "團隊視角",  -- 17
        "騎乘巡航",  -- 18
        "城鎮漫步",  -- 19
        "縮放",  -- 20
        "手把",  -- 21
        "朝向",  -- 22
        "肩部",  -- 23
        "頭部追蹤",  -- 24
        "目標",  -- 25
        "平滑",  -- 26
        "鏡頭距離（碼）",  -- 27
        "最大拉遠倍率",  -- 28
        "搖桿轉向速度（左/右）",  -- 29
        "搖桿俯仰速度（上/下）",  -- 30
        "鏡頭跟隨移動方向",  -- 31
        "跟隨速度（左/右）",  -- 32
        "跟隨速度（上/下）",  -- 33
        "恢復跟隨前的延遲",  -- 34
        "面向移動方向（最大角度）",  -- 35
        "戰鬥中面向移動方向（最大角度）",  -- 36
        "角色隨鏡頭轉動",  -- 37
        "騎乘時面向移動方向",  -- 38
        "游泳時面向移動方向",  -- 39
        "飛行時面向移動方向",  -- 40
        "越肩偏移",  -- 41
        "按縮放的越肩偏移",  -- 42
        "動態俯仰（電影式傾斜）",  -- 43
        "頭部追蹤強度",  -- 44
        "站立時頭部追蹤",  -- 45
        "移動時頭部追蹤",  -- 46
        "頭部追蹤範圍",  -- 47
        "朝向你的目標",  -- 48
        "目標聚焦強度（左/右）",  -- 49
        "目標聚焦強度（上/下）",  -- 50
        "朝向對話的NPC",  -- 51
        "互動聚焦強度（左/右）",  -- 52
        "互動聚焦強度（上/下）",  -- 53
        "鏡頭自動跟隨（滑鼠和鍵盤）",  -- 54
        "從不",  -- 55
        "戰鬥中",  -- 56
        "總是",  -- 57
        "戰鬥中或施法時",  -- 58
        "僅移動時",  -- 59
        "開",  -- 60
        "關",  -- 61
        "設定檔",  -- 62
        "啟用 ControllerCam",  -- 63
        "快速選擇（所有情境使用同一設定檔）：",  -- 64
        "建議設定",  -- 65
        "（不變更）",  -- 66
        "全部使用",  -- 67
        "建立副本",  -- 68
        "儲存目前鏡頭",  -- 69
        "匯出",  -- 70
        "匯入",  -- 71
        "關閉",  -- 72
        "刪除",  -- 73
        "遊戲預設",  -- 74
        "預設",  -- 75
        "我的設定檔",  -- 76
        "副本",  -- 77
        "強制",  -- 78
        "自訂",  -- 79
        "不變更",  -- 80
        "目前",  -- 81
        "尚未套用",  -- 82
        "目前：%s（%s）",  -- 83
        "目前：尚未套用",  -- 84
        "鏡像越肩偏移（另一側肩膀）",  -- 85
        "情境結束後保持 %.1f 秒",  -- 86
        "指令：/ccam help",  -- 87
        "每種情境使用的設定檔（由上往下，第一個符合的生效）：",  -- 88
        "完成。",  -- 89
        "已在所有情境使用「%s」。",  -- 90
        "已套用建議設定。",  -- 91
        "已儲存為「%s」。",  -- 92
        "已刪除「%s」。",  -- 93
        "已啟用",  -- 94
        "已停用。已還原你原本的鏡頭設定。",  -- 95
        "已匯入「%s」。用 /ccam use \"%s\" 試試。",  -- 96
        "這不是 ControllerCam 設定檔字串。",  -- 97
        "沒有可匯入的內容。",  -- 98
        "字串太長，不是有效的設定檔。",  -- 99
        "此設定檔由較新版本的 ControllerCam 建立。請更新插件。",  -- 100
        "字串已損壞（檢查碼不符）。請重新完整複製。",  -- 101
        "該設定檔沒有有效的名稱。",  -- 102
        "無法匯入：%s（%s）。",  -- 103
        "有數值超出允許範圍",  -- 104
        "有數值無效",  -- 105
        "有曲線無效",  -- 106
        "包含此版本不認得的設定",  -- 107
        "已安裝。動作鏡頭已開啟。試試 /ccam use hybrid 或 /ccam use classic，/ccam help 列出所有指令。",  -- 108
        "%s 也已載入。兩者都會修改鏡頭，會互相衝突。請停用其中一個。",  -- 109
        "鏡頭跟隨地形",  -- 110
        "你的設定",  -- 111
    },
}
TRANSLATIONS.esMX = TRANSLATIONS.esES      -- Latin American Spanish uses the same text

-- Lookup table: L["English text"] -> translated text, or the English text itself when there is none.
local L = setmetatable({}, { __index = function(_, key) return key end })

local translated = TRANSLATIONS[GetLocale()]
if translated then
    for i, english in ipairs(ENGLISH) do
        if translated[i] then L[english] = translated[i] end
    end
end

ns.L = L
ns.localeData = { english = ENGLISH, translations = TRANSLATIONS }   -- used by the automated tests
