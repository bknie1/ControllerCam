-- ControllerCam HUD: quests that ask for items you can trade or sell, for quests not in your log yet (the game
-- tells an addon only of the quests in your log). Quests.lua reads it: an item a quest here wants is kept for
-- it while that quest is for your faction, not grey for you and not done yet, and its tooltip says which:
-- "[37] Bloodscalp Insight in Stranglethorn Vale".
--
-- A short list made by hand for this addon from public facts about the game (which quest asks for which item,
-- its level and where it is), checked against the community wikis. It is not copied from any other addon's or
-- server's database. Only items that drop or are gathered and can be traded: quest items bound to you are the
-- game's own business, and cloth turn-ins, cooking and class quests are left out.
--
-- [item id] = { { quest id, quest name, quest level, zone, side ("A", "H", or nil for both), how many }, ... }

local ADDON, ns = ...

local STV, BL, BAD = "Stranglethorn Vale", "Blasted Lands", "Badlands"
local GOULASH = { 92, "Redridge Goulash", 18, "Redridge Mountains", "A", 5 }
local function Run(n) return { 2258, "Badlands Reagent Run", 39, BAD, "H", n }, { 2500, "Badlands Reagent Run", 39, BAD, "A", n } end
local function Page(chapter, quest) return { { quest, "Chapter " .. chapter .. " (The Green Hills of Stranglethorn)", 40, STV, nil, 1 } } end
local BARRENS, TN, DESO, TAN, FERALAS, WS = "The Barrens", "Thousand Needles", "Desolace", "Tanaris", "Feralas", "Winterspring"
local KEG = { 821, "Chen's Empty Keg", 15, BARRENS, "H", 5 }
local RECLAIM = "Reagents for Reclaimers Inc."
local function JINZIL(n) return { 1058, "Jin'Zil's Forest Magic", 26, "Stonetalon Mountains", "H", n } end
local function NATURAL(n) return { 3128, "Natural Materials", 50, FERALAS, "H", n } end

ns.QuestItemData = {
    ---------------------------------------------------------------------------
    -- Eastern Kingdoms
    ---------------------------------------------------------------------------
    [2799] = { { 349, "Stranglethorn Fever", 35, STV, nil, 10 } },                     -- Gorilla Fang
    [1532] = { { 582, "Headhunting", 37, STV, "H", 20 } },                             -- Shrunken Head
    [3863] = { { 572, "Mok'thardin's Enchantment", 41, STV, "H", 10 } },               -- Jungle Stalker Feather
    [4278] = { { 627, "Favor for Krazek", 37, STV, "A", 4 } },                         -- Lesser Bloodstone Ore
    [1524] = { { 209, "Skullsplitter Tusks", 42, STV, nil, 18 } },                     -- Skullsplitter Tusk
    [3918] = { { 605, "Singing Blue Shards", 35, STV, nil, 10 } },                     -- Singing Crystal Shard
    [5796] = { { 1107, "Encrusted Tail Fins", 35, "Thousand Needles", nil, 10 } },     -- (from the Vile Reef)
    -- The Green Hills of Stranglethorn: the pages each chapter wants
    [2725] = Page("I", 339), [2728] = Page("I", 339), [2730] = Page("I", 339), [2732] = Page("I", 339),
    [2734] = Page("II", 340), [2735] = Page("II", 340), [2738] = Page("II", 340), [2740] = Page("II", 340),
    [2742] = Page("III", 341), [2744] = Page("III", 341), [2745] = Page("III", 341), [2748] = Page("III", 341),
    [2749] = Page("IV", 342), [2750] = Page("IV", 342), [2751] = Page("IV", 342),
    -- Blasted Lands: Bloodmage Lynnore's and Bloodmage Drazial's brews
    [8394] = { { 2601, "The Basilisk's Bite", 50, BL, nil, 10 }, { 2602, "Infallible Mind", 50, BL, nil, 10 },  -- Basilisk Brain
               { 2583, "A Boar's Vitality", 50, BL, nil, 1 }, { 2584, "Spirit of the Boar", 50, BL, nil, 1 } },
    [8396] = { { 2603, "Vulture's Vigor", 50, BL, nil, 10 }, { 2604, "Spiritual Domination", 50, BL, nil, 10 }, -- Vulture Gizzard
               { 2601, "The Basilisk's Bite", 50, BL, nil, 2 }, { 2602, "Infallible Mind", 50, BL, nil, 2 },
               { 2585, "The Decisive Striker", 50, BL, nil, 2 }, { 2586, "Salt of the Scorpok", 50, BL, nil, 2 } },
    [8391] = { { 2581, "Snickerfang Jowls", 50, BL, nil, 3 }, { 2582, "Rage of Ages", 50, BL, nil, 3 },        -- Snickerfang Jowl
               { 2603, "Vulture's Vigor", 50, BL, nil, 2 }, { 2604, "Spiritual Domination", 50, BL, nil, 2 } },
    [8392] = { { 2583, "A Boar's Vitality", 50, BL, nil, 3 }, { 2584, "Spirit of the Boar", 50, BL, nil, 3 },  -- Blasted Boar Lung
               { 2581, "Snickerfang Jowls", 50, BL, nil, 2 }, { 2582, "Rage of Ages", 50, BL, nil, 2 },
               { 2585, "The Decisive Striker", 50, BL, nil, 1 }, { 2586, "Salt of the Scorpok", 50, BL, nil, 1 } },
    [8393] = { { 2585, "The Decisive Striker", 50, BL, nil, 3 }, { 2586, "Salt of the Scorpok", 50, BL, nil, 3 }, -- Scorpok Pincer
               { 2583, "A Boar's Vitality", 50, BL, nil, 2 }, { 2584, "Spirit of the Boar", 50, BL, nil, 2 },
               { 2581, "Snickerfang Jowls", 50, BL, nil, 1 }, { 2582, "Rage of Ages", 50, BL, nil, 1 } },
    [9259] = { { 2880, "Troll Necklace Bounty", 45, "The Hinterlands", "A", 5 } },     -- Troll Tribal Necklace
    [3397] = { { 484, "Young Crocolisk Skins", 22, "Wetlands", "A", 4 } },             -- Young Crocolisk Skin
    [7847] = { Run(5) },                                                               -- Buzzard Gizzard
    [7846] = { Run(10) },                                                              -- Crag Coyote Fang
    [7848] = { Run(5) },                                                               -- Rock Elemental Shard
    [3404] = { { 703, "Barbecued Buzzard Wings", 40, BAD, nil, 4 } },                  -- Buzzard Wing
    [4513] = { { 701, "Guile of the Raptor", 37, "Arathi Highlands", "H", 12 } },      -- Raptor Heart
    [6169] = { { 698, "Lack of Surplus", 40, "Swamp of Sorrows", "H", 8 } },           -- Unprepared Sawtooth Flank
    [1080] = { GOULASH },                                                              -- Tough Condor Meat
    [2296] = { GOULASH },                                                              -- Great Goretusk Snout
    [1081] = { GOULASH },                                                              -- Crisp Spider Meat
    [1015] = { { 90, "Seasoned Wolf Kabobs", 25, "Duskwood", "A", 10 } },              -- Lean Wolf Flank
    [3712] = { { 555, "Soothing Turtle Bisque", 31, "Hillsbrad Foothills", "A", 10 },  -- Turtle Meat
               { 7321, "Soothing Turtle Bisque", 31, "Hillsbrad Foothills", "H", 10 } },

    ---------------------------------------------------------------------------
    -- Kalimdor
    ---------------------------------------------------------------------------
    [4893] = { KEG },                                                                  -- Savannah Lion Tusk
    [4894] = { KEG },                                                                  -- Plainstrider Kidney
    [4895] = { { 821, "Chen's Empty Keg", 15, BARRENS, "H", 1 } },                     -- Thunder Lizard Horn
    [5055] = { { 865, "Raptor Horns", 18, BARRENS, nil, 5 } },                         -- Intact Raptor Horn
    [5064] = { { 867, "Harpy Raiders", 15, BARRENS, "H", 8 } },                        -- Witchwing Talon
    [5098] = { { 880, "Altered Beings", 16, BARRENS, "H", 8 } },                       -- Altered Snapjaw Shell
    [5012] = { { 848, "Fungal Spores", 15, BARRENS, "H", 4 } },                        -- Fungal Spores
    [5437] = { { 1010, "Bathran's Hair", 20, "Ashenvale", "A", 5 } },                  -- Bathran's Hair
    [5582] = { JINZIL(5) },                                                            -- Stonetalon Sap
    [5584] = { JINZIL(5) },                                                            -- Twilight Whisker
    [5585] = { JINZIL(30) },                                                           -- Courser Eye
    [5583] = { JINZIL(1) },                                                            -- Fey Dragon Scale
    [5794] = { { 1104, "Salt Flat Venom", 30, TN, nil, 6 } },                          -- Salty Scorpid Venom
    [5848] = { { 1176, "Load Lightening", 30, TN, nil, 10 } },                         -- Hollow Vulture Bone
    [5798] = { { 1110, "Rocket Car Parts", 31, TN, nil, 30 } },                        -- Rocket Car Parts
    [6067] = { { 1387, "Centaur Bounty", 31, DESO, "A", 15 }, { 1366, "Centaur Bounty", 31, DESO, "H", 15 } },
    [6246] = { { 1458, RECLAIM, 33, DESO, "A", 10 } },                                 -- Hatefury Claw
    [6247] = { { 1458, RECLAIM, 33, DESO, "A", 10 } },                                 -- Hatefury Horn
    [6248] = { { 1459, RECLAIM, 35, DESO, "A", 7 } },                                  -- Scorpashi Venom
    [6249] = { { 1459, RECLAIM, 35, DESO, "A", 3 } },                                  -- Aged Kodo Hide
    [6250] = { { 1466, RECLAIM, 40, DESO, "A", 10 } },                                 -- Felhound Brain
    [6251] = { { 1466, RECLAIM, 40, DESO, "A", 10 } },                                 -- Nether Wing
    [6252] = { { 1466, RECLAIM, 40, DESO, "A", 10 } },                                 -- Doomwarder Blood
    [5847] = { { 1177, "Hungry!", 36, "Dustwallow Marsh", nil, 12 } },                 -- Mirefin Head
    [8483] = { { 1707, "Water Pouch Bounty", 44, TAN, nil, 5 }, { 1878, "Water Pouch Bounty", 44, TAN, nil, 5 },
               { 379, "Slake That Thirst", 46, TAN, "H", 5 }, { 841, "Another Power Source?", 46, TAN, "H", 10 } },
    [20519] = { { 8365, "Pirate Hats Ahoy!", 45, TAN, nil, 20 } },                     -- Southsea Pirate Hat
    [11834] = { { 4504, "Super Sticky", 54, TAN, nil, 12 } },                          -- Super Sticky Tar
    [9523] = { { 3042, "Troll Temper", 45, "Zul'Farrak", nil, 20 } },                  -- Troll Temper
    [9238] = { { 2865, "Scarab Shells", 45, "Zul'Farrak", nil, 5 } },                  -- Uncracked Scarab Shell
    [8973] = { { 2821, "The Mark of Quality", 46, FERALAS, "A", 10 },                  -- Thick Yeti Hide
               { 2822, "The Mark of Quality", 46, FERALAS, "H", 10 } },
    [18958] = { { 7721, "Fuel for the Zapping", 48, FERALAS, nil, 10 } },              -- Water Elemental Core
    [9590] = { NATURAL(2) },                                                           -- Splintered Log
    [9589] = { NATURAL(6) },                                                           -- Encrusted Minerals
    [9591] = { NATURAL(20) },                                                          -- Resilient Sinew
    [9592] = { NATURAL(40) },                                                          -- Metallic Fragments
    [11018] = { { 3764, "Un'Goro Soil", 50, "Darnassus", "A", 20 }, { 3761, "Un'Goro Soil", 50, "Thunder Bluff", "H", 20 },
                { 4496, "Bungle in the Jungle", 53, TAN, nil, 5 } },                   -- Un'Goro Soil
    [11040] = { { 3785, "Morrowgrain Research", 50, "Darnassus", "A", 10 },            -- Morrowgrain
                { 3786, "Morrowgrain Research", 50, "Thunder Bluff", "H", 10 },
                { 3803, "Morrowgrain to Darnassus", 55, "Darnassus", "A", 10 },
                { 3804, "Morrowgrain to Thunder Bluff", 55, "Thunder Bluff", "H", 10 } },
    [12444] = { { 4809, "Chillwind Horns", 54, WS, nil, 8 } },                         -- Uncracked Chillwind Horn
    [12366] = { { 3783, "Are We There, Yeti?", 56, WS, nil, 10 } },                    -- Thick Yeti Fur
    [12822] = { { 5086, "Toxic Horrors", 56, WS, nil, 3 } },                           -- Toxic Horror Droplet
    [12622] = { { 4970, "Frostsaber Provisions", 60, WS, "A", 5 } },                   -- Shardtooth Meat
    [12623] = { { 4970, "Frostsaber Provisions", 60, WS, "A", 5 } },                   -- Chillwind Meat
}
