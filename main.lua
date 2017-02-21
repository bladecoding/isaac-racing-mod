--
-- The Racing+ Lua Mod
-- by Zamiel
--

--[[

TODO:
- check for exception list in room search for dead
- Add trophy for finish, add fireworks for first place: https://www.reddit.com/r/bindingofisaac/comments/5r4vmb/spawn_1000104/
- Integrate 1st place, 2nd place, etc. on screen
- forget me now after killing boss, go back to B1
- Fix unseeded Boss heart drops from Pin, etc. (and make it so that they drop during door opening)
- Make Devil / Angel Rooms given in order and independent of floor

TODO CAN'T FIX:
- Automatically enable BLCK CNDL seed (not possible with current bindings)
- Automatically enter in a seed for seeded races (not possible with current bindings)
- Make timer on the screen use real time
- Make Teleport / Undefined / Cursed Eye / Telepills seeded (the ChangeRoom() function is broken and doesn't actually consistently send you to the room that you specify)
- Fix shop "item on sale" bug (setting price to anything other than 15 just causes it to go back to 15 on the next frame)
- Fix shop pedestal items "rerolling into consumables" bug
- Do item bans in a proper way via editing item pools (not possible to modify item pools via current bindings)
  - When spawning an item via the console (like "spawn 5.100.12"), it removes it from item pools.
  - When spawning a specific item with Lua (like "game:Spawn(5, 100, Vector(300, 300), Vector(0, 0), nil, 12, 0)"), it does not remove it from any pools.
  - When spawning a random item with Lua (like "game:Spawn(5, 100, Vector(300, 300), Vector(0, 0), nil, 0, 0)"), it removes it from item pools.
  - When giving the player an item with Lua (like "player:AddCollectible(race.startingItems[i], 12, true)"), it does not remove it from any pools.
- Skip the fade in and fade out animation when traveling to the next floor (need console access or the "StartStageTransition()" function's second argument to be working)
- Stop the player from being teleported upon entering a room with Gurdy, Mom's Heart, or It Lives (Isaac is placed in the location and you can't move him fast enough)
- Fix Dead Eye on red poop / static TNT barrels (can't modify existing items)

--]]

-- Register the mod (the second argument is the API version)
local RacingPlus = RegisterMod("Racing+", 1)

-- Global variables
local run = {
  initializing          = false,
  roomsCleared          = 0,
  roomsEntered          = 0,
  roomEntering          = false,
  currentFloor          = 1,
  currentRoomClearState = true,
  currentGlobins        = {},
  currentKnights        = {},
  replacedItems         = {},
  replacedTrinkets      = {},
  placedKeys            = false,
  keeperBaseHearts      = 4, -- Either 4 (for base), 2, 0, -2, -4, -6, etc.
  keeperHealthItems     = {},
  spawnedCoop           = false,
  schoolBagItem         = 0,
  schoolBagMaxCharges   = 0,
  schoolBagCharges      = 0,
  schoolBagFrame        = 0, -- The frame at which the "cooldown" wears off and we can switch items again
}
local raceLoadNextFrame = false
local race = { -- The table that gets updated from the "save.dat" file
  status          = "none",      -- Can be "none", "open", "starting", "in progress"
  rType           = "unranked",  -- Can be "unranked", "ranked" (this is not currently used)
  rFormat         = "unseeded",  -- Can be "unseeded", "seeded", "diveristy", "custom"
  character       = "Judas",     -- Can be the name of any character
  goal            = "Blue Baby", -- Can be "Blue Baby", "The Lamb", "Mega Satan"
  seed            = "-",         -- Corresponds to the seed that is the race goal
  startingItems   = {},          -- The starting items for this race
  schoolBag       = false,       -- Whether or not this race will have double active items
  currentSeed     = "-",         -- The seed of our current run (detected through the "log.txt" file)
  countdown       = -1,          -- This corresponds to the graphic to draw on the screen
}
local raceVars = { -- Things that pertain to the race but are not read from the "save.dat" file
  runInitForRaceDone = false,
  blckCndlOn         = false,
  difficulty         = 0,
  character          = "Isaac",
  itemBanList        = {},
  trinketBanList     = {},
  hourglassUsed      = false,
  started            = false,
  startedTime        = 0,
  updateCache        = 0, -- 0 is not update, 1 is set to update after the next run begins, 2 is after the next run has begun
}
local RNGCounter = {
  InitialSeed,
  BookOfSin,
  Teleport,
  Undefined,
  SackOfPennies,
  BombBag,
  JuicySack,
  MysterySack,
  LilChest,
  RuneBag,
  AcidBaby,
  SackOfSacks,
}
local spriteTable = {}
local spriteTableSchoolBag = {}
CollectibleType.COLLECTIBLE_BOOK_OF_SIN_SEEDED = 43
local megaBlastPlaceholder = Isaac.GetItemIdByName("Mega Blast (Placeholder)")

-- Welcome banner
Isaac.DebugString("+----------------------+")
Isaac.DebugString("| Racing+ initialized. |")
Isaac.DebugString("+----------------------+")

--
-- Table subroutines
-- From: http://lua-users.org/wiki/TableUtils
--

function tableval_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and tabletostring( v ) or
      tostring( v )
  end
end

function tablekey_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. tableval_to_str( k ) .. "]"
  end
end

function tabletostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, tableval_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        tablekey_to_str( k ) .. "=" .. tableval_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end

--
-- Math subroutines
--

-- From: http://lua-users.org/wiki/SimpleRound
function round(num, numDecimalPlaces)
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

--
-- Sprite subroutines
--

-- Call this once to load the PNG from the anm2 file
function spriteInit(spriteType, spriteName)
  -- If this is a new sprite type, initialize it in the sprite table
  if spriteTable[spriteType] == nil then
    spriteTable[spriteType] = {}
  end

  -- Do nothing if this sprite type is already set to this name
  if spriteTable[spriteType].spriteName == spriteName then
    return
  end

  -- Check to see if we are clearing this sprite
  if spriteName == 0 then
    spriteTable[spriteType].sprite = nil
    spriteTable[spriteType].spriteName = 0
    return
  end

  -- Otherwise, initialize the sprite
  spriteTable[spriteType].sprite = Sprite()
  spriteTable[spriteType].sprite:Load("gfx/race/" .. spriteName .. ".anm2", true) -- The second argument is "LoadGraphics"
  spriteTable[spriteType].spriteName = spriteName
end

-- Call this every frame in MC_POST_RENDER
function spriteDisplay()
  -- Local variables
  local game = Game()
  local room = game:GetRoom()

  -- Loop through all the sprites and render them
  for k, v in pairs(spriteTable) do
    -- Position it
    local vec = Vector(0, 0)
    local animationName = "Default"
    if k == "top" then -- Pre-race messages and the countdown
      -- Make it be a little bit higher than the center of the screen
      vec = Isaac.WorldToRenderPosition(room:GetCenterPos(), false) -- The second argument is "ToRound"
      vec.Y = vec.Y - 80 -- Move it upwards from the center
    elseif k == "clock" then
      vec.X = 7.5 -- Move it below the Angel chance
      vec.Y = 217
    end

    -- Draw it
    if v.sprite ~= nil then
      spriteTable[k].sprite:SetFrame(animationName, 0)
      spriteTable[k].sprite:RenderLayer(0, vec)
    end
  end
end

function spriteDisplaySchoolBag()
  if race == nil or race.schoolBag == false or run.schoolBagItem == 0 then
    return
  end

  -- Local variables
  local itemX = 45;
  local itemY = 50;
  local barXOffset = 17
  local barYOffset = 1
  local itemVector = Vector(itemX, itemY)
  local barVector = Vector(itemX + barXOffset, itemY + barYOffset)

  -- Draw the item image
  spriteTableSchoolBag.item:Update()
  spriteTableSchoolBag.item:Render(itemVector, Vector(0, 0), Vector(0, 0))

  if run.schoolBagMaxCharges ~= 0 then
    -- Draw the charge bar 1/3 (the background)
    spriteTableSchoolBag.barBack:Update()
    spriteTableSchoolBag.barBack:Render(barVector, Vector(0, 0), Vector(0, 0))

    -- Draw the charge bar 2/3 (the bar itself, clipped appropriately)
    spriteTableSchoolBag.barMeter:Update()
    local meterMultiplier
    if run.schoolBagMaxCharges == 12 then
      meterMultiplier = 2
    elseif run.schoolBagMaxCharges == 6 then
      meterMultiplier = 4
    elseif run.schoolBagMaxCharges == 4 then
      meterMultiplier = 6
    elseif run.schoolBagMaxCharges == 3 then
      meterMultiplier = 8
    elseif run.schoolBagMaxCharges == 2 then
      meterMultiplier = 12
    elseif run.schoolBagMaxCharges == 1 then
      meterMultiplier = 24
    end
    local meterClip = 26 - (run.schoolBagCharges * meterMultiplier)
    spriteTableSchoolBag.barMeter:Render(barVector, Vector(0, meterClip), Vector(0, 0))

    -- Draw the charge bar 3/3 (the segment lines on top)
    spriteTableSchoolBag.barLines:Update()
    spriteTableSchoolBag.barLines:Render(barVector, Vector(0, 0), Vector(0, 0))
  end
end

function timerUpdate()
  if raceVars.startedTime == 0 then
    return
  end

  local elapsedFrames = Isaac:GetFrameCount() - raceVars.startedTime
  local elapsedTime = elapsedFrames * 0.017

  local minutes = math.floor(elapsedTime / 60)
  if minutes < 10 then
    minutes = "0" .. tostring(minutes)
  else
    minutes = tostring(minutes)
  end
  
  local seconds = elapsedTime % 60
  seconds = round(seconds, 1)
  if seconds < 10 then
    seconds = "0" .. tostring(seconds)
  else
    seconds = tostring(seconds)
  end

  local timerString = minutes .. ':' .. seconds
  Isaac.RenderText(timerString, 17, 211, 0.7, 1, 0.2, 1.0) -- X, Y, R, G, B, A
end

--
-- Misc. subroutines
--

function incrementRNG(seed)
  -- The initial RNG value recieved from the B1 floor RNG is a 10 digit integer
  -- So let's just continue to work with integers that are roughly in this range
  math.randomseed(seed)
  return math.random(1, 9999999999)
end

function addItemBanList(itemID)
  local inBanList = false
  for i = 1, #raceVars.itemBanList do
    if raceVars.itemBanList[i] == itemID then
      inBanList = true
      break
    end
  end
  if inBanList == false then
    raceVars.itemBanList[#raceVars.itemBanList + 1] = itemID
  end
end

function addTrinketBanList(trinketID)
  local inBanList = false
  for i = 1, #raceVars.trinketBanList do
    if raceVars.trinketBanList[i] == trinketID then
      inBanList = true
      break
    end
  end
  if inBanList == false then
    raceVars.trinketBanList[#raceVars.trinketBanList + 1] = trinketID
  end
end

function gridToPos(x, y)
  local game = Game()
  local room = game:GetRoom()
  x = x + 1
  y = y + 1
  return room:GetGridPosition(y * room:GetGridWidth() + x)
end

--
-- Main functions
--

-- Called when starting a new run
function RacingPlus:RunInit()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local player = game:GetPlayer(0)
  local seed = level:GetDungeonPlacementSeed()
  local isaacFrameCount = Isaac:GetFrameCount()

  -- Reset some global variables that we keep track of per run
  run.roomsCleared = 0
  run.roomsEntered = 0
  run.roomEntering = false
  run.currentFloor = 1
  run.currentRoomClearState = true
  run.currentGlobins = {}
  run.currentKnights = {}
  run.replacedItems = {}
  run.replacedTrinkets = {}
  run.placedKeys = false
  run.keeperBaseHearts = 4
  run.keeperHealthItems = {}
  run.spawnedCoop = false
  run.schoolBagItem = 0
  run.schoolBagMaxCharges = 0
  run.schoolBagCharges = 0
  run.schoolBagFrame = isaacFrameCount

  -- Reset some race variables that we keep track of per run
  raceVars.runInitForRaceDone = false
  raceVars.itemBanList = {}
  raceVars.trinketBanList = {}

  -- Reset some RNG counters to the floor RNG of B1 for this seed
  -- (future drops will be based on the RNG from this initial random value)
  RNGCounter.InitialSeed = seed
  RNGCounter.BookOfSin = seed
  RNGCounter.SackOfPennies = seed
  RNGCounter.BombBag = seed
  RNGCounter.JuicySack = seed
  RNGCounter.MysterySack = seed
  RNGCounter.LilChest = seed
  RNGCounter.RuneBag = seed
  RNGCounter.AcidBaby = seed
  RNGCounter.SackOfSacks = seed

  -- Check to see if we are on the BLCK CNDL Easter Egg
  level:AddCurse(LevelCurse.CURSE_OF_THE_CURSED, false) -- The second argument is "ShowName"
  local curses = level:GetCurses()
  if curses == 0 then
    raceVars.blckCndlOn = true
  else
    raceVars.blckCndlOn = false

    -- The client assumes that it is on by default, so it only needs to be alerted for the negative case
    Isaac.DebugString("BLCK CNDL off.")
  end
  level:RemoveCurse(LevelCurse.CURSE_OF_THE_CURSED)

  -- Check to see if we are on normal mode or hard mode
  raceVars.difficulty = game.Difficulty
  Isaac.DebugString("Difficulty: " .. tostring(game.Difficulty))

  -- Check what character we are on
  local playerType = player:GetPlayerType()
  if playerType == 0 then
    raceVars.character = "Isaac"
  elseif playerType == 1 then
    raceVars.character = "Magdalene"
  elseif playerType == 2 then
    raceVars.character = "Cain"
  elseif playerType == 3 then
    raceVars.character = "Judas"
  elseif playerType == 4 then
    raceVars.character = "Blue Baby"
  elseif playerType == 5 then
    raceVars.character = "Eve"
  elseif playerType == 6 then
    raceVars.character = "Samson"
  elseif playerType == 7 then
    raceVars.character = "Azazel"
  elseif playerType == 8 then
    raceVars.character = "Lazarus"
  elseif playerType == 9 then
    raceVars.character = "Eden"
  elseif playerType == 10 then
    raceVars.character = "The Lost"
  elseif playerType == 13 then
    raceVars.character = "Lilith"
  elseif playerType == 14 then
    raceVars.character = "Keeper"
  elseif playerType == 15 then
    raceVars.character = "Apollyon"
  end

  -- Give us custom racing items, depending on the character (mostly just the D6)
  RacingPlus:CharacterInit()

  -- Log the run beginning
  Isaac.DebugString("A new run has begun.")

  -- We will do more run initialization things specifically pertaining to races later on in the PostRender callback, so return for now
  -- (we want to make sure that we check the "save.dat" file for updates on this frame)
  raceLoadNextFrame = true
end

-- This is done when a run is started and after the Glowing Hour Glass is used
function RacingPlus:CharacterInit()
  -- Local variables
  local game = Game()
  local player = Game():GetPlayer(0)
  local playerType = player:GetPlayerType()

  -- Do character-specific actions
  if playerType == PlayerType.PLAYER_MAGDALENA then -- 1
    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_YUM_HEART -- 45
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_YUM_HEART))

  elseif playerType == PlayerType.PLAYER_JUDAS then -- 3
    -- Judas needs to be at half of a red heart
    player:AddHearts(-1)

    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL -- 34
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL))

  elseif playerType == PlayerType.PLAYER_XXX then -- 4
    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_POOP -- 36
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_POOP))

  elseif playerType == PlayerType.PLAYER_EVE then -- 5
    -- Remove the existing items (they need to be in "players.xml" so that they get removed from item pools)
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_D6) -- 105
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_D6))
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON) -- 122
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON))
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_DEAD_BIRD) -- 117
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_DEAD_BIRD))

    -- Add the D6, Whore of Babylon, and Dead Bird
    player:AddCollectible(CollectibleType.COLLECTIBLE_D6, 6, true) -- 105
    player:AddCollectible(CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON, 0, true) -- 122
    player:AddCollectible(CollectibleType. COLLECTIBLE_DEAD_BIRD, 0, true) -- 117

    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_RAZOR_BLADE -- 126
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_RAZOR_BLADE))

  elseif playerType == PlayerType.PLAYER_AZAZEL then -- 7
    -- Decrease his red hearts
    player:AddHearts(-1)

  elseif playerType == PlayerType.PLAYER_EDEN then -- 9
    -- Swap the random active item with the D6
    local activeItem = player:GetActiveItem()
    player:AddCollectible(CollectibleType.COLLECTIBLE_D6, 6, true) -- 105

    -- It would be nice to remove and re-add the passive item so that it appears in the correct order with the D6 first
    -- However, if the passive gives pickups (on the ground), then it would give double

    -- Add the School Bag item
    run.schoolBagItem = activeItem
    Isaac.DebugString("Removing collectible " .. tostring(activeItem))

  elseif playerType == PlayerType.PLAYER_LILITH then -- 13
    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_BOX_OF_FRIENDS -- 357
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_BOX_OF_FRIENDS))

  elseif playerType == PlayerType.PLAYER_KEEPER then -- 14
    -- Remove the existing items (they need to be in "players.xml" so that they get removed from item pools)
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_D6) -- 105
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_D6))
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_GREEDS_GULLET) -- 501
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_GREEDS_GULLET))
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_DUALITY) -- 498
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_DUALITY))
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_WOODEN_NICKEL) -- 349
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_WOODEN_NICKEL))

    -- Add the D6, Greed's Gullet, and Duality
    player:AddCollectible(CollectibleType.COLLECTIBLE_D6, 6, true) -- 105
    player:AddCollectible(CollectibleType.COLLECTIBLE_GREEDS_GULLET, 0, true) -- 501
    player:AddCollectible(CollectibleType.COLLECTIBLE_DUALITY, 0, true) -- 498

    -- Grant an extra coin/heart container
    player:AddCoins(24) -- Keeper starts with 1 coin so we only need to give 24
    player:AddCoins(1) -- This fills in the new heart container
    player:AddCoins(25) -- Add a 2nd container
    player:AddCoins(1) -- This fills in the new heart container

  elseif playerType == PlayerType.PLAYER_APOLLYON then -- 15
    -- Add the School Bag item
    run.schoolBagItem = CollectibleType.COLLECTIBLE_VOID -- 477
    Isaac.DebugString("Removing collectible " .. tostring(CollectibleType.COLLECTIBLE_VOID))
  end

  -- Make sure that the School Bag item is maximally charged
  if run.schoolBagItem ~= 0 then
    run.schoolBagCharges = 12 -- 12 is the maximum amount of charges that an item can have
  end
end

-- This occurs when first going into the game, after using the Glowing Hour Glass during race countdown, and after a reset occurs mid-race
function RacingPlus:RunInitForRace()
  -- Once per run, we need to check the race status
  -- (this needs to be in a separate function in case reading "save.dat" fails on the first frame of the run)
  if raceVars.runInitForRaceDone then
    return
  else
    Isaac.DebugString("Doing run initialization for the race.")
    raceVars.runInitForRaceDone = true
  end

  -- Local variables
  local game = Game()
  local player = game:GetPlayer(0)
  local inBanList

  -- Do School Bag related initiailization
  if race.schoolBag == true then
    RacingPlus:SchoolBagInit()
    player:FullCharge()
  end

  -- If we are not in a race, don't do anything special
  if race.status == "none" then
    return
  end

  -- Validate BLCK CNDL for races
  if raceVars.blckCndlOn == false then
    Isaac.DebugString("Race error: BLCK CNDL not enabled.")
    return
  end

  -- Validate difficulty (hard mode) for races
  if raceVars.difficulty ~= 0 then
    Isaac.DebugString("Race error: On the wrong difficulty (hard mode or Greed mode).")
    return
  end

  -- Validate character for races
  if raceVars.character ~= race.character then
    Isaac.DebugString("Race error: On the wrong character.")
    return
  end
  
  -- Validate that we are on the right seed for the race
  -- (if this is an unseeded race, the seed with be "-")
  if race.seed ~= "-" and race.seed ~= race.currentSeed then
    Isaac.DebugString("Race error: On the wrong seed.")
    return
  end

  -- Give the player extra starting items (which should only happen on a seeded race or a diversity race)
  for i = 1, #race.startingItems do
    -- If the diversity race has not started yet, don't give the items
    if race.rFormat == "diversity" and raceVars.started == false then
      break
    end

    -- Send a message to the item tracker to remove this item
    -- (otherwise, if we are using Glowing Hour Glass, it will record two of them)
    Isaac.DebugString("Removing collectible " .. tostring(race.startingItems[i]))

    if race.startingItems[i] == 441 and raceVars.hourglassUsed == false then
      -- Mega Blast bugs out if Glowing Hour Glass is used while the blast is occuring
      -- So, give them a placeholder Mega Blast if this is before the race has started
      player:AddCollectible(megaBlastPlaceholder, 12, false)
    else
      -- Give the item; the second argument is charge amount, and the third argument is "AddConsumables"
      player:AddCollectible(race.startingItems[i], 12, true)
    end

    -- Giving the player the item does not actually remove it from any of the pools, so we have to expliticly add it to the ban list
    addItemBanList(race.startingItems[i])

    -- Find out if Crown of Light is one of the starting items
    if race.startingItems[i] == 415 then
      -- Remove the 2 soul hearts that it gives
      player:AddSoulHearts(-4)

      -- Re-heal Judas and Azazel back to 1 red heart so that they can properly use the Crown of Light
      -- (this should do nothing on all of the other characters)
      player:AddHearts(1)
      break
    end
  end

  -- Add item bans for seeded mode
  if race.rFormat == "seeded" then
    addItemBanList(CollectibleType.COLLECTIBLE_TELEPORT) -- 44
    addItemBanList(CollectibleType.COLLECTIBLE_UNDEFINED) -- 324
    addTrinketBanList(TrinketType.TRINKET_CAINS_EYE) -- 59
  end

  -- Add bans for diversity races
  if race.rFormat == "diversity" then
    addItemBanList(CollectibleType.COLLECTIBLE_MOMS_KNIFE) -- 114
    addItemBanList(CollectibleType.COLLECTIBLE_EPIC_FETUS) -- 168
    addItemBanList(CollectibleType.COLLECTIBLE_TECH_X) -- 395
    addItemBanList(CollectibleType.COLLECTIBLE_D4) -- 284
    addItemBanList(CollectibleType.COLLECTIBLE_D100) -- 283
    addItemBanList(CollectibleType.COLLECTIBLE_DINF) -- 489
  end

  -- Add bans for The Lamb (Dark Room) races
  if race.goal == "The Lamb" then
    addItemBanList(CollectibleType.COLLECTIBLE_WE_NEED_GO_DEEPER) -- 84
  end

  -- If we need to update the cache, mark to do it on the next game frame
  if raceVars.updateCache == 1 then
    raceVars.updateCache = 2
  end

  if race.status == "in progress" then
    -- The race has already started (we are late, or perhaps died in the middle of the race)
    RacingPlus:RaceStart()
  elseif race.status == "starting" and raceVars.hourglassUsed == true then
    -- Don't spawn the Gaping Maws after the reset
  else
    -- Spawn two Gaping Maws (235.0)
    local game = Game()
    game:Spawn(EntityType.ENTITY_GAPING_MAW, 0, Vector(280, 360), Vector(0,0), nil, 0, 0)
    game:Spawn(EntityType.ENTITY_GAPING_MAW, 0, Vector(360, 360), Vector(0,0), nil, 0, 0)
  end
end

function RacingPlus:SchoolBagInit()
  if race == nil or race.schoolBag == false or run.schoolBagItem == 0 then
    return
  end

  -- Find out how many charges this item has
  local charges
  if run.schoolBagItem == CollectibleType.COLLECTIBLE_MEGA_SATANS_BREATH or -- 441
     run.schoolBagItem == CollectibleType.COLLECTIBLE_EDENS_SOUL or -- 490
     run.schoolBagItem == CollectibleType.COLLECTIBLE_DELIRIOUS then -- 510
  
    run.schoolBagMaxCharges = 12

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_BIBLE or -- 33
         run.schoolBagItem == CollectibleType.COLLECTIBLE_NECRONOMICON or -- 35
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MY_LITTLE_UNICORN or -- 77
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_REVELATIONS or -- 78
         run.schoolBagItem == CollectibleType.COLLECTIBLE_THE_NAIL or -- 83
         run.schoolBagItem == CollectibleType.COLLECTIBLE_WE_NEED_GO_DEEPER or -- 84
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DECK_OF_CARDS or -- 85
         run.schoolBagItem == CollectibleType.COLLECTIBLE_GAMEKID or -- 93
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MOMS_BOTTLE_PILLS or -- 102
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D6 or -- 105
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PINKING_SHEARS or -- 107
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PRAYER_CARD or -- 146
         run.schoolBagItem == CollectibleType.COLLECTIBLE_CRYSTAL_BALL or -- 158
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D20 or -- 166
         run.schoolBagItem == CollectibleType.COLLECTIBLE_WHITE_PONY or -- 181
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D100 or -- 283
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D4 or -- 284
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_OF_SECRETS or -- 287
         run.schoolBagItem == CollectibleType.COLLECTIBLE_FLUSH or -- 291
         run.schoolBagItem == CollectibleType.COLLECTIBLE_SATANIC_BIBLE or -- 292
         run.schoolBagItem == CollectibleType.COLLECTIBLE_HEAD_OF_KRAMPUS or -- 293
         run.schoolBagItem == CollectibleType.COLLECTIBLE_ISAACS_TEARS or -- 323
         run.schoolBagItem == CollectibleType.COLLECTIBLE_UNDEFINED or -- 324
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BREATH_OF_LIFE or -- 326
         run.schoolBagItem == CollectibleType.COLLECTIBLE_VOID or -- 477
         run.schoolBagItem == CollectibleType.COLLECTIBLE_SMELTER or -- 479
         run.schoolBagItem == CollectibleType.COLLECTIBLE_CLICKER then -- 482

    run.schoolBagMaxCharges = 6

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_YUM_HEART or -- 45
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_OF_SIN or -- 97
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_OF_SIN_SEEDED or -- 43
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PONY or -- 130
         run.schoolBagItem == CollectibleType.COLLECTIBLE_CRACK_THE_SKY or -- 160
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BLANK_CARD or -- 286
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PLACEBO or -- 348
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOX_OF_FRIENDS or -- 357
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D8 or -- 406
         run.schoolBagItem == CollectibleType.COLLECTIBLE_TELEPORT_2 or -- 419
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MOMS_BOX or -- 439
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D1 or -- 476
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DATAMINER or -- 481
         run.schoolBagItem == CollectibleType.COLLECTIBLE_CROOKED_PENNY then -- 485

    run.schoolBagMaxCharges = 4

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_OF_BELIAL or -- 34
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MOMS_BRA or -- 39
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MOMS_PAD or -- 41
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD or -- 42
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOOK_OF_SHADOWS or -- 58
         run.schoolBagItem == CollectibleType.COLLECTIBLE_ANARCHIST_COOKBOOK or -- 65
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MONSTROS_TOOTH or -- 86
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MONSTER_MANUAL or -- 123
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BEST_FRIEND or -- 136
         run.schoolBagItem == CollectibleType.COLLECTIBLE_NOTCHED_AXE or -- 147
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MEGA_BEAN or -- 351
         run.schoolBagItem == CollectibleType.COLLECTIBLE_FRIEND_BALL or -- 382
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D12 or -- 386
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D7 then -- 437

    run.schoolBagMaxCharges = 3

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_MR_BOOM or -- 37
         run.schoolBagItem == CollectibleType.COLLECTIBLE_TELEPORT or -- 44
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DOCTORS_REMOTE or -- 47
         run.schoolBagItem == CollectibleType.COLLECTIBLE_SHOOP_DA_WHOOP or -- 49
         run.schoolBagItem == CollectibleType.COLLECTIBLE_LEMON_MISHAP or -- 56
         run.schoolBagItem == CollectibleType.COLLECTIBLE_HOURGLASS or -- 66
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DEAD_SEA_SCROLLS or -- 124
         run.schoolBagItem == CollectibleType.COLLECTIBLE_SPIDER_BUTT or -- 171
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DADS_KEY or -- 175
         run.schoolBagItem == CollectibleType.COLLECTIBLE_TELEPATHY_BOOK or -- 192
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BOX_OF_SPIDERS or -- 288
         run.schoolBagItem == CollectibleType.COLLECTIBLE_SCISSORS or -- 325
         run.schoolBagItem == CollectibleType.COLLECTIBLE_KIDNEY_BEAN or -- 421
         run.schoolBagItem == CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS or -- 422
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PAUSE or -- 478
         run.schoolBagItem == CollectibleType.COLLECTIBLE_COMPOST or -- 480
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DULL_RAZOR or -- 486
         run.schoolBagItem == CollectibleType.COLLECTIBLE_METRONOME or -- 488
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DINF then -- 489

    run.schoolBagMaxCharges = 2

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_POOP or -- 36
         run.schoolBagItem == CollectibleType.COLLECTIBLE_TAMMYS_HEAD or -- 38
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BEAN or -- 111
         run.schoolBagItem == CollectibleType.COLLECTIBLE_FORGET_ME_NOW or -- 127
         run.schoolBagItem == CollectibleType.COLLECTIBLE_GUPPYS_HEAD or -- 145
         run.schoolBagItem == 235 or -- Debug
         run.schoolBagItem == CollectibleType.COLLECTIBLE_D10 or -- 285
         run.schoolBagItem == CollectibleType.COLLECTIBLE_UNICORN_STUMP or -- 298
         run.schoolBagItem == CollectibleType.COLLECTIBLE_WOODEN_NICKEL or -- 349
         run.schoolBagItem == CollectibleType.COLLECTIBLE_TEAR_DETONATOR or -- 383
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MINE_CRAFTER or -- 427
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PLAN_C then -- 475

    run.schoolBagMaxCharges = 1

  elseif run.schoolBagItem == CollectibleType.COLLECTIBLE_KAMIKAZE or -- 40
         run.schoolBagItem == CollectibleType.COLLECTIBLE_RAZOR_BLADE or -- 126
         run.schoolBagItem == CollectibleType.COLLECTIBLE_GUPPYS_PAW or -- 133
         run.schoolBagItem == CollectibleType.COLLECTIBLE_IV_BAG or -- 135
         run.schoolBagItem == CollectibleType.COLLECTIBLE_REMOTE_DETONATOR or -- 137
         run.schoolBagItem == CollectibleType.COLLECTIBLE_PORTABLE_SLOT or -- 177
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BLOOD_RIGHTS or -- 186
         run.schoolBagItem == CollectibleType.COLLECTIBLE_HOW_TO_JUMP or -- 282
         run.schoolBagItem == CollectibleType.COLLECTIBLE_THE_JAR or -- 290
         run.schoolBagItem == CollectibleType.COLLECTIBLE_MAGIC_FINGERS or -- 295
         run.schoolBagItem == CollectibleType.COLLECTIBLE_CONVERTER or -- 296
         run.schoolBagItem == CollectibleType.COLLECTIBLE_BLUE_BOX or -- 297
         run.schoolBagItem == CollectibleType.COLLECTIBLE_DIPLOPIA or -- 347
         run.schoolBagItem == CollectibleType.COLLECTIBLE_JAR_OF_FLIES then -- 434

    run.schoolBagMaxCharges = 0
  else
    -- Somehow, a non-active item got put inside the School Bag
    Isaac.DebugString("Error: A non-active item got put inside the School Bag.")
    run.schoolBagMaxCharges = 0
  end

  -- Load the sprites
  spriteTableSchoolBag.item = Sprite()
  spriteTableSchoolBag.item:Load("gfx/schoolbag/" .. run.schoolBagItem .. ".anm2", true)
  spriteTableSchoolBag.item:Play("Default", true)
  spriteTableSchoolBag.barBack = Sprite()
  spriteTableSchoolBag.barBack:Load("gfx/ui/ui_chargebar.anm2", true)
  spriteTableSchoolBag.barBack:Play("BarEmpty", true)
  spriteTableSchoolBag.barMeter = Sprite()
  spriteTableSchoolBag.barMeter:Load("gfx/ui/ui_chargebar.anm2", true)
  spriteTableSchoolBag.barMeter:Play("BarFull", true)
  spriteTableSchoolBag.barLines = Sprite()
  spriteTableSchoolBag.barLines:Load("gfx/ui/ui_chargebar.anm2", true)
  spriteTableSchoolBag.barLines:Play("BarOverlay" .. tostring(run.schoolBagMaxCharges), true)
end

function RacingPlus:RaceStart()
  -- Only do these actions once per race
  if raceVars.started == true then
    return
  else
    raceVars.started = true
    race.status = "in progress"
  end

  -- Local variables
  local game = Game()
  local player = game:GetPlayer(0)
  Isaac.DebugString("Starting the race!")

  -- If this is a diversity race, give the player the extra starting items
  if race.rFormat == "diversity" then
    for i = 1, #race.startingItems do
      -- Give the item; the second argument is charge amount, and the third argument is "AddConsumables"
      player:AddCollectible(race.startingItems[i], 12, true)

      -- Giving the player the item does not actually remove it from any of the pools, so we have to expliticly add it to the ban list
      addItemBanList(race.startingItems[i])
    end
  end

  -- Load the clock sprite for the timer
  if raceVars.startedTime ~= 0 then
    spriteInit("clock", "clock")
  end
end

-- This emulates what happens when you normally clear a room
function RacingPlus:ManuallyClearCurrentRoom()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local room = game:GetRoom()
  local player = game:GetPlayer(0)

  -- Set the room clear to true (so that it gets marked off on the minimap)
  room:SetClear(true)

  -- Open the doors
  local door
  for i = 0, 7 do
    door = room:GetDoor(i)
    if door ~= nil then
      door:Open()
    end
  end

  -- Check to see if it is a boss room
  if room:GetType() == RoomType.ROOM_BOSS then
    -- Try and spawn a Devil Room or Angel Room
    -- (this takes into account their Devil/Angel percentage and so forth)
    room:TrySpawnDevilRoomDoor(true) -- The argument is "Animate"

    -- Try to spawn the Boss Rush door
    if stage == 6 then
      room:TrySpawnBossRushDoor(false) -- The argument is "IgnoreTime"
    end
  end

  -- Spawns the award for clearing the room (the pickup, chest, etc.)
  room:SpawnClearAward() -- This takes into account their luck and so forth

  -- After the reward is spawned, if it is a boss room, the trapdoor(s)
  -- to the next floor will show up and the item pedestals will spawn
  if room:GetType() == RoomType.ROOM_BOSS then
    -- Check all the grid entities in the room
    local num = room:GetGridSize()
    for i = 1, num do
      local gridEntity = room:GetGridEntity(i)
      if gridEntity ~= nil then
        -- If this entity is a trap door
        local test = gridEntity:ToTrapdoor()
        if test ~= nil then
          if gridEntity:GetSaveState().VarData == 1 then
            -- Delete Void Portals, which have a VarData of 1
            room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work
          elseif stage == 8 then
            -- Delete the W2 normal trap door
            if race.goal == "Blue Baby" then
              room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work
            end
          end
        end
      end
    end

    -- Check all the (non-grid) entities in the room
    local entities = Isaac.GetRoomEntities()
    for i = 1, #entities do
      -- Check for The Polaroid (5.100.327)
      if entities[i].Type == EntityType.ENTITY_PICKUP and
         entities[i].Variant == PickupVariant.PICKUP_COLLECTIBLE and
         entities[i].SubType == CollectibleType.COLLECTIBLE_POLAROID and
         race.goal == "The Lamb" then

        entities[i]:Remove()
        break
      end

      -- Check for The Negative (5.100.328)
      if entities[i].Type == EntityType.ENTITY_PICKUP and
         entities[i].Variant == PickupVariant.PICKUP_COLLECTIBLE and
         entities[i].SubType == CollectibleType.COLLECTIBLE_NEGATIVE and
         race.goal == "Blue Baby" then

        entities[i]:Remove()
        break
      end

      -- Check for Heaven door (1000.39)
      if entities[i].Type == EntityType.ENTITY_EFFECT and
         entities[i].Variant == EffectVariant.HEAVEN_LIGHT_DOOR and
         race.goal == "The Lamb" then

        entities[i]:Remove()
        break
      end
    end
  end

  -- Give a charge to the player's active item
  if player:NeedsCharge() == true then
    -- Find out if we are in a 2x2 or L room
    local chargesToAdd = 1
    local shape = room:GetRoomShape()
    if shape >= 8 then
      chargesToAdd = 2
    end

    -- Add the correct amount of charges
    local currentCharge = player:GetActiveCharge()
    player:SetActiveCharge(currentCharge + chargesToAdd)
  end

  -- Play the sound effect for the door opening
  -- (the only way to play sounds is to attach them to an NPC, so we have to create one and then destroy it)
  local entity = game:Spawn(EntityType.ENTITY_FLY, 0, Vector(0, 0), Vector(0,0), nil, 0, 0)
  local npc = entity:ToNPC()
  npc:PlaySound(SoundEffect.SOUND_DOOR_HEAVY_OPEN, 1, 0, false, 1)
  entity:Remove()

  -- Emulate various familiars dropping things
  local newRoomsCleared = run.roomsCleared + 1
  local pos
  local vel = Vector(0, 0)
  local constant1 = 1.1 -- For Little C.H.A.D., Bomb Bag, Acid Baby, Sack of Sacks
  local constant2 = 1.11 -- For The Relic, Mystery Sack, Rune Bag
  if player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then -- 247
    constant1 = 1.2
    constant2 = 1.2
  end

  -- Sack of Pennies (21)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_SACK_OF_PENNIES) then -- 21
    -- This drops a penny/nickel/dime/etc. every 2 rooms cleared (or more with BFFs!)
    RNGCounter.SackOfPennies = incrementRNG(RNGCounter.SackOfPennies)
    math.randomseed(RNGCounter.SackOfPennies)
    local sackBFFChance = math.random(1, 4294967295)
    if newRoomsCleared & 1 == 0 or
       (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and sackBFFChance % 3 == 0) then

      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Sack of Pennies - 3.21
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.SACK_OF_PENNIES then

          pos = entities[i].Position
          break
        end
      end

      -- Random Coin - 5.20.0
      RNGCounter.SackOfPennies = incrementRNG(RNGCounter.SackOfPennies)
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, pos, vel, player, 0, RNGCounter.SackOfPennies)
    end
  end

  -- Little C.H.A.D (96)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LITTLE_CHAD) then -- 96
    -- This drops a half a red heart based on the formula:
    -- floor(roomsCleared / 1.1) > 0 && floor(roomsCleared / 1.1) & 1 == 0
    if math.floor(newRoomsCleared / constant1) > 0 and math.floor(newRoomsCleared / constant1) & 1 == 0 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Little C.H.A.D. - 3.22
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.LITTLE_CHAD then

          pos = entities[i].Position
          break
        end
      end

      -- Heart (half) - 5.10.2
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, pos, vel, player, 2, 0)
    end
  end

  -- The Relic (98)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_RELIC) then -- 98
    -- This drops a soul heart based on the formula:
    -- floor(roomsCleared / 1.11) & 3 == 2
    if math.floor(newRoomsCleared / constant2) & 3 == 2 then
      -- Get the position of familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- The Relic - 3.23
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.RELIC then

          pos = entities[i].Position
          break
        end
      end

      -- Heart (soul) - 5.10.3
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, pos, vel, player, 3, 0)
    end
  end

  -- Bomb Bag (131)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_BOMB_BAG) then -- 131
    -- This drops a bomb based on the formula:
    -- floor(roomsCleared / 1.1) > 0 && floor(roomsCleared / 1.1) & 1 == 0
    if math.floor(newRoomsCleared / constant1) > 0 and math.floor(newRoomsCleared / constant1) & 1 == 0 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Bomb Bag - 3.20
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.BOMB_BAG then

          pos = entities[i].Position
          break
        end
      end

      -- Random Bomb - 5.40.0
      RNGCounter.BombBag = incrementRNG(RNGCounter.BombBag)
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, pos, vel, player, 0, RNGCounter.BombBag)
    end
  end

  -- Juicy Sack (266)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_JUICY_SACK) then -- 266
    -- Get the position of the familiar
    local entities = Isaac.GetRoomEntities()
    for i = 1, #entities do
      -- Juicy Sack - 3.52
      if entities[i].Type == EntityType.ENTITY_FAMILIAR and
         entities[i].Variant == FamiliarVariant.JUICY_SACK then

        pos = entities[i].Position
        break
      end
    end

    -- Spawn either 1 or 2 blue spiders (50% chance of each)
    RNGCounter.JuicySack = incrementRNG(RNGCounter.JuicySack)
    math.randomseed(RNGCounter.JuicySack)
    local spiders = math.random(1, 2)
    player:AddBlueSpider(pos)
    if spiders == 2 then
      player:AddBlueSpider(pos)
    end

    -- The BFFs! synergy gives an additional spider
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
      player:AddBlueSpider(pos)
    end
  end

  -- Mystery Sack (271)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MYSTERY_SACK) then -- 271
    -- This drops a heart, coin, bomb, or key based on the formula:
    -- floor(roomsCleared / 1.11) & 3 == 2
    if math.floor(newRoomsCleared / constant2) & 3 == 2 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Mystery Sack - 3.57
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.MYSTERY_SACK then

          pos = entities[i].Position
          break
        end
      end

      -- First, decide whether we get a heart, coin, bomb, or key
      RNGCounter.MysterySack = incrementRNG(RNGCounter.MysterySack)
      math.randomseed(RNGCounter.MysterySack)
      local sackPickupType = math.random(1, 4)
      RNGCounter.MysterySack = incrementRNG(RNGCounter.MysterySack)

      -- If heart
      if sackPickupType == 1 then
        -- Random Heart - 5.10.0
        game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, pos, vel, player, 0, RNGCounter.MysterySack)

      -- If coin
      elseif sackPickupType == 2 then
        -- Random Coin - 5.20.0
        game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, pos, vel, player, 0, RNGCounter.MysterySack)

      -- If bomb
      elseif sackPickupType == 3 then
        -- Random Bomb - 5.40.0
        game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, pos, vel, player, 0, RNGCounter.MysterySack)

      -- If key
      elseif sackPickupType == 4 then
        -- Random Key - 5.30.0
        game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, pos, vel, player, 0, RNGCounter.MysterySack)
      end
    end
  end

  -- Lil' Chest (362)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LIL_CHEST) then -- 362
    -- This drops a heart, coin, bomb, or key based on the formula:
    -- 10% chance for a trinket, if no trinket, 25% chance for a random consumable (based on time)
    -- Or, with BFFS!, 12.5% chance for a trinket, if no trinket, 31.25% chance for a random consumable
    -- We don't want it based on time in the Racing+ mod

    -- Get the position of the familiar
    local entities = Isaac.GetRoomEntities()
    for i = 1, #entities do
      -- Lil Chest - 3.82
      if entities[i].Type == EntityType.ENTITY_FAMILIAR and
         entities[i].Variant == FamiliarVariant.LIL_CHEST then

        pos = entities[i].Position
        break
      end
    end

    -- First, decide whether we get a trinket
    RNGCounter.LilChest = incrementRNG(RNGCounter.LilChest)
    math.randomseed(RNGCounter.LilChest)
    local chestTrinket = math.random(1, 1000)
    if chestTrinket <= 100 or
       (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and chestTrinket <= 125) then

       -- Random Trinket - 5.350.0
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, pos, vel, player, 0, RNGCounter.LilChest)
    else
      -- Second, decide whether it spawns a consumable
      RNGCounter.LilChest = incrementRNG(RNGCounter.LilChest)
      math.randomseed(RNGCounter.LilChest)
      local chestConsumable = math.random(1, 10000)
      if chestConsumable <= 2500 or
         (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and chestTrinket <= 3125) then

        -- Third, decide whether we get a heart, coin, bomb, or key
        RNGCounter.LilChest = incrementRNG(RNGCounter.LilChest)
        math.randomseed(RNGCounter.LilChest)
        local chestPickupType = math.random(1, 4)
        RNGCounter.LilChest = incrementRNG(RNGCounter.LilChest)

        -- If heart
        if chestPickupType == 1 then
          -- Random Heart - 5.10.0
          game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, pos, vel, player, 0, RNGCounter.LilChest)

        -- If coin
        elseif chestPickupType == 2 then
          -- Random Coin - 5.20.0
          game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, pos, vel, player, 0, RNGCounter.LilChest)

        -- If bomb
        elseif chestPickupType == 3 then
          -- Random Bomb - 5.40.0
          game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, pos, vel, player, 0, RNGCounter.LilChest)

        -- If key
        elseif chestPickupType == 4 then
          -- Random Key - 5.30.0
          game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, pos, vel, player, 0, RNGCounter.LilChest)
        end
      end
    end
  end

  -- Rune Bag (389)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_RUNE_BAG) then -- 389
    -- This drops a random rune based on the formula:
    -- floor(roomsCleared / 1.11) & 3 == 2
    if math.floor(newRoomsCleared / constant2) & 3 == 2 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Rune Bag - 3.91
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.RUNE_BAG then

          pos = entities[i].Position
          break
        end
      end

      -- For some reason you cannot spawn the normal "Random Rune" entity (5.301.0)
      -- So, spawn a random card (5.300.0) over and over until we get a rune
      while true do
        RNGCounter.RuneBag = incrementRNG(RNGCounter.RuneBag)
        local entity = game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, pos, vel, player, 0, RNGCounter.RuneBag)
        -- Hagalaz is 32 and Black Rune is 41
        if entity.SubType >= 32 and entity.SubType <= 41 then
          break
        end
        entity:Remove()
      end
    end
  end

  -- Acid Baby (491)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_ACID_BABY) then -- 491
    -- This drops a pill based on the formula:
    -- floor(roomsCleared / 1.1) > 0 && floor(roomsCleared / 1.1) & 1 == 0
    if math.floor(newRoomsCleared / constant1) > 0 and math.floor(newRoomsCleared / constant1) & 1 == 0 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Acid Baby - 3.112
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.ACID_BABY then

          pos = entities[i].Position
          break
        end
      end

      -- Random Pill - 5.70.0
      RNGCounter.AcidBaby = incrementRNG(RNGCounter.AcidBaby)
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_PILL, pos, vel, player, 0, RNGCounter.AcidBaby)
    end
  end

  -- Sack of Sacks (500)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_SACK_OF_SACKS) then -- 500
    -- This drops a sack based on the formula:
    -- floor(roomsCleared / 1.1) > 0 && floor(roomsCleared / 1.1) & 1 == 0
    if math.floor(newRoomsCleared / constant1) > 0 and math.floor(newRoomsCleared / constant1) & 1 == 0 then
      -- Get the position of the familiar
      local entities = Isaac.GetRoomEntities()
      for i = 1, #entities do
        -- Sack of Sacks - 3.114
        if entities[i].Type == EntityType.ENTITY_FAMILIAR and
           entities[i].Variant == FamiliarVariant.SACK_OF_SACKS then

          pos = entities[i].Position
          break
        end
      end

      -- Grab Bag - 5.69.0
      RNGCounter.SackOfSacks = incrementRNG(RNGCounter.SackOfSacks)
      game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_GRAB_BAG, pos, vel, player, 0, RNGCounter.SackOfSacks)
    end
  end
end

--
-- Callbacks
--

function RacingPlus:EntityTakeDamage(TookDamage, DamageAmount, DamageFlag, DamageSource, DamageCountdownFrames)
  local npc = TookDamage:ToNPC()  
  if npc == nil then
    return
  end

  -- We want to track Globins for potential softlocks
  if (npc.Type == EntityType.ENTITY_GLOBIN or
      npc.Type == EntityType.ENTITY_BLACK_GLOBIN) and
     run.currentGlobins[npc.Index] == nil then

    run.currentGlobins[npc.Index] = {
      npc       = npc,
      lastState = npc.State,
      regens    = 0,
    }
  end

  -- We want to "unstick" Knights if they take damage
  if (npc.Type == EntityType.ENTITY_KNIGHT or -- 41
      npc.Type == EntityType.ENTITY_FLOATING_KNIGHT or -- 254
      npc.Type == EntityType.ENTITY_BONE_KNIGHT) and -- 283
     run.currentKnights[npc.Index].damaged == false then

    run.currentKnights[npc.Index].damaged = true
  end
end

function RacingPlus:EvaluateCache(player, cacheFlag)
  if raceVars.character == "Keeper" and cacheFlag == CacheFlag.CACHE_RANGE then -- 8
    local maxHearts = player:GetMaxHearts()
    local coins = player:GetNumCoins()
    local coinContainers = 0

    -- Find out how many coin containers we should have
    -- (2 is equal to 1 actual heart container)
    if coins >= 99 then
      coinContainers = 8
    elseif coins >= 75 then
      coinContainers = 6
    elseif coins >= 50 then
      coinContainers = 4
    elseif coins >= 25 then
      coinContainers = 2
    end
    local baseHearts = maxHearts - coinContainers

    -- We have to add the range cache to all health up items
    --   12  - Magic Mushroom (already has range cache)
    --   15  - <3
    --   16  - Raw Liver (gives 2 containers)
    --   22  - Lunch
    --   23  - Dinner
    --   24  - Dessert
    --   25  - Breakfast
    --   26  - Rotten Meat
    --   81  - Dead Cat
    --   92  - Super Bandage
    --   101 - The Halo (already has range cache)
    --   119 - Blood Bag
    --   121 - Odd Mushroom (Thick) (already has range cache)
    --   129 - Bucket of Lard (gives 2 containers)
    --   138 - Stigmata
    --   176 - Stem Cells
    --   182 - Sacred Heart (already has range cache)
    --   184 - Holy Grail
    --   189 - SMB Super Fan (already has range cache)
    --   193 - Meat!
    --   218 - Placenta
    --   219 - Old Bandage
    --   226 - Black Lotus
    --   230 - Abaddon
    --   253 - Magic Scab
    --   307 - Capricorn (already has range cache)
    --   312 - Maggy's Bow
    --   314 - Thunder Theighs
    --   334 - The Body (gives 3 containers) 
    --   342 - Blue Cap
    --   346 - A Snack
    --   354 - Crack Jacks
    --   456 - Moldy Bread
    local HPItemArray = {
      12,  15,  16,  22,  23,
      24,  25,  26,  81,  92,
      101, 119, 121, 129, 138,
      176, 182, 184, 189, 193,
      218, 219, 226, 230, 253,
      307, 312, 314, 334, 342,
      346, 354, 456,
    }
    for i = 1, #HPItemArray do
      if player:HasCollectible(HPItemArray[i]) then
        if run.keeperHealthItems[HPItemArray[i]] == nil then
          run.keeperHealthItems[HPItemArray[i]] = true

          if HPItemArray[i] == CollectibleType.COLLECTIBLE_ABADDON then -- 230
            player:AddMaxHearts(-24, true) -- Remove all hearts
            player:AddMaxHearts(coinContainers, true) -- Give whatever containers we should have from coins
            player:AddHearts(24) -- This is needed because all the new heart containers will be empty
            -- We have no way of knowing what the current health was before, because "player:GetHearts()" returns 0 at this point
            -- So, just give them max health
            Isaac.DebugString("Set 0 heart containers to Keeper (Abaddon).")

          elseif HPItemArray[i] == CollectibleType.COLLECTIBLE_DEAD_CAT then -- 81
            player:AddMaxHearts(-24, true) -- Remove all hearts
            player:AddMaxHearts(2 + coinContainers, true) -- Give 1 heart container + whatever containers we should have from coins
            player:AddHearts(24) -- This is needed because all the new heart containers will be empty
            -- We have no way of knowing what the current health was before, because "player:GetHearts()" returns 0 at this point
            -- So, just give them max health
            Isaac.DebugString("Set 1 heart container to Keeper (Dead Cat).")

          elseif baseHearts < 0 and
             HPItemArray[i] == CollectibleType.COLLECTIBLE_BODY then -- 334

            player:AddMaxHearts(6, true) -- Give 3 heart containers
            Isaac.DebugString("Gave 3 heart containers to Keeper.")

            -- Fill in the new containers
            player:AddCoins(1)
            player:AddCoins(1)
            player:AddCoins(1)

          elseif baseHearts < 2 and
                 (HPItemArray[i] == CollectibleType.COLLECTIBLE_RAW_LIVER or -- 16
                  HPItemArray[i] == CollectibleType.COLLECTIBLE_BUCKET_LARD or -- 129
                  HPItemArray[i] == CollectibleType.COLLECTIBLE_BODY) then -- 334

            player:AddMaxHearts(4, true) -- Give 2 heart containers
            Isaac.DebugString("Gave 2 heart containers to Keeper.")

            -- Fill in the new containers
            player:AddCoins(1)
            player:AddCoins(1)

          elseif baseHearts < 4 then
            player:AddMaxHearts(2, true) -- Give 1 heart container
            Isaac.DebugString("Gave 1 heart container to Keeper.")

            if HPItemArray[i] ~= CollectibleType.COLLECTIBLE_ODD_MUSHROOM_DAMAGE and -- 121
               HPItemArray[i] ~= CollectibleType.COLLECTIBLE_OLD_BANDAGE then -- 219
               
              -- Fill in the new container
              -- (Odd Mushroom (Thick) and Old Bandage do not give filled heart containers)
              player:AddCoins(1)
            end

          else
            Isaac.DebugString("Health up detected, but baseHearts are full.")
          end
        end
      end
    end
  end

  if race == nil then
    return
  end

  for i = 1, #race.startingItems do
    if race.startingItems[i] == 600 and -- 13 luck
       cacheFlag == CacheFlag.CACHE_LUCK then -- 1024
    
      player.Luck = player.Luck + 13
    end
  end
end

-- Knight invulnerability frame removal and fast-clear stuff
function RacingPlus:NPCUpdate(aNpc)
  -- Local variables
  local game = Game()
  local runFrameCount = game:GetFrameCount()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local room = game:GetRoom()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"

  -- First, look for Knights that are in the "warmup" animation
  if (aNpc.Type == EntityType.ENTITY_KNIGHT or -- 41
      aNpc.Type == EntityType.ENTITY_FLOATING_KNIGHT or -- 254
      aNpc.Type == EntityType.ENTITY_BONE_KNIGHT) and -- 283
     aNpc.FrameCount >= 5 and
     aNpc.FrameCount <= 30 and
     run.currentKnights[aNpc.Index].damaged == false then

    -- Keep the 5th frame of the spawn animation going
    aNpc:GetSprite():SetFrame("Down", 0)

    -- Make sure that it stays in place
    aNpc.Position = run.currentKnights[aNpc.Index].pos
    aNpc.Velocity = Vector(0, 0)
  end

  -- 
  -- Fast-clear - We want to look for enemies that are dying so that we can open the doors prematurely
  --

  -- Only look for enemies that are dying
  if aNpc:IsDead() == false then
    return
  end

  -- Only look for enemies that can shut the doors
  if aNpc.CanShutDoors == false then
    return
  end

  -- Only look when the the room is not cleared yet
  if room:IsClear() then
    return
  end

  -- We don't want to open the doors in a a puzzle room
  if room:HasTriggerPressurePlates() then
    return
  end

  -- Check all the (non-grid) entities in the room to see if anything is alive
  local allDead = true
  local entities = Isaac.GetRoomEntities()
  for i = 1, #entities do
    local npc = entities[i]:ToNPC()
    if npc ~= nil then
      -- We don't fast-clear to apply to splitting enemies, so make an exception for those
      -- (we want to look for these even if they are in a dying state)
      if npc.Type == EntityType.ENTITY_GAPER or -- 10
         npc.Type == EntityType.ENTITY_MULLIGAN or -- 16
         npc.Type == EntityType.ENTITY_HIVE or -- 22
         npc.Type == EntityType.ENTITY_GLOBIN or -- 24
         (npc.Type == EntityType.ENTITY_BOOMFLY and npc.Variant == 2) or -- 25 (for Drowned Boom Flies)
         npc.Type == EntityType.ENTITY_ENVY or -- 51
         npc.Type == EntityType.ENTITY_MEMBRAIN or -- 57 (Mama Guts also counts as Membrain)
         npc.Type == EntityType.ENTITY_FISTULA_BIG or -- 71 (Teratoma also counts as Fistula)
         npc.Type == EntityType.ENTITY_FISTULA_MEDIUM or -- 72 (Teratoma also counts as Fistula)
         npc.Type == EntityType.ENTITY_FISTULA_SMALL or -- 73 (Teratoma also counts as Fistula)
         npc.Type == EntityType.ENTITY_BLASTOCYST_BIG or -- 74
         npc.Type == EntityType.ENTITY_BLASTOCYST_MEDIUM or -- 75
         npc.Type == EntityType.ENTITY_BLASTOCYST_SMALL or -- 76
         npc.Type == EntityType.ENTITY_MOTER or -- 80
         (npc.Type == EntityType.ENTITY_FALLEN and npc.Variant ~= 1) or -- 81 (fast-clear should apply to Krampus)
         npc.Type == EntityType.ENTITY_GURGLE or -- 87
         npc.Type == EntityType.ENTITY_HANGER or -- 90
         npc.Type == EntityType.ENTITY_SWARMER or -- 91
         npc.Type == EntityType.ENTITY_BIGSPIDER or -- 94
         npc.Type == EntityType.ENTITY_NEST or -- 205
         (npc.Type == EntityType.ENTITY_FATTY and npc.Variant == 1) or -- 208 (for Pale Fatties)
         npc.Type == EntityType.ENTITY_FAT_SACK or -- 209
         npc.Type == EntityType.ENTITY_BLUBBER or -- 210
         npc.Type == EntityType.ENTITY_SWINGER or -- 216
         npc.Type == EntityType.ENTITY_SQUIRT or -- 220
         (npc.Type == EntityType.ENTITY_SKINNY and npc.Variant == 1) or -- 226 (for Rotties)
         npc.Type == EntityType.ENTITY_DINGA or -- 223
         npc.Type == EntityType.ENTITY_GRUB or -- 239
         npc.Type == EntityType.ENTITY_BLACK_GLOBIN or -- 278
         npc.Type == EntityType.ENTITY_MEGA_CLOTTY or -- 282
         npc.Type == EntityType.ENTITY_MOMS_DEAD_HAND or -- 287
         npc.Type == EntityType.ENTITY_MEATBALL or -- 290
         npc.Type == 303 or -- There is no enum for Blister (303.0)
         npc.Type == EntityType.ENTITY_BROWNIE or -- 402
         (npc:IsBoss() == false and npc:IsChampion()) or -- This is a champion
         (npc:IsDead() == false and npc.CanShutDoors == true) then -- This is an alive enemy

        -- The following champions split:
        -- 1) Pulsing Green champion, spawns 2 versions of itself
        -- 2) Holy (white) champion, spawns 2 flies
        -- The Lua API doesn't allow us to check the specific champion type, so just make an exception for all champions

        allDead = false
        break
      end
    end
  end
  if allDead then
    -- Manually clear the room, emulating all the steps that the game does
    RacingPlus:ManuallyClearCurrentRoom()
  end
end

-- Check various things once per frame (this will fire while the floor/room is loading)
function RacingPlus:PostRender()
  -- Local variables
  local game = Game()
  local gameFrameCount = game:GetFrameCount()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local room = game:GetRoom()
  local roomFrameCount = room:GetFrameCount()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local clear = room:IsClear()
  local player = game:GetPlayer(0)
  local isaacFrameCount = Isaac:GetFrameCount()

  -- Check to see if we are starting a run
  -- (this does not work if we put it in a PostUpdate callback because that only starts on the first frame of movement)
  -- (this does not work if we put it in a PlayerInit callback because Eve/Keeper are given their active items after the callback has fired)

  if gameFrameCount == 0 and run.initializing == false then
    run.initializing = true
    RacingPlus:RunInit()
  elseif gameFrameCount > 0 and run.initializing == true then
    run.initializing = false
  end

  -- Keep track of when we change floors
  -- (this has to be in the PostRender callback because we don't want to wait for the floor transition animation to complete before teleporting away from the Void floor)
  if stage ~= run.currentFloor then
    -- Find out if we are using a Sacrifice Room
    if stage == 11 and run.currentFloor ~= 10 then
      -- We arrivated at The Chest / Dark Room without going through Cathedral / Sheol
      level:SetStage(run.currentFloor, 0) -- Return to one after the the floor we were on before
      -- (the first argument is "LevelStage", which is 0 indexed for some reason, the second argument is StageType)
      game:StartStageTransition(false, 1) -- The first argument is "SameStage", the second is meaningless
      Isaac.DebugString("Sacrifice Room teleport / cheating detected.")
      return
    end

    -- Set the new floor
    run.currentFloor = stage

    -- Reset the RNG of some items that should be seeded per floor
    local floorSeed = level:GetDungeonPlacementSeed()
    RNGCounter.Teleport = floorSeed
    RNGCounter.Undefined = floorSeed

    -- Detect Void teleports
    if stage ==  12 then
      -- Give the player The Polaroid if they don't have it already
      if player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) == false then
        player:AddCollectible(CollectibleType.COLLECTIBLE_POLAROID, 0, false) -- 327
      end

      -- Teleport them back to Womb 1
      level:SetStage(6, 0) -- Womb 1, a stage type of 0 appears to give a random stage type
      game:StartStageTransition(false, 1) -- The first argument is "SameStage", the second is meaningless
      return
    end

    -- Spawn Mega Satan key pieces
    if race ~= nil and
       race.goal == "Mega Satan" and
       stage == 11 and
       run.placedKeys == false then

      run.placedKeys = true

      -- Key Piece 1 (5.100.238)
      -- 275,175 & 375, 175
      game:Spawn(5, 100, gridToPos(4, 0), Vector(0, 0), nil, CollectibleType.COLLECTIBLE_KEY_PIECE_1, roomSeed)

      -- Key Piece 2 (5.100.239)
      game:Spawn(5, 100, gridToPos(8, 0), Vector(0, 0), nil, CollectibleType.COLLECTIBLE_KEY_PIECE_2, roomSeed)
    end
  end

  -- Keep track of when we change rooms
  -- (this has to be in the PostRender callback because we want the "Go!" graphic to be removed at the beginning of the room transition animation, not the end)
  if roomFrameCount == 0 and run.roomEntering == false then
     run.roomEntering = true
     run.roomsEntered = run.roomsEntered + 1
     run.currentRoomClearState = clear -- This is needed so that we don't get credit for clearing a room when bombing from a room with enemies into an empty room

     -- Also reset the current room's Globins (used for softlock prevention) and Knights (used to delete invulnerability frames)
     run.currentGlobins = {}
     run.currentKnights = {}

  elseif roomFrameCount > 0 then
    run.roomEntering = false
  end

  --
  -- Fix seed incrementation from touching active pedestal items
  -- (this also fixes Angel key pieces and Pandora's Box items being unseeded)
  --

  -- Find "unseeded" pedestal items/trinkets and do item/trinket bans
  local entities = Isaac.GetRoomEntities()
  for i = 1, #entities do
    -- Item pedestals
    if entities[i].Type == EntityType.ENTITY_PICKUP and -- If this is a pedestal item (5.100)
       entities[i].Variant == PickupVariant.PICKUP_COLLECTIBLE and
       entities[i].InitSeed ~= roomSeed and
       room:GetType() ~= RoomType.ROOM_SHOP then -- Skip shops for now because of the "item on sale" bug and the "rerolling into consumables" bug

      -- Check to see if we already replaced it with a seeded pedestal
      local itemIdentifier = tostring(roomSeed) .. "-" .. tostring(entities[i].InitSeed)
      local alreadyReplaced = false
      for j = 1, #run.replacedItems do
        if itemIdentifier == run.replacedItems[j] then
          alreadyReplaced = true
          break
        end
      end

      if alreadyReplaced == false then
        -- Add it to the list of items that have been replaced
        run.replacedItems[#run.replacedItems + 1] = itemIdentifier

        -- Check to see if this is a B1 item room on a seeded race
        local offLimits = false
        if race ~= nil and race.rFormat == "seeded" and
           stage == 1 and
           room:GetType() == RoomType.ROOM_TREASURE and
           entities[i].SubType ~= 263 then
          offLimits = true
        end

        -- Check to see if this item is banned
        local bannedItem = false
        for j = 1, #raceVars.itemBanList do
          if entities[i].SubType == raceVars.itemBanList[j] then
            bannedItem = true
            break
          end
        end

        local newPedestal
        if offLimits then
          -- Change the item to Off Limits (263)
          newPedestal = game:Spawn(5, 100, entities[i].Position, entities[i].Velocity, entities[i].Parent, 263, RNGCounter.InitialSeed)
          game:Fart(newPedestal.Position, 0, newPedestal, 0.5, 0) -- Play a fart animation so that it doesn't look like some bug with the Racing+ mod
          --Isaac.DebugString("Made a new random pedestal (Off Limits).")
        elseif bannedItem then
          -- Make a new random item pedestal (using the B1 floor seed)
          -- (the new random item generated will automatically be decremented from item pools properly on sight)
          newPedestal = game:Spawn(5, 100, entities[i].Position, entities[i].Velocity, entities[i].Parent, 0, RNGCounter.InitialSeed)
          game:Fart(newPedestal.Position, 0, newPedestal, 0.5, 0) -- Play a fart animation so that it doesn't look like some bug with the Racing+ mod
          --Isaac.DebugString("Made a new random pedestal using seed: " .. tostring(RNGCounter.InitialSeed))
        else
          -- Make a new copy of this item using the room seed
          newPedestal = game:Spawn(5, 100, entities[i].Position, entities[i].Velocity, entities[i].Parent, entities[i].SubType, roomSeed)
          
          -- We don't need to make a fart noise because the swap will be completely transparent to the user
          -- (the sprites of the two items will obviously be identical)
          -- We don't need to add this item to the ban list because since it already existed, it was properly decremented from the pools on sight
          --Isaac.DebugString("Made a copied " .. tostring(newPedestal.SubType) .. " pedestal using seed: " .. tostring(roomSeed))
        end

        -- If we don't do this, the item will be fully recharged every time the player swaps it out
        newPedestal:ToPickup().Charge = entities[i]:ToPickup().Charge

        -- If we don't do this, shop items and Devil Room items will become automatically bought
        newPedestal:ToPickup().Price = entities[i]:ToPickup().Price

        -- If we don't do this, you can take both of the pedestals in a double Treasure Room
        newPedestal:ToPickup().TheresOptionsPickup = entities[i]:ToPickup().TheresOptionsPickup

        -- Now that we have created a new pedestal, we can delete the old one
        entities[i]:Remove()
      end
    end

    -- Trinkets
    if entities[i].Type == EntityType.ENTITY_PICKUP and -- If this is a trinket (5.350)
       entities[i].Variant == PickupVariant.PICKUP_TRINKET and
       entities[i].InitSeed ~= roomSeed then

      -- Check to see if we already replaced it with a seeded trinket
      local trinketIdentifier = tostring(roomSeed) .. "-" .. tostring(entities[i].InitSeed)
      local alreadyReplaced = false
      for j = 1, #run.replacedTrinkets do
        if trinketIdentifier == run.replacedTrinkets[j] then
          alreadyReplaced = true
          break
        end
      end

      if alreadyReplaced == false then
        -- Add it to the list of trinkets that have been replaced
        run.replacedTrinkets[#run.replacedTrinkets + 1] = trinketIdentifier

        -- Check to see if this trinket is banned
        local bannedTrinket = false
        for j = 1, #raceVars.trinketBanList do
          if entities[i].SubType == raceVars.trinketBanList[j] then
            bannedTrinket = true
            break
          end
        end

        local newTrinket
        if bannedTrinket then
          -- Spawn a new random trinket (using the B1 floor seed)
          newTrinket = game:Spawn(5, 350, entities[i].Position, entities[i].Velocity, entities[i].Parent, 0, roomSeed)
          --Isaac.DebugString("Made a new random trinket using seed: " .. tostring(roomSeed))
        else
          -- Make a new copy of this trinket using the room seed
          newTrinket = game:Spawn(5, 350, entities[i].Position, entities[i].Velocity, entities[i].Parent, entities[i].SubType, roomSeed)
          --Isaac.DebugString("Made a copied " .. tostring(newPedestal.SubType) .. " trinket using seed: " .. tostring(roomSeed))
        end

        -- Now that we have created a new trinket, we can delete the old one
        entities[i]:Remove()
      end
    end
  end

  --
  -- Draw graphics
  --

  spriteDisplay()
  spriteDisplaySchoolBag()

  --
  -- Do race stuff / draw graphics
  --

  -- Decide if we need to check the "save.dat" file for updates from the Racing+ client
  if race == nil or -- Since we initialized it at the beginning of the program, the "race" table will only be nil if reading the "save.dat" file failed
     raceLoadNextFrame or -- We explicitly need to check for updates on this frame
     race.status == "open" or -- We want to check for updates every frame if the race is starting soon so that we can display the countdown quickly
     race.status == "starting" or -- We want to check for updates every frame if the race is starting so that the countdown is smooth
     ((race.status == "none" or race.status == "in progress") and isaacFrameCount % 30 == 0) then -- Otherwise, only check for updates every half second (file reads are expensive)

    -- The server will write data for us to the "save.dat" file in the mod subdirectory
    -- From: https://www.reddit.com/r/themoddingofisaac/comments/5q3ml0/tutorial_saving_different_moddata_for_each_run/
    local oldRace = race
    race = load("return " .. Isaac.LoadModData(RacingPlus))() -- This loads the "save.dat" file

    -- Sometimes loading can fail, I'm not sure why; give up for now and try again on the next frame
    if race == nil then
      Isaac.DebugString("Loading the \"save.dat\" file failed. Trying again on the next frame...")
      return
    end

    -- If anything changed, write it to the log
    if oldRace == nil then
      return
    end
    if oldRace.status ~= race.status then
      Isaac.DebugString("ModData status changed: " .. race.status)
    end
    if oldRace.rType ~= race.rType then
      Isaac.DebugString("ModData rType changed: " .. race.rType)
    end
    if oldRace.rFormat ~= race.rFormat then
      Isaac.DebugString("ModData rFormat changed: " .. race.rFormat)
    end
    if oldRace.character ~= race.character then
      Isaac.DebugString("ModData character changed: " .. race.character)
    end
    if oldRace.goal ~= race.goal then
      Isaac.DebugString("ModData goal changed: " .. race.goal)
    end
    if oldRace.seed ~= race.seed then
      Isaac.DebugString("ModData seed changed: " .. race.seed)
    end
    if #oldRace.startingItems ~= #race.startingItems then
      Isaac.DebugString("ModData startingItems amount changed: " .. tostring(#race.startingItems))
    end
    if oldRace.currentSeed ~= race.currentSeed then
      Isaac.DebugString("ModData currentSeed changed: " .. race.currentSeed)
    end
    if oldRace.countdown ~= race.countdown then
      Isaac.DebugString("ModData countdown changed: " .. tostring(race.countdown))
    end
  end

  -- Since race loading succeeded, we need to check to see if we have done a once-per-run race initiailization
  RacingPlus:RunInitForRace()

  -- Make sure that some race related variables are reset
  -- (we need to check for "open" because it is possible to quit at the main menu and then join another race before starting the game)
  if race.status == "none" or race.status == "open" then
    raceVars.hourglassUsed = false
    raceVars.started = false
    raceVars.startedTime = 0 -- Remove the timer after we finish or quit a race (1/2)
    spriteInit("clock", 0) -- Remove the timer after we finish or quit a race (2/2)
    raceVars.updateCache = 0
  end

  -- If we are not in a run, do nothing
  if race.status == "none" then
    return
  end

  -- Check to see if we are on the BLCK CNDL Easter Egg
  if raceVars.blckCndlOn == false and raceVars.startedTime == 0 then
    spriteInit("top", "errorBlckCndl")
    return
  end

  -- Check to see if we are on hard mode
  if raceVars.difficulty ~= 0 and raceVars.startedTime == 0 then
    spriteInit("top", "errorHardMode")
    return
  end

  -- Check to see if we are on the right character
  if race.character ~= raceVars.character and raceVars.startedTime == 0 then
    spriteInit("top", "errorCharacter")
    return
  end

  -- Check to see if we are on the right seed
  if race.seed ~= "-" and race.seed ~= race.currentSeed and raceVars.startedTime == 0 then
    spriteInit("top", "errorSeed")
    return
  end

  -- Hold the player in place if the race has not started yet (emulate the Gaping Maws effect)
  if raceVars.started == false then
    -- The starting position is 320.0, 380.0
    player.Position = Vector(320.0, 380.0)
  end

  -- Show the "Wait for the race to begin!" graphic/text
  if race.status == "open" then
    spriteInit("top", "wait")
  end

  -- For some reason, Glowing Hour Glass does not update the cache properly for some items, so update the cache manually
  if gameFrameCount >= 1 and raceVars.updateCache == 2 then
    raceVars.updateCache = 0

    for i = 1, #race.startingItems do
      if race.startingItems[i] == 275 or -- Lil' Brimstone
         race.startingItems[i] == 172 or -- Sacrificial Dagger
         race.startingItems[i] == 360 then -- Incubus

        -- Using "EvaluateItems()" doesn't update the familiar cache, so do it ourselves manually
        player:RemoveCollectible(race.startingItems[i])
        Isaac.DebugString("Removing collectible " .. tostring(race.startingItems[i]))
        player:AddCollectible(race.startingItems[i], 0, false)
      end
    end
  end

  -- Show the appropriate countdown graphic/text
  if run.roomsEntered > 1 then
    -- Remove the "Go!" graphic as soon as we enter another room
    -- (the starting room counts as room #1)
    spriteInit("top", 0)
  end
  if race.status == "starting" or race.status == "in progress" then
    if race.countdown == 10 then
      spriteInit("top", "10")
    elseif race.countdown == 5 then
      spriteInit("top", "5")
    elseif race.countdown == 4 then
      spriteInit("top", "4")
    elseif race.countdown == 3 then
      spriteInit("top", "3")
    elseif race.countdown == 2 then
      spriteInit("top", "2")

      if raceVars.hourglassUsed == false then
        raceVars.hourglassUsed = true

        -- For some reason, Glowing Hour Glass does not update the familiar cache properly, so we have to manually update the cache a frame from now
        for i = 1, #race.startingItems do
          if race.startingItems[i] == 172 or -- Sacrificial Dagger
             race.startingItems[i] == 275 or -- Lil' Brimstone
             race.startingItems[i] == 360 then -- Incubus

            raceVars.updateCache = 1 -- Set the cache to update on the first game frame after the next reset
          end
        end

        -- Fix a bug with Dead Eye where the multiplier will not get properly reset after using Glowing Hour Glass
        for i = 1, 100 do
          -- This function is analogous to missing a shot, so let's miss 100 shots to be sure that the multiplier is actually cleared
          player:ClearDeadEyeCharge()
        end

        -- Fix a bug with Mega Blast where it will continue to shoot after using Glowing Hour Glass
        -- (swapping the Mega Blast for another spacebar item should stop the blast)
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_MEGA_SATANS_BREATH) -- 441

        -- Use the Glowing Hour Glass (422)
        player:UseActiveItem(422, false, false, false, false)
      end
    elseif race.countdown == 1 then
      spriteInit("top", "1")
    elseif race.countdown == 0 and raceVars.started == false then -- The countdown has reached 0
      -- Set the start time to the number of frames that have elapsed since the game is open
      -- (this won't account for lag, but we are unable to call things like "os.clock()" without forcing the using to enable the "--luadebug" flag on the game)
      -- (we have to do this here so that the clock doesn't get reset if the player dies or resets)
      raceVars.startedTime = isaacFrameCount

      -- Draw the "Go!" graphic
      spriteInit("top", "go") 

      -- Start the race, if it isn't already
      RacingPlus:RaceStart()
    end

    timerUpdate()
  end
end

-- Check various things once per frame (this will not fire while the floor/room is loading)
function RacingPlus:PostUpdate()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local room = game:GetRoom()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local clear = room:IsClear()
  local player = game:GetPlayer(0)
  local playerSprite = player:GetSprite()
  local isaacFrameCount = Isaac:GetFrameCount()

  --
  -- Keep track of the total amount of rooms cleared on this run thus far
  --

  -- Check the clear status of the room and compare it to what it was a frame ago
  if clear ~= run.currentRoomClearState then
    run.currentRoomClearState = clear

    if clear == true then
      -- If the room just got changed to a cleared state, increment the total rooms cleared
      run.roomsCleared = run.roomsCleared + 1
      Isaac.DebugString("Rooms cleared: " .. tostring(run.roomsCleared))

      -- Find out if we are in a 2x2 or L room
      local chargesToAdd = 1
      local shape = room:GetRoomShape()
      if shape >= 8 then
        chargesToAdd = 2
      end

      -- Give a charge to the player's School Bag item
      if run.schoolBagItem ~= 0 and run.schoolBagCharges < run.schoolBagMaxCharges then
        -- Add the correct amount of charges
        run.schoolBagCharges = run.schoolBagCharges + chargesToAdd
        if run.schoolBagCharges > run.schoolBagMaxCharges then
          run.schoolBagCharges = run.schoolBagMaxCharges
        end
      end
    end
  end

  --
  -- Keep track of our max hearts if we are Keeper (to fix the Greed's Gullet bug)
  --

  if raceVars.character == "Keeper" then
    local maxHearts = player:GetMaxHearts()
    local hearts = player:GetHearts()
    local coins = player:GetNumCoins()
    local coinContainers = 0

    -- Find out how many coin containers we should have
    -- (2 is equal to 1 actual heart container)
    if coins >= 99 then
      coinContainers = 8
    elseif coins >= 75 then
      coinContainers = 6
    elseif coins >= 50 then
      coinContainers = 4
    elseif coins >= 25 then
      coinContainers = 2
    end
    local baseHearts = maxHearts - coinContainers

    if baseHearts ~= run.keeperBaseHearts then
      -- Our health changed; we took a devil deal, took a health down pill, or went from 1 heart to 2 hearts
      local heartsDiff = baseHearts - run.keeperBaseHearts
      run.keeperBaseHearts = run.keeperBaseHearts + heartsDiff
      Isaac.DebugString("Set new Keeper baseHearts to: " .. tostring(run.keeperBaseHearts) .. " (from detection, change was " .. tostring(heartsDiff) .. ")")
    end
  end

  --
  -- Fix Globin softlocks
  --

  for i, globin in pairs(run.currentGlobins) do
    if globin ~= nil then
      if globin.npc.State ~= globin.lastState and globin.npc.State == 3 then
        -- A globin went down
        globin.regens = globin.regens + 1
        if (globin.regens >= 5) then
          globin.npc:Kill()
          run.currentGlobins[i] = nil
          Isaac.DebugString("Killed Globin " .. tostring(i) .. " to prevent a soft-lock.")
        end
      end
      globin.lastState = globin.npc.State
    end
  end

  -- Check all the (non-grid) entities in the room
  local entities = Isaac.GetRoomEntities()
  for i = 1, #entities do
    --
    -- Make Troll Bomb and Mega Troll Bomb fuses deterministic (exactly 2 seconds long)
    -- (in vanilla the fuse is: 45 + random(1, 2147483647) % 30)
    --

    if entities[i].FrameCount == 1 and
       entities[i].Type == EntityType.ENTITY_BOMBDROP and
       (entities[i].Variant == 3 or -- Troll Bomb
        entities[i].Variant == 4) then -- Mega Troll Bomb

      local bomb = entities[i]:ToBomb()
      bomb:SetExplosionCountdown(59) -- 60 minus 1 because we start at frame 1
      -- Note that game physics occur at 30 frames per second instead of 60
    end

    --
    -- Fix invulnerability frames on Knights, Selfless Knights, Floating Knights, Bone Knights, Eyes, Bloodshot Eyes, Wizoobs, and Red Ghosts
    --

    local npc = entities[i]:ToNPC()
    if npc ~= nil then
      if npc.Type == EntityType.ENTITY_KNIGHT or -- 41
         npc.Type == EntityType.ENTITY_FLOATING_KNIGHT or -- 254
         npc.Type == EntityType.ENTITY_BONE_KNIGHT then -- 283

        -- Knights, Selfless Knights, Floating Knights, and Bone Knights
        -- Add their position to the table so that we can keep track of it on future frames
        if run.currentKnights[npc.Index] == nil then
          run.currentKnights[npc.Index] = {
           pos = npc.Position,
           damaged = false,
         }
        end

        if npc.FrameCount == 4 then
          -- Changing the NPC's state triggers the invulnerability removal in the next frame
          npc.State = 4

          -- Manually setting visible to true allows us to disable the invulnerability 1 frame earlier
          -- (this is to compensate for having only post update hooks)
          npc.Visible = true
        end

      elseif npc.Type == EntityType.ENTITY_EYE then -- 60
        -- Eyes and Blootshot Eyes
        if npc.FrameCount == 4 then
          npc:GetSprite():SetFrame("Eye Opened", 0)
          npc.State = 3
          npc.Visible = true
        end

        -- Prevent the Eye from shooting for 30 frames
        if (npc.State == 4 or npc.State == 8) and npc.FrameCount < 31 then
          npc.StateFrame = 0
        end

      elseif npc.Type == EntityType.ENTITY_WIZOOB or -- 219
             npc.Type == EntityType.ENTITY_RED_GHOST then -- 285

        -- Wizoobs and Red Ghosts
        if npc.FrameCount == 1 then -- (most NPCs are only visable on the 4th frame, but these are visible immediately)
          -- The ghost is set to ENTCOLL_NONE until the first reappearance
          npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
        end
      end
    end
  end
  
  --
  -- Check for co-op babies
  --

  if run.spawnedCoop == false then
    for i = 0, 3 do -- There are 4 possible players from 0 to 3
      if Input.IsActionPressed(ButtonAction.ACTION_JOINMULTIPLAYER, i) then -- 19
        run.spawnedCoop = true
        player:ResetDamageCooldown() -- Get rid of their invulnerability frames, if any
        player:TakeDamage(24, 0, EntityRef(player), 0) -- Damage, Flags, Source, DamageCountdown
        -- This should kill them instantly
      end
    end
  end

  --
  -- Check for input for a School Bag switch
  --

  if race ~= nil and
     race.schoolBag == true and
     isaacFrameCount >= run.schoolBagFrame then

    if playerSprite:IsPlaying("Pickup") or
       playerSprite:IsPlaying("PickupWalkDown") or
       playerSprite:IsPlaying("PickupWalkLeft") or
       playerSprite:IsPlaying("PickupWalkUp") or
       playerSprite:IsPlaying("PickupWalkRight") then
       
       run.schoolBagFrame = isaacFrameCount + 69 -- The animation is only 42 frames long, but if we delay anything less than 69, it will hit twice
       Isaac.DebugString("Delaying to frame " .. tostring(run.schoolBagFrame) .. ".")
       return
    end

    for i = 0, 3 do -- There are 4 possible players from 0 to 3
      if Input.IsActionPressed(ButtonAction.ACTION_DROP, i) then -- 11
        Isaac.DebugString("Used School Bag (on frame " .. tostring(isaacFrameCount) .. ").")
        -- Set a new cooldown period so that we can't spam this
        run.schoolBagFrame = isaacFrameCount + 20 -- 1/3 of a second

        -- Switch the items
        local activeItem = player:GetActiveItem()
        local activeCharge = player:GetActiveCharge()
        if run.schoolBagItem == 0 then
          player:RemoveCollectible(activeItem)
        else
          player:AddCollectible(run.schoolBagItem, run.schoolBagCharges, false)
        end
        run.schoolBagItem = activeItem
        run.schoolBagCharges = activeCharge
        RacingPlus:SchoolBagInit()
      end
    end
  end
end

function RacingPlus:BookOfSin()
  -- Local variables
  local game = Game()
  local player = game:GetPlayer(0)

  -- The Book of Sin has an equal chance to spawn a heart, coin, bomb, key, battery, pill, or card/rune.
  RNGCounter.BookOfSin = incrementRNG(RNGCounter.BookOfSin)
  math.randomseed(RNGCounter.BookOfSin)
  local bookPickupType = math.random(1, 7)
  RNGCounter.BookOfSin = incrementRNG(RNGCounter.BookOfSin)

  local pos = player.Position
  local vel = Vector(0, 0)

  -- If heart
  if bookPickupType == 1 then
    -- Random Heart - 5.10.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If coin
  elseif bookPickupType == 2 then
    -- Random Coin - 5.20.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If bomb
  elseif bookPickupType == 3 then
    -- Random Bomb - 5.40.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If key
  elseif bookPickupType == 4 then
    -- Random Key - 5.30.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If battery
  elseif bookPickupType == 5 then
    -- Lil' Battery - 5.90.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If pill
  elseif bookPickupType == 6 then
    -- Random Pill - 5.70.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_PILL, pos, vel, player, 0, RNGCounter.BookOfSin)

  -- If card/rune
  elseif bookPickupType == 7 then
    -- Random Card - 5.300.0
    game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, pos, vel, player, 0, RNGCounter.RuneBag)
  end

  -- By returning true, it will play the animation where Isaac holds the Book of Sin over his head
  return true
end

function RacingPlus:Teleport()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local index = level:GetCurrentRoomIndex()
  local index2 = level:GetStartingRoomIndex()

  --[[
  level:ChangeRoom(index2)
  level:ChangeRoom(index2)
  level:ChangeRoom(index2)
  --]]
  game:StartRoomTransition(index2, Direction.NO_DIRECTION, 3)
  Isaac.DebugString("Current room index: " .. tostring(index))
  Isaac.DebugString("Teleporting to room: " .. tostring(index2))
end

function RacingPlus:MegaBlast()
  local game = Game()
  local player = game:GetPlayer(0)
  player:AnimateSad()
  return true
end

function debugFunction()
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local room = game:GetRoom()
  local player = game:GetPlayer(0)

  -- Print out various debug information to Isaac's log.txt
  Isaac.DebugString("-----------------------")
  Isaac.DebugString("Entering test callback.")
  Isaac.DebugString("-----------------------")

  Isaac.DebugString("run table:")
  for k, v in pairs(run) do
    Isaac.DebugString("    " .. k .. ': ' .. tostring(v))
  end

  Isaac.DebugString("race table:")
  for k, v in pairs(race) do
    Isaac.DebugString("    " .. k .. ': ' .. tostring(v))
  end

  Isaac.DebugString("raceVars table:")
  for k, v in pairs(raceVars) do
    Isaac.DebugString("    " .. k .. ': ' .. tostring(v))
    if k == "itemBanList" or k == "trinketBanList" then
      for x, y in pairs(raceVars[k]) do
        Isaac.DebugString("        " .. x .. ': ' .. tostring(y))
      end
    end
  end

  Isaac.DebugString("sprite table:")
  for k, v in pairs(spriteTable) do
    for k2, v2 in pairs(v) do
      Isaac.DebugString("    " .. k .. '.' .. k2 .. ': ' .. tostring(v2))
    end
  end

  Isaac.DebugString("----------------------")
  Isaac.DebugString("Exiting test callback.")
  Isaac.DebugString("----------------------")

  -- Display the "use" animation
  return true
end

-- Define callbacks
RacingPlus:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, RacingPlus.EntityTakeDamage)
RacingPlus:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,  RacingPlus.EvaluateCache)
RacingPlus:AddCallback(ModCallbacks.MC_NPC_UPDATE,      RacingPlus.NPCUpdate)
RacingPlus:AddCallback(ModCallbacks.MC_POST_RENDER,     RacingPlus.PostRender)
RacingPlus:AddCallback(ModCallbacks.MC_POST_UPDATE,     RacingPlus.PostUpdate)
RacingPlus:AddCallback(ModCallbacks.MC_USE_ITEM,        RacingPlus.BookOfSin, CollectibleType.COLLECTIBLE_BOOK_OF_SIN_SEEDED) -- Replacing Book of Sin (97) with 43
--RacingPlus:AddCallback(ModCallbacks.MC_USE_ITEM,        RacingPlus.Teleport, 59) -- Replacing Teleport (44) (TODO)
--RacingPlus:AddCallback(ModCallbacks.MC_USE_ITEM,        RacingPlus.Undefined, 61) -- Replacing Undefined (324) (TODO)
RacingPlus:AddCallback(ModCallbacks.MC_USE_ITEM,        RacingPlus.MegaBlast, megaBlastPlaceholder) -- Mega Blast (Placeholder)
RacingPlus:AddCallback(ModCallbacks.MC_USE_ITEM,        debugFunction, 235) -- Debug (custom item)

-- Missing item IDs: 43, 59, 61, 235, 263
