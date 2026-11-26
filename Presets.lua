-- ControllerCam built-in profiles.
--
-- A profile only lists what it wants different from the game. Everything it does not mention is reset to the
-- game's default, so "classic" is simply an empty profile and switching profiles never leaves settings behind.
-- "x1.2" means 1.2 times the game's default (used for speeds, so no default has to be guessed).
-- Built-in profiles are read-only: duplicate one to change it.

local ADDON, ns = ...
local L = ns.L

-- Over-the-shoulder offset by camera distance. A sideways offset in yards covers more of the screen the closer
-- the camera is, so a fixed offset throws the character out of view when you zoom in. The offset therefore grows
-- in proportion to the distance (the character stays in about the same place on screen): `offset` at `ramp`
-- yards, and on at the same rate to `hold` (it used to stop growing at `ramp`, and between the two the character
-- drifted toward the middle of the screen), then fades to 0 at `fade`.
local function ShoulderCurve(offset, ramp, hold, fade)
    local points = { { 0, 0 }, { ramp, offset } }
    if hold > ramp then points[#points + 1] = { hold, math.floor(offset * hold / ramp * 10 + 0.5) / 10 } end
    points[#points + 1] = { fade, 0 }
    return points
end

-- The camera of the recommended setup (the Action profile) by zoom view, one value for each of ns.ZOOM_VIEWS:
--   first person | over the shoulder (2-3.5 yd) | upper body (4.5-6) | whole body (7-10) | mid (13-20) | far (24+)
-- offset: yards to the side. Strong over the shoulder, half a yard less with the whole body in sight, and the
-- game's own centred ("classic") camera from the mid range out.
-- focus: the share of the target focus strength: hardest over the shoulder and at the upper body, letting go as
-- the camera goes out.
-- fov: the share of your own field of view. Only the editor uses it (switching "field of view by zoom" on);
-- no built-in profile sets one, as the game is not known to have such a setting.
ns.VIEW_DEFAULTS = {
    shoulderCurve = { 0, 1.5, 1.5, 1,   0,   0    },
    focusCurve    = { 0, 1,   1,   0.6, 0.3, 0    },
    fovCurve      = { 1, 0.92, 0.95, 1,  1,  1.05 },
}

-- In the water you face the way you do on land: the game's "face movement direction when swimming" stays off.
-- With it on, your character turned to the side of the stick as soon as it swam (the camera followed, and the
-- shoulder offset swung with it). It can be turned on again in a profile of your own.
--
-- id, English name, English description, values. Listed in the order shown in menus: the recommended setup's
-- camera first, Classic last.
local BUILTIN = {
    {
        id = "action",
        name = "Action",
        desc = "The out-of-the-box feel: over your shoulder up close, easing to the middle as you zoom out, turning toward your target most when you are near. Head tracking, and the camera follows where you run.",
        values = {
            followTerrain = 0,
            zoom = 7, zoomMax = 2.2,
            yawSpeed = "x1.25", pitchSpeed = "x1.15",
            followOnStick = 1, followYawSpeed = "x1.2", followDelay = "x0.8",
            faceAngle = 0, faceAngleCombat = 180, turnWithCamera = 1,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ns.CurveFromViews(ns.VIEW_DEFAULTS.shoulderCurve),
            dynamicPitch = 1,
            headStrength = 1, headStanding = 0.3, headMoving = 0.5, headRange = 5,
            focusEnemy = 1, focusEnemyYaw = 1, focusEnemyPitch = 0.75,
            focusCurve = ns.CurveFromViews(ns.VIEW_DEFAULTS.focusCurve),
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
        },
    },
    {
        id = "hybrid",
        name = "Hybrid",
        desc = "Between Classic and Action: a medium distance, a light over-the-shoulder offset and gentle head tracking. The camera follows your movement, but you still get a wide view.",
        values = {
            followTerrain = 0,
            zoom = 11,
            yawSpeed = "x1.1", pitchSpeed = "x1.1",
            followOnStick = 1,
            faceAngle = 115, faceAngleCombat = 180, turnWithCamera = 1,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ShoulderCurve(1, 4, 10, 22),
            headStrength = 0.5, headStanding = 0.3, headMoving = 0.5,
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
        },
    },
    {
        id = "shooter",
        name = "Shooter",
        desc = "A third-person shooter feel: tight camera, a strong shoulder offset, fast stick aim. You run facing your movement outside combat and strafe facing the camera in combat.",
        values = {
            followTerrain = 0,
            zoom = 5, zoomMax = 1.6,
            yawSpeed = "x1.4", pitchSpeed = "x1.3",
            followOnStick = 0,
            faceAngle = 0, faceAngleCombat = 180, turnWithCamera = 1,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ShoulderCurve(2, 5, 8, 16),
            headStrength = 0.6, headStanding = 0.2, headMoving = 0.4,
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
        },
    },
    {
        id = "tactical",
        name = "Tactical",
        desc = "Even closer and steadier, for cover-shooter play: your character always turns with the camera, the shoulder offset is large and the camera does not drift on its own.",
        values = {
            followTerrain = 0,
            zoom = 3.5, zoomMax = 1.4,
            yawSpeed = "x1.6", pitchSpeed = "x1.4",
            followOnStick = 0,
            faceAngle = 90, faceAngleCombat = 180, turnWithCamera = 2,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ShoulderCurve(1.5, 3.5, 6, 12),
            headStrength = 0.4, headStanding = 0.2, headMoving = 0.3,
        },
    },
    {
        id = "cinematic",
        name = "Cinematic",
        desc = "Slow, wide and moody, for questing and screenshots: dynamic pitch, strong head tracking and a camera that turns toward whoever you talk to.",
        values = {
            followTerrain = 0,
            zoom = 12,
            yawSpeed = "x0.75", pitchSpeed = "x0.75",
            followOnStick = 1, followYawSpeed = "x0.7", followPitchSpeed = "x0.7",
            faceAngle = 0, faceAngleCombat = 115, turnWithCamera = 1,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ShoulderCurve(1.5, 6, 12, 25),
            dynamicPitch = 1,
            headStrength = 1, headStanding = 0.5, headMoving = 0.7, headRange = 6,
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
            smoothStyle = 2,
        },
    },
    {
        id = "targetlock",
        name = "Target focus",
        desc = "The camera leans toward your current target and the NPCs you talk to. Good for single-target fights.",
        values = {
            followTerrain = 0,
            zoom = 10,
            followOnStick = 1,
            faceAngle = 115, faceAngleCombat = 180, turnWithCamera = 3,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            shoulderCurve = ShoulderCurve(1, 4, 6, 12),
            headStrength = 0.4,
            focusEnemy = 1, focusEnemyYaw = 0.5, focusEnemyPitch = 0.4,
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
        },
    },
    {
        id = "raid",
        name = "Raid view",
        desc = "A far, steady camera for dungeons and raids: no offset, no head tracking, no camera drift and fast stick turning so you can see the whole fight.",
        values = {
            followTerrain = 0,
            zoom = 18,
            yawSpeed = "x1.2", pitchSpeed = "x1.2",
            followOnStick = 0,
            faceAngle = 115, faceAngleCombat = 180, turnWithCamera = 1,
        },
    },
    {
        id = "cruise",
        name = "Mounted cruise",
        desc = "For riding: a far camera that swings behind you as you steer. The offset is off, because mounts of different sizes make it unreliable.",
        values = {
            followTerrain = 0,
            zoom = 16,
            followOnStick = 1, followYawSpeed = "x1.3",
            faceAngle = 0, faceMount = 1, faceSwim = 0, faceFly = 1,
            headStrength = 0.3, headStanding = 0.2, headMoving = 0.3,
        },
    },
    {
        id = "skies",
        name = "Flying",
        desc = "For flying: a far camera that follows your climb and dive.",
        values = {
            followTerrain = 0,
            zoom = 20,
            followOnStick = 1, followPitchSpeed = "x1.5",
            faceAngle = 0, faceMount = 1, faceSwim = 0, faceFly = 1,
        },
    },
    {
        id = "stroll",
        name = "Town stroll",
        desc = "A relaxed, slower camera for cities: closer, calm and with head tracking.",
        values = {
            followTerrain = 0,
            zoom = 7,
            yawSpeed = "x0.85", pitchSpeed = "x0.85",
            followOnStick = 1,
            faceAngle = 0, faceAngleCombat = 115, turnWithCamera = 1,
            faceMount = 1, faceSwim = 0, faceFly = 1,
            -- ShoulderCurve(1, 4, 6, 12), with half a yard more on the closest steps: at the last one before
            -- first person the character stood in the view. 1 from 2 yards in to 4; as before from 4 out.
            shoulderCurve = { { 0, 0 }, { 0.5, 0.6 }, { 2, 1 }, { 4, 1 }, { 6, 1.5 }, { 12, 0 } },
            dynamicPitch = 1,
            headStrength = 0.7, headStanding = 0.4, headMoving = 0.5,
            focusInteract = 1, focusInteractYaw = 1, focusInteractPitch = 0.75,
        },
    },
    -- last on purpose: the game's own camera, for those who only want the HUD
    {
        id = "classic",
        name = "Classic",
        desc = "The game's own camera: every setting ControllerCam manages goes back to its default. Your camera distance and your terrain-following setting are left as they are.",
        values = {},
    },
}

ns.BUILTIN_LIST = BUILTIN
ns.BUILTIN = {}
for _, p in ipairs(BUILTIN) do ns.BUILTIN[p.id] = p end

-- What a fresh install uses: the Action camera everywhere, with calmer profiles where the situation calls for it.
-- "combat" is left empty on purpose, so the profile of the place you are in (dungeon, raid, ...) stays. So is
-- "swimming": going into the water swapped the camera to another profile, whose shoulder offset and facing angle
-- differ, and the camera jumped sideways and turned your character as you went in. In the water the camera you
-- had stays.
ns.STARTER = {
    default  = "action",
    city     = "stroll",
    dungeon  = "action",
    raid     = "raid",
    mounted  = "cruise",
    flying   = "skies",
    vehicle  = "hybrid",
    fishing  = "shooter",       -- when you cast your line: close over the shoulder, looking out at the float
}
