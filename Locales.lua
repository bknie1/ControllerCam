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
    "Recommended setup",  -- 64
    "(no change)",  -- 65
    "Use everywhere",  -- 66
    "Make a copy",  -- 67
    "Save my current camera",  -- 68
    "Export",  -- 69
    "Import",  -- 70
    "Close",  -- 71
    "Delete",  -- 72
    "game default",  -- 73
    "Default",  -- 74
    "My profile",  -- 75
    "copy",  -- 76
    "forced",  -- 77
    "custom",  -- 78
    "no change",  -- 79
    "current",  -- 80
    "nothing applied yet",  -- 81
    "Now: %s (%s)",  -- 82
    "Now: nothing applied yet",  -- 83
    "Mirror the shoulder offset (other shoulder)",  -- 84
    "Keep a situation for %.1f s after it ends",  -- 85
    "Slash commands: /ccam help",  -- 86
    "Profile for each situation (the first one that applies wins, from the top):",  -- 87
    "Done.",  -- 88
    "Using '%s' everywhere.",  -- 89
    "Recommended setup applied.",  -- 90
    "Saved as '%s'.",  -- 91
    "Deleted '%s'.",  -- 92
    "enabled",  -- 93
    "disabled. Your original camera settings were restored.",  -- 94
    "Imported '%s'. /ccam use \"%s\" to try it.",  -- 95
    "That is not a ControllerCam profile string.",  -- 96
    "Nothing to import.",  -- 97
    "The string is too long to be a profile.",  -- 98
    "This profile was made with a newer version of ControllerCam. Please update the addon.",  -- 99
    "The string is damaged (checksum mismatch). Copy it again, completely.",  -- 100
    "The profile has no valid name.",  -- 101
    "Cannot import: %s (%s).",  -- 102
    "a value is outside its allowed range",  -- 103
    "a value is not valid",  -- 104
    "a curve is not valid",  -- 105
    "it contains a setting this version does not know",  -- 106
    "Installed. The Action camera is on. Try /ccam use hybrid or /ccam use classic, /ccam help lists everything.",  -- 107
    "%s is also loaded. Both change the camera and will fight each other. Disable one of them.",  -- 108
    "Camera follows terrain",  -- 109
    "your setting",  -- 110
    "Reset to original",  -- 111
    "(edited)",  -- 112
    "Everything not listed uses the game default.",  -- 113
    "Between Classic and Action: a medium distance, a light over-the-shoulder offset and gentle head tracking. The camera follows your movement, but you still get a wide view.",  -- 114
    "The game's own camera: every setting ControllerCam manages goes back to its default. Your camera distance and your terrain-following setting are left as they are.",  -- 115
    "A third-person shooter feel: tight camera, a strong shoulder offset, fast stick aim. You run facing your movement outside combat and strafe facing the camera in combat.",  -- 116
    "Even closer and steadier, for cover-shooter play: your character always turns with the camera, the shoulder offset is large and the camera does not drift on its own.",  -- 117
    "Slow, wide and moody, for questing and screenshots: dynamic pitch, strong head tracking and a camera that turns toward whoever you talk to.",  -- 118
    "The camera leans toward your current target and the NPCs you talk to. Good for single-target fights.",  -- 119
    "A far, steady camera for dungeons and raids: no offset, no head tracking, no camera drift and fast stick turning so you can see the whole fight.",  -- 120
    "For riding: a far camera that swings behind you as you steer. The offset is off, because mounts of different sizes make it unreliable.",  -- 121
    "For flying: a far camera that follows your climb and dive.",  -- 122
    "A relaxed, slower camera for cities: closer, calm and with head tracking.",  -- 123
    "Custom profile. Duplicate or edit it in the profile editor.",  -- 124
    "show status",  -- 125
    "list the profiles",  -- 126
    "what a profile feels like and every setting it changes",  -- 127
    "the recommended setup: Action camera with calmer profiles for cities, mounts, flying, raids",  -- 128
    "use a profile now, whatever the situation",  -- 129
    "stop forcing a profile",  -- 130
    "save your current camera settings as a new profile",  -- 131
    "make an editable copy of a profile",  -- 132
    "change a setting of a custom profile (/ccam settings lists them)",  -- 133
    "shoulder offset by camera distance, e.g. /ccam curve mine 0:2 8:2 20:0",  -- 134
    "allow editing the built-in profiles too (/ccam reset <profile> brings the original back)",  -- 135
    "put an edited built-in profile back to its original settings",  -- 136
    "delete a custom profile",  -- 137
    "show a string you can share",  -- 138
    "add a profile from a shared string",  -- 139
    "switch the shoulder offset to the other shoulder",  -- 140
    "how long a situation is kept after it ends (default 1.5)",  -- 141
    "turn on, or turn off and restore your original camera settings",  -- 142
    "show the zoom, shoulder offset and motion settings right now (for troubleshooting)",  -- 143
    "open the options panel (Options > AddOns > ControllerCam)",  -- 144
    "show this list",  -- 145
    "'%s' matches more than one profile. Type more of the name.",  -- 146
    "No profile called '%s'. /ccam list shows them.",  -- 147
    "Camera profiles for controller play. Out of the box you get an Action camera; Hybrid and Classic are one command away.",  -- 148
    "Built-in profiles are locked. Turn on advanced editing (/ccam advanced on) or make a copy: /ccam copy <profile>",  -- 149
    "Unknown setting. /ccam settings lists them.",  -- 150
    "That value is outside the allowed range.",  -- 151
    "That value is not valid.",  -- 152
    "usage: /ccam set <situation> <profile|none>",  -- 153
    "%s: no change",  -- 154
    "Forcing '%s'. /ccam auto goes back to the situations.",  -- 155
    "The camera follows your situations again.",  -- 156
    "usage: /ccam edit <profile> <setting> <value|default>",  -- 157
    "Use /ccam curve for the offset by zoom.",  -- 158
    "usage: /ccam advanced [on|off]",  -- 159
    "Advanced editing is %s.",  -- 160
    "'%s' is back to its original settings.",  -- 161
    "Nothing to reset: '%s' has not been edited.",  -- 162
    "Built-in profiles cannot be deleted.",  -- 163
    "Shoulder offset mirrored.",  -- 164
    "Shoulder offset back to normal.",  -- 165
    "Situations are kept for %.1f seconds after they end.",  -- 166
    "usage: /ccam delay <seconds>",  -- 167
    "options panel is not available in this client",  -- 168
    "unknown command '%s'. Type /ccam help",  -- 169
    "Left-click: next profile. Right-click: previous profile. The first entry, no change, leaves the camera alone.",  -- 170
    "Left-click: next profile. Right-click: previous profile.",  -- 171
    "Press Ctrl+C to copy, then Esc.",  -- 172
    "Paste a ControllerCam string here (Ctrl+V), then press Import.",  -- 173
    "Camera profiles for controller play. Pick what the camera feels like in each situation. Left-click a profile to go to the next one, right-click for the previous one.",  -- 174
    "Turn the camera control on or off. When off, your original camera settings are put back.",  -- 175
    "Action camera with calmer profiles for cities, mounts, flying and raids.",  -- 176
    "Stops the camera from flickering between profiles when a situation switches on and off quickly.",  -- 177
    "Swaps which shoulder the camera looks over.",  -- 178
    "Use this profile in every situation.",  -- 179
    "Makes an editable copy of this profile.",  -- 180
    "Saves the camera settings you have right now as a new profile.",  -- 181
    "Shows a string you can share.",  -- 182
    "Add a profile from a shared string.",  -- 183
    "Deletes this custom profile.",  -- 184
    "Puts this built-in profile back to its original settings.",  -- 185
    "Use the game's default for this setting.",  -- 186
    "Advanced editing is on. Changes to a built-in profile are kept; Reset to original brings it back.",  -- 187
    "Fishing",  -- 188
    "Indoors",  -- 189
    "Unknown situation. Use one of:",  -- 190
    "choose the profile for one situation (/ccam shows the list)",  -- 191
    "the shoulder offset in the form you are in (druid forms, ghost wolf), in percent of normal",  -- 192
    "You are not in a form.",  -- 193
    "Shoulder offset in this form: %d%%",  -- 194
    "usage: /ccam formoffset <percent> (or reset)",  -- 195
    "The game will ask about its experimental camera settings again at the next login.",  -- 196
    "The game will not ask about the experimental camera settings again (you accepted them). /ccam notice brings the question back.",  -- 197
    "let the game ask about its experimental camera settings again at the next login",  -- 198
    "On an enemy target the camera comes in to %.1f yards.",  -- 199
    "The camera keeps its distance on an enemy target.",  -- 200
    "usage: /ccam targetzoom <yards> (0 or off: off)",  -- 201
    "on an enemy target the camera comes in this close, and goes back out after (0: off)",  -- 202
    "Closer on an enemy target: %.1f yards",  -- 203
    "Closer on an enemy target: off",  -- 204
    "Target an enemy and the camera comes in to this distance; let it go and it goes back to where you had it (not while mounted). Roam far out, fight up close.",  -- 205
    "ControllerCam: how you move",  -- 206
    "The camera profiles can also set how your character faces and turns as you move, and how fast the stick turns the camera. Let them, or keep your own settings?",  -- 207
    "The profiles now set how you move and the stick's speeds (/ccam movement to change it).",  -- 208
    "Your own movement and stick settings are kept (/ccam movement to change it).",  -- 209
    "Let the profiles set them",  -- 210
    "Keep mine",  -- 211
    "Profiles also set how you move and the stick's speeds",  -- 212
    "Facing and turning as you move, and the stick's camera speeds, set by each profile. Off: your own settings, as you had them.",  -- 213
    "Field of view by zoom",  -- 214
    "Target focus by zoom",  -- 215
    "The out-of-the-box feel: over your shoulder up close, easing to the middle as you zoom out, turning toward your target most when you are near. Head tracking, and the camera follows where you run.",  -- 216
    "use one profile everywhere (try: recommended, action, classic)",  -- 217
    "the strength of the shoulder offset in every profile, in percent of normal",  -- 218
    "usage: /ccam offset <percent> (0 to 200)",  -- 219
    "Shoulder offset strength: %d%%",  -- 220
    "Quick pick:",  -- 221
    "Moves the over-the-shoulder camera further out or back toward the middle, in every profile. Handy if your character's size makes it sit differently.",  -- 222
    "Advanced: show and edit every setting",  -- 223
    "Shows every setting, in groups, and lets you change the built-in profiles too. Your changes are kept, and Reset to original brings the original back.",  -- 224
    "Change the offset with zoom",  -- 225
    "How far to the side at each distance. The camera eases from one to the next.",  -- 226
    "Change the target focus with zoom",  -- 227
    "How much of your target focus strength at each distance. Off: all of it everywhere.",  -- 228
    "Change the field of view with zoom",  -- 229
    "The field of view at each distance, as a share of your own. Off: yours is left alone.",  -- 230
    "%s (%s to %s yards)",  -- 231
    "You are at %.1f yards now: %s.",  -- 232
    "Distance and value pairs, for example 0:2 8:2 20:0. Empty: not by zoom. Press Enter to apply.",  -- 233
    "by zoom",  -- 234
    "This game has no field of view setting that add-ons can change.",  -- 235
    "Settings not listed use the game default. Pick a group below to see its settings.",  -- 236
    "The presets are all most people need. To change one, make a copy, or tick Advanced to see every setting.",  -- 237
    "Only used once you let the profiles set how you move (ControllerCam's first page).",  -- 238
    "How far away the camera sits when this profile takes over.",  -- 239
    "How far out you can pull the camera. Higher is farther.",  -- 240
    "Exact points behind the table above, as distance:share. 1 is your own.",  -- 241
    "How fast the right stick turns the camera.",  -- 242
    "How fast the right stick looks up and down.",  -- 243
    "The camera swings round behind you as you run.",  -- 244
    "How quickly the camera swings round behind you.",  -- 245
    "How quickly the camera levels out again.",  -- 246
    "How long the camera waits after you move it yourself.",  -- 247
    "0: your character faces wherever it runs. 180: it keeps facing forward and strafes.",  -- 248
    "The same choice, while you are in a fight.",  -- 249
    "When your character turns as you turn the camera.",  -- 250
    "Your mount turns to face the way you push the stick.",  -- 251
    "While swimming, your character turns to face the way you push the stick.",  -- 252
    "While flying, you turn to face the way you push the stick.",  -- 253
    "One offset at every distance. 0 keeps your character in the middle.",  -- 254
    "Exact points behind the table above, as distance:offset.",  -- 255
    "Tilts the view as you zoom, for a lower, cinematic angle.",  -- 256
    "How much the camera moves with your character's head. 0 is off.",  -- 257
    "How much of that movement while you stand still.",  -- 258
    "How much of that movement while you run.",  -- 259
    "How far out the camera can be and still move with your character's head.",  -- 260
    "The camera turns toward the enemy you have targeted.",  -- 261
    "How hard it turns left and right. 1 is the strongest.",  -- 262
    "How hard it tilts up and down. 1 is the strongest.",  -- 263
    "Exact points behind the table above, as distance:share. 1 is full strength.",  -- 264
    "The camera turns toward the person you are talking to.",  -- 265
    "How hard it turns left and right toward them.",  -- 266
    "How hard it tilts up and down toward them.",  -- 267
    "With mouse and keyboard: when the camera swings back behind you.",  -- 268
    "Tilts the camera with hills and slopes. Yours is kept unless set here.",  -- 269
    "How far away the camera sits, and how far out you can pull it.",  -- 270
    "How far to the side the camera sits, so your character is not in the middle of the screen.",  -- 271
    "How much the camera turns to look at your target, or at the person you talk to.",  -- 272
    "How much the camera moves along with your character's head.",  -- 273
    "Small movements the camera makes on its own.",  -- 274
    "How fast the stick moves the camera, and whether the camera follows where you run.",  -- 275
    "Which way your character faces as you move.",  -- 276
    "First person",  -- 277
    "Over the shoulder",  -- 278
    "Upper body",  -- 279
    "Whole body",  -- 280
    "Mid range",  -- 281
    "Zoomed out",  -- 282
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
        "Empfohlene Einrichtung",  -- 64
        "(keine Änderung)",  -- 65
        "Überall verwenden",  -- 66
        "Kopie erstellen",  -- 67
        "Meine aktuelle Kamera speichern",  -- 68
        "Exportieren",  -- 69
        "Importieren",  -- 70
        "Schließen",  -- 71
        "Löschen",  -- 72
        "Spielstandard",  -- 73
        "Standard",  -- 74
        "Mein Profil",  -- 75
        "Kopie",  -- 76
        "erzwungen",  -- 77
        "eigenes",  -- 78
        "keine Änderung",  -- 79
        "aktuell",  -- 80
        "noch nichts angewendet",  -- 81
        "Jetzt: %s (%s)",  -- 82
        "Jetzt: noch nichts angewendet",  -- 83
        "Schulterversatz spiegeln (andere Schulter)",  -- 84
        "Situation nach Ende noch %.1f s halten",  -- 85
        "Chat-Befehle: /ccam help",  -- 86
        "Profil für jede Situation (die erste zutreffende von oben gewinnt):",  -- 87
        "Erledigt.",  -- 88
        "'%s' wird überall verwendet.",  -- 89
        "Empfohlene Einrichtung angewendet.",  -- 90
        "Gespeichert als '%s'.",  -- 91
        "'%s' gelöscht.",  -- 92
        "aktiviert",  -- 93
        "deaktiviert. Deine ursprünglichen Kameraeinstellungen wurden wiederhergestellt.",  -- 94
        "'%s' importiert. Mit /ccam use \"%s\" ausprobieren.",  -- 95
        "Das ist keine ControllerCam-Profilzeichenfolge.",  -- 96
        "Nichts zu importieren.",  -- 97
        "Die Zeichenfolge ist zu lang für ein Profil.",  -- 98
        "Dieses Profil stammt von einer neueren ControllerCam-Version. Bitte aktualisiere das Addon.",  -- 99
        "Die Zeichenfolge ist beschädigt (Prüfsumme stimmt nicht). Kopiere sie erneut, vollständig.",  -- 100
        "Das Profil hat keinen gültigen Namen.",  -- 101
        "Import nicht möglich: %s (%s).",  -- 102
        "ein Wert liegt außerhalb des erlaubten Bereichs",  -- 103
        "ein Wert ist ungültig",  -- 104
        "eine Kurve ist ungültig",  -- 105
        "sie enthält eine Einstellung, die diese Version nicht kennt",  -- 106
        "Installiert. Die Action-Kamera ist aktiv. Probiere /ccam use hybrid oder /ccam use classic, /ccam help zeigt alles.",  -- 107
        "%s ist ebenfalls geladen. Beide ändern die Kamera und stören sich gegenseitig. Deaktiviere eines davon.",  -- 108
        "Kamera folgt dem Gelände",  -- 109
        "deine Einstellung",  -- 110
        "Auf Original zurücksetzen",  -- 111
        "(bearbeitet)",  -- 112
        "Alles, was nicht aufgeführt ist, verwendet den Spielstandard.",  -- 113
        "Zwischen Klassisch und Action: mittlerer Abstand, leichter Schulterversatz und sanfte Kopfbewegung. Die Kamera folgt deiner Bewegung, du behältst aber einen weiten Blick.",  -- 114
        "Die Kamera des Spiels: Jede von ControllerCam verwaltete Einstellung geht auf ihren Standard zurück. Dein Kameraabstand und deine Einstellung zum Geländefolgen bleiben unverändert.",  -- 115
        "Third-Person-Shooter-Gefühl: enge Kamera, starker Schulterversatz, schnelles Zielen mit dem Stick. Außerhalb des Kampfs läufst du in Bewegungsrichtung, im Kampf strafst du mit Blick in Kamerarichtung.",  -- 116
        "Noch näher und ruhiger, für Deckungs-Shooter-Spiel: Dein Charakter dreht sich immer mit der Kamera, der Schulterversatz ist groß und die Kamera driftet nicht von selbst.",  -- 117
        "Langsam, weit und stimmungsvoll, für Quests und Screenshots: dynamische Neigung, starke Kopfbewegung und eine Kamera, die sich zu deinem Gesprächspartner dreht.",  -- 118
        "Die Kamera neigt sich zu deinem aktuellen Ziel und zu NPCs, mit denen du sprichst. Gut für Kämpfe gegen einzelne Ziele.",  -- 119
        "Eine weite, ruhige Kamera für Dungeons und Schlachtzüge: kein Versatz, keine Kopfbewegung, kein Kameradrift und schnelles Drehen mit dem Stick, damit du den ganzen Kampf überblickst.",  -- 120
        "Fürs Reiten: eine weite Kamera, die beim Lenken hinter dich schwenkt. Der Versatz ist aus, weil Reittiere unterschiedlicher Größe ihn unzuverlässig machen.",  -- 121
        "Fürs Fliegen: eine weite Kamera, die deinem Steig- und Sinkflug folgt.",  -- 122
        "Eine entspannte, langsamere Kamera für Städte: näher, ruhig und mit Kopfbewegung.",  -- 123
        "Eigenes Profil. Im Profil-Editor duplizieren oder bearbeiten.",  -- 124
        "Status anzeigen",  -- 125
        "Profile auflisten",  -- 126
        "wie sich ein Profil anfühlt und jede Einstellung, die es ändert",  -- 127
        "die empfohlene Einrichtung: Action-Kamera mit ruhigeren Profilen für Städte, Reittiere, Fliegen und Schlachtzüge",  -- 128
        "ein Profil jetzt verwenden, egal in welcher Situation",  -- 129
        "Erzwingen eines Profils beenden",  -- 130
        "deine aktuellen Kameraeinstellungen als neues Profil speichern",  -- 131
        "eine bearbeitbare Kopie eines Profils erstellen",  -- 132
        "eine Einstellung eines eigenen Profils ändern (/ccam settings listet sie auf)",  -- 133
        "Schulterversatz nach Kameraabstand, z. B. /ccam curve mine 0:2 8:2 20:0",  -- 134
        "auch die integrierten Profile bearbeitbar machen (/ccam reset <profile> stellt das Original wieder her)",  -- 135
        "ein bearbeitetes integriertes Profil auf seine Originaleinstellungen zurücksetzen",  -- 136
        "ein eigenes Profil löschen",  -- 137
        "eine Zeichenfolge zum Teilen anzeigen",  -- 138
        "ein Profil aus einer geteilten Zeichenfolge hinzufügen",  -- 139
        "den Schulterversatz auf die andere Schulter wechseln",  -- 140
        "wie lange eine Situation nach ihrem Ende gehalten wird (Standard 1,5)",  -- 141
        "einschalten, oder ausschalten und deine ursprünglichen Kameraeinstellungen wiederherstellen",  -- 142
        "Zoom, Schulterversatz und Bewegungseinstellungen jetzt anzeigen (zur Fehlersuche)",  -- 143
        "das Optionsfenster öffnen (Optionen > AddOns > ControllerCam)",  -- 144
        "diese Liste anzeigen",  -- 145
        "'%s' passt auf mehr als ein Profil. Gib mehr vom Namen ein.",  -- 146
        "Kein Profil namens '%s'. /ccam list zeigt sie an.",  -- 147
        "Kameraprofile für das Spielen mit Controller. Sofort gibt es eine Action-Kamera; Hybrid und Klassisch sind einen Befehl entfernt.",  -- 148
        "Integrierte Profile sind gesperrt. Aktiviere die erweiterte Bearbeitung (/ccam advanced on) oder erstelle eine Kopie: /ccam copy <profile>",  -- 149
        "Unbekannte Einstellung. /ccam settings listet sie auf.",  -- 150
        "Dieser Wert liegt außerhalb des erlaubten Bereichs.",  -- 151
        "Dieser Wert ist ungültig.",  -- 152
        "Verwendung: /ccam set <situation> <profile|none>",  -- 153
        "%s: keine Änderung",  -- 154
        "'%s' wird erzwungen. /ccam auto kehrt zu den Situationen zurück.",  -- 155
        "Die Kamera folgt wieder deinen Situationen.",  -- 156
        "Verwendung: /ccam edit <profile> <setting> <value|default>",  -- 157
        "Verwende /ccam curve für den Versatz nach Zoom.",  -- 158
        "Verwendung: /ccam advanced [on|off]",  -- 159
        "Erweiterte Bearbeitung ist %s.",  -- 160
        "'%s' hat wieder seine Originaleinstellungen.",  -- 161
        "Nichts zurückzusetzen: '%s' wurde nicht bearbeitet.",  -- 162
        "Integrierte Profile können nicht gelöscht werden.",  -- 163
        "Schulterversatz gespiegelt.",  -- 164
        "Schulterversatz wieder normal.",  -- 165
        "Situationen werden nach ihrem Ende noch %.1f Sekunden gehalten.",  -- 166
        "Verwendung: /ccam delay <seconds>",  -- 167
        "Das Optionsfenster ist in diesem Client nicht verfügbar",  -- 168
        "unbekannter Befehl '%s'. Gib /ccam help ein",  -- 169
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil. Der erste Eintrag, keine Änderung, lässt die Kamera unberührt.",  -- 170
        "Linksklick: nächstes Profil. Rechtsklick: vorheriges Profil.",  -- 171
        "Strg+C zum Kopieren drücken, dann Esc.",  -- 172
        "Füge hier eine ControllerCam-Zeichenfolge ein (Strg+V) und drücke dann auf Importieren.",  -- 173
        "Kameraprofile für das Spielen mit Controller. Wähle, wie sich die Kamera in jeder Situation anfühlt. Linksklick auf ein Profil wechselt zum nächsten, Rechtsklick zum vorherigen.",  -- 174
        "Kamerasteuerung ein- oder ausschalten. Im ausgeschalteten Zustand werden deine ursprünglichen Kameraeinstellungen wiederhergestellt.",  -- 175
        "Action-Kamera mit ruhigeren Profilen für Städte, Reittiere, Fliegen und Schlachtzüge.",  -- 176
        "Verhindert, dass die Kamera zwischen Profilen flackert, wenn eine Situation schnell an- und ausgeht.",  -- 177
        "Wechselt, über welche Schulter die Kamera blickt.",  -- 178
        "Dieses Profil in jeder Situation verwenden.",  -- 179
        "Erstellt eine bearbeitbare Kopie dieses Profils.",  -- 180
        "Speichert deine aktuellen Kameraeinstellungen als neues Profil.",  -- 181
        "Zeigt eine Zeichenfolge zum Teilen an.",  -- 182
        "Fügt ein Profil aus einer geteilten Zeichenfolge hinzu.",  -- 183
        "Löscht dieses eigene Profil.",  -- 184
        "Setzt dieses integrierte Profil auf seine Originaleinstellungen zurück.",  -- 185
        "Den Spielstandard für diese Einstellung verwenden.",  -- 186
        "Erweiterte Bearbeitung ist aktiv. Änderungen an einem integrierten Profil bleiben erhalten; „Auf Original zurücksetzen“ stellt es wieder her.",  -- 187
        "Angeln",  -- 188
        "In Innenräumen",  -- 189
        "Unbekannte Situation. Möglich sind:",  -- 190
        "das Profil für eine Situation wählen (/ccam zeigt die Liste)",  -- 191
        "der Schulterversatz in deiner aktuellen Gestalt (Druidengestalten, Geisterwolf), in Prozent des normalen",  -- 192
        "Du bist in keiner Gestalt.",  -- 193
        "Schulterversatz in dieser Gestalt: %d%%",  -- 194
        "Verwendung: /ccam formoffset <Prozent> (oder reset)",  -- 195
        "Das Spiel fragt beim nächsten Einloggen wieder nach seinen experimentellen Kameraeinstellungen.",  -- 196
        "Das Spiel fragt nicht mehr nach den experimentellen Kameraeinstellungen (du hast sie akzeptiert). /ccam notice holt die Frage zurück.",  -- 197
        "das Spiel beim nächsten Einloggen wieder nach seinen experimentellen Kameraeinstellungen fragen lassen",  -- 198
        "Bei einem feindlichen Ziel kommt die Kamera auf %.1f Meter heran.",  -- 199
        "Die Kamera behält bei einem feindlichen Ziel ihren Abstand.",  -- 200
        "Verwendung: /ccam targetzoom <Meter> (0 oder off: aus)",  -- 201
        "bei einem feindlichen Ziel kommt die Kamera so nah heran und geht danach wieder zurück (0: aus)",  -- 202
        "Näher bei feindlichem Ziel: %.1f Meter",  -- 203
        "Näher bei feindlichem Ziel: aus",  -- 204
        "Ziele auf einen Feind und die Kamera kommt auf diesen Abstand heran; lässt du ihn los, geht sie zurück, wo du sie hattest (nicht auf dem Reittier). Weit draußen unterwegs, nah dran im Kampf.",  -- 205
        "ControllerCam: wie Ihr Euch bewegt",  -- 206
        "Die Kameraprofile können auch festlegen, wie sich Eure Figur beim Laufen ausrichtet und dreht und wie schnell der Stick die Kamera dreht. Sollen sie das, oder behaltet Ihr Eure eigenen Einstellungen?",  -- 207
        "Die Profile legen jetzt fest, wie Ihr Euch bewegt und wie schnell der Stick ist (/ccam movement zum Ändern).",  -- 208
        "Eure eigenen Bewegungs- und Stick-Einstellungen bleiben erhalten (/ccam movement zum Ändern).",  -- 209
        "Die Profile machen lassen",  -- 210
        "Meine behalten",  -- 211
        "Profile legen auch Bewegung und Stick-Geschwindigkeit fest",  -- 212
        "Ausrichtung und Drehen beim Laufen sowie die Kamerageschwindigkeit des Sticks, von jedem Profil festgelegt. Aus: Eure eigenen Einstellungen, wie Ihr sie hattet.",  -- 213
        "Sichtfeld nach Zoom",  -- 214
        "Zielfokus nach Zoom",  -- 215
        "Das Gefühl direkt nach der Installation: nah über der Schulter, beim Herauszoomen sanft zur Mitte, und aus der Nähe am stärksten zum Ziel gedreht. Mit Kopfbewegung, und die Kamera folgt deiner Laufrichtung.",  -- 216
        "ein Profil überall verwenden (z. B. recommended, action, classic)",  -- 217
        "die Stärke des Schulterversatzes in jedem Profil, in Prozent vom Normalwert",  -- 218
        "Verwendung: /ccam offset <Prozent> (0 bis 200)",  -- 219
        "Stärke des Schulterversatzes: %d%%",  -- 220
        "Schnellwahl:",  -- 221
        "Verschiebt die Schulterkamera in jedem Profil weiter nach außen oder zurück zur Mitte. Praktisch, wenn die Größe deiner Figur das Bild anders wirken lässt.",  -- 222
        "Erweitert: alle Einstellungen zeigen und ändern",  -- 223
        "Zeigt alle Einstellungen in Gruppen und lässt dich auch die integrierten Profile ändern. Deine Änderungen bleiben erhalten, und „Auf Original zurücksetzen“ stellt das Original wieder her.",  -- 224
        "Versatz mit dem Zoom ändern",  -- 225
        "Wie weit zur Seite bei jedem Abstand. Die Kamera gleitet von einem Wert zum nächsten.",  -- 226
        "Zielfokus mit dem Zoom ändern",  -- 227
        "Wie viel deiner Zielfokus-Stärke bei jedem Abstand wirkt. Aus: überall die volle Stärke.",  -- 228
        "Sichtfeld mit dem Zoom ändern",  -- 229
        "Das Sichtfeld bei jedem Abstand, als Anteil deines eigenen. Aus: deines bleibt unverändert.",  -- 230
        "%s (%s bis %s Meter)",  -- 231
        "Du bist gerade bei %.1f Metern: %s.",  -- 232
        "Paare aus Abstand und Wert, zum Beispiel 0:2 8:2 20:0. Leer: nicht nach Zoom. Zum Anwenden Enter drücken.",  -- 233
        "nach Zoom",  -- 234
        "Dieses Spiel hat keine Sichtfeld-Einstellung, die Addons ändern können.",  -- 235
        "Nicht aufgeführte Einstellungen verwenden den Spielstandard. Wähle unten eine Gruppe, um ihre Einstellungen zu sehen.",  -- 236
        "Den meisten reichen die Voreinstellungen. Um eine zu ändern, erstelle eine Kopie oder aktiviere „Erweitert“, um alle Einstellungen zu sehen.",  -- 237
        "Gilt nur, wenn die Profile festlegen dürfen, wie du dich bewegst (erste Seite von ControllerCam).",  -- 238
        "Wie weit die Kamera entfernt ist, wenn dieses Profil übernimmt.",  -- 239
        "Wie weit du die Kamera herausziehen kannst. Höher bedeutet weiter.",  -- 240
        "Die genauen Punkte hinter der Tabelle oben, als Abstand:Anteil. 1 ist dein eigenes.",  -- 241
        "Wie schnell der rechte Stick die Kamera dreht.",  -- 242
        "Wie schnell der rechte Stick hoch und runter blickt.",  -- 243
        "Die Kamera schwenkt beim Laufen hinter dich.",  -- 244
        "Wie schnell die Kamera hinter dich schwenkt.",  -- 245
        "Wie schnell sich die Kamera wieder ausrichtet.",  -- 246
        "Wie lange die Kamera wartet, nachdem du sie selbst bewegt hast.",  -- 247
        "0: Deine Figur blickt dorthin, wohin sie läuft. 180: Sie blickt weiter nach vorn und strafet.",  -- 248
        "Dieselbe Wahl, während du kämpfst.",  -- 249
        "Wann sich deine Figur mitdreht, wenn du die Kamera drehst.",  -- 250
        "Dein Reittier dreht sich in die Richtung, in die du den Stick drückst.",  -- 251
        "Beim Schwimmen dreht sich deine Figur in die Richtung, in die du den Stick drückst.",  -- 252
        "Beim Fliegen drehst du dich in die Richtung, in die du den Stick drückst.",  -- 253
        "Ein Versatz für jeden Abstand. 0 hält deine Figur in der Mitte.",  -- 254
        "Die genauen Punkte hinter der Tabelle oben, als Abstand:Versatz.",  -- 255
        "Neigt die Ansicht beim Zoomen für einen flacheren, filmischen Winkel.",  -- 256
        "Wie stark sich die Kamera mit dem Kopf deiner Figur bewegt. 0 ist aus.",  -- 257
        "Wie viel dieser Bewegung im Stehen.",  -- 258
        "Wie viel dieser Bewegung beim Laufen.",  -- 259
        "Bis zu welchem Abstand sich die Kamera noch mit dem Kopf deiner Figur bewegt.",  -- 260
        "Die Kamera dreht sich zu dem Feind, den du anvisierst.",  -- 261
        "Wie stark sie sich nach links und rechts dreht. 1 ist am stärksten.",  -- 262
        "Wie stark sie sich nach oben und unten neigt. 1 ist am stärksten.",  -- 263
        "Die genauen Punkte hinter der Tabelle oben, als Abstand:Anteil. 1 ist die volle Stärke.",  -- 264
        "Die Kamera dreht sich zu der Person, mit der du sprichst.",  -- 265
        "Wie stark sie sich nach links und rechts zu ihr dreht.",  -- 266
        "Wie stark sie sich nach oben und unten zu ihr neigt.",  -- 267
        "Mit Maus und Tastatur: wann die Kamera wieder hinter dich schwenkt.",  -- 268
        "Neigt die Kamera mit Hügeln und Hängen. Deine Einstellung bleibt, wenn hier nichts gesetzt ist.",  -- 269
        "Wie weit die Kamera entfernt ist und wie weit du sie herausziehen kannst.",  -- 270
        "Wie weit die Kamera zur Seite versetzt ist, damit deine Figur nicht mitten im Bild steht.",  -- 271
        "Wie stark sich die Kamera zu deinem Ziel oder deinem Gesprächspartner dreht.",  -- 272
        "Wie stark sich die Kamera mit dem Kopf deiner Figur mitbewegt.",  -- 273
        "Kleine Bewegungen, die die Kamera von selbst macht.",  -- 274
        "Wie schnell der Stick die Kamera bewegt und ob die Kamera deiner Laufrichtung folgt.",  -- 275
        "In welche Richtung deine Figur beim Laufen blickt.",  -- 276
        "Ego-Perspektive",  -- 277
        "Über der Schulter",  -- 278
        "Oberkörper",  -- 279
        "Ganzer Körper",  -- 280
        "Mittlere Entfernung",  -- 281
        "Weit herausgezoomt",  -- 282
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
        "Configuración recomendada",  -- 64
        "(sin cambios)",  -- 65
        "Usar en todas partes",  -- 66
        "Hacer una copia",  -- 67
        "Guardar mi cámara actual",  -- 68
        "Exportar",  -- 69
        "Importar",  -- 70
        "Cerrar",  -- 71
        "Eliminar",  -- 72
        "predeterminado del juego",  -- 73
        "Predet.",  -- 74
        "Mi perfil",  -- 75
        "copia",  -- 76
        "forzado",  -- 77
        "personalizado",  -- 78
        "sin cambios",  -- 79
        "actual",  -- 80
        "nada aplicado todavía",  -- 81
        "Ahora: %s (%s)",  -- 82
        "Ahora: nada aplicado todavía",  -- 83
        "Reflejar el desplazamiento (otro hombro)",  -- 84
        "Mantener una situación %.1f s tras terminar",  -- 85
        "Comandos: /ccam help",  -- 86
        "Perfil para cada situación (gana la primera que se cumple, de arriba abajo):",  -- 87
        "Hecho.",  -- 88
        "Usando '%s' en todas partes.",  -- 89
        "Configuración recomendada aplicada.",  -- 90
        "Guardado como '%s'.",  -- 91
        "'%s' eliminado.",  -- 92
        "activado",  -- 93
        "desactivado. Se restauraron tus ajustes de cámara originales.",  -- 94
        "'%s' importado. Pruébalo con /ccam use \"%s\".",  -- 95
        "Eso no es una cadena de perfil de ControllerCam.",  -- 96
        "No hay nada que importar.",  -- 97
        "La cadena es demasiado larga para ser un perfil.",  -- 98
        "Este perfil se creó con una versión más reciente de ControllerCam. Actualiza el addon.",  -- 99
        "La cadena está dañada (la suma de comprobación no coincide). Cópiala de nuevo, completa.",  -- 100
        "El perfil no tiene un nombre válido.",  -- 101
        "No se puede importar: %s (%s).",  -- 102
        "un valor está fuera del rango permitido",  -- 103
        "un valor no es válido",  -- 104
        "una curva no es válida",  -- 105
        "contiene un ajuste que esta versión no conoce",  -- 106
        "Instalado. La cámara de Acción está activa. Prueba /ccam use hybrid o /ccam use classic; /ccam help lo lista todo.",  -- 107
        "%s también está cargado. Ambos cambian la cámara y chocarán. Desactiva uno de ellos.",  -- 108
        "La cámara sigue el terreno",  -- 109
        "tu ajuste",  -- 110
        "Restablecer el original",  -- 111
        "(editado)",  -- 112
        "Todo lo que no aparece usa el valor predeterminado del juego.",  -- 113
        "Entre Clásico y Acción: distancia media, un ligero desplazamiento sobre el hombro y un seguimiento de cabeza suave. La cámara sigue tu movimiento, pero conservas una vista amplia.",  -- 114
        "La cámara del propio juego: todos los ajustes que gestiona ControllerCam vuelven a su valor predeterminado. Tu distancia de cámara y tu ajuste de seguir el terreno no se tocan.",  -- 115
        "Sensación de shooter en tercera persona: cámara ajustada, fuerte desplazamiento sobre el hombro y apuntado rápido con el stick. Fuera de combate corres mirando hacia donde te mueves; en combate te desplazas lateralmente mirando a la cámara.",  -- 116
        "Aún más cerca y más estable, para juego tipo cover shooter: tu personaje siempre gira con la cámara, el desplazamiento sobre el hombro es grande y la cámara no se mueve sola.",  -- 117
        "Lenta, amplia y atmosférica, para misiones y capturas: inclinación dinámica, seguimiento de cabeza intenso y una cámara que se vuelve hacia quien hablas.",  -- 118
        "La cámara se inclina hacia tu objetivo actual y los PNJ con los que hablas. Buena para combates contra un solo objetivo.",  -- 119
        "Una cámara lejana y estable para mazmorras y bandas: sin desplazamiento, sin seguimiento de cabeza, sin deriva y con giro rápido del stick para ver todo el combate.",  -- 120
        "Para cabalgar: una cámara lejana que gira tras de ti al dirigir. El desplazamiento está desactivado porque las monturas de distintos tamaños lo hacen poco fiable.",  -- 121
        "Para volar: una cámara lejana que sigue tus ascensos y descensos.",  -- 122
        "Una cámara relajada y más lenta para ciudades: más cercana, tranquila y con seguimiento de cabeza.",  -- 123
        "Perfil personalizado. Duplícalo o edítalo en el editor de perfiles.",  -- 124
        "mostrar el estado",  -- 125
        "listar los perfiles",  -- 126
        "cómo se siente un perfil y todos los ajustes que cambia",  -- 127
        "la configuración recomendada: cámara de Acción con perfiles más calmados para ciudades, monturas, vuelo y bandas",  -- 128
        "usar un perfil ahora, sea cual sea la situación",  -- 129
        "dejar de forzar un perfil",  -- 130
        "guardar tus ajustes de cámara actuales como un perfil nuevo",  -- 131
        "hacer una copia editable de un perfil",  -- 132
        "cambiar un ajuste de un perfil personalizado (/ccam settings los lista)",  -- 133
        "desplazamiento sobre el hombro según la distancia de la cámara, p. ej. /ccam curve mine 0:2 8:2 20:0",  -- 134
        "permitir editar también los perfiles integrados (/ccam reset <profile> restaura el original)",  -- 135
        "devolver un perfil integrado editado a sus ajustes originales",  -- 136
        "eliminar un perfil personalizado",  -- 137
        "mostrar una cadena que puedes compartir",  -- 138
        "añadir un perfil desde una cadena compartida",  -- 139
        "cambiar el desplazamiento al otro hombro",  -- 140
        "cuánto se mantiene una situación tras terminar (predeterminado 1,5)",  -- 141
        "activar, o desactivar y restaurar tus ajustes de cámara originales",  -- 142
        "mostrar ahora el zoom, el desplazamiento y los ajustes de movimiento (para diagnosticar)",  -- 143
        "abrir el panel de opciones (Opciones > AddOns > ControllerCam)",  -- 144
        "mostrar esta lista",  -- 145
        "'%s' coincide con más de un perfil. Escribe más del nombre.",  -- 146
        "No hay ningún perfil llamado '%s'. /ccam list los muestra.",  -- 147
        "Perfiles de cámara para jugar con mando. Nada más instalar tienes una cámara de Acción; Híbrido y Clásico están a un comando.",  -- 148
        "Los perfiles integrados están bloqueados. Activa la edición avanzada (/ccam advanced on) o haz una copia: /ccam copy <profile>",  -- 149
        "Ajuste desconocido. /ccam settings los lista.",  -- 150
        "Ese valor está fuera del rango permitido.",  -- 151
        "Ese valor no es válido.",  -- 152
        "uso: /ccam set <situation> <profile|none>",  -- 153
        "%s: sin cambios",  -- 154
        "Forzando '%s'. /ccam auto vuelve a las situaciones.",  -- 155
        "La cámara vuelve a seguir tus situaciones.",  -- 156
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 157
        "Usa /ccam curve para el desplazamiento según el zoom.",  -- 158
        "uso: /ccam advanced [on|off]",  -- 159
        "La edición avanzada está %s.",  -- 160
        "'%s' vuelve a sus ajustes originales.",  -- 161
        "Nada que restablecer: '%s' no se ha editado.",  -- 162
        "Los perfiles integrados no se pueden eliminar.",  -- 163
        "Desplazamiento sobre el hombro reflejado.",  -- 164
        "Desplazamiento sobre el hombro de nuevo normal.",  -- 165
        "Las situaciones se mantienen %.1f segundos tras terminar.",  -- 166
        "uso: /ccam delay <seconds>",  -- 167
        "el panel de opciones no está disponible en este cliente",  -- 168
        "comando desconocido '%s'. Escribe /ccam help",  -- 169
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior. La primera entrada, sin cambios, deja la cámara como está.",  -- 170
        "Clic izquierdo: siguiente perfil. Clic derecho: perfil anterior.",  -- 171
        "Pulsa Ctrl+C para copiar y luego Esc.",  -- 172
        "Pega aquí una cadena de ControllerCam (Ctrl+V) y pulsa Importar.",  -- 173
        "Perfiles de cámara para jugar con mando. Elige cómo se siente la cámara en cada situación. Clic izquierdo en un perfil pasa al siguiente; clic derecho, al anterior.",  -- 174
        "Activa o desactiva el control de la cámara. Al desactivarlo se restauran tus ajustes de cámara originales.",  -- 175
        "Cámara de Acción con perfiles más calmados para ciudades, monturas, vuelo y bandas.",  -- 176
        "Evita que la cámara parpadee entre perfiles cuando una situación se activa y desactiva rápidamente.",  -- 177
        "Cambia el hombro sobre el que mira la cámara.",  -- 178
        "Usa este perfil en todas las situaciones.",  -- 179
        "Crea una copia editable de este perfil.",  -- 180
        "Guarda los ajustes de cámara actuales como un perfil nuevo.",  -- 181
        "Muestra una cadena que puedes compartir.",  -- 182
        "Añade un perfil desde una cadena compartida.",  -- 183
        "Elimina este perfil personalizado.",  -- 184
        "Devuelve este perfil integrado a sus ajustes originales.",  -- 185
        "Usar el valor predeterminado del juego para este ajuste.",  -- 186
        "La edición avanzada está activada. Los cambios en un perfil integrado se conservan; «Restablecer el original» lo recupera.",  -- 187
        "Pescando",  -- 188
        "En interiores",  -- 189
        "Situación desconocida. Usa una de:",  -- 190
        "elegir el perfil para una situación (/ccam muestra la lista)",  -- 191
        "el desplazamiento de hombro en la forma en la que estás (formas de druida, lobo fantasmal), en porcentaje del normal",  -- 192
        "No estás en ninguna forma.",  -- 193
        "Desplazamiento de hombro en esta forma: %d%%",  -- 194
        "uso: /ccam formoffset <porcentaje> (o reset)",  -- 195
        "El juego volverá a preguntar por sus ajustes de cámara experimentales al iniciar sesión la próxima vez.",  -- 196
        "El juego no volverá a preguntar por los ajustes de cámara experimentales (los aceptaste). /ccam notice recupera la pregunta.",  -- 197
        "hacer que el juego vuelva a preguntar por sus ajustes de cámara experimentales al iniciar sesión",  -- 198
        "Con un enemigo como objetivo, la cámara se acerca a %.1f yardas.",  -- 199
        "La cámara mantiene su distancia con un enemigo como objetivo.",  -- 200
        "uso: /ccam targetzoom <yardas> (0 u off: desactivado)",  -- 201
        "con un enemigo como objetivo, la cámara se acerca a esta distancia y luego vuelve (0: desactivado)",  -- 202
        "Más cerca con un enemigo como objetivo: %.1f yardas",  -- 203
        "Más cerca con un enemigo como objetivo: desactivado",  -- 204
        "Al fijar un enemigo, la cámara se acerca a esta distancia; al soltarlo vuelve a donde la tenías (no montado). Explora de lejos, lucha de cerca.",  -- 205
        "ControllerCam: cómo te mueves",  -- 206
        "Los perfiles de cámara también pueden ajustar cómo se orienta y gira tu personaje al moverse, y lo rápido que el stick gira la cámara. ¿Dejar que lo hagan, o mantener tus propios ajustes?",  -- 207
        "Los perfiles ahora ajustan cómo te mueves y la velocidad del stick (/ccam movement para cambiarlo).",  -- 208
        "Se mantienen tus propios ajustes de movimiento y del stick (/ccam movement para cambiarlo).",  -- 209
        "Que los perfiles los ajusten",  -- 210
        "Mantener los míos",  -- 211
        "Los perfiles también ajustan el movimiento y la velocidad del stick",  -- 212
        "La orientación y el giro al moverte, y las velocidades de cámara del stick, los ajusta cada perfil. Desactivado: tus propios ajustes, tal como los tenías.",  -- 213
        "Campo de visión según el zoom",  -- 214
        "Enfoque en el objetivo según el zoom",  -- 215
        "La sensación lista para usar: de cerca, sobre el hombro; al alejar el zoom vuelve suavemente al centro, y de cerca es cuando más gira hacia tu objetivo. Con seguimiento de cabeza, y la cámara sigue hacia dónde corres.",  -- 216
        "usar un perfil en todas partes (prueba: recommended, action, classic)",  -- 217
        "la intensidad del desplazamiento del hombro en todos los perfiles, en porcentaje de lo normal",  -- 218
        "uso: /ccam offset <porcentaje> (de 0 a 200)",  -- 219
        "Intensidad del desplazamiento del hombro: %d%%",  -- 220
        "Selección rápida:",  -- 221
        "Aleja la cámara sobre el hombro o la devuelve hacia el centro, en todos los perfiles. Útil si el tamaño de tu personaje hace que quede distinto.",  -- 222
        "Avanzado: ver y editar todos los ajustes",  -- 223
        "Muestra todos los ajustes, por grupos, y permite cambiar también los perfiles integrados. Tus cambios se conservan y «Restablecer el original» recupera el original.",  -- 224
        "Cambiar el desplazamiento con el zoom",  -- 225
        "Cuánto hacia un lado a cada distancia. La cámara pasa suavemente de un valor al siguiente.",  -- 226
        "Cambiar el enfoque en el objetivo con el zoom",  -- 227
        "Qué parte de la intensidad del enfoque en el objetivo se usa a cada distancia. Desactivado: toda, en todas partes.",  -- 228
        "Cambiar el campo de visión con el zoom",  -- 229
        "El campo de visión a cada distancia, como parte del tuyo. Desactivado: el tuyo no se toca.",  -- 230
        "%s (de %s a %s yardas)",  -- 231
        "Ahora estás a %.1f yardas: %s.",  -- 232
        "Pares de distancia y valor, por ejemplo 0:2 8:2 20:0. Vacío: sin variar con el zoom. Pulsa Intro para aplicar.",  -- 233
        "según zoom",  -- 234
        "Este juego no tiene un ajuste de campo de visión que los addons puedan cambiar.",  -- 235
        "Los ajustes que no aparecen usan el valor predeterminado del juego. Elige un grupo abajo para ver sus ajustes.",  -- 236
        "Para la mayoría bastan los perfiles ya hechos. Para cambiar uno, haz una copia o marca Avanzado para ver todos los ajustes.",  -- 237
        "Solo se usa si dejas que los perfiles ajusten cómo te mueves (primera página de ControllerCam).",  -- 238
        "A qué distancia se coloca la cámara cuando entra este perfil.",  -- 239
        "Cuánto puedes alejar la cámara. Más alto es más lejos.",  -- 240
        "Los puntos exactos de la tabla de arriba, como distancia:parte. 1 es el tuyo.",  -- 241
        "Lo rápido que el stick derecho gira la cámara.",  -- 242
        "Lo rápido que el stick derecho mira arriba y abajo.",  -- 243
        "La cámara se coloca detrás de ti mientras corres.",  -- 244
        "Lo rápido que la cámara se coloca detrás de ti.",  -- 245
        "Lo rápido que la cámara vuelve a nivelarse.",  -- 246
        "Cuánto espera la cámara después de que la muevas tú.",  -- 247
        "0: tu personaje mira hacia donde corre. 180: sigue mirando al frente y se desplaza de lado.",  -- 248
        "La misma elección, mientras estás en combate.",  -- 249
        "Cuándo gira tu personaje al girar la cámara.",  -- 250
        "Tu montura se orienta hacia donde empujas el stick.",  -- 251
        "Al nadar, tu personaje se orienta hacia donde empujas el stick.",  -- 252
        "Al volar, te orientas hacia donde empujas el stick.",  -- 253
        "Un solo desplazamiento a cualquier distancia. 0 deja a tu personaje en el centro.",  -- 254
        "Los puntos exactos de la tabla de arriba, como distancia:desplazamiento.",  -- 255
        "Inclina la vista al hacer zoom para un ángulo más bajo y cinematográfico.",  -- 256
        "Cuánto se mueve la cámara con la cabeza de tu personaje. 0 es desactivado.",  -- 257
        "Cuánto de ese movimiento cuando estás parado.",  -- 258
        "Cuánto de ese movimiento mientras corres.",  -- 259
        "Hasta qué distancia la cámara sigue moviéndose con la cabeza de tu personaje.",  -- 260
        "La cámara gira hacia el enemigo que tienes como objetivo.",  -- 261
        "Con cuánta fuerza gira a izquierda y derecha. 1 es lo más fuerte.",  -- 262
        "Con cuánta fuerza se inclina arriba y abajo. 1 es lo más fuerte.",  -- 263
        "Los puntos exactos de la tabla de arriba, como distancia:parte. 1 es toda la intensidad.",  -- 264
        "La cámara gira hacia la persona con quien hablas.",  -- 265
        "Con cuánta fuerza gira a izquierda y derecha hacia esa persona.",  -- 266
        "Con cuánta fuerza se inclina arriba y abajo hacia esa persona.",  -- 267
        "Con ratón y teclado: cuándo la cámara vuelve detrás de ti.",  -- 268
        "Inclina la cámara con colinas y pendientes. Se mantiene tu ajuste si no lo cambias aquí.",  -- 269
        "A qué distancia está la cámara y cuánto puedes alejarla.",  -- 270
        "Cuánto se coloca la cámara hacia un lado, para que tu personaje no quede en el centro de la pantalla.",  -- 271
        "Cuánto gira la cámara para mirar a tu objetivo o a la persona con quien hablas.",  -- 272
        "Cuánto acompaña la cámara el movimiento de la cabeza de tu personaje.",  -- 273
        "Pequeños movimientos que la cámara hace por sí sola.",  -- 274
        "Lo rápido que el stick mueve la cámara y si la cámara sigue hacia dónde corres.",  -- 275
        "Hacia dónde mira tu personaje al moverse.",  -- 276
        "Primera persona",  -- 277
        "Sobre el hombro",  -- 278
        "Torso",  -- 279
        "Cuerpo entero",  -- 280
        "Distancia media",  -- 281
        "Alejado",  -- 282
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
        "Configuration recommandée",  -- 64
        "(aucun changement)",  -- 65
        "Utiliser partout",  -- 66
        "Faire une copie",  -- 67
        "Enregistrer ma caméra actuelle",  -- 68
        "Exporter",  -- 69
        "Importer",  -- 70
        "Fermer",  -- 71
        "Supprimer",  -- 72
        "défaut du jeu",  -- 73
        "Défaut",  -- 74
        "Mon profil",  -- 75
        "copie",  -- 76
        "forcé",  -- 77
        "personnalisé",  -- 78
        "aucun changement",  -- 79
        "actuel",  -- 80
        "rien d'appliqué pour l'instant",  -- 81
        "Maintenant : %s (%s)",  -- 82
        "Maintenant : rien d'appliqué pour l'instant",  -- 83
        "Inverser le décalage (autre épaule)",  -- 84
        "Garder une situation %.1f s après sa fin",  -- 85
        "Commandes : /ccam help",  -- 86
        "Profil pour chaque situation (la première qui s'applique l'emporte, en partant du haut) :",  -- 87
        "Terminé.",  -- 88
        "'%s' est utilisé partout.",  -- 89
        "Configuration recommandée appliquée.",  -- 90
        "Enregistré sous '%s'.",  -- 91
        "'%s' supprimé.",  -- 92
        "activé",  -- 93
        "désactivé. Vos réglages de caméra d'origine ont été restaurés.",  -- 94
        "'%s' importé. Essayez-le avec /ccam use \"%s\".",  -- 95
        "Ce n'est pas une chaîne de profil ControllerCam.",  -- 96
        "Rien à importer.",  -- 97
        "La chaîne est trop longue pour être un profil.",  -- 98
        "Ce profil a été créé avec une version plus récente de ControllerCam. Mettez l'addon à jour.",  -- 99
        "La chaîne est endommagée (somme de contrôle incorrecte). Copiez-la à nouveau, en entier.",  -- 100
        "Le profil n'a pas de nom valide.",  -- 101
        "Import impossible : %s (%s).",  -- 102
        "une valeur est hors de la plage autorisée",  -- 103
        "une valeur n'est pas valide",  -- 104
        "une courbe n'est pas valide",  -- 105
        "elle contient un réglage inconnu de cette version",  -- 106
        "Installé. La caméra Action est active. Essayez /ccam use hybrid ou /ccam use classic ; /ccam help liste tout.",  -- 107
        "%s est également chargé. Les deux modifient la caméra et se gênent. Désactivez-en un.",  -- 108
        "La caméra suit le terrain",  -- 109
        "votre réglage",  -- 110
        "Rétablir l'original",  -- 111
        "(modifié)",  -- 112
        "Tout ce qui n'est pas listé utilise la valeur par défaut du jeu.",  -- 113
        "Entre Classique et Action : distance moyenne, léger décalage par-dessus l'épaule et suivi de la tête discret. La caméra suit votre déplacement, mais vous gardez une vue large.",  -- 114
        "La caméra d'origine du jeu : tous les réglages gérés par ControllerCam reviennent à leur valeur par défaut. Votre distance de caméra et votre réglage de suivi du terrain ne sont pas modifiés.",  -- 115
        "Ambiance shooter à la troisième personne : caméra serrée, fort décalage par-dessus l'épaule, visée rapide au stick. Hors combat vous courez face à votre direction, en combat vous vous déplacez latéralement face à la caméra.",  -- 116
        "Encore plus proche et plus stable, pour le jeu de tir à couvert : votre personnage tourne toujours avec la caméra, le décalage par-dessus l'épaule est important et la caméra ne dérive pas toute seule.",  -- 117
        "Lente, large et d'ambiance, pour les quêtes et les captures d'écran : inclinaison dynamique, fort suivi de la tête et une caméra qui se tourne vers votre interlocuteur.",  -- 118
        "La caméra se penche vers votre cible actuelle et les PNJ à qui vous parlez. Idéal pour les combats contre une seule cible.",  -- 119
        "Une caméra éloignée et stable pour les donjons et les raids : aucun décalage, aucun suivi de la tête, aucune dérive et une rotation rapide au stick pour voir tout le combat.",  -- 120
        "Pour la monture : une caméra éloignée qui se place derrière vous quand vous dirigez. Le décalage est désactivé, car les montures de tailles différentes le rendent peu fiable.",  -- 121
        "Pour le vol : une caméra éloignée qui suit vos montées et vos piqués.",  -- 122
        "Une caméra détendue et plus lente pour les villes : plus proche, calme et avec suivi de la tête.",  -- 123
        "Profil personnalisé. Dupliquez-le ou modifiez-le dans l'éditeur de profils.",  -- 124
        "afficher l'état",  -- 125
        "lister les profils",  -- 126
        "le ressenti d'un profil et tous les réglages qu'il modifie",  -- 127
        "la configuration recommandée : caméra Action avec des profils plus calmes pour les villes, montures, le vol et les raids",  -- 128
        "utiliser un profil maintenant, quelle que soit la situation",  -- 129
        "arrêter de forcer un profil",  -- 130
        "enregistrer vos réglages de caméra actuels comme nouveau profil",  -- 131
        "faire une copie modifiable d'un profil",  -- 132
        "modifier un réglage d'un profil personnalisé (/ccam settings les liste)",  -- 133
        "décalage par-dessus l'épaule selon la distance de la caméra, p. ex. /ccam curve mine 0:2 8:2 20:0",  -- 134
        "autoriser aussi la modification des profils intégrés (/ccam reset <profile> rétablit l'original)",  -- 135
        "remettre un profil intégré modifié à ses réglages d'origine",  -- 136
        "supprimer un profil personnalisé",  -- 137
        "afficher une chaîne à partager",  -- 138
        "ajouter un profil depuis une chaîne partagée",  -- 139
        "passer le décalage sur l'autre épaule",  -- 140
        "combien de temps une situation est conservée après sa fin (par défaut 1,5)",  -- 141
        "activer, ou désactiver et restaurer vos réglages de caméra d'origine",  -- 142
        "afficher maintenant le zoom, le décalage et les réglages de mouvement (pour le dépannage)",  -- 143
        "ouvrir le panneau d'options (Options > AddOns > ControllerCam)",  -- 144
        "afficher cette liste",  -- 145
        "'%s' correspond à plusieurs profils. Tapez davantage du nom.",  -- 146
        "Aucun profil nommé '%s'. /ccam list les affiche.",  -- 147
        "Profils de caméra pour jouer à la manette. Vous avez d'emblée une caméra Action ; Hybride et Classique sont à une commande.",  -- 148
        "Les profils intégrés sont verrouillés. Activez la modification avancée (/ccam advanced on) ou faites une copie : /ccam copy <profile>",  -- 149
        "Réglage inconnu. /ccam settings les liste.",  -- 150
        "Cette valeur est hors de la plage autorisée.",  -- 151
        "Cette valeur n'est pas valide.",  -- 152
        "utilisation : /ccam set <situation> <profile|none>",  -- 153
        "%s : aucun changement",  -- 154
        "'%s' est forcé. /ccam auto revient aux situations.",  -- 155
        "La caméra suit de nouveau vos situations.",  -- 156
        "utilisation : /ccam edit <profile> <setting> <value|default>",  -- 157
        "Utilisez /ccam curve pour le décalage selon le zoom.",  -- 158
        "utilisation : /ccam advanced [on|off]",  -- 159
        "La modification avancée est %s.",  -- 160
        "'%s' est revenu à ses réglages d'origine.",  -- 161
        "Rien à rétablir : '%s' n'a pas été modifié.",  -- 162
        "Les profils intégrés ne peuvent pas être supprimés.",  -- 163
        "Décalage par-dessus l'épaule inversé.",  -- 164
        "Décalage par-dessus l'épaule revenu à la normale.",  -- 165
        "Les situations sont conservées %.1f secondes après leur fin.",  -- 166
        "utilisation : /ccam delay <seconds>",  -- 167
        "le panneau d'options n'est pas disponible dans ce client",  -- 168
        "commande inconnue '%s'. Tapez /ccam help",  -- 169
        "Clic gauche : profil suivant. Clic droit : profil précédent. La première entrée, aucun changement, laisse la caméra telle quelle.",  -- 170
        "Clic gauche : profil suivant. Clic droit : profil précédent.",  -- 171
        "Appuyez sur Ctrl+C pour copier, puis sur Échap.",  -- 172
        "Collez ici une chaîne ControllerCam (Ctrl+V), puis appuyez sur Importer.",  -- 173
        "Profils de caméra pour jouer à la manette. Choisissez le ressenti de la caméra dans chaque situation. Clic gauche sur un profil pour passer au suivant, clic droit pour le précédent.",  -- 174
        "Active ou désactive le contrôle de la caméra. Une fois désactivé, vos réglages de caméra d'origine sont rétablis.",  -- 175
        "Caméra Action avec des profils plus calmes pour les villes, montures, le vol et les raids.",  -- 176
        "Empêche la caméra de basculer entre les profils lorsqu'une situation s'active et se désactive rapidement.",  -- 177
        "Change l'épaule par-dessus laquelle la caméra regarde.",  -- 178
        "Utiliser ce profil dans toutes les situations.",  -- 179
        "Crée une copie modifiable de ce profil.",  -- 180
        "Enregistre vos réglages de caméra actuels comme nouveau profil.",  -- 181
        "Affiche une chaîne à partager.",  -- 182
        "Ajoute un profil depuis une chaîne partagée.",  -- 183
        "Supprime ce profil personnalisé.",  -- 184
        "Remet ce profil intégré à ses réglages d'origine.",  -- 185
        "Utiliser la valeur par défaut du jeu pour ce réglage.",  -- 186
        "La modification avancée est activée. Les modifications d'un profil intégré sont conservées ; « Rétablir l'original » le restaure.",  -- 187
        "À la pêche",  -- 188
        "En intérieur",  -- 189
        "Situation inconnue. Utilisez l'une de :",  -- 190
        "choisir le profil pour une situation (/ccam affiche la liste)",  -- 191
        "le décalage d'épaule dans votre forme actuelle (formes de druide, loup fantôme), en pourcentage de la normale",  -- 192
        "Vous n'êtes sous aucune forme.",  -- 193
        "Décalage d'épaule dans cette forme : %d%%",  -- 194
        "utilisation : /ccam formoffset <pourcentage> (ou reset)",  -- 195
        "Le jeu redemandera pour ses réglages de caméra expérimentaux à la prochaine connexion.",  -- 196
        "Le jeu ne demandera plus pour les réglages de caméra expérimentaux (vous les avez acceptés). /ccam notice fait revenir la question.",  -- 197
        "laisser le jeu redemander pour ses réglages de caméra expérimentaux à la prochaine connexion",  -- 198
        "Sur une cible ennemie, la caméra se rapproche à %.1f mètres.",  -- 199
        "La caméra garde sa distance sur une cible ennemie.",  -- 200
        "utilisation : /ccam targetzoom <mètres> (0 ou off : désactivé)",  -- 201
        "sur une cible ennemie, la caméra se rapproche à cette distance puis revient (0 : désactivé)",  -- 202
        "Plus près sur une cible ennemie : %.1f mètres",  -- 203
        "Plus près sur une cible ennemie : désactivé",  -- 204
        "Ciblez un ennemi et la caméra se rapproche à cette distance ; relâchez-le et elle revient où vous l'aviez (pas sur une monture). Explorez de loin, combattez de près.",  -- 205
        "ControllerCam : vos déplacements",  -- 206
        "Les profils de caméra peuvent aussi régler l'orientation et la rotation de votre personnage quand il se déplace, et la vitesse à laquelle le stick tourne la caméra. Les laisser faire, ou garder vos propres réglages ?",  -- 207
        "Les profils règlent désormais vos déplacements et la vitesse du stick (/ccam movement pour changer).",  -- 208
        "Vos propres réglages de déplacement et de stick sont conservés (/ccam movement pour changer).",  -- 209
        "Laisser les profils régler",  -- 210
        "Garder les miens",  -- 211
        "Les profils règlent aussi les déplacements et la vitesse du stick",  -- 212
        "L'orientation et la rotation en déplacement, et les vitesses de caméra du stick, réglées par chaque profil. Désactivé : vos propres réglages, tels que vous les aviez.",  -- 213
        "Champ de vision selon le zoom",  -- 214
        "Focus sur la cible selon le zoom",  -- 215
        "Le ressenti prêt à l'emploi : de près, par-dessus l'épaule ; en dézoomant, la caméra revient doucement au centre, et c'est de près qu'elle se tourne le plus vers votre cible. Suivi de la tête, et la caméra suit votre course.",  -- 216
        "utiliser un profil partout (essayez : recommended, action, classic)",  -- 217
        "la force du décalage d'épaule dans tous les profils, en pourcentage de la normale",  -- 218
        "utilisation : /ccam offset <pourcentage> (0 à 200)",  -- 219
        "Force du décalage d'épaule : %d%%",  -- 220
        "Choix rapide :",  -- 221
        "Éloigne la caméra par-dessus l'épaule ou la ramène vers le centre, dans tous les profils. Pratique si la taille de votre personnage change son placement.",  -- 222
        "Avancé : afficher et modifier tous les réglages",  -- 223
        "Affiche tous les réglages, par groupes, et permet de modifier aussi les profils intégrés. Vos modifications sont conservées et « Rétablir l'original » rétablit l'original.",  -- 224
        "Faire varier le décalage avec le zoom",  -- 225
        "De combien sur le côté à chaque distance. La caméra passe en douceur d'une valeur à l'autre.",  -- 226
        "Faire varier le focus sur la cible avec le zoom",  -- 227
        "Quelle part de la force du focus sur la cible à chaque distance. Désactivé : toute la force, partout.",  -- 228
        "Faire varier le champ de vision avec le zoom",  -- 229
        "Le champ de vision à chaque distance, en proportion du vôtre. Désactivé : le vôtre n'est pas modifié.",  -- 230
        "%s (de %s à %s mètres)",  -- 231
        "Vous êtes à %.1f mètres : %s.",  -- 232
        "Paires distance et valeur, par exemple 0:2 8:2 20:0. Vide : pas de variation avec le zoom. Appuyez sur Entrée pour appliquer.",  -- 233
        "selon le zoom",  -- 234
        "Ce jeu n'a pas de réglage de champ de vision que les addons puissent modifier.",  -- 235
        "Les réglages non listés utilisent la valeur par défaut du jeu. Choisissez un groupe ci-dessous pour voir ses réglages.",  -- 236
        "Les préréglages suffisent à la plupart. Pour en modifier un, faites une copie ou cochez Avancé pour voir tous les réglages.",  -- 237
        "Utilisé seulement si vous laissez les profils régler vos déplacements (première page de ControllerCam).",  -- 238
        "À quelle distance se place la caméra quand ce profil prend le relais.",  -- 239
        "Jusqu'où vous pouvez éloigner la caméra. Plus la valeur est haute, plus c'est loin.",  -- 240
        "Les points exacts derrière le tableau ci-dessus, en distance:proportion. 1 correspond au vôtre.",  -- 241
        "La vitesse à laquelle le stick droit tourne la caméra.",  -- 242
        "La vitesse à laquelle le stick droit regarde en haut et en bas.",  -- 243
        "La caméra revient derrière vous quand vous courez.",  -- 244
        "La vitesse à laquelle la caméra revient derrière vous.",  -- 245
        "La vitesse à laquelle la caméra se remet à niveau.",  -- 246
        "Combien de temps la caméra attend après que vous l'avez bougée.",  -- 247
        "0 : votre personnage fait face à sa direction de course. 180 : il reste tourné vers l'avant et se déplace latéralement.",  -- 248
        "Le même choix, pendant un combat.",  -- 249
        "Quand votre personnage tourne avec la caméra.",  -- 250
        "Votre monture se tourne dans la direction où vous poussez le stick.",  -- 251
        "En nageant, votre personnage se tourne dans la direction où vous poussez le stick.",  -- 252
        "En vol, vous vous tournez dans la direction où vous poussez le stick.",  -- 253
        "Un seul décalage à toutes les distances. 0 garde votre personnage au centre.",  -- 254
        "Les points exacts derrière le tableau ci-dessus, en distance:décalage.",  -- 255
        "Incline la vue pendant le zoom pour un angle plus bas, plus cinématique.",  -- 256
        "À quel point la caméra suit la tête de votre personnage. 0 désactive.",  -- 257
        "La part de ce mouvement à l'arrêt.",  -- 258
        "La part de ce mouvement en courant.",  -- 259
        "Jusqu'à quelle distance la caméra bouge encore avec la tête de votre personnage.",  -- 260
        "La caméra se tourne vers l'ennemi que vous ciblez.",  -- 261
        "Avec quelle force elle tourne à gauche et à droite. 1 est le maximum.",  -- 262
        "Avec quelle force elle s'incline de haut en bas. 1 est le maximum.",  -- 263
        "Les points exacts derrière le tableau ci-dessus, en distance:proportion. 1 correspond à la pleine force.",  -- 264
        "La caméra se tourne vers la personne à qui vous parlez.",  -- 265
        "Avec quelle force elle tourne à gauche et à droite vers elle.",  -- 266
        "Avec quelle force elle s'incline de haut en bas vers elle.",  -- 267
        "À la souris et au clavier : quand la caméra revient derrière vous.",  -- 268
        "Incline la caméra avec les collines et les pentes. Votre réglage est conservé sauf s'il est défini ici.",  -- 269
        "La distance de la caméra, et jusqu'où vous pouvez l'éloigner.",  -- 270
        "De combien la caméra est décalée sur le côté, pour que votre personnage ne soit pas au centre de l'écran.",  -- 271
        "À quel point la caméra se tourne vers votre cible ou la personne à qui vous parlez.",  -- 272
        "À quel point la caméra accompagne la tête de votre personnage.",  -- 273
        "Les petits mouvements que la caméra fait d'elle-même.",  -- 274
        "La vitesse de la caméra au stick, et si elle suit votre course.",  -- 275
        "La direction à laquelle votre personnage fait face en se déplaçant.",  -- 276
        "Vue à la première personne",  -- 277
        "Par-dessus l'épaule",  -- 278
        "Haut du corps",  -- 279
        "Corps entier",  -- 280
        "Mi-distance",  -- 281
        "Dézoomé",  -- 282
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
        "Configurazione consigliata",  -- 64
        "(nessuna modifica)",  -- 65
        "Usa ovunque",  -- 66
        "Crea una copia",  -- 67
        "Salva la mia telecamera attuale",  -- 68
        "Esporta",  -- 69
        "Importa",  -- 70
        "Chiudi",  -- 71
        "Elimina",  -- 72
        "predefinito del gioco",  -- 73
        "Predef.",  -- 74
        "Il mio profilo",  -- 75
        "copia",  -- 76
        "forzato",  -- 77
        "personalizzato",  -- 78
        "nessuna modifica",  -- 79
        "attuale",  -- 80
        "ancora nulla applicato",  -- 81
        "Ora: %s (%s)",  -- 82
        "Ora: ancora nulla applicato",  -- 83
        "Specchia lo scostamento (altra spalla)",  -- 84
        "Mantieni una situazione per %.1f s dopo la fine",  -- 85
        "Comandi: /ccam help",  -- 86
        "Profilo per ogni situazione (vince la prima che si applica, dall'alto):",  -- 87
        "Fatto.",  -- 88
        "'%s' viene usato ovunque.",  -- 89
        "Configurazione consigliata applicata.",  -- 90
        "Salvato come '%s'.",  -- 91
        "'%s' eliminato.",  -- 92
        "attivato",  -- 93
        "disattivato. Le tue impostazioni originali della telecamera sono state ripristinate.",  -- 94
        "'%s' importato. Provalo con /ccam use \"%s\".",  -- 95
        "Questa non è una stringa di profilo ControllerCam.",  -- 96
        "Niente da importare.",  -- 97
        "La stringa è troppo lunga per essere un profilo.",  -- 98
        "Questo profilo è stato creato con una versione più recente di ControllerCam. Aggiorna l'addon.",  -- 99
        "La stringa è danneggiata (checksum non corrispondente). Copiala di nuovo, per intero.",  -- 100
        "Il profilo non ha un nome valido.",  -- 101
        "Impossibile importare: %s (%s).",  -- 102
        "un valore è fuori dall'intervallo consentito",  -- 103
        "un valore non è valido",  -- 104
        "una curva non è valida",  -- 105
        "contiene un'impostazione sconosciuta a questa versione",  -- 106
        "Installato. La telecamera Azione è attiva. Prova /ccam use hybrid o /ccam use classic; /ccam help mostra tutto.",  -- 107
        "Anche %s è caricato. Entrambi modificano la telecamera e interferiranno. Disattiva uno dei due.",  -- 108
        "La telecamera segue il terreno",  -- 109
        "la tua impostazione",  -- 110
        "Ripristina l'originale",  -- 111
        "(modificato)",  -- 112
        "Tutto ciò che non è elencato usa il valore predefinito del gioco.",  -- 113
        "A metà tra Classico e Azione: distanza media, un leggero scostamento sopra la spalla e un movimento della testa delicato. La telecamera segue il tuo movimento, ma mantieni una visuale ampia.",  -- 114
        "La telecamera originale del gioco: ogni impostazione gestita da ControllerCam torna al valore predefinito. La distanza della telecamera e l'impostazione di inseguimento del terreno restano invariate.",  -- 115
        "Sensazione da sparatutto in terza persona: telecamera stretta, forte scostamento sopra la spalla, mira rapida con lo stick. Fuori dal combattimento corri nella direzione del movimento, in combattimento ti sposti lateralmente guardando la telecamera.",  -- 116
        "Ancora più vicina e stabile, per il gioco da cover shooter: il personaggio ruota sempre con la telecamera, lo scostamento sopra la spalla è ampio e la telecamera non si sposta da sola.",  -- 117
        "Lenta, ampia e suggestiva, per le missioni e gli screenshot: inclinazione dinamica, forte movimento della testa e una telecamera che si volge verso chi parli.",  -- 118
        "La telecamera si inclina verso il bersaglio attuale e gli NPC con cui parli. Ottima per gli scontri contro un singolo bersaglio.",  -- 119
        "Una telecamera lontana e stabile per dungeon e raid: nessuno scostamento, nessun movimento della testa, nessuna deriva e rotazione rapida con lo stick per vedere tutto lo scontro.",  -- 120
        "Per la cavalcatura: una telecamera lontana che si porta dietro di te mentre sterzi. Lo scostamento è disattivato, perché le cavalcature di dimensioni diverse lo rendono inaffidabile.",  -- 121
        "Per il volo: una telecamera lontana che segue le tue salite e picchiate.",  -- 122
        "Una telecamera rilassata e più lenta per le città: più vicina, calma e con movimento della testa.",  -- 123
        "Profilo personalizzato. Duplicalo o modificalo nell'editor dei profili.",  -- 124
        "mostra lo stato",  -- 125
        "elenca i profili",  -- 126
        "come si comporta un profilo e ogni impostazione che modifica",  -- 127
        "la configurazione consigliata: telecamera Azione con profili più calmi per città, cavalcature, volo e raid",  -- 128
        "usa un profilo adesso, qualunque sia la situazione",  -- 129
        "smetti di forzare un profilo",  -- 130
        "salva le impostazioni attuali della telecamera come nuovo profilo",  -- 131
        "crea una copia modificabile di un profilo",  -- 132
        "cambia un'impostazione di un profilo personalizzato (/ccam settings le elenca)",  -- 133
        "scostamento sopra la spalla in base alla distanza della telecamera, es. /ccam curve mine 0:2 8:2 20:0",  -- 134
        "consenti di modificare anche i profili integrati (/ccam reset <profile> ripristina l'originale)",  -- 135
        "riporta un profilo integrato modificato alle impostazioni originali",  -- 136
        "elimina un profilo personalizzato",  -- 137
        "mostra una stringa da condividere",  -- 138
        "aggiungi un profilo da una stringa condivisa",  -- 139
        "sposta lo scostamento sull'altra spalla",  -- 140
        "per quanto una situazione viene mantenuta dopo la fine (predefinito 1,5)",  -- 141
        "attiva, oppure disattiva e ripristina le impostazioni originali della telecamera",  -- 142
        "mostra ora zoom, scostamento e impostazioni di movimento (per la diagnosi)",  -- 143
        "apri il pannello delle opzioni (Opzioni > AddOn > ControllerCam)",  -- 144
        "mostra questo elenco",  -- 145
        "'%s' corrisponde a più profili. Scrivi più parte del nome.",  -- 146
        "Nessun profilo chiamato '%s'. /ccam list li mostra.",  -- 147
        "Profili della telecamera per giocare con il controller. Subito hai una telecamera Azione; Ibrido e Classico sono a un comando di distanza.",  -- 148
        "I profili integrati sono bloccati. Attiva la modifica avanzata (/ccam advanced on) o crea una copia: /ccam copy <profile>",  -- 149
        "Impostazione sconosciuta. /ccam settings le elenca.",  -- 150
        "Quel valore è fuori dall'intervallo consentito.",  -- 151
        "Quel valore non è valido.",  -- 152
        "uso: /ccam set <situation> <profile|none>",  -- 153
        "%s: nessuna modifica",  -- 154
        "'%s' forzato. /ccam auto torna alle situazioni.",  -- 155
        "La telecamera segue di nuovo le tue situazioni.",  -- 156
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 157
        "Usa /ccam curve per lo scostamento in base allo zoom.",  -- 158
        "uso: /ccam advanced [on|off]",  -- 159
        "La modifica avanzata è %s.",  -- 160
        "'%s' è tornato alle impostazioni originali.",  -- 161
        "Niente da ripristinare: '%s' non è stato modificato.",  -- 162
        "I profili integrati non possono essere eliminati.",  -- 163
        "Scostamento sopra la spalla specchiato.",  -- 164
        "Scostamento sopra la spalla tornato normale.",  -- 165
        "Le situazioni vengono mantenute per %.1f secondi dopo la fine.",  -- 166
        "uso: /ccam delay <seconds>",  -- 167
        "il pannello delle opzioni non è disponibile in questo client",  -- 168
        "comando sconosciuto '%s'. Digita /ccam help",  -- 169
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente. La prima voce, nessuna modifica, lascia la telecamera com'è.",  -- 170
        "Clic sinistro: profilo successivo. Clic destro: profilo precedente.",  -- 171
        "Premi Ctrl+C per copiare, poi Esc.",  -- 172
        "Incolla qui una stringa ControllerCam (Ctrl+V), poi premi Importa.",  -- 173
        "Profili della telecamera per giocare con il controller. Scegli come si comporta la telecamera in ogni situazione. Clic sinistro su un profilo per il successivo, clic destro per il precedente.",  -- 174
        "Attiva o disattiva il controllo della telecamera. Quando è disattivato, le impostazioni originali della telecamera vengono ripristinate.",  -- 175
        "Telecamera Azione con profili più calmi per città, cavalcature, volo e raid.",  -- 176
        "Evita che la telecamera sfarfalli tra i profili quando una situazione si attiva e disattiva rapidamente.",  -- 177
        "Cambia la spalla sopra la quale guarda la telecamera.",  -- 178
        "Usa questo profilo in ogni situazione.",  -- 179
        "Crea una copia modificabile di questo profilo.",  -- 180
        "Salva le impostazioni attuali della telecamera come nuovo profilo.",  -- 181
        "Mostra una stringa da condividere.",  -- 182
        "Aggiunge un profilo da una stringa condivisa.",  -- 183
        "Elimina questo profilo personalizzato.",  -- 184
        "Riporta questo profilo integrato alle impostazioni originali.",  -- 185
        "Usa il valore predefinito del gioco per questa impostazione.",  -- 186
        "La modifica avanzata è attiva. Le modifiche a un profilo integrato vengono conservate; «Ripristina l'originale» lo riporta com'era.",  -- 187
        "A pesca",  -- 188
        "Al chiuso",  -- 189
        "Situazione sconosciuta. Usa una di:",  -- 190
        "scegliere il profilo per una situazione (/ccam mostra l'elenco)",  -- 191
        "lo spostamento sulla spalla nella forma attuale (forme del druido, lupo spettrale), in percentuale del normale",  -- 192
        "Non sei in nessuna forma.",  -- 193
        "Spostamento sulla spalla in questa forma: %d%%",  -- 194
        "uso: /ccam formoffset <percentuale> (o reset)",  -- 195
        "Il gioco chiederà di nuovo delle sue impostazioni sperimentali della telecamera al prossimo accesso.",  -- 196
        "Il gioco non chiederà più delle impostazioni sperimentali della telecamera (le hai accettate). /ccam notice riporta la domanda.",  -- 197
        "far chiedere di nuovo al gioco delle sue impostazioni sperimentali della telecamera al prossimo accesso",  -- 198
        "Con un nemico come bersaglio, la telecamera si avvicina a %.1f iarde.",  -- 199
        "La telecamera mantiene la distanza con un nemico come bersaglio.",  -- 200
        "uso: /ccam targetzoom <iarde> (0 o off: disattivo)",  -- 201
        "con un nemico come bersaglio, la telecamera si avvicina a questa distanza e poi torna indietro (0: disattivo)",  -- 202
        "Più vicino con un nemico come bersaglio: %.1f iarde",  -- 203
        "Più vicino con un nemico come bersaglio: disattivo",  -- 204
        "Prendi di mira un nemico e la telecamera si avvicina a questa distanza; lascialo e torna dov'era (non in sella). Esplora da lontano, combatti da vicino.",  -- 205
        "ControllerCam: come ti muovi",  -- 206
        "I profili della visuale possono anche impostare come il personaggio si orienta e si gira mentre si muove, e quanto velocemente lo stick gira la visuale. Lasciarli fare o tenere le tue impostazioni?",  -- 207
        "Ora i profili impostano come ti muovi e la velocità dello stick (/ccam movement per cambiarlo).",  -- 208
        "Le tue impostazioni di movimento e dello stick restano invariate (/ccam movement per cambiarlo).",  -- 209
        "Lascia fare ai profili",  -- 210
        "Tieni i miei",  -- 211
        "I profili impostano anche movimento e velocità dello stick",  -- 212
        "Orientamento e rotazione mentre ti muovi, e le velocità della visuale dello stick, impostati da ogni profilo. Disattivato: le tue impostazioni, come le avevi.",  -- 213
        "Campo visivo in base allo zoom",  -- 214
        "Focus sul bersaglio in base allo zoom",  -- 215
        "La sensazione pronta all'uso: da vicino sopra la spalla, allontanando lo zoom torna dolcemente al centro, e da vicino si gira di più verso il bersaglio. Movimento della testa, e la telecamera segue dove corri.",  -- 216
        "usa un profilo ovunque (prova: recommended, action, classic)",  -- 217
        "l'intensità dello scostamento sulla spalla in ogni profilo, in percentuale del normale",  -- 218
        "uso: /ccam offset <percentuale> (da 0 a 200)",  -- 219
        "Intensità dello scostamento sulla spalla: %d%%",  -- 220
        "Selezione rapida:",  -- 221
        "Sposta la telecamera sopra la spalla più all'esterno o di nuovo verso il centro, in ogni profilo. Utile se la taglia del personaggio la fa apparire diversa.",  -- 222
        "Avanzate: mostra e modifica ogni impostazione",  -- 223
        "Mostra tutte le impostazioni, a gruppi, e permette di modificare anche i profili integrati. Le modifiche vengono conservate e «Ripristina l'originale» riporta l'originale.",  -- 224
        "Cambia lo scostamento con lo zoom",  -- 225
        "Quanto di lato a ogni distanza. La telecamera passa dolcemente da un valore al successivo.",  -- 226
        "Cambia il focus sul bersaglio con lo zoom",  -- 227
        "Quanta parte dell'intensità del focus sul bersaglio a ogni distanza. Disattivato: tutta, ovunque.",  -- 228
        "Cambia il campo visivo con lo zoom",  -- 229
        "Il campo visivo a ogni distanza, come parte del tuo. Disattivato: il tuo non viene toccato.",  -- 230
        "%s (da %s a %s iarde)",  -- 231
        "Ora sei a %.1f iarde: %s.",  -- 232
        "Coppie di distanza e valore, per esempio 0:2 8:2 20:0. Vuoto: non cambia con lo zoom. Premi Invio per applicare.",  -- 233
        "in base allo zoom",  -- 234
        "Questo gioco non ha un'impostazione del campo visivo modificabile dagli addon.",  -- 235
        "Le impostazioni non elencate usano il valore predefinito del gioco. Scegli un gruppo qui sotto per vederne le impostazioni.",  -- 236
        "Ai più bastano i profili pronti. Per modificarne uno, crea una copia o seleziona Avanzate per vedere ogni impostazione.",  -- 237
        "Si usa solo se lasci che i profili impostino come ti muovi (prima pagina di ControllerCam).",  -- 238
        "A che distanza si mette la telecamera quando subentra questo profilo.",  -- 239
        "Quanto puoi allontanare la telecamera. Più è alto, più va lontano.",  -- 240
        "I punti esatti dietro la tabella qui sopra, come distanza:parte. 1 è il tuo.",  -- 241
        "Quanto velocemente lo stick destro gira la telecamera.",  -- 242
        "Quanto velocemente lo stick destro guarda su e giù.",  -- 243
        "La telecamera si porta dietro di te mentre corri.",  -- 244
        "Quanto velocemente la telecamera si porta dietro di te.",  -- 245
        "Quanto velocemente la telecamera torna in piano.",  -- 246
        "Quanto aspetta la telecamera dopo che l'hai mossa tu.",  -- 247
        "0: il personaggio guarda dove corre. 180: resta rivolto in avanti e si sposta di lato.",  -- 248
        "La stessa scelta, mentre combatti.",  -- 249
        "Quando il personaggio si gira mentre giri la telecamera.",  -- 250
        "La cavalcatura si gira dove spingi lo stick.",  -- 251
        "Mentre nuoti, il personaggio si gira dove spingi lo stick.",  -- 252
        "Mentre voli, ti giri dove spingi lo stick.",  -- 253
        "Un solo scostamento a ogni distanza. 0 tiene il personaggio al centro.",  -- 254
        "I punti esatti dietro la tabella qui sopra, come distanza:scostamento.",  -- 255
        "Inclina la visuale con lo zoom per un'angolazione più bassa e cinematografica.",  -- 256
        "Quanto la telecamera si muove con la testa del personaggio. 0 lo disattiva.",  -- 257
        "Quanto di quel movimento quando sei fermo.",  -- 258
        "Quanto di quel movimento mentre corri.",  -- 259
        "Fino a che distanza la telecamera si muove ancora con la testa del personaggio.",  -- 260
        "La telecamera si gira verso il nemico che hai come bersaglio.",  -- 261
        "Con quanta forza gira a sinistra e a destra. 1 è il massimo.",  -- 262
        "Con quanta forza si inclina su e giù. 1 è il massimo.",  -- 263
        "I punti esatti dietro la tabella qui sopra, come distanza:parte. 1 è l'intensità piena.",  -- 264
        "La telecamera si gira verso chi stai parlando.",  -- 265
        "Con quanta forza gira a sinistra e a destra verso quella persona.",  -- 266
        "Con quanta forza si inclina su e giù verso quella persona.",  -- 267
        "Con mouse e tastiera: quando la telecamera torna dietro di te.",  -- 268
        "Inclina la telecamera con colline e pendii. La tua impostazione resta se qui non è definita.",  -- 269
        "A che distanza sta la telecamera e quanto puoi allontanarla.",  -- 270
        "Quanto la telecamera sta di lato, perché il personaggio non sia al centro dello schermo.",  -- 271
        "Quanto la telecamera si gira per guardare il bersaglio o chi stai parlando.",  -- 272
        "Quanto la telecamera accompagna la testa del personaggio.",  -- 273
        "Piccoli movimenti che la telecamera fa da sola.",  -- 274
        "Quanto velocemente lo stick muove la telecamera e se la telecamera segue dove corri.",  -- 275
        "Dove guarda il personaggio mentre si muove.",  -- 276
        "Prima persona",  -- 277
        "Sopra la spalla",  -- 278
        "Busto",  -- 279
        "Corpo intero",  -- 280
        "Media distanza",  -- 281
        "Zoom lontano",  -- 282
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
        "권장 설정",  -- 64
        "(변경 없음)",  -- 65
        "모든 곳에 사용",  -- 66
        "복사본 만들기",  -- 67
        "현재 카메라 저장",  -- 68
        "내보내기",  -- 69
        "가져오기",  -- 70
        "닫기",  -- 71
        "삭제",  -- 72
        "게임 기본값",  -- 73
        "기본값",  -- 74
        "내 프로필",  -- 75
        "복사본",  -- 76
        "강제",  -- 77
        "사용자 지정",  -- 78
        "변경 없음",  -- 79
        "현재",  -- 80
        "아직 적용 안 됨",  -- 81
        "현재: %s (%s)",  -- 82
        "현재: 아직 적용 안 됨",  -- 83
        "어깨 오프셋 반전 (반대쪽 어깨)",  -- 84
        "상황 종료 후 %.1f초 유지",  -- 85
        "명령어: /ccam help",  -- 86
        "상황별 프로필 (위에서부터 처음 해당하는 것이 적용됨):",  -- 87
        "완료.",  -- 88
        "어디서나 '%s'을(를) 사용합니다.",  -- 89
        "권장 설정을 적용했습니다.",  -- 90
        "'%s'(으)로 저장했습니다.",  -- 91
        "'%s'을(를) 삭제했습니다.",  -- 92
        "사용함",  -- 93
        "사용 안 함. 원래 카메라 설정을 복원했습니다.",  -- 94
        "'%s'을(를) 가져왔습니다. /ccam use \"%s\" 로 사용해 보세요.",  -- 95
        "ControllerCam 프로필 문자열이 아닙니다.",  -- 96
        "가져올 내용이 없습니다.",  -- 97
        "문자열이 너무 길어 프로필이 될 수 없습니다.",  -- 98
        "이 프로필은 더 최신 버전의 ControllerCam으로 만들어졌습니다. 애드온을 업데이트하세요.",  -- 99
        "문자열이 손상되었습니다(체크섬 불일치). 전체를 다시 복사하세요.",  -- 100
        "프로필 이름이 올바르지 않습니다.",  -- 101
        "가져올 수 없음: %s (%s).",  -- 102
        "값이 허용 범위를 벗어났습니다",  -- 103
        "값이 올바르지 않습니다",  -- 104
        "곡선이 올바르지 않습니다",  -- 105
        "이 버전이 모르는 설정이 있습니다",  -- 106
        "설치되었습니다. 액션 카메라가 켜져 있습니다. /ccam use hybrid 또는 /ccam use classic 을 시도해 보세요. /ccam help 로 전체 명령을 볼 수 있습니다.",  -- 107
        "%s도 로드되어 있습니다. 둘 다 카메라를 바꾸므로 서로 충돌합니다. 하나를 비활성화하세요.",  -- 108
        "카메라가 지형을 따라감",  -- 109
        "내 설정",  -- 110
        "원래대로 되돌리기",  -- 111
        "(편집됨)",  -- 112
        "나열되지 않은 모든 항목은 게임 기본값을 사용합니다.",  -- 113
        "클래식과 액션의 중간: 중간 거리, 약한 어깨 너머 오프셋, 부드러운 머리 추적. 카메라가 이동을 따라가면서도 넓은 시야를 유지합니다.",  -- 114
        "게임 기본 카메라: ControllerCam이 관리하는 모든 설정이 기본값으로 돌아갑니다. 카메라 거리와 지형 따라가기 설정은 그대로 둡니다.",  -- 115
        "3인칭 슈터 느낌: 가까운 카메라, 강한 어깨 너머 오프셋, 빠른 스틱 조준. 전투 밖에서는 이동 방향을 보고 달리고, 전투 중에는 카메라 방향을 보며 게걸음으로 움직입니다.",  -- 116
        "더 가깝고 안정적인 엄폐 슈터용 설정: 캐릭터가 항상 카메라와 함께 회전하고, 어깨 너머 오프셋이 크며, 카메라가 저절로 움직이지 않습니다.",  -- 117
        "느리고 넓고 분위기 있는 설정, 퀘스트와 스크린샷용: 동적 피치, 강한 머리 추적, 대화 상대 쪽으로 향하는 카메라.",  -- 118
        "카메라가 현재 대상과 대화 중인 NPC 쪽으로 기울어집니다. 단일 대상 전투에 좋습니다.",  -- 119
        "던전과 공격대용 먼 거리의 안정적인 카메라: 오프셋 없음, 머리 추적 없음, 카메라 흔들림 없음, 빠른 스틱 회전으로 전투 전체를 볼 수 있습니다.",  -- 120
        "탈것용: 방향을 틀 때 뒤로 따라 돌아오는 먼 카메라. 크기가 다른 탈것에서는 오프셋이 불안정해 꺼져 있습니다.",  -- 121
        "비행용: 상승과 하강을 따라가는 먼 카메라.",  -- 122
        "도시용 여유롭고 느린 카메라: 더 가깝고 차분하며 머리 추적이 있습니다.",  -- 123
        "사용자 지정 프로필. 프로필 편집기에서 복제하거나 편집하세요.",  -- 124
        "상태 표시",  -- 125
        "프로필 목록",  -- 126
        "프로필의 느낌과 바꾸는 모든 설정",  -- 127
        "권장 설정: 도시, 탈것, 비행, 공격대에는 더 차분한 프로필을 쓰는 액션 카메라",  -- 128
        "상황과 관계없이 지금 프로필 사용",  -- 129
        "프로필 강제 사용 해제",  -- 130
        "현재 카메라 설정을 새 프로필로 저장",  -- 131
        "프로필의 편집 가능한 복사본 만들기",  -- 132
        "사용자 지정 프로필의 설정 변경 (/ccam settings 로 목록 확인)",  -- 133
        "카메라 거리에 따른 어깨 너머 오프셋, 예: /ccam curve mine 0:2 8:2 20:0",  -- 134
        "기본 제공 프로필도 편집 허용 (/ccam reset <profile> 로 원래대로 복원)",  -- 135
        "편집한 기본 제공 프로필을 원래 설정으로 되돌리기",  -- 136
        "사용자 지정 프로필 삭제",  -- 137
        "공유할 수 있는 문자열 표시",  -- 138
        "공유된 문자열에서 프로필 추가",  -- 139
        "어깨 오프셋을 반대쪽 어깨로 전환",  -- 140
        "상황이 끝난 뒤 유지되는 시간 (기본 1.5)",  -- 141
        "켜기, 또는 끄고 원래 카메라 설정 복원",  -- 142
        "현재 줌, 어깨 오프셋, 모션 설정 표시 (문제 해결용)",  -- 143
        "설정 창 열기 (설정 > 애드온 > ControllerCam)",  -- 144
        "이 목록 표시",  -- 145
        "'%s'은(는) 여러 프로필과 일치합니다. 이름을 더 입력하세요.",  -- 146
        "'%s'(이)라는 프로필이 없습니다. /ccam list 로 확인하세요.",  -- 147
        "컨트롤러 플레이를 위한 카메라 프로필. 설치하면 바로 액션 카메라를 쓰고, 하이브리드와 클래식은 명령어 한 번이면 됩니다.",  -- 148
        "기본 제공 프로필은 잠겨 있습니다. 고급 편집을 켜거나(/ccam advanced on) 복사본을 만드세요: /ccam copy <profile>",  -- 149
        "알 수 없는 설정입니다. /ccam settings 로 목록을 확인하세요.",  -- 150
        "그 값은 허용 범위를 벗어났습니다.",  -- 151
        "그 값이 올바르지 않습니다.",  -- 152
        "사용법: /ccam set <situation> <profile|none>",  -- 153
        "%s: 변경 없음",  -- 154
        "'%s'을(를) 강제 사용합니다. /ccam auto 로 상황별 설정으로 돌아갑니다.",  -- 155
        "카메라가 다시 상황에 따라 바뀝니다.",  -- 156
        "사용법: /ccam edit <profile> <setting> <value|default>",  -- 157
        "줌에 따른 오프셋은 /ccam curve 를 사용하세요.",  -- 158
        "사용법: /ccam advanced [on|off]",  -- 159
        "고급 편집: %s.",  -- 160
        "'%s'이(가) 원래 설정으로 돌아갔습니다.",  -- 161
        "되돌릴 내용 없음: '%s'은(는) 편집되지 않았습니다.",  -- 162
        "기본 제공 프로필은 삭제할 수 없습니다.",  -- 163
        "어깨 오프셋이 반전되었습니다.",  -- 164
        "어깨 오프셋이 원래대로 돌아왔습니다.",  -- 165
        "상황은 종료 후 %.1f초 동안 유지됩니다.",  -- 166
        "사용법: /ccam delay <seconds>",  -- 167
        "이 클라이언트에서는 설정 창을 사용할 수 없습니다",  -- 168
        "알 수 없는 명령어 '%s'. /ccam help 를 입력하세요",  -- 169
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필. 첫 항목인 변경 없음은 카메라를 그대로 둡니다.",  -- 170
        "좌클릭: 다음 프로필. 우클릭: 이전 프로필.",  -- 171
        "Ctrl+C로 복사한 뒤 Esc를 누르세요.",  -- 172
        "여기에 ControllerCam 문자열을 붙여넣고(Ctrl+V) 가져오기를 누르세요.",  -- 173
        "컨트롤러 플레이를 위한 카메라 프로필. 각 상황에서 카메라가 어떤 느낌일지 고르세요. 프로필을 좌클릭하면 다음, 우클릭하면 이전 프로필로 바뀝니다.",  -- 174
        "카메라 제어를 켜거나 끕니다. 끄면 원래 카메라 설정이 복원됩니다.",  -- 175
        "도시, 탈것, 비행, 공격대에는 더 차분한 프로필을 쓰는 액션 카메라.",  -- 176
        "상황이 빠르게 켜지고 꺼질 때 카메라가 프로필 사이를 깜빡이며 오가는 것을 막습니다.",  -- 177
        "카메라가 넘겨다보는 어깨를 바꿉니다.",  -- 178
        "모든 상황에서 이 프로필을 사용합니다.",  -- 179
        "이 프로필의 편집 가능한 복사본을 만듭니다.",  -- 180
        "현재 카메라 설정을 새 프로필로 저장합니다.",  -- 181
        "공유할 수 있는 문자열을 표시합니다.",  -- 182
        "공유된 문자열에서 프로필을 추가합니다.",  -- 183
        "이 사용자 지정 프로필을 삭제합니다.",  -- 184
        "이 기본 제공 프로필을 원래 설정으로 되돌립니다.",  -- 185
        "이 설정에 게임 기본값을 사용합니다.",  -- 186
        "고급 편집이 켜져 있습니다. 기본 제공 프로필의 변경 사항은 유지되며 \"원래대로 되돌리기\"로 복원할 수 있습니다.",  -- 187
        "낚시 중",  -- 188
        "실내",  -- 189
        "알 수 없는 상황입니다. 다음 중 하나를 사용하세요:",  -- 190
        "한 상황에 사용할 프로필 선택 (/ccam 으로 목록 표시)",  -- 191
        "현재 변신 상태(드루이드 변신, 늑대 정령)의 어깨 시점 이동, 기본값 대비 퍼센트",  -- 192
        "변신 상태가 아닙니다.",  -- 193
        "이 변신 상태의 어깨 시점 이동: %d%%",  -- 194
        "사용법: /ccam formoffset <퍼센트> (또는 reset)",  -- 195
        "다음 접속 시 게임이 실험적 카메라 설정에 대해 다시 묻습니다.",  -- 196
        "게임이 더 이상 실험적 카메라 설정에 대해 묻지 않습니다 (수락했습니다). /ccam notice 로 질문을 다시 받을 수 있습니다.",  -- 197
        "다음 접속 시 게임이 실험적 카메라 설정에 대해 다시 묻게 합니다",  -- 198
        "적을 대상으로 잡으면 카메라가 %.1f야드까지 다가옵니다.",  -- 199
        "적을 대상으로 잡아도 카메라 거리가 그대로입니다.",  -- 200
        "사용법: /ccam targetzoom <야드> (0 또는 off: 끔)",  -- 201
        "적을 대상으로 잡으면 카메라가 이만큼 다가왔다가 다시 물러납니다 (0: 끔)",  -- 202
        "적 대상 시 가까이: %.1f야드",  -- 203
        "적 대상 시 가까이: 끔",  -- 204
        "적을 대상으로 잡으면 카메라가 이 거리까지 다가오고, 놓으면 원래 위치로 돌아갑니다 (탈것 탑승 중 제외). 멀리서 둘러보고, 가까이서 싸우세요.",  -- 205
        "ControllerCam: 이동 방식",  -- 206
        "카메라 프로필은 이동할 때 캐릭터가 바라보고 회전하는 방식과 스틱이 카메라를 돌리는 속도도 설정할 수 있습니다. 프로필에 맡길까요, 아니면 지금 설정을 유지할까요?",  -- 207
        "이제 프로필이 이동 방식과 스틱 속도를 설정합니다 (/ccam movement로 변경).",  -- 208
        "이동 및 스틱 설정은 지금 그대로 유지됩니다 (/ccam movement로 변경).",  -- 209
        "프로필에 맡기기",  -- 210
        "내 설정 유지",  -- 211
        "프로필이 이동 방식과 스틱 속도도 설정",  -- 212
        "이동할 때의 방향과 회전, 스틱의 카메라 속도를 각 프로필이 설정합니다. 끄면: 원래 쓰던 내 설정 그대로.",  -- 213
        "확대/축소별 시야각",  -- 214
        "확대/축소별 대상 집중",  -- 215
        "설치 즉시 쓰는 느낌: 가까이에서는 어깨 너머로, 멀어질수록 부드럽게 가운데로 돌아오며, 가까울 때 대상 쪽으로 가장 많이 돌아갑니다. 머리 추적이 켜지고 카메라가 달리는 방향을 따라갑니다.",  -- 216
        "모든 곳에 프로필 하나 사용 (예: recommended, action, classic)",  -- 217
        "모든 프로필의 어깨 오프셋 강도 (기본의 백분율)",  -- 218
        "사용법: /ccam offset <퍼센트> (0~200)",  -- 219
        "어깨 오프셋 강도: %d%%",  -- 220
        "빠른 선택:",  -- 221
        "모든 프로필에서 어깨 너머 카메라를 더 바깥으로 보내거나 가운데로 되돌립니다. 캐릭터 크기 때문에 위치가 다르게 보일 때 유용합니다.",  -- 222
        "고급: 모든 설정 보기 및 편집",  -- 223
        "모든 설정을 묶음별로 보여 주고 기본 제공 프로필도 변경할 수 있게 합니다. 변경 사항은 유지되며 \"원래대로 되돌리기\"로 원본을 복원할 수 있습니다.",  -- 224
        "확대/축소에 따라 오프셋 바꾸기",  -- 225
        "거리별로 옆으로 치우치는 정도입니다. 카메라는 한 값에서 다음 값으로 부드럽게 넘어갑니다.",  -- 226
        "확대/축소에 따라 대상 집중 바꾸기",  -- 227
        "거리별로 대상 집중 강도를 얼마나 쓸지 정합니다. 끄면 어디서나 전부 씁니다.",  -- 228
        "확대/축소에 따라 시야각 바꾸기",  -- 229
        "거리별 시야각을 내 시야각에 대한 비율로 정합니다. 끄면 내 설정을 그대로 둡니다.",  -- 230
        "%s (%s~%s야드)",  -- 231
        "지금 거리는 %.1f야드입니다: %s.",  -- 232
        "거리와 값의 쌍, 예: 0:2 8:2 20:0. 비워 두면 확대/축소를 따르지 않습니다. Enter를 눌러 적용하세요.",  -- 233
        "확대/축소별",  -- 234
        "이 게임에는 애드온이 바꿀 수 있는 시야각 설정이 없습니다.",  -- 235
        "나열되지 않은 설정은 게임 기본값을 사용합니다. 아래에서 묶음을 고르면 해당 설정이 보입니다.",  -- 236
        "대부분은 기본 프로필이면 충분합니다. 바꾸려면 복사본을 만들거나 고급을 체크해 모든 설정을 확인하세요.",  -- 237
        "프로필이 이동 방식을 설정하도록 허용해야 적용됩니다 (ControllerCam 첫 페이지).",  -- 238
        "이 프로필이 적용될 때 카메라가 놓이는 거리입니다.",  -- 239
        "카메라를 얼마나 멀리 뺄 수 있는지 정합니다. 높을수록 멀어집니다.",  -- 240
        "위 표의 정확한 값입니다 (거리:비율). 1은 내 시야각입니다.",  -- 241
        "오른쪽 스틱이 카메라를 돌리는 속도입니다.",  -- 242
        "오른쪽 스틱으로 위아래를 보는 속도입니다.",  -- 243
        "달리면 카메라가 뒤로 돌아옵니다.",  -- 244
        "카메라가 뒤로 돌아오는 속도입니다.",  -- 245
        "카메라가 다시 수평으로 돌아오는 속도입니다.",  -- 246
        "직접 카메라를 움직인 뒤 카메라가 기다리는 시간입니다.",  -- 247
        "0: 캐릭터가 달리는 방향을 바라봅니다. 180: 계속 앞을 보며 옆걸음으로 움직입니다.",  -- 248
        "전투 중에 적용되는 같은 설정입니다.",  -- 249
        "카메라를 돌릴 때 캐릭터가 함께 도는 조건입니다.",  -- 250
        "탈것이 스틱을 미는 방향을 바라봅니다.",  -- 251
        "수영할 때 캐릭터가 스틱을 미는 방향을 바라봅니다.",  -- 252
        "비행할 때 스틱을 미는 방향을 바라봅니다.",  -- 253
        "모든 거리에 같은 오프셋을 씁니다. 0이면 캐릭터가 가운데에 있습니다.",  -- 254
        "위 표의 정확한 값입니다 (거리:오프셋).",  -- 255
        "확대/축소에 따라 시점을 기울여 낮고 영화 같은 각도를 만듭니다.",  -- 256
        "카메라가 캐릭터의 머리를 따라 움직이는 정도입니다. 0은 끔입니다.",  -- 257
        "가만히 서 있을 때 그 움직임의 크기입니다.",  -- 258
        "달릴 때 그 움직임의 크기입니다.",  -- 259
        "카메라가 캐릭터의 머리를 따라 움직이는 최대 거리 범위입니다.",  -- 260
        "대상으로 잡은 적 쪽으로 카메라가 돌아갑니다.",  -- 261
        "좌우로 돌아가는 힘입니다. 1이 가장 강합니다.",  -- 262
        "위아래로 기울어지는 힘입니다. 1이 가장 강합니다.",  -- 263
        "위 표의 정확한 값입니다 (거리:비율). 1은 최대 강도입니다.",  -- 264
        "대화 중인 상대 쪽으로 카메라가 돌아갑니다.",  -- 265
        "상대를 향해 좌우로 돌아가는 힘입니다.",  -- 266
        "상대를 향해 위아래로 기울어지는 힘입니다.",  -- 267
        "마우스와 키보드 사용 시: 카메라가 뒤로 돌아오는 때입니다.",  -- 268
        "언덕과 경사에 따라 카메라를 기울입니다. 여기서 정하지 않으면 내 설정이 유지됩니다.",  -- 269
        "카메라 거리와 최대로 뺄 수 있는 범위입니다.",  -- 270
        "캐릭터가 화면 가운데에 오지 않도록 카메라를 옆으로 두는 정도입니다.",  -- 271
        "카메라가 대상이나 대화 상대를 보려고 돌아가는 정도입니다.",  -- 272
        "카메라가 캐릭터의 머리를 따라 움직이는 정도입니다.",  -- 273
        "카메라가 스스로 하는 작은 움직임입니다.",  -- 274
        "스틱이 카메라를 움직이는 속도와 카메라가 달리는 방향을 따라갈지 정합니다.",  -- 275
        "이동할 때 캐릭터가 바라보는 방향입니다.",  -- 276
        "1인칭",  -- 277
        "어깨 너머",  -- 278
        "상반신",  -- 279
        "전신",  -- 280
        "중거리",  -- 281
        "최대한 멀리",  -- 282
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
        "Configuração recomendada",  -- 64
        "(sem alteração)",  -- 65
        "Usar em todo lugar",  -- 66
        "Fazer uma cópia",  -- 67
        "Salvar minha câmera atual",  -- 68
        "Exportar",  -- 69
        "Importar",  -- 70
        "Fechar",  -- 71
        "Excluir",  -- 72
        "padrão do jogo",  -- 73
        "Padrão",  -- 74
        "Meu perfil",  -- 75
        "cópia",  -- 76
        "forçado",  -- 77
        "personalizado",  -- 78
        "sem alteração",  -- 79
        "atual",  -- 80
        "nada aplicado ainda",  -- 81
        "Agora: %s (%s)",  -- 82
        "Agora: nada aplicado ainda",  -- 83
        "Espelhar o deslocamento (outro ombro)",  -- 84
        "Manter uma situação por %.1f s após o fim",  -- 85
        "Comandos: /ccam help",  -- 86
        "Perfil para cada situação (vale a primeira que se aplica, de cima para baixo):",  -- 87
        "Pronto.",  -- 88
        "Usando '%s' em todo lugar.",  -- 89
        "Configuração recomendada aplicada.",  -- 90
        "Salvo como '%s'.",  -- 91
        "'%s' excluído.",  -- 92
        "ativado",  -- 93
        "desativado. Suas configurações originais de câmera foram restauradas.",  -- 94
        "'%s' importado. Experimente com /ccam use \"%s\".",  -- 95
        "Isso não é uma sequência de perfil do ControllerCam.",  -- 96
        "Nada para importar.",  -- 97
        "A sequência é longa demais para ser um perfil.",  -- 98
        "Este perfil foi criado com uma versão mais nova do ControllerCam. Atualize o addon.",  -- 99
        "A sequência está danificada (checksum não confere). Copie-a novamente, por completo.",  -- 100
        "O perfil não tem um nome válido.",  -- 101
        "Não é possível importar: %s (%s).",  -- 102
        "um valor está fora do intervalo permitido",  -- 103
        "um valor não é válido",  -- 104
        "uma curva não é válida",  -- 105
        "contém uma configuração que esta versão não conhece",  -- 106
        "Instalado. A câmera Ação está ativa. Experimente /ccam use hybrid ou /ccam use classic; /ccam help lista tudo.",  -- 107
        "%s também está carregado. Os dois alteram a câmera e vão conflitar. Desative um deles.",  -- 108
        "A câmera segue o terreno",  -- 109
        "sua configuração",  -- 110
        "Restaurar o original",  -- 111
        "(editado)",  -- 112
        "Tudo que não está listado usa o padrão do jogo.",  -- 113
        "Entre Clássico e Ação: distância média, um leve deslocamento sobre o ombro e rastreamento suave da cabeça. A câmera segue seu movimento, mas você mantém uma visão ampla.",  -- 114
        "A câmera original do jogo: todas as configurações gerenciadas pelo ControllerCam voltam ao padrão. Sua distância de câmera e sua configuração de seguir o terreno não são alteradas.",  -- 115
        "Sensação de tiro em terceira pessoa: câmera fechada, forte deslocamento sobre o ombro, mira rápida com o analógico. Fora de combate você corre olhando na direção do movimento; em combate você se desloca lateralmente olhando para a câmera.",  -- 116
        "Ainda mais perto e estável, para jogo de tiro com cobertura: seu personagem sempre gira com a câmera, o deslocamento sobre o ombro é grande e a câmera não se move sozinha.",  -- 117
        "Lenta, ampla e atmosférica, para missões e capturas de tela: inclinação dinâmica, forte rastreamento da cabeça e uma câmera que se vira para quem você conversa.",  -- 118
        "A câmera se inclina para o alvo atual e para os NPCs com quem você fala. Boa para lutas contra um único alvo.",  -- 119
        "Uma câmera distante e estável para masmorras e raides: sem deslocamento, sem rastreamento da cabeça, sem deriva e com giro rápido do analógico para ver toda a luta.",  -- 120
        "Para cavalgar: uma câmera distante que gira atrás de você ao conduzir. O deslocamento fica desligado porque montarias de tamanhos diferentes o tornam pouco confiável.",  -- 121
        "Para voar: uma câmera distante que acompanha suas subidas e mergulhos.",  -- 122
        "Uma câmera relaxada e mais lenta para cidades: mais próxima, calma e com rastreamento da cabeça.",  -- 123
        "Perfil personalizado. Duplique ou edite no editor de perfis.",  -- 124
        "mostrar o status",  -- 125
        "listar os perfis",  -- 126
        "como um perfil se comporta e todas as configurações que ele altera",  -- 127
        "a configuração recomendada: câmera de Ação com perfis mais calmos para cidades, montarias, voo e raides",  -- 128
        "usar um perfil agora, qualquer que seja a situação",  -- 129
        "parar de forçar um perfil",  -- 130
        "salvar suas configurações atuais de câmera como um novo perfil",  -- 131
        "fazer uma cópia editável de um perfil",  -- 132
        "alterar uma configuração de um perfil personalizado (/ccam settings lista todas)",  -- 133
        "deslocamento sobre o ombro por distância da câmera, ex.: /ccam curve mine 0:2 8:2 20:0",  -- 134
        "permitir editar também os perfis integrados (/ccam reset <profile> restaura o original)",  -- 135
        "devolver um perfil integrado editado às configurações originais",  -- 136
        "excluir um perfil personalizado",  -- 137
        "mostrar uma sequência que você pode compartilhar",  -- 138
        "adicionar um perfil a partir de uma sequência compartilhada",  -- 139
        "trocar o deslocamento para o outro ombro",  -- 140
        "por quanto tempo uma situação é mantida após o fim (padrão 1,5)",  -- 141
        "ligar, ou desligar e restaurar suas configurações originais de câmera",  -- 142
        "mostrar agora o zoom, o deslocamento e as configurações de movimento (para diagnóstico)",  -- 143
        "abrir o painel de opções (Opções > AddOns > ControllerCam)",  -- 144
        "mostrar esta lista",  -- 145
        "'%s' corresponde a mais de um perfil. Digite mais do nome.",  -- 146
        "Não há perfil chamado '%s'. /ccam list mostra todos.",  -- 147
        "Perfis de câmera para jogar com controle. Logo de início você tem uma câmera de Ação; Híbrido e Clássico estão a um comando.",  -- 148
        "Os perfis integrados estão bloqueados. Ative a edição avançada (/ccam advanced on) ou faça uma cópia: /ccam copy <profile>",  -- 149
        "Configuração desconhecida. /ccam settings lista todas.",  -- 150
        "Esse valor está fora do intervalo permitido.",  -- 151
        "Esse valor não é válido.",  -- 152
        "uso: /ccam set <situation> <profile|none>",  -- 153
        "%s: sem alteração",  -- 154
        "Forçando '%s'. /ccam auto volta às situações.",  -- 155
        "A câmera volta a seguir suas situações.",  -- 156
        "uso: /ccam edit <profile> <setting> <value|default>",  -- 157
        "Use /ccam curve para o deslocamento por zoom.",  -- 158
        "uso: /ccam advanced [on|off]",  -- 159
        "A edição avançada está %s.",  -- 160
        "'%s' voltou às configurações originais.",  -- 161
        "Nada para restaurar: '%s' não foi editado.",  -- 162
        "Os perfis integrados não podem ser excluídos.",  -- 163
        "Deslocamento sobre o ombro espelhado.",  -- 164
        "Deslocamento sobre o ombro de volta ao normal.",  -- 165
        "As situações são mantidas por %.1f segundos após o fim.",  -- 166
        "uso: /ccam delay <seconds>",  -- 167
        "o painel de opções não está disponível neste cliente",  -- 168
        "comando desconhecido '%s'. Digite /ccam help",  -- 169
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior. A primeira entrada, sem alteração, deixa a câmera como está.",  -- 170
        "Clique esquerdo: próximo perfil. Clique direito: perfil anterior.",  -- 171
        "Pressione Ctrl+C para copiar e depois Esc.",  -- 172
        "Cole aqui uma sequência do ControllerCam (Ctrl+V) e pressione Importar.",  -- 173
        "Perfis de câmera para jogar com controle. Escolha como a câmera se comporta em cada situação. Clique esquerdo em um perfil vai para o próximo; clique direito, para o anterior.",  -- 174
        "Liga ou desliga o controle da câmera. Desligado, suas configurações originais de câmera são restauradas.",  -- 175
        "Câmera de Ação com perfis mais calmos para cidades, montarias, voo e raides.",  -- 176
        "Evita que a câmera fique alternando entre perfis quando uma situação liga e desliga rapidamente.",  -- 177
        "Troca o ombro sobre o qual a câmera olha.",  -- 178
        "Usa este perfil em todas as situações.",  -- 179
        "Cria uma cópia editável deste perfil.",  -- 180
        "Salva as configurações atuais de câmera como um novo perfil.",  -- 181
        "Mostra uma sequência que você pode compartilhar.",  -- 182
        "Adiciona um perfil a partir de uma sequência compartilhada.",  -- 183
        "Exclui este perfil personalizado.",  -- 184
        "Devolve este perfil integrado às configurações originais.",  -- 185
        "Usar o padrão do jogo para esta configuração.",  -- 186
        "A edição avançada está ativada. As alterações em um perfil integrado são mantidas; «Restaurar o original» o recupera.",  -- 187
        "Pescando",  -- 188
        "Em ambientes internos",  -- 189
        "Situação desconhecida. Use uma destas:",  -- 190
        "escolher o perfil para uma situação (/ccam mostra a lista)",  -- 191
        "o deslocamento de ombro na forma em que você está (formas de druida, lobo fantasma), em porcentagem do normal",  -- 192
        "Você não está em nenhuma forma.",  -- 193
        "Deslocamento de ombro nesta forma: %d%%",  -- 194
        "uso: /ccam formoffset <porcentagem> (ou reset)",  -- 195
        "O jogo perguntará novamente sobre suas configurações experimentais de câmera no próximo login.",  -- 196
        "O jogo não perguntará mais sobre as configurações experimentais de câmera (você as aceitou). /ccam notice traz a pergunta de volta.",  -- 197
        "fazer o jogo perguntar novamente sobre suas configurações experimentais de câmera no próximo login",  -- 198
        "Com um inimigo como alvo, a câmera se aproxima a %.1f jardas.",  -- 199
        "A câmera mantém a distância com um inimigo como alvo.",  -- 200
        "uso: /ccam targetzoom <jardas> (0 ou off: desligado)",  -- 201
        "com um inimigo como alvo, a câmera se aproxima a esta distância e depois volta (0: desligado)",  -- 202
        "Mais perto com um inimigo como alvo: %.1f jardas",  -- 203
        "Mais perto com um inimigo como alvo: desligado",  -- 204
        "Mire um inimigo e a câmera se aproxima a esta distância; solte-o e ela volta para onde estava (não montado). Explore de longe, lute de perto.",  -- 205
        "ControllerCam: como você se move",  -- 206
        "Os perfis de câmera também podem definir como seu personagem se vira e gira ao se mover, e a velocidade com que o analógico gira a câmera. Deixar que façam isso, ou manter suas próprias configurações?",  -- 207
        "Agora os perfis definem como você se move e a velocidade do analógico (/ccam movement para mudar).",  -- 208
        "Suas próprias configurações de movimento e do analógico são mantidas (/ccam movement para mudar).",  -- 209
        "Deixar os perfis definirem",  -- 210
        "Manter os meus",  -- 211
        "Os perfis também definem o movimento e a velocidade do analógico",  -- 212
        "A orientação e o giro ao se mover, e as velocidades de câmera do analógico, definidos por cada perfil. Desligado: suas próprias configurações, como você as tinha.",  -- 213
        "Campo de visão por zoom",  -- 214
        "Foco no alvo por zoom",  -- 215
        "A sensação pronta para usar: de perto, sobre o ombro; ao afastar o zoom, volta suavemente ao centro, e é de perto que mais se vira para o seu alvo. Com rastreamento da cabeça, e a câmera segue para onde você corre.",  -- 216
        "usar um perfil em todo lugar (experimente: recommended, action, classic)",  -- 217
        "a intensidade do deslocamento do ombro em todos os perfis, em porcentagem do normal",  -- 218
        "uso: /ccam offset <porcentagem> (0 a 200)",  -- 219
        "Intensidade do deslocamento do ombro: %d%%",  -- 220
        "Escolha rápida:",  -- 221
        "Afasta a câmera sobre o ombro ou a traz de volta ao centro, em todos os perfis. Útil se o tamanho do seu personagem a deixa diferente.",  -- 222
        "Avançado: ver e editar todas as configurações",  -- 223
        "Mostra todas as configurações, em grupos, e permite alterar também os perfis integrados. Suas alterações são mantidas e «Restaurar o original» traz o original de volta.",  -- 224
        "Mudar o deslocamento com o zoom",  -- 225
        "Quanto para o lado em cada distância. A câmera passa suavemente de um valor ao outro.",  -- 226
        "Mudar o foco no alvo com o zoom",  -- 227
        "Quanto da força do foco no alvo é usado em cada distância. Desligado: toda ela, em qualquer distância.",  -- 228
        "Mudar o campo de visão com o zoom",  -- 229
        "O campo de visão em cada distância, como parte do seu. Desligado: o seu não é alterado.",  -- 230
        "%s (de %s a %s jardas)",  -- 231
        "Você está a %.1f jardas agora: %s.",  -- 232
        "Pares de distância e valor, por exemplo 0:2 8:2 20:0. Vazio: não varia com o zoom. Pressione Enter para aplicar.",  -- 233
        "por zoom",  -- 234
        "Este jogo não tem uma configuração de campo de visão que os addons possam mudar.",  -- 235
        "As configurações não listadas usam o padrão do jogo. Escolha um grupo abaixo para ver as configurações dele.",  -- 236
        "Para a maioria, os perfis prontos bastam. Para mudar um, faça uma cópia ou marque Avançado para ver todas as configurações.",  -- 237
        "Só vale se você deixar os perfis definirem como você se move (primeira página do ControllerCam).",  -- 238
        "A que distância a câmera fica quando este perfil entra.",  -- 239
        "O quanto você pode afastar a câmera. Quanto maior, mais longe.",  -- 240
        "Os pontos exatos da tabela acima, como distância:parte. 1 é o seu.",  -- 241
        "A velocidade com que o analógico direito gira a câmera.",  -- 242
        "A velocidade com que o analógico direito olha para cima e para baixo.",  -- 243
        "A câmera vai para trás de você enquanto corre.",  -- 244
        "A rapidez com que a câmera vai para trás de você.",  -- 245
        "A rapidez com que a câmera volta a se nivelar.",  -- 246
        "Quanto a câmera espera depois que você mesmo a move.",  -- 247
        "0: seu personagem olha para onde corre. 180: continua olhando para a frente e anda de lado.",  -- 248
        "A mesma escolha, enquanto você está em combate.",  -- 249
        "Quando seu personagem gira junto ao girar a câmera.",  -- 250
        "Sua montaria se vira para onde você empurra o analógico.",  -- 251
        "Ao nadar, seu personagem se vira para onde você empurra o analógico.",  -- 252
        "Ao voar, você se vira para onde empurra o analógico.",  -- 253
        "Um só deslocamento em qualquer distância. 0 mantém seu personagem no centro.",  -- 254
        "Os pontos exatos da tabela acima, como distância:deslocamento.",  -- 255
        "Inclina a visão com o zoom, para um ângulo mais baixo e cinematográfico.",  -- 256
        "O quanto a câmera se move com a cabeça do personagem. 0 desliga.",  -- 257
        "Quanto desse movimento quando você está parado.",  -- 258
        "Quanto desse movimento enquanto você corre.",  -- 259
        "Até que distância a câmera ainda se move com a cabeça do personagem.",  -- 260
        "A câmera se vira para o inimigo que você tem como alvo.",  -- 261
        "Com quanta força ela gira para os lados. 1 é o mais forte.",  -- 262
        "Com quanta força ela se inclina para cima e para baixo. 1 é o mais forte.",  -- 263
        "Os pontos exatos da tabela acima, como distância:parte. 1 é a força total.",  -- 264
        "A câmera se vira para a pessoa com quem você está falando.",  -- 265
        "Com quanta força ela gira para os lados na direção dela.",  -- 266
        "Com quanta força ela se inclina para cima e para baixo na direção dela.",  -- 267
        "Com mouse e teclado: quando a câmera volta para trás de você.",  -- 268
        "Inclina a câmera com morros e ladeiras. A sua configuração é mantida se não for definida aqui.",  -- 269
        "A que distância a câmera fica e o quanto você pode afastá-la.",  -- 270
        "O quanto a câmera fica para o lado, para o personagem não ficar no meio da tela.",  -- 271
        "O quanto a câmera se vira para olhar o seu alvo ou a pessoa com quem você fala.",  -- 272
        "O quanto a câmera acompanha a cabeça do personagem.",  -- 273
        "Pequenos movimentos que a câmera faz sozinha.",  -- 274
        "A velocidade com que o analógico move a câmera e se ela segue para onde você corre.",  -- 275
        "Para onde seu personagem olha ao se mover.",  -- 276
        "Primeira pessoa",  -- 277
        "Sobre o ombro",  -- 278
        "Tronco",  -- 279
        "Corpo inteiro",  -- 280
        "Distância média",  -- 281
        "Afastado",  -- 282
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
        "Рекомендуемая настройка",  -- 64
        "(без изменений)",  -- 65
        "Использовать везде",  -- 66
        "Создать копию",  -- 67
        "Сохранить текущую камеру",  -- 68
        "Экспорт",  -- 69
        "Импорт",  -- 70
        "Закрыть",  -- 71
        "Удалить",  -- 72
        "по умолчанию",  -- 73
        "По умолч.",  -- 74
        "Мой профиль",  -- 75
        "копия",  -- 76
        "принудительно",  -- 77
        "свой",  -- 78
        "без изменений",  -- 79
        "сейчас",  -- 80
        "пока ничего не применено",  -- 81
        "Сейчас: %s (%s)",  -- 82
        "Сейчас: пока ничего не применено",  -- 83
        "Отразить смещение (другое плечо)",  -- 84
        "Удерживать ситуацию %.1f с после окончания",  -- 85
        "Команды: /ccam help",  -- 86
        "Профиль для каждой ситуации (применяется первая подходящая сверху):",  -- 87
        "Готово.",  -- 88
        "'%s' используется везде.",  -- 89
        "Рекомендуемая настройка применена.",  -- 90
        "Сохранено как '%s'.",  -- 91
        "'%s' удалён.",  -- 92
        "включено",  -- 93
        "отключено. Ваши исходные настройки камеры восстановлены.",  -- 94
        "'%s' импортирован. Попробуйте: /ccam use \"%s\".",  -- 95
        "Это не строка профиля ControllerCam.",  -- 96
        "Нечего импортировать.",  -- 97
        "Строка слишком длинная для профиля.",  -- 98
        "Этот профиль создан в более новой версии ControllerCam. Обновите аддон.",  -- 99
        "Строка повреждена (контрольная сумма не совпадает). Скопируйте её снова целиком.",  -- 100
        "У профиля нет допустимого имени.",  -- 101
        "Невозможно импортировать: %s (%s).",  -- 102
        "значение вне допустимого диапазона",  -- 103
        "недопустимое значение",  -- 104
        "недопустимая кривая",  -- 105
        "содержит неизвестную этой версии настройку",  -- 106
        "Установлено. Включена камера «Экшен». Попробуйте /ccam use hybrid или /ccam use classic; /ccam help покажет все команды.",  -- 107
        "%s тоже загружен. Оба меняют камеру и будут мешать друг другу. Отключите один из них.",  -- 108
        "Камера следует за рельефом",  -- 109
        "ваша настройка",  -- 110
        "Вернуть исходный",  -- 111
        "(изменён)",  -- 112
        "Все, что не указано, использует значения игры по умолчанию.",  -- 113
        "Золотая середина между «Классикой» и «Экшеном»: средняя дистанция, небольшое смещение за плечо и мягкое движение головы. Камера следует за движением, но обзор остаётся широким.",  -- 114
        "Родная камера игры: все настройки, которыми управляет ControllerCam, возвращаются к значениям по умолчанию. Дистанция камеры и ваша настройка слежения за рельефом не меняются.",  -- 115
        "Ощущения от шутера от третьего лица: тесная камера, сильное смещение за плечо, быстрое прицеливание стиком. Вне боя вы бежите лицом по ходу движения, в бою — перемещаетесь боком, глядя в сторону камеры.",  -- 116
        "Ещё ближе и стабильнее, для игры в стиле шутера с укрытиями: персонаж всегда поворачивается вместе с камерой, смещение за плечо большое, а камера не уплывает сама.",  -- 117
        "Медленная, широкая и атмосферная, для заданий и скриншотов: динамический наклон, сильное движение головы и камера, поворачивающаяся к собеседнику.",  -- 118
        "Камера наклоняется к текущей цели и к NPC, с которыми вы говорите. Хороша для боёв с одной целью.",  -- 119
        "Дальняя устойчивая камера для подземелий и рейдов: без смещения, без движения головы, без дрейфа и с быстрым поворотом стиком, чтобы видеть весь бой.",  -- 120
        "Для езды верхом: дальняя камера, которая разворачивается за вами при повороте. Смещение отключено, потому что у ездовых животных разный размер и оно работает ненадёжно.",  -- 121
        "Для полёта: дальняя камера, следующая за набором высоты и снижением.",  -- 122
        "Спокойная, более медленная камера для городов: ближе, плавная, с движением головы.",  -- 123
        "Пользовательский профиль. Дублируйте или изменяйте его в редакторе профилей.",  -- 124
        "показать состояние",  -- 125
        "список профилей",  -- 126
        "как ощущается профиль и все настройки, которые он меняет",  -- 127
        "рекомендуемая настройка: камера «Экшен» со спокойными профилями для городов, езды верхом, полёта и рейдов",  -- 128
        "использовать профиль сейчас, независимо от ситуации",  -- 129
        "прекратить принудительное использование профиля",  -- 130
        "сохранить текущие настройки камеры как новый профиль",  -- 131
        "создать редактируемую копию профиля",  -- 132
        "изменить настройку пользовательского профиля (/ccam settings покажет список)",  -- 133
        "смещение за плечо в зависимости от дистанции камеры, например /ccam curve mine 0:2 8:2 20:0",  -- 134
        "разрешить изменять и встроенные профили (/ccam reset <profile> вернёт исходный)",  -- 135
        "вернуть изменённый встроенный профиль к исходным настройкам",  -- 136
        "удалить пользовательский профиль",  -- 137
        "показать строку для обмена",  -- 138
        "добавить профиль из полученной строки",  -- 139
        "переключить смещение на другое плечо",  -- 140
        "как долго ситуация сохраняется после окончания (по умолчанию 1,5)",  -- 141
        "включить, либо выключить и восстановить исходные настройки камеры",  -- 142
        "показать текущий масштаб, смещение и настройки движения (для диагностики)",  -- 143
        "открыть окно настроек (Настройки > Модификации > ControllerCam)",  -- 144
        "показать этот список",  -- 145
        "'%s' подходит к нескольким профилям. Введите больше букв названия.",  -- 146
        "Профиль «%s» не найден. /ccam list покажет все профили.",  -- 147
        "Профили камеры для игры с геймпадом. Сразу доступна камера «Экшен»; «Гибрид» и «Классика» включаются одной командой.",  -- 148
        "Встроенные профили заблокированы. Включите расширенное редактирование (/ccam advanced on) или сделайте копию: /ccam copy <profile>",  -- 149
        "Неизвестная настройка. /ccam settings покажет список.",  -- 150
        "Значение вне допустимого диапазона.",  -- 151
        "Недопустимое значение.",  -- 152
        "использование: /ccam set <situation> <profile|none>",  -- 153
        "%s: без изменений",  -- 154
        "Принудительно используется «%s». /ccam auto возвращает ситуации.",  -- 155
        "Камера снова следует вашим ситуациям.",  -- 156
        "использование: /ccam edit <profile> <setting> <value|default>",  -- 157
        "Для смещения по масштабу используйте /ccam curve.",  -- 158
        "использование: /ccam advanced [on|off]",  -- 159
        "Расширенное редактирование: %s.",  -- 160
        "«%s» возвращён к исходным настройкам.",  -- 161
        "Нечего возвращать: «%s» не изменялся.",  -- 162
        "Встроенные профили нельзя удалить.",  -- 163
        "Смещение за плечо отражено.",  -- 164
        "Смещение за плечо снова обычное.",  -- 165
        "Ситуации сохраняются %.1f с после окончания.",  -- 166
        "использование: /ccam delay <seconds>",  -- 167
        "окно настроек недоступно в этом клиенте",  -- 168
        "неизвестная команда «%s». Введите /ccam help",  -- 169
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль. Первый пункт, без изменений, оставляет камеру как есть.",  -- 170
        "ЛКМ: следующий профиль. ПКМ: предыдущий профиль.",  -- 171
        "Нажмите Ctrl+C, чтобы скопировать, затем Esc.",  -- 172
        "Вставьте сюда строку ControllerCam (Ctrl+V) и нажмите «Импорт».",  -- 173
        "Профили камеры для игры с геймпадом. Выберите, как должна ощущаться камера в каждой ситуации. ЛКМ по профилю — следующий, ПКМ — предыдущий.",  -- 174
        "Включает и выключает управление камерой. При выключении исходные настройки камеры восстанавливаются.",  -- 175
        "Камера «Экшен» со спокойными профилями для городов, езды верхом, полёта и рейдов.",  -- 176
        "Не даёт камере метаться между профилями, когда ситуация быстро включается и выключается.",  -- 177
        "Меняет плечо, через которое смотрит камера.",  -- 178
        "Использовать этот профиль во всех ситуациях.",  -- 179
        "Создаёт редактируемую копию этого профиля.",  -- 180
        "Сохраняет текущие настройки камеры как новый профиль.",  -- 181
        "Показывает строку, которой можно поделиться.",  -- 182
        "Добавляет профиль из полученной строки.",  -- 183
        "Удаляет этот пользовательский профиль.",  -- 184
        "Возвращает этот встроенный профиль к исходным настройкам.",  -- 185
        "Использовать значение игры по умолчанию для этой настройки.",  -- 186
        "Расширенное редактирование включено. Изменения встроенного профиля сохраняются; «Вернуть исходный» восстанавливает оригинал.",  -- 187
        "Рыбалка",  -- 188
        "В помещении",  -- 189
        "Неизвестная ситуация. Используйте одну из:",  -- 190
        "выбрать профиль для одной ситуации (/ccam показывает список)",  -- 191
        "смещение камеры к плечу в текущем облике (облики друида, призрачный волк), в процентах от обычного",  -- 192
        "Вы не в облике.",  -- 193
        "Смещение к плечу в этом облике: %d%%",  -- 194
        "использование: /ccam formoffset <процент> (или reset)",  -- 195
        "При следующем входе игра снова спросит об экспериментальных настройках камеры.",  -- 196
        "Игра больше не будет спрашивать об экспериментальных настройках камеры (вы их приняли). /ccam notice возвращает вопрос.",  -- 197
        "игра снова спросит об экспериментальных настройках камеры при следующем входе",  -- 198
        "При враждебной цели камера приближается до %.1f ярдов.",  -- 199
        "При враждебной цели камера сохраняет расстояние.",  -- 200
        "использование: /ccam targetzoom <ярды> (0 или off: выкл.)",  -- 201
        "при враждебной цели камера приближается на это расстояние, а потом отходит обратно (0: выкл.)",  -- 202
        "Ближе при враждебной цели: %.1f ярда",  -- 203
        "Ближе при враждебной цели: выкл.",  -- 204
        "Возьмите врага в цель — камера приблизится на это расстояние; отпустите — вернётся туда, где была (не верхом). Исследуйте издалека, сражайтесь вблизи.",  -- 205
        "ControllerCam: как вы двигаетесь",  -- 206
        "Профили камеры также могут задавать, как персонаж поворачивается и разворачивается при движении и как быстро стик вращает камеру. Доверить это им или оставить ваши настройки?",  -- 207
        "Теперь профили задают, как вы двигаетесь, и скорость стика (/ccam movement, чтобы изменить).",  -- 208
        "Ваши настройки движения и стика сохранены (/ccam movement, чтобы изменить).",  -- 209
        "Пусть задают профили",  -- 210
        "Оставить мои",  -- 211
        "Профили задают также движение и скорость стика",  -- 212
        "Направление и повороты при движении, а также скорость камеры на стике задаются каждым профилем. Выкл.: ваши собственные настройки, как были.",  -- 213
        "Угол обзора по масштабу",  -- 214
        "Фокус на цели по масштабу",  -- 215
        "Ощущения «из коробки»: вблизи камера смотрит из-за плеча, при отдалении плавно возвращается к центру, а сильнее всего поворачивается к цели, когда вы рядом. Движение головы, и камера следует за вашим бегом.",  -- 216
        "один профиль везде (например: recommended, action, classic)",  -- 217
        "сила смещения за плечо во всех профилях, в процентах от обычной",  -- 218
        "использование: /ccam offset <проценты> (от 0 до 200)",  -- 219
        "Сила смещения за плечо: %d%%",  -- 220
        "Быстрый выбор:",  -- 221
        "Отодвигает камеру из-за плеча дальше или возвращает к центру во всех профилях. Удобно, если из-за размера персонажа она стоит иначе.",  -- 222
        "Дополнительно: показать и менять все настройки",  -- 223
        "Показывает все настройки по группам и позволяет изменять встроенные профили. Ваши изменения сохраняются, а «Вернуть исходный» восстанавливает оригинал.",  -- 224
        "Менять смещение вместе с масштабом",  -- 225
        "Насколько в сторону на каждом расстоянии. Камера плавно переходит от одного значения к другому.",  -- 226
        "Менять фокус на цели вместе с масштабом",  -- 227
        "Какая доля силы фокуса на цели действует на каждом расстоянии. Выкл.: везде полная сила.",  -- 228
        "Менять угол обзора вместе с масштабом",  -- 229
        "Угол обзора на каждом расстоянии как доля вашего. Выкл.: ваш не меняется.",  -- 230
        "%s (от %s до %s ярдов)",  -- 231
        "Сейчас вы на расстоянии %.1f ярда: %s.",  -- 232
        "Пары «расстояние : значение», например 0:2 8:2 20:0. Пусто — не зависит от масштаба. Нажмите Enter, чтобы применить.",  -- 233
        "по масштабу",  -- 234
        "В этой игре нет настройки угла обзора, которую могли бы менять модификации.",  -- 235
        "Не указанные настройки используют значения игры по умолчанию. Выберите группу ниже, чтобы увидеть её настройки.",  -- 236
        "Большинству хватает готовых профилей. Чтобы изменить один из них, сделайте копию или отметьте «Дополнительно», чтобы увидеть все настройки.",  -- 237
        "Действует только если вы разрешили профилям задавать, как вы двигаетесь (первая страница ControllerCam).",  -- 238
        "На каком расстоянии оказывается камера, когда включается этот профиль.",  -- 239
        "Насколько далеко можно отвести камеру. Чем больше, тем дальше.",  -- 240
        "Точные точки таблицы выше в виде «расстояние:доля». 1 — ваш собственный.",  -- 241
        "Как быстро правый стик поворачивает камеру.",  -- 242
        "Как быстро правый стик смотрит вверх и вниз.",  -- 243
        "Когда вы бежите, камера заходит вам за спину.",  -- 244
        "Как быстро камера заходит вам за спину.",  -- 245
        "Как быстро камера снова выравнивается.",  -- 246
        "Сколько камера ждёт после того, как вы сами её повернули.",  -- 247
        "0: персонаж смотрит туда, куда бежит. 180: смотрит вперёд и перемещается боком.",  -- 248
        "То же самое, пока вы в бою.",  -- 249
        "Когда персонаж поворачивается вместе с камерой.",  -- 250
        "Ездовое животное поворачивается туда, куда вы наклоняете стик.",  -- 251
        "Во время плавания персонаж поворачивается туда, куда вы наклоняете стик.",  -- 252
        "В полёте вы поворачиваетесь туда, куда наклоняете стик.",  -- 253
        "Одно смещение на всех расстояниях. 0 — персонаж по центру.",  -- 254
        "Точные точки таблицы выше в виде «расстояние:смещение».",  -- 255
        "Наклоняет вид при изменении масштаба — более низкий, кинематографичный ракурс.",  -- 256
        "Насколько камера движется вместе с головой персонажа. 0 — выкл.",  -- 257
        "Сколько этого движения, пока вы стоите.",  -- 258
        "Сколько этого движения на бегу.",  -- 259
        "До какого расстояния камера ещё движется вместе с головой персонажа.",  -- 260
        "Камера поворачивается к врагу, выбранному целью.",  -- 261
        "Насколько сильно она поворачивается влево и вправо. 1 — сильнее всего.",  -- 262
        "Насколько сильно она наклоняется вверх и вниз. 1 — сильнее всего.",  -- 263
        "Точные точки таблицы выше в виде «расстояние:доля». 1 — полная сила.",  -- 264
        "Камера поворачивается к тому, с кем вы говорите.",  -- 265
        "Насколько сильно она поворачивается к собеседнику влево и вправо.",  -- 266
        "Насколько сильно она наклоняется к собеседнику вверх и вниз.",  -- 267
        "С мышью и клавиатурой: когда камера возвращается вам за спину.",  -- 268
        "Наклоняет камеру на холмах и склонах. Если здесь не задано, остаётся ваша настройка.",  -- 269
        "Как далеко находится камера и насколько её можно отвести.",  -- 270
        "Насколько камера смещена в сторону, чтобы персонаж не был в центре экрана.",  -- 271
        "Насколько камера поворачивается к вашей цели или собеседнику.",  -- 272
        "Насколько камера следует за головой персонажа.",  -- 273
        "Небольшие движения, которые камера делает сама.",  -- 274
        "Как быстро стик двигает камеру и следует ли она за вашим бегом.",  -- 275
        "Куда смотрит персонаж при движении.",  -- 276
        "Вид от первого лица",  -- 277
        "Из-за плеча",  -- 278
        "По пояс",  -- 279
        "В полный рост",  -- 280
        "Средняя дистанция",  -- 281
        "Издалека",  -- 282
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
        "推荐设置",  -- 64
        "（不更改）",  -- 65
        "全部使用",  -- 66
        "创建副本",  -- 67
        "保存当前镜头",  -- 68
        "导出",  -- 69
        "导入",  -- 70
        "关闭",  -- 71
        "删除",  -- 72
        "游戏默认",  -- 73
        "默认",  -- 74
        "我的配置",  -- 75
        "副本",  -- 76
        "强制",  -- 77
        "自定义",  -- 78
        "不更改",  -- 79
        "当前",  -- 80
        "尚未应用",  -- 81
        "当前：%s（%s）",  -- 82
        "当前：尚未应用",  -- 83
        "镜像越肩偏移（另一侧肩膀）",  -- 84
        "情境结束后保持 %.1f 秒",  -- 85
        "命令：/ccam help",  -- 86
        "每种情境使用的配置（从上往下，第一个符合的生效）：",  -- 87
        "完成。",  -- 88
        "已在所有情境使用“%s”。",  -- 89
        "已应用推荐设置。",  -- 90
        "已保存为“%s”。",  -- 91
        "已删除“%s”。",  -- 92
        "已启用",  -- 93
        "已禁用。已还原你原来的镜头设置。",  -- 94
        "已导入“%s”。用 /ccam use \"%s\" 试试。",  -- 95
        "这不是 ControllerCam 配置字符串。",  -- 96
        "没有可导入的内容。",  -- 97
        "字符串太长，不是有效的配置。",  -- 98
        "此配置由更新版本的 ControllerCam 创建。请更新插件。",  -- 99
        "字符串已损坏（校验和不匹配）。请重新完整复制。",  -- 100
        "该配置没有有效的名称。",  -- 101
        "无法导入：%s（%s）。",  -- 102
        "有数值超出允许范围",  -- 103
        "有数值无效",  -- 104
        "有曲线无效",  -- 105
        "包含此版本不认识的设置",  -- 106
        "已安装。动作镜头已开启。试试 /ccam use hybrid 或 /ccam use classic，/ccam help 列出所有命令。",  -- 107
        "%s 也已加载。两者都会修改镜头，会互相冲突。请禁用其中一个。",  -- 108
        "镜头跟随地形",  -- 109
        "你的设置",  -- 110
        "恢复原始设置",  -- 111
        "（已编辑）",  -- 112
        "未列出的所有设置均使用游戏默认值。",  -- 113
        "介于经典和动作之间：中等距离、轻微的越肩偏移和柔和的头部追踪。镜头跟随你的移动，同时保持开阔的视野。",  -- 114
        "游戏自带镜头：ControllerCam 管理的所有设置恢复为默认值。镜头距离和你的地形跟随设置保持不变。",  -- 115
        "第三人称射击手感：紧凑的镜头、较大的越肩偏移、快速的摇杆瞄准。非战斗时面向移动方向奔跑，战斗中面向镜头方向横向移动。",  -- 116
        "更近更稳，适合掩体射击玩法：角色始终随镜头转动，越肩偏移较大，镜头不会自行漂移。",  -- 117
        "缓慢、开阔、富有氛围，适合做任务和截图：动态俯仰、强烈的头部追踪，镜头会转向你正在交谈的对象。",  -- 118
        "镜头会偏向你当前的目标和对话的NPC。适合单目标战斗。",  -- 119
        "适合地下城和团队副本的远距离稳定镜头：无偏移、无头部追踪、无镜头漂移，摇杆转向迅速，让你看清整场战斗。",  -- 120
        "骑乘专用：转向时镜头会摆到你身后的远距离镜头。越肩偏移已关闭，因为不同体型的坐骑会让它不可靠。",  -- 121
        "飞行专用：跟随你爬升和俯冲的远距离镜头。",  -- 122
        "适合城市的悠闲慢速镜头：更近、更平稳，并带有头部追踪。",  -- 123
        "自定义配置。可在配置编辑器中复制或编辑。",  -- 124
        "显示状态",  -- 125
        "列出配置",  -- 126
        "配置的手感及其更改的所有设置",  -- 127
        "推荐设置：动作镜头，城市、骑乘、飞行和团队副本使用更平稳的配置",  -- 128
        "立即使用某个配置，不论情境",  -- 129
        "停止强制使用配置",  -- 130
        "将当前镜头设置保存为新配置",  -- 131
        "创建配置的可编辑副本",  -- 132
        "更改自定义配置的某项设置（/ccam settings 列出所有设置）",  -- 133
        "按镜头距离设置越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 134
        "同时允许编辑内置配置（/ccam reset <profile> 可恢复原始设置）",  -- 135
        "将已编辑的内置配置恢复为原始设置",  -- 136
        "删除自定义配置",  -- 137
        "显示可分享的字符串",  -- 138
        "从分享的字符串添加配置",  -- 139
        "将越肩偏移切换到另一侧肩膀",  -- 140
        "情境结束后保持多久（默认 1.5）",  -- 141
        "开启，或关闭并还原原来的镜头设置",  -- 142
        "显示当前缩放、越肩偏移和动态设置（用于排查问题）",  -- 143
        "打开选项面板（选项 > 插件 > ControllerCam）",  -- 144
        "显示此列表",  -- 145
        "“%s”匹配多个配置。请输入更多名称。",  -- 146
        "没有名为“%s”的配置。/ccam list 可查看所有配置。",  -- 147
        "手柄玩家的镜头配置。开箱即用动作镜头；混合和经典只需一条命令。",  -- 148
        "内置配置已锁定。请开启高级编辑（/ccam advanced on）或创建副本：/ccam copy <profile>",  -- 149
        "未知设置。/ccam settings 可列出所有设置。",  -- 150
        "该数值超出允许范围。",  -- 151
        "该数值无效。",  -- 152
        "用法：/ccam set <situation> <profile|none>",  -- 153
        "%s：不更改",  -- 154
        "正在强制使用“%s”。/ccam auto 可返回按情境切换。",  -- 155
        "镜头恢复按情境切换。",  -- 156
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 157
        "按缩放的偏移请使用 /ccam curve。",  -- 158
        "用法：/ccam advanced [on|off]",  -- 159
        "高级编辑：%s。",  -- 160
        "“%s”已恢复为原始设置。",  -- 161
        "无需还原：“%s”尚未被编辑。",  -- 162
        "内置配置无法删除。",  -- 163
        "越肩偏移已镜像。",  -- 164
        "越肩偏移已恢复正常。",  -- 165
        "情境结束后会保持 %.1f 秒。",  -- 166
        "用法：/ccam delay <seconds>",  -- 167
        "此客户端不支持选项面板",  -- 168
        "未知命令“%s”。请输入 /ccam help",  -- 169
        "左键：下一个配置。右键：上一个配置。第一项“不更改”会保持镜头不变。",  -- 170
        "左键：下一个配置。右键：上一个配置。",  -- 171
        "按 Ctrl+C 复制，然后按 Esc。",  -- 172
        "在此粘贴 ControllerCam 字符串（Ctrl+V），然后点击导入。",  -- 173
        "手柄玩家的镜头配置。为每种情境选择镜头的手感。左键点击配置切换到下一个，右键切换到上一个。",  -- 174
        "开启或关闭镜头控制。关闭后会还原你原来的镜头设置。",  -- 175
        "动作镜头，城市、骑乘、飞行和团队副本使用更平稳的配置。",  -- 176
        "防止情境快速开关时镜头在配置之间来回闪烁。",  -- 177
        "切换镜头越过的肩膀。",  -- 178
        "在所有情境中使用此配置。",  -- 179
        "创建此配置的可编辑副本。",  -- 180
        "将当前镜头设置保存为新配置。",  -- 181
        "显示可分享的字符串。",  -- 182
        "从分享的字符串添加配置。",  -- 183
        "删除此自定义配置。",  -- 184
        "将此内置配置恢复为原始设置。",  -- 185
        "此设置使用游戏默认值。",  -- 186
        "高级编辑已开启。对内置配置的更改会被保留；“恢复原始设置”可还原。",  -- 187
        "钓鱼中",  -- 188
        "室内",  -- 189
        "未知的情境。请使用以下之一：",  -- 190
        "为一种情境选择配置（/ccam 显示列表）",  -- 191
        "当前形态下的越肩偏移（德鲁伊形态、幽魂之狼），为正常值的百分比",  -- 192
        "你当前不在任何形态中。",  -- 193
        "此形态下的越肩偏移：%d%%",  -- 194
        "用法：/ccam formoffset <百分比>（或 reset）",  -- 195
        "下次登录时，游戏会再次询问其实验性镜头设置。",  -- 196
        "游戏不会再询问实验性镜头设置（你已接受）。/ccam notice 可恢复询问。",  -- 197
        "下次登录时让游戏再次询问其实验性镜头设置",  -- 198
        "选中敌人时，镜头拉近到 %.1f 码。",  -- 199
        "选中敌人时镜头保持距离。",  -- 200
        "用法：/ccam targetzoom <码>（0 或 off：关闭）",  -- 201
        "选中敌人时镜头拉近到这个距离，之后再拉回（0：关闭）",  -- 202
        "选中敌人时拉近：%.1f 码",  -- 203
        "选中敌人时拉近：关闭",  -- 204
        "选中敌人时镜头拉近到这个距离；放开后回到原来的位置（骑乘时除外）。远处漫游，近身战斗。",  -- 205
        "ControllerCam：移动方式",  -- 206
        "镜头配置也可以设置移动时角色的朝向和转身方式，以及摇杆转动镜头的速度。交给配置，还是保留你自己的设置？",  -- 207
        "现在由配置设置移动方式和摇杆速度（/ccam movement 可更改）。",  -- 208
        "保留你自己的移动和摇杆设置（/ccam movement 可更改）。",  -- 209
        "交给配置",  -- 210
        "保留我的",  -- 211
        "配置也设置移动方式和摇杆速度",  -- 212
        "移动时的朝向和转身，以及摇杆的镜头速度，由每个配置设置。关闭：使用你原来的设置。",  -- 213
        "随缩放变化的视野",  -- 214
        "随缩放变化的目标聚焦",  -- 215
        "开箱即用的手感：拉近时越过肩膀，拉远时平缓回到中央，距离越近越朝目标转动。带头部追踪，镜头跟随你的奔跑方向。",  -- 216
        "所有情境使用同一配置（例如：recommended、action、classic）",  -- 217
        "所有配置的越肩偏移强度（正常值的百分比）",  -- 218
        "用法：/ccam offset <百分比>（0 到 200）",  -- 219
        "越肩偏移强度：%d%%",  -- 220
        "快速选择：",  -- 221
        "在所有配置中让越肩镜头更偏向一侧，或移回中央。当角色体型让画面位置不同时很有用。",  -- 222
        "高级：显示并编辑所有设置",  -- 223
        "分组显示所有设置，并允许修改内置配置。你的更改会被保留，“恢复原始设置”可还原原始版本。",  -- 224
        "偏移随缩放变化",  -- 225
        "各个距离下向侧面偏移多少。镜头会平缓过渡到下一个数值。",  -- 226
        "目标聚焦随缩放变化",  -- 227
        "各个距离下使用多少目标聚焦强度。关闭：任何距离都用全部强度。",  -- 228
        "视野随缩放变化",  -- 229
        "各个距离下的视野，按你自己视野的比例。关闭：保持你的视野不变。",  -- 230
        "%s（%s 到 %s 码）",  -- 231
        "你现在在 %.1f 码：%s。",  -- 232
        "距离与数值的组合，例如 0:2 8:2 20:0。留空表示不随缩放变化。按 Enter 应用。",  -- 233
        "随缩放",  -- 234
        "本游戏没有可供插件修改的视野设置。",  -- 235
        "未列出的设置使用游戏默认值。在下方选择一个分组查看其设置。",  -- 236
        "大多数人用预设就够了。要修改某个配置，请创建副本，或勾选“高级”查看所有设置。",  -- 237
        "仅在允许配置设置移动方式后生效（ControllerCam 第一页）。",  -- 238
        "切换到此配置时镜头所在的距离。",  -- 239
        "镜头最远能拉到哪里。数值越大越远。",  -- 240
        "上表背后的精确数据点，格式为 距离:比例。1 表示你自己的视野。",  -- 241
        "右摇杆转动镜头的速度。",  -- 242
        "右摇杆上下看的速度。",  -- 243
        "奔跑时镜头会转到你身后。",  -- 244
        "镜头转到你身后的速度。",  -- 245
        "镜头恢复水平的速度。",  -- 246
        "你手动移动镜头后，它等待多久。",  -- 247
        "0：角色朝向奔跑方向。180：始终朝前，横向移动。",  -- 248
        "战斗中的同一项选择。",  -- 249
        "转动镜头时，角色何时跟着转身。",  -- 250
        "坐骑会转向你推动摇杆的方向。",  -- 251
        "游泳时，角色会转向你推动摇杆的方向。",  -- 252
        "飞行时，你会转向推动摇杆的方向。",  -- 253
        "所有距离使用同一偏移。0 让角色保持在中央。",  -- 254
        "上表背后的精确数据点，格式为 距离:偏移。",  -- 255
        "缩放时让视角倾斜，形成更低、更有电影感的角度。",  -- 256
        "镜头随角色头部移动的幅度。0 为关闭。",  -- 257
        "站立不动时的移动幅度。",  -- 258
        "奔跑时的移动幅度。",  -- 259
        "镜头距离多远时仍会随角色头部移动。",  -- 260
        "镜头转向你选中的敌人。",  -- 261
        "左右转动的力度。1 为最强。",  -- 262
        "上下倾斜的力度。1 为最强。",  -- 263
        "上表背后的精确数据点，格式为 距离:比例。1 表示全部强度。",  -- 264
        "镜头转向正在与你对话的人。",  -- 265
        "朝对方左右转动的力度。",  -- 266
        "朝对方上下倾斜的力度。",  -- 267
        "使用键鼠时：镜头何时转回你身后。",  -- 268
        "镜头随山坡起伏倾斜。此处未设置时保留你的设置。",  -- 269
        "镜头的距离，以及最远能拉多远。",  -- 270
        "镜头向侧面偏移多少，让角色不在屏幕正中。",  -- 271
        "镜头为看向目标或对话对象而转动的幅度。",  -- 272
        "镜头跟随角色头部移动的幅度。",  -- 273
        "镜头自行做出的细微动作。",  -- 274
        "摇杆移动镜头的速度，以及镜头是否跟随你的奔跑方向。",  -- 275
        "移动时角色朝向哪里。",  -- 276
        "第一人称",  -- 277
        "越肩",  -- 278
        "上半身",  -- 279
        "全身",  -- 280
        "中距离",  -- 281
        "拉远",  -- 282
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
        "建議設定",  -- 64
        "（不變更）",  -- 65
        "全部使用",  -- 66
        "建立副本",  -- 67
        "儲存目前鏡頭",  -- 68
        "匯出",  -- 69
        "匯入",  -- 70
        "關閉",  -- 71
        "刪除",  -- 72
        "遊戲預設",  -- 73
        "預設",  -- 74
        "我的設定檔",  -- 75
        "副本",  -- 76
        "強制",  -- 77
        "自訂",  -- 78
        "不變更",  -- 79
        "目前",  -- 80
        "尚未套用",  -- 81
        "目前：%s（%s）",  -- 82
        "目前：尚未套用",  -- 83
        "鏡像越肩偏移（另一側肩膀）",  -- 84
        "情境結束後保持 %.1f 秒",  -- 85
        "指令：/ccam help",  -- 86
        "每種情境使用的設定檔（由上往下，第一個符合的生效）：",  -- 87
        "完成。",  -- 88
        "已在所有情境使用「%s」。",  -- 89
        "已套用建議設定。",  -- 90
        "已儲存為「%s」。",  -- 91
        "已刪除「%s」。",  -- 92
        "已啟用",  -- 93
        "已停用。已還原你原本的鏡頭設定。",  -- 94
        "已匯入「%s」。用 /ccam use \"%s\" 試試。",  -- 95
        "這不是 ControllerCam 設定檔字串。",  -- 96
        "沒有可匯入的內容。",  -- 97
        "字串太長，不是有效的設定檔。",  -- 98
        "此設定檔由較新版本的 ControllerCam 建立。請更新插件。",  -- 99
        "字串已損壞（檢查碼不符）。請重新完整複製。",  -- 100
        "該設定檔沒有有效的名稱。",  -- 101
        "無法匯入：%s（%s）。",  -- 102
        "有數值超出允許範圍",  -- 103
        "有數值無效",  -- 104
        "有曲線無效",  -- 105
        "包含此版本不認得的設定",  -- 106
        "已安裝。動作鏡頭已開啟。試試 /ccam use hybrid 或 /ccam use classic，/ccam help 列出所有指令。",  -- 107
        "%s 也已載入。兩者都會修改鏡頭，會互相衝突。請停用其中一個。",  -- 108
        "鏡頭跟隨地形",  -- 109
        "你的設定",  -- 110
        "還原為原始設定",  -- 111
        "（已編輯）",  -- 112
        "未列出的所有設定皆使用遊戲預設值。",  -- 113
        "介於經典和動作之間：中等距離、輕微的越肩偏移和柔和的頭部追蹤。鏡頭跟隨你的移動，同時保持開闊的視野。",  -- 114
        "遊戲內建鏡頭：ControllerCam 管理的所有設定恢復為預設值。鏡頭距離和你的地形跟隨設定保持不變。",  -- 115
        "第三人稱射擊手感：緊湊的鏡頭、較大的越肩偏移、快速的搖桿瞄準。非戰鬥時面向移動方向奔跑，戰鬥中面向鏡頭方向橫向移動。",  -- 116
        "更近更穩，適合掩體射擊玩法：角色始終隨鏡頭轉動，越肩偏移較大，鏡頭不會自行漂移。",  -- 117
        "緩慢、開闊、富有氣氛，適合做任務和截圖：動態俯仰、強烈的頭部追蹤，鏡頭會轉向你正在交談的對象。",  -- 118
        "鏡頭會偏向你目前的目標和對話的NPC。適合單目標戰鬥。",  -- 119
        "適合地城和團隊副本的遠距離穩定鏡頭：無偏移、無頭部追蹤、無鏡頭漂移，搖桿轉向迅速，讓你看清整場戰鬥。",  -- 120
        "騎乘專用：轉向時鏡頭會擺到你身後的遠距離鏡頭。越肩偏移已關閉，因為不同體型的坐騎會讓它不可靠。",  -- 121
        "飛行專用：跟隨你爬升和俯衝的遠距離鏡頭。",  -- 122
        "適合城市的悠閒慢速鏡頭：更近、更平穩，並帶有頭部追蹤。",  -- 123
        "自訂設定檔。可在設定檔編輯器中複製或編輯。",  -- 124
        "顯示狀態",  -- 125
        "列出設定檔",  -- 126
        "設定檔的手感及其更改的所有設定",  -- 127
        "建議設定：動作鏡頭，城市、騎乘、飛行和團隊副本使用更平穩的設定檔",  -- 128
        "立即使用某個設定檔，不論情境",  -- 129
        "停止強制使用設定檔",  -- 130
        "將目前鏡頭設定儲存為新設定檔",  -- 131
        "建立設定檔的可編輯副本",  -- 132
        "更改自訂設定檔的某項設定（/ccam settings 列出所有設定）",  -- 133
        "依鏡頭距離設定越肩偏移，例如 /ccam curve mine 0:2 8:2 20:0",  -- 134
        "同時允許編輯內建設定檔（/ccam reset <profile> 可還原為原始設定）",  -- 135
        "將已編輯的內建設定檔還原為原始設定",  -- 136
        "刪除自訂設定檔",  -- 137
        "顯示可分享的字串",  -- 138
        "從分享的字串新增設定檔",  -- 139
        "將越肩偏移切換到另一側肩膀",  -- 140
        "情境結束後保持多久（預設 1.5）",  -- 141
        "開啟，或關閉並還原原本的鏡頭設定",  -- 142
        "顯示目前縮放、越肩偏移和動態設定（用於排查問題）",  -- 143
        "開啟選項面板（選項 > 插件 > ControllerCam）",  -- 144
        "顯示此列表",  -- 145
        "「%s」符合多個設定檔。請輸入更多名稱。",  -- 146
        "沒有名為「%s」的設定檔。/ccam list 可查看所有設定檔。",  -- 147
        "手把玩家的鏡頭設定檔。開箱即用動作鏡頭；混合和經典只需一條指令。",  -- 148
        "內建設定檔已鎖定。請開啟進階編輯（/ccam advanced on）或建立副本：/ccam copy <profile>",  -- 149
        "未知設定。/ccam settings 可列出所有設定。",  -- 150
        "該數值超出允許範圍。",  -- 151
        "該數值無效。",  -- 152
        "用法：/ccam set <situation> <profile|none>",  -- 153
        "%s：不變更",  -- 154
        "正在強制使用「%s」。/ccam auto 可返回依情境切換。",  -- 155
        "鏡頭恢復依情境切換。",  -- 156
        "用法：/ccam edit <profile> <setting> <value|default>",  -- 157
        "依縮放的偏移請使用 /ccam curve。",  -- 158
        "用法：/ccam advanced [on|off]",  -- 159
        "進階編輯：%s。",  -- 160
        "「%s」已還原為原始設定。",  -- 161
        "無需還原：「%s」尚未被編輯。",  -- 162
        "內建設定檔無法刪除。",  -- 163
        "越肩偏移已鏡像。",  -- 164
        "越肩偏移已恢復正常。",  -- 165
        "情境結束後會保持 %.1f 秒。",  -- 166
        "用法：/ccam delay <seconds>",  -- 167
        "此用戶端不支援選項面板",  -- 168
        "未知指令「%s」。請輸入 /ccam help",  -- 169
        "左鍵：下一個設定檔。右鍵：上一個設定檔。第一項「不變更」會保持鏡頭不變。",  -- 170
        "左鍵：下一個設定檔。右鍵：上一個設定檔。",  -- 171
        "按 Ctrl+C 複製，然後按 Esc。",  -- 172
        "在此貼上 ControllerCam 字串（Ctrl+V），然後點擊匯入。",  -- 173
        "手把玩家的鏡頭設定檔。為每種情境選擇鏡頭的手感。左鍵點擊設定檔切換到下一個，右鍵切換到上一個。",  -- 174
        "開啟或關閉鏡頭控制。關閉後會還原你原本的鏡頭設定。",  -- 175
        "動作鏡頭，城市、騎乘、飛行和團隊副本使用更平穩的設定檔。",  -- 176
        "防止情境快速開關時鏡頭在設定檔之間來回閃爍。",  -- 177
        "切換鏡頭越過的肩膀。",  -- 178
        "在所有情境中使用此設定檔。",  -- 179
        "建立此設定檔的可編輯副本。",  -- 180
        "將目前鏡頭設定儲存為新設定檔。",  -- 181
        "顯示可分享的字串。",  -- 182
        "從分享的字串新增設定檔。",  -- 183
        "刪除此自訂設定檔。",  -- 184
        "將此內建設定檔還原為原始設定。",  -- 185
        "此設定使用遊戲預設值。",  -- 186
        "進階編輯已開啟。對內建設定檔的變更會被保留；「還原為原始設定」可還原。",  -- 187
        "釣魚中",  -- 188
        "室內",  -- 189
        "未知的情境。請使用以下之一：",  -- 190
        "為一種情境選擇設定檔（/ccam 顯示列表）",  -- 191
        "目前形態下的越肩偏移（德魯伊形態、鬼魂之狼），為正常值的百分比",  -- 192
        "你目前不在任何形態中。",  -- 193
        "此形態下的越肩偏移：%d%%",  -- 194
        "用法：/ccam formoffset <百分比>（或 reset）",  -- 195
        "下次登入時，遊戲會再次詢問其實驗性鏡頭設定。",  -- 196
        "遊戲不會再詢問實驗性鏡頭設定（你已接受）。/ccam notice 可恢復詢問。",  -- 197
        "下次登入時讓遊戲再次詢問其實驗性鏡頭設定",  -- 198
        "選中敵人時，鏡頭拉近到 %.1f 碼。",  -- 199
        "選中敵人時鏡頭保持距離。",  -- 200
        "用法：/ccam targetzoom <碼>（0 或 off：關閉）",  -- 201
        "選中敵人時鏡頭拉近到這個距離，之後再拉回（0：關閉）",  -- 202
        "選中敵人時拉近：%.1f 碼",  -- 203
        "選中敵人時拉近：關閉",  -- 204
        "選中敵人時鏡頭拉近到這個距離；放開後回到原來的位置（騎乘時除外）。遠處漫遊，近身戰鬥。",  -- 205
        "ControllerCam：移動方式",  -- 206
        "鏡頭設定檔也可以設定移動時角色的朝向和轉身方式，以及搖桿轉動鏡頭的速度。交給設定檔，還是保留你自己的設定？",  -- 207
        "現在由設定檔設定移動方式和搖桿速度（/ccam movement 可更改）。",  -- 208
        "保留你自己的移動和搖桿設定（/ccam movement 可更改）。",  -- 209
        "交給設定檔",  -- 210
        "保留我的",  -- 211
        "設定檔也設定移動方式和搖桿速度",  -- 212
        "移動時的朝向和轉身，以及搖桿的鏡頭速度，由每個設定檔設定。關閉：使用你原來的設定。",  -- 213
        "隨縮放變化的視野",  -- 214
        "隨縮放變化的目標聚焦",  -- 215
        "開箱即用的手感：拉近時越過肩膀，拉遠時平緩回到中央，距離越近越朝目標轉動。帶頭部追蹤，鏡頭跟隨你的奔跑方向。",  -- 216
        "所有情境使用同一設定檔（例如：recommended、action、classic）",  -- 217
        "所有設定檔的越肩偏移強度（正常值的百分比）",  -- 218
        "用法：/ccam offset <百分比>（0 到 200）",  -- 219
        "越肩偏移強度：%d%%",  -- 220
        "快速選擇：",  -- 221
        "在所有設定檔中讓越肩鏡頭更偏向一側，或移回中央。當角色體型讓畫面位置不同時很有用。",  -- 222
        "進階：顯示並編輯所有設定",  -- 223
        "分組顯示所有設定，並允許修改內建設定檔。你的變更會被保留，「還原為原始設定」可還原原始版本。",  -- 224
        "偏移隨縮放變化",  -- 225
        "各個距離下向側面偏移多少。鏡頭會平緩過渡到下一個數值。",  -- 226
        "目標聚焦隨縮放變化",  -- 227
        "各個距離下使用多少目標聚焦強度。關閉：任何距離都用全部強度。",  -- 228
        "視野隨縮放變化",  -- 229
        "各個距離下的視野，按你自己視野的比例。關閉：保持你的視野不變。",  -- 230
        "%s（%s 到 %s 碼）",  -- 231
        "你現在在 %.1f 碼：%s。",  -- 232
        "距離與數值的組合，例如 0:2 8:2 20:0。留空表示不隨縮放變化。按 Enter 套用。",  -- 233
        "隨縮放",  -- 234
        "本遊戲沒有可供插件修改的視野設定。",  -- 235
        "未列出的設定使用遊戲預設值。在下方選擇一個分組查看其設定。",  -- 236
        "大多數人用預設就夠了。要修改某個設定檔，請建立副本，或勾選「進階」查看所有設定。",  -- 237
        "僅在允許設定檔設定移動方式後生效（ControllerCam 第一頁）。",  -- 238
        "切換到此設定檔時鏡頭所在的距離。",  -- 239
        "鏡頭最遠能拉到哪裡。數值越大越遠。",  -- 240
        "上表背後的精確資料點，格式為 距離:比例。1 表示你自己的視野。",  -- 241
        "右搖桿轉動鏡頭的速度。",  -- 242
        "右搖桿上下看的速度。",  -- 243
        "奔跑時鏡頭會轉到你身後。",  -- 244
        "鏡頭轉到你身後的速度。",  -- 245
        "鏡頭恢復水平的速度。",  -- 246
        "你手動移動鏡頭後，它等待多久。",  -- 247
        "0：角色朝向奔跑方向。180：始終朝前，橫向移動。",  -- 248
        "戰鬥中的同一項選擇。",  -- 249
        "轉動鏡頭時，角色何時跟著轉身。",  -- 250
        "坐騎會轉向你推動搖桿的方向。",  -- 251
        "游泳時，角色會轉向你推動搖桿的方向。",  -- 252
        "飛行時，你會轉向推動搖桿的方向。",  -- 253
        "所有距離使用同一偏移。0 讓角色保持在中央。",  -- 254
        "上表背後的精確資料點，格式為 距離:偏移。",  -- 255
        "縮放時讓視角傾斜，形成更低、更有電影感的角度。",  -- 256
        "鏡頭隨角色頭部移動的幅度。0 為關閉。",  -- 257
        "站立不動時的移動幅度。",  -- 258
        "奔跑時的移動幅度。",  -- 259
        "鏡頭距離多遠時仍會隨角色頭部移動。",  -- 260
        "鏡頭轉向你選中的敵人。",  -- 261
        "左右轉動的力度。1 為最強。",  -- 262
        "上下傾斜的力度。1 為最強。",  -- 263
        "上表背後的精確資料點，格式為 距離:比例。1 表示全部強度。",  -- 264
        "鏡頭轉向正在與你對話的人。",  -- 265
        "朝對方左右轉動的力度。",  -- 266
        "朝對方上下傾斜的力度。",  -- 267
        "使用鍵鼠時：鏡頭何時轉回你身後。",  -- 268
        "鏡頭隨山坡起伏傾斜。此處未設定時保留你的設定。",  -- 269
        "鏡頭的距離，以及最遠能拉多遠。",  -- 270
        "鏡頭向側面偏移多少，讓角色不在畫面正中。",  -- 271
        "鏡頭為看向目標或對話對象而轉動的幅度。",  -- 272
        "鏡頭跟隨角色頭部移動的幅度。",  -- 273
        "鏡頭自行做出的細微動作。",  -- 274
        "搖桿移動鏡頭的速度，以及鏡頭是否跟隨你的奔跑方向。",  -- 275
        "移動時角色朝向哪裡。",  -- 276
        "第一人稱",  -- 277
        "越肩",  -- 278
        "上半身",  -- 279
        "全身",  -- 280
        "中距離",  -- 281
        "拉遠",  -- 282
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
