-- Midnight Riders Dragons: an elite dragon around the portrait of the guild's leaders.
--   Guild master  -> gold winged dragon (the art Forever uses for bosses)
--   Officers      -> silver winged dragon (the art Forever uses for rares)
-- Shown on the player, target and focus frames. Rank comes from GetGuildInfo(unit), which the game
-- knows for any player you can see, so everyone with this addon sees the dragons; no messages are sent.
--
-- The art and offsets are Forever's own (Blizzard_UnitFrame/Camelot/TargetFrameUtils.lua,
-- GetBossPortraitFrameData). The player frame has no dragon slot, so it gets a mirrored copy.
local ADDON, ns = ...

-- Guild settings -------------------------------------------------------------------

local GUILD = "Midnight Riders"
-- Who is an officer:
--  1. Members of the guild read it from the guild's own rank settings: a rank with "officer
--     privileges" ticked (permission 22 in C_GuildInfo.GuildControlGetRankFlags) is an officer rank.
--  2. Players outside the guild can't see those settings, so for them (or if the client won't say)
--     these rank numbers (0 is the guild master, 1 the next rank down, ...) and any rank whose name
--     contains one of these words count as officers.
local OFFICER_FLAG = 22
local OFFICER_RANKS = { [1] = true }
local OFFICER_WORDS = { "officer" }

local STYLES = {
  gm      = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", x = 11, y = -4, label = "gold" },
  officer = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged", x = 8, y = -7, label = "silver" },
}

-- Target frame portrait: TOPRIGHT -26, -19 in its container. Player portrait: TOPLEFT 24, -19.
local TARGET_PORTRAIT_X, TARGET_PORTRAIT_Y = -26, -19

local NAME = "|cff8a7cffMidnight Riders|r"
local issecret = issecretvalue or function() return false end
local DEFAULTS = { enabled = true, player = true, target = true, focus = true, party = true, preview = nil, nudgeX = 0, nudgeY = 0 }

local db
local overlays = {} -- frameKey -> texture

local function Print(msg) print(NAME .. " Dragons: " .. tostring(msg)) end

-- Who gets a dragon ----------------------------------------------------------------

local function Plain(...)
  for i = 1, select("#", ...) do
    if issecret((select(i, ...))) then return false end
  end
  return true
end

-- Officer ranks from the guild's own settings, when we are in the guild and the client will say.
-- rankIndex (0 = guild master) -> true/false; nil when unknown. Rebuilt when ranks change.
local officerByRank

local function InOurGuild()
  local ok, g = pcall(GetGuildInfo, "player")
  return ok and g ~= nil and not issecret(g) and g == GUILD
end

local function LoadOfficerRanks()
  officerByRank = nil
  if not InOurGuild() or not (C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags and GuildControlGetNumRanks) then
    return
  end
  local ok, n = pcall(GuildControlGetNumRanks)
  if not ok or type(n) ~= "number" or n < 1 then return end
  local map, any = {}, false
  for order = 1, n do
    -- Never call GuildControlSetRank here: on Forever it is Blizzard-only, and calling it shows
    -- "blocked from an action only available to the Blizzard UI" (pcall can't catch that).
    local okFlags, flags = pcall(C_GuildInfo.GuildControlGetRankFlags, order)
    if okFlags and type(flags) == "table" and flags[OFFICER_FLAG] ~= nil then
      map[order - 1] = flags[OFFICER_FLAG] == true
      any = true
    end
  end
  if any then officerByRank = map end
end

-- The guild roster, for members of the guild. On Forever GetGuildInfo(unit) doesn't reliably tell
-- us another player's guild and rank, but the roster does, so we match people by GUID (and by
-- name as a backup: the roster says "Cassidy Darkstarr", the unit "Cassidy" + surname "Darkstarr").
local rosterByGUID, rosterByName, rosterByFirst = {}, {}, {}

local function LoadRoster()
  rosterByGUID, rosterByName, rosterByFirst = {}, {}, {}
  if not InOurGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then return end
  local ok, n = pcall(GetNumGuildMembers)
  if not ok or type(n) ~= "number" then return end
  local firstCount = {}
  for i = 1, n do
    local r = { pcall(GetGuildRosterInfo, i) }
    local name, rankName, rankIndex, guid = r[2], r[3], r[4], r[18]
    if r[1] and Plain(name, rankName, rankIndex) and type(name) == "string" and type(rankIndex) == "number" then
      local entry = { name = name, rankName = rankName, rankIndex = rankIndex }
      if type(guid) == "string" and not issecret(guid) then rosterByGUID[guid] = entry end
      local lower = name:lower():gsub("%-", " ")
      rosterByName[lower] = entry
      local first = lower:match("^(%S+)")
      if first then
        firstCount[first] = (firstCount[first] or 0) + 1
        rosterByFirst[first] = entry
      end
    end
  end
  for first, count in pairs(firstCount) do
    if count > 1 then rosterByFirst[first] = nil end -- two people share a first name: don't guess
  end
end

local function RosterMatch(unit)
  if next(rosterByName) == nil then return nil end
  local okG, guid = pcall(UnitGUID, unit)
  local guidKnown = okG and type(guid) == "string" and not issecret(guid)
  if guidKnown and rosterByGUID[guid] then return rosterByGUID[guid], "guild roster" end
  -- A readable GUID that isn't in our roster (when the roster has GUIDs) means not one of us.
  if guidKnown and next(rosterByGUID) ~= nil then return nil end
  local okN, name, surname = pcall(UnitFullName, unit)
  if not okN or type(name) ~= "string" or issecret(name) then
    okN, name = pcall(UnitName, unit)
    surname = nil
  end
  if not okN or type(name) ~= "string" or issecret(name) then return nil end
  local lower = name:lower():gsub("%-", " ")
  if rosterByName[lower] then return rosterByName[lower], "guild roster (name)" end
  if type(surname) == "string" and not issecret(surname) and surname ~= "" then
    local full = (lower .. " " .. surname:lower())
    if rosterByName[full] then return rosterByName[full], "guild roster (name)" end
    return nil -- we know their full name and it isn't ours: don't fall back to first names
  end
  local first = lower:match("^(%S+)")
  if first and rosterByFirst[first] then return rosterByFirst[first], "guild roster (first name)" end
  return nil
end

-- Diagnosis ------------------------------------------------------------------------------
-- Written into MidnightRidersDragonsDB.diag at logout and /reload (and on /mrdragon), so what the
-- client reported can be read from the SavedVariables file without anyone copying chat.
local function Safe(v)
  if v == nil then return nil end
  if issecret(v) then return "<secret>" end
  local t = type(v)
  if t == "string" or t == "number" or t == "boolean" then return v end
  return "<" .. t .. ">"
end

local RankOf, Yes -- defined below

-- What the client said about each player we looked at this session (target, focus, party), by name.
local probes = {}
local function Probe(unit)
  local p = { unit = unit }
  local function grab(key, fn, ...) local r = { pcall(fn, ...) } if r[1] then p[key] = Safe(r[2]) return r end p[key] = "error" end
  grab("exists", UnitExists, unit)
  grab("isPlayer", UnitIsPlayer, unit)
  grab("guid", UnitGUID, unit)
  local n = grab("name", UnitFullName, unit)
  if n then p.surname = Safe(n[3]) end
  local gi = { pcall(GetGuildInfo, unit) }
  if gi[1] then
    p.giGuild, p.giRank, p.giIndex = Safe(gi[2]), Safe(gi[3]), Safe(gi[4])
    if gi[2] == nil then p.giGuild = "nil" end
  else
    p.giGuild = "error: " .. tostring(gi[2])
  end
  local style, guild, rankName, rankIndex, how = RankOf(unit)
  p.dragon, p.decidedGuild, p.decidedRank, p.decidedIndex, p.how = style or "none", guild, rankName, rankIndex, how
  return p
end

local function Remember(unit)
  if not db or not db.debug or not Yes or not Yes(UnitExists, unit) then return end
  local ok, p = pcall(Probe, unit)
  if ok and p then
    local key = ((type(p.name) == "string" and p.name ~= "<secret>") and p.name or unit) .. "|" .. tostring(p.guid)
    probes[key] = p
  end
end

local function SaveDiagnosis()
  if not db then return end
  local d = { when = time and time() or nil, guild = nil, ranks = {}, roster = {}, party = {}, notes = {} }
  local function note(s) d.notes[#d.notes + 1] = s end
  local okG, g, rn, ri = pcall(GetGuildInfo, "player")
  if okG then d.guild, d.myRankName, d.myRankIndex = Safe(g), Safe(rn), Safe(ri) else note("GetGuildInfo(player) failed") end
  d.officerSettingsRead = officerByRank ~= nil
  d.hasGetRankFlags = (C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags) ~= nil
  local okN, n = pcall(GuildControlGetNumRanks)
  d.numRanks = okN and Safe(n) or "failed"
  if okN and type(n) == "number" then
    for order = 1, n do
      local r = { order = order }
      local okName, name = pcall(GuildControlGetRankName, order)
      r.name = okName and Safe(name) or "failed"
      local okF, flags = pcall(C_GuildInfo.GuildControlGetRankFlags, order)
      if not okF then
        r.flags = "error: " .. tostring(flags)
      elseif type(flags) ~= "table" then
        r.flags = "returned " .. type(flags)
      else
        local on = {}
        for k, v in pairs(flags) do
          if v == true and type(k) == "number" then on[#on + 1] = k end
        end
        table.sort(on)
        r.flagsOn = table.concat(on, ",")
        r.flag22 = Safe(flags[OFFICER_FLAG])
      end
      d.ranks[#d.ranks + 1] = r
    end
  end
  local okM, members = pcall(GetNumGuildMembers)
  d.numMembers = okM and Safe(members) or "failed"
  if okM and type(members) == "number" then
    for i = 1, math.min(members, 200) do
      local okR, name, rankName, rankIndex = pcall(GetGuildRosterInfo, i)
      if okR then d.roster[#d.roster + 1] = { name = Safe(name), rank = Safe(rankName), rankIndex = Safe(rankIndex) } end
    end
  end
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) then
      local okGI, pg, prn, pri = pcall(GetGuildInfo, unit)
      local style, _, _, _, how = RankOf(unit)
      d.party[#d.party + 1] = { unit = unit, name = Safe((UnitName(unit))), guild = okGI and Safe(pg) or "failed",
        rank = okGI and Safe(prn) or nil, rankIndex = okGI and Safe(pri) or nil, dragon = style or "none", how = how }
    end
  end
  local frames = 0
  local pool = PartyFrame and PartyFrame.PartyMemberFramePool
  if pool and pool.EnumerateActive then
    pcall(function() for fr in pool:EnumerateActive() do
      frames = frames + 1
      d.party[#d.party + 1] = { frame = frames, unit = Safe(fr.unit), shown = fr:IsShown(), hasPortrait = fr.Portrait ~= nil,
        dragonShown = fr.mrDragon and fr.mrDragon:IsShown() or false }
    end end)
  else
    note("no PartyFrame.PartyMemberFramePool")
  end
  d.partyFrames = frames
  d.seen = {}
  for _, p in pairs(probes) do d.seen[#d.seen + 1] = p end
  d.rosterGUIDs = 0
  for _ in pairs(rosterByGUID) do d.rosterGUIDs = d.rosterGUIDs + 1 end
  db.diag = d
end

local function OfficerByNameOrNumber(rIndex, rName)
  if OFFICER_RANKS[rIndex] then return true end
  if type(rName) == "string" then
    local lower = rName:lower()
    for _, word in ipairs(OFFICER_WORDS) do
      if lower:find(word, 1, true) then return true end
    end
  end
  return false
end

-- "gm", "officer" or nil, plus the guild, rank name, rank number and how we decided, for /mrdragon.
-- Which dragon a rank in our guild gets.
local function Decide(rIndex, rName)
  if rIndex == 0 then return "gm", "guild master" end
  local settings = officerByRank and officerByRank[rIndex]
  if settings ~= nil then return settings and "officer" or nil, "guild rank settings" end
  if OfficerByNameOrNumber(rIndex, rName) then return "officer", "rank name or number" end
  return nil, "rank name or number"
end

-- A yes/no from the client that may be secret; a secret answer counts as yes.
Yes = function(fn, unit)
  local ok, v = pcall(fn, unit)
  if not ok then return false end
  if issecret(v) then return true end
  return v and true or false
end

RankOf = function(unit)
  local ok, style, guild, rankName, rankIndex, how = pcall(function()
    if not Yes(UnitExists, unit) or not Yes(UnitIsPlayer, unit) then return nil end
    -- 1. Our own guild roster, when we're in the guild.
    local entry, source = RosterMatch(unit)
    if entry then
      local s, why = Decide(entry.rankIndex, entry.rankName)
      return s, GUILD, entry.rankName, entry.rankIndex, source .. ", " .. why
    end
    -- 2. What the client says about the unit (works for players outside the guild too).
    local g, rName, rIndex = GetGuildInfo(unit)
    if g == nil or not Plain(g, rName, rIndex) then return nil end
    if g ~= GUILD then return nil, g, rName, rIndex end
    local s, why = Decide(rIndex, rName)
    return s, g, rName, rIndex, why
  end)
  if not ok then return nil end
  return style, guild, rankName, rankIndex, how
end

-- Drawing ----------------------------------------------------------------------------

local function TargetOverlay(frame)
  local container = frame and frame.TargetFrameContainer
  if not container then return nil end
  local tex = container:CreateTexture(nil, "ARTWORK", nil, 2)
  tex:Hide()
  tex.container = container
  return tex
end

local function PlayerOverlay()
  local container = PlayerFrame and PlayerFrame.PlayerFrameContainer
  local portrait = container and container.PlayerPortrait
  if not portrait then return nil end
  local tex = container:CreateTexture(nil, "ARTWORK", nil, 2)
  tex:Hide()
  tex.portrait = portrait
  return tex
end

local function ShowOnTarget(tex, style)
  tex:SetAtlas(style.atlas, true)
  tex:ClearAllPoints()
  tex:SetPoint("TOPRIGHT", tex.container, "TOPRIGHT", style.x, style.y)
  tex:Show()
end

-- The target art faces right; player and party portraits are on the left, so flip it and mirror the
-- offset. scale shrinks it for smaller portraits (party frames: 37 px against the target's 58 px).
local function ShowMirrored(tex, style, scale, nudgeX, nudgeY)
  local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(style.atlas)
  local file = info and (info.file or info.filename)
  if file then
    tex:SetTexture(file)
    tex:SetSize(info.width * scale, info.height * scale)
    tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
  else
    tex:SetAtlas(style.atlas, true) -- unflipped, but still a dragon
  end
  local dx = -(style.x - TARGET_PORTRAIT_X) * scale + (nudgeX or 0)
  local dy = (style.y - TARGET_PORTRAIT_Y) * scale + (nudgeY or 0)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", tex.portrait, "TOPLEFT", dx, dy)
  tex:Show()
end

local function ShowOnPlayer(tex, style)
  ShowMirrored(tex, style, 1, db.nudgeX, db.nudgeY)
end

local function Update(key)
  local tex = overlays[key]
  if not tex then return end
  local unit = key
  local style
  if db.enabled and db[key] then
    local rank = RankOf(unit)
    if key == "player" and db.preview then rank = db.preview end
    style = rank and STYLES[rank]
  end
  if key ~= "player" then Remember(unit) end
  if key == "player" and PlayerFrame and PlayerFrame.state == "vehicle" then style = nil end
  if not style then tex:Hide() return end
  if key == "player" then ShowOnPlayer(tex, style) else ShowOnTarget(tex, style) end
end

-- Party frames ------------------------------------------------------------------------
-- Blizzard's party frames come from a pool (PartyFrame.PartyMemberFramePool); each member frame has a
-- 37 px round Portrait. Each frame gets its own overlay the first time we see it.
local PARTY_SCALE = 37 / 58

local function PartyFrames()
  local list = {}
  local pool = PartyFrame and PartyFrame.PartyMemberFramePool
  if pool and pool.EnumerateActive then
    pcall(function() for frame in pool:EnumerateActive() do list[#list + 1] = frame end end)
  else
    for i = 1, 4 do
      local frame = PartyFrame and PartyFrame["MemberFrame" .. i]
      if frame then list[#list + 1] = frame end
    end
  end
  return list
end

local function UpdateParty()
  for _, frame in ipairs(PartyFrames()) do
    pcall(function()
      local tex = frame.mrDragon
      if not tex then
        if not frame.Portrait then return end
        tex = frame:CreateTexture(nil, "OVERLAY", nil, -8)
        tex.portrait = frame.Portrait
        frame.mrDragon = tex
      end
      local unit = (frame.GetUnit and frame:GetUnit()) or frame.unit
      if unit and frame:IsShown() then Remember(unit) end
      local rank = db.enabled and db.party and unit and frame:IsShown() and RankOf(unit)
      local style = rank and STYLES[rank]
      if style then ShowMirrored(tex, style, PARTY_SCALE) else tex:Hide() end
    end)
  end
end

local function UpdateAll()
  for key in pairs(overlays) do Update(key) end
  UpdateParty()
end

-- Guild info for a player you just targeted can arrive a moment late; look again shortly after.
local function UpdateSoon(key)
  Update(key)
  C_Timer.After(0.4, function() Update(key) end)
  C_Timer.After(1.5, function() Update(key) end)
end

-- Events -------------------------------------------------------------------------------

local f = CreateFrame("Frame")

local function SafeRegister(event)
  pcall(f.RegisterEvent, f, event)
end

local function Setup()
  overlays.player = PlayerOverlay()
  overlays.target = TargetOverlay(TargetFrame)
  overlays.focus = TargetOverlay(FocusFrame)
  if type(PlayerFrame_UpdateArt) == "function" then
    hooksecurefunc("PlayerFrame_UpdateArt", function() Update("player") end)
  end
  if PartyFrame then
    for _, method in ipairs({ "InitializePartyMemberFrames", "UpdateMemberFrames" }) do
      if type(PartyFrame[method]) == "function" then
        hooksecurefunc(PartyFrame, method, function() UpdateParty() end)
      end
    end
  end
  UpdateAll()
end

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    if type(MidnightRidersDragonsDB) ~= "table" then MidnightRidersDragonsDB = {} end
    db = MidnightRidersDragonsDB
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then db[k] = v end
    end
    db.preview = nil -- previews never survive a reload
  elseif event == "PLAYER_LOGIN" then
    LoadOfficerRanks()
    LoadRoster()
    Setup()
    -- Ask the server for the roster so rank settings arrive; GUILD_ROSTER_UPDATE follows.
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    UpdateSoon("target")
  elseif event == "PLAYER_FOCUS_CHANGED" then
    UpdateSoon("focus")
  elseif event == "UNIT_NAME_UPDATE" then
    if arg1 == "target" or arg1 == "focus" or arg1 == "player" then Update(arg1) end
    if type(arg1) == "string" and arg1:find("^party") then UpdateParty() end
  elseif event == "PLAYER_LOGOUT" then
    -- Fires just before SavedVariables are written (logout and /reload). Only with /mrdragon debug on;
    -- otherwise any old diagnosis is dropped so nobody keeps a copy of the roster by accident.
    if db.debug then pcall(SaveDiagnosis) else db.diag = nil end
  elseif event == "GROUP_ROSTER_UPDATE" then
    UpdateParty()
    C_Timer.After(0.5, UpdateParty)
    C_Timer.After(2, UpdateParty)
  else -- guild changed, ranks changed, roster arrived, loading screen
    LoadOfficerRanks()
    LoadRoster()
    UpdateAll()
  end
end)

for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
                         "PLAYER_FOCUS_CHANGED", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "GUILD_RANKS_UPDATE",
                         "UNIT_NAME_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_LOGOUT" }) do
  SafeRegister(event)
end

-- /mrdragon ------------------------------------------------------------------------------

local function Describe(unit, label)
  if not UnitExists(unit) then return end
  local style, guild, rankName, rankIndex, how = RankOf(unit)
  local who = (UnitName(unit))
  if issecret(who) then who = label end
  local where = guild and string.format("<%s>, rank %s \"%s\"", guild, tostring(rankIndex), tostring(rankName or "?"))
    or "no guild we can see"
  local verdict = style and (STYLES[style].label .. " dragon") or "no dragon"
  print(string.format("  %s: %s — %s (%s%s)", label, tostring(who), verdict, where, how and (", by " .. how) or ""))
end

local function ListRanks()
  if not InOurGuild() then
    Print("you need to be in <" .. GUILD .. "> to list its ranks.")
    return
  end
  LoadOfficerRanks()
  local ok, n = pcall(GuildControlGetNumRanks)
  if not ok or type(n) ~= "number" then Print("the game didn't give us the rank list yet; try again in a moment.") return end
  Print("<" .. GUILD .. "> ranks" .. (officerByRank and " (officer from the guild's rank settings)" or
    " (rank settings not readable here, so going by rank name or number)") .. ":")
  for order = 1, n do
    local i = order - 1
    local okName, name = pcall(GuildControlGetRankName, order)
    local dragon
    if i == 0 then dragon = "gold"
    elseif officerByRank and officerByRank[i] ~= nil then dragon = officerByRank[i] and "silver" or "none"
    else dragon = OfficerByNameOrNumber(i, okName and name) and "silver" or "none" end
    print(string.format("  %d. %s — %s", i, tostring(okName and name or "?"), dragon))
  end
end

SLASH_MIDNIGHTRIDERSDRAGONS1 = "/mrdragon"
SLASH_MIDNIGHTRIDERSDRAGONS2 = "/mrdragons"
SlashCmdList.MIDNIGHTRIDERSDRAGONS = function(msg)
  local cmd, a, b = strtrim(msg or ""):lower():match("^(%S*)%s*(%S*)%s*(%S*)")
  if cmd == "on" or cmd == "off" then
    db.enabled = (cmd == "on")
    UpdateAll()
    Print(db.enabled and "dragons on." or "dragons off.")
  elseif cmd == "player" or cmd == "target" or cmd == "focus" or cmd == "party" then
    db[cmd] = not db[cmd]
    UpdateAll()
    Print(cmd .. (cmd == "party" and " frames " or " frame ") .. (db[cmd] and "on." or "off."))
  elseif cmd == "debug" then
    db.debug = not db.debug
    Print(db.debug and "debug on: what the game reports is saved to the addon's settings file at the next /reload."
      or "debug off.")
  elseif cmd == "ranks" then
    ListRanks()
  elseif cmd == "test" then
    if a == "gold" or a == "gm" then db.preview = "gm"
    elseif a == "silver" or a == "officer" then db.preview = "officer"
    else db.preview = nil end
    Update("player")
    Print(db.preview and ("showing the " .. STYLES[db.preview].label .. " dragon on your frame. /mrdragon test off to stop.")
      or "preview off.")
  elseif cmd == "nudge" then
    local x, y = tonumber(a), tonumber(b)
    if x and y then
      db.nudgeX, db.nudgeY = db.nudgeX + x, db.nudgeY + y
      Update("player")
      Print(string.format("player dragon moved to %d, %d. /mrdragon nudge reset to undo.", db.nudgeX, db.nudgeY))
    elseif a == "reset" then
      db.nudgeX, db.nudgeY = 0, 0
      Update("player")
      Print("player dragon back in its usual spot.")
    else
      Print("example: /mrdragon nudge 2 -1 (moves your own dragon right 2 and down 1)")
    end
  else
    Print(string.format("gold for the <%s> guild master, silver for officers. Dragons are %s.", GUILD,
      db.enabled and "on" or "off"))
    if db.debug then pcall(SaveDiagnosis) end
    Describe("player", "you")
    Describe("target", "target")
    Describe("focus", "focus")
    for i = 1, 4 do Describe("party" .. i, "party " .. i) end
    print("  /mrdragon ranks — every guild rank and its dragon")
    print("  /mrdragon on | off — all dragons")
    print("  /mrdragon player | target | focus | party — one kind of frame on or off")
    print("  /mrdragon test gold | silver | off — preview on your own frame")
    print("  /mrdragon nudge 2 -1 — move your own dragon (or nudge reset)")
  end
end
