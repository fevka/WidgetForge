local addonName, addonTable = ...

if not _G.WidgetForge then _G.WidgetForge = {} end
_G.WidgetForge.MoveWidget = _G.WidgetForge.MoveWidget or {}

local MoveWidget = _G.WidgetForge.MoveWidget
addonTable.MoveWidget = MoveWidget

MoveWidget.Instances = MoveWidget.Instances or {}
MoveWidget.ManagedFrames = MoveWidget.ManagedFrames or {}
MoveWidget.HookedTargets = MoveWidget.HookedTargets or {}
MoveWidget.HookedFrames = MoveWidget.HookedFrames or {}

local EXTRA_PANEL_NAMES = {
    "GameMenuFrame",
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "HelpFrame",
    "FriendsFrame",
    "PVEFrame",
    "EncounterJournal",
    "CollectionsJournal",
    "QuestLogFrame",
    "CharacterFrame",
    "SpellBookFrame",
    "AchievementFrame",
    "WorldMapFrame",
}

local function EnsureDB()
    if not WidgetForgeDB then WidgetForgeDB = {} end
    if type(WidgetForgeDB.panelMover) ~= "table" then
        WidgetForgeDB.panelMover = {}
    end
    if type(WidgetForgeDB.panelMover.positions) ~= "table" then
        WidgetForgeDB.panelMover.positions = {}
    end
    return WidgetForgeDB.panelMover
end

local function GetActiveConfig()
    local inst = MoveWidget.Instances[1]
    return inst and inst.config or nil
end

function MoveWidget:IsActive()
    return #self.Instances > 0
end

function MoveWidget:ShouldSave()
    local cfg = GetActiveConfig()
    if not cfg then return true end
    return cfg.savePosition ~= false
end

local function IsValidPanelFrame(frame)
    if not frame or type(frame) ~= "table" then return false end
    if not frame.IsObjectType or not frame:IsObjectType("Frame") then return false end
    if frame == UIParent then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end

    local name = frame.GetName and frame:GetName()
    if not name or name == "" then return false end
    if string.find(name, "WidgetForge", 1, true) then return false end
    if string.find(name, "DropDownList", 1, true) then return false end
    if string.find(name, "Tooltip", 1, true) then return false end
    return true
end

local function GetFrameKey(frame)
    return frame and frame.GetName and frame:GetName() or nil
end

function MoveWidget:SavePosition(frame)
    if not self:ShouldSave() then return end
    local key = GetFrameKey(frame)
    if not key then return end

    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point then return end
    local relName = (rel and rel.GetName and rel:GetName()) or "UIParent"

    local db = EnsureDB()
    db.positions[key] = {
        point = point,
        rel = relName,
        relPoint = relPoint or point,
        x = x or 0,
        y = y or 0,
    }
end

function MoveWidget:ApplyPosition(frame)
    if not self:ShouldSave() then return end
    local key = GetFrameKey(frame)
    if not key then return end

    local db = EnsureDB()
    local p = db.positions[key]
    if not p then return end

    local rel = _G[p.rel] or UIParent
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(p.point or "CENTER", rel, p.relPoint or p.point or "CENTER", p.x or 0, p.y or 0)
        if frame.SetUserPlaced then frame:SetUserPlaced(true) end
    end)
    if not ok then
        db.positions[key] = nil
    end
end

function MoveWidget:ApplyPositionDeferred(frame)
    if not frame then return end
    self:ApplyPosition(frame)
    C_Timer.After(0, function()
        if MoveWidget:IsActive() and frame and frame:IsShown() then
            MoveWidget:ApplyPosition(frame)
        end
    end)
    C_Timer.After(0.08, function()
        if MoveWidget:IsActive() and frame and frame:IsShown() then
            MoveWidget:ApplyPosition(frame)
        end
    end)
end

function MoveWidget:ResetPositions()
    local db = EnsureDB()
    local savedPositions = db.positions or {}
    db.positions = {}

    local function ResetFrame(frame)
        if not frame then return end

        local canMutate = not (frame.IsProtected and frame:IsProtected() and InCombatLockdown())
        if frame.SetUserPlaced and canMutate then
            pcall(function()
                if frame.IsMovable and not frame:IsMovable() and frame.SetMovable then
                    frame:SetMovable(true)
                end
                frame:SetUserPlaced(false)
            end)
        end
        if frame.SetToDefaultPosition and canMutate then
            pcall(frame.SetToDefaultPosition, frame)
        end
    end

    local seen = {}
    for frame in pairs(self.ManagedFrames) do
        seen[frame] = true
        ResetFrame(frame)
    end

    for frameName in pairs(savedPositions) do
        local frame = _G[frameName]
        if frame and not seen[frame] then
            ResetFrame(frame)
        end
    end

    if UpdateUIPanelPositions then
        pcall(UpdateUIPanelPositions)
    end
end

local function CreateTitleProxy(frame)
    if frame.WFMoveTitleProxy then
        return frame.WFMoveTitleProxy
    end
    local proxy = CreateFrame("Frame", nil, frame)
    proxy:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -2)
    proxy:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -2)
    proxy:SetHeight(28)
    proxy:SetFrameStrata(frame:GetFrameStrata())
    proxy:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    proxy:EnableMouse(true)
    frame.WFMoveTitleProxy = proxy
    return proxy
end

local function ResolveTitleTarget(frame)
    local frameName = frame.GetName and frame:GetName()
    if frameName == "WorldMapFrame" then
        return CreateTitleProxy(frame)
    end

    if frame.BorderFrame and frame.BorderFrame.TitleContainer and frame.BorderFrame.TitleContainer.IsObjectType and frame.BorderFrame.TitleContainer:IsObjectType("Frame") then
        return frame.BorderFrame.TitleContainer
    end

    if frame.TitleContainer and frame.TitleContainer.IsObjectType and frame.TitleContainer:IsObjectType("Frame") then
        return frame.TitleContainer
    end

    if frame.NineSlice and frame.NineSlice.TitleContainer and frame.NineSlice.TitleContainer.IsObjectType and frame.NineSlice.TitleContainer:IsObjectType("Frame") then
        return frame.NineSlice.TitleContainer
    end

    if frame.TitleText or frame.TitleBg then
        return CreateTitleProxy(frame)
    end

    return nil
end

function MoveWidget:HookFrame(frame)
    if not IsValidPanelFrame(frame) then return end
    if self.ManagedFrames[frame] then
        self:ApplyPositionDeferred(frame)
        return
    end

    local dragTarget = ResolveTitleTarget(frame)
    if not dragTarget then return end

    self.ManagedFrames[frame] = true

    if dragTarget.EnableMouse then dragTarget:EnableMouse(true) end

    if not self.HookedTargets[dragTarget] then
        self.HookedTargets[dragTarget] = frame
        dragTarget:RegisterForDrag("LeftButton")

        dragTarget:HookScript("OnDragStart", function(target)
            local owner = MoveWidget.HookedTargets[target]
            if not owner or not MoveWidget:IsActive() then return end
            if owner.IsProtected and owner:IsProtected() and InCombatLockdown() then return end
            local ok = pcall(function()
                owner:SetMovable(true)
                owner:StartMoving()
            end)
            if not ok then return end
            owner.__wfMoveActive = true
        end)

        dragTarget:HookScript("OnDragStop", function(target)
            local owner = MoveWidget.HookedTargets[target]
            if not owner or not owner.__wfMoveActive then return end
            owner.__wfMoveActive = nil
            pcall(owner.StopMovingOrSizing, owner)
            if owner.SetUserPlaced then owner:SetUserPlaced(true) end
            MoveWidget:SavePosition(owner)
            C_Timer.After(0.05, function()
                if owner then MoveWidget:SavePosition(owner) end
            end)
        end)

        dragTarget:HookScript("OnMouseUp", function(target)
            local owner = MoveWidget.HookedTargets[target]
            if not owner or not owner.__wfMoveActive then return end
            owner.__wfMoveActive = nil
            pcall(owner.StopMovingOrSizing, owner)
            if owner.SetUserPlaced then owner:SetUserPlaced(true) end
            MoveWidget:SavePosition(owner)
        end)
    end

    if frame.HookScript and not self.HookedFrames[frame] then
        self.HookedFrames[frame] = true
        frame:HookScript("OnShow", function(f)
            if MoveWidget:IsActive() then
                MoveWidget:ApplyPositionDeferred(f)
            end
        end)
    end

    self:ApplyPositionDeferred(frame)
end

function MoveWidget:ScanAndHookPanels()
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            local panel = _G[name]
            if panel then
                self:HookFrame(panel)
            end
        end
    end

    for _, name in ipairs(EXTRA_PANEL_NAMES) do
        local panel = _G[name]
        if panel then
            self:HookFrame(panel)
        end
    end
end

function MoveWidget:InstallHooks()
    if self.HooksInstalled then return end
    self.HooksInstalled = true

    hooksecurefunc("ShowUIPanel", function(frame)
        if type(frame) == "string" then frame = _G[frame] end
        if MoveWidget:IsActive() then
            MoveWidget:HookFrame(frame)
        end
    end)

    if UpdateUIPanelPositions then
        hooksecurefunc("UpdateUIPanelPositions", function()
            if not MoveWidget:IsActive() then return end
            for frame in pairs(MoveWidget.ManagedFrames) do
                if frame and frame:IsShown() then
                    MoveWidget:ApplyPositionDeferred(frame)
                end
            end
        end)
    end
end

function MoveWidget:SyncRuntime()
    if not self:IsActive() then return end
    self:InstallHooks()
    self:ScanAndHookPanels()
end

function MoveWidget:Load(parent, config)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f.config = config
    f.parentBar = parent

    if config.savePosition == nil then
        config.savePosition = true
    end

    if parent then
        parent:SetAlpha(0)
        parent:EnableMouse(false)
    end

    table.insert(self.Instances, f)
    self:SyncRuntime()

    function f:Unload()
        for i = #MoveWidget.Instances, 1, -1 do
            if MoveWidget.Instances[i] == self then
                table.remove(MoveWidget.Instances, i)
                break
            end
        end
        if self.parentBar then
            self.parentBar:SetAlpha(1)
            self.parentBar:EnableMouse(true)
            self.parentBar = nil
        end
    end

    return f
end
