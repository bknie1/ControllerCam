-- ControllerCam HUD: the steps the well-known profession levelling guides take, for The Mentor (Levelling.lua).
-- Made by docs/levelling/make_guides.py from docs/levelling/<profession>.json; change those, not this file.
-- For each profession, by skill: the recipe the guides use (p: what it makes, s: its spell), how many crafts
-- (n), how many one makes (m), the skill it needs (at), where it is learned when not at a trainer, its
-- reagents (r: item, count, ...), and the guides' alternatives, each with why you might pick it. Where the
-- guides level by gathering: { from, to, gather = what to gather }.

local ADDON, ns = ...

ns.LevelGuides = {
    alchemy = {
        { 1, 60, p = 118, s = 2330, n = 59, at = 1, r = { 2447, 1, 765, 1, 3371, 1 }, name = "Minor Healing Potion" },
        { 60, 110, p = 858, s = 2337, n = 59, at = 55, r = { 118, 1, 2450, 1 }, name = "Lesser Healing Potion" },
        { 110, 140, p = 929, s = 3447, n = 30, at = 110, r = { 2453, 1, 2450, 1, 3372, 1 }, name = "Healing Potion" },
        { 140, 155, p = 3385, s = 3173, n = 15, at = 120, r = { 785, 1, 3820, 1, 3371, 1 }, name = "Lesser Mana Potion" },
        { 155, 185, p = 1710, s = 7181, n = 30, at = 155, r = { 3357, 1, 3356, 1, 3372, 1 }, name = "Greater Healing Potion" },
        { 185, 210, p = 8949, s = 11449, n = 25, at = 185, r = { 3820, 1, 3821, 1, 3372, 1 }, name = "Elixir of Agility" },
        { 210, 215, p = 8951, s = 11450, n = 10, at = 195, r = { 3355, 1, 3821, 1, 3372, 1 }, name = "Elixir of Greater Defense" },
        { 215, 230, p = 3928, s = 11457, n = 15, at = 215, r = { 8838, 1, 3358, 1, 8925, 1 }, name = "Superior Healing Potion" },
        { 230, 231, p = 9149, s = 11459, n = 1, at = 225, r = { 3575, 4, 9262, 1, 8831, 4, 4625, 4 }, name = "Philosophers' Stone" },
        { 231, 250, p = 9154, s = 11460, n = 19, at = 230, r = { 8836, 1, 8925, 1 }, name = "Elixir of Detect Undead" },
        { 250, 265, p = 9187, s = 11467, n = 15, at = 240, r = { 8838, 1, 3821, 1, 8925, 1 }, name = "Elixir of Greater Agility" },
        { 265, 285, p = 13443, s = 17553, n = 20, at = 260, r = { 8838, 2, 8839, 2, 8925, 1 }, name = "Superior Mana Potion" },
        { 285, 300, p = 13446, s = 17556, n = 18, at = 275, r = { 13464, 2, 13465, 1, 8925, 1 }, name = "Major Healing Potion" },
    },
    blacksmithing = {
        { 1, 30, p = 2862, s = 2660, n = 40, at = 1, r = { 2835, 1 }, name = "Rough Sharpening Stone" },
        { 30, 65, p = 3470, s = 3320, n = 60, r = { 2835, 2 }, name = "Rough Grinding Stone" },
        { 65, 75, p = 2863, s = 2665, n = 25, r = { 2836, 1 }, name = "Coarse Sharpening Stone" },
        { 75, 90, p = 3478, s = 3326, n = 35, r = { 2836, 2 }, name = "Coarse Grinding Stone" },
        { 90, 100, p = 2857, s = 2666, n = 10, r = { 2840, 10 }, name = "Runed Copper Belt" },
        { 100, 105, p = 6338, s = 7818, n = 5, r = { 2842, 1, 3470, 2 }, name = "Silver Rod" },
        { 105, 110, p = 2857, s = 2666, n = 5, r = { 2840, 10 }, name = "Runed Copper Belt" },
        { 110, 125, p = 2865, s = 2668, n = 15, r = { 2841, 6 }, name = "Rough Bronze Leggings" },
        { 125, 140, p = 3486, s = 3337, n = 35, r = { 2838, 3 }, name = "Heavy Grinding Stone" },
        { 140, 150, p = 2868, s = 2672, n = 10, r = { 2841, 5, 3478, 2 }, name = "Patterned Bronze Bracers" },
        { 150, 155, p = 11128, s = 14379, n = 5, r = { 3577, 1, 3478, 2 }, name = "Golden Rod" },
        { 155, 165, p = 3842, s = 3506, n = 10, r = { 3575, 8, 3486, 1, 2605, 1 }, name = "Green Iron Leggings" },
        { 165, 190, p = 3835, s = 3501, n = 25, r = { 3575, 6, 2605, 1 }, name = "Green Iron Bracers" },
        { 190, 200, p = 6040, s = 7223, n = 10, r = { 3859, 5, 3486, 2 }, name = "Golden Scale Bracers" },
        { 200, 210, p = 7966, s = 9920, n = 30, r = { 7912, 4 }, name = "Solid Grinding Stone" },
        { 210, 225, p = 7919, s = 9928, n = 15, r = { 3860, 6, 4338, 4 }, name = "Heavy Mithril Gauntlet" },
        { 225, 235, p = 7922, s = 9935, n = 10, r = { 3859, 14, 7966, 1 }, name = "Steel Plate Helm" },
        { 235, 250, p = 7931, s = 9961, n = 15, r = { 3860, 10, 4338, 6 }, name = "Mithril Coif", alts = {
            { p = 7969, s = 9964, learn = "drop", r = { 3860, 4 }, name = "Mithril Spurs", why = { "recipe" } } } },
        { 250, 260, p = 12404, s = 16641, n = 20, r = { 12365, 1 }, name = "Dense Sharpening Stone" },
        { 260, 270, p = 12406, s = 16643, n = 10, learn = "drop", r = { 12359, 12, 11186, 4 }, name = "Thorium Belt", alts = {
            { p = 7933, s = 9968, n = 7, r = { 3860, 14, 4304, 4 }, name = "Heavy Mithril Boots", lo = 260, hi = 265, why = { "other" } },
            { p = 12424, s = 16647, n = 5, learn = "quest", r = { 12359, 22, 8170, 6, 7909, 1 }, name = "Imperial Plate Belt", lo = 265, hi = 270, why = { "recipe" } } } },
        { 270, 275, p = 12408, s = 16644, n = 5, learn = "drop", r = { 12359, 12, 11184, 4 }, name = "Thorium Bracers", alts = {
            { p = 12425, s = 16649, n = 27, learn = "quest", r = { 12359, 20, 7910, 1 }, name = "Imperial Plate Bracers", lo = 270, hi = 295, why = { "recipe" } } } },
        { 275, 290, p = 12425, s = 16649, n = 15, learn = "quest", r = { 12359, 20, 7910, 1 }, name = "Imperial Plate Bracers" },
        { 290, 300, p = 12409, s = 16652, n = 10, learn = "drop", r = { 12359, 20, 8170, 8, 11185, 4 }, name = "Thorium Boots", alts = {
            { p = 12426, s = 16657, n = 5, learn = "quest", r = { 12359, 34, 7910, 1, 7909, 1 }, name = "Imperial Plate Boots", lo = 295, hi = 300, why = { "recipe" } },
            { p = 12419, s = 16656, n = 10, learn = "drop", r = { 12359, 14, 7077, 4 }, name = "Radiant Boots", lo = 290, hi = 300, why = { "recipe" } } } },
    },
    enchanting = {
        { 1, 2, p = 6218, s = 7421, n = 1, at = 1, r = { 6217, 1, 10940, 1, 10938, 1 }, name = "Runed Copper Rod" },
        { 2, 50, s = 7418, n = 48, at = 1, r = { 10940, 1 }, name = "Enchant Bracer - Minor Health" },
        { 50, 90, s = 7418, n = 60, at = 1, r = { 10940, 1 }, name = "Enchant Bracer - Minor Health" },
        { 90, 100, s = 7457, n = 10, at = 50, r = { 10940, 3 }, name = "Enchant Bracer - Minor Stamina" },
        { 100, 101, p = 6339, s = 7795, n = 1, at = 100, r = { 6338, 1, 10940, 6, 10939, 3, 1210, 1 }, name = "Runed Silver Rod" },
        { 101, 110, p = 11288, s = 14807, n = 9, at = 70, r = { 4470, 1, 10939, 1 }, name = "Greater Magic Wand" },
        { 110, 135, s = 13419, n = 25, at = 110, learn = "vendor", r = { 10998, 1 }, name = "Enchant Cloak - Minor Agility" },
        { 135, 155, s = 13501, n = 20, at = 130, r = { 11083, 2 }, name = "Enchant Bracer - Lesser Stamina" },
        { 155, 156, p = 11130, s = 13628, n = 1, at = 150, r = { 11128, 1, 5500, 1, 11082, 2, 11083, 2 }, name = "Runed Golden Rod" },
        { 156, 185, s = 13536, n = 40, at = 140, learn = "vendor", r = { 11083, 2 }, name = "Enchant Bracer - Lesser Strength" },
        { 185, 200, s = 13661, n = 15, at = 180, r = { 11137, 1 }, name = "Enchant Bracer - Strength" },
        { 200, 201, p = 11145, s = 13702, n = 1, at = 200, r = { 11144, 1, 7971, 1, 11135, 2, 11137, 2 }, name = "Runed Truesilver Rod" },
        { 201, 220, s = 13661, n = 25, at = 180, r = { 11137, 1 }, name = "Enchant Bracer - Strength" },
        { 220, 225, s = 13746, n = 5, at = 205, r = { 11137, 3 }, name = "Enchant Cloak - Greater Defense" },
        { 225, 230, s = 13815, n = 5, at = 210, r = { 11174, 1, 11137, 1 }, name = "Enchant Gloves - Agility" },
        { 230, 235, s = 13836, n = 5, at = 215, r = { 11137, 5 }, name = "Enchant Boots - Stamina" },
        { 235, 250, s = 13858, n = 25, at = 220, r = { 11137, 6 }, name = "Enchant Chest - Superior Health" },
        { 250, 265, p = 20747, s = 25127, n = 20, at = 250, learn = "vendor", r = { 11176, 3, 8831, 2, 8925, 1 }, name = "Lesser Mana Oil" },
        { 265, 294, s = 20017, n = 30, at = 265, learn = "vendor", r = { 11176, 10 }, name = "Enchant Shield - Greater Stamina" },
        { 294, 295, p = 16207, s = 20051, n = 1, at = 290, learn = "vendor", r = { 16206, 1, 13926, 1, 16204, 10, 16203, 4, 14343, 4, 14344, 2 }, name = "Runed Arcanite Rod" },
        { 295, 300, s = 20015, n = 5, at = 285, r = { 16204, 8 }, name = "Enchant Cloak - Superior Defense" },
    },
    engineering = {
        { 1, 30, p = 4357, s = 3918, n = 60, r = { 2835, 1 }, name = "Rough Blasting Powder" },
        { 30, 50, p = 4359, s = 3922, n = 30, r = { 2840, 1 }, name = "Handful of Copper Bolts" },
        { 50, 51, p = 6219, s = 7430, n = 1, at = 50, r = { 2840, 6 }, name = "Arclight Spanner" },
        { 51, 75, p = 4360, s = 3923, n = 30, r = { 2840, 1, 4359, 1, 4357, 2, 2589, 1 }, name = "Rough Copper Bomb" },
        { 75, 90, p = 4364, s = 3929, n = 60, r = { 2836, 1 }, name = "Coarse Blasting Powder" },
        { 90, 100, p = 4365, s = 3931, n = 20, r = { 4364, 3, 2589, 1 }, name = "Coarse Dynamite" },
        { 100, 105, p = 4404, s = 3973, n = 5, r = { 2842, 1 }, name = "Silver Contact" },
        { 105, 125, p = 4371, s = 3938, n = 25, r = { 2841, 2, 2880, 1 }, name = "Bronze Tube" },
        { 125, 135, p = 4406, s = 3978, n = 10, r = { 4371, 1, 1206, 1 }, name = "Standard Scope" },
        { 135, 145, p = 4377, s = 3945, n = 30, r = { 2838, 1 }, name = "Heavy Blasting Powder" },
        { 145, 150, p = 4375, s = 3942, n = 15, r = { 2841, 2, 2592, 1 }, name = "Whirring Bronze Gizmo" },
        { 150, 160, p = 4382, s = 3953, n = 15, r = { 2841, 2, 2319, 1, 2592, 1 }, name = "Bronze Framework" },
        { 160, 175, p = 4384, s = 3955, n = 15, r = { 4382, 1, 4375, 1, 4377, 2, 2592, 2 }, name = "Explosive Sheep" },
        { 175, 176, p = 10498, s = 12590, n = 1, at = 175, r = { 3859, 4 }, name = "Gyromatic Micro-Adjustor" },
        { 176, 195, p = 10505, s = 12585, n = 60, r = { 7912, 2 }, name = "Solid Blasting Powder" },
        { 195, 200, p = 10559, s = 12589, n = 7, r = { 3860, 3 }, name = "Mithril Tube" },
        { 200, 215, p = 10560, s = 12591, n = 20, r = { 3860, 1, 4338, 1, 10505, 1 }, name = "Unstable Trigger" },
        { 215, 238, p = 10561, s = 12599, n = 40, r = { 3860, 3 }, name = "Mithril Casing" },
        { 238, 250, p = 10562, s = 12619, n = 20, at = 235, r = { 10561, 2, 10560, 1, 10505, 2 }, name = "Hi-Explosive Bomb" },
        { 250, 260, p = 15992, s = 19788, n = 30, at = 250, r = { 12365, 2 }, name = "Dense Blasting Powder" },
        { 260, 285, p = 15994, s = 19791, n = 35, learn = "vendor", r = { 12359, 3, 14047, 1 }, name = "Thorium Widget" },
        { 285, 300, p = 15997, s = 19800, n = 15, learn = "drop", r = { 12359, 2, 15992, 1 }, name = "Thorium Shells", alts = {
            { p = 16000, s = 19795, r = { 12359, 6 }, name = "Thorium Tube", why = { "other" } } } },
    },
    leatherworking = {
        { 1, 30, p = 2318, n = 30, at = 1, r = { 2934, 3 }, name = "Light Leather" },
        { 30, 45, p = 2304, n = 18, at = 1, r = { 2318, 1 }, name = "Light Armor Kit" },
        { 45, 55, p = 4231, n = 10, at = 35, r = { 783, 1, 4289, 1 }, name = "Cured Light Hide" },
        { 55, 85, p = 4239, n = 30, at = 55, r = { 2318, 3, 2320, 2 }, name = "Embossed Leather Gloves" },
        { 85, 100, p = 4246, n = 15, at = 80, r = { 2318, 6, 2320, 2 }, name = "Fine Leather Belt" },
        { 100, 115, p = 4233, n = 15, at = 100, r = { 4232, 1, 4289, 1 }, name = "Cured Medium Hide" },
        { 115, 125, p = 2315, n = 10, at = 100, r = { 2319, 4, 2321, 2, 4340, 1 }, name = "Dark Leather Boots" },
        { 125, 135, p = 2315, n = 12, at = 100, r = { 2319, 4, 2321, 2, 4340, 1 }, name = "Dark Leather Boots" },
        { 135, 150, p = 4249, n = 15, at = 125, r = { 4246, 1, 4233, 1, 2321, 2, 4340, 1 }, name = "Dark Leather Belt" },
        { 150, 155, p = 4234, n = 5, at = 150, r = { 2319, 5 }, name = "Heavy Leather" },
        { 155, 160, p = 4236, n = 5, at = 150, r = { 4235, 1, 4289, 3 }, name = "Cured Heavy Hide" },
        { 160, 180, p = 4265, n = 22, at = 150, r = { 4234, 5, 2321, 1 }, name = "Heavy Armor Kit" },
        { 180, 190, p = 5964, n = 10, at = 175, r = { 4234, 8, 4236, 1, 2321, 2 }, name = "Barbaric Shoulders" },
        { 190, 200, p = 5966, n = 10, at = 190, r = { 4234, 4, 4236, 1, 4291, 1 }, name = "Guardian Gloves" },
        { 200, 220, p = 8173, n = 20, at = 200, r = { 4304, 5, 4291, 1 }, name = "Thick Armor Kit" },
        { 220, 230, p = 8176, n = 11, at = 205, r = { 4304, 5, 4291, 2 }, name = "Nightscape Headband" },
        { 230, 250, p = 8193, n = 20, at = 230, r = { 4304, 14, 4291, 4 }, name = "Nightscape Pants" },
        { 250, 260, p = 15564, n = 12, at = 250, r = { 8170, 5 }, name = "Rugged Armor Kit" },
        { 260, 290, p = 15083, n = 32, at = 260, learn = "vendor", r = { 8170, 8, 2325, 1, 14341, 1 }, name = "Wicked Leather Gauntlets" },
        { 290, 300, p = 15086, n = 10, at = 280, learn = "drop", r = { 8170, 12, 2325, 1, 14341, 1 }, name = "Wicked Leather Headband", alts = {
            { p = 15084, at = 265, learn = "drop", r = { 8170, 8, 2325, 1, 14341, 1 }, name = "Wicked Leather Bracers", why = { "recipe", "cheap" } },
            { p = 15087, at = 290, learn = "drop", r = { 8170, 16, 15407, 1, 2325, 3, 14341, 1 }, name = "Wicked Leather Pants", why = { "recipe", "other" } },
            { p = 15083, at = 260, learn = "vendor", r = { 8170, 8, 2325, 1, 14341, 1 }, name = "Wicked Leather Gauntlets", why = { "cheap" } } } },
    },
    tailoring = {
        { 1, 45, p = 2996, s = 2963, n = 95, at = 1, r = { 2589, 2 }, name = "Bolt of Linen Cloth" },
        { 45, 70, p = 7026, s = 8776, n = 25, at = 10, r = { 2996, 1, 2320, 1 }, name = "Linen Belt", alts = {
            { p = 6238, s = 7623, at = 30, r = { 2996, 3, 2320, 1 }, name = "Brown Linen Robe", why = { "other" } },
            { p = 4238, s = 3755, n = 25, at = 45, r = { 2996, 3, 2320, 3 }, name = "Linen Bag", lo = 50, hi = 75, why = { "sells", "cheap" } } } },
        { 70, 75, p = 2580, s = 2397, n = 5, at = 60, r = { 2996, 2, 2320, 3 }, name = "Reinforced Linen Cape" },
        { 75, 100, p = 2997, s = 2964, n = 45, at = 75, r = { 2592, 3 }, name = "Bolt of Woolen Cloth" },
        { 100, 110, p = 10047, s = 12046, n = 15, at = 75, r = { 2996, 4, 2321, 1 }, name = "Simple Kilt", alts = {
            { p = 4240, s = 3757, n = 12, at = 80, r = { 2997, 3, 2321, 1 }, name = "Woolen Bag", lo = 107, hi = 115, why = { "sells" } } } },
        { 110, 125, p = 4314, s = 3848, n = 15, at = 110, r = { 2997, 3, 2321, 2 }, name = "Double-stitched Woolen Shoulders", alts = {
            { p = 5763, s = 6688, n = 10, at = 115, learn = "vendor", r = { 2997, 4, 2604, 1, 2321, 1 }, name = "Red Woolen Bag", lo = 115, hi = 125, why = { "recipe", "sells" } } } },
        { 125, 145, p = 4305, s = 3839, n = 205, at = 125, r = { 4306, 4 }, name = "Bolt of Silk Cloth" },
        { 145, 160, p = 7048, s = 8760, n = 20, at = 145, r = { 4305, 2, 2321, 1, 6260, 2 }, name = "Azure Silk Hood", alts = {
            { p = 5763, s = 6688, n = 8, at = 115, learn = "vendor", r = { 2997, 4, 2604, 1, 2321, 1 }, name = "Red Woolen Bag", lo = 145, hi = 150, why = { "recipe", "sells" } },
            { p = 4245, s = 3813, n = 25, at = 150, r = { 4305, 3, 2321, 3, 4234, 2 }, name = "Small Silk Pack", lo = 150, hi = 175, why = { "sells" } },
            { p = 4324, s = 3859, n = 25, at = 150, r = { 4305, 5, 6260, 4 }, name = "Azure Silk Vest", lo = 150, hi = 175, why = { "other" } } } },
        { 160, 170, p = 7050, s = 8762, n = 10, at = 160, r = { 4305, 3, 2321, 2 }, name = "Silk Headband" },
        { 170, 175, p = 4334, s = 3871, n = 5, at = 170, r = { 4305, 3, 2321, 1, 2324, 2 }, name = "Formal White Shirt" },
        { 175, 185, p = 4339, s = 3865, n = 100, at = 175, r = { 4338, 5 }, name = "Bolt of Mageweave" },
        { 185, 205, p = 7058, s = 8791, n = 20, at = 185, r = { 4305, 4, 2321, 2, 2604, 2 }, name = "Crimson Silk Vest", alts = {
            { p = 7053, s = 8786, n = 25, at = 175, learn = "vendor", r = { 4305, 3, 2321, 2, 6260, 2 }, name = "Azure Silk Cloak", why = { "recipe", "sells" } } } },
        { 205, 215, p = 7062, s = 8799, n = 10, at = 195, r = { 4305, 4, 4291, 2, 2604, 2 }, name = "Crimson Silk Pantaloons", alts = {
            { p = 9999, s = 12049, n = 20, at = 205, r = { 4339, 2, 4291, 3 }, name = "Black Mageweave Leggings", lo = 205, hi = 225, why = { "sells", "cheap" } } } },
        { 215, 220, p = 10056, s = 12061, n = 5, at = 215, r = { 4339, 1, 8343, 1, 6261, 1 }, name = "Orange Mageweave Shirt" },
        { 220, 230, p = 10003, s = 12053, n = 10, at = 215, r = { 4339, 2, 8343, 2 }, name = "Black Mageweave Gloves", alts = {
            { p = 10050, s = 12065, n = 30, at = 225, r = { 4339, 4, 4291, 2 }, name = "Mageweave Bag", lo = 225, hi = 250, why = { "sells" } } } },
        { 230, 250, p = 10024, s = 12072, n = 25, at = 230, r = { 4339, 3, 8343, 2 }, name = "Black Mageweave Headband" },
        { 250, 260, p = 14048, s = 18401, n = 155, at = 250, r = { 14047, 5 }, name = "Bolt of Runecloth" },
        { 260, 280, p = 13856, s = 18402, n = 25, at = 255, r = { 14048, 3, 14341, 1 }, name = "Runecloth Belt", alts = {
            { p = 14046, s = 18405, n = 35, at = 260, learn = "vendor", r = { 14048, 5, 8170, 2, 14341, 1 }, name = "Runecloth Bag", lo = 260, hi = 290, why = { "recipe", "sells" } } } },
        { 280, 300, p = 13863, s = 18417, n = 20, at = 275, learn = "vendor", r = { 14048, 4, 8170, 4, 14341, 1 }, name = "Runecloth Gloves", alts = {
            { p = 13856, s = 18402, at = 255, r = { 14048, 3, 14341, 1 }, name = "Runecloth Belt", why = { "other" } } } },
    },
    cooking = {
        { 1, 50, p = 6290, n = 50, at = 1, learn = "vendor", r = { 6291, 1 }, name = "Brilliant Smallfish", alts = {
            { p = 2679, at = 1, r = { 2672, 1 }, name = "Charred Wolf Meat", why = { "other" } },
            { p = 2681, at = 1, r = { 769, 1 }, name = "Roasted Boar Meat", why = { "other" } } } },
        { 50, 100, p = 4592, n = 50, at = 50, learn = "vendor", r = { 6289, 1 }, name = "Longjaw Mud Snapper", alts = {
            { p = 2684, at = 50, r = { 2673, 1 }, name = "Coyote Steak", why = { "other" } },
            { p = 2687, at = 80, r = { 2677, 1, 2678, 1 }, name = "Dry Pork Ribs", why = { "other" } },
            { p = 5477, m = 2, at = 50, learn = "vendor", r = { 5469, 1, 4536, 1 }, name = "Strider Stew", why = { "other" } },
            { p = 7676, at = 60, learn = "quest", r = { 2452, 1, 159, 1 }, name = "Thistle Tea", why = { "useful", "recipe" } } } },
        { 100, 150, p = 4593, n = 50, at = 100, learn = "vendor", r = { 6308, 1 }, name = "Bristle Whisker Catfish", alts = {
            { p = 2684, at = 50, r = { 2673, 1 }, name = "Coyote Steak", why = { "other" } },
            { p = 2687, at = 80, r = { 2677, 1, 2678, 1 }, name = "Dry Pork Ribs", why = { "other" } },
            { p = 7676, at = 60, learn = "quest", r = { 2452, 1, 159, 1 }, name = "Thistle Tea", why = { "useful", "recipe" } },
            { p = 3665, at = 130, learn = "vendor", r = { 3685, 1, 2692, 1 }, name = "Curiously Tasty Omelet", why = { "other" } } } },
        { 150, 175, p = 4593, n = 70, at = 100, learn = "vendor", r = { 6308, 1 }, name = "Bristle Whisker Catfish", alts = {
            { p = 3665, at = 130, learn = "vendor", r = { 3685, 1, 2692, 1 }, name = "Curiously Tasty Omelet", why = { "other" } } } },
        { 175, 225, p = 8364, n = 60, at = 175, learn = "vendor", r = { 8365, 1 }, name = "Mithril Headed Trout", alts = {
            { p = 12210, at = 175, learn = "vendor", r = { 12184, 1, 2692, 1 }, name = "Roast Raptor", why = { "other" } },
            { p = 4594, at = 175, learn = "vendor", r = { 6362, 1 }, name = "Rockscale Cod", why = { "other" } } } },
        { 225, 275, p = 6887, n = 70, at = 225, learn = "vendor", r = { 4603, 1 }, name = "Spotted Yellowtail" },
        { 275, 300, p = 13934, n = 25, at = 275, learn = "vendor", r = { 13893, 1, 2692, 1, 3713, 1 }, name = "Mightfish Steak", alts = {
            { p = 13933, at = 275, learn = "vendor", r = { 13888, 1, 159, 1 }, name = "Lobster Stew", why = { "other" } },
            { p = 13935, at = 275, learn = "vendor", r = { 13889, 1, 3713, 1 }, name = "Baked Salmon", why = { "other" } } } },
    },
    firstaid = {
        { 1, 40, p = 1251, at = 1, r = { 2589, 1 }, name = "Linen Bandage" },
        { 40, 50, p = 2581, at = 40, r = { 2589, 2 }, name = "Heavy Linen Bandage" },
        { 50, 80, p = 2581, at = 40, r = { 2589, 2 }, name = "Heavy Linen Bandage" },
        { 80, 115, p = 3530, at = 80, r = { 2592, 1 }, name = "Wool Bandage" },
        { 115, 125, p = 3531, at = 115, r = { 2592, 2 }, name = "Heavy Wool Bandage" },
        { 125, 150, p = 3531, at = 115, r = { 2592, 2 }, name = "Heavy Wool Bandage" },
        { 150, 180, p = 6450, at = 150, r = { 4306, 1 }, name = "Silk Bandage" },
        { 180, 210, p = 6451, at = 180, learn = "vendor", r = { 4306, 2 }, name = "Heavy Silk Bandage" },
        { 210, 225, p = 8544, at = 210, learn = "vendor", r = { 4338, 1 }, name = "Mageweave Bandage" },
        { 225, 240, p = 8544, at = 210, learn = "vendor", r = { 4338, 1 }, name = "Mageweave Bandage" },
        { 240, 260, p = 8545, at = 240, r = { 4338, 2 }, name = "Heavy Mageweave Bandage" },
        { 260, 290, p = 14529, at = 260, r = { 14047, 1 }, name = "Runecloth Bandage", alts = {
            { p = 8545, at = 240, r = { 4338, 2 }, name = "Heavy Mageweave Bandage", why = { "other" } } } },
        { 290, 300, p = 14530, at = 290, r = { 14047, 2 }, name = "Heavy Runecloth Bandage", alts = {
            { p = 8545, at = 240, r = { 4338, 2 }, name = "Heavy Mageweave Bandage", why = { "other" } } } },
    },
    mining = {
        { 1, 65, gather = 2770, name = "Copper Vein", alts = {
            { p = 2840, s = 2657, at = 1, r = { 2770, 1 }, name = "Smelt Copper", why = { "gathered" } } } },
        { 65, 125, gather = 2771, name = "Tin Vein", alts = {
            { gather = 2775, name = "Silver Vein" },
            { p = 3576, s = 3304, at = 65, r = { 2771, 1 }, name = "Smelt Tin", why = { "gathered" } },
            { p = 2841, s = 2659, m = 2, at = 65, r = { 2840, 1, 3576, 1 }, name = "Smelt Bronze", why = { "gathered" } },
            { p = 2842, s = 2658, at = 75, r = { 2775, 1 }, name = "Smelt Silver", why = { "gathered" } } } },
        { 125, 175, gather = 2772, name = "Iron Deposit", alts = {
            { gather = 2776, name = "Gold Vein" },
            { p = 3575, s = 3307, at = 125, r = { 2772, 1 }, name = "Smelt Iron", why = { "gathered" } },
            { p = 3577, s = 3308, at = 155, r = { 2776, 1 }, name = "Smelt Gold", why = { "gathered" } } } },
        { 175, 245, gather = 3858, name = "Mithril Deposit", alts = {
            { gather = 7911, name = "Truesilver Deposit" } } },
        { 245, 300, gather = 10620, name = "Small Thorium Vein", alts = {
            { gather = 10620, name = "Rich Thorium Vein" } } },
    },
}
