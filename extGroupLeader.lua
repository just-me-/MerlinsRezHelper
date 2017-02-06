ZO_CreateStringId("SI_BINDING_NAME_SET_GROUP_LEADER", "Set Group Leader")

local LAM = LibStub('LibAddonMenu-1.0')
local FAKETAG = 'EXT_GROUPLEADER_FAKE'

local state = {
    Hidden = true,
    
    
    Angle = 0,
    Linear = 0,
    AbsoluteLinear = 0,
    DX = 0,
    DY = 0,
    
    Color = { R = 1, G = 1, B = 1 },
    Alpha = 0,
    Size = 0,
    
    Colors = nil,
    Mode = nil,
    
    Leader = nil,
    Player = nil,
    
    Settings = nil,
    
    Constants = {
        GameReticleSize = 58
    }
}

local defaultSettings = {
    Mode = 'Elastic Reticle Arrows',
    Colors = 'White Orange Red',
    MinAlpha = 0.3,
    MaxAlpha = 0.9,
    MinSize = 24,
    MaxSize = 32,
    MinDistance = 0,
    MaxDistance = 128,
    PvPOnly = true,
    Mimic = false,
    
    LeaderArrowSize = false,
    LeaderArrowDistance = false,
    LeaderArrowNumeric = false
}

-- **************** UTILS ****************

local function NormalizeAngle(c)
    if c > math.pi then return c - 2 * math.pi end
    if c < -math.pi then return c + 2 * math.pi end
    return c
end

-- **************** ENTITIES ****************

local function UpdatePlayerEntity(entity)
    if entity == nil then return end
    if entity.Tag == FAKETAG then return end
    
    entity.X, entity.Y, entity.Z = GetMapPlayerPosition(entity.Tag)
    entity.Zone = GetUnitZone(entity.Tag)
    entity.Name = GetUnitName(entity.Tag)
end

local function CheckLeader()
    if state.Leader and state.Leader.Custom then return end
    
	local newLeader = GetGroupLeaderUnitTag()
    if newLeader == nil or newLeader == '' then
        state.Leader = nil
    elseif state.Leader == nil or state.Leader.Tag ~= newLeader then
        state.Leader = {
            Tag = newLeader
        }
    end
end

-- **************** UI ****************

local function UpdateReticle()
    if state.Player == nil then return end
    
    if (state.Leader == nil) or 
       (state.Settings.PvPOnly and state.Player.Zone ~= 'Cyrodiil') or
       (state.Settings.Mimic and ZO_ReticleContainer:IsHidden() == true) or 
       (IsUnitGrouped('player') == false) then
        state.Hidden = true
    else
        state.Hidden = false
        
        state.DX = state.Player.X - state.Leader.X
        state.DY = state.Player.Y - state.Leader.Y
        state.D = math.sqrt((state.DX * state.DX) + (state.DY * state.DY))
        
        state.Angle = NormalizeAngle(state.Player.H - math.atan2( state.DX, state.DY ))
        state.Linear = state.Angle / math.pi
        state.AbsoluteLinear = math.abs(state.Linear)
        
        state.Alpha = state.Settings.MinAlpha + (state.Settings.MaxAlpha - state.Settings.MinAlpha) * state.AbsoluteLinear;
        
        if state.Settings.LeaderArrowSize then
            state.Size = state.Settings.MinSize + (state.Settings.MaxSize - state.Settings.MinSize) * (math.tanh(state.D * 40 - 1) + 1.0) / 2.0;
        else 
            state.Size = state.Settings.MinSize + (state.Settings.MaxSize - state.Settings.MinSize) * state.AbsoluteLinear;
        end
        if state.Settings.LeaderArrowDistance then
            state.Distance = state.Settings.MinDistance + (state.Settings.MaxDistance - state.Settings.MinDistance) * (math.tanh(state.D * 40 - 1) + 1.0) / 2.0;
        else
            state.Distance = state.Settings.MinDistance + (state.Settings.MaxDistance - state.Settings.MinDistance) * state.AbsoluteLinear;
        end
    end
    
    state.Colors:Update(state)
    state.Mode:Update(state)
end

-- **************** EVENTS ****************

function extGroupLeaderUpdate()
    if state.Player == nil then return end
    
    UpdatePlayerEntity(state.Player)
    local h = NormalizeAngle(GetPlayerCameraHeading())
    if h ~= nil then state.Player.H = h end
    
    CheckLeader()
    UpdatePlayerEntity(state.Leader)
    
    if state.Leader == nil or state.Leader.X == nil or state.Leader.Y == nil then state.Leader = nil end
    if state.Leader == nil or state.Leader.Name == state.Player.Name then state.Leader = nil end
    
    UpdateReticle()
end

local function FakeIt(text)
    state.Leader = {
        Tag = 'player'
    }
    UpdatePlayerEntity(state.Leader)
    state.Leader.Tag = FAKETAG
    state.Leader.Name = FAKETAG
    state.Leader.Custom = true
    
    d("Leader faked.")
end

function OnSetTargettedLeader()
    SetCustomLeader(GetUnitNameHighlightedByReticle())
end

-- Slash command for custom follow target ( /glset = set to default group leader - /glset <charname> = set to custom person )
function SetCustomLeader(text)
    if IsUnitGrouped('player') == false then 
        d("You must be in a group to set a follow target.")
        return
    end
    if text == "" then
        state.Leader.Custom = false
    else
        for xmemberid = 1, GetGroupSize(), 1 do
            if string.lower(text) == string.lower(GetUnitName(GetGroupUnitTagByIndex(xmemberid))) then
                d("Successfully set '" .. text .. "' as follow target.")
                state.Leader = {
                        Tag = GetGroupUnitTagByIndex(xmemberid)
                }
                UpdatePlayerEntity(state.Leader)
                state.Leader.Tag = GetGroupUnitTagByIndex(xmemberid)
                state.Leader.Name = GetUnitName(GetGroupUnitTagByIndex(xmember))
                state.Leader.Custom = true
            else
                --d("ZERO MATCH ON - ".. text .. " = " .. GetUnitName(GetGroupUnitTagByIndex(xmemberid))) 
            end
		end
	   if not state.Leader.Custom then
             d("Could not find anyone named '" .. text .. "' in your group.")
        end
    end
end

--Find out if your follow target has left the group and if so notify and set leader to nil
local function OnPlayerLeft(leftmemberName, reason, wasLocalPlayer)
    if IsUnitGrouped('player') == false then return end -- Ignore if you just left the group
    if state.Leader == nil then return end
    
    local doesCustomExist = false
    for xmemberid = 1, GetGroupSize() , 1 do
        if GetGroupUnitTagByIndex(xmemberid) == state.Leader.Tag then
            doesCustomExist = true
        end
    end
    if not doesCustomExist then
        d("Your follow target has left the group. Now following group leader.")
        state.Leader = nil
    end
end

local function InitializePlugin()
    state.Player = {
        Tag = 'player'
    }
end

-- **************** SETTINGS ****************

local function LoadSettings()
    extGroupLeaderSettings = extGroupLeaderSettings or {}
    state.Settings = EXT_GROUPLEADER.Extend(extGroupLeaderSettings, defaultSettings)
end

local function ChangeMode(value)
    state.Settings.Mode = value
    if state.Mode then state.Mode:Unit() end
    state.Mode = EXT_GROUPLEADER.Modes[value]
    state.Mode.Init()
end

local function ChangeColors(value)
    state.Settings.Colors = value
    if state.Colors then state.Colors:Unit() end
    state.Colors = EXT_GROUPLEADER.Colors[value]
    state.Colors.Init()
end

local function CreateSettingsMenu()
    local panelID = LAM:CreateControlPanel('extGroupLeader', 'extGroupLeader')
    
    LAM:AddHeader(panelID, 'extGroupLeaderHeader', '|cFFFF22Exterminatus|r Group Leader')

    -- DROPDOWN: Mode
    LAM:AddDropdown(panelID, 'extGroupLeaderMode', 'Mode', 'The style of the leader reticle.', 
        EXT_GROUPLEADER.Modes.Plugins,
        function () return state.Settings.Mode end,
        ChangeMode,
        false, '');
        
    -- DROPDOWN: Colors
    LAM:AddDropdown(panelID, 'extGroupLeaderColors', 'Colors', 'The color style of the leader reticle.',
        EXT_GROUPLEADER.Colors.Plugins,
        function () return state.Settings.Colors end,
        ChangeColors,
        false, '')
    
    -- DROPDOWN: Opacity
    LAM:AddSlider(panelID, 'extGroupLeaderMinOpacity', 'Targetted Opacity', 'The arrows will be this opaque (as a percentage) when you are facing the leader.', 0, 100, 1, 
            function() return state.Settings.MinAlpha * 100 end,
            function(value) state.Settings.MinAlpha = value / 100 end,
        false, '');
    LAM:AddSlider(panelID, 'extGroupLeaderMaxOpacity', 'Behind Opacity', 'The arrows will be this opaque (as a percentage) when the leader is directly behind you.', 0, 100, 1, 
            function() return state.Settings.MaxAlpha * 100 end,
            function(value) state.Settings.MaxAlpha = value / 100 end,
        false, '')
    
    -- DROPDOWN: Size
    LAM:AddSlider(panelID, 'extGroupLeaderMinSize', 'Targetted Size', 'The arrows will be this size when you are facing the leader.', 0, 64, 2, 
            function() return state.Settings.MinSize end,
            function(value) state.Settings.MinSize = value end,
        false, '');
    LAM:AddSlider(panelID, 'extGroupLeaderMaxSize', 'Behind Size', 'The arrows will be this size when the leader is directly behind you.', 0, 64, 2, 
            function() return state.Settings.MaxSize end,
            function(value) state.Settings.MaxSize = value end,
        false, '')
    
    -- DROPDOWN: Distance
    LAM:AddSlider(panelID, 'extGroupLeaderMinDistance', 'Targetted Distance', 'The arrows will be this distance from the reticle when you are facing the leader.', 0, 512, 1, 
            function() return state.Settings.MinDistance end,
            function(value) state.Settings.MinDistance = value end,
        false, '');
    LAM:AddSlider(panelID, 'extGroupLeaderMaxDistance', 'Behind Distance', 'The arrows will be this distance from the reticle when you are facing the leader.', 0, 512, 1, 
            function() return state.Settings.MaxDistance end,
            function(value) state.Settings.MaxDistance = value end,
        false, '')
    
    -- CHECKBOX: Only in Cyrodiil
    LAM:AddCheckbox(panelID, 'extGroupLeaderPvPOnly', 'Only in Cyrodiil', 'Disable the arrows in PvE areas.',
            function() return state.Settings.PvPOnly end,
            function() state.Settings.PvPOnly = not state.Settings.PvPOnly end,
        false, '')
    
    -- CHECKBOX: Mimic Reticle
    LAM:AddCheckbox(panelID, 'extGroupLeaderMimic', 'Mimic Reticle', 'Disable the arrows if the game reticle is not visible.',
            function() return state.Settings.Mimic end,
            function() state.Settings.Mimic = not state.Settings.Mimic end,
        false, '')
    
    LAM:AddDescription(panelID, 'extGroupLeaderDistance', '', '|cFFFF22Leader Distance')
    
    -- CHECKBOX: Leader Arrow Size
    LAM:AddCheckbox(panelID, 'extGroupLeaderArrowSize', 'Arrow Size', 'Uses the arrow size to represent the leader distance.',
            function() return state.Settings.LeaderArrowSize end,
            function() state.Settings.LeaderArrowSize = not state.Settings.LeaderArrowSize end,
        false, '')
    
    -- CHECKBOX: Leader Arrow Distance
    LAM:AddCheckbox(panelID, 'extGroupLeaderArrowDistance', 'Arrow Distance', 'Uses the arrow distance to represent the leader distance.',
            function() return state.Settings.LeaderArrowDistance end,
            function() state.Settings.LeaderArrowDistance = not state.Settings.LeaderArrowDistance end,
        false, '')
    
    -- DESCRIPTION: Shameless Plug :P
    LAM:AddDescription(panelID, 'extGroupLeaderAuthors', '|c22FF22[EXT]|r Mitazaki, |c22FF22[EXT]|r Zamalek', '|cFFFF22Contributors')
end

local function OnPluginLoaded(event, addon)
	if addon ~= "extGroupLeader" then return end
    
    LoadSettings()
    CreateSettingsMenu()
    
    ChangeMode(state.Settings.Mode)
    ChangeColors(state.Settings.Colors)
        
    InitializePlugin()
    
    SLASH_COMMANDS["/glfake"] = FakeIt
    SLASH_COMMANDS["/glset"] = SetCustomLeader
end

EVENT_MANAGER:RegisterForEvent("extGroupLeader", EVENT_ADD_ON_LOADED, OnPluginLoaded)
EVENT_MANAGER:RegisterForEvent("extGroupLeader", EVENT_GROUP_MEMBER_LEFT, OnPlayerLeft)
