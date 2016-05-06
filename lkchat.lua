-- localize globals
local string = string;
local math = math;
local table = table;

-- TODO: Move to LIB ipf
-- global utility functions
_G["printc"] = function(text)
	ui.SysMsg(text);
	--LKChat.OnDebugMessage(text);
end

if not _G["math"].clamp then
	_G["math"].clamp = function(num,min,max)
		return math.max(math.min(num, max), min);
	end
end

-- Globals
_G["LKChat"] = {};
local LKChat = _G["LKChat"];
local PRIVATE = {};
--local L = setmetatable({ region = "kr",  = {}, }, {__index = function(k,v) return v end });

LKChat._version = "Alpha v0.5c";

-- Constants
local TYPE_INT = 0;
local TYPE_STRING = 1;
local TYPE_BOOL = 2;

local THEME_BUBBLE = 0;
local THEME_LINE = 1;

local SEARCH_FIND = "find";
local SEARCH_MATCH = "match";

local FRIEND_LOGIN = "%s has come online.";
local FRIEND_LOGOFF = "%s has gone offline.";

local g_LineChatFormat = {
	"{#%s}[%s] [%s]: %s",				-- Default
	"{#FF777777}%s {#%s}[%s] [%s]: %s", -- Timestamp
};

local g_ItemGradeColors = setmetatable({
	"#051505",	-- Common
	"#050515",	-- Uncommon?
	"#151505",	-- Rare
	"#FFFF00",	-- Epic
	"#FF0000",	-- Legendary
}, {__index = function() return "#FFFFFF" end });

local g_DefaultChatColors = {
	-- Chat Channels
	["Normal"] = {
		["Default"] = "FFFFFFFF",
		["Player"] = "FFFFE86A",
		["Friend"] = "FFFFFFFF",
		["GM"] = "FFE0B0FF",
	},
	["Whisper"] = {
		["Default"] = "FFB4DDEF",
		["Player"] = "FF7CD8FF",
		["Friend"] = "FFFFFFFF",
		["GM"] = "FF9F00FF",
	},
	["Shout"] = {
		["Default"] = "FFFFA800",
		["Player"] = "FFFF7C0f",
		["Friend"] = "FFFFFFFF",
		["GM"] = "FF9F00FF",
	},
	["Party"] = {
		["Default"] = "FFBCEB89",
		["Player"] = "FF93C95A",
		["Friend"] = "FFFFFFFF",
		["GM"] = "FFDA70D6",
	},
	["Guild"] = {
		["Default"] = "FFBE80CE",
		["Player"] = "FFA735DC",
		["Friend"] = "FFFFFFFF",
		["GM"] = "FF7F00FF",
	},
	["System"] = {
		["Default"] = "FFFFFFFF",
	},
	
	-- Special
	["SpamNotice"] = {
		["Default"] = "FFFF5A36",
	},
};

local g_UncheckedChannels = {
	"System",
	"Guild",
	"Party",
};

local g_RegExList = {
	"[3vw]-%s*[vw]-%s*[vw]-%s*[vw]-%s*[,%.%-]+%s*.+%s*[,%.%-]+%s*c%s*[o0%(%)]-%s*[nm]", -- improved greedy spam url detection, catches nearly any url by bot spammers
	--"[%s3vw]+[,%.%-]+%s*.*%s*[,%.%-]+%s*c%s*[o0]%s*[nm]%s*", -- DemiImp's improved greedy spam url detection, modified [UNTESTED]
	--"[%s3vw]*[,%.]%s*.*%s*[,%.]%s*c%s*[o0]%s*[nm]%s*", -- DemiImp's improved greedy spam url detection
};

local g_BotSpamPatterns = {
	-- find
	{ pattern = "sell",				type = SEARCH_FIND,	weight = 1 },
	{ pattern = "usd",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "eur",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "daum",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "cheap",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "fast",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "f@st",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "offer",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "qq",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "delivery",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "silver",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "s1lver",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "gold",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "g0ld",				type = SEARCH_FIND, weight = 1 },
	{ pattern = "powerleveling",	type = SEARCH_FIND, weight = 1 },
	{ pattern = "p0wer1eve1ing",	type = SEARCH_FIND, weight = 1 },
	{ pattern = "mmoceo",			type = SEARCH_FIND, weight = 1 },
	{ pattern = "m-m-o-c-e-o",		type = SEARCH_FIND, weight = 2 },
	
	-- match
	{ pattern = "%d+k=%d+%$",		type = SEARCH_MATCH, weight = 2 },	-- 100k=1$
};

-- Lookup table
local g_UserKeySettings = {
	["LKCHAT_THEME"]			= { name = "Theme", type = TYPE_INT, default = 0, min = 0, max = 1 },
	["LKCHAT_FONTSIZE"]			= { name = "FontSize", type = TYPE_INT, default = 16, min = 10, max = 40 },
	["LKCHAT_TRANSPARENCY"]		= { name = "Transparency", type = TYPE_INT, default = 255, min = 0, max = 255 },
	["LKCHAT_SHOWTICKER"]		= { name = "ShowTicker", type = TYPE_INT, default = 0, min = 0, max = 1 },
	["LKCHAT_TIMESTAMP"]		= { name = "TimeStamp", type = TYPE_INT, default = 1, min = 0, max = 1 },
	["LKCHAT_AUTOHIDE"]			= { name = "AutoHide", type = TYPE_INT, default = 0, min = 0, max = 1 },
	
	["LKCHAT_ANTISPAM"]			= { name = "AntiSpam", type = TYPE_INT, default = 1, min = 0, max = 1 },
	["LKCHAT_ANTISPAMNOTICE"]	= { name = "AntiSpamNotice", type = TYPE_INT, default = 1, min = 0, max = 1 },
	["LKCHAT_AUTOREPORT"]		= { name = "ReportAutoBot", type = TYPE_INT, default = 0, min = 0, max = 1 },
	
	["LKCHAT_DISPLAYFPS"]		= { name = "DisplayFPS", type = TYPE_INT, default = 1, min = 0, max = 1 },
};

-- Variables
local g_Region;
local g_PlayerFamilyName;
local g_Settings = {};
local g_RegisteredSlashCommands = {};
local g_FriendWhiteList = {};
local g_FriendLoginState = {};
--local g_PauseMessages = false;
local g_PendingMessages = {};
local g_SessionIgnoreUser = {};

local g_LastChatIndex = 0;
local g_MessageBoxPosition = {};	-- used with chat generation

-- UI Events
function LKCHAT_ON_INIT(addon, frame)
	if not LKChat.hasLoaded then
		LKChat.addon = addon;
		addon:RegisterMsg("GAME_START", "LKCHAT_ON_GAME_START");
		addon:RegisterMsg("GAME_START_3SEC", "LKCHAT_ON_GAME_START_DELAY");
		--addon:RegisterMsg('START_LOADING', 'LKCHAT_ON_START_LOADING');
		--addon:RegisterMsg('START_LOADING', "LKCHAT_ON_LOADING");
		addon:RegisterOpenOnlyMsg("ADD_FRIEND", "LKCHAT_ON_UPDATE_FRIENDLIST");
		addon:RegisterOpenOnlyMsg("REMOVE_FRIEND", "LKCHAT_ON_UPDATE_FRIENDLIST");
		addon:RegisterOpenOnlyMsg("UPDATE_FRIEND_LIST", "LKCHAT_ON_UPDATE_FRIENDLIST");
		
		LKChat.SetAPIHooks();
		LKChat.OnInit(frame);
		PRIVATE.RefreshFriendList();
	end
end

function LKCHAT_ON_GAME_START(frame)
	-- Refresh on channel change or zone change
	LKChat.RefreshSettings(frame);
	PRIVATE.DisplayFPS();
	
	--g_PauseMessages = false;
	--if #g_PendingMessages > 0 then
	--	for i = 1, #g_PendingMessages do
	--		local pending = g_PendingMessages[i];
	--		LKChat.OnChatMessage(pending.groupBoxName, pending.size, pending.startIndex, nil);
	--	end
	--	g_PendingMessages = {};
	--end
end

function LKCHAT_ON_GAME_START_DELAY(frame)
	-- Refresh on channel change or zone change
	LKChat.RefreshSettings(frame);
	PRIVATE.DisplayFPS();
end

function LKCHAT_ON_START_LOADING(frame)
	--g_PauseMessages = true;
end

--function LKCHAT_ON_LOADING(frame)

--end

function LKCHAT_ON_OPEN(frame)
	PRIVATE.SetVersion(frame);

	LKChat.RefreshSettings(frame);
end

function LKCHAT_ON_CLOSE(frame)

end

function LKCHAT_ON_UPDATE_FRIENDLIST()
	PRIVATE.RefreshFriendList();
end

function LKCHAT_ON_CHANGE_THEME(frame, ctrl, str, num)
	local w_THEME = tolua.cast(ctrl, "ui::CDropList");
	
	local themeIndex = w_THEME:GetSelItemIndex();
	LKChat.SetConfigByKey("LKCHAT_THEME", themeIndex);
end

function LKCHAT_ON_RIGHTCLICK_CHAT(frame, chatCtrl)
	LKChat.OnRightClickMessage(frame, chatCtrl);
end

function LKCHAT_ON_SLIDE_FONTSIZE(frame, ctrl, str, num)
	local w_SLIDE = tolua.cast(ctrl, "ui::CSlideBar");
	local size = w_SLIDE:GetLevel();
	
	local w_PARENT = ctrl:GetParent();
	local w_LABEL = GET_CHILD(w_PARENT, "label_FontSize", "ui::CRichText");
	w_LABEL:SetTextByKey("size", size);
	
	LKChat.SetConfigByKey("LKCHAT_FONTSIZE", size);
end

function LKCHAT_ON_SLIDE_OPACITY(frame, ctrl, str, num)
	local w_SLIDE = tolua.cast(ctrl, "ui::CSlideBar");
	local value = w_SLIDE:GetLevel();
	
	local w_PARENT = ctrl:GetParent();
	local w_LABEL = GET_CHILD(w_PARENT, "label_Transparency", "ui::CRichText");
	w_LABEL:SetTextByKey("pct", string.format("%0.f%%", (value / 255) * 100));
	
	LKChat.SetConfigByKey("LKCHAT_TRANSPARENCY", value);
	
	CHAT_SET_OPACITY(value);
end

function LKCHAT_ON_CHECKBOX_TIMESTAMP(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_TIMESTAMP", isChecked);
end

function LKCHAT_ON_CHECKBOX_AUTOHIDECHAT(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_AUTOHIDE", isChecked);
end

function LKCHAT_ON_CHECKBOX_SPAMDETECTION(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_ANTISPAM", isChecked);
end

function LKCHAT_ON_CHECKBOX_SPAMNOTICE(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_ANTISPAMNOTICE", isChecked);
end

function LKCHAT_ON_CHECKBOX_AUTOREPORT(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_AUTOREPORT", isChecked);
end


function LKCHAT_ON_CHECKBOX_DISPLAYFPS(frame, obj, argStr, argNum)
	local w_CHECKBOX = tolua.cast(obj, "ui::CCheckBox");
	
	local isChecked = w_CHECKBOX:IsChecked();
	LKChat.SetConfigByKey("LKCHAT_DISPLAYFPS", isChecked);
	
	PRIVATE.DisplayFPS();
end

-- Initialize
function LKChat.OnInit(frame)
	g_Region = config.GetServiceNation();	-- if this becomes popular enough, may need a korean translation
	g_PlayerFamilyName = GETMYFAMILYNAME();

	PRIVATE.SetVersion(frame);

	LKChat.RefreshSettings(frame);
	
	LKChat.RegisterSlashCommands();
	
	LKChat.hasLoaded = true;
	printc(string.format("LKChat Loaded:{nl}Hello %s.", g_PlayerFamilyName));
end

function LKChat.SetAPIHooks()
	-- Override Hooks
	_G["UI_CHAT"] = LKChat.OnSendMessage;
	_G["DRAW_CHAT_MSG"] = LKChat.OnChatMessage;
	_G["CHAT_OPEN_OPTION"] = function()
		ui.ToggleFrame('lkchat');
		PRIVATE.HideInput();
	end;
	
	-- Local Hooks
	LKChat.Hooks = {};
	--LKChat.Hooks.FPS_ON_INIT = _G["FPS_ON_INIT"];
	--_G["FPS_ON_INIT"] = function(addon, frame)
	--	LKChat.Hooks.FPS_ON_INIT(addon, frame);
	--	PRIVATE.DisplayFPS();
	--end
end

function LKChat.RefreshSettings(frame)
	LKChat.RefreshAllStoredUserValues();
	
	LKChat.InitializeSettings(frame);
	LKChat.InitializeCombatLog(frame);
	
	PRIVATE.RefreshFriendList();
end

function LKChat.SetConfigByKey(key, value)
	if g_UserKeySettings[key] then
		local name = g_UserKeySettings[key].name;
		g_Settings[name] = value;
		config.SetConfig(key, value);
	else
		printc(key.." is an invalid setting key.");
	end
end

function LKChat.InitializeSettings(frame)
	local w_GROUP_SETTINGS = GET_CHILD(frame, "gbox_settings", "ui::CGroupBox");
	local w_GROUP_CHATDISPLAY = GET_CHILD(w_GROUP_SETTINGS, "gbox_ChatDisplay", "ui::CGroupBox");
	local w_GROUP_ANTISPAM = GET_CHILD(w_GROUP_SETTINGS, "gbox_AntiSpam", "ui::CGroupBox");
	
	-- Chatbox
	
	-- Theme Dropdown List
	local w_DROPLISTTHEME = GET_CHILD(w_GROUP_CHATDISPLAY, "droplist_Theme", "ui::CDropList");
	w_DROPLISTTHEME:ClearItems();
	w_DROPLISTTHEME:AddItem(0, "Bubble");
	if g_PlayerFamilyName == "CitrusKingdom" then
		w_DROPLISTTHEME:AddItem(1, "Simple");
	end
	-- Load stored theme
	w_DROPLISTTHEME:SelectItem(LKChat.GetConfigByKey("LKCHAT_THEME"));
	
	-- Font Size
	local w_SLIDERFONTSIZE = GET_CHILD(w_GROUP_CHATDISPLAY, "slider_FontSize", "ui::CSlideBar");
	w_SLIDERFONTSIZE:SetLevel(LKChat.GetConfigByKey("LKCHAT_FONTSIZE"));
	local w_LABELFONTSIZE = GET_CHILD(w_GROUP_CHATDISPLAY, "label_FontSize", "ui::CRichText");
	w_LABELFONTSIZE:SetTextByKey("size", LKChat.GetConfigByKey("LKCHAT_FONTSIZE"));
	
	-- Transparency
	local w_SLIDER_TRANSPARENCY = GET_CHILD(w_GROUP_CHATDISPLAY, "slider_Transparency", "ui::CSlideBar");
	w_SLIDER_TRANSPARENCY:SetLevel(LKChat.GetConfigByKey("LKCHAT_TRANSPARENCY"));
	local w_LABEL_TRANSPARENCY = GET_CHILD(w_GROUP_CHATDISPLAY, "label_Transparency", "ui::CRichText");
	w_LABEL_TRANSPARENCY:SetTextByKey("pct", string.format("%0.f%%", (LKChat.GetConfigByKey("LKCHAT_TRANSPARENCY") / 255) * 100));
	CHAT_SET_OPACITY(LKChat.GetConfigByKey("LKCHAT_TRANSPARENCY"));
	
	-- Timestamp
	local w_CHECKBOXTIMESTAMP = GET_CHILD(w_GROUP_CHATDISPLAY, "check_Timestamp", "ui::CCheckBox");
	w_CHECKBOXTIMESTAMP:SetCheck(LKChat.GetConfigByKey("LKCHAT_TIMESTAMP"));
	
	-- Autohide Input
	local w_AUTOHIDEINPUT = GET_CHILD(w_GROUP_CHATDISPLAY, "check_AutoHideInput", "ui::CCheckBox");
	w_AUTOHIDEINPUT:SetCheck(LKChat.GetConfigByKey("LKCHAT_AUTOHIDE"));
	
	
	-- AntiSpam
	
	-- Spam Detection
	local w_CHECK_SPAMDETECT = GET_CHILD(w_GROUP_ANTISPAM, "check_SpamDetection", "ui::CCheckBox");
	w_CHECK_SPAMDETECT:SetCheck(LKChat.GetConfigByKey("LKCHAT_ANTISPAM"));
	
	-- Spam Notice
	local w_CHECK_SPAMNOTICE = GET_CHILD(w_GROUP_ANTISPAM, "check_SpamNotice", "ui::CCheckBox");
	w_CHECK_SPAMNOTICE:SetCheck(LKChat.GetConfigByKey("LKCHAT_ANTISPAMNOTICE"));
	
	-- Auto Report
	local w_CHECK_AUTOREPORT = GET_CHILD(w_GROUP_ANTISPAM, "check_ReportSpamBots", "ui::CCheckBox");
	w_CHECK_AUTOREPORT:SetCheck(LKChat.GetConfigByKey("LKCHAT_AUTOREPORT"));		
	
	
	-- Misc
	
	-- Display FPS
	local w_CHECK_DISPLAYFPS = GET_CHILD(w_GROUP_SETTINGS, "check_DisplayFPS", "ui::CCheckBox");
	w_CHECK_DISPLAYFPS:SetCheck(LKChat.GetConfigByKey("LKCHAT_DISPLAYFPS"));
	PRIVATE.DisplayFPS();
end

function LKChat.InitializeCombatLog(frame)
	-- NYI
end

function LKChat.RegisterSlashCommands()
	-- Please don't mess with these, for development use right now.
	if g_PlayerFamilyName == "CitrusKingdom" or g_PlayerFamilyName == "Gibbed" then
		LKChat.RegisterSlash({"script", "lua", "run"}, PRIVATE.RunScript, "Allows lua script to be executed from chat input.");
		LKChat.RegisterSlash({"fclear"}, PRIVATE.ClearBlocked, "Clears all blocked users.");
		LKChat.RegisterSlash({"flm"}, PRIVATE.PrintFriendMapState(), "Lists friend map ids");
	end
	
	LKChat.RegisterSlash({"listslash", "ls"}, LKChat.ListSlashCommands, "Lists all registered slash commands");
	LKChat.RegisterSlash({"lkchat", "lkc"}, function() ui.ToggleFrame('lkchat') end, "Toggles LKChat UI");
end

-- Config
function LKChat.GetConfigByKey(key)
	if g_UserKeySettings[key] then
		local name = g_UserKeySettings[key].name;
		return g_Settings[name];
	end
end

function LKChat.RefreshAllStoredUserValues()
	for key, setting in pairs(g_UserKeySettings) do
		if setting.type == TYPE_INT then
			local value = config.GetConfigInt(key, setting.default);
			g_Settings[setting.name] = math.clamp(value, setting.min, setting.max);
		elseif setting.type == TYPE_STRING then
			local value = config.GetConfig(key, setting.default);
			g_Settings[setting.name] = value;
		elseif setting.type == TYPE_BOOL then
			-- TODO
		end
	end
end

-- Register Slash Commands
function LKChat.RegisterSlash(slashList, func, description)
	local newCommands = false;
	if #slashList > 0 then
		for i = 1, #slashList do
			local newSlash = slashList[i];
			if not g_RegisteredSlashCommands[newSlash] then
				g_RegisteredSlashCommands[newSlash] = {func = func, desc = description or ""};
				newCommands = true;
			end
		end
		if newCommands then
			printc("Slash Command Registered: "..slashList[1]);
		end
	end
end

-- Chat Input & Slash Commands, override for UI_CHAT()
function LKChat.OnSendMessage(msg)
-- If leading character is a '/' check to ensure its a correct slash command
	if (string.sub(msg, 1, 1) == "/") and not (string.sub(msg, 1, 2) == "//") then
		local slash, args = string.match(msg, "/(%w+)%s*(.*)");
		if g_RegisteredSlashCommands[slash] then
			g_RegisteredSlashCommands[slash].func(args);
			
			PRIVATE.HideInput();
			return nil;
		end
	end
	
	ui.Chat(msg);

	if g_uiChatHandler ~= nil then
		local func = _G[g_uiChatHandler];
		if func ~= nil then
			func(msg);
		end
	end
	
	PRIVATE.HideInput();
end

function LKChat.ListSlashCommands()
	local commands = {};
	for k,v in pairs(g_RegisteredSlashCommands) do
		table.insert(commands, {name = k, desc = v.desc});
	end
	table.sort(commands, function(a,b) return a.name > b.name end);

	printc("---- Registered Slash Commands ----");
	for i=1, #commands do
		printc(string.format("%s: %s", commands[i].name, commands[i].desc));
	end
end

 -- Chat Rendering
 -- Rewrite of the existing chat update system
 -- Features: Speed, Rendering efficiency, and proper user filtering hooks
function LKChat.IsChannelUnchecked(type)
	for i = 1, #g_UncheckedChannels do
		if g_UncheckedChannels[i] == type then
			return false
		end
	end
	return true;
end

function LKChat.AddGroupbox(groupBoxName)
	local w_CHATFRAME = ui.GetFrame("chatframe");
	local w_GROUPBOX = GET_CHILD(w_CHATFRAME, groupBoxName);

	if not w_GROUPBOX then
		local leftMargin = w_CHATFRAME:GetUserConfig("GBOX_LEFT_MARGIN");
		local rightMargin = w_CHATFRAME:GetUserConfig("GBOX_RIGHT_MARGIN");
		local topMargin = w_CHATFRAME:GetUserConfig("GBOX_TOP_MARGIN");
		local bottomMargin = w_CHATFRAME:GetUserConfig("GBOX_BOTTOM_MARGIN");

		w_GROUPBOX = w_CHATFRAME:CreateControl("groupbox", groupBoxName, w_CHATFRAME:GetWidth() - (leftMargin + rightMargin), w_CHATFRAME:GetHeight() - (topMargin + bottomMargin), ui.RIGHT, ui.BOTTOM, 0, 0, rightMargin, bottomMargin);

		_ADD_GBOX_OPTION_FOR_CHATFRAME(w_GROUPBOX)
	end
	return w_GROUPBOX;
end

function LKChat.OnDebugMessage(text)
	-- TODO: Rewrite
end

-- Text is set to lowercase for easier detection
function LKChat.FilterMessage(text)
	-- TODO: Normalize text
	local lowtext = string.lower(text);
	local doPatternCheck = false;
	for i = 1, #g_RegExList do
		if (string.match(lowtext, g_RegExList[i])) then
			doPatternCheck = true;
		end
	end
	
	local threshold = 2
	local weight = 0;
	if doPatternCheck then
		for i = 1, #g_BotSpamPatterns do
			local bsp = g_BotSpamPatterns[i];
			if (string[bsp.type](lowtext, bsp.pattern)) then
				weight = weight + bsp.weight;
				if weight >= threshold then
					return true;
				end
			end
		end
	end
end

function LKChat.OnRightClickMessage(frame, chatCtrl)
	local name = chatCtrl:GetUserValue("TARGET_NAME");
	if g_PlayerFamilyName == name then
		return nil;
	end

	local menu = ui.CreateContextMenu("CONTEXT_CHAT_RBTN", name, 0, 0, 170, 100);
	ui.AddContextMenuItem(menu, ScpArgMsg("WHISPER"),			string.format("ui.WhisperTo('%s')", name));
	ui.AddContextMenuItem(menu, ScpArgMsg("ReqAddFriend"),		string.format("friends.RequestRegister('%s')", name));
	ui.AddContextMenuItem(menu, ScpArgMsg("PARTY_INVITE"),		string.format("PARTY_INVITE(\"%s\")", name));
	ui.AddContextMenuItem(menu, ScpArgMsg("Report_AutoBot"),	string.format("REPORT_AUTOBOT_MSGBOX(\"%s\")", name));
	ui.AddContextMenuItem(menu, ScpArgMsg("FriendBlock"),		string.format("CHAT_BLOCK_MSG('%s')", name));
	ui.AddContextMenuItem(menu, ScpArgMsg("Cancel"),			"None");
	
	ui.OpenContextMenu(menu);
end

function LKChat.OnChatMessage(groupBoxName, size, startIndex, frameName)
	--if g_PauseMessages then
	--	table.insert(g_PendingMessages, {size=size, startIndex=startIndex, groupBoxName=groupBoxName});
	--	return nil;
	--end
	if not g_MessageBoxPosition[groupBoxName] or g_MessageBoxPosition[groupBoxName].index > startIndex then
		g_MessageBoxPosition[groupBoxName] = { top = 0, height = 0, id = -1, index = startIndex };
	end
	
	local pending = {};
	for i = startIndex, size - 1 do
		local message = session.ui.GetChatMsgClusterInfo(groupBoxName, i);
		if message then
			local msg = PRIVATE.FormatMessage(message, groupBoxName);
			if not g_SessionIgnoreUser[msg.name] then
				-- Message Filter
				if (PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_ANTISPAM")) and LKChat.IsChannelUnchecked(message.type)) and not PRIVATE.isFriend(name) and msg.name ~= g_PlayerFamilyName then
					if LKChat.FilterMessage(msg.text) then
						g_SessionIgnoreUser[msg.name] = true;
						PRIVATE.AntiSpam_BlockActions(msg);
						if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_ANTISPAMNOTICE")) then
							msg = PRIVATE.SpamRemoval_Notice(msg);
						end
					end
				end
				table.insert(pending, msg);
			end
		end
	end
	
	if #pending > 0 then
		local w_MESSAGEBOX = LKChat.AddGroupbox(groupBoxName);
		LKChat.DrawMessages(w_MESSAGEBOX, pending);
	end

	if groupBoxName == "chatgbox_TOTAL" then
		chat.UpdateAllReadFlag();
	else
		chat.UpdateReadFlag(groupBoxName);
	end
end

function LKChat.DrawMessages(w_MESSAGEBOX, messages)
	local mbName = w_MESSAGEBOX:GetName();
	local msgPosition = g_MessageBoxPosition[mbName];
	local lineCount = w_MESSAGEBOX:GetLineCount();
	
	local top = msgPosition.top;
	for i = 1, #messages do
		local msg = messages[i];
		if msgPosition.id ~= msg.id then
			top = top + msgPosition.height;
		end
		if g_Settings.Theme == THEME_BUBBLE then
			msgPosition.top, msgPosition.height = LKChat.DrawBubbleMessage(w_MESSAGEBOX, msg, top);
		end
		msgPosition.id = msg.id;
	end
	w_MESSAGEBOX:UpdateData();
	
	local afterLineCount = w_MESSAGEBOX:GetLineCount();
	local changedLineCount = afterLineCount - lineCount;
	local curLine = w_MESSAGEBOX:GetCurLine();
	if not scrollend then
		w_MESSAGEBOX:SetScrollPos(curLine + changedLineCount);
	else
		w_MESSAGEBOX:SetScrollPos(99999);
	end
end

-- Bubble Chat - TODO: Refactor
function LKChat.DrawBubbleMessage(w_MESSAGEBOX, message, top)
	local marginLeft = 0;
	local marginRight = 25;

	local colorGroup = "Default";
	local chatCtrlName = 'chatu';
	local horzGravity = ui.LEFT;
	local margin = marginLeft;
	if g_PlayerFamilyName == message.name then
		colorGroup = "Player";
		chatCtrlName = 'chati';
		horzGravity = ui.RIGHT;
		margin = marginRight;
	end
	
	local w_CHATCONTROL = w_MESSAGEBOX:CreateOrGetControlSet(chatCtrlName, "cluster_"..message.id, horzGravity, ui.TOP, marginLeft, top, marginRight, 0);
	w_CHATCONTROL:EnableHitTest(1);
	w_CHATCONTROL:SetUserValue("id", message.id);
	w_CHATCONTROL:SetOffset(margin, top);
	if message.type ~= "System" or message.type ~= "SpamNotice" then
		if message.isGM then
			colorGroup = "GM";
		end
		w_CHATCONTROL:SetEventScript(ui.RBUTTONDOWN, "LKCHAT_ON_RIGHTCLICK_CHAT");
		w_CHATCONTROL:SetUserValue("TARGET_NAME", message.name);
	end

	local w_BACKGROUND = w_CHATCONTROL:GetChild('bg');
	local w_NAME = GET_CHILD(w_CHATCONTROL, "name", "ui::CRichText");
	local w_TEXT = GET_CHILD(w_BACKGROUND, "text", "ui::CRichText");
	local w_UNREAD = GET_CHILD(w_BACKGROUND, "notread", "ui::CRichText");
	local w_TIMEBOX = GET_CHILD(w_CHATCONTROL, "timebox", "ui::CGroupBox");
	local w_TIME = GET_CHILD(w_TIMEBOX, "time", "ui::CRichText");

	w_TEXT:SetTextByKey("size", g_Settings.FontSize);
	w_TEXT:SetTextByKey("text", message.text);

	local color = g_DefaultChatColors[message.type];
	if chatCtrlName == 'chati' then
		w_BACKGROUND:SetSkinName('textballoon_i');
		w_BACKGROUND:SetColorTone(color[colorGroup]);
	else
		w_BACKGROUND:SetColorTone(color[colorGroup]);
		w_NAME:SetText('{@st61}'..message.name..'{/}');

		local w_ICON = GET_CHILD(w_CHATCONTROL, "iconPicture", "ui::CPicture");
		w_ICON:ShowWindow(0);
	end

	w_TIMEBOX:ShowWindow(g_Settings.TimeStamp);
	w_TIME:SetTextByKey("time", message.time);
	
	if message.unreadCount <= 0 then
		w_UNREAD:ShowWindow(0);
	else
		w_UNREAD:SetTextByKey("count", message.unreadCount)
	end

	local slflag = string.find(message.text,'a SL')
	if not slflag then
		w_BACKGROUND:EnableHitTest(0);
	else
		w_BACKGROUND:EnableHitTest(1);
	end

	local height = LKChat.ResizeBubble(w_CHATCONTROL, w_BACKGROUND, w_TEXT, w_TIMEBOX);
	return top, height;
end

function LKChat.ResizeBubble(w_CHATCONTROL, w_BACKGROUND, w_TEXT, w_TIMEBOX)
	local textWidth = w_TEXT:GetWidth() + 40;
	local chatWidth = w_CHATCONTROL:GetWidth();
	w_BACKGROUND:Resize(textWidth, w_TEXT:GetHeight() + 20);
	
	local height = w_BACKGROUND:GetY() + w_BACKGROUND:GetHeight() + 10;

	w_CHATCONTROL:Resize(chatWidth, height);

	local offsetX = w_BACKGROUND:GetX() + w_TEXT:GetWidth() - 60;
	if 35 > offsetX then
		offsetX = offsetX + 40;
	end
	w_TIMEBOX:SetOffset(offsetX, w_BACKGROUND:GetY() + w_BACKGROUND:GetHeight() - 10);
	
	return height;
end

-- Simple Chat
function LKChat.DrawSimpleMessage(w_MESSAGEBOX, message, top)
	local colorGroup = "Default";
	if g_PlayerFamilyName == message.name then
		colorGroup = "Player";
	end
	
	local w_CHATCONTROL = w_MESSAGEBOX:CreateOrGetControl('groupbox', "cluster_"..math.random(), ui.LEFT, ui.TOP, 0, top, 0, 0);
	w_CHATCONTROL = tolua.cast(w_CHATCONTROL, "ui::CGroupBox");
	local w_TEXT = w_CHATCONTROL:CreateOrGetControlSet("richtext", "text", ui.LEFT, ui.TOP, 0, 0, 0, 0);
	w_TEXT = tolua.cast(w_TEXT, "ui::CRichText");
	w_CHATCONTROL:ShowWindow(1);
	w_CHATCONTROL:EnableHitTest(1);
	
	w_TEXT:ShowWindow(1);
	if message.type == "Debug" then
		--fontSize = 12;
	elseif message.type == "SpamNotice" then
		colorGroup = "Default";
		--fontSize = 12;
	elseif message.type ~= "System" then
		if message.isGM then
			colorGroup = "GM";
		end
		w_CHATCONTROL:SetEventScript(ui.RBUTTONDOWN, 'CHAT_RBTN_POPUP');
		w_CHATCONTROL:SetUserValue("TARGET_NAME", message.name);
	end

	--w_TEXT:Resize(350, 20);
	w_TEXT:SetTextAlign('left','top');
	w_TEXT:SetFontName("white_18_ol");
	w_TEXT:SetTextByKey("size", g_Settings.FontSize);
	
	local colors = g_DefaultChatColors[message.type];
	local textFormat = g_LineChatFormat[g_Settings.TimeStamp];
	if g_Settings.TimeStamp == 0 then
		w_TEXT:SetText(string.format(textFormat, colors[colorGroup], message.type, message.name, message.text));
	elseif g_Settings.TimeStamp == 1 then
		w_TEXT:SetText(string.format(textFormat, message.time, colors[colorGroup], message.type, message.name, message.text));
	end
	
	local slflag = string.find(message.text,'a SL')
	if not slflag then
		w_TEXT:EnableHitTest(0);
	else
		w_TEXT:EnableHitTest(1);
	end

	--w_CHATCONTROL:Resize(w_TEXT:GetWidth(), w_TEXT:GetHeight() + 4);
	
	
	local textWidth = w_TEXT:GetWidth();
	local chatWidth = w_CHATCONTROL:GetWidth();
	w_CHATCONTROL:Resize(chatWidth, w_TEXT:GetHeight() + 4);
end


-- Private Functions
function PRIVATE.SetVersion(frame)
	local w_VERSION = GET_CHILD(frame, "label_Version", "ui::CRichText");
	w_VERSION:SetTextByKey("version", LKChat._version);
end

function PRIVATE.GetMessageType(msg)
	local messageType = msg:GetMsgType();
	if type(tonumber(messageType)) == "number" then
		return "Whisper";
	end
	return messageType;
end

function PRIVATE.FormatMessage(msg, group)
	local name = msg:GetCommanderName();
	local isGM = (string.sub(name, 1, 3) == "GM_");
	local o = {
		id = msg:GetClusterID(),
		group = group,
		name = name,
		time = msg:GetTimeStr(),
		type = PRIVATE.GetMessageType(msg),
		room = msg:GetRoomID(),
		text = msg:GetMsg(),
		unreadCount = msg:GetNotReadCount(),
		isGM = isGM,
	};

	return o;
end

function LKChat.DisplayMessage(text, header, color)
	local name = msg:GetCommanderName();
	local isGM = (string.sub(name, 1, 3) == "GM_");
	local o = {
		id = 9000 + math.random(),
		name = header or "System",
		time = "",
		type = "Custom",
		room = "TOTAL",
		text = text or "",
		unreadCount = 0,
		isGM = false,
		color = color or g_DefaultChatColors.System.Default;
	};
end

function PRIVATE.SpamRemoval_Notice(msg)
	local blockMsg;
	if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_AUTOREPORT")) then
		blockMsg = string.format("User %s has been blocked and reported.", msg.name);
	else
		blockMsg = string.format("User %s has been blocked.", msg.name);
	end

	local notice = {
		id = 9000 + math.random(),
		group = "TOTAL",
		name = "Spam Detection",
		time = msg.time,
		type = "SpamNotice",
		room = msg.room,
		text = blockMsg,
		unreadCount = 0,
		isGM = false,
		isNotice = true,
	};
	
	return notice;
end

function PRIVATE.AntiSpam_BlockActions(msg)
	friends.RequestBlock(msg.name);		-- Blocked! No more spam for you!
	if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_AUTOREPORT")) then
		packet.ReportAutoBot(msg.name);		-- Bot Report
	end
end

function PRIVATE.HideInput()
	if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_AUTOHIDE")) then
		local chatFrame = GET_CHATFRAME();
		local edit = chatFrame:GetChild('mainchat');

		chatFrame:ShowWindow(0);
		edit:ShowWindow(0);
		
		ui.CloseFrame("chat_option");
		ui.CloseFrame("chat_emoticon");
	end
end

-- Misc
function PRIVATE.DisplayFPS()
	local visible = LKChat.GetConfigByKey("LKCHAT_DISPLAYFPS");
	
	local f = ui.GetFrame("fps");
	f:ShowWindow(visible);
end

-- Util
function PRIVATE.RunScript(args)
	loadstring(args)();
end

function PRIVATE.IntToBool(int)
	return (int > 0);
end

function PRIVATE.ClearBlocked()
	local cnt = session.friends.GetFriendCount(FRIEND_LIST_BLOCKED);
	for i = 0 , cnt - 1 do
		local f = session.friends.GetFriendByIndex(FRIEND_LIST_BLOCKED, i);	
		local name = f:GetInfo():GetFamilyName();
		friends.RequestDelete(name);
		printc("Block Removed: "..name);
	end
end

function PRIVATE.isFriend(name)
	return g_FriendWhiteList[name];
end

function PRIVATE.RefreshFriendList()
	g_FriendWhiteList = {};
	local num = session.friends.GetFriendCount(FRIEND_LIST_COMPLETE);
	for i = 0 , num - 1 do
		local f = session.friends.GetFriendByIndex(FRIEND_LIST_COMPLETE, i);
		local fInfo = f:GetInfo();
		local familyName = fInfo:GetFamilyName();
		
		g_FriendWhiteList[familyName] = true;
		
		PRIVATE.NotifyFriendState(fInfo, familyName);
	end
end

function PRIVATE.NotifyFriendState(fInfo, familyName)
	if not g_FriendLoginState[familyName] then
		g_FriendLoginState[familyName] = {
			online = false,
		};
	end
	local isOnlinePrev = g_FriendLoginState[familyName].online;
	local isOnlineCurr = (fInfo.mapID ~= 0);
	printc(string.format("%s mapId: %s", familyName, fInfo.mapID));
	
	if isOnlinePrev ~= isOnlineCurr then
		if isOnlineCurr then
			printc(string.format(FRIEND_LOGIN, familyName));
			imcSound.PlaySoundEvent("travel_diary_1");
		else
			printc(string.format(FRIEND_LOGOFF, familyName));
		end
	end
	g_FriendLoginState[familyName].online = isOnlineCurr;
end

function PRIVATE.PrintFriendMapState()
	local num = session.friends.GetFriendCount(FRIEND_LIST_COMPLETE);
	for i = 0 , num - 1 do
		local f = session.friends.GetFriendByIndex(FRIEND_LIST_COMPLETE, i);
		local fInfo = f:GetInfo();
		local familyName = fInfo:GetFamilyName();
		printc("FName: %s FMapId: %d", familyName, fInfo.mapID);
	end
end

--[[
function PRIVATE.FindAndColorizeLink(text)
	local properties, id, color, image, height, width = string.match(text, "{a SLI (%.*) (%.*)}{#(%.*)}{img (%.*) (%.*) (%.*)}(%.*){/}{/}{/}");
	
	if id then
		local item = CreateIESByID("Item", tonumber(id));
		-- g_ItemGradeColors[item.ItemGrade];
		string.grep(text, "({a SLI %.*}{#%.*}{img %.* %.* %.*}%.*{/}{/}{/})", {a SLI (%.*) (%.*)}{#(%.*)}{img (%.*) (%.*) (%.*)}(%.*){/}{/}{/})
	end
end
--]]