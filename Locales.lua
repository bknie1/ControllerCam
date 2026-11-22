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
    "use a profile now, whatever the situation",  -- 133
    "stop forcing a profile",  -- 134
    "save your current camera settings as a new profile",  -- 135
    "make an editable copy of a profile",  -- 136
    "change a setting of a custom profile (/ccam settings lists them)",  -- 137
    "shoulder offset by camera distance, e.g. /ccam curve mine 0:2 8:2 20:0",  -- 138
    "allow editing the built-in profiles too (/ccam reset <profile> brings the original back)",  -- 139
    "put an edited built-in profile back to its original settings",  -- 140
    "delete a custom profile",  -- 141
    "show a string you can share",  -- 142
    "add a profile from a shared string",  -- 143
    "switch the shoulder offset to the other shoulder",  -- 144
    "how long a situation is kept after it ends (default 1.5)",  -- 145
    "turn on, or turn off and restore your original camera settings",  -- 146
    "show the zoom, shoulder offset and motion settings right now (for troubleshooting)",  -- 147
    "open the options panel (Options > AddOns > ControllerCam)",  -- 148
    "show this list",  -- 149
    "'%s' matches more than one profile. Type more of the name.",  -- 150
    "No profile called '%s'. /ccam list shows them.",  -- 151
    "Camera profiles for controller play. Out of the box you get an Action camera; Hybrid and Classic are one command away.",  -- 152
    "Built-in profiles are locked. Turn on advanced editing (/ccam advanced on) or make a copy: /ccam copy <profile>",  -- 153
    "Unknown setting. /ccam settings lists them.",  -- 154
    "That value is outside the allowed range.",  -- 155
    "That value is not valid.",  -- 156
    "usage: /ccam set <situation> <profile|none>",  -- 157
    "%s: no change",  -- 158
    "Forcing '%s'. /ccam auto goes back to the situations.",  -- 159
    "The camera follows your situations again.",  -- 160
    "usage: /ccam edit <profile> <setting> <value|default>",  -- 161
    "Use /ccam curve for the offset by zoom.",  -- 162
    "usage: /ccam advanced [on|off]",  -- 163
    "Advanced editing is %s.",  -- 164
    "'%s' is back to its original settings.",  -- 165
    "Nothing to reset: '%s' has not been edited.",  -- 166
    "Built-in profiles cannot be deleted.",  -- 167
    "Shoulder offset mirrored.",  -- 168
    "Shoulder offset back to normal.",  -- 169
    "Situations are kept for %.1f seconds after they end.",  -- 170
    "usage: /ccam delay <seconds>",  -- 171
    "options panel is not available in this client",  -- 172
    "unknown command '%s'. Type /ccam help",  -- 173
    "Left-click: next profile. Right-click: previous profile. The first entry, no change, leaves the camera alone.",  -- 174
    "Left-click: next profile. Right-click: previous profile.",  -- 175
    "Press Ctrl+C to copy, then Esc.",  -- 176
    "Paste a ControllerCam string here (Ctrl+V), then press Import.",  -- 177
    "Camera profiles for controller play. Pick what the camera feels like in each situation. Left-click a profile to go to the next one, right-click for the previous one.",  -- 178
    "Turn the camera control on or off. When off, your original camera settings are put back.",  -- 179
    "Action camera with calmer profiles for cities, mounts, flying and raids.",  -- 180
    "Stops the camera from flickering between profiles when a situation switches on and off quickly.",  -- 181
    "Swaps which shoulder the camera looks over.",  -- 182
    "Use this profile in every situation.",  -- 183
    "Makes an editable copy of this profile.",  -- 184
    "Saves the camera settings you have right now as a new profile.",  -- 185
    "Shows a string you can share.",  -- 186
    "Add a profile from a shared string.",  -- 187
    "Deletes this custom profile.",  -- 188
    "Puts this built-in profile back to its original settings.",  -- 189
    "Lets you change the built-in profiles too. Your changes are kept, and Reset to original brings the original back.",  -- 190
    "Zoom distance and offset pairs, for example 0:2 8:2 20:0. Empty = no curve. Press Enter to apply.",  -- 191
    "Use the game's default for this setting.",  -- 192
    "Advanced editing is on. Changes to a built-in profile are kept; Reset to original brings it back.",  -- 193
    "Settings not listed use the game default. Click a value to change it; the curve box takes zoom:offset pairs.",  -- 194
    "Built-in profiles are locked. Make a copy, or tick Advanced to edit them.",  -- 195
    "Fishing",  -- 196
    "Indoors",  -- 197
    "Unknown situation. Use one of:",  -- 198
    "choose the profile for one situation (/ccam shows the list)",  -- 199
    "the shoulder offset in the form you are in (druid forms, ghost wolf), in percent of normal",  -- 200
    "You are not in a form.",  -- 201
    "Shoulder offset in this form: %d%%",  -- 202
    "usage: /ccam formoffset <percent> (or reset)",  -- 203
    "The game will ask about its experimental camera settings again at the next login.",  -- 204
    "The game will not ask about the experimental camera settings again (you accepted them). /ccam notice brings the question back.",  -- 205
    "let the game ask about its experimental camera settings again at the next login",  -- 206
    "On an enemy target the camera comes in to %.1f yards.",  -- 207
    "The camera keeps its distance on an enemy target.",  -- 208
    "usage: /ccam targetzoom <yards> (0 or off: off)",  -- 209
    "on an enemy target the camera comes in this close, and goes back out after (0: off)",  -- 210
    "Closer on an enemy target: %.1f yards",  -- 211
    "Closer on an enemy target: off",  -- 212
    "Target an enemy and the camera comes in to this distance; let it go and it goes back to where you had it (not while mounted). Roam far out, fight up close.",  -- 213
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
        "ein Profil jetzt verwenden, egal in welcher Situation",  -- 133
        "Erzwingen eines Profils beenden",  -- 134
        "deine aktuellen Kameraeinstellungen als neues Profil speichern",  -- 135
        "eine bearbeitbare Kopie eines Profils erstellen",  -- 136
        "eine Einstellung eines eigenen Profils ändern (/ccam settings listet sie auf)",  -- 137
        "Schulterversatz nach Kameraabstand, z. B. /ccam curve mine 0:2 8:2 20:0",  -- 138
        "auch die integrierten Profile bearbeitbar machen (/ccam reset <profile> stellt das Original wieder her)",  -- 139
        "ein bearbeitetes integriertes Profil auf seine Originaleinstellungen zurücksetzen",  -- 140
        "ein eigenes Profil löschen",  -- 141
        "eine Zeichenfolge zum Teilen anzeigen",  -- 142
        "ein Profil aus einer geteilten Zeichenfolge hinzufügen",  -- 143
        "den Schulterversatz auf die andere Schulter wechseln",  -- 144
        "wie lange eine Situation nach ihrem Ende gehalten wird (Standard 1,5)",  -- 145
        "einschalten, oder ausschalten und deine ursprünglichen Kameraeinstellungen wiederherstellen",  -- 146
        "Zoom, Schulterversatz und Bewegungseinstellungen jetzt anzeigen (zur Fehlersuche)",  -- 147
        "das Optionsfenster öffnen (Optionen > AddOns > ControllerCam)",  -- 148
        "diese Liste anzeigen",  -- 149
        "'%s' passt auf mehr als ein Profil. Gib mehr vom Namen ein.",  -- 150
        "Kein Profil namens '%s'. /ccam list zeigt sie an.",  -- 151
        "Kameraprofile für das Spielen mit Controller. Sofort gibt es eine Action-Kamera; Hybrid und Klassisch sind einen Befehl entfernt.",  -- 152
        "Integrierte Profile sind gesperrt. Aktiviere die erweiterte Bearbeitung (/ccam advanced on) oder erstelle eine Kopie: /ccam copy <profile>",  -- 153
        "Unbekannte Einstellung. /ccam settings listet sie auf.",  -- 154
        "Dieser Wert liegt außerhalb des erlaubten Bereichs.",  -- 155
        "Dieser Wert ist ungültig.",  -- 156
        "Verwendung: /ccam set <situation> <profile|none>",  -- 157
        "%s: keine Änderung",  -- 158
        "'%s' wird erzwungen. /ccam auto kehrt zu den Situationen zurück.",  -- 159
        "Die Kamera folgt wieder deinen Situationen.",  -- 160
        "Verwendung: /ccam edit <profile> <setting> <value|default>",  -- 161
        "Verwende /ccam curve für den Versatz nach Zoom.",  -- 162
        "Verwendung: /ccam advanced [on|off]",  -- 163
        "Erweiterte Bearbeitung ist %s.",  -- 164
        "'%s' hat wieder seine Originaleinstellungen.",  -- 165
        "Nichts zurückzusetzen: '%s' wurde nicht bearbeitet.",  -- 166
        "Integrierte Profile können nicht gelöscht werden.",  -- 167
        "Schulterversatz gespiegelt.",  -- 168
        "Schulterversatz wieder normal.",  -- 169
        "Situationen werden nach ihrem Ende noch %.1f Sekunden gehalten.",  -- 170
        "Verwendung: /ccam delay <seconds>",  -- 171
        "Das Optionsfenster ist in diesem Client nicht verfügbar",  -- 172
        "unbekannter Befehl '%s'. Gib /ccam help ein",  -- 173
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil. Der erste Eintrag, keine Änderung, lässt die Kamera unberührt.",  -- 174
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil.",  -- 175
        "Strg+C zum Kopieren drücken, dann Esc.",  -- 176
        "Füge hier eine ControllerCam-Zeichenfolge ein (Strg+V) und drücke dann auf Importieren.",  -- 177
        "Kameraprofile für das Spielen mit Controller. Wähle, wie sich die Kamera in jeder Situation anfühlt. Linksklick auf ein Profil wechselt zum nächsten, Rechtsklick zum vorherigen.",  -- 178
        "Kamerasteuerung ein- oder ausschalten. Im ausgeschalteten Zustand werden deine ursprünglichen Kameraeinstellungen wiederhergestellt.",  -- 179
        "Action-Kamera mit ruhigeren Profilen für Städte, Reittiere, Fliegen und Schlachtzüge.",  -- 180
        "Verhindert, dass die Kamera zwischen Profilen flackert, wenn eine Situation schnell an- und ausgeht.",  -- 181
        "Wechselt, über welche Schulter die Kamera blickt.",  -- 182
        "Dieses Profil in jeder Situation verwenden.",  -- 183
        "Erstellt eine bearbeitbare Kopie dieses Profils.",  -- 184
        "Speichert deine aktuellen Kameraeinstellungen als neues Profil.",  -- 185
        "Zeigt eine Zeichenfolge zum Teilen an.",  -- 186
        "Fügt ein Profil aus einer geteilten Zeichenfolge hinzu.",  -- 187
        "Löscht dieses eigene Profil.",  -- 188
        "Setzt dieses integrierte Profil auf seine Originaleinstellungen zurück.",  -- 189
        "Erlaubt es, auch die integrierten Profile zu ändern. Deine Änderungen bleiben erhalten, und „Auf Original zurücksetzen“ stellt das Original wieder her.",  -- 190
        "Paare aus Zoomabstand und Versatz, zum Beispiel 0:2 8:2 20:0. Leer = keine Kurve. Zum Anwenden Enter drücken.",  -- 191
        "Den Spielstandard für diese Einstellung verwenden.",  -- 192
        "Erweiterte Bearbeitung ist aktiv. Änderungen an einem integrierten Profil bleiben erhalten; „Auf Original zurücksetzen“ stellt es wieder her.",  -- 193
        "Nicht aufgeführte Einstellungen verwenden den Spielstandard. Klicke auf einen Wert, um ihn zu ändern; das Kurvenfeld nimmt Zoom:Versatz-Paare an.",  -- 194
        "Integrierte Profile sind gesperrt. Erstelle eine Kopie oder aktiviere „Erweitert“, um sie zu bearbeiten.",  -- 195
        "Angeln",  -- 196
        "In Innenräumen",  -- 197
        "Unbekannte Situation. Möglich sind:",  -- 198
        "das Profil für eine Situation wählen (/ccam zeigt die Liste)",  -- 199
        "der Schulterversatz in deiner aktuellen Gestalt (Druidengestalten, Geisterwolf), in Prozent des normalen",  -- 200
        "Du bist in keiner Gestalt.",  -- 201
        "Schulterversatz in dieser Gestalt: %d%%",  -- 202
        "Verwendung: /ccam formoffset <Prozent> (oder reset)",  -- 203
        "Das Spiel fragt beim nächsten Einloggen wieder nach seinen experimentellen Kameraeinstellungen.",  -- 204
        "Das Spiel fragt nicht mehr nach den experimentellen Kameraeinstellungen (du hast sie akzeptiert). /ccam notice holt die Frage zurück.",  -- 205
        "das Spiel beim nächsten Einloggen wieder nach seinen experimentellen Kameraeinstellungen fragen lassen",  -- 206
        "Bei einem feindlichen Ziel kommt die Kamera auf %.1f Meter heran.",  -- 207
        "Die Kamera behält bei einem feindlichen Ziel ihren Abstand.",  -- 208
        "Verwendung: /ccam targetzoom <Meter> (0 oder off: aus)",  -- 209
        "bei einem feindlichen Ziel kommt die Kamera so nah heran und geht danach wieder zurück (0: aus)",  -- 210
        "Näher bei feindlichem Ziel: %.1f Meter",  -- 211
        "Näher bei feindlichem Ziel: aus",  -- 212
        "Ziele auf einen Feind und die Kamera kommt auf diesen Abstand heran; lässt du ihn los, geht sie zurück, wo du sie hattest (nicht auf dem Reittier). Weit draußen unterwegs, nah dran im Kampf.",  -- 213
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
        "usar un perfil ahora, sea cual sea la situación",  -- 133
        "dejar de forzar un perfil",  -- 134
        "guardar tus ajustes de cámara actuales como un perfil nuevo",  -- 135
        "hacer una copia editable de un perfil",  -- 136
        "cambiar un ajuste de un perfil personalizado (/ccam settings los lista)",  -- 137
        "desplazamiento sobre el hombro según la distancia de la cámara, p. ej. /ccam curve mine 0:2 8:2 20:0",  -- 138
        "permitir editar también los perfiles integrados (/ccam reset <profile> restaura el original)",  -- 139
        "devolver un perfil integrado editado a sus ajustes originales",  -- 140
        "eliminar un perfil personalizado",  -- 141
        "mostrar una cadena que puedes compartir",  -- 142
        "añadir un perfil desde una cadena compartida",  -- 143
        "cambiar el desplazamiento al otro hombro",  -- 144
        "cuánto se mantiene una situación tras terminar (predeterminado 1,5)",  -- 145
        "activar, o desactivar y restaurar tus ajustes de cámara originales",  -- 146
        "mostrar ahora el zoom, el desplazamiento y los ajustes de movimiento (para diagnosticar)",  -- 147
        "abrir el panel de opciones (Opciones > AddOns > ControllerCam)",  -- 148
        "mostrar esta lista",  -- 149
        "'%s' coincide con más de un perfil. Escribe más del nombre.",  -- 150
        "No hay ningún perfil llamado '%s'. /ccam list los muestra.",  -- 151
        "Perfiles de cámara para jugar con mando. Nada más instalar tienes una cámara de Acción; Híbrido y Clásico están a un comando.",  -- 152
        "Los perfiles integrados están bloqueados. Activa la edición avanzada (/ccam advanced on) o haz una copia: /ccam copy <profile>",  -- 153
        "Ajuste desconocido. /ccam settings los lista.",  -- 154
        "Ese valor está fuera del rango permitido.",  -- 155
        "Ese valor no es válido.",  -- 156
        "uso: /ccam set <situation> <profile|none>",  -- 157
        "%s: sin cambios",  -- 158
        "Forzando '%s'. /ccam auto vuelve a las situaciones.",  -- 159
        "La cámara vuelve a seguir tus situaciones.",  -- 160
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 161
        "Usa /ccam curve para el desplazamiento según el zoom.",  -- 162
        "uso: /ccam advanced [on|off]",  -- 163
        "La edición avanzada está %s.",  -- 164
        "'%s' vuelve a sus ajustes originales.",  -- 165
        "Nada que restablecer: '%s' no se ha editado.",  -- 166
        "Los perfiles integrados no se pueden eliminar.",  -- 167
        "Desplazamiento sobre el hombro reflejado.",  -- 168
        "Desplazamiento sobre el hombro de nuevo normal.",  -- 169
        "Las situaciones se mantienen %.1f segundos tras terminar.",  -- 170
        "uso: /ccam delay <seconds>",  -- 171
        "el panel de opciones no está disponible en este cliente",  -- 172
        "comando desconocido '%s'. Escribe /ccam help",  -- 173
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior. La primera entrada, sin cambios, deja la cámara como está.",  -- 174
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior.",  -- 175
        "Pulsa Ctrl+C para copiar y luego Esc.",  -- 176
        "Pega aquí una cadena de ControllerCam (Ctrl+V) y pulsa Importar.",  -- 177
        "Perfiles de cámara para jugar con mando. Elige cómo se siente la cámara en cada situación. Clic izquierdo en un perfil pasa al siguiente; clic derecho, al anterior.",  -- 178
        "Activa o desactiva el control de la cámara. Al desactivarlo se restauran tus ajustes de cámara originales.",  -- 179
        "Cámara de Acción con perfiles más calmados para ciudades, monturas, vuelo y bandas.",  -- 180
        "Evita que la cámara parpadee entre perfiles cuando una situación se activa y desactiva rápidamente.",  -- 181
        "Cambia el hombro sobre el que mira la cámara.",  -- 182
        "Usa este perfil en todas las situaciones.",  -- 183
        "Crea una copia editable de este perfil.",  -- 184
        "Guarda los ajustes de cámara actuales como un perfil nuevo.",  -- 185
        "Muestra una cadena que puedes compartir.",  -- 186
        "Añade un perfil desde una cadena compartida.",  -- 187
        "Elimina este perfil personalizado.",  -- 188
        "Devuelve este perfil integrado a sus ajustes originales.",  -- 189
        "Permite cambiar también los perfiles integrados. Tus cambios se conservan y «Restablecer el original» recupera el original.",  -- 190
        "Pares de distancia de zoom y desplazamiento, por ejemplo 0:2 8:2 20:0. Vacío = sin curva. Pulsa Intro para aplicar.",  -- 191
        "Usar el valor predeterminado del juego para este ajuste.",  -- 192
        "La edición avanzada está activada. Los cambios en un perfil integrado se conservan; «Restablecer el original» lo recupera.",  -- 193
        "Los ajustes que no aparecen usan el valor predeterminado del juego. Haz clic en un valor para cambiarlo; el cuadro de curva acepta pares zoom:desplazamiento.",  -- 194
        "Los perfiles integrados están bloqueados. Haz una copia o marca Avanzado para editarlos.",  -- 195
        "Pescando",  -- 196
        "En interiores",  -- 197
        "Situación desconocida. Usa una de:",  -- 198
        "elegir el perfil para una situación (/ccam muestra la lista)",  -- 199
        "el desplazamiento de hombro en la forma en la que estás (formas de druida, lobo fantasmal), en porcentaje del normal",  -- 200
        "No estás en ninguna forma.",  -- 201
        "Desplazamiento de hombro en esta forma: %d%%",  -- 202
        "uso: /ccam formoffset <porcentaje> (o reset)",  -- 203
        "El juego volverá a preguntar por sus ajustes de cámara experimentales al iniciar sesión la próxima vez.",  -- 204
        "El juego no volverá a preguntar por los ajustes de cámara experimentales (los aceptaste). /ccam notice recupera la pregunta.",  -- 205
        "hacer que el juego vuelva a preguntar por sus ajustes de cámara experimentales al iniciar sesión",  -- 206
        "Con un enemigo como objetivo, la cámara se acerca a %.1f yardas.",  -- 207
        "La cámara mantiene su distancia con un enemigo como objetivo.",  -- 208
        "uso: /ccam targetzoom <yardas> (0 u off: desactivado)",  -- 209
        "con un enemigo como objetivo, la cámara se acerca a esta distancia y luego vuelve (0: desactivado)",  -- 210
        "Más cerca con un enemigo como objetivo: %.1f yardas",  -- 211
        "Más cerca con un enemigo como objetivo: desactivado",  -- 212
        "Al fijar un enemigo, la cámara se acerca a esta distancia; al soltarlo vuelve a donde la tenías (no montado). Explora de lejos, lucha de cerca.",  -- 213
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
        "utiliser un profil maintenant, quelle que soit la situation",  -- 133
        "arrêter de forcer un profil",  -- 134
        "enregistrer vos réglages de caméra actuels comme nouveau profil",  -- 135
        "faire une copie modifiable d'un profil",  -- 136
        "modifier un réglage d'un profil personnalisé (/ccam settings les liste)",  -- 137
        "décalage par-dessus l'épaule selon la distance de la caméra, p. ex. /ccam curve mine 0:2 8:2 20:0",  -- 138
        "autoriser aussi la modification des profils intégrés (/ccam reset <profile> rétablit l'original)",  -- 139
        "remettre un profil intégré modifié à ses réglages d'origine",  -- 140
        "supprimer un profil personnalisé",  -- 141
        "afficher une chaîne à partager",  -- 142
        "ajouter un profil depuis une chaîne partagée",  -- 143
        "passer le décalage sur l'autre épaule",  -- 144
        "combien de temps une situation est conservée après sa fin (par défaut 1,5)",  -- 145
        "activer, ou désactiver et restaurer vos réglages de caméra d'origine",  -- 146
        "afficher maintenant le zoom, le décalage et les réglages de mouvement (pour le dépannage)",  -- 147
        "ouvrir le panneau d'options (Options > AddOns > ControllerCam)",  -- 148
        "afficher cette liste",  -- 149
        "'%s' correspond à plusieurs profils. Tapez davantage du nom.",  -- 150
        "Aucun profil nommé '%s'. /ccam list les affiche.",  -- 151
        "Profils de caméra pour jouer à la manette. Vous avez d'emblée une caméra Action ; Hybride et Classique sont à une commande.",  -- 152
        "Les profils intégrés sont verrouillés. Activez la modification avancée (/ccam advanced on) ou faites une copie : /ccam copy <profile>",  -- 153
        "Réglage inconnu. /ccam settings les liste.",  -- 154
        "Cette valeur est hors de la plage autorisée.",  -- 155
        "Cette valeur n'est pas valide.",  -- 156
        "utilisation : /ccam set <situation> <profile|none>",  -- 157
        "%s : aucun changement",  -- 158
        "'%s' est forcé. /ccam auto revient aux situations.",  -- 159
        "La caméra suit de nouveau vos situations.",  -- 160
        "utilisation : /ccam edit <profile> <setting> <value|default>",  -- 161
        "Utilisez /ccam curve pour le décalage selon le zoom.",  -- 162
        "utilisation : /ccam advanced [on|off]",  -- 163
        "La modification avancée est %s.",  -- 164
        "'%s' est revenu à ses réglages d'origine.",  -- 165
        "Rien à rétablir : '%s' n'a pas été modifié.",  -- 166
        "Les profils intégrés ne peuvent pas être supprimés.",  -- 167
        "Décalage par-dessus l'épaule inversé.",  -- 168
        "Décalage par-dessus l'épaule revenu à la normale.",  -- 169
        "Les situations sont conservées %.1f secondes après leur fin.",  -- 170
        "utilisation : /ccam delay <seconds>",  -- 171
        "le panneau d'options n'est pas disponible dans ce client",  -- 172
        "commande inconnue '%s'. Tapez /ccam help",  -- 173
        "Clic gauche : profil suivant. Clic droit : profil précédent. La première entrée, aucun changement, laisse la caméra telle quelle.",  -- 174
        "Clic gauche : profil suivant. Clic droit : profil précédent.",  -- 175
        "Appuyez sur Ctrl+C pour copier, puis sur Échap.",  -- 176
        "Collez ici une chaîne ControllerCam (Ctrl+V), puis appuyez sur Importer.",  -- 177
        "Profils de caméra pour jouer à la manette. Choisissez le ressenti de la caméra dans chaque situation. Clic gauche sur un profil pour passer au suivant, clic droit pour le précédent.",  -- 178
        "Active ou désactive le contrôle de la caméra. Une fois désactivé, vos réglages de caméra d'origine sont rétablis.",  -- 179
        "Caméra Action avec des profils plus calmes pour les villes, montures, le vol et les raids.",  -- 180
        "Empêche la caméra de basculer entre les profils lorsqu'une situation s'active et se désactive rapidement.",  -- 181
        "Change l'épaule par-dessus laquelle la caméra regarde.",  -- 182
        "Utiliser ce profil dans toutes les situations.",  -- 183
        "Crée une copie modifiable de ce profil.",  -- 184
        "Enregistre vos réglages de caméra actuels comme nouveau profil.",  -- 185
        "Affiche une chaîne à partager.",  -- 186
        "Ajoute un profil depuis une chaîne partagée.",  -- 187
        "Supprime ce profil personnalisé.",  -- 188
        "Remet ce profil intégré à ses réglages d'origine.",  -- 189
        "Permet de modifier aussi les profils intégrés. Vos modifications sont conservées et « Rétablir l'original » rétablit l'original.",  -- 190
        "Paires distance de zoom et décalage, par exemple 0:2 8:2 20:0. Vide = pas de courbe. Appuyez sur Entrée pour appliquer.",  -- 191
        "Utiliser la valeur par défaut du jeu pour ce réglage.",  -- 192
        "La modification avancée est activée. Les modifications d'un profil intégré sont conservées ; « Rétablir l'original » le restaure.",  -- 193
        "Les réglages non listés utilisent la valeur par défaut du jeu. Cliquez sur une valeur pour la modifier ; le champ de courbe accepte des paires zoom:décalage.",  -- 194
        "Les profils intégrés sont verrouillés. Faites une copie ou cochez Avancé pour les modifier.",  -- 195
        "À la pêche",  -- 196
        "En intérieur",  -- 197
        "Situation inconnue. Utilisez l'une de :",  -- 198
        "choisir le profil pour une situation (/ccam affiche la liste)",  -- 199
        "le décalage d'épaule dans votre forme actuelle (formes de druide, loup fantôme), en pourcentage de la normale",  -- 200
        "Vous n'êtes sous aucune forme.",  -- 201
        "Décalage d'épaule dans cette forme : %d%%",  -- 202
        "utilisation : /ccam formoffset <pourcentage> (ou reset)",  -- 203
        "Le jeu redemandera pour ses réglages de caméra expérimentaux à la prochaine connexion.",  -- 204
        "Le jeu ne demandera plus pour les réglages de caméra expérimentaux (vous les avez acceptés). /ccam notice fait revenir la question.",  -- 205
        "laisser le jeu redemander pour ses réglages de caméra expérimentaux à la prochaine connexion",  -- 206
        "Sur une cible ennemie, la caméra se rapproche à %.1f mètres.",  -- 207
        "La caméra garde sa distance sur une cible ennemie.",  -- 208
        "utilisation : /ccam targetzoom <mètres> (0 ou off : désactivé)",  -- 209
        "sur une cible ennemie, la caméra se rapproche à cette distance puis revient (0 : désactivé)",  -- 210
        "Plus près sur une cible ennemie : %.1f mètres",  -- 211
        "Plus près sur une cible ennemie : désactivé",  -- 212
        "Ciblez un ennemi et la caméra se rapproche à cette distance ; relâchez-le et elle revient où vous l'aviez (pas sur une monture). Explorez de loin, combattez de près.",  -- 213
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
        "usa un profilo adesso, qualunque sia la situazione",  -- 133
        "smetti di forzare un profilo",  -- 134
        "salva le impostazioni attuali della telecamera come nuovo profilo",  -- 135
        "crea una copia modificabile di un profilo",  -- 136
        "cambia un'impostazione di un profilo personalizzato (/ccam settings le elenca)",  -- 137
        "scostamento sopra la spalla in base alla distanza della telecamera, es. /ccam curve mine 0:2 8:2 20:0",  -- 138
        "consenti di modificare anche i profili integrati (/ccam reset <profile> ripristina l'originale)",  -- 139
        "riporta un profilo integrato modificato alle impostazioni originali",  -- 140
        "elimina un profilo personalizzato",  -- 141
        "mostra una stringa da condividere",  -- 142
        "aggiungi un profilo da una stringa condivisa",  -- 143
        "sposta lo scostamento sull'altra spalla",  -- 144
        "per quanto una situazione viene mantenuta dopo la fine (predefinito 1,5)",  -- 145
        "attiva, oppure disattiva e ripristina le impostazioni originali della telecamera",  -- 146
        "mostra ora zoom, scostamento e impostazioni di movimento (per la diagnosi)",  -- 147
        "apri il pannello delle opzioni (Opzioni > AddOn > ControllerCam)",  -- 148
        "mostra questo elenco",  -- 149
        "'%s' corrisponde a più profili. Scrivi più parte del nome.",  -- 150
        "Nessun profilo chiamato '%s'. /ccam list li mostra.",  -- 151
        "Profili della telecamera per giocare con il controller. Subito hai una telecamera Azione; Ibrido e Classico sono a un comando di distanza.",  -- 152
        "I profili integrati sono bloccati. Attiva la modifica avanzata (/ccam advanced on) o crea una copia: /ccam copy <profile>",  -- 153
        "Impostazione sconosciuta. /ccam settings le elenca.",  -- 154
        "Quel valore è fuori dall'intervallo consentito.",  -- 155
        "Quel valore non è valido.",  -- 156
        "uso: /ccam set <situation> <profile|none>",  -- 157
        "%s: nessuna modifica",  -- 158
        "'%s' forzato. /ccam auto torna alle situazioni.",  -- 159
        "La telecamera segue di nuovo le tue situazioni.",  -- 160
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 161
        "Usa /ccam curve per lo scostamento in base allo zoom.",  -- 162
        "uso: /ccam advanced [on|off]",  -- 163
        "La modifica avanzata è %s.",  -- 164
        "'%s' è tornato alle impostazioni originali.",  -- 165
        "Niente da ripristinare: '%s' non è stato modificato.",  -- 166
        "I profili integrati non possono essere eliminati.",  -- 167
        "Scostamento sopra la spalla specchiato.",  -- 168
        "Scostamento sopra la spalla tornato normale.",  -- 169
        "Le situazioni vengono mantenute per %.1f secondi dopo la fine.",  -- 170
        "uso: /ccam delay <seconds>",  -- 171
        "il pannello delle opzioni non è disponibile in questo client",  -- 172
        "comando sconosciuto '%s'. Digita /ccam help",  -- 173
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente. La prima voce, nessuna modifica, lascia la telecamera com'è.",  -- 174
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente.",  -- 175
        "Premi Ctrl+C per copiare, poi Esc.",  -- 176
        "Incolla qui una stringa ControllerCam (Ctrl+V), poi premi Importa.",  -- 177
        "Profili della telecamera per giocare con il controller. Scegli come si comporta la telecamera in ogni situazione. Clic sinistro su un profilo per il successivo, clic destro per il precedente.",  -- 178
        "Attiva o disattiva il controllo della telecamera. Quando è disattivato, le impostazioni originali della telecamera vengono ripristinate.",  -- 179
        "Telecamera Azione con profili più calmi per città, cavalcature, volo e raid.",  -- 180
        "Evita che la telecamera sfarfalli tra i profili quando una situazione si attiva e disattiva rapidamente.",  -- 181
        "Cambia la spalla sopra la quale guarda la telecamera.",  -- 182
        "Usa questo profilo in ogni situazione.",  -- 183
        "Crea una copia modificabile di questo profilo.",  -- 184
        "Salva le impostazioni attuali della telecamera come nuovo profilo.",  -- 185
        "Mostra una stringa da condividere.",  -- 186
        "Aggiunge un profilo da una stringa condivisa.",  -- 187
        "Elimina questo profilo personalizzato.",  -- 188
        "Riporta questo profilo integrato alle impostazioni originali.",  -- 189
        "Permette di modificare anche i profili integrati. Le modifiche vengono conservate e «Ripristina l'originale» riporta l'originale.",  -- 190
        "Coppie di distanza di zoom e scostamento, per esempio 0:2 8:2 20:0. Vuoto = nessuna curva. Premi Invio per applicare.",  -- 191
        "Usa il valore predefinito del gioco per questa impostazione.",  -- 192
        "La modifica avanzata è attiva. Le modifiche a un profilo integrato vengono conservate; «Ripristina l'originale» lo riporta com'era.",  -- 193
        "Le impostazioni non elencate usano il valore predefinito del gioco. Fai clic su un valore per cambiarlo; il campo della curva accetta coppie zoom:scostamento.",  -- 194
        "I profili integrati sono bloccati. Crea una copia o seleziona Avanzate per modificarli.",  -- 195
        "A pesca",  -- 196
        "Al chiuso",  -- 197
        "Situazione sconosciuta. Usa una di:",  -- 198
        "scegliere il profilo per una situazione (/ccam mostra l'elenco)",  -- 199
        "lo spostamento sulla spalla nella forma attuale (forme del druido, lupo spettrale), in percentuale del normale",  -- 200
        "Non sei in nessuna forma.",  -- 201
        "Spostamento sulla spalla in questa forma: %d%%",  -- 202
        "uso: /ccam formoffset <percentuale> (o reset)",  -- 203
        "Il gioco chiederà di nuovo delle sue impostazioni sperimentali della telecamera al prossimo accesso.",  -- 204
        "Il gioco non chiederà più delle impostazioni sperimentali della telecamera (le hai accettate). /ccam notice riporta la domanda.",  -- 205
        "far chiedere di nuovo al gioco delle sue impostazioni sperimentali della telecamera al prossimo accesso",  -- 206
        "Con un nemico come bersaglio, la telecamera si avvicina a %.1f iarde.",  -- 207
        "La telecamera mantiene la distanza con un nemico come bersaglio.",  -- 208
        "uso: /ccam targetzoom <iarde> (0 o off: disattivo)",  -- 209
        "con un nemico come bersaglio, la telecamera si avvicina a questa distanza e poi torna indietro (0: disattivo)",  -- 210
        "Più vicino con un nemico come bersaglio: %.1f iarde",  -- 211
        "Più vicino con un nemico come bersaglio: disattivo",  -- 212
        "Prendi di mira un nemico e la telecamera si avvicina a questa distanza; lascialo e torna dov'era (non in sella). Esplora da lontano, combatti da vicino.",  -- 213
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
        "상황과 관계없이 지금 프로필 사용",  -- 133
        "프로필 강제 사용 해제",  -- 134
        "현재 카메라 설정을 새 프로필로 저장",  -- 135
        "프로필의 편집 가능한 복사본 만들기",  -- 136
        "사용자 지정 프로필의 설정 변경 (/ccam settings 로 목록 확인)",  -- 137
        "카메라 거리에 따른 어깨 너머 오프셋, 예: /ccam curve mine 0:2 8:2 20:0",  -- 138
        "기본 제공 프로필도 편집 허용 (/ccam reset <profile> 로 원래대로 복원)",  -- 139
        "편집한 기본 제공 프로필을 원래 설정으로 되돌리기",  -- 140
        "사용자 지정 프로필 삭제",  -- 141
        "공유할 수 있는 문자열 표시",  -- 142
        "공유된 문자열에서 프로필 추가",  -- 143
        "어깨 오프셋을 반대쪽 어깨로 전환",  -- 144
        "상황이 끝난 뒤 유지되는 시간 (기본 1.5)",  -- 145
        "켜기, 또는 끄고 원래 카메라 설정 복원",  -- 146
        "현재 줌, 어깨 오프셋, 모션 설정 표시 (문제 해결용)",  -- 147
        "설정 창 열기 (설정 > 애드온 > ControllerCam)",  -- 148
        "이 목록 표시",  -- 149
        "'%s'은(는) 여러 프로필과 일치합니다. 이름을 더 입력하세요.",  -- 150
        "'%s'(이)라는 프로필이 없습니다. /ccam list 로 확인하세요.",  -- 151
        "컨트롤러 플레이를 위한 카메라 프로필. 설치하면 바로 액션 카메라를 쓰고, 하이브리드와 클래식은 명령어 한 번이면 됩니다.",  -- 152
        "기본 제공 프로필은 잠겨 있습니다. 고급 편집을 켜거나(/ccam advanced on) 복사본을 만드세요: /ccam copy <profile>",  -- 153
        "알 수 없는 설정입니다. /ccam settings 로 목록을 확인하세요.",  -- 154
        "그 값은 허용 범위를 벗어났습니다.",  -- 155
        "그 값이 올바르지 않습니다.",  -- 156
        "사용법: /ccam set <situation> <profile|none>",  -- 157
        "%s: 변경 없음",  -- 158
        "'%s'을(를) 강제 사용합니다. /ccam auto 로 상황별 설정으로 돌아갑니다.",  -- 159
        "카메라가 다시 상황에 따라 바뀝니다.",  -- 160
        "사용법: /ccam edit <profile> <setting> <value|default>",  -- 161
        "줌에 따른 오프셋은 /ccam curve 를 사용하세요.",  -- 162
        "사용법: /ccam advanced [on|off]",  -- 163
        "고급 편집: %s.",  -- 164
        "'%s'이(가) 원래 설정으로 돌아갔습니다.",  -- 165
        "되돌릴 내용 없음: '%s'은(는) 편집되지 않았습니다.",  -- 166
        "기본 제공 프로필은 삭제할 수 없습니다.",  -- 167
        "어깨 오프셋이 반전되었습니다.",  -- 168
        "어깨 오프셋이 원래대로 돌아왔습니다.",  -- 169
        "상황은 종료 후 %.1f초 동안 유지됩니다.",  -- 170
        "사용법: /ccam delay <seconds>",  -- 171
        "이 클라이언트에서는 설정 창을 사용할 수 없습니다",  -- 172
        "알 수 없는 명령어 '%s'. /ccam help 를 입력하세요",  -- 173
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필. 첫 항목인 변경 없음은 카메라를 그대로 둡니다.",  -- 174
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필.",  -- 175
        "Ctrl+C로 복사한 뒤 Esc를 누르세요.",  -- 176
        "여기에 ControllerCam 문자열을 붙여넣고(Ctrl+V) 가져오기를 누르세요.",  -- 177
        "컨트롤러 플레이를 위한 카메라 프로필. 각 상황에서 카메라가 어떤 느낌일지 고르세요. 프로필을 좌클릭하면 다음, 우클릭하면 이전 프로필로 바뀝니다.",  -- 178
        "카메라 제어를 켜거나 끕니다. 끄면 원래 카메라 설정이 복원됩니다.",  -- 179
        "도시, 탈것, 비행, 공격대에는 더 차분한 프로필을 쓰는 액션 카메라.",  -- 180
        "상황이 빠르게 켜지고 꺼질 때 카메라가 프로필 사이를 깜빡이며 오가는 것을 막습니다.",  -- 181
        "카메라가 넘겨다보는 어깨를 바꿉니다.",  -- 182
        "모든 상황에서 이 프로필을 사용합니다.",  -- 183
        "이 프로필의 편집 가능한 복사본을 만듭니다.",  -- 184
        "현재 카메라 설정을 새 프로필로 저장합니다.",  -- 185
        "공유할 수 있는 문자열을 표시합니다.",  -- 186
        "공유된 문자열에서 프로필을 추가합니다.",  -- 187
        "이 사용자 지정 프로필을 삭제합니다.",  -- 188
        "이 기본 제공 프로필을 원래 설정으로 되돌립니다.",  -- 189
        "기본 제공 프로필도 변경할 수 있게 합니다. 변경 사항은 유지되며 \"원래대로 되돌리기\"로 원본을 복원할 수 있습니다.",  -- 190
        "줌 거리와 오프셋 쌍, 예: 0:2 8:2 20:0. 비워 두면 곡선 없음. Enter를 눌러 적용하세요.",  -- 191
        "이 설정에 게임 기본값을 사용합니다.",  -- 192
        "고급 편집이 켜져 있습니다. 기본 제공 프로필의 변경 사항은 유지되며 \"원래대로 되돌리기\"로 복원할 수 있습니다.",  -- 193
        "나열되지 않은 설정은 게임 기본값을 사용합니다. 값을 클릭해 변경하세요. 곡선 입력란은 줌:오프셋 쌍을 받습니다.",  -- 194
        "기본 제공 프로필은 잠겨 있습니다. 복사본을 만들거나 고급을 체크해 편집하세요.",  -- 195
        "낚시 중",  -- 196
        "실내",  -- 197
        "알 수 없는 상황입니다. 다음 중 하나를 사용하세요:",  -- 198
        "한 상황에 사용할 프로필 선택 (/ccam 으로 목록 표시)",  -- 199
        "현재 변신 상태(드루이드 변신, 늑대 정령)의 어깨 시점 이동, 기본값 대비 퍼센트",  -- 200
        "변신 상태가 아닙니다.",  -- 201
        "이 변신 상태의 어깨 시점 이동: %d%%",  -- 202
        "사용법: /ccam formoffset <퍼센트> (또는 reset)",  -- 203
        "다음 접속 시 게임이 실험적 카메라 설정에 대해 다시 묻습니다.",  -- 204
        "게임이 더 이상 실험적 카메라 설정에 대해 묻지 않습니다 (수락했습니다). /ccam notice 로 질문을 다시 받을 수 있습니다.",  -- 205
        "다음 접속 시 게임이 실험적 카메라 설정에 대해 다시 묻게 합니다",  -- 206
        "적을 대상으로 잡으면 카메라가 %.1f야드까지 다가옵니다.",  -- 207
        "적을 대상으로 잡아도 카메라 거리가 그대로입니다.",  -- 208
        "사용법: /ccam targetzoom <야드> (0 또는 off: 끔)",  -- 209
        "적을 대상으로 잡으면 카메라가 이만큼 다가왔다가 다시 물러납니다 (0: 끔)",  -- 210
        "적 대상 시 가까이: %.1f야드",  -- 211
        "적 대상 시 가까이: 끔",  -- 212
        "적을 대상으로 잡으면 카메라가 이 거리까지 다가오고, 놓으면 원래 위치로 돌아갑니다 (탈것 탑승 중 제외). 멀리서 둘러보고, 가까이서 싸우세요.",  -- 213
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
        "usar um perfil agora, qualquer que seja a situação",  -- 133
        "parar de forçar um perfil",  -- 134
        "salvar suas configurações atuais de câmera como um novo perfil",  -- 135
        "fazer uma cópia editável de um perfil",  -- 136
        "alterar uma configuração de um perfil personalizado (/ccam settings lista todas)",  -- 137
        "deslocamento sobre o ombro por distância da câmera, ex.: /ccam curve mine 0:2 8:2 20:0",  -- 138
        "permitir editar também os perfis integrados (/ccam reset <profile> restaura o original)",  -- 139
        "devolver um perfil integrado editado às configurações originais",  -- 140
        "excluir um perfil personalizado",  -- 141
        "mostrar uma sequência que você pode compartilhar",  -- 142
        "adicionar um perfil a partir de uma sequência compartilhada",  -- 143
        "trocar o deslocamento para o outro ombro",  -- 144
        "por quanto tempo uma situação é mantida após o fim (padrão 1,5)",  -- 145
        "ligar, ou desligar e restaurar suas configurações originais de câmera",  -- 146
        "mostrar agora o zoom, o deslocamento e as configurações de movimento (para diagnóstico)",  -- 147
        "abrir o painel de opções (Opções > AddOns > ControllerCam)",  -- 148
        "mostrar esta lista",  -- 149
        "'%s' corresponde a mais de um perfil. Digite mais do nome.",  -- 150
        "Não há perfil chamado '%s'. /ccam list mostra todos.",  -- 151
        "Perfis de câmera para jogar com controle. Logo de início você tem uma câmera de Ação; Híbrido e Clássico estão a um comando.",  -- 152
        "Os perfis integrados estão bloqueados. Ative a edição avançada (/ccam advanced on) ou faça uma cópia: /ccam copy <profile>",  -- 153
        "Configuração desconhecida. /ccam settings lista todas.",  -- 154
        "Esse valor está fora do intervalo permitido.",  -- 155
        "Esse valor não é válido.",  -- 156
        "uso: /ccam set <situation> <profile|none>",  -- 157
        "%s: sem alteração",  -- 158
        "Forçando '%s'. /ccam auto volta às situações.",  -- 159
        "A câmera volta a seguir suas situações.",  -- 160
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 161
        "Use /ccam curve para o deslocamento por zoom.",  -- 162
        "uso: /ccam advanced [on|off]",  -- 163
        "A edição avançada está %s.",  -- 164
        "'%s' voltou às configurações originais.",  -- 165
        "Nada para restaurar: '%s' não foi editado.",  -- 166
        "Os perfis integrados não podem ser excluídos.",  -- 167
        "Deslocamento sobre o ombro espelhado.",  -- 168
        "Deslocamento sobre o ombro de volta ao normal.",  -- 169
        "As situações são mantidas por %.1f segundos após o fim.",  -- 170
        "uso: /ccam delay <seconds>",  -- 171
        "o painel de opções não está disponível neste cliente",  -- 172
        "comando desconhecido '%s'. Digite /ccam help",  -- 173
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior. A primeira entrada, sem alteração, deixa a câmera como está.",  -- 174
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior.",  -- 175
        "Pressione Ctrl+C para copiar e depois Esc.",  -- 176
        "Cole aqui uma sequência do ControllerCam (Ctrl+V) e pressione Importar.",  -- 177
        "Perfis de câmera para jogar com controle. Escolha como a câmera se comporta em cada situação. Clique esquerdo em um perfil vai para o próximo; clique direito, para o anterior.",  -- 178
        "Liga ou desliga o controle da câmera. Desligado, suas configurações originais de câmera são restauradas.",  -- 179
        "Câmera de Ação com perfis mais calmos para cidades, montarias, voo e raides.",  -- 180
        "Evita que a câmera fique alternando entre perfis quando uma situação liga e desliga rapidamente.",  -- 181
        "Troca o ombro sobre o qual a câmera olha.",  -- 182
        "Usa este perfil em todas as situações.",  -- 183
        "Cria uma cópia editável deste perfil.",  -- 184
        "Salva as configurações atuais de câmera como um novo perfil.",  -- 185
        "Mostra uma sequência que você pode compartilhar.",  -- 186
        "Adiciona um perfil a partir de uma sequência compartilhada.",  -- 187
        "Exclui este perfil personalizado.",  -- 188
        "Devolve este perfil integrado às configurações originais.",  -- 189
        "Permite alterar também os perfis integrados. Suas alterações são mantidas e «Restaurar o original» traz o original de volta.",  -- 190
        "Pares de distância de zoom e deslocamento, por exemplo 0:2 8:2 20:0. Vazio = sem curva. Pressione Enter para aplicar.",  -- 191
        "Usar o padrão do jogo para esta configuração.",  -- 192
        "A edição avançada está ativada. As alterações em um perfil integrado são mantidas; «Restaurar o original» o recupera.",  -- 193
        "As configurações não listadas usam o padrão do jogo. Clique em um valor para alterá-lo; a caixa de curva aceita pares zoom:deslocamento.",  -- 194
        "Os perfis integrados estão bloqueados. Faça uma cópia ou marque Avançado para editá-los.",  -- 195
        "Pescando",  -- 196
        "Em ambientes internos",  -- 197
        "Situação desconhecida. Use uma destas:",  -- 198
        "escolher o perfil para uma situação (/ccam mostra a lista)",  -- 199
        "o deslocamento de ombro na forma em que você está (formas de druida, lobo fantasma), em porcentagem do normal",  -- 200
        "Você não está em nenhuma forma.",  -- 201
        "Deslocamento de ombro nesta forma: %d%%",  -- 202
        "uso: /ccam formoffset <porcentagem> (ou reset)",  -- 203
        "O jogo perguntará novamente sobre suas configurações experimentais de câmera no próximo login.",  -- 204
        "O jogo não perguntará mais sobre as configurações experimentais de câmera (você as aceitou). /ccam notice traz a pergunta de volta.",  -- 205
        "fazer o jogo perguntar novamente sobre suas configurações experimentais de câmera no próximo login",  -- 206
        "Com um inimigo como alvo, a câmera se aproxima a %.1f jardas.",  -- 207
        "A câmera mantém a distância com um inimigo como alvo.",  -- 208
        "uso: /ccam targetzoom <jardas> (0 ou off: desligado)",  -- 209
        "com um inimigo como alvo, a câmera se aproxima a esta distância e depois volta (0: desligado)",  -- 210
        "Mais perto com um inimigo como alvo: %.1f jardas",  -- 211
        "Mais perto com um inimigo como alvo: desligado",  -- 212
        "Mire um inimigo e a câmera se aproxima a esta distância; solte-o e ela volta para onde estava (não montado). Explore de longe, lute de perto.",  -- 213
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
        "использовать профиль сейчас, независимо от ситуации",  -- 133
        "прекратить принудительное использование профиля",  -- 134
        "сохранить текущие настройки камеры как новый профиль",  -- 135
        "создать редактируемую копию профиля",  -- 136
        "изменить настройку пользовательского профиля (/ccam settings покажет список)",  -- 137
        "смещение за плечо в зависимости от дистанции камеры, например /ccam curve mine 0:2 8:2 20:0",  -- 138
        "разрешить изменять и встроенные профили (/ccam reset <profile> вернёт исходный)",  -- 139
        "вернуть изменённый встроенный профиль к исходным настройкам",  -- 140
        "удалить пользовательский профиль",  -- 141
        "показать строку для обмена",  -- 142
        "добавить профиль из полученной строки",  -- 143
        "переключить смещение на другое плечо",  -- 144
        "как долго ситуация сохраняется после окончания (по умолчанию 1,5)",  -- 145
        "включить, либо выключить и восстановить исходные настройки камеры",  -- 146
        "показать текущий масштаб, смещение и настройки движения (для диагностики)",  -- 147
        "открыть окно настроек (Настройки > Модификации > ControllerCam)",  -- 148
        "показать этот список",  -- 149
        "'%s' подходит к нескольким профилям. Введите больше букв названия.",  -- 150
        "Профиль «%s» не найден. /ccam list покажет все профили.",  -- 151
        "Профили камеры для игры с геймпадом. Сразу доступна камера «Экшен»; «Гибрид» и «Классика» включаются одной командой.",  -- 152
        "Встроенные профили заблокированы. Включите расширенное редактирование (/ccam advanced on) или сделайте копию: /ccam copy <profile>",  -- 153
        "Неизвестная настройка. /ccam settings покажет список.",  -- 154
        "Значение вне допустимого диапазона.",  -- 155
        "Недопустимое значение.",  -- 156
        "использование: /ccam set <situation> <profile|none>",  -- 157
        "%s: без изменений",  -- 158
        "Принудительно используется «%s». /ccam auto возвращает ситуации.",  -- 159
        "Камера снова следует вашим ситуациям.",  -- 160
        "использование: /ccam edit <profile> <setting> <value|default>",  -- 161
        "Для смещения по масштабу используйте /ccam curve.",  -- 162
        "использование: /ccam advanced [on|off]",  -- 163
        "Расширенное редактирование: %s.",  -- 164
        "«%s» возвращён к исходным настройкам.",  -- 165
        "Нечего возвращать: «%s» не изменялся.",  -- 166
        "Встроенные профили нельзя удалить.",  -- 167
        "Смещение за плечо отражено.",  -- 168
        "Смещение за плечо снова обычное.",  -- 169
        "Ситуации сохраняются %.1f с после окончания.",  -- 170
        "использование: /ccam delay <seconds>",  -- 171
        "окно настроек недоступно в этом клиенте",  -- 172
        "неизвестная команда «%s». Введите /ccam help",  -- 173
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль. Первый пункт, без изменений, оставляет камеру как есть.",  -- 174
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль.",  -- 175
        "Нажмите Ctrl+C, чтобы скопировать, затем Esc.",  -- 176
        "Вставьте сюда строку ControllerCam (Ctrl+V) и нажмите «Импорт».",  -- 177
        "Профили камеры для игры с геймпадом. Выберите, как должна ощущаться камера в каждой ситуации. ЛКМ по профилю — следующий, ПКМ — предыдущий.",  -- 178
        "Включает и выключает управление камерой. При выключении исходные настройки камеры восстанавливаются.",  -- 179
        "Камера «Экшен» со спокойными профилями для городов, езды верхом, полёта и рейдов.",  -- 180
        "Не даёт камере метаться между профилями, когда ситуация быстро включается и выключается.",  -- 181
        "Меняет плечо, через которое смотрит камера.",  -- 182
        "Использовать этот профиль во всех ситуациях.",  -- 183
        "Создаёт редактируемую копию этого профиля.",  -- 184
        "Сохраняет текущие настройки камеры как новый профиль.",  -- 185
        "Показывает строку, которой можно поделиться.",  -- 186
        "Добавляет профиль из полученной строки.",  -- 187
        "Удаляет этот пользовательский профиль.",  -- 188
        "Возвращает этот встроенный профиль к исходным настройкам.",  -- 189
        "Позволяет изменять и встроенные профили. Ваши изменения сохраняются, а «Вернуть исходный» восстанавливает оригинал.",  -- 190
        "Пары «дистанция масштаба : смещение», например 0:2 8:2 20:0. Пусто — без кривой. Нажмите Enter, чтобы применить.",  -- 191
        "Использовать значение игры по умолчанию для этой настройки.",  -- 192
        "Расширенное редактирование включено. Изменения встроенного профиля сохраняются; «Вернуть исходный» восстанавливает оригинал.",  -- 193
        "Не указанные настройки используют значения игры по умолчанию. Щёлкните значение, чтобы изменить его; в поле кривой вводятся пары «масштаб:смещение».",  -- 194
        "Встроенные профили заблокированы. Сделайте копию или отметьте «Дополнительно», чтобы изменять их.",  -- 195
        "Рыбалка",  -- 196
        "В помещении",  -- 197
        "Неизвестная ситуация. Используйте одну из:",  -- 198
        "выбрать профиль для одной ситуации (/ccam показывает список)",  -- 199
        "смещение камеры к плечу в текущем облике (облики друида, призрачный волк), в процентах от обычного",  -- 200
        "Вы не в облике.",  -- 201
        "Смещение к плечу в этом облике: %d%%",  -- 202
        "использование: /ccam formoffset <процент> (или reset)",  -- 203
        "При следующем входе игра снова спросит об экспериментальных настройках камеры.",  -- 204
        "Игра больше не будет спрашивать об экспериментальных настройках камеры (вы их приняли). /ccam notice возвращает вопрос.",  -- 205
        "игра снова спросит об экспериментальных настройках камеры при следующем входе",  -- 206
        "При враждебной цели камера приближается до %.1f ярдов.",  -- 207
        "При враждебной цели камера сохраняет расстояние.",  -- 208
        "использование: /ccam targetzoom <ярды> (0 или off: выкл.)",  -- 209
        "при враждебной цели камера приближается на это расстояние, а потом отходит обратно (0: выкл.)",  -- 210
        "Ближе при враждебной цели: %.1f ярда",  -- 211
        "Ближе при враждебной цели: выкл.",  -- 212
        "Возьмите врага в цель — камера приблизится на это расстояние; отпустите — вернётся туда, где была (не верхом). Исследуйте издалека, сражайтесь вблизи.",  -- 213
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
        "立即使用某个配置，不论情境",  -- 133
        "停止强制使用配置",  -- 134
        "将当前镜头设置保存为新配置",  -- 135
        "创建配置的可编辑副本",  -- 136
        "更改自定义配置的某项设置（/ccam settings 列出所有设置）",  -- 137
        "按镜头距离设置越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 138
        "同时允许编辑内置配置（/ccam reset <profile> 可恢复原始设置）",  -- 139
        "将已编辑的内置配置恢复为原始设置",  -- 140
        "删除自定义配置",  -- 141
        "显示可分享的字符串",  -- 142
        "从分享的字符串添加配置",  -- 143
        "将越肩偏移切换到另一侧肩膀",  -- 144
        "情境结束后保持多久（默认 1.5）",  -- 145
        "开启，或关闭并还原原来的镜头设置",  -- 146
        "显示当前缩放、越肩偏移和动态设置（用于排查问题）",  -- 147
        "打开选项面板（选项 > 插件 > ControllerCam）",  -- 148
        "显示此列表",  -- 149
        "“%s”匹配多个配置。请输入更多名称。",  -- 150
        "没有名为“%s”的配置。/ccam list 可查看所有配置。",  -- 151
        "手柄玩家的镜头配置。开箱即用动作镜头；混合和经典只需一条命令。",  -- 152
        "内置配置已锁定。请开启高级编辑（/ccam advanced on）或创建副本：/ccam copy <profile>",  -- 153
        "未知设置。/ccam settings 可列出所有设置。",  -- 154
        "该数值超出允许范围。",  -- 155
        "该数值无效。",  -- 156
        "用法：/ccam set <situation> <profile|none>",  -- 157
        "%s：不更改",  -- 158
        "正在强制使用“%s”。/ccam auto 可返回按情境切换。",  -- 159
        "镜头恢复按情境切换。",  -- 160
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 161
        "按缩放的偏移请使用 /ccam curve。",  -- 162
        "用法：/ccam advanced [on|off]",  -- 163
        "高级编辑：%s。",  -- 164
        "“%s”已恢复为原始设置。",  -- 165
        "无需还原：“%s”尚未被编辑。",  -- 166
        "内置配置无法删除。",  -- 167
        "越肩偏移已镜像。",  -- 168
        "越肩偏移已恢复正常。",  -- 169
        "情境结束后会保持 %.1f 秒。",  -- 170
        "用法：/ccam delay <seconds>",  -- 171
        "此客户端不支持选项面板",  -- 172
        "未知命令“%s”。请输入 /ccam help",  -- 173
        "左键：下一个配置。右键：上一个配置。第一项“不更改”会保持镜头不变。",  -- 174
        "左键：下一个配置。右键：上一个配置。",  -- 175
        "按 Ctrl+C 复制，然后按 Esc。",  -- 176
        "在此粘贴 ControllerCam 字符串（Ctrl+V），然后点击导入。",  -- 177
        "手柄玩家的镜头配置。为每种情境选择镜头的手感。左键点击配置切换到下一个，右键切换到上一个。",  -- 178
        "开启或关闭镜头控制。关闭后会还原你原来的镜头设置。",  -- 179
        "动作镜头，城市、骑乘、飞行和团队副本使用更平稳的配置。",  -- 180
        "防止情境快速开关时镜头在配置之间来回闪烁。",  -- 181
        "切换镜头越过的肩膀。",  -- 182
        "在所有情境中使用此配置。",  -- 183
        "创建此配置的可编辑副本。",  -- 184
        "将当前镜头设置保存为新配置。",  -- 185
        "显示可分享的字符串。",  -- 186
        "从分享的字符串添加配置。",  -- 187
        "删除此自定义配置。",  -- 188
        "将此内置配置恢复为原始设置。",  -- 189
        "允许同时修改内置配置。你的更改会被保留，“恢复原始设置”可还原原始版本。",  -- 190
        "缩放距离与偏移的数值对，例如 0:2 8:2 20:0。留空表示无曲线。按 Enter 应用。",  -- 191
        "此设置使用游戏默认值。",  -- 192
        "高级编辑已开启。对内置配置的更改会被保留；“恢复原始设置”可还原。",  -- 193
        "未列出的设置使用游戏默认值。点击数值即可更改；曲线输入框接受“缩放:偏移”数值对。",  -- 194
        "内置配置已锁定。请创建副本，或勾选“高级”来编辑它们。",  -- 195
        "钓鱼中",  -- 196
        "室内",  -- 197
        "未知的情境。请使用以下之一：",  -- 198
        "为一种情境选择配置（/ccam 显示列表）",  -- 199
        "当前形态下的越肩偏移（德鲁伊形态、幽魂之狼），为正常值的百分比",  -- 200
        "你当前不在任何形态中。",  -- 201
        "此形态下的越肩偏移：%d%%",  -- 202
        "用法：/ccam formoffset <百分比>（或 reset）",  -- 203
        "下次登录时，游戏会再次询问其实验性镜头设置。",  -- 204
        "游戏不会再询问实验性镜头设置（你已接受）。/ccam notice 可恢复询问。",  -- 205
        "下次登录时让游戏再次询问其实验性镜头设置",  -- 206
        "选中敌人时，镜头拉近到 %.1f 码。",  -- 207
        "选中敌人时镜头保持距离。",  -- 208
        "用法：/ccam targetzoom <码>（0 或 off：关闭）",  -- 209
        "选中敌人时镜头拉近到这个距离，之后再拉回（0：关闭）",  -- 210
        "选中敌人时拉近：%.1f 码",  -- 211
        "选中敌人时拉近：关闭",  -- 212
        "选中敌人时镜头拉近到这个距离；放开后回到原来的位置（骑乘时除外）。远处漫游，近身战斗。",  -- 213
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
        "立即使用某個設定檔，不論情境",  -- 133
        "停止強制使用設定檔",  -- 134
        "將目前鏡頭設定儲存為新設定檔",  -- 135
        "建立設定檔的可編輯副本",  -- 136
        "更改自訂設定檔的某項設定（/ccam settings 列出所有設定）",  -- 137
        "依鏡頭距離設定越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 138
        "同時允許編輯內建設定檔（/ccam reset <profile> 可還原為原始設定）",  -- 139
        "將已編輯的內建設定檔還原為原始設定",  -- 140
        "刪除自訂設定檔",  -- 141
        "顯示可分享的字串",  -- 142
        "從分享的字串新增設定檔",  -- 143
        "將越肩偏移切換到另一側肩膀",  -- 144
        "情境結束後保持多久（預設 1.5）",  -- 145
        "開啟，或關閉並還原原本的鏡頭設定",  -- 146
        "顯示目前縮放、越肩偏移和動態設定（用於排查問題）",  -- 147
        "開啟選項面板（選項 > 插件 > ControllerCam）",  -- 148
        "顯示此列表",  -- 149
        "「%s」符合多個設定檔。請輸入更多名稱。",  -- 150
        "沒有名為「%s」的設定檔。/ccam list 可查看所有設定檔。",  -- 151
        "手把玩家的鏡頭設定檔。開箱即用動作鏡頭；混合和經典只需一條指令。",  -- 152
        "內建設定檔已鎖定。請開啟進階編輯（/ccam advanced on）或建立副本：/ccam copy <profile>",  -- 153
        "未知設定。/ccam settings 可列出所有設定。",  -- 154
        "該數值超出允許範圍。",  -- 155
        "該數值無效。",  -- 156
        "用法：/ccam set <situation> <profile|none>",  -- 157
        "%s：不變更",  -- 158
        "正在強制使用「%s」。/ccam auto 可返回依情境切換。",  -- 159
        "鏡頭恢復依情境切換。",  -- 160
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 161
        "依縮放的偏移請使用 /ccam curve。",  -- 162
        "用法：/ccam advanced [on|off]",  -- 163
        "進階編輯：%s。",  -- 164
        "「%s」已還原為原始設定。",  -- 165
        "無需還原：「%s」尚未被編輯。",  -- 166
        "內建設定檔無法刪除。",  -- 167
        "越肩偏移已鏡像。",  -- 168
        "越肩偏移已恢復正常。",  -- 169
        "情境結束後會保持 %.1f 秒。",  -- 170
        "用法：/ccam delay <seconds>",  -- 171
        "此用戶端不支援選項面板",  -- 172
        "未知指令「%s」。請輸入 /ccam help",  -- 173
        "左鍵：下一個設定檔。右鍵：上一個設定檔。第一項「不變更」會保持鏡頭不變。",  -- 174
        "左鍵：下一個設定檔。右鍵：上一個設定檔。",  -- 175
        "按 Ctrl+C 複製，然後按 Esc。",  -- 176
        "在此貼上 ControllerCam 字串（Ctrl+V），然後點擊匯入。",  -- 177
        "手把玩家的鏡頭設定檔。為每種情境選擇鏡頭的手感。左鍵點擊設定檔切換到下一個，右鍵切換到上一個。",  -- 178
        "開啟或關閉鏡頭控制。關閉後會還原你原本的鏡頭設定。",  -- 179
        "動作鏡頭，城市、騎乘、飛行和團隊副本使用更平穩的設定檔。",  -- 180
        "防止情境快速開關時鏡頭在設定檔之間來回閃爍。",  -- 181
        "切換鏡頭越過的肩膀。",  -- 182
        "在所有情境中使用此設定檔。",  -- 183
        "建立此設定檔的可編輯副本。",  -- 184
        "將目前鏡頭設定儲存為新設定檔。",  -- 185
        "顯示可分享的字串。",  -- 186
        "從分享的字串新增設定檔。",  -- 187
        "刪除此自訂設定檔。",  -- 188
        "將此內建設定檔還原為原始設定。",  -- 189
        "允許同時修改內建設定檔。你的變更會被保留，「還原為原始設定」可還原原始版本。",  -- 190
        "縮放距離與偏移的數值對，例如 0:2 8:2 20:0。留空表示無曲線。按 Enter 套用。",  -- 191
        "此設定使用遊戲預設值。",  -- 192
        "進階編輯已開啟。對內建設定檔的變更會被保留；「還原為原始設定」可還原。",  -- 193
        "未列出的設定使用遊戲預設值。點擊數值即可變更；曲線輸入框接受「縮放:偏移」數值對。",  -- 194
        "內建設定檔已鎖定。請建立副本，或勾選「進階」來編輯它們。",  -- 195
        "釣魚中",  -- 196
        "室內",  -- 197
        "未知的情境。請使用以下之一：",  -- 198
        "為一種情境選擇設定檔（/ccam 顯示列表）",  -- 199
        "目前形態下的越肩偏移（德魯伊形態、鬼魂之狼），為正常值的百分比",  -- 200
        "你目前不在任何形態中。",  -- 201
        "此形態下的越肩偏移：%d%%",  -- 202
        "用法：/ccam formoffset <百分比>（或 reset）",  -- 203
        "下次登入時，遊戲會再次詢問其實驗性鏡頭設定。",  -- 204
        "遊戲不會再詢問實驗性鏡頭設定（你已接受）。/ccam notice 可恢復詢問。",  -- 205
        "下次登入時讓遊戲再次詢問其實驗性鏡頭設定",  -- 206
        "選中敵人時，鏡頭拉近到 %.1f 碼。",  -- 207
        "選中敵人時鏡頭保持距離。",  -- 208
        "用法：/ccam targetzoom <碼>（0 或 off：關閉）",  -- 209
        "選中敵人時鏡頭拉近到這個距離，之後再拉回（0：關閉）",  -- 210
        "選中敵人時拉近：%.1f 碼",  -- 211
        "選中敵人時拉近：關閉",  -- 212
        "選中敵人時鏡頭拉近到這個距離；放開後回到原來的位置（騎乘時除外）。遠處漫遊，近身戰鬥。",  -- 213
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
