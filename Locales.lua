-- ControllerCam localization.
--
-- The English text is the lookup key (L["Some text"]). Translations are listed in the SAME ORDER as the
-- ENGLISH list below, one table per game locale. Anything missing falls back to English, so a new text can be
-- added at the end of ENGLISH before it is translated. Keep %s / %d / %.1f placeholders in the same order when
-- adding or fixing a language.

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
    "Advanced: edit built-in profiles",  -- 112
    "Reset to original",  -- 113
    "(edited)",  -- 114
    "Everything not listed uses the game default.",  -- 115
    "The out-of-the-box feel: close third-person camera over your shoulder, head tracking, the camera follows where you run and you face where you move. Out of combat you run free, in combat you strafe.",  -- 116
    "Between Classic and Action: a medium distance, a light over-the-shoulder offset and gentle head tracking. The camera follows your movement, but you still get a wide view.",  -- 117
    "The game's own camera: every setting ControllerCam manages goes back to its default. Your camera distance and your terrain-following setting are left as they are.",  -- 118
    "A third-person shooter feel: tight camera, a strong shoulder offset, fast stick aim. You run facing your movement outside combat and strafe facing the camera in combat.",  -- 119
    "Even closer and steadier, for cover-shooter play: your character always turns with the camera, the shoulder offset is large and the camera does not drift on its own.",  -- 120
    "Slow, wide and moody, for questing and screenshots: dynamic pitch, strong head tracking and a camera that turns toward whoever you talk to.",  -- 121
    "The camera leans toward your current target and the NPCs you talk to. Good for single-target fights.",  -- 122
    "A far, steady camera for dungeons and raids: no offset, no head tracking, no camera drift and fast stick turning so you can see the whole fight.",  -- 123
    "For riding: a far camera that swings behind you as you steer. The offset is off, because mounts of different sizes make it unreliable.",  -- 124
    "For flying: a far camera that follows your climb and dive.",  -- 125
    "A relaxed, slower camera for cities: closer, calm and with head tracking.",  -- 126
    "Custom profile. Duplicate or edit it in the profile editor.",  -- 127
    "show status",  -- 128
    "list the profiles",  -- 129
    "what a profile feels like and every setting it changes",  -- 130
    "use one profile everywhere (try: action, hybrid, classic)",  -- 131
    "the recommended setup: Action camera with calmer profiles for cities, mounts, flying, raids",  -- 132
    "choose the profile for one situation (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
    "use a profile now, whatever the situation",  -- 134
    "stop forcing a profile",  -- 135
    "save your current camera settings as a new profile",  -- 136
    "make an editable copy of a profile",  -- 137
    "change a setting of a custom profile (/ccam settings lists them)",  -- 138
    "shoulder offset by camera distance, e.g. /ccam curve mine 0:2 8:2 20:0",  -- 139
    "allow editing the built-in profiles too (/ccam reset <profile> brings the original back)",  -- 140
    "put an edited built-in profile back to its original settings",  -- 141
    "delete a custom profile",  -- 142
    "show a string you can share",  -- 143
    "add a profile from a shared string",  -- 144
    "switch the shoulder offset to the other shoulder",  -- 145
    "how long a situation is kept after it ends (default 1.5)",  -- 146
    "turn on, or turn off and restore your original camera settings",  -- 147
    "show the zoom, shoulder offset and motion settings right now (for troubleshooting)",  -- 148
    "open the options panel (Options > AddOns > ControllerCam)",  -- 149
    "show this list",  -- 150
    "'%s' matches more than one profile. Type more of the name.",  -- 151
    "No profile called '%s'. /ccam list shows them.",  -- 152
    "Camera profiles for controller play. Out of the box you get an Action camera; Hybrid and Classic are one command away.",  -- 153
    "Built-in profiles are locked. Turn on advanced editing (/ccam advanced on) or make a copy: /ccam copy <profile>",  -- 154
    "Unknown setting. /ccam settings lists them.",  -- 155
    "That value is outside the allowed range.",  -- 156
    "That value is not valid.",  -- 157
    "Unknown situation. Use: vehicle, flying, swimming, mounted, combat, raid, dungeon, city or default.",  -- 158
    "usage: /ccam set <situation> <profile|none>",  -- 159
    "%s: no change",  -- 160
    "Forcing '%s'. /ccam auto goes back to the situations.",  -- 161
    "The camera follows your situations again.",  -- 162
    "usage: /ccam edit <profile> <setting> <value|default>",  -- 163
    "Use /ccam curve for the offset by zoom.",  -- 164
    "usage: /ccam advanced [on|off]",  -- 165
    "Advanced editing is %s.",  -- 166
    "'%s' is back to its original settings.",  -- 167
    "Nothing to reset: '%s' has not been edited.",  -- 168
    "Built-in profiles cannot be deleted.",  -- 169
    "Shoulder offset mirrored.",  -- 170
    "Shoulder offset back to normal.",  -- 171
    "Situations are kept for %.1f seconds after they end.",  -- 172
    "usage: /ccam delay <seconds>",  -- 173
    "options panel is not available in this client",  -- 174
    "unknown command '%s'. Type /ccam help",  -- 175
    "Left-click: next profile. Right-click: previous profile. The first entry, no change, leaves the camera alone.",  -- 176
    "Left-click: next profile. Right-click: previous profile.",  -- 177
    "Press Ctrl+C to copy, then Esc.",  -- 178
    "Paste a ControllerCam string here (Ctrl+V), then press Import.",  -- 179
    "Camera profiles for controller play. Pick what the camera feels like in each situation. Left-click a profile to go to the next one, right-click for the previous one.",  -- 180
    "Turn the camera control on or off. When off, your original camera settings are put back.",  -- 181
    "Action camera with calmer profiles for cities, mounts, flying and raids.",  -- 182
    "Stops the camera from flickering between profiles when a situation switches on and off quickly.",  -- 183
    "Swaps which shoulder the camera looks over.",  -- 184
    "Use this profile in every situation.",  -- 185
    "Makes an editable copy of this profile.",  -- 186
    "Saves the camera settings you have right now as a new profile.",  -- 187
    "Shows a string you can share.",  -- 188
    "Add a profile from a shared string.",  -- 189
    "Deletes this custom profile.",  -- 190
    "Puts this built-in profile back to its original settings.",  -- 191
    "Lets you change the built-in profiles too. Your changes are kept, and Reset to original brings the original back.",  -- 192
    "Zoom distance and offset pairs, for example 0:2 8:2 20:0. Empty = no curve. Press Enter to apply.",  -- 193
    "Use the game's default for this setting.",  -- 194
    "Advanced editing is on. Changes to a built-in profile are kept; Reset to original brings it back.",  -- 195
    "Settings not listed use the game default. Click a value to change it; the curve box takes zoom:offset pairs.",  -- 196
    "Built-in profiles are locked. Make a copy, or tick Advanced to edit them.",  -- 197
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
        "Erweitert: integrierte Profile bearbeiten",  -- 112
        "Auf Original zurücksetzen",  -- 113
        "(bearbeitet)",  -- 114
        "Alles, was nicht aufgeführt ist, verwendet den Spielstandard.",  -- 115
        "Das Gefühl direkt nach der Installation: nahe Third-Person-Kamera über der Schulter, Kopfbewegung, die Kamera folgt deiner Laufrichtung und du blickst in Bewegungsrichtung. Außerhalb des Kampfs läufst du frei, im Kampf strafst du.",  -- 116
        "Zwischen Klassisch und Action: mittlerer Abstand, leichter Schulterversatz und sanfte Kopfbewegung. Die Kamera folgt deiner Bewegung, du behältst aber einen weiten Blick.",  -- 117
        "Die Kamera des Spiels: Jede von ControllerCam verwaltete Einstellung geht auf ihren Standard zurück. Dein Kameraabstand und deine Einstellung zum Geländefolgen bleiben unverändert.",  -- 118
        "Third-Person-Shooter-Gefühl: enge Kamera, starker Schulterversatz, schnelles Zielen mit dem Stick. Außerhalb des Kampfs läufst du in Bewegungsrichtung, im Kampf strafst du mit Blick in Kamerarichtung.",  -- 119
        "Noch näher und ruhiger, für Deckungs-Shooter-Spiel: Dein Charakter dreht sich immer mit der Kamera, der Schulterversatz ist groß und die Kamera driftet nicht von selbst.",  -- 120
        "Langsam, weit und stimmungsvoll, für Quests und Screenshots: dynamische Neigung, starke Kopfbewegung und eine Kamera, die sich zu deinem Gesprächspartner dreht.",  -- 121
        "Die Kamera neigt sich zu deinem aktuellen Ziel und zu NPCs, mit denen du sprichst. Gut für Kämpfe gegen einzelne Ziele.",  -- 122
        "Eine weite, ruhige Kamera für Dungeons und Schlachtzüge: kein Versatz, keine Kopfbewegung, kein Kameradrift und schnelles Drehen mit dem Stick, damit du den ganzen Kampf überblickst.",  -- 123
        "Fürs Reiten: eine weite Kamera, die beim Lenken hinter dich schwenkt. Der Versatz ist aus, weil Reittiere unterschiedlicher Größe ihn unzuverlässig machen.",  -- 124
        "Fürs Fliegen: eine weite Kamera, die deinem Steig- und Sinkflug folgt.",  -- 125
        "Eine entspannte, langsamere Kamera für Städte: näher, ruhig und mit Kopfbewegung.",  -- 126
        "Eigenes Profil. Im Profil-Editor duplizieren oder bearbeiten.",  -- 127
        "Status anzeigen",  -- 128
        "Profile auflisten",  -- 129
        "wie sich ein Profil anfühlt und jede Einstellung, die es ändert",  -- 130
        "ein Profil überall verwenden (z. B. action, hybrid, classic)",  -- 131
        "die empfohlene Einrichtung: Action-Kamera mit ruhigeren Profilen für Städte, Reittiere, Fliegen und Schlachtzüge",  -- 132
        "das Profil für eine Situation wählen (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "ein Profil jetzt verwenden, egal in welcher Situation",  -- 134
        "Erzwingen eines Profils beenden",  -- 135
        "deine aktuellen Kameraeinstellungen als neues Profil speichern",  -- 136
        "eine bearbeitbare Kopie eines Profils erstellen",  -- 137
        "eine Einstellung eines eigenen Profils ändern (/ccam settings listet sie auf)",  -- 138
        "Schulterversatz nach Kameraabstand, z. B. /ccam curve mine 0:2 8:2 20:0",  -- 139
        "auch die integrierten Profile bearbeitbar machen (/ccam reset <profile> stellt das Original wieder her)",  -- 140
        "ein bearbeitetes integriertes Profil auf seine Originaleinstellungen zurücksetzen",  -- 141
        "ein eigenes Profil löschen",  -- 142
        "eine Zeichenfolge zum Teilen anzeigen",  -- 143
        "ein Profil aus einer geteilten Zeichenfolge hinzufügen",  -- 144
        "den Schulterversatz auf die andere Schulter wechseln",  -- 145
        "wie lange eine Situation nach ihrem Ende gehalten wird (Standard 1,5)",  -- 146
        "einschalten, oder ausschalten und deine ursprünglichen Kameraeinstellungen wiederherstellen",  -- 147
        "Zoom, Schulterversatz und Bewegungseinstellungen jetzt anzeigen (zur Fehlersuche)",  -- 148
        "das Optionsfenster öffnen (Optionen > AddOns > ControllerCam)",  -- 149
        "diese Liste anzeigen",  -- 150
        "'%s' passt auf mehr als ein Profil. Gib mehr vom Namen ein.",  -- 151
        "Kein Profil namens '%s'. /ccam list zeigt sie an.",  -- 152
        "Kameraprofile für das Spielen mit Controller. Sofort gibt es eine Action-Kamera; Hybrid und Klassisch sind einen Befehl entfernt.",  -- 153
        "Integrierte Profile sind gesperrt. Aktiviere die erweiterte Bearbeitung (/ccam advanced on) oder erstelle eine Kopie: /ccam copy <profile>",  -- 154
        "Unbekannte Einstellung. /ccam settings listet sie auf.",  -- 155
        "Dieser Wert liegt außerhalb des erlaubten Bereichs.",  -- 156
        "Dieser Wert ist ungültig.",  -- 157
        "Unbekannte Situation. Verwende: vehicle, flying, swimming, mounted, combat, raid, dungeon, city oder default.",  -- 158
        "Verwendung: /ccam set <situation> <profile|none>",  -- 159
        "%s: keine Änderung",  -- 160
        "'%s' wird erzwungen. /ccam auto kehrt zu den Situationen zurück.",  -- 161
        "Die Kamera folgt wieder deinen Situationen.",  -- 162
        "Verwendung: /ccam edit <profile> <setting> <value|default>",  -- 163
        "Verwende /ccam curve für den Versatz nach Zoom.",  -- 164
        "Verwendung: /ccam advanced [on|off]",  -- 165
        "Erweiterte Bearbeitung ist %s.",  -- 166
        "'%s' hat wieder seine Originaleinstellungen.",  -- 167
        "Nichts zurückzusetzen: '%s' wurde nicht bearbeitet.",  -- 168
        "Integrierte Profile können nicht gelöscht werden.",  -- 169
        "Schulterversatz gespiegelt.",  -- 170
        "Schulterversatz wieder normal.",  -- 171
        "Situationen werden nach ihrem Ende noch %.1f Sekunden gehalten.",  -- 172
        "Verwendung: /ccam delay <seconds>",  -- 173
        "Das Optionsfenster ist in diesem Client nicht verfügbar",  -- 174
        "unbekannter Befehl '%s'. Gib /ccam help ein",  -- 175
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil. Der erste Eintrag, keine Änderung, lässt die Kamera unberührt.",  -- 176
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil.",  -- 177
        "Strg+C zum Kopieren drücken, dann Esc.",  -- 178
        "Füge hier eine ControllerCam-Zeichenfolge ein (Strg+V) und drücke dann auf Importieren.",  -- 179
        "Kameraprofile für das Spielen mit Controller. Wähle, wie sich die Kamera in jeder Situation anfühlt. Linksklick auf ein Profil wechselt zum nächsten, Rechtsklick zum vorherigen.",  -- 180
        "Kamerasteuerung ein- oder ausschalten. Im ausgeschalteten Zustand werden deine ursprünglichen Kameraeinstellungen wiederhergestellt.",  -- 181
        "Action-Kamera mit ruhigeren Profilen für Städte, Reittiere, Fliegen und Schlachtzüge.",  -- 182
        "Verhindert, dass die Kamera zwischen Profilen flackert, wenn eine Situation schnell an- und ausgeht.",  -- 183
        "Wechselt, über welche Schulter die Kamera blickt.",  -- 184
        "Dieses Profil in jeder Situation verwenden.",  -- 185
        "Erstellt eine bearbeitbare Kopie dieses Profils.",  -- 186
        "Speichert deine aktuellen Kameraeinstellungen als neues Profil.",  -- 187
        "Zeigt eine Zeichenfolge zum Teilen an.",  -- 188
        "Fügt ein Profil aus einer geteilten Zeichenfolge hinzu.",  -- 189
        "Löscht dieses eigene Profil.",  -- 190
        "Setzt dieses integrierte Profil auf seine Originaleinstellungen zurück.",  -- 191
        "Erlaubt es, auch die integrierten Profile zu ändern. Deine Änderungen bleiben erhalten, und „Auf Original zurücksetzen“ stellt das Original wieder her.",  -- 192
        "Paare aus Zoomabstand und Versatz, zum Beispiel 0:2 8:2 20:0. Leer = keine Kurve. Zum Anwenden Enter drücken.",  -- 193
        "Den Spielstandard für diese Einstellung verwenden.",  -- 194
        "Erweiterte Bearbeitung ist aktiv. Änderungen an einem integrierten Profil bleiben erhalten; „Auf Original zurücksetzen“ stellt es wieder her.",  -- 195
        "Nicht aufgeführte Einstellungen verwenden den Spielstandard. Klicke auf einen Wert, um ihn zu ändern; das Kurvenfeld nimmt Zoom:Versatz-Paare an.",  -- 196
        "Integrierte Profile sind gesperrt. Erstelle eine Kopie oder aktiviere „Erweitert“, um sie zu bearbeiten.",  -- 197
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
        "Avanzado: editar los perfiles integrados",  -- 112
        "Restablecer el original",  -- 113
        "(editado)",  -- 114
        "Todo lo que no aparece usa el valor predeterminado del juego.",  -- 115
        "La sensación lista para usar: cámara cercana en tercera persona sobre el hombro, seguimiento de cabeza, la cámara sigue hacia dónde corres y miras hacia donde te mueves. Fuera de combate corres libremente; en combate te desplazas lateralmente.",  -- 116
        "Entre Clásico y Acción: distancia media, un ligero desplazamiento sobre el hombro y un seguimiento de cabeza suave. La cámara sigue tu movimiento, pero conservas una vista amplia.",  -- 117
        "La cámara del propio juego: todos los ajustes que gestiona ControllerCam vuelven a su valor predeterminado. Tu distancia de cámara y tu ajuste de seguir el terreno no se tocan.",  -- 118
        "Sensación de shooter en tercera persona: cámara ajustada, fuerte desplazamiento sobre el hombro y apuntado rápido con el stick. Fuera de combate corres mirando hacia donde te mueves; en combate te desplazas lateralmente mirando a la cámara.",  -- 119
        "Aún más cerca y más estable, para juego tipo cover shooter: tu personaje siempre gira con la cámara, el desplazamiento sobre el hombro es grande y la cámara no se mueve sola.",  -- 120
        "Lenta, amplia y atmosférica, para misiones y capturas: inclinación dinámica, seguimiento de cabeza intenso y una cámara que se vuelve hacia quien hablas.",  -- 121
        "La cámara se inclina hacia tu objetivo actual y los PNJ con los que hablas. Buena para combates contra un solo objetivo.",  -- 122
        "Una cámara lejana y estable para mazmorras y bandas: sin desplazamiento, sin seguimiento de cabeza, sin deriva y con giro rápido del stick para ver todo el combate.",  -- 123
        "Para cabalgar: una cámara lejana que gira tras de ti al dirigir. El desplazamiento está desactivado porque las monturas de distintos tamaños lo hacen poco fiable.",  -- 124
        "Para volar: una cámara lejana que sigue tus ascensos y descensos.",  -- 125
        "Una cámara relajada y más lenta para ciudades: más cercana, tranquila y con seguimiento de cabeza.",  -- 126
        "Perfil personalizado. Duplícalo o edítalo en el editor de perfiles.",  -- 127
        "mostrar el estado",  -- 128
        "listar los perfiles",  -- 129
        "cómo se siente un perfil y todos los ajustes que cambia",  -- 130
        "usar un perfil en todas partes (prueba: action, hybrid, classic)",  -- 131
        "la configuración recomendada: cámara de Acción con perfiles más calmados para ciudades, monturas, vuelo y bandas",  -- 132
        "elegir el perfil de una situación (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "usar un perfil ahora, sea cual sea la situación",  -- 134
        "dejar de forzar un perfil",  -- 135
        "guardar tus ajustes de cámara actuales como un perfil nuevo",  -- 136
        "hacer una copia editable de un perfil",  -- 137
        "cambiar un ajuste de un perfil personalizado (/ccam settings los lista)",  -- 138
        "desplazamiento sobre el hombro según la distancia de la cámara, p. ej. /ccam curve mine 0:2 8:2 20:0",  -- 139
        "permitir editar también los perfiles integrados (/ccam reset <profile> restaura el original)",  -- 140
        "devolver un perfil integrado editado a sus ajustes originales",  -- 141
        "eliminar un perfil personalizado",  -- 142
        "mostrar una cadena que puedes compartir",  -- 143
        "añadir un perfil desde una cadena compartida",  -- 144
        "cambiar el desplazamiento al otro hombro",  -- 145
        "cuánto se mantiene una situación tras terminar (predeterminado 1,5)",  -- 146
        "activar, o desactivar y restaurar tus ajustes de cámara originales",  -- 147
        "mostrar ahora el zoom, el desplazamiento y los ajustes de movimiento (para diagnosticar)",  -- 148
        "abrir el panel de opciones (Opciones > AddOns > ControllerCam)",  -- 149
        "mostrar esta lista",  -- 150
        "'%s' coincide con más de un perfil. Escribe más del nombre.",  -- 151
        "No hay ningún perfil llamado '%s'. /ccam list los muestra.",  -- 152
        "Perfiles de cámara para jugar con mando. Nada más instalar tienes una cámara de Acción; Híbrido y Clásico están a un comando.",  -- 153
        "Los perfiles integrados están bloqueados. Activa la edición avanzada (/ccam advanced on) o haz una copia: /ccam copy <profile>",  -- 154
        "Ajuste desconocido. /ccam settings los lista.",  -- 155
        "Ese valor está fuera del rango permitido.",  -- 156
        "Ese valor no es válido.",  -- 157
        "Situación desconocida. Usa: vehicle, flying, swimming, mounted, combat, raid, dungeon, city o default.",  -- 158
        "uso: /ccam set <situation> <profile|none>",  -- 159
        "%s: sin cambios",  -- 160
        "Forzando '%s'. /ccam auto vuelve a las situaciones.",  -- 161
        "La cámara vuelve a seguir tus situaciones.",  -- 162
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 163
        "Usa /ccam curve para el desplazamiento según el zoom.",  -- 164
        "uso: /ccam advanced [on|off]",  -- 165
        "La edición avanzada está %s.",  -- 166
        "'%s' vuelve a sus ajustes originales.",  -- 167
        "Nada que restablecer: '%s' no se ha editado.",  -- 168
        "Los perfiles integrados no se pueden eliminar.",  -- 169
        "Desplazamiento sobre el hombro reflejado.",  -- 170
        "Desplazamiento sobre el hombro de nuevo normal.",  -- 171
        "Las situaciones se mantienen %.1f segundos tras terminar.",  -- 172
        "uso: /ccam delay <seconds>",  -- 173
        "el panel de opciones no está disponible en este cliente",  -- 174
        "comando desconocido '%s'. Escribe /ccam help",  -- 175
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior. La primera entrada, sin cambios, deja la cámara como está.",  -- 176
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior.",  -- 177
        "Pulsa Ctrl+C para copiar y luego Esc.",  -- 178
        "Pega aquí una cadena de ControllerCam (Ctrl+V) y pulsa Importar.",  -- 179
        "Perfiles de cámara para jugar con mando. Elige cómo se siente la cámara en cada situación. Clic izquierdo en un perfil pasa al siguiente; clic derecho, al anterior.",  -- 180
        "Activa o desactiva el control de la cámara. Al desactivarlo se restauran tus ajustes de cámara originales.",  -- 181
        "Cámara de Acción con perfiles más calmados para ciudades, monturas, vuelo y bandas.",  -- 182
        "Evita que la cámara parpadee entre perfiles cuando una situación se activa y desactiva rápidamente.",  -- 183
        "Cambia el hombro sobre el que mira la cámara.",  -- 184
        "Usa este perfil en todas las situaciones.",  -- 185
        "Crea una copia editable de este perfil.",  -- 186
        "Guarda los ajustes de cámara actuales como un perfil nuevo.",  -- 187
        "Muestra una cadena que puedes compartir.",  -- 188
        "Añade un perfil desde una cadena compartida.",  -- 189
        "Elimina este perfil personalizado.",  -- 190
        "Devuelve este perfil integrado a sus ajustes originales.",  -- 191
        "Permite cambiar también los perfiles integrados. Tus cambios se conservan y «Restablecer el original» recupera el original.",  -- 192
        "Pares de distancia de zoom y desplazamiento, por ejemplo 0:2 8:2 20:0. Vacío = sin curva. Pulsa Intro para aplicar.",  -- 193
        "Usar el valor predeterminado del juego para este ajuste.",  -- 194
        "La edición avanzada está activada. Los cambios en un perfil integrado se conservan; «Restablecer el original» lo recupera.",  -- 195
        "Los ajustes que no aparecen usan el valor predeterminado del juego. Haz clic en un valor para cambiarlo; el cuadro de curva acepta pares zoom:desplazamiento.",  -- 196
        "Los perfiles integrados están bloqueados. Haz una copia o marca Avanzado para editarlos.",  -- 197
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
        "Avancé : modifier les profils intégrés",  -- 112
        "Rétablir l'original",  -- 113
        "(modifié)",  -- 114
        "Tout ce qui n'est pas listé utilise la valeur par défaut du jeu.",  -- 115
        "Le ressenti prêt à l'emploi : caméra rapprochée à la troisième personne par-dessus l'épaule, suivi de la tête, la caméra suit votre course et vous faites face à votre direction. Hors combat vous courez librement, en combat vous vous déplacez latéralement.",  -- 116
        "Entre Classique et Action : distance moyenne, léger décalage par-dessus l'épaule et suivi de la tête discret. La caméra suit votre déplacement, mais vous gardez une vue large.",  -- 117
        "La caméra d'origine du jeu : tous les réglages gérés par ControllerCam reviennent à leur valeur par défaut. Votre distance de caméra et votre réglage de suivi du terrain ne sont pas modifiés.",  -- 118
        "Ambiance shooter à la troisième personne : caméra serrée, fort décalage par-dessus l'épaule, visée rapide au stick. Hors combat vous courez face à votre direction, en combat vous vous déplacez latéralement face à la caméra.",  -- 119
        "Encore plus proche et plus stable, pour le jeu de tir à couvert : votre personnage tourne toujours avec la caméra, le décalage par-dessus l'épaule est important et la caméra ne dérive pas toute seule.",  -- 120
        "Lente, large et d'ambiance, pour les quêtes et les captures d'écran : inclinaison dynamique, fort suivi de la tête et une caméra qui se tourne vers votre interlocuteur.",  -- 121
        "La caméra se penche vers votre cible actuelle et les PNJ à qui vous parlez. Idéal pour les combats contre une seule cible.",  -- 122
        "Une caméra éloignée et stable pour les donjons et les raids : aucun décalage, aucun suivi de la tête, aucune dérive et une rotation rapide au stick pour voir tout le combat.",  -- 123
        "Pour la monture : une caméra éloignée qui se place derrière vous quand vous dirigez. Le décalage est désactivé, car les montures de tailles différentes le rendent peu fiable.",  -- 124
        "Pour le vol : une caméra éloignée qui suit vos montées et vos piqués.",  -- 125
        "Une caméra détendue et plus lente pour les villes : plus proche, calme et avec suivi de la tête.",  -- 126
        "Profil personnalisé. Dupliquez-le ou modifiez-le dans l'éditeur de profils.",  -- 127
        "afficher l'état",  -- 128
        "lister les profils",  -- 129
        "le ressenti d'un profil et tous les réglages qu'il modifie",  -- 130
        "utiliser un profil partout (essayez : action, hybrid, classic)",  -- 131
        "la configuration recommandée : caméra Action avec des profils plus calmes pour les villes, montures, le vol et les raids",  -- 132
        "choisir le profil d'une situation (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "utiliser un profil maintenant, quelle que soit la situation",  -- 134
        "arrêter de forcer un profil",  -- 135
        "enregistrer vos réglages de caméra actuels comme nouveau profil",  -- 136
        "faire une copie modifiable d'un profil",  -- 137
        "modifier un réglage d'un profil personnalisé (/ccam settings les liste)",  -- 138
        "décalage par-dessus l'épaule selon la distance de la caméra, p. ex. /ccam curve mine 0:2 8:2 20:0",  -- 139
        "autoriser aussi la modification des profils intégrés (/ccam reset <profile> rétablit l'original)",  -- 140
        "remettre un profil intégré modifié à ses réglages d'origine",  -- 141
        "supprimer un profil personnalisé",  -- 142
        "afficher une chaîne à partager",  -- 143
        "ajouter un profil depuis une chaîne partagée",  -- 144
        "passer le décalage sur l'autre épaule",  -- 145
        "combien de temps une situation est conservée après sa fin (par défaut 1,5)",  -- 146
        "activer, ou désactiver et restaurer vos réglages de caméra d'origine",  -- 147
        "afficher maintenant le zoom, le décalage et les réglages de mouvement (pour le dépannage)",  -- 148
        "ouvrir le panneau d'options (Options > AddOns > ControllerCam)",  -- 149
        "afficher cette liste",  -- 150
        "'%s' correspond à plusieurs profils. Tapez davantage du nom.",  -- 151
        "Aucun profil nommé '%s'. /ccam list les affiche.",  -- 152
        "Profils de caméra pour jouer à la manette. Vous avez d'emblée une caméra Action ; Hybride et Classique sont à une commande.",  -- 153
        "Les profils intégrés sont verrouillés. Activez la modification avancée (/ccam advanced on) ou faites une copie : /ccam copy <profile>",  -- 154
        "Réglage inconnu. /ccam settings les liste.",  -- 155
        "Cette valeur est hors de la plage autorisée.",  -- 156
        "Cette valeur n'est pas valide.",  -- 157
        "Situation inconnue. Utilisez : vehicle, flying, swimming, mounted, combat, raid, dungeon, city ou default.",  -- 158
        "utilisation : /ccam set <situation> <profile|none>",  -- 159
        "%s : aucun changement",  -- 160
        "'%s' est forcé. /ccam auto revient aux situations.",  -- 161
        "La caméra suit de nouveau vos situations.",  -- 162
        "utilisation : /ccam edit <profile> <setting> <value|default>",  -- 163
        "Utilisez /ccam curve pour le décalage selon le zoom.",  -- 164
        "utilisation : /ccam advanced [on|off]",  -- 165
        "La modification avancée est %s.",  -- 166
        "'%s' est revenu à ses réglages d'origine.",  -- 167
        "Rien à rétablir : '%s' n'a pas été modifié.",  -- 168
        "Les profils intégrés ne peuvent pas être supprimés.",  -- 169
        "Décalage par-dessus l'épaule inversé.",  -- 170
        "Décalage par-dessus l'épaule revenu à la normale.",  -- 171
        "Les situations sont conservées %.1f secondes après leur fin.",  -- 172
        "utilisation : /ccam delay <seconds>",  -- 173
        "le panneau d'options n'est pas disponible dans ce client",  -- 174
        "commande inconnue '%s'. Tapez /ccam help",  -- 175
        "Clic gauche : profil suivant. Clic droit : profil précédent. La première entrée, aucun changement, laisse la caméra telle quelle.",  -- 176
        "Clic gauche : profil suivant. Clic droit : profil précédent.",  -- 177
        "Appuyez sur Ctrl+C pour copier, puis sur Échap.",  -- 178
        "Collez ici une chaîne ControllerCam (Ctrl+V), puis appuyez sur Importer.",  -- 179
        "Profils de caméra pour jouer à la manette. Choisissez le ressenti de la caméra dans chaque situation. Clic gauche sur un profil pour passer au suivant, clic droit pour le précédent.",  -- 180
        "Active ou désactive le contrôle de la caméra. Une fois désactivé, vos réglages de caméra d'origine sont rétablis.",  -- 181
        "Caméra Action avec des profils plus calmes pour les villes, montures, le vol et les raids.",  -- 182
        "Empêche la caméra de basculer entre les profils lorsqu'une situation s'active et se désactive rapidement.",  -- 183
        "Change l'épaule par-dessus laquelle la caméra regarde.",  -- 184
        "Utiliser ce profil dans toutes les situations.",  -- 185
        "Crée une copie modifiable de ce profil.",  -- 186
        "Enregistre vos réglages de caméra actuels comme nouveau profil.",  -- 187
        "Affiche une chaîne à partager.",  -- 188
        "Ajoute un profil depuis une chaîne partagée.",  -- 189
        "Supprime ce profil personnalisé.",  -- 190
        "Remet ce profil intégré à ses réglages d'origine.",  -- 191
        "Permet de modifier aussi les profils intégrés. Vos modifications sont conservées et « Rétablir l'original » rétablit l'original.",  -- 192
        "Paires distance de zoom et décalage, par exemple 0:2 8:2 20:0. Vide = pas de courbe. Appuyez sur Entrée pour appliquer.",  -- 193
        "Utiliser la valeur par défaut du jeu pour ce réglage.",  -- 194
        "La modification avancée est activée. Les modifications d'un profil intégré sont conservées ; « Rétablir l'original » le restaure.",  -- 195
        "Les réglages non listés utilisent la valeur par défaut du jeu. Cliquez sur une valeur pour la modifier ; le champ de courbe accepte des paires zoom:décalage.",  -- 196
        "Les profils intégrés sont verrouillés. Faites une copie ou cochez Avancé pour les modifier.",  -- 197
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
        "Avanzate: modifica i profili integrati",  -- 112
        "Ripristina l'originale",  -- 113
        "(modificato)",  -- 114
        "Tutto ciò che non è elencato usa il valore predefinito del gioco.",  -- 115
        "La sensazione pronta all'uso: telecamera ravvicinata in terza persona sopra la spalla, movimento della testa, la telecamera segue dove corri e guardi nella direzione del movimento. Fuori dal combattimento corri libero, in combattimento ti sposti lateralmente.",  -- 116
        "A metà tra Classico e Azione: distanza media, un leggero scostamento sopra la spalla e un movimento della testa delicato. La telecamera segue il tuo movimento, ma mantieni una visuale ampia.",  -- 117
        "La telecamera originale del gioco: ogni impostazione gestita da ControllerCam torna al valore predefinito. La distanza della telecamera e l'impostazione di inseguimento del terreno restano invariate.",  -- 118
        "Sensazione da sparatutto in terza persona: telecamera stretta, forte scostamento sopra la spalla, mira rapida con lo stick. Fuori dal combattimento corri nella direzione del movimento, in combattimento ti sposti lateralmente guardando la telecamera.",  -- 119
        "Ancora più vicina e stabile, per il gioco da cover shooter: il personaggio ruota sempre con la telecamera, lo scostamento sopra la spalla è ampio e la telecamera non si sposta da sola.",  -- 120
        "Lenta, ampia e suggestiva, per le missioni e gli screenshot: inclinazione dinamica, forte movimento della testa e una telecamera che si volge verso chi parli.",  -- 121
        "La telecamera si inclina verso il bersaglio attuale e gli NPC con cui parli. Ottima per gli scontri contro un singolo bersaglio.",  -- 122
        "Una telecamera lontana e stabile per dungeon e raid: nessuno scostamento, nessun movimento della testa, nessuna deriva e rotazione rapida con lo stick per vedere tutto lo scontro.",  -- 123
        "Per la cavalcatura: una telecamera lontana che si porta dietro di te mentre sterzi. Lo scostamento è disattivato, perché le cavalcature di dimensioni diverse lo rendono inaffidabile.",  -- 124
        "Per il volo: una telecamera lontana che segue le tue salite e picchiate.",  -- 125
        "Una telecamera rilassata e più lenta per le città: più vicina, calma e con movimento della testa.",  -- 126
        "Profilo personalizzato. Duplicalo o modificalo nell'editor dei profili.",  -- 127
        "mostra lo stato",  -- 128
        "elenca i profili",  -- 129
        "come si comporta un profilo e ogni impostazione che modifica",  -- 130
        "usa un profilo ovunque (prova: action, hybrid, classic)",  -- 131
        "la configurazione consigliata: telecamera Azione con profili più calmi per città, cavalcature, volo e raid",  -- 132
        "scegli il profilo per una situazione (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "usa un profilo adesso, qualunque sia la situazione",  -- 134
        "smetti di forzare un profilo",  -- 135
        "salva le impostazioni attuali della telecamera come nuovo profilo",  -- 136
        "crea una copia modificabile di un profilo",  -- 137
        "cambia un'impostazione di un profilo personalizzato (/ccam settings le elenca)",  -- 138
        "scostamento sopra la spalla in base alla distanza della telecamera, es. /ccam curve mine 0:2 8:2 20:0",  -- 139
        "consenti di modificare anche i profili integrati (/ccam reset <profile> ripristina l'originale)",  -- 140
        "riporta un profilo integrato modificato alle impostazioni originali",  -- 141
        "elimina un profilo personalizzato",  -- 142
        "mostra una stringa da condividere",  -- 143
        "aggiungi un profilo da una stringa condivisa",  -- 144
        "sposta lo scostamento sull'altra spalla",  -- 145
        "per quanto una situazione viene mantenuta dopo la fine (predefinito 1,5)",  -- 146
        "attiva, oppure disattiva e ripristina le impostazioni originali della telecamera",  -- 147
        "mostra ora zoom, scostamento e impostazioni di movimento (per la diagnosi)",  -- 148
        "apri il pannello delle opzioni (Opzioni > AddOn > ControllerCam)",  -- 149
        "mostra questo elenco",  -- 150
        "'%s' corrisponde a più profili. Scrivi più parte del nome.",  -- 151
        "Nessun profilo chiamato '%s'. /ccam list li mostra.",  -- 152
        "Profili della telecamera per giocare con il controller. Subito hai una telecamera Azione; Ibrido e Classico sono a un comando di distanza.",  -- 153
        "I profili integrati sono bloccati. Attiva la modifica avanzata (/ccam advanced on) o crea una copia: /ccam copy <profile>",  -- 154
        "Impostazione sconosciuta. /ccam settings le elenca.",  -- 155
        "Quel valore è fuori dall'intervallo consentito.",  -- 156
        "Quel valore non è valido.",  -- 157
        "Situazione sconosciuta. Usa: vehicle, flying, swimming, mounted, combat, raid, dungeon, city o default.",  -- 158
        "uso: /ccam set <situation> <profile|none>",  -- 159
        "%s: nessuna modifica",  -- 160
        "'%s' forzato. /ccam auto torna alle situazioni.",  -- 161
        "La telecamera segue di nuovo le tue situazioni.",  -- 162
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 163
        "Usa /ccam curve per lo scostamento in base allo zoom.",  -- 164
        "uso: /ccam advanced [on|off]",  -- 165
        "La modifica avanzata è %s.",  -- 166
        "'%s' è tornato alle impostazioni originali.",  -- 167
        "Niente da ripristinare: '%s' non è stato modificato.",  -- 168
        "I profili integrati non possono essere eliminati.",  -- 169
        "Scostamento sopra la spalla specchiato.",  -- 170
        "Scostamento sopra la spalla tornato normale.",  -- 171
        "Le situazioni vengono mantenute per %.1f secondi dopo la fine.",  -- 172
        "uso: /ccam delay <seconds>",  -- 173
        "il pannello delle opzioni non è disponibile in questo client",  -- 174
        "comando sconosciuto '%s'. Digita /ccam help",  -- 175
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente. La prima voce, nessuna modifica, lascia la telecamera com'è.",  -- 176
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente.",  -- 177
        "Premi Ctrl+C per copiare, poi Esc.",  -- 178
        "Incolla qui una stringa ControllerCam (Ctrl+V), poi premi Importa.",  -- 179
        "Profili della telecamera per giocare con il controller. Scegli come si comporta la telecamera in ogni situazione. Clic sinistro su un profilo per il successivo, clic destro per il precedente.",  -- 180
        "Attiva o disattiva il controllo della telecamera. Quando è disattivato, le impostazioni originali della telecamera vengono ripristinate.",  -- 181
        "Telecamera Azione con profili più calmi per città, cavalcature, volo e raid.",  -- 182
        "Evita che la telecamera sfarfalli tra i profili quando una situazione si attiva e disattiva rapidamente.",  -- 183
        "Cambia la spalla sopra la quale guarda la telecamera.",  -- 184
        "Usa questo profilo in ogni situazione.",  -- 185
        "Crea una copia modificabile di questo profilo.",  -- 186
        "Salva le impostazioni attuali della telecamera come nuovo profilo.",  -- 187
        "Mostra una stringa da condividere.",  -- 188
        "Aggiunge un profilo da una stringa condivisa.",  -- 189
        "Elimina questo profilo personalizzato.",  -- 190
        "Riporta questo profilo integrato alle impostazioni originali.",  -- 191
        "Permette di modificare anche i profili integrati. Le modifiche vengono conservate e «Ripristina l'originale» riporta l'originale.",  -- 192
        "Coppie di distanza di zoom e scostamento, per esempio 0:2 8:2 20:0. Vuoto = nessuna curva. Premi Invio per applicare.",  -- 193
        "Usa il valore predefinito del gioco per questa impostazione.",  -- 194
        "La modifica avanzata è attiva. Le modifiche a un profilo integrato vengono conservate; «Ripristina l'originale» lo riporta com'era.",  -- 195
        "Le impostazioni non elencate usano il valore predefinito del gioco. Fai clic su un valore per cambiarlo; il campo della curva accetta coppie zoom:scostamento.",  -- 196
        "I profili integrati sono bloccati. Crea una copia o seleziona Avanzate per modificarli.",  -- 197
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
        "고급: 기본 제공 프로필 편집",  -- 112
        "원래대로 되돌리기",  -- 113
        "(편집됨)",  -- 114
        "나열되지 않은 모든 항목은 게임 기본값을 사용합니다.",  -- 115
        "설치 즉시 쓰는 느낌: 어깨 너머 근접 3인칭 카메라, 머리 추적, 달리는 방향을 따라가는 카메라, 이동 방향을 바라보는 캐릭터. 전투 밖에서는 자유롭게 달리고 전투 중에는 게걸음으로 움직입니다.",  -- 116
        "클래식과 액션의 중간: 중간 거리, 약한 어깨 너머 오프셋, 부드러운 머리 추적. 카메라가 이동을 따라가면서도 넓은 시야를 유지합니다.",  -- 117
        "게임 기본 카메라: ControllerCam이 관리하는 모든 설정이 기본값으로 돌아갑니다. 카메라 거리와 지형 따라가기 설정은 그대로 둡니다.",  -- 118
        "3인칭 슈터 느낌: 가까운 카메라, 강한 어깨 너머 오프셋, 빠른 스틱 조준. 전투 밖에서는 이동 방향을 보고 달리고, 전투 중에는 카메라 방향을 보며 게걸음으로 움직입니다.",  -- 119
        "더 가깝고 안정적인 엄폐 슈터용 설정: 캐릭터가 항상 카메라와 함께 회전하고, 어깨 너머 오프셋이 크며, 카메라가 저절로 움직이지 않습니다.",  -- 120
        "느리고 넓고 분위기 있는 설정, 퀘스트와 스크린샷용: 동적 피치, 강한 머리 추적, 대화 상대 쪽으로 향하는 카메라.",  -- 121
        "카메라가 현재 대상과 대화 중인 NPC 쪽으로 기울어집니다. 단일 대상 전투에 좋습니다.",  -- 122
        "던전과 공격대용 먼 거리의 안정적인 카메라: 오프셋 없음, 머리 추적 없음, 카메라 흔들림 없음, 빠른 스틱 회전으로 전투 전체를 볼 수 있습니다.",  -- 123
        "탈것용: 방향을 틀 때 뒤로 따라 돌아오는 먼 카메라. 크기가 다른 탈것에서는 오프셋이 불안정해 꺼져 있습니다.",  -- 124
        "비행용: 상승과 하강을 따라가는 먼 카메라.",  -- 125
        "도시용 여유롭고 느린 카메라: 더 가깝고 차분하며 머리 추적이 있습니다.",  -- 126
        "사용자 지정 프로필. 프로필 편집기에서 복제하거나 편집하세요.",  -- 127
        "상태 표시",  -- 128
        "프로필 목록",  -- 129
        "프로필의 느낌과 바꾸는 모든 설정",  -- 130
        "모든 곳에 프로필 하나 사용 (예: action, hybrid, classic)",  -- 131
        "권장 설정: 도시, 탈것, 비행, 공격대에는 더 차분한 프로필을 쓰는 액션 카메라",  -- 132
        "한 상황의 프로필 선택 (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "상황과 관계없이 지금 프로필 사용",  -- 134
        "프로필 강제 사용 해제",  -- 135
        "현재 카메라 설정을 새 프로필로 저장",  -- 136
        "프로필의 편집 가능한 복사본 만들기",  -- 137
        "사용자 지정 프로필의 설정 변경 (/ccam settings 로 목록 확인)",  -- 138
        "카메라 거리에 따른 어깨 너머 오프셋, 예: /ccam curve mine 0:2 8:2 20:0",  -- 139
        "기본 제공 프로필도 편집 허용 (/ccam reset <profile> 로 원래대로 복원)",  -- 140
        "편집한 기본 제공 프로필을 원래 설정으로 되돌리기",  -- 141
        "사용자 지정 프로필 삭제",  -- 142
        "공유할 수 있는 문자열 표시",  -- 143
        "공유된 문자열에서 프로필 추가",  -- 144
        "어깨 오프셋을 반대쪽 어깨로 전환",  -- 145
        "상황이 끝난 뒤 유지되는 시간 (기본 1.5)",  -- 146
        "켜기, 또는 끄고 원래 카메라 설정 복원",  -- 147
        "현재 줌, 어깨 오프셋, 모션 설정 표시 (문제 해결용)",  -- 148
        "설정 창 열기 (설정 > 애드온 > ControllerCam)",  -- 149
        "이 목록 표시",  -- 150
        "'%s'은(는) 여러 프로필과 일치합니다. 이름을 더 입력하세요.",  -- 151
        "'%s'(이)라는 프로필이 없습니다. /ccam list 로 확인하세요.",  -- 152
        "컨트롤러 플레이를 위한 카메라 프로필. 설치하면 바로 액션 카메라를 쓰고, 하이브리드와 클래식은 명령어 한 번이면 됩니다.",  -- 153
        "기본 제공 프로필은 잠겨 있습니다. 고급 편집을 켜거나(/ccam advanced on) 복사본을 만드세요: /ccam copy <profile>",  -- 154
        "알 수 없는 설정입니다. /ccam settings 로 목록을 확인하세요.",  -- 155
        "그 값은 허용 범위를 벗어났습니다.",  -- 156
        "그 값이 올바르지 않습니다.",  -- 157
        "알 수 없는 상황입니다. vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default 중 하나를 사용하세요.",  -- 158
        "사용법: /ccam set <situation> <profile|none>",  -- 159
        "%s: 변경 없음",  -- 160
        "'%s'을(를) 강제 사용합니다. /ccam auto 로 상황별 설정으로 돌아갑니다.",  -- 161
        "카메라가 다시 상황에 따라 바뀝니다.",  -- 162
        "사용법: /ccam edit <profile> <setting> <value|default>",  -- 163
        "줌에 따른 오프셋은 /ccam curve 를 사용하세요.",  -- 164
        "사용법: /ccam advanced [on|off]",  -- 165
        "고급 편집: %s.",  -- 166
        "'%s'이(가) 원래 설정으로 돌아갔습니다.",  -- 167
        "되돌릴 내용 없음: '%s'은(는) 편집되지 않았습니다.",  -- 168
        "기본 제공 프로필은 삭제할 수 없습니다.",  -- 169
        "어깨 오프셋이 반전되었습니다.",  -- 170
        "어깨 오프셋이 원래대로 돌아왔습니다.",  -- 171
        "상황은 종료 후 %.1f초 동안 유지됩니다.",  -- 172
        "사용법: /ccam delay <seconds>",  -- 173
        "이 클라이언트에서는 설정 창을 사용할 수 없습니다",  -- 174
        "알 수 없는 명령어 '%s'. /ccam help 를 입력하세요",  -- 175
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필. 첫 항목인 변경 없음은 카메라를 그대로 둡니다.",  -- 176
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필.",  -- 177
        "Ctrl+C로 복사한 뒤 Esc를 누르세요.",  -- 178
        "여기에 ControllerCam 문자열을 붙여넣고(Ctrl+V) 가져오기를 누르세요.",  -- 179
        "컨트롤러 플레이를 위한 카메라 프로필. 각 상황에서 카메라가 어떤 느낌일지 고르세요. 프로필을 좌클릭하면 다음, 우클릭하면 이전 프로필로 바뀝니다.",  -- 180
        "카메라 제어를 켜거나 끕니다. 끄면 원래 카메라 설정이 복원됩니다.",  -- 181
        "도시, 탈것, 비행, 공격대에는 더 차분한 프로필을 쓰는 액션 카메라.",  -- 182
        "상황이 빠르게 켜지고 꺼질 때 카메라가 프로필 사이를 깜빡이며 오가는 것을 막습니다.",  -- 183
        "카메라가 넘겨다보는 어깨를 바꿉니다.",  -- 184
        "모든 상황에서 이 프로필을 사용합니다.",  -- 185
        "이 프로필의 편집 가능한 복사본을 만듭니다.",  -- 186
        "현재 카메라 설정을 새 프로필로 저장합니다.",  -- 187
        "공유할 수 있는 문자열을 표시합니다.",  -- 188
        "공유된 문자열에서 프로필을 추가합니다.",  -- 189
        "이 사용자 지정 프로필을 삭제합니다.",  -- 190
        "이 기본 제공 프로필을 원래 설정으로 되돌립니다.",  -- 191
        "기본 제공 프로필도 변경할 수 있게 합니다. 변경 사항은 유지되며 \"원래대로 되돌리기\"로 원본을 복원할 수 있습니다.",  -- 192
        "줌 거리와 오프셋 쌍, 예: 0:2 8:2 20:0. 비워 두면 곡선 없음. Enter를 눌러 적용하세요.",  -- 193
        "이 설정에 게임 기본값을 사용합니다.",  -- 194
        "고급 편집이 켜져 있습니다. 기본 제공 프로필의 변경 사항은 유지되며 \"원래대로 되돌리기\"로 복원할 수 있습니다.",  -- 195
        "나열되지 않은 설정은 게임 기본값을 사용합니다. 값을 클릭해 변경하세요. 곡선 입력란은 줌:오프셋 쌍을 받습니다.",  -- 196
        "기본 제공 프로필은 잠겨 있습니다. 복사본을 만들거나 고급을 체크해 편집하세요.",  -- 197
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
        "Avançado: editar os perfis integrados",  -- 112
        "Restaurar o original",  -- 113
        "(editado)",  -- 114
        "Tudo que não está listado usa o padrão do jogo.",  -- 115
        "A sensação pronta para usar: câmera próxima em terceira pessoa sobre o ombro, rastreamento da cabeça, a câmera segue para onde você corre e você olha na direção do movimento. Fora de combate você corre livremente; em combate você se desloca lateralmente.",  -- 116
        "Entre Clássico e Ação: distância média, um leve deslocamento sobre o ombro e rastreamento suave da cabeça. A câmera segue seu movimento, mas você mantém uma visão ampla.",  -- 117
        "A câmera original do jogo: todas as configurações gerenciadas pelo ControllerCam voltam ao padrão. Sua distância de câmera e sua configuração de seguir o terreno não são alteradas.",  -- 118
        "Sensação de tiro em terceira pessoa: câmera fechada, forte deslocamento sobre o ombro, mira rápida com o analógico. Fora de combate você corre olhando na direção do movimento; em combate você se desloca lateralmente olhando para a câmera.",  -- 119
        "Ainda mais perto e estável, para jogo de tiro com cobertura: seu personagem sempre gira com a câmera, o deslocamento sobre o ombro é grande e a câmera não se move sozinha.",  -- 120
        "Lenta, ampla e atmosférica, para missões e capturas de tela: inclinação dinâmica, forte rastreamento da cabeça e uma câmera que se vira para quem você conversa.",  -- 121
        "A câmera se inclina para o alvo atual e para os NPCs com quem você fala. Boa para lutas contra um único alvo.",  -- 122
        "Uma câmera distante e estável para masmorras e raides: sem deslocamento, sem rastreamento da cabeça, sem deriva e com giro rápido do analógico para ver toda a luta.",  -- 123
        "Para cavalgar: uma câmera distante que gira atrás de você ao conduzir. O deslocamento fica desligado porque montarias de tamanhos diferentes o tornam pouco confiável.",  -- 124
        "Para voar: uma câmera distante que acompanha suas subidas e mergulhos.",  -- 125
        "Uma câmera relaxada e mais lenta para cidades: mais próxima, calma e com rastreamento da cabeça.",  -- 126
        "Perfil personalizado. Duplique ou edite no editor de perfis.",  -- 127
        "mostrar o status",  -- 128
        "listar os perfis",  -- 129
        "como um perfil se comporta e todas as configurações que ele altera",  -- 130
        "usar um perfil em todo lugar (experimente: action, hybrid, classic)",  -- 131
        "a configuração recomendada: câmera de Ação com perfis mais calmos para cidades, montarias, voo e raides",  -- 132
        "escolher o perfil de uma situação (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "usar um perfil agora, qualquer que seja a situação",  -- 134
        "parar de forçar um perfil",  -- 135
        "salvar suas configurações atuais de câmera como um novo perfil",  -- 136
        "fazer uma cópia editável de um perfil",  -- 137
        "alterar uma configuração de um perfil personalizado (/ccam settings lista todas)",  -- 138
        "deslocamento sobre o ombro por distância da câmera, ex.: /ccam curve mine 0:2 8:2 20:0",  -- 139
        "permitir editar também os perfis integrados (/ccam reset <profile> restaura o original)",  -- 140
        "devolver um perfil integrado editado às configurações originais",  -- 141
        "excluir um perfil personalizado",  -- 142
        "mostrar uma sequência que você pode compartilhar",  -- 143
        "adicionar um perfil a partir de uma sequência compartilhada",  -- 144
        "trocar o deslocamento para o outro ombro",  -- 145
        "por quanto tempo uma situação é mantida após o fim (padrão 1,5)",  -- 146
        "ligar, ou desligar e restaurar suas configurações originais de câmera",  -- 147
        "mostrar agora o zoom, o deslocamento e as configurações de movimento (para diagnóstico)",  -- 148
        "abrir o painel de opções (Opções > AddOns > ControllerCam)",  -- 149
        "mostrar esta lista",  -- 150
        "'%s' corresponde a mais de um perfil. Digite mais do nome.",  -- 151
        "Não há perfil chamado '%s'. /ccam list mostra todos.",  -- 152
        "Perfis de câmera para jogar com controle. Logo de início você tem uma câmera de Ação; Híbrido e Clássico estão a um comando.",  -- 153
        "Os perfis integrados estão bloqueados. Ative a edição avançada (/ccam advanced on) ou faça uma cópia: /ccam copy <profile>",  -- 154
        "Configuração desconhecida. /ccam settings lista todas.",  -- 155
        "Esse valor está fora do intervalo permitido.",  -- 156
        "Esse valor não é válido.",  -- 157
        "Situação desconhecida. Use: vehicle, flying, swimming, mounted, combat, raid, dungeon, city ou default.",  -- 158
        "uso: /ccam set <situation> <profile|none>",  -- 159
        "%s: sem alteração",  -- 160
        "Forçando '%s'. /ccam auto volta às situações.",  -- 161
        "A câmera volta a seguir suas situações.",  -- 162
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 163
        "Use /ccam curve para o deslocamento por zoom.",  -- 164
        "uso: /ccam advanced [on|off]",  -- 165
        "A edição avançada está %s.",  -- 166
        "'%s' voltou às configurações originais.",  -- 167
        "Nada para restaurar: '%s' não foi editado.",  -- 168
        "Os perfis integrados não podem ser excluídos.",  -- 169
        "Deslocamento sobre o ombro espelhado.",  -- 170
        "Deslocamento sobre o ombro de volta ao normal.",  -- 171
        "As situações são mantidas por %.1f segundos após o fim.",  -- 172
        "uso: /ccam delay <seconds>",  -- 173
        "o painel de opções não está disponível neste cliente",  -- 174
        "comando desconhecido '%s'. Digite /ccam help",  -- 175
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior. A primeira entrada, sem alteração, deixa a câmera como está.",  -- 176
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior.",  -- 177
        "Pressione Ctrl+C para copiar e depois Esc.",  -- 178
        "Cole aqui uma sequência do ControllerCam (Ctrl+V) e pressione Importar.",  -- 179
        "Perfis de câmera para jogar com controle. Escolha como a câmera se comporta em cada situação. Clique esquerdo em um perfil vai para o próximo; clique direito, para o anterior.",  -- 180
        "Liga ou desliga o controle da câmera. Desligado, suas configurações originais de câmera são restauradas.",  -- 181
        "Câmera de Ação com perfis mais calmos para cidades, montarias, voo e raides.",  -- 182
        "Evita que a câmera fique alternando entre perfis quando uma situação liga e desliga rapidamente.",  -- 183
        "Troca o ombro sobre o qual a câmera olha.",  -- 184
        "Usa este perfil em todas as situações.",  -- 185
        "Cria uma cópia editável deste perfil.",  -- 186
        "Salva as configurações atuais de câmera como um novo perfil.",  -- 187
        "Mostra uma sequência que você pode compartilhar.",  -- 188
        "Adiciona um perfil a partir de uma sequência compartilhada.",  -- 189
        "Exclui este perfil personalizado.",  -- 190
        "Devolve este perfil integrado às configurações originais.",  -- 191
        "Permite alterar também os perfis integrados. Suas alterações são mantidas e «Restaurar o original» traz o original de volta.",  -- 192
        "Pares de distância de zoom e deslocamento, por exemplo 0:2 8:2 20:0. Vazio = sem curva. Pressione Enter para aplicar.",  -- 193
        "Usar o padrão do jogo para esta configuração.",  -- 194
        "A edição avançada está ativada. As alterações em um perfil integrado são mantidas; «Restaurar o original» o recupera.",  -- 195
        "As configurações não listadas usam o padrão do jogo. Clique em um valor para alterá-lo; a caixa de curva aceita pares zoom:deslocamento.",  -- 196
        "Os perfis integrados estão bloqueados. Faça uma cópia ou marque Avançado para editá-los.",  -- 197
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
        "Дополнительно: изменять встроенные профили",  -- 112
        "Вернуть исходный",  -- 113
        "(изменён)",  -- 114
        "Все, что не указано, использует значения игры по умолчанию.",  -- 115
        "Ощущения «из коробки»: близкая камера от третьего лица из-за плеча, движение головы, камера следует за вашим бегом, а персонаж смотрит по направлению движения. Вне боя вы бежите свободно, в бою — перемещаетесь боком.",  -- 116
        "Золотая середина между «Классикой» и «Экшеном»: средняя дистанция, небольшое смещение за плечо и мягкое движение головы. Камера следует за движением, но обзор остаётся широким.",  -- 117
        "Родная камера игры: все настройки, которыми управляет ControllerCam, возвращаются к значениям по умолчанию. Дистанция камеры и ваша настройка слежения за рельефом не меняются.",  -- 118
        "Ощущения от шутера от третьего лица: тесная камера, сильное смещение за плечо, быстрое прицеливание стиком. Вне боя вы бежите лицом по ходу движения, в бою — перемещаетесь боком, глядя в сторону камеры.",  -- 119
        "Ещё ближе и стабильнее, для игры в стиле шутера с укрытиями: персонаж всегда поворачивается вместе с камерой, смещение за плечо большое, а камера не уплывает сама.",  -- 120
        "Медленная, широкая и атмосферная, для заданий и скриншотов: динамический наклон, сильное движение головы и камера, поворачивающаяся к собеседнику.",  -- 121
        "Камера наклоняется к текущей цели и к NPC, с которыми вы говорите. Хороша для боёв с одной целью.",  -- 122
        "Дальняя устойчивая камера для подземелий и рейдов: без смещения, без движения головы, без дрейфа и с быстрым поворотом стиком, чтобы видеть весь бой.",  -- 123
        "Для езды верхом: дальняя камера, которая разворачивается за вами при повороте. Смещение отключено, потому что у ездовых животных разный размер и оно работает ненадёжно.",  -- 124
        "Для полёта: дальняя камера, следующая за набором высоты и снижением.",  -- 125
        "Спокойная, более медленная камера для городов: ближе, плавная, с движением головы.",  -- 126
        "Пользовательский профиль. Дублируйте или изменяйте его в редакторе профилей.",  -- 127
        "показать состояние",  -- 128
        "список профилей",  -- 129
        "как ощущается профиль и все настройки, которые он меняет",  -- 130
        "один профиль везде (например: action, hybrid, classic)",  -- 131
        "рекомендуемая настройка: камера «Экшен» со спокойными профилями для городов, езды верхом, полёта и рейдов",  -- 132
        "выбрать профиль для ситуации (vehicle, flying, swimming, mounted, combat, raid, dungeon, city, default)",  -- 133
        "использовать профиль сейчас, независимо от ситуации",  -- 134
        "прекратить принудительное использование профиля",  -- 135
        "сохранить текущие настройки камеры как новый профиль",  -- 136
        "создать редактируемую копию профиля",  -- 137
        "изменить настройку пользовательского профиля (/ccam settings покажет список)",  -- 138
        "смещение за плечо в зависимости от дистанции камеры, например /ccam curve mine 0:2 8:2 20:0",  -- 139
        "разрешить изменять и встроенные профили (/ccam reset <profile> вернёт исходный)",  -- 140
        "вернуть изменённый встроенный профиль к исходным настройкам",  -- 141
        "удалить пользовательский профиль",  -- 142
        "показать строку для обмена",  -- 143
        "добавить профиль из полученной строки",  -- 144
        "переключить смещение на другое плечо",  -- 145
        "как долго ситуация сохраняется после окончания (по умолчанию 1,5)",  -- 146
        "включить, либо выключить и восстановить исходные настройки камеры",  -- 147
        "показать текущий масштаб, смещение и настройки движения (для диагностики)",  -- 148
        "открыть окно настроек (Настройки > Модификации > ControllerCam)",  -- 149
        "показать этот список",  -- 150
        "'%s' подходит к нескольким профилям. Введите больше букв названия.",  -- 151
        "Профиль «%s» не найден. /ccam list покажет все профили.",  -- 152
        "Профили камеры для игры с геймпадом. Сразу доступна камера «Экшен»; «Гибрид» и «Классика» включаются одной командой.",  -- 153
        "Встроенные профили заблокированы. Включите расширенное редактирование (/ccam advanced on) или сделайте копию: /ccam copy <profile>",  -- 154
        "Неизвестная настройка. /ccam settings покажет список.",  -- 155
        "Значение вне допустимого диапазона.",  -- 156
        "Недопустимое значение.",  -- 157
        "Неизвестная ситуация. Используйте: vehicle, flying, swimming, mounted, combat, raid, dungeon, city или default.",  -- 158
        "использование: /ccam set <situation> <profile|none>",  -- 159
        "%s: без изменений",  -- 160
        "Принудительно используется «%s». /ccam auto возвращает ситуации.",  -- 161
        "Камера снова следует вашим ситуациям.",  -- 162
        "использование: /ccam edit <profile> <setting> <value|default>",  -- 163
        "Для смещения по масштабу используйте /ccam curve.",  -- 164
        "использование: /ccam advanced [on|off]",  -- 165
        "Расширенное редактирование: %s.",  -- 166
        "«%s» возвращён к исходным настройкам.",  -- 167
        "Нечего возвращать: «%s» не изменялся.",  -- 168
        "Встроенные профили нельзя удалить.",  -- 169
        "Смещение за плечо отражено.",  -- 170
        "Смещение за плечо снова обычное.",  -- 171
        "Ситуации сохраняются %.1f с после окончания.",  -- 172
        "использование: /ccam delay <seconds>",  -- 173
        "окно настроек недоступно в этом клиенте",  -- 174
        "неизвестная команда «%s». Введите /ccam help",  -- 175
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль. Первый пункт, без изменений, оставляет камеру как есть.",  -- 176
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль.",  -- 177
        "Нажмите Ctrl+C, чтобы скопировать, затем Esc.",  -- 178
        "Вставьте сюда строку ControllerCam (Ctrl+V) и нажмите «Импорт».",  -- 179
        "Профили камеры для игры с геймпадом. Выберите, как должна ощущаться камера в каждой ситуации. ЛКМ по профилю — следующий, ПКМ — предыдущий.",  -- 180
        "Включает и выключает управление камерой. При выключении исходные настройки камеры восстанавливаются.",  -- 181
        "Камера «Экшен» со спокойными профилями для городов, езды верхом, полёта и рейдов.",  -- 182
        "Не даёт камере метаться между профилями, когда ситуация быстро включается и выключается.",  -- 183
        "Меняет плечо, через которое смотрит камера.",  -- 184
        "Использовать этот профиль во всех ситуациях.",  -- 185
        "Создаёт редактируемую копию этого профиля.",  -- 186
        "Сохраняет текущие настройки камеры как новый профиль.",  -- 187
        "Показывает строку, которой можно поделиться.",  -- 188
        "Добавляет профиль из полученной строки.",  -- 189
        "Удаляет этот пользовательский профиль.",  -- 190
        "Возвращает этот встроенный профиль к исходным настройкам.",  -- 191
        "Позволяет изменять и встроенные профили. Ваши изменения сохраняются, а «Вернуть исходный» восстанавливает оригинал.",  -- 192
        "Пары «дистанция масштаба : смещение», например 0:2 8:2 20:0. Пусто — без кривой. Нажмите Enter, чтобы применить.",  -- 193
        "Использовать значение игры по умолчанию для этой настройки.",  -- 194
        "Расширенное редактирование включено. Изменения встроенного профиля сохраняются; «Вернуть исходный» восстанавливает оригинал.",  -- 195
        "Не указанные настройки используют значения игры по умолчанию. Щёлкните значение, чтобы изменить его; в поле кривой вводятся пары «масштаб:смещение».",  -- 196
        "Встроенные профили заблокированы. Сделайте копию или отметьте «Дополнительно», чтобы изменять их.",  -- 197
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
        "高级：编辑内置配置",  -- 112
        "恢复原始设置",  -- 113
        "（已编辑）",  -- 114
        "未列出的所有设置均使用游戏默认值。",  -- 115
        "开箱即用的手感：近距离越肩第三人称镜头、头部追踪，镜头跟随你的奔跑方向，角色面向移动方向。非战斗时自由奔跑，战斗中横向移动。",  -- 116
        "介于经典和动作之间：中等距离、轻微的越肩偏移和柔和的头部追踪。镜头跟随你的移动，同时保持开阔的视野。",  -- 117
        "游戏自带镜头：ControllerCam 管理的所有设置恢复为默认值。镜头距离和你的地形跟随设置保持不变。",  -- 118
        "第三人称射击手感：紧凑的镜头、较大的越肩偏移、快速的摇杆瞄准。非战斗时面向移动方向奔跑，战斗中面向镜头方向横向移动。",  -- 119
        "更近更稳，适合掩体射击玩法：角色始终随镜头转动，越肩偏移较大，镜头不会自行漂移。",  -- 120
        "缓慢、开阔、富有氛围，适合做任务和截图：动态俯仰、强烈的头部追踪，镜头会转向你正在交谈的对象。",  -- 121
        "镜头会偏向你当前的目标和对话的NPC。适合单目标战斗。",  -- 122
        "适合地下城和团队副本的远距离稳定镜头：无偏移、无头部追踪、无镜头漂移，摇杆转向迅速，让你看清整场战斗。",  -- 123
        "骑乘专用：转向时镜头会摆到你身后的远距离镜头。越肩偏移已关闭，因为不同体型的坐骑会让它不可靠。",  -- 124
        "飞行专用：跟随你爬升和俯冲的远距离镜头。",  -- 125
        "适合城市的悠闲慢速镜头：更近、更平稳，并带有头部追踪。",  -- 126
        "自定义配置。可在配置编辑器中复制或编辑。",  -- 127
        "显示状态",  -- 128
        "列出配置",  -- 129
        "配置的手感及其更改的所有设置",  -- 130
        "所有情境使用同一配置（例如：action、hybrid、classic）",  -- 131
        "推荐设置：动作镜头，城市、骑乘、飞行和团队副本使用更平稳的配置",  -- 132
        "为某个情境选择配置（vehicle、flying、swimming、mounted、combat、raid、dungeon、city、default）",  -- 133
        "立即使用某个配置，不论情境",  -- 134
        "停止强制使用配置",  -- 135
        "将当前镜头设置保存为新配置",  -- 136
        "创建配置的可编辑副本",  -- 137
        "更改自定义配置的某项设置（/ccam settings 列出所有设置）",  -- 138
        "按镜头距离设置越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 139
        "同时允许编辑内置配置（/ccam reset <profile> 可恢复原始设置）",  -- 140
        "将已编辑的内置配置恢复为原始设置",  -- 141
        "删除自定义配置",  -- 142
        "显示可分享的字符串",  -- 143
        "从分享的字符串添加配置",  -- 144
        "将越肩偏移切换到另一侧肩膀",  -- 145
        "情境结束后保持多久（默认 1.5）",  -- 146
        "开启，或关闭并还原原来的镜头设置",  -- 147
        "显示当前缩放、越肩偏移和动态设置（用于排查问题）",  -- 148
        "打开选项面板（选项 > 插件 > ControllerCam）",  -- 149
        "显示此列表",  -- 150
        "“%s”匹配多个配置。请输入更多名称。",  -- 151
        "没有名为“%s”的配置。/ccam list 可查看所有配置。",  -- 152
        "手柄玩家的镜头配置。开箱即用动作镜头；混合和经典只需一条命令。",  -- 153
        "内置配置已锁定。请开启高级编辑（/ccam advanced on）或创建副本：/ccam copy <profile>",  -- 154
        "未知设置。/ccam settings 可列出所有设置。",  -- 155
        "该数值超出允许范围。",  -- 156
        "该数值无效。",  -- 157
        "未知情境。请使用：vehicle、flying、swimming、mounted、combat、raid、dungeon、city 或 default。",  -- 158
        "用法：/ccam set <situation> <profile|none>",  -- 159
        "%s：不更改",  -- 160
        "正在强制使用“%s”。/ccam auto 可返回按情境切换。",  -- 161
        "镜头恢复按情境切换。",  -- 162
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 163
        "按缩放的偏移请使用 /ccam curve。",  -- 164
        "用法：/ccam advanced [on|off]",  -- 165
        "高级编辑：%s。",  -- 166
        "“%s”已恢复为原始设置。",  -- 167
        "无需还原：“%s”尚未被编辑。",  -- 168
        "内置配置无法删除。",  -- 169
        "越肩偏移已镜像。",  -- 170
        "越肩偏移已恢复正常。",  -- 171
        "情境结束后会保持 %.1f 秒。",  -- 172
        "用法：/ccam delay <seconds>",  -- 173
        "此客户端不支持选项面板",  -- 174
        "未知命令“%s”。请输入 /ccam help",  -- 175
        "左键：下一个配置。右键：上一个配置。第一项“不更改”会保持镜头不变。",  -- 176
        "左键：下一个配置。右键：上一个配置。",  -- 177
        "按 Ctrl+C 复制，然后按 Esc。",  -- 178
        "在此粘贴 ControllerCam 字符串（Ctrl+V），然后点击导入。",  -- 179
        "手柄玩家的镜头配置。为每种情境选择镜头的手感。左键点击配置切换到下一个，右键切换到上一个。",  -- 180
        "开启或关闭镜头控制。关闭后会还原你原来的镜头设置。",  -- 181
        "动作镜头，城市、骑乘、飞行和团队副本使用更平稳的配置。",  -- 182
        "防止情境快速开关时镜头在配置之间来回闪烁。",  -- 183
        "切换镜头越过的肩膀。",  -- 184
        "在所有情境中使用此配置。",  -- 185
        "创建此配置的可编辑副本。",  -- 186
        "将当前镜头设置保存为新配置。",  -- 187
        "显示可分享的字符串。",  -- 188
        "从分享的字符串添加配置。",  -- 189
        "删除此自定义配置。",  -- 190
        "将此内置配置恢复为原始设置。",  -- 191
        "允许同时修改内置配置。你的更改会被保留，“恢复原始设置”可还原原始版本。",  -- 192
        "缩放距离与偏移的数值对，例如 0:2 8:2 20:0。留空表示无曲线。按 Enter 应用。",  -- 193
        "此设置使用游戏默认值。",  -- 194
        "高级编辑已开启。对内置配置的更改会被保留；“恢复原始设置”可还原。",  -- 195
        "未列出的设置使用游戏默认值。点击数值即可更改；曲线输入框接受“缩放:偏移”数值对。",  -- 196
        "内置配置已锁定。请创建副本，或勾选“高级”来编辑它们。",  -- 197
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
        "進階：編輯內建設定檔",  -- 112
        "還原為原始設定",  -- 113
        "（已編輯）",  -- 114
        "未列出的所有設定皆使用遊戲預設值。",  -- 115
        "開箱即用的手感：近距離越肩第三人稱鏡頭、頭部追蹤，鏡頭跟隨你的奔跑方向，角色面向移動方向。非戰鬥時自由奔跑，戰鬥中橫向移動。",  -- 116
        "介於經典和動作之間：中等距離、輕微的越肩偏移和柔和的頭部追蹤。鏡頭跟隨你的移動，同時保持開闊的視野。",  -- 117
        "遊戲內建鏡頭：ControllerCam 管理的所有設定恢復為預設值。鏡頭距離和你的地形跟隨設定保持不變。",  -- 118
        "第三人稱射擊手感：緊湊的鏡頭、較大的越肩偏移、快速的搖桿瞄準。非戰鬥時面向移動方向奔跑，戰鬥中面向鏡頭方向橫向移動。",  -- 119
        "更近更穩，適合掩體射擊玩法：角色始終隨鏡頭轉動，越肩偏移較大，鏡頭不會自行漂移。",  -- 120
        "緩慢、開闊、富有氣氛，適合做任務和截圖：動態俯仰、強烈的頭部追蹤，鏡頭會轉向你正在交談的對象。",  -- 121
        "鏡頭會偏向你目前的目標和對話的NPC。適合單目標戰鬥。",  -- 122
        "適合地城和團隊副本的遠距離穩定鏡頭：無偏移、無頭部追蹤、無鏡頭漂移，搖桿轉向迅速，讓你看清整場戰鬥。",  -- 123
        "騎乘專用：轉向時鏡頭會擺到你身後的遠距離鏡頭。越肩偏移已關閉，因為不同體型的坐騎會讓它不可靠。",  -- 124
        "飛行專用：跟隨你爬升和俯衝的遠距離鏡頭。",  -- 125
        "適合城市的悠閒慢速鏡頭：更近、更平穩，並帶有頭部追蹤。",  -- 126
        "自訂設定檔。可在設定檔編輯器中複製或編輯。",  -- 127
        "顯示狀態",  -- 128
        "列出設定檔",  -- 129
        "設定檔的手感及其更改的所有設定",  -- 130
        "所有情境使用同一設定檔（例如：action、hybrid、classic）",  -- 131
        "建議設定：動作鏡頭，城市、騎乘、飛行和團隊副本使用更平穩的設定檔",  -- 132
        "為某個情境選擇設定檔（vehicle、flying、swimming、mounted、combat、raid、dungeon、city、default）",  -- 133
        "立即使用某個設定檔，不論情境",  -- 134
        "停止強制使用設定檔",  -- 135
        "將目前鏡頭設定儲存為新設定檔",  -- 136
        "建立設定檔的可編輯副本",  -- 137
        "更改自訂設定檔的某項設定（/ccam settings 列出所有設定）",  -- 138
        "依鏡頭距離設定越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 139
        "同時允許編輯內建設定檔（/ccam reset <profile> 可還原為原始設定）",  -- 140
        "將已編輯的內建設定檔還原為原始設定",  -- 141
        "刪除自訂設定檔",  -- 142
        "顯示可分享的字串",  -- 143
        "從分享的字串新增設定檔",  -- 144
        "將越肩偏移切換到另一側肩膀",  -- 145
        "情境結束後保持多久（預設 1.5）",  -- 146
        "開啟，或關閉並還原原本的鏡頭設定",  -- 147
        "顯示目前縮放、越肩偏移和動態設定（用於排查問題）",  -- 148
        "開啟選項面板（選項 > 插件 > ControllerCam）",  -- 149
        "顯示此列表",  -- 150
        "「%s」符合多個設定檔。請輸入更多名稱。",  -- 151
        "沒有名為「%s」的設定檔。/ccam list 可查看所有設定檔。",  -- 152
        "手把玩家的鏡頭設定檔。開箱即用動作鏡頭；混合和經典只需一條指令。",  -- 153
        "內建設定檔已鎖定。請開啟進階編輯（/ccam advanced on）或建立副本：/ccam copy <profile>",  -- 154
        "未知設定。/ccam settings 可列出所有設定。",  -- 155
        "該數值超出允許範圍。",  -- 156
        "該數值無效。",  -- 157
        "未知情境。請使用：vehicle、flying、swimming、mounted、combat、raid、dungeon、city 或 default。",  -- 158
        "用法：/ccam set <situation> <profile|none>",  -- 159
        "%s：不變更",  -- 160
        "正在強制使用「%s」。/ccam auto 可返回依情境切換。",  -- 161
        "鏡頭恢復依情境切換。",  -- 162
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 163
        "依縮放的偏移請使用 /ccam curve。",  -- 164
        "用法：/ccam advanced [on|off]",  -- 165
        "進階編輯：%s。",  -- 166
        "「%s」已還原為原始設定。",  -- 167
        "無需還原：「%s」尚未被編輯。",  -- 168
        "內建設定檔無法刪除。",  -- 169
        "越肩偏移已鏡像。",  -- 170
        "越肩偏移已恢復正常。",  -- 171
        "情境結束後會保持 %.1f 秒。",  -- 172
        "用法：/ccam delay <seconds>",  -- 173
        "此用戶端不支援選項面板",  -- 174
        "未知指令「%s」。請輸入 /ccam help",  -- 175
        "左鍵：下一個設定檔。右鍵：上一個設定檔。第一項「不變更」會保持鏡頭不變。",  -- 176
        "左鍵：下一個設定檔。右鍵：上一個設定檔。",  -- 177
        "按 Ctrl+C 複製，然後按 Esc。",  -- 178
        "在此貼上 ControllerCam 字串（Ctrl+V），然後點擊匯入。",  -- 179
        "手把玩家的鏡頭設定檔。為每種情境選擇鏡頭的手感。左鍵點擊設定檔切換到下一個，右鍵切換到上一個。",  -- 180
        "開啟或關閉鏡頭控制。關閉後會還原你原本的鏡頭設定。",  -- 181
        "動作鏡頭，城市、騎乘、飛行和團隊副本使用更平穩的設定檔。",  -- 182
        "防止情境快速開關時鏡頭在設定檔之間來回閃爍。",  -- 183
        "切換鏡頭越過的肩膀。",  -- 184
        "在所有情境中使用此設定檔。",  -- 185
        "建立此設定檔的可編輯副本。",  -- 186
        "將目前鏡頭設定儲存為新設定檔。",  -- 187
        "顯示可分享的字串。",  -- 188
        "從分享的字串新增設定檔。",  -- 189
        "刪除此自訂設定檔。",  -- 190
        "將此內建設定檔還原為原始設定。",  -- 191
        "允許同時修改內建設定檔。你的變更會被保留，「還原為原始設定」可還原原始版本。",  -- 192
        "縮放距離與偏移的數值對，例如 0:2 8:2 20:0。留空表示無曲線。按 Enter 套用。",  -- 193
        "此設定使用遊戲預設值。",  -- 194
        "進階編輯已開啟。對內建設定檔的變更會被保留；「還原為原始設定」可還原。",  -- 195
        "未列出的設定使用遊戲預設值。點擊數值即可變更；曲線輸入框接受「縮放:偏移」數值對。",  -- 196
        "內建設定檔已鎖定。請建立副本，或勾選「進階」來編輯它們。",  -- 197
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
