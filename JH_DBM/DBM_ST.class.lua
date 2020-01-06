-- @Author: Webster
-- @Date:   2015-04-28 16:41:08
-- @Last Modified by:   Administrator
-- @Last Modified time: 2017-01-12 22:00:49
-- JX3_Client ����ʱ��
local _L = JH.LoadLangPack
-- ST class
local ST = {}
ST.__index = ST
-- ini path
local ST_INIFILE = JH.GetAddonInfo().szRootPath .. "JH_DBM/ui/ST_UI.ini"
-- cache
local type, tonumber, ipairs, pairs, assert = type, tonumber, ipairs, pairs, assert
local tinsert, tsort = table.insert, table.sort
local setmetatable = setmetatable
local JH_Split, JH_Trim, JH_FormatTimeString = JH.Split, JH.Trim, JH.FormatTimeString
local floor = math.floor
local GetClientPlayer, GetTime, IsEmpty = GetClientPlayer, GetTime, IsEmpty
local ST_UI_NOMAL   = 5
local ST_UI_WARNING = 2
local ST_UI_ALPHA   = 180
local ST_TIME_EXPIRE = {}
local ST_CACHE = {}
do
	for k, v in pairs(DBM_TYPE) do
		ST_CACHE[v] = setmetatable({}, { __mode = "v" })
		ST_TIME_EXPIRE[v] = {}
	end
end

-- �����ֶε���ʱ
local function GetCountdown(tTime)
	local tab = {}
	local t = JH_Split(tTime, ";")
	for k, v in ipairs(t) do
		local time = JH_Split(v, ",")
		if time[1] and time[2] and tonumber(JH_Trim(time[1])) and time[2] ~= "" then
			tinsert(tab, { nTime = tonumber(time[1]), szName = time[2] })
		end
	end
	if IsEmpty(tab) then
		return nil
	else
		tsort(tab, function(a, b) return a.nTime < b.nTime end)
		return tab
	end
end
-- ����ʱģ�� �¼����� JH_ST_CREATE
-- nType ����ʱ���� Compatible.lua �е� DBM_TYPE
-- szKey ͬһ������Ψһ��ʶ��
-- tParam {
--      szName   -- ����ʱ���� ����ǷֶξͲ���Ҫ������
--      nTime    -- ʱ��  �� 10,����;25,����2; �� 30
--      nRefresh -- ����ʱ���ڽ�ֹ�ظ�ˢ��
--      nIcon    -- ����ʱͼ��ID
--      bTalk    -- �Ƿ񷢲�����ʱ 5�����������ʾ ��szName�� ʣ�� n �롣
-- }
-- ���ӣ�FireUIEvent("JH_ST_CREATE", 0, "test", { nTime = "5,test;15,����;25,c", szName = "demo" })
-- ���ܲ��ԣ�for i = 1, 200 do FireUIEvent("JH_ST_CREATE", 0, i, { nTime = Random(5, 15), nIcon = i }) end
local function CreateCountdown(nType, szKey, tParam)
	assert(type(tParam) == "table", "CreateCountdown failed!")
	local tTime = {}
	local nTime = GetTime()
	if type(tParam.nTime) == "number" then
		tTime = tParam
	else
		local tCountdown = GetCountdown(tParam.nTime)
		if tCountdown then
			tTime = tCountdown[1]
			tParam.nTime = tCountdown
			tParam.nRefresh = tParam.nRefresh or tCountdown[#tCountdown].nTime - 3 -- ���ʱ���ڷ�ֹ�ظ�ˢ�� ��������ս����NPC��Ҫ�ֶ�ɾ��
		else
			return JH.Sysmsg2(_L["Countdown format Error"] .. " TYPE: " .. _L["Countdown TYPE " .. nType] .. " KEY:" .. szKey .. " Content:" .. tParam.nTime)
		end
	end
	if tTime.nTime == 0 then
		local ui = ST_CACHE[nType][szKey]
		if ui and ui:IsValid() then
			ST_TIME_EXPIRE[nType][szKey] = nil
			return ui.obj:RemoveItem()
		end
	else
		local nExpire =  ST_TIME_EXPIRE[nType][szKey]
		if nExpire and nExpire > nTime then
			return
		end
		ST_TIME_EXPIRE[nType][szKey] = nTime + (tParam.nRefresh or 0) * 1000
		ST:ctor(nType, szKey, tParam):SetInfo(tTime, tParam.nIcon or 13):Switch(false)
	end
end

ST_UI = {
	bEnable = true,
	tAnchor = {},
}
JH.RegisterCustomData("ST_UI")

local _ST_UI = {}

function ST_UI.OnFrameCreate()
	this:RegisterEvent("LOADING_END")
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("ON_ENTER_CUSTOM_UI_MODE")
	this:RegisterEvent("ON_LEAVE_CUSTOM_UI_MODE")
	this:RegisterEvent("JH_ST_CREATE")
	this:RegisterEvent("JH_ST_DEL")
	this:RegisterEvent("JH_ST_CLEAR")
	_ST_UI.hItem = this:CreateItemData(ST_INIFILE, "Handle_Item")
	_ST_UI.UpdateAnchor(this)
	_ST_UI.handle = this:Lookup("", "Handle_List")
end

function ST_UI.OnEvent(szEvent)
	if szEvent == "JH_ST_CREATE" then
		CreateCountdown(arg0, arg1, arg2)
	elseif szEvent == "JH_ST_DEL" then
		local ui = ST_CACHE[arg0][arg1]
		if ui and ui:IsValid() then
			if arg2 then -- ǿ��������ɾ��
				ui.obj:RemoveItem()
				ST_TIME_EXPIRE[arg0][arg1] = nil
			end
		end
	elseif szEvent == "JH_ST_CLEAR" then
		_ST_UI.handle:Clear()
		for k, v in pairs(ST_TIME_EXPIRE) do
			ST_TIME_EXPIRE[k] = {}
		end
	elseif szEvent == "UI_SCALED" then
		_ST_UI.UpdateAnchor(this)
	elseif szEvent == "ON_ENTER_CUSTOM_UI_MODE" or szEvent == "ON_LEAVE_CUSTOM_UI_MODE" then
		UpdateCustomModeWindow(this, _L["Countdown"])
	elseif szEvent == "LOADING_END" then
		for k, v in pairs(ST_CACHE) do
			for kk, vv in pairs(v) do
				if vv and vv:IsValid() and not vv.bHold then
					vv.obj:RemoveItem()
				end
			end
		end
	end
end

function ST_UI.OnFrameDragEnd()
	this:CorrectPos()
	ST_UI.tAnchor = GetFrameAnchor(this)
end

local function SetSTAction(ui, nLeft, nPer)
	local me = GetClientPlayer()
	local obj = ui.obj
	if nLeft < 5 then
		local nTimeLeft = nLeft * 1000 % 1000
		local nAlpha = 255 * nTimeLeft / 1000
		if floor(nLeft / 1) % 2 == 1 then
			nAlpha = 255 - nAlpha
		end
		obj:SetInfo({ nTime = nLeft }):SetPercentage(nPer):Switch(true):SetAlpha(100 + nAlpha)
		if ui.bTalk and me.IsInParty() then
			if not ui.szTalk or ui.szTalk ~= floor(nLeft) then
				ui.szTalk = floor(nLeft)
				JH.Talk(_L("[%s] left over %d.", obj:GetName(), floor(nLeft)))
			end
		end
	else
		if ui.nAlpha < ST_UI_ALPHA then
			ui.nAlpha = math.min(ST_UI_ALPHA, ui.nAlpha + 15)
			obj:SetInfo({ nTime = nLeft }):SetPercentage(nPer):SetAlpha(ui.nAlpha)
		else
			obj:SetInfo({ nTime = nLeft }):SetPercentage(nPer)
		end
	end
end

function ST_UI.OnFrameBreathe()
	local me = GetClientPlayer()
	if not me then return end
	local nNow = GetTime()
	for k, v in pairs(ST_CACHE) do
		for kk, vv in pairs(v) do
			if vv:IsValid() then
				if type(vv.countdown) == "number" then
					local nLeft  = vv.countdown - ((nNow - vv.nLeft) / 1000)
					if nLeft >= 0 then
						SetSTAction(vv, nLeft, nLeft / vv.countdown)
					else
						vv.obj:RemoveItem()
					end
				else
					local time = vv.countdown[1]
					local nLeft = time.nTime - (nNow - vv.nLeft) / 1000
					if nLeft >= 0 then
						SetSTAction(vv, nLeft, nLeft / time.nTime)
					else
						if #vv.countdown == 1 then
							vv.obj:RemoveItem()
						else
							local nATime = (nNow - vv.nCreate) / 1000
							vv.nLeft = nNow
							table.remove(vv.countdown, 1)
							local time = vv.countdown[1]
							time.nTime = time.nTime - nATime
							vv.obj:SetInfo(time):Switch(false)
						end
					end
				end
			end
		end
	end
	_ST_UI.handle:Sort()
	_ST_UI.handle:FormatAllItemPos()
end

function _ST_UI.UpdateAnchor(frame)
	local a = ST_UI.tAnchor
	if not IsEmpty(a) then
		frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	else
		frame:SetPoint("CENTER", 0, 0, "CENTER", 0, -300)
	end
end

function _ST_UI.Init()
	local frame = Wnd.OpenWindow(ST_INIFILE, "ST_UI")
end

-- ���캯��
function ST:ctor(nType, szKey, tParam)
	if not ST_CACHE[nType] then
		return
	end
	local ui = ST_CACHE[nType][szKey]
	local nTime = GetTime()
	local key = nType .. "#" .. szKey
	tParam.szName = tParam.szName or key
	local oo
	if ui and ui:IsValid() then
		oo = ui.obj
		oo.ui.nCreate   = nTime
		oo.ui.nLeft     = nTime
		oo.ui.countdown = tParam.nTime
		oo.ui.nRefresh  = tParam.nRefresh or 1
		oo.ui.bTalk     = tParam.bTalk
		oo.ui.nFrame    = tParam.nFrame
	else -- û��ui������� ����
		oo = {}
		setmetatable(oo, self)
		oo.ui                = _ST_UI.handle:AppendItemFromData(_ST_UI.hItem)
		-- ����
		oo.ui.nCreate        = nTime
		oo.ui.nLeft          = nTime
		oo.ui.countdown      = tParam.nTime
		oo.ui.nRefresh       = tParam.nRefresh or 1
		oo.ui.bTalk          = tParam.bTalk
		oo.ui.nFrame         = tParam.nFrame
		oo.ui.bHold          = tParam.bHold
		-- ����
		oo.ui.nAlpha         = 30
		-- ui
		oo.ui.time           = oo.ui:Lookup("TimeLeft")
		oo.ui.txt            = oo.ui:Lookup("SkillName")
		oo.ui.img            = oo.ui:Lookup("Image")
		oo.ui.sha            = oo.ui:Lookup("shadow")
		oo.ui.sfx            = oo.ui:Lookup("SFX")
		oo.ui.obj            = oo
		ST_CACHE[nType][szKey] = oo.ui
		oo.ui:Show()
		_ST_UI.handle:FormatAllItemPos()
	end
	return oo
end
-- ���õ���ʱ�����ƺ�ʱ�� ���ڶ�̬�ı�ֶε���ʱ
function ST:SetInfo(tTime, nIcon)
	if tTime.szName then
		self.ui.txt:SetText(tTime.szName)
	end
	if tTime.nTime then
		self.ui:SetUserData(math.floor(tTime.nTime))
		self.ui.time:SetText(JH_FormatTimeString(tTime.nTime))
	end
	if nIcon then
		local box = self.ui:Lookup("Box")
		box:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		box:SetObjectIcon(nIcon)
	end
	return self
end
-- ���ý�����
function ST:SetPercentage(fPercentage)
	self.ui.img:SetPercentage(fPercentage)
	self.ui.sfx:SetRelX(32 + 300 * fPercentage)
	self.ui.sha:SetW(300 - 300 * fPercentage)
	self.ui.sha:SetRelX(32 + 300 * fPercentage)
	self.ui:FormatAllItemPos()
	return self
end
-- �ı���ʽ ���true�����Ϊ�ڶ���ʽ ����ʱ��С��5���ʱ��
function ST:Switch(bSwitch)
	if bSwitch then
		self.ui.txt:SetFontColor(255, 255, 255)
		-- self.ui.time:SetFontColor(255, 255, 255)
		self.ui.img:SetFrame(ST_UI_WARNING)
		-- self.ui.sha:SetColorRGB(30, 0, 0)
	else
		self.ui.txt:SetFontColor(255, 255, 0)
		self.ui.time:SetFontColor(255, 255, 255)
		self.ui.img:SetFrame(self.ui.nFrame or ST_UI_NOMAL)
		self.ui.img:SetAlpha(self.ui.nAlpha)
		-- self.ui.sha:SetAlpha(100)
		self.ui.sha:SetColorRGB(0, 0, 0)
	end
	return self
end

function ST:SetAlpha(nAlpha)
	self.ui.img:SetAlpha(nAlpha)
	-- self.ui.sha:SetAlpha(100 * (nAlpha / 255))
	return self
end

function ST:GetName()
	return self.ui.txt:GetText()
end
-- ɾ������ʱ
function ST:RemoveItem()
	_ST_UI.handle:RemoveItem(self.ui)
	_ST_UI.handle:FormatAllItemPos()
end

JH.RegisterEvent("LOGIN_GAME", _ST_UI.Init)
