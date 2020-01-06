-- @Author: Webster
-- @Date:   2015-06-06 13:17:37
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-06-06 13:59:54


local UI = 	{
	["Lowest"] = {
		["ActionBar1"]         = "����ݼ���",
		["ActionBar2"]         = "����ݼ���",
		["ActionBar3"]         = "�Զ����ݼ���һ",
		["ActionBar4"]         = "�Զ����ݼ�����",
		["CombatTextWnd"]      = "����ս����Ϣ",
		["FullScreenSFX"]      = "ȫ����Ч",
		["GlobalEventHandler"] = "GlobalEventHandler",
		["Hand"]               = "����ƶ�����",
		["Scene"]              = "ϵͳ��Ϸ����",
	},
	["Lowest1"] = {
		["ChatTitleBG"]  = "����Ƶ�����౳��",
		["MainBarPanel"] = "������ݼ�������",
	},
	["Lowest2"] = {
		["ChatPanel1"] = "�������Ƶ��1",
		["ChatPanel2"] = "�������Ƶ��2",
		["ChatPanel3"] = "�������Ƶ��3",
		["ChatPanel4"] = "�������Ƶ��4",
		["ChatPanel5"] = "�������Ƶ��5",
		["ChatPanel6"] = "�������Ƶ��6",
		["EditBox"]    = "������Ϣ�����",
	},
	["Normal"] = {
		["AnimationMgr"]        = "AnimationMgr",
		["BuffList"]            = "��������״̬�б�",
		["CampActiveTime"]      = "��Ӫ�ʱ��",
		["CampPanel"]           = "��Ӫʿ����",
		["CharacterPanel"]      = "����װ�����",
		["CraftPanel"]          = "��������",
		["DebuffList"]          = "�������״̬�б�",
		["DialoguePanel"]       = "NPC�Ի�����",
		["DurabilityPanel"]     = "װ���־���ʾ",
		["ExpLine"]             = "���ﾭ����",
		["GuildMainPanel"]      = "�����Ϣ���",
		["LootListExSingle"]    = "���Ӳ��_ʰȡ����",
		["MainMessageLine"]     = "��Ļ������Ϣ��",
		["Matrix"]              = "Matrix",
		["Player"]              = "����ͷ�����",
		["QuestAcceptPanel"]    = "�����ȡ�Ի���",
		["QuestPanel"]          = "����鿴���",
		["ReputationIntroduce"] = "������ϸ�������",
		["SprintPower"]         = "�Ṧ����ֵͼ��",
		["Teammate"]            = "�ٷ��Ŷ����",
		["TopMenu"]             = "��Ļ����ͼ��˵�",
		["Minimap"]             = "С��ͼ���",
		["SystemMenu_Left"]     = "��Ļ����ͼ��˵�",
		["SystemMenu_Right"]    = "��Ļ����ͼ��˵�",
		["DBM"]                 = "DBM_Core",
		["DBM_UI"]              = "DBM�������",
		["GKP"]                 = "���ż�¼",
		["TargetTarget"]        = "Ŀ���Ŀ�����",
	},
	["Normal1"] = {
		["GKP_Record"] = "GKP��¼���",
		["BL_UI"]      = "DBM_��ͨBUFF�б�",
		["CA_UI"]      = "DBM_���뱨��",
	},
	["Normal2"] = {
		["ST_UI"] = "DBM_����ʱ",
	},
	["Topmost"] = {
		["BreatheBar"]       = "BreatheBar",
		["LoginMotp"]        = "LoginMotp",

		["OTActionBar"]      = "������ʾ���",
		["TargetMark"]       = "�ٷ�Ŀ��ͷ�����",
	},
	["Topmost1"] = {
		["BattleTipPanel"]       = "ս����ʾ��Ϣ",
		["PopupMenuPanel"]       = "��Ϸ���е����˵�",
		["SceneCampTip"]         = "��Ӫ������ʾ��Ϣ",
		["TipPanel_Normal"]      = "��Ļ�ұ���ʾ��Ϣ",
		["TraceButton"]          = "��Ļ�Ҳ�˵�ͼ��",
	},
	["Topmost2"] = {
		["Announce"]        = "ϵͳ�������ʾ����",
		["EnterAreaTip"]    = "EnterAreaTip",
		["GMAnnouncePanel"] = "ϵͳ�������������",
		["LoadingPanel"]    = "��Ϸ���ؽ���",
	}
}

local function GetMeun(ui)
	local menu, frames = { szOption = ui }, {}
	local frame = Station.Lookup(ui):GetFirstChild()
	while frame do
		table.insert(frames, { szName = frame:GetName() })
		frame = frame:GetNext()
	end
	table.sort(frames, function(a, b) return a.szName < b.szName end)
	for k, v in ipairs(frames) do
		local frame = Station.Lookup(ui .. "/" .. v.szName)
		table.insert(menu, {
			szOption = UI[ui][v.szName] and v.szName .. "��" .. UI[ui][v.szName]  .. "��" or  v.szName,
			bCheck = true,
			bChecked = frame:IsVisible(),
			rgb = frame:IsAddOn() and { 255, 255, 255 } or { 255, 255, 0 },
			fnAction = function()
				if frame:IsVisible() then
					frame:Hide()
				else
					frame:Show()
				end
				if IsCtrlKeyDown() then
					Wnd.CloseWindow(frame)
				end
			end
		})
	end
	return menu
end

TraceButton_AppendAddonMenu({function()
	local menu = { szOption = 'KG_UIManager' }
	for k, v in ipairs({ "Lowest", "Lowest1", "Lowest2", "Normal", "Normal1", "Normal2", "Topmost", "Topmost1", "Topmost2" })do
		table.insert(menu, GetMeun(v))
	end
	return {menu}
end})
