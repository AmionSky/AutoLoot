-----------------------------------------------------------------------------------------------
-- Client Lua Script for AutoLoot
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Item"
 
-----------------------------------------------------------------------------------------------
-- AutoLoot Module Definition
-----------------------------------------------------------------------------------------------
local AutoLoot = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local tRuleNames = {
	[1] = "Need",
	[2] = "Greed",
	[3] = "Pass",
	[4] = "Ignore"
}

local tCategoryIds = {
	Survivalist = 110
}

local tDefault = {
	bEnabled = true,
	nNonNeedableRule = 2,

	tLootRules = {
		--tById = {},
		tByName = {},
		tByCategory = {
			[tCategoryIds.Survivalist] = 4
		}
	}
}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function AutoLoot:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here
	o.SortMode = 1
	o.bDocLoaded = false
	o.tSettings = self:tableClone(tDefault)
	o.tVersion = {
		nMajor = 1,
		nMinor = 0,
		nBuild = 0
	}

    return o
end

function AutoLoot:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "Auto Loot"
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- AutoLoot OnLoad
-----------------------------------------------------------------------------------------------
function AutoLoot:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("AutoLoot.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- AutoLoot OnSave and OnRestore
-----------------------------------------------------------------------------------------------
function AutoLoot:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return nil end
	return self.tSettings
end

function AutoLoot:OnRestore(eLevel, tData)
	if tData == nil then return end
	self.tSettings = self:tableMerge(self.tSettings, tData)
end

-----------------------------------------------------------------------------------------------
-- AutoLoot OnDocLoaded
-----------------------------------------------------------------------------------------------
function AutoLoot:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.bDocLoaded = true

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("LootRollUpdate", "OnLootUpdate", self)
		Apollo.RegisterSlashCommand("autoloot", "OnConfigure", self)
	end
end

-----------------------------------------------------------------------------------------------
-- AutoLoot Functions
-----------------------------------------------------------------------------------------------
function AutoLoot:OnLootUpdate()
	if not self.tSettings.bEnabled then return end

	local tLoot = GameLib.GetLootRolls()
	
	for _, tLootItem in ipairs(tLoot) do
		local nLootId = tLootItem.nLootId
		local tItem = tLootItem.itemDrop
		
		self:HandleItem(nLootId, tItem)
	end
end

function AutoLoot:HandleItem(nLootId, tItem)
	--If option set, greed non-needable items
	if self.tSettings.nNonNeedableRule ~= 4 and not GameLib.IsNeedRollAllowed(nLootId) then
		self:UseRule(self.tSettings.nNonNeedableRule, nLootId)
		return
	end

	--Check the LootRules
	if self:ByNameFindMatch(tItem:GetName(), nLootId) then return end

	--if self:UseRule(self.tSettings.tLootRules.tById[tItem:GetItemId()], nLootId) then return end
	if self:UseRule(self.tSettings.tLootRules.tByCategory[tItem:GetItemCategory()], nLootId) then return end
end

function AutoLoot:ByNameFindMatch(strItemName, nLootId)
	local nFoundRule = nil
	local bPriority = false

	for k,v in pairs(self.tSettings.tLootRules.tByName) do
		if not bPriority or v.bPriority then
			if string.find(strItemName, k) ~= nil then
				bPriority = v.bPriority
				nFoundRule = v.nRule
			end
		end
	end

	if nFoundRule == nil then return false end

	self:UseRule(nFoundRule, nLootId)
	return true
end

function AutoLoot:UseRule(nRule, nLootId)
	if nRule == 1 then
		-- Need
		GameLib.RollOnLoot(nLootId, true)
		return true
	elseif nRule == 2 then
		-- Greed
		GameLib.RollOnLoot(nLootId, false)
		return true
	elseif nRule == 3 then
		-- Pass
		GameLib.PassOnLoot(nLootId)
		return true
	elseif nRule == 4 then
		-- Ignore
		return true
	else
		-- Incorrect
		return false
	end
end

-----------------------------------------------------------------------------------------------
-- AutoLoot Lib
-----------------------------------------------------------------------------------------------
function AutoLoot:tableMerge(t1, t2)
    for k,v in pairs(t2) do
    	if type(v) == "table" then
    		if type(t1[k] or false) == "table" then
    			self:tableMerge(t1[k] or {}, t2[k] or {})
    		else
    			t1[k] = v
    		end
    	else
    		t1[k] = v
    	end
    end
    return t1
end

function AutoLoot:tableClone(t)
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = self:tableClone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

-----------------------------------------------------------------------------------------------
-- AutoLootForm Functions
-----------------------------------------------------------------------------------------------
function AutoLoot:OnConfigure()
	if not self.bDocLoaded then return end

	if self.wndMain == nil then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "AutoLootForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

		local tVer = self.tVersion
		self.wndMain:FindChild("Version"):SetText(string.format("v%d.%d.%d", tVer.nMajor, tVer.nMinor, tVer.nBuild))

		self.wndMain:Show(false, true)
	end

	self.wndMain:Show(true, false)

	self:LoadSettings()
end

function AutoLoot:LoadSettings()
	self:RuleListClear()

	self.wndListRuleChoices = nil

	self.wndMain:FindChild("btnName"):SetCheck(self.SortMode == 1)
	self.wndMain:FindChild("btnRule"):SetCheck(self.SortMode == 2)
	self.wndMain:FindChild("btnPriority"):SetCheck(self.SortMode == 3)
	self.wndMain:FindChild("ButtonEnabled"):SetCheck(self.tSettings.bEnabled)

	self:SetupRuleButton(self.wndMain:FindChild("AddRule"), 2)
	self:SetupRuleButton(self.wndMain:FindChild("SelectRuleNonNeed"), self.tSettings.nNonNeedableRule)
	self:SetupRuleButton(self.wndMain:FindChild("SelectRuleSurvivalist"), self.tSettings.tLootRules.tByCategory[tCategoryIds.Survivalist])

	self:RefreshNameList()
end

function AutoLoot:SetupRuleButton(btn, nRule)
	btn:SetCheck(false)
	self:SetRuleButton(btn, nRule)
end

function AutoLoot:RefreshNameList()
	local wndList = self.wndMain:FindChild("RuleList")

	wndList:DestroyChildren()
	
	for k,v in pairs(self.tSettings.tLootRules.tByName) do
		local wndNewEntry = Apollo.LoadForm(self.xmlDoc, "ListEntry", wndList, self)

		wndNewEntry:FindChild("Name"):SetText(k)
		wndNewEntry:FindChild("Priority"):SetCheck(v.bPriority)

		self:SetRuleButton(wndNewEntry:FindChild("Rule"), v.nRule)
	end

	self:SortEntries(wndList)
end

-- Sort Start

function AutoLoot:SortEntries(wndList)
	if wndList == nil then return end

	if self.SortMode == 1 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByName)
	elseif self.SortMode == -1 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByNameBack)
	elseif self.SortMode == 2 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByRule)
	elseif self.SortMode == -2 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByRuleBack)
	elseif self.SortMode == 3 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByPriority)
	elseif self.SortMode == -3 then
		wndList:ArrangeChildrenVert(0, AutoLoot.SortByPriorityBack)
	end
end

function AutoLoot.SortByName(a,b)
	return a:FindChild("Name"):GetText() <= b:FindChild("Name"):GetText()
end

function AutoLoot.SortByNameBack(a,b)
	return not AutoLoot.SortByName(a,b)
end

function AutoLoot.SortByRule(a,b)
	local aRule = a:FindChild("Rule"):GetData()
	local bRule = b:FindChild("Rule"):GetData()

	if aRule == bRule then
		return AutoLoot.SortByName(a,b)
	else
		return (aRule < bRule)
	end
end

function AutoLoot.SortByRuleBack(a,b)
	return not AutoLoot.SortByRule(a,b)
end

function AutoLoot.SortByPriority(a,b)
	local aPriority = a:FindChild("Priority"):IsChecked()
	local bPriority = b:FindChild("Priority"):IsChecked()

	if aPriority == bPriority then
		return AutoLoot.SortByName(a,b)
	else
		return aPriority
	end
end

function AutoLoot.SortByPriorityBack(a,b)
	return not AutoLoot.SortByPriority(a,b)
end

-- Sort End

function AutoLoot:OnClose()
	self.wndMain:Close()
end

function AutoLoot:OnClosed()
	self.wndMain:FindChild("RuleList"):DestroyChildren()

	self:RuleListClear()
end

function AutoLoot:OnMove()
	self:RuleListClear()
end

function AutoLoot:OnResetSettings()
	self.tSettings = self:tableClone(tDefault)
	self:LoadSettings()
end

function AutoLoot:ButtonEnabled(wndHandler, wndControl)
	self.tSettings.bEnabled = wndControl:IsChecked()
end

-- Header

function AutoLoot:OnHeaderButton(wndHandler, wndControl)
	local nSortMode = wndHandler:GetContentId()

	if self.SortMode == nSortMode then
		self.SortMode = -nSortMode
	else
		self.SortMode = nSortMode
	end

	self:SortEntries(self.wndMain:FindChild("RuleList"))
end

-- List

function AutoLoot:OnListPriority(wndHandler, wndControl)
	local strName = wndControl:GetParent():FindChild("Name"):GetText()
	self.tSettings.tLootRules.tByName[strName].bPriority = wndControl:IsChecked()
end

function AutoLoot:OnRemoveEntry(wndHandler, wndControl)
	local wndEntry = wndControl:GetParent()

	self.tSettings.tLootRules.tByName[wndEntry:FindChild("Name"):GetText()] = nil
	wndEntry:Destroy()

	self:SortEntries(self.wndMain:FindChild("RuleList"))
end

-- Rule Select

function AutoLoot:OnRuleSelectUncheck(wndHandler, wndControl)
	self:RuleListClear()
end

function AutoLoot:OnRuleSelectCheck(wndHandler, wndControl)
	self:RuleListClear()

	local wndChoices = Apollo.LoadForm(self.xmlDoc, "RuleChoiceContainer", nil, self)

	--Set Position
	wndChoices:SetData(wndControl)

	local nPosX, nPosY = wndControl:GetPos()
	local wndParents = wndControl:GetParent()

	while wndParents do
		local nPosX2, nPosY2 = wndParents:GetPos()
		nPosX = nPosX + nPosX2
		nPosY = nPosY + nPosY2
		wndParents = wndParents:GetParent()
	end

	local nChoicesWidth = wndChoices:GetWidth()
	local nChoicesHeight = wndChoices:GetHeight()
	local nButtonWidth = wndControl:GetWidth()
	local nButtonHeight = wndControl:GetHeight()
	
	wndChoices:Move(nPosX + nButtonWidth - 20, nPosY - nChoicesHeight / 2 + nButtonHeight / 2, nChoicesWidth, nChoicesHeight)

	local nCurrentData = wndControl:GetData()

	for k,v in ipairs(wndChoices:FindChild("Controls"):GetChildren()) do
		v:SetCheck(nCurrentData == v:GetContentId())
	end
	
	if wndControl:GetContentId() == 1 then
		wndChoices:FindChild("Controls"):FindChild("Need"):Enable(false)
	end

	wndChoices:Show(true, false)
end

function AutoLoot:OnRuleRadio(wndHandler, wndControl)
	local wndChoices = wndControl:GetParent():GetParent()
	local btnRule = wndChoices:GetData()
	local nRule = wndControl:GetContentId()

	wndChoices:Show(false)

	if not btnRule:IsValid() then return end

	self:SetRuleButton(btnRule, nRule)
	btnRule:SetCheck(false)

	local btnName = btnRule:GetName()

	if btnName == "Rule" then
		self.tSettings.tLootRules.tByName[btnRule:GetParent():FindChild("Name"):GetText()].nRule = nRule
	elseif btnName == "SelectRuleNonNeed" then
		self.tSettings.nNonNeedableRule = nRule
	elseif btnName == "SelectRuleSurvivalist" then
		self.tSettings.tLootRules.tByCategory[tCategoryIds.Survivalist] = nRule
	end	
end

function AutoLoot:SetRuleButton(btnRule, nRule)
	btnRule:SetText(tRuleNames[nRule])
	btnRule:SetData(nRule)
end

function AutoLoot:OnRuleListShow(wndHandler, wndControl)
	self.wndListRuleChoices = wndHandler
	wndHandler:ToFront()
end

function AutoLoot:OnRuleListHide(wndHandler, wndControl)
	wndControl:Close()
end

function AutoLoot:OnRuleListClosed(wndHandler, wndControl)
	self.wndListRuleChoices = nil

	if wndControl:GetData() ~= nil then
		wndControl:GetData():SetCheck(false)
	end
end

function AutoLoot:RuleListClear()
	if self.wndListRuleChoices ~= nil and self.wndListRuleChoices:IsValid() then
		self.wndListRuleChoices:Close()
	end
end

-- Add Window Functions

function AutoLoot:OnDragDropItem(wndHandler, wndControl, x, y, wndSource, strType, nItemSourceLoc)
	if strType ~= "DDBagItem" or wndHandler ~= wndControl then return end
	
	local itemDropped = Item.GetItemFromInventoryLoc(nItemSourceLoc)
	if not itemDropped then return end

	wndControl:SetText(itemDropped:GetName())
end

function AutoLoot:OnDragDropItemQuery(wndHandler, wndControl, x, y, wndSource, strType, nItemSourceLoc)
	if strType ~= "DDBagItem" or wndHandler ~= wndControl then return end

	local itemSource = Item.GetItemFromInventoryLoc(nItemSourceLoc)
	if not itemSource then return end

	return Apollo.DragDropQueryResult.Accept
end

function AutoLoot:OnAddConfirm(wndHandler, wndControl)
	local wndAddOptions = wndControl:GetParent()

	local strAddName = wndAddOptions:FindChild("AddName"):GetText()
	local nAddRule = wndAddOptions:FindChild("AddRule"):GetData()
	local bAddPriority = wndAddOptions:FindChild("AddPriority"):IsChecked()

	if strAddName == "" then return end

	self.tSettings.tLootRules.tByName[strAddName] = { bPriority = bAddPriority, nRule = nAddRule }
	
	wndAddOptions:FindChild("AddName"):SetText("")

	self:RefreshNameList()
end

-----------------------------------------------------------------------------------------------
-- AutoLoot Instance
-----------------------------------------------------------------------------------------------
local AutoLootInst = AutoLoot:new()
AutoLootInst:Init()
