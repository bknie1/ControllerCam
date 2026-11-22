-- ControllerCam HUD: the game's experimental features notice.
-- The game asks at every login whether you accept its experimental features. The HUD used to answer it for
-- you once you had said yes yourself. It no longer does, and cannot: answering means pressing a button of the
-- game's own dialog from an addon, and everything the game does on that press (closing the dialog, handing
-- the controller back) then runs in the addon's name. The game stops trusting it, and the gamepad bars
-- refused their own buttons later on (seen 2026-11-20, after a vendor; a reload cured it until the next
-- login answered the notice again). The game's dialogs are the game's: the HUD neither shows nor presses them.
--
-- What is left here is the tidying: the switch and the list of accepted notices leave the saved settings.
-- Not asking at every login is the camera addon's job now (ControllerCam's Core.lua, "The game's notice about
-- experimental camera settings"): after you accept the notice yourself, the game is no longer told to ask.

local ADDON, ns = ...

ns.Notices = { answered = 0 }
ns.RegisterSaved("acceptedNotices", function() return nil end)
ns.RegisterSaved("autoNotice", function() return nil end)
