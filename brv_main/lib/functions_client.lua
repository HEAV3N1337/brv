--------------------------------------------------------------------------------
--                               BATTLE ROYALE V                              --
--                            Client functions file                           --
--------------------------------------------------------------------------------

function GetPlayers()
  local players = {}

  for i = 0, 31 do
    if NetworkIsPlayerActive(i) then
      table.insert(players, i)
    end
  end

  return players
end

-- Prints help text (top left)
function showHelp(str)
  SetTextComponentFormat("STRING")
  AddTextComponentString(str)
  DisplayHelpTextFromStringLabel(0, 0, 0, -1)
end

-- Print notification (bottom left)
function showNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text:gsub('[^%w~!%.%(%)|# ]',''))
  DrawNotification(true, false)
end

-- Print notification with details
function showNotificationDetails(pic, title, subtitle, message)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(message)
  SetNotificationMessage(pic, pic, true, 2, title, subtitle)
  DrawNotification(true, false)
end

-- Print a text at coords
function showText(text, x, y, color, font)
  if color == nil then
    color = conf.color.grey
  end
  if font == nil then
    font = 4
  end
  SetTextFont(font)
  SetTextProportional(1)
  SetTextScale(0.0, 0.5)
  SetTextColour(color.r, color.g, color.b, 255)
  -- SetTextDropshadow(0, 0, 0, 0, 255)
  -- SetTextEdge(1, 0, 0, 0, 255)
  -- SetTextDropShadow()
  SetTextOutline()
  SetTextEntry("STRING")
  AddTextComponentString(text)
  DrawText(x, y)
end

function getGroundZ(x, y, z)
  local result, groundZ = GetGroundZFor_3dCoord(x+0.0, y+0.0, z+0.0, Citizen.ReturnResultAnyway())
  return groundZ
end

-- Get the current ped weapon equipped
function getPedWeapon(ped)
  local int
  pedWeapon = Citizen.InvokeNative(0x3A87E44BB9A01D54, ped, Citizen.PointerValueIntInitialized(int), 0)
  return pedWeapon
end

-- Teleports current player to coords
function teleport(coords)
  Citizen.CreateThread(function()
    local playerPed = GetPlayerPed(-1)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    while not HasCollisionLoadedAroundEntity(playerPed) do
      RequestCollisionAtCoord(coords.x, coords.y, coords.z)
      Wait(0)
    end
    ClearPedTasksImmediately(playerPed)

    local groundZ = coords.z
    if groundZ == 0.0 then
      groundZ = getGroundZ(coords.x, coords.y, 1000.0)
    end
    SetEntityCoords(playerPed, coords.x, coords.y, groundZ)
  end)
end

-- Change the skin of the player, from a predefined list
function changeSkin(skin)
  local model = (skin ~= '' and skin or getRandomNPCModel())
  Citizen.CreateThread(function()
    -- Get model hash.
    local modelhashed = GetHashKey(model)

    -- Request the model, and wait further triggering untill fully loaded.
    RequestModel(modelhashed)
    while not HasModelLoaded(modelhashed) do
      RequestModel(modelhashed)
      Wait(0)
    end
    -- Set playermodel.
    SetPlayerModel(PlayerId(), modelhashed)
    -- Set model no longer needed.
    SetModelAsNoLongerNeeded(modelhashed)
  end)
  return model
end

-- Sets a countdown
-- duration (integer) : Duration of the countdown (seconds)
-- step (integer) : Step of the countdown (seconds)
function showCountdown(duration, step, callback)
  Citizen.CreateThread(function()
      local startedAt = GetGameTimer()
      local time = duration
      local run = true
      local loop = 0
      local color = nil
      local countdown = 0

      while run do
        Wait(0)
        timeDiff = GetTimeDifference(GetGameTimer(), startedAt)
        countdown = duration - tonumber(round(timeDiff / (step * 1000)))

        if countdown < (duration / 10) then
          color = conf.color.red
        end

        showText(tonumber(round(countdown)) .. 's remaining', 0.93, 0.08, color)

        if countdown <= 0 then
          run = false
        end
        if not getIsGameStarted() then return end
      end
      callback()
  end)
end

-- Returns a random npc model from a predefined list
function getRandomNPCModel()
  local nbModels = count(npc_models)
  local randModelIndex = math.random(nbModels)
  return npc_models[randModelIndex]
end

-- Returns a random weapon model from a predefined list
function getRandomWeapon(type)
  if weapons[type] == nil then return false end

  local nbWeapons = count(weapons[type])
  local randWeaponIndex = math.random(nbWeapons)
  return weapons[type][randWeaponIndex]
end

-- Returns the pickup hash equivalent from a weapon hash
-- false if the hash is not found
function getPickupHashFromWeapon(hash)
  for k,v in pairs(weapons) do
    for i,value in pairs(v) do
      local pickupHash = GetHashKey(value)
      if pickupHash < 0 then
        pickupHash = pickupHash +0xFFFFFFFF +1
      end
      if pickupHash == hash then
        return GetHashKey('pickup_' .. value)
      end
    end
  end

  return false
end

-- Returns a random location from a predefined list
function getRandomLocation()
  local nbLocations = count(locations)
  local randLocationIndex = math.random(nbLocations)
  return locations[randLocationIndex]
end

-- Sets the current safe zone and draws it on the map
-- safeZoneBlip (integer)
-- safeZoneCoords (x, y, z)
-- safeZoneRadius (float)
-- removeBlip (boolean) : If true, removes the previous drawed safe zone if it exists
-- step (integer)
function setSafeZone(safeZoneBlip, safeZone, step, removeBlip)
  if removeBlip and safeZoneBlip ~= nil then
    RemoveBlip(safeZoneBlip)
  end

  local colorIndex =  25

  if step == 5 then colorIndex = 1 end

  safeZoneBlip = AddBlipForRadius(safeZone.x, safeZone.y, safeZone.z, safeZone.radius * 1.0)
  SetBlipColour(safeZoneBlip, colorIndex)
  SetBlipAlpha(safeZoneBlip, 100 + (10*step)) --

  return safeZoneBlip
end

function addWeaponBlip(coords)
  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(blip, 110)
  SetBlipAsShortRange(blip, true)

  return blip
end

-- Returns true if the player is out of the zone, false otherwise
function isPlayerOutOfZone(safeZone)
  if safeZone == nil then return false end

  local playerPos = GetEntityCoords(GetPlayerPed(PlayerId()))
  local distance = math.abs(GetDistanceBetweenCoords(playerPos.x, playerPos.y, playerPos.z, safeZone.x, safeZone.y, safeZone.z, false))

  return distance > safeZone.radius
end

-- Returns true if the player is near coords
function isPlayerNearCoords(coords, min)
  if min == nil then min = 100.0 end

  if coords == nil then return false end

  local playerPos = GetEntityCoords(GetPlayerPed(PlayerId()))
  local distance = math.abs(GetDistanceBetweenCoords(playerPos.x, playerPos.y, playerPos.z, coords.x, coords.y, coords.z, true))

  return distance <= min
end

function drawInstructionalButtons(buttons)
  Citizen.CreateThread(function()
    local scaleform = RequestScaleformMovie('instructional_buttons')
    while not HasScaleformMovieLoaded(scaleform) do
      Wait(0)
    end

    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PushScaleformMovieFunction(scaleform, 'TOGGLE_MOUSE_BUTTONS')
    PushScaleformMovieFunctionParameterBool(0)
    PopScaleformMovieFunctionVoid()

    for i,v in ipairs(buttons) do
      PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
      PushScaleformMovieFunctionParameterInt(i-1)
      Citizen.InvokeNative(0xE83A3E3557A56640, v.button)
      PushScaleformMovieFunctionParameterString(v.label)
      PopScaleformMovieFunctionVoid()
    end

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PushScaleformMovieFunctionParameterInt(-1)
    PopScaleformMovieFunctionVoid()
    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
  end)
end
