-- @Author: Webster
-- @Date:   2015-12-04 20:17:03
-- @Last modified by:   Zhai Yiming
-- @Last modified time: 2016-11-18 10:46:37

local pairs, ipairs, select = pairs, ipairs, select
local GetClientPlayer, GetPlayer, GetNpc, GetDoodad, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, GetDoodad, IsPlayer
local PostThreadCall = PostThreadCall
local tinsert = table.insert
local mmax = math.max
local TARGET = TARGET
DBM_SA = {
	bAlert     = false,
	bOnlySelf  = true,
	fLifePer   = 0.3,
	fManaPer   = 0.1,
	nFont      = 203,
	bDrawColor = false,
}
JH.RegisterCustomData("DBM_SA")

local _L = JH.LoadLangPack
local UI_SCALED = 1
local JH_MARK_NAME = JH_MARK_NAME
local HANDLE
local CACHE = {
	[TARGET.DOODAD] = {},
	[TARGET.PLAYER] = {},
	[TARGET.NPC]    = {},
}
local SA = {}
SA.__index = SA
local SA_COLOR = {
	FONT = {
		["BUFF"]    = { 255, 128, 0   },
		["DEBUFF"]  = { 255, 0,   255 },
		["Life"]    = { 130, 255, 130 },
		["Mana"]    = { 255, 255, 128 },
		["NPC"]     = { 0,   255, 255 },
		["CASTING"] = { 150, 200, 255 },
		["DOODAD"]  = { 200, 200, 255 },
		["TIME"]    = { 128, 255, 255 },
	},
	ARROW = {
		["BUFF"]    = { 0,   255, 0   },
		["DEBUFF"]  = { 255, 0,   0   },
		["Life"]    = { 255, 0,   0   },
		["Mana"]    = { 0,   0,   255 },
		["NPC"]     = { 0,   128, 255 },
		["CASTING"] = { 255, 128, 0   },
		["DOODAD"]  = { 200, 200, 255 },
		["TIME"]    = { 255, 0,   0   },
	}
}
do
	local mt = { __index = function() return { 255, 128, 0 } end }
	setmetatable(SA_COLOR.FONT,  mt)
	setmetatable(SA_COLOR.ARROW, mt)
end

local BASE_SA_POINT_C = { 25, 25, 180 }
local BASE_SA_POINT = {
	{ 15, 0,  100 },
	{ 35, 0,  100 },
	{ 35, 25, 180 },
	{ 43, 25, 255 },
	{ 25, 50, 180 },
	{ 7,  25, 255 },
	{ 15, 25, 180 },
}

local BASE_WIDTH
local BASE_HEIGHT
local BASE_PEAK
local BASE_EDGE
local SA_POINT_C = {}
local SA_POINT = {}
local BASE_POINT_START
local function setUIScale()
	local dpi = Station.GetMaxUIScale()
	UI_SCALED = Station.GetUIScale()
	BASE_PEAK = -60 * dpi * 0.5
	BASE_WIDTH = 100 * dpi
	BASE_HEIGHT = 12 * dpi
	BASE_EDGE = dpi * 1.2
	BASE_POINT_START = 15 * dpi
	SA_POINT_C = {}
	SA_POINT = {}
	for k, v in ipairs(BASE_SA_POINT_C) do
		if k ~= 3 then
			SA_POINT_C[k] = v * dpi
		else
			SA_POINT_C[k] = v
		end
	end
	for k, v in ipairs(BASE_SA_POINT) do
		SA_POINT[k] = {}
		for kk, vv in ipairs(v) do
			if kk ~= 3 then
				SA_POINT[k][kk] = vv * dpi
			else
				SA_POINT[k][kk] = vv
			end
		end
	end
end


-- for i=1, 2 do FireUIEvent("JH_SA_CREATE", "TIME", GetClientPlayer().dwID, { col = { 255, 255, 255 }, txt = "test" })end
local function CreateScreenArrow(szClass, dwID, tArgs)
	tArgs = tArgs or {}
	SA:ctor(szClass, dwID, tArgs)
end

local ScreenArrow = {
	tCache = {
		["Life"] = {},
		["Mana"] = {},
	}
}

function ScreenArrow.OnSort()
	local t = {}
	for k, v in pairs(HANDLE:GetAllItem(true)) do
		PostThreadCall(function(v, xScreen, yScreen)
			v.nIndex = yScreen or 0
		end, v, "Scene_GetCharacterTopScreenPos", v.dwID)
	    tinsert(t, { handle = v, index = v.nIndex or 0 })
	end
	table.sort(t, function(a, b) return a.index < b.index end)
	for i = #t, 1, -1 do
		if t[i].handle and t[i].handle:GetIndex() ~= i - 1 then
		t[i].handle:ExchangeIndex(i - 1)
		end
	end
end

function ScreenArrow.OnBreathe()
	local me = GetClientPlayer()
	if not me then return end
	local team = GetClientTeam()
	local tTeamMark = team.dwTeamID > 0 and team.GetTeamMark() or EMPTY_TABLE
	for dwType, tab in pairs(CACHE) do
		for dwID, v in pairs(tab) do
			local object, tInfo = select(2, ScreenArrow.GetObject(dwType, dwID))
			if object then
				local obj = ScreenArrow.GetAction(dwType, dwID)
				local fLifePer = obj.dwType == TARGET.DOODAD and 1 or tInfo.nCurrentLife / mmax(tInfo.nMaxLife, tInfo.nCurrentLife, 1)
				local fManaPer = obj.dwType == TARGET.DOODAD and 1 or tInfo.nCurrentMana / mmax(tInfo.nMaxMana, tInfo.nCurrentMana, 1)
				local szName
				if dwType == TARGET.DOODAD then
					szName = tInfo.szName
				else
					szName = JH.GetTemplateName(object)
				end
				szName = obj.szName or szName
				if tTeamMark[dwID] then
					szName = szName .. _L("[%s]", JH_MARK_NAME[tTeamMark[dwID]])
				end
				local txt = ""
				if obj.szClass == "BUFF" or obj.szClass == "DEBUFF" then
					local KBuff = JH.GetBuff(obj.dwBuffID, object) -- ֻ�ж�dwID ����������ͬʱ��ò�ͬlv
					if KBuff then
						local nSec = JH.GetEndTime(KBuff.GetEndTime())
						if KBuff.nStackNum > 1 then
							txt = string.format("%s(%d)_%s", obj.txt or JH.GetBuffName(KBuff.dwID, KBuff.nLevel), KBuff.nStackNum, JH.FormatTimeString(nSec, 1, true))
						else
							txt = string.format("%s_%s", obj.txt or JH.GetBuffName(KBuff.dwID, KBuff.nLevel), JH.FormatTimeString(nSec, 1, true))
						end
					else
						return obj:Free()
					end
				elseif obj.szClass == "Life" or obj.szClass == "Mana" then
					if object.nMoveState == MOVE_STATE.ON_DEATH then
						return obj:Free()
					end
					if obj.szClass == "Life" then
						if fLifePer > DBM_SA.fLifePer then
							return obj:Free()
						end
						txt = g_tStrings.STR_SKILL_H_LIFE_COST .. string.format("%d/%d", tInfo.nCurrentLife, tInfo.nMaxLife)
					elseif obj.szClass == "Mana" then
						if fManaPer > DBM_SA.fManaPer then
							return obj:Free()
						end
						txt = g_tStrings.STR_SKILL_H_MANA_COST .. string.format("%d/%d", tInfo.nCurrentMana, tInfo.nMaxMana)
					end
				elseif obj.szClass == "CASTING" then
					local nType, dwSkillID, dwSkillLevel, fCastPercent = object.GetSkillOTActionState()
					if nType == CHARACTER_OTACTION_TYPE.ACTION_SKILL_PREPARE
					or nType == CHARACTER_OTACTION_TYPE.ACTION_SKILL_CHANNEL then
						txt = obj.txt or JH.GetSkillName(dwSkillID, dwSkillLevel)
						fManaPer = fCastPercent
					else
						return obj:Free()
					end
				elseif obj.szClass == "NPC" or obj.szClass == "DOODAD" then
					txt = obj.txt or txt
				elseif obj.szClass == "TIME" then
					if (GetTime() - obj.nNow) / 1000 > 5 then
						return obj:Free()
					end
					txt = obj.txt or _L["Call Alert"]
				end
				if not obj.init then
					obj:DrawBackGround()
				end
				obj:DrawLifeBar(fLifePer, fManaPer):DrawText(txt, szName):DrowArrow()
			else
				for _, vv in pairs(v) do
					vv:Free()
				end
			end
		end
	end
end

function ScreenArrow.GetAction(dwType, dwID)
	local tab = CACHE[dwType][dwID]
	if #tab > 1 then
		for k, v in ipairs(CACHE[dwType][dwID]) do
			v:Hide()
		end
	end
	local obj = CACHE[dwType][dwID][#CACHE[dwType][dwID]]
	return obj:Show()
end

function ScreenArrow.GetObject(szClass, dwID)
	local dwType, object, tInfo
	if szClass == "DOODAD" or szClass == TARGET.DOODAD then
		dwType = TARGET.DOODAD
		object = GetDoodad(dwID)
	elseif IsPlayer(dwID) then
		dwType = TARGET.PLAYER
		local me = GetClientPlayer()
		if dwID == me.dwID then
			object = me
		elseif JH.IsParty(dwID) then
			object = GetPlayer(dwID)
			tInfo  = GetClientTeam().GetMemberInfo(dwID)
		else
			object = GetPlayer(dwID)
		end
	else
		dwType = TARGET.NPC
		object = GetNpc(dwID)
	end
	tInfo = tInfo and tInfo or object
	return dwType, object, tInfo
end

function ScreenArrow.RegisterFight()
	if arg0 and DBM_SA.bAlert then
		JH.BreatheCall("ScreenArrow_Fight", ScreenArrow.OnBreatheFight)
	else
		ScreenArrow.KillBreathe()
	end
end

function ScreenArrow.KillBreathe()
	JH.BreatheCall("ScreenArrow_Fight")
	ScreenArrow.tCache["Mana"] = {}
	ScreenArrow.tCache["Life"] = {}
end

function ScreenArrow.OnBreatheFight()
	local me = GetClientPlayer()
	if not me then return end
	if not me.bFightState then -- kill fix bug
		return ScreenArrow.KillBreathe()
	end
	local team = GetClientTeam()
	local list = {}
	if me.IsInParty() and not DBM_SA.bOnlySelf then
		list = team.GetTeamMemberList()
	else
		list[1] = me.dwID
	end
	for k, v in ipairs(list) do
		local p, info = select(2, ScreenArrow.GetObject(TARGET.PLAYER, v))
		if p and info then
			if p.nMoveState == MOVE_STATE.ON_DEATH then
				ScreenArrow.tCache["Mana"][v] = nil
				ScreenArrow.tCache["Life"][v] = nil
			else
				local fLifePer = info.nCurrentLife / mmax(info.nMaxLife, info.nCurrentLife, 1)
				local fManaPer = info.nCurrentMana / mmax(info.nMaxMana, info.nCurrentMana, 1)
				if fLifePer < DBM_SA.fLifePer then
					if not ScreenArrow.tCache["Life"][v] then
						ScreenArrow.tCache["Life"][v] = true
						CreateScreenArrow("Life", v)
					end
				else
					ScreenArrow.tCache["Life"][v] = nil
				end
				if fManaPer < DBM_SA.fManaPer and (p.dwForceID < 7 or p.dwForceID == 22) then
					if not ScreenArrow.tCache["Mana"][v] then
						ScreenArrow.tCache["Mana"][v] = true
						CreateScreenArrow("Mana", v)
					end
				else
					ScreenArrow.tCache["Mana"][v] = nil
				end
			end
		end
	end
end

function SA:ctor(szClass, dwID, tArgs)
	local dwType, object = ScreenArrow.GetObject(szClass, dwID)
	if not JH.bDebugClient and not JH.IsInDungeon(true) then
		if dwType == TARGET.NPC and object.bDialogFlag then
			return
		end
	end
	local oo = {}
	setmetatable(oo, self)
	local ui      = HANDLE:New()
	oo.szName   = tArgs.szName
	oo.txt      = tArgs.txt
	oo.col      = tArgs.col or SA_COLOR.ARROW[szClass]
	oo.dwBuffID = tArgs.dwID
	oo.szClass  = szClass

	oo.Arrow    = ui:Lookup(0)
	oo.Text     = ui:Lookup(1)
	oo.BGB      = ui:Lookup(2)
	oo.BGI      = ui:Lookup(3)
	oo.Life     = ui:Lookup(4)
	oo.Mana     = ui:Lookup(5)

	oo.ui       = ui
	oo.ui.dwID  = dwID
	oo.init     = false
	oo.bUp      = false
	oo.nTop     = 10
	oo.dwID     = dwID
	oo.dwType   = dwType
	if szClass == "TIME" then
		oo.nNow = GetTime()
	end
	oo.Text:SetTriangleFan(GEOMETRY_TYPE.TEXT)
	for k, v in pairs({ oo.BGB, oo.BGI, oo.Life, oo.Mana, oo.Arrow }) do
		v:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
		v:SetD3DPT(D3DPT.TRIANGLEFAN)
	end
	CACHE[dwType][dwID] = CACHE[dwType][dwID] or {}
	tinsert(CACHE[dwType][dwID], oo)
	return oo
end

-- �������� ���λ���
function SA:DrawText( ... )
	self.Text:ClearTriangleFanPoint()
	local nTop = BASE_PEAK - (BASE_EDGE * 2)
	local r, g, b = unpack(SA_COLOR.FONT[self.szClass])
	local i = 1
	for k, v in ipairs({ ... }) do
		if v and v ~= "" then
			local top = nTop + i * -23 * UI_SCALED
			if self.dwType == TARGET.DOODAD then
				self.Text:AppendDoodadID(self.dwID, r, g, b, 240, { 0, 0, 0, 0, top }, DBM_SA.nFont, v, 1, 1)
			else
				if DBM_SA.bDrawColor and self.dwType == TARGET.PLAYER and k ~= 1 then
					local p = select(2, ScreenArrow.GetObject(self.szClass, self.dwID))
					if p then
						r, g, b = JH.GetForceColor(p.dwForceID)
					end
				end
				self.Text:AppendCharacterID(self.dwID, true, r, g, b, 240, { 0, 0, 0, 0, top }, DBM_SA.nFont, v, 1, 1)
			end
			i = i + 1
		end
	end
	return self
end

function SA:DrawBackGround()
	for k, v in pairs({ self.BGB, self.BGI }) do
		v:ClearTriangleFanPoint()
	end
	local bcX, bcY = -BASE_WIDTH / 2, BASE_PEAK
	local doubleEdge = BASE_EDGE * 2
	if self.dwType == TARGET.DOODAD then
		self.BGB:AppendDoodadID(self.dwID, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY })
		self.BGB:AppendDoodadID(self.dwID, 255, 255, 255, 200, { 0, 0, 0, bcX + BASE_WIDTH, bcY })
		self.BGB:AppendDoodadID(self.dwID, 255, 255, 255, 200, { 0, 0, 0, bcX + BASE_WIDTH, bcY + BASE_HEIGHT })
		self.BGB:AppendDoodadID(self.dwID, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY + BASE_HEIGHT })
		bcX, bcY = -BASE_WIDTH / 2 + BASE_EDGE, BASE_PEAK + BASE_EDGE
		self.BGI:AppendDoodadID(self.dwID, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY })
		self.BGI:AppendDoodadID(self.dwID, 120, 120, 120, 80, { 0, 0, 0, bcX + BASE_WIDTH - doubleEdge, bcY })
		self.BGI:AppendDoodadID(self.dwID, 120, 120, 120, 80, { 0, 0, 0, bcX + BASE_WIDTH - doubleEdge, bcY + BASE_HEIGHT - doubleEdge })
		self.BGI:AppendDoodadID(self.dwID, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY + BASE_HEIGHT - doubleEdge})
	else
		self.BGB:AppendCharacterID(self.dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY })
		self.BGB:AppendCharacterID(self.dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX + BASE_WIDTH, bcY })
		self.BGB:AppendCharacterID(self.dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX + BASE_WIDTH, bcY + BASE_HEIGHT })
		self.BGB:AppendCharacterID(self.dwID, true, 255, 255, 255, 200, { 0, 0, 0, bcX, bcY + BASE_HEIGHT })
		bcX, bcY = -BASE_WIDTH / 2 + BASE_EDGE, BASE_PEAK + BASE_EDGE
		self.BGI:AppendCharacterID(self.dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY })
		self.BGI:AppendCharacterID(self.dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX + BASE_WIDTH - doubleEdge, bcY })
		self.BGI:AppendCharacterID(self.dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX + BASE_WIDTH - doubleEdge, bcY + BASE_HEIGHT - doubleEdge })
		self.BGI:AppendCharacterID(self.dwID, true, 120, 120, 120, 80, { 0, 0, 0, bcX, bcY + BASE_HEIGHT - doubleEdge})
	end
	self.init = true
	return self
end

function SA:DrawLifeBar(fLifePer, fManaPer)
	local height = BASE_HEIGHT / 2 - BASE_EDGE
	local width = BASE_WIDTH - (BASE_EDGE * 2)
	if fLifePer ~= self.fLifePer then
		self.Life:ClearTriangleFanPoint()
		if fLifePer > 0 then
			local bcX, bcY = -BASE_WIDTH / 2 + BASE_EDGE, BASE_PEAK + BASE_EDGE
			local r, g ,b = 220, 40, 0
			if self.dwType == TARGET.DOODAD then
				self.Life:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX, bcY })
				self.Life:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX + (width * fLifePer), bcY })
				self.Life:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX + (width * fLifePer), bcY + height })
				self.Life:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX, bcY + height })
			else
				self.Life:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
				self.Life:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (width * fLifePer), bcY })
				self.Life:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (width * fLifePer), bcY + height })
				self.Life:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + height })
			end
		end
		self.fLifePer = fLifePer
	end
	if fManaPer ~= self.fManaPer then
		self.Mana:ClearTriangleFanPoint()
		if fManaPer > 0 then
			local bcX, bcY = -BASE_WIDTH / 2 + BASE_EDGE, BASE_PEAK + height + BASE_EDGE
			local r, g ,b = 50, 100, 255
			if self.szClass == "CASTING" then
				r, g ,b = 255, 128, 0
			end
			if self.dwType == TARGET.DOODAD then
				self.Mana:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX, bcY })
				self.Mana:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX + (width * fManaPer), bcY })
				self.Mana:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX + (width * fManaPer), bcY + height })
				self.Mana:AppendDoodadID(self.dwID, r, g, b, 225, { 0, 0, 0, bcX, bcY + height })
			else
				self.Mana:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY })
				self.Mana:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (width * fManaPer), bcY })
				self.Mana:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX + (width * fManaPer), bcY + height })
				self.Mana:AppendCharacterID(self.dwID, true, r, g, b, 225, { 0, 0, 0, bcX, bcY + height })
			end
		end
		self.fManaPer = fManaPer
	end
	return self
end

function SA:DrowArrow()
	local cX, cY, cA = unpack(SA_POINT_C)
	cX, cY = cX * 0.7, cY * 0.7
	local fX, fY = BASE_POINT_START, -BASE_PEAK - BASE_HEIGHT
	if self.bUp then
		self.nTop = self.nTop + 2
		if self.nTop >= 10 then
			self.bUp = false
		end
	else
		self.nTop = self.nTop - 2
		if self.nTop <= 0 then
			self.bUp = true
		end
	end
	fY = fY - self.nTop

 	self.Arrow:ClearTriangleFanPoint()
 	local r, g, b = unpack(self.col)
 	if self.dwType == TARGET.DOODAD then
		self.Arrow:AppendDoodadID(self.dwID, r, g, b, cA, { 0, 0, 0, cX - fX, cY - fY })
		for k, v in ipairs(SA_POINT) do
			local x, y, a = unpack(v)
			x, y = x * 0.7, y * 0.7
			self.Arrow:AppendDoodadID(self.dwID, r, g, b, a, { 0, 0, 0, x - fX, y - fY })
		end
		local x, y, a = unpack(SA_POINT[1])
		self.Arrow:AppendDoodadID(self.dwID, r, g, b, a, { 0, 0, 0, x - fX, y - fY })
 	else
		self.Arrow:AppendCharacterID(self.dwID, true, r, g, b, cA, { 0, 0, 0, cX - fX, cY - fY })
		for k, v in ipairs(SA_POINT) do
			local x, y, a = unpack(v)
			x, y = x * 0.7, y * 0.7
			self.Arrow:AppendCharacterID(self.dwID, true, r, g, b, a, { 0, 0, 0, x - fX, y - fY })
		end
		local x, y, a = unpack(SA_POINT[1])
		self.Arrow:AppendCharacterID(self.dwID, true, r, g, b, a, { 0, 0, 0, x- fX, y - fY })
	end
	return self
end

function SA:Show()
	self.ui:Show()
	return self
end

function SA:Hide()
	self.ui:Hide()
	return self
end

function SA:Free()
	local tab = CACHE[self.dwType][self.dwID]
	if #tab == 1 then
		CACHE[self.dwType][self.dwID] = nil
	else
		for k, v in pairs(tab) do
			if v.ui == self.ui then
				table.remove(tab, k)
				break
			end
		end
	end
	HANDLE:Free(self.ui)
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Screen Head Alarm"], font = 27 }):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 10, y = nY + 10, txt = _L["Draw School Color"], checked = DBM_SA.bDrawColor })
	:Click(function(bChecked)
		DBM_SA.bDrawColor = bChecked
	end):Pos_()
	nX, nY = ui:Append("Text", { x = 0, y = nY + 5, txt = _L["less life/mana HeadAlert"], font = 27 }):Pos_()
	nX = ui:Append("WndCheckBox",{ x = 10, y = nY + 10, txt = _L["Enable"], checked = DBM_SA.bAlert }):Click(function(bChecked)
		DBM_SA.bAlert = bChecked
		ui:Fetch("Track_MP"):Enable(bChecked)
		ui:Fetch("Track_HP"):Enable(bChecked)
		ui:Fetch("bIsMe"):Enable(bChecked)
		local me = GetClientPlayer()
		if bChecked and me.bFightState then
			JH.BreatheCall("ScreenArrow_Fight", ScreenArrow.OnBreatheFight)
		else
			ScreenArrow.KillBreathe()
		end
	end):Pos_()
	nX, nY = ui:Append("WndCheckBox", "bIsMe", { x = nX + 10, y = nY + 10, txt = _L["only Monitor self"], checked = DBM_SA.bOnlySelf, enable = DBM_SA.bAlert })
	:Click(function(bChecked)
		DBM_SA.bOnlySelf = bChecked
	end):Pos_()
	nX = ui:Append("Text", { txt = _L["While HP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_HP", { x = nX +10, y = nY + 3, enable = DBM_SA.bAlert })
	:Range(0, 100, 100):Value(DBM_SA.fLifePer * 100):Change(function(nVal) DBM_SA.fLifePer = nVal / 100 end):Pos_()

	nX = ui:Append("Text", { txt = _L["While MP less than"], x = 10, y = nY }):Pos_()
	nX,nY = ui:Append("WndTrackBar", "Track_MP", { x = nX + 10, y = nY + 3, enable = DBM_SA.bAlert })
	:Range(0, 100, 100):Value(DBM_SA.fManaPer * 100):Change(function(nVal) DBM_SA.fManaPer = nVal / 100 end):Pos_()

	nX = ui:Append("WndButton2", { x = 10, y = nY + 5, txt = g_tStrings.FONT }):Click(function()
		GUI.OpenFontTablePanel(function(nFont)
			DBM_SA.nFont = nFont
		end)
	end):Pos_()
	ui:Append("WndButton2", { txt = _L["preview"], x = nX + 10, y = nY + 5 }):Click(function()
		CreateScreenArrow("TIME", GetClientPlayer().dwID, { txt = _L("%s are welcome to use JH plug-in", GetUserRoleName()) })
	end)
end
GUI.RegisterPanel(_L["Screen Head Alarm"], 431, _L["Dungeon"], PS)

function ScreenArrow.Init()
	HANDLE = JH.HandlePool(JH.GetShadowHandle("ScreenArrow"), FormatHandle(string.rep("<shadow></shadow>", 6)))
	JH.BreatheCall("ScreenArrow_Sort", ScreenArrow.OnSort, 500)
end

JH.RegisterInit("DBM_ARROW",
	{ "Breathe", ScreenArrow.OnBreathe },
	{ "FIGHT_HINT", ScreenArrow.RegisterFight },
	{ "LOGIN_GAME", ScreenArrow.Init },
	{ "UI_SCALED" , setUIScale},
	{ "JH_SA_CREATE", function()
			CreateScreenArrow(arg0, arg1, arg2)
	end }
)
