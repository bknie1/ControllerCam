-- ControllerCam HUD: what your character has to say (the lines only; Commentary.lua says when).
--   * said: out loud, in your people's way of talking, as N.RACE and N.CALM are (Narrative.lua). Allied races
--     speak as their kin; a race without a voice only thinks.
--   * everything else: thoughts, in plain words with no accent. They notice things and wonder about them; they
--     do not decide what kind of person your character is.
-- All of it written for the HUD, and translated like every other text of the HUD. A thought about a fish does
-- not name it: the name comes first, in the game's own words.
--
-- The voices:
--   Human      plain country folk of an old kingdom: the village, the king, the Light
--   Dwarf      a brogue; miners and diggers
--   Gnome      quirky inventors: specimens, tests, gadgets
--   NightElf   wise, and knows it; the moon and the Light of Elune
--   Orc        gruff; honour and the spirits
--   Scourge    gallows humour, nothing impresses
--   Tauren     calm and spiritual; the Earth Mother, the ancestors, a pipe of peacebloom
--   Troll      an island lilt; the loa, who are generous and dangerous
--   Goblin     out to impress, takes chances, and is not above stretching the truth
--   HighOrder  Skyborne of the Alliance: proud scholars who mean to need no spirit's help
--   Windshaper Skyborne of the Horde: stubborn that the wind spirits, who built their home, are paid back

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local R = {}
ns.Remarks = R

---------------------------------------------------------------------------
-- Out loud
---------------------------------------------------------------------------
R.said = {}

-- a fish that is new to your journal
R.said.new = {
    Human      = { L["Well now, what have we here?"], L["Light's grace, there's a new one!"] },
    Dwarf      = { L["Och, now what're you, then?"], L["Aye, there's a new find!"] },
    Gnome      = { L["Ooh! A new specimen!"], L["Fascinating! Does it come with a manual?"] },
    NightElf   = { L["By Elune's light, what are you?"], L["The deep still has something to show me."] },
    Draenei    = { L["The Light shows me something new!"], L["Ah! We have not met, little one."] },
    Worgen     = { L["Hrm. Now that's one I don't know."], L["Well, well. A newcomer."] },
    Pandaren   = { L["Ah, a new friend! Welcome, welcome."], L["Every pond has a surprise."] },
    Orc        = { L["Hah! A new foe. A short fight."], L["Spirits, what is this one?"] },
    Scourge    = { L["Dragged up from the deep. I know the feeling."], L["A new one. Relax, being dead isn't so bad."] },
    Tauren     = { L["A new face from the water. Greetings, little one."],
                   L["The Earth Mother still has things to show me."] },
    Troll      = { L["Ain't never seen ya kind on me hook, mon!"], L["What da loa be sendin' me now?"] },
    BloodElf   = { L["Oh? Something I haven't seen."], L["How exotic. And how damp."] },
    Goblin     = { L["New merchandise! I wonder what it'll fetch."], L["Never seen one. Nobody needs to know that."] },
    HighOrder  = { L["Unrecorded, until now. I shall correct that."], L["A new specimen. The archives will want this."] },
    Windshaper = { L["Something I don't know yet. The winds still teach."],
                   L["The wind led me to the right water."] },
}

-- your heaviest of a kind, well past the old one
R.said.record = {
    Human      = { L["That'd feed the whole village!"], L["Now that's fit for the king's own table!"] },
    Dwarf      = { L["Och, would ye look at the size o' that!"], L["By the forge, there's a find for the museum!"] },
    Gnome      = { L["Remarkable! My scales were not built for this!"], L["A new record! I'm going to need a bigger net!"] },
    NightElf   = { L["Elune's light falls kindly on me."], L["A magnificent creature. Of course it came to me."] },
    Draenei    = { L["By the Naaru, it is magnificent!"], L["A great gift. I am grateful."] },
    Worgen     = { L["Blimey, that's a monster!"], L["Now that is a proper catch."] },
    Pandaren   = { L["Ho ho! That one is a feast all by itself!"], L["Be patient, and look what comes!"] },
    Orc        = { L["A worthy opponent!"], L["It fought with honour. It will feed us well."] },
    Scourge    = { L["Well. That almost made me feel something."],
                   L["Look at that. Something down there was thriving."] },
    Tauren     = { L["The Earth Mother is generous today."], L["That deserves a quiet pipe of peacebloom."] },
    Troll      = { L["Whoa, mon! Dat's a big one!"], L["Da loa be generous. Dey gonna want somethin' back."] },
    BloodElf   = { L["Now that is worthy of me."], L["Magnificent. Naturally."] },
    Goblin     = { L["Cha-ching! Look at the size of that!"], L["And when I tell it, it'll be twice as big!"] },
    HighOrder  = { L["Exceptional. And no spirit had to hand it to me."], L["Remarkable. Our scholars would envy this."] },
    Windshaper = { L["A great gift! I owe the wind for this one."], L["Look at that! A debt I'll gladly pay."] },
}

-- a boss that is down for the first time
R.said.boss = {
    Human      = { L["And that's the end of that!"], L["The Light stands with us!"] },
    Dwarf      = { L["Ha! Down ye go, and stay down!"], L["That's worth a round o' ale!"] },
    Gnome      = { L["Hypothesis confirmed: we win!"], L["Test complete! Hardly any explosions!"] },
    NightElf   = { L["Elune's light has judged you."], L["It is done. It was never truly in doubt."] },
    Draenei    = { L["The Light prevails!"], L["It is finished. May it trouble no one again."] },
    Worgen     = { L["Stay down this time."], L["Hunt's over."] },
    Pandaren   = { L["A fine fight! Now, who is hungry?"], L["Breathe out. It is over."] },
    Orc        = { L["Victory! Lok'tar!"], L["You fought well. Die with honour."] },
    Scourge    = { L["Stay dead. Some of us didn't."], L["Welcome to the other side. You get used to the smell."] },
    Tauren     = { L["Walk with the ancestors now."], L["It is done. Let the land rest."] },
    Troll      = { L["Stay down, mon, an' take ya bad juju wit' ya!"], L["Da loa seen dat. Hope dey liked it."] },
    BloodElf   = { L["Flawless. As expected."], L["How tiresome. Next?"] },
    Goblin     = { L["Ha! Did you SEE that?"], L["Small package, big finish!"] },
    HighOrder  = { L["Skill and study. We needed nothing else."], L["More proof of what we can do on our own."] },
    Windshaper = { L["The winds were with us. We owe them for it."], L["It is done. Give the wind its due."] },
}

-- a chest, or a box fished up or carried, with something in it
R.said.treasure = {
    Human      = { L["Light's mercy, look at this!"], L["That'll help see us through the winter!"] },
    Dwarf      = { L["Och, now there's a bit o' treasure!"], L["Aye, worth the diggin'!"] },
    Gnome      = { L["Ooh, what's inside? What's inside?"], L["A mystery box! My favourite kind!"] },
    NightElf   = { L["What others lose, Elune reveals."], L["Well hidden. Not well enough."] },
    Draenei    = { L["A blessing, unlooked for!"], L["Someone's loss. May it find good use."] },
    Worgen     = { L["Hrm. Smelled that one coming."], L["Let's see what was worth hiding."] },
    Pandaren   = { L["Ooh, a present! For me?"], L["Every box holds a story. Some hold snacks."] },
    Orc        = { L["Spoils! Good."], L["Take it. Whoever left it could not keep it."] },
    Scourge    = { L["The last owner isn't complaining."],
                   L["A gift from the dearly departed. Don't mind if I do."] },
    Tauren     = { L["Let us take only what we need."], L["May whoever left this be at peace."] },
    Troll      = { L["Ooh, shiny! Hope it ain't cursed, mon."], L["Nobody leave loot for free. Watch ya back."] },
    BloodElf   = { L["At last, something with taste."], L["Dusty. Still, I'll take it."] },
    Goblin     = { L["Jackpot! I mean... a very modest find."], L["Finder's fee: all of it!"] },
    HighOrder  = { L["Lost to others. Recovered by those who look."],
                   L["Let's see what lesser seekers overlooked."] },
    Windshaper = { L["The wind leads, and look what's there!"],
                   L["A gift along the way. Remember to give something back."] },
}

---------------------------------------------------------------------------
-- Thoughts: fish
---------------------------------------------------------------------------
R.new = { L["Worth remembering where it came from."], L["Another page for the journal."] }

R.big = {
    L["Heavy for its kind. That one has been eating well."],
    L["A big one. It put up a proper argument."],
    L["You don't see many that size."],
    L["My arms noticed that one."],
}
R.small = {
    L["Barely worth the bait. It can tell its friends it was bigger."],
    L["A little one. Given another season, it would have been a real catch."],
    L["Small, but it counts."],
    L["More promise than fish."],
}

-- what sort of fish it is, by item number
R.kind = {
    [6289] = "snapper", [6359] = "snapper", [13759] = "snapper",
    [6308] = "catfish",
    [13422] = "eel", [13757] = "eel",
    [13760] = "salmon", [13889] = "salmon",
    [8365] = "trout",
    [6362] = "cod",
    [6303] = "mackerel",
    [6361] = "albacore",
    [6291] = "smallfish",
    [13888] = "lobster",
    [13755] = "squid",
    [13756] = "bass",
    [21071] = "sagefish", [21153] = "sagefish",
    [13754] = "mightfish", [13893] = "mightfish",
}
R.kinds = {
    snapper = L["Snappers have the jaws for the name. Mind your fingers on the hook."],
    catfish = L["Catfish feel their way along the bottom with those whiskers. Muddy water is no trouble to them."],
    eel = L["Eels are all muscle and slime. Getting one off the hook is a fight of its own."],
    salmon = L["Salmon swim against the current. Is that stubbornness, or knowing the way home?"],
    trout = L["Trout like cold, clear, moving water, and they spook at a shadow."],
    cod = L["Cod is honest food: plain, filling, and it keeps well salted."],
    mackerel = L["Where there's one mackerel there's usually a shoal."],
    albacore = L["Albacore are built for speed. That one never stopped pulling."],
    smallfish = L["Small fry. A pan full of them still makes a meal."],
    lobster = L["Lobsters don't so much bite as hold on and refuse to let go."],
    squid = L["Squid. Mind the ink."],
    bass = L["Bass fight hard, and jump when they can."],
    sagefish = L["Sagefish keep to quiet water. Do they know something the others don't?"],
    mightfish = L["Mightfish earns its name on the end of a line."],
}

R.musing = {
    L["While the line is out, nothing else needs deciding."],
    L["How long have I been standing here?"],
    L["Quiet water. Time to think."],
    L["I wonder what else is down there."],
    L["Who else has stood on this spot with a line in the water?"],
    L["One more cast, or back to the road?"],
}
R.junk = {
    L["Not a fish. Somebody may be missing that."],
    L["The water gives back all sorts."],
    L["That has been down there a while."],
    L["Not what I was after. How did it get down there?"],
}

---------------------------------------------------------------------------
-- Thoughts: treasure
---------------------------------------------------------------------------
R.treasure = {
    L["Somebody left this behind. Did they mean to come back?"],
    L["Who packed this, and what happened to them?"],
    L["How long has this been sitting here?"],
    L["Does this still belong to anyone?"],
    L["Every closed lid is a question."],
    L["That was worth stopping for."],
}
R.prize = {    -- (something rare or better in it)
    L["Why would anyone leave something like this behind?"],
    L["Somebody must have missed this."],
}
R.hauled = {   -- (a box that came up on the line)
    L["That came up from the bottom. Who dropped it?"],
    L["A box on a fishing line. What could be inside?"],
}
-- the chests, crates and trunks that come up on a line, and the bottle with a message, by item number
R.boxes = {
    [6307] = true, [6351] = true, [6352] = true, [6353] = true, [6354] = true, [6355] = true, [6356] = true,
    [6357] = true, [13874] = true, [13875] = true, [13918] = true, [20708] = true, [21113] = true,
    [21150] = true, [21228] = true,
}

---------------------------------------------------------------------------
-- Thoughts: bosses (by the dungeon's number, the eighth thing GetInstanceInfo says)
---------------------------------------------------------------------------
R.dungeons = {
    [389] = { L["A cavern of fire right under Orgrimmar. Do the people overhead ever think about it?"],
              L["The Searing Blade made themselves at home down here, with a whole city overhead."] },
    [36] = { L["The Defias turned an old mine into a hideout, with room down here for a ship."],
             L["All that digging, and it ends up sheltering the Defias."] },
    [43] = { L["A druid came here to heal the land through the Emerald Dream. These caverns show how that went."],
             L["All this water under the dry Barrens. No wonder someone thought healing could start here."] },
    [33] = { L["Arugal summoned the worgen, and they overran this keep."],
             L["A whole keep in Silverpine, and the worgen have the run of it."] },
    [48] = { L["This was a temple to Elune once, before the water and worse things took it."],
             L["The Twilight's Hammer picked a drowned temple to gather in. They never choose anywhere cheerful."] },
    [34] = { L["A prison in the middle of Stormwind, and the prisoners took it over."],
             L["Strange to think of ordinary city streets just above all that."] },
    [90] = { L["The gnomes lost their whole city here. Every broken machine was somebody's work."],
             L["Troggs came up from below, and what was meant to stop them poisoned the city."] },
    [47] = { L["The quillboar hold these thorns sacred. How must we look to them, walking in like this?"],
             L["The story goes that these thorns grew where the demigod Agamaggan fell."] },
    [129] = { L["Quillboar thorns again, with the dead stirring among them. The Scourge has found its way here."],
              L["Someone has been raising the dead on ground the quillboar hold sacred."] },
    [189] = { L["The Scarlet Crusade set out to fight the Scourge. When did they start seeing it in everyone?"],
              L["These halls are as grand as any chapel. What gets preached in them now?"] },
    [70] = { L["The titans left this place long before any of today's kingdoms. Who has been through it since?"],
             L["Dwarves have been digging here for answers about where they came from."] },
    [209] = { L["The Sandfury trolls have held this city through more sandstorms than anyone has counted."],
              L["A troll city out in Tanaris, and the desert still hasn't swallowed it."] },
    [349] = { L["The centaur hold this place sacred. Their story began down here."],
              L["If the old tale is true, every centaur descends from Zaetar and Theradras."] },
    [109] = { L["The Atal'ai raised this temple for Hakkar. It went down into the swamp for good reason."],
              L["The green dragonflight sank this place, and they're still keeping watch over it."] },
    [230] = { L["A whole Dark Iron city inside the mountain. How long would it take to learn every road in it?"],
              L["The Dark Irons answer to Ragnaros down here, whether they like it or not."] },
    [229] = { L["Orcs and black dragons, all wanting the same mountain."],
              L["Rend Blackhand calls himself warchief up here. Not every orc would agree."] },
    [429] = { L["This was a night elf city once. Ogres and satyrs squat in what's left."],
              L["All that old learning, and now the ogres have a king in the ruins."] },
    [289] = { L["A school for necromancy under Caer Darrow. Who signs up for lessons like these?"],
              L["This ground belonged to the Barov family once. What would they make of it now?"] },
    [329] = { L["This was a living city once. Arthas saw to it that it wouldn't be again."],
              L["Parts of the city still burn. Some stories don't end, they smoulder."] },
    [409] = { L["All this fire, and Ragnaros at the heart of it."] },
    [249] = { L["A black dragon doesn't give up her lair politely."] },
}

-- a first kill with no line of its dungeon left (or none known)
R.boss = {
    L["One less thing waiting in the dark."],
    L["I wonder what it was guarding, and for whom."],
    L["Will anyone miss it?"],
    L["That's the end of its story. How did it begin?"],
}

---------------------------------------------------------------------------
-- Thoughts: on the road
---------------------------------------------------------------------------
R.arrive = {   -- (the zone's name goes in)
    L["%s. Worth a good look around."],
    L["%s. I wonder who calls this home, and how they like it."],
    L["%s. Eyes open: every place has its own trouble."],
    L["%s. What stories do they tell about a place like this?"],
}
R.hard = {     -- (a dungeon, raid or group quest: its title goes in)
    L["“%s”, done. That one was no errand."],
    L["“%s” is finished. Was it worth what it took?"],
}
R.quest = {    -- (its title goes in)
    L["“%s”, finished. Someone's day just got better."],
    L["“%s”, done. I wonder what happens to them now."],
}
