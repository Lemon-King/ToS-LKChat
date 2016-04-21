-- Globals
_G["LKChat"] = {};
local LKChat = _G["LKChat"];
local PRIVATE = {};

LKChat._version = "Alpha v0.2";

-- Constants
local TYPE_INT = 0;
local TYPE_STRING = 1;

local THEME_BUBBLE = 0;
local THEME_LINE = 1;

local g_LineChatFormat = {
	"{#%s}[%s] [%s]: %s",				-- Default
	"{#FF777777}%s {#%s}[%s] [%s]: %s", -- Timestamp
};

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
	["AntiSpam"] = {
		["Default"] = "FFA6E7FF",
	},
};

local g_UncheckedChannels = {
	"System",
	"Guild",
	"Party",
};

local g_RegExList = {
	"%s*[3vw]*%s*[vw]*%s*[vw]*%s*[vw]*%s*[,%.]%s*.*%s*[,%.]%s*c%s*[o0]%s*[nm]%s*", -- greedy spam url detection, catches nearly any url by bot spammers
	--"[3vw]%s-[vw]%s-[vw]%s-[vw]%s-[,%.]%s-.+%s-[,%.]%s-c%s-[o0]%s-[nm]", -- less greedy more precise url detection
};

local g_BotSpamFlags = {
	"sell",
	"usd",
	"cheap",
	"fast",
	"f@st",
	"offer",
	"qq",
	"delivery",
	"silver",
	"s1lver",
	"gold",
	"g0ld",
};

-- Lookup table
local g_UserKeySettings = {
	["LKCHAT_THEME"]			= {name = "Theme", type = TYPE_INT, default = 0, min = 0, max = 1},
	["LKCHAT_FONTSIZE"]			= {name = "FontSize", type = TYPE_INT, default = 16, min = 10, max = 25},
	["LKCHAT_TIMESTAMP"]		= {name = "TimeStamp", type = TYPE_INT, default = 1, min = 0, max = 1},
	["LKCHAT_AUTOHIDE"]			= {name = "AutoHide", type = TYPE_INT, default = 0, min = 0, max = 1},
	
	["LKCHAT_ANTISPAM"]			= {name = "AntiSpam", type = TYPE_INT, default = 1, min = 0, max = 1},
	["LKCHAT_ANTISPAMNOTICE"]	= {name = "AntiSpamNotice", type = TYPE_INT, default = 1, min = 0, max = 1},
	["LKCHAT_AUTOREPORT"]		= {name = "ReportAutoBot", type = TYPE_INT, default = 0, min = 0, max = 1},
	
	["LKCHAT_DISPLAYFPS"]		= {name = "DisplayFPS", type = TYPE_INT, default = 1, min = 0, max = 1},
};

-- Variables
local g_Region;
local g_PlayerFamilyName;
local g_Settings = {};
local g_RegisteredSlashCommands = {};

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



-- UI Events
function LKCHAT_ON_INIT(addon, frame)
	if not LKChat.hasLoaded then
		LKChat.addon = addon;
		LKChat.addon:RegisterMsg("GAME_START", "LKCHAT_ON_GAME_START");
	end
end

function LKCHAT_ON_GAME_START(frame)
	if not LKChat.hasLoaded then
		LKChat.OnInit(frame);
	end
end

function LKCHAT_ON_OPEN(frame)
	LKChat.RefreshSettings(frame);
	
	PRIVATE.SetVersion(frame);
end

function LKCHAT_ON_CLOSE(frame)

end

function LKCHAT_ON_CHANGE_THEME(frame, ctrl, str, num)
	local w_THEME = tolua.cast(ctrl, "ui::CDropList");
	
	local themeIndex = w_THEME:GetSelItemIndex();
	LKChat.SetConfigByKey("LKCHAT_THEME", themeIndex);
end

function LKCHAT_ON_SLIDE_FONTSIZE(frame, ctrl, str, num)
	local w_GROUP_SETTINGS = GET_CHILD(frame, "gbox_settings", "ui::CGroupBox");
	local w_GROUP_CHATDISPLAY = GET_CHILD(w_GROUP_SETTINGS, "gbox_ChatDisplay", "ui::CGroupBox");
	
	local w_SLIDE_FONTSIZE = tolua.cast(ctrl, "ui::CSlideBar");
	local size = w_SLIDE_FONTSIZE:GetLevel();
	
	local w_LABEL_FONTSIZE = GET_CHILD(w_GROUP_CHATDISPLAY, "label_FontSize", "ui::CRichText");
	if w_LABEL_FONTSIZE then
		w_LABEL_FONTSIZE:SetTextByKey("size", size);
	end
	
	LKChat.SetConfigByKey("LKCHAT_FONTSIZE", size);
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
	
	if not _G["DRAW_CHAT_MSG_ORIG"] then
		_G["DRAW_CHAT_MSG_ORIG"] = _G["DRAW_CHAT_MSG"];
	end
    _G["DRAW_CHAT_MSG"] = LKChat.OnMessage;
	--_G["SEND_POPUP_FRAME_CHAT"] = LKChat.OnInputMessage;

	_G["UI_CHAT"] = LKChat.OnSendMessage;

	LKChat.RegisterShowSlash();
	--LKChat.RegisterSlashScript();
	--LKChat.RegisterFriendClearScript();
	LKChat.RegisterSlashLKChat();
	
	LKChat.hasLoaded = true;
	printc(string.format("LKChat Loaded:{nl}Hello %s.", g_PlayerFamilyName));
end

function LKChat.RefreshSettings(frame)
	LKChat.RefreshAllStoredUserValues();
	
	LKChat.InitializeSettings(frame);
	LKChat.InitializeCombatLog(frame);
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
		end
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



-- Register Slash Commands
function LKChat.RegisterSlash(slashList, func, description)
	if #slashList > 0 then
		for i = 1, #slashList do
			local newSlash = slashList[i];
			if not g_RegisteredSlashCommands[newSlash] then
				g_RegisteredSlashCommands[newSlash] = {func = func, desc = description or ""};
			end
		end
		printc("Slash Command Registered: "..slashList[1]);
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

function LKChat.RegisterSlashScript()
	-- Please don't mess with this, for development use right now.
	if g_PlayerFamilyName == "CitrusKingdom" or g_PlayerFamilyName == "Gibbed" then
		LKChat.RegisterSlash({"script", "lua", "run"}, PRIVATE.RunScript, "Allows lua script to be executed from chat input.");
	end
end

function LKChat.RegisterFriendClearScript()
	-- Please don't mess with this, for development use right now.
	if g_PlayerFamilyName == "CitrusKingdom" or g_PlayerFamilyName == "Gibbed" then
		LKChat.RegisterSlash({"fclear"}, PRIVATE.ClearBlocked, "Clears all blocked users.");
	end
end

function LKChat.RegisterSlashLKChat()
	LKChat.RegisterSlash({"lkchat", "lkc"}, function() ui.ToggleFrame('lkchat') end, "Toggles LKChat UI");
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

function LKChat.RegisterShowSlash()
	LKChat.RegisterSlash({"listslash", "ls"}, LKChat.ListSlashCommands, "Lists all registered slash commands");
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

		w_GROUPBOX = w_CHATFRAME:CreateControl("groupbox", groupboxname, w_CHATFRAME:GetWidth() - (leftMargin + rightMargin), w_CHATFRAME:GetHeight() - (topMargin + bottomMargin), ui.RIGHT, ui.BOTTOM, 0, 0, rightMargin, bottomMargin);

		_ADD_GBOX_OPTION_FOR_CHATFRAME(w_GROUPBOX)
	end
	return w_GROUPBOX;
end

function LKChat.FormatMessage(msg)
	local name = msg:GetCommanderName();
	local isGM = (string.sub(name, 1, 3) == "GM_");
	local o = {
		id = msg:GetClusterID(),
		name = name,
		time = msg:GetTimeStr(),
		type = msg:GetMsgType(),
		room = msg:GetRoomID(),
		text = msg:GetMsg(),
		unreadCount = msg:GetNotReadCount(),
		isGM = isGM,
	};

	return o;
end

function LKChat.OnDebugMessage(text)
	-- TODO: Rewrite
end

-- Text is set to lowercase for easier detection
function LKChat.FilterMessage(text)
	-- TODO: Normalize text
	local lowtext = string.lower(text);
	local flagCheck = false;
	for i = 1, #g_RegExList do
		if (string.match(lowtext, g_RegExList[i])) then
			flagCheck = true;
		end
	end
	
	local requiredFlags = 2
	local flags = 0;
	if flagCheck then
		for i = 1, #g_BotSpamFlags do
			if (string.find(lowtext, g_BotSpamFlags[i])) then
				flags = flags + 1;
				if flags >= requiredFlags then
					return true;
				end
			end
		end
	end
end

local ignoreUser = {};
local activeGroupBoxes = {};	-- used with chat regeneration
function LKChat.OnMessage(groupBoxName, size, startIndex, frameName)
	local w_MESSAGEBOX = LKChat.AddGroupbox(groupBoxName);
	if not activeGroupBoxes[groupBoxName] then activeGroupBoxes[groupBoxName] = true end;

	local top = 0;
	local lineCount = w_MESSAGEBOX:GetLineCount();
	local drawMessages = {};
	for i = startIndex, size - 1 do
		local message = session.ui.GetChatMsgClusterInfo(groupBoxName, i);
		if message then
			local msg = LKChat.FormatMessage(message);
			if not ignoreUser[msg.name] then
				-- filter messages
				local isSpam = false;
				if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_ANTISPAM")) and LKChat.IsChannelUnchecked(message.type) then
					local isSpam = LKChat.FilterMessage(msg.text);
					if isSpam then
						ignoreUser[msg.name] = true;
						PRIVATE.AntiSpam_BlockActions(msg);
						if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_ANTISPAMNOTICE")) then
							msg.id = math.random();
							msg.text = string.format("Blocked Spam from %s.", msg.name);
							msg.name = "Spam Detection";
							msg.type = "AntiSpam";
						end
					end
				end
				table.insert(drawMessages, msg);
			end
		end
	end
	
	for i=1, #drawMessages do
		local msg = drawMessages[i];
	
		local childCount = w_MESSAGEBOX:GetChildCount();
		local w_PREVCHILD = w_MESSAGEBOX:GetChildByIndex(childCount - 1);
		if w_PREVCHILD then
			top = w_PREVCHILD:GetY() + w_PREVCHILD:GetHeight();
		end
		if g_Settings.Theme == THEME_BUBBLE then
			LKChat.DrawBubbleMessage(w_MESSAGEBOX, msg, top);
		elseif g_Settings.Theme == THEME_LINE then
			LKChat.DrawSimpleMessage(w_MESSAGEBOX, msg, top);
		end
		w_MESSAGEBOX:UpdateData();
	end

	-- construct chat messages
	if groupBoxName == "TOTAL" then
		chat.UpdateAllReadFlag();
	else
		chat.UpdateReadFlag(groupBoxName);
	end

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
	if g_PlayerFamilyName == message.name then
		colorGroup = "Player";
		chatCtrlName = 'chati';
		horzGravity = ui.RIGHT;
	end
	
	local w_CHATCONTROL = w_MESSAGEBOX:CreateOrGetControlSet(chatCtrlName, "cluster_"..message.id, horzGravity, ui.TOP, marginLeft, top, marginRight, 0);
	w_CHATCONTROL:EnableHitTest(1);
	if message.type ~= "System" then
		if message.isGM then
			colorGroup = "GM";
		end
		w_CHATCONTROL:SetEventScript(ui.RBUTTONDOWN, 'CHAT_RBTN_POPUP');
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

	local colors = g_DefaultChatColors[message.type];
	if not colors then
		colors = g_DefaultChatColors["Whisper"];
	end
	if chatCtrlName == 'chati' then
		w_BACKGROUND:SetSkinName('textballoon_i');
		w_BACKGROUND:SetColorTone(colors[colorGroup]);
	else
		w_BACKGROUND:SetColorTone(colors[colorGroup]);
		w_NAME:SetText('{@st61}'..message.name..'{/}');

		local w_ICON = GET_CHILD(w_CHATCONTROL, "iconPicture", "ui::CPicture");
		w_ICON:ShowWindow(0);
		--[[ ĳ���� ���� �츱�Ÿ� ����

		if iconInfo == nil then
			iconPicture:ShowWindow(0);
		else
			iconPicture:ShowWindow(0);
		end
		--]]
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

	LKChat.ResizeBubble(w_CHATCONTROL, w_BACKGROUND, w_TEXT, w_TIMEBOX);
end

function LKChat.ResizeBubble(w_CHATCONTROL, w_BACKGROUND, w_TEXT, w_TIMEBOX)
	local textWidth = w_TEXT:GetWidth() + 40;
	local chatWidth = w_CHATCONTROL:GetWidth();
	w_BACKGROUND:Resize(textWidth, w_TEXT:GetHeight() + 20);

	w_CHATCONTROL:Resize(chatWidth, w_BACKGROUND:GetY() + w_BACKGROUND:GetHeight() + 10);

	local offsetX = w_BACKGROUND:GetX() + w_TEXT:GetWidth() - 60;
	if 35 > offsetX then
		offsetX = offsetX + 40;
	end
	w_TIMEBOX:SetOffset(offsetX, w_BACKGROUND:GetY() + w_BACKGROUND:GetHeight() - 10);
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
	elseif message.type == "AntiSpam" then
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

function PRIVATE.AntiSpam_Notice(msg)
	local notice = {
		id = math.random(),
		name = "Spam Detection",
		time = msg.time,
		type = "AntiSpam",
		room = msg.room,
		text = string.format("Blocked Spam from %s.", msg.name),
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
	end
end

-- Misc
function PRIVATE.DisplayFPS()
	if PRIVATE.IntToBool(LKChat.GetConfigByKey("LKCHAT_DISPLAYFPS")) then
		ui.OpenFrame("fps");
	else
		ui.CloseFrame("fps");
	end
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