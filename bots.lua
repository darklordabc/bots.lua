BOTS_VERSION = "0.1"

--[[
  bots.lua helps making your bots a bit more interesting
  Main features are custom abilities, custom build order and custom item build

  Installation
  -"require" this file inside your code in order to gain access to the PlayerTables global table.

  Library Usage
  -Lua
    -void PlayerTables:CreateTable(tableName, tableContents, pids)
      Creates a new PlayerTable with the given name, default table contents, and automatically sets up a subscription
      for all playerIDs in the "pids" object.

  Examples:
    --Create a Table and set a few values.
      PlayerTables:CreateTable("new_table", {initial="initial value"}, {0})
      PlayerTables:SetTableValue("new_table", "count", 0)
      PlayerTables:SetTableValues("new_table", {val1=1, val2=2})

]]

BOTS_DIRE = 5
BOTS_RADIANT = 5

-- If you use default valve-provided hero selection this should be "true" so bots can get random hero
BOTS_USE_DEFAULT_HERO_SELECTION = true

if not Bots then
  Bots = class({})
end

function Bots:createBots()
  self.botsCreated = true

  self.desiredRadiant = BOTS_DIRE or 5
  self.desiredDire = BOTS_RADIANT or 5

  -- Adjust the team sizes
  GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, self.desiredRadiant)
  GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, self.desiredDire)

  -- Grab number of players
  local maxplayerID = 24
  local totalRadiant = 0
  local totalDire = 0

  -- Work out how many bots are going to be needed
  for playerID=0,maxplayerID-1 do
    local state = PlayerResource:GetConnectionState(playerID)

    if state ~= 0 then
      if PlayerResource:GetTeam(playerID) == DOTA_TEAM_GOODGUYS then
        totalRadiant = totalRadiant + 1
      elseif PlayerResource:GetTeam(playerID) == DOTA_TEAM_BADGUYS then
        totalDire = totalDire + 1
      end
    end
  end

  -- Add bot players
  self.botPlayers = {
    radiant = {},
    dire = {},
    all = {},
    -- Unique skills for teams
    [DOTA_TEAM_GOODGUYS] = {},
    [DOTA_TEAM_BADGUYS] = {},
    -- Unique global skills
    global = {}
  }

  local playerID

  -- Add radiant players
  while totalRadiant < self.desiredRadiant do
    playerID = totalRadiant + totalDire
    totalRadiant = totalRadiant + 1
    Tutorial:AddBot('', '', 'unfair', true)

    local ply = PlayerResource:GetPlayer(playerID)
    if ply then
      local store = {
        ply = ply,
        team = DOTA_TEAM_GOODGUYS,
        ID = playerID
      }

      -- Store this bot player
      self.botPlayers.radiant[playerID] = store
      self.botPlayers.all[playerID] = store

      -- Push them onto the correct team
      PlayerResource:SetCustomTeamAssignment(playerID, DOTA_TEAM_GOODGUYS)

      if BOTS_USE_DEFAULT_HERO_SELECTION then
        ply:MakeRandomHeroSelection()
      end
    end
  end

  -- Add dire players
  while totalDire < self.desiredDire do
    playerID = totalRadiant + totalDire
    totalDire = totalDire + 1
    Tutorial:AddBot('', '', 'unfair', false)

    local ply = PlayerResource:GetPlayer(playerID)
    if ply then
      local store = {
        ply = ply,
        team = DOTA_TEAM_BADGUYS,
        ID = playerID
      }

      -- Store this bot player
      self.botPlayers.dire[playerID] = store
      self.botPlayers.all[playerID] = store

      -- Push them onto the correct team
      PlayerResource:SetCustomTeamAssignment(playerID, DOTA_TEAM_BADGUYS)

      if BOTS_USE_DEFAULT_HERO_SELECTION then
        ply:MakeRandomHeroSelection()
      end
    end
  end
end

function Bots:doToAllBots( callback )
  for _,v in pairs(Entities:FindAllByName("npc_dota_hero*")) do
    if IsValidEntity(v) and v:IsNull() == false and v.GetPlayerOwnerID and not v:IsClone() and not v:HasModifier("modifier_arc_warden_tempest_double") and PlayerResource:GetSteamAccountID(v:GetPlayerOwnerID()) == 0 then
      callback(v)
    end
  end
end

function Bots:onThink()
  if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
    if BOTS_USE_DEFAULT_HERO_SELECTION then
      if not self.botsCreated then
        self:createBots()
      end
    end
  elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return nil
  end
  return 1
end

function Bots:start()
  GameRules:GetGameModeEntity():SetBotThinkingEnabled(true)

  ListenToGameEvent('game_rules_state_change', 
    function(keys)
      local state = GameRules:State_Get()

      if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
      elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        Tutorial:StartTutorialMode()
      end
    end, 
  nil)

  GameRules:GetGameModeEntity():SetThink('onThink', self, 'BotsThink', 0.25)
end