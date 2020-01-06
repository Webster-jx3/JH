-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   WilliamChan
-- @Last Modified time: 2018-01-01 15:30:16

---------------------------------------
--          JH Plugin - Base         --
-- https://github.com/Webster-jx3/JH --
---------------------------------------

-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
local ipairs, pairs, next, pcall, Log = ipairs, pairs, next, pcall, Log
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local ssub, slen, schar, srep, sbyte, sformat, sgsub =
      string.sub, string.len, string.char, string.rep, string.byte, string.format, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local floor, mmin, mmax, mceil = math.floor, math.min, math.max, math.ceil
local GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID = GetClientPlayer, GetPlayer, GetNpc, GetClientTeam, UI_GetClientPlayerID
local setmetatable = setmetatable

------------------
--  Addon Path  --
------------------
local ADDON_BASE_PATH   = "Interface/JH/JH_0Base/"
local ADDON_DATA_PATH   = "Interface/JH/@DATA/"
local ADDON_SHADOW_PATH = "Interface/JH/JH_0Base/item/shadow.ini"
local ADDON_ROOT_PATH   = "Interface/JH/"
-------------------
--  Local cache  --
-------------------
-- event
local JH_EVENT        = {}
local JH_BGMSG        = {}
local JH_REQUEST      = {}
local JH_MONMSG       = {}
-- call
local JH_CALL_BREATHE = {}
local JH_CALL_DELAY   = {}
-- cache
local JH_CACHE_BUFF   = {}
local JH_CACHE_SKILL  = {}
local JH_CACHE_MAP    = {}
local JH_CACHE_ITEM   = {}
-- list
local JH_LIST_DUNGEON = {}
local JH_LIST_MAP     = {}
local JH_LIST_PLAYER  = {}
local JH_LIST_NPC     = {}
local JH_LIST_DOODAD  = {}

-------------------------------------
-- EventHandler
-------------------------------------
local function EventHandler(szEvent)
	-- local nTime = GetTime()
	for k, v in pairs(JH_EVENT[szEvent]) do
		local res, err = pcall(v, szEvent)
		if not res then
			JH.Debug("EVENT#" .. szEvent .. "." .. k .." ERROR: " .. err)
		end
	end
	-- �������������������
	-- Log("[JH] EventHandler " .. szEvent .. " cost:" .. GetTime() - nTime .."ms")
end
---------------------------------------------------------------------
-- LangPack
---------------------------------------------------------------------
local function GetLang()
	local szLang = select(3, GetVersion())
	local t0 = LoadLUAData(ADDON_BASE_PATH .. "lang/default.jx3dat") or {}
	local t1 = LoadLUAData(ADDON_BASE_PATH .. "lang/" .. szLang .. ".jx3dat") or {}
	for k, v in pairs(t0) do
		if not t1[k] then
			t1[k] = v
		end
	end
	t1.__import = function(szPath)
		local t2 = LoadLUAData(szPath .. "/" .. szLang .. ".jx3dat") or {}
		for k, v in pairs(t2) do
			t1[k] = v
		end
	end
	local mt = {
		__index = function(t, k) return k end,
		__call = function(t, k, ...) return sformat(t[k] or k, ...) end,
	}
	setmetatable(t1, mt)
	return t1
end
local _L = GetLang()

local _VERSION_   = 0x1060000
local _BUILD_     = "20170221"
local _DEBUG_     = IsFileExist(ADDON_DATA_PATH .. "EnableDebug")
local _LOGLV_     = 2

local JH_PANEL_INIFILE     = ADDON_BASE_PATH .. "ui/JH.ini"
local JH_PANEL_CLASS       = { g_tStrings.CHANNEL_CHANNEL, _L["Dungeon"], _L["Panel"], _L["Recreation"] }
local JH_PANEL_ADDON       = {}
local JH_PANEL_SELECT
local JH_PANEL_ANCHOR      = { s = "CENTER", r = "CENTER", x = 0, y = 0 }

---------------------------------------------------------------------
-- �����ʼ
---------------------------------------------------------------------
JH = {
	bDebugClient = true, -- ���Կͻ��˰汾
	nChannel     = PLAYER_TALK_CHANNEL.RAID, -- JH.TalkĬ��Ƶ��
	LoadLangPack = _L,
}

do
	if GetVersion and OutputMessage then
		local exp = { GetVersion() }
		if (exp and exp[4] == "exp" or exp[4] == "bvt") or EnableDebugEnv then -- ������
			_DEBUG_ = true
			OutputMessage("MSG_SYS", " [-- JH --] debug client, enable debug !!\n")
			OutputMessage("MSG_SYS", " [-- JH --] client version " .. exp[2] .. "\n")
			OutputMessage("MSG_SYS", " [-- JH --] client tag " .. exp[4] .. "\n")
			if EnableDebugEnv then
				OutputMessage("MSG_SYS", " [-- JH --] Debug LUA Env !! \n")
			end
		end
	end
end

local _JH = {
	szTitle      = _L["JH, JX3 Plug-in Collection"],
	tHotkey      = {},
	tGlobalValue = {},
	tModule      = {},
	szShort      = _L["JH"],
	tOption      = {},
	tOption2     = {},
}

-- (string, number) JH.GetVersion() -- ��ȡ����汾��
function _JH.GetVersion()
	local v = _VERSION_
	local szVersion = sformat("%d.%d.%d", v / 0x1000000,
		floor(v / 0x10000) % 0x100, floor(v / 0x100) % 0x100)
	if v % 0x100 ~= 0 then
		szVersion = szVersion .. "b" .. tostring(v % 0x100)
	end
	return szVersion, v
end

local JH = JH
-- ������� �ڲ���ʱ ��Զ����ʼ��
function JH.OnFrameCreate()
	this.bInit = true
	this:RegisterEvent("UI_SCALED")
	this:RegisterEvent("CALL_LUA_ERROR")
end

function JH.OnEvent(szEvent)
	if szEvent == "CALL_LUA_ERROR" and _DEBUG_ then
		if not ECHO_LUA_ERROR then
			ECHO_LUA_ERROR = { ID = 'JH' }
		end
		if ECHO_LUA_ERROR and ECHO_LUA_ERROR.ID == 'JH' then
			OutputMessage("MSG_SYS", arg0)
		end
	elseif szEvent == "UI_SCALED" then
		local a = JH_PANEL_ANCHOR
		this:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	end
end

function JH.OnFrameDragEnd()
	JH_PANEL_ANCHOR = GetFrameAnchor(this)
end

function JH.OnFrameBreathe()
	-- run breathe calls
	local nFrame = GetLogicFrameCount()
	for k, v in pairs(JH_CALL_BREATHE) do
		if nFrame >= v.nNext then
			v.nNext = nFrame + v.nFrame
			local res, err = pcall(v.fnAction)
			if not res then
				JH.Debug("BreatheCall#" .. k .." ERROR: " .. err)
			end
		end
	end
	local nTime = GetTime()
	for k = #JH_CALL_DELAY, 1, -1 do
		local v = JH_CALL_DELAY[k]
		if v.nTime <= nTime then
			local res, err = pcall(v.fnAction)
			if not res then
				JH.Debug("DelayCall#" .. k .." ERROR: " .. err)
			end
			tremove(JH_CALL_DELAY, k)
		end
	end
	-- run remote request (3s)
	if not _JH.nRequestExpire or _JH.nRequestExpire < nTime then
		if _JH.nRequestExpire then
			local r = tremove(JH_REQUEST, 1)
			if r then
				pcall(r.fnAction)
			end
			_JH.nRequestExpire = nil
		end
		if #JH_REQUEST > 0 then
			local page = Station.Lookup("Normal/JH/Page_1")
			if page then
				page:Navigate(JH_REQUEST[1].szUrl)
			end
			_JH.nRequestExpire = GetTime() + 3000
		end
	end
end

function JH.OnDocumentComplete()
	local r = tremove(JH_REQUEST, 1)
	if r then
		_JH.nRequestExpire = nil
		pcall(r.fnAction, this:GetLocationName(), this:GetDocument())
	end
end

function JH.OnCheckBoxCheck()
	local szName = this:GetName()
	if szName == "WndCheck_Home"
		or szName == "WndCheck_About"
		or szName == "WndCheck_Issues"
	then
		local frame = _JH.GetFrame()
		for i = 0, frame.hTab:GetAllContentCount() -1 do
			local hCheck = frame.hTab:LookupContent(i)
			if hCheck ~= this then
				hCheck:Check(false)
			else
				hCheck:Check(true)
			end
		end
		if szName == "WndCheck_Home" then
			_JH.BackHome()
		elseif szName == "WndCheck_About" then
			_JH.UpdatePage(JH_Panel.About)
		elseif szName == "WndCheck_Issues" then
			_JH.UpdatePage(JH_Panel.Feedback)
		end
	end
end

function _JH.UpdatePage(fn)
	_JH.CloseAddonPanel(true)
	local frame = _JH.GetFrame()
	if not frame.hPage:IsVisible() then
		frame.hPage:Show()
		frame.hPage:SetMousePenetrable(false)
	end
	for k, v in ipairs({ frame.hContent, frame.hHome }) do
		if v:IsVisible() then
			v:SetMousePenetrable(true)
			v:Hide()
		end
	end
	frame.hPage:Clear()
	frame.hPage:Lookup("", ""):Clear()
	return fn.OnPanelActive(frame.hPage)
end

function _JH.BackHome()
	_JH.CloseAddonPanel(true)
	local frame = _JH.GetFrame()
	if not frame.hHome:IsVisible() then
		JH.Animate(frame.hHome):FadeIn(300, function()
			frame.hHome:SetMousePenetrable(false)
		end)
	end
	frame.hPage:Hide()
	frame.hPage:SetMousePenetrable(true)
	if frame.hContent:IsVisible() then
		frame.hContent:SetMousePenetrable(true)
		JH.Animate(frame.hContent):FadeOut(300)
	end
	PlaySound(SOUND.UI_SOUND, g_sound.TakeUpSkill)
end

function JH.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Close" then
		_JH.ClosePanel()
	elseif szName == "Btn_JH" then
		local btn = this
		JH.Animate(btn):Scale(2, true):FadeOut(function()
			JH.Animate(btn):FadeIn()
		end)
		if not _DEBUG_ then
			Station.Lookup("Normal/Player", "Text_Player"):SetFontColor(32, 255, 166)
			_DEBUG_ = true
			JH.Sysmsg("Enable Debug!!")
		else
			Station.Lookup("Normal/Player", "Text_Player"):SetFontColor(255, 255, 0)
			_DEBUG_ = false
			JH.Sysmsg("Disable Debug!!")
		end
	end
end

function _JH.GetAddonExist(dwClass, nIndex)
	if JH_PANEL_ADDON[dwClass] and JH_PANEL_ADDON[dwClass][nIndex] then
		return JH_PANEL_ADDON[dwClass][nIndex]
	end
end

function _JH.CreateAddonFrame(tAddon)
	local frame = _JH.GetFrame()
	for i = 0, frame.hTab:GetAllContentCount() -1 do
		local hCheck = frame.hTab:LookupContent(i)
		hCheck:Check(false)
	end
	for k, v in pairs(frame.hContainer) do
		if k ~= "___id" then
			frame.hContainer[k] = nil
		end
	end
	frame.hContainer:Clear()
	frame.hContainer:Lookup("", ""):Clear()
	return tAddon.fn.OnPanelActive(frame.hContainer)
end

function _JH.CloseAddonPanel(bClear)
	if JH_PANEL_SELECT and JH_PANEL_SELECT.fn and JH_PANEL_SELECT.fn.OnPanelDeactive then
		JH_PANEL_SELECT.fn.OnPanelDeactive()
		if bClear then
			JH_PANEL_SELECT = nil
		end
	end
end

function _JH.OpenAddonPanel(dwClass, nIndex)
	if type(dwClass) == "string" then
		for k, v in pairs(JH_PANEL_ADDON) do
			for kk, vv in ipairs(v) do
				if vv.szTitle == dwClass then
					dwClass, nIndex = k, kk
					break
				end
			end
		end
	end
	local tAddon = _JH.GetAddonExist(dwClass, nIndex)
	if tAddon then
		local frame = _JH.GetFrame()
		for k, v in ipairs({ frame.hHome, frame.hPage }) do
			if v:IsVisible() then
				v:SetMousePenetrable(true)
				JH.Animate(v):FadeOut(300)
			end
		end
		if not frame.hContent:IsVisible() then
			JH.Animate(frame.hContent):FadeIn(300, function()
				frame.hContent:SetMousePenetrable(false)
			end)
		end
		_JH.CloseAddonPanel()
		frame.hContainer:SetRelPos(220, 0) -- fix close pos
		if JH_PANEL_SELECT ~= tAddon then
			JH_PANEL_SELECT = tAddon
			for i = 0, frame.hTree:GetItemCount() -1 do
				local ui = frame.hTree:Lookup(i)
				if ui then
					if ui:GetName() == "TreeLeaf_Node" then
						if ui.dwClass == dwClass then
							ui:Expand()
						else
							ui:Collapse()
						end
					elseif ui:GetName() == "TreeLeaf_Addon" then
						if ui.nIndex == nIndex and ui.dwClass == dwClass then
							ui:Lookup("Text_Addon_Tree"):SetFontColor(255, 128, 0)
							ui:Lookup("Image_Addon_Tree"):SetFrame(27)
						else
							ui:Lookup("Text_Addon_Tree"):SetFontColor(255, 255, 255)
							ui:Lookup("Image_Addon_Tree"):SetFrame(29)
						end
					end
				end
			end
			JH.Animate(frame.hContainer, 200):Pos({ 30, 0 }):FadeIn()
			PlaySound(SOUND.UI_SOUND, g_sound.Button)
			frame.hTree:FormatAllItemPos()
		end
		_JH.CreateAddonFrame(tAddon)
	end
end

function JH.OnItemLButtonClick()
	local szName = this:GetName()
	if szName == "Handle_Addon" or szName == "TreeLeaf_Addon" then
		if _JH.GetAddonExist(this.dwClass, this.nIndex) then
			_JH.OpenAddonPanel(this.dwClass, this.nIndex)
		end
	elseif szName == "TreeLeaf_Node" then
		local hTree = this:GetParent()
		for i = 0, hTree:GetItemCount() -1 do
			local ui = hTree:Lookup(i)
			if ui ~= this and ui and ui:GetName() == "TreeLeaf_Node" then
				ui:Collapse()
			end
		end
		if this:IsExpand() then
			this:Collapse()
		else
			this:Expand()
		end
		return hTree:FormatAllItemPos()
	end
end

function JH.OnMouseEnter()
	local szName = this:GetName()
	if szName == "Btn_JH" then -- ̫������
		local btn = this
		local t1 = Random(15, 50)
		local t2 = t1 / 2
		JH.Animate(btn):Pos({ 0, -t1 }, 200, true, function()
			JH.Animate(btn):Pos({ 0, t1 }, 200, true, function()
				JH.Animate(btn):Pos({ 0, -t2 }, 200, true, function()
					JH.Animate(btn):Pos({ 0, t2 }, 200, true)
				end)
			end)
		end)
	end
end

function JH.OnItemMouseEnter()
	local szName = this:GetName()
	if szName == "Handle_Addon" then
		return this:Lookup("Image_Addon"):SetFrame(28)
	elseif szName == "TreeLeaf_Addon" then
		return this:Lookup("Image_Addon_Tree"):SetFrame(28)
	elseif szName == "TreeLeaf_Node" then
		return this:Lookup("Image_Hover"):SetFrame(67)
	end
end

function JH.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == "Handle_Addon" then
		return this:Lookup("Image_Addon"):SetFrame(29)
	elseif szName == "TreeLeaf_Addon" then
		local szTitle = this:Lookup("Text_Addon_Tree"):GetText()
		if JH_PANEL_SELECT and szTitle ~= JH_PANEL_SELECT.szTitle then
			return this:Lookup("Image_Addon_Tree"):SetFrame(29)
		else
			return this:Lookup("Image_Addon_Tree"):SetFrame(27)
		end
	elseif szName == "TreeLeaf_Node" then
		return this:Lookup("Image_Hover"):SetFrame(66)
	end
end

function _JH.UpdateAddon()
	local frame = _JH.GetFrame()
	frame.hClass:Clear()
	frame.hTree:Clear()
	for k, v in pairs(JH_PANEL_ADDON) do
		-- home
		local hClass = frame.hClass:AppendItemFromIni(JH_PANEL_INIFILE, "Handle_Class")
		local hAddon = hClass:Lookup("Handle_Addon_List")
		hClass:Lookup("Text_Class"):SetText(JH_PANEL_CLASS[k])
		hAddon:Clear()
		-- Tree
		local hNode = frame.hTree:AppendItemFromIni(JH_PANEL_INIFILE, "TreeLeaf_Node")
		hNode:Lookup("Text_Tag"):SetText(JH_PANEL_CLASS[k])
		for kk, vv in ipairs(v) do
			local item  = hAddon:AppendItemFromIni(JH_PANEL_INIFILE, "Handle_Addon")
			local addon = frame.hTree:AppendItemFromIni(JH_PANEL_INIFILE, "TreeLeaf_Addon")
			item:Lookup("Text_Addon"):SetText(vv.szTitle)
			addon:Lookup("Text_Addon_Tree"):SetText(vv.szTitle)
			if type(vv.dwIcon) == "number" then
				item:Lookup("Box_Addon"):SetObjectIcon(vv.dwIcon)
				addon:Lookup("Box_Addon_Tree"):SetObjectIcon(vv.dwIcon)
			else
				item:Lookup("Box_Addon"):ClearObjectIcon()
				addon:Lookup("Box_Addon_Tree"):ClearObjectIcon()
				local szImage, nFrame = unpack(vv.dwIcon)
				item:Lookup("Box_Addon"):SetExtentImage(szImage, nFrame)
				addon:Lookup("Box_Addon_Tree"):SetExtentImage(szImage, nFrame)
			end
			item.nIndex   = kk
			item.dwClass  = k
			addon.nIndex  = kk
			addon.dwClass = k
		end
		hNode.dwClass = k
		hAddon:FormatAllItemPos()
		hAddon:SetSizeByAllItemSize()
		hNode:Collapse()
		hClass:FormatAllItemPos()
		hClass:SetSizeByAllItemSize()
	end
	frame.hClass:FormatAllItemPos()
	frame.hTree:FormatAllItemPos()
end

function _JH.UpdateTabBox()
	local frame = _JH.GetFrame()
	frame.hTab:Clear()
	for k, v in ipairs({ "Home", "About", --[["Issues"]] }) do
		local hCheck = frame.hTab:AppendContentFromIni(JH_PANEL_INIFILE, "Wnd_TabBox", "WndCheck_" .. v)
		local txt = hCheck:Lookup("", "Text_TabBox")
		txt:SetText(_L[v])
		local w = txt:GetTextExtent()
		txt:SetW(w + 30)
		hCheck:SetW(w + 30)
	end
	local _ = JH.OnCheckBoxCheck
	JH.OnCheckBoxCheck = nil
	frame.hTab:LookupContent(0):Check(true)
	JH.OnCheckBoxCheck = _
	frame.hTab:FormatAllContentPos()
end

function _JH.GetFrame()
	return Station.Lookup("Normal/JH")
end

function _JH.IsOpened()
	local frame = _JH.GetFrame()
	return frame and frame:IsVisible()
end

-- open
function _JH.OpenPanel(szTitle)
	local frame = _JH.GetFrame()
	if frame then
		if not frame.ani then
			local function fnAction()
				if szTitle then
					_JH.OpenAddonPanel(szTitle)
				elseif JH_PANEL_SELECT then
					_JH.OpenAddonPanel(JH_PANEL_SELECT.szTitle)
				end
				local date = frame:Lookup("", "Text_Date")
				local time = TimeToDate(GetCurrentTime())
				-- year, month, day, hour, minute, second, weekday
				if time.weekday == 0 then
					time.weekday = 7
				end
				local L = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
				local col = { 1, 1, 0, 4, 5, 5, 4 }
				date:SetText(_L("Today is %d-%d-%d (%s)", time.year, time.month, time.day, _L[L[time.weekday]]))
				date:SetFontColor(GetItemFontColorByQuality(col[time.weekday]))
			end
			if frame.bInit then -- �Բ��� ios����������... ���Ӹ�welcome�����
				local function Init()
					frame.hTab       = frame:Lookup("WndContainer_Tab")
					frame.hHome      = frame:Lookup("WndScroll_Home")
					frame.hPage      = frame:Lookup("WndContainer_Page")
					frame.hClass     = frame.hHome:Lookup("", "")
					frame.hContent   = frame:Lookup("Wnd_Content")
					frame.hTree      = frame.hContent:Lookup("WndScroll_TreeLeaf"):Lookup("", "")
					frame.hContainer = frame.hContent:Lookup("WndContainer_Main")
					local a = JH_PANEL_ANCHOR
					frame:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
					_JH.UpdateAddon()
					_JH.UpdateTabBox()
					local szTitle = _JH.szTitle .. " v" ..  _JH.GetVersion() .. " (" .. _BUILD_ .. ")"
					frame:Lookup("", "Text_Title"):SetText(szTitle)
					JH.RegisterGlobalEsc("JH", _JH.IsOpened, _JH.ClosePanel)
					frame.bInit = nil
					JH.Debug("Panel init success!")
				end
				local loading = frame:Lookup("", "Text_Loading")
				loading:SetText(GetUserRoleName() .. "\nWelcome Back.")
				if szTitle then
					JH.Animate(loading):FadeOut(function()
						Init()
						fnAction()
					end)
				else
					JH.Animate(loading):FadeIn(200, function()
						JH.Animate(loading):FadeOut(function()
							Init()
							JH.Animate(frame.hHome):FadeIn(300, fnAction)
						end)
					end)
				end
			else
				fnAction()
			end
			if not _JH.IsOpened() then
				JH.Animate(frame, 200):Scale(0.8):FadeIn(function()
					frame.ani = nil
				end)
				frame.ani = true
				PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
				frame:BringToTop()
				if Cursor.IsVisible() then
					Station.SetFocusWindow(frame)
				end
			end
		end
	else
		frame = Wnd.OpenWindow(JH_PANEL_INIFILE, "JH")
		frame:Hide()
	end
	return frame
end

-- close
function _JH.ClosePanel(bDisable)
	local frame = _JH.GetFrame()
	if frame and not frame.ani and not frame.bInit then
		if not bDisable then
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
		end
		_JH.CloseAddonPanel()
		JH.Animate(frame, 200):Scale(0.8, true):FadeOut()
	end
end

-- toggle
function _JH.TogglePanel()
	if _JH.IsOpened() then
		_JH.ClosePanel()
	else
		_JH.OpenPanel()
	end
end

JH.OpenPanel   = _JH.OpenPanel
JH.GetFrame    = _JH.GetFrame
JH.IsOpened    = _JH.IsOpened
JH.ClosePanel  = _JH.ClosePanel
JH.TogglePanel = _JH.TogglePanel

--------------------------------------- * ���ú��� * ---------------------------------------

-- (void) JH.SetHotKey()               -- �򿪿�ݼ��������
-- (void) JH.SetHotKey(string szGroup) -- �򿪿�ݼ�������岢��λ�� szGroup ���飨�����ã�
function JH.SetHotKey(szGroup)
	HotkeyPanel_Open(szGroup or _JH.szTitle)
end

-- (table) JH.GetAddonInfo() -- ��ȡ���������Ϣ
function JH.GetAddonInfo()
	return {
		szName      = _JH.szTitle,
		szVersion   = _JH.GetVersion(),
		szRootPath  = ADDON_ROOT_PATH,
		szAuthor    = _L["JH @ Double Dream Town"],
		szShadowIni = ADDON_SHADOW_PATH,
		szDataPath  = ADDON_DATA_PATH,
		szBuildDate = _BUILD_,
	}
end
local JH_NPC_TAB
local function JH_GetNpcName(dwTemplateID)
	local szName
	if JH_NPC_TAB and JH_NPC_TAB[dwTemplateID] then
		szName = JH_NPC_TAB[dwTemplateID]
	end
	if not szName then
		szName = Table_GetNpcTemplateName(dwTemplateID)
	end
	if JH.Trim(szName) == "" then
		szName = tostring(dwTemplateID)
	end
	return szName
end
-- (string) JH.GetTemplateName(KObject KObject[, boolean bEmployer])  -- ��ȡ���ʽ��NPC������ʵ����
-- (string) JH.GetTemplateName(number KObject[, boolean bEmployer])
function JH.GetTemplateName(KObject, bEmployer)
	if type(KObject) == "userdata" then
		local szName
		if IsPlayer(KObject.dwID) then
			return KObject.szName
		else
			szName = JH_GetNpcName(KObject.dwTemplateID)
		end
		if bEmployer and KObject.dwEmployer ~= 0 then
			local emp = GetPlayer(KObject.dwEmployer)
			if not emp then
				szName =  g_tStrings.STR_SOME_BODY .. g_tStrings.STR_PET_SKILL_LOG .. szName
			else
				if KObject.szName == "" then
					szName = emp.szName
				else
					szName = emp.szName .. g_tStrings.STR_PET_SKILL_LOG .. szName
				end
			end
		end
		return szName
	else
		return JH_GetNpcName(KObject)
	end
end
-- ע���¼�����ϵͳ���������ڿ���ָ��һ�� KEY ��ֹ��μ���
-- (void) JH.RegisterEvent(string szEvent, func fnAction[, string szKey])
-- szEvent		-- �¼������ں����һ���㲢����һ����ʶ�ַ������ڷ�ֹ�ظ���ȡ���󶨣��� LOADING_END.xxx
-- fnAction		-- �¼���������arg0 ~ arg9������ nil �൱��ȡ�����¼�
--�ر�ע�⣺�� fnAction Ϊ nil ���� szKey ҲΪ nil ʱ��ȡ������ͨ��������ע����¼�������
local function JH_RegisterEvent(szEvent, fnAction)
	local szKey = nil
	local nPos = StringFindW(szEvent, ".")
	if nPos then
		szKey = ssub(szEvent, nPos + 1)
		szEvent = ssub(szEvent, 1, nPos - 1)
	end
	if not JH_EVENT[szEvent] then
		JH_EVENT[szEvent] = {}
		RegisterEvent(szEvent, EventHandler)
	end
	local tEvent = JH_EVENT[szEvent]
	if fnAction then
		if not szKey then
			tinsert(tEvent, fnAction)
		else
			tEvent[szKey] = fnAction
		end
	else
		if not szKey then
			JH_EVENT[szEvent] = {}
		else
			tEvent[szKey] = nil
		end
		if next(tEvent) == nil then
			JH_EVENT[szEvent] = nil
			UnRegisterEvent(szEvent, EventHandler)
		end
	end
end

function JH.RegisterEvent(szEvent, fnAction)
	if type(szEvent) == "table" then
		for _, v in ipairs(szEvent) do
			JH_RegisterEvent(v, fnAction)
		end
	else
		JH_RegisterEvent(szEvent, fnAction)
	end
end

-- ȡ���¼�������
-- (void) JH.UnRegisterEvent(string szEvent)
function JH.UnRegisterEvent(szEvent)
	JH.RegisterEvent(szEvent, nil)
end
-- ע���û��������ݣ�֧��ȫ�ֱ����������
-- (void) JH.RegisterCustomData(string szVarPath[, number nVersion])
function JH.RegisterCustomData(szVarPath, nVersion, szDomain)
	szDomain = szDomain or "Role"
	if _G and type(_G[szVarPath]) == "table" then
		for k, _ in pairs(_G[szVarPath]) do
			RegisterCustomData(szDomain .. "/" .. szVarPath .. "." .. k, nVersion)
		end
	else
		RegisterCustomData(szDomain .. "/" .. szVarPath, nVersion)
	end
end
-- �������� �޸�ȫ�ֱ���
function _JH.SetGlobalValue(szVarPath, Val)
	local t = JH.Split(szVarPath, ".")
	local tab = _G
	for k, v in ipairs(t) do
		if type(tab[v]) == "nil" then
			tab[v] = {}
		end
		if k == #t then
			tab[v] = Val
		end
		tab = tab[v]
	end
end
-- ��ʼ��һ��ģ��
function JH.RegisterInit(key, ...)
	local events = { ... }
	if _JH.tModule[key] and IsEmpty(events) then
		for k, v in ipairs(_JH.tModule[key]) do
			if v[1] == "Breathe" then
				JH.UnBreatheCall(key)
			else
				JH.UnRegisterEvent(sformat("%s.%s", v[1], key))
			end
		end
		_JH.tModule[key] = nil
		JH.Debug2("UnInit # "  .. key)
	elseif #events > 0 then
		_JH.tModule[key] = events
		for k, v in ipairs(_JH.tModule[key]) do
			if v[1] == "Breathe" then
				JH.BreatheCall(key, v[2], v[3] or nil)
			else
				JH.RegisterEvent(sformat("%s.%s", v[1], key), v[2])
			end
		end
		JH.Debug2("Init # "  .. key .. " # Events # " .. #_JH.tModule[key])
	end
end

function JH.UnRegisterInit(key)
	JH.RegisterInit(key)
end

function JH.RegisterExit(fnAction)
	JH.RegisterEvent("PLAYER_EXIT_GAME", fnAction)
	JH.RegisterEvent("GAME_EXIT", fnAction)
	JH.RegisterEvent("RELOAD_UI_ADDON_BEGIN", fnAction)
end

function JH.RegisterBgMsg(szKey, fnAction)
	JH_BGMSG[szKey] = fnAction
end

function JH.GetForceColor(dwForce)
	return unpack(JH_FORCE_COLOR[dwForce])
end

function JH.CanTalk(nChannel)
	for _, v in ipairs({"WHISPER", "TEAM", "RAID", "BATTLE_FIELD", "NEARBY", "TONG", "TONG_ALLIANCE" }) do
		if nChannel == PLAYER_TALK_CHANNEL[v] then
			return true
		end
	end
	return false
end

function JH.SwitchChat(nChannel)
	local szHeader = JH_TALK_CHANNEL_HEADER[nChannel]
	if szHeader then
		SwitchChatChannel(szHeader)
	elseif type(nChannel) == "string" then
		SwitchChatChannel("/w " .. nChannel .. " ")
	end
end

-- parse emotion in talking message
local function ParseFaceIcon(t)
	if not _JH.tFaceIcon then
		_JH.tFaceIcon = {}
		for i = 1, g_tTable.FaceIcon:GetRowCount() do
			local tLine = g_tTable.FaceIcon:GetRow(i)
			_JH.tFaceIcon[tLine.szCommand] = tLine.dwID
		end
	end
	local t2 = {}
	for _, v in ipairs(t) do
		if v.type ~= "text" then
			if v.type == "emotion" then
				v.type = "text"
			end
			tinsert(t2, v)
		else
			local nOff, nLen = 1, slen(v.text)
			while nOff <= nLen do
				local szFace, dwFaceID = nil, nil
				local nPos = StringFindW(v.text, "#", nOff)
				if not nPos then
					nPos = nLen
				else
					for i = nPos + 7, nPos + 2, -1 do
						if i <= nLen then
							local szTest = ssub(v.text, nPos, i)
							if _JH.tFaceIcon[szTest] then
								szFace, dwFaceID = szTest, _JH.tFaceIcon[szTest]
								nPos = nPos - 1
								break
							end
						end
					end
				end
				if nPos >= nOff then
					tinsert(t2, { type = "text", text = ssub(v.text, nOff, nPos) })
					nOff = nPos + 1
				end
				if szFace and dwFaceID then
					tinsert(t2, { type = "emotion", text = szFace, id = dwFaceID })
					nOff = nOff + slen(szFace)
				end
			end
		end
	end
	return t2
end

function JH.Talk(nChannel, szText, szUUID, bNoEmotion, bSaveDeny, bNotLimit)
	local szTarget, me = "", GetClientPlayer()
	-- channel
	if not nChannel then
		nChannel = JH.nChannel
	elseif type(nChannel) == "string" then
		if not szText then
			szText = nChannel
			nChannel = JH.nChannel
		elseif type(szText) == "number" then
			szText, nChannel = nChannel, szText
		else
			szTarget = nChannel
			nChannel = PLAYER_TALK_CHANNEL.WHISPER
		end
	elseif nChannel == PLAYER_TALK_CHANNEL.RAID and me.GetScene().nType == MAP_TYPE.BATTLE_FIELD then
		nChannel = PLAYER_TALK_CHANNEL.BATTLE_FIELD
	elseif type(nChannel) == "table" then
		szText = nChannel
		nChannel = JH.nChannel
	end
	if nChannel == PLAYER_TALK_CHANNEL.RAID and not me.IsInParty() then
		return
	end
	-- say body
	local tSay = nil
	if type(szText) == "table" then
		tSay = szText
	else
		local tar = JH.GetTarget(me.GetTarget())
		szText = sgsub(szText, "%$zj", me.szName)
		if tar then
			szText = sgsub(szText, "%$mb", tar.szName)
		end
		if wstring.len(szText) > 150 and not bNotLimit then
			szText = wstring.sub(szText, 1, 150)
		end
		tSay = {{ type = "text", text = szText .. "\n"}}
	end
	if not bNoEmotion then
		tSay = ParseFaceIcon(tSay)
	end
	-- add addon msg header
	if not tSay[1] or (
		not (tSay[1].type == "eventlink" and tSay[1].name == "BG_CHANNEL_MSG") -- bgmsg
 		and not (tSay[1].name == "" and tSay[1].type == "eventlink") -- header already added
 	) then
		tinsert(tSay, 1, {
			type = "eventlink",
			name = "",
			linkinfo = JH.JsonEncode({
				via = "JH",
				uuid = szUUID and tostring(szUUID),
			}),
		})
	end
	if bSaveDeny and not JH.CanTalk(nChannel) then
		local edit = Station.Lookup("Lowest2/EditBox/Edit_Input")
		edit:ClearText()
		for _, v in ipairs(tSay) do
			if v.type == "text" then
				edit:InsertText(v.text)
			else
				edit:InsertObj(v.text, v)
			end
		end
		-- change to this channel
		JH.SwitchChat(nChannel)
	else
		me.Talk(nChannel, szTarget, tSay)
	end
end

function JH.Talk2(nChannel, szText, szUUID, bNoEmotion)
	JH.Talk(nChannel, szText, szUUID, bNoEmotion, true)
end

function JH.BgTalk(nChannel, szKey, ...)
	local tSay = { { type = "eventlink", name = "BG_CHANNEL_MSG", linkinfo = szKey } }
	local tArg = { ... }
	for _, v in ipairs(tArg) do
		tinsert(tSay, { type = "eventlink", name = "", linkinfo = var2str(v) })
	end
	JH.Talk(nChannel, tSay, nil, true)
end

function JH.BgHear(szKey, bIgnore)
	local me = GetClientPlayer()
	local tSay = me.GetTalkData()
	if tSay and (arg0 ~= me.dwID or bIgnore) and #tSay > 1 and (tSay[1].text == _L["Addon comm."] or tSay[1].text == "BG_CHANNEL_MSG") and tSay[2].type == "eventlink" then
		local tData, nOff = {}, 2
		if szKey then
			if tSay[nOff].linkinfo ~= szKey then
				return nil
			end
			nOff = nOff + 1
		end
		for i = nOff, #tSay do
			tinsert(tData, tSay[i].linkinfo)
		end
		return tData
	end
end

function JH.IsParty(dwID)
	return GetClientPlayer().IsPlayerInMyParty(dwID)
end

function JH.GetAllPlayer(nLimit)
	local aPlayer = {}
	for k, _ in pairs(JH_LIST_PLAYER) do
		local p = GetPlayer(k)
		if not p then
			JH_LIST_PLAYER[k] = nil
		elseif p.szName ~= "" then
			tinsert(aPlayer, p)
			if nLimit and #aPlayer == nLimit then
				break
			end
		end
	end
	return aPlayer
end

function JH.GetAllPlayerID()
	return JH_LIST_PLAYER
end

function JH.GetAllNpc(nLimit)
	local aNpc = {}
	for k, _ in pairs(JH_LIST_NPC) do
		local p = GetNpc(k)
		if not p then
			JH_LIST_NPC[k] = nil
		else
			tinsert(aNpc, p)
			if nLimit and #aNpc == nLimit then
				break
			end
		end
	end
	return aNpc
end

function JH.GetAllNpcID()
	return JH_LIST_NPC
end

function JH.GetAllDoodad(nLimit)
	local aDoodad = {}
	for k, _ in pairs(JH_LIST_DOODAD) do
		local p = GetDoodad(k)
		if not p then
			JH_LIST_DOODAD[k] = nil
		else
			tinsert(aDoodad, p)
			if nLimit and #aDoodad == nLimit then
				break
			end
		end
	end
	return aDoodad
end

function JH.GetAllDoodadID()
	return JH_LIST_DOODAD
end

function JH.GetDistance(nX, nY, nZ)
	local me = GetClientPlayer()
	if not nY and not nZ then
		local tar = nX
		nX, nY, nZ = tar.nX, tar.nY, tar.nZ
	elseif not nZ then
		return floor(((me.nX - nX) ^ 2 + (me.nY - nY) ^ 2) ^ 0.5)/64
	end
	return floor(((me.nX - nX) ^ 2 + (me.nY - nY) ^ 2 + (me.nZ/8 - nZ/8) ^ 2) ^ 0.5)/64
end

function JH.GetAllMap()
	local tList, tMap = {}, {}
	for k, v in ipairs(GetMapList()) do
		local szName = Table_GetMapName(v)
		if not tMap[szName] then
			tMap[szName] = true
			tinsert(tList, 1, szName)
		end
	end
	return tList
end

-- �ж�һ����ͼ�ǲ��Ǹ���
-- (bool) JH.IsDungeonMap(dwMapID, bType)
function JH.IsDungeon(dwMapID, bType)
	if bType then
		return select(2, GetMapParams(dwMapID)) == MAP_TYPE.DUNGEON
	else
		if IsEmpty(JH_LIST_DUNGEON) then
			for k, v in ipairs(GetMapList()) do
				local a = g_tTable.DungeonInfo:Search(v)
				if a and a.dwClassID == 3 then
					JH_LIST_DUNGEON[a.dwMapID] = true
				end
			end
		end
		return JH_LIST_DUNGEON[dwMapID] or false
	end
end

-- ��ȡ���ǵ�ǰ���ڵ�ͼ
-- JH.GetMapID(bool bFix) �Ƿ�������
function JH.GetMapID(bFix)
	local dwMapID = GetClientPlayer().GetMapID()
	if not bFix then
		return dwMapID
	else
		return JH_MAP_NAME_FIX[dwMapID] or dwMapID
	end
end

-- battle map
function JH.IsInBattleField()
	local me = GetClientPlayer()
	return me ~= nil and g_tTable.BattleField:Search(GetClientPlayer().GetScene().dwMapID) ~= nil
end


function JH.IsInArena()
	local me = GetClientPlayer()
	return me ~= nil and me.GetScene().bIsArenaMap
end

-- function JH.IsInArena()
-- 	local me = GetClientPlayer()
-- 	local dwMapID = me.GetMapID()
-- 	local nMapType = select(2, GetMapParams(dwMapID))
-- 	return nMapType and nMapType == MAP_TYPE.BATTLE_FIELD
-- end

-- �ж��ǲ��Ǹ�����ͼ
function JH.IsInDungeon(bType)
	local me = GetClientPlayer()
	local dwMapID = me.GetMapID()
	return JH.IsDungeon(dwMapID, bType)
end

function JH.IsMapExist(param)
	if not JH_LIST_MAP[-1] then
		local tMapListByID   = {
			[-1] = g_tStrings.CHANNEL_COMMON,
			[-9] = _L["recycle bin"],
		}
		local tMapListByName = {
			[g_tStrings.CHANNEL_COMMON] = -1,
			[_L["recycle bin"]]         = -9,
		}
		for k, v in ipairs(GetMapList()) do
			if not JH_MAP_NAME_FIX[v] then
				local szName           = Table_GetMapName(v)
				tMapListByID[v]        = szName
				tMapListByName[szName] = v
			end
		end
		setmetatable(JH_LIST_MAP, { __index = function(me, k)
			if tonumber(k) then
				if JH_MAP_NAME_FIX[k] then
					k = JH_MAP_NAME_FIX[k]
				end
				return tMapListByID[k]
			else
				return tMapListByName[k]
			end
		end })
	end
	return JH_LIST_MAP[param]
end

function JH.IsInParty()
	local me = GetClientPlayer()
	return me and me.IsInParty()
end


function JH.JsonToTable(szJson, bUrlEncode)
	if bUrlEncode then
		szJson = JH.UrlDecode(szJson)
	end
	local result, err = JH.JsonDecode(szJson)
	if err then
		JH.Debug(err)
		return false, err
	end
	if type(result) ~= "table" then
		return false, "data is invalid"
	end
	local data = {}
	local function Key2Num(data, tab)
		for k, v in pairs(tab) do
			local key = tonumber(k) or k
			data[key] = {}
			if type(v) == "table" then
				Key2Num(data[key], v)
			else
				data[key] = v
			end
		end
	end
	Key2Num(data, result)
	return data, nil
end

-- ���һ��������Ϣ
function JH.OutputWhisper(szMsg, szHead)
	szHead = szHead or _JH.szShort
	OutputMessage("MSG_WHISPER", "[" .. szHead .. "]" .. g_tStrings.STR_TALK_HEAD_WHISPER .. szMsg .. "\n")
	PlaySound(SOUND.UI_SOUND, g_sound.Whisper)
end
-- û��ͷ��������Ϣ Ҳ��������ϵͳ��Ϣ
function JH.Topmsg(szText, szType)
	OutputMessage(szType or "MSG_ANNOUNCE_YELLOW", szText .. "\n")
end

function JH.Sysmsg(szMsg, szHead, szType)
	szHead = szHead or _JH.szShort
	szType = szType or "MSG_SYS"
	OutputMessage(szType, "[" .. szHead .. "] " .. szMsg .. "\n")
end
-- err message
function JH.Sysmsg2(szMsg, szHead, col)
	szHead = szHead or _JH.szShort
	local r, g, b = 255, 0, 0
	if col then r, g, b = unpack(col) end
	OutputMessage("MSG_SYS", "[" .. szHead .. "] " .. szMsg .. "\n", false, 10, { r, g, b })
end

function JH.Debug(szMsg, szHead, nLevel)
	nLevel = nLevel or 1
	if _DEBUG_ and _LOGLV_ >= nLevel then
		if nLevel == 3 then szMsg = "### " .. szMsg
		elseif nLevel == 2 then szMsg = "=== " .. szMsg
		else szMsg = "-- " .. szMsg end
		JH.Sysmsg(szMsg, szHead)
	end
end
function JH.Debug2(szMsg, szHead) JH.Debug(szMsg, szHead, 2) end
function JH.Debug3(szMsg, szHead) JH.Debug(szMsg, szHead, 3) end

function JH.Alert(szMsg, fnAction, szSure)
	local nW, nH = Station.GetClientSize()
	local tMsg = {
		x = nW / 2, y = nH / 3, szMessage = szMsg, szName = "JH_Alert", szAlignment = "CENTER",
		{
			szOption = szSure or g_tStrings.STR_HOTKEY_SURE,
			fnAction = fnAction,
		},
	}
	MessageBox(tMsg)
end

function JH.Confirm(szMsg, fnAction, fnCancel, szSure, szCancel)
	local nW, nH = Station.GetClientSize()
	local tMsg = {
		x = nW / 2, y = nH / 3, szMessage = szMsg, szName = "JH_Confirm", szAlignment = "CENTER",
		{
			szOption = szSure or g_tStrings.STR_HOTKEY_SURE,
			fnAction = fnAction,
		}, {
			szOption = szCancel or g_tStrings.STR_HOTKEY_CANCEL,
			fnAction = fnCancel,
		},
	}
	MessageBox(tMsg)
end

function JH.RegisterGlobalEsc(szID, fnCondition, fnAction, bTopmost)
	if fnCondition and fnAction then
		RegisterGlobalEsc("JH_" .. szID, fnCondition, fnAction, bTopmost)
	else
		UnRegisterGlobalEsc("JH_" .. szID, bTopmost)
	end
end

-- Register:   JH.Chat.RegisterMsgMonitor(string szKey, function fnAction, table tChannels)
--             JH.Chat.RegisterMsgMonitor(function fnAction, table tChannels)
-- Unregister: JH.Chat.RegisterMsgMonitor(string szKey)
function JH.RegisterMsgMonitor(arg0, arg1, arg2)
	local szKey, fnAction, tChannels
	local tp0, tp1, tp2 = type(arg0), type(arg1), type(arg2)
	if tp0 == "string" and tp1 == "function" and tp2 == "table" then
		szKey, fnAction, tChannels = arg0, arg1, arg2
	elseif tp0 == "function" and tp1 == "table" then
		fnAction, tChannels = arg0, arg1
	elseif tp0 == "string" and not arg1 then
		szKey = arg0
	end

	if szKey and JH_MONMSG[szKey] then
		UnRegisterMsgMonitor(JH_MONMSG[szKey].fn)
		JH_MONMSG[szKey] = nil
	end
	if fnAction and tChannels then
		JH_MONMSG[szKey] = { fn = function(szMsg, nFont, bRich, r, g, b, szChannel)
			-- filter addon comm.
			-- if StringFindW(szMsg, "eventlink") and StringFindW(szMsg, _L["Addon comm."]) then
			-- 	return
			-- end
			fnAction(szMsg, nFont, bRich, r, g, b, szChannel)
		end, ch = tChannels }
		RegisterMsgMonitor(JH_MONMSG[szKey].fn, JH_MONMSG[szKey].ch)
	end
end

-- ѡ���� ����
local function fnBpairs(tab, nIndex)
	nIndex = nIndex - 1
	if nIndex > 0 then
		return nIndex, tab[nIndex]
	end
end

function JH.bpairs(tab)
	return fnBpairs, tab, #tab + 1
end

function JH.UpdateItemBoxExtend(box, nQuality)
	local szImage = "ui/Image/Common/Box.UITex"
	local nFrame
	if nQuality == 2 then
		nFrame = 13
	elseif nQuality == 3 then
		nFrame = 12
	elseif nQuality == 4 then
		nFrame = 14
	elseif nQuality == 5 then
		nFrame = 17
	end
	box:ClearExtentImage()
	box:ClearExtentAnimate()
	if nFrame and nQuality < 5 then
		box:SetExtentImage(szImage, nFrame)
	elseif nQuality == 5 then
		box:SetExtentAnimate(szImage, nFrame, -1)
	end
end

function JH.GetEndTime(nEndFrame)
	return (nEndFrame - GetLogicFrameCount()) / GLOBAL.GAME_FPS
end

function JH.GetBuffName(dwBuffID, dwLevel)
	local xKey = dwBuffID
	if dwLevel then
		xKey = dwBuffID .. "_" .. dwLevel
	end
	if not JH_CACHE_BUFF[xKey] then
		local tLine = Table_GetBuff(dwBuffID, dwLevel or 1)
		if tLine then
			JH_CACHE_BUFF[xKey] = { tLine.szName, tLine.dwIconID }
		else
			local szName = "BUFF#" .. dwBuffID
			if dwLevel then
				szName = szName .. ":" .. dwLevel
			end
			JH_CACHE_BUFF[xKey] = { szName, 1436 }
		end
	end
	return unpack(JH_CACHE_BUFF[xKey])
end

function JH.GetSkillName(dwSkillID, dwLevel)
	if not JH_CACHE_SKILL[dwSkillID] then
		local tLine = Table_GetSkill(dwSkillID, dwLevel)
		if tLine and tLine.dwSkillID > 0 and tLine.bShow
			and (StringFindW(tLine.szDesc, "_") == nil  or StringFindW(tLine.szDesc, "<") ~= nil)
		then
			JH_CACHE_SKILL[dwSkillID] = { tLine.szName, tLine.dwIconID }
		else
			local szName = "SKILL#" .. dwSkillID
			if dwLevel then
				szName = szName .. ":" .. dwLevel
			end
			JH_CACHE_SKILL[dwSkillID] = { szName, 1435 }
		end
	end
	return unpack(JH_CACHE_SKILL[dwSkillID])
end

function JH.GetItemName(nUiId)
	if not JH_CACHE_ITEM[nUiId] then
		local szName = Table_GetItemName(nUiId)
		local nIcon = Table_GetItemIconID(nUiId)
		if szName ~= "" and nIocn ~= -1 then
			JH_CACHE_ITEM[nUiId] = { szName, nIcon }
		else
			JH_CACHE_ITEM[nUiId] = { "ITEM#" .. nUiId, 1435 }
		end
	end
	return unpack(JH_CACHE_ITEM[nUiId])
end

function JH.GetMapName(dwMapID)
	if not JH_CACHE_MAP[dwMapID] then
		local szName = Table_GetMapName(dwMapID)
		if szName ~= "" then
			JH_CACHE_MAP[dwMapID] = tostring(dwMapID)
		else
			JH_CACHE_MAP[dwMapID] = szName
		end
	end
	return JH_CACHE_MAP[dwMapID]
end

-- ���� dwType ���ͺ� dwID ����Ŀ��
-- (void) JH.SetTarget([number dwType, ]number dwID)
-- dwType	-- *��ѡ* Ŀ������
-- dwID		-- Ŀ�� ID
function JH.SetTarget(dwType, dwID)
	if not dwType or dwType <= 0 then
		dwType, dwID = TARGET.NO_TARGET, 0
	elseif not dwID then
		dwID, dwType = dwType, TARGET.NPC
		if IsPlayer(dwID) then
			dwType = TARGET.PLAYER
		end
	end
	SetTarget(dwType, dwID)
end

-- ����BUFF ID ���� KBUFF ���� �粻�� nLevel �� nLevel ����0 ������� nLevel
-- (KBUFF) JH.GetBuff(dwBuffID, [nLevel[, KObject me]])
-- (KBUFF) JH.GetBuff(tBuff, [nLevel[, KObject me]])
-- KBUFF_LIST_NODE
-- DECLARE_LUA_CLASS(KBUFF_LIST_NODE);
-- DECLARE_LUA_STRUCT_INTEGER(Index, nIndex);
-- DECLARE_LUA_STRUCT_INTEGER(StackNum, nStackNum);
-- DECLARE_LUA_STRUCT_INTEGER(NextActiveFrame, nNextActiveFrame);
-- DECLARE_LUA_STRUCT_INTEGER(LeftActiveCount, nLeftActiveCount);
-- DECLARE_LUA_STRUCT_DWORD(SkillSrcID, dwSkillSrcID);
-- DECLARE_LUA_STRUCT_BOOL(Validity, bValidity);
-- int LuaGetIntervalFrame(Lua_State* L);
-- int LuaGetEndTime(Lua_State* L);
function JH.GetBuff(dwID, nLevel, KObject)
	local tBuff = {}
	if type(dwID) == "table" then
		tBuff = dwID
	elseif type(dwID) == "number" then
		if type(nLevel) == "number" then
			tBuff[dwID] = nLevel
		else
			tBuff[dwID] = 0
		end
	end
	if type(nLevel) == "userdata" then
		KObject = nLevel
	else
		KObject = KObject or GetClientPlayer()
	end
	for k, v in pairs(tBuff) do
		local KBuff = KObject.GetBuff(k, v)
		if KBuff then
			return KBuff
		end
	end
end

function JH.CancelBuff( ... )
	local tBuff = JH.GetBuff( ... )
	if tBuff then
		return GetClientPlayer().CancelBuff(tBuff.nIndex)
	end
end
-- ��ʽ��ʱ���ַ���
function JH.FormatTimeString(nSec, nStyle, bDefault)
	nSec = nSec > 0 and nSec or 0
	if nStyle == 1 then
		if bDefault then
			nSec = nSec < 5999 and nSec or 5999
		end
		if nSec > 60 then
			return floor(nSec / 60) .. "'" .. floor(nSec % 60) .. "\""
		else
			return floor(nSec) .. "\""
		end
	else
		local h, m, s = "h", "m", "s"
		if nStyle == 2 then
			h, m, s = g_tStrings.STR_TIME_HOUR, g_tStrings.STR_TIME_MINUTE, g_tStrings.STR_TIME_SECOND
		end
		if nSec > 3600 then
			return floor(nSec / 3600) .. h .. floor(nSec / 60) % 60  .. m .. floor(nSec % 60) .. s
		elseif nSec > 60 then
			return floor(nSec / 60) .. m .. floor(nSec % 60) .. s
		else
			return floor(nSec) .. s
		end
	end
end

function JH.GetBuffList(tar)
	tar = tar or GetClientPlayer()
	local aBuff = {}
	local nCount = tar.GetBuffCount()
	for i = 1, nCount, 1 do
		local dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid = tar.GetBuff(i - 1)
		if dwID then
			tinsert(aBuff, {
				dwID = dwID, nLevel = nLevel, bCanCancel = bCanCancel, nEndFrame = nEndFrame,
				nIndex = nIndex, nStackNum = nStackNum, dwSkillSrcID = dwSkillSrcID, bValid = bValid,
				nCount = i
			})
		end
	end
	return aBuff
end

function JH.WalkAllBuff(tar, fnAction)
	if type(tar) == "function" then
		fnAction = tar
		tar = GetClientPlayer()
	end
	local nCount = tar.GetBuffCount()
	for i = 1, nCount, 1 do
		local dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid = tar.GetBuff(i - 1)
		if dwID then
			local res, ret = pcall(fnAction, dwID, nLevel, bCanCancel, nEndFrame, nIndex, nStackNum, dwSkillSrcID, bValid)
			if res == true and ret == false then
				break
			end
		end
	end
end

function JH.SaveLUAData(szPath, ...)
	local nTime = GetTime()
	SaveLUAData(ADDON_DATA_PATH .. szPath, ...)
	JH.Debug3(_L["SaveLUAData # "] ..  ADDON_DATA_PATH .. szPath .. " " .. GetTime() - nTime .. "ms")
end

function JH.LoadLUAData(szPath)
	local nTime = GetTime()
	local data = LoadLUAData(ADDON_DATA_PATH .. szPath)
	JH.Debug3(_L["LoadLUAData # "] ..  ADDON_DATA_PATH .. szPath .. " " .. GetTime() - nTime .. "ms")
	return data
end

function JH.IsMark()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) == UI_GetClientPlayerID()
end

function JH.IsLeader()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) == UI_GetClientPlayerID()
end

function JH.IsDistributer()
	return GetClientTeam().GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) == UI_GetClientPlayerID()
end

function JH.RemoteRequest(szUrl, fnAction)
	tinsert(JH_REQUEST, { szUrl = szUrl, fnAction = fnAction })
end

local function ConvertToAnsi(data)
	if type(data) == "table" then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == "string" then
				t[ConvertToAnsi(k)] = ConvertToAnsi(v)
			else
				t[k] = ConvertToAnsi(v)
			end
		end
		return t
	elseif type(data) == "string" then
		return UTF8ToAnsi(data)
	else
		return data
	end
end
JH.ConvertToAnsi = ConvertToAnsi

function JH.DelayCall(fnAction, nDelay)
	if not nDelay then
		if #JH_CALL_DELAY > 0 then
			if JH_CALL_DELAY[#JH_CALL_DELAY].fnAction == fnAction then
				return JH.Debug3("Ignore DelayCall " .. tostring(fnAction))
			end
		end
		nDelay = 0
	end
	tinsert(JH_CALL_DELAY, { nTime = nDelay + GetTime(), fnAction = fnAction })
end

function JH.Split(szFull, szSep)
	local nOff, tResult = 1, {}
	while true do
		local nEnd = StringFindW(szFull, szSep, nOff)
		if not nEnd then
			tinsert(tResult, ssub(szFull, nOff, slen(szFull)))
			break
		else
			tinsert(tResult, ssub(szFull, nOff, nEnd - 1))
			nOff = nEnd + slen(szSep)
		end
	end
	return tResult
end

function JH.DoMessageBox(szName, i)
	local frame = Station.Lookup("Topmost2/MB_" .. szName) or Station.Lookup("Topmost/MB_" .. szName)
	if frame then
		i = i or 1
		local btn = frame:Lookup("Wnd_All/Btn_Option" .. i)
		if btn and btn:IsEnabled() then
			if btn.fnAction then
				if frame.args then
					btn.fnAction(unpack(frame.args))
				else
					btn.fnAction()
				end
			elseif frame.fnAction then
				if frame.args then
					frame.fnAction(i, unpack(frame.args))
				else
					frame.fnAction(i)
				end
			end
			frame.OnFrameDestroy = nil
			CloseMessageBox(szName)
		end
	end
end

function JH.BreatheCall(szKey, fnAction, nTime)
	local key = StringLowerW(szKey)
	if type(fnAction) == "function" then
		local nFrame = 1
		if nTime and nTime > 0 then
			nFrame = mceil(nTime / 62.5)
		end
		JH_CALL_BREATHE[key] = { fnAction = fnAction, nNext = GetLogicFrameCount() + 1, nFrame = nFrame }
		JH.Debug3("BreatheCall # " .. szKey .. " # " .. nFrame)
	else
		JH_CALL_BREATHE[key] = nil
		JH.Debug3("UnBreatheCall # " .. szKey)
	end
end

function JH.UnBreatheCall(szKey)
	JH.BreatheCall(szKey)
end

function JH.AddHotKey(szName, szTitle, fnAction)
	if ssub(szName, 1, 3) ~= "JH_" then
		szName = "JH_" .. szName
	end
	tinsert(_JH.tHotkey, { szName = szName, szTitle = szTitle, fnAction = fnAction })
end
-- (KObject) JH.GetTarget() -- ȡ�õ�ǰĿ���������
-- (KObject) JH.GetTarget([number dwType, ]number dwID)	-- ���� dwType ���ͺ� dwID ȡ�ò�������
function JH.GetTarget(dwType, dwID)
	if not dwType then
		local me = GetClientPlayer()
		if me then
			dwType, dwID = me.GetTarget()
		else
			dwType, dwID = TARGET.NO_TARGET, 0
		end
	elseif not dwID then
		dwID, dwType = dwType, TARGET.NPC
		if IsPlayer(dwID) then
			dwType = TARGET.PLAYER
		end
	end
	if dwID <= 0 or dwType == TARGET.NO_TARGET then
		return nil, TARGET.NO_TARGET
	elseif dwType == TARGET.PLAYER then
		return GetPlayer(dwID), TARGET.PLAYER
	elseif dwType == TARGET.DOODAD then
		return GetDoodad(dwID), TARGET.DOODAD
	else
		return GetNpc(dwID), TARGET.NPC
	end
end

function _JH.GetMainMenu()
	return {
		szOption    = _L["JH Plugin"],
		fnAction    = _JH.TogglePanel,
		bCheck      = true,
		bChecked    = _JH.IsOpened(),
		szIcon      = 'ui/Image/UICommon/CommonPanel2.UITex',
		nFrame      = 105, nMouseOverFrame = 106,
		szLayer     = "ICON_RIGHT",
		fnClickIcon = _JH.TogglePanel
	}
end

function _JH.GetPlayerAddonMenu()
	local menu = _JH.GetMainMenu()
	tinsert(menu, { szOption = _L["JH Plugin"] .. " v" .. _JH.GetVersion(), bDisable = true })
	tinsert(menu, { bDevide = true })
	tinsert(menu, { szOption = _L["Open JH Panel"], fnAction = _JH.TogglePanel })
	tinsert(menu, { bDevide = true })
	for k, v in ipairs(_JH.tOption) do
		if type(v) == "function" then
			tinsert(menu, v())
		else
			tinsert(menu, v)
		end
	end
	if JH.bDebugClient then
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "ReloadUIAddon", fnAction = function()
			ReloadUIAddon()
		end })
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Enable Debug mode", bCheck = true, bChecked = _DEBUG_, fnAction = function()
			_DEBUG_ = not _DEBUG_
		end })
	end
	if _DEBUG_ then
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Debug Level 1", bMCheck = true, bChecked = _LOGLV_ == 1, fnAction = function()
			_LOGLV_ = 1
		end })
		tinsert(menu, { szOption = "Debug Level 2", bMCheck = true, bChecked = _LOGLV_ == 2, fnAction = function()
			_LOGLV_ = 2
		end })
		tinsert(menu, { szOption = "Debug Level 3", bMCheck = true, bChecked = _LOGLV_ == 3, fnAction = function()
			_LOGLV_ = 3
		end })
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "Talk Debug Channel",
			{ szOption = g_tStrings.tChannelName["MSG_TEAM"], rgb = GetMsgFontColor("MSG_TEAM", true), bMCheck = true ,bChecked = JH.nChannel == PLAYER_TALK_CHANNEL.RAID, fnAction = function()
				JH.nChannel = PLAYER_TALK_CHANNEL.RAID
			end },
			{ szOption = g_tStrings.tChannelName["MSG_GUILD"], rgb = GetMsgFontColor("MSG_GUILD", true), bMCheck = true ,bChecked = JH.nChannel == PLAYER_TALK_CHANNEL.TONG, fnAction = function()
				JH.nChannel = PLAYER_TALK_CHANNEL.TONG
			end },
		})
		tinsert(menu, { bDevide = true })
		tinsert(menu, { szOption = "EventHandler" })
		local EventHandler = menu[#menu]
		for k, v in pairs(JH_EVENT) do
			tinsert(EventHandler, { szOption = k })
			for kk, vv in pairs(v) do
				tinsert(EventHandler[#EventHandler], { szOption = tostring(vv) .. (type(kk) ~= "number" and " (" .. kk .. ")" or "") })
			end
		end
	end
	return { menu }
end
JH.GetPlayerAddonMenu = _JH.GetPlayerAddonMenu

function _JH.GetAddonMenu()
	local menu = _JH.GetMainMenu()
	tinsert(menu,{ szOption = _L["JH Plugin"] .. " v" .. _JH.GetVersion(), bDisable = true })
	tinsert(menu,{ bDevide = true })
	for _, v in ipairs(_JH.tOption2) do
		if type(v) == "function" then
			tinsert(menu, v())
		else
			tinsert(menu, v)
		end
	end
	return { menu }
end
-- ע�����ͷ��Ĳ���˵�
function JH.PlayerAddonMenu(tMenu)
	tinsert(_JH.tOption, tMenu)
end
-- ע�����Ͻǵİ��ֲ˵�
function JH.AddonMenu(tMenu)
	tinsert(_JH.tOption2, tMenu)
end
-- ����ȫ��shadow������ �������Է�ֹǰ��˳�򸲸�
function JH.GetShadowHandle(szName)
	local sh = Station.Lookup("Lowest/JH_Shadows") or Wnd.OpenWindow(ADDON_BASE_PATH .. "item/JH_Shadows.ini", "JH_Shadows")
	if not sh:Lookup("", szName) then
		sh:Lookup("", ""):AppendItemFromString(sformat("<handle> name=\"%s\" </handle>", szName))
	end
	JH.Debug3("Create sh # " .. szName)
	return sh:Lookup("", szName)
end

JH.RegisterEvent("PLAYER_ENTER_GAME", function()
	_JH.OpenPanel()
	-- _JH.tGlobalValue = JH.LoadLUAData("dev/GlobalValue.jx3dat") or {}
	-- ע���ݼ�
	Hotkey.AddBinding("JH_Total", _L["JH Plugin"], _L["JH Plugin"], _JH.TogglePanel , nil)
	for _, v in ipairs(_JH.tHotkey) do
		Hotkey.AddBinding(v.szName, v.szTitle, "", v.fnAction, nil)
	end
	for k, v in ipairs(JH_MARK_NAME) do
		Hotkey.AddBinding("JH_AutoSetTeam" .. k, _L["Mark"] .. " [" .. v .. "]", "", function()
			local dwID = select(2, Target_GetTargetData())
			GetClientTeam().SetTeamMark(k, dwID)
		end, nil)
	end
	-- ע�����ͷ��˵�
	Player_AppendAddonMenu({ _JH.GetPlayerAddonMenu })
	-- ע�����Ͻǲ˵�
	TraceButton_AppendAddonMenu({ _JH.GetAddonMenu })
	JH.Sysmsg(_L("%s are welcome to use JH plug-in", GetUserRoleName()) .. "! v" .. _JH.GetVersion())
end)

JH.RegisterEvent("LOADING_END", function()
	-- reseting frame count (FIXED BUG FOR Cross Server)
	for k, v in pairs(JH_CALL_BREATHE) do
		v.nNext = GetLogicFrameCount()
	end
	-- debug mode
	for k, v in pairs(_JH.tGlobalValue) do
		_JH.SetGlobalValue(k, v)
		_JH.tGlobalValue[k] = nil
	end
end)

-- szKey, nChannel, dwID, szName, aTable
JH.RegisterEvent("ON_BG_CHANNEL_MSG", function()
	if JH_BGMSG[arg0] then
		local res, err = pcall(JH_BGMSG[arg0], arg1, arg2, arg3, arg4, arg2 == UI_GetClientPlayerID())
		if not res then
			JH.Debug("BG_MSG#" .. arg0 .. "# ERROR:" .. err)
		end
	end
end)

JH.RegisterEvent("PLAYER_ENTER_SCENE", function() JH_LIST_PLAYER[arg0] = true end)
JH.RegisterEvent("PLAYER_LEAVE_SCENE", function() JH_LIST_PLAYER[arg0] = nil  end)
JH.RegisterEvent("NPC_ENTER_SCENE",    function() JH_LIST_NPC[arg0]    = true end)
JH.RegisterEvent("NPC_LEAVE_SCENE",    function() JH_LIST_NPC[arg0]    = nil  end)
JH.RegisterEvent("DOODAD_ENTER_SCENE", function() JH_LIST_DOODAD[arg0] = true end)
JH.RegisterEvent("DOODAD_LEAVE_SCENE", function() JH_LIST_DOODAD[arg0] = nil  end)
-- �ַ�����
function JH.Trim(szText)
	if not szText or szText == "" then
		return ""
	end
	return (sgsub(szText, "^%s*(.-)%s*$", "%1"))
end

local function get_urlencode(c)
	return sformat("%%%02X", sbyte(c))
end
function JH.UrlEncode(szText)
	local str = szText:gsub("([^0-9a-zA-Z ])", get_urlencode)
	str = str:gsub(" ", "+")
	return str
end

local function get_urldecode(h)
	return schar(tonumber(h, 16))
end
function JH.UrlDecode(szText)
	return szText:gsub("+", " "):gsub("%%(%x%x)", get_urldecode)
end

local function get_asciiencode(s)
	return sformat("%02x", s:byte())
end
function JH.AscIIEncode(szText)
	return szText:gsub('(.)', get_asciiencode)
end

local function get_asciidecode(s)
	return schar(tonumber(s, 16))
end
function JH.AscIIDecode(szText)
	return szText:gsub('(%x%x)', get_asciidecode)
end

-- ��ʱѡ���д���
local JH_TAR_TEMP
local JH_TAR_TEMP_STATUS = false

JH.RegisterEvent("JH_TAR_TEMP_UPDATE", function()
	JH_TAR_TEMP = arg0
end)

function JH.SetTempTarget(dwMemberID, bEnter)
	if JH_TAR_TEMP_STATUS == bEnter then -- ��ֹż��UIBUG
		return
	end
	JH_TAR_TEMP_STATUS = bEnter
	local dwType, dwID = Target_GetTargetData()
	if bEnter then
		JH_TAR_TEMP = dwID
		if dwMemberID ~= dwID then
			JH.SetTarget(dwMemberID)
		end
	else
		JH.SetTarget(JH_TAR_TEMP)
	end
end

-- Output
function JH.OutputNpcTip(dwNpcTemplateID, Rect)
	local npc = GetNpcTemplate(dwNpcTemplateID)
	if not npc then
		return
	end
	local szName = JH.GetTemplateName(dwNpcTemplateID)
	local t = {}
	tinsert(t, GetFormatText(szName .. "\n", 80, 255, 255, 0))
		-------------�ȼ�----------------------------
	if npc.nLevel - GetClientPlayer().nLevel > 10 then
		tinsert(t, GetFormatText(g_tStrings.STR_PLAYER_H_UNKNOWN_LEVEL, 82))
	else
		tinsert(t, GetFormatText(FormatString(g_tStrings.STR_NPC_H_WHAT_LEVEL, npc.nLevel), 0))
	end
	------------ģ��ID-----------------------
	tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_TEMPLATE_ID_NPC_INTENSITY, npc.dwTemplateID, npc.nIntensity or 1), 101))

	OutputTip(tconcat(t), 345, Rect)
end

function JH.OutputDoodadTip(dwTemplateID, Rect)
	local doodad = GetDoodadTemplate(dwTemplateID)
	if not doodad then
		return
	end
	local t = {}
	--------------����-------------------------
	local szName = doodad.szName ~= "" and doodad.szName or dwTemplateID
	if doodad.nKind == DOODAD_KIND.CORPSE then
		szName = szName .. g_tStrings.STR_DOODAD_CORPSE
	end
	tinsert(t, GetFormatText(szName .. "\n", 65))
	tinsert(t, GetDoodadQuestTip(dwTemplateID))
	------------ģ��ID-----------------------
	tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_TEMPLATE_ID, doodad.dwTemplateID), 101))
	if IsCtrlKeyDown() then
		tinsert(t, GetFormatText(FormatString(g_tStrings.TIP_REPRESENTID_ID, doodad.dwRepresentID), 102))
	end
	OutputTip(tconcat(t), 300, Rect)
end

local XML_LINE_BREAKER = GetFormatText("\n")
function JH.OutputBuffTip(dwID, nLevel, Rect, nTime)
	local t, tab = {}, {}
	local szName = Table_GetBuffName(dwID, nLevel)
	if szName == "" then
		szName = g_tStrings.STR_HOTKEY_HIDE
	end
	tinsert(t, GetFormatText(szName .. "\t", 65))
	local buffInfo = GetBuffInfo(dwID, nLevel, {})
	if buffInfo and buffInfo.nDetachType and g_tStrings.tBuffDetachType[buffInfo.nDetachType] then
		tinsert(t, GetFormatText(g_tStrings.tBuffDetachType[buffInfo.nDetachType] .. "\n", 106))
	else
		tinsert(t, XML_LINE_BREAKER)
	end
	local szDesc = GetBuffDesc(dwID, nLevel, "desc")
	if szDesc and szDesc ~= "" then
		tinsert(t, GetFormatText(szDesc .. g_tStrings.STR_FULL_STOP, 106))
	else
		tinsert(t, GetFormatText("BUFF#" .. dwID .. "#" .. nLevel, 106))
	end

	if nTime then
		if nTime == 0 then
			tinsert(t, XML_LINE_BREAKER)
			tinsert(t, GetFormatText(g_tStrings.STR_BUFF_H_TIME_ZERO, 102))
		else
			local H, M, S = "", "", ""
			local h = floor(nTime / 3600)
			local m = floor(nTime / 60) % 60
			local s = floor(nTime % 60)
			if h > 0 then
				H = h .. g_tStrings.STR_BUFF_H_TIME_H .. " "
			end
			if h > 0 or m > 0 then
				M = m .. g_tStrings.STR_BUFF_H_TIME_M_SHORT .. " "
			end
			S = s..g_tStrings.STR_BUFF_H_TIME_S
			if h < 720 then
				tinsert(t, XML_LINE_BREAKER)
				tinsert(t, GetFormatText(FormatString(g_tStrings.STR_BUFF_H_LEFT_TIME_MSG, H, M, S), 102))
			end
		end
	end

	-- For test
	if IsCtrlKeyDown() then
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText(g_tStrings.DEBUG_INFO_ITEM_TIP, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("ID:     " .. dwID, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("Level:  " .. nLevel, 102))
		tinsert(t, XML_LINE_BREAKER)
		tinsert(t, GetFormatText("IconID: " .. tostring(Table_GetBuffIconID(dwID, nLevel)), 102))
	end
	OutputTip(tconcat(t), 300, Rect)
end

---------------------------------------------------------------------
-- ���ظ����õļ��� Handle Ԫ�������
---------------------------------------------------------------------
local HandlePool = {}
HandlePool.__index = HandlePool
-- construct
function HandlePool:ctor(handle, xml)
	local oo = {}
	setmetatable(oo, self)
	oo.handle, oo.xml = handle, xml
	handle.nFreeCount = 0
	handle:Clear()
	return oo
end

-- clear
function HandlePool:Clear()
	self.handle:Clear()
	self.handle.nFreeCount = 0
end

-- new item
function HandlePool:New()
	local handle = self.handle
	local nCount = handle:GetItemCount()
	if handle.nFreeCount > 0 then
		for i = nCount - 1, 0, -1 do
			local item = handle:Lookup(i)
			if item.bFree then
				item.bFree = false
				handle.nFreeCount = handle.nFreeCount - 1
				return item
			end
		end
		handle.nFreeCount = 0
	else
		handle:AppendItemFromString(self.xml)
		local item = handle:Lookup(nCount)
		item.bFree = false
		return item
	end
end

-- remove item
function HandlePool:Remove(item)
	if item:IsValid() then
		self.handle:RemoveItem(item)
	end
end

-- free item
function HandlePool:Free(item)
	if item:IsValid() then
		self.handle.nFreeCount = self.handle.nFreeCount + 1
		item.bFree = true
		item:SetName("")
		item:Hide()
	end
end

function HandlePool:GetAllItem(bShow)
	local t = {}
	for i = self.handle:GetItemCount() - 1, 0, -1 do
		local item = self.handle:Lookup(i)
		if bShow and item:IsVisible() or not bShow then
			table.insert(t, item)
		end
	end
	return t
end
-- public api, create pool
-- (class) JH.HandlePool(userdata handle, string szXml)
JH.HandlePool = setmetatable({}, { __call = function(me, ...) return HandlePool:ctor( ... ) end, __metatable = true, __newindex = function() end })

---------------------------------------------------------------------
-- ���ص� UI �������
---------------------------------------------------------------------
local _GUI = {}
-------------------------------------
-- Base object class
-------------------------------------
_GUI.Base = class()

-- (userdata) Instance:Raw()		-- ��ȡԭʼ����/�������
function _GUI.Base:Raw()
	if self.type == "Label" then
		return self.txt
	end
	return self.wnd or self.edit or self.self
end

-- (void) Instance:Remove()		-- ɾ�����
function _GUI.Base:Remove()
	if self.fnDestroy then
		local wnd = self.wnd or self.self
		self.fnDestroy(wnd)
	end
	local hP = self.self:GetParent()
	if hP.___uis then
		local szName = self.self:GetName()
		hP.___uis[szName] = nil
	end
	if self.type == "WndFrame" then
		Wnd.CloseWindow(self.self)
	elseif ssub(self.type, 1, 3) == "Wnd" then
		self.self:Destroy()
	else
		hP:RemoveItem(self.self:GetIndex())
	end
end

-- (string) Instance:Name()					-- ȡ������
-- (self) Instance:Name(szName)			-- ��������Ϊ szName ������������֧�ִ��ӵ���
function _GUI.Base:Name(szName)
	if not szName then
		return self.self:GetName()
	end
	self.self:SetName(szName)
	return self
end

-- (self) Instance:Toggle([boolean bShow])			-- ��ʾ/����
function _GUI.Base:Toggle(bShow)
	if bShow == false or (not bShow and self.self:IsVisible()) then
		self.self:Hide()
	else
		self.self:Show()
		if self.type == "WndFrame" then
			self.self:BringToTop()
		end
	end
	return self
end

function _GUI.Base:IsVisible()
	return self.self:IsVisible()
end

function _GUI.Base:Point( ... )
	if self.type == "WndFrame" or self.type == "WndWindow" then
		local t = { ... }
		if IsEmpty(t) then
			self.self:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		else
			self.self:SetPoint( ... )
		end
	end
	return self
end

function _GUI.Base:RegisterClose(fnAction, bNotButton, bNotKeyDown)
	if self.type == "WndFrame" or self.type == "WndWindow" then
		if not bNotKeyDown then
			self.self.OnFrameKeyDown = function()
				if GetKeyName(Station.GetMessageKey()) == "Esc" then
					fnAction()
					return 1
				end
			end
		end
		if not bNotButton then
			self.self:Lookup("Btn_Close").OnLButtonClick = fnAction
		end
	end
	return self
end

-- (number, number) Instance:Pos()					-- ȡ��λ������
-- (self) Instance:Pos(number nX, number nY)	-- ����λ������
function _GUI.Base:Pos(nX, nY)
	if not nX then
		return self.self:GetRelPos()
	end
	self.self:SetRelPos(nX, nY)
	if self.type == "WndFrame" then
		self.self:CorrectPos()
	elseif ssub(self.type, 1, 3) ~= "Wnd" then
		self.self:GetParent():FormatAllItemPos()
	end
	return self
end

-- (number, number) Instance:Pos_()			-- ȡ�����½ǵ�����
function _GUI.Base:Pos_()
	local nX, nY = self:Pos()
	local nW, nH = self:Size()
	return nX + nW, nY + nH
end

-- (number, number) Instance:CPos_()			-- ȡ�����һ����Ԫ�����½�����
-- �ر�ע�⣺����ͨ�� :Append() ׷�ӵ�Ԫ����Ч���Ա����ڶ�̬��λ
function _GUI.Base:CPos_()
	local hP = self.wnd or self.self
	if not hP.___last and ssub(hP:GetType(), 1, 3) == "Wnd" then
		hP = hP:Lookup("", "")
	end
	if hP.___last then
		local ui = GUI.Fetch(hP, hP.___last)
		if ui then
			return ui:Pos_()
		end
	end
	return 0, 0
end

-- (class) Instance:Append(string szType, ...)	-- ��� UI �����
-- NOTICE��only for Handle��WndXXX
function _GUI.Base:Append(szType, ...)
	local hP = self.wnd or self.self
	if ssub(hP:GetType(), 1, 3) == "Wnd" and ssub(szType, 1, 3) ~= "Wnd" then
		hP.___last = nil
		hP = hP:Lookup("", "")
	end
	return GUI.Append(hP, szType, ...)
end

-- (class) Instance:Fetch(string szName)	-- �������ƻ�ȡ UI �����
function _GUI.Base:Fetch(szName)
	local hP = self.wnd or self.self
	local ui = GUI.Fetch(hP, szName)
	if not ui and self.handle then
		ui = GUI.Fetch(self.handle, szName)
	end
	return ui
end

-- (number, number) Instance:Align()
-- (self) Instance:Align(number nHAlign, number nVAlign)
function _GUI.Base:Align(nHAlign, nVAlign)
	local txt = self.edit or self.txt
	if txt then
		if not nHAlign and not nVAlign then
			return txt:GetHAlign(), txt:GetVAlign()
		else
			if nHAlign then
				txt:SetHAlign(nHAlign)
			end
			if nVAlign then
				txt:SetVAlign(nVAlign)
			end
		end
	end
	return self
end

-- (number) Instance:Font()
-- (self) Instance:Font(number nFont)
function _GUI.Base:Font(nFont)
	local txt = self.edit or self.txt
	if txt then
		if not nFont then
			return txt:GetFontScheme()
		end
		txt:SetFontScheme(nFont)
		if self.type == "WndEdit" then
			txt:SetSelectFontScheme(nFont)
		end
	end
	return self
end

-- (number, number, number) Instance:Color()
-- (self) Instance:Color(number nRed, number nGreen, number nBlue)
function _GUI.Base:Color(nRed, nGreen, nBlue)
	if self.type == "Shadow" then
		if not nRed then
			return self.self:GetColorRGB()
		end
		self.self:SetColorRGB(nRed, nGreen, nBlue)
	else
		local txt = self.edit or self.txt
		if txt then
			if not nRed then
				return txt:GetFontColor()
			end
			txt:SetFontColor(nRed, nGreen, nBlue)
			txt.col = { nRed, nGreen, nBlue }
		end
	end
	return self
end

-- (number) Instance:Alpha()
-- (self) Instance:Alpha(number nAlpha)
function _GUI.Base:Alpha(nAlpha)
	local txt = self.edit or self.txt or self.self
	if txt then
		if not nAlpha then
			return txt:GetAlpha()
		end
		txt:SetAlpha(nAlpha)
	end
	return self
end

function _GUI.Base:Event( ... )
	local t = { ... }
	for i = 1, select("#", ...) do
		if self.type == "WndFrame" then
			self.self:UnRegisterEvent(t[i])
		end
		self.self:RegisterEvent(t[i])
	end
	return self
end

------------------------------------------------

_GUI.Frame = class(_GUI.Base)

function _GUI.Frame:OnEvent(fnAction)
	if not self.event then
		self.event = { fnAction }
		self.self.OnEvent = function(szEvent)
			for k, v in ipairs(self.event) do
				v(szEvent)
			end
		end
	end
	for k, v in ipairs(self.event) do
		if v ~= fnAction then
			tinsert(self.event, fnAction)
			break
		end
	end
	return self
end

-- (string) Instance:Title()					-- ȡ�ô������
-- (self) Instance:Title(string szTitle)	-- ���ô������
function _GUI.Frame:Title(szTitle)
	local ttl = self.self:Lookup("", "Text_Title")
	if not szTitle then
		return ttl:GetText()
	end
	ttl:SetText(szTitle)
	return self
end

-- (boolean) Instance:Drag()						-- �жϴ����Ƿ������
-- (self) Instance:Drag(boolean bEnable)	-- ���ô����Ƿ������
function _GUI.Frame:Drag(bEnable)
	local frm = self.self
	if bEnable == nil then
		return frm:IsDragable()
	end
	frm:EnableDrag(bEnable == true)
	return self
end

-- (string) Instance:Relation()
-- (self) Instance:Relation(string szName)	-- Normal/Lowest ...
function _GUI.Frame:Relation(szName)
	local frm = self.self
	if not szName then
		return frm:GetParent():GetName()
	end
	frm:ChangeRelation(szName)
	return self
end

-- (userdata) Instance:Lookup(...)
function _GUI.Frame:Lookup(...)
	local wnd = self.wnd or self.self
	return self.wnd:Lookup(...)
end

-------------------------------------
-- Dialog frame
-------------------------------------
_GUI.Frm = class(_GUI.Frame)

-- constructor
function _GUI.Frm:ctor(szName, bEmpty)
	local frm, szIniFile = nil, ADDON_BASE_PATH .. "ui/WndFrame.ini"
	if bEmpty then
		szIniFile = ADDON_BASE_PATH .. "ui/WndFrameEmpty.ini"
	end
	if type(szName) == "string" then
		frm = Station.Lookup("Normal/" .. szName)
		if frm then
			Wnd.CloseWindow(frm)
		else
			PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		end
		frm = Wnd.OpenWindow(szIniFile, szName)
	else
		frm = Wnd.OpenWindow(szIniFile)
	end
	frm:Show()
	if not bEmpty then
		frm:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		frm:Lookup("Btn_Close").OnLButtonClick = function()
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
			Wnd.CloseWindow(frm)
		end
		frm.OnFrameKeyDown = function()
			if GetKeyName(Station.GetMessageKey()) == "Esc" then
				PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
				self:Remove()
				return 1
			end
		end
		self.wnd = frm:Lookup("Window_Main")
		self.handle = self.wnd:Lookup("", "")
	else
		self.handle = frm:Lookup("", "")
	end
	self.self, self.type = frm, "WndFrame"
end

-- (number, number) Instance:Size()						-- ȡ�ô����͸�
-- (self) Instance:Size(number nW, number nH)	-- ���ô���Ŀ�͸�
function _GUI.Frm:Size(nW, nH)
	local frm = self.self
	if not nW then
		return frm:GetSize()
	end
	local hnd = frm:Lookup("", "")
	-- empty frame
	if not self.wnd then
		frm:SetSize(nW, nH)
		hnd:SetSize(nW, nH)
		return self
	end
	-- set size
	frm:SetSize(nW, nH)
	frm:SetDragArea(0, 0, nW, 70)
	hnd:SetSize(nW, nH)
	hnd:Lookup("Image_BgT"):SetW(nW)
	hnd:Lookup("Image_BgCT"):SetW(nW - 32)
	hnd:Lookup("Image_BgLC"):SetH(nH - 149)
	hnd:Lookup("Image_BgCC"):SetSize(nW - 16, nH - 149)
	hnd:Lookup("Image_BgRC"):SetH(nH - 149)
	hnd:Lookup("Image_BgCB"):SetW(nW - 132)
	hnd:Lookup("Text_Title"):SetW(nW - 90)

	hnd:FormatAllItemPos()
	frm:Lookup("Btn_Close"):SetRelPos(nW - 35, 15)
	self.wnd:SetSize(nW, nH)
	self.wnd:Lookup("", ""):SetSize(nW, nH)
	-- reset position
	local an = GetFrameAnchor(frm)
	frm:SetPoint(an.s, 0, 0, an.r, an.x, an.y)
	return self
end

_GUI.Frm2 = class(_GUI.Frame)
-- constructor
function _GUI.Frm2:ctor(szName, bEmpty)
	local frm, szIniFile = nil, ADDON_BASE_PATH .. "ui/WndFrame2.ini"
	if bEmpty then
		szIniFile = ADDON_BASE_PATH .. "ui/WndFrameEmpty.ini"
	end
	if type(szName) == "string" then
		frm = Station.Lookup("Normal/" .. szName)
		if frm then
			Wnd.CloseWindow(frm)
		else
			PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		end
		frm = Wnd.OpenWindow(szIniFile, szName)
	else
		frm = Wnd.OpenWindow(szIniFile)
	end
	frm:Show()
	if not bEmpty then
		frm:SetPoint("CENTER", 0, 0, "CENTER", 0, 0)
		frm:Lookup("Btn_Close").OnLButtonClick = function()
			PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
			self:Remove()
		end
		frm.OnFrameKeyDown = function()
			if GetKeyName(Station.GetMessageKey()) == "Esc" then
				PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
				self:Remove()
				return 1
			end
		end
		self.wnd = frm:Lookup("Window_Main")
		self.handle = self.wnd:Lookup("", "")
	else
		self.handle = frm:Lookup("", "")
	end
	self.self, self.type = frm, "WndFrame"
end

function _GUI.Frm2:Size(nW, nH)
	local frm = self.self
	if not nW then
		return frm:GetSize()
	end
	local hnd = frm:Lookup("", "")
	-- empty frame
	if not self.wnd then
		frm:SetSize(nW, nH)
		hnd:SetSize(nW, nH)
		return self
	end
	-- set size
	frm:SetSize(nW, nH)
	frm:SetDragArea(0, 0, nW, 30)
	hnd:SetSize(nW, nH)
	hnd:Lookup("Shadow_Bg"):SetSize(nW, nH)
	hnd:Lookup("Shadow_Title"):SetW(nW)
	hnd:Lookup("Text_Title"):SetW(nW - 90)
	hnd:FormatAllItemPos()
	frm:Lookup("Btn_Close"):SetRelPos(nW - 28, 5)
	self.wnd:SetSize(nW, nH)
	self.wnd:Lookup("", ""):SetSize(nW, nH)
	-- reset position
	local an = GetFrameAnchor(frm)
	frm:SetPoint(an.s, 0, 0, an.r, an.x, an.y)
	return self
end

function _GUI.Frm2:Setting(fnAction)
	local wnd = self.self
	wnd:Lookup("Btn_Setting").OnLButtonClick = fnAction
	return self
end

function _GUI.Frm2:BackGround( ... )
	local shadow = self.self:Lookup("", "Shadow_Bg")
	local title  = self.self:Lookup("", "Shadow_Title")
	if ... then
		title:SetColorRGB( ... )
		shadow:SetColorRGB( ... )
		return self
	else
		return shadow:GetColorRGB()
	end

end

-------------------------------------
-- Window Component
-------------------------------------
_GUI.Wnd = class(_GUI.Base)

-- constructor
function _GUI.Wnd:ctor(pFrame, szType, szName)
	local wnd = nil
	if not szType and not szName then
		-- convert from raw object
		wnd, szType = pFrame, pFrame:GetType()
	else
		-- append from ini file
		local szFile = ADDON_BASE_PATH .. "ui/" .. szType .. ".ini"
		local frame = Wnd.OpenWindow(szFile, "GUI_Virtual")
		assert(frame, _L("Unable to open ini file [%s]", szFile))
		wnd = frame:Lookup(szType)
		assert(wnd, _L("Can not find wnd component [%s]", szType))
		wnd:SetName(szName)
		wnd:ChangeRelation(pFrame, true, true)
		Wnd.CloseWindow(frame)
	end
	if wnd then
		if string.find(szType, "WndButton") then
			szType = "WndButton"
		end
		self.type = szType
		self.edit = wnd:Lookup("Edit_Default")
		self.handle = wnd:Lookup("", "")
		self.self = wnd
		if self.handle then
			self.txt = self.handle:Lookup("Text_Default")
		end
		if szType == "WndTrackBar" then
			local scroll = wnd:Lookup("Scroll_Track")
			scroll.nMin, scroll.nMax, scroll.szText = 0, scroll:GetStepCount(), self.txt:GetText()
			scroll.nVal = scroll.nMin
			self.txt:SetText(scroll.nVal .. scroll.szText)
			scroll.OnScrollBarPosChanged = function()
				-- if (this.nMax - this.nMin) < this:GetStepCount() then
					this.nVal = this.nMin + (this:GetScrollPos() / this:GetStepCount()) * (this.nMax - this.nMin)
				-- else
				-- 	this.nVal = this.nMin + mceil((this:GetScrollPos() / this:GetStepCount()) * (this.nMax - this.nMin))
				-- end
				if this.OnScrollBarPosChanged_ then
					this.OnScrollBarPosChanged_(this.nVal)
				end
				self.txt:SetText(this.nVal .. this.szText)
			end
		end
	end
end

-- (number, number) Instance:Size()
-- (self) Instance:Size(number nW, number nH)
function _GUI.Wnd:Size(nW, nH)
	local wnd = self.self
	if not nW then
		local nW, nH = wnd:GetSize()
		if self.type == "WndRadioBox" or self.type == "WndCheckBox" or self.type == "WndTrackBar" then
			local xW, _ = self.txt:GetTextExtent()
			nW = nW + xW + 5
		end
		return nW, nH
	end
	if self.edit then
		wnd:SetSize(nW + 2, nH)
		self.handle:SetSize(nW + 2, nH)
		self.handle:Lookup("Image_Default"):SetSize(nW + 2, nH)
		self.edit:SetSize(nW - 3, nH)
	else
		wnd:SetSize(nW, nH)
		if self.handle then
			self.handle:SetSize(nW, nH)
			if self.type == "WndButton" or self.type == "WndTabBox" then
				self.txt:SetSize(nW, nH)
			elseif self.type == "WndComboBox" then
				self.handle:Lookup("Image_ComboBoxBg"):SetSize(nW, nH)
				local btn = wnd:Lookup("Btn_ComboBox")
				local hnd = btn:Lookup("", "")
				local bW, bH = btn:GetSize()
				btn:SetRelPos(nW - bW - 5, mceil((nH - bH)/2))
				hnd:SetAbsPos(self.handle:GetAbsPos())
				hnd:SetSize(nW, nH)
				self.txt:SetSize(nW - mceil(bW/2), nH)
			elseif self.type == "WndCheckBox" then
				local _, xH = self.txt:GetTextExtent()
				self.txt:SetRelPos(nW - 20, floor((nH - xH)/2))
			elseif self.type == "WndRadioBox" then
				local _, xH = self.txt:GetTextExtent()
				self.txt:SetRelPos(nW + 5, floor((nH - xH)/2))
				self.handle:FormatAllItemPos()
			elseif self.type == "WndTrackBar" then
				wnd:Lookup("Scroll_Track"):SetSize(nW, nH - 13)
				wnd:Lookup("Scroll_Track/Btn_Track"):SetH(nH - 13)
				self.handle:Lookup("Image_BG"):SetSize(nW, nH - 15)
				self.handle:Lookup("Text_Default"):SetRelPos(nW + 5, mceil((nH - 25)/2))
				self.handle:FormatAllItemPos()
			end
		end
	end
	return self
end

function _GUI.Wnd:Title(szTitle)
	local ttl = self.self:Lookup("", "Text_Title")
	if not szTitle then
		return ttl:GetText()
	end
	ttl:SetText(szTitle)
	return self
end

-- (boolean) Instance:Enable()
-- (self) Instance:Enable(boolean bEnable)
function _GUI.Wnd:Enable(bEnable)
	local wnd = self.edit or self.self
	local txt = self.edit or self.txt
	if bEnable == nil then
		if self.type == "WndButton" then
			return wnd:IsEnabled()
		end
		return self.enable ~= false
	end
	if bEnable then
		if self.type == "WndTrackBar" then
			wnd:Lookup("Scroll_Track/Btn_Track"):Enable(1)
		elseif self.type == "WndComboBox" then
			wnd:Lookup("Btn_ComboBox"):Enable(1)
		end
		wnd:Enable(1)
		if txt then
			if self.font then
				txt:SetFontScheme(self.font)
			end
			if txt.col then
				txt:SetFontColor(unpack(txt.col))
			end
		end
		self.enable = true
	else
		if self.type == "WndTrackBar" then
			wnd:Lookup("Scroll_Track/Btn_Track"):Enable(0)
		elseif self.type == "WndComboBox" then
			wnd:Lookup("Btn_ComboBox"):Enable(0)
		end
		wnd:Enable(0)
		if txt and self.enable ~= false then
			self.font = txt:GetFontScheme()
			txt:SetFontScheme(161)
		end
		self.enable = false
	end
	return self
end

-- (self) Instance:AutoSize([number hPad[, number vPad]])
function _GUI.Wnd:AutoSize(hPad, vPad)
	local wnd = self.self
	if self.type == "WndTabBox" or self.type == "WndButton" then
		local _, nH = wnd:GetSize()
		local nW, _ = self.txt:GetTextExtent()
		local nEx = self.txt:GetTextPosExtent()
		if hPad then
			nW = nW + hPad + hPad
		end
		if vPad then
			nH = nH + vPad + vPad
		end
		self:Size(nW + nEx + 16, nH)
	elseif self.type == "WndComboBox" then
		local bW, _ = wnd:Lookup("Btn_ComboBox"):GetSize()
		local nW, nH = self.txt:GetTextExtent()
		local nEx = self.txt:GetTextPosExtent()
		if hPad then
			nW = nW + hPad + hPad
		end
		if vPad then
			nH = nH + vPad + vPad
		end
		self:Size(nW + bW + 20, nH + 6)
	end
	return self
end

-- (boolean) Instance:Check()
-- (self) Instance:Check(boolean bCheck)
-- NOTICE��only for WndCheckBox
function _GUI.Wnd:Check(bCheck)
	local wnd = self.self
	if wnd:GetType() == "WndCheckBox" then
		if bCheck == nil then
			return wnd:IsCheckBoxChecked()
		end
		wnd:Check(bCheck == true)
	end
	return self
end

-- (string) Instance:Group()
-- (self) Instance:Group(string szGroup)
-- NOTICE��only for WndCheckBox
function _GUI.Wnd:Group(szGroup)
	local wnd = self.self
	if wnd:GetType() == "WndCheckBox" then
		if not szGroup then
			return wnd.group
		end
		wnd.group = szGroup
	end
	return self
end

-- (string) Instance:Url()
-- (self) Instance:Url(string szUrl)
-- NOTICE��only for WndWebPage
function _GUI.Wnd:Url(szUrl)
	local wnd = self.self
	if self.type == "WndWebPage" then
		if not szUrl then
			return wnd:GetLocationURL()
		end
		wnd:Navigate(szUrl)
	end
	return self
end

-- (number, number, number) Instance:Range()
-- (self) Instance:Range(number nMin, number nMax[, number nStep])
-- NOTICE��only for WndTrackBar
function _GUI.Wnd:Range(nMin, nMax, nStep)
	if self.type == "WndTrackBar" then
		local scroll = self.self:Lookup("Scroll_Track")
		if not nMin and not nMax then
			return scroll.nMin, scroll.nMax, scroll:GetStepCount()
		end
		if nMin then scroll.nMin = nMin end
		if nMax then scroll.nMax = nMax end
		if nStep then
			scroll:SetStepCount(nStep)
			-- scroll.SetDragStep(nStep)
		end
		self:Value(scroll.nVal)
	end
	return self
end

-- (number) Instance:Value()
-- (self) Instance:Value(number nVal)
-- NOTICE��only for WndTrackBar
function _GUI.Wnd:Value(nVal)
	if self.type == "WndTrackBar" then
		local scroll = self.self:Lookup("Scroll_Track")
		if not nVal then
			return scroll.nVal
		end
		scroll.nVal = mmin(mmax(nVal, scroll.nMin), scroll.nMax)
		local onChange = scroll.OnScrollBarPosChanged
		scroll.OnScrollBarPosChanged = nil
		scroll:SetScrollPos((scroll.nVal - scroll.nMin) / (scroll.nMax - scroll.nMin) * scroll:GetStepCount(), WNDEVENT_FIRETYPE.FORCE)
		scroll.OnScrollBarPosChanged = onChange
		self.txt:SetText(scroll.nVal .. scroll.szText)
	end
	return self
end

-- (string) Instance:Text()
-- (self) Instance:Text(string szText[, boolean bDummy])
-- bDummy		-- ��Ϊ true ������������ onChange �¼�
function _GUI.Wnd:Text(szText, bDummy)
	local txt = self.edit or self.txt
	if txt then
		if not szText then
			return txt:GetText()
		end
		if self.type == "WndTrackBar" then
			local scroll = self.self:Lookup("Scroll_Track")
			scroll.szText = szText
			txt:SetText(scroll.nVal .. scroll.szText)
		elseif self.type == "WndEdit" and bDummy then
			local fnChanged = txt.OnEditChanged
			txt.OnEditChanged = nil
			txt:SetText(szText)
			txt.OnEditChanged = fnChanged
		else
			txt:SetText(szText)
		end
		if self.type == "WndTabBox" then
			self:AutoSize()
		end
		if self.type == "WndCheckBox" or self.type == "WndRadioBox" then
			local nWidth, nHeight = txt:GetTextExtent()
			txt:SetSize(nWidth + 26, nHeight)
			self.handle:SetSize(nWidth + 26, nHeight)
			self.handle:FormatAllItemPos()
		end
	end
	return self
end

-- (boolean) Instance:Multi()
-- (self) Instance:Multi(boolean bEnable)
-- NOTICE: only for WndEdit
function _GUI.Wnd:Multi(bEnable)
	local edit = self.edit
	if edit then
		if bEnable == nil then
			return edit:IsMultiLine()
		end
		edit:SetMultiLine(bEnable == true)
	end
	return self
end

-- (number) Instance:Limit()
-- (self) Instance:Limit(number nLimit)
-- NOTICE: only for WndEdit
function _GUI.Wnd:Limit(nLimit)
	local edit = self.edit
	if edit then
		if not nLimit then
			return edit:GetLimit()
		end
		edit:SetLimit(nLimit)
	end
	return self
end
-- Autocomplete
function _GUI.Wnd:Autocomplete(fnTable, fnCallBack, fnRecovery, nMaxOption)
	if self.type == "WndEdit" then
		local wnd = self.edit
		local tab = {}
		local Autocomplete = function()
			local tList, tTab  = {}, {}
			local szText = this:GetText()
			szText = string.gsub(szText, "[%[%]]", "") -- ���� [xxx] Ϊ xxx
			if type(fnTable) == "function" then
				tTab = fnTable(szText)
			else
				tTab = fnTable
			end
			for k, v in ipairs(tTab) do
				local txt = type(v) ~= "table" and tostring(v) or v.bRichText and v.option or v.szOption
				if txt and wstring.find(txt, szText) and (txt ~= szText or type(v) == "table" and v.self) then
					table.insert(tList, v)
				elseif type(v) == "table" and v.bDevide then
					table.insert(tList, v)
				end
				if #tList > (nMaxOption or 15) then break end
			end

			if #tList == 0 or (#tList == 1 and ((type(tList[1]) == "table" and tList[1].szOption == szText) or tostring(tList[1]) == szText)) then
				if IsPopupMenuOpened() then
					Wnd.CloseWindow(GetPopupMenu())
				end
			else
				local menu = {}
				for k, v in ipairs(tList) do
					local t = {}
					if type(v) == "table" then
						t = v
					else
						t.szOption = v
					end
					t.fnAction = function()
						local txt = t.szOption
						if type(v) == "table" and v.bRichText then
							txt = v.option
						end
						wnd:SetText(txt)
						Wnd.CloseWindow(GetPopupMenu())
						if fnCallBack then
							local _this = this
							this = wnd
							fnCallBack(txt, type(v) == "table" and v.data) -- callback
							this = _this
						end
					end
					if fnRecovery then
						t.szLayer         = "ICON_RIGHTMOST"
						t.nFrame          = 86
						t.nMouseOverFrame = 87
						t.szIcon          = "ui/Image/UICommon/Feedanimials.uitex"
						t.fnClickIcon     = function()
							JH.Confirm(FormatString(g_tStrings.MSG_DELETE_NAME, t.szOption), function()
								local _this = this
								this = wnd
								fnRecovery(t.szOption) -- callback
								this = _this
								Wnd.CloseWindow(GetPopupMenu())
								Station.SetFocusWindow(wnd)
								return
							end)
						end
					end
					table.insert(menu, t)
				end
				local nX, nY = this:GetAbsPos()
				local nW, nH = this:GetSize()
				menu.nMiniWidth = nW
				menu.x = nX
				menu.y = nY + nH
				menu.bShowKillFocus = true
				menu.bDisableSound = true
				menu.fnAutoClose = function()
					local frame = Station.GetFocusWindow()
					if not frame or frame and frame:GetName() ~= "PopupMenuPanel" and frame:GetName() ~= wnd:GetName() then
						return true
					end
				end
				PopupMenu(menu)
				-- PopupMenu_ProcessHotkey("Down") -- ���ǲ��ӵĺ�
			end
			if fnCallBack then
				fnCallBack(szText)
			end
		end
		if not wnd.__Autocomplete then
			wnd.__Autocomplete = Autocomplete
			if wnd.OnEditChanged then
				local OnEditChanged = wnd.OnEditChanged
				wnd.OnEditChanged = function()
					this.__Autocomplete()
					OnEditChanged()
				end
			else
				wnd.OnEditChanged = wnd.__Autocomplete
			end
		else
			wnd.__Autocomplete = Autocomplete
		end
		wnd.OnSetFocus = function()
			this.OnEditChanged()
		end
		wnd.OnEditSpecialKeyDown = function()
			local szKey = GetKeyName(Station.GetMessageKey())
			if IsPopupMenuOpened() and PopupMenu_ProcessHotkey then
				if szKey == "Enter"
				or szKey == "Up"
				or szKey == "Down"
				or szKey == "Left"
				or szKey == "Right"
			then
					return PopupMenu_ProcessHotkey(szKey)
				end
			end
		end
		wnd.OnKillFocus = function() -- �������л�edit
			if IsPopupMenuOpened() then
				local frame = Station.GetFocusWindow()
				if frame and frame:GetName() ~= "PopupMenuPanel" then
					Wnd.CloseWindow(GetPopupMenu())
				end
			end
		end
	end
	return self
end

-- (self) Instance:Change()			-- �����༭���޸Ĵ�����
-- (self) Instance:Change(func fnAction)
-- NOTICE��only for WndEdit��WndTrackBar
function _GUI.Wnd:Change(fnAction)
	if self.type == "WndTrackBar" then
		self.self:Lookup("Scroll_Track").OnScrollBarPosChanged_ = fnAction
	elseif self.edit then
		local edit = self.edit
		if not fnAction then
			if edit.OnEditChanged then
				local _this = this
				this = edit
				edit.OnEditChanged()
				this = _this
			end
		else
			edit.OnEditChanged = function()
				if not this.bChanging then
					this.bChanging = true
					if this.__Autocomplete then
						this.__Autocomplete()
					end
					fnAction(this:GetText())
					this.bChanging = false
				end
			end
		end
	end
	return self
end

-- (self) Instance:Focus()
-- (self) Instance:Focus(func fnFocus[, func fnKillFocus])
-- NOTICE��only for WndWindow, WndEdit
function _GUI.Wnd:Focus(fnFocus, fnKillFocus)
	local wnd = self.self
	if self.type == "WndEdit" then
		wnd = self.edit
	end
	if type(fnFocus) == "function" then
		fnKillFocus = fnKillFocus or fnFocus
		wnd.OnSetFocus  = function() fnFocus(true) end
		wnd.OnKillFocus = function() fnKillFocus(false) end
	else
		Station.SetFocusWindow(wnd)
	end
	return self
end

-- (self) Instance:Menu(table menu)		-- ���������˵�
-- NOTICE��only for WndComboBox
function _GUI.Wnd:Menu(menu)
	if self.type == "WndComboBox" then
		local wnd = self.self
		self:Click(function()
			local _menu = nil
			local nX, nY = wnd:GetAbsPos()
			local nW, nH = wnd:GetSize()
			if type(menu) == "function" then
				_menu = menu()
			else
				_menu = menu
			end
			_menu.nMiniWidth = nW
			_menu.x = nX
			_menu.y = nY + nH
			PopupMenu(_menu)
		end)
	end
	return self
end

-- (self) Instance:Click()
-- (self) Instance:Click(func fnAction)	-- �����������󴥷�ִ�еĺ���
-- fnAction = function([bCheck])			-- ���� WndCheckBox �ᴫ�� bCheck �����Ƿ�ѡ
function _GUI.Wnd:Click(fnAction)
	local wnd = self.self
	if self.type == "WndComboBox" then
		wnd = wnd:Lookup("Btn_ComboBox")
	end
	if wnd:GetType() == "WndCheckBox" then
		if not fnAction then
			self:Check(not self:Check())
		else
			wnd.OnCheckBoxCheck = function()
				if wnd.group then
					local uis = this:GetParent().___uis or {}
					for _, ui in pairs(uis) do
						if ui:Group() == this.group and ui:Name() ~= this:GetName() then
							ui.bCanUnCheck = true
							ui:Check(false)
							ui.bCanUnCheck = nil
						end
					end
				end
				fnAction(true)
			end
			wnd.OnCheckBoxUncheck = function()
				if wnd.group and not self.bCanUnCheck then
					self:Check(true)
				else
					fnAction(false)
				end
			end
		end
	else
		if not fnAction then
			if wnd.OnLButtonClick then
				local _this = this
				this = wnd
				wnd.OnLButtonClick()
				this = _this
			end
		else
			wnd.OnLButtonClick = fnAction
		end
	end
	return self
end

-- (self) Instance:Hover(func fnEnter[, func fnLeave])	-- ����������������
-- fnEnter = function(true)		-- ������ʱ����
-- fnLeave = function(false)		-- ����Ƴ�ʱ���ã���ʡ����ͽ��뺯��һ��
function _GUI.Wnd:Hover(fnEnter, fnLeave)
	local wnd = self.self
	if self.type == "WndComboBox" then
		wnd = wnd:Lookup("Btn_ComboBox")
	end
	if wnd then
		fnLeave = fnLeave or fnEnter
		if fnEnter then
			wnd.OnMouseEnter = function() fnEnter(true) end
		end
		if fnLeave then
			wnd.OnMouseLeave = function() fnLeave(false) end
		end
	end
	return self
end

function _GUI.Wnd:Type(nType)
	if self.type == "WndEdit" then
		self.edit:SetType(nType)
	end
	return self
end

-------------------------------------
-- Handle Item
-------------------------------------
_GUI.Item = class(_GUI.Base)

-- xml string
_GUI.tItemXML = {
	["Text"]    = "<text>w=150 h=30 valign=1 font=162 </text>",
	["Image"]   = "<image>w=100 h=100 </image>",
	["Animate"] = "<Animate>w=100 h=100 </Animate>",
	["Box"]     = "<box>w=48 h=48 </box>",
	["Shadow"]  = "<shadow>w=15 h=15 </shadow>",
	["Handle"]  = "<handle>firstpostype=0 w=10 h=10</handle>",
	["Label"]   = "<handle>w=150 h=30 <text>name=\"Text_Label\" w=150 h=30 font=162 valign=1 </text></handle>",
}

-- construct
function _GUI.Item:ctor(pHandle, szType, szName)
	local hnd = nil
	if not szType and not szName then
		-- convert from raw object
		hnd, szType = pHandle, pHandle:GetType()
	else
		local szXml = _GUI.tItemXML[szType]
		if szXml then
			-- append from xml
			local nCount = pHandle:GetItemCount()
			pHandle:AppendItemFromString(szXml)
			hnd = pHandle:Lookup(nCount)
			if hnd then hnd:SetName(szName) end
		else
			-- append from ini
			hnd = pHandle:AppendItemFromIni(ADDON_BASE_PATH .. "ui/HandleItems.ini","Handle_" .. szType, szName)
		end
		assert(hnd, _L("Unable to append handle item [%s]", szType))
	end
	if szType == "BoxButton" then
		self.txt = hnd:Lookup("Text_BoxButton")
		self.img = hnd:Lookup("Image_BoxIco")
		hnd.OnItemMouseEnter = function()
			if not this.bSelected then
				this:Lookup("Image_BoxBg"):Hide()
				this:Lookup("Image_BoxBgOver"):Show()
			end
		end
		hnd.OnItemMouseLeave = function()
			if not this.bSelected then
				this:Lookup("Image_BoxBg"):Show()
				this:Lookup("Image_BoxBgOver"):Hide()
			end
		end
	elseif szType == "TxtButton" then
		self.txt = hnd:Lookup("Text_TxtButton")
		self.img = hnd:Lookup("Image_TxtBg")
		hnd.OnItemMouseEnter = function()
			self.img:Show()
		end
		hnd.OnItemMouseLeave = function()
			if not this.bSelected then
				self.img:Hide()
			end
		end
	elseif szType == "Label" then
		self.txt = hnd:Lookup("Text_Label")
	elseif szType == "Text" then
		self.txt = hnd
	elseif szType == "Image" then
		self.img = hnd
	end
	self.self, self.type = hnd, szType
	hnd:SetRelPos(0, 0)
	hnd:GetParent():FormatAllItemPos()
end

-- (number, number) Instance:Size()
-- (self) Instance:Size(number nW, number nH)
function _GUI.Item:Size(nW, nH)
	local hnd = self.self
	if not nW then
		local nW, nH = hnd:GetSize()
		if self.type == "Text" or self.type == "Label" then
			nW, nH = self.txt:GetTextExtent()
		end
		return nW, nH
	end
	hnd:SetSize(nW, nH)
	if self.type == "BoxButton" then
		local nPad = mceil(nH * 0.2)
		hnd:Lookup("Image_BoxBg"):SetSize(nW - 12, nH + 8)
		hnd:Lookup("Image_BoxBgOver"):SetSize(nW - 12, nH + 8)
		hnd:Lookup("Image_BoxBgSel"):SetSize(nW - 1, nH + 11)
		self.img:SetSize(nH - nPad, nH - nPad)
		self.img:SetRelPos(10, mceil(nPad / 2))
		self.txt:SetSize(nW - nH - nPad, nH)
		self.txt:SetRelPos(nH + 10, 0)
		hnd:FormatAllItemPos()
	elseif self.type == "TxtButton" then
		self.img:SetSize(nW, nH - 5)
		self.txt:SetSize(nW - 10, nH - 5)
	elseif self.type == "Label" then
		self.txt:SetSize(nW, nH)
	end
	return self
end

function _GUI.Item:AutoSize()
	self.self:AutoSize()
	return self
end

-- (self) Instance:Zoom(boolean bEnable)	-- �Ƿ����õ����Ŵ�
-- NOTICE��only for BoxButton
function _GUI.Item:Zoom(bEnable)
	local hnd = self.self
	if self.type == "BoxButton" then
		local bg = hnd:Lookup("Image_BoxBg")
		local sel = hnd:Lookup("Image_BoxBgSel")
		if bEnable == true then
			local nW, nH = bg:GetSize()
			sel:SetSize(nW + 11, nH + 3)
			sel:SetRelPos(1, -5)
		else
			sel:SetSize(bg:GetSize())
			sel:SetRelPos(5, -2)
		end
		hnd:FormatAllItemPos()
	end
	return self
end

-- (self) Instance:Select()		-- ����ѡ�е�ǰ��Ŧ��������Ч����
-- NOTICE��only for BoxButton��TxtButton
function _GUI.Item:Select()
	local hnd = self.self
	if self.type == "BoxButton" or self.type == "TxtButton" then
		local hParent, nIndex = hnd:GetParent(), hnd:GetIndex()
		local nCount = hParent:GetItemCount() - 1
		for i = 0, nCount do
			local item = GUI.Fetch(hParent:Lookup(i))
			if item and item.type == self.type then
				if i == nIndex then
					if not item.self.bSelected then
						hnd.bSelected = true
						hnd.nIndex = i
						if self.type == "BoxButton" then
							hnd:Lookup("Image_BoxBg"):Hide()
							hnd:Lookup("Image_BoxBgOver"):Hide()
							hnd:Lookup("Image_BoxBgSel"):Show()
							self.txt:SetFontScheme(168)
							local icon = hnd:Lookup("Image_BoxIco")
							local nW, nH = icon:GetSize()
							local nX, nY = icon:GetRelPos()
							icon:SetSize(nW + 6, nH + 6)
							icon:SetRelPos(nX - 3, nY - 3)
							hnd:FormatAllItemPos()
						else
							self.img:Show()
						end
					end
				elseif item.self.bSelected then
					item.self.bSelected = false
					if item.type == "BoxButton" then
						item.self:SetIndex(item.self.nIndex)
						if hnd.nIndex >= item.self.nIndex then
							hnd.nIndex = hnd.nIndex + 1
						end
						item.self:Lookup("Image_BoxBg"):Show()
						item.self:Lookup("Image_BoxBgOver"):Hide()
						item.self:Lookup("Image_BoxBgSel"):Hide()
						item.txt:SetFontScheme(163)
						local icon = item.self:Lookup("Image_BoxIco")
						local nW, nH = icon:GetSize()
						local nX, nY = icon:GetRelPos()
						icon:SetSize(nW - 6, nH - 6)
						icon:SetRelPos(nX + 3, nY + 3)
						item.self:FormatAllItemPos()
					else
						item.img:Hide()
					end
				end
			end
		end
		if hnd.nIndex then
			hnd:SetIndex(nCount)
		end
	end
	return self
end

-- (string) Instance:Text()
-- (self) Instance:Text(string szText)
function _GUI.Item:Text(szText)
	local txt = self.txt
	if txt then
		if not szText then
			return txt:GetText()
		end
		txt:SetText(szText)
	end
	return self
end
function _GUI.Item:Scale(fScale)
	local txt = self.txt
	if txt then
		if not fScale then
			return txt:GetFontScale()
		end
		txt:SetFontScale(fScale)
	end
	return self
end

-- (boolean) Instance:Multi()
-- (self) Instance:Multi(boolean bEnable)
-- NOTICE: only for Text��Label
function _GUI.Item:Multi(bEnable)
	local txt = self.txt
	if txt then
		if bEnable == nil then
			return txt:IsMultiLine()
		end
		txt:SetMultiLine(bEnable == true)
	end
	return self
end

-- (self) Instance:File(string szUitexFile, number nFrame)
-- (self) Instance:File(string szTextureFile)
-- (self) Instance:File(number dwIcon)
-- NOTICE��only for Image��BoxButton
function _GUI.Item:File(szFile, nFrame)
	local img = nil
	if self.type == "Image" then
		img = self.self
	elseif self.type == "BoxButton" then
		img = self.img
	end
	if self.type == "Box" then
		self.self:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		if type(szFile) == "number" then
			self.self:ClearExtentImage()
			self.self:SetObjectIcon(szFile)
		else
			self.self:ClearObjectIcon()
			self.self:SetExtentImage(szFile, nFrame)
		end
	else
		if img then
			if type(szFile) == "number" then
				img:FromIconID(szFile)
			elseif not nFrame then
				img:FromTextureFile(szFile)
			else
				img:FromUITex(szFile, nFrame)
			end
		end
	end
	return self
end
function _GUI.Item:Animate(szImage, nGroup, nLoopCount)
	if self.type == "Animate" then
		self.self:SetAnimate(szImage, nGroup, nLoopCount)
	end
	return self
end

-- (self) Instance:Type()
-- (self) Instance:Type(number nType)		-- �޸�ͼƬ���ͻ� BoxButton �ı�������
-- NOTICE��only for Image��BoxButton
function _GUI.Item:Type(nType)
	local hnd = self.self
	if self.type == "Image" then
		if not nType then
			return hnd:GetImageType()
		end
		hnd:SetImageType(nType)
	elseif self.type == "BoxButton" then
		if nType == nil then
			local nFrame = hnd:Lookup("Image_BoxBg"):GetFrame()
			if nFrame == 16 then
				return 2
			elseif nFrame == 18 then
				return 1
			end
			return 0
		elseif nType == 0 then
			hnd:Lookup("Image_BoxBg"):SetFrame(1)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(2)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(3)
		elseif nType == 1 then
			hnd:Lookup("Image_BoxBg"):SetFrame(18)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(19)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(22)
		elseif nType == 2 then
			hnd:Lookup("Image_BoxBg"):SetFrame(16)
			hnd:Lookup("Image_BoxBgOver"):SetFrame(17)
			hnd:Lookup("Image_BoxBgSel"):SetFrame(15)
		end
	end
	return self
end

-- (self) Instance:ToGray(bGray)
-- NOTICE��only for Box
function _GUI.Item:ToGray(bGray)
	if self.type == "Box" then
		if bGray then
			self.self:IconToGray()
		else
			self.self:IconToNormal()
		end
	end
	return self
end
-- (self) Instance:ItemInfo( ... )
-- NOTICE��only for Box
function _GUI.Item:ItemInfo( ... )
	if self.type == "Box" then
		local data = { ... }
		if IsEmpty(data) then
			UpdataItemBoxObject(self.self)
		else
			local KItemInfo = GetItemInfo(data[2], data[3])
			if KItemInfo.nGenre == ITEM_GENRE.BOOK and #data == 4 then -- ��ɽ��BUG
				table.insert(data, 4, 99999)
			end
			local res, err = pcall(UpdataItemInfoBoxObject, self.self, unpack(data)) -- ��ֹitemtab��һ��
			if not res then
				JH.Debug(err)
			end
		end
	end
	return self
end
function _GUI.Item:BoxInfo(nType, ...)
	if self.type == "Box" then
		if IsEmpty({ ... }) then
			UpdataItemBoxObject(self.self)
		else
			local res, err = pcall(UpdateBoxObject, self.self, nType, ...) -- ��ֹitemtab��������һ��
			if not res then
				JH.Debug(err)
			end
		end
	end
	return self
end
-- (self) Instance:Icon(number dwIcon)
-- NOTICE��only for Box��Image��BoxButton
function _GUI.Item:Icon(dwIcon)
	if self.type == "BoxButton" or self.type == "Image" then
		if type(dwIcon) == "number" then
			self.img:FromIconID(dwIcon)
		elseif type(dwIcon) == "table" then
			self.img:FromUITex(unpack(dwIcon))
		end
	elseif self.type == "Box" then
		self.self:SetObject(UI_OBJECT_NOT_NEED_KNOWN)
		self.self:SetObjectIcon(dwIcon)
	end
	return self
end

function _GUI.Item:OverText(nPos, szText, nOverTextIndex, nFontScheme)
	if self.type == "Box" then
		if nPos and szText then
			nOverTextIndex = nOverTextIndex or 0
			nFontScheme = nFontScheme or 15
			self.self:SetOverTextPosition(nOverTextIndex, nPos)
			self.self:SetOverTextFontScheme(nOverTextIndex, nFontScheme)
			self.self:SetOverText(nOverTextIndex, szText)
		else
			nPos = nPos or 0
			return self.self:GetOverText(nPos)
		end
	end
	return self
end

function _GUI.Item:Sparking(bSparking)
	if self.type == "Box" then
		self.self:SetObjectSparking(bSparking)
	end
	return self
end
function _GUI.Item:Staring(bStaring)
	if self.type == "Box" then
		self.self:SetObjectStaring(bStaring)
	end
	return self
end

function _GUI.Item:Percentage(fPercentage)
	if self.type == "Image" then
		if fPercentage then
			self.self:SetImageType(1)
			self.self:SetPercentage(fPercentage)
		else
			return self.self:GetPercentage()
		end
	end
	return self
end

function _GUI.Item:Type(nType)
	if self.type == "Image" then
		self.self:SetImageType(nType)
	elseif self.type == "Handle" then
		self.self:SetHandleStyle(nType)
	end
	return self
end

function _GUI.Item:Event(dwEventID)
	if dwEventID then
		self.self:RegisterEvent(dwEventID)
	else
		self.self:ClearEvent()
	end
	return self
end

function _GUI.Item:Clear()
	if self.type == "Handle" then
		self.self:Clear()
	end
	return self
end

function _GUI.Item:Enable(bEnable)
	if self.type == "Box" then
		if type(bEnable) ~= "nil" then
			self.self:EnableObject(bEnable)
		else
			return self.self:IsObjectEnable()
		end
	end
	return self
end

-- (self) Instance:Click()
-- (self) Instance:Click(func fnAction[, boolean bSound[, boolean bSelect]])	-- �Ǽ������������
-- (self) Instance:Click(func fnAction[, table tLinkColor[, tHoverColor]])		-- ͬ�ϣ�ֻ���ı�
function _GUI.Item:Click(fnAction, bSound, bSelect)
	local hnd = self.self
	hnd:RegisterEvent(0x10)
	if not fnAction then
		if hnd.OnItemLButtonClick then
			local _this = this
			this = hnd
			hnd.OnItemLButtonClick()
			this = _this
		end
	elseif self.type == "BoxButton" or self.type == "TxtButton" then
		hnd.OnItemLButtonClick = function()
			if bSound then PlaySound(SOUND.UI_SOUND, g_sound.Button) end
			if bSelect then self:Select() end
			fnAction()
		end
	else
		hnd.OnItemLButtonClick = fnAction
		-- text link��tLinkColor��tHoverColor
		local txt = self.txt
		if txt then
			local tLinkColor = bSound or { 255, 255, 0 }
			local tHoverColor = bSelect or { 255, 200, 100 }
			if bSound then
				txt:SetFontColor(unpack(tLinkColor))
			end
			if tHoverColor then
				self:Hover(function(bIn)
					if bSound then
						if bIn then
							txt:SetFontColor(unpack(tHoverColor))
						else
							txt:SetFontColor(unpack(tLinkColor))
						end
					end
				end)
			end
		end
	end
	return self
end

-- (self) Instance:Hover(func fnEnter[, func fnLeave])	-- ����������������
-- fnEnter = function(true)		-- ������ʱ����
-- fnLeave = function(false)		-- ����Ƴ�ʱ���ã���ʡ����ͽ��뺯��һ��
function _GUI.Item:Hover(fnEnter, fnLeave)
	local hnd = self.self
	hnd:RegisterEvent(0x100)
	fnLeave = fnLeave or fnEnter
	if fnEnter then
		hnd.OnItemMouseEnter = function() fnEnter(true) end
	end
	if fnLeave then
		hnd.OnItemMouseLeave = function() fnLeave(false) end
	end
	return self
end

---------------------------------------------------------------------
-- ������ API��GUI.xxx
---------------------------------------------------------------------
GUI = {}
setmetatable(GUI, { __call = function(me, ...) return me.Fetch(...) end, __metatable = true })

-- ����һ���յĶԻ�������棬������ GUI ��װ����
-- (class) GUI.CreateFrame([string szName, ]table tArg)
-- szName		-- *��ѡ* ���ƣ���ʡ�����Զ������
-- tArg {			-- *��ѡ* ��ʼ�����ò������Զ�������Ӧ�ķ�װ�������������Ծ���ѡ
--		w, h,			-- ��͸ߣ��ɶԳ�������ָ����С��ע���Ȼ��Զ����ͽ�����Ϊ��770/380/234���߶���С 200
--		x, y,			-- λ�����꣬Ĭ������Ļ���м�
--		title			-- �������
--		drag			-- ���ô����Ƿ���϶�
--		close		-- ����رհ�Ŧ���Ƿ������رմ��壨��Ϊ false �������أ�
--		empty		-- �����մ��壬����������ȫ͸����ֻ�ǽ�������
--		fnCreate = function(frame)		-- �򿪴����ĳ�ʼ��������frame Ϊ���ݴ��壬�ڴ���� UI
--		fnDestroy = function(frame)	-- �ر����ٴ���ʱ���ã�frame Ϊ���ݴ��壬���ڴ��������
-- }
-- ����ֵ��ͨ�õ�  GUI ���󣬿�ֱ�ӵ��÷�װ����
function GUI.CreateFrame(szName, tArg)
	if type(szName) == "table" then
		szName, tArg = nil, szName
	end
	tArg = tArg or {}
	local ui = tArg.nStyle == 2 and _GUI.Frm2.new(szName, tArg.empty == true) or _GUI.Frm.new(szName, tArg.empty == true)
	if tArg.focus then
		Station.SetFocusWindow(ui.self)
	end
	-- apply init setting
	if tArg.w and tArg.h then ui:Size(tArg.w, tArg.h) end
	if tArg.x and tArg.y then ui:Pos(tArg.x, tArg.y) end
	if tArg.title then ui:Title(tArg.title) end
	if tArg.drag ~= nil then ui:Drag(tArg.drag) end
	if tArg.close ~= nil then ui.self.bClose = tArg.close end
	if tArg.fnCreate then tArg.fnCreate(ui:Raw()) end
	if tArg.fnDestroy then ui.fnDestroy = tArg.fnDestroy end
	if tArg.parent then ui:Relation(tArg.parent) end
	ui:Point() -- fix Size
	return ui
end

-- �����մ���
function GUI.CreateFrameEmpty(szName, szParent)
	return GUI.CreateFrame(szName, { empty  = true, parent = szParent })
end

-- ��ĳһ��������������  INI �����ļ��еĲ��֣������� GUI ��װ����
-- (class) GUI.Append(userdata hParent, string szIniFile, string szTag, string szName)
-- hParent		-- �����������ԭʼ����GUI ������ֱ����  :Append ������
-- szIniFile		-- INI �ļ�·��
-- szTag			-- Ҫ��ӵĶ���Դ�����������ڵĲ��� [XXXX]������ hParent ƥ����� Wnd ���������
-- szName		-- *��ѡ* �������ƣ�����ָ��������ԭ����
-- ����ֵ��ͨ�õ�  GUI ���󣬿�ֱ�ӵ��÷�װ������ʧ�ܻ������ nil
-- �ر�ע�⣺�������Ҳ֧����Ӵ������
function GUI.AppendIni(hParent, szFile, szTag, szName)
	local raw = nil
	if hParent:GetType() == "Handle" then
		if not szName then
			szName = "Child_" .. hParent:GetItemCount()
		end
		raw = hParent:AppendItemFromIni(szFile, szTag, szName)
	elseif ssub(hParent:GetType(), 1, 3) == "Wnd" then
		local frame = Wnd.OpenWindow(szFile, "GUI_Virtual")
		if frame then
			raw = frame:Lookup(szTag)
			if raw and ssub(raw:GetType(), 1, 3) == "Wnd" then
				raw:ChangeRelation(hParent, true, true)
				if szName then
					raw:SetName(szName)
				end
			else
				raw = nil
			end
			Wnd.CloseWindow(frame)
		end
	end
	assert(raw, _L("Fail to add component [%s@%s]", szTag, szFile))
	return GUI.Fetch(raw)
end

-- ��ĳһ�������������� GUI ��������ط�װ����
-- (class) GUI.Append(userdata hParent, string szType[, string szName], table tArg)
-- hParent		-- �����������ԭʼ����GUI ������ֱ����  :Append ������
-- szType			-- Ҫ��ӵ�������ͣ��磺WndWindow��WndEdit��Handle��Text ������
-- szName		-- *��ѡ* ���ƣ���ʡ�����Զ������
-- tArg {			-- *��ѡ* ��ʼ�����ò������Զ�������Ӧ�ķ�װ�������������Ծ���ѡ�����û�������
--		w, h,			-- ��͸ߣ��ɶԳ�������ָ����С
--		x, y,			-- λ������
--		txt, font, multi, limit, align		-- �ı����ݣ����壬�Ƿ���У��������ƣ����뷽ʽ��0����1���У�2���ң�
--		color, alpha			-- ��ɫ����͸����
--		checked				-- �Ƿ�ѡ��CheckBox ר��
--		enable					-- �Ƿ�����
--		file, icon, type		-- ͼƬ�ļ���ַ��ͼ���ţ�����
--		group					-- ��ѡ���������
-- }
-- ����ֵ��ͨ�õ�  GUI ���󣬿�ֱ�ӵ��÷�װ������ʧ�ܻ������ nil
-- �ر�ע�⣺Ϊͳһ�ӿڴ˺���Ҳ������ AppendIni �ļ��������� GUI.AppendIni һ��
-- (class) GUI.Append(userdata hParent, string szIniFile, string szTag, string szName)
function GUI.Append(hParent, szType, szName, tArg)
	-- compatiable with AppendIni
	if StringFindW(szType, ".ini") ~= nil then
		return GUI.AppendIni(hParent, szType, szName, tArg)
	end
	-- reset parameters
	if not tArg and type(szName) == "table" then
		szName, tArg = nil, szName
	end
	if not szName then
		if not hParent.nAutoIndex then
			hParent.nAutoIndex = 1
		end
		szName = szType .. "_" .. hParent.nAutoIndex
		hParent.nAutoIndex = hParent.nAutoIndex + 1
	else
		szName = tostring(szName)
	end
	-- create ui
	local ui = nil
	if ssub(szType, 1, 3) == "Wnd" then
		assert(ssub(hParent:GetType(), 1, 3) == "Wnd", _L["The 1st arg for adding component must be a [WndXxx]"])
		ui = _GUI.Wnd.new(hParent, szType, szName)
	else
		assert(hParent:GetType() == "Handle", _L["The 1st arg for adding item must be a [Handle]"])
		ui = _GUI.Item.new(hParent, szType, szName)
	end
	local raw = ui:Raw()
	if raw then
		-- for reverse fetching
		hParent.___uis = hParent.___uis or {}
		for k, v in pairs(hParent.___uis) do
			if not v.self.___id then
				hParent.___uis[k] = nil
			end
		end
		hParent.___uis[szName] = ui
		hParent.___last = szName
		-- apply init setting
		tArg = tArg or {}
		if tArg.w and tArg.h then ui:Size(tArg.w, tArg.h) end
		if tArg.x and tArg.y then ui:Pos(tArg.x, tArg.y) end
		if tArg.font then ui:Font(tArg.font) end
		if tArg.multi ~= nil then ui:Multi(tArg.multi) end
		if tArg.limit then ui:Limit(tArg.limit) end
		if tArg.color then ui:Color(unpack(tArg.color)) end
		if tArg.align ~= nil then ui:Align(tArg.align) end
		if tArg.alpha then ui:Alpha(tArg.alpha) end
		if tArg.txt then ui:Text(tArg.txt) end
		if tArg.checked ~= nil then ui:Check(tArg.checked) end
		-- wnd only
		if tArg.enable ~= nil then ui:Enable(tArg.enable) end
		if tArg.group then ui:Group(tArg.group) end
		if ui.type == "WndComboBox" and (not tArg.w or not tArg.h) then
			ui:Size(185, 25)
		end
		-- item only
		if tArg.file then ui:File(tArg.file, tArg.num) end
		if tArg.icon ~= nil then ui:Icon(tArg.icon) end
		if tArg.type then ui:Type(tArg.type) end
		return ui
	end
end

-- (class) GUI(...)
-- (class) GUI.Fetch(hRaw)						-- �� hRaw ԭʼ����ת��Ϊ GUI ��װ����
-- (class) GUI.Fetch(hParent, szName)	-- �� hParent ����ȡ��Ϊ szName ����Ԫ����ת��Ϊ GUI ����
-- ����ֵ��ͨ�õ�  GUI ���󣬿�ֱ�ӵ��÷�װ������ʧ�ܻ������ nil
function GUI.Fetch(hParent, szName)
	if type(hParent) == "string" then
		hParent = Station.Lookup(hParent)
	end
	if not szName then
		szName = hParent:GetName()
		hParent = hParent:GetParent()
	end
	-- exists
	if hParent.___uis and hParent.___uis[szName] then
		local ui = hParent.___uis[szName]
		if ui and ui.self.___id then
			return ui
		end
	end
	-- convert
	local hRaw = hParent:Lookup(szName)
	if hRaw then
		local ui
		if ssub(hRaw:GetType(), 1, 3) == "Wnd" then
			ui = _GUI.Wnd.new(hRaw)
		else
			ui = _GUI.Item.new(hRaw)
		end
		hParent.___uis = hParent.___uis or {}
		hParent.___uis[szName] = ui
		return ui
	end
end

function GUI.RegisterPanel(szTitle, dwIcon, szClass, fn)
	local dwClass
	for k, v in ipairs(JH_PANEL_CLASS) do
		if szClass == v then
			dwClass = k
			break
		end
	end
	if not dwClass then
		table.insert(JH_PANEL_CLASS, szClass)
		dwClass = #JH_PANEL_CLASS
	end
	JH_PANEL_ADDON[dwClass] = JH_PANEL_ADDON[dwClass] or {}
	for k, v in ipairs(JH_PANEL_ADDON[dwClass]) do
		if v.szTitle == szTitle then
			return -- exist
		end
	end
	tinsert(JH_PANEL_ADDON[dwClass], {
		dwIcon  = dwIcon,
		szTitle = szTitle,
		fn      = fn,
		dwClass = dwClass,
	})
end

-- ����ѡ����
function GUI.OpenFontTablePanel(fnAction)
	local ui = GUI.CreateFrame("JH_FontTable", { w = 470, h = 370, title = g_tStrings.FONT, nStyle = 2 , close = true, focus = true }):BackGround(64, 64, 64)
	ui:Setting(function()
		GetUserInput(_L["Input Font ID"], function(szText)
			if tonumber(szText) and tonumber(szText) >= 0 and tonumber(szText) <= 236 then
				if fnAction then fnAction(tonumber(szText)) end
				ui:Remove()
			end
		end)
	end)
	local tFontList = LoadLUAData(ADDON_BASE_PATH .. "font/FontList.jx3dat")
	local tFont = {
		["0"] = g_tStrings.FONT_HEITI,
		["7"] = g_tStrings.FONT_JIANZHI,
		["8"] = g_tStrings.FONT_XINGKAI,
	}
	local handle = ui:Append("Handle", { x = 0, y = 40, w = 100, h = 300 })
	local function LoadFontList(szFont)
		local i = 0
		local txt = tFont[szFont]
		handle:Clear()
		table.sort(tFontList[szFont], function(a, b)
			if a.Size ~= b.Size then
				return a.Size < b.Size
			else
				return a.FontID < b.FontID
			end
		end)
		for k , v in ipairs(tFontList[szFont]) do
			handle:Append("Text", { x = (i % 7) * 68 + 10, y = floor(i / 7) * 35 + 15, color = { 255, 128, 0 } , txt = txt, font = v.FontID } ):AutoSize()
			:Click(function()
				if fnAction then fnAction(v.FontID) end
				ui:Remove()
			end):Hover(function(bHover)
				if bHover then
					this:SetFontColor(255, 255, 0)
					if IsCtrlKeyDown() then
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						OutputTip(GetFormatText(var2str(v, "    "), 41, 255, 255, 255), 300, { x, y, w, h })
					end
				else
					HideTip()
					this:SetFontColor(255, 128, 0)
				end
			end)
			i = i + 1
		end
	end
	local i = 0
	for k, v in pairs(tFont) do
		ui:Append("WndRadioBox", { x = i * 80 + 125, y = 10, txt = v , group = "font", checked = k == "0" }):Click(function()
			LoadFontList(k)
		end)
		i = i + 1
	end
	LoadFontList("0")
end

-- ��ɫ�� https://en.wikipedia.org/wiki/HSL_and_HSV
local COLOR_HUE = 0
function GUI.OpenColorTablePanel(fnAction)
	local fX, fY = Cursor.GetPos(true)
	local tUI = {}
	local function hsv2rgb(h, s, v)
		s = s / 100
		v = v / 100
		local r, g, b = 0, 0, 0
		local h = h / 60
		local i = floor(h)
		local f = h - i
		local p = v * (1 - s)
		local q = v * (1 - s * f)
		local t = v * (1 - s * (1 - f))
		if i == 0 or i == 6 then
			r, g, b = v, t, p
		elseif i == 1 then
			r, g, b = q, v, p
		elseif i == 2 then
			r, g, b = p, v, t
		elseif i == 3 then
			r, g, b = p, q, v
		elseif i == 4 then
			r, g, b = t, p, v
		elseif i == 5 then
			r, g, b = v, p, q
		end
		return floor(r * 255), floor(g * 255), floor(b * 255)
	end

	local ui = GUI.CreateFrame("JH_ColorTable", { w = 346, h = 430, title = _L["Color Picker"], nStyle = 2 , close = true, focus = true }):Pos(fX + 15, fY + 15)
	local GetRGBValue = function()
		for k, v in pairs({ "R", "G", "B" }) do
			local val = tonumber(ui:Fetch(v):Text())
			if val and val > 255 then
				ui:Fetch(v):Text(0, true)
			end
		end
		local r, g, b = tonumber(ui:Fetch("R"):Text()), tonumber(ui:Fetch("G"):Text(g)), tonumber(ui:Fetch("B"):Text(b))
		return r or 0, g or 0, b or 0
	end
	local fnChang = function()
		local r, g, b = GetRGBValue()
		ui:Fetch("Select"):Color(r, g, b)
		ui:Fetch("SURE"):Toggle(true)
	end

	local fnHover = function(bHover, r, g, b)
		if bHover then
			ui:Fetch("Select"):Color(r, g, b)
			for k, v in pairs({ R = r, G = g, B = b }) do
				ui:Fetch(k):Text(v, true)
			end
		else
			ui:Fetch("Select"):Color(255, 255, 255)
			for k, v in pairs({ "R", "G", "B" }) do
				if ui:Fetch(v) then ui:Fetch(v):Text("", true) end
			end
		end
	end
	local fnClick = function()
		if fnAction then fnAction(GetRGBValue()) end
		if not IsCtrlKeyDown() then ui:Remove() end
	end
	ui.self.OnItemMouseEnter = function()
		local r, g, b = this:GetColorRGB()
		fnHover(true, r, g, b)
		ui:Fetch("Select_Image"):Pos(this:GetRelPos()):Toggle(true)
		ui:Fetch("SURE"):Toggle(false)
	end
	ui.self.OnItemMouseLeave = function()
		local r, g, b = this:GetColorRGB()
		fnHover(false, r, g, b)
		ui:Fetch("Select_Image"):Pos(this:GetRelPos()):Toggle(false)
	end
	ui.self.OnItemLButtonClick = fnClick
	local handle = ui:Append("Handle", { w = 300, h = 300, x = 0, y = 0 }):Type(0):Raw()
	local function SetColor(bInit)
		for v = 100, 0, -2 do
			tUI[v] = tUI[v] or {}
			for s = 0, 100, 2 do
				local x = 20 + s * 3
				local y = 80 + (100 - v) * 3
				local r, g, b = hsv2rgb(COLOR_HUE, s, v)
				if not bInit then
					tUI[v][s]:SetColorRGB(r, g, b)
				else
					handle:AppendItemFromString("<shadow> w=6 h=6 EventID=272 </shadow>")
					local sha = handle:Lookup(handle:GetItemCount() - 1)
					sha:SetRelPos(x, y)
					sha:SetColorRGB(r, g, b)
					tUI[v][s] = sha
				end
			end
		end
		if bInit then
			handle:FormatAllItemPos()
		end
	end
	SetColor(true)
	local x, y = ui:Append("Text", { x = 50, y = 8, txt = "R" }):Pos_()
	x, y = ui:Append("WndEdit", "R", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()

	x, y = ui:Append("Text", { x = x + 5, y = 8, txt = "G" }):Pos_()
	x, y = ui:Append("WndEdit", "G", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()

	x, y = ui:Append("Text", { x = x + 5, y = 8, txt = "B" }):Pos_()
	x, y = ui:Append("WndEdit", "B", { x = x + 5, y = 10, w = 30, h = 25, limit = 3 }):Change(fnChang):Type(0):Pos_()
	ui:Append("WndButton2", "SURE", { x = x + 5, y = 10, txt = g_tStrings.STR_PLAYER_SURE }):Click(fnClick):Toggle(false)
	ui:Append("Image", "Select_Image", { w = 6, h = 6, x = 0, y = 0 }):File("ui/Image/Common/Box.Uitex", 9):Toggle(false)
	ui:Append("Shadow", "Select", { w = 25, h = 25, x = 20, y = 10, color = { 255, 255, 255 } })
	ui:Append("WndTrackBar", { x = 20, y = 35, h = 25, w = 270, txt = " H" }):Range(0, 360, 360):Value(COLOR_HUE):Change(function(nVal)
		COLOR_HUE = nVal
		SetColor()
	end)
	for i = 0, 360, 2 do
		ui:Append("Shadow", { x = 20 + (0.74 * i), y = 60, h = 10, w = 2, color = { hsv2rgb(i, 100, 100) } })
	end
end

local ICON_PAGE
-- iconѡ����
function GUI.OpenIconPanel(fnAction)
	local nMaxIocn, boxs, txts = 8587, {}, {}
	local ui = GUI.CreateFrame("JH_IconPanel", { w = 920, h = 650, title = _L["Icon Picker"], nStyle = 2 , close = true, focus = true })
	local function GetPage(nPage, bInit)
		if nPage == ICON_PAGE and not bInit then
			return
		end
		ICON_PAGE = nPage
		local nStart = (nPage - 1) * 144
		for i = 1, 144 do
			local x = ((i - 1) % 18) * 50 + 10
			local y = floor((i - 1) / 18) * 70 + 10
			if boxs[i] then
				local nIocn = nStart + i
				if nIocn > nMaxIocn then
					boxs[i]:Toggle(false)
					txts[i]:Toggle(false)
				else
					boxs[i]:Icon(-1)
					txts[i]:Text(nIocn):Toggle(true)
					JH.DelayCall(function()
						if mceil(nIocn / 144) == ICON_PAGE and boxs[i] then
							boxs[i]:Icon(nIocn):Toggle(true)
						end
					end)
				end
			else
				boxs[i] = ui:Append("Box", { w = 48, h = 48, x = x, y = y, icon = nStart + i}):Hover(function(bHover)
					this:SetObjectMouseOver(bHover)
				end):Click(function()
					if fnAction then
						fnAction(this:GetObjectIcon())
					end
					ui:Remove()
				end)
				txts[i] = ui:Append("Text", { w = 48, h = 20, x = x, y = y + 48, txt = nStart + i, align = 1 })
			end
		end
	end
	ui:Append("WndEdit", "Icon", { x = 730, y = 580, w = 50, h = 25 }):Type(0)
	ui:Append("WndButton2", { txt = g_tStrings.STR_HOTKEY_SURE, x = 800, y = 580 }):Click(function()
		local nIocn = tonumber(ui:Fetch("Icon"):Text())
		if nIocn then
			if fnAction then
				fnAction(nIocn)
			end
			ui:Remove()
		end
	end)
	ui:Append("WndTrackBar", { x = 10, y = 580, h = 25, w = 500, txt = " Page" }):Range(1, math.ceil(nMaxIocn / 144), math.ceil(nMaxIocn / 144) - 1):Value(ICON_PAGE or 21):Change(function(nVal)
		GetPage(nVal)
	end)
	GetPage(ICON_PAGE or 21, true)
end
--[[
do
	local t = {
		{ f = "i", t = "ID" },
		{ f = "s", t = "Name" },
		{ f = "s", t = "Title" },
		{ f = "s", t = "Model" },
		{ f = "s", t = "Kind" },
		{ f = "s", t = "CampRequire" },
		{ f = "s", t = "ForceID" },
		{ f = "s", t = "MoveMode" },
		{ f = "s", t = "Species" },
		{ f = "s", t = "DropClassID" },
		{ f = "s", t = "Level" },
		{ f = "s", t = "AdjustLevel" },
		{ f = "s", t = "Height" },
		{ f = "s", t = "TouchRange" },
		{ f = "s", t = "Intensity" },
		{ f = "s", t = "IsSelectable" },
		{ f = "s", t = "CanSeeLifeBar" },
		{ f = "s", t = "AlarmRange" },
		{ f = "s", t = "ReviveTime" },
		{ f = "s", t = "MaxLife" },
		{ f = "s", t = "LifeReplenish" },
		{ f = "s", t = "LifeReplenishPercent" },
		{ f = "s", t = "MaxMana" },
		{ f = "s", t = "ManaReplenish" },
		{ f = "s", t = "ManaReplenishPercent" },
		{ f = "s", t = "MaxRage" },
		{ f = "s", t = "WalkSpeed" },
		{ f = "s", t = "RunSpeed" },
		{ f = "s", t = "PhysicsAttackHit" },
		{ f = "s", t = "SolarMagicHit" },
		{ f = "s", t = "NeutralMagicHit" },
		{ f = "s", t = "LunarMagicHit" },
		{ f = "s", t = "PoisonMagicHit" },
		{ f = "s", t = "Dodge" },
		{ f = "s", t = "PhysicsCriticalStrike" },
		{ f = "s", t = "SolarCriticalStrike" },
		{ f = "s", t = "NeutralCriticalStrike" },
		{ f = "s", t = "LunarCriticalStrike" },
		{ f = "s", t = "PoisonCriticalStrike" },
		{ f = "s", t = "PhysicsDefenceMax" },
		{ f = "s", t = "PhysicsShieldBase" },
		{ f = "s", t = "SolarMagicDefence" },
		{ f = "s", t = "NeutralMagicDefence" },
		{ f = "s", t = "LunarMagicDefence" },
		{ f = "s", t = "PoisonMagicDefence" },
		{ f = "s", t = "NpcDialogID" },
		{ f = "s", t = "AIType" },
		{ f = "s", t = "AIParamTemplateID" },
		{ f = "s", t = "MeleeWeaponDamageBase" },
		{ f = "s", t = "MeleeWeaponDamageRand" },
		{ f = "s", t = "RangeWeaponDamageBase" },
		{ f = "s", t = "RangeWeaponDamageRand" },
		{ f = "s", t = "SkillID1" },
		{ f = "s", t = "SkillLevel1" },
		{ f = "s", t = "SkillInterval1" },
		{ f = "s", t = "SkillFirstInterval1" },
		{ f = "s", t = "SkillType1" },
		{ f = "s", t = "SkillRate1" },
		{ f = "s", t = "SkillAniFrame1" },
		{ f = "s", t = "SkillRestFrame1" },
		{ f = "s", t = "SkillID2" },
		{ f = "s", t = "SkillLevel2" },
		{ f = "s", t = "SkillInterval2" },
		{ f = "s", t = "SkillFirstInterval2" },
		{ f = "s", t = "SkillType2" },
		{ f = "s", t = "SkillRate2" },
		{ f = "s", t = "SkillAniFrame2" },
		{ f = "s", t = "SkillRestFrame2" },
		{ f = "s", t = "SkillID3" },
		{ f = "s", t = "SkillLevel3" },
		{ f = "s", t = "SkillInterval3" },
		{ f = "s", t = "SkillFirstInterval3" },
		{ f = "s", t = "SkillType3" },
		{ f = "s", t = "SkillRate3" },
		{ f = "s", t = "SkillAniFrame3" },
		{ f = "s", t = "SkillRestFrame3" },
		{ f = "s", t = "SkillID4" },
		{ f = "s", t = "SkillLevel4" },
		{ f = "s", t = "SkillInterval4" },
		{ f = "s", t = "SkillFirstInterval4" },
		{ f = "s", t = "SkillType4" },
		{ f = "s", t = "SkillRate4" },
		{ f = "s", t = "SkillAniFrame4" },
		{ f = "s", t = "SkillRestFrame4" },
		{ f = "s", t = "ThreatTime" },
		{ f = "s", t = "ThreatPercent" },
		{ f = "s", t = "OverThreatPercent" },
		{ f = "s", t = "Drop1" },
		{ f = "s", t = "Count1" },
		{ f = "s", t = "Drop2" },
		{ f = "s", t = "Count2" },
		{ f = "s", t = "Drop3" },
		{ f = "s", t = "Count3" },
		{ f = "s", t = "Drop4" },
		{ f = "s", t = "Count4" },
		{ f = "s", t = "RepresentID1" },
		{ f = "s", t = "RepresentID2" },
		{ f = "s", t = "RepresentID3" },
		{ f = "s", t = "RepresentID4" },
		{ f = "s", t = "RepresentID5" },
		{ f = "s", t = "RepresentID6" },
		{ f = "s", t = "RepresentID7" },
		{ f = "s", t = "RepresentID8" },
		{ f = "s", t = "RepresentID9" },
		{ f = "s", t = "RepresentID10" },
		{ f = "s", t = "CorpseDoodadID" },
		{ f = "s", t = "MoneyMin" },
		{ f = "s", t = "MoneyMax" },
		{ f = "s", t = "MoneyDropRate" },
		{ f = "s", t = "MapName" },
		{ f = "s", t = "MasterID" },
		{ f = "s", t = "CraftMasterID" },
		{ f = "s", t = "RaceClass" },
		{ f = "s", t = "CombatType" },
		{ f = "s", t = "IsSpecial" },
		{ f = "s", t = "JumpSpeed" },
		{ f = "s", t = "IdleDialog1" },
		{ f = "s", t = "IdleDialogRate1" },
		{ f = "s", t = "IdleDialog2" },
		{ f = "s", t = "IdleDialogRate2" },
		{ f = "s", t = "IdleDialog3" },
		{ f = "s", t = "IdleDialogRate3" },
		{ f = "s", t = "IdleDialogAfterQuest" },
		{ f = "s", t = "IdleDialogQuestID" },
		{ f = "s", t = "HasBank" },
		{ f = "s", t = "HasMailBox" },
		{ f = "s", t = "ScriptName" },
		{ f = "s", t = "MailOptionText" },
		{ f = "s", t = "BankOptionText" },
		{ f = "s", t = "SkillMasterOptionText" },
		{ f = "s", t = "CraftMasterOptionText" },
		{ f = "s", t = "ReputeID1" },
		{ f = "s", t = "ReputeValue1" },
		{ f = "s", t = "ReputeID2" },
		{ f = "s", t = "ReputeValue2" },
		{ f = "s", t = "ReputeID3" },
		{ f = "s", t = "ReputeValue3" },
		{ f = "s", t = "ReputeID4" },
		{ f = "s", t = "ReputeValue4" },
		{ f = "s", t = "Parry" },
		{ f = "s", t = "ParryValue" },
		{ f = "s", t = "Sense" },
		{ f = "s", t = "HitBase" },
		{ f = "s", t = "PursuitRange" },
		{ f = "s", t = "ShopRequireReputeLevel" },
		{ f = "s", t = "MasterRequireReputeLevel" },
		{ f = "s", t = "CraftMasterRequireReputeLevel" },
		{ f = "s", t = "BankRequireReputeLevel" },
		{ f = "s", t = "MailBoxRequireReputeLevel" },
		{ f = "s", t = "QuestRequireReputeLevel" },
		{ f = "s", t = "CanSeeName" },
		{ f = "s", t = "AIDefaultMode" },
		{ f = "s", t = "ImmunityMask" },
		{ f = "s", t = "DropNotQuestItemFlag" },
		{ f = "s", t = "_NormalDpsCof" },
		{ f = "s", t = "DailyQuestCycle" },
		{ f = "s", t = "DailyQuestOffset" },
		{ f = "s", t = "_Intensity" },
		{ f = "s", t = "_EquipLevel" },
		{ f = "s", t = "NpcExp" },
		{ f = "s", t = "ProgressID" },
		{ f = "s", t = "HasAuction" },
		{ f = "s", t = "AuctionOptionText" },
		{ f = "s", t = "AuctionRequireReputeLevel" },
		{ f = "s", t = "AchievementID" },
		{ f = "s", t = "CampLootPrestige" },
		{ f = "s", t = "Prestige" },
		{ f = "s", t = "CoinType1" },
		{ f = "s", t = "CoinAmount1" },
		{ f = "s", t = "Contribution" },
		{ f = "s", t = "Drop5" },
		{ f = "s", t = "Count5" },
		{ f = "s", t = "Drop6" },
		{ f = "s", t = "Count6" },
		{ f = "s", t = "Drop7" },
		{ f = "s", t = "Count7" },
		{ f = "s", t = "Drop8" },
		{ f = "s", t = "Count8" },
		{ f = "s", t = "Drop9" },
		{ f = "s", t = "Count9" },
		{ f = "s", t = "Drop10" },
		{ f = "s", t = "Count10" },
		{ f = "s", t = "SkillID5" },
		{ f = "s", t = "SkillID6" },
		{ f = "s", t = "SkillID7" },
		{ f = "s", t = "SkillID8" },
		{ f = "s", t = "SkillLevel5" },
		{ f = "s", t = "SkillLevel6" },
		{ f = "s", t = "SkillLevel7" },
		{ f = "s", t = "SkillLevel8" },
		{ f = "s", t = "SkillInterval5" },
		{ f = "s", t = "SkillFirstInterval5" },
		{ f = "s", t = "SkillInterval6" },
		{ f = "s", t = "SkillFirstInterval6" },
		{ f = "s", t = "SkillInterval7" },
		{ f = "s", t = "SkillFirstInterval7" },
		{ f = "s", t = "SkillInterval8" },
		{ f = "s", t = "SkillFirstInterval8" },
		{ f = "s", t = "SkillType5" },
		{ f = "s", t = "SkillType6" },
		{ f = "s", t = "SkillType7" },
		{ f = "s", t = "SkillType8" },
		{ f = "s", t = "SkillRate5" },
		{ f = "s", t = "SkillRate6" },
		{ f = "s", t = "SkillRate7" },
		{ f = "s", t = "SkillRate8" },
		{ f = "s", t = "SkillAniFrame5" },
		{ f = "s", t = "SkillAniFrame6" },
		{ f = "s", t = "SkillAniFrame7" },
		{ f = "s", t = "SkillAniFrame8" },
		{ f = "s", t = "SkillRestFrame5" },
		{ f = "s", t = "SkillRestFrame6" },
		{ f = "s", t = "SkillRestFrame7" },
		{ f = "s", t = "SkillRestFrame8" },
		{ f = "s", t = "GuardForceID" },
		{ f = "s", t = "HasTongRepertory" },
		{ f = "s", t = "TongRepertoryOptionText" },
		{ f = "s", t = "TongRepertoryRequireReputeLevel" },
		{ f = "s", t = "DynamicReviveMinTime" },
		{ f = "s", t = "KnockedBackRate" },
		{ f = "s", t = "KnockedDownRate" },
		{ f = "s", t = "KnockedOffRate" },
		{ f = "s", t = "RepulsedRate" },
		{ f = "s", t = "PullRate" },
		{ f = "s", t = "AddCampScore" },
		{ f = "s", t = "BattleFieldID" },
		{ f = "s", t = "BattleFieldSide" },
		{ f = "s", t = "ReputeLevel1" },
		{ f = "s", t = "ReputeLevel2" },
		{ f = "s", t = "ReputeLevel3" },
		{ f = "s", t = "ReputeLevel4" },
		{ f = "s", t = "LogLootFlag" },
		{ f = "s", t = "TitlePoint" },
		{ f = "s", t = "Train" },
		{ f = "s", t = "DropJustice" },
		{ f = "s", t = "DropExamPrint" },
		{ f = "s", t = "DropActivityAward" },
		{ f = "s", t = "ValidReputeLootBuff" },
		{ f = "s", t = "BuffReputeValue" },
		{ f = "s", t = "BuffReputeLevel" },
		{ f = "s", t = "HasGameCard" },
		{ f = "s", t = "GameCardSaleOptionText" },
		{ f = "s", t = "GameCardBuyOptionText" },
		{ f = "s", t = "GameCardOrderOptionText" },
		{ f = "s", t = "GameCardOrderBuyOptionText" },
		{ f = "s", t = "CounterStealth" },
		{ f = "s", t = "CounterStealthRange" },
		{ f = "s", t = "HasCubPackage" },
		{ f = "s", t = "CubPackageOptionText" },
		{ f = "s", t = "CubPackageRequireReputeLevel" },
		{ f = "s", t = "ForceDrop" },
		{ f = "s", t = "IndependentDrop" },
		{ f = "s", t = "IndependentDropCount" },
		{ f = "s", t = "IndependentDropType" },
		{ f = "s", t = "IsCostMana" },
		{ f = "s", t = "CriticalDamagePowerBase" },
		{ f = "s", t = "DisableSkillMove" },
		{ f = "s", t = "HideLevel" },
		{ f = "s", t = "DecreaseDamagePercent" },
		{ f = "s", t = "ReturnNotRecoveryBlood" },
		{ f = "s", t = "CanShareNpcKillByQuestEvent" },
		{ f = "s", t = "IdentityVisiableID" },
	}
	local tab = KG_Table.Load("Settings/NpcTemplate.tab", t)
	if tab then
		JH_NPC_TAB = {}
		local step = 500
		local count = tab:GetRowCount()
		for i = 1, math.ceil(count / step) do
			JH.DelayCall(function()
				for ii = 1 + (i - 1) * step, i * step do
					local line = tab:Search(ii)
					if line then
						JH_NPC_TAB[line.ID] = line.Name
					end
				end
				JH.Debug("Load Npc Name " .. i .."/" .. math.ceil(count / step))
			end, i * 1000)
		end
	end
end
]]
