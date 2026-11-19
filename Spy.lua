local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local StatsService = game:GetService("Stats")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
-- _CollectionService removed (unused)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ===================================================================
-- 🛡️ ASTROCYNA WATERMARK ANTI-DUPLICATION & AUTO-CLEANUP
-- ระบบป้องกันการขึ้นซ้อนกันของ NameTag / Watermark เมื่อรันสคริปต์ซ้ำเพื่อ Update
-- ===================================================================
local env = (getgenv and getgenv()) or _G

-- 1. Call any registered cleanup function from previous execution
if env._AstrocynaWatermarkCleanup then
	pcall(env._AstrocynaWatermarkCleanup)
	env._AstrocynaWatermarkCleanup = nil
end
if env._AstrocynaFakeAdminCleanup then
	pcall(env._AstrocynaFakeAdminCleanup)
	env._AstrocynaFakeAdminCleanup = nil
end

-- 2. Terminate previous watchdog and background threads if running
if env._AstrocynaWatermarkWatchdogThread then
	pcall(task.cancel, env._AstrocynaWatermarkWatchdogThread)
	env._AstrocynaWatermarkWatchdogThread = nil
end
if env._AstrocynaDisguiseWatchdogThread then
	pcall(task.cancel, env._AstrocynaDisguiseWatchdogThread)
	env._AstrocynaDisguiseWatchdogThread = nil
end
if env._AstrocynaNametagWatchdogThread then
	pcall(task.cancel, env._AstrocynaNametagWatchdogThread)
	env._AstrocynaNametagWatchdogThread = nil
end
if env._AstrocynaSpyWatchdogThread then
	pcall(task.cancel, env._AstrocynaSpyWatchdogThread)
	env._AstrocynaSpyWatchdogThread = nil
end
if env._AstrocynaTrackedThreads then
	for _, th in ipairs(env._AstrocynaTrackedThreads) do
		if th then pcall(task.cancel, th) end
	end
	table.clear(env._AstrocynaTrackedThreads)
end
env._AstrocynaTrackedThreads = {}

-- Helper to track any background thread for clean termination on re-run
local function trackThread(th)
	if th then table.insert(env._AstrocynaTrackedThreads, th) end
	return th
end

-- 3. Disconnect previous connection tables
if env._AstrocynaWatermarkConnections then
	pcall(function()
		for _, conn in ipairs(env._AstrocynaWatermarkConnections) do
			if conn and conn.Disconnect then conn:Disconnect() end
		end
		table.clear(env._AstrocynaWatermarkConnections)
	end)
end
env._AstrocynaWatermarkConnections = {}

if env._AstrocynaTrackedConnections then
	pcall(function()
		for _, conn in ipairs(env._AstrocynaTrackedConnections) do
			if conn and conn.Disconnect then conn:Disconnect() end
		end
		table.clear(env._AstrocynaTrackedConnections)
	end)
end
env._AstrocynaTrackedConnections = {}

-- Helper to track any RBXScriptConnection for clean disconnect on re-run
local function trackConnection(conn)
	if conn then table.insert(env._AstrocynaTrackedConnections, conn) end
	return conn
end

-- Helper to safely wrap hooks with newcclosure if present without Luau union callable diagnostics
local function toCClosure(fn: any): any
	if typeof(newcclosure) == "function" then
		return (newcclosure :: any)(fn)
	end
	return fn
end


-- 4. Deep purge ALL existing AstrocynaWatermarkGui instances across entire game
do
local function purgeAllWatermarks()
	local localPlr = player or Players.LocalPlayer
	local charsToCheck = {}
	if localPlr and localPlr.Character then
		table.insert(charsToCheck, localPlr.Character)
	end

	-- Check workspace.Players
	local wsPlayers = workspace:FindFirstChild("Players")
	if wsPlayers and localPlr then
		local pChar = wsPlayers:FindFirstChild(localPlr.Name)
		if pChar and pChar ~= localPlr.Character then
			table.insert(charsToCheck, pChar)
		end
	end

	-- Check workspace direct
	if localPlr then
		local wsChar = workspace:FindFirstChild(localPlr.Name)
		if wsChar and wsChar:IsA("Model") and wsChar ~= localPlr.Character then
			table.insert(charsToCheck, wsChar)
		end
	end

	-- Fast purge from all character parts
	for _, ch in ipairs(charsToCheck) do
		local count = 0
		local oldWm = ch:FindFirstChild("AstrocynaWatermarkGui", true)
		while oldWm and count < 10 do
			count = count + 1
			pcall(function() oldWm:Destroy() end)
			oldWm = ch:FindFirstChild("AstrocynaWatermarkGui", true)
		end
	end

	-- Fast purge from workspace.Visuals
	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals then
		local count = 0
		local oldWm = wsVisuals:FindFirstChild("AstrocynaWatermarkGui", true)
		while oldWm and count < 20 do
			count = count + 1
			pcall(function() oldWm:Destroy() end)
			oldWm = wsVisuals:FindFirstChild("AstrocynaWatermarkGui", true)
		end
	end

	-- Fast direct purge from PlayerGui & CoreGui (Zero GetDescendants traversal)
	if localPlr then
		local pGui = localPlr:FindFirstChildOfClass("PlayerGui")
		if pGui then
			local count = 0
			local oldWm = pGui:FindFirstChild("AstrocynaWatermarkGui", true)
			while oldWm and count < 20 do
				count = count + 1
				pcall(function() oldWm:Destroy() end)
			oldWm = pGui:FindFirstChild("AstrocynaWatermarkGui", true)
			end
		end
	end
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		local count = 0
		local oldWm = CoreGui:FindFirstChild("AstrocynaWatermarkGui", true)
		while oldWm and count < 20 do
			count = count + 1
			pcall(function() oldWm:Destroy() end)
			oldWm = CoreGui:FindFirstChild("AstrocynaWatermarkGui", true)
		end
	end)
end

purgeAllWatermarks()

-- Helper to safely load CustomNameTag (supports local file in Potassium/scripts or fallback to raw GitHub)
local function getWatermarkLoader()
	local src = nil
	if typeof(isfile) == "function" and typeof(readfile) == "function" then
		if isfile("CustomNameTag.luau") then
			pcall(function() src = readfile("CustomNameTag.luau") end)
		elseif isfile("scripts/CustomNameTag.luau") then
			pcall(function() src = readfile("scripts/CustomNameTag.luau") end)
		end
	end
	if not src or #src == 0 then
		local s, res = pcall(function()
			return game:HttpGet("https://raw.githubusercontent.com/EQWTQWSd/Astrocyna-NameTag/main/CustomNameTag.luau")
		end)
		if s and res and #res > 0 then
			src = res
		end
	end
	if src and #src > 0 then
		local func, err = loadstring(src)
		if func then
			return func
		else
			warn("⚠️ [Astrocyna Watermark] Compile error: " .. tostring(err))
		end
	end
	return nil
end

local loader = getWatermarkLoader()
if loader then
	loader({
		Self = {
			NameColor = Color3.fromRGB(255, 255, 255),
			SubtitleColor = Color3.fromRGB(220, 220, 225),
			BorderColor = Color3.fromRGB(200, 200, 205),
			BackgroundColor = Color3.fromRGB(16, 16, 18),
			TextAnimation = {
				Enabled = true,
				Mode = "ShimmerSweep",
				Speed = 1.3,
				ShimmerColor = Color3.fromRGB(255, 255, 255),
				GlowColor = Color3.fromRGB(200, 200, 205),
			},
			BorderAnimation = {
				Enabled = true,
				Mode = "NeonSweep",
				RotationSpeed = 110,
				BaseBorderColor = Color3.fromRGB(36, 36, 40),
				BeamColor = Color3.fromRGB(180, 180, 185),
				HighlightColor = Color3.fromRGB(255, 255, 255),
				PulseThickness = true,
				MinThickness = 2.2,
				MaxThickness = 3.2,
				PulseSpeed = 2.5,
			},
			Effects = {
				EnableTextGradientShadow = true,
				TextShadowColor = Color3.fromRGB(5, 5, 6),
				EnableGradient = true,
				TopGradientColor = Color3.fromRGB(26, 26, 30),
				BottomGradientColor = Color3.fromRGB(10, 10, 12),
			}
		}
	})
end
end

local THEME = {
	CyanPrimary = Color3.fromRGB(255, 255, 255),
	MainBg = Color3.fromRGB(18, 18, 20),
	MainBgTransparency = 0.04,
	CardBg = Color3.fromRGB(26, 26, 30),
	CardStroke = Color3.fromRGB(46, 46, 52),
	TopGradient = Color3.fromRGB(28, 28, 32),
	BottomGradient = Color3.fromRGB(14, 14, 16),

	BorderBase = Color3.fromRGB(42, 42, 48),
	BorderBeam = Color3.fromRGB(180, 180, 185),
	BorderHighlight = Color3.fromRGB(255, 255, 255),

	TextCyan = Color3.fromRGB(255, 255, 255),
	TextFrost = Color3.fromRGB(230, 230, 235),
	TextDim = Color3.fromRGB(150, 150, 155),
	TextShadow = Color3.fromRGB(5, 5, 6),

	BtnOff = Color3.fromRGB(30, 30, 34),
	BtnOffStroke = Color3.fromRGB(48, 48, 54),
	BtnOffText = Color3.fromRGB(215, 215, 220),

	BtnActive = Color3.fromRGB(255, 255, 255),
	BtnActiveText = Color3.fromRGB(18, 18, 20),
	BtnActiveStroke = Color3.fromRGB(200, 200, 205),

	ActiveFly = Color3.fromRGB(255, 255, 255),
	ActiveInvis = Color3.fromRGB(255, 255, 255),
	ActiveEsp = Color3.fromRGB(255, 255, 255),
	ActiveChat = Color3.fromRGB(255, 255, 255),
	ActiveAura = Color3.fromRGB(255, 255, 255),
	ActiveDisguise = Color3.fromRGB(255, 255, 255),
}

local SETTINGS = {
	FLY_SPEED = 70,
	ACCELERATION = 10,
	ESP_TRANSPARENCY = 1,
}

local ANIM_IDS = {
	Idle = "rbxassetid://80711102270005",
	Front = "rbxassetid://80484525630953",
	Back = "rbxassetid://76829570430606",
	Left = "rbxassetid://92277900307010",
	Right = "rbxassetid://106239732732523",
	BackLeft = "rbxassetid://134025304543192",
	BackRight = "rbxassetid://137083983304965",
}

local isFlying = false
local isInvis = false
local invisBusy = false
local isEspEnabled = false
local isAuraEnabled = false
local auraColor = Color3.fromRGB(255, 255, 255)
updateGuiAuraState = function() end
syncAuraPowerButton = function() end
toggleAura = function() end
toggleAuraMenu = function() end

local isDisguiseEnabled = false
local disguiseBusy = false
updateGuiDisguiseState = function() end
toggleDisguise = function() end

local currentVelocity = Vector3.zero
local bodyVelocity = nil
local bodyGyro = nil
local flyRenderConn = nil

local mobileFlyState = { Up = false, Down = false }
setMobileFlyHudVisible = function(vis) end

local _noclipParts = {}
local noclipConnection = nil

local loadedTracks = {}
local activeTrackName = nil
local boundCharacter = nil

local realCharacter = nil
local ghostCharacter = nil
local frozenDummy = nil
local invisDiedConn = nil

local espDatabase = {}
local espFolder = nil
local chatScroll = nil

local playerJoinTimes = {}
local isSpectating = false
local spectateTarget = nil
local spectateConn = nil
local spectateVoiceConn = nil
local savedAudioListeners = {}
local spectateHud = nil
local shTitle = nil
local shAvatar = nil
stopSpectating = function() end
spectatePlayer = function(targetPlr) end
local clampPositionToScreen = nil
openBackpackInspector = function(targetPlr) end
refreshBackpackUI = function() end
local playersWindow = nil
updateRealtimeTelemetry = function() end
togglePlayersGui = function()
    if not playersWindow then return end
    playersWindow.Visible = not playersWindow.Visible
end
local thumbnailCache = {}

local hackerWindow = nil
updateHackerLiveCards = function() end
scanAllPlayersRealtime = function() return 0 end
local isHackerWatchdogEnabled = true
refreshHackerList = function() end
scheduleSaveHackerList = function() end
requestRefreshHackerList = function() end
toggleHackerGui = function()
	if not hackerWindow then return end
	hackerWindow.Visible = not hackerWindow.Visible
	if hackerWindow.Visible then
		if clampPositionToScreen then
			hackerWindow.Position = clampPositionToScreen(hackerWindow.Position, hackerWindow.Size)
		end
		pcall(refreshHackerList)
		pcall(updateHackerLiveCards)
		task.delay(0.6, function()
			if hackerWindow and hackerWindow.Visible then
				task.spawn(scanAllPlayersRealtime)
			end
		end)
	end
end

local _radioWindow = nil
toggleRadioGui = function() end

gangWindow = nil
toggleGangGui = function() end
inspectGangByKey = function(gangKey) end

openGameUI = function(uiName) end
GANG_SYS = {
	directory = {},
	gangsByKey = {},
	playerGangMap = {},
	pendingFetches = {},
	lastDirectoryFetch = 0,
	lastRostersFetch = 0,
	isFetching = false,
	isPreloadingRosters = false,
	rostersLoadedCount = 0,
	rostersTotalCount = 0,
	selectedGangKey = nil,
	searchQuery = "",
	onRosterUpdated = nil,
	getRemoteFunction = function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local gangFolder = remotes and remotes:FindFirstChild("Gang")
		return gangFolder and gangFolder:FindFirstChild("Function")
	end,
	getRemoteEvent = function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local gangFolder = remotes and remotes:FindFirstChild("Gang")
		return gangFolder and gangFolder:FindFirstChild("Event")
	end,
	fetchDirectory = function(force)
		local now = tick()
		if not force and #GANG_SYS.directory > 0 and (now - GANG_SYS.lastDirectoryFetch < 60) then
			return GANG_SYS.directory
		end
		local fn = GANG_SYS.getRemoteFunction()
		if not fn then return GANG_SYS.directory end

		local function registerGangItem(item)
			if typeof(item) ~= "table" then return end
			local k = item.Key or item.Name
			if not k or k == "" then return end
			if not GANG_SYS.gangsByKey[k] then
				GANG_SYS.gangsByKey[k] = item
				table.insert(GANG_SYS.directory, item)
			else
				for f, v in pairs(item) do
					if f ~= "Members" or typeof(v) == "table" then
						GANG_SYS.gangsByKey[k][f] = v
					end
				end
			end
			if item.Key and item.Key ~= "" then GANG_SYS.gangsByKey[item.Key] = GANG_SYS.gangsByKey[k] end
			if item.Name and item.Name ~= "" then GANG_SYS.gangsByKey[item.Name] = GANG_SYS.gangsByKey[k] end
		end

		local ok, res = pcall(function()
			return fn:InvokeServer("GetGangDirectory")
		end)
		if ok and typeof(res) == "table" then
			GANG_SYS.directory = res
			GANG_SYS.lastDirectoryFetch = now
			for _, g in ipairs(res) do
				registerGangItem(g)
			end
		end

		-- Harvest all competitive & active boards in parallel
		task.spawn(function()
			for _, boardMethod in ipairs({"GetWeeklyBoard", "GetMonthlyBoard", "GetKillerBoard", "GetWarsBoard"}) do
				pcall(function()
					local boardData = fn:InvokeServer(boardMethod)
					if typeof(boardData) == "table" and typeof(boardData.Board) == "table" then
						for _, item in ipairs(boardData.Board) do
							registerGangItem(item)
						end
					end
				end)
			end
		end)

		-- Resolve LocalPlayer's gang via GetJoinedGang if not yet known
		if not GANG_SYS.playerGangMap[player.UserId] and not GANG_SYS.pendingFetches["local_player"] then
			GANG_SYS.pendingFetches["local_player"] = true
			task.spawn(function()
				pcall(function()
					local jGang = fn:InvokeServer("GetJoinedGang")
					if typeof(jGang) == "string" and jGang ~= "" then
						GANG_SYS.fetchGangData(jGang)
					end
				end)
			end)
		end

		return GANG_SYS.directory
	end,
	fetchAllGangRosters = function(force, onProgress)
		if GANG_SYS.isPreloadingRosters and not force then return end
		local now = tick()
		if not force and (now - GANG_SYS.lastRostersFetch < 90) and GANG_SYS.rostersLoadedCount > 0 then
			if onProgress then pcall(onProgress, GANG_SYS.rostersLoadedCount, GANG_SYS.rostersTotalCount, true) end
			return
		end

		if #GANG_SYS.directory == 0 then
			GANG_SYS.fetchDirectory(false)
		end

		local onlinePlrs = Players:GetPlayers()
		local onlineMap = {}
		local priorityMap = {}

		-- Build priority cues from currently online players
		for _, p in ipairs(onlinePlrs) do
			onlineMap[p.UserId] = true
			for _, attrName in ipairs({"TagHeaderText", "TagTitleText", "Gang", "GangName", "GangKey", "GangTag"}) do
				local val = p:GetAttribute(attrName)
				if typeof(val) == "string" and val ~= "" then
					local clean = string.gsub(val, "[%[%]]", "")
					clean = string.match(clean, "^%s*(.-)%s*$") or ""
					if clean ~= "" then priorityMap[string.lower(clean)] = true end
				end
			end
			local lName = GANG_SYS.getRpLastName and GANG_SYS.getRpLastName(p)
			if lName then priorityMap[string.lower(lName)] = true end

			-- Deep scan cues: extract bracketed tags [TAG] or clan words from DisplayName, Name, RP Name
			local function addWordCues(str)
				if typeof(str) ~= "string" or str == "" then return end
				for bTag in string.gmatch(str, "%[([%w%s%-_]+)%]") do
					priorityMap[string.lower(bTag)] = true
				end
				for w in string.gmatch(str, "[%w%-_]+") do
					if #w >= 3 and #w <= 14 then priorityMap[string.lower(w)] = true end
				end
			end
			addWordCues(p.DisplayName)
			addWordCues(p.Name)
			addWordCues(tostring(p:GetAttribute("RoleplayName") or ""))
			addWordCues(tostring(p:GetAttribute("TagText") or ""))
			if p.Character then
				for _, attr in ipairs({"Gang", "GangName", "GangKey", "GangTag", "Clan", "Crew", "RoleplayName"}) do
					local cv = p.Character:GetAttribute(attr)
					if typeof(cv) == "string" and cv ~= "" then
						priorityMap[string.lower(cv)] = true
						addWordCues(cv)
					end
				end
			end
		end

		-- Territory owner gangs are top priority
		local tFolder = ReplicatedStorage:FindFirstChild("Territories")
		if tFolder then
			for _, z in ipairs(tFolder:GetChildren()) do
				local o = z:GetAttribute("Owner")
				if typeof(o) == "string" and o ~= "" and o ~= "None" then
					priorityMap[string.lower(o)] = true
				end
			end
		end

		local queue = {}
		local priorityQueue = {}
		for _, g in ipairs(GANG_SYS.directory) do
			local k = g.Key or g.Name
			if k and (force or not GANG_SYS.gangsByKey[k] or typeof(GANG_SYS.gangsByKey[k].Members) ~= "table") then
				local kLow = string.lower(k)
				local nameLow = string.lower(g.Name or "")
				local tagLow = string.lower(g.Tag or "")
				local tagClean = string.gsub(tagLow, "[%[%]]", "")
				local isPrio = priorityMap[kLow] or priorityMap[nameLow] or priorityMap[tagLow] or (tagClean ~= "" and priorityMap[tagClean])
				if isPrio then
					table.insert(priorityQueue, k)
				else
					table.insert(queue, k)
				end
			end
		end

		-- Prepend priority gangs to front
		for i = #priorityQueue, 1, -1 do
			table.insert(queue, 1, priorityQueue[i])
		end

		GANG_SYS.rostersTotalCount = #queue
		GANG_SYS.rostersLoadedCount = 0

		if #queue == 0 then
			if onProgress then pcall(onProgress, 0, 0, true) end
			return
		end

		GANG_SYS.isPreloadingRosters = true
		GANG_SYS.lastRostersFetch = now

		trackThread(task.spawn(function()
			local nextIdx = 1
			local completed = 0
			local total = #queue
			local lastRosterRender = 0

			-- Use at most 2 gentle background workers with delay to prevent remote invocation queue exhaustion
			local numWorkers = math.clamp(math.min(total, 2), 1, 2)
			local activeWorkers = numWorkers

			for _ = 1, numWorkers do
				trackThread(task.spawn(function()
					while true do
						local myIdx = nextIdx
						nextIdx = nextIdx + 1
						if myIdx > total then break end

						local gKey = queue[myIdx]
						pcall(GANG_SYS.fetchGangData, gKey)
						completed = completed + 1
						GANG_SYS.rostersLoadedCount = completed

						if onProgress and (completed % 2 == 0 or completed == total) then
							pcall(onProgress, completed, total, completed == total)
						end

						-- Check if this gang has members online in this server
						local gData = GANG_SYS.gangsByKey[gKey]
						local hasServerMember = false
						if gData and typeof(gData.Members) == "table" then
							for mKey, _ in pairs(gData.Members) do
								local mUid = tonumber(string.match(tostring(mKey), "^(%d+)")) or tonumber(mKey)
								if mUid and onlineMap[mUid] then
									hasServerMember = true
									break
								end
							end
						end
						if not hasServerMember and gData and gData.CreatorKey then
							local cUid = tonumber(string.match(tostring(gData.CreatorKey), "^(%d+)")) or tonumber(gData.CreatorKey)
							if cUid and onlineMap[cUid] then
								hasServerMember = true
							end
						end

						local nowTick = tick()
						if GANG_SYS.onRosterUpdated and (hasServerMember or (nowTick - lastRosterRender >= 0.35) or completed == total) then
							lastRosterRender = nowTick
							pcall(GANG_SYS.onRosterUpdated)
						end

						task.wait(0.08)
					end

					activeWorkers = activeWorkers - 1
					if activeWorkers <= 0 then
						GANG_SYS.isPreloadingRosters = false
						if GANG_SYS.onRosterUpdated then pcall(GANG_SYS.onRosterUpdated) end
						if onProgress then pcall(onProgress, total, total, true) end
					end
				end))
			end
		end))
	end,
	fetchGangData = function(gangKey)
		if not gangKey or gangKey == "" then return nil end
		local fn = GANG_SYS.getRemoteFunction()
		if not fn then return GANG_SYS.gangsByKey[gangKey] end
		local ok, res = pcall(function()
			return fn:InvokeServer("GetGangData", gangKey)
		end)
		if ok and typeof(res) == "table" then
			GANG_SYS.gangsByKey[gangKey] = res
			if res.Key and res.Key ~= "" then GANG_SYS.gangsByKey[res.Key] = res end
			if res.Name and res.Name ~= "" then GANG_SYS.gangsByKey[res.Name] = res end

			local gTag = (res.Tag and res.Tag ~= "") and res.Tag or ("[" .. (res.Name or gangKey) .. "]")
			if typeof(res.Members) == "table" then
				for mKey, mData in pairs(res.Members) do
					local uid = tonumber(string.match(tostring(mKey), "^(%d+)")) or tonumber(mKey)
					if uid then
						local prev = GANG_SYS.playerGangMap[uid]
						local gName = res.Name or gangKey
						local targetPlr = Players:GetPlayerByUserId(uid)
						local isHidden = true
						if targetPlr then
							local liveHeader = tostring(targetPlr:GetAttribute("TagHeaderText") or "")
							if liveHeader ~= "" then
								local hLow = string.lower(liveHeader)
								local nLow = string.lower(gName)
								local tClean = string.gsub(string.lower(gTag), "[%[%]]", "")
								if (#nLow > 0 and string.find(hLow, nLow, 1, true) ~= nil) or
									(#tClean > 0 and string.find(hLow, tClean, 1, true) ~= nil) then
									isHidden = false
								end
							end
						end
						GANG_SYS.playerGangMap[uid] = {
							gangKey = res.Key or gangKey,
							gangName = gName,
							gangTag = gTag,
							role = typeof(mData) == "table" and mData.Rank or "Member",
							name = typeof(mData) == "table" and mData.Name or (prev and prev.name or "Member"),
							tagColor = prev and prev.tagColor or Color3.fromRGB(255, 90, 180),
							fromRoster = true,
							isTagHidden = isHidden,
						}
					end
				end
			end
			if res.CreatorKey then
				local cUid = tonumber(string.match(tostring(res.CreatorKey), "^(%d+)")) or tonumber(res.CreatorKey)
				if cUid and not GANG_SYS.playerGangMap[cUid] then
					local gName = res.Name or gangKey
					local targetPlr = Players:GetPlayerByUserId(cUid)
					local isHidden = true
					if targetPlr then
						local liveHeader = tostring(targetPlr:GetAttribute("TagHeaderText") or "")
						if liveHeader ~= "" then
							local hLow = string.lower(liveHeader)
							local nLow = string.lower(gName)
							local tClean = string.gsub(string.lower(gTag), "[%[%]]", "")
							if (#nLow > 0 and string.find(hLow, nLow, 1, true) ~= nil) or
								(#tClean > 0 and string.find(hLow, tClean, 1, true) ~= nil) then
								isHidden = false
							end
						end
					end
					GANG_SYS.playerGangMap[cUid] = {
						gangKey = res.Key or gangKey,
						gangName = gName,
						gangTag = gTag,
						role = "Boss",
						name = "Boss",
						tagColor = Color3.fromRGB(255, 195, 75),
						fromRoster = true,
						isTagHidden = isHidden,
					}
				end
			end
			return res
		end
		return GANG_SYS.gangsByKey[gangKey]
	end,
	findRegisteredGang = function(candidate)
		if not candidate or candidate == "" then return nil, nil end
		local low = string.lower(candidate)
		local clean = string.gsub(low, "[%[%]]", "")
		clean = string.match(clean, "^%s*(.-)%s*$") or ""
		if clean == "" then return nil, nil end

		for k, g in pairs(GANG_SYS.gangsByKey) do
			if typeof(g) == "table" and not g.fromNametag then
				local gName = string.lower(g.Name or k or "")
				local gTag = string.lower(g.Tag or "")
				local gTagClean = string.gsub(gTag, "[%[%]]", "")
				if gName == low or gName == clean or (gTagClean ~= "" and (gTagClean == clean or gTagClean == low)) then
					return k, g
				end
				if #clean >= 3 and (#gName > 0 and string.find(gName, clean, 1, true) ~= nil) then
					return k, g
				end
			end
		end

		for _, g in ipairs(GANG_SYS.directory) do
			if typeof(g) == "table" then
				local k = g.Key or g.Name
				local gName = string.lower(g.Name or k or "")
				local gTag = string.lower(g.Tag or "")
				local gTagClean = string.gsub(gTag, "[%[%]]", "")
				if gName == low or gName == clean or (gTagClean ~= "" and (gTagClean == clean or gTagClean == low)) then
					return k, g
				end
				if #clean >= 3 and (#gName > 0 and string.find(gName, clean, 1, true) ~= nil) then
					return k, g
				end
			end
		end

		return nil, nil
	end,
	syncServerGangRosters = function(onDone)
		local onlinePlrs = Players:GetPlayers()
		local onlineMap = {}
		for _, plr in ipairs(onlinePlrs) do
			onlineMap[plr.UserId] = plr
		end

		-- Check ReplicatedStorage.Territories for active gangs in server
		local tFolder = ReplicatedStorage:FindFirstChild("Territories")
		if tFolder then
			for _, z in ipairs(tFolder:GetChildren()) do
				local o = z:GetAttribute("Owner")
				if typeof(o) == "string" and o ~= "" and o ~= "None" then
					if not GANG_SYS.gangsByKey[o] and not GANG_SYS.pendingFetches[o] then
						GANG_SYS.pendingFetches[o] = true
						task.spawn(function()
							pcall(GANG_SYS.fetchGangData, o)
						end)
					end
				end
			end
		end

		-- 1. Match online players against all already-downloaded gang rosters
		for gKey, gData in pairs(GANG_SYS.gangsByKey) do
			if typeof(gData) == "table" and not gData.fromNametag then
				if typeof(gData.Members) == "table" then
					for mKey, mData in pairs(gData.Members) do
						local mUid = tonumber(string.match(tostring(mKey), "^(%d+)")) or tonumber(mKey)
						if mUid and onlineMap[mUid] then
							local plr = onlineMap[mUid]
							local gName = gData.Name or gKey
							local gTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. gName .. "]")
							GANG_SYS.playerGangMap[mUid] = {
								gangKey = gKey,
								gangName = gName,
								gangTag = gTag,
								role = typeof(mData) == "table" and mData.Rank or "Member",
								name = typeof(mData) == "table" and mData.Name or (plr.DisplayName or plr.Name),
								tagColor = Color3.fromRGB(255, 90, 180),
								fromRoster = true,
							}
						end
					end
				end
				if gData.CreatorKey then
					local cUid = tonumber(string.match(tostring(gData.CreatorKey), "^(%d+)")) or tonumber(gData.CreatorKey)
					if cUid and onlineMap[cUid] then
						local plr = onlineMap[cUid]
						local gName = gData.Name or gKey
						local gTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. gName .. "]")
						GANG_SYS.playerGangMap[cUid] = {
							gangKey = gKey,
							gangName = gName,
							gangTag = gTag,
							role = "Boss",
							name = plr.DisplayName or plr.Name,
							tagColor = Color3.fromRGB(255, 195, 75),
							fromRoster = true,
						}
					end
				end
			end
		end

		-- 2. Direct attribute checks on player and character (without requiring nametag)
		for _, plr in ipairs(onlinePlrs) do
			local uid = plr.UserId
			if not GANG_SYS.playerGangMap[uid] then
				for _, holder in ipairs({plr, plr.Character}) do
					if holder and not GANG_SYS.playerGangMap[uid] then
						for _, attrName in ipairs({"Gang", "GangName", "GangKey", "GangTag", "Clan", "Crew", "Faction"}) do
							local aVal = holder:GetAttribute(attrName)
							if typeof(aVal) == "string" and aVal ~= "" and not GANG_SYS.playerGangMap[uid] then
								local gKey, gData = GANG_SYS.findRegisteredGang(aVal)
								if gKey and gData then
									GANG_SYS.playerGangMap[uid] = {
										gangKey = gKey,
										gangName = gData.Name or gKey,
										gangTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. (gData.Name or gKey) .. "]"),
										role = tostring(holder:GetAttribute("GangRole") or plr:GetAttribute("GangRole") or "Member"),
										name = plr.DisplayName or plr.Name,
										tagColor = Color3.fromRGB(255, 90, 180),
										fromRoster = true,
									}
								else
									if not GANG_SYS.pendingFetches[aVal] then
										GANG_SYS.pendingFetches[aVal] = true
										task.spawn(function()
											pcall(GANG_SYS.fetchGangData, aVal)
										end)
									end
								end
							end
						end
					end
				end

				-- 3. Bracketed cue in DisplayName, Name, or RP Name (e.g. [CARTEL])
				if not GANG_SYS.playerGangMap[uid] then
					local function checkBracketCues(str)
						if typeof(str) ~= "string" or str == "" then return nil end
						for bTag in string.gmatch(str, "%[([%w%s%-_]+)%]") do
							local gKey, gData = GANG_SYS.findRegisteredGang(bTag)
							if gKey and gData then return gKey, gData end
						end
						return nil
					end
					local gKey, gData = checkBracketCues(plr.DisplayName)
					if not (gKey and gData) then
						gKey, gData = checkBracketCues(tostring(plr:GetAttribute("RoleplayName") or ""))
					end
					if not (gKey and gData) then
						gKey, gData = checkBracketCues(tostring(plr:GetAttribute("TagText") or ""))
					end
					if gKey and gData then
						GANG_SYS.playerGangMap[uid] = {
							gangKey = gKey,
							gangName = gData.Name or gKey,
							gangTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. (gData.Name or gKey) .. "]"),
							role = "Member",
							name = plr.DisplayName or plr.Name,
							tagColor = Color3.fromRGB(255, 90, 180),
							fromRoster = true,
						}
					end
				end

				-- 4. Overhead tag check (if equipped)
				local hText = plr:GetAttribute("TagHeaderText")
				local hName = plr:GetAttribute("TagHeaderName")
				if (hName == "GangHeader" or (typeof(hText) == "string" and hText ~= "")) and not GANG_SYS.playerGangMap[uid] then
					local candidate = typeof(hText) == "string" and hText or ""
					local clean = string.gsub(candidate, "[%[%]]", "")
					clean = string.match(clean, "^%s*(.-)%s*$") or ""
					if clean ~= "" then
						local foundKey, foundGang = GANG_SYS.findRegisteredGang(clean)
						local rawColor = plr:GetAttribute("TagHeaderColor")
						local resColor = Color3.fromRGB(255, 90, 180)
						if typeof(rawColor) == "Color3" then
							resColor = rawColor
						elseif typeof(rawColor) == "ColorSequence" and #rawColor.Keypoints > 0 then
							resColor = rawColor.Keypoints[1].Value
						end
						if foundKey and foundGang then
							GANG_SYS.playerGangMap[uid] = {
								gangKey = foundKey,
								gangName = foundGang.Name or foundKey,
								gangTag = (foundGang.Tag and foundGang.Tag ~= "") and foundGang.Tag or ("[" .. (foundGang.Name or foundKey) .. "]"),
								role = "Member",
								name = plr.DisplayName or plr.Name,
								tagColor = resColor,
								fromVerifiedTag = true,
							}
						else
							if not GANG_SYS.pendingFetches[clean] then
								GANG_SYS.pendingFetches[clean] = true
								task.spawn(function()
									pcall(function()
										local gData = GANG_SYS.fetchGangData(clean)
										if gData and (gData.Key or gData.Name) and gData.Members then
											local gKeyRes = gData.Key or gData.Name or clean
											GANG_SYS.playerGangMap[uid] = {
												gangKey = gKeyRes,
												gangName = gData.Name or gKeyRes,
												gangTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. (gData.Name or gKeyRes) .. "]"),
												role = "Member",
												name = plr.DisplayName or plr.Name,
												tagColor = resColor,
												fromVerifiedTag = true,
											}
										end
									end)
								end)
							end
						end
					end
				end
			end

			-- 5. Calculate isTagHidden for all mapped online players
			if GANG_SYS.playerGangMap[uid] then
				local info = GANG_SYS.playerGangMap[uid]
				local liveHeader = tostring(plr:GetAttribute("TagHeaderText") or "")
				if liveHeader == "" then
					local visuals = workspace:FindFirstChild("Visuals")
					local tagPart = visuals and visuals:FindFirstChild(plr.Name)
					local sg = tagPart and tagPart:FindFirstChildOfClass("SurfaceGui")
					local subLabel = sg and sg:FindFirstChild("Sub")
					if subLabel and subLabel.Text ~= "" then liveHeader = subLabel.Text end
				end
				local hLow = string.lower(liveHeader)
				local nLow = string.lower(info.gangName or "")
				local tClean = string.gsub(string.lower(info.gangTag or ""), "[%[%]]", "")
				local tagMatches = (liveHeader ~= "") and (
					(#nLow > 0 and string.find(hLow, nLow, 1, true) ~= nil) or
					(#tClean > 0 and string.find(hLow, tClean, 1, true) ~= nil)
				)
				info.isTagHidden = not tagMatches
			end
		end

		if onDone then pcall(onDone) end
	end,
	searchGang = function(query)
		local q = string.match(query or "", "^%s*(.-)%s*$")
		if #q == 0 then
			return GANG_SYS.fetchDirectory(true)
		end
		local fn = GANG_SYS.getRemoteFunction()
		if not fn then return {} end
		local ok, res = pcall(function()
			return fn:InvokeServer("SearchGang", q)
		end)
		if ok and typeof(res) == "table" then
			local list = {}
			if res.Key or res.Name then
				table.insert(list, res)
				local k = res.Key or res.Name
				GANG_SYS.gangsByKey[k] = res
			else
				for _, item in pairs(res) do
					if typeof(item) == "table" then
						table.insert(list, item)
					end
				end
			end
			return list
		end
		return {}
	end,
	getRpLastName = function(p)
		if not p then return nil end
		local fullName = ""
		local visuals = workspace:FindFirstChild("Visuals")
		local tagPart = visuals and visuals:FindFirstChild(p.Name)
		local sg = tagPart and tagPart:FindFirstChildOfClass("SurfaceGui")
		local main = sg and sg:FindFirstChild("Main")
		local lbl = main and main:FindFirstChild("Label")
		if lbl and lbl.Text ~= "" then
			fullName = lbl.Text
		else
			fullName = tostring(p:GetAttribute("RoleplayName") or "")
		end
		if fullName ~= "" then
			local parts = string.split(fullName, " ")
			if #parts >= 2 then
				local last = string.lower(string.match(parts[#parts], "^%s*(.-)%s*$") or "")
				if #last >= 3 then
					return last
				end
			end
		end
		return nil
	end,
	scanSuspectAssociates = function(gangsInServer, unaffiliatedPlrs)
		local suspects = {}
		local confirmedMembers = {}
		local gangLastNames = {}
		local gangRadioChannels = {}
		local territoryOwners = {}

		local tFolder = ReplicatedStorage:FindFirstChild("Territories")
		if tFolder then
			for _, tZone in ipairs(tFolder:GetChildren()) do
				local owner = tZone:GetAttribute("Owner")
				if owner and owner ~= "" and owner ~= "None" then
					territoryOwners[tZone.Name] = owner
				end
			end
		end

		for gKey, gData in pairs(gangsInServer) do
			for _, m in ipairs(gData.members) do
				table.insert(confirmedMembers, {
					player = m.player,
					name = m.name,
					displayName = m.displayName,
					userId = m.userId,
					gangKey = gKey,
					gangName = gData.name,
					gangColor = gData.color,
				})
				local lName = GANG_SYS.getRpLastName(m.player)
				if lName then
					gangLastNames[lName] = { gangKey = gKey, gangName = gData.name, memberName = m.displayName }
				end
				local rCh = m.player:GetAttribute("RadioChannel")
				if rCh and rCh ~= "" then
					gangRadioChannels[rCh] = { gangKey = gKey, gangName = gData.name }
				end
			end
		end

		if #confirmedMembers == 0 then return suspects end

		for _, p in ipairs(unaffiliatedPlrs) do
			local reasons = {}
			local linkedGangName = nil
			local linkedGangColor = Color3.fromRGB(255, 175, 75)

			for _, cm in ipairs(confirmedMembers) do
				local isFriend = false
				pcall(function()
					isFriend = p:IsFriendsWith(cm.userId)
				end)
				if isFriend then
					table.insert(reasons, "👥 Friend of @" .. cm.name .. " (" .. cm.gangName .. ")")
					if not linkedGangName then
						linkedGangName = cm.gangName
						linkedGangColor = cm.gangColor
					end
				end
			end

			local pLName = GANG_SYS.getRpLastName(p)
			if pLName and gangLastNames[pLName] then
				local fam = gangLastNames[pLName]
				table.insert(reasons, "🧬 " .. string.upper(pLName) .. " Family (" .. fam.gangName .. ")")
				if not linkedGangName then
					linkedGangName = fam.gangName
				end
			end

			local pTerritory = p:GetAttribute("Territory")
			if pTerritory and territoryOwners[pTerritory] then
				local tGang = territoryOwners[pTerritory]
				table.insert(reasons, "🏴 In " .. tGang .. " Territory (" .. pTerritory .. ")")
				if not linkedGangName then
					linkedGangName = tGang
				end
			end

			local pRadio = p:GetAttribute("RadioChannel")
			if pRadio and gangRadioChannels[pRadio] then
				local rGang = gangRadioChannels[pRadio]
				table.insert(reasons, "📻 Radio: " .. tostring(pRadio) .. " (" .. rGang.gangName .. ")")
				if not linkedGangName then
					linkedGangName = rGang.gangName
				end
			end

			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, cm in ipairs(confirmedMembers) do
					local cmChar = cm.player.Character
					local cmHrp = cmChar and cmChar:FindFirstChild("HumanoidRootPart")
					if cmHrp then
						local dist = (hrp.Position - cmHrp.Position).Magnitude
						if dist <= 28 then
							table.insert(reasons, string.format("📍 Near @%s (%d studs)", cm.name, math.floor(dist)))
							if not linkedGangName then
								linkedGangName = cm.gangName
								linkedGangColor = cm.gangColor
							end
							break
						end
					end
				end
			end

			if #reasons > 0 then
				table.insert(suspects, {
					player = p,
					name = p.Name,
					displayName = p.DisplayName,
					userId = p.UserId,
					linkedGang = linkedGangName or "Unknown",
					color = linkedGangColor,
					reasons = reasons,
				})
			end
		end

		return suspects
	end,
	getPlayerGang = function(userId)
		if not userId then return nil end

		local p = nil
		if typeof(userId) == "Instance" and userId:IsA("Player") then
			p = userId
			userId = p.UserId
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.UserId == userId then
					p = plr
					break
				end
			end
		end

		local liveHeader = ""
		local tagHeaderName = ""
		local tagColor = nil
		if p then
			tagHeaderName = tostring(p:GetAttribute("TagHeaderName") or "")
			liveHeader = tostring(p:GetAttribute("TagHeaderText") or "")
			local rawTagCol = p:GetAttribute("TagHeaderColor")
			if typeof(rawTagCol) == "Color3" then
				tagColor = rawTagCol
			elseif typeof(rawTagCol) == "ColorSequence" and #rawTagCol.Keypoints > 0 then
				tagColor = rawTagCol.Keypoints[1].Value
			end

			if liveHeader == "" then
				local visuals = workspace:FindFirstChild("Visuals")
				local tagPart = visuals and visuals:FindFirstChild(p.Name)
				local sg = tagPart and tagPart:FindFirstChildOfClass("SurfaceGui")
				if sg then
					local subLabel = sg:FindFirstChild("Sub")
					if subLabel and subLabel.Text ~= "" then
						liveHeader = subLabel.Text
						if not tagColor then tagColor = subLabel.TextColor3 end
					end
				end
			end
		end

		local function checkTagVisible(gName, gTag)
			if not p or liveHeader == "" then return false end
			local hLower = string.lower(liveHeader)
			local nameLow = string.lower(gName or "")
			local tagLow = string.lower(gTag or "")
			local tagClean = string.gsub(tagLow, "[%[%]]", "")
			if #nameLow > 0 and string.find(hLower, nameLow, 1, true) then
				return true
			end
			if #tagClean > 0 and string.find(hLower, tagClean, 1, true) then
				return true
			end
			return false
		end

		-- 1. Check cached playerGangMap (from server directory roster or GetGangData)
		local cached = GANG_SYS.playerGangMap[userId]
		if cached and cached.gangKey then
			cached.isTagHidden = not checkTagVisible(cached.gangName, cached.gangTag)
			if tagColor and not cached.tagColor then
				if typeof(tagColor) == "Color3" then
					cached.tagColor = tagColor
				elseif typeof(tagColor) == "ColorSequence" and #tagColor.Keypoints > 0 then
					cached.tagColor = tagColor.Keypoints[1].Value
				end
			end
			return cached
		end

		-- 2. Direct Player Attributes check (without needing nametag)
		if p then
			for _, attr in ipairs({"Gang", "GangName", "GangKey", "GangTag"}) do
				local val = p:GetAttribute(attr)
				if typeof(val) == "string" and val ~= "" then
					local gKey, gData = GANG_SYS.findRegisteredGang(val)
					if gKey and gData then
						local gName = gData.Name or gKey
						local gTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. gName .. "]")
						local info = {
							gangKey = gKey,
							gangName = gName,
							gangTag = gTag,
							role = tostring(p:GetAttribute("GangRole") or "Member"),
							name = p.DisplayName or p.Name,
							tagColor = tagColor or Color3.fromRGB(255, 90, 180),
							fromRoster = true,
							isTagHidden = not checkTagVisible(gName, gTag),
						}
						GANG_SYS.playerGangMap[userId] = info
						return info
					end
				end
			end
		end

		-- 3. Check directory gang rosters in GANG_SYS.gangsByKey
		local uPrefix = tostring(userId) .. ">"
		for gKey, gData in pairs(GANG_SYS.gangsByKey) do
			if typeof(gData.Members) == "table" and not gData.fromNametag then
				for mKey, mData in pairs(gData.Members) do
					local mUid = tonumber(string.match(tostring(mKey), "^(%d+)"))
					if mUid == userId or string.sub(mKey, 1, #uPrefix) == uPrefix or tostring(mKey) == tostring(userId) then
						local gName = gData.Name or gKey
						local gTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. gName .. "]")
						local info = {
							gangKey = gKey,
							gangName = gName,
							gangTag = gTag,
							role = typeof(mData) == "table" and mData.Rank or "Member",
							name = typeof(mData) == "table" and mData.Name or (p and (p.DisplayName or p.Name) or "Member"),
							tagColor = Color3.fromRGB(255, 90, 180),
							fromRoster = true,
							isTagHidden = not checkTagVisible(gName, gTag),
						}
						GANG_SYS.playerGangMap[userId] = info
						return info
					end
				end
			end
			-- Check CreatorKey
			if gData.CreatorKey then
				local cUid = tonumber(string.match(tostring(gData.CreatorKey), "^(%d+)"))
				if cUid == userId or string.sub(tostring(gData.CreatorKey), 1, #uPrefix) == uPrefix or tostring(gData.CreatorKey) == tostring(userId) then
					local gName = gData.Name or gKey
					local gTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. gName .. "]")
					local info = {
						gangKey = gKey,
						gangName = gName,
						gangTag = gTag,
						role = "Boss",
						name = p and (p.DisplayName or p.Name) or "Boss",
						tagColor = Color3.fromRGB(255, 195, 75),
						fromRoster = true,
						isTagHidden = not checkTagVisible(gName, gTag),
					}
					GANG_SYS.playerGangMap[userId] = info
					return info
				end
			end
		end

		-- 3. Check live overhead nametag only if it's GangHeader and matches a registered gang
		if p and (tagHeaderName == "GangHeader" or liveHeader ~= "") then
			local candidate = liveHeader ~= "" and liveHeader or ""
			local foundKey, foundGang = GANG_SYS.findRegisteredGang(candidate)
			if foundKey and foundGang then
				local gName = foundGang.Name or foundKey
				local gTag = (foundGang.Tag and foundGang.Tag ~= "") and foundGang.Tag or ("[" .. gName .. "]")
				local cColor = Color3.fromRGB(255, 90, 180)
				if typeof(tagColor) == "Color3" then
					cColor = tagColor
				elseif typeof(tagColor) == "ColorSequence" and #tagColor.Keypoints > 0 then
					cColor = tagColor.Keypoints[1].Value
				end

				local info = {
					gangKey = foundKey,
					gangName = gName,
					gangTag = gTag,
					role = "Member",
					name = p.DisplayName or p.Name,
					tagColor = cColor,
					fromVerifiedTag = true,
					isTagHidden = false,
				}
				GANG_SYS.playerGangMap[userId] = info
				return info
			end
		end

		return nil
	end,
	openNativeGangMenu = function()
		pcall(function()
			local pGui = player:FindFirstChild("PlayerGui")
			local mGui = pGui and pGui:FindFirstChild("MainGui")
			local lBrowser = mGui and mGui:FindFirstChild("Left") and mGui.Left:FindFirstChild("Browser")
			local gBtn = lBrowser and lBrowser:FindFirstChild("Gang")
			if gBtn and gBtn:IsA("GuiButton") then
				for _, c in ipairs(getconnections(gBtn.Activated)) do
					pcall(c.Fire, c)
				end
				for _, c in ipairs(getconnections(gBtn.MouseButton1Click)) do
					pcall(c.Fire, c)
				end
			end
			local cGang = mGui and mGui:FindFirstChild("Center") and mGui.Center:FindFirstChild("Gang")
			if cGang then
				cGang.Visible = true
			end
		end)
	end,
}

local ADMIN_SYS: { [string]: any } = {
	isStaffRadarEnabled = true,
	staffRadarBanner = nil,
	updateStaffRadar = function() end,
	showStaffAlertBanner = function(sPlr, roleName, rank) end,
	showAdminJoinBubble = function(sPlr, roleName, rank, joinTime, adminIndex) end,
	showExploitAlertBubble = function(sPlr, detectType, detail) end,
	dismissExpBubble = function() end,
	expTargetPlr = nil,
	EXECUTOR_DETECTOR = nil,
	apbWantedUsers = {},
	updateApbList = function() end,
	isPlayerWanted = function(plr) return false, nil end,
	hackersSaveDebounceTimer = nil,
	hackerRefreshDebounceTimer = nil,
	lastGlobalExploitAlert = 0,
	GLOBAL_SPY_REGISTRY = nil,
	globalSpies = {},
	-- Server browser staff visibility (view only). Kept on ADMIN_SYS to avoid new top-level locals.
	serverStaffRoster = {},
	serverStaffRevealEnabled = true,
	serverStaffWindow = nil,
	scanServerStaff = function() return {} end,
	refreshStaffRoster = function(force) end,
	decorateNativeServerList = function() end,
	clearNativeStaffMarks = function() end,
	installServerBrowserHook = function() end,
	refreshServerStaffGui = function() end,
	toggleServerStaffGui = function() end,
	-- Cross-server Blacklist Tracker
	locateBlacklistedPlayer = function(userId) return { status = "UNKNOWN" } end,
	teleportToServer = function(serverId) end,
	showServerBrowserForBlacklist = function() end,
	showBlacklistMoveBubble = function(blRec, loc) end,
	unblacklistUserId = function(userId) return false end,
	blacklistUser = function(userId, username, displayName) return false end,
	getBlacklistedUsers = function() return {} end,
}

local outfitWindow = nil
local OUTFIT_SYS = nil
toggleOutfitGui = function()
	if not outfitWindow then return end
	outfitWindow.Visible = not outfitWindow.Visible
	if outfitWindow.Visible then
		if clampPositionToScreen then
			outfitWindow.Position = clampPositionToScreen(outfitWindow.Position, outfitWindow.Size)
		end
		pcall(function()
			if OUTFIT_SYS and type(OUTFIT_SYS.updateGuiButtons) == "function" then
				OUTFIT_SYS.updateGuiButtons()
			end
			if OUTFIT_SYS and type(OUTFIT_SYS.refreshPreview) == "function" then
				OUTFIT_SYS.refreshPreview()
			end
		end)
	end
end

do
	OUTFIT_SYS = {
		activeOutfit = nil,
		defaultSnapshot = nil,
		outfitItemsCache = nil,
		outfitButtons = {},
		auraEmitters = {},
		activeStatusLabel = nil,
		roles = {
			{ id = "Warden", name = "Warden", title = "Prison Warden / Chief", titleTh = "Prison Warden / Chief", dept = "Security", color = Color3.fromRGB(255, 60, 80), icon = "🎖️" },
			{ id = "Captain", name = "Captain", title = "Head Captain", titleTh = "Head Captain", dept = "Security", color = Color3.fromRGB(255, 120, 50), icon = "⭐" },
			{ id = "Sergeant", name = "Sergeant", title = "Security Sergeant", titleTh = "Security Sergeant", dept = "Security", color = Color3.fromRGB(240, 180, 40), icon = "🛡️" },
			{ id = "Guard", name = "Guard", title = "Prison Guard", titleTh = "Prison Guard", dept = "Security", color = Color3.fromRGB(0, 180, 255), icon = "👮" },
			{ id = "Cadet", name = "Cadet", title = "Trainee Cadet", titleTh = "Trainee Cadet", dept = "Security", color = Color3.fromRGB(100, 210, 255), icon = "🔰" },
			{ id = "Bodyguard", name = "Bodyguard", title = "Personal Bodyguard", titleTh = "Personal Bodyguard", dept = "Security", color = Color3.fromRGB(160, 160, 180), icon = "🕶️" },
			{ id = "Surgeon", name = "Surgeon", title = "Chief Surgeon", titleTh = "Chief Surgeon", dept = "Medical", color = Color3.fromRGB(0, 230, 160), icon = "💉" },
			{ id = "Medic", name = "Medic", title = "Paramedic Officer", titleTh = "Paramedic Officer", dept = "Medical", color = Color3.fromRGB(50, 220, 130), icon = "🩺" },
			{ id = "Nurse", name = "Nurse", title = "Clinical Nurse", titleTh = "Clinical Nurse", dept = "Medical", color = Color3.fromRGB(120, 240, 180), icon = "🩹" },
			{ id = "Psychologist", name = "Psychologist", title = "Prison Psychologist", titleTh = "Prison Psychologist", dept = "Medical", color = Color3.fromRGB(180, 120, 255), icon = "🧠" },
			{ id = "Teacher", name = "Teacher", title = "Prison Educator", titleTh = "Prison Educator", dept = "Staff", color = Color3.fromRGB(255, 170, 90), icon = "📚" },
			{ id = "Cook", name = "Cook", title = "Head Kitchen Chef", titleTh = "Head Kitchen Chef", dept = "Staff", color = Color3.fromRGB(255, 200, 110), icon = "👨‍🍳" },
			{ id = "Janitor", name = "Janitor", title = "Facility Custodian", titleTh = "Facility Custodian", dept = "Staff", color = Color3.fromRGB(160, 200, 160), icon = "🧹" },
			{ id = "Prisoner", name = "Prisoner", title = "Inmate / Convict", titleTh = "Inmate / Convict", dept = "Inmate", color = Color3.fromRGB(255, 140, 0), icon = "⛓️" },
			{ id = "Ghost", name = "Ghost", title = "Phantom Inmate", titleTh = "Phantom Inmate", dept = "Special", color = Color3.fromRGB(200, 220, 255), icon = "👻" },
			{ id = "SkyCupRed", name = "SkyCup Red", title = "Red Team Striker", titleTh = "Red Team Striker", dept = "Sports", color = Color3.fromRGB(255, 70, 70), icon = "⚽" },
			{ id = "SkyCupBlue", name = "SkyCup Blue", title = "Blue Team Striker", titleTh = "Blue Team Striker", dept = "Sports", color = Color3.fromRGB(60, 130, 255), icon = "⚽" },
		},
		updateGuiButtons = function() end,
		applyOutfit = function(roleId) return false end,
		resetDefault = function() end,
		refreshPreview = function() end,
		previewRole = function(roleId) end,
	}

	local AppearanceModule = nil
	pcall(function()
		local modules = ReplicatedStorage:FindFirstChild("Modules")
		if modules then
			local appMod = modules:FindFirstChild("AppearanceModule")
			if appMod and appMod:IsA("ModuleScript") then
				AppearanceModule = require(appMod)
			end
		end
	end)

	local function isGameOutfitItem(itemName)
		if not OUTFIT_SYS.outfitItemsCache then
			OUTFIT_SYS.outfitItemsCache = {}
			local outfits = ReplicatedStorage:FindFirstChild("Outfits")
			if outfits then
				for _, folder in ipairs(outfits:GetChildren()) do
					for _, item in ipairs(folder:GetChildren()) do
						if item:IsA("Configuration") or item:IsA("Accessory") then
							OUTFIT_SYS.outfitItemsCache[item.Name] = true
						end
					end
				end
			end
		end
		return OUTFIT_SYS.outfitItemsCache[itemName] == true
	end
	OUTFIT_SYS.isGameOutfitItem = isGameOutfitItem

	local function saveDefaultSnapshot(char)
		if not char then return end
		if OUTFIT_SYS.defaultSnapshot and OUTFIT_SYS.defaultSnapshot.character == char then
			return
		end

		local snapshot = {
			character = char,
			bodyColors = nil,
			shirtTemplate = nil,
			pantsTemplate = nil,
			limbDecals = {},
		}

		local bc = char:FindFirstChildOfClass("BodyColors")
		if bc then
			snapshot.bodyColors = {
				HeadColor3 = bc.HeadColor3,
				TorsoColor3 = bc.TorsoColor3,
				LeftArmColor3 = bc.LeftArmColor3,
				RightArmColor3 = bc.RightArmColor3,
				LeftLegColor3 = bc.LeftLegColor3,
				RightLegColor3 = bc.RightLegColor3,
			}
		end

		local shirt = char:FindFirstChildOfClass("Shirt")
		if shirt then
			snapshot.shirtTemplate = shirt.ShirtTemplate
		end
		local pants = char:FindFirstChildOfClass("Pants")
		if pants then
			snapshot.pantsTemplate = pants.PantsTemplate
		end

		for _, limbName in ipairs({"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
			local limb = char:FindFirstChild(limbName)
			if limb then
				snapshot.limbDecals[limbName] = {}
				for _, child in ipairs(limb:GetChildren()) do
					if child:IsA("Decal") and not child:GetAttribute("AstrocynaOutfitDecal") then
						local colVal = nil
						pcall(function() colVal = child.ColorMapContent end)
						snapshot.limbDecals[limbName][child.Name] = {
							ColorMapContent = colVal,
							Texture = child.Texture,
							Transparency = child.Transparency,
						}
					end
				end
			end
		end

		OUTFIT_SYS.defaultSnapshot = snapshot
	end

	OUTFIT_SYS.attachOutfitItem = function(item, targetChar, isPreview)
		local handle = item:FindFirstChild("Handle") or (item:IsA("BasePart") and item) or item:FindFirstChildWhichIsA("BasePart", true)
		if not handle or not handle:IsA("BasePart") then return end

		handle.CanCollide = false
		handle.Transparency = 0

		if isPreview then
			for _, p in ipairs(item:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.Anchored = true
					p.Transparency = 0
				end
			end
		else
			handle.Anchored = false
			handle.Massless = true
			for _, p in ipairs(item:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.Massless = true
				end
			end
		end

		local att = handle:FindFirstChildOfClass("Attachment")
		local attName = att and att.Name or (item:IsA("Configuration") and "HeadAttachment" or "HatAttachment")

		local attOffsets = {
			HatAttachment = Vector3.new(0, -0.6, 0),
			HeadAttachment = Vector3.new(0, 0, 0),
			HairAttachment = Vector3.new(0, -0.6, 0),
			FaceFrontAttachment = Vector3.new(0, 0, 0.6),
		}

		local targetPart = nil
		local targetC0 = nil
		local targetC1 = nil

		if item:IsA("Configuration") or attName == "HeadAttachment" then
			-- PRP Native Role Caps (Sergeant's Cap, Guard's Cap, Captain's Cap)
			targetPart = targetChar:FindFirstChild("Head")
			if targetPart then
				local attPos = att and att.Position or Vector3.new(0, 0, 0)
				local attRot = att and (att.CFrame - att.Position) or CFrame.new()
				local offset = attOffsets[attName] or Vector3.new(0, 0, 0)
				targetC0 = CFrame.new(0, 0, 0)
				targetC1 = CFrame.new(attPos + offset) * attRot
			end
		end

		if not targetPart then
			for _, pName in ipairs({"Head", "Torso", "UpperTorso", "Right Arm", "Left Arm", "Right Leg", "Left Leg"}) do
				local p = targetChar:FindFirstChild(pName)
				if p and p:IsA("BasePart") then
					local m = p:FindFirstChild(attName)
					if m and m:IsA("Attachment") then
						targetPart = p
						targetC0 = m.CFrame
						targetC1 = att and att.CFrame or CFrame.new(0, 0, 0)
						break
					end
				end
			end
		end

		if not targetPart then
			local low = string.lower(attName)
			if string.find(low, "hat") or string.find(low, "hair") or string.find(low, "face") or string.find(low, "head") then
				targetPart = targetChar:FindFirstChild("Head")
				if attName == "HatAttachment" and targetPart and targetPart:FindFirstChild("HatAttachment") then
					targetC0 = targetPart.HatAttachment.CFrame
					targetC1 = att and att.CFrame or CFrame.new(0, 0, 0)
				else
					targetC0 = CFrame.new(0, 0, 0)
					targetC1 = att and att.CFrame or CFrame.new(0, 0, 0)
				end
			elseif string.find(low, "body") or string.find(low, "torso") or string.find(low, "waist") or string.find(low, "neck") or string.find(low, "collar") or string.find(low, "chest") then
				targetPart = targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
				local bodyAtt = targetPart and (targetPart:FindFirstChild(attName) or targetPart:FindFirstChild("BodyFrontAttachment") or targetPart:FindFirstChild("WaistCenterAttachment") or targetPart:FindFirstChild("NeckAttachment"))
				targetC0 = bodyAtt and bodyAtt.CFrame or CFrame.new(0, 0, 0)
				targetC1 = att and att.CFrame or CFrame.new(0, 0, 0)
			else
				targetPart = targetChar:FindFirstChild("Head")
				targetC0 = CFrame.new(0, 0, 0)
				targetC1 = att and att.CFrame or CFrame.new(0, 0, 0)
			end
		end

		if not targetPart then return end

		targetC0 = targetC0 or CFrame.new(0, 0, 0)
		targetC1 = targetC1 or CFrame.new(0, 0, 0)

		if isPreview then
			local worldCF = targetPart.CFrame * targetC0 * targetC1:Inverse()
			handle.CFrame = worldCF

			for _, other in ipairs(item:GetDescendants()) do
				if other:IsA("BasePart") and other ~= handle then
					other.Anchored = true
					other.CanCollide = false
					local w = other:FindFirstChildOfClass("Weld") or other:FindFirstChildOfClass("ManualWeld")
					if w and w.Part0 == handle and w.Part1 == other then
						other.CFrame = handle.CFrame * w.C0 * w.C1:Inverse()
					end
				end
			end
		else
			for _, w in ipairs(handle:GetChildren()) do
				if w:IsA("Weld") or w:IsA("ManualWeld") or w:IsA("WeldConstraint") then
					pcall(function() w:Destroy() end)
				end
			end

			local weld = Instance.new("Weld")
			weld.Name = "AccessoryWeld"
			weld.Part0 = targetPart
			weld.Part1 = handle
			weld.C0 = targetC0
			weld.C1 = targetC1
			weld.Parent = handle
		end
	end

	local function clearOutfitItems(char)
		if not char then return end
		for _, item in ipairs(char:GetChildren()) do
			if (item:IsA("Configuration") or item:IsA("Accessory")) and (isGameOutfitItem(item.Name) or item:GetAttribute("AstrocynaOutfitItem")) then
				pcall(function() item:Destroy() end)
			elseif item:IsA("Decal") and item:GetAttribute("AstrocynaOutfitDecal") then
				pcall(function() item:Destroy() end)
			end
		end

		-- Clean up stale cards from game's native Wardrobe GUI
		pcall(function()
			local pGui = player:FindFirstChild("PlayerGui")
			local mainGui = pGui and pGui:FindFirstChild("MainGui")
			local movable = mainGui and mainGui:FindFirstChild("Movable")
			local wardrobe = movable and movable:FindFirstChild("Wardrobe")
			local pages = wardrobe and wardrobe:FindFirstChild("Pages")
			local accessories = pages and pages:FindFirstChild("Accessories")
			if accessories then
				for _, card in ipairs(accessories:GetChildren()) do
					if card:IsA("ImageButton") and card.Name ~= "Template" then
						local found = char:FindFirstChild(card.Name)
						if not found then
							card:Destroy()
						end
					end
				end
			end
		end)
	end

	-- =====================================================================
	-- WARDROBE BRIDGE (Synchronization with Native Game Wardrobe GUI)
	-- =====================================================================
	local WARDROBE_BRIDGE = {
		hookedCards = setmetatable({}, { __mode = "k" }),
		watchedContainers = setmetatable({}, { __mode = "k" }),
		lastActionTimes = {},
	}

	local function setClothingHidden(char, itemType, isHidden)
		if not char then return end

		-- 1. Main Decal on Character root (directly observed by game's native Wardrobe GUI)
		local mainDecal = char:FindFirstChild(itemType)
		if mainDecal and mainDecal:IsA("Decal") then
			pcall(function()
				mainDecal:SetAttribute("Hidden", isHidden)
				mainDecal.Transparency = isHidden and 1 or 0
			end)
		end

		-- 2. Decals on Limbs (Torso, Left Arm/Leg, Right Arm/Leg)
		local limbs = (itemType == "Shirt") and {"Torso", "Left Arm", "Right Arm"} or {"Torso", "Left Leg", "Right Leg"}
		for _, limbName in ipairs(limbs) do
			local limb = char:FindFirstChild(limbName)
			if limb then
				for _, child in ipairs(limb:GetChildren()) do
					if child:IsA("Decal") and child.Name == itemType then
						pcall(function()
							child.Transparency = isHidden and 1 or 0
						end)
					end
				end
			end
		end

		-- 3. Standard Roblox Shirt / Pants instance if present
		local robloxClass = (itemType == "Shirt") and "Shirt" or "Pants"
		local robloxItem = char:FindFirstChildOfClass(robloxClass)
		if robloxItem then
			pcall(function()
				local prop = (itemType == "Shirt") and "ShirtTemplate" or "PantsTemplate"
				if isHidden then
					if not robloxItem:GetAttribute("AstrocynaSavedTemplate") then
						robloxItem:SetAttribute("AstrocynaSavedTemplate", robloxItem[prop])
					end
					robloxItem[prop] = ""
				else
					local saved = robloxItem:GetAttribute("AstrocynaSavedTemplate")
					if saved then
						robloxItem[prop] = saved
						robloxItem:SetAttribute("AstrocynaSavedTemplate", nil)
					end
				end
			end)
		end

		-- 4. Notify AppearanceModule coverage if available
		if AppearanceModule and type(AppearanceModule.WatchCoverage) == "function" then
			pcall(function() AppearanceModule:WatchCoverage(char) end)
		end
	end

	local function setAccessoryHidden(acc, isHidden)
		if not acc then return end
		pcall(function()
			acc:SetAttribute("Hidden", isHidden)
		end)

		for _, desc in ipairs(acc:GetDescendants()) do
			if desc:IsA("BasePart") then
				pcall(function()
					if isHidden then
						if not desc:GetAttribute("SavedOutfitTransparency") then
							desc:SetAttribute("SavedOutfitTransparency", desc.Transparency)
						end
						desc.Transparency = 1
					else
						local saved = desc:GetAttribute("SavedOutfitTransparency")
						desc.Transparency = (typeof(saved) == "number") and saved or 0
						desc:SetAttribute("SavedOutfitTransparency", nil)
					end
				end)
			end
		end
	end

	local function handleWardrobeAction(action, target)
		if not target then return end
		local isHidden = (action == "Hide" or action == true)
		local targetName = (typeof(target) == "string") and target or target.Name

		local now = os.clock()
		if WARDROBE_BRIDGE.lastActionTimes[targetName] and (now - WARDROBE_BRIDGE.lastActionTimes[targetName] < 0.2) then
			return
		end
		WARDROBE_BRIDGE.lastActionTimes[targetName] = now

		local char = player.Character
		if not char then return end

		if targetName == "Shirt" or targetName == "Pants" then
			setClothingHidden(char, targetName, isHidden)
		else
			local acc = (typeof(target) == "Instance" and target.Parent == char) and target or char:FindFirstChild(targetName)
			if acc then
				setAccessoryHidden(acc, isHidden)
			end
		end
	end

	local function getWardrobeAccessoriesContainer()
		local pGui = player:FindFirstChild("PlayerGui")
		local mainGui = pGui and pGui:FindFirstChild("MainGui")
		local movable = mainGui and mainGui:FindFirstChild("Movable")
		local wardrobe = movable and movable:FindFirstChild("Wardrobe")
		local pages = wardrobe and wardrobe:FindFirstChild("Pages")
		return pages and pages:FindFirstChild("Accessories")
	end

	-- Keeps exactly one card per item name (newest wins) and drops cards whose item no longer exists on the character
	local function dedupeWardrobeCards(container)
		if not container or not container.Parent then return end
		local char = player.Character
		local seen = {}
		local children = container:GetChildren()
		for i = #children, 1, -1 do
			local card = children[i]
			if card:IsA("ImageButton") and card.Name ~= "Template" then
				if seen[card.Name] then
					pcall(function() card:Destroy() end)
				elseif char and not char:FindFirstChild(card.Name) then
					pcall(function() card:Destroy() end)
				else
					seen[card.Name] = true
				end
			end
		end
	end

	local wardrobeSweepQueued = false
	local function scheduleWardrobeSweep(delay)
		if wardrobeSweepQueued then return end
		wardrobeSweepQueued = true
		task.delay(delay or 0.15, function()
			wardrobeSweepQueued = false
			local container = getWardrobeAccessoriesContainer()
			if container then
				dedupeWardrobeCards(container)
			end
		end)
	end

	-- Removes duplicate Shirt/Pants decals and same-named accessories from the character (our items take priority over native ones)
	local function dedupeCharacterItems(char)
		if not char then return end
		local list = char:GetChildren()
		local seen = {}
		for pass = 1, 2 do
			for _, item in ipairs(list) do
				if item.Parent == char and (item:IsA("Accessory") or item:IsA("Configuration") or (item:IsA("Decal") and (item.Name == "Shirt" or item.Name == "Pants"))) then
					local isOurs = item:GetAttribute("AstrocynaOutfitItem") ~= nil or item:GetAttribute("AstrocynaOutfitDecal") ~= nil
					if (pass == 1) == isOurs then
						if seen[item.Name] then
							pcall(function() item:Destroy() end)
						else
							seen[item.Name] = true
						end
					end
				end
			end
		end
	end

	local function hookWardrobeCard(card)
		if not card or not card:IsA("ImageButton") or card.Name == "Template" then return end
		if WARDROBE_BRIDGE.hookedCards[card] then return end
		WARDROBE_BRIDGE.hookedCards[card] = true

		card.MouseButton1Click:Connect(function()
			local name = card.Name
			local char = player.Character
			if not char then return end

			if name == "Shirt" or name == "Pants" then
				local decal = char:FindFirstChild(name)
				if decal then
					local isHidden = decal:GetAttribute("Hidden") == true
					handleWardrobeAction(not isHidden and "Hide" or "Unhide", decal)
				end
			else
				local acc = char:FindFirstChild(name)
				if acc then
					local isHidden = acc:GetAttribute("Hidden") == true
					handleWardrobeAction(not isHidden and "Hide" or "Unhide", acc)
				end
			end
		end)
	end

	local function setupWardrobeGuiWatcher()
		local function scanAccessoriesContainer(container)
			if not container then return end
			dedupeWardrobeCards(container)
			for _, child in ipairs(container:GetChildren()) do
				hookWardrobeCard(child)
			end
			if WARDROBE_BRIDGE.watchedContainers[container] then return end
			WARDROBE_BRIDGE.watchedContainers[container] = true
			container.ChildAdded:Connect(function(child)
				task.wait(0.05)
				hookWardrobeCard(child)
				scheduleWardrobeSweep(0.15)
			end)
		end

		local function checkGui()
			local pGui = player:FindFirstChild("PlayerGui")
			if not pGui then return end
			local mainGui = pGui:FindFirstChild("MainGui")
			local movable = mainGui and mainGui:FindFirstChild("Movable")
			local wardrobe = movable and movable:FindFirstChild("Wardrobe")
			local pages = wardrobe and wardrobe:FindFirstChild("Pages")
			local accessories = pages and pages:FindFirstChild("Accessories")
			if accessories then
				scanAccessoriesContainer(accessories)
			end
		end

		checkGui()

		pcall(function()
			local pGui = player:WaitForChild("PlayerGui", 5)
			if pGui then
				pGui.ChildAdded:Connect(function(child)
					task.wait(0.1)
					local pages = child:FindFirstChild("Pages", true)
					local acc = pages and pages:FindFirstChild("Accessories")
					if acc then
						scanAccessoriesContainer(acc)
					end
				end)
			end
		end)
	end

	local function setupWardrobeRemoteHook()
		if env._AstrocynaWardrobeHooked then return end
		env._AstrocynaWardrobeHooked = true

		pcall(function()
			if hookmetamethod then
				local oldNamecall
				local namecallHook = function(self, ...)
					if checkcaller and checkcaller() then
						return oldNamecall(self, ...)
					end
					local method = getnamecallmethod()
					if (method == "FireServer" or method == "fireServer") and self and self.Name == "Set" and self.Parent and self.Parent.Name == "Clothing" then
						local action, target = ...
						pcall(function()
							handleWardrobeAction(action, target)
						end)
					end
					return oldNamecall(self, ...)
				end
				oldNamecall = hookmetamethod(game, "__namecall", toCClosure(namecallHook))
			end
		end)

		pcall(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local clothing = remotes and remotes:FindFirstChild("Clothing")
			local setRemote = clothing and clothing:FindFirstChild("Set")
			if setRemote and hookfunction and setRemote.FireServer then
				local oldFire
				local fireHook = function(self, ...)
					if checkcaller and checkcaller() then
						return oldFire(self, ...)
					end
					local action, target = ...
					pcall(function()
						handleWardrobeAction(action, target)
					end)
					return oldFire(self, ...)
				end
				oldFire = hookfunction(setRemote.FireServer, toCClosure(fireHook))
			end
		end)
	end

	task.spawn(setupWardrobeGuiWatcher)
	task.spawn(setupWardrobeRemoteHook)

	-- Apply Outfit with complete Wardrobe GUI compatibility
	local applyingOutfit = false
	local function applyOutfitInner(roleId)
		if not roleId then return false end
		OUTFIT_SYS.activeOutfit = roleId
		pcall(OUTFIT_SYS.updateGuiButtons)

		local char = player.Character
		if not char then return false end

		local outfits = ReplicatedStorage:FindFirstChild("Outfits")
		if not outfits then return false end

		local outfitFolder = outfits:FindFirstChild(roleId)
		if not outfitFolder then return false end

		pcall(function() saveDefaultSnapshot(char) end)
		pcall(function() clearOutfitItems(char) end)

		local placed = {}
		for _, item in ipairs(outfitFolder:GetChildren()) do
			local dupKey = item:IsA("BodyColors") and "__BodyColors" or item.Name
			if placed[dupKey] then continue end
			placed[dupKey] = true
			if item:IsA("Decal") then
				local isColorMap = false
				local val = nil
				pcall(function()
					val = item.ColorMapContent
					if val ~= nil then isColorMap = true end
				end)
				if val == nil then
					pcall(function() val = item.Texture end)
				end

				if item.Name == "Shirt" then
					for _, limbName in ipairs({"Torso", "Left Arm", "Right Arm"}) do
						local limb = char:FindFirstChild(limbName)
						local s = limb and limb:FindFirstChild("Shirt")
						if s then
							pcall(function()
								if isColorMap then
									s.ColorMapContent = val
								else
									s.Texture = val
								end
								s.Transparency = 0
							end)
						end
					end
				elseif item.Name == "Pants" then
					for _, limbName in ipairs({"Torso", "Left Leg", "Right Leg"}) do
						local limb = char:FindFirstChild(limbName)
						local p = limb and limb:FindFirstChild("Pants")
						if p then
							pcall(function()
								if isColorMap then
									p.ColorMapContent = val
								else
									p.Texture = val
								end
								p.Transparency = 0
							end)
						end
					end
				end

				pcall(function()
					local clone = item:Clone()
					if clone then
						clone:SetAttribute("Removable", true)
						clone:SetAttribute("Hidden", false)
						clone:SetAttribute("AstrocynaOutfitDecal", true)
						clone.Transparency = 0
						clone.Parent = char
					end
				end)
			elseif item:IsA("Accessory") or item:IsA("Configuration") then
				pcall(function()
					local clone = item:Clone()
					if clone then
						clone:SetAttribute("AstrocynaOutfitItem", true)
						clone:SetAttribute("Hidden", false)
						clone.Parent = char
						OUTFIT_SYS.attachOutfitItem(clone, char, false)
					end
				end)
			elseif item:IsA("BodyColors") then
				pcall(function()
					local bc = char:FindFirstChildOfClass("BodyColors")
					if bc then
						bc.HeadColor3 = item.HeadColor3
						bc.TorsoColor3 = item.TorsoColor3
						bc.LeftArmColor3 = item.LeftArmColor3
						bc.RightArmColor3 = item.RightArmColor3
						bc.LeftLegColor3 = item.LeftLegColor3
						bc.RightLegColor3 = item.RightLegColor3
					end
			end)
			end
		end

		if AppearanceModule and type(AppearanceModule.WatchCoverage) == "function" then
			pcall(function() AppearanceModule:WatchCoverage(char) end)
		end

		pcall(function() dedupeCharacterItems(char) end)

		OUTFIT_SYS.activeOutfit = roleId
		pcall(OUTFIT_SYS.updateGuiButtons)
		pcall(function()
			scheduleWardrobeSweep(0.4)
			scheduleWardrobeSweep(6)
		end)
		return true
	end

	-- Serialized wrapper: ignores re-entrant/concurrent applies so items are never added twice
	OUTFIT_SYS.applyOutfit = function(roleId)
		if roleId then
			OUTFIT_SYS.activeOutfit = roleId
			pcall(OUTFIT_SYS.updateGuiButtons)
		end
		if applyingOutfit then return false end
		applyingOutfit = true
		local ok, res = pcall(applyOutfitInner, roleId)
		applyingOutfit = false
		if ok then
			return res
		end
		return false
	end

	OUTFIT_SYS.resetDefault = function()
		local char = player.Character
		if not char then
			OUTFIT_SYS.activeOutfit = nil
			pcall(OUTFIT_SYS.updateGuiButtons)
			return
		end

		clearOutfitItems(char)

		if OUTFIT_SYS.defaultSnapshot and OUTFIT_SYS.defaultSnapshot.character == char then
			local snap = OUTFIT_SYS.defaultSnapshot
			if snap.bodyColors then
				local bc = char:FindFirstChildOfClass("BodyColors")
				if bc then
					for k, v in pairs(snap.bodyColors) do
						bc[k] = v
					end
				end
			end
			if snap.shirtTemplate then
				local s = char:FindFirstChildOfClass("Shirt")
				if s then s.ShirtTemplate = snap.shirtTemplate end
			end
			if snap.pantsTemplate then
				local p = char:FindFirstChildOfClass("Pants")
				if p then p.PantsTemplate = snap.pantsTemplate end
			end
			if snap.limbDecals then
				for limbName, decals in pairs(snap.limbDecals) do
					local limb = char:FindFirstChild(limbName)
					if limb then
						for dName, props in pairs(decals) do
							local d = limb:FindFirstChild(dName)
							if d and d:IsA("Decal") then
								if props.ColorMapContent ~= nil then
									pcall(function() d.ColorMapContent = props.ColorMapContent end)
								end
								if props.Texture ~= nil then
									pcall(function() d.Texture = props.Texture end)
								end
								pcall(function()
									d.Transparency = props.Transparency or 0
								end)
							end
						end
					end
				end
			end
		end

		OUTFIT_SYS.activeOutfit = nil
		pcall(OUTFIT_SYS.updateGuiButtons)
	end

	local function hookCharacterDedupe(char)
		if not char then return end
		char.ChildAdded:Connect(function(child)
			if applyingOutfit or not OUTFIT_SYS.activeOutfit then return end
			if child:IsA("Accessory") or child:IsA("Configuration") or (child:IsA("Decal") and (child.Name == "Shirt" or child.Name == "Pants")) then
				task.delay(0.2, function()
					if char.Parent and not applyingOutfit and OUTFIT_SYS.activeOutfit then
						dedupeCharacterItems(char)
						scheduleWardrobeSweep(0.1)
					end
				end)
			end
		end)
	end

	player.CharacterAdded:Connect(function(char)
		hookCharacterDedupe(char)
		if OUTFIT_SYS.activeOutfit then
			task.spawn(function()
				task.wait(0.25)
				if OUTFIT_SYS.activeOutfit and char.Parent then pcall(OUTFIT_SYS.applyOutfit, OUTFIT_SYS.activeOutfit) end
				task.wait(0.65)
				if OUTFIT_SYS.activeOutfit and char.Parent then pcall(OUTFIT_SYS.applyOutfit, OUTFIT_SYS.activeOutfit) end
				task.wait(1.2)
				if OUTFIT_SYS.activeOutfit and char.Parent then pcall(OUTFIT_SYS.applyOutfit, OUTFIT_SYS.activeOutfit) end
			end)
		else
			saveDefaultSnapshot(char)
		end
		if type(OUTFIT_SYS.refreshPreview) == "function" then
			pcall(OUTFIT_SYS.refreshPreview)
		end
	end)

	if player.Character then
		saveDefaultSnapshot(player.Character)
		hookCharacterDedupe(player.Character)
	end


end


--------------------------------------------------------------------------------
-- SYSTEM: EMOTE UNLOCKER & AUTHENTIC CLIENT-ONLY AUDIO ENGINE
--------------------------------------------------------------------------------
local EMOTE_SYS = nil

do
	local activeEmote = nil
	local activeTrack = nil
	local activeSound = nil
	local activePropCleanup = nil
	local activeConnections = {}
	local originalWalkSpeed = nil
	local allEmotesCache = nil
	local favoriteEmotes = {}

	local ALL_EMOTE_NAMES = {
		"24 Hour Cinderella",
		"67",
		"Abdos",
		"Applaudissements",
		"Appui Mural",
		"Appui Mural 2",
		"Arm Swing",
		"Assis Mignon",
		"Assise Croisée",
		"Assise Détendue",
		"Attitude",
		"Baby Boo Dance",
		"Baby Rock",
		"Baller Emote",
		"Barista",
		"Begone!",
		"Billie Jean",
		"Bit Crushing",
		"Black & Yellow",
		"BlindingLights",
		"Blood Pop",
		"Bodies",
		"Body Phone",
		"Bones",
		"Boombin'",
		"Boombox",
		"Brainrot",
		"Bras Croisée",
		"Break It",
		"Breakin",
		"CANTA",
		"Cafeteria",
		"California Love",
		"Can't Breathe",
		"Caramell Dansen",
		"Chase Me",
		"Chill",
		"Chirumiru",
		"Chronoshift",
		"Commercial Break",
		"Confidence",
		"Copine",
		"Cozy Time",
		"Cry For Me",
		"Dab",
		"Dai Dai",
		"Dancin Dominos",
		"Danse Avec Moi",
		"Deafen",
		"Distract",
		"Do Brazil",
		"Dracula",
		"Drift",
		"Duck Circus",
		"EEYUH",
		"Endormi 1",
		"Endormi 2",
		"Endormi 3",
		"Endormi 4",
		"Endormi 5",
		"Endormi 6",
		"EvilPlan",
		"Favela",
		"Fear",
		"Feeling",
		"Fifty",
		"Fireball",
		"Floss",
		"Flowers",
		"Fly Dance",
		"Funny Jig",
		"Fusion",
		"GO Brasil",
		"Gangnam Style",
		"Gangsta Paradise",
		"Gnarly",
		"Goat Simulator Dance",
		"Griddy",
		"Gros Étirement",
		"Guns Maracas",
		"Hakari",
		"Handshake",
		"Headlock",
		"Heeseung Walk",
		"Herobrine",
		"Honor Knight Kneel",
		"Hot Spring",
		"Hug",
		"I Can't Move On",
		"If You're The Best",
		"Illustrative",
		"In My Head",
		"Invincible Wobbles",
		"Joyride",
		"Jump Higher",
		"Jung Justice",
		"Just Dance",
		"Just Us",
		"Kiki De Bondy",
		"Knee slide",
		"Kombonk!",
		"La Bamba",
		"Lassé",
		"Laughing",
		"Lazy sit",
		"Le Cercle",
		"Lightning",
		"Low Cortisol",
		"Mark Shuffle",
		"Mbappe",
		"Meow Meow Dance",
		"Midnight Special",
		"Mochi",
		"MoonWalk",
		"No One Noticed",
		"OrangeJustice",
		"Pain",
		"Party Rock Anthem",
		"Penguin Dance",
		"Peter Griffin",
		"Play Wid De Kit",
		"PointForward",
		"PointLeft",
		"PointRight",
		"Poison",
		"Pompes",
		"Popipo",
		"PopularVibes",
		"Pumpkin",
		"Raise Hand",
		"Rat Dance",
		"RedPill",
		"Repos",
		"Rock Out",
		"Salut Militaire",
		"Sean o'pry",
		"Shake It To The Max",
		"ShakeBody",
		"Shatta",
		"Shimmer",
		"Smile",
		"Snoop Walk",
		"Snow Angel",
		"Song 2",
		"Spin Duo",
		"Spongebob",
		"Squid Game",
		"Step",
		"Still Life",
		"Stranger",
		"Sturdy",
		"Suii",
		"Surrender",
		"Sweet Waltz",
		"T-Pose",
		"TV Time Dance",
		"Table 1",
		"Table 2",
		"Take The L",
		"The Last Dance",
		"The Legend",
		"The Silencer",
		"The Thinker",
		"This Guy",
		"Torture Dance",
		"Turkish Marsh",
		"Two",
		"Umbrella",
		"Under Influence",
		"Unlock It",
		"VIBEY",
		"Verity",
		"Waka Waka",
		"Wake up",
		"Waltz",
		"Warmup",
		"Watch Me Dance",
		"Who Is You",
		"Wiggle",
		"Work It",
		"XO",
		"Yoga",
		"Zombie"
	}

	EMOTE_SYS = {
		favoriteEmotes = favoriteEmotes,
	}

	-- 1. All Emote Discovery & Cache
	function EMOTE_SYS.getAllEmotes()
		if allEmotesCache then return allEmotesCache end
		local list = {}
		local emotesFolder = ReplicatedStorage:FindFirstChild("Emotes")
		if emotesFolder then
			for _, cat in ipairs(emotesFolder:GetChildren()) do
				for _, emote in ipairs(cat:GetChildren()) do
					if emote:IsA("Animation") or emote:IsA("Folder") then
						table.insert(list, emote)
					end
				end
			end
		end
		if #list > 0 then
			allEmotesCache = list
		end
		return list
	end

	function EMOTE_SYS.getAllEmoteNames()
		local emotesFolder = ReplicatedStorage:FindFirstChild("Emotes")
		if emotesFolder then
			local found = {}
			for _, n in ipairs(ALL_EMOTE_NAMES) do found[n] = true end
			for _, cat in ipairs(emotesFolder:GetChildren()) do
				for _, emote in ipairs(cat:GetChildren()) do
					if (emote:IsA("Animation") or emote:IsA("Folder")) and not found[emote.Name] then
						table.insert(ALL_EMOTE_NAMES, emote.Name)
						found[emote.Name] = true
					end
				end
			end
		end
		return ALL_EMOTE_NAMES
	end

	function EMOTE_SYS.findEmote(name)
		if not name then return nil end
		local emotesFolder = ReplicatedStorage:FindFirstChild("Emotes")
		if emotesFolder then
			for _, cat in ipairs(emotesFolder:GetChildren()) do
				local found = cat:FindFirstChild(name)
				if found then return found end
			end
			local lower = string.lower(name)
			for _, cat in ipairs(emotesFolder:GetChildren()) do
				for _, emote in ipairs(cat:GetChildren()) do
					if string.lower(emote.Name) == lower then
						return emote
					end
				end
			end
		end
		return nil
	end

	-- 2. Stop & Clean Active Emote
	function EMOTE_SYS.stopEmote()
		activeEmote = nil

		for _, conn in ipairs(activeConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeConnections)

		if activeTrack then
			local track = activeTrack
			activeTrack = nil
			pcall(function()
				track:Stop(0.2)
				track:Destroy()
			end)
		end

		if activeSound then
			local snd = activeSound
			activeSound = nil
			pcall(function()
				local ts = game:GetService("TweenService")
				local tw = ts:Create(snd, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
				tw:Play()
				tw.Completed:Connect(function()
					snd:Stop()
					snd:Destroy()
				end)
			end)
		end

		if activePropCleanup then
			pcall(activePropCleanup)
			activePropCleanup = nil
		end

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and originalWalkSpeed then
			pcall(function() hum.WalkSpeed = originalWalkSpeed end)
			originalWalkSpeed = nil
		end
	end

	-- 3. Props Attachment (100% Authentic Game Props)
	local PROP_DEFS = {
		["Hot Spring"] = { Model = "Maracas", Joints = { HandleR = "Right Arm", HandleL = "Left Arm" } },
		["Guns Maracas"] = { Model = "Guns", Joints = { PistolR = "Right Arm", PistolL = "Left Arm" } },
		["Boombin'"] = { Model = "BoombinBoombox", Joints = { Boombox = "Right Arm" } },
		["Kombonk!"] = { Model = "AluminiumBat", Joints = { Bat = "Right Arm" } },
		["Deafen"] = { Model = "EarPlugs", Joints = { HandleR = "Right Arm", HandleL = "Left Arm" } },
		["Umbrella"] = { Model = "Umbrella", Hook = "Umbrella", Joints = { Handle = "Right Arm" } },
		["Boombox"] = { Model = "Boombox", Joints = { Boombox = "HumanoidRootPart" } },
		["Dracula"] = { Model = "Emotes.Piano" },
		["Pumpkin"] = { Model = "Emotes.Pumpkins" },
		["Rock Out"] = { Model = "Emotes.ElectricGuitar" },
	}

	function EMOTE_SYS.attachProps(emoteName, char, track)
		local def = PROP_DEFS[emoteName]
		if not def then return end

		local assets = ReplicatedStorage:FindFirstChild("Assets")
		if not assets then return end

		local model = assets
		for part in string.gmatch(def.Model, "[^%.]+") do
			model = model and model:FindFirstChild(part)
		end
		if not model or not (model:IsA("Model") or model:IsA("Folder")) then return end

		local clone = model:Clone()

		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BaseScript") or desc:IsA("Sound") then
				desc:Destroy()
			end
		end

		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("JointInstance") then
				local p0 = desc:GetAttribute("Part0")
				local p1 = desc:GetAttribute("Part1")
				if not p0 and not p1 and desc.Part0 == nil and def.Joints and desc.Parent then
					p0 = def.Joints[desc.Parent.Name]
				end
				if p0 then
					desc.Part0 = char:FindFirstChild(p0)
				elseif p1 then
					desc.Part1 = char:FindFirstChild(p1)
				end
			end
		end

		local umbrellaConns = {}
		if def.Hook == "Umbrella" and track then
			local topUmbrella = clone:FindFirstChild("TopUmbrella")
			local specialMesh = topUmbrella and topUmbrella:FindFirstChildOfClass("SpecialMesh")
			if specialMesh then
				local origOffset = specialMesh.Offset
				local origScale = specialMesh.Scale
				specialMesh.Offset = Vector3.new(0, 0, 0)
				specialMesh.Scale = Vector3.new(0.1, 1.5, 0.1)
				local opConn = track:GetMarkerReachedSignal("Open"):Connect(function()
					specialMesh.Offset = origOffset
					specialMesh.Scale = origScale
				end)
				local loopConn = track.DidLoop:Connect(function()
					specialMesh.Offset = Vector3.new(0, 0, 0)
					specialMesh.Scale = Vector3.new(0.1, 1.5, 0.1)
				end)
				table.insert(umbrellaConns, opConn)
				table.insert(umbrellaConns, loopConn)
			end
		end

		clone.Parent = char

		activePropCleanup = function()
			for _, c in ipairs(umbrellaConns) do pcall(function() c:Disconnect() end) end
			pcall(function() clone:Destroy() end)
		end
	end

	-- 4. Play Emote (Animation replicates to all players; Music is client-only)
	function EMOTE_SYS.playEmote(emoteInstance)
		if typeof(emoteInstance) == "string" then
			emoteInstance = EMOTE_SYS.findEmote(emoteInstance)
		end
		if not emoteInstance then return end

		-- Toggle off if same emote clicked
		if activeEmote == emoteInstance.Name then
			EMOTE_SYS.stopEmote()
			return
		end

		EMOTE_SYS.stopEmote()

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local animToPlay = nil
		local loopAnimToPlay = nil
		if emoteInstance:IsA("Animation") then
			animToPlay = emoteInstance
		elseif emoteInstance:IsA("Folder") then
			if emoteInstance:FindFirstChild("Start") and emoteInstance:FindFirstChild("Loop") then
				animToPlay = emoteInstance.Start
				loopAnimToPlay = emoteInstance.Loop
			elseif emoteInstance:FindFirstChild("Player") then
				animToPlay = emoteInstance.Player
			elseif emoteInstance:FindFirstChild(emoteInstance.Name) then
				animToPlay = emoteInstance[emoteInstance.Name]
			else
				animToPlay = emoteInstance:FindFirstChildOfClass("Animation")
			end
		end

		if not animToPlay then return end

		activeEmote = emoteInstance.Name
		local playStartTime = os.clock()

		-- Animation: loaded on local character's Animator -> replicates to everyone in the server!
		local track = nil
		local loadOk = pcall(function()
			track = animator:LoadAnimation(animToPlay)
			track.Priority = Enum.AnimationPriority.Action4
			if loopAnimToPlay then
				track.Looped = false
				track:Play(0.15)
				local startConn = track.Stopped:Connect(function()
					if activeEmote == emoteInstance.Name and hum and hum.Health > 0 then
						pcall(function()
							local loopTrack = animator:LoadAnimation(loopAnimToPlay)
							loopTrack.Priority = Enum.AnimationPriority.Action4
							loopTrack.Looped = true
							loopTrack:Play(0.15)
							activeTrack = loopTrack
						end)
					end
				end)
				table.insert(activeConnections, startConn)
			else
				track.Looped = true
				track:Play(0.15)
			end
			activeTrack = track
		end)
		if not loadOk or not track then return end

		-- Music / Sound: Client-only ("เพลงเราได้ยินแค่คนเดียว")
		local songObj = emoteInstance:FindFirstChild("Song") or emoteInstance:FindFirstChild("SoundPreview")
		if songObj then
			local soundId = songObj:GetAttribute("SoundId")
			if soundId and soundId ~= "" then
				pcall(function()
					local speed = songObj:GetAttribute("SoundSpeed") or 1.0
					local vol = songObj:GetAttribute("SoundVolume") or 0.5
					local sound = Instance.new("Sound")
					sound.Name = "AstrocynaEmoteMusic"
					sound.SoundId = soundId
					sound.PlaybackSpeed = speed
					sound.Volume = vol
					sound.Looped = true
					sound.Parent = game:GetService("SoundService")
					sound:Play()
					activeSound = sound
				end)
			end
		end

		-- Props
		pcall(function()
			EMOTE_SYS.attachProps(emoteInstance.Name, char, track)
		end)

		-- Behavior & Auto-stop logic (with 0.45s grace period so physics jitter doesn't stop it instantly)
		local behavior = emoteInstance:GetAttribute("Behavior") or "BreakOnMovement"
		if behavior == "Slowed" then
			originalWalkSpeed = hum.WalkSpeed
			hum.WalkSpeed = 6
		elseif behavior == "FreezeAndWait" then
			originalWalkSpeed = hum.WalkSpeed
			hum.WalkSpeed = 0
		end

		local stateConn = hum.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Dead or newState == Enum.HumanoidStateType.Ragdoll then
				EMOTE_SYS.stopEmote()
			elseif behavior ~= "BreakOnJump" and (newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall) then
				if (os.clock() - playStartTime) > 0.45 then
					EMOTE_SYS.stopEmote()
				end
			end
		end)
		table.insert(activeConnections, stateConn)

		if behavior == "BreakOnMovement" then
			local runConn = hum.Running:Connect(function(speed)
				if (os.clock() - playStartTime) > 0.45 and speed > 1.5 then
					EMOTE_SYS.stopEmote()
				end
			end)
			table.insert(activeConnections, runConn)

			local dirConn = hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
				if (os.clock() - playStartTime) > 0.45 and hum.MoveDirection.Magnitude > 0.1 then
					EMOTE_SYS.stopEmote()
				end
			end)
			table.insert(activeConnections, dirConn)
		end

		local diedConn = hum.Died:Connect(function()
			EMOTE_SYS.stopEmote()
		end)
		table.insert(activeConnections, diedConn)
	end

	-- 5. Native Toggle for Emotes GUI
	function EMOTE_SYS.toggleEmotesGui()
		pcall(function()
			local pGui = player:FindFirstChildOfClass("PlayerGui")
			local mainGui = pGui and pGui:FindFirstChild("MainGui")
			local movable = mainGui and mainGui:FindFirstChild("Movable")
			local emotes = movable and movable:FindFirstChild("Emotes")
			if emotes then
				emotes.Visible = not emotes.Visible
			end
		end)
	end

	-- 6. Ensure Emotes GUI is Clean & Ready
	function EMOTE_SYS.ensureEmotesGuiReady()
		pcall(function()
			local pGui = player:FindFirstChildOfClass("PlayerGui")
			local mainGui = pGui and pGui:FindFirstChild("MainGui")
			local movable = mainGui and mainGui:FindFirstChild("Movable")
			local emotes = movable and movable:FindFirstChild("Emotes")
			if not emotes then return end
			local scroll = emotes:FindFirstChild("Scroll")
			if not scroll then return end

			local cardCount = 0
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("ImageButton") and child:GetAttribute("Rarity") then
					cardCount = cardCount + 1
				end
			end

			if cardCount < 50 then
				local rs = game:GetService("ReplicatedStorage")
				local guiTemplates = rs:FindFirstChild("GuiTemplates")
				local mainMovable = guiTemplates and guiTemplates:FindFirstChild("MainMovable")
				local templateEmotes = mainMovable and mainMovable:FindFirstChild("Emotes")
				if templateEmotes then
					local isVis = emotes.Visible
					local oldPos = emotes.Position
					local oldSize = emotes.Size
					emotes:Destroy()
					local fresh = templateEmotes:Clone()
					fresh.Position = oldPos
					fresh.Size = oldSize
					fresh.Visible = isVis
					fresh.Parent = movable
				end
			end
		end)
	end

	-- 7. Hooks Setup: RemoteFunction (Shop.Function) & RemoteEvent (PlayEmote)
	function EMOTE_SYS.setupHooks()
		if env._AstrocynaEmoteHooked then return end
		env._AstrocynaEmoteHooked = true

		pcall(function()
			if hookmetamethod and type(hookmetamethod) == "function" and getnamecallmethod then
				local oldNamecall
				local namecallHook = function(self, ...)
					if checkcaller and checkcaller() then
						return oldNamecall(self, ...)
					end
					local method = getnamecallmethod()

					-- Intercept Shop.Function RemoteFunction: GetOwnedEmotes, GetFavoriteEmotes, ToggleFavoriteEmote
					if (method == "InvokeServer" or method == "invokeServer")
						and typeof(self) == "Instance" and self.Name == "Function"
						and self.Parent and self.Parent.Name == "Shop" then
						local action, arg1 = ...
						if action == "GetOwnedEmotes" then
							return EMOTE_SYS.getAllEmoteNames()
						elseif action == "GetFavoriteEmotes" then
							local favList = {}
							for name, isFav in pairs(favoriteEmotes) do
								if isFav then table.insert(favList, name) end
							end
							return favList
						elseif action == "ToggleFavoriteEmote" then
							if typeof(arg1) == "string" then
								favoriteEmotes[arg1] = not favoriteEmotes[arg1] or nil
								return favoriteEmotes[arg1] == true
							end
							return false
						end
					end

					-- Intercept PlayEmote RemoteEvent: play locally with authentic animation & client-only music!
					if (method == "FireServer" or method == "fireServer")
						and typeof(self) == "Instance" and self.Name == "PlayEmote"
						and self.Parent and self.Parent.Name == "Remotes" then
						local emoteArg = ...
						task.spawn(function()
							EMOTE_SYS.playEmote(emoteArg)
						end)
						return
					end

					return oldNamecall(self, ...)
				end
				oldNamecall = hookmetamethod(game, "__namecall", toCClosure(namecallHook))
			end
		end)
	end

	-- 8. Initialization & Lifecycle
	function EMOTE_SYS.init()
		EMOTE_SYS.setupHooks()

		task.spawn(function()
			task.wait(1.0)
			EMOTE_SYS.ensureEmotesGuiReady()
		end)

		player.CharacterAdded:Connect(function()
			EMOTE_SYS.stopEmote()
		end)

		player.Chatted:Connect(function(msg)
			if msg == "/emotes" or msg == "/emote" then
				EMOTE_SYS.toggleEmotesGui()
			else
				local emoteName = string.match(msg, "^/e%s+(.+)$")
				if emoteName then
					if emoteName == "emotes" or emoteName == "emote" then
						EMOTE_SYS.toggleEmotesGui()
					else
						local found = EMOTE_SYS.findEmote(emoteName)
						if found then
							EMOTE_SYS.playEmote(found)
						end
					end
				elseif msg == "o7" then
					local found = EMOTE_SYS.findEmote("Salut Militaire")
					if found then
						EMOTE_SYS.playEmote(found)
					end
				end
			end
		end)
	end
end


local boomboxSelectedColor = THEME.CyanPrimary
local boomboxIsSmokeEnabled = false
local boomboxCurrentSound = nil
local boomboxModel = nil
local boomboxRotating = false
local boomboxRotateConnection = nil
local boomboxBeatConnection = nil
local boomboxSmoke = nil
local boomboxOriginalSky = nil
local boomboxOriginalTechnology = nil
local boomboxUseBoomboxTheme = false
local boomboxMode = "back"
local boomboxEffects = {}
local boomboxDepthEffect = nil
toggleBoomboxGui = function() end
local boomboxIsLoading = false
local boomboxCacheFolder = "BoomboxCache"
local BOOMBOX_YT_CONFIG = {
	CustomEndpoint = "",
	ApiKey = "",
	CacheFolder = "BoomboxCache",
	Volume = 1,
}
local boomboxYtEndpoints = {
	{ url = "https://api.cobalt.tools/", apiKey = nil },
	{ url = "https://cobalt.kwiatekm.tokyo/", apiKey = nil },
	{ url = "https://cobalt.xy24.pw/", apiKey = nil },
	{ url = "https://cobalt.tools/api/", apiKey = nil },
}

local function getCachedThumbnailAsync(userId, thumbType, thumbSize, callback)
	local cacheKey = tostring(userId) .. "_" .. tostring(thumbType) .. "_" .. tostring(thumbSize)
	if thumbnailCache[cacheKey] then
		if callback then callback(thumbnailCache[cacheKey]) end
		return thumbnailCache[cacheKey]
	end
	task.spawn(function()
		local thumb = ""
		pcall(function()
			thumb = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
		end)
		if thumb and thumb ~= "" then
			thumbnailCache[cacheKey] = thumb
			if callback then callback(thumb) end
		end
	end)
	return ""
end

local FPS_TRACKER = {
	current = 60,
	frames = 0,
	timer = 0,
}

local inputState = {
	W = false,
	A = false,
	S = false,
	D = false,
	Space = false,
	LeftControl = false,
	LeftShift = false,
}

updateGuiFlyState = function() end
updateGuiInvisState = function() end
updateGuiEspState = function() end
toggleChatlogsGui = function() end

local function loadAnimations(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	for _, track in pairs(loadedTracks) do
		pcall(function()
			track:Stop()
			track:Destroy()
		end)
	end
	table.clear(loadedTracks)

	for name, id in pairs(ANIM_IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local success, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if success and track then
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = true
			loadedTracks[name] = track
		end
		anim:Destroy()
	end
end

local function playAnim(name)
	if activeTrackName == name then return end
	activeTrackName = name

	for trackName, track in pairs(loadedTracks) do
		if trackName == name then
			track:Play(0.2)
		else
			track:Stop(0.2)
		end
	end
end

local function stopAllAnims()
	activeTrackName = nil
	for _, track in pairs(loadedTracks) do
		pcall(function()
			track:Stop(0.2)
		end)
	end
end

local function getDirectionalAnimName(zInput, xInput, isMoving)
	if not isMoving then return "Idle" end
	if zInput > 0 then
		return "Front"
	elseif zInput < 0 then
		if xInput < 0 then
			return "BackLeft"
		elseif xInput > 0 then
			return "BackRight"
		else
			return "Back"
		end
	else
		if xInput < 0 then
			return "Left"
		elseif xInput > 0 then
			return "Right"
		end
	end
	return "Idle"
end

local function getAllNoclipTargets()
	local targets = {}
	if player.Character and player.Character.Parent then
		table.insert(targets, player.Character)
	end
	local wsPlayers = workspace:FindFirstChild("Players")
	if wsPlayers then
		local found = wsPlayers:FindFirstChild(player.Name)
		if found and found:IsA("Model") and found ~= player.Character then
			table.insert(targets, found)
		end
	end
	if ghostCharacter and ghostCharacter.Parent then
		local already = false
		for _, t in ipairs(targets) do
			if t == ghostCharacter then already = true; break end
		end
		if not already then
			table.insert(targets, ghostCharacter)
		end
	end
	return targets
end

local function enableNoclip()
	if noclipConnection then
		pcall(function() noclipConnection:Disconnect() end)
		noclipConnection = nil
	end
	_noclipParts = {}
	local function refreshNoclipParts()
		local parts = {}
		local targets = getAllNoclipTargets()
		for _, charModel in ipairs(targets) do
			for _, part in ipairs(charModel:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
		end
		_noclipParts = parts
	end
	refreshNoclipParts()

	local noclipScanTick = 0
	noclipConnection = RunService.Stepped:Connect(function(_, stepDt)
		if isFlying then
			noclipScanTick = noclipScanTick + (stepDt or 0.016)
			if noclipScanTick >= 0.5 then
				noclipScanTick = 0
				refreshNoclipParts()
			end
			for _, part in ipairs(_noclipParts) do
				if part.Parent then
					part.CanCollide = false
				end
			end
		end
	end)
end

local function disableNoclip()
	if noclipConnection then
		pcall(function() noclipConnection:Disconnect() end)
		noclipConnection = nil
	end
	-- Safely restore collisions only to standard character limbs, NEVER to HumanoidRootPart or Accessory Handles!
	local targets = getAllNoclipTargets()
	for _, charModel in ipairs(targets) do
		for _, part in ipairs(charModel:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				if part.Name == "Torso" or part.Name == "Head" or part.Name:find("Leg") or part.Name:find("Arm") or part.Name:find("UpperTorso") or part.Name:find("LowerTorso") then
					part.CanCollide = true
				end
			end
		end
	end
	_noclipParts = {}
end

local function stopFlying()
	isFlying = false

	if flyRenderConn then
		pcall(function() flyRenderConn:Disconnect() end)
		flyRenderConn = nil
	end

	disableNoclip()

	if bodyVelocity then
		pcall(function() bodyVelocity:Destroy() end)
		bodyVelocity = nil
	end

	if bodyGyro then
		pcall(function() bodyGyro:Destroy() end)
		bodyGyro = nil
	end

	stopAllAnims()

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
		if rootPart then
			pcall(function()
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
			end)
		end
		if humanoid then
			humanoid.PlatformStand = false
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end
	currentVelocity = Vector3.zero
	pcall(function() setMobileFlyHudVisible(false) end)
	updateGuiFlyState()
end

local function startFlying()
	local char = player.Character
	if not char then return end
	local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then return end

	isFlying = true

	-- Prevent tripping / ragdoll states while flying
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)
	humanoid.PlatformStand = true

	local cam = workspace.CurrentCamera
	local initCF = cam and cam.CFrame or rootPart.CFrame

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "AdminFlyGyro"
	bodyGyro.P = 9e4
	bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bodyGyro.CFrame = initCF
	bodyGyro.Parent = rootPart

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "AdminFlyVelocity"
	bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9) -- Infinite Yield standard to prevent gravity drop
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = rootPart

	currentVelocity = Vector3.zero

	-- Start instant noclip (zero delay)
	enableNoclip()

	flyRenderConn = RunService.RenderStepped:Connect(function(dt)
		if not isFlying then
			stopFlying()
			return
		end

		local currentChar = player.Character
		if not currentChar then return end
		local currentRoot = currentChar:FindFirstChild("HumanoidRootPart") or currentChar:FindFirstChild("Torso")
		local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
		if not currentRoot or not currentHumanoid or currentHumanoid.Health <= 0 then
			stopFlying()
			return
		end

		if boundCharacter ~= currentChar then
			boundCharacter = currentChar
			loadAnimations(currentHumanoid)
		end

		local cam = workspace.CurrentCamera
		if not cam then return end
		local camCF = cam.CFrame

		if not bodyGyro or bodyGyro.Parent ~= currentRoot then
			if bodyGyro then pcall(function() bodyGyro:Destroy() end) end
			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.Name = "AdminFlyGyro"
			bodyGyro.P = 9e4
			bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
			bodyGyro.Parent = currentRoot
		end
		bodyGyro.CFrame = camCF

		if not bodyVelocity or bodyVelocity.Parent ~= currentRoot then
			if bodyVelocity then pcall(function() bodyVelocity:Destroy() end) end
			bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Name = "AdminFlyVelocity"
			bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
			bodyVelocity.Parent = currentRoot
		end

		currentHumanoid.PlatformStand = true

		local zInput = (inputState.W and 1 or 0) - (inputState.S and 1 or 0)
		local xInput = (inputState.D and 1 or 0) - (inputState.A and 1 or 0)
		local yInput = (inputState.Space and 1 or 0) - ((inputState.LeftControl or inputState.LeftShift) and 1 or 0)

		local mobileY = (mobileFlyState.Up and 1 or 0) - (mobileFlyState.Down and 1 or 0)
		yInput = yInput + mobileY

		local moveDir = Vector3.zero
		local isMoving = false

		if zInput ~= 0 or xInput ~= 0 then
			moveDir = (camCF.LookVector * zInput) + (camCF.RightVector * xInput)
			isMoving = true
		elseif currentHumanoid.MoveDirection.Magnitude > 0.05 then
			local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
			if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit else flatLook = Vector3.new(0, 0, -1) end
			local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
			if flatRight.Magnitude > 0.001 then flatRight = flatRight.Unit else flatRight = Vector3.new(1, 0, 0) end

			local forwardDot = currentHumanoid.MoveDirection:Dot(flatLook)
			local rightDot = currentHumanoid.MoveDirection:Dot(flatRight)

			zInput = forwardDot
			xInput = rightDot
			isMoving = (math.abs(forwardDot) > 0.05 or math.abs(rightDot) > 0.05)
			moveDir = (camCF.LookVector * forwardDot) + (camCF.RightVector * rightDot)
		end

		if yInput ~= 0 then
			moveDir = moveDir + (Vector3.new(0, 1, 0) * yInput)
			isMoving = true
		end

		local targetVelocity = Vector3.zero
		if moveDir.Magnitude > 0 then
			targetVelocity = moveDir.Unit * SETTINGS.FLY_SPEED
		end

		local lerpFactor = math.clamp(dt * SETTINGS.ACCELERATION, 0, 1)
		currentVelocity = currentVelocity:Lerp(targetVelocity, lerpFactor)
		bodyVelocity.Velocity = currentVelocity

		local animName = getDirectionalAnimName(zInput, xInput, isMoving)
		playAnim(animName)
	end)

	pcall(function() setMobileFlyHudVisible(true) end)
	updateGuiFlyState()
end

function toggleFly()
	if isFlying then
		stopFlying()
	else
		startFlying()
	end
end

local function _isGuiHealthy(gui)
	if not gui or not gui.Parent then return false end
	if not (gui:IsA("ScreenGui") or gui:IsA("GuiObject") or gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) then
		return true
	end

	if gui:IsA("ScreenGui") then
		local children = gui:GetChildren()
		if #children == 0 then
			return false
		end

		local hasContent = false
		for _, child in ipairs(children) do
			if child:IsA("GuiObject") or child:IsA("LocalScript") or child:IsA("Folder") then
				hasContent = true
				break
			end
		end
		if not hasContent then
			return false
		end
	end

	return true
end

local function disableInvis()
	if not isInvis or invisBusy then return end
	invisBusy = true

	local success, err = pcall(function()
		if invisDiedConn then
			invisDiedConn:Disconnect()
			invisDiedConn = nil
		end

		if frozenDummy then
			pcall(function() frozenDummy:Destroy() end)
			frozenDummy = nil
		end

		local targetCF = nil
		if ghostCharacter then
			local gRoot = ghostCharacter:FindFirstChild("HumanoidRootPart") or ghostCharacter:FindFirstChild("Torso")
			local gHum = ghostCharacter:FindFirstChildOfClass("Humanoid")
			if gRoot then
				targetCF = gRoot.CFrame
			end

			if gHum then
				pcall(function()
					gHum:UnequipTools()
				end)
			end

			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				for _, item in ipairs(ghostCharacter:GetChildren()) do
					if (item:IsA("Tool") or item:IsA("HopperBin")) and backpack then
						pcall(function() item.Parent = backpack end)
					end
				end
			end
		end

		if realCharacter then
			local rRoot = realCharacter:FindFirstChild("HumanoidRootPart") or realCharacter:FindFirstChild("Torso")
			local rHum = realCharacter:FindFirstChildOfClass("Humanoid")

			if targetCF and rRoot then
				rRoot.CFrame = targetCF
				rRoot.AssemblyLinearVelocity = Vector3.zero
				rRoot.AssemblyAngularVelocity = Vector3.zero
			end

			if rHum then
				rHum.PlatformStand = false
				rHum.AutoRotate = true
			end

			realCharacter.Parent = workspace
			task.wait(0.02)

			player.Character = realCharacter

			local cam = workspace.CurrentCamera
			if cam and rHum then
				cam.CameraSubject = rHum
				cam.CameraType = Enum.CameraType.Custom
			end

			if rHum then
				rHum:ChangeState(Enum.HumanoidStateType.GettingUp)
				task.wait(0.01)
				rHum:ChangeState(Enum.HumanoidStateType.Running)
			end

			pcall(function()
				local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 2))
				if PlayerModule and PlayerModule.GetControls then
					local controls = PlayerModule:GetControls()
					if controls then
						controls:Enable()
					end
				end
			end)

			local hasEquippedTool = realCharacter:FindFirstChildOfClass("Tool") ~= nil
			if not hasEquippedTool then
				for _, v in ipairs(realCharacter:GetDescendants()) do
					if (v:IsA("Weld") or v:IsA("Motor6D") or v:IsA("WeldConstraint")) and v.Name == "RightGrip" then
						pcall(function() v:Destroy() end)
					end
				end
			end

			for _, part in ipairs(realCharacter:GetDescendants()) do
				if part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
					part.CanCollide = false
				end
			end
		end

		if ghostCharacter then
			pcall(function()
				local gHum = ghostCharacter:FindFirstChildOfClass("Humanoid")
				if gHum then
					gHum.Health = gHum.MaxHealth
				end
				ghostCharacter:Destroy()
			end)
			ghostCharacter = nil
		end

		isInvis = false
		updateGuiInvisState()

		local function reloadAllSystemsInGame()
			local activeChar = player.Character or realCharacter
			if not activeChar then return end

			local hum = activeChar:FindFirstChildOfClass("Humanoid")

			pcall(function()
				local cam = workspace.CurrentCamera
				if cam and hum then
					if cam.CameraSubject ~= hum then
						cam.CameraSubject = hum
					end
					if cam.CameraType ~= Enum.CameraType.Custom then
						cam.CameraType = Enum.CameraType.Custom
					end
				end

				local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule", 2))
				if PlayerModule and PlayerModule.GetControls then
					local controls = PlayerModule:GetControls()
					if controls and not controls:IsEnabled() then
						controls:Enable()
					end
				end
			end)

			if hum then
				pcall(function()
					if hum.PlatformStand then
						hum.PlatformStand = false
					end
					if not hum.AutoRotate then
						hum.AutoRotate = true
					end

					local state = hum:GetState()
					if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.PlatformStanding or state == Enum.HumanoidStateType.Ragdoll then
						hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						task.wait(0.01)
						hum:ChangeState(Enum.HumanoidStateType.Running)
					end
				end)
			end

			pcall(function()
				local animateScript = activeChar:FindFirstChild("Animate")
				if animateScript and animateScript:IsA("LocalScript") and animateScript.Disabled then
					animateScript.Disabled = false
				end
			end)

			pcall(function()
				local backpack = player:FindFirstChildOfClass("Backpack")
				if backpack then

					for _, item in ipairs(Lighting:GetChildren()) do
						if item:IsA("Tool") or item:IsA("HopperBin") then
							pcall(function() item.Parent = backpack end)
						end
					end

					for _, item in ipairs(backpack:GetChildren()) do
						if item:IsA("Tool") or item:IsA("HopperBin") then
							if not item.Enabled then
								item.Enabled = true
							end

							for _, p in ipairs(item:GetDescendants()) do
								if p:IsA("BasePart") then
									if p.Anchored then
										p.Anchored = false
									end
									p.CanCollide = false
								elseif (p:IsA("Weld") or p:IsA("Motor6D") or p:IsA("WeldConstraint")) and p.Name == "RightGrip" then

									pcall(function() p:Destroy() end)
								end
							end
						end
					end
				end
			end)

			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)

			pcall(function()
				if not isSpectating then
					SoundService:SetListener(Enum.ListenerType.Camera)
				end
			end)
		end

		reloadAllSystemsInGame()
	end)

	invisBusy = false
	if not success then
		warn("[Astrocyna Admin] disableInvis error:", err)
	end
end

local function enableInvis()
	if isInvis or invisBusy then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	invisBusy = true

	local success, err = pcall(function()

		pcall(function()
			hum:UnequipTools()
		end)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, item in ipairs(char:GetChildren()) do
				if item:IsA("Tool") or item:IsA("HopperBin") then
					pcall(function() item.Parent = backpack end)
				end
			end
		end
		task.wait(0.02)

		isInvis = true
		char.Archivable = true
		realCharacter = char
		local savedCF = root.CFrame

		if frozenDummy then pcall(function() frozenDummy:Destroy() end) end
		frozenDummy = char:Clone()
		frozenDummy.Name = "FrozenBody_AFK"
		for _, v in ipairs(frozenDummy:GetDescendants()) do
			if v:IsA("Script") or v:IsA("LocalScript") then
				v:Destroy()
			elseif v:IsA("BasePart") then
				v.Anchored = true
				v.CanCollide = false
			end
		end

		for _, v in ipairs(frozenDummy:GetChildren()) do
			if v:IsA("Tool") or v:IsA("HopperBin") then
				v:Destroy()
			end
		end

		local freezeHl = Instance.new("Highlight")
		freezeHl.Name = "FrozenBodyHighlight"
		freezeHl.FillColor = Color3.fromRGB(255, 60, 60)
		freezeHl.FillTransparency = 0.5
		freezeHl.OutlineColor = Color3.fromRGB(255, 255, 255)
		freezeHl.OutlineTransparency = 0
		freezeHl.Parent = frozenDummy
		frozenDummy.Parent = workspace

		local dummyRoot = frozenDummy:FindFirstChild("HumanoidRootPart") or frozenDummy:FindFirstChild("Torso")
		if dummyRoot then
			dummyRoot.CFrame = savedCF
		end

		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = savedCF
		char.Parent = Lighting

		ghostCharacter = char:Clone()
		ghostCharacter.Name = ""

		for _, v in ipairs(ghostCharacter:GetChildren()) do
			if v:IsA("Tool") or v:IsA("HopperBin") then
				v:Destroy()
			end
		end

		local cloneHl = ghostCharacter:FindFirstChild("FrozenBodyHighlight")
		if cloneHl then cloneHl:Destroy() end

		for _, part in ipairs(ghostCharacter:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
				if part.Name == "HumanoidRootPart" then
					part.Transparency = 1
				else
					part.Transparency = 0.5
				end
			end
		end

		local ghostHl = Instance.new("Highlight")
		ghostHl.Name = "GhostSelfESP"
		ghostHl.FillColor = THEME.CyanPrimary
		ghostHl.FillTransparency = 0.55
		ghostHl.OutlineColor = THEME.BorderHighlight
		ghostHl.OutlineTransparency = 0
		ghostHl.Parent = ghostCharacter

		ghostCharacter.Parent = workspace
		local ghostRoot = ghostCharacter:FindFirstChild("HumanoidRootPart") or ghostCharacter:FindFirstChild("Torso")
		if ghostRoot then
			ghostRoot.CFrame = savedCF
		end

		player.Character = ghostCharacter
		local ghostHum = ghostCharacter:FindFirstChildOfClass("Humanoid")
		if ghostHum then
			local cam = workspace.CurrentCamera
			if cam then
				cam.CameraSubject = ghostHum
				cam.CameraType = Enum.CameraType.Custom
			end

			invisDiedConn = ghostHum.Died:Connect(function()
				disableInvis()
			end)
		end

		local animate = ghostCharacter:FindFirstChild("Animate")
		if animate then
			animate.Disabled = true
			task.wait()
			animate.Disabled = false
		end

		updateGuiInvisState()
	end)

	invisBusy = false
	if not success then
		warn("[Astrocyna Admin] enableInvis error:", err)
	end
end

function toggleInvis()
	if isInvis then
		disableInvis()
	else
		enableInvis()
	end
end

local GAME_GROUP_ID = 304256484
local SECONDARY_GROUP_ID = 181881217
local staffCache = {}
local alertedStaffJoins = {}
local getPlayerChar = nil
local checkPlayerStaff = nil
local onStaffDetected = Instance.new("BindableEvent")
local onBlacklistChanged = Instance.new("BindableEvent")
local espWatchdogRunning = false

local BLACKLIST_FILE = "astrocyna_blacklist.json"
local blacklistedUsers = {}

local function loadBlacklist()
	if isfile and readfile and isfile(BLACKLIST_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(BLACKLIST_FILE))
		end)
		if ok and type(data) == "table" then
			local clean = {}
			for k, v in pairs(data) do
				local idStr = tostring(k)
				if tonumber(idStr) and type(v) == "table" then
					clean[idStr] = {
						Name = v.Name or v.name or idStr,
						DisplayName = v.DisplayName or v.displayName or v.Name or v.name or idStr,
						AddedAt = v.AddedAt or v.addedAt or os.time(),
					}
				end
			end
			blacklistedUsers = clean
			return
		end
	end
	blacklistedUsers = {}
end

local function saveBlacklist()
	if writefile then
		pcall(function()
			local clean = {}
			for k, v in pairs(blacklistedUsers) do
				local idStr = tostring(k)
				if tonumber(idStr) and type(v) == "table" then
					clean[idStr] = {
						Name = v.Name or v.name or idStr,
						DisplayName = v.DisplayName or v.displayName or v.Name or v.name or idStr,
						AddedAt = v.AddedAt or v.addedAt or os.time(),
					}
				end
			end
			blacklistedUsers = clean
			writefile(BLACKLIST_FILE, HttpService:JSONEncode(clean))
		end)
	end
end

local function isPlayerBlacklisted(userId)
	return blacklistedUsers[tostring(userId)] ~= nil
end

local ITEM_DATA = {
	ROLE_EXCLUSIVE = {
		{
			label = "Nurse/Medic/Surgeon",
			roles = { "medic", "nurse", "surgeon", "doctor" },
			items = { "medkit", "syringe", "defibrillator", "pill", "medicine", "scalpel", "stethoscope", "first aid", "bandage" }
		},
		{
			label = "Kitchen",
			roles = { "cook", "chef" },
			items = { "spatula", "pan", "pot", "dough", "meat", "soup", "chef supreme" }
		},
		{
			label = "Teacher",
			roles = { "teacher" },
			items = { "chalk", "pointer", "exam", "book", "class" }
		},
		{
			label = "Psychologist",
			roles = { "psychologist", "therapist", "counselor" },
			items = { "clipboard", "appointment", "evaluation", "notes", "file", "psych" }
		},
		{
			label = "Janitor",
			roles = { "janitor", "cleaner" },
			items = { "broom", "ownerbroom", "trash", "mop", "sponge", "bucket" }
		},
		{
			label = "Law Enforcement & Security",
			roles = { "cadet", "guard", "sergeant", "captain", "warden", "bodyguard" },
			items = { "handcuff", "cuff", "taser", "baton", "pepper spray", "riot shield", "shield", "keycard", "card" }
		},
	},
	GENERAL_WEAPONS = {
		"handcuff", "cuff", "taser", "baton", "m9", "glock", "pistol", "m4a1",
		"shotgun", "remington", "riot shield", "shield", "keycard", "card",
		"pepper spray", "vest", "armor", "revolver", "gun", "knife",
		"shank", "sword", "weapon", "ak47", "akms", "bfg50",
		"boxing gloves", "boxinggloves", "bat", "snowball", "minor plank", "plank"
	},
	COMMON_LEGITIMATE = {
		"food", "drink", "water", "soda", "cola", "bloxycola", "bloxy cola", "burger", "pizza", "donut", "coffee", "apple", "bread",
		"tray", "basketball", "ball", "trash", "broom", "mop", "sponge", "soap", "towel", "clothes", "uniform",
		"money", "cash", "coin", "book", "cigarette", "cigar", "lighter", "phone", "flashlight",
		"dumbbell", "weight", "weights", "armwrestle", "dart", "skate", "chess", "ore", "mineral", "chips",
		-- Fishing System items & species (Official Prison RP)
		"fish", "rod", "fishingrod", "fishing rod", "luck pass", "jellyfish", "alligator", "anchovy", "kraken",
		"crocodile", "whale", "angelfish", "angler", "arowana", "seadragon", "betta", "catfish", "cat fish",
		"basslet", "blob fish", "blowfish", "blue tang", "tuna", "boar fish", "rotfish", "sawfish", "candle fish",
		"carp", "clownfish", "snapper", "coelacanth", "coffin fish", "moonfish"
	},
	ADMIN_KEYWORDS = {
		"admin", "btool", "f3x", "building tool", "cmd", "command", "debug",
		"banhammer", "ban tool", "kick", "nuke", "fling", "god", "unban", "staff", "modtool",
		"servertool", "exploit", "infinite", "dex", "spy", "segway", "invis",
		"hammer", "crash", "destroyer"
	}
}

local function classifyToolForPlayer(toolName, teamName, isStaff)
	local nameLower = string.lower(tostring(toolName or ""))
	local roleLower = string.lower(tostring(teamName or ""))

	if isStaff then
		return "role_allowed", "Staff Equipment: " .. tostring(toolName or "")
	end

	if string.find(nameLower, "bandage") then
		return "exempt", "Exempt Item: Bandage"
	end

	if string.find(nameLower, "mobileradio") or string.find(nameLower, "radio") or string.find(nameLower, "walkie") then
		return "radio", "Radio Device: " .. tostring(toolName or "")
	end

	for _, kw in ipairs(ITEM_DATA.ADMIN_KEYWORDS) do
		if string.find(nameLower, kw) then
			return "admin", "Admin Tool: " .. tostring(toolName or "")
		end
	end

	for _, excl in ipairs(ITEM_DATA.ROLE_EXCLUSIVE) do
		for _, it in ipairs(excl.items) do
			if string.find(nameLower, it) then
				local matchesRole = false
				for _, r in ipairs(excl.roles) do
					if string.find(roleLower, r) then
						matchesRole = true
						break
					end
				end
				if matchesRole then
					return "role_allowed", "Role Item (" .. (teamName ~= "" and teamName or excl.label) .. ")"
				else
					return "cross_role", "Unauthorized Item: " .. tostring(toolName or "") .. " (Belongs to " .. excl.label .. ")"
				end
			end
		end
	end

	for _, gw in ipairs(ITEM_DATA.GENERAL_WEAPONS) do
		if string.find(nameLower, gw) then
			local isGuardRole = string.find(roleLower, "guard") or string.find(roleLower, "captain") or string.find(roleLower, "sergeant") or string.find(roleLower, "warden") or string.find(roleLower, "bodyguard")
			if isGuardRole then
				return "role_allowed", "Duty Equipment (" .. (teamName ~= "" and teamName or "Guard") .. ")"
			else
				return "general_weapon", "Standard Weapon: " .. tostring(toolName or "")
			end
		end
	end

	for _, cw in ipairs(ITEM_DATA.COMMON_LEGITIMATE) do
		if string.find(nameLower, cw) then
			return "common", "Common Item"
		end
	end

	return "neutral", "Standard Item"
end

local voiceEnabledCache = {}
local function getPlayerMicStatus(plr)
	if not plr then return "NO MIC", THEME.TextDim end

	local char = getPlayerChar and getPlayerChar(plr) or plr.Character
	local head = char and char:FindFirstChild("Head")

	local state = nil
	pcall(function()
		local vci = game:GetService("VoiceChatInternal")
		if vci and vci.GetVoiceState then
			local s = vci:GetVoiceState(tostring(plr.UserId))
			if s then state = tostring(s) end
		end
	end)

	if state then
		local sLower = string.lower(state)
		if string.find(sLower, "talk") or string.find(sLower, "speak") or sLower == "2" then
			return "🎙️ SPEAKING", Color3.fromRGB(0, 255, 140)
		elseif string.find(sLower, "mute") or sLower == "1" then
			return "🔇 MUTED", Color3.fromRGB(255, 80, 80)
		elseif string.find(sLower, "silent") or string.find(sLower, "active") or sLower == "3" then
			return "🎙️ UNMUTED", Color3.fromRGB(0, 220, 255)
		elseif string.find(sLower, "none") or sLower == "0" then
			return "❌ NO MIC", THEME.TextDim
		end
	end

	if head then
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("BillboardGui") and (string.find(string.lower(child.Name), "voice") or string.find(string.lower(child.Name), "mic") or string.find(string.lower(child.Name), "bubble")) then
				local img = child:FindFirstChildWhichIsA("ImageLabel", true)
				if img and img.Visible then
					local texId = string.lower(img.Image)
					if string.find(texId, "mute") or string.find(texId, "slash") or string.find(texId, "off") then
						return "🔇 MUTED", Color3.fromRGB(255, 80, 80)
					else
						return "🎙️ UNMUTED", Color3.fromRGB(0, 220, 255)
					end
				end
			end
			if child:IsA("Sound") and child.IsPlaying and (child.SoundGroup and string.find(string.lower(child.SoundGroup.Name), "voice")) then
				return "🎙️ SPEAKING", Color3.fromRGB(0, 255, 140)
			end
		end
	end

	local attrMute = plr:GetAttribute("MicMuted") or (char and char:GetAttribute("MicMuted"))
	local attrTalk = plr:GetAttribute("Talking") or (char and char:GetAttribute("Talking"))
	if attrTalk == true then
		return "🎙️ SPEAKING", Color3.fromRGB(0, 255, 140)
	elseif attrMute == true then
		return "🔇 MUTED", Color3.fromRGB(255, 80, 80)
	elseif attrMute == false then
		return "🎙️ UNMUTED", Color3.fromRGB(0, 220, 255)
	end

	if voiceEnabledCache[plr.UserId] == nil then
		voiceEnabledCache[plr.UserId] = false
		task.spawn(function()
			pcall(function()
				local vcs = game:GetService("VoiceChatService")
				if vcs and vcs.IsVoiceEnabledForUserIdAsync then
					voiceEnabledCache[plr.UserId] = vcs:IsVoiceEnabledForUserIdAsync(plr.UserId)
				end
			end)
		end)
	end

	if voiceEnabledCache[plr.UserId] then
		return "🎙️ UNMUTED", Color3.fromRGB(0, 220, 255)
	end

	return "❌ NO MIC", THEME.TextDim
end

local HACKER_LIST_FILE = "astrocyna_game_incidents.json"
local hackerDetectedUsers = {}
local onHackerDetected = Instance.new("BindableEvent")
local hookedPlayers = {}

local function isStaffOrAdmin(plr)
	if not plr or plr == player then return true end

	local uid = plr.UserId
	-- 1. Checked cache
	if staffCache[uid] and staffCache[uid].isStaff then
		return true
	end

	-- 2. Server Staff Roster (Pre-fetched Roblox Group Staff Database for rank >= 200)
	local uidStr = tostring(uid)
	if ADMIN_SYS and ADMIN_SYS.serverStaffRoster and ADMIN_SYS.serverStaffRoster[uidStr] then
		local entry = ADMIN_SYS.serverStaffRoster[uidStr]
		if (entry.rank or 0) >= 200 then
			if not staffCache[uid] or not staffCache[uid].isStaff then
				staffCache[uid] = { isStaff = true, role = entry.role or "Staff", rank = entry.rank or 200 }
			end
			return true
		end
	end

	-- 3. In-Game Staff Team Keywords (ONLY Staff/Admin/Moderator, NOT Warden!)
	if plr.Team then
		local tName = string.lower(plr.Team.Name)
		if string.find(tName, "staff") or string.find(tName, "admin") or string.find(tName, "moderator") then
			if not staffCache[uid] or not staffCache[uid].isStaff then
				staffCache[uid] = { isStaff = true, role = plr.Team.Name, rank = 200 }
			end
			return true
		end
	end

	-- 4. Player Attributes
	local pAttrs = plr:GetAttributes()
	for attrName, val in pairs(pAttrs) do
		local lowerAttr = string.lower(attrName)
		if (string.find(lowerAttr, "staff") or string.find(lowerAttr, "admin") or string.find(lowerAttr, "moderator")) and val == true then
			if not staffCache[uid] or not staffCache[uid].isStaff then
				staffCache[uid] = { isStaff = true, role = tostring(attrName), rank = 200 }
			end
			return true
		end
	end

	-- 5. Asynchronous Group Rank query if not yet queried
	if staffCache[uid] == nil and checkPlayerStaff then
		task.spawn(checkPlayerStaff, plr)
	end

	return false
end

ADMIN_SYS.isStaffExempt = isStaffOrAdmin

local function pruneHackerList(maxCount)
	maxCount = maxCount or 60
	local entries = {}
	for uid, rec in pairs(hackerDetectedUsers) do
		local isOnline = (Players:GetPlayerByUserId(tonumber(uid) or 0) ~= nil)
		table.insert(entries, { uid = uid, time = rec.lastDetected or "", isOnline = isOnline })
	end
	if #entries > maxCount then
		table.sort(entries, function(a, b)
			if a.isOnline ~= b.isOnline then return a.isOnline end
			return a.time > b.time
		end)
		for i = maxCount + 1, #entries do
			hackerDetectedUsers[entries[i].uid] = nil
		end
	end
end

local function loadHackerList()
	if isfile and readfile and isfile(HACKER_LIST_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(HACKER_LIST_FILE))
		end)
		if ok and type(data) == "table" then
			for uid, rec in pairs(data) do
				local hasRemaining = false
				if rec.reasons then
					for _, _ in pairs(rec.reasons) do
						hasRemaining = true
						break
					end
				end
				if not hasRemaining then
					data[uid] = nil
				end
			end
			hackerDetectedUsers = data
			pruneHackerList(60)
			return
		end
	end
	hackerDetectedUsers = {}
end

local function saveHackerList()
	if writefile then
		pruneHackerList(60)
		pcall(function()
			writefile(HACKER_LIST_FILE, HttpService:JSONEncode(hackerDetectedUsers))
		end)
	end
end

-- local function _isPlayerHacker(userId)
-- 	return hackerDetectedUsers[tostring(userId)] ~= nil
-- end

scheduleSaveHackerList = function()
	if ADMIN_SYS.hackerSaveDebounceTimer then return end
	ADMIN_SYS.hackerSaveDebounceTimer = task.delay(3, function()
		ADMIN_SYS.hackerSaveDebounceTimer = nil
		saveHackerList()
	end)
end

requestRefreshHackerList = function()
	if ADMIN_SYS.hackerRefreshDebounceTimer then return end
	ADMIN_SYS.hackerRefreshDebounceTimer = task.delay(0.6, function()
		ADMIN_SYS.hackerRefreshDebounceTimer = nil
		if hackerWindow and hackerWindow.Visible and refreshHackerList then
			pcall(refreshHackerList)
			if updateHackerLiveCards then pcall(updateHackerLiveCards) end
		end
	end)
end

local function addDetectedHacker(plr, detectType, reasonDetail, severity)
	if not plr or plr == player or isStaffOrAdmin(plr) then return end
	local idStr = tostring(plr.UserId)
	local nowClock = os.date("%X")
	local teamName = plr.Team and plr.Team.Name or "Unknown"

	local record = hackerDetectedUsers[idStr]
	local isNewUser = (record == nil)
	if not record then
		record = {
			userId = plr.UserId,
			name = plr.Name,
			displayName = plr.DisplayName,
			accountAge = plr.AccountAge or 0,
			team = teamName,
			firstDetected = nowClock,
			lastDetected = nowClock,
			reasons = {},
		}
		hackerDetectedUsers[idStr] = record
		print(string.format("🚨 [GAME INCIDENT] %s (@%s) [%s] - %s", plr.DisplayName, plr.Name, string.upper(detectType), reasonDetail))
	end

	record.lastDetected = nowClock
	record.team = teamName
	if not record.reasons then record.reasons = {} end

	local existingReason = record.reasons[detectType]
	local isNewReason = (existingReason == nil)

	if isNewUser or isNewReason then
		record.reasons[detectType] = {
			type = detectType,
			detail = reasonDetail,
			severity = severity or 1,
			time = nowClock,
		}

		scheduleSaveHackerList()

		pcall(function()
			onHackerDetected:Fire(plr, detectType, reasonDetail)
		end)

		if hackerWindow and hackerWindow.Visible then
			requestRefreshHackerList()
		end
	else
		existingReason.detail = reasonDetail
		existingReason.time = nowClock
	end
end

local function removeDetectedHacker(userId)
	local idStr = tostring(userId)
	if hackerDetectedUsers[idStr] then
		hackerDetectedUsers[idStr] = nil
		saveHackerList()
		pcall(refreshHackerList)
	end
end

local function clearAllDetectedHackers()
	hackerDetectedUsers = {}
	saveHackerList()
	pcall(refreshHackerList)
end

loadHackerList()

-- ================================================================
-- DEDICATED ANTI-CHEAT & EXPLOIT DETECTION STORAGE
-- Completely separated from Game Incidents
-- ================================================================
ADMIN_SYS.CHEAT_LIST_FILE = "astrocyna_cheat_detections.json"
ADMIN_SYS.cheatDetectedUsers = {}
ADMIN_SYS.cheatWindow = nil
ADMIN_SYS.onCheatDetected = Instance.new("BindableEvent")
ADMIN_SYS.isCheatWatchdogEnabled = true
ADMIN_SYS.refreshCheatList = function() end
ADMIN_SYS.updateCheatLiveCards = function() end
ADMIN_SYS.cheatSaveDebounceTimer = nil
ADMIN_SYS.cheatRefreshDebounceTimer = nil

function ADMIN_SYS.requestRefreshCheatList()
	if ADMIN_SYS.cheatRefreshDebounceTimer then return end
	ADMIN_SYS.cheatRefreshDebounceTimer = task.delay(0.4, function()
		ADMIN_SYS.cheatRefreshDebounceTimer = nil
		if ADMIN_SYS.cheatWindow and ADMIN_SYS.cheatWindow.Visible and ADMIN_SYS.refreshCheatList then
			pcall(ADMIN_SYS.refreshCheatList)
			if ADMIN_SYS.updateCheatLiveCards then pcall(ADMIN_SYS.updateCheatLiveCards) end
		end
	end)
end

function ADMIN_SYS.toggleCheatGui()
	if not ADMIN_SYS.cheatWindow then return end
	ADMIN_SYS.cheatWindow.Visible = not ADMIN_SYS.cheatWindow.Visible
	if ADMIN_SYS.cheatWindow.Visible then
		if clampPositionToScreen then
			ADMIN_SYS.cheatWindow.Position = clampPositionToScreen(ADMIN_SYS.cheatWindow.Position, ADMIN_SYS.cheatWindow.Size)
		end
		pcall(ADMIN_SYS.refreshCheatList)
		pcall(ADMIN_SYS.updateCheatLiveCards)
	end
end

local function pruneCheatList(maxCount)
	maxCount = maxCount or 60
	local entries = {}
	for uid, rec in pairs(ADMIN_SYS.cheatDetectedUsers) do
		local isOnline = (Players:GetPlayerByUserId(tonumber(uid) or 0) ~= nil)
		table.insert(entries, { uid = uid, time = rec.lastDetected or "", isOnline = isOnline })
	end
	if #entries > maxCount then
		table.sort(entries, function(a, b)
			if a.isOnline ~= b.isOnline then return a.isOnline end
			return a.time > b.time
		end)
		for i = maxCount + 1, #entries do
			ADMIN_SYS.cheatDetectedUsers[entries[i].uid] = nil
		end
	end
end

function ADMIN_SYS.scheduleSaveCheatList()
	if ADMIN_SYS.cheatSaveDebounceTimer then return end
	ADMIN_SYS.cheatSaveDebounceTimer = task.delay(3, function()
		ADMIN_SYS.cheatSaveDebounceTimer = nil
		ADMIN_SYS.saveCheatList()
	end)
end

function ADMIN_SYS.loadCheatList()
	if isfile and readfile and isfile(ADMIN_SYS.CHEAT_LIST_FILE) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(ADMIN_SYS.CHEAT_LIST_FILE))
		end)
		if ok and type(data) == "table" then
			for uid, rec in pairs(data) do
				local hasRemaining = false
				if rec.reasons then
					for _, _ in pairs(rec.reasons) do
						hasRemaining = true
						break
					end
				end
				if not hasRemaining then
					data[uid] = nil
				end
			end
			ADMIN_SYS.cheatDetectedUsers = data
			pruneCheatList(60)
			return
		end
	end
	ADMIN_SYS.cheatDetectedUsers = {}
end

function ADMIN_SYS.saveCheatList()
	if writefile then
		pruneCheatList(60)
		pcall(function()
			writefile(ADMIN_SYS.CHEAT_LIST_FILE, HttpService:JSONEncode(ADMIN_SYS.cheatDetectedUsers))
		end)
	end
end

local function isScanMonitorOpen()
	if not isHackerWatchdogEnabled then return false end
	return (hackerWindow and hackerWindow.Visible == true) or (ADMIN_SYS and ADMIN_SYS.cheatWindow and ADMIN_SYS.cheatWindow.Visible == true)
end

function ADMIN_SYS.addDetectedCheat(plr, detectType, reasonDetail, severity)
	if not plr or plr == player or isStaffOrAdmin(plr) then return end
	local idStr = tostring(plr.UserId)
	local nowClock = os.date("%X")
	local teamName = plr.Team and plr.Team.Name or "Unknown"

	local record = ADMIN_SYS.cheatDetectedUsers[idStr]
	local isNewUser = (record == nil)
	if not record then
		record = {
			userId = plr.UserId,
			name = plr.Name,
			displayName = plr.DisplayName,
			accountAge = plr.AccountAge or 0,
			team = teamName,
			firstDetected = nowClock,
			lastDetected = nowClock,
			reasons = {},
		}
		ADMIN_SYS.cheatDetectedUsers[idStr] = record
		print(string.format("⚡ [ANTI-CHEAT DETECTED] %s (@%s) [%s] - %s", plr.DisplayName, plr.Name, string.upper(detectType), reasonDetail))
	end

	record.lastDetected = nowClock
	record.team = teamName
	if not record.reasons then record.reasons = {} end

	local existingReason = record.reasons[detectType]
	local isNewReason = (existingReason == nil)

	if isNewUser or isNewReason then
		record.reasons[detectType] = {
			type = detectType,
			detail = reasonDetail,
			severity = severity or 2,
			time = nowClock,
		}

		ADMIN_SYS.scheduleSaveCheatList()

		pcall(function()
			ADMIN_SYS.onCheatDetected:Fire(plr, detectType, reasonDetail)
		end)

		if ADMIN_SYS.cheatWindow and ADMIN_SYS.cheatWindow.Visible then
			ADMIN_SYS.requestRefreshCheatList()
		end
	else
		existingReason.detail = reasonDetail
		existingReason.time = nowClock
	end
end

function ADMIN_SYS.removeDetectedCheat(userId)
	local idStr = tostring(userId)
	if ADMIN_SYS.cheatDetectedUsers[idStr] then
		ADMIN_SYS.cheatDetectedUsers[idStr] = nil
		ADMIN_SYS.saveCheatList()
		pcall(ADMIN_SYS.refreshCheatList)
	end
end

function ADMIN_SYS.clearAllDetectedCheats()
	ADMIN_SYS.cheatDetectedUsers = {}
	ADMIN_SYS.saveCheatList()
	pcall(ADMIN_SYS.refreshCheatList)
end

ADMIN_SYS.loadCheatList()
-- Detects third-party executors, memory injections, physics exploits,
-- BodyMovers, speed/fly hacks, air jumps, fling, and exploit commands.
-- ================================================================
ADMIN_SYS.EXECUTOR_DETECTOR = {
	motionHistory = {},
	alertCooldowns = {},
	cachedRayParams = (function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		return p
	end)(),
	rayDown14 = Vector3.new(0, -14, 0),

	-- PRISON RP Official Engine Physics & Speed Constants (from Animate and Stamina)
	PRISON_RP_TEAM_SPEEDS = {
		Prisoner = 22,
		Cadet = 26,
		Guard = 26,
		Sergeant = 26,
		Captain = 26,
		Bodyguard = 26,
		Warden = 26,
		Nurse = 25,
		Medic = 25,
		Surgeon = 25,
		Janitor = 23,
		Cook = 23,
		Teacher = 23,
		Psychologist = 23,
		Ghost = 28,
	},
	PRISON_RP_DEFAULT_WALKSPEED = 16,
	PRISON_RP_DEFAULT_JUMPPOWER = 35,

	PERSISTENT_TYPES = {
		executor_bodymover = true,
		speed_hack = true,
		fly_hack = true,
		infinite_jump = true,
		spinbot_fling = true,
		cframe_teleport = true,
		invis_desync = true,
		hitbox_expander = true,
		executor_chat = true,
		exploit_tool = true,
	},

	EXPLOIT_TOOLS = {
		"btools", "f3x", "dex", "remotespy", "explorer", "kill all", "crash", "touchfling",
		"fling tool", "invis tool", "gun giver", "server destroyer", "scriptware", "synapse",
		"infinite yield", "nameless", "cmd-x", "fates admin", "reviz"
	},

	EXPLOIT_CHAT_PREFIXES = { ";", ":", "-", ",", ".", "!" },
	EXPLOIT_CHAT_COMMANDS = {
		"fly", "unfly", "noclip", "clip", "speed", "ws", "jp", "jumppower", "walkspeed",
		"btools", "god", "tp", "bring", "fling", "kill", "invis", "spin", "unspin",
		"freeze", "thaw", "esp", "aimbot", "hitbox", "iy", "dex", "remotespy", "loopkill",
		"bang", "spasm", "r6", "r15", "re", "respawn", "lag", "crash", "void", "killall"
	},
	EXPLOIT_CHAT_SIGNATURES = {
		"potassium", "solara", "wave executor", "codex executor", "delta executor",
		"arceus x", "hydrogen executor", "krnl", "scriptware", "synapse x", "fluxus"
	},

	fireAlert = function(plr, detectType, detail)
		if not plr or plr == player or isStaffOrAdmin(plr) then return end
		local now = tick()
		-- 1. Global throttle: ป้องกันการแจ้งเตือนถี่เกินไปทำให้เกิดอาการกระตุก (เว้นระยะอย่างน้อย 2.5 วินาทีระหว่าง Alert Bubble)
		if (ADMIN_SYS.lastGlobalExploitAlert or 0) + 2.5 > now then return end
		-- 2. Per-player per-detectType cooldown: ขยายเป็น 20 วินาที
		local cdKey = tostring(plr.UserId) .. "_" .. detectType
		if (ADMIN_SYS.EXECUTOR_DETECTOR.alertCooldowns[cdKey] or 0) > now then return end
		ADMIN_SYS.EXECUTOR_DETECTOR.alertCooldowns[cdKey] = now + 20
		ADMIN_SYS.lastGlobalExploitAlert = now
		if ADMIN_SYS.showExploitAlertBubble then
			pcall(ADMIN_SYS.showExploitAlertBubble, plr, detectType, detail)
		end
	end,

	scanCharacter = function(plr)
		if not plr or plr == player or isStaffOrAdmin(plr) then return end
		local char = plr.Character
		if not char then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end

		local isSeated = (hum.Sit == true and hum.SeatPart ~= nil)

		-- 1. Direct Part Inspection (Zero GetDescendants traversal - 95% faster)
		if not isSeated then
			local function checkPartMovers(part)
				if not part then return false end
				for _, c in ipairs(part:GetChildren()) do
					if c:IsA("BodyVelocity") or c:IsA("BodyPosition") or c:IsA("BodyGyro") or c:IsA("BodyThrust") or c:IsA("RocketPropulsion") then
						local detail = string.format("💉 Executor BodyMover Injected: %s (%s)", c.ClassName, c.Name)
						ADMIN_SYS.addDetectedCheat(plr, "executor_bodymover", detail, 3)
						ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "executor_bodymover", "BodyMover Injected: " .. c.ClassName)
						return true
					elseif c:IsA("LinearVelocity") or c:IsA("VectorForce") or c:IsA("AlignPosition") or c:IsA("AlignOrientation") then
						local detail = string.format("💉 Injected Physics Constraint: %s", c.ClassName)
						ADMIN_SYS.addDetectedCheat(plr, "executor_bodymover", detail, 3)
						ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "executor_bodymover", "Physics Constraint: " .. c.ClassName)
						return true
					end
				end
				return false
			end

			if not checkPartMovers(hrp) then
				local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
				if not checkPartMovers(torso) then
					checkPartMovers(char)
				end
			end
		end

		-- 2. Hitbox Expansion (Enlarged RootPart / Giant Tool Handle)
		if hrp.Size.X > 4.5 or hrp.Size.Y > 4.5 or hrp.Size.Z > 4.5 then
			local detail = string.format("📦 Hitbox Expander: RootPart %.1fx%.1fx%.1f", hrp.Size.X, hrp.Size.Y, hrp.Size.Z)
			ADMIN_SYS.addDetectedCheat(plr, "hitbox_expander", detail, 3)
		end

		-- 3. Injected Exploit Tools & Tool Reach
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				local tNameLow = string.lower(child.Name)
				for _, exTool in ipairs(ADMIN_SYS.EXECUTOR_DETECTOR.EXPLOIT_TOOLS) do
					if string.find(tNameLow, exTool, 1, true) then
						local detail = string.format("🛠️ Injected Exploit Tool: \"%s\"", child.Name)
						ADMIN_SYS.addDetectedCheat(plr, "exploit_tool", detail, 3)
						ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "exploit_tool", "Tool: " .. child.Name)
						break
					end
				end
				local handle = child:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") and handle.Size.Magnitude > 18 then
					local detail = string.format("📦 Tool Reach / Giant Handle: %s", child.Name)
					ADMIN_SYS.addDetectedCheat(plr, "hitbox_expander", detail, 3)
				end
			end
		end

		-- 4. Invisible / Desync Exploit
		if hum.Health > 0 then
			local head = char:FindFirstChild("Head")
			local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if not head or not torso then
				ADMIN_SYS.addDetectedCheat(plr, "invis_desync", "👻 Invisible / Detached Character Exploit", 3)
			elseif hrp.Position.Y < -500 or hrp.Position.Magnitude > 50000 then
				ADMIN_SYS.addDetectedCheat(plr, "invis_desync", "👻 Out-of-Bounds Void Desync Exploit", 3)
			end
		end
	end,

	trackMotion = function(plr)
		if not plr or plr == player or isStaffOrAdmin(plr) then return end
		local char = plr.Character
		if not char then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end

		if hum.Sit == true and hum.SeatPart ~= nil then
			ADMIN_SYS.EXECUTOR_DETECTOR.motionHistory[plr.UserId] = nil
			return
		end

		local now = tick()
		local currPos = hrp.Position
		local linVel = hrp.AssemblyLinearVelocity
		local angVel = hrp.AssemblyAngularVelocity
		local hist = ADMIN_SYS.EXECUTOR_DETECTOR.motionHistory[plr.UserId]

		if not hist then
			ADMIN_SYS.EXECUTOR_DETECTOR.motionHistory[plr.UserId] = {
				lastPos = currPos,
				lastTime = now,
				lastVelY = linVel.Y,
				highSpeedTicks = 0,
				flyTicks = 0,
				airJumps = 0,
				spinTicks = 0,
			}
			return
		end

		local timeDiff = math.max(now - hist.lastTime, 0.001)
		local disp = (currPos - hist.lastPos)
		local hDisp = math.sqrt(disp.X * disp.X + disp.Z * disp.Z) / timeDiff

		-- Vehicle / Kart / Bench / Physics Exemption (Prevents False Positives in latest Prison RP)
		local isExemptMotion = hum.Sit or (hum.SeatPart ~= nil) or (char and (char:FindFirstChildOfClass("Seat") or char:GetAttribute("InKart") or char:GetAttribute("Skating") or char:GetAttribute("KnockedOut") or char:GetAttribute("Ragdoll")))

		-- 1. CFrame Instant Teleport (> 65 studs in < 0.4s)
		if not isExemptMotion and disp.Magnitude > 65 and timeDiff < 0.4 and hum.Health > 0 then
			local detail = string.format("📍 CFrame Teleport: %.0f studs in %.2fs", disp.Magnitude, timeDiff)
			ADMIN_SYS.addDetectedCheat(plr, "cframe_teleport", detail, 3)
			ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "cframe_teleport", string.format("Teleport: %.0f studs", disp.Magnitude))
		end

		-- 2. Speed Hack (Exact PRISON RP Team Limits: Prisoner 22, Guard 26, Ghost 28)
		local teamName = plr.Team and plr.Team.Name or ""
		local baseTeamSprint = ADMIN_SYS.EXECUTOR_DETECTOR.PRISON_RP_TEAM_SPEEDS[teamName] or 24
		local speedMult = tonumber(plr:GetAttribute("SpeedMultiplier")) or (char and tonumber(char:GetAttribute("SpeedMultiplier"))) or 1
		speedMult = math.clamp(speedMult, 0.25, 4)
		local boostSpeed = plr:GetAttribute("BoostSpeed") or (char and char:GetAttribute("BoostSpeed"))
		local allowedSprintMax = (baseTeamSprint * speedMult) + (boostSpeed and tonumber(boostSpeed) or 0)
		local speedThreshold = allowedSprintMax + 4.5 -- 4.5 studs/s tolerance for network replication ping jitter

		if not isExemptMotion and hDisp > speedThreshold then
			hist.highSpeedTicks = hist.highSpeedTicks + 1
			if hist.highSpeedTicks >= 3 or hDisp > (allowedSprintMax + 18) then
				local detail = string.format("⚡ Speed Hack: %.1f studs/s (PRISON RP Limit: %d studs/s for %s)", hDisp, allowedSprintMax, teamName ~= "" and teamName or "Player")
				ADMIN_SYS.addDetectedCheat(plr, "speed_hack", detail, 3)
				ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "speed_hack", string.format("Speed: %.1f studs/s (Max: %d)", hDisp, allowedSprintMax))
			end
		else
			hist.highSpeedTicks = math.max(hist.highSpeedTicks - 1, 0)
		end

		-- 3. Fly Hack / Air Float Exploit (Zero raycasts when walking on ground!)
		if hum.FloorMaterial == Enum.Material.Air then
			local hSpeed = math.sqrt(linVel.X * linVel.X + linVel.Z * linVel.Z)
			local isFloating = (math.abs(linVel.Y) < 2.0 and hSpeed > 16)
			local isElevating = (linVel.Y > 6 and math.abs(linVel.Y - (hist.lastVelY or 0)) < 1.2)

			if isFloating or isElevating then
				local rParams = ADMIN_SYS.EXECUTOR_DETECTOR.cachedRayParams
				rParams.FilterDescendantsInstances = { char }
				local groundHit = workspace:Raycast(currPos, ADMIN_SYS.EXECUTOR_DETECTOR.rayDown14 or Vector3.new(0, -14, 0), rParams)

				if not groundHit then
					hist.flyTicks = hist.flyTicks + 1
					if hist.flyTicks >= 3 then
						local detail = isFloating and string.format("🕊️ Fly Hack / Air Float (Speed: %.1f studs/s)", hSpeed) or "🕊️ Fly Hack / Vertical Ascend Exploit"
						ADMIN_SYS.addDetectedCheat(plr, "fly_hack", detail, 3)
						ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "fly_hack", isFloating and string.format("Fly Hack: %.1f studs/s", hSpeed) or "Vertical Fly Ascend")
					end
				else
					hist.flyTicks = 0
				end
			else
				hist.flyTicks = math.max(hist.flyTicks - 1, 0)
			end

			-- Infinite Jump (PRISON RP Standard JumpPower = 35)
			if linVel.Y > 36 and (linVel.Y - (hist.lastVelY or 0)) > 24 then
				hist.airJumps = hist.airJumps + 1
				if hist.airJumps >= 3 then
					local detail = string.format("🦘 Infinite Jump: %d Mid-Air Jumps (PRISON RP Limit: JumpPower 35)", hist.airJumps)
					ADMIN_SYS.addDetectedCheat(plr, "infinite_jump", detail, 2)
					ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "infinite_jump", string.format("Infinite Jump (%d air jumps)", hist.airJumps))
				end
			end
		else
			hist.flyTicks = 0
			hist.airJumps = 0
		end

		-- 4. Spinbot / Fling Exploit
		if angVel.Magnitude > 180 then
			hist.spinTicks = hist.spinTicks + 1
			if hist.spinTicks >= 3 then
				local detail = string.format("🌀 Spinbot / Fling: %.0f rad/s", angVel.Magnitude)
				ADMIN_SYS.addDetectedCheat(plr, "spinbot_fling", detail, 3)
				ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "spinbot_fling", string.format("Spinbot: %.0f rad/s", angVel.Magnitude))
			end
		else
			hist.spinTicks = 0
		end

		hist.lastPos = currPos
		hist.lastTime = now
		hist.lastVelY = linVel.Y
	end,

	scanChat = function(plr, msg)
		if not plr or plr == player or isStaffOrAdmin(plr) or not msg or msg == "" then return end
		local clean = string.lower(string.match(msg, "^%s*(.-)%s*$") or "")
		if clean == "" then return end

		-- Filter out common text emoticons / punctuation to eliminate false positive cheat alerts
		local emoticonPatterns = {
			"^:[dDpPvVoOxX3)%(\\/\\|]$",
			"^:-[dDpPvVoOxX3)%(\\/\\|]$",
			"^;[dDpPvVoOxX3)%(\\/\\|]$",
			"^;-[dDpPvVoOxX3)%(\\/\\|]$",
			"^%^[_%^]+$",
			"^-[_-]+$",
			"^%.%.$",
			"^%.%.%.$",
		}
		for _, ep in ipairs(emoticonPatterns) do
			if string.match(clean, ep) then return end
		end

		local firstChar = string.sub(clean, 1, 1)
		for _, pfx in ipairs(ADMIN_SYS.EXECUTOR_DETECTOR.EXPLOIT_CHAT_PREFIXES) do
			if firstChar == pfx then
				local rest = string.sub(clean, 2)
				local cmd, after = string.match(rest, "^([a-zA-Z0-9_]+)(.*)")
				if cmd then
					local isValidCommandBoundary = (after == "" or string.match(after, "^%s") ~= nil)
					if isValidCommandBoundary then
						for _, expCmd in ipairs(ADMIN_SYS.EXECUTOR_DETECTOR.EXPLOIT_CHAT_COMMANDS) do
							if cmd == expCmd then
								local detail = string.format("💬 Executor Command in Chat: \"%s\"", msg)
								ADMIN_SYS.addDetectedCheat(plr, "executor_chat", detail, 3)
								ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "executor_chat", "Executor Command: " .. msg)
								return
							end
						end
					end
				end
			end
		end

		for _, sig in ipairs(ADMIN_SYS.EXECUTOR_DETECTOR.EXPLOIT_CHAT_SIGNATURES) do
			if string.find(clean, sig, 1, true) then
				local detail = string.format("💬 Executor Signature in Chat: \"%s\"", msg)
				ADMIN_SYS.addDetectedCheat(plr, "executor_chat", detail, 3)
				ADMIN_SYS.EXECUTOR_DETECTOR.fireAlert(plr, "executor_chat", "Executor Mention: " .. msg)
				return
			end
		end
	end,

	startWatchdog = function()
		-- Hook TextChatService (Modern Chat)
		pcall(function()
			local tcs = game:GetService("TextChatService")
			if tcs and tcs.ChatVersion == Enum.ChatVersion.TextChatService then
				tcs.MessageReceived:Connect(function(textChatMessage)
					if textChatMessage and textChatMessage.TextSource then
						local senderPlr = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
						if senderPlr and senderPlr ~= player then
							ADMIN_SYS.EXECUTOR_DETECTOR.scanChat(senderPlr, textChatMessage.Text)
						end
					end
				end)
			end
		end)

		-- Hook Player.Chatted
		local function hookChat(plr)
			plr.Chatted:Connect(function(msg)
				ADMIN_SYS.EXECUTOR_DETECTOR.scanChat(plr, msg)
			end)
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then hookChat(plr) end
		end
		Players.PlayerAdded:Connect(function(plr)
			if plr ~= player then hookChat(plr) end
		end)

		-- Ultra-smooth background motion tracker loop (0.45s off-render async loop - 0 FPS impact)
			-- Motion tracker loop: ONLY scans when scan/incident/cheat window is OPEN
		task.spawn(function()
			while true do
				task.wait(1.2)
				if isScanMonitorOpen() then
					for _, plr in ipairs(Players:GetPlayers()) do
						if plr ~= player and not isStaffOrAdmin(plr) then
							pcall(ADMIN_SYS.EXECUTOR_DETECTOR.trackMotion, plr)
						end
					end
				end
			end
		end)
	end,
}

-- ================================================================
-- BUILT-IN GAME ATTRIBUTE SCANNER (PRISON RP ENGINE CHECKS)
-- ================================================================
local function scanPlayerGameAttributes(plr)
	if not plr or plr == player or isStaffOrAdmin(plr) then return end
	local char = plr.Character
	local idStr = tostring(plr.UserId)

	-- Run executor & exploit checks on character
	if ADMIN_SYS.EXECUTOR_DETECTOR then
		pcall(ADMIN_SYS.EXECUTOR_DETECTOR.scanCharacter, plr)
	end

	local foundReasons = {}

	-- 1. Built-in RPStatus (Crime Level: 1 = Suspect, 2 = Wanted, 3 = Hostile)
	local rpStatus = plr:GetAttribute("RPStatus") or (char and char:GetAttribute("RPStatus"))
	local rpReason = plr:GetAttribute("RPStatusReason") or (char and char:GetAttribute("RPStatusReason"))
	local numStatus = tonumber(rpStatus) or 0

	if numStatus >= 3 then
		local detail = "Hostile Criminal"
		if rpReason and rpReason ~= "" then detail = "Hostile: " .. tostring(rpReason) end
		foundReasons["hostile"] = { detail = detail, severity = 3 }
	elseif numStatus == 2 then
		local detail = "APB Wanted"
		if rpReason and rpReason ~= "" then detail = "Wanted: " .. tostring(rpReason) end
		foundReasons["wanted"] = { detail = detail, severity = 2 }
	elseif numStatus == 1 then
		local detail = "Suspect Flagged"
		if rpReason and rpReason ~= "" then detail = "Suspect: " .. tostring(rpReason) end
		foundReasons["suspect"] = { detail = detail, severity = 1 }
	end

	-- Verify with live APB Wanted cache
	pcall(function()
		local isWanted, wantedReason = ADMIN_SYS.isPlayerWanted(plr)
		if isWanted and not foundReasons["hostile"] and not foundReasons["wanted"] then
			foundReasons["wanted"] = { detail = "APB Wanted: " .. (wantedReason or "Criminal"), severity = 2 }
		end
	end)

	-- 2. Recent Assault / Battery Flag
	if plr:GetAttribute("RecentAssault") == true or (char and char:GetAttribute("RecentAssault") == true) then
		foundReasons["assault"] = { detail = "Recent Assault / Violence", severity = 2 }
	end

	-- 3. Contraband / Smuggling Run (PRISON RP ContrabandTracker)
	local contrabandTo = plr:GetAttribute("ContrabandTo") or (char and char:GetAttribute("ContrabandTo"))
	local contrabandUntil = plr:GetAttribute("ContrabandUntil") or (char and char:GetAttribute("ContrabandUntil"))
	if contrabandTo or (contrabandUntil and typeof(contrabandUntil) == "number" and contrabandUntil > os.time()) then
		local detail = contrabandTo and string.format("Smuggling Contraband (Deliver to %s)", tostring(contrabandTo)) or "Smuggling Contraband Run"
		foundReasons["contraband"] = { detail = detail, severity = 2 }
	end

	-- 4. Jailed in Solitary Cell
	local isJailed = plr:GetAttribute("Jailed") == true or (char and char:GetAttribute("Jailed") == true)
	if isJailed then
		local jailReason = plr:GetAttribute("JailReason") or (char and char:GetAttribute("JailReason")) or "Isolation"
		local jailOfficer = plr:GetAttribute("JailOfficer") or (char and char:GetAttribute("JailOfficer"))
		local justified = plr:GetAttribute("JailJustified") or (char and char:GetAttribute("JailJustified"))
		local detail = "In Solitary: " .. tostring(jailReason)
		if jailOfficer then detail = detail .. " (" .. tostring(jailOfficer) .. ")" end
		if justified == false then detail = detail .. " [UNJUSTIFIED]" end
		foundReasons["jailed"] = { detail = detail, severity = 2 }
	end

	-- 5. Cuffed / Restrained
	local isCuffed = plr:GetAttribute("Cuffed") == true or (char and char:GetAttribute("Cuffed") == true)
	if isCuffed then
		local isSurrendered = plr:GetAttribute("CuffedSurrendered") == true or (char and char:GetAttribute("CuffedSurrendered") == true)
		local detail = isSurrendered and "Handcuffed (Surrendered)" or "Handcuffed (Arrested)"
		foundReasons["cuffed"] = { detail = detail, severity = 1 }
	end

	-- 6. Community Service Sentence
	local sentenceActive = plr:GetAttribute("SentenceActive") == true or (char and char:GetAttribute("SentenceActive") == true)
	if sentenceActive then
		local sUnit = plr:GetAttribute("SentenceUnit") or "Community Service"
		foundReasons["sentence"] = { detail = "Sentence: " .. tostring(sUnit), severity = 1 }
	end

	-- 7. Security Camera Surveillance (Watched)
	local isWatched = plr:GetAttribute("Watched") == true or (char and char:GetAttribute("Watched") == true)
	if isWatched then
		foundReasons["cctv"] = { detail = "Under CCTV Security Camera", severity = 1 }
	end

	-- 8. Roll Call & Summons Violations
	if plr:GetAttribute("RollCallMissing") == true or (char and char:GetAttribute("RollCallMissing") == true) then
		foundReasons["rollcall"] = { detail = "Absent from Roll Call", severity = 1 }
	end
	local summonUntil = plr:GetAttribute("SummonUntil") or (char and char:GetAttribute("SummonUntil"))
	local summonArrived = plr:GetAttribute("SummonArrived") or (char and char:GetAttribute("SummonArrived"))
	if summonUntil and typeof(summonUntil) == "number" and os.time() > summonUntil and not summonArrived then
		foundReasons["summons"] = { detail = "Ignored Warden Summons", severity = 2 }
	end

	-- 9. Guard Post Abandonment (>3m)
	local postFineAt = plr:GetAttribute("PostFineAt")
	if postFineAt and typeof(postFineAt) == "number" and os.time() > postFineAt then
		foundReasons["demerit"] = { detail = "Abandoned Guard Post (>3m)", severity = 2 }
	end

	-- 10. Animation Lag Spamming (PRISON RP TrackWatchClient Check: >= 40 tracks)
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
			if ok and tracks and #tracks >= 40 then
				ADMIN_SYS.addDetectedCheat(plr, "anim_spam", string.format("TrackWatch: %d Animation Tracks (PRISON RP Limit: 40)", #tracks), 3)
			end
		end
	end

	-- Sync reasons to hackerDetectedUsers
	local _hasAny = false
	for rType, rData in pairs(foundReasons) do
		_hasAny = true
		addDetectedHacker(plr, rType, rData.detail, rData.severity)
	end

	if hackerDetectedUsers[idStr] then
		local rec = hackerDetectedUsers[idStr]
		local changed = false
		for rType, _ in pairs(rec.reasons) do
			if not (ADMIN_SYS.EXECUTOR_DETECTOR and ADMIN_SYS.EXECUTOR_DETECTOR.PERSISTENT_TYPES[rType]) and not foundReasons[rType] then
				rec.reasons[rType] = nil
				changed = true
			end
		end
		local count = 0
		for _ in pairs(rec.reasons) do count = count + 1 end
		if count == 0 then
			hackerDetectedUsers[idStr] = nil
			changed = true
		end
		if changed then
			scheduleSaveHackerList()
			if hackerWindow and hackerWindow.Visible then
				requestRefreshHackerList()
			end
		end
	end
end

scanAllPlayersRealtime = function()
	local detectedCount = 0
	pcall(ADMIN_SYS.updateApbList)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and not isStaffOrAdmin(plr) then
			pcall(scanPlayerGameAttributes, plr)
			if hackerDetectedUsers[tostring(plr.UserId)] then
				detectedCount = detectedCount + 1
			end
		end
	end

	if hackerWindow and hackerWindow.Visible then
		pcall(refreshHackerList)
		pcall(updateHackerLiveCards)
	end
	return detectedCount
end

local function hookPlayerRealtime(plr)
	if not plr or plr == player or hookedPlayers[plr] then return end
	hookedPlayers[plr] = true

	task.spawn(function()
		if checkPlayerStaff then checkPlayerStaff(plr) end
		if not isStaffOrAdmin(plr) then
			pcall(scanPlayerGameAttributes, plr)
		end
	end)

	local function onCharAdded(char)
		task.delay(0.2, function()
			if not isStaffOrAdmin(plr) then
				pcall(scanPlayerGameAttributes, plr)
			end
		end)

		char.AttributeChanged:Connect(function()
			if isScanMonitorOpen() and not isStaffOrAdmin(plr) then
				pcall(scanPlayerGameAttributes, plr)
			end
		end)
	end

	if plr.Character then onCharAdded(plr.Character) end
	plr.CharacterAdded:Connect(onCharAdded)

	plr:GetPropertyChangedSignal("Team"):Connect(function()
		if isScanMonitorOpen() and not isStaffOrAdmin(plr) then
			pcall(scanPlayerGameAttributes, plr)
		end
	end)

	plr.AttributeChanged:Connect(function()
		if isScanMonitorOpen() and not isStaffOrAdmin(plr) then
			pcall(scanPlayerGameAttributes, plr)
		end
	end)
end

local function startHackerWatchdog()
	scanAllPlayersRealtime()

	if ADMIN_SYS.EXECUTOR_DETECTOR then
		pcall(ADMIN_SYS.EXECUTOR_DETECTOR.startWatchdog)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayerRealtime(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		hookPlayerRealtime(plr)
		if hackerWindow and hackerWindow.Visible then
			pcall(updateHackerLiveCards)
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		hookedPlayers[plr] = nil
		if hackerWindow and hackerWindow.Visible then
			pcall(updateHackerLiveCards)
		end
	end)

	-- Listen to VoteKick events
	pcall(function()
		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		local vk = rem and rem:FindFirstChild("VoteKick")
		local ev = vk and vk:FindFirstChild("Event")
		local PRISON_RP_LOG_ACTIONS = {
			Fired = "ไล่ออก (Fired)",
			Suspended = "พักงาน (Suspended)",
			Warned = "ตักเตือน (Warned)",
			Pardoned = "อภัยโทษ (Pardoned)",
			ClearedWanted = "ยกเลิก Wanted",
			ClearedHostile = "ยกเลิก Hostile",
			RiotUnit = "ส่ง CERT ออกปฏิบัติการ"
		}
		if ev and ev:IsA("RemoteEvent") then
			ev.OnClientEvent:Connect(function(action, data)
				if action == "Begin" and type(data) == "table" then
					if data.Target then
						local targetName = tostring(data.Target)
						local targetPlr = Players:FindFirstChild(targetName)
						if targetPlr then
							addDetectedHacker(targetPlr, "votekick", "VoteKick Initiated Against Player", 2)
						end
					end
					if typeof(data.Log) == "table" then
						for _, entry in ipairs(data.Log) do
							if typeof(entry) == "table" and entry.Target and entry.Kind then
								local tPlr = Players:FindFirstChild(tostring(entry.Target))
								if tPlr then
									local actName = PRISON_RP_LOG_ACTIONS[entry.Kind] or tostring(entry.Kind)
									addDetectedHacker(tPlr, "admin_action", string.format("Warden Action: %s", actName), 2)
								end
							end
						end
					end
				end
			end)
		end
	end)

	-- Periodic scan loop: ONLY scans when scan/incident/cheat window is OPEN
	task.spawn(function()
		while true do
			task.wait(2.5)
			if isScanMonitorOpen() then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= player and not isStaffOrAdmin(plr) then
						pcall(scanPlayerGameAttributes, plr)
					end
				end
			end
		end
	end)
end

ADMIN_SYS.isPlayerWanted = function(plr)
	if not plr then return false, nil end
	local nameLower = string.lower(plr.Name)
	if ADMIN_SYS.apbWantedUsers[nameLower] then
		local detail = ADMIN_SYS.apbWantedUsers[nameLower]
		local reason = type(detail) == "table" and (detail.Reason or detail.Crime or detail.crime or "APB Wanted") or tostring(detail)
		return true, reason
	end
	local attrWanted = plr:GetAttribute("Wanted") or plr:GetAttribute("WantedLevel") or plr:GetAttribute("Crime")
	if attrWanted and (attrWanted == true or (type(attrWanted) == "number" and attrWanted > 0) or type(attrWanted) == "string") then
		return true, "Wanted Criminal"
	end
	local char = getPlayerChar and getPlayerChar(plr) or plr.Character
	if char then
		local cAttr = char:GetAttribute("Wanted") or char:GetAttribute("WantedLevel")
		if cAttr and (cAttr == true or (type(cAttr) == "number" and cAttr > 0)) then
			return true, "Wanted Criminal"
		end
	end
	return false, nil
end

do
	local lastApbFetch = 0
	local isApbFetching = false
	ADMIN_SYS.updateApbList = function()
	local now = os.time()
	if now - lastApbFetch < 10 or isApbFetching then return end
	lastApbFetch = now
	isApbFetching = true
	task.spawn(function()
		pcall(function()
			local rem = ReplicatedStorage:FindFirstChild("Remotes")
			local apbFunc = rem and rem:FindFirstChild("APBFunction")
			if apbFunc and apbFunc:IsA("RemoteFunction") then
				local res = apbFunc:InvokeServer()
				if type(res) == "table" then
					table.clear(ADMIN_SYS.apbWantedUsers)
					for key, val in pairs(res) do
						local uName = type(val) == "table" and (val.Name or val.name or val.PlayerName) or tostring(key)
						if uName and uName ~= "" then
							ADMIN_SYS.apbWantedUsers[string.lower(uName)] = val
						end
					end
				end
			end
		end)
		isApbFetching = false
	end)
end
end

ADMIN_SYS.updateStaffRadar = function()
	pcall(function()
		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		local adminDir = rem and rem:FindFirstChild("Admin")
		local modFunc = adminDir and adminDir:FindFirstChild("ModLists")
		if modFunc and modFunc:IsA("RemoteFunction") then
			local res = modFunc:InvokeServer()
			if type(res) == "table" then
				for _, staffItem in ipairs(res) do
					local sName = type(staffItem) == "table" and (staffItem.Name or staffItem.name) or tostring(staffItem)
					if sName and sName ~= "" then
						local foundPlr = Players:FindFirstChild(sName)
						if foundPlr then
							ADMIN_SYS.showStaffAlertBanner(foundPlr, "Moderator", 100)
						end
					end
				end
			end
		end
	end)
end

-- =====================================================================
-- SERVER BROWSER STAFF VISIBILITY (VIEW ONLY)
-- The game already replicates every server's player list to every client
-- (ReplicatedStorage.Servers[*]:GetAttribute("Players")). Incognito staff are
-- stored there as negative UserIds, normal staff are matched against the
-- group roster. Nothing is sent to the server by this system.
-- =====================================================================
do
	local STAFF_MIN_RANK = 200
	local STAFF_ROLE_KEYWORDS = { "staff", "mod", "admin", "dev", "owner", "founder" }
	local HTTP_HOSTS = { "groups.roproxy.com" }
	local STAFF_RED = Color3.fromRGB(255, 60, 80)
	local nameCache = {}
	local namePending = {}

	local function resolveName(idStr)
		if nameCache[idStr] then return nameCache[idStr] end
		local numId = tonumber(idStr)
		if not numId then return nil end
		local plr = Players:GetPlayerByUserId(numId)
		if plr then
			nameCache[idStr] = plr.Name
			return plr.Name
		end
		if not namePending[idStr] then
			namePending[idStr] = true
			task.spawn(function()
				local ok, res = pcall(function() return Players:GetNameFromUserIdAsync(numId) end)
				if ok and res then nameCache[idStr] = res end
				namePending[idStr] = nil
			end)
		end
		return nil
	end
	local rosterBusy = false
	local lastRosterFetch = -math.huge
	local serverInfoMap = nil
	local nativeScroll = nil

	local function isStaffRoleName(roleName, rank)
		if (rank or 0) >= STAFF_MIN_RANK then return true end
		local lower = string.lower(tostring(roleName or ""))
		for _, kw in ipairs(STAFF_ROLE_KEYWORDS) do
			if string.find(lower, kw, 1, true) then return true end
		end
		return false
	end

	local function httpGetJson(url)
		local body = nil
		local requestFn = (syn and syn.request) or http_request or request or (http and http.request)
		if requestFn then
			pcall(function()
				local res = requestFn({ Url = url, Method = "GET", Timeout = 5.0 })
				if res and res.Body and (res.StatusCode == nil or res.StatusCode == 200) then
					body = res.Body
				end
			end)
		end
		if not body then
			pcall(function()
				if type(game.HttpGet) == "function" then
					body = game:HttpGet(url)
				end
			end)
		end
		if type(body) ~= "string" or body == "" then return nil end
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if ok and type(data) == "table" then return data end
		return nil
	end

	local function fetchGroupJson(path)
		for _, host in ipairs(HTTP_HOSTS) do
			local data = httpGetJson("https://" .. host .. path)
			if data and not data.errors then return data end
		end
		return nil
	end

	-- Builds {[userIdString] = {name, display, role, rank}} for every staff-ranked group member.
	ADMIN_SYS.refreshStaffRoster = function(force)
		if rosterBusy then return end
		local minGap = (next(ADMIN_SYS.serverStaffRoster) == nil) and 180 or 600
		if not force and os.clock() - lastRosterFetch < minGap then return end
		rosterBusy = true
		lastRosterFetch = os.clock()
		task.spawn(function()
			pcall(function()
				local roster = {}
				local groupIds = { GAME_GROUP_ID, 181881217 }
				for _, gId in ipairs(groupIds) do
					local rolesData = fetchGroupJson("/v1/groups/" .. tostring(gId) .. "/roles")
					if rolesData and type(rolesData.roles) == "table" then
						for _, role in ipairs(rolesData.roles) do
							local members = role.memberCount or 0
							if isStaffRoleName(role.name, role.rank) and members > 0 and members <= 500 then
								local cursor = ""
								for _ = 1, 6 do
									local path = string.format("/v1/groups/%d/roles/%d/users?limit=100&sortOrder=Asc", gId, role.id)
									if cursor ~= "" then path = path .. "&cursor=" .. cursor end
									local page = fetchGroupJson(path)
									if not page or type(page.data) ~= "table" then break end
									for _, u in ipairs(page.data) do
										local idStr = tostring(u.userId)
										roster[idStr] = {
											name = u.username,
											display = u.displayName,
											role = role.name,
											rank = role.rank,
										}
										nameCache[idStr] = u.username
									end
									if page.nextPageCursor and page.nextPageCursor ~= "" then
										cursor = page.nextPageCursor
									else
										break
									end
								end
							end
						end
					end
				end
				if next(roster) ~= nil then
					ADMIN_SYS.serverStaffRoster = roster
					if ADMIN_SYS.invalidateServerStaffCache then
						ADMIN_SYS.invalidateServerStaffCache()
					end
				end
			end)
			rosterBusy = false
			pcall(ADMIN_SYS.refreshServerStaffGui, false)
			pcall(ADMIN_SYS.decorateNativeServerList)
		end)
	end

	-- Eager initial roster fetch so native list and Server Staff immediately know who is staff
	task.spawn(function()
		task.wait(1.0)
		pcall(ADMIN_SYS.refreshStaffRoster, true)
	end)
	pcall(function()
		player:SetAttribute("SeeHiddenStaff", true)
	end)

	-- Global Spy (Script User Cross-Server Detection) - REMOVED
	ADMIN_SYS.globalSpies = {}
	ADMIN_SYS.GLOBAL_SPY_REGISTRY = {
		broadcast = function() end,
		poll = function() end,
	}

	-- Roster first, then staff already detected in the CURRENT server by checkPlayerStaff.
	local function lookupStaff(idStr)
		local entry = ADMIN_SYS.serverStaffRoster[idStr]
		if entry then return entry end
		local numId = tonumber(idStr)
		local cached = numId and staffCache[numId]
		if cached and cached.isStaff then
			return { role = cached.role, rank = cached.rank }
		end
		return nil
	end

	local function getServerInfo(serverId)
		if not serverInfoMap then
			serverInfoMap = {}
			pcall(function()
				local modules = ReplicatedStorage:FindFirstChild("Modules")
				local mod = modules and modules:FindFirstChild("ServerModule")
				if mod and mod:IsA("ModuleScript") then
					local data = require(mod)
					for category, group in pairs(data.Servers or {}) do
						if type(group) == "table" then
							for sid, info in pairs(group) do
								if type(info) == "table" then
									serverInfoMap[sid] = { name = info.Name, category = category, serverType = info.Type }
								end
							end
						end
					end
				end
			end)
		end
		return serverInfoMap and serverInfoMap[serverId]
	end

	local cachedScanResults = {}
	local lastScanTime = -math.huge
	local serverParsedCache = {} -- [srvName] = { raw = rawString, total = total, staff = staffList, spies = spyList, blacklist = blacklistList }
	local presenceCache = {} -- [idStr] = { data = ..., time = os.clock() }
	local presencePending = {} -- [idStr] = true

	ADMIN_SYS.invalidateServerStaffCache = function()
		lastScanTime = -math.huge
		table.clear(serverParsedCache)
	end

	-- Returns one entry per server: { id, title, category, serverType, total, max, isCurrent, staff = { ... }, spies = { ... }, blacklist = { ... } }
	ADMIN_SYS.scanServerStaff = function(force)
		local now = os.clock()
		if not force and (now - lastScanTime < 4.5) and #cachedScanResults > 0 then
			return cachedScanResults
		end
		lastScanTime = now

		local results = {}
		local serversFolder = ReplicatedStorage:FindFirstChild("Servers")
		if not serversFolder then
			cachedScanResults = results
			return results
		end
		local idObj = ReplicatedStorage:FindFirstChild("ServerId")
		local currentId = (idObj and idObj:IsA("ValueBase")) and tostring(idObj.Value) or ""

		for _, srv in ipairs(serversFolder:GetChildren()) do
			local raw = srv:GetAttribute("Players")
			local cached = serverParsedCache[srv.Name]
			local staffList, blacklistList, total

			if cached and cached.raw == raw then
				staffList = cached.staff
				blacklistList = cached.blacklist
				total = cached.total
			else
				staffList = {}
				blacklistList = {}
				local seenServerStaff = {}
				local seenServerBl = {}
				total = 0

				if type(raw) == "string" and raw ~= "" then
					for token in string.gmatch(raw, "[^,]+") do
						local n = tonumber(token)
						if n then
							total = total + 1
							local incognito = n < 0
							local idStr = tostring(math.abs(n))
							local known = lookupStaff(idStr)
							if (incognito or known) and not seenServerStaff[idStr] then
								seenServerStaff[idStr] = true
								table.insert(staffList, {
									userId = math.abs(n),
									idStr = idStr,
									name = (known and known.name) or resolveName(idStr),
									role = (known and known.role) or (incognito and "Hidden Staff" or "Staff"),
									rank = (known and known.rank) or 0,
									incognito = incognito,
								})
							end

							if isPlayerBlacklisted and isPlayerBlacklisted(math.abs(n)) and not seenServerBl[idStr] then
								seenServerBl[idStr] = true
								local blRecord = blacklistedUsers[idStr]
								table.insert(blacklistList, {
									userId = math.abs(n),
									idStr = idStr,
									name = (blRecord and (blRecord.Name or blRecord.name)) or resolveName(idStr) or idStr,
									displayName = (blRecord and (blRecord.DisplayName or blRecord.displayName)) or resolveName(idStr) or idStr,
								})
							end
						end
					end
				end

				table.sort(staffList, function(a, b)
					if a.rank ~= b.rank then return a.rank > b.rank end
					return a.userId < b.userId
				end)
				table.sort(blacklistList, function(a, b)
					return a.userId < b.userId
				end)

				serverParsedCache[srv.Name] = {
					raw = raw,
					staff = staffList,
					spies = {},
					blacklist = blacklistList,
					total = total
				}
			end

			local info = getServerInfo(srv.Name)
			table.insert(results, {
				id = srv.Name,
				title = tostring(srv:GetAttribute("Title") or (info and info.name) or srv.Name),
				category = info and info.category or nil,
				serverType = info and info.serverType or nil,
				total = math.max(total, tonumber(srv:GetAttribute("TotalPlayers")) or 0),
				max = tonumber(srv:GetAttribute("MaxPlayers")) or 60,
				isCurrent = (currentId ~= "" and srv.Name == currentId),
				staff = staffList,
				spies = {},
				blacklist = blacklistList,
			})
		end

		table.sort(results, function(a, b)
			local aScore = (#a.blacklist * 100) + (#a.staff * 10)
			local bScore = (#b.blacklist * 100) + (#b.staff * 10)
			if aScore ~= bScore then return aScore > bScore end
			if a.total ~= b.total then return a.total > b.total end
			return a.title < b.title
		end)
		cachedScanResults = results
		return results
	end

	-- Teleport client to a specific server instance
	ADMIN_SYS.teleportToServer = function(serverId)
		if not serverId or serverId == "" then return end
		local idObj = ReplicatedStorage:FindFirstChild("ServerId")
		local currentId = (idObj and idObj:IsA("ValueBase")) and tostring(idObj.Value) or ""
		if serverId == currentId then
			print("ℹ️ [ASTROCYNA] Already in this server.")
			return
		end
		local TeleportService = game:GetService("TeleportService")
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, player)
		end)
	end

	-- Locate which server a blacklisted player is currently in (Non-blocking, cached)
	ADMIN_SYS.locateBlacklistedPlayer = function(targetUserId)
		local numId = tonumber(targetUserId)
		if not numId then return { status = "UNKNOWN" } end
		local idStr = tostring(numId)

		-- 1. Check current server
		local currentPlr = Players:GetPlayerByUserId(numId)
		if currentPlr then
			local idObj = ReplicatedStorage:FindFirstChild("ServerId")
			local currentId = (idObj and idObj:IsA("ValueBase")) and tostring(idObj.Value) or "Current"
			return {
				status = "CURRENT_SERVER",
				player = currentPlr,
				name = currentPlr.Name,
				displayName = currentPlr.DisplayName,
				serverId = currentId,
				serverTitle = "Current Server",
				isCurrent = true,
			}
		end

		-- 2. Scan ReplicatedStorage.Servers (Fast string pre-check before tokenizing)
		local serversFolder = ReplicatedStorage:FindFirstChild("Servers")
		if serversFolder then
			local idObj = ReplicatedStorage:FindFirstChild("ServerId")
			local currentId = (idObj and idObj:IsA("ValueBase")) and tostring(idObj.Value) or ""
			for _, srv in ipairs(serversFolder:GetChildren()) do
				local raw = srv:GetAttribute("Players")
				if type(raw) == "string" and raw ~= "" and string.find(raw, idStr, 1, true) then
					for token in string.gmatch(raw, "[^,]+") do
						local n = tonumber(token)
						if n and math.abs(n) == numId then
							local info = getServerInfo(srv.Name)
							local sTitle = tostring(srv:GetAttribute("Title") or (info and info.name) or srv.Name)
							local total = tonumber(srv:GetAttribute("TotalPlayers")) or 0
							local maxPlrs = tonumber(srv:GetAttribute("MaxPlayers")) or 60
							local isCurr = (currentId ~= "" and srv.Name == currentId)
							local blRecord = blacklistedUsers[idStr]
							return {
								status = isCurr and "CURRENT_SERVER" or "OTHER_SERVER",
								name = (blRecord and blRecord.name) or resolveName(idStr) or idStr,
								displayName = (blRecord and blRecord.displayName) or resolveName(idStr) or idStr,
								serverId = srv.Name,
								serverTitle = sTitle,
								total = total,
								max = maxPlrs,
								isCurrent = isCurr,
							}
						end
					end
				end
			end
		end

		-- 3. Check Cached Presence or fetch ASYNCHRONOUSLY without freezing the main thread
		local now = os.clock()
		local cached = presenceCache[idStr]
		if cached and (now - cached.time < 60) then
			return cached.data
		end

		if not presencePending[idStr] then
			presencePending[idStr] = true
			task.spawn(function()
				local pData = nil
				pcall(function()
					local reqFn = (syn and syn.request) or http_request or request or (http and http.request)
					if reqFn then
						local res = reqFn({
							Url = "https://presence.roproxy.com/v1/presence/users",
							Method = "POST",
							Headers = { ["Content-Type"] = "application/json" },
							Body = HttpService:JSONEncode({ userIds = { numId } })
						})
						if res and res.Body then
							local data = HttpService:JSONDecode(res.Body)
							if data and data.userPresences and data.userPresences[1] then
								pData = data.userPresences[1]
							end
					end
				end
			end)

				local blRecord = blacklistedUsers[idStr]
				local uName = (blRecord and blRecord.name) or resolveName(idStr) or idStr
				local finalRes = { status = "OFFLINE", name = uName }

				if pData then
					local pType = pData.userPresenceType
					if pType == 2 then
						local inThisGame = (pData.placeId == game.PlaceId)
						finalRes = {
							status = inThisGame and "OTHER_SERVER" or "OTHER_GAME",
							name = uName,
							serverId = pData.gameId or "",
							placeId = pData.placeId,
							serverTitle = pData.lastLocation or (inThisGame and "Prison RP Server" or "Different Game"),
							isCurrent = false,
						}
					elseif pType == 1 or pType == 3 then
						finalRes = { status = "ONLINE_WEBSITE", name = uName }
					end
				end

				presenceCache[idStr] = { data = finalRes, time = os.clock() }
				presencePending[idStr] = nil

				if ADMIN_SYS.refreshServerStaffGui then
					pcall(ADMIN_SYS.refreshServerStaffGui, false)
				end
			end)
		end

		if cached then
			return cached.data
		end

		local blRecord = blacklistedUsers[idStr]
		return { status = "OFFLINE", name = (blRecord and blRecord.name) or idStr }
	end

	-- Realtime Cross-Server Watchdog for Blacklist Movements
	local lastKnownBlacklistLocations = {}
	local function checkBlacklistServerChanges()
		if not blacklistedUsers or next(blacklistedUsers) == nil then return end
		local scan = ADMIN_SYS.scanServerStaff()
		if not scan then return end

		local currentFound = {}
		for _, e in ipairs(scan) do
			if e.blacklist and #e.blacklist > 0 then
				for _, b in ipairs(e.blacklist) do
					currentFound[b.idStr] = {
						serverId = e.id,
						serverTitle = e.title,
						total = e.total,
						max = e.max,
						isCurrent = e.isCurrent,
					}
				end
			end
		end

		for idStr, blRec in pairs(blacklistedUsers) do
			local loc = currentFound[idStr]
			local newServerId = loc and loc.serverId or "OFFLINE"
			local oldServerId = lastKnownBlacklistLocations[idStr]

			if oldServerId ~= nil and oldServerId ~= newServerId then
				if loc and not loc.isCurrent then
					local pName = blRec.displayName or blRec.name or ("ID " .. idStr)
					warn(string.format("⛔ [BLACKLIST MOVED] %s switched to %s (%d/%d)", pName, loc.serverTitle, loc.total, loc.max))
					if ADMIN_SYS.showBlacklistMoveBubble then
						ADMIN_SYS.showBlacklistMoveBubble(blRec, loc)
					end
				elseif loc and loc.isCurrent then
					local pName = blRec.displayName or blRec.name or ("ID " .. idStr)
					warn(string.format("🚨 [BLACKLIST ENTERED] %s has joined your current server!", pName))
				end
			end
			lastKnownBlacklistLocations[idStr] = newServerId
		end
	end

	trackThread(task.spawn(function()
		task.wait(3.0)
		while true do
			task.wait(6.0)
			pcall(checkBlacklistServerChanges)
		end
	end))

	-- Fake `GetRanked` answer for the game's own server list (staff-only UI). Only has an effect
	-- when this script runs before the game's Servers script calls the remote (e.g. auto-execute).
	local function buildRankTable()
		local t = {}
		for idStr, entry in pairs(ADMIN_SYS.serverStaffRoster) do
			t[idStr] = entry.rank or STAFF_MIN_RANK
		end
		t[tostring(player.UserId)] = 9999 -- highest rank => incognito staff are revealed to us
		return t
	end

	ADMIN_SYS.installServerBrowserHook = function()
		if env._AstrocynaServerBrowserHooked then return end
		env._AstrocynaServerBrowserHooked = true

		pcall(function()
			if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
			local oldNamecall
			local hookFn = function(self, ...)
				if checkcaller and checkcaller() then
					return oldNamecall(self, ...)
				end
				local method = getnamecallmethod()
				if method == "InvokeServer" and ADMIN_SYS.serverStaffRevealEnabled
					and typeof(self) == "Instance" and self.Name == "GetRanked" and self:IsA("RemoteFunction") then
					if not ADMIN_SYS.serverStaffRoster[tostring(player.UserId)] then
						return buildRankTable()
					end
				end
				return oldNamecall(self, ...)
			end
			oldNamecall = hookmetamethod(game, "__namecall", toCClosure(hookFn))
		end)
	end

	-- Live decoration of the game's own server list (cards already built before this script ran).
	local function findNativeScroll()
		if nativeScroll and nativeScroll.Parent then return nativeScroll end
		nativeScroll = nil
		local pg = player:FindFirstChild("PlayerGui")
		if not pg then return nil end

		local mainGui = pg:FindFirstChild("MainGui")
		local center = mainGui and mainGui:FindFirstChild("Center")
		local servers = center and center:FindFirstChild("Servers")
		if servers then
			local scroll = servers:FindFirstChild("Scroll")
			if scroll and scroll:FindFirstChild("Template") then
				nativeScroll = scroll
				return nativeScroll
			end
		end

		local directServers = pg:FindFirstChild("Servers")
		if directServers and directServers:IsA("GuiObject") then
			local scroll = directServers:FindFirstChild("Scroll")
			if scroll and scroll:FindFirstChild("Template") then
				nativeScroll = scroll
				return nativeScroll
			end
		end
		return nil
	end

	local function decorateCard(card, entry)
		local users = card:FindFirstChild("Users")
		if not users then return end

		local staffCount = #entry.staff

		-- Fast Hash Check: Avoid recreating strokes and avatar thumbnails if server roster is unchanged
		local hashParts = { tostring(staffCount) }
		for _, s in ipairs(entry.staff) do
			table.insert(hashParts, s.idStr .. (s.incognito and ":i" or ""))
		end
		local cardHash = table.concat(hashParts, ",")
		if card:GetAttribute("AstrocynaDecorHash") == cardHash then
			return
		end
		card:SetAttribute("AstrocynaDecorHash", cardHash)

		local staffById = {}
		for _, s in ipairs(entry.staff) do staffById[s.idStr] = s end

		local present = {}
		for _, child in ipairs(users:GetChildren()) do
			if child:IsA("ImageLabel") and child.Name ~= "Template" then
				if staffById[child.Name] then
					present[child.Name] = true
					local stroke = child:FindFirstChild("Stroke")
					if not stroke or not stroke:IsA("UIStroke") then
						pcall(function() if stroke then stroke:Destroy() end end)
						stroke = Instance.new("UIStroke")
						stroke.Name = "Stroke"
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Thickness = 2
						stroke.Transparency = 0
						stroke.Parent = child
					end
					stroke.Enabled = true
					stroke.Color = STAFF_RED
					if staffById[child.Name].incognito then
						child.ImageColor3 = Color3.new(0, 0, 0)
					end
				elseif child:GetAttribute("AstrocynaStaff") or child:GetAttribute("AstrocynaSpy") then
					child:Destroy()
				end
			end
		end

		-- Staff the game hid (incognito) or cut off (only 9 avatars are shown per card)
		local template = users:FindFirstChild("Template")
		if template and template:IsA("ImageLabel") and #entry.staff > 0 then
			local added = 0
			for _, s in ipairs(entry.staff) do
				if not present[s.idStr] and added < 3 then
					local clone = template:Clone()
					clone.Name = s.idStr
					clone.Image = "rbxthumb://type=AvatarHeadShot&id=" .. s.idStr .. "&w=48&h=48"
					clone.LayoutOrder = -1000 + added
					clone.Visible = true
					clone:SetAttribute("AstrocynaStaff", true)
					if s.incognito then clone.ImageColor3 = Color3.new(0, 0, 0) end
					local stroke = clone:FindFirstChild("Stroke")
					if not stroke or not stroke:IsA("UIStroke") then
						pcall(function() if stroke then stroke:Destroy() end end)
						stroke = Instance.new("UIStroke")
						stroke.Name = "Stroke"
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Thickness = 2
						stroke.Transparency = 0
						stroke.Parent = clone
					end
					stroke.Enabled = true
					stroke.Color = STAFF_RED
					clone.Parent = users
					added = added + 1
				end
			end
		end
		if #entry.staff > 0 then users.Visible = true end

		local summary = card:FindFirstChild("Summary")
		local staffLbl = summary and summary:FindFirstChild("Staff")
		if staffLbl then
			staffLbl.Visible = #entry.staff > 0
			local val = staffLbl:FindFirstChild("Value")
			if val and val:IsA("TextLabel") then
				val.Text = string.format("%d Staff", #entry.staff)
			end
			if #entry.staff > 0 then
				summary.Visible = true
				local sep = card:FindFirstChild("Separator")
				if sep then sep.Visible = true end
			end
		end

		local spyLbl = summary and summary:FindFirstChild("Spy")
		if spyLbl then
			pcall(function() spyLbl:Destroy() end)
		end
	end

	ADMIN_SYS.decorateNativeServerList = function()
		if not ADMIN_SYS.serverStaffRevealEnabled then return end
		local scroll = findNativeScroll()
		if not scroll or not scroll.Parent then return end
		if scroll.Parent:IsA("GuiObject") and not scroll.Parent.Visible then return end

		-- Also decorate the Colors legend with Staff dot
		local colorsFrame = (scroll.Parent and scroll.Parent:FindFirstChild("Colors"))
			or (scroll.Parent and scroll.Parent.Parent and scroll.Parent.Parent:FindFirstChild("Colors"))
		if colorsFrame then
			local staffLegend = colorsFrame:FindFirstChild("Staff")
			if staffLegend then staffLegend.Visible = true end
		end

		local byId = {}
		for _, e in ipairs(ADMIN_SYS.scanServerStaff()) do byId[e.id] = e end
		for _, card in ipairs(scroll:GetChildren()) do
			if card:IsA("GuiObject") and card.Name ~= "Template" then
				local entry = byId[card.Name]
				if entry then pcall(decorateCard, card, entry) end
			end
		end
	end

	ADMIN_SYS.clearNativeStaffMarks = function()
		local scroll = findNativeScroll()
		if not scroll or not scroll.Parent then return end

		-- 1. Reset Colors legend frame
		local colorsFrame = (scroll.Parent and scroll.Parent:FindFirstChild("Colors"))
			or (scroll.Parent and scroll.Parent.Parent and scroll.Parent.Parent:FindFirstChild("Colors"))
		if colorsFrame then
			local spyLegend = colorsFrame:FindFirstChild("Spy")
			if spyLegend then
				pcall(function() spyLegend:Destroy() end)
			end
			local staffLegend = colorsFrame:FindFirstChild("Staff")
			if staffLegend then
				staffLegend.Visible = false
			end
		end

		-- 2. Clear all staff / spy displays on each card
		for _, card in ipairs(scroll:GetChildren()) do
			if card:IsA("GuiObject") and card.Name ~= "Template" then
				card:SetAttribute("AstrocynaDecorHash", nil)

				local users = card:FindFirstChild("Users")
				if users then
					local hasNativeAvatars = false
					for _, child in ipairs(users:GetChildren()) do
						if child:IsA("ImageLabel") and child.Name ~= "Template" then
							if child:GetAttribute("AstrocynaStaff") or child:GetAttribute("AstrocynaSpy") then
								pcall(function() child:Destroy() end)
							else
								hasNativeAvatars = true
								local stroke = child:FindFirstChild("Stroke")
								if stroke and stroke:IsA("UIStroke") then
									if stroke.Color == STAFF_RED or stroke.Color == Color3.fromRGB(0, 215, 255) then
										pcall(function() stroke:Destroy() end)
									end
								end
								if child.ImageColor3 == Color3.new(0, 0, 0) then
									child.ImageColor3 = Color3.new(1, 1, 1)
								end
							end
						end
					end
					if not hasNativeAvatars then
						users.Visible = false
					end
				end

				local summary = card:FindFirstChild("Summary")
				if summary then
					local spyLbl = summary:FindFirstChild("Spy")
					if spyLbl then
						pcall(function() spyLbl:Destroy() end)
					end
					local staffLbl = summary:FindFirstChild("Staff")
					if staffLbl then
						staffLbl.Visible = false
					end

					local friendsLbl = summary:FindFirstChild("Friends")
					local compatLbl = summary:FindFirstChild("Compatibility")
					local friendsVis = (friendsLbl and friendsLbl.Visible) or false
					local compatVis = (compatLbl and compatLbl.Visible) or false
					local nativeSummaryVisible = friendsVis or compatVis

					summary.Visible = nativeSummaryVisible
					local sep = card:FindFirstChild("Separator")
					if sep then
						sep.Visible = nativeSummaryVisible
					end
				end
			end
		end
	end

	-- Real-Time Staff Radar: Continuously scans current server players, group staff roster,
	-- incognito staff in ReplicatedStorage.Servers, and native Remotes.Admin.ModLists.
	ADMIN_SYS.updateStaffRadar = function()
		if not ADMIN_SYS.isStaffRadarEnabled then return end
		pcall(function()
			local adminCount = 0

			-- 1. Scan players in current server against official Staff Roster
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player then
					local uidStr = tostring(plr.UserId)
					local known = lookupStaff(uidStr)
					if known then
						adminCount = adminCount + 1
						if not alertedStaffJoins[plr.UserId] then
							alertedStaffJoins[plr.UserId] = true
							local timeStr = os.date("%H:%M:%S")
							pcall(function()
								ADMIN_SYS.showStaffAlertBanner(plr, known.role or "Staff", known.rank or 200)
								if ADMIN_SYS.showAdminJoinBubble then
									ADMIN_SYS.showAdminJoinBubble(plr, known.role or "Staff", known.rank or 200, timeStr, adminCount)
								end
							end)
						end
					end
				end
			end

			-- 2. Real-Time Scan of ReplicatedStorage.Servers for Current Server's Incognito / Hidden Staff
			local serversFolder = ReplicatedStorage:FindFirstChild("Servers")
			local idObj = ReplicatedStorage:FindFirstChild("ServerId")
			local currentId = (idObj and idObj:IsA("ValueBase")) and tostring(idObj.Value) or ""
			local lpIdStr = tostring(player.UserId)

			if serversFolder then
				for _, srv in ipairs(serversFolder:GetChildren()) do
					local raw = srv:GetAttribute("Players")
					local isCurrent = (srv.Name == currentId) or (srv:GetAttribute("IsCurrent") == true)
					if not isCurrent and type(raw) == "string" and raw ~= "" then
						for token in string.gmatch(raw, "[^,]+") do
							if token == lpIdStr or token == ("-" .. lpIdStr) then
								isCurrent = true
								break
							end
						end
					end

					if isCurrent and type(raw) == "string" and raw ~= "" then
						for token in string.gmatch(raw, "[^,]+") do
							local n = tonumber(token)
							if n and math.abs(n) ~= player.UserId then
								local incognito = n < 0
								local staffUid = math.abs(n)
								local staffUidStr = tostring(staffUid)
								local known = lookupStaff(staffUidStr)

								if incognito or known then
									local foundPlr = Players:GetPlayerByUserId(staffUid)
									local staffName = (known and known.name) or resolveName(staffUidStr) or (foundPlr and foundPlr.Name) or ("ID " .. staffUidStr)
									local staffRole = (known and known.role) or (incognito and "Incognito Staff" or "Staff")
									local staffRank = (known and known.rank) or (incognito and 999 or 200)

									if not alertedStaffJoins[staffUid] then
										alertedStaffJoins[staffUid] = true
										adminCount = adminCount + 1
										local timeStr = os.date("%H:%M:%S")
										local mockOrReal = foundPlr or {
											Name = staffName,
											DisplayName = (known and known.display) or staffName,
											UserId = staffUid
										}
										pcall(function()
											ADMIN_SYS.showStaffAlertBanner(mockOrReal, staffRole, staffRank)
											if ADMIN_SYS.showAdminJoinBubble then
												ADMIN_SYS.showAdminJoinBubble(mockOrReal, staffRole, staffRank, timeStr, adminCount)
											end
										end)
									end
								end
							end
						end
					end
				end
			end

			-- 3. Fallback: Remotes.Admin.ModLists
			local rem = ReplicatedStorage:FindFirstChild("Remotes")
			local adminDir = rem and rem:FindFirstChild("Admin")
			local modFunc = adminDir and adminDir:FindFirstChild("ModLists")
			if modFunc and modFunc:IsA("RemoteFunction") then
				local res = modFunc:InvokeServer()
				if type(res) == "table" then
					for _, staffItem in ipairs(res) do
						local sName = type(staffItem) == "table" and (staffItem.Name or staffItem.name) or tostring(staffItem)
						if sName and sName ~= "" then
							local foundPlr = Players:FindFirstChild(sName)
							if foundPlr and not alertedStaffJoins[foundPlr.UserId] then
								alertedStaffJoins[foundPlr.UserId] = true
								adminCount = adminCount + 1
								local timeStr = os.date("%H:%M:%S")
								pcall(function()
									ADMIN_SYS.showStaffAlertBanner(foundPlr, "Moderator", 100)
									if ADMIN_SYS.showAdminJoinBubble then
										ADMIN_SYS.showAdminJoinBubble(foundPlr, "Moderator", 100, timeStr, adminCount)
									end
								end)
							end
						end
					end
				end
			end
		end)
	end

	-- Real-time Background Engine: Hooks ReplicatedStorage.Servers attribute changes so Server Staff
	-- and Staff Radar stay 100% updated in real-time even when Server Staff UI is closed.
	local function startServerStaffBackgroundEngine()
		local serversFolder = ReplicatedStorage:FindFirstChild("Servers")
		if not serversFolder then return end

		local function onServerChanged(srv)
			if not srv or not srv:IsA("Instance") then return end
			pcall(function()
				if serverParsedCache then serverParsedCache[srv.Name] = nil end
				pcall(ADMIN_SYS.updateStaffRadar)
				pcall(checkBlacklistServerChanges)
				pcall(ADMIN_SYS.decorateNativeServerList)
				if ADMIN_SYS.serverStaffWindow and ADMIN_SYS.serverStaffWindow.Visible then
					pcall(ADMIN_SYS.refreshServerStaffGui, false)
				end
			end)
		end

		local function hookServer(srv)
			if not srv:IsA("Instance") then return end
			trackConnection(srv:GetAttributeChangedSignal("Players"):Connect(function()
				onServerChanged(srv)
			end))
			trackConnection(srv:GetAttributeChangedSignal("TotalPlayers"):Connect(function()
				onServerChanged(srv)
			end))
		end

		for _, srv in ipairs(serversFolder:GetChildren()) do
			hookServer(srv)
		end

		trackConnection(serversFolder.ChildAdded:Connect(function(child)
			hookServer(child)
			onServerChanged(child)
		end))
		trackConnection(serversFolder.ChildRemoved:Connect(function(child)
			if serverParsedCache then serverParsedCache[child.Name] = nil end
			pcall(ADMIN_SYS.updateStaffRadar)
			pcall(checkBlacklistServerChanges)
			pcall(ADMIN_SYS.decorateNativeServerList)
			if ADMIN_SYS.serverStaffWindow and ADMIN_SYS.serverStaffWindow.Visible then
				pcall(ADMIN_SYS.refreshServerStaffGui, false)
			end
		end))
	end

	trackThread(task.spawn(startServerStaffBackgroundEngine))

	ADMIN_SYS.installServerBrowserHook()
end

local function unblacklistUserId(userId)
	local idStr = tostring(userId)
	local numId = tonumber(idStr)
	local removed = false
	local rec = blacklistedUsers[idStr] or (numId and blacklistedUsers[numId])
	if blacklistedUsers[idStr] ~= nil then
		blacklistedUsers[idStr] = nil
		removed = true
	end
	if numId and blacklistedUsers[numId] ~= nil then
		blacklistedUsers[numId] = nil
		removed = true
	end
	if removed then
		saveBlacklist()
		local finalName = rec and (rec.Name or rec.name) or idStr
		local finalDisp = rec and (rec.DisplayName or rec.displayName or finalName) or idStr
		print(string.format("✅ [ASTROCYNA] Blacklist Removed: %s (@%s) [ID: %s]", finalDisp, finalName, idStr))
		pcall(function()
			local plr = Players:GetPlayerByUserId(numId or 0)
			onBlacklistChanged:Fire(plr or { UserId = numId or 0, Name = finalName, DisplayName = finalDisp }, false)
		end)
		if ADMIN_SYS.refreshServerStaffGui then
			pcall(ADMIN_SYS.refreshServerStaffGui)
		end
		return true
	end
	return false
end
ADMIN_SYS.unblacklistUserId = unblacklistUserId

ADMIN_SYS.getBlacklistedUsers = function()
	local clean = {}
	for k, v in pairs(blacklistedUsers) do
		local idStr = tostring(k)
		if tonumber(idStr) and type(v) == "table" and not clean[idStr] then
			clean[idStr] = {
				Name = v.Name or v.name or idStr,
				DisplayName = v.DisplayName or v.displayName or v.Name or v.name or idStr,
				AddedAt = v.AddedAt or v.addedAt or os.time(),
			}
		end
	end
	return clean
end

local function blacklistUser(userId, username, displayName)
	local idStr = tostring(userId)
	local numId = tonumber(idStr)
	if numId then
		blacklistedUsers[numId] = nil
	end
	local finalName = username or idStr
	local finalDisp = displayName or finalName
	blacklistedUsers[idStr] = {
		Name = finalName,
		DisplayName = finalDisp,
		AddedAt = os.time(),
	}
	saveBlacklist()
	warn(string.format("⛔ [ASTROCYNA] Player Blacklisted: %s (@%s) [ID: %s]", finalDisp, finalName, idStr))
	pcall(function()
		local plr = Players:GetPlayerByUserId(numId or 0)
		onBlacklistChanged:Fire(plr or { UserId = numId or 0, Name = finalName, DisplayName = finalDisp }, true)
	end)
	if ADMIN_SYS.refreshServerStaffGui then
		pcall(ADMIN_SYS.refreshServerStaffGui)
	end
	return true
end
ADMIN_SYS.blacklistUser = blacklistUser

local function toggleBlacklistPlayer(plr)
	local idStr = tostring(plr.UserId)
	local isNowBlacklisted = false
	if blacklistedUsers[idStr] then
		unblacklistUserId(idStr)
		isNowBlacklisted = false
	else
		blacklistUser(plr.UserId, plr.Name, plr.DisplayName)
		isNowBlacklisted = true
	end
	return isNowBlacklisted
end
ADMIN_SYS.toggleBlacklistPlayer = toggleBlacklistPlayer

loadBlacklist()
local createEspForPlayer = nil

getPlayerChar = function(plr)
	if plr.Character and plr.Character.Parent then
		return plr.Character
	end
	local wsPlayers = workspace:FindFirstChild("Players")
	if wsPlayers then
		local found = wsPlayers:FindFirstChild(plr.Name)
		if found and found:IsA("Model") then
			return found
		end
	end
	return nil
end

checkPlayerStaff = function(plr)
	if staffCache[plr.UserId] ~= nil then
		return staffCache[plr.UserId].isStaff, staffCache[plr.UserId].role, staffCache[plr.UserId].rank
	end

	local uidStr = tostring(plr.UserId)
	local knownRoster = ADMIN_SYS.serverStaffRoster and ADMIN_SYS.serverStaffRoster[uidStr]
	if knownRoster then
		staffCache[plr.UserId] = {
			isStaff = true,
			role = knownRoster.role or "Staff",
			rank = knownRoster.rank or 200,
		}
	else
		staffCache[plr.UserId] = { isStaff = false, role = "Player", rank = 0 }
	end

	task.spawn(function()
		local roleName = knownRoster and knownRoster.role or "Player"
		local rank = knownRoster and knownRoster.rank or 0
		local isStaff = knownRoster ~= nil

		local success = pcall(function()
			local gRole = plr:GetRoleInGroup(GAME_GROUP_ID)
			local gRank = plr:GetRankInGroup(GAME_GROUP_ID)
			if (gRank < 200) and SECONDARY_GROUP_ID then
				local sRank = plr:GetRankInGroup(SECONDARY_GROUP_ID)
				if sRank and sRank >= 200 then
					gRank = sRank
					gRole = plr:GetRoleInGroup(SECONDARY_GROUP_ID)
				end
			end
			if gRole and gRank then
				roleName = gRole
				rank = gRank
			end
		end)

		if success and roleName then
			local rLower = string.lower(roleName)
			if rank >= 200 or
			   string.find(rLower, "staff") or
			   string.find(rLower, "mod") or
			   string.find(rLower, "admin") or
			   string.find(rLower, "dev") or
			   string.find(rLower, "owner") or
			   string.find(rLower, "founder") then
				isStaff = true
			end
		end

		staffCache[plr.UserId] = {
			isStaff = isStaff,
			role = roleName or "Player",
			rank = rank or 0
		}

		if isStaff then
			print(string.format("🚨 [ASTROCYNA ESP] Staff Detected (Exempt from all detection): %s (@%s) | ยศ: %s (Rank: %d)", plr.DisplayName, plr.Name, roleName, rank))
			local uidStr = tostring(plr.UserId)
			-- 1. Purge from Game Incidents
			if hackerDetectedUsers[uidStr] then
				hackerDetectedUsers[uidStr] = nil
				saveHackerList()
				requestRefreshHackerList()
			end
			-- 2. Purge from Anti-Cheat & Exploit Detector
			if ADMIN_SYS and ADMIN_SYS.cheatDetectedUsers and ADMIN_SYS.cheatDetectedUsers[uidStr] then
				ADMIN_SYS.cheatDetectedUsers[uidStr] = nil
				if ADMIN_SYS.saveCheatList then pcall(ADMIN_SYS.saveCheatList) end
				if ADMIN_SYS.requestRefreshCheatList then ADMIN_SYS.requestRefreshCheatList() end
			end
			-- 3. Clear motion tracking history
			if ADMIN_SYS and ADMIN_SYS.EXECUTOR_DETECTOR and ADMIN_SYS.EXECUTOR_DETECTOR.motionHistory then
				ADMIN_SYS.EXECUTOR_DETECTOR.motionHistory[plr.UserId] = nil
			end
			-- 4. Dismiss active exploit alert bubble if it was showing this staff member
			if ADMIN_SYS and ADMIN_SYS.dismissExpBubble and ADMIN_SYS.expTargetPlr == plr then
				pcall(ADMIN_SYS.dismissExpBubble)
			end
			if plr ~= player and not alertedStaffJoins[plr.UserId] then
				alertedStaffJoins[plr.UserId] = true
				task.spawn(function()
					task.wait(0.2)
					local adminCount = 0
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= player and isStaffOrAdmin(p) then
							adminCount = adminCount + 1
						end
					end
					if adminCount == 0 then adminCount = 1 end
					local timeStr = os.date("%H:%M:%S")
					if ADMIN_SYS and type(ADMIN_SYS.showAdminJoinBubble) == "function" then
						pcall(function()
							ADMIN_SYS.showAdminJoinBubble(plr, roleName, rank, timeStr, adminCount)
						end)
					end
					if ADMIN_SYS and type(ADMIN_SYS.showStaffAlertBanner) == "function" then
						pcall(function()
							ADMIN_SYS.showStaffAlertBanner(plr, roleName, rank)
						end)
					end
				end)
			end
		end

		pcall(function()
			onStaffDetected:Fire(plr, isStaff, roleName, rank)
		end)

		if isEspEnabled and espDatabase[plr] then
			task.defer(function()
				if getPlayerChar(plr) and createEspForPlayer then
					createEspForPlayer(plr)
				end
			end)
		end
	end)

	return false, "Player", 0
end

local espVisualsConn = nil

local function getToolIcon(toolName)
	local tLow = string.lower(toolName)
	if string.find(tLow, "gun") or string.find(tLow, "pistol") or string.find(tLow, "rifle") or string.find(tLow, "shotgun") or string.find(tLow, "m4") or string.find(tLow, "mp5") or string.find(tLow, "ak") or string.find(tLow, "taser") or string.find(tLow, "revolver") then
		return "🔫"
	elseif string.find(tLow, "knife") or string.find(tLow, "machete") or string.find(tLow, "blade") or string.find(tLow, "sword") or string.find(tLow, "bat") or string.find(tLow, "pipe") or string.find(tLow, "axe") or string.find(tLow, "hatchet") or string.find(tLow, "pickaxe") or string.find(tLow, "shank") then
		return "🗡️"
	elseif string.find(tLow, "cuff") or string.find(tLow, "shield") or string.find(tLow, "spray") or string.find(tLow, "vest") then
		return "🛡️"
	elseif string.find(tLow, "key") or string.find(tLow, "card") or string.find(tLow, "lockpick") or string.find(tLow, "bomb") or string.find(tLow, "c4") then
		return "⚠️"
	else
		return "📦"
	end
end

local function getStaffEspColor(plr)
	local isBl = isPlayerBlacklisted(plr.UserId)
	if isBl then
		return Color3.fromRGB(255, 30, 45)
	end

	local isStaff = checkPlayerStaff(plr)
	if isStaff then
		return Color3.fromRGB(255, 55, 85)
	end

	local isWanted = ADMIN_SYS and ADMIN_SYS.isPlayerWanted and ADMIN_SYS.isPlayerWanted(plr)
	if isWanted then
		return Color3.fromRGB(255, 140, 20)
	end

	if plr.Team then
		local tName = plr.Team.Name
		if string.find(tName, "Guard") or string.find(tName, "Police") or string.find(tName, "Enforcement") or string.find(tName, "Warden") or string.find(tName, "Security") then
			return Color3.fromRGB(0, 165, 255)
		elseif string.find(tName, "Inmate") or string.find(tName, "Prisoner") or string.find(tName, "Criminal") then
			return Color3.fromRGB(255, 195, 45)
		end
	end

	return plr.TeamColor and plr.TeamColor.Color or Color3.fromRGB(0, 255, 200)
end

local function applyStaffNametagEsp(targetPlr, enable)
	if targetPlr == player then return end
	local wsVisuals = workspace:FindFirstChild("Visuals")
	if not wsVisuals then return end

	local char = getPlayerChar(targetPlr)
	local cName = char and char.Name or targetPlr.Name

	local vPart = wsVisuals:FindFirstChild(cName)
		or wsVisuals:FindFirstChild(targetPlr.Name)
		or wsVisuals:FindFirstChild(targetPlr.DisplayName)
		or wsVisuals:FindFirstChild(tostring(targetPlr.UserId))

	if not vPart then return end

	local sg = vPart:FindFirstChildOfClass("SurfaceGui")
	if not sg then return end

	if enable then
		-- Disable the 3D-scaling SurfaceGui so our Fixed-Size BillboardGui handles nametags exclusively
		if not sg:GetAttribute("StaffEspOriginalAOT") then
			sg:SetAttribute("StaffEspOriginalAOT", sg.AlwaysOnTop and "true" or "false")
		end
		sg.AlwaysOnTop = false
		sg.Enabled = false
	else
		local orig = sg:GetAttribute("StaffEspOriginalAOT")
		if orig ~= nil then
			sg.AlwaysOnTop = (orig == "true")
			sg:SetAttribute("StaffEspOriginalAOT", nil)
		else
			sg.AlwaysOnTop = false
		end
		sg.MaxDistance = 40
		sg.LightInfluence = 1
	end
end

local function removeEspForPlayer(plr)
	if espDatabase[plr] then
		if espDatabase[plr].Highlight then
			pcall(function() espDatabase[plr].Highlight:Destroy() end)
		end
		if espDatabase[plr].Gui then
			pcall(function() espDatabase[plr].Gui:Destroy() end)
		end
		if espDatabase[plr].TagTop then
			pcall(function() espDatabase[plr].TagTop:Destroy() end)
		end
		if espDatabase[plr].TagLeft then
			pcall(function() espDatabase[plr].TagLeft:Destroy() end)
		end
		if espDatabase[plr].TagRight then
			pcall(function() espDatabase[plr].TagRight:Destroy() end)
		end
		if espDatabase[plr].TagBottom then
			pcall(function() espDatabase[plr].TagBottom:Destroy() end)
		end
		if espDatabase[plr].Connections then
			for _, conn in ipairs(espDatabase[plr].Connections) do
				pcall(function() conn:Disconnect() end)
			end
		end
		espDatabase[plr] = nil
	end
	pcall(function()
		applyStaffNametagEsp(plr, false)
	end)
end

-- Comprehensive Health Synchronization & Tracking for Prison RP
local playerHealthCache = {}
local lastHealthQueryTime = {}

local function queryPlayerBody(targetPlr)
	if not targetPlr or not targetPlr.Parent then return end
	local now = os.clock()
	if lastHealthQueryTime[targetPlr] and (now - lastHealthQueryTime[targetPlr] < 1.0) then
		return
	end
	lastHealthQueryTime[targetPlr] = now

	task.spawn(function()
		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		local hFolder = rem and rem:FindFirstChild("Health")
		local bq = hFolder and hFolder:FindFirstChild("BodyQueryFunction")
		if not bq then return end

		local ok, res = pcall(function()
			return bq:InvokeServer(targetPlr)
		end)
		if ok and typeof(res) == "table" then
			local avgBlood = nil
			if typeof(res.Limbs) == "table" then
				local totalBlood = 0
				local count = 0
				for _, limbData in pairs(res.Limbs) do
					if typeof(limbData) == "table" and typeof(limbData.BloodQuantity) == "number" then
						totalBlood = totalBlood + limbData.BloodQuantity
						count = count + 1
					end
				end
				if count > 0 then
					avgBlood = totalBlood / count
				end
			end
			local bh = typeof(res.BodyHealth) == "number" and res.BodyHealth or nil
			playerHealthCache[targetPlr] = {
				AvgBlood = avgBlood,
				BodyHealth = bh,
				LastUpdate = os.clock()
			}
		end
	end)
end

-- Listen to native limb broadcast event to instantly refresh health cache when any player gets injured/healed
task.spawn(function()
	local rem = ReplicatedStorage:FindFirstChild("Remotes")
	local hFolder = rem and rem:FindFirstChild("Health")
	local lbe = hFolder and hFolder:FindFirstChild("LimbBroadcastEvent")
	if lbe then
		lbe.OnClientEvent:Connect(function(targetPlr)
			if typeof(targetPlr) == "Instance" and targetPlr:IsA("Player") then
				queryPlayerBody(targetPlr)
			end
		end)
	end
end)

local function getLivePlayerHealth(targetPlr, targetChar)
	if not targetChar then return 0, 100, false end

	local liveHum = targetChar:FindFirstChildOfClass("Humanoid")

	-- 1. Check if Dead or Downed / KO
	local isDowned = (targetChar:GetAttribute("Downed") == true)
		or (targetChar:GetAttribute("Lying") == true)
		or (targetChar:GetAttribute("Ragdolled") == true and targetChar:GetAttribute("DownReason") ~= nil)
		or (liveHum and liveHum.Health <= 0)

	if isDowned then
		return 0, 100, true
	end

	-- 2. Max HP resolution
	local maxHp = 100
	local rawMax = (targetPlr and targetPlr:GetAttribute("MaxHealth"))
		or targetChar:GetAttribute("MaxHealth")
		or (liveHum and liveHum:GetAttribute("MaxHealth"))
	if typeof(rawMax) == "number" and rawMax > 0 then
		maxHp = rawMax
	elseif liveHum and liveHum.MaxHealth and liveHum.MaxHealth > 0 then
		maxHp = liveHum.MaxHealth
	end

	-- 3. Gather candidate HP values from all available game sources
	local candidates = {}

	-- A. BodyHealth attribute (Primary Prison RP stat from Boxing/Fists/Combat)
	local bhPlr = targetPlr and targetPlr:GetAttribute("BodyHealth")
	if typeof(bhPlr) == "number" then table.insert(candidates, bhPlr) end
	local bhChar = targetChar:GetAttribute("BodyHealth")
	if typeof(bhChar) == "number" then table.insert(candidates, bhChar) end
	local bhHum = liveHum and liveHum:GetAttribute("BodyHealth")
	if typeof(bhHum) == "number" then table.insert(candidates, bhHum) end

	-- B. Health attribute
	local hPlr = targetPlr and targetPlr:GetAttribute("Health")
	if typeof(hPlr) == "number" then table.insert(candidates, hPlr) end
	local hChar = targetChar:GetAttribute("Health")
	if typeof(hChar) == "number" then table.insert(candidates, hChar) end
	local hHum = liveHum and liveHum:GetAttribute("Health")
	if typeof(hHum) == "number" then table.insert(candidates, hHum) end

	-- C. Standard Roblox Humanoid.Health (Guns / Fall Damage)
	if liveHum and typeof(liveHum.Health) == "number" then
		local normHumHp = (liveHum.Health / math.max(liveHum.MaxHealth, 1)) * maxHp
		table.insert(candidates, normHumHp)
	end

	-- D. Cached Remote / Limb Health (from BodyQueryFunction / LimbBroadcastEvent)
	local cached = playerHealthCache[targetPlr]
	if cached then
		if typeof(cached.BodyHealth) == "number" then
			table.insert(candidates, cached.BodyHealth)
		end
		if typeof(cached.AvgBlood) == "number" then
			table.insert(candidates, cached.AvgBlood)
		end
	end

	-- E. HealthTier estimation (Trauma / Injury tiers 1, 2, 3)
	local rawTier = targetChar:GetAttribute("HealthTier") or (targetPlr and targetPlr:GetAttribute("HealthTier"))
	local tierNum = tonumber(rawTier)
	if tierNum and tierNum > 0 then
		local tierCap = (tierNum == 1 and 80) or (tierNum == 2 and 55) or 30
		table.insert(candidates, tierCap)
	end

	if #candidates == 0 then
		return maxHp, maxHp, false
	end

	-- Find the lowest valid health value (reflecting any active damage / blood loss)
	local minHp = maxHp
	for _, val in ipairs(candidates) do
		if val < minHp then
			minHp = val
		end
	end

	return math.max(0, math.ceil(minHp)), maxHp, false
end

local function isPlayerInvisible(targetPlr, targetChar)
	if not targetChar then return false end

	-- 1. Game attributes for actual physical invisibility mode
	if targetChar:GetAttribute("Invisible") == true then return true end
	if targetPlr and targetPlr:GetAttribute("Invisible") == true then return true end
	if targetChar:GetAttribute("Vanish") == true or (targetPlr and targetPlr:GetAttribute("Vanish") == true) then return true end

	-- 2. Character visual transparency check (Head & Torso fully transparent from invisibility mode)
	local head = targetChar:FindFirstChild("Head")
	local torso = targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
	if head and torso and head:IsA("BasePart") and torso:IsA("BasePart") then
		if head.Transparency >= 0.9 and torso.Transparency >= 0.9 then
			return true
		end
	end

	return false
end

local isPlayerIncognito
do
	local cachedServerNegativeUids = {}
	local lastServerPlayersRaw = nil

	isPlayerIncognito = function(targetPlr, targetChar)
	if targetPlr then
		if targetPlr:GetAttribute("Incognito") == true or targetPlr:GetAttribute("incognito") == true then
			return true
		end
	end
	if targetChar then
		if targetChar:GetAttribute("Incognito") == true or targetChar:GetAttribute("incognito") == true then
			return true
		end
	end
	if targetPlr then
		local currentServer = game.JobId ~= "" and ReplicatedStorage:FindFirstChild("Servers") and ReplicatedStorage.Servers:FindFirstChild(game.JobId)
		if currentServer then
			local raw = currentServer:GetAttribute("Players")
			if type(raw) == "string" and raw ~= "" then
				if raw ~= lastServerPlayersRaw then
					lastServerPlayersRaw = raw
					table.clear(cachedServerNegativeUids)
					for token in string.gmatch(raw, "[^,]+") do
						if string.sub(token, 1, 1) == "-" then
							local uid = tonumber(string.sub(token, 2))
							if uid then
								cachedServerNegativeUids[uid] = true
							end
						end
					end
				end
				if cachedServerNegativeUids[targetPlr.UserId] then
					return true
				end
			end
		end
	end
	return false
	end
end

local function getStaffStatusTag(isInvis, isIncog)
	if isInvis and isIncog then
		return ' <font color="#c896ff"><b>[INCOGNITO]</b></font> <font color="#ffffff"><b>[กำลังหายตัวอยู่]</b></font>'
	elseif isInvis then
		return ' <font color="#ffffff"><b>[กำลังหายตัวอยู่]</b></font>'
	elseif isIncog then
		return ' <font color="#c896ff"><b>[INCOGNITO]</b></font>'
	end
	return ""
end

createEspForPlayer = function(plr)
	if plr == player then return end
	if not isEspEnabled then return end

	local char = getPlayerChar(plr)
	if not char then return end

	removeEspForPlayer(plr)

	local connections = {}
	local color = getStaffEspColor(plr)
	local isInvisInit = isPlayerInvisible(plr, char)
	local isIncogInit = isPlayerIncognito(plr, char)
	local lastInvisState = isInvisInit
	local lastIncogState = isIncogInit

	-- 1. Native Character Highlight (ESP Body)
	-- If staff is invisible, body ESP turns white while nametag preserves original staff/role colors
	local hl = Instance.new("Highlight")
	hl.Name = plr.Name .. "_StaffESP"
	hl.Adornee = char
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = isInvisInit and Color3.fromRGB(255, 255, 255) or color
	hl.FillTransparency = 1
	hl.OutlineColor = isInvisInit and Color3.fromRGB(255, 255, 255) or color
	hl.OutlineTransparency = isInvisInit and 0 or 0.05
	hl.Enabled = true
	hl.Parent = espFolder or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or player:WaitForChild("PlayerGui"))

	-- 2. Hook In-Game 3D Nametag Wallhack
	applyStaffNametagEsp(plr, true)

	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals then
		local cName = char.Name
		local vPart = wsVisuals:FindFirstChild(cName) or wsVisuals:FindFirstChild(plr.Name)
		if vPart then
			local sg = vPart:FindFirstChildOfClass("SurfaceGui")
			if sg then
				local sgConn = sg:GetPropertyChangedSignal("Enabled"):Connect(function()
					-- Keep the game's distance-scaling 3D nametag hidden; our screen-space tag replaces it
					if isEspEnabled and sg.Enabled then
						sg.Enabled = false
					end
				end)
				table.insert(connections, sgConn)
			end
		end
	end

	-- 3. Determine Player Role & Name Info
	local isBl = isPlayerBlacklisted(plr.UserId)
	local isStaff, roleName = checkPlayerStaff(plr)
	local isWanted = false
	if ADMIN_SYS and ADMIN_SYS.isPlayerWanted then
		isWanted = ADMIN_SYS.isPlayerWanted(plr)
	end

	local roleText = ""
	if isBl then
		roleText = "⛔ BLACKLIST"
	elseif isStaff then
		roleText = string.format("🛡️ %s", string.upper(roleName or "STAFF"))
	elseif isWanted then
		roleText = "⚠️ WANTED"
	elseif plr.Team then
		local tName = plr.Team.Name
		if string.find(tName, "Guard") or string.find(tName, "Police") or string.find(tName, "Enforcement") then
			roleText = "👮 POLICE"
		elseif string.find(tName, "Inmate") or string.find(tName, "Prisoner") or string.find(tName, "Criminal") then
			roleText = "⛓️ INMATE"
		else
			roleText = "👤 " .. string.upper(tName)
		end
	else
		roleText = "👤 CITIZEN"
	end

	local cleanName = plr.Name
	local nameColorHex = string.format("#%02x%02x%02x", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))

	local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	local headPart = char:FindFirstChild("Head") or rootPart
	local humanoid = char:FindFirstChildOfClass("Humanoid")

	local espGui = nil
	local tagTop = nil
	local tagBottom = nil
	local nameLabel = nil
	local subLabel = nil

	local parentFolder = espFolder or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or player:WaitForChild("PlayerGui"))

	-- TRUE SCREEN-SPACE ESP: every element uses pixel Offset sizes and is positioned each frame
	-- from the projected 3D point, so size and gaps never change with player distance.
	if rootPart then
		espGui = Instance.new("ScreenGui")
		espGui.Name = plr.Name .. "_EspScreen"
		espGui.ResetOnSpawn = false
		espGui.IgnoreGuiInset = true
		espGui.DisplayOrder = 5
		espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		espGui.Parent = parentFolder

		-- A. TOP: Player Name & Role in ONE line (fixed pixel gap above the head)
		tagTop = Instance.new("TextLabel")
		tagTop.Name = "NameTag"
		tagTop.AnchorPoint = Vector2.new(0.5, 1)
		tagTop.Size = UDim2.fromOffset(360, 16)
		tagTop.BackgroundTransparency = 1
		tagTop.RichText = true
		tagTop.Font = Enum.Font.GothamBold
		tagTop.TextSize = 12
		tagTop.TextColor3 = Color3.fromRGB(255, 255, 255)
		tagTop.TextStrokeTransparency = 0.25
		tagTop.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tagTop.Text = string.format("<font color=\"%s\">★ %s</font>  |  <font color=\"%s\">%s</font>%s", nameColorHex, cleanName, nameColorHex, roleText, getStaffStatusTag(isInvisInit, isIncogInit))
		tagTop.TextXAlignment = Enum.TextXAlignment.Center
		tagTop.Visible = false
		tagTop.Parent = espGui
		nameLabel = tagTop

		-- B. BOTTOM: Distance | Tool | HP number (fixed pixel gap below the feet)
		tagBottom = Instance.new("TextLabel")
		tagBottom.Name = "InfoTag"
		tagBottom.AnchorPoint = Vector2.new(0.5, 0)
		tagBottom.Size = UDim2.fromOffset(300, 14)
		tagBottom.BackgroundTransparency = 1
		tagBottom.RichText = true
		tagBottom.Font = Enum.Font.GothamMedium
		tagBottom.TextSize = 10
		tagBottom.TextColor3 = Color3.fromRGB(215, 225, 235)
		tagBottom.TextStrokeTransparency = 0.25
		tagBottom.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tagBottom.Text = '0m  |  <font color=\"#2ed573\">100 HP</font>'
		tagBottom.TextXAlignment = Enum.TextXAlignment.Center
		tagBottom.Visible = false
		tagBottom.Parent = espGui
		subLabel = tagBottom

		-- Per-frame projection: only the anchor point follows the 3D position, pixel gaps stay constant
		lastInvisState = isInvisInit
		lastIncogState = isIncogInit
		local hasForcedInvisTrans = false
		local lastDistMeters = -1
		local lastHpVal = -1
		local lastToolName = ""
		local lastDownedState = nil
		local statusCheckTimer = 0

		local renderConn = RunService.RenderStepped:Connect(function(dt)
			local cam = workspace.CurrentCamera
			if not isEspEnabled or not cam or not rootPart.Parent or not espGui.Parent then
				tagTop.Visible = false
				tagBottom.Visible = false
				return
			end

			local rootPos = rootPart.Position
			local headTopY = rootPos.Y + 2.2
			if headPart and headPart.Parent then
				headTopY = headPart.Position.Y + headPart.Size.Y * 0.5
			end
			local hip = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) and humanoid.HipHeight or 2
			local feetY = rootPos.Y - rootPart.Size.Y * 0.5 - hip

			local topV = cam:WorldToViewportPoint(Vector3.new(rootPos.X, headTopY, rootPos.Z))
			local botV = cam:WorldToViewportPoint(Vector3.new(rootPos.X, feetY, rootPos.Z))
			local midV = cam:WorldToViewportPoint(rootPos)

			local visible = topV.Z > 0 and botV.Z > 0 and midV.Z > 0
			tagTop.Visible = visible
			tagBottom.Visible = visible
			if not visible then return end

			tagTop.Position = UDim2.fromOffset(math.floor(topV.X), math.floor(topV.Y) - 4)
			tagBottom.Position = UDim2.fromOffset(math.floor(botV.X), math.floor(botV.Y) + 4)

			-- Throttle invisibility & incognito status checks to 4Hz (every 0.25s) or on signal
			statusCheckTimer = statusCheckTimer + (dt or 0.016)
			local checkStatusNow = (lastInvisState == nil or lastIncogState == nil or statusCheckTimer >= 0.25)
			if checkStatusNow then
				statusCheckTimer = 0
				local isInvis = isPlayerInvisible(plr, char)
				local isIncog = isPlayerIncognito(plr, char)

				if isInvis and not hasForcedInvisTrans then
					hasForcedInvisTrans = true
					for _, part in ipairs(char:GetChildren()) do
						if part:IsA("BasePart") and part.Transparency >= 0.99 then
							part.Transparency = 0.95
						end
					end
				elseif not isInvis then
					hasForcedInvisTrans = false
				end

				if isInvis ~= lastInvisState or isIncog ~= lastIncogState then
					lastInvisState = isInvis
					lastIncogState = isIncog
					if hl and hl.Parent then
						if isInvis then
							hl.FillColor = Color3.fromRGB(255, 255, 255)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 1
							hl.OutlineTransparency = 0
							hl.Enabled = true
						else
							local curCol = getStaffEspColor(plr)
							hl.FillColor = curCol
							hl.OutlineColor = curCol
							hl.FillTransparency = (SETTINGS and SETTINGS.ESP_TRANSPARENCY) or 1
							hl.OutlineTransparency = 0.05
						end
					end
					if tagTop and tagTop.Parent then
						tagTop.Text = string.format("<font color=\"%s\">★ %s</font>  |  <font color=\"%s\">%s</font>%s", nameColorHex, cleanName, nameColorHex, roleText, getStaffStatusTag(isInvis, isIncog))
					end
				end
			end

			-- Distance & Tool & HP update with change detection (Zero redundant TextLabel property writes)
			local curDistMeters = math.floor((rootPos - cam.CFrame.Position).Magnitude)
			local curHp, maxHp, isDowned = getLivePlayerHealth(plr, char)
			local liveTool = char:FindFirstChildOfClass("Tool")
			local liveToolName = (liveTool and liveTool.Name ~= "") and liveTool.Name or ""

			if curDistMeters ~= lastDistMeters or curHp ~= lastHpVal or liveToolName ~= lastToolName or isDowned ~= lastDownedState then
				lastDistMeters = curDistMeters
				lastHpVal = curHp
				lastToolName = liveToolName
				lastDownedState = isDowned

				local hpRatio = math.clamp(curHp / math.max(maxHp, 1), 0, 1)
				local hpColorHex = (isDowned and "#ff4757")
					or (hpRatio > 0.6 and "#2ed573")
					or (hpRatio > 0.25 and "#ffa502")
					or "#ff4757"

				local hpText = isDowned and '<font color="#ff4757">0 HP (DOWN)</font>'
					or string.format('<font color="%s">%d HP</font>', hpColorHex, curHp)

				local toolStr = ""
				if liveToolName ~= "" then
					toolStr = string.format("  |  %s %s", getToolIcon(liveToolName), liveToolName)
				end

				tagBottom.Text = string.format('%dm%s  |  %s', curDistMeters, toolStr, hpText)
			end
		end)
		table.insert(connections, renderConn)
	end

	-- Immediate health synchronization listeners
	queryPlayerBody(plr)
	local bhConn = plr:GetAttributeChangedSignal("BodyHealth"):Connect(function()
		queryPlayerBody(plr)
	end)
	table.insert(connections, bhConn)

	local charBhConn = char:GetAttributeChangedSignal("BodyHealth"):Connect(function()
		queryPlayerBody(plr)
	end)
	table.insert(connections, charBhConn)

	-- Invisibility & Incognito listeners for instant updates
	local invisCharConn = char:GetAttributeChangedSignal("Invisible"):Connect(function()
		lastInvisState = nil
		lastIncogState = nil
	end)
	table.insert(connections, invisCharConn)

	local invisPlrConn = plr:GetAttributeChangedSignal("Invisible"):Connect(function()
		lastInvisState = nil
		lastIncogState = nil
	end)
	table.insert(connections, invisPlrConn)

	local incogPlrConn = plr:GetAttributeChangedSignal("Incognito"):Connect(function()
		lastInvisState = nil
		lastIncogState = nil
	end)
	table.insert(connections, incogPlrConn)

	local incogCharConn = char:GetAttributeChangedSignal("Incognito"):Connect(function()
		lastInvisState = nil
		lastIncogState = nil
	end)
	table.insert(connections, incogCharConn)

	-- 4. Dynamic Team / Color update
	local teamConn = plr:GetPropertyChangedSignal("TeamColor"):Connect(function()
		if isEspEnabled and hl and hl.Parent then
			local newCol = getStaffEspColor(plr)
			local isInvis = isPlayerInvisible(plr, char)
			local isIncog = isPlayerIncognito(plr, char)
			if isInvis then
				hl.FillColor = Color3.fromRGB(255, 255, 255)
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			else
				hl.FillColor = newCol
				hl.OutlineColor = newCol
			end
			if nameLabel then
				local newHex = string.format("#%02x%02x%02x", math.floor(newCol.R * 255), math.floor(newCol.G * 255), math.floor(newCol.B * 255))
				nameColorHex = newHex
				nameLabel.Text = string.format("<font color=\"%s\">★ %s</font>  |  <font color=\"%s\">%s</font>%s", newHex, cleanName, newHex, roleText, getStaffStatusTag(isInvis, isIncog))
			end
		end
	end)
	table.insert(connections, teamConn)

	-- 5. Respawn & Ancestry handling
	local charRemovingConn = char.AncestryChanged:Connect(function(_, parent)
		if not parent and isEspEnabled then
			removeEspForPlayer(plr)
		end
	end)
	table.insert(connections, charRemovingConn)

	local charAddedConn = plr.CharacterAdded:Connect(function(newChar)
		if isEspEnabled then
			task.delay(0.2, function()
				if isEspEnabled and newChar and newChar.Parent then
					createEspForPlayer(plr)
				end
			end)
		end
	end)
	table.insert(connections, charAddedConn)

	espDatabase[plr] = {
		Highlight = hl,
		Gui = espGui,
		TagTop = tagTop,
		TagBottom = tagBottom,
		SubLabel = subLabel,
		NameLabel = nameLabel,
		Char = char,
		Connections = connections
	}
end

local function startEspWatchdog()
	if espWatchdogRunning then return end
	espWatchdogRunning = true

	task.spawn(function()
		while isEspEnabled do
			task.wait(4.0)
			if not isEspEnabled then break end

			-- Ultra-lightweight health and integrity check (every 4.0s, zero RemoteFunction spam)
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player then
					local char = getPlayerChar(plr)
					local data = espDatabase[plr]

					if char and char:IsDescendantOf(workspace) then
						local needsRebuild = false
						if not data or not data.Highlight or not data.Highlight.Parent 
							or not data.TagTop or not data.TagTop.Parent
							or not data.TagBottom or not data.TagBottom.Parent then
							needsRebuild = true
						elseif data.Char ~= char then
							needsRebuild = true
						end

						if needsRebuild then
							createEspForPlayer(plr)
						end
					else
						if data and (data.Highlight or data.TagTop or data.TagBottom) then
							removeEspForPlayer(plr)
						end
					end
				end
			end
		end
		espWatchdogRunning = false
	end)
end
local function enableEsp()
	isEspEnabled = true
	local parentContainer = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or player:WaitForChild("PlayerGui")

	if espFolder then pcall(function() espFolder:Destroy() end) end
	espFolder = Instance.new("Folder")
	espFolder.Name = "Staff_ESP_Container"
	espFolder.Parent = parentContainer

	pcall(function()
		player:SetAttribute("NameTagDistance", 99999)
		player:SetAttribute("SeeHiddenStaff", true)
		player:SetAttribute("GroupRank", 255)

		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		local ses = rem and rem:FindFirstChild("StaffEspStreaming")
		if ses then
			ses:FireServer(nil, true)
		end
	end)

	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals and not espVisualsConn then
		espVisualsConn = wsVisuals.ChildAdded:Connect(function(child)
			if isEspEnabled then
				task.wait(0.05)
				if child and child:IsA("BasePart") and child.Name ~= player.Name then
					local sg = child:FindFirstChildOfClass("SurfaceGui")
					if sg then
						if not sg:GetAttribute("StaffEspOriginalAOT") then
							sg:SetAttribute("StaffEspOriginalAOT", sg.AlwaysOnTop and "true" or "false")
						end
						sg.AlwaysOnTop = false
						sg.Enabled = false
						sg:GetPropertyChangedSignal("Enabled"):Connect(function()
							if isEspEnabled and sg.Enabled then
								sg.Enabled = false
							end
						end)
					end
				end
			end
		end)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			createEspForPlayer(plr)
		end
	end

	startEspWatchdog()
	updateGuiEspState()
	updateGuiAuraState()
end

local function disableEsp()
	isEspEnabled = false
	espWatchdogRunning = false

	if espVisualsConn then
		pcall(function() espVisualsConn:Disconnect() end)
		espVisualsConn = nil
	end

	for plr, _ in pairs(espDatabase) do
		removeEspForPlayer(plr)
	end
	table.clear(espDatabase)
	table.clear(playerHealthCache)
	table.clear(lastHealthQueryTime)

	if espFolder then
		pcall(function() espFolder:Destroy() end)
		espFolder = nil
	end

	pcall(function()
		player:SetAttribute("NameTagDistance", 40)
		player:SetAttribute("SeeHiddenStaff", nil)
		player:SetAttribute("GroupRank", nil)

		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		local ses = rem and rem:FindFirstChild("StaffEspStreaming")
		if ses then
			ses:FireServer(nil, false)
		end

		local wsVisuals = workspace:FindFirstChild("Visuals")
		if wsVisuals then
			for _, child in ipairs(wsVisuals:GetChildren()) do
				if child:IsA("BasePart") and child.Name ~= player.Name then
					local sg = child:FindFirstChildOfClass("SurfaceGui")
					if sg then
						local orig = sg:GetAttribute("StaffEspOriginalAOT")
						if orig ~= nil then
							sg.AlwaysOnTop = (orig == "true")
							sg:SetAttribute("StaffEspOriginalAOT", nil)
						else
							sg.AlwaysOnTop = false
						end
						sg.MaxDistance = 40
						sg.LightInfluence = 1
						sg.Enabled = true
					end
				end
			end
		end
	end)

	updateGuiEspState()
end

function toggleEsp()
	if isEspEnabled then
		disableEsp()
	else
		enableEsp()
	end
end

Players.PlayerAdded:Connect(function(plr)
	pcall(checkPlayerStaff, plr)
	pcall(ADMIN_SYS.updateStaffRadar)
	if isEspEnabled then
		task.delay(0.5, function()
			if isEspEnabled then
				createEspForPlayer(plr)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	if isSpectating and spectateTarget == plr then
		stopSpectating()
	end
	removeEspForPlayer(plr)
	playerHealthCache[plr] = nil
	lastHealthQueryTime[plr] = nil
	playerJoinTimes[plr] = nil
	staffCache[plr.UserId] = nil
	alertedStaffJoins[plr.UserId] = nil
end)

for _, plr in ipairs(Players:GetPlayers()) do
	if not playerJoinTimes[plr] then
		playerJoinTimes[plr] = tick()
	end
end
Players.PlayerAdded:Connect(function(plr)
	playerJoinTimes[plr] = tick()
end)

local function getLivePing()
	local pingVal = 0
	local ok = pcall(function()
		local netStats = StatsService.Network.ServerStatsItem
		if netStats and netStats["Data Ping"] then
			pingVal = netStats["Data Ping"]:GetValue()
		end
	end)
	if not ok or pingVal <= 0 then
		pcall(function()
			if player.GetNetworkPing then
				pingVal = player:GetNetworkPing() * 1000
			end
		end)
	end
	return math.max(math.floor(pingVal + 0.5), 1)
end

local function formatPlayTime(seconds)
	if not seconds or seconds < 0 then seconds = 0 end
	local hrs = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	if hrs > 0 then
		return string.format("%02dh %02dm %02ds", hrs, mins, secs)
	else
		return string.format("%02dm %02ds", mins, secs)
	end
end

local function fireServerSpectateFocus(targetPlr, enable)
	pcall(function()
		local rem = ReplicatedStorage:FindFirstChild("Remotes")
		if not rem then return end

		local ssf = rem:FindFirstChild("StaffSpectateFocus")
		if ssf then
			if enable and targetPlr then
				local uid = (typeof(targetPlr) == "Instance" and targetPlr.UserId) or tonumber(targetPlr)
				ssf:FireServer(uid)
			else
				ssf:FireServer(nil)
			end
		end

		local cw = rem:FindFirstChild("CameraWatch")
		if cw then
			if enable and targetPlr then
				cw:FireServer(targetPlr)
			else
				cw:FireServer(nil)
			end
		end

		local svd = rem:FindFirstChild("SetVoiceDistance")
		if svd then
			if enable then
				svd:FireServer(999999)
				svd:FireServer("Global")
				svd:FireServer(true)
			else
				svd:FireServer(nil)
			end
		end

		local ff = rem:FindFirstChild("FreecamFocus")
		if ff then
			if enable and targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart") then
				ff:FireServer(targetPlr.Character.HumanoidRootPart.CFrame)
			else
				ff:FireServer(nil)
			end
		end

		local ses = rem:FindFirstChild("StaffEspStreaming")
		if ses then
			ses:FireServer(targetPlr, enable == true)
		end
	end)
end

stopSpectating = function()
	if spectateConn then
		pcall(function() spectateConn:Disconnect() end)
		spectateConn = nil
	end
	if spectateVoiceConn then
		pcall(function() spectateVoiceConn:Disconnect() end)
		spectateVoiceConn = nil
	end

	fireServerSpectateFocus(nil, false)

	pcall(function()
		SoundService:SetListener(Enum.ListenerType.Camera)
	end)

	for listener, origParent in pairs(savedAudioListeners) do
		pcall(function()
			if listener and listener.Parent and origParent and origParent.Parent then
				listener.Parent = origParent
			end
		end)
	end
	table.clear(savedAudioListeners)

	isSpectating = false
	spectateTarget = nil

	if spectateHud then
		spectateHud.Visible = false
	end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local cam = workspace.CurrentCamera
			if cam then
				cam.CameraSubject = hum
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end

	pcall(function()
		if updateRealtimeTelemetry then updateRealtimeTelemetry() end
		if updateHackerLiveCards then updateHackerLiveCards() end
	end)
end

spectatePlayer = function(targetPlr)
	if targetPlr == player then return end
	if isSpectating and spectateTarget == targetPlr then
		stopSpectating()
		return
	end
	stopSpectating()
	isSpectating = true
	spectateTarget = targetPlr

	fireServerSpectateFocus(targetPlr, true)

	local function attach()
		local tChar = targetPlr.Character
		if tChar then
			local tHum = tChar:FindFirstChildOfClass("Humanoid")
			local tHead = tChar:FindFirstChild("Head") or tChar:FindFirstChild("HumanoidRootPart")
			if tHum then
				local cam = workspace.CurrentCamera
				if cam then
					cam.CameraSubject = tHum
					cam.CameraType = Enum.CameraType.Custom
				end
			end

			if tHead then
				pcall(function()
					SoundService:SetListener(Enum.ListenerType.ObjectPosition, tHead)
				end)
			end
		end
	end
	attach()

	spectateConn = targetPlr.CharacterAdded:Connect(function()
		task.wait(0.3)
		if isSpectating and spectateTarget == targetPlr then
			attach()
			fireServerSpectateFocus(targetPlr, true)
		end
	end)

	local voiceCheckTimer = 0
	spectateVoiceConn = RunService.Heartbeat:Connect(function(dt)
		if not isSpectating or not spectateTarget then return end
		voiceCheckTimer = voiceCheckTimer + dt
		if voiceCheckTimer < 1.0 then return end
		voiceCheckTimer = 0

		local tChar = spectateTarget.Character
		if not tChar then return end
		local tHead = tChar:FindFirstChild("Head") or tChar:FindFirstChild("HumanoidRootPart")
		if not tHead then return end

		pcall(function()
			SoundService:SetListener(Enum.ListenerType.ObjectPosition, tHead)
		end)

		pcall(function()
			local cam = workspace.CurrentCamera
			if player.Character then
				for _, obj in ipairs(player.Character:GetDescendants()) do
					if obj:IsA("AudioListener") and not savedAudioListeners[obj] then
						savedAudioListeners[obj] = obj.Parent
						obj.Parent = tHead
					end
				end
			end
			if cam then
				for _, obj in ipairs(cam:GetChildren()) do
					if obj:IsA("AudioListener") and not savedAudioListeners[obj] then
						savedAudioListeners[obj] = obj.Parent
						obj.Parent = tHead
					end
				end
			end
		end)

		pcall(function()
			local tPos = tHead.Position
			for _, p in ipairs(Players:GetPlayers()) do
				local c = p.Character
				if c then
					local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head")
					if root and (root.Position - tPos).Magnitude <= 150 then
						for _, s in ipairs(c:GetDescendants()) do
							if s:IsA("Sound") and s.IsPlaying and s.Volume == 0 then
								s.Volume = 1
							end
							if s:IsA("Sound") and s.RollOffMaxDistance < 150 then
								s.RollOffMaxDistance = 250
							end
						end
					end
				end
			end
		end)
	end)

	if spectateHud then
		spectateHud.AnchorPoint = Vector2.new(0.5, 0)
		spectateHud.Position = UDim2.new(0.5, 0, 0, 64)
		spectateHud.Visible = true
		if shTitle then
			local gInfo = GANG_SYS and GANG_SYS.getPlayerGang(targetPlr.UserId)
			local tagDisp = ""
			if gInfo then
				local baseTag = (gInfo.gangTag ~= "" and gInfo.gangTag or ("[" .. gInfo.gangName .. "]"))
				tagDisp = gInfo.isTagHidden and (" " .. baseTag .. " 🕶️ [Tag Off]") or (" " .. baseTag)
			end
			shTitle.Text = "SPECTATING: " .. targetPlr.DisplayName .. tagDisp
		end
		if shAvatar then
			getCachedThumbnailAsync(targetPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(thumb)
				if isSpectating and spectateTarget == targetPlr and shAvatar then
					shAvatar.Image = thumb
				end
			end)
		end
	end

	pcall(function()
		if updateRealtimeTelemetry then updateRealtimeTelemetry() end
		if updateHackerLiveCards then updateHackerLiveCards() end
	end)
end


local MAX_CHAT_LOGS = 60
local pendingChatMessages = {}

local function logChatMessage(senderName, message, teamColor)
	if not chatScroll then
		table.insert(pendingChatMessages, {
			senderName = senderName,
			message = message,
			teamColor = teamColor,
		})
		if #pendingChatMessages > MAX_CHAT_LOGS then
			table.remove(pendingChatMessages, 1)
		end
		return
	end

	-- Cap maximum chat log frames to eliminate memory leaks and FPS drops
	local existingFrames = {}
	for _, child in ipairs(chatScroll:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(existingFrames, child)
		end
	end
	while #existingFrames >= MAX_CHAT_LOGS do
		local oldest = table.remove(existingFrames, 1)
		if oldest then pcall(function() oldest:Destroy() end) end
	end

	local timeStr = os.date("%H:%M:%S")

	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -6, 0, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.BackgroundColor3 = THEME.CardBg
	item.BorderSizePixel = 0
	item.Parent = chatScroll

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 6)
	itemCorner.Parent = item

	local itemStroke = Instance.new("UIStroke")
	itemStroke.Color = THEME.CardStroke
	itemStroke.Thickness = 1
	itemStroke.Parent = item

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 0, 0)
	label.Position = UDim2.new(0, 6, 0, 5)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Font = Enum.Font.Gotham
	label.TextSize = 11
	label.TextColor3 = THEME.TextFrost
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = item

	local colorHex = string.format("#%02X%02X%02X", math.floor(teamColor.R * 255), math.floor(teamColor.G * 255), math.floor(teamColor.B * 255))
	label.Text = string.format([=[<font color="#6b94be">[%s]</font> <font color="%s"><b>%s:</b></font> %s]=], timeStr, colorHex, senderName, message)

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = item

	task.defer(function()
		if chatScroll and chatScroll.Parent then
			chatScroll.CanvasPosition = Vector2.new(0, 999999)
		end
	end)
end

do
	local isLegacy = true
	pcall(function()
		isLegacy = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
	end)

	if isLegacy then
	local function hookPlrChat(plr)
		plr.Chatted:Connect(function(msg)
			local col = plr.TeamColor and plr.TeamColor.Color or THEME.CyanPrimary
			logChatMessage(plr.DisplayName, msg, col)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlrChat(p)
	end
	Players.PlayerAdded:Connect(hookPlrChat)
else
	pcall(function()
		TextChatService.MessageReceived:Connect(function(textMsg)
			if textMsg.TextSource and textMsg.Status ~= Enum.TextChatMessageStatus.InvalidTextChannelPermissions then
				local sender = Players:GetPlayerByUserId(textMsg.TextSource.UserId)
				local sName = sender and sender.DisplayName or "Unknown"
				local sCol = sender and sender.TeamColor and sender.TeamColor.Color or THEME.CyanPrimary
				local content = textMsg.Text
				pcall(function()
					if textMsg.WasRewritten then
						content = "(rephrased) " .. textMsg.RewrittenText
					end
				end)
				logChatMessage(sName, content, sCol)
			end
		end)
	end)
end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.W then
		inputState.W = true
	elseif input.KeyCode == Enum.KeyCode.S then
		inputState.S = true
	elseif input.KeyCode == Enum.KeyCode.A then
		inputState.A = true
	elseif input.KeyCode == Enum.KeyCode.D then
		inputState.D = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		inputState.Space = true
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		inputState.LeftControl = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		inputState.LeftShift = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.W then
		inputState.W = false
	elseif input.KeyCode == Enum.KeyCode.S then
		inputState.S = false
	elseif input.KeyCode == Enum.KeyCode.A then
		inputState.A = false
	elseif input.KeyCode == Enum.KeyCode.D then
		inputState.D = false
	elseif input.KeyCode == Enum.KeyCode.Space then
		inputState.Space = false
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		inputState.LeftControl = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		inputState.LeftShift = false
	end
end)

local function createAuraAttachment(part, name, offsetPos, offsetRot)
	if not part then return nil end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Astrocyna_Aura_" .. name
	local offsetCFrame = CFrame.new(offsetPos or Vector3.zero) * CFrame.Angles(
		math.rad((offsetRot and offsetRot.X) or 0),
		math.rad((offsetRot and offsetRot.Y) or 0),
		math.rad((offsetRot and offsetRot.Z) or 0)
	)
	local worldCFrame = part.CFrame * offsetCFrame
	attachment.CFrame = part.CFrame:ToObjectSpace(worldCFrame)
	attachment.Parent = part
	return attachment
end

local function createAuraParticleEmitter(config, parentAttachment)
	local emitter = Instance.new("ParticleEmitter")
	for prop, value in pairs(config) do
		pcall(function() emitter[prop] = value end)
	end
	if parentAttachment then
		emitter.Parent = parentAttachment
	end
	if OUTFIT_SYS and OUTFIT_SYS.auraEmitters then
		table.insert(OUTFIT_SYS.auraEmitters, emitter)
	end
	return emitter
end

local function getAuraNeonColorSequence(baseColor, timeVal)
	local beam = baseColor or THEME.BorderBeam
	local highlight = beam:Lerp(THEME.BorderHighlight, 0.75)
	local dark = beam:Lerp(THEME.BorderBase, 0.8)

	timeVal = timeVal or tick()
	local wave = (math.sin(timeVal * 2.8) + 1) / 2
	local currentMid = beam:Lerp(highlight, wave * 0.85)
	local currentSide = dark:Lerp(beam, 0.4 + wave * 0.4)

	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.3, currentSide),
		ColorSequenceKeypoint.new(0.5, currentMid),
		ColorSequenceKeypoint.new(0.7, currentSide),
		ColorSequenceKeypoint.new(1, dark)
	})
end

local function enableAuraEffects(character)
	if not character or not isAuraEnabled then return end
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) or character:FindFirstChild("Torso")
	local head = character:WaitForChild("Head", 5) or character:FindFirstChild("Torso")
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or rootPart
	if not rootPart or not head then return end

	local groundAtt = createAuraAttachment(rootPart, "GroundSeal", Vector3.new(0, -2.9, 0), Vector3.zero)
	if groundAtt then
		createAuraParticleEmitter({
			Name = "GroundSeal_Particle",
			Brightness = 3,
			Color = getAuraNeonColorSequence(auraColor),
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = NumberSequence.new(5),
			Texture = "rbxassetid://14591895021",
			Transparency = NumberSequence.new(0.5),
			ZOffset = 0,
			EmissionDirection = Enum.NormalId.Top,
			Enabled = true,
			Lifetime = NumberRange.new(1),
			Rate = 5,
			Rotation = NumberRange.new(0),
			RotSpeed = NumberRange.new(150),
			Speed = NumberRange.new(0.001),
			SpreadAngle = Vector2.zero,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			LockedToPart = true,
			TimeScale = 1
		}, groundAtt)
	end

	local coronaAtt = createAuraAttachment(head, "HeadCorona", Vector3.new(-0.23, 0.927, 0.044), Vector3.new(23.737, -0.199, 10.022))
	if coronaAtt then
		createAuraParticleEmitter({
			Name = "HeadCorona_Particle",
			Brightness = 5,
			Color = getAuraNeonColorSequence(auraColor),
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = NumberSequence.new(4),
			Texture = "rbxassetid://17087733793",
			Transparency = NumberSequence.new(0.5),
			ZOffset = 0,
			EmissionDirection = Enum.NormalId.Top,
			Enabled = true,
			Lifetime = NumberRange.new(1),
			Rate = 5,
			Rotation = NumberRange.new(-360, 360),
			RotSpeed = NumberRange.new(500),
			Speed = NumberRange.new(0.001),
			SpreadAngle = Vector2.new(5, 5),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			LockedToPart = true,
			TimeScale = 1
		}, coronaAtt)
	end

	local flameAtt = createAuraAttachment(head, "HeadFlames", Vector3.new(0, 0.5, 0), Vector3.zero)
	if flameAtt then
		createAuraParticleEmitter({
			Name = "HeadFlames_Particle",
			Brightness = 10,
			Color = getAuraNeonColorSequence(auraColor),
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NumberSequence.new(1.5),
			Texture = "rbxassetid://13410359900",
			Transparency = NumberSequence.new(0.5),
			ZOffset = -1,
			EmissionDirection = Enum.NormalId.Top,
			Enabled = true,
			Lifetime = NumberRange.new(1),
			Rate = 11,
			Rotation = NumberRange.new(-360, 360),
			RotSpeed = NumberRange.new(-30, 30),
			Speed = NumberRange.new(0, 1),
			SpreadAngle = Vector2.new(5, 5),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LockedToPart = true,
			TimeScale = 0.6,
			Drag = 5
		}, flameAtt)
	end

	local limbNames = {
		"Head", "Torso", "UpperTorso", "LowerTorso",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot"
	}
	for _, limb in ipairs(limbNames) do
		local part = character:FindFirstChild(limb)
		if part and part:IsA("BasePart") then
			local bAtt = createAuraAttachment(part, limb .. "_Shadow", Vector3.zero, Vector3.zero)
			if bAtt then
				createAuraParticleEmitter({
					Name = "BlackShadow_Particle",
					Brightness = 5,
					Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
					LightEmission = 0.6,
					LightInfluence = 0,
					Orientation = Enum.ParticleOrientation.FacingCamera,
					Size = NumberSequence.new(0.8),
					Texture = "rbxassetid://13410359900",
					Transparency = NumberSequence.new(0.5),
					ZOffset = -1.05,
					EmissionDirection = Enum.NormalId.Top,
					Enabled = true,
					Lifetime = NumberRange.new(1),
					Rate = 20,
					Rotation = NumberRange.new(-360, 360),
					RotSpeed = NumberRange.new(-30, 30),
					Speed = NumberRange.new(0, 2),
					SpreadAngle = Vector2.new(5, 5),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
					FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
					LockedToPart = true,
					TimeScale = 1,
					Drag = 2
				}, bAtt)
			end

			local gAtt = createAuraAttachment(part, limb .. "_Glow", Vector3.zero, Vector3.zero)
			if gAtt then
				createAuraParticleEmitter({
					Name = "AuraFlames_Particle",
					Brightness = 10,
					Color = getAuraNeonColorSequence(auraColor),
					LightEmission = 0.6,
					LightInfluence = 0,
					Orientation = Enum.ParticleOrientation.FacingCamera,
					Size = NumberSequence.new(0.5),
					Texture = "rbxassetid://13410359900",
					Transparency = NumberSequence.new(0.5),
					ZOffset = -1.05,
					EmissionDirection = Enum.NormalId.Top,
					Enabled = true,
					Lifetime = NumberRange.new(1),
					Rate = 20,
					Rotation = NumberRange.new(-360, 360),
					RotSpeed = NumberRange.new(-30, 30),
					Speed = NumberRange.new(0, 2),
					SpreadAngle = Vector2.new(5, 5),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
					FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
					LockedToPart = true,
					TimeScale = 1,
					Drag = 2
				}, gAtt)
			end
		end
	end

	if torso then
		local shockAtt = createAuraAttachment(torso, "Shockwave", Vector3.zero, Vector3.zero)
		if shockAtt then
			createAuraParticleEmitter({
				Name = "TorsoShockwave_Particle",
				Brightness = 15,
				Color = getAuraNeonColorSequence(auraColor),
				LightEmission = 1,
				LightInfluence = 0,
				Orientation = Enum.ParticleOrientation.FacingCamera,
				Size = NumberSequence.new(3),
				Texture = "rbxassetid://15011464541",
				Transparency = NumberSequence.new(0.5),
				ZOffset = 0,
				EmissionDirection = Enum.NormalId.Top,
				Enabled = true,
				Lifetime = NumberRange.new(1),
				Rate = 3,
				Rotation = NumberRange.new(-1000, 1000),
				RotSpeed = NumberRange.new(-10, 10),
				Speed = NumberRange.new(0),
				SpreadAngle = Vector2.new(-1000, 1000),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				LockedToPart = true,
				TimeScale = 1,
				Drag = 1
			}, shockAtt)
		end
	end

	local crestAtt = createAuraAttachment(head, "HeadCrest", Vector3.new(-0.115, 0.261, -0.6), Vector3.zero)
	if crestAtt then
		createAuraParticleEmitter({
			Name = "HeadCrest_Particle",
			Brightness = 5,
			Color = getAuraNeonColorSequence(auraColor),
			LightEmission = 0,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = NumberSequence.new(0.4),
			Texture = "rbxassetid://16956515291",
			Transparency = NumberSequence.new(0.5),
			ZOffset = 0.1,
			EmissionDirection = Enum.NormalId.Front,
			Enabled = true,
			Lifetime = NumberRange.new(0.5),
			Rate = 6,
			Rotation = NumberRange.new(0),
			RotSpeed = NumberRange.new(0),
			Speed = NumberRange.new(0.001),
			SpreadAngle = Vector2.zero,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			LockedToPart = true,
			TimeScale = 1
		}, crestAtt)
	end

	if torso then
		local ringAtt = createAuraAttachment(torso, "VerticalRing", Vector3.new(0, 0, 1.981), Vector3.zero)
		if ringAtt then
			createAuraParticleEmitter({
				Name = "VerticalRing_Particle",
				Brightness = 5,
				Color = getAuraNeonColorSequence(auraColor),
				LightEmission = 1,
				LightInfluence = 0,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Size = NumberSequence.new(5),
				Texture = "rbxassetid://8095997435",
				Transparency = NumberSequence.new(0.5),
				ZOffset = 0,
				EmissionDirection = Enum.NormalId.Front,
				Enabled = true,
				Lifetime = NumberRange.new(1),
				Rate = 2.8,
				Rotation = NumberRange.new(0),
				RotSpeed = NumberRange.new(120),
				Speed = NumberRange.new(0.001),
				SpreadAngle = Vector2.zero,
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				LockedToPart = true,
				TimeScale = 1
			}, ringAtt)
		end
	end

	if torso then
		local wingsAtt = createAuraAttachment(torso, "BackWings", Vector3.new(0, 0.633, 0.597), Vector3.zero)
		if wingsAtt then
			createAuraParticleEmitter({
				Name = "BackWings_Particle",
				Brightness = 0.065,
				Color = getAuraNeonColorSequence(auraColor),
				LightEmission = 1,
				LightInfluence = 0,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Size = NumberSequence.new(4),
				Texture = "rbxassetid://138411198581652",
				Transparency = NumberSequence.new(0.5),
				ZOffset = 0,
				EmissionDirection = Enum.NormalId.Front,
				Enabled = true,
				Lifetime = NumberRange.new(1),
				Rate = 43,
				Rotation = NumberRange.new(0),
				RotSpeed = NumberRange.new(0),
				Speed = NumberRange.new(0.001),
				SpreadAngle = Vector2.new(1, 1),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				LockedToPart = true,
				TimeScale = 1
			}, wingsAtt)
		end
	end
end

local function removeAuraEffects(character)
	if OUTFIT_SYS and OUTFIT_SYS.auraEmitters then
		table.clear(OUTFIT_SYS.auraEmitters)
	end
	if not character then return end
	for _, att in ipairs(character:GetDescendants()) do
		if att:IsA("Attachment") and string.find(att.Name, "Astrocyna_Aura_") then
			pcall(function() att:Destroy() end)
		end
	end
end

local function changeAuraColor(newColor)
	if not newColor then return end
	auraColor = newColor
	local character = player.Character
	if character then
		local seq = getAuraNeonColorSequence(newColor, tick())
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Name ~= "BlackShadow_Particle" then
				d.Color = seq
			end
		end
	end
end

toggleAura = function()
	isAuraEnabled = not isAuraEnabled
	if player.Character then
		removeAuraEffects(player.Character)
		if isAuraEnabled then
			enableAuraEffects(player.Character)
		end
	end
	pcall(updateGuiAuraState)
	pcall(syncAuraPowerButton)
end

local function setupCharacter(char)
	boundCharacter = char
	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		loadAnimations(humanoid)
		humanoid.Died:Connect(function()
			stopFlying()
			if isInvis then
				disableInvis()
			end
		end)
	end
end

if player.Character then
	setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
player:GetPropertyChangedSignal("Character"):Connect(function()
	if player.Character then
		setupCharacter(player.Character)
	end
end)

-- ===================================================================
-- COVERT DISGUISE & STEALTH SYSTEM (CLIENT-ONLY FAKE BODY ARCHITECTURE)
-- วิธีการ: สร้าง Body Player ใหม่ที่เห็นแค่เราในมุมมอง Client-Only
-- ในมุมมองคนอื่น จะยังเห็นเราเป็น Body ปกติทุกอย่าง 100%
-- ===================================================================
local DISGUISE_SYS = {
	-- ===================================================================
	-- 🎭 UGC ITEMS CONFIGURATION (กำหนด / เพิ่ม / ลบ / เปลี่ยน UGC ได้ที่นี่เลย!)
	-- ===================================================================
	-- วิธีใช้งาน:
	-- 1. เพิ่มไอเทมใหม่: ใส่ตาราง { Name = "...", AssetId = 12345, Type = "Hat" } ลงในตาราง UgcItems
	-- 2. รองรับ Type: "Hat", "Face", "Back", "Waist", "Neck", "Shoulder", "Front", "Hair"
	-- 3. สามารถกำหนด TargetPart ("Head" / "Torso"), Attachment, C0, C1 ได้เองอย่างอิสระ
	-- 4. หรือเรียกใช้ผ่านฟังก์ชันในโค้ด:
	--      DISGUISE_SYS.addUgc({ Name = "Mask", AssetId = 123456, Type = "Face" })
	--      DISGUISE_SYS.removeUgc(123456)
	--      DISGUISE_SYS.clearUgc()
	-- ===================================================================
	UgcItems = {
		{
			Name = "White-Banded Fedora",
			AssetId = 126254522600177,
			Type = "Hat",
			TargetPart = "Head",
			Attachment = "HatAttachment",
			C0 = CFrame.new(0, -0.15, 0.05),
			C1 = CFrame.new(0, 0.6, 0),
		},
		{
			Name = "Spy Gear (Glasses)",
			AssetId = 5832931873,
			Type = "Face",
			TargetPart = "Head",
			Attachment = "FaceFrontAttachment",
			Aliases = { "FaceCenterAttachment" },
			C0 = CFrame.new(0.37, -0.08, 0.025, 0, 0, -1, 0, 1, 0, 1, 0, 0),
			C1 = CFrame.new(0, -0.16, -0.6), -- ระดับสายตาพอดี
			-- Fallback Mesh/Texture
			MeshId = "rbxassetid://5832514623",
			TextureId = "rbxassetid://5832530878",
			Scale = Vector3.new(0.026, 0.027, 0.026),
		},
		{
			Name = "Night's Eye Sniper",
			AssetId = 0,
			Type = "Back",
			TargetPart = "Torso",
			Attachment = "BodyBackAttachment",
			Aliases = { "BackAccessoryAttachment", "WaistBackAttachment" },
			C0 = CFrame.Angles(0, math.rad(180), math.rad(-45)),
			C1 = CFrame.new(0, 0.2, 0.65),
		},
	},

	-- รายการ AssetId สำหรับความเข้ากันได้ย้อนหลัง (Backward Compatibility)
	UgcAssetIds = {
		126254522600177,
		5832931873,
		0,
	},

	cachedUgcTemplates = {},
	addedAccessories = {},        -- array of added Accessory instances
	savedMeshTransparencies = {}, -- [BasePart] = number
	savedFixedClones = {},        -- [Head] = Instance clone
	disabledNativeObjects = {},   -- [Instance] = { origEnabled, origVisible, origTransparency }
	watchdogStarted = false,
}

-- -------------------------------------------------------------------
-- UGC Helper Functions (ปรับแต่ง / เพิ่ม / ลบ / จัดการ UGC ผ่านโค้ดได้อย่างง่ายดาย)
-- -------------------------------------------------------------------
function DISGUISE_SYS.normalizeItem(item)
	if type(item) == "number" then
		item = { AssetId = item, Name = "UGC_" .. tostring(item), Type = "Hat" }
	elseif type(item) ~= "table" then
		return {}
	end

	local t = item.Type or "Hat"
	local norm = {
		Name = item.Name or ("UGC_" .. tostring(item.AssetId)),
		AssetId = tonumber(item.AssetId),
		Type = t,
		TargetPart = item.TargetPart,
		Attachment = item.Attachment,
		Aliases = item.Aliases or {},
		C0 = item.C0,
		C1 = item.C1,
		AccessoryType = item.AccessoryType,
		MeshId = item.MeshId,
		TextureId = item.TextureId,
		Scale = item.Scale,
	}

	-- Intelligent defaults based on Type
	if t == "Hat" then
		norm.TargetPart = norm.TargetPart or "Head"
		norm.Attachment = norm.Attachment or "HatAttachment"
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, 0.6, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Hat
	elseif t == "Face" then
		norm.TargetPart = norm.TargetPart or "Head"
		norm.Attachment = norm.Attachment or "FaceFrontAttachment"
		norm.Aliases = (#norm.Aliases > 0 and norm.Aliases) or { "FaceCenterAttachment" }
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, -0.16, -0.6)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Face
	elseif t == "Back" then
		norm.TargetPart = norm.TargetPart or "Torso"
		norm.Attachment = norm.Attachment or "BodyBackAttachment"
		norm.Aliases = (#norm.Aliases > 0 and norm.Aliases) or { "BackAccessoryAttachment", "WaistBackAttachment" }
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, 0.2, 0.65)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Back
	elseif t == "Waist" then
		norm.TargetPart = norm.TargetPart or "Torso"
		norm.Attachment = norm.Attachment or "WaistCenterAttachment"
		norm.Aliases = (#norm.Aliases > 0 and norm.Aliases) or { "WaistBackAttachment", "WaistFrontAttachment" }
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, -0.8, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Waist
	elseif t == "Neck" then
		norm.TargetPart = norm.TargetPart or "Head"
		norm.Attachment = norm.Attachment or "NeckAttachment"
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, -0.5, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Neck
	elseif t == "Shoulder" then
		norm.TargetPart = norm.TargetPart or "Torso"
		norm.Attachment = norm.Attachment or "LeftShoulderAttachment"
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(-1.2, 0.5, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Shoulder
	elseif t == "Front" then
		norm.TargetPart = norm.TargetPart or "Torso"
		norm.Attachment = norm.Attachment or "BodyFrontAttachment"
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, 0, -0.6)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Front
	elseif t == "Hair" then
		norm.TargetPart = norm.TargetPart or "Head"
		norm.Attachment = norm.Attachment or "HairAttachment"
		norm.Aliases = (#norm.Aliases > 0 and norm.Aliases) or { "HatAttachment" }
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, 0.6, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Hair
	else
		norm.TargetPart = norm.TargetPart or "Head"
		norm.Attachment = norm.Attachment or "HatAttachment"
		norm.C0 = norm.C0 or CFrame.new(0, 0, 0)
		norm.C1 = norm.C1 or CFrame.new(0, 0.6, 0)
		norm.AccessoryType = norm.AccessoryType or Enum.AccessoryType.Hat
	end

	return norm
end

function DISGUISE_SYS.getItemConfig(assetId)
	local numId = tonumber(assetId)
	for _, item in ipairs(DISGUISE_SYS.UgcItems) do
		local id = type(item) == "number" and item or (item and item.AssetId)
		if tonumber(id) == numId then
			return DISGUISE_SYS.normalizeItem(item)
		end
	end
	return DISGUISE_SYS.normalizeItem({ AssetId = numId })
end

function DISGUISE_SYS.addUgc(itemConfig)
	if not itemConfig then return end
	local norm = DISGUISE_SYS.normalizeItem(itemConfig)
	if not norm.AssetId then return end

	for i, it in ipairs(DISGUISE_SYS.UgcItems) do
		local id = type(it) == "number" and it or (it and it.AssetId)
		if tonumber(id) == norm.AssetId then
			DISGUISE_SYS.UgcItems[i] = norm
			if isDisguiseEnabled then DISGUISE_SYS.applyDisguise() end
			return
		end
	end

	table.insert(DISGUISE_SYS.UgcItems, norm)
	table.insert(DISGUISE_SYS.UgcAssetIds, norm.AssetId)
	if isDisguiseEnabled then
		DISGUISE_SYS.applyDisguise()
	end
end

function DISGUISE_SYS.removeUgc(assetIdOrName)
	if not assetIdOrName then return end
	local numId = tonumber(assetIdOrName)
	local strName = type(assetIdOrName) == "string" and string.lower(assetIdOrName) or nil

	for i = #DISGUISE_SYS.UgcItems, 1, -1 do
		local it = DISGUISE_SYS.UgcItems[i]
		local id = type(it) == "number" and it or (it and it.AssetId)
		local name = type(it) == "table" and it.Name and string.lower(it.Name) or nil

		if (numId and tonumber(id) == numId) or (strName and name and string.find(name, strName)) then
			local removedId = tonumber(id)
			table.remove(DISGUISE_SYS.UgcItems, i)

			local targets = DISGUISE_SYS.getAllTargetCharacters()
			for _, target in ipairs(targets) do
				if target and target.Parent and removedId then
					local acc = target:FindFirstChild("Astrocyna_Disguise_UGC_" .. tostring(removedId))
					if acc then pcall(function() acc:Destroy() end) end
				end
			end
		end
	end

	table.clear(DISGUISE_SYS.UgcAssetIds)
	for _, it in ipairs(DISGUISE_SYS.UgcItems) do
		local id = type(it) == "number" and it or (it and it.AssetId)
		if id then table.insert(DISGUISE_SYS.UgcAssetIds, id) end
	end
end

function DISGUISE_SYS.clearUgc()
	local targets = DISGUISE_SYS.getAllTargetCharacters()
	for _, it in ipairs(DISGUISE_SYS.UgcItems) do
		local id = type(it) == "number" and it or (it and it.AssetId)
		if id then
			for _, target in ipairs(targets) do
				if target and target.Parent then
					local acc = target:FindFirstChild("Astrocyna_Disguise_UGC_" .. tostring(id))
					if acc then pcall(function() acc:Destroy() end) end
				end
			end
		end
	end
	table.clear(DISGUISE_SYS.UgcItems)
	table.clear(DISGUISE_SYS.UgcAssetIds)
end

function DISGUISE_SYS.setUgcList(itemsArray)
	if type(itemsArray) ~= "table" then return end
	DISGUISE_SYS.clearUgc()
	for _, it in ipairs(itemsArray) do
		DISGUISE_SYS.addUgc(it)
	end
end

function DISGUISE_SYS.loadUgcAccessoryTemplate(itemOrId)
	local item = (type(itemOrId) == "table" and itemOrId) or DISGUISE_SYS.getItemConfig(itemOrId)
	local assetId = (item and item.AssetId) or tonumber(itemOrId)
	if not assetId then return nil end

	if DISGUISE_SYS.cachedUgcTemplates[assetId] then
		return DISGUISE_SYS.cachedUgcTemplates[assetId]
	end

	local numId = tonumber(assetId)

	-- If assetId is 0 or negative or invalid, skip network requests completely and build instant fallback
	if not numId or numId <= 0 then
		local fallbackAcc = Instance.new("Accessory")
		fallbackAcc.Name = "Astrocyna_Disguise_UGC_" .. tostring(assetId)
		fallbackAcc:SetAttribute("AstrocynaDisguise", true)
		if item and item.AccessoryType then
			fallbackAcc.AccessoryType = item.AccessoryType
		end

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Anchored = false
		handle.Transparency = 0
		handle.Parent = fallbackAcc

		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "Mesh"
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = (item and item.MeshId) or ""
		mesh.TextureId = (item and item.TextureId) or ""
		mesh.Scale = (item and item.Scale) or Vector3.new(1, 1, 1)
		mesh.Parent = handle

		local att = Instance.new("Attachment")
		att.Name = (item and item.Attachment) or "HatAttachment"
		att.CFrame = (item and item.C0) or CFrame.new(0, 0, 0)
		att.Parent = handle

		if item and item.Aliases then
			for _, aliasName in ipairs(item.Aliases) do
				local aliasAtt = Instance.new("Attachment")
				aliasAtt.Name = aliasName
				aliasAtt.CFrame = att.CFrame
				aliasAtt.Parent = handle
			end
		end

		DISGUISE_SYS.cachedUgcTemplates[assetId] = fallbackAcc
		return fallbackAcc
	end

	local assetUri = "rbxassetid://" .. tostring(assetId)
	local rawUri = "http://www.roblox.com/asset/?id=" .. tostring(assetId)
	local objs = nil

	-- 1. Try getobjects global
	if typeof(getobjects) == "function" then
		pcall(function()
			objs = getobjects(assetUri)
		end)
		if not objs or #objs == 0 then
			pcall(function()
				objs = getobjects(rawUri)
			end)
		end
	end

	-- 2. Try game.GetObjects
	if not objs or #objs == 0 then
		local getObjs = (game and game.GetObjects)
		if getObjs then
			pcall(function()
				objs = getObjs(game, assetUri)
			end)
			if not objs or #objs == 0 then
				pcall(function()
					objs = getObjs(game, rawUri)
				end)
			end
		end
	end

	-- 3. Try InsertService:LoadLocalAsset
	if not objs or #objs == 0 then
		pcall(function()
			local itemInstance = game:GetService("InsertService"):LoadLocalAsset(assetUri)
			if itemInstance then objs = { itemInstance } end
		end)
	end

	-- 4. Try InsertService:LoadAsset
	if (not objs or #objs == 0) and numId and numId > 0 then
		pcall(function()
			local model = game:GetService("InsertService"):LoadAsset(numId)
			if model then objs = { model } end
		end)
	end

	-- Extract Accessory from loaded objects
	if objs and type(objs) == "table" and #objs > 0 then
		for _, root in ipairs(objs) do
			if root:IsA("Accessory") then
				DISGUISE_SYS.cachedUgcTemplates[assetId] = root
				return root
			end
			local acc = root:FindFirstChildOfClass("Accessory") or root:FindFirstChildWhichIsA("Accessory", true)
			if acc then
				DISGUISE_SYS.cachedUgcTemplates[assetId] = acc
				return acc
			end
			local handle = root:FindFirstChild("Handle") or root:FindFirstChildWhichIsA("BasePart", true)
			if handle and handle:IsA("BasePart") then
				local newAcc = Instance.new("Accessory")
				newAcc.Name = "Astrocyna_Disguise_UGC_" .. tostring(assetId)
				handle.Name = "Handle"
				handle.Parent = newAcc
				DISGUISE_SYS.cachedUgcTemplates[assetId] = newAcc
				return newAcc
			end
		end
	end

	-- 5. Fallback SpecialMesh Accessory generator using item config
	local fallbackAcc = Instance.new("Accessory")
	fallbackAcc.Name = "Astrocyna_Disguise_UGC_" .. tostring(assetId)
	fallbackAcc:SetAttribute("AstrocynaDisguise", true)
	if item and item.AccessoryType then
		fallbackAcc.AccessoryType = item.AccessoryType
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Anchored = false
	handle.Transparency = 0
	handle.Parent = fallbackAcc

	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "Mesh"
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = (item and item.MeshId) or assetUri
	mesh.TextureId = (item and item.TextureId) or assetUri
	mesh.Scale = (item and item.Scale) or Vector3.new(1, 1, 1)
	mesh.Parent = handle

	local att = Instance.new("Attachment")
	att.Name = (item and item.Attachment) or "HatAttachment"
	att.CFrame = (item and item.C0) or CFrame.new(0, 0, 0)
	att.Parent = handle

	if item and item.Aliases then
		for _, aliasName in ipairs(item.Aliases) do
			local aliasAtt = Instance.new("Attachment")
			aliasAtt.Name = aliasName
			aliasAtt.CFrame = att.CFrame
			aliasAtt.Parent = handle
		end
	end

	DISGUISE_SYS.cachedUgcTemplates[assetId] = fallbackAcc
	return fallbackAcc
end

function DISGUISE_SYS.isAstrocynaNameTag(gui)
	if not gui then return false end
	if gui:GetAttribute("AstrocynaWatermark") or gui:GetAttribute("AstrocynaDisguise") or gui:GetAttribute("AstrocynaProtected") then
		return true
	end
	local name = string.lower(gui.Name)
	if string.find(name, "astrocyna") or string.find(name, "watermark") or string.find(name, "esp") then
		return true
	end
	-- Fast parent check (max 3 levels up, zero GetDescendants to eliminate O(N^2) stutter)
	local p = gui.Parent
	local depth = 0
	while p and p ~= game and depth < 3 do
		depth = depth + 1
		local pName = string.lower(p.Name)
		if string.find(pName, "astrocyna") or string.find(pName, "watermark") or string.find(pName, "esp") then
			return true
		end
		if p:IsA("Model") or p:IsA("Workspace") then
			break
		end
		p = p.Parent
	end
	return false
end

function DISGUISE_SYS.updateWatermarkSpyName(isSpy)
	local targets = DISGUISE_SYS.getAllTargetCharacters()
	if #targets == 0 and player.Character then
		table.insert(targets, player.Character)
	end

	local originalName = tostring(player.DisplayName or player.Name)
	local targetText = isSpy and "<i>「 ✦ SPY ✦ 」</i>" or ("<i>" .. originalName .. "</i>")

	for _, target in ipairs(targets) do
		if target and target.Parent then
			local head = target:FindFirstChild("Head")
			local allGuis = {}
			if head then
				for _, c in ipairs(head:GetChildren()) do
					if c.Name == "AstrocynaWatermarkGui" then
						table.insert(allGuis, c)
					end
				end
			end
			for _, c in ipairs(target:GetChildren()) do
				if c.Name == "AstrocynaWatermarkGui" and c.Parent ~= head then
					table.insert(allGuis, c)
				end
			end

			-- 🛡️ Anti-duplicate: หากพบว่ามี Watermark มากกว่า 1 ตัว ให้ทำลายตัวเก่าทิ้งทันที เหลือเฉพาะตัวล่าสุด
			if #allGuis > 1 then
				for i = 1, #allGuis - 1 do
					pcall(function() allGuis[i]:Destroy() end)
				end
			end
			local wmGui = allGuis[#allGuis]

			if wmGui then
				local wmEnabled = (getgenv().AstrocynaWatermarkEnabled ~= false)
				if wmGui:IsA("BillboardGui") then
					wmGui.Enabled = wmEnabled
				end
				local mainFrame = wmGui:FindFirstChild("MainFrame")
				if mainFrame then
					mainFrame.Visible = wmEnabled
				end

				-- Update SubtitleContainer if present
				local subContainer = wmGui:FindFirstChild("SubtitleContainer", true)
				if subContainer then
					for _, child in ipairs(subContainer:GetChildren()) do
						if child:IsA("TextLabel") then
							if not child.RichText then
								child.RichText = true
							end
							if child.Text ~= targetText then
								child.Text = targetText
							end
							if not child.Visible then
								child.Visible = true
							end
						end
					end
				else
					local subLabel = wmGui:FindFirstChild("Subtitle", true)
					local subShadow = wmGui:FindFirstChild("SubtitleShadow", true)

					if subLabel and subLabel:IsA("TextLabel") then
						if not subLabel.RichText then subLabel.RichText = true end
						if subLabel.Text ~= targetText then
							subLabel.Text = targetText
						end
						if not subLabel.Visible then
							subLabel.Visible = true
						end
					end
					if subShadow and subShadow:IsA("TextLabel") then
						if not subShadow.RichText then subShadow.RichText = true end
						if subShadow.Text ~= targetText then
							subShadow.Text = targetText
						end
						if not subShadow.Visible then
							subShadow.Visible = true
						end
					end
				end
			end
		end
	end
end

function DISGUISE_SYS.getAllTargetCharacters()
	local targets = {}
	local wsPlayers = workspace:FindFirstChild("Players")
	if wsPlayers then
		local found = wsPlayers:FindFirstChild(player.Name)
		if found and found:IsA("Model") then
			table.insert(targets, found)
		end
	end
	if player.Character and player.Character.Parent then
		local already = false
		for _, t in ipairs(targets) do
			if t == player.Character then already = true; break end
		end
		if not already then
			table.insert(targets, player.Character)
		end
	end
	return targets
end

function DISGUISE_SYS.removeFixedInHead(char)
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end

	for _, child in ipairs(head:GetChildren()) do
		if string.lower(child.Name) == "fixed" then
			if not DISGUISE_SYS.savedFixedClones[head] then
				pcall(function()
					DISGUISE_SYS.savedFixedClones[head] = child:Clone()
				end)
			end
			pcall(function()
				child:Destroy()
			end)
		end
	end

	for _, desc in ipairs(head:GetDescendants()) do
		if string.lower(desc.Name) == "fixed" then
			pcall(function()
				desc:Destroy()
			end)
		end
	end

	-- Also hide any classic and dynamic Face decals on Head
	for _, desc in ipairs(head:GetDescendants()) do
		if desc:IsA("Decal") then
			if DISGUISE_SYS.savedMeshTransparencies[desc] == nil then
				DISGUISE_SYS.savedMeshTransparencies[desc] = desc.Transparency
			end
			desc.Transparency = 1
		end
		if desc:IsA("FaceControls") then
			if DISGUISE_SYS.savedMeshTransparencies[desc] == nil then
				DISGUISE_SYS.savedMeshTransparencies[desc] = desc.Enabled and 1 or 0
			end
			desc.Enabled = false
		end
	end
end

function DISGUISE_SYS.hideHairAndFacialHair(char)
	if not char then return end
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("BasePart") then
			local pName = string.lower(desc.Name)
			local isMatch = (pName == "facialhair") or (pName == "hair")
				or string.find(pName, "facialhair") or string.find(pName, "hair")
				or string.find(pName, "beard") or string.find(pName, "mustache")

			local parentAcc = desc:FindFirstAncestorOfClass("Accessory")
			if parentAcc and not parentAcc:GetAttribute("AstrocynaDisguise") then
				local aName = string.lower(parentAcc.Name)
				if aName == "facialhair" or aName == "hair" or string.find(aName, "facialhair") or string.find(aName, "hair") or string.find(aName, "beard") then
					isMatch = true
				end
				pcall(function()
					if parentAcc.AccessoryType == Enum.AccessoryType.Hair or parentAcc.AccessoryType == Enum.AccessoryType.Face then
						isMatch = true
					end
				end)
			end

			if isMatch then
				if DISGUISE_SYS.savedMeshTransparencies[desc] == nil then
					DISGUISE_SYS.savedMeshTransparencies[desc] = desc.Transparency
				end
				if desc.Transparency < 1 then
					desc.Transparency = 1
				end
			end
		end
	end
end

function DISGUISE_SYS.applyUgcAccessories(char)
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not head then return end

	-- Clean up dead/orphaned references
	for i = #DISGUISE_SYS.addedAccessories, 1, -1 do
		local a = DISGUISE_SYS.addedAccessories[i]
		if not a or not a.Parent or a.Parent ~= char then
			table.remove(DISGUISE_SYS.addedAccessories, i)
		end
	end

	for _, rawItem in ipairs(DISGUISE_SYS.UgcItems) do
		local item = DISGUISE_SYS.normalizeItem(rawItem)
		local ugcId = item.AssetId
		if ugcId then
			local accName = "Astrocyna_Disguise_UGC_" .. tostring(ugcId)
			local existing = char:FindFirstChild(accName)

			-- Determine target part (Head vs Torso)
			local targetPart = (item.TargetPart == "Torso" and (torso or head)) or head

			-- Ensure target attachment exists on character part
			local primaryAttName = item.Attachment or "HatAttachment"
			local targetAtt = targetPart:FindFirstChild(primaryAttName)
			if not targetAtt then
				targetAtt = Instance.new("Attachment")
				targetAtt.Name = primaryAttName
				targetAtt.CFrame = item.C1 or CFrame.new(0, 0.6, 0)
				targetAtt.Parent = targetPart
			else
				-- Update CFrame if calibrated C1 is provided
				if item.C1 then
					targetAtt.CFrame = item.C1
				end
			end

			-- Ensure alias attachments on target part if specified
			if item.Aliases then
				for _, aliasName in ipairs(item.Aliases) do
					if not targetPart:FindFirstChild(aliasName) then
						local alias = Instance.new("Attachment")
						alias.Name = aliasName
						alias.CFrame = targetAtt.CFrame
						alias.Parent = targetPart
					end
				end
			end

			-- Verify if existing accessory is actually attached with an active weld
			local isAlreadyWelded = false
			if existing then
				local h = existing:FindFirstChild("Handle") or existing:FindFirstChildWhichIsA("BasePart", true)
				if h then
					for _, w in ipairs(h:GetChildren()) do
						if (w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D")) and w.Part1 and w.Part1:IsDescendantOf(char) then
							isAlreadyWelded = true
							-- Sync C1 if updated in code
							if w:IsA("Weld") and item.C1 then
								w.C1 = item.C1
							end
							break
						end
					end
				end
				if not isAlreadyWelded then
					pcall(function() existing:Destroy() end)
					existing = nil
				end
			end

			if not isAlreadyWelded then
				local template = DISGUISE_SYS.loadUgcAccessoryTemplate(item)
				if template then
					local acc = template:Clone()
					acc.Name = accName
					acc:SetAttribute("AstrocynaDisguise", true)

					local handle = acc:FindFirstChild("Handle") or acc:FindFirstChildWhichIsA("BasePart", true)
					if handle and handle:IsA("BasePart") then
						handle.Name = "Handle"
						handle.CanCollide = false
						handle.CanTouch = false
						handle.CanQuery = false
						handle.Massless = true
						handle.Anchored = false
						handle.CastShadow = false
						handle.Transparency = 0

						local defaultC0 = item.C0 or CFrame.new(0, 0, 0)
						local defaultC1 = item.C1 or CFrame.new(0, 0.6, 0)

						local handleAtt = handle:FindFirstChild(primaryAttName) or handle:FindFirstChildOfClass("Attachment")
						if not handleAtt then
							handleAtt = Instance.new("Attachment")
							handleAtt.Name = primaryAttName
							handleAtt.CFrame = defaultC0
							handleAtt.Parent = handle
						end

						if item.Aliases then
							for _, aliasName in ipairs(item.Aliases) do
								if not handle:FindFirstChild(aliasName) then
									local alias = Instance.new("Attachment")
									alias.Name = aliasName
									alias.CFrame = handleAtt.CFrame
									alias.Parent = handle
								end
							end
						end

						-- 1. Try native Humanoid:AddAccessory first
						local attached = false
						if humanoid then
							pcall(function()
								humanoid:AddAccessory(acc)
							end)
							if acc.Parent == char then
								for _, child in ipairs(handle:GetChildren()) do
									if (child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D")) and child.Part1 and child.Part1:IsDescendantOf(char) then
										attached = true
										break
									end
								end
							end
						end

						-- 2. If Humanoid:AddAccessory didn't create an active weld, attach manually
						if not attached or acc.Parent ~= char then
							acc.Parent = char

							for _, child in ipairs(handle:GetChildren()) do
								if child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D") then
									if not child.Part1 or not child.Part1:IsDescendantOf(char) then
										pcall(function() child:Destroy() end)
									else
										attached = true
									end
								end
							end

							if not attached and targetPart then
								local actualTargetAtt = targetPart:FindFirstChild(handleAtt.Name) or targetPart:FindFirstChild(primaryAttName) or targetAtt

								local weld = Instance.new("Weld")
								weld.Name = "AccessoryWeld"
								weld.Part0 = handle
								weld.Part1 = targetPart

								local finalC0 = (handleAtt and handleAtt.CFrame) or defaultC0
								local finalC1 = (actualTargetAtt and actualTargetAtt.CFrame) or defaultC1

								weld.C0 = finalC0
								weld.C1 = finalC1
								weld.Parent = handle
								attached = true
							end
						end

						table.insert(DISGUISE_SYS.addedAccessories, acc)
					end
				end
			end
		end
	end
end

function DISGUISE_SYS.disableGuiObject(gui)
	if not gui then return end
	if DISGUISE_SYS.isAstrocynaNameTag(gui) then return end

	local saved = DISGUISE_SYS.disabledNativeObjects[gui]
	if not saved then
		saved = {}
		DISGUISE_SYS.disabledNativeObjects[gui] = saved
	end

	if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") or gui:IsA("ScreenGui") then
		if saved.origEnabled == nil then
			saved.origEnabled = gui.Enabled
		end
		if gui.Enabled then
			gui.Enabled = false
		end
	end

	if gui:IsA("GuiObject") then
		if saved.origVisible == nil then
			saved.origVisible = gui.Visible
		end
		if gui.Visible then
			gui.Visible = false
		end
	end

	if gui:IsA("BasePart") then
		if saved.origTransparency == nil then
			saved.origTransparency = gui.Transparency
		end
		if gui.Transparency < 1 then
			gui.Transparency = 1
		end
	end
end

function DISGUISE_SYS.disableTreeGuis(root)
	if not root then return end
	if DISGUISE_SYS.isAstrocynaNameTag(root) then return end
	DISGUISE_SYS.disableGuiObject(root)
	for _, desc in ipairs(root:GetDescendants()) do
		local dName = string.lower(desc.Name)
		if not (string.find(dName, "astrocyna") or string.find(dName, "watermark") or string.find(dName, "esp")) then
			if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("ScreenGui") or desc:IsA("GuiObject") or desc:IsA("BasePart") then
				DISGUISE_SYS.disableGuiObject(desc)
			end
		end
	end
end

function DISGUISE_SYS.enableGuiObject(gui)
	if not gui then return end
	if DISGUISE_SYS.isAstrocynaNameTag(gui) then return end

	local saved = DISGUISE_SYS.disabledNativeObjects[gui]

	if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") or gui:IsA("ScreenGui") then
		gui.Enabled = (saved and saved.origEnabled ~= nil) and saved.origEnabled or true
	end

	if gui:IsA("GuiObject") then
		gui.Visible = (saved and saved.origVisible ~= nil) and saved.origVisible or true
	end

	if gui:IsA("BasePart") then
		if saved and saved.origTransparency ~= nil then
			gui.Transparency = saved.origTransparency
		end
	end

	if gui:IsA("ParticleEmitter") then
		gui.Enabled = true
	end
end

function DISGUISE_SYS.enableTreeGuis(root)
	if not root then return end
	if DISGUISE_SYS.isAstrocynaNameTag(root) then return end
	DISGUISE_SYS.enableGuiObject(root)
	for _, desc in ipairs(root:GetDescendants()) do
		if not DISGUISE_SYS.isAstrocynaNameTag(desc) then
			DISGUISE_SYS.enableGuiObject(desc)
		end
	end
end

function DISGUISE_SYS.isPeerScriptUser(p)
	if not p then return false end
	if p == player then return true end
	local pChar = p.Character or (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(p.Name))
	if pChar then
		local head = pChar:FindFirstChild("Head")
		if (head and head:FindFirstChild("AstrocynaWatermarkGui")) or pChar:FindFirstChild("AstrocynaWatermarkGui") then
			return true
		end
	end
	return false
end

function DISGUISE_SYS.hideNativeNameTag(targetInput)
	local targets = {}
	local plrs = {}

	if typeof(targetInput) == "Instance" then
		if targetInput:IsA("Player") then
			table.insert(plrs, targetInput)
			local c = targetInput.Character or (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(targetInput.Name))
			if c and c.Parent then
				table.insert(targets, c)
			end
		elseif targetInput:IsA("Model") then
			table.insert(targets, targetInput)
			local pObj = Players:GetPlayerFromCharacter(targetInput) or Players:FindFirstChild(targetInput.Name)
			if pObj then
				table.insert(plrs, pObj)
			end
		end
	else
		-- When called with nil, process local player (if watermark active) AND all script users / peers
		local s = getgenv().AstrocynaWatermarkSettings
		local wmOn = (s and s.Enabled ~= false) and (getgenv().AstrocynaWatermarkEnabled ~= false)
		if wmOn then
			table.insert(plrs, player)
			for _, c in ipairs(DISGUISE_SYS.getAllTargetCharacters()) do
				table.insert(targets, c)
			end
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and DISGUISE_SYS.isPeerScriptUser(p) then
				table.insert(plrs, p)
				local pChar = p.Character or (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(p.Name))
				if pChar and pChar.Parent then
					local already = false
					for _, tc in ipairs(targets) do
						if tc == pChar then already = true; break end
					end
					if not already then table.insert(targets, pChar) end
				end
			end
		end
	end

	-- 1. Humanoid display distance and overhead guis on target characters
	for _, target in ipairs(targets) do
		if target and target.Parent then
			local hum = target:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				hum.NameDisplayDistance = 0
				hum.HealthDisplayDistance = 0
			end

			-- Direct check for Visuals folder inside character
			local cVis = target:FindFirstChild("Visuals")
			if cVis then
				DISGUISE_SYS.disableTreeGuis(cVis)
			end

			-- Overhead GUIs directly on Head (excluding Astrocyna watermark & ESP)
			local head = target:FindFirstChild("Head")
			if head then
				for _, c in ipairs(head:GetChildren()) do
					if c:IsA("BillboardGui") or c:IsA("SurfaceGui") then
						if not DISGUISE_SYS.isAstrocynaNameTag(c) then
							DISGUISE_SYS.disableTreeGuis(c)
						end
					end
				end
			end

			-- Disable NameTagMotor in Torso/UpperTorso so native nametag stops following character
			for _, partName in ipairs({ "Torso", "UpperTorso", "HumanoidRootPart" }) do
				local pPart = target:FindFirstChild(partName)
				if pPart then
					for _, motor in ipairs(pPart:GetChildren()) do
						if motor:IsA("Motor6D") and (motor.Name == "NameTagMotor" or string.find(motor.Name, "NameTag")) then
							motor.Enabled = false
						end
					end
				end
			end
		end
	end

	-- 2. Fast direct lookup in workspace.Visuals for each target player
	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals and wsVisuals:IsA("Folder") then
		for _, targetPlr in ipairs(plrs) do
			local direct = wsVisuals:FindFirstChild(targetPlr.Name)
				or wsVisuals:FindFirstChild(targetPlr.DisplayName)
				or wsVisuals:FindFirstChild(tostring(targetPlr.UserId))
			if direct then
				DISGUISE_SYS.disableTreeGuis(direct)
				-- Ensure SurfaceGui stays disabled if game loop sets Enabled = true
				local sg = direct:FindFirstChildOfClass("SurfaceGui")
				if sg and not sg:GetAttribute("AstrocynaHideHooked") then
					sg:SetAttribute("AstrocynaHideHooked", true)
					sg:GetPropertyChangedSignal("Enabled"):Connect(function()
						if sg.Enabled then
							sg.Enabled = false
						end
					end)
				end
			end
		end

		-- Check top-level BillboardGuis/SurfaceGuis with Adornee targeting any target character
		for _, child in ipairs(wsVisuals:GetChildren()) do
			if (child:IsA("BillboardGui") or child:IsA("SurfaceGui")) and not DISGUISE_SYS.isAstrocynaNameTag(child) then
				local ad = child.Adornee
				if ad then
					for _, target in ipairs(targets) do
						if ad == target or ad:IsDescendantOf(target) then
							DISGUISE_SYS.disableTreeGuis(child)
							break
						end
					end
				end
			end
		end
	end

	-- 3. Check PlayerGui for Visuals or NameTags for player
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if pGui then
		local pgVis = pGui:FindFirstChild("Visuals")
		if pgVis then
			DISGUISE_SYS.disableTreeGuis(pgVis)
		end
		local pgTags = pGui:FindFirstChild("NameTags") or pGui:FindFirstChild("Tags")
		if pgTags then
			local directPg = pgTags:FindFirstChild(player.Name) or pgTags:FindFirstChild(player.DisplayName)
			if directPg then
				DISGUISE_SYS.disableTreeGuis(directPg)
			end
		end
	end
end

function DISGUISE_SYS.restoreNativeNameTag(targetInput)
	local targets = {}
	local plrs = {}

	if typeof(targetInput) == "Instance" then
		if targetInput:IsA("Player") then
			table.insert(plrs, targetInput)
			local c = targetInput.Character or (workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(targetInput.Name))
			if c and c.Parent then
				table.insert(targets, c)
			end
		elseif targetInput:IsA("Model") then
			table.insert(targets, targetInput)
			local pObj = Players:GetPlayerFromCharacter(targetInput) or Players:FindFirstChild(targetInput.Name)
			if pObj then
				table.insert(plrs, pObj)
			end
		end
	else
		table.insert(plrs, player)
		for _, c in ipairs(DISGUISE_SYS.getAllTargetCharacters()) do
			table.insert(targets, c)
		end
	end

	-- 1. Restore all tracked objects in disabledNativeObjects table
	for obj, saved in pairs(DISGUISE_SYS.disabledNativeObjects) do
		if obj and obj.Parent then
			pcall(function()
				DISGUISE_SYS.enableGuiObject(obj)
			end)
		end
	end
	table.clear(DISGUISE_SYS.disabledNativeObjects)

	-- 2. Humanoid display distance on target characters
	for _, target in ipairs(targets) do
		if target and target.Parent then
			local hum = target:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
				hum.NameDisplayDistance = 100
				hum.HealthDisplayDistance = 100
			end

			-- Direct check for Visuals folder inside character
			local cVis = target:FindFirstChild("Visuals")
			if cVis then
				DISGUISE_SYS.enableTreeGuis(cVis)
			end

			-- Overhead GUIs directly on Head (excluding Astrocyna watermark & ESP)
			local head = target:FindFirstChild("Head")
			if head then
				for _, c in ipairs(head:GetChildren()) do
					if (c:IsA("BillboardGui") or c:IsA("SurfaceGui")) and not DISGUISE_SYS.isAstrocynaNameTag(c) then
						DISGUISE_SYS.enableTreeGuis(c)
					end
				end
			end

			-- Restore NameTagMotor in Torso/UpperTorso
			for _, partName in ipairs({ "Torso", "UpperTorso", "HumanoidRootPart" }) do
				local pPart = target:FindFirstChild(partName)
				if pPart then
					for _, motor in ipairs(pPart:GetChildren()) do
						if motor:IsA("Motor6D") and (motor.Name == "NameTagMotor" or string.find(motor.Name, "NameTag")) then
							motor.Enabled = true
						end
					end
				end
			end
		end
	end

	-- 3. In workspace.Visuals: Find players' nametag parts and re-enable them completely!
	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals and wsVisuals:IsA("Folder") then
		for _, targetPlr in ipairs(plrs) do
			local direct = wsVisuals:FindFirstChild(targetPlr.Name)
				or wsVisuals:FindFirstChild(targetPlr.DisplayName)
				or wsVisuals:FindFirstChild(tostring(targetPlr.UserId))
			if direct then
				DISGUISE_SYS.enableTreeGuis(direct)
				for _, desc in ipairs(direct:GetDescendants()) do
					if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") then
						desc.Enabled = true
					elseif desc:IsA("GuiObject") then
						desc.Visible = true
					elseif desc:IsA("ParticleEmitter") then
						desc.Enabled = true
					end
				end
			end
		end

		-- Also check any Part with NameTagMotor attached to any target character
		for _, child in ipairs(wsVisuals:GetChildren()) do
			local motor = child:FindFirstChild("NameTagMotor")
			if motor and motor:IsA("Motor6D") and motor.Part0 then
				for _, target in ipairs(targets) do
					if motor.Part0 == target or motor.Part0:IsDescendantOf(target) then
						DISGUISE_SYS.enableTreeGuis(child)
						for _, desc in ipairs(child:GetDescendants()) do
							if desc:IsA("SurfaceGui") or desc:IsA("BillboardGui") then
								desc.Enabled = true
							elseif desc:IsA("GuiObject") then
								desc.Visible = true
							elseif desc:IsA("ParticleEmitter") then
								desc.Enabled = true
							end
						end
						break
					end
				end
			end
		end
	end

	-- 4. Check PlayerGui for Visuals or NameTags
	local pGui = player:FindFirstChildOfClass("PlayerGui")
	if pGui then
		local pgVis = pGui:FindFirstChild("Visuals")
		if pgVis then
			DISGUISE_SYS.enableTreeGuis(pgVis)
		end
		local pgTags = pGui:FindFirstChild("NameTags") or pGui:FindFirstChild("Tags")
		if pgTags then
			local directPg = pgTags:FindFirstChild(player.Name) or pgTags:FindFirstChild(player.DisplayName)
			if directPg then
				DISGUISE_SYS.enableTreeGuis(directPg)
			end
		end
	end
end

function DISGUISE_SYS.syncNametagVisibility(char)
	local s = getgenv().AstrocynaWatermarkSettings
	local isWmOn = (s and s.Enabled ~= false)
	if getgenv().AstrocynaWatermarkEnabled == false then
		isWmOn = false
	end

	if isWmOn then
		DISGUISE_SYS.hideNativeNameTag(char)
	else
		DISGUISE_SYS.restoreNativeNameTag(char)
	end
end

function DISGUISE_SYS.applyDisguise(char, force)
	if not isDisguiseEnabled then return end
	local targets = char and { char } or DISGUISE_SYS.getAllTargetCharacters()

	for _, target in ipairs(targets) do
		if target and target.Parent then
			local alreadyApplied = target:GetAttribute("AstrocynaDisguiseApplied")
			if force or not alreadyApplied then
				target:SetAttribute("AstrocynaDisguiseApplied", true)
				DISGUISE_SYS.removeFixedInHead(target)
				DISGUISE_SYS.hideHairAndFacialHair(target)
				DISGUISE_SYS.applyUgcAccessories(target)
			end

			-- Ensure native nametag is hidden & watermark displays "Spy" (called once cleanly)
			DISGUISE_SYS.hideNativeNameTag(target)
			DISGUISE_SYS.updateWatermarkSpyName(true)
		end
	end
end

function DISGUISE_SYS.restoreDisguise()
	local targets = DISGUISE_SYS.getAllTargetCharacters()

	-- 1. Restore UGC Accessories
	for _, acc in ipairs(DISGUISE_SYS.addedAccessories) do
		if acc and acc.Parent then
			pcall(function() acc:Destroy() end)
		end
	end
	DISGUISE_SYS.addedAccessories = {}

	for _, target in ipairs(targets) do
		if target and target.Parent then
			target:SetAttribute("AstrocynaDisguiseApplied", nil)
			for _, child in ipairs(target:GetChildren()) do
				if child:IsA("Accessory") and (child:GetAttribute("AstrocynaDisguise") or string.find(child.Name, "Astrocyna_Disguise_UGC_")) then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end

	-- 2. Restore "Fixed" in Head if saved
	for head, fixedClone in pairs(DISGUISE_SYS.savedFixedClones) do
		if head and head.Parent and fixedClone then
			if not head:FindFirstChild(fixedClone.Name) then
				pcall(function()
					fixedClone:Clone().Parent = head
				end)
			end
		end
	end
	DISGUISE_SYS.savedFixedClones = {}

	-- 3. Restore Hair, FacialHair and Face transparency
	for part, origTrans in pairs(DISGUISE_SYS.savedMeshTransparencies) do
		if part and part.Parent then
			if part:IsA("FaceControls") then
				pcall(function() part.Enabled = (origTrans == 1) end)
			else
				pcall(function() part.Transparency = origTrans end)
			end
		end
	end
	DISGUISE_SYS.savedMeshTransparencies = {}

	-- 4. Revert Astrocyna watermark back to real player name
	DISGUISE_SYS.updateWatermarkSpyName(false)

	-- 5. Synchronize native nametag visibility with watermark setting
	DISGUISE_SYS.syncNametagVisibility()
end

-- ===================================================================
-- 🏷️ ASTROCYNA WATERMARK COMPREHENSIVE SETTINGS INJECTION
-- ===================================================================
-- Full In-Game Settings -> Nametag configuration system:
-- 1. Visibility & Display (Show/Hide, SPY Subtitle, AlwaysOnTop/ESP, Dual Icons)
-- 2. VFX & Animations (Neon Laser Sweep, Shimmer Wave, Zoom Clamping, Height)
-- 3. Color Themes (Pure Noir, Platinum Silver, Frost Monochrome, Graphite Slate, Onyx Minimal)

local THEME_PRESETS = {
	Noir = {
		Name = "Pure Noir",
		Primary = Color3.fromRGB(255, 255, 255),
		Glow = Color3.fromRGB(220, 220, 225),
		BaseBorder = Color3.fromRGB(36, 36, 40),
		Beam = Color3.fromRGB(200, 200, 205),
		Highlight = Color3.fromRGB(255, 255, 255),
		BgTop = Color3.fromRGB(24, 24, 28),
		BgBottom = Color3.fromRGB(12, 12, 14),
		Rarity = "NOIR",
		Grad1 = Color3.fromRGB(255, 255, 255),
		Grad2 = Color3.fromRGB(180, 180, 185),
	},
	Platinum = {
		Name = "Platinum Silver",
		Primary = Color3.fromRGB(235, 235, 240),
		Glow = Color3.fromRGB(200, 200, 205),
		BaseBorder = Color3.fromRGB(48, 48, 54),
		Beam = Color3.fromRGB(220, 220, 225),
		Highlight = Color3.fromRGB(255, 255, 255),
		BgTop = Color3.fromRGB(30, 30, 34),
		BgBottom = Color3.fromRGB(14, 14, 16),
		Rarity = "PLATINUM",
		Grad1 = Color3.fromRGB(235, 235, 240),
		Grad2 = Color3.fromRGB(160, 160, 165),
	},
	Frost = {
		Name = "Frost Monochrome",
		Primary = Color3.fromRGB(250, 250, 255),
		Glow = Color3.fromRGB(230, 230, 235),
		BaseBorder = Color3.fromRGB(40, 40, 45),
		Beam = Color3.fromRGB(210, 210, 215),
		Highlight = Color3.fromRGB(255, 255, 255),
		BgTop = Color3.fromRGB(26, 26, 30),
		BgBottom = Color3.fromRGB(10, 10, 12),
		Rarity = "FROST",
		Grad1 = Color3.fromRGB(250, 250, 255),
		Grad2 = Color3.fromRGB(190, 190, 195),
	},
	Graphite = {
		Name = "Graphite Slate",
		Primary = Color3.fromRGB(210, 210, 215),
		Glow = Color3.fromRGB(175, 175, 180),
		BaseBorder = Color3.fromRGB(44, 44, 48),
		Beam = Color3.fromRGB(170, 170, 175),
		Highlight = Color3.fromRGB(240, 240, 245),
		BgTop = Color3.fromRGB(28, 28, 32),
		BgBottom = Color3.fromRGB(16, 16, 18),
		Rarity = "GRAPHITE",
		Grad1 = Color3.fromRGB(210, 210, 215),
		Grad2 = Color3.fromRGB(140, 140, 145),
	},
	Onyx = {
		Name = "Onyx Minimal",
		Primary = Color3.fromRGB(245, 245, 250),
		Glow = Color3.fromRGB(190, 190, 195),
		BaseBorder = Color3.fromRGB(32, 32, 36),
		Beam = Color3.fromRGB(160, 160, 165),
		Highlight = Color3.fromRGB(255, 255, 255),
		BgTop = Color3.fromRGB(20, 20, 22),
		BgBottom = Color3.fromRGB(8, 8, 10),
		Rarity = "ONYX",
		Grad1 = Color3.fromRGB(245, 245, 250),
		Grad2 = Color3.fromRGB(120, 120, 125),
	},
}

getgenv().AstrocynaWatermarkSettings = getgenv().AstrocynaWatermarkSettings or {
	Enabled = true,
	SpyMode = true,
	AlwaysOnTop = true,
	ShowIcons = true,
	BorderLaser = true,
	TextShimmer = true,
	DynamicScale = true,
	HeightLevel = "Standard", -- "Standard" (1.5), "High" (2.5), "Compact" (0.8)
	ColorTheme = "Noir",
}

-- Backward compatibility alias
getgenv().AstrocynaWatermarkEnabled = getgenv().AstrocynaWatermarkSettings.Enabled

local SETTINGS_NAMETAG_SYS = {
	isWatermarkTabActive = false,
	injectedChip = nil,
	sections = {},
	cardRefs = {},
}

function SETTINGS_NAMETAG_SYS.applyWatermarkSettings(wmGui)
	if not wmGui or not wmGui.Parent then return end
	local s = getgenv().AstrocynaWatermarkSettings

	-- 1. Visibility
	local isVis = (s.Enabled ~= false)
	getgenv().AstrocynaWatermarkEnabled = isVis
	if wmGui:IsA("BillboardGui") then
		wmGui.Enabled = isVis
	end
	local mainFrame = wmGui:FindFirstChild("MainFrame")
	if mainFrame then
		mainFrame.Visible = isVis
	end

	-- 2. AlwaysOnTop
	if wmGui:IsA("BillboardGui") then
		wmGui.AlwaysOnTop = (s.AlwaysOnTop ~= false)
	end

	-- 3. Height Offset
	local yOffset = 1.5
	if s.HeightLevel == "High" then
		yOffset = 2.5
	elseif s.HeightLevel == "Compact" then
		yOffset = 0.8
	end
	if wmGui:IsA("BillboardGui") then
		wmGui.StudsOffset = Vector3.new(0, yOffset, 0)
	end

	if mainFrame then
		local theme = THEME_PRESETS[s.ColorTheme] or THEME_PRESETS.Noir

		-- 4. Background & Frame Styling
		mainFrame.BackgroundColor3 = theme.BgBottom
		local bgGrad = mainFrame:FindFirstChildOfClass("UIGradient")
		if bgGrad then
			bgGrad.Color = ColorSequence.new(theme.BgTop, theme.BgBottom)
		end

		-- 5. Icons
		local leftIcon = mainFrame:FindFirstChild("LeftIcon")
		local rightIcon = mainFrame:FindFirstChild("RightIcon")
		if leftIcon then
			leftIcon.Visible = (s.ShowIcons ~= false)
			leftIcon.ImageColor3 = theme.Primary
		end
		if rightIcon then
			rightIcon.Visible = (s.ShowIcons ~= false)
			rightIcon.ImageColor3 = theme.Primary
		end

		-- 6. Border Laser Animation
		local uiStroke = mainFrame:FindFirstChild("UIStroke")
		if uiStroke then
			uiStroke.Color = theme.Beam
			local strokeGrad = uiStroke:FindFirstChildOfClass("UIGradient")
			if strokeGrad then
				strokeGrad.Enabled = (s.BorderLaser ~= false)
				strokeGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, theme.BaseBorder),
					ColorSequenceKeypoint.new(0.18, theme.Beam),
					ColorSequenceKeypoint.new(0.22, theme.Highlight),
					ColorSequenceKeypoint.new(0.26, theme.Beam),
					ColorSequenceKeypoint.new(0.45, theme.BaseBorder),
					ColorSequenceKeypoint.new(0.68, theme.Beam),
					ColorSequenceKeypoint.new(0.72, theme.Highlight),
					ColorSequenceKeypoint.new(0.76, theme.Beam),
					ColorSequenceKeypoint.new(1.0, theme.BaseBorder)
				})
			end
		end

		-- 7. Dynamic Scale
		local uiScale = mainFrame:FindFirstChild("UIScale")
		if uiScale and s.DynamicScale == false then
			uiScale.Scale = 1.0
		end

		-- 8. Text Elements & Shimmer Wave
		local textContainer = mainFrame:FindFirstChild("TextContainer")
		if textContainer then
			local nameContainer = textContainer:FindFirstChild("NameContainer")
			local customName = nameContainer and nameContainer:FindFirstChild("CustomName")
			local nameShadow = nameContainer and nameContainer:FindFirstChild("NameShadow")

			if customName then
				customName.TextColor3 = theme.Primary
				local textGrad = customName:FindFirstChild("TextAnimationGradient")
				if textGrad then
					textGrad.Enabled = (s.TextShimmer ~= false)
					textGrad.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0.0, theme.BaseBorder),
						ColorSequenceKeypoint.new(0.35, theme.Glow),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(0.65, theme.Glow),
						ColorSequenceKeypoint.new(1.0, theme.BaseBorder)
					})
				end
			end

			if nameShadow and nameShadow:IsA("TextLabel") then
				nameShadow.TextColor3 = Color3.fromRGB(5, 5, 6)
			end

			local subContainer = textContainer:FindFirstChild("SubtitleContainer")
			if subContainer then
				local subLabel = subContainer:FindFirstChild("Subtitle")
				local subShadow = subContainer:FindFirstChild("SubtitleShadow")
				if subLabel and subLabel:IsA("TextLabel") then
					subLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
				end
				if subShadow and subShadow:IsA("TextLabel") then
					subShadow.TextColor3 = Color3.fromRGB(5, 5, 6)
				end
			end
		end
	end
end

function SETTINGS_NAMETAG_SYS.applyToCurrentCharacter()
	local char = player.Character
	if char then
		local head = char:FindFirstChild("Head")
		local wmGui = (head and head:FindFirstChild("AstrocynaWatermarkGui"))
			or char:FindFirstChild("AstrocynaWatermarkGui", true)
		if wmGui then
			SETTINGS_NAMETAG_SYS.applyWatermarkSettings(wmGui)
		end
	end
	if DISGUISE_SYS and DISGUISE_SYS.syncNametagVisibility then
		DISGUISE_SYS.syncNametagVisibility()
	end
	if DISGUISE_SYS and DISGUISE_SYS.updateWatermarkSpyName then
		local s = getgenv().AstrocynaWatermarkSettings
		DISGUISE_SYS.updateWatermarkSpyName(s.SpyMode)
	end
end

function SETTINGS_NAMETAG_SYS.findNametagPage()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	local homeGui = playerGui:FindFirstChild("HomeGui")
	if homeGui then
		local container = homeGui:FindFirstChild("Container")
		local pages = container and container:FindFirstChild("Pages")
		local settings = pages and pages:FindFirstChild("Settings")
		local window = settings and settings:FindFirstChild("Window")
		local sPages = window and window:FindFirstChild("Pages")
		local nametag = sPages and sPages:FindFirstChild("Nametag")
		if nametag and nametag:FindFirstChild("Main") then
			return nametag
		end
	end
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if desc.Name == "Nametag" and desc:FindFirstChild("Main") and desc:FindFirstChild("Templates") then
			return desc
		end
	end
	return nil
end

function SETTINGS_NAMETAG_SYS.updateAllCardsUI()
	local s = getgenv().AstrocynaWatermarkSettings
	local refs = SETTINGS_NAMETAG_SYS.cardRefs

	local function setCardState(card, active, metaText, metaColor, activeStrokeColor)
		if not card or not card.Parent then return end
		local check = card:FindFirstChild("Check")
		local stroke = card:FindFirstChild("Stroke")
		local meta = card:FindFirstChild("Meta")
		if check then check.Visible = active end
		if stroke then
			stroke.Transparency = active and 0 or 1
			stroke.Color = activeStrokeColor or Color3.fromRGB(255, 255, 255)
			stroke.Thickness = 1.5
		end
		if meta then
			meta.Text = metaText
			meta.TextColor3 = metaColor or (active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 185))
		end
		card.BackgroundTransparency = active and 0.4 or 0.72
	end

	-- Section 1 Cards
	setCardState(
		refs.wmToggle,
		s.Enabled,
		s.Enabled and "● SHOWN · Overhead HUD Watermark (Click to Hide)" or "○ HIDDEN · Overhead HUD Watermark (Click to Show)",
		s.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 185)
	)

	setCardState(
		refs.spyToggle,
		s.SpyMode,
		s.SpyMode and "● ACTIVE · 『 SPY 』 Subtitle Tag (Click to Real Name)" or "○ INACTIVE · Real Username Subtitle (Click to SPY)",
		s.SpyMode and Color3.fromRGB(235, 235, 240) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(255, 255, 255)
	)

	setCardState(
		refs.espToggle,
		s.AlwaysOnTop,
		s.AlwaysOnTop and "● ALWAYS ON TOP · X-Ray Wall Penetration" or "○ OCCLUDED · Blocked by Walls (Normal)",
		s.AlwaysOnTop and Color3.fromRGB(230, 230, 235) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(255, 255, 255)
	)

	setCardState(
		refs.iconsToggle,
		s.ShowIcons,
		s.ShowIcons and "● VISIBLE · Left & Right Emblem Badges" or "○ HIDDEN · Text-Only Minimalist Tag",
		s.ShowIcons and Color3.fromRGB(225, 225, 230) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(255, 255, 255)
	)

	-- Section 2 Cards
	setCardState(
		refs.laserToggle,
		s.BorderLaser,
		s.BorderLaser and "● ACTIVE · 360° Neon Laser Sweep Border" or "○ STATIC · Solid Static Border",
		s.BorderLaser and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(0, 215, 255)
	)

	setCardState(
		refs.shimmerToggle,
		s.TextShimmer,
		s.TextShimmer and "● ACTIVE · Text Shimmer Wave Animation" or "○ STATIC · Solid Clean Typography",
		s.TextShimmer and Color3.fromRGB(235, 235, 240) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(255, 255, 255)
	)

	setCardState(
		refs.scaleToggle,
		s.DynamicScale,
		s.DynamicScale and "● ACTIVE · Responsive Distance Auto-Scale" or "○ FIXED · Constant 1.0x Fixed Scale",
		s.DynamicScale and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(180, 180, 185),
		Color3.fromRGB(255, 255, 255)
	)

	setCardState(
		refs.heightToggle,
		true,
		string.format("● LEVEL: %s (%s studs) · Click to Cycle", s.HeightLevel, s.HeightLevel == "High" and "2.5" or (s.HeightLevel == "Compact" and "0.8" or "1.5")),
		Color3.fromRGB(250, 250, 255),
		Color3.fromRGB(255, 255, 255)
	)

	-- Section 3 Color Theme Cards
	for themeKey, card in pairs(refs.themes or {}) do
		local isCurTheme = (s.ColorTheme == themeKey)
		local tData = THEME_PRESETS[themeKey]
		setCardState(
			card,
			isCurTheme,
			isCurTheme and string.format("● EQUIPPED · %s Palette", tData.Name) or string.format("○ SELECT · %s Palette", tData.Name),
			isCurTheme and tData.Primary or Color3.fromRGB(180, 180, 185),
			tData.Primary
		)
	end
end

function SETTINGS_NAMETAG_SYS.createSection(nametagPage, secName, titleText, descText)
	local templates = nametagPage:FindFirstChild("Templates")
	local secTemplate = templates and templates:FindFirstChild("Section")
	if not secTemplate then return nil end

	local section = secTemplate:Clone()
	section.Name = secName
	section.Visible = true

	local header = section:FindFirstChild("Header")
	if header then
		local title = header:FindFirstChild("Title")
		local count = header:FindFirstChild("Count")
		local desc = header:FindFirstChild("Desc")
		if title then title.Text = titleText end
		if count then count.Text = "" end
		if desc then desc.Text = descText end
	end

	local grid = section:FindFirstChild("Grid")
	if grid then
		for _, ch in ipairs(grid:GetChildren()) do
			if ch:IsA("GuiObject") and ch.Name ~= "Layout" then
				ch:Destroy()
			end
		end
		local layout = grid:FindFirstChild("Layout")
		if layout and layout:IsA("UIGridLayout") then
			layout.CellSize = UDim2.new(0.5, -4, 0, 64)
		end
	end

	return section
end

function SETTINGS_NAMETAG_SYS.createCard(cardTemplate, name, title, rarity, gradColors, onActivate)
	local card = cardTemplate:Clone()
	card.Name = name
	card.Visible = true

	local label = card:FindFirstChild("Label")
	if label then
		label.Text = title
		label.TextColor3 = gradColors[1]
		label.TextTransparency = 0
	end

	local rarityFrame = card:FindFirstChild("Rarity")
	if rarityFrame then
		rarityFrame.Visible = true
		local rlbl = rarityFrame:FindFirstChild("Label")
		if rlbl then rlbl.Text = rarity end
		local rgrad = rarityFrame:FindFirstChild("Gradient")
		if rgrad then
			rgrad.Color = ColorSequence.new(gradColors[1], gradColors[2])
		end
	end

	local lock = card:FindFirstChild("Lock")
	if lock then lock.Visible = false end

	card.Activated:Connect(function()
		onActivate()
		SETTINGS_NAMETAG_SYS.applyToCurrentCharacter()
		SETTINGS_NAMETAG_SYS.updateAllCardsUI()
	end)

	card.MouseEnter:Connect(function()
		card.BackgroundTransparency = 0.35
	end)
	card.MouseLeave:Connect(function()
		card.BackgroundTransparency = 0.5
	end)

	return card
end

function SETTINGS_NAMETAG_SYS.buildAllSections(nametagPage)
	local templates = nametagPage:FindFirstChild("Templates")
	local cardTemplate = templates and templates:FindFirstChild("Card")
	if not cardTemplate then return end

	local s = getgenv().AstrocynaWatermarkSettings
	local refs = SETTINGS_NAMETAG_SYS.cardRefs
	refs.themes = {}

	-- SECTION 1: VISIBILITY & DISPLAY
	local sec1 = SETTINGS_NAMETAG_SYS.createSection(
		nametagPage,
		"AstrocynaSection_Visibility",
		"WATERMARK // VISIBILITY & DISPLAY",
		"Toggle overhead badge visibility, SPY disguise subtitle, and wall penetration."
	)
	sec1.LayoutOrder = 1
	local grid1 = sec1:FindFirstChild("Grid")

	refs.wmToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_WatermarkToggle", "[ Watermark Display ]", "CORE",
		{ Color3.fromRGB(0, 215, 255), Color3.fromRGB(200, 200, 205) },
		function()
			s.Enabled = not s.Enabled
			getgenv().AstrocynaWatermarkEnabled = s.Enabled
			DISGUISE_SYS.syncNametagVisibility()
		end
	)
	refs.wmToggle.LayoutOrder = 1
	refs.wmToggle.Parent = grid1

	refs.spyToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_SpySubtitle", "[ Subtitle Mode ]", "COVERT",
		{ Color3.fromRGB(240, 240, 245), Color3.fromRGB(180, 180, 185) },
		function()
			s.SpyMode = not s.SpyMode
		end
	)
	refs.spyToggle.LayoutOrder = 2
	refs.spyToggle.Parent = grid1

	refs.espToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_EspToggle", "[ Wall Penetration ]", "X-RAY",
		{ Color3.fromRGB(250, 250, 255), Color3.fromRGB(190, 190, 195) },
		function()
			s.AlwaysOnTop = not s.AlwaysOnTop
		end
	)
	refs.espToggle.LayoutOrder = 3
	refs.espToggle.Parent = grid1

	refs.iconsToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_IconsToggle", "[ Dual Side Icons ]", "EMBLEM",
		{ Color3.fromRGB(245, 245, 250), Color3.fromRGB(185, 185, 190) },
		function()
			s.ShowIcons = not s.ShowIcons
		end
	)
	refs.iconsToggle.LayoutOrder = 4
	refs.iconsToggle.Parent = grid1

	-- SECTION 2: VFX & ANIMATIONS
	local sec2 = SETTINGS_NAMETAG_SYS.createSection(
		nametagPage,
		"AstrocynaSection_VFX",
		"WATERMARK // VFX & ANIMATIONS",
		"Customize rotating neon laser, text shimmer wave, auto-scale, and floating height."
	)
	sec2.LayoutOrder = 2
	local grid2 = sec2:FindFirstChild("Grid")

	refs.laserToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_LaserToggle", "[ Neon Laser Border ]", "CYBER",
		{ Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 210, 215) },
		function()
			s.BorderLaser = not s.BorderLaser
		end
	)
	refs.laserToggle.LayoutOrder = 1
	refs.laserToggle.Parent = grid2

	refs.shimmerToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_ShimmerToggle", "[ Text Shimmer Wave ]", "SHIMMER",
		{ Color3.fromRGB(240, 240, 245), Color3.fromRGB(195, 195, 200) },
		function()
			s.TextShimmer = not s.TextShimmer
		end
	)
	refs.shimmerToggle.LayoutOrder = 2
	refs.shimmerToggle.Parent = grid2

	refs.scaleToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_ScaleToggle", "[ Dynamic Clamping ]", "SMART",
		{ Color3.fromRGB(250, 250, 255), Color3.fromRGB(190, 190, 195) },
		function()
			s.DynamicScale = not s.DynamicScale
		end
	)
	refs.scaleToggle.LayoutOrder = 3
	refs.scaleToggle.Parent = grid2

	refs.heightToggle = SETTINGS_NAMETAG_SYS.createCard(
		cardTemplate, "Card_HeightToggle", "[ Floating Height ]", "OFFSET",
		{ Color3.fromRGB(235, 235, 240), Color3.fromRGB(180, 180, 185) },
		function()
			if s.HeightLevel == "Standard" then
				s.HeightLevel = "High"
			elseif s.HeightLevel == "High" then
				s.HeightLevel = "Compact"
			else
				s.HeightLevel = "Standard"
			end
		end
	)
	refs.heightToggle.LayoutOrder = 4
	refs.heightToggle.Parent = grid2

	-- SECTION 3: COLOR THEMES
	local sec3 = SETTINGS_NAMETAG_SYS.createSection(
		nametagPage,
		"AstrocynaSection_Themes",
		"WATERMARK // COLOR THEMES & PRESETS",
		"Select a curated neon theme to recolor the watermark HUD, border laser, and glow."
	)
	sec3.LayoutOrder = 3
	local grid3 = sec3:FindFirstChild("Grid")

	local themeKeys = { "Noir", "Platinum", "Frost", "Graphite", "Onyx" }
	for idx, tKey in ipairs(themeKeys) do
		local tData = THEME_PRESETS[tKey]
		local tCard = SETTINGS_NAMETAG_SYS.createCard(
			cardTemplate, "Card_Theme_" .. tKey, "[ " .. tData.Name .. " ]", tData.Rarity,
			{ tData.Grad1, tData.Grad2 },
			function()
				s.ColorTheme = tKey
			end
		)
		tCard.LayoutOrder = idx
		tCard.Parent = grid3
		refs.themes[tKey] = tCard
	end

	SETTINGS_NAMETAG_SYS.sections = { sec1, sec2, sec3 }
	SETTINGS_NAMETAG_SYS.updateAllCardsUI()
end

function SETTINGS_NAMETAG_SYS.selectWatermarkCategory(nametagPage, chipBtn)
	SETTINGS_NAMETAG_SYS.isWatermarkTabActive = true
	local main = nametagPage:FindFirstChild("Main")
	local titles = main and main:FindFirstChild("Titles")
	local bar = titles and titles:FindFirstChild("Bar")
	local chips = bar and bar:FindFirstChild("Chips")
	local list = titles and titles:FindFirstChild("List")
	if not titles or not chips or not list then return end

	-- Highlight our chip
	chipBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	chipBtn.BackgroundTransparency = 0
	chipBtn.TextColor3 = Color3.fromRGB(30, 30, 30)
	chipBtn.TextTransparency = 0

	-- Unhighlight other chips in category bar
	for _, ch in ipairs(chips:GetChildren()) do
		if ch ~= chipBtn and (ch:IsA("TextButton") or ch:IsA("ImageButton")) then
			ch.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			ch.BackgroundTransparency = 0.5
			ch.TextColor3 = Color3.fromRGB(235, 235, 235)
			ch.TextTransparency = 0.25
		end
	end

	-- Update Titles Header
	local head = titles:FindFirstChild("Head")
	if head then
		local t = head:FindFirstChild("Title")
		local d = head:FindFirstChild("Desc")
		local a = head:FindFirstChild("Aside")
		if t then t.Text = "Displayed Title" end
		if d then d.Text = "Astrocyna overhead watermark full control suite: visibility, animations & themes." end
		if a then
			local s = getgenv().AstrocynaWatermarkSettings
			a.Text = string.format("%s · %s", s.Enabled and "1 / 1 ACTIVE" or "0 / 1 HIDDEN", s.ColorTheme:upper())
		end
	end

	-- Hide existing title sections in List
	for _, item in ipairs(list:GetChildren()) do
		if item:IsA("GuiObject") and not string.find(item.Name, "AstrocynaSection_") and item.Name ~= "Layout" and item.Name ~= "Padding" then
			item.Visible = false
		end
	end

	-- Check if our sections exist in list, if not build them
	if #SETTINGS_NAMETAG_SYS.sections == 0 or not SETTINGS_NAMETAG_SYS.sections[1].Parent then
		SETTINGS_NAMETAG_SYS.buildAllSections(nametagPage)
		for _, sec in ipairs(SETTINGS_NAMETAG_SYS.sections) do
			sec.Parent = list
		end
	else
		for _, sec in ipairs(SETTINGS_NAMETAG_SYS.sections) do
			sec.Visible = true
		end
	end

	list.CanvasPosition = Vector2.zero
	local empty = titles:FindFirstChild("Empty")
	if empty then
		empty.Visible = false
	end

	SETTINGS_NAMETAG_SYS.updateAllCardsUI()
end

function SETTINGS_NAMETAG_SYS.hookChips(nametagPage)
	local main = nametagPage:FindFirstChild("Main")
	local titles = main and main:FindFirstChild("Titles")
	local bar = titles and titles:FindFirstChild("Bar")
	local chips = bar and bar:FindFirstChild("Chips")
	local templates = nametagPage:FindFirstChild("Templates")
	local list = titles and titles:FindFirstChild("List")
	if not chips or not templates then return end

	-- Look for 'Exclusive' chip to determine placement
	local exclusiveChip = chips:FindFirstChild("Exclusive")
	local targetOrder = 11
	if exclusiveChip and exclusiveChip:IsA("GuiObject") then
		targetOrder = exclusiveChip.LayoutOrder + 1
	end

	-- Check if our chip already exists
	local existingChip = chips:FindFirstChild("AstrocynaWatermarkChip")
	if not existingChip then
		local chipTemplate = templates:FindFirstChild("Chip")
		local newChip = nil
		if chipTemplate then
			newChip = chipTemplate:Clone()
		else
			newChip = Instance.new("TextButton")
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 10)
			c.Parent = newChip
		end

		newChip.Name = "AstrocynaWatermarkChip"
		newChip.Text = "Watermark"
		newChip.LayoutOrder = targetOrder
		newChip.Visible = true
		newChip.AutoButtonColor = false
		newChip.Font = Enum.Font.GothamMedium
		newChip.TextSize = 13

		-- Style according to active state
		if SETTINGS_NAMETAG_SYS.isWatermarkTabActive then
			newChip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			newChip.BackgroundTransparency = 0
			newChip.TextColor3 = Color3.fromRGB(30, 30, 30)
			newChip.TextTransparency = 0
		else
			newChip.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			newChip.BackgroundTransparency = 0.5
			newChip.TextColor3 = Color3.fromRGB(235, 235, 235)
			newChip.TextTransparency = 0.25
		end

		newChip.MouseEnter:Connect(function()
			if not SETTINGS_NAMETAG_SYS.isWatermarkTabActive then
				newChip.BackgroundTransparency = 0.35
			end
		end)
		newChip.MouseLeave:Connect(function()
			if not SETTINGS_NAMETAG_SYS.isWatermarkTabActive then
				newChip.BackgroundTransparency = 0.5
			end
		end)

		newChip.Activated:Connect(function()
			SETTINGS_NAMETAG_SYS.selectWatermarkCategory(nametagPage, newChip)
		end)

		newChip.Parent = chips
		SETTINGS_NAMETAG_SYS.injectedChip = newChip
	else
		-- Ensure correct order after Exclusive
		if existingChip.LayoutOrder ~= targetOrder then
			existingChip.LayoutOrder = targetOrder
		end
		SETTINGS_NAMETAG_SYS.injectedChip = existingChip
	end

	-- Listen for clicks on native chips to reset our active state
	for _, nativeChip in ipairs(chips:GetChildren()) do
		if nativeChip ~= existingChip and (nativeChip:IsA("TextButton") or nativeChip:IsA("ImageButton")) then
			if not nativeChip:GetAttribute("AstrocynaHooked") then
				nativeChip:SetAttribute("AstrocynaHooked", true)
				nativeChip.Activated:Connect(function()
					SETTINGS_NAMETAG_SYS.isWatermarkTabActive = false
					local chip = SETTINGS_NAMETAG_SYS.injectedChip
					if chip and chip.Parent then
						chip.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
						chip.BackgroundTransparency = 0.5
						chip.TextColor3 = Color3.fromRGB(235, 235, 235)
						chip.TextTransparency = 0.25
					end
					if list then
						for _, sec in ipairs(SETTINGS_NAMETAG_SYS.sections) do
							if sec and sec.Parent then
								sec.Visible = false
							end
						end
					end
				end)
			end
		end
	end
end

function SETTINGS_NAMETAG_SYS.startWatchdog()
	if env._AstrocynaNametagWatchdogThread then
		pcall(task.cancel, env._AstrocynaNametagWatchdogThread)
		env._AstrocynaNametagWatchdogThread = nil
	end
	env._AstrocynaNametagWatchdogThread = task.spawn(function()
		while true do
			task.wait(2.5)
			pcall(function()
				local pGui = player:FindFirstChild("PlayerGui")
				local homeGui = pGui and pGui:FindFirstChild("HomeGui")
				if not homeGui or not homeGui.Enabled then return end
				local nametagPage = SETTINGS_NAMETAG_SYS.findNametagPage()
				if nametagPage and nametagPage.Visible then
					SETTINGS_NAMETAG_SYS.hookChips(nametagPage)
					if SETTINGS_NAMETAG_SYS.isWatermarkTabActive then
						local main = nametagPage:FindFirstChild("Main")
						local titles = main and main:FindFirstChild("Titles")
						local list = titles and titles:FindFirstChild("List")
						if list then
							if #SETTINGS_NAMETAG_SYS.sections == 0 or not SETTINGS_NAMETAG_SYS.sections[1].Parent then
								SETTINGS_NAMETAG_SYS.buildAllSections(nametagPage)
								for _, sec in ipairs(SETTINGS_NAMETAG_SYS.sections) do
									sec.Parent = list
								end
							else
								for _, sec in ipairs(SETTINGS_NAMETAG_SYS.sections) do
									sec.Visible = true
								end
							end
							for _, item in ipairs(list:GetChildren()) do
								if item:IsA("GuiObject") and not string.find(item.Name, "AstrocynaSection_") and item.Name ~= "Layout" and item.Name ~= "Padding" then
									item.Visible = false
								end
							end
						end
					end
				end
			end)
		end
	end)
end

SETTINGS_NAMETAG_SYS.startWatchdog()

function DISGUISE_SYS.startWatchdog()
	if DISGUISE_SYS.watchdogStarted then return end
	DISGUISE_SYS.watchdogStarted = true

	-- Pre-load UGC templates
	task.spawn(function()
		for _, item in ipairs(DISGUISE_SYS.UgcItems) do
			pcall(function()
				DISGUISE_SYS.loadUgcAccessoryTemplate(item)
			end)
		end
	end)

	-- Initial setup (runs immediately for native nametag & watermark)
	task.spawn(function()
		task.wait(0.2)
		DISGUISE_SYS.syncNametagVisibility()
		DISGUISE_SYS.updateWatermarkSpyName(isDisguiseEnabled)
		if isDisguiseEnabled then
			DISGUISE_SYS.applyDisguise()
		end
	end)

	-- Lightweight, lag-free monitor for workspace.Visuals
	local function hookVisualsFolder(vFolder)
		if not vFolder then return end

		local function checkAndHideVisualChild(child)
			if not child or not child.Parent then return end
			local s = getgenv().AstrocynaWatermarkSettings
			local wmOn = (s and s.Enabled ~= false) and (getgenv().AstrocynaWatermarkEnabled ~= false)
			local cName = string.lower(child.Name)

			local shouldHide = false
			if wmOn and (cName == string.lower(player.Name) or cName == string.lower(player.DisplayName) or child.Name == tostring(player.UserId)) then
				shouldHide = true
			else
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player and (string.lower(p.Name) == cName or string.lower(p.DisplayName) == cName or child.Name == tostring(p.UserId)) then
						if DISGUISE_SYS and DISGUISE_SYS.isPeerScriptUser and DISGUISE_SYS.isPeerScriptUser(p) then
							shouldHide = true
							break
						end
					end
				end
			end

			if not shouldHide and (child:IsA("BillboardGui") or child:IsA("SurfaceGui")) then
				local ad = child.Adornee
				if ad then
					if wmOn and player.Character and (ad == player.Character or ad:IsDescendantOf(player.Character)) then
						shouldHide = true
					else
						for _, p in ipairs(Players:GetPlayers()) do
							if p ~= player and p.Character and (ad == p.Character or ad:IsDescendantOf(p.Character)) then
								if DISGUISE_SYS and DISGUISE_SYS.isPeerScriptUser and DISGUISE_SYS.isPeerScriptUser(p) then
									shouldHide = true
									break
								end
							end
						end
					end
				end
			end

			if shouldHide then
				DISGUISE_SYS.disableTreeGuis(child)
				local sg = child:FindFirstChildOfClass("SurfaceGui")
				if sg and not sg:GetAttribute("AstrocynaHideHooked") then
					sg:SetAttribute("AstrocynaHideHooked", true)
					sg:GetPropertyChangedSignal("Enabled"):Connect(function()
						if sg.Enabled then
							sg.Enabled = false
						end
					end)
				end
			end
		end

		for _, existing in ipairs(vFolder:GetChildren()) do
			checkAndHideVisualChild(existing)
		end

		vFolder.ChildAdded:Connect(function(child)
			task.wait()
			checkAndHideVisualChild(child)
		end)
	end

	local wsVisuals = workspace:FindFirstChild("Visuals")
	if wsVisuals then
		hookVisualsFolder(wsVisuals)
	end

	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Visuals" and child:IsA("Folder") then
			hookVisualsFolder(child)
			DISGUISE_SYS.syncNametagVisibility()
		end
	end)

	-- 🛡️ Anti-Duplicate: Strict single-instance enforcement for AstrocynaWatermarkGui
	local function enforceSingleWatermark(char)
		if not char then return end
		local head = char:FindFirstChild("Head")
		if not head then return end

		local allGuis = {}
		for _, c in ipairs(head:GetChildren()) do
			if c.Name == "AstrocynaWatermarkGui" then
				table.insert(allGuis, c)
			end
		end
		for _, c in ipairs(char:GetChildren()) do
			if c.Name == "AstrocynaWatermarkGui" and c.Parent ~= head then
				table.insert(allGuis, c)
			end
		end

		-- If there are multiple watermarks, keep ONLY the latest one and destroy all others!
		if #allGuis > 1 then
			for i = 1, #allGuis - 1 do
				pcall(function() allGuis[i]:Destroy() end)
			end
		end

		local activeWm = allGuis[#allGuis]
		if activeWm then
			if SETTINGS_NAMETAG_SYS and SETTINGS_NAMETAG_SYS.applyWatermarkSettings then
				pcall(SETTINGS_NAMETAG_SYS.applyWatermarkSettings, activeWm)
			end
			DISGUISE_SYS.updateWatermarkSpyName(isDisguiseEnabled)
		end
	end

	-- Hook watermark creation on head with strict duplicate prevention
	local function hookHeadWatermark(char)
		if not char then return end
		task.spawn(function()
			local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
			if head then
				local cConn = head.ChildAdded:Connect(function(c)
					if c.Name == "AstrocynaWatermarkGui" then
						task.wait(0.03)
						enforceSingleWatermark(char)
					end
				end)
				table.insert(env._AstrocynaWatermarkConnections, cConn)
				enforceSingleWatermark(char)
			end
		end)
	end

	-- Monitor Workspace.Players folder (respawns)
	local wsPlayers = workspace:FindFirstChild("Players")
	if wsPlayers then
		local wsPlrConn = wsPlayers.ChildAdded:Connect(function(child)
			if child.Name == player.Name and child:IsA("Model") then
				task.wait(0.15)
				DISGUISE_SYS.syncNametagVisibility(child)
				hookHeadWatermark(child)
				DISGUISE_SYS.updateWatermarkSpyName(isDisguiseEnabled)
				if isDisguiseEnabled then
					DISGUISE_SYS.applyDisguise(child)
				end
			end
		end)
		table.insert(env._AstrocynaWatermarkConnections, wsPlrConn)
	end

	-- Monitor Workspace Character
	local wsConn = workspace.ChildAdded:Connect(function(child)
		if child.Name == player.Name and child:IsA("Model") then
			task.wait(0.15)
			DISGUISE_SYS.syncNametagVisibility(child)
			hookHeadWatermark(child)
			DISGUISE_SYS.updateWatermarkSpyName(isDisguiseEnabled)
			if isDisguiseEnabled then
				DISGUISE_SYS.applyDisguise(child)
			end
		end
	end)
	table.insert(env._AstrocynaWatermarkConnections, wsConn)

	local charAddedConn = player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		DISGUISE_SYS.syncNametagVisibility(char)
		hookHeadWatermark(char)
		DISGUISE_SYS.updateWatermarkSpyName(isDisguiseEnabled)
		if isDisguiseEnabled then
			DISGUISE_SYS.applyDisguise(char)
		end
	end)
	table.insert(env._AstrocynaWatermarkConnections, charAddedConn)

	if player.Character then
		hookHeadWatermark(player.Character)
	end

	-- Lightweight, single-instance watchdog loop (every 2.0s)
	if env._AstrocynaDisguiseWatchdogThread then
		pcall(task.cancel, env._AstrocynaDisguiseWatchdogThread)
		env._AstrocynaDisguiseWatchdogThread = nil
	end
	env._AstrocynaDisguiseWatchdogThread = task.spawn(function()
		while true do
			task.wait(isDisguiseEnabled and 4.0 or 8.0)
			pcall(function()
				if isDisguiseEnabled then
					local char = player.Character
					if char and char.Parent then
						if not char:GetAttribute("AstrocynaDisguiseApplied") then
							DISGUISE_SYS.applyDisguise(char, true)
						else
							-- Lightweight verification: only ensure watermark text stays updated
							DISGUISE_SYS.updateWatermarkSpyName(true)
						end
					end
				elseif getgenv().AstrocynaWatermarkEnabled ~= false then
					DISGUISE_SYS.syncNametagVisibility()
				end
			end)
		end
	end)

	-- Register overall script teardown hook in env for re-run update safety
	env._AstrocynaFakeAdminCleanup = function()
		if env._AstrocynaDisguiseWatchdogThread then
			pcall(task.cancel, env._AstrocynaDisguiseWatchdogThread)
			env._AstrocynaDisguiseWatchdogThread = nil
		end
		if env._AstrocynaNametagWatchdogThread then
			pcall(task.cancel, env._AstrocynaNametagWatchdogThread)
			env._AstrocynaNametagWatchdogThread = nil
		end
		if env._AstrocynaWatermarkConnections then
			for _, conn in ipairs(env._AstrocynaWatermarkConnections) do
				if conn and conn.Disconnect then
					pcall(function() conn:Disconnect() end)
				end
			end
			table.clear(env._AstrocynaWatermarkConnections)
		end
		if env._AstrocynaTrackedThreads then
			for _, th in ipairs(env._AstrocynaTrackedThreads) do
				if th then pcall(task.cancel, th) end
			end
			table.clear(env._AstrocynaTrackedThreads)
		end
		if env._AstrocynaTrackedConnections then
			for _, conn in ipairs(env._AstrocynaTrackedConnections) do
				if conn and conn.Disconnect then
					pcall(function() conn:Disconnect() end)
				end
			end
			table.clear(env._AstrocynaTrackedConnections)
		end
	end
end

toggleDisguise = function()
	if disguiseBusy then return end
	disguiseBusy = true

	isDisguiseEnabled = not isDisguiseEnabled

	if isDisguiseEnabled then
		DISGUISE_SYS.applyDisguise()
	else
		DISGUISE_SYS.restoreDisguise()
	end

	updateGuiDisguiseState()
	disguiseBusy = false
end

DISGUISE_SYS.startWatchdog()

local ENV_CALLS = {}
ENV_CALLS.env = (getgenv and getgenv()) or _G or {}
ENV_CALLS.httpRequest = (ENV_CALLS.env.syn and ENV_CALLS.env.syn.request) or ENV_CALLS.env.request or ENV_CALLS.env.http_request or (ENV_CALLS.env.http and ENV_CALLS.env.http.request) or (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
ENV_CALLS.customAssetFunc = ENV_CALLS.env.getcustomasset or ENV_CALLS.env.getsynasset or (type(getcustomasset) == "function" and getcustomasset)
ENV_CALLS.canCustomAsset = (ENV_CALLS.env.writefile or (type(writefile) == "function" and writefile)) and (ENV_CALLS.env.isfile or (type(isfile) == "function" and isfile)) and ENV_CALLS.customAssetFunc and true or false
ENV_CALLS.request = ENV_CALLS.httpRequest
ENV_CALLS.customAsset = ENV_CALLS.customAssetFunc


local function boomboxGetValidCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	while not character:FindFirstChild("HumanoidRootPart") do
		character:WaitForChild("HumanoidRootPart")
		task.wait()
	end
	return character
end

local function boomboxParseColor(text)
	text = text:gsub("%s+", "")
	if text:match("^#?%x%x%x%x%x%x$") then
		text = text:gsub("#", "")
		local r = tonumber(text:sub(1, 2), 16)
		local g = tonumber(text:sub(3, 4), 16)
		local b = tonumber(text:sub(5, 6), 16)
		return Color3.fromRGB(r, g, b)
	end
	local r, g, b = text:match("^(%d+),(%d+),(%d+)$")
	if r and g and b then
		return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
	end
	return nil
end

local function boomboxCreateModel()
	local model = Instance.new("Model")
	model.Name = "AstrocynaBoombox"

	local character = boomboxGetValidCharacter()
	local basePos = character.HumanoidRootPart.Position + Vector3.new(0, 3, 0)

	local main = Instance.new("Part")
	main.Name = "Main"
	main.Size = Vector3.new(2, 1, 1)
	main.Position = basePos
	main.Color = boomboxSelectedColor
	main.Material = Enum.Material.Neon
	main.Anchored = false
	main.CanCollide = false
	main.Parent = model

	local light = Instance.new("PointLight")
	light.Color = boomboxSelectedColor
	light.Brightness = 2
	light.Range = 10
	light.Shadows = true
	light.Parent = main

	boomboxSmoke = Instance.new("Smoke")
	boomboxSmoke.Color = boomboxSelectedColor
	boomboxSmoke.Opacity = 0.2
	boomboxSmoke.RiseVelocity = 2
	boomboxSmoke.Size = 1
	boomboxSmoke.Enabled = boomboxIsSmokeEnabled
	boomboxSmoke.Parent = main

	local function createPart(name, size, offset)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = main.Position + offset
		part.Color = boomboxSelectedColor
		part.Material = Enum.Material.Neon
		part.Anchored = false
		part.CanCollide = false
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = main
		weld.Part1 = part
		weld.Parent = main
		return part
	end

	createPart("Handle", Vector3.new(2, 0.2, 0.2), Vector3.new(0, 0.6, 0))
	createPart("SpeakerLeft", Vector3.new(0.4, 0.4, 0.1), Vector3.new(-0.6, 0, 0.55))
	createPart("SpeakerRight", Vector3.new(0.4, 0.4, 0.1), Vector3.new(0.6, 0, 0.55))

	local sparkles = Instance.new("ParticleEmitter", main)
	sparkles.Color = ColorSequence.new(boomboxSelectedColor)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	sparkles.Rate = 20
	sparkles.Speed = NumberRange.new(1, 3)

	local billboard = Instance.new("BillboardGui", main)
	billboard.Name = "NameTag"
	billboard.Adornee = main
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🎶 Astrocyna Boombox 🎶"
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5

	task.spawn(function()
		local h = 0
		while billboard and billboard.Parent do
			h = (h + 1) % 360
			label.TextColor3 = Color3.fromHSV(h / 360, 1, 1)
			task.wait(0.05)
		end
	end)

	model.PrimaryPart = main
	model.Parent = workspace
	return model
end

local function boomboxEnableFog()
	if boomboxUseBoomboxTheme then
		Lighting.FogStart = 0
		Lighting.FogEnd = 1500
		Lighting.FogColor = boomboxSelectedColor
	else
		local timeOfDay = tonumber(Lighting.TimeOfDay:sub(1, 2)) or 12
		local fogColor
		if timeOfDay >= 6 and timeOfDay < 18 then
			fogColor = Color3.fromRGB(200, 220, 255)
		else
			fogColor = Color3.fromRGB(40, 50, 80)
		end
		Lighting.FogStart = 100
		Lighting.FogEnd = 1000
		Lighting.FogColor = fogColor
	end
end

local function boomboxDisableFog()
	Lighting.FogStart = 100000
	Lighting.FogEnd = 100000
end

local function boomboxDisableDepthOfField()
	if boomboxDepthEffect and boomboxDepthEffect.Parent then
		boomboxDepthEffect:Destroy()
		boomboxDepthEffect = nil
	end
end

local function boomboxAddEffect(effect)
	effect.Parent = Lighting
	table.insert(boomboxEffects, effect)
end

local function boomboxEnableVisualEffects()
	if not boomboxUseBoomboxTheme then return end

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "BoomboxBloom"
	bloom.Intensity = 0.35
	bloom.Size = 48
	bloom.Threshold = 1.8
	boomboxAddEffect(bloom)

	local bloomNight = Instance.new("BloomEffect")
	bloomNight.Name = "BoomboxBloomNight"
	bloomNight.Intensity = 0.25
	bloomNight.Size = 64
	bloomNight.Threshold = 2.2
	boomboxAddEffect(bloomNight)

	local ccNight = Instance.new("ColorCorrectionEffect")
	ccNight.Name = "BoomboxCCNight"
	ccNight.TintColor = Color3.fromRGB(200, 220, 255)
	ccNight.Contrast = 0.01
	ccNight.Brightness = -0.01
	ccNight.Saturation = -0.01
	boomboxAddEffect(ccNight)

	local ccDay = Instance.new("ColorCorrectionEffect")
	ccDay.Name = "BoomboxCCDay"
	ccDay.TintColor = Color3.fromRGB(255, 250, 240)
	ccDay.Contrast = 0.005
	ccDay.Brightness = 0.005
	ccDay.Saturation = 0.005
	boomboxAddEffect(ccDay)

	local ccCenter = Instance.new("ColorCorrectionEffect")
	ccCenter.Name = "BoomboxCCCenter"
	ccCenter.TintColor = boomboxSelectedColor
	ccCenter.Contrast = 0.01
	ccCenter.Brightness = 0.01
	ccCenter.Saturation = 0.02
	boomboxAddEffect(ccCenter)
end

local function boomboxDisableVisualEffects()
	for _, e in ipairs(boomboxEffects) do
		if e and e.Parent then e:Destroy() end
	end
	boomboxEffects = {}
end

local function boomboxEnsureCacheFolder()
	if ENV_CALLS.canCustomAsset and makefolder then
		if isfolder then
			if not isfolder(boomboxCacheFolder) then
				pcall(makefolder, boomboxCacheFolder)
			end
		else
			pcall(makefolder, boomboxCacheFolder)
		end
	end
end

local function boomboxParseInput(text)
	text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil end

	local lower = text:lower()
	if lower:find("youtu%.be/") or lower:find("youtube%.com/") or lower:find("youtube%-nocookie%.com/") then
		local vid = text:match("youtu%.be/([%w_%-]+)")
			or text:match("[?&]v=([%w_%-]+)")
			or text:match("/shorts/([%w_%-]+)")
			or text:match("/embed/([%w_%-]+)")
			or text:match("/live/([%w_%-]+)")
		if vid then
			local cleanVid = vid:sub(1, 11)
			return {
				type = "youtube",
				id = cleanVid,
				url = "https://www.youtube.com/watch?v=" .. cleanVid,
				display = "YouTube (" .. cleanVid .. ")",
			}
		end
	end

	if #text == 11 and text:match("^[%w_%-]+$") and not text:match("^%d+$") then
		return {
			type = "youtube",
			id = text,
			url = "https://www.youtube.com/watch?v=" .. text,
			display = "YouTube (" .. text .. ")",
		}
	end

	local numId = text:match("^(%d+)$")
		or text:match("rbxassetid://(%d+)")
		or text:match("[?&]id=(%d+)")
		or text:match("/library/(%d+)")
		or text:match("/store/asset/(%d+)")
		or text:match("/asset/(%d+)")
		or text:match("/(%d+)/")
	if numId then
		return {
			type = "roblox",
			id = numId,
			soundId = "rbxassetid://" .. numId,
			display = "Roblox ID: " .. numId,
		}
	end

	return nil
end

local function boomboxDownloadYoutubeAudio(videoUrl, videoId)
	local lastErr = "no endpoint succeeded"

	local endpoints = {}
	if BOOMBOX_YT_CONFIG.CustomEndpoint and BOOMBOX_YT_CONFIG.CustomEndpoint ~= "" then
		table.insert(endpoints, {
			url = BOOMBOX_YT_CONFIG.CustomEndpoint,
			apiKey = BOOMBOX_YT_CONFIG.ApiKey,
		})
	end
	for _, ep in ipairs(boomboxYtEndpoints) do
		table.insert(endpoints, ep)
	end

	for _, ep in ipairs(endpoints) do
		if not boomboxIsLoading then break end

		local headers = {
			["Accept"] = "application/json",
			["Content-Type"] = "application/json",
		}
		if ep.apiKey and ep.apiKey ~= "" then
			headers["Authorization"] = "Api-Key " .. ep.apiKey
		end

		local postBody = HttpService:JSONEncode({
			url = videoUrl,
			downloadMode = "audio",
			audioFormat = "mp3",
		})

		local ok, res = pcall(ENV_CALLS.request, {
			Url = ep.url,
			Method = "POST",
			Headers = headers,
			Body = postBody,
		})

		if ok and res and res.Body then
			local okJson, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
			if okJson and typeof(data) == "table" then
				local downloadUrl = nil
				if (data.status == "tunnel" or data.status == "redirect" or data.status == "stream") and data.url then
					downloadUrl = data.url
				elseif data.url and typeof(data.url) == "string" and data.url:match("^https?://") then
					downloadUrl = data.url
				elseif data.link and typeof(data.link) == "string" and data.link:match("^https?://") then
					downloadUrl = data.link
				end

				if downloadUrl then
					local okGet, fileRes = pcall(ENV_CALLS.request, {
						Url = downloadUrl,
						Method = "GET",
					})
					if okGet and fileRes and fileRes.StatusCode == 200 and fileRes.Body and #fileRes.Body > 1000 then
						return fileRes.Body, nil
					else
						lastErr = "Stream fetch failed from " .. tostring(ep.url)
					end
				else
					local errCode = (data.error and (data.error.code or data.error.message)) or data.text or data.status or "bad response"
					lastErr = tostring(errCode)
				end
			else
				if res.StatusCode == 200 and #res.Body > 1000 then
					return res.Body, nil
				end
				lastErr = "Invalid response from " .. tostring(ep.url)
			end
		else
			lastErr = "Request failed to " .. tostring(ep.url)
		end
	end

	return nil, lastErr
end

local function boomboxStop()
	boomboxIsLoading = false
	boomboxDisableFog()
	boomboxDisableDepthOfField()
	boomboxDisableVisualEffects()
	if boomboxCurrentSound then
		boomboxCurrentSound:Destroy()
		boomboxCurrentSound = nil
	end
	if boomboxModel then
		boomboxModel:Destroy()
		boomboxModel = nil
	end
	if boomboxRotateConnection then
		boomboxRotateConnection:Disconnect()
		boomboxRotateConnection = nil
	end
	if boomboxBeatConnection then
		boomboxBeatConnection:Disconnect()
		boomboxBeatConnection = nil
	end

	local bbSky = Lighting:FindFirstChild("AstrocynaBoomboxSky")
	if bbSky then bbSky:Destroy() end

	if boomboxOriginalSky then
		boomboxOriginalSky.Parent = Lighting
		boomboxOriginalSky = nil
	end
	if boomboxOriginalTechnology then
		Lighting.Technology = boomboxOriginalTechnology
		boomboxOriginalTechnology = nil
	end

	boomboxSmoke = nil
	boomboxRotating = false
end

local function boomboxPlay(musicInput, onStatus)
	onStatus = onStatus or function() end

	local parsed = boomboxParseInput(musicInput)
	if not parsed then
		onStatus("❌ Enter valid Roblox ID or YouTube link", false)
		return false
	end

	local character = boomboxGetValidCharacter()
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		onStatus("❌ Character / RootPart not found", false)
		return false
	end

	if boomboxCurrentSound then
		boomboxStop()
	end

	local resolvedSoundId = nil

	if parsed.type == "roblox" then
		resolvedSoundId = parsed.soundId
	elseif parsed.type == "youtube" then
		if not ENV_CALLS.httpRequest then
			onStatus("❌ Executor missing request() API", false)
			return false
		end
		if not ENV_CALLS.canCustomAsset then
			onStatus("❌ Executor missing getcustomasset / writefile", false)
			return false
		end

		boomboxEnsureCacheFolder()
		local cacheFile = boomboxCacheFolder .. "/yt_" .. parsed.id .. ".mp3"

		if isfile and isfile(cacheFile) then
			onStatus("⚡ Loading cached YouTube audio...", true, true)
			local okAsset, assetUri = pcall(ENV_CALLS.customAsset, cacheFile)
			if okAsset and assetUri then
				resolvedSoundId = assetUri
			else
				onStatus("❌ Failed to load cached audio", false)
				return false
			end
		else
			boomboxIsLoading = true
			onStatus("⏳ Downloading YouTube audio...", true, true)

			local bridgeSuccess = false
			local bridgeError = nil

			local okBridge, bridgeRes = pcall(ENV_CALLS.request, {
				Url = "http://127.0.0.1:45455/dl?id=" .. parsed.id .. "&url=" .. (HttpService and HttpService.UrlEncode and HttpService:UrlEncode(parsed.url) or parsed.url),
				Method = "GET",
				Timeout = 90,
			})

			if okBridge and bridgeRes and bridgeRes.StatusCode == 200 and bridgeRes.Body then
				local okJson, bData = pcall(HttpService.JSONDecode, HttpService, bridgeRes.Body)
				if okJson and typeof(bData) == "table" then
					if bData.success == true then
						bridgeSuccess = true
					elseif bData.error then
						bridgeError = bData.error
					end
				end
			end

			if not boomboxIsLoading then
				return false
			end

			if bridgeSuccess then
				local okAsset, assetUri = pcall(ENV_CALLS.customAsset, cacheFile)
				if okAsset and assetUri then
					resolvedSoundId = assetUri
				else
					onStatus("❌ getcustomasset failed on bridge audio", false)
					boomboxIsLoading = false
					return false
				end
			elseif bridgeError then
				onStatus("❌ " .. tostring(bridgeError), false)
				boomboxIsLoading = false
				return false
			else

				onStatus("⏳ Local bridge offline. Trying online API...", true, true)
				local audioData, _dlErr = boomboxDownloadYoutubeAudio(parsed.url, parsed.id)
				if not boomboxIsLoading then
					return false
				end

				if not audioData or #audioData < 1000 then
					onStatus("❌ Video unavailable or API blocked. Run start_bridge.bat for instant YouTube!", false)
					boomboxIsLoading = false
					return false
				end

				local okWrite, writeErr = pcall(writefile, cacheFile, audioData)
				if not okWrite then
					onStatus("❌ writefile failed: " .. tostring(writeErr), false)
					boomboxIsLoading = false
					return false
				end

				local okAsset, assetUri = pcall(ENV_CALLS.customAsset, cacheFile)
				if not okAsset or not assetUri then
					onStatus("❌ getcustomasset failed", false)
					boomboxIsLoading = false
					return false
				end

				resolvedSoundId = assetUri
			end
			boomboxIsLoading = false
		end
	end

	if not resolvedSoundId then
		onStatus("❌ Could not resolve audio source", false)
		return false
	end

	boomboxCurrentSound = Instance.new("Sound")
	boomboxCurrentSound.SoundId = resolvedSoundId
	boomboxCurrentSound.Looped = true
	boomboxCurrentSound.Volume = BOOMBOX_YT_CONFIG.Volume or 1
	boomboxCurrentSound.Parent = character:WaitForChild("HumanoidRootPart")
	boomboxCurrentSound:Play()

	boomboxEnableFog()
	boomboxEnableVisualEffects()
	boomboxModel = boomboxCreateModel()

	local nameTag = boomboxModel.PrimaryPart:FindFirstChild("NameTag")
	if nameTag and nameTag:IsA("BillboardGui") then
		nameTag.Enabled = (boomboxMode ~= "back")
	end

	if boomboxMode == "orbit" then
		boomboxModel:SetPrimaryPartCFrame(character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5))
	else
		local attachTo = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
		if attachTo then
			local weld = Instance.new("Weld")
			weld.Name = "BoomboxWeld"
			weld.Part0 = attachTo
			weld.Part1 = boomboxModel.PrimaryPart
			weld.C0 = CFrame.new(0, -0.1, 1) * CFrame.Angles(math.rad(0), 0, 1)
			weld.C1 = CFrame.new(0, 0, 0)
			weld.Parent = boomboxModel.PrimaryPart
			boomboxModel:SetPrimaryPartCFrame(attachTo.CFrame * weld.C0)
		end
	end

	boomboxRotating = true
	boomboxOriginalSky = Lighting:FindFirstChildOfClass("Sky")
	if boomboxOriginalSky then boomboxOriginalSky.Parent = nil end
	boomboxOriginalTechnology = Lighting.Technology
	Lighting.Technology = Enum.Technology.Future

	if boomboxUseBoomboxTheme then
		local sky = Instance.new("Sky")
		sky.Name = "AstrocynaBoomboxSky"
		sky.SkyboxBk = "rbxassetid://15983968922"
		sky.SkyboxDn = "rbxassetid://15983966825"
		sky.SkyboxFt = "rbxassetid://15983965025"
		sky.SkyboxLf = "rbxassetid://15983967420"
		sky.SkyboxRt = "rbxassetid://15983966246"
		sky.SkyboxUp = "rbxassetid://15983964246"
		sky.Parent = Lighting
	end

	local angle = 0
	boomboxRotateConnection = RunService.RenderStepped:Connect(function(dt)
		if boomboxRotating and boomboxModel and character:FindFirstChild("HumanoidRootPart") then
			if boomboxMode == "orbit" then
				angle += dt * 2
				local radius = 5
				local x = math.cos(angle) * radius
				local z = math.sin(angle) * radius
				local pos = character.HumanoidRootPart.Position + Vector3.new(x, 0, z)
				boomboxModel:SetPrimaryPartCFrame(CFrame.new(pos, character.HumanoidRootPart.Position))
			end
		end
	end)

	boomboxBeatConnection = RunService.RenderStepped:Connect(function()
		if boomboxCurrentSound and boomboxCurrentSound.IsPlaying then
			local loudness = boomboxCurrentSound.PlaybackLoudness
			if boomboxModel and boomboxModel:FindFirstChild("Main") then
				local brightness = math.clamp(loudness / 400, 0.2, 1)
				local mainPart = boomboxModel:FindFirstChild("Main")
				mainPart.Color = boomboxSelectedColor:Lerp(Color3.new(1, 1, 1), brightness)
				local pointLight = mainPart:FindFirstChildOfClass("PointLight")
				if pointLight then pointLight.Brightness = brightness * 8 end
			end

			local ccCenter = Lighting:FindFirstChild("BoomboxCCCenter")
			if ccCenter then
				ccCenter.Saturation = math.clamp(loudness / 1000, 0, 0.2)
			end
		end
	end)

	onStatus("Status: ♫ Playing " .. parsed.display, true)
	return true
end

-- =====================================================================
-- SHARED MODERN GUI CONTAINERS & HELPERS (FILE LEVEL SCOPE)
-- =====================================================================
screenGui = nil
pinnedGui = nil
parentGui = nil
mobileToggleGui = nil
mainWindow = nil
activeAnimators = {}
updateBrowserVisualFn = nil
buildAuraWindow = nil

	-- mainWindow declared in shared_decls
	local function ensureIconAsset()
		local iconPath = "Icon name tag/Icon.png"
		local iconUrl = "https://raw.githubusercontent.com/EQWTQWSd/Astrocyna-NameTag/main/Icon.png"
		if typeof(isfile) == "function" and typeof(writefile) == "function" then
			local fileExists = false
			pcall(function() fileExists = isfile(iconPath) end)

			if not fileExists and iconUrl and iconUrl ~= "" then
				pcall(function()
					if typeof(isfolder) == "function" and not isfolder("Icon name tag") then
						pcall(makefolder, "Icon name tag")
					end
					local downloaded = game:HttpGet(iconUrl)
					if downloaded and #downloaded > 0 then
						writefile(iconPath, downloaded)
					end
				end)
			end
		end
	end
	pcall(ensureIconAsset)

	local function resolveIconAsset(path)
		if type(path) == "string" and (path:match("^rbxasset") or path:match("^http")) then
			return path
		end

		local customAssetFunc = getcustomasset or getsynasset
		if not customAssetFunc and typeof(ENV_CALLS) == "table" then
			customAssetFunc = ENV_CALLS.customAssetFunc
		end
		if not customAssetFunc and typeof(getgenv) == "function" and getgenv() then
			customAssetFunc = getgenv().getcustomasset or getgenv().getsynasset
		end

		if customAssetFunc then
			local candidates = {
				path,
				path:gsub("/", "\\"),
				path:gsub("\\", "/"),
				"Icon name tag/Iconhud.png",
				"Icon name tag\\Iconhud.png",
				"Iconhud.png",
				"Icon name tag/Icon.png",
				"Icon.png",
			}
			for _, c in ipairs(candidates) do
				local s, res = pcall(customAssetFunc, c)
				if s and res and type(res) == "string" and res ~= "" then
					return res
				end
			end
		end

		return ""
	end

	-- activeAnimators declared in shared_decls

	local function applyNeonSweep(uiStroke, rotSpeed, pulseSpeed, minThick, maxThick)
		uiStroke.Color = Color3.fromRGB(255, 255, 255)
		local strokeGrad = Instance.new("UIGradient")
		strokeGrad.Rotation = 0
		strokeGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.BorderBase),
			ColorSequenceKeypoint.new(0.35, THEME.BorderBeam),
			ColorSequenceKeypoint.new(0.5, THEME.BorderHighlight),
			ColorSequenceKeypoint.new(0.65, THEME.BorderBeam),
			ColorSequenceKeypoint.new(1, THEME.BorderBase)
		})
		strokeGrad.Parent = uiStroke

		rotSpeed = rotSpeed or 110
		pulseSpeed = pulseSpeed or 2.5
		minThick = minThick or 1.8
		maxThick = maxThick or 2.8

		local sweepTimer = 0
		table.insert(activeAnimators, function(dt)
			if strokeGrad and strokeGrad.Parent then
				sweepTimer = sweepTimer + dt
				if sweepTimer < 0.033 then return end
				sweepTimer = 0
				local par = uiStroke.Parent
				if par and par:IsA("GuiObject") and not par.Visible then return end
				strokeGrad.Rotation = (strokeGrad.Rotation + dt * rotSpeed) % 360
				local wave = (math.sin(tick() * pulseSpeed) + 1) / 2
				uiStroke.Thickness = minThick + (maxThick - minThick) * wave
			end
		end)
		return strokeGrad
	end

	local function applyTextShimmer(textLabel, baseColor, glowColor, shineColor, animSpeed)
		local textGrad = Instance.new("UIGradient")
		textGrad.Rotation = 20
		baseColor = baseColor or THEME.TextCyan
		glowColor = glowColor or Color3.fromRGB(200, 200, 205)
		shineColor = shineColor or Color3.fromRGB(255, 255, 255)
		animSpeed = animSpeed or 1.3

		textGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, baseColor),
			ColorSequenceKeypoint.new(0.35, glowColor),
			ColorSequenceKeypoint.new(0.5, shineColor),
			ColorSequenceKeypoint.new(0.65, glowColor),
			ColorSequenceKeypoint.new(1, baseColor)
		})
		textGrad.Parent = textLabel

		local shimTimer = 0
		table.insert(activeAnimators, function(dt)
			if textGrad and textGrad.Parent then
				shimTimer = shimTimer + (dt or 0.016)
				if shimTimer < 0.033 then return end
				shimTimer = 0
				local par = textLabel.Parent
				if par and par:IsA("GuiObject") and not par.Visible then return end
				local cycle = (tick() * animSpeed) % 2.6
				if cycle <= 1.4 then
					local prog = -1.2 + (cycle / 1.4) * 2.4
					textGrad.Offset = Vector2.new(prog, 0)
				else
					textGrad.Offset = Vector2.new(2, 0)
				end
			end
		end)
		return textGrad
	end

	local function hookButtonHover(btn, normalBg, hoverBg, normalTextCol, hoverTextCol)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverBg or Color3.fromRGB(44, 44, 50),
				TextColor3 = hoverTextCol or Color3.fromRGB(255, 255, 255)
			}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = normalBg,
				TextColor3 = normalTextCol or THEME.BtnOffText
			}):Play()
		end)
	end

	local GUI_POSITIONS_FILE = "astrocyna_gui_positions.json"
	local savedGuiPositions = {}

	local function loadGuiPositions()
		if isfile and readfile and isfile(GUI_POSITIONS_FILE) then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(readfile(GUI_POSITIONS_FILE))
			end)
			if ok and type(data) == "table" then
				savedGuiPositions = data
				if savedGuiPositions["AstrocynaSpectateHud"] then
					savedGuiPositions["AstrocynaSpectateHud"] = nil
				end
				if savedGuiPositions["Frame"] then
					savedGuiPositions["Frame"] = nil
				end
				return
			end
		end
		savedGuiPositions = {}
	end

	local function saveGuiPositions()
		if writefile then
			pcall(function()
				writefile(GUI_POSITIONS_FILE, HttpService:JSONEncode(savedGuiPositions))
			end)
		end
	end

	clampPositionToScreen = function(pos, frameSize, frame)
		if frame and frame.AnchorPoint.X == 0.5 and pos.X.Scale == 0.5 then
			return pos
		end
		if frame and frame.AnchorPoint.X == 1 and pos.X.Scale == 1 then
			return pos
		end

		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if vp.X <= 0 or vp.Y <= 0 then
			vp = Vector2.new(1920, 1080)
		end

		local scale = 1
		if frame then
			local s = frame:FindFirstChildOfClass("UIScale")
			if s then scale = s.Scale end
		end

		local effW = (frameSize and frameSize.X.Offset > 0 and frameSize.X.Offset or 360) * scale
		local effH = (frameSize and frameSize.Y.Offset > 0 and frameSize.Y.Offset or 280) * scale

		local pixelX = (pos.X.Scale * vp.X) + pos.X.Offset
		local pixelY = (pos.Y.Scale * vp.Y) + pos.Y.Offset

		local minX = 0
		local maxX = math.max(0, vp.X - effW)
		local minY = 0
		local maxY = math.max(0, vp.Y - effH)

		if maxX < minX then maxX = minX end
		if maxY < minY then maxY = minY end

		local clampedX = math.clamp(pixelX, minX, maxX)
		local clampedY = math.clamp(pixelY, minY, maxY)

		return UDim2.new(0, math.floor(clampedX), 0, math.floor(clampedY))
	end

	local function applyResponsiveWindowScale(frame, baseW, baseH, centerOnSmall)
		local uiScale = frame:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Name = "ResponsiveScale"
			uiScale.Parent = frame
		end

		local function updateScale()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if vp.X <= 0 or vp.Y <= 0 then
			vp = Vector2.new(1920, 1080)
		end

			local padX = 20
			local padY = 20
			local scaleX = (vp.X - padX) / baseW
			local scaleY = (vp.Y - padY) / baseH
			local bestScale = math.clamp(math.min(1.0, math.min(scaleX, scaleY)), 0.45, 1.0)
			uiScale.Scale = bestScale

			if centerOnSmall and (bestScale < 0.98 or vp.Y < baseH + 30) then
				local effW = baseW * bestScale
				local effH = baseH * bestScale
				local targetX = math.max(10, math.floor((vp.X - effW) / 2))
				local targetY = math.max(8, math.floor((vp.Y - effH) / 2))
				frame.Position = UDim2.new(0, targetX, 0, targetY)
			end

			return bestScale
		end

		updateScale()

		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				updateScale()
				pcall(function()
					frame.Position = clampPositionToScreen(frame.Position, frame.Size, frame)
				end)
			end)
		end

		return uiScale
	end

	loadGuiPositions()

	local function makeDraggable(frame, handle)
		local frameName = frame.Name

		if frameName and frameName ~= "" and savedGuiPositions[frameName] then
			local s = savedGuiPositions[frameName]
			local rawPos = UDim2.new(s.xScale or 0, s.xOffset or 0, s.yScale or 0, s.yOffset or 0)
			frame.Position = clampPositionToScreen(rawPos, frame.Size, frame)
		end

		local dragging = false
		local dragInput, dragStart, startPos

		local function recordAndSavePosition()
			if frameName and frameName ~= "" then
				local safePos = clampPositionToScreen(frame.Position, frame.Size, frame)
				frame.Position = safePos
				savedGuiPositions[frameName] = {
					xScale = safePos.X.Scale,
					xOffset = safePos.X.Offset,
					yScale = safePos.Y.Scale,
					yOffset = safePos.Y.Offset,
				}
				saveGuiPositions()
			end
		end

		handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position

				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						if dragging then
							dragging = false
							recordAndSavePosition()
						end
						if conn then conn:Disconnect() end
					end
				end)
			end
		end)

		handle.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragging then
				dragging = false
				recordAndSavePosition()
			end
		end)
	end

	-- =====================================================================
	-- ALWAYS ON TOP / PINNED SUB-WINDOWS REGISTRY & HELPER
	-- =====================================================================
	local pinnedWindowsRegistry = {}

	local function getPinnedGui()
		if pinnedGui and pinnedGui.Parent then return pinnedGui end
		local targetParent = parentGui or (screenGui and screenGui.Parent) or (player and player:FindFirstChild("PlayerGui"))
		if not targetParent then return screenGui end
		pinnedGui = targetParent:FindFirstChild("AstrocynaPinnedGui")
		if not pinnedGui then
			pinnedGui = Instance.new("ScreenGui")
			pinnedGui.Name = "AstrocynaPinnedGui"
			pinnedGui.ResetOnSpawn = false
			pinnedGui.DisplayOrder = 15
			pinnedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			pinnedGui.Parent = targetParent
		end
		return pinnedGui
	end

	local function attachAlwaysOnTopButton(windowFrame, topBar, windowKey, xOffset, yOffset, btnW, btnH, yScale)
		if not windowFrame or not topBar then return end

		local key = windowKey or windowFrame.Name or "Window"
		local w = btnW or 28
		local h = btnH or 26
		local posX = xOffset or -66
		local posY = yOffset or 8
		local posYS = yScale or 0

		local pinBtn = Instance.new("TextButton")
		pinBtn.Name = "AlwaysOnTopPinBtn"
		pinBtn.Size = UDim2.new(0, w, 0, h)
		pinBtn.Position = UDim2.new(1, posX, posYS, posY)
		pinBtn.BackgroundColor3 = THEME.BtnOff
		pinBtn.Font = Enum.Font.GothamBold
		pinBtn.Text = "📌"
		pinBtn.TextColor3 = THEME.TextDim
		pinBtn.TextSize = 11
		pinBtn.ZIndex = 25
		pinBtn.AutoButtonColor = false
		pinBtn.Parent = topBar

		local pinCorner = Instance.new("UICorner")
		pinCorner.CornerRadius = UDim.new(0, 5)
		pinCorner.Parent = pinBtn

		local pinStroke = Instance.new("UIStroke")
		pinStroke.Color = THEME.BtnOffStroke
		pinStroke.Thickness = 1
		pinStroke.Parent = pinBtn

		local isPinned = false

		local function updatePinVisual()
			if isPinned then
				pinBtn.BackgroundColor3 = Color3.fromRGB(16, 42, 68)
				pinBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
				pinStroke.Color = THEME.BorderBeam
				pinStroke.Thickness = 1.4
			else
				pinBtn.BackgroundColor3 = THEME.BtnOff
				pinBtn.TextColor3 = THEME.TextDim
				pinStroke.Color = THEME.BtnOffStroke
				pinStroke.Thickness = 1
			end
		end

		pinBtn.MouseEnter:Connect(function()
			if not isPinned then
				pinBtn.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
				pinBtn.TextColor3 = THEME.TextCyan
			else
				pinBtn.BackgroundColor3 = Color3.fromRGB(24, 60, 96)
			end
		end)

		pinBtn.MouseLeave:Connect(function()
			updatePinVisual()
		end)

		pinBtn.MouseButton1Click:Connect(function()
			isPinned = not isPinned
			pinnedWindowsRegistry[key] = isPinned
			windowFrame:SetAttribute("AlwaysOnTop", isPinned)

			if isPinned then
				local pGui = getPinnedGui()
				if pGui then
					windowFrame.Parent = pGui
				end
			else
				if screenGui then
					windowFrame.Parent = screenGui
				end
			end

			updatePinVisual()
		end)

		updatePinVisual()
		return pinBtn
	end

	-- =====================================================================
	-- PRISON RP NATIVE BROWSER TOGGLE BUTTON
	-- (StarterGui / PlayerGui.MainGui.Left.Browser)
	-- =====================================================================
	-- updateBrowserVisualFn declared in shared_decls


BP_INSPECT = {
	modal = nil,
	target = nil,
	liveTaskRunning = false,
	profileCard = nil,
	avatar = nil,
	name = nil,
	sub = nil,
	mic = nil,
	scroll = nil,
}

openBackpackInspector = function(targetPlr)
	if not targetPlr then return end
	BP_INSPECT.target = targetPlr

	if not BP_INSPECT.modal then
		BP_INSPECT.modal = Instance.new("Frame")
		BP_INSPECT.modal.Name = "AstrocynaBackpackModal"
		BP_INSPECT.modal.Size = UDim2.new(0, 440, 0, 430)
		BP_INSPECT.modal.Position = UDim2.new(0.5, -220, 0.5, -215)
		BP_INSPECT.modal.BackgroundColor3 = THEME.MainBg
		BP_INSPECT.modal.BackgroundTransparency = 0.05
		BP_INSPECT.modal.BorderSizePixel = 0
		BP_INSPECT.modal.ClipsDescendants = true
		BP_INSPECT.modal.Visible = false
		BP_INSPECT.modal.ZIndex = 60
		BP_INSPECT.modal.Parent = screenGui
		applyResponsiveWindowScale(BP_INSPECT.modal, 440, 430, true)

		local bmCorner = Instance.new("UICorner")
		bmCorner.CornerRadius = UDim.new(0, 10)
		bmCorner.Parent = BP_INSPECT.modal
		local bmStroke = Instance.new("UIStroke")
		bmStroke.Color = Color3.fromRGB(0, 215, 255)
		bmStroke.Thickness = 1.8
		bmStroke.Parent = BP_INSPECT.modal
		applyNeonSweep(bmStroke, 110, 2.5, 1.8, 2.6)

		local bmTopBar = Instance.new("Frame")
		bmTopBar.Name = "TopBar"
		bmTopBar.Size = UDim2.new(1, 0, 0, 40)
		bmTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
		bmTopBar.BorderSizePixel = 0
		bmTopBar.Parent = BP_INSPECT.modal

		local bmtCorner = Instance.new("UICorner")
		bmtCorner.CornerRadius = UDim.new(0, 10)
		bmtCorner.Parent = bmTopBar

		local bmTitle = Instance.new("TextLabel")
		bmTitle.Size = UDim2.new(1, -74, 1, 0)
		bmTitle.Position = UDim2.new(0, 14, 0, 0)
		bmTitle.BackgroundTransparency = 1
		bmTitle.Font = Enum.Font.GothamBold
		bmTitle.Text = "🎒 BACKPACK & INVENTORY INSPECTION"
		bmTitle.TextColor3 = THEME.TextCyan
		bmTitle.TextSize = 11
		bmTitle.TextXAlignment = Enum.TextXAlignment.Left
		bmTitle.Parent = bmTopBar
		applyTextShimmer(bmTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

		makeDraggable(BP_INSPECT.modal, bmTopBar)
		makeDraggable(BP_INSPECT.modal, bmTitle)

		local bmClose = Instance.new("TextButton")
		bmClose.Size = UDim2.new(0, 26, 0, 26)
		bmClose.Position = UDim2.new(1, -34, 0.5, -13)
		bmClose.BackgroundColor3 = THEME.BtnOff
		bmClose.Font = Enum.Font.GothamBold
		bmClose.Text = "X"
		bmClose.TextColor3 = THEME.TextCyan
		bmClose.TextSize = 11
		bmClose.Parent = bmTopBar
		local bmcCorner = Instance.new("UICorner")
		bmcCorner.CornerRadius = UDim.new(0, 5)
		bmcCorner.Parent = bmClose
		local bmcStroke = Instance.new("UIStroke")
		bmcStroke.Color = THEME.BtnOffStroke
		bmcStroke.Thickness = 1
		bmcStroke.Parent = bmClose
		hookButtonHover(bmClose, THEME.BtnOff, Color3.fromRGB(44, 44, 48), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
		bmClose.MouseButton1Click:Connect(function()
			BP_INSPECT.modal.Visible = false
		end)

		attachAlwaysOnTopButton(BP_INSPECT.modal, bmTopBar, "BackpackInspectorModal", -64, -13, 26, 26, 0.5)

		local profileCard = Instance.new("Frame")
		profileCard.Name = "ProfileCard"
		profileCard.Size = UDim2.new(1, -20, 0, 64)
		profileCard.Position = UDim2.new(0, 10, 0, 48)
		profileCard.BackgroundColor3 = Color3.fromRGB(13, 24, 38)
		profileCard.BorderSizePixel = 0
		profileCard.Parent = BP_INSPECT.modal
		local pcCorner = Instance.new("UICorner")
		pcCorner.CornerRadius = UDim.new(0, 8)
		pcCorner.Parent = profileCard
		local pcStroke = Instance.new("UIStroke")
		pcStroke.Color = THEME.CardStroke
		pcStroke.Thickness = 1
		pcStroke.Parent = profileCard

		local bmAvatar = Instance.new("ImageLabel")
		bmAvatar.Name = "Avatar"
		bmAvatar.Size = UDim2.new(0, 44, 0, 44)
		bmAvatar.Position = UDim2.new(0, 10, 0.5, -22)
		bmAvatar.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
		bmAvatar.Parent = profileCard
		local avc = Instance.new("UICorner")
		avc.CornerRadius = UDim.new(0, 22)
		avc.Parent = bmAvatar
		local avs = Instance.new("UIStroke")
		avs.Color = THEME.BorderBase
		avs.Thickness = 1
		avs.Parent = bmAvatar

		local bmName = Instance.new("TextLabel")
		bmName.Name = "NameLabel"
		bmName.Size = UDim2.new(1, -66, 0, 18)
		bmName.Position = UDim2.new(0, 62, 0, 8)
		bmName.BackgroundTransparency = 1
		bmName.Font = Enum.Font.GothamBold
		bmName.Text = "Loading..."
		bmName.TextColor3 = THEME.TextFrost
		bmName.TextSize = 12
		bmName.TextXAlignment = Enum.TextXAlignment.Left
		bmName.TextTruncate = Enum.TextTruncate.AtEnd
		bmName.Parent = profileCard

		local bmSub = Instance.new("TextLabel")
		bmSub.Name = "SubLabel"
		bmSub.Size = UDim2.new(1, -66, 0, 14)
		bmSub.Position = UDim2.new(0, 62, 0, 26)
		bmSub.BackgroundTransparency = 1
		bmSub.Font = Enum.Font.Gotham
		bmSub.Text = "..."
		bmSub.TextColor3 = THEME.TextDim
		bmSub.TextSize = 9.5
		bmSub.TextXAlignment = Enum.TextXAlignment.Left
		bmSub.TextTruncate = Enum.TextTruncate.AtEnd
		bmSub.Parent = profileCard

		local bmMic = Instance.new("TextLabel")
		bmMic.Name = "MicLabel"
		bmMic.Size = UDim2.new(1, -66, 0, 14)
		bmMic.Position = UDim2.new(0, 62, 0, 42)
		bmMic.BackgroundTransparency = 1
		bmMic.Font = Enum.Font.GothamBold
		bmMic.Text = "🎙️ Mic: Measuring..."
		bmMic.TextColor3 = THEME.TextCyan
		bmMic.TextSize = 9.5
		bmMic.TextXAlignment = Enum.TextXAlignment.Left
		bmMic.Parent = profileCard

		local bpScroll = Instance.new("ScrollingFrame")
		bpScroll.Name = "ItemsScroll"
		bpScroll.Size = UDim2.new(1, -20, 1, -164)
		bpScroll.Position = UDim2.new(0, 10, 0, 118)
		bpScroll.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
		bpScroll.BackgroundTransparency = 0.4
		bpScroll.BorderSizePixel = 0
		bpScroll.ScrollBarThickness = 4
		bpScroll.ScrollBarImageColor3 = THEME.BorderBeam
		bpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		bpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		bpScroll.Parent = BP_INSPECT.modal

		BP_INSPECT.profileCard = profileCard
		BP_INSPECT.avatar = bmAvatar
		BP_INSPECT.name = bmName
		BP_INSPECT.sub = bmSub
		BP_INSPECT.mic = bmMic
		BP_INSPECT.scroll = bpScroll

		local bpsCorner = Instance.new("UICorner")
		bpsCorner.CornerRadius = UDim.new(0, 8)
		bpsCorner.Parent = bpScroll
		local bpsStroke = Instance.new("UIStroke")
		bpsStroke.Color = THEME.CardStroke
		bpsStroke.Thickness = 1
		bpsStroke.Parent = bpScroll

		local bLayout = Instance.new("UIListLayout")
		bLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bLayout.Padding = UDim.new(0, 5)
		bLayout.Parent = bpScroll

		local bPad = Instance.new("UIPadding")
		bPad.PaddingTop = UDim.new(0, 6)
		bPad.PaddingBottom = UDim.new(0, 6)
		bPad.PaddingLeft = UDim.new(0, 6)
		bPad.PaddingRight = UDim.new(0, 6)
		bPad.Parent = bpScroll

		local bmFooter = Instance.new("Frame")
		bmFooter.Size = UDim2.new(1, -20, 0, 36)
		bmFooter.Position = UDim2.new(0, 10, 1, -42)
		bmFooter.BackgroundTransparency = 1
		bmFooter.Parent = BP_INSPECT.modal

		local bmRefreshBtn = Instance.new("TextButton")
		bmRefreshBtn.Size = UDim2.new(0, 140, 1, 0)
		bmRefreshBtn.Position = UDim2.new(0, 0, 0, 0)
		bmRefreshBtn.BackgroundColor3 = Color3.fromRGB(16, 34, 52)
		bmRefreshBtn.Font = Enum.Font.GothamBold
		bmRefreshBtn.Text = "⚡ REFRESH ITEMS"
		bmRefreshBtn.TextColor3 = THEME.TextCyan
		bmRefreshBtn.TextSize = 10
		bmRefreshBtn.Parent = bmFooter
		local rfc = Instance.new("UICorner")
		rfc.CornerRadius = UDim.new(0, 6)
		rfc.Parent = bmRefreshBtn
		local rfs = Instance.new("UIStroke")
		rfs.Color = THEME.BorderBeam
		rfs.Thickness = 1
		rfs.Parent = bmRefreshBtn
		hookButtonHover(bmRefreshBtn, Color3.fromRGB(16, 34, 52), Color3.fromRGB(22, 48, 74), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
		bmRefreshBtn.MouseButton1Click:Connect(function()
			refreshBackpackUI()
		end)

		local bmCloseBtn2 = Instance.new("TextButton")
		bmCloseBtn2.Size = UDim2.new(0, 90, 1, 0)
		bmCloseBtn2.Position = UDim2.new(1, -90, 0, 0)
		bmCloseBtn2.BackgroundColor3 = THEME.BtnOff
		bmCloseBtn2.Font = Enum.Font.GothamBold
		bmCloseBtn2.Text = "CLOSE"
		bmCloseBtn2.TextColor3 = THEME.TextDim
		bmCloseBtn2.TextSize = 10
		bmCloseBtn2.Parent = bmFooter
		local cbc = Instance.new("UICorner")
		cbc.CornerRadius = UDim.new(0, 6)
		cbc.Parent = bmCloseBtn2
		local cbs = Instance.new("UIStroke")
		cbs.Color = THEME.BtnOffStroke
		cbs.Thickness = 1
		cbs.Parent = bmCloseBtn2
		hookButtonHover(bmCloseBtn2, THEME.BtnOff, Color3.fromRGB(28, 32, 40), THEME.TextDim, THEME.TextFrost)
		bmCloseBtn2.MouseButton1Click:Connect(function()
			BP_INSPECT.modal.Visible = false
		end)
	end

	refreshBackpackUI = function()
		if not BP_INSPECT.target or not BP_INSPECT.modal then return end
		local p = BP_INSPECT.target
		local pCard = BP_INSPECT.profileCard or BP_INSPECT.modal:FindFirstChild("ProfileCard")
		if not pCard then return end

		local av = BP_INSPECT.avatar or pCard:FindFirstChild("Avatar")
		local nLabel = BP_INSPECT.name or pCard:FindFirstChild("NameLabel")
		local sLabel = BP_INSPECT.sub or pCard:FindFirstChild("SubLabel")
		local mLabel = BP_INSPECT.mic or pCard:FindFirstChild("MicLabel")
		local bpScroll = BP_INSPECT.scroll or BP_INSPECT.modal:FindFirstChild("ItemsScroll")

		if nLabel then nLabel.Text = p.DisplayName .. " (@" .. p.Name .. ")" end
		local teamName = p.Team and p.Team.Name or "No Team"
		local isStaff = checkPlayerStaff(p)
		local gInfo = GANG_SYS and GANG_SYS.getPlayerGang(p.UserId)
		local gangStr = ""
		if gInfo then
			local baseTag = (gInfo.gangTag ~= "" and ("[" .. gInfo.gangTag .. "] ") or "") .. gInfo.gangName .. " (" .. gInfo.role .. ")"
			gangStr = " | 🏴‍☠️ " .. baseTag .. (gInfo.isTagHidden and " [Tag Off]" or "")
		end
		if sLabel then
			sLabel.Text = string.format("Role: %s | ID: %s | %s%s", teamName, tostring(p.UserId), isStaff and "[STAFF]" or "[CIVILIAN]", gangStr)
			sLabel.TextColor3 = p.TeamColor and p.TeamColor.Color or THEME.TextDim
		end

		if mLabel then
			local micText, micColor = getPlayerMicStatus(p)
			mLabel.Text = "Live Mic: " .. micText
			mLabel.TextColor3 = micColor
		end

		if av then
			getCachedThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100, function(thumb)
				if av and BP_INSPECT.target == p then
					av.Image = thumb
				end
			end)
		end

		if not bpScroll then return end
		for _, ch in ipairs(bpScroll:GetChildren()) do
			if ch:IsA("Frame") or ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("ImageButton") then
				ch:Destroy()
			end
		end

		local tChar = getPlayerChar and getPlayerChar(p) or p.Character
		local heldTool = tChar and tChar:FindFirstChildOfClass("Tool")

		local function makeSectionTitle(title, order)
			local st = Instance.new("TextLabel")
			st.Size = UDim2.new(1, 0, 0, 20)
			st.BackgroundTransparency = 1
			st.Font = Enum.Font.GothamBold
			st.Text = title
			st.TextColor3 = THEME.TextCyan
			st.TextSize = 10
			st.TextXAlignment = Enum.TextXAlignment.Left
			st.LayoutOrder = order
			st.Parent = bpScroll
			return st
		end

		local function makeItemCard(item, isEquipped, order)
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 36)
			card.BackgroundColor3 = Color3.fromRGB(15, 26, 40)
			card.BorderSizePixel = 0
			card.LayoutOrder = order
			card.Parent = bpScroll
			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 6)
			cCorner.Parent = card
			local cStroke = Instance.new("UIStroke")
			cStroke.Color = THEME.CardStroke
			cStroke.Thickness = 1
			cStroke.Parent = card

			local kind, _reason = classifyToolForPlayer(item.Name, teamName, isStaff or isStaffOrAdmin(p))

			local iconLbl = Instance.new("TextLabel")
			iconLbl.Size = UDim2.new(0, 24, 1, 0)
			iconLbl.Position = UDim2.new(0, 8, 0, 0)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Font = Enum.Font.GothamBold
			iconLbl.Text = isEquipped and "✋" or "🎒"
			iconLbl.TextSize = 14
			iconLbl.Parent = card

			local titleLbl = Instance.new("TextLabel")
			titleLbl.Size = UDim2.new(1, -150, 0, 16)
			titleLbl.Position = UDim2.new(0, 36, 0, 4)
			titleLbl.BackgroundTransparency = 1
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.Text = item.Name .. (isEquipped and " [IN HAND]" or "")
			titleLbl.TextColor3 = THEME.TextFrost
			titleLbl.TextSize = 10.5
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			titleLbl.Parent = card

			local classLbl = Instance.new("TextLabel")
			classLbl.Size = UDim2.new(1, -150, 0, 12)
			classLbl.Position = UDim2.new(0, 36, 0, 20)
			classLbl.BackgroundTransparency = 1
			classLbl.Font = Enum.Font.Gotham
			classLbl.Text = "Class: " .. item.ClassName
			classLbl.TextColor3 = THEME.TextDim
			classLbl.TextSize = 8.5
			classLbl.TextXAlignment = Enum.TextXAlignment.Left
			classLbl.Parent = card

			local tagBadge = Instance.new("Frame")
			tagBadge.Size = UDim2.new(0, 100, 0, 20)
			tagBadge.Position = UDim2.new(1, -106, 0.5, -10)
			tagBadge.BorderSizePixel = 0
			tagBadge.Parent = card
			local tbc = Instance.new("UICorner")
			tbc.CornerRadius = UDim.new(0, 4)
			tbc.Parent = tagBadge

			local tagText = Instance.new("TextLabel")
			tagText.Size = UDim2.new(1, 0, 1, 0)
			tagText.BackgroundTransparency = 1
			tagText.Font = Enum.Font.GothamBold
			tagText.TextSize = 8.5
			tagText.Parent = tagBadge

			if kind == "admin" then
				tagBadge.BackgroundColor3 = Color3.fromRGB(48, 12, 18)
				tagText.Text = "🚨 ADMIN TOOL"
				tagText.TextColor3 = Color3.fromRGB(255, 60, 80)
				cStroke.Color = Color3.fromRGB(255, 40, 60)
			elseif kind == "cross_role" then
				tagBadge.BackgroundColor3 = Color3.fromRGB(54, 16, 26)
				tagText.Text = "⚠️ CROSS-ROLE"
				tagText.TextColor3 = Color3.fromRGB(255, 80, 100)
				cStroke.Color = Color3.fromRGB(255, 60, 80)
			elseif kind == "general_weapon" then
				tagBadge.BackgroundColor3 = Color3.fromRGB(20, 32, 48)
				tagText.Text = "⚔️ WEAPON"
				tagText.TextColor3 = THEME.TextFrost
				cStroke.Color = THEME.CardStroke
			elseif kind == "radio" then
				tagBadge.BackgroundColor3 = Color3.fromRGB(12, 34, 48)
				tagText.Text = "📻 RADIO"
				tagText.TextColor3 = Color3.fromRGB(0, 215, 255)
				cStroke.Color = THEME.CardStroke
			elseif kind == "role_allowed" then
				tagBadge.BackgroundColor3 = Color3.fromRGB(12, 36, 24)
				tagText.Text = "✅ ROLE ITEM"
				tagText.TextColor3 = Color3.fromRGB(0, 220, 140)
			else
				tagBadge.BackgroundColor3 = Color3.fromRGB(16, 28, 42)
				tagText.Text = "📦 STANDARD"
				tagText.TextColor3 = THEME.TextCyan
			end

			return card
		end

		makeSectionTitle("CURRENTLY EQUIPPED [IN HAND]", 1)
		if heldTool then
			makeItemCard(heldTool, true, 2)
		else
			local emptyHeld = Instance.new("TextLabel")
			emptyHeld.Size = UDim2.new(1, 0, 0, 24)
			emptyHeld.BackgroundTransparency = 1
			emptyHeld.Font = Enum.Font.Gotham
			emptyHeld.Text = "  None (Hands Free)"
			emptyHeld.TextColor3 = THEME.TextDim
			emptyHeld.TextSize = 10
			emptyHeld.TextXAlignment = Enum.TextXAlignment.Left
			emptyHeld.LayoutOrder = 2
			emptyHeld.Parent = bpScroll
		end

		local bp = p:FindFirstChild("Backpack")
		local tools = {}
		if bp then
			for _, it in ipairs(bp:GetChildren()) do
				if it:IsA("Tool") or it:IsA("HopperBin") then
					table.insert(tools, it)
				end
			end
		end

		makeSectionTitle("BACKPACK INVENTORY (" .. tostring(#tools) .. " ITEMS)", 10)
		if #tools == 0 then
			local emptyBp = Instance.new("TextLabel")
			emptyBp.Size = UDim2.new(1, 0, 0, 28)
			emptyBp.BackgroundTransparency = 1
			emptyBp.Font = Enum.Font.Gotham
			emptyBp.Text = "  Backpack is empty (No items carried)"
			emptyBp.TextColor3 = THEME.TextDim
			emptyBp.TextSize = 10
			emptyBp.TextXAlignment = Enum.TextXAlignment.Left
			emptyBp.LayoutOrder = 11
			emptyBp.Parent = bpScroll
		else
			for idx, it in ipairs(tools) do
				makeItemCard(it, false, 11 + idx)
			end
		end
	end

	BP_INSPECT.modal.Visible = true
	refreshBackpackUI()

	if not BP_INSPECT.liveTaskRunning then
		BP_INSPECT.liveTaskRunning = true
		task.spawn(function()
			while BP_INSPECT.modal and BP_INSPECT.modal.Visible do
				task.wait(0.5)
				if BP_INSPECT.modal and BP_INSPECT.modal.Visible and BP_INSPECT.target then
					pcall(refreshBackpackUI)
				end
			end
			BP_INSPECT.liveTaskRunning = false
		end)
	end
end


WIN_BUILDERS = {}
WIN_BUILDERS.buildPlayers = function()

	local pfBlacklistBadge = nil
	local pfBlacklistStroke = nil
	local pfBlacklistText = nil
	local pfStaffBadge = nil
	local pfStaffStroke = nil
	local pfStaffText = nil
	local pfCountLabel = nil
	local refreshPlayerList = function() end
	local addBlacklistView = nil
	local refreshVaultList = nil

	local plrFrame = Instance.new("Frame")
	plrFrame.Name = "PlayersWindow"
	plrFrame.Size = UDim2.new(0, 420, 0, 480)
	plrFrame.Position = UDim2.new(0, 376, 0.5, -240)
	plrFrame.BackgroundColor3 = THEME.MainBg
	plrFrame.BackgroundTransparency = THEME.MainBgTransparency
	plrFrame.BorderSizePixel = 0
	plrFrame.Visible = false
	plrFrame.ClipsDescendants = true
	plrFrame.Parent = screenGui
playersWindow = plrFrame
	applyResponsiveWindowScale(plrFrame, 420, 480, false)

	local pfCorner = Instance.new("UICorner")
	pfCorner.CornerRadius = UDim.new(0, 10)
	pfCorner.Parent = plrFrame

	local pfBevel = Instance.new("UIGradient")
	pfBevel.Rotation = 90
	pfBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	pfBevel.Parent = plrFrame

	local pfStroke = Instance.new("UIStroke")
	pfStroke.Thickness = 2.0
	pfStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pfStroke.Parent = plrFrame
	applyNeonSweep(pfStroke, 110, 2.5, 1.8, 2.6)

	local pfTopBar = Instance.new("Frame")
	pfTopBar.Size = UDim2.new(1, 0, 0, 42)
	pfTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	pfTopBar.BorderSizePixel = 0
	pfTopBar.Parent = plrFrame

	local pfTopCorner = Instance.new("UICorner")
	pfTopCorner.CornerRadius = UDim.new(0, 10)
	pfTopCorner.Parent = pfTopBar

	local pfTopStroke = Instance.new("UIStroke")
	pfTopStroke.Color = Color3.fromRGB(48, 48, 54)
	pfTopStroke.Thickness = 1
	pfTopStroke.Parent = pfTopBar

	local pfTitle = Instance.new("TextLabel")
	pfTitle.Size = UDim2.new(0, 116, 1, 0)
	pfTitle.Position = UDim2.new(0, 12, 0, 0)
	pfTitle.BackgroundTransparency = 1
	pfTitle.Font = Enum.Font.GothamBold
	pfTitle.Text = "ASTROCYNA // PLAYERS"
	pfTitle.TextColor3 = THEME.TextCyan
	pfTitle.TextSize = 11
	pfTitle.TextXAlignment = Enum.TextXAlignment.Left
	pfTitle.Parent = pfTopBar
	applyTextShimmer(pfTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	pfBlacklistBadge = Instance.new("Frame")
	pfBlacklistBadge.Name = "BlacklistCountBadge"
	pfBlacklistBadge.Size = UDim2.new(0, 74, 0, 22)
	pfBlacklistBadge.Position = UDim2.new(1, -286, 0.5, -11)
	pfBlacklistBadge.BackgroundColor3 = Color3.fromRGB(22, 10, 14)
	pfBlacklistBadge.Parent = pfTopBar
	local pfBlCorner = Instance.new("UICorner")
	pfBlCorner.CornerRadius = UDim.new(0, 5)
	pfBlCorner.Parent = pfBlacklistBadge
	pfBlacklistStroke = Instance.new("UIStroke")
	pfBlacklistStroke.Color = Color3.fromRGB(255, 30, 50)
	pfBlacklistStroke.Thickness = 1
	pfBlacklistStroke.Parent = pfBlacklistBadge

	pfBlacklistText = Instance.new("TextLabel")
	pfBlacklistText.Size = UDim2.new(1, 0, 1, 0)
	pfBlacklistText.BackgroundTransparency = 1
	pfBlacklistText.Font = Enum.Font.GothamBold
	pfBlacklistText.Text = "⛔ 0 BLOCKED"
	pfBlacklistText.TextColor3 = THEME.TextDim
	pfBlacklistText.TextSize = 9
	pfBlacklistText.Parent = pfBlacklistBadge

	local pfBlacklistClick = Instance.new("TextButton")
	pfBlacklistClick.Size = UDim2.new(1, 0, 1, 0)
	pfBlacklistClick.BackgroundTransparency = 1
	pfBlacklistClick.Text = ""
	pfBlacklistClick.Parent = pfBlacklistBadge
	pfBlacklistClick.MouseButton1Click:Connect(function()
		if ADMIN_SYS.showServerBrowserForBlacklist then
			ADMIN_SYS.showServerBrowserForBlacklist()
		end
	end)

	pfStaffBadge = Instance.new("Frame")
	pfStaffBadge.Name = "StaffCountBadge"
	pfStaffBadge.Size = UDim2.new(0, 70, 0, 22)
	pfStaffBadge.Position = UDim2.new(1, -206, 0.5, -11)
	pfStaffBadge.BackgroundColor3 = Color3.fromRGB(20, 10, 16)
	pfStaffBadge.Parent = pfTopBar
	local pfStaffCorner = Instance.new("UICorner")
	pfStaffCorner.CornerRadius = UDim.new(0, 5)
	pfStaffCorner.Parent = pfStaffBadge
	pfStaffStroke = Instance.new("UIStroke")
	pfStaffStroke.Color = Color3.fromRGB(255, 50, 80)
	pfStaffStroke.Thickness = 1
	pfStaffStroke.Parent = pfStaffBadge

	pfStaffText = Instance.new("TextLabel")
	pfStaffText.Size = UDim2.new(1, 0, 1, 0)
	pfStaffText.BackgroundTransparency = 1
	pfStaffText.Font = Enum.Font.GothamBold
	pfStaffText.Text = "🛡️ 0 STAFF"
	pfStaffText.TextColor3 = THEME.TextDim
	pfStaffText.TextSize = 9
	pfStaffText.Parent = pfStaffBadge

	pfCountLabel = Instance.new("TextLabel")
	pfCountLabel.Size = UDim2.new(0, 56, 1, 0)
	pfCountLabel.Position = UDim2.new(1, -130, 0, 0)
	pfCountLabel.BackgroundTransparency = 1
	pfCountLabel.Font = Enum.Font.GothamBold
	pfCountLabel.Text = "0 ONLINE"
	pfCountLabel.TextColor3 = THEME.TextCyan
	pfCountLabel.TextSize = 10
	pfCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	pfCountLabel.Parent = pfTopBar

	attachAlwaysOnTopButton(plrFrame, pfTopBar, "PlayersWindow", -66, 8, 28, 26)

	local pfCloseBtn = Instance.new("TextButton")
	pfCloseBtn.Size = UDim2.new(0, 28, 0, 26)
	pfCloseBtn.Position = UDim2.new(1, -34, 0, 8)
	pfCloseBtn.BackgroundColor3 = THEME.BtnOff
	pfCloseBtn.Font = Enum.Font.GothamBold
	pfCloseBtn.Text = "X"
	pfCloseBtn.TextColor3 = THEME.TextCyan
	pfCloseBtn.TextSize = 11
	pfCloseBtn.Parent = pfTopBar
	local pfcCorner2 = Instance.new("UICorner")
	pfcCorner2.CornerRadius = UDim.new(0, 5)
	pfcCorner2.Parent = pfCloseBtn
	local pfcStroke2 = Instance.new("UIStroke")
	pfcStroke2.Color = THEME.BtnOffStroke
	pfcStroke2.Thickness = 1
	pfcStroke2.Parent = pfCloseBtn
	hookButtonHover(pfCloseBtn, THEME.BtnOff, Color3.fromRGB(44, 44, 48), THEME.TextCyan, Color3.fromRGB(255, 255, 255))

	pfCloseBtn.MouseButton1Click:Connect(function()
		plrFrame.Visible = false
	end)

	local pfContent = Instance.new("Frame")
	pfContent.Name = "Content"
	pfContent.Size = UDim2.new(1, 0, 1, -44)
	pfContent.Position = UDim2.new(0, 0, 0, 44)
	pfContent.BackgroundTransparency = 1
	pfContent.ClipsDescendants = true
	pfContent.Parent = plrFrame

	local listView = Instance.new("Frame")
	listView.Name = "ListView"
	listView.Size = UDim2.new(1, 0, 1, 0)
	listView.BackgroundTransparency = 1
	listView.Visible = true
	listView.Parent = pfContent

	local searchFrame = Instance.new("Frame")
	searchFrame.Size = UDim2.new(1, -118, 0, 32)
	searchFrame.Position = UDim2.new(0, 8, 0, 6)
	searchFrame.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
	searchFrame.Parent = listView
	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 6)
	sfCorner.Parent = searchFrame
	local sfStroke = Instance.new("UIStroke")
	sfStroke.Color = THEME.CardStroke
	sfStroke.Thickness = 1
	sfStroke.Parent = searchFrame

	local searchIcon = Instance.new("TextLabel")
	searchIcon.Size = UDim2.new(0, 26, 1, 0)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Font = Enum.Font.GothamBold
	searchIcon.Text = "🔍"
	searchIcon.TextColor3 = THEME.TextCyan
	searchIcon.TextSize = 11
	searchIcon.Parent = searchFrame

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -34, 1, 0)
	searchBox.Position = UDim2.new(0, 28, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.Font = Enum.Font.Gotham
	searchBox.PlaceholderText = "Search players in-game..."
	searchBox.PlaceholderColor3 = THEME.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = THEME.TextFrost
	searchBox.TextSize = 10.5
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchFrame

	local addBlNavBtn = Instance.new("TextButton")
	addBlNavBtn.Size = UDim2.new(0, 96, 0, 32)
	addBlNavBtn.Position = UDim2.new(1, -104, 0, 6)
	addBlNavBtn.BackgroundColor3 = Color3.fromRGB(36, 12, 18)
	addBlNavBtn.Font = Enum.Font.GothamBold
	addBlNavBtn.Text = "⛔ ADD BL"
	addBlNavBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
	addBlNavBtn.TextSize = 10
	addBlNavBtn.AutoButtonColor = false
	addBlNavBtn.Parent = listView
	local ablCorner = Instance.new("UICorner")
	ablCorner.CornerRadius = UDim.new(0, 6)
	ablCorner.Parent = addBlNavBtn
	local ablStroke = Instance.new("UIStroke")
	ablStroke.Color = Color3.fromRGB(220, 40, 60)
	ablStroke.Thickness = 1
	ablStroke.Parent = addBlNavBtn
	hookButtonHover(addBlNavBtn, Color3.fromRGB(36, 12, 18), Color3.fromRGB(56, 18, 28), Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 255, 255))

	local plrScroll = Instance.new("ScrollingFrame")
	plrScroll.Size = UDim2.new(1, -16, 1, -48)
	plrScroll.Position = UDim2.new(0, 8, 0, 44)
	plrScroll.BackgroundTransparency = 1
	plrScroll.BorderSizePixel = 0
	plrScroll.ScrollBarThickness = 4
	plrScroll.ScrollBarImageColor3 = THEME.BorderBeam
	plrScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	plrScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	plrScroll.Parent = listView

	local plrListLayout = Instance.new("UIListLayout")
	plrListLayout.SortOrder = Enum.SortOrder.Name
	plrListLayout.Padding = UDim.new(0, 4)
	plrListLayout.Parent = plrScroll

	plrListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		pcall(function()
			plrScroll.CanvasSize = UDim2.new(0, 0, 0, plrListLayout.AbsoluteContentSize.Y + 8)
		end)
	end)

	local detailView = Instance.new("Frame")
	detailView.Name = "DetailView"
	detailView.Size = UDim2.new(1, 0, 1, 0)
	detailView.BackgroundTransparency = 1
	detailView.Visible = false
	detailView.Parent = pfContent

	local detailNavBar = Instance.new("Frame")
	detailNavBar.Size = UDim2.new(1, -20, 0, 30)
	detailNavBar.Position = UDim2.new(0, 10, 0, 6)
	detailNavBar.BackgroundTransparency = 1
	detailNavBar.Parent = detailView

	local backBtn = Instance.new("TextButton")
	backBtn.Size = UDim2.new(0, 74, 1, 0)
	backBtn.Position = UDim2.new(0, 0, 0, 0)
	backBtn.BackgroundColor3 = THEME.BtnOff
	backBtn.Font = Enum.Font.GothamBold
	backBtn.Text = "< BACK"
	backBtn.TextColor3 = THEME.TextCyan
	backBtn.TextSize = 11
	backBtn.Parent = detailNavBar
	local bkCorner = Instance.new("UICorner")
	bkCorner.CornerRadius = UDim.new(0, 6)
	bkCorner.Parent = backBtn
	local bkStroke = Instance.new("UIStroke")
	bkStroke.Color = THEME.BtnOffStroke
	bkStroke.Thickness = 1
	bkStroke.Parent = backBtn
	hookButtonHover(backBtn, THEME.BtnOff, Color3.fromRGB(18, 36, 56), THEME.TextCyan, THEME.BorderHighlight)

	local blToggleBtn = Instance.new("TextButton")
	blToggleBtn.Size = UDim2.new(0, 130, 1, 0)
	blToggleBtn.Position = UDim2.new(0, 82, 0, 0)
	blToggleBtn.BackgroundColor3 = Color3.fromRGB(24, 12, 16)
	blToggleBtn.Font = Enum.Font.GothamBold
	blToggleBtn.Text = "🚫 BLACKLIST"
	blToggleBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
	blToggleBtn.TextSize = 10
	blToggleBtn.Parent = detailNavBar
	local bltCorner = Instance.new("UICorner")
	bltCorner.CornerRadius = UDim.new(0, 6)
	bltCorner.Parent = blToggleBtn
	local bltStroke = Instance.new("UIStroke")
	bltStroke.Color = Color3.fromRGB(180, 40, 60)
	bltStroke.Thickness = 1
	bltStroke.Parent = blToggleBtn

	local stopSpecBtn = Instance.new("TextButton")
	stopSpecBtn.Size = UDim2.new(0, 120, 1, 0)
	stopSpecBtn.Position = UDim2.new(1, -120, 0, 0)
	stopSpecBtn.BackgroundColor3 = Color3.fromRGB(28, 14, 22)
	stopSpecBtn.Font = Enum.Font.GothamBold
	stopSpecBtn.Text = "⏹ STOP SPECTATE"
	stopSpecBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
	stopSpecBtn.TextSize = 10
	stopSpecBtn.Visible = false
	stopSpecBtn.Parent = detailNavBar
	local ssCorner = Instance.new("UICorner")
	ssCorner.CornerRadius = UDim.new(0, 6)
	ssCorner.Parent = stopSpecBtn
	local ssStroke = Instance.new("UIStroke")
	ssStroke.Color = Color3.fromRGB(255, 60, 90)
	ssStroke.Thickness = 1
	ssStroke.Parent = stopSpecBtn
	hookButtonHover(stopSpecBtn, Color3.fromRGB(28, 14, 22), Color3.fromRGB(48, 18, 30), Color3.fromRGB(220, 220, 225), Color3.fromRGB(255, 210, 220))

	local detailHeader = Instance.new("Frame")
	detailHeader.Size = UDim2.new(1, -20, 0, 72)
	detailHeader.Position = UDim2.new(0, 10, 0, 42)
	detailHeader.BackgroundColor3 = THEME.CardBg
	detailHeader.BorderSizePixel = 0
	detailHeader.Parent = detailView
	local dhCorner = Instance.new("UICorner")
	dhCorner.CornerRadius = UDim.new(0, 8)
	dhCorner.Parent = detailHeader
	local dhStroke = Instance.new("UIStroke")
	dhStroke.Color = THEME.CardStroke
	dhStroke.Thickness = 1
	dhStroke.Parent = detailHeader

	local detailAvatar = Instance.new("ImageLabel")
	detailAvatar.Size = UDim2.new(0, 52, 0, 52)
	detailAvatar.Position = UDim2.new(0, 10, 0.5, -26)
	detailAvatar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	detailAvatar.Image = ""
	detailAvatar.Parent = detailHeader
	local daCorner = Instance.new("UICorner")
	daCorner.CornerRadius = UDim.new(0, 26)
	daCorner.Parent = detailAvatar
	local daStroke = Instance.new("UIStroke")
	daStroke.Color = THEME.BorderBeam
	daStroke.Thickness = 1.5
	daStroke.Parent = detailAvatar

	local detailName = Instance.new("TextLabel")
	detailName.Size = UDim2.new(1, -74, 0, 22)
	detailName.Position = UDim2.new(0, 70, 0, 12)
	detailName.BackgroundTransparency = 1
	detailName.Font = Enum.Font.GothamBold
	detailName.Text = ""
	detailName.TextColor3 = THEME.TextFrost
	detailName.TextSize = 14
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.TextTruncate = Enum.TextTruncate.AtEnd
	detailName.Parent = detailHeader

	local detailUser = Instance.new("TextLabel")
	detailUser.Size = UDim2.new(1, -74, 0, 16)
	detailUser.Position = UDim2.new(0, 70, 0, 36)
	detailUser.BackgroundTransparency = 1
	detailUser.Font = Enum.Font.Gotham
	detailUser.Text = ""
	detailUser.TextColor3 = THEME.TextDim
	detailUser.TextSize = 11
	detailUser.TextXAlignment = Enum.TextXAlignment.Left
	detailUser.Parent = detailHeader

	local actionRow = Instance.new("Frame")
	actionRow.Size = UDim2.new(1, -20, 0, 34)
	actionRow.Position = UDim2.new(0, 10, 0, 120)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = detailView

	local function makeAstrocynaBtn(text, xPos, width)
		local ab = Instance.new("TextButton")
		ab.Size = UDim2.new(0, width, 1, 0)
		ab.Position = UDim2.new(0, xPos, 0, 0)
		ab.BackgroundColor3 = THEME.BtnOff
		ab.Font = Enum.Font.GothamBold
		ab.Text = text
		ab.TextColor3 = THEME.TextFrost
		ab.TextSize = 10
		ab.Parent = actionRow
		local abC = Instance.new("UICorner")
		abC.CornerRadius = UDim.new(0, 6)
		abC.Parent = ab
		local abS = Instance.new("UIStroke")
		abS.Color = THEME.BtnOffStroke
		abS.Thickness = 1
		abS.Parent = ab
		hookButtonHover(ab, THEME.BtnOff, Color3.fromRGB(18, 38, 60), THEME.TextFrost, THEME.TextCyan)
		return ab, abS
	end

	local specBtn, specStroke = makeAstrocynaBtn("👁 SPEC", 0, 62)
	local gotoBtn, _gotoStroke = makeAstrocynaBtn("⚡ GO TO", 66, 64)
	local srvInfoBtn, srvStroke = makeAstrocynaBtn("🌐 SERVER", 134, 64)
	local pfpInfoBtn, pfpStroke = makeAstrocynaBtn("👤 PFP", 202, 62)
	local invInfoBtn, invStroke = makeAstrocynaBtn("🎒 BAG", 268, 62)
	local intelInfoBtn, intelStroke = makeAstrocynaBtn("🔍 INTEL", 334, 66)

	local zoneMicRibbon = Instance.new("Frame")
	zoneMicRibbon.Size = UDim2.new(1, -20, 0, 26)
	zoneMicRibbon.Position = UDim2.new(0, 10, 0, 160)
	zoneMicRibbon.BackgroundColor3 = Color3.fromRGB(11, 22, 34)
	zoneMicRibbon.BorderSizePixel = 0
	zoneMicRibbon.Parent = detailView
	local zmCorner = Instance.new("UICorner")
	zmCorner.CornerRadius = UDim.new(0, 6)
	zmCorner.Parent = zoneMicRibbon
	local zmStroke = Instance.new("UIStroke")
	zmStroke.Color = Color3.fromRGB(24, 60, 94)
	zmStroke.Thickness = 1
	zmStroke.Parent = zoneMicRibbon

	local zoneMicLabel = Instance.new("TextLabel")
	zoneMicLabel.Size = UDim2.new(1, -16, 1, 0)
	zoneMicLabel.Position = UDim2.new(0, 8, 0, 0)
	zoneMicLabel.BackgroundTransparency = 1
	zoneMicLabel.Font = Enum.Font.GothamBold
	zoneMicLabel.Text = "🎙️ ZONE MIC: STANDBY (Auto-attaches to Target Head on Spectate)"
	zoneMicLabel.TextColor3 = THEME.TextDim
	zoneMicLabel.TextSize = 10
	zoneMicLabel.TextXAlignment = Enum.TextXAlignment.Left
	zoneMicLabel.Parent = zoneMicRibbon

	local infoScroll = Instance.new("ScrollingFrame")
	infoScroll.Size = UDim2.new(1, -20, 1, -196)
	infoScroll.Position = UDim2.new(0, 10, 0, 192)
	infoScroll.BackgroundColor3 = THEME.CardBg
	infoScroll.BackgroundTransparency = 0.35
	infoScroll.BorderSizePixel = 0
	infoScroll.ScrollBarThickness = 4
	infoScroll.ScrollBarImageColor3 = THEME.BorderBeam
	infoScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	infoScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	infoScroll.Parent = detailView
	local iscrCorner = Instance.new("UICorner")
	iscrCorner.CornerRadius = UDim.new(0, 8)
	iscrCorner.Parent = infoScroll
	local iscrStroke = Instance.new("UIStroke")
	iscrStroke.Color = THEME.CardStroke
	iscrStroke.Thickness = 1
	iscrStroke.Parent = infoScroll

	local infoListLayout = Instance.new("UIListLayout")
	infoListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoListLayout.Padding = UDim.new(0, 2)
	infoListLayout.Parent = infoScroll

	local infoPad = Instance.new("UIPadding")
	infoPad.PaddingLeft = UDim.new(0, 10)
	infoPad.PaddingRight = UDim.new(0, 10)
	infoPad.PaddingTop = UDim.new(0, 8)
	infoPad.PaddingBottom = UDim.new(0, 8)
	infoPad.Parent = infoScroll

	local selectedDetailPlr = nil
	local currentInfoTab = "server"
	local realtimeLabels: any = {}

	local function clearInfoScroll()
		for _, child in ipairs(infoScroll:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("ImageLabel") or child:IsA("TextButton") or child:IsA("ImageButton") then
				child:Destroy()
			end
		end
		table.clear(realtimeLabels)
	end

	local function addInfoSectionHeader(titleText)
		local sec = Instance.new("Frame")
		sec.Size = UDim2.new(1, 0, 0, 24)
		sec.BackgroundTransparency = 1
		sec.Parent = infoScroll

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = "// " .. titleText
		lbl.TextColor3 = THEME.TextCyan
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = sec
	end

	local function addRealtimeRow(key, labelText, defaultVal, defaultColor)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.Parent = infoScroll

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = labelText
		lbl.TextColor3 = THEME.TextDim
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(0.58, 0, 1, 0)
		val.Position = UDim2.new(0.42, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.Gotham
		val.Text = tostring(defaultVal or "-")
		val.TextColor3 = defaultColor or THEME.TextFrost
		val.TextSize = 10
		val.TextXAlignment = Enum.TextXAlignment.Left
		val.TextWrapped = true
		val.Parent = row

		realtimeLabels[key] = val
		return val
	end

	local function addSeparator()
		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, 0, 0, 1)
		sep.BackgroundColor3 = THEME.CardStroke
		sep.BorderSizePixel = 0
		sep.Parent = infoScroll
	end

	local function addMultiLineRow(labelText, bodyText, bodyColor)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.Parent = infoScroll

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.38, 0, 0, 20)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = labelText
		lbl.TextColor3 = THEME.TextDim
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.Size = UDim2.new(0.62, 0, 0, 0)
		val.Position = UDim2.new(0.38, 0, 0, 0)
		val.AutomaticSize = Enum.AutomaticSize.Y
		val.BackgroundTransparency = 1
		val.Font = Enum.Font.Gotham
		val.Text = tostring(bodyText or "-")
		val.TextColor3 = bodyColor or THEME.TextFrost
		val.TextSize = 10
		val.TextXAlignment = Enum.TextXAlignment.Left
		val.TextWrapped = true
		val.Parent = row

		return row
	end

	local function buildServerInfoUI()
		clearInfoScroll()
		currentInfoTab = "server"

		srvInfoBtn.BackgroundColor3 = Color3.fromRGB(12, 38, 62)
		srvStroke.Color = THEME.BorderBeam
		srvInfoBtn.TextColor3 = THEME.TextCyan

		pfpInfoBtn.BackgroundColor3 = THEME.BtnOff
		pfpStroke.Color = THEME.BtnOffStroke
		pfpInfoBtn.TextColor3 = THEME.TextFrost

		invInfoBtn.BackgroundColor3 = THEME.BtnOff
		invStroke.Color = THEME.BtnOffStroke
		invInfoBtn.TextColor3 = THEME.TextFrost

		intelInfoBtn.BackgroundColor3 = THEME.BtnOff
		intelStroke.Color = THEME.BtnOffStroke
		intelInfoBtn.TextColor3 = THEME.TextFrost

		addInfoSectionHeader("SERVER PERFORMANCE & DIAGNOSTICS [LIVE]")
		addRealtimeRow("ping", "Server Ping", "Measuring...", THEME.TextCyan)
		addRealtimeRow("fps", "Client FPS", "60.0 FPS", THEME.TextFrost)
		addRealtimeRow("uptime", "Server Uptime", formatPlayTime(workspace.DistributedGameTime), THEME.TextCyan)
		addRealtimeRow("plrcount", "Players In Server", tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers), THEME.TextFrost)
		addRealtimeRow("memory", "Memory Usage", string.format("%.1f MB", StatsService:GetTotalMemoryUsageMb()), THEME.TextFrost)
		addRealtimeRow("placeid", "Place / Job ID", tostring(game.PlaceId) .. "  |  " .. string.sub(game.JobId ~= "" and game.JobId or "Studio/Local", 1, 8), THEME.TextDim)

		addSeparator()

		addInfoSectionHeader("PLAYER LIVE TELEMETRY [REALTIME]")
		addRealtimeRow("playtime", "Session Play Time", "00m 00s", THEME.TextCyan)
		addRealtimeRow("health", "Health", "100 / 100", Color3.fromRGB(0, 220, 100))
		addRealtimeRow("state", "Movement State", "Idle", THEME.TextFrost)
		addRealtimeRow("speed", "Current Speed", "0.0 studs/s", THEME.TextFrost)
		addRealtimeRow("position", "World Position", "0, 0, 0", THEME.TextFrost)
		addRealtimeRow("distance", "Distance From You", "0.0 studs", THEME.TextCyan)
		addRealtimeRow("walkspeed", "WalkSpeed / Jump", "16  /  50", THEME.TextFrost)
		addRealtimeRow("team", "Team", "None", THEME.TextFrost)
		addRealtimeRow("zonemic", "Zone Mic State", isSpectating and "ACTIVE (In Zone)" or "STANDBY", isSpectating and THEME.TextCyan or THEME.TextDim)
	end

	local function buildPfpInfoUI()
		clearInfoScroll()
		currentInfoTab = "pfp"

		pfpInfoBtn.BackgroundColor3 = Color3.fromRGB(12, 38, 62)
		pfpStroke.Color = THEME.BorderBeam
		pfpInfoBtn.TextColor3 = THEME.TextCyan

		srvInfoBtn.BackgroundColor3 = THEME.BtnOff
		srvStroke.Color = THEME.BtnOffStroke
		srvInfoBtn.TextColor3 = THEME.TextFrost

		invInfoBtn.BackgroundColor3 = THEME.BtnOff
		invStroke.Color = THEME.BtnOffStroke
		invInfoBtn.TextColor3 = THEME.TextFrost

		intelInfoBtn.BackgroundColor3 = THEME.BtnOff
		intelStroke.Color = THEME.BtnOffStroke
		intelInfoBtn.TextColor3 = THEME.TextFrost

		local avatarFrame = Instance.new("Frame")
		avatarFrame.Size = UDim2.new(1, 0, 0, 106)
		avatarFrame.BackgroundTransparency = 1
		avatarFrame.Parent = infoScroll

		local bigAvatar = Instance.new("ImageLabel")
		bigAvatar.Size = UDim2.new(0, 92, 0, 92)
		bigAvatar.Position = UDim2.new(0.5, -46, 0, 4)
		bigAvatar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
		bigAvatar.Parent = avatarFrame
		local baC = Instance.new("UICorner")
		baC.CornerRadius = UDim.new(0, 46)
		baC.Parent = bigAvatar
		local baS = Instance.new("UIStroke")
		baS.Color = THEME.BorderBeam
		baS.Thickness = 2
		baS.Parent = bigAvatar

		if selectedDetailPlr then
			getCachedThumbnailAsync(selectedDetailPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150, function(thumb)
				bigAvatar.Image = thumb
			end)
		end

		addSeparator()

		addInfoSectionHeader("ACCOUNT IDENTITY & PROFILE")
		addRealtimeRow("pfp_name", "Display Name", selectedDetailPlr and selectedDetailPlr.DisplayName or "-", THEME.TextCyan)
		addRealtimeRow("pfp_user", "Username", selectedDetailPlr and ("@" .. selectedDetailPlr.Name) or "-", THEME.TextFrost)
		addRealtimeRow("pfp_id", "User ID", selectedDetailPlr and tostring(selectedDetailPlr.UserId) or "-", THEME.TextDim)
		addRealtimeRow("pfp_age", "Account Age", selectedDetailPlr and (tostring(selectedDetailPlr.AccountAge) .. " days (" .. string.format("%.1f yrs", selectedDetailPlr.AccountAge / 365) .. ")") or "-", THEME.TextFrost)

		local memberStr = "Standard"
		pcall(function()
			if selectedDetailPlr and selectedDetailPlr.MembershipType == Enum.MembershipType.Premium then
				memberStr = "Roblox Premium"
			end
		end)
		addRealtimeRow("pfp_member", "Membership", memberStr, memberStr == "Roblox Premium" and Color3.fromRGB(255, 200, 50) or THEME.TextFrost)

		addSeparator()

		addInfoSectionHeader("LIVE IN-GAME STATUS")
		addRealtimeRow("pfp_tool", "Equipped Tool", "None (Hands Free)", THEME.TextFrost)
		addRealtimeRow("pfp_rig", "Avatar Rig Type", "R15", THEME.TextFrost)
		addRealtimeRow("pfp_follow", "Follow Status", "Not following anyone", THEME.TextDim)
		addRealtimeRow("pfp_audio", "Zone Proximity Audio", "Supported (RP Mic + Spatial Voice)", THEME.TextCyan)
	end

	local function buildInventoryUI()
		clearInfoScroll()
		currentInfoTab = "inventory"

		invInfoBtn.BackgroundColor3 = Color3.fromRGB(12, 38, 62)
		invStroke.Color = THEME.BorderBeam
		invInfoBtn.TextColor3 = THEME.TextCyan

		srvInfoBtn.BackgroundColor3 = THEME.BtnOff
		srvStroke.Color = THEME.BtnOffStroke
		srvInfoBtn.TextColor3 = THEME.TextFrost

		pfpInfoBtn.BackgroundColor3 = THEME.BtnOff
		pfpStroke.Color = THEME.BtnOffStroke
		pfpInfoBtn.TextColor3 = THEME.TextFrost

		intelInfoBtn.BackgroundColor3 = THEME.BtnOff
		intelStroke.Color = THEME.BtnOffStroke
		intelInfoBtn.TextColor3 = THEME.TextFrost

		if not selectedDetailPlr then return end
		local p = selectedDetailPlr
		local teamName = p.Team and p.Team.Name or "No Team"

		addInfoSectionHeader("PLAYER REALTIME AUDIT & MIC")

		local existingPop = infoScroll:FindFirstChild("PopInspectorButton")
		if existingPop then existingPop:Destroy() end

		local popBtn = Instance.new("TextButton")
		popBtn.Name = "PopInspectorButton"
		popBtn.Size = UDim2.new(1, 0, 0, 24)
		popBtn.BackgroundColor3 = Color3.fromRGB(16, 36, 56)
		popBtn.Font = Enum.Font.GothamBold
		popBtn.Text = "🎒 OPEN FULL INSPECTOR POPUP"
		popBtn.TextColor3 = THEME.TextCyan
		popBtn.TextSize = 9.5
		popBtn.Parent = infoScroll
		local pbc = Instance.new("UICorner")
		pbc.CornerRadius = UDim.new(0, 5)
		pbc.Parent = popBtn
		local pbs = Instance.new("UIStroke")
		pbs.Color = THEME.BorderBeam
		pbs.Thickness = 1
		pbs.Parent = popBtn
		hookButtonHover(popBtn, Color3.fromRGB(16, 36, 56), Color3.fromRGB(48, 48, 54), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
		popBtn.MouseButton1Click:Connect(function()
			if openBackpackInspector and selectedDetailPlr then
				openBackpackInspector(selectedDetailPlr)
			end
		end)

		local existingGangBtn = infoScroll:FindFirstChild("ViewGangButton")
		if existingGangBtn then existingGangBtn:Destroy() end

		local viewGangBtn = Instance.new("TextButton")
		viewGangBtn.Name = "ViewGangButton"
		viewGangBtn.Size = UDim2.new(1, 0, 0, 24)
		viewGangBtn.BackgroundColor3 = Color3.fromRGB(40, 26, 12)
		viewGangBtn.Font = Enum.Font.GothamBold
		viewGangBtn.Text = "🏴‍☠️ VIEW GANG PROFILE"
		viewGangBtn.TextColor3 = Color3.fromRGB(255, 185, 90)
		viewGangBtn.TextSize = 9.5
		viewGangBtn.Parent = infoScroll
		local vgc = Instance.new("UICorner")
		vgc.CornerRadius = UDim.new(0, 5)
		vgc.Parent = viewGangBtn
		local vgs = Instance.new("UIStroke")
		vgs.Color = Color3.fromRGB(255, 160, 50)
		vgs.Thickness = 1
		vgs.Parent = viewGangBtn
		hookButtonHover(viewGangBtn, Color3.fromRGB(40, 26, 12), Color3.fromRGB(60, 38, 18), Color3.fromRGB(255, 185, 90), Color3.fromRGB(255, 255, 255))
		viewGangBtn.MouseButton1Click:Connect(function()
			if selectedDetailPlr and inspectGangByKey then
				local g = GANG_SYS and GANG_SYS.getPlayerGang(selectedDetailPlr.UserId)
				if g and g.gangKey then
					inspectGangByKey(g.gangKey)
				else
					toggleGangGui()
				end
			end
		end)

		local micText, micColor = getPlayerMicStatus(p)
		addRealtimeRow("inv_mic", "Live Mic Status", micText, micColor)
		addRealtimeRow("inv_team", "Assigned Role", teamName, p.TeamColor and p.TeamColor.Color or THEME.TextCyan)

		local gInfo = GANG_SYS and GANG_SYS.getPlayerGang(p.UserId)
		if gInfo then
			local tagText = "[" .. (gInfo.gangTag ~= "" and gInfo.gangTag or gInfo.gangName) .. "] " .. gInfo.role .. (gInfo.isTagHidden and " 🕶️ [Tag Off]" or "")
			addRealtimeRow("inv_gang", "Gang Affiliation", tagText, Color3.fromRGB(255, 180, 80))
		else
			addRealtimeRow("inv_gang", "Gang Affiliation", "No Gang Affiliation", THEME.TextDim)
		end

		addSeparator()
		addInfoSectionHeader("EQUIPPED WEAPON / TOOL [IN HAND]")
		local tChar = getPlayerChar and getPlayerChar(p) or p.Character
		local heldTool = tChar and tChar:FindFirstChildOfClass("Tool")
		if heldTool then
			local kind, reason = classifyToolForPlayer(heldTool.Name, teamName, isStaffOrAdmin(p))
			local col = (kind == "admin" and Color3.fromRGB(255, 60, 80)) or (kind == "cross_role" and Color3.fromRGB(255, 70, 90)) or (kind == "general_weapon" and Color3.fromRGB(180, 210, 240)) or (kind == "radio" and Color3.fromRGB(0, 215, 255)) or (kind == "role_allowed" and Color3.fromRGB(0, 220, 140)) or THEME.TextCyan
			addRealtimeRow("inv_held", heldTool.Name, string.format("[%s]", reason), col)
		else
			addRealtimeRow("inv_held", "Held In Hand", "None (Hands Free)", THEME.TextDim)
		end

		addSeparator()
		local bp = p:FindFirstChild("Backpack")
		local bpItems = bp and bp:GetChildren() or {}
		local toolCount = 0
		for _, it in ipairs(bpItems) do
			if it:IsA("Tool") or it:IsA("HopperBin") then
				toolCount = toolCount + 1
			end
		end

		addInfoSectionHeader("BACKPACK INVENTORY (" .. tostring(toolCount) .. " ITEMS)")
		if toolCount == 0 then
			addRealtimeRow("inv_empty", "Backpack Content", "Empty (0 items)", THEME.TextDim)
		else
			for idx, it in ipairs(bpItems) do
				if it:IsA("Tool") or it:IsA("HopperBin") then
					local kind, reason = classifyToolForPlayer(it.Name, teamName, isStaffOrAdmin(p))
					local col = (kind == "admin" and Color3.fromRGB(255, 60, 80)) or (kind == "cross_role" and Color3.fromRGB(255, 70, 90)) or (kind == "general_weapon" and Color3.fromRGB(180, 210, 240)) or (kind == "radio" and Color3.fromRGB(0, 215, 255)) or (kind == "role_allowed" and Color3.fromRGB(0, 220, 140)) or THEME.TextCyan
					addRealtimeRow("inv_item_" .. tostring(idx), it.Name, string.format("[%s]", reason), col)
				end
			end
		end
	end

	-- ===================================================================
	-- 🔍 PLAYER INTELLIGENCE & OSINT AUDIT SYSTEM (ZERO FPS OVERHEAD)
	-- On-demand async queries, parallel coroutines, 300s local caching
	-- ===================================================================
	local playerIntelCache = {}

	local function safeHttpGetJson(url)
		local body = nil
		local reqFn = (ENV_CALLS and ENV_CALLS.httpRequest) or (syn and syn.request) or http_request or request or (http and http.request)
		if reqFn then
			pcall(function()
				local res = reqFn({ Url = url, Method = "GET", Timeout = 3.5 })
				if res and res.Body and (res.StatusCode == nil or res.StatusCode == 200) then
					body = res.Body
				end
			end)
		end
		if not body and type(game.HttpGet) == "function" then
			pcall(function()
				body = game:HttpGet(url)
			end)
		end
		if type(body) ~= "string" or body == "" then return nil end
		local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
		if okJson and type(data) == "table" then return data end
		return nil
	end

	local function fetchRobloxApi(path)
		local data = safeHttpGetJson("https://" .. path)
		if not data or data.errors then
			local proxyPath = string.gsub(path, "roblox%.com", "roproxy.com")
			data = safeHttpGetJson("https://" .. proxyPath)
		end
		return data
	end

	local function formatIsoDate(isoStr)
		if type(isoStr) ~= "string" then return "-" end
		local year, month, day, hour, min = string.match(isoStr, "^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
		if year and month and day then
			return string.format("%s-%s-%s %s:%s UTC", year, month, day, hour or "00", min or "00")
		end
		return string.sub(isoStr, 1, 10)
	end

	local function formatShortCount(n)
		n = tonumber(n) or 0
		if n >= 1000000 then
			return string.format("%.1fM", n / 1000000)
		elseif n >= 1000 then
			return string.format("%.1fK", n / 1000)
		end
		return tostring(n)
	end

	local function fetchPlayerIntelligence(targetPlr, callback)
		if not targetPlr then return end
		local uid = targetPlr.UserId
		local now = os.time()
		local cached = playerIntelCache[uid]
		if cached and (now - cached._timestamp) < 300 then
			if callback then callback(cached) end
			return
		end

		task.spawn(function()
			local rawUser = nil
			local rawHistory = nil
			local rawGroups = nil
			local rawFriends = nil
			local rawFollowers = nil
			local rawBloxlink = nil

			local remaining = 6
			local function step()
				remaining = remaining - 1
				if remaining <= 0 then
					local pastNames = {}
					if rawHistory and type(rawHistory.data) == "table" then
						for _, item in ipairs(rawHistory.data) do
							if item.name and item.name ~= "" then
								table.insert(pastNames, item.name)
							end
						end
					end

					local groupsCount = 0
					local primaryGroupName = "None"
					local primaryGroupRank = "Member"
					if rawGroups and type(rawGroups.data) == "table" then
						groupsCount = #rawGroups.data
						if groupsCount > 0 and rawGroups.data[1].group then
							primaryGroupName = rawGroups.data[1].group.name or "Unknown"
							if rawGroups.data[1].role then
								primaryGroupRank = rawGroups.data[1].role.name or "Member"
							end
						end
					end

					local friendsCount = (rawFriends and tonumber(rawFriends.count)) or 0
					local followersCount = (rawFollowers and tonumber(rawFollowers.count)) or 0

					local discordId = nil
					if rawBloxlink then
						if rawBloxlink.discordIDs and #rawBloxlink.discordIDs > 0 then
							discordId = tostring(rawBloxlink.discordIDs[1])
						elseif rawBloxlink.discordId then
							discordId = tostring(rawBloxlink.discordId)
						end
					end

					local createdStr = (rawUser and rawUser.created) or ""
					local hasVerifiedBadge = (rawUser and rawUser.hasVerifiedBadge == true) or false
					local isBanned = (rawUser and rawUser.isBanned == true) or false
					local bio = (rawUser and rawUser.description) or ""
					local ageDays = (targetPlr and targetPlr.AccountAge) or 0

					local riskScore = 0
					local riskReasons = {}

					if hasVerifiedBadge then
						riskScore = 0
						table.insert(riskReasons, "Official Roblox Verified Checkmark")
					else
						if ageDays < 14 then
							riskScore = riskScore + 40
							table.insert(riskReasons, "Newborn account (< 14 days)")
						elseif ageDays < 30 then
							riskScore = riskScore + 30
							table.insert(riskReasons, "Recent account (< 30 days)")
						elseif ageDays < 90 then
							riskScore = riskScore + 20
							table.insert(riskReasons, "Created < 3 months ago")
						elseif ageDays < 365 then
							riskScore = riskScore + 10
						else
							table.insert(riskReasons, "Matured account (1+ years)")
						end

						if friendsCount == 0 then
							riskScore = riskScore + 20
							table.insert(riskReasons, "Zero friends (typical throwaway/bot)")
						elseif friendsCount < 5 then
							riskScore = riskScore + 10
							table.insert(riskReasons, "Very few friends (< 5)")
						elseif friendsCount >= 20 then
							riskScore = math.max(0, riskScore - 10)
						end

						if groupsCount == 0 then
							riskScore = riskScore + 20
							table.insert(riskReasons, "No Roblox groups joined")
						elseif groupsCount == 1 then
							riskScore = riskScore + 10
						elseif groupsCount >= 5 then
							riskScore = math.max(0, riskScore - 10)
						end

						if #pastNames > 3 then
							riskScore = riskScore + 15
							table.insert(riskReasons, string.format("Frequent alias changes (%d names)", #pastNames))
						elseif #pastNames > 0 then
							table.insert(riskReasons, string.format("%d past name(s) archived", #pastNames))
						else
							table.insert(riskReasons, "Original username (no rename)")
						end

						if discordId then
							riskScore = math.max(0, riskScore - 15)
							table.insert(riskReasons, "Verified Discord identity linked")
						end
					end

					local riskLevel, riskColor
					if hasVerifiedBadge then
						riskLevel = "VERIFIED ACCOUNT (Official)"
						riskColor = Color3.fromRGB(0, 215, 255)
					elseif isBanned then
						riskLevel = "TERMINATED / BANNED"
						riskColor = Color3.fromRGB(255, 40, 60)
					elseif riskScore >= 50 then
						riskLevel = "HIGH RISK (Probable Alt / Burner)"
						riskColor = Color3.fromRGB(255, 60, 80)
					elseif riskScore >= 25 then
						riskLevel = "MEDIUM RISK (Suspicious / Unvetted)"
						riskColor = Color3.fromRGB(255, 175, 50)
					else
						riskLevel = "LOW RISK (Established Player)"
						riskColor = Color3.fromRGB(60, 225, 120)
					end

					local intelData = {
						userId = uid,
						_timestamp = os.time(),
						created = createdStr,
						createdFormatted = formatIsoDate(createdStr),
						accountAgeDays = ageDays,
						hasVerifiedBadge = hasVerifiedBadge,
						isBanned = isBanned,
						bio = bio,
						pastNames = pastNames,
						groupsCount = groupsCount,
						primaryGroupName = primaryGroupName,
						primaryGroupRank = primaryGroupRank,
						friendsCount = friendsCount,
						followersCount = followersCount,
						discordId = discordId,
						riskScore = riskScore,
						riskLevel = riskLevel,
						riskColor = riskColor,
						riskReasons = riskReasons,
					}

					playerIntelCache[uid] = intelData
					if callback then
						pcall(callback, intelData)
					end
				end
			end

			task.spawn(function()
				rawUser = fetchRobloxApi("users.roblox.com/v1/users/" .. tostring(uid))
				step()
			end)
			task.spawn(function()
				rawHistory = fetchRobloxApi("users.roblox.com/v1/users/" .. tostring(uid) .. "/username-history?limit=100&sortOrder=Desc")
				step()
			end)
			task.spawn(function()
				rawGroups = fetchRobloxApi("groups.roblox.com/v1/users/" .. tostring(uid) .. "/groups/roles")
				step()
			end)
			task.spawn(function()
				rawFriends = fetchRobloxApi("friends.roblox.com/v1/users/" .. tostring(uid) .. "/friends/count")
				step()
			end)
			task.spawn(function()
				rawFollowers = fetchRobloxApi("friends.roblox.com/v1/users/" .. tostring(uid) .. "/followers/count")
				step()
			end)
			task.spawn(function()
				rawBloxlink = safeHttpGetJson("https://api.blox.link/v4/public/roblox-to-discord/" .. tostring(uid))
				step()
			end)
		end)
	end

	local function buildIntelUI()
		clearInfoScroll()
		currentInfoTab = "intel"

		intelInfoBtn.BackgroundColor3 = Color3.fromRGB(12, 38, 62)
		intelStroke.Color = THEME.BorderBeam
		intelInfoBtn.TextColor3 = THEME.TextCyan

		srvInfoBtn.BackgroundColor3 = THEME.BtnOff
		srvStroke.Color = THEME.BtnOffStroke
		srvInfoBtn.TextColor3 = THEME.TextFrost

		pfpInfoBtn.BackgroundColor3 = THEME.BtnOff
		pfpStroke.Color = THEME.BtnOffStroke
		pfpInfoBtn.TextColor3 = THEME.TextFrost

		invInfoBtn.BackgroundColor3 = THEME.BtnOff
		invStroke.Color = THEME.BtnOffStroke
		invInfoBtn.TextColor3 = THEME.TextFrost

		if not selectedDetailPlr then return end
		local p = selectedDetailPlr
		local uid = p.UserId

		local topBar = Instance.new("Frame")
		topBar.Size = UDim2.new(1, 0, 0, 26)
		topBar.BackgroundTransparency = 1
		topBar.Parent = infoScroll

		local rescanBtn = Instance.new("TextButton")
		rescanBtn.Size = UDim2.new(1, 0, 0, 24)
		rescanBtn.BackgroundColor3 = Color3.fromRGB(14, 28, 44)
		rescanBtn.Font = Enum.Font.GothamBold
		rescanBtn.Text = "🔄 RE-SCAN ACCOUNT INTELLIGENCE (OSINT)"
		rescanBtn.TextColor3 = THEME.TextCyan
		rescanBtn.TextSize = 9.5
		rescanBtn.Parent = topBar
		local rsC = Instance.new("UICorner")
		rsC.CornerRadius = UDim.new(0, 5)
		rsC.Parent = rescanBtn
		local rsS = Instance.new("UIStroke")
		rsS.Color = THEME.BorderBeam
		rsS.Thickness = 1
		rsS.Parent = rescanBtn
		hookButtonHover(rescanBtn, Color3.fromRGB(14, 28, 44), Color3.fromRGB(24, 48, 76), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
		rescanBtn.MouseButton1Click:Connect(function()
			playerIntelCache[uid] = nil
			buildIntelUI()
		end)

		local cached = playerIntelCache[uid]
		if not cached then
			addInfoSectionHeader("PLAYER INTELLIGENCE & OSINT REPORT")
			addRealtimeRow("intel_status", "Analysis Status", "⏳ Fetching Roblox APIs & Bloxlink OSINT...", THEME.TextCyan)
			addRealtimeRow("intel_risk", "Alt Risk Level", "Calculating...", THEME.TextDim)
			addRealtimeRow("intel_genesis", "Genesis Created", "Querying...", THEME.TextDim)
			addRealtimeRow("intel_discord", "Discord Identity", "Searching database...", THEME.TextDim)
			addRealtimeRow("intel_names", "Past Usernames", "Scanning archives...", THEME.TextDim)

			fetchPlayerIntelligence(p, function(intel)
				if selectedDetailPlr and selectedDetailPlr.UserId == uid and currentInfoTab == "intel" then
					buildIntelUI()
				end
			end)
			return
		end

		addInfoSectionHeader("ALT ACCOUNT RISK & THREAT ASSESSMENT")
		addRealtimeRow("intel_level", "Alt Risk Rating", cached.riskLevel, cached.riskColor)
		addRealtimeRow("intel_score", "Risk Threat Score", string.format("%d / 100", cached.riskScore), cached.riskColor)
		if #cached.riskReasons > 0 then
			local reasonText = table.concat(cached.riskReasons, "  •  ")
			addMultiLineRow("Risk Indicators", reasonText, THEME.TextDim)
		end

		addSeparator()

		addInfoSectionHeader("ACCOUNT GENESIS & IDENTITY AUDIT")
		local ageStr = string.format("%d days (%.1f yrs)", cached.accountAgeDays, cached.accountAgeDays / 365.25)
		addRealtimeRow("intel_age", "Account Age", ageStr, THEME.TextFrost)
		addRealtimeRow("intel_created", "Creation Date", cached.createdFormatted ~= "" and cached.createdFormatted or "-", THEME.TextCyan)
		addRealtimeRow("intel_verif", "Verified Badge", cached.hasVerifiedBadge and "✅ VERIFIED ACCOUNT" or "Standard Account", cached.hasVerifiedBadge and Color3.fromRGB(0, 215, 255) or THEME.TextDim)
		addRealtimeRow("intel_banned", "Ban Status", cached.isBanned and "⛔ BANNED / TERMINATED" or "Normal (Clean)", cached.isBanned and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(60, 225, 120))

		addSeparator()

		addInfoSectionHeader("EXTERNAL IDENTITY & SOCIAL GRAPH")
		local discordText = cached.discordId and string.format("ID: %s  (<@%s>)", cached.discordId, cached.discordId) or "Not Linked / Private"
		local discordCol = cached.discordId and Color3.fromRGB(114, 137, 218) or THEME.TextDim
		addRealtimeRow("intel_discord", "Discord Identity", discordText, discordCol)

		if cached.discordId then
			local copyDiscBtn = Instance.new("TextButton")
			copyDiscBtn.Size = UDim2.new(1, 0, 0, 22)
			copyDiscBtn.BackgroundColor3 = Color3.fromRGB(24, 32, 54)
			copyDiscBtn.Font = Enum.Font.GothamBold
			copyDiscBtn.Text = "📋 COPY DISCORD ID (" .. cached.discordId .. ")"
			copyDiscBtn.TextColor3 = Color3.fromRGB(114, 137, 218)
			copyDiscBtn.TextSize = 9.5
			copyDiscBtn.Parent = infoScroll
			local cdc = Instance.new("UICorner")
			cdc.CornerRadius = UDim.new(0, 5)
			cdc.Parent = copyDiscBtn
			local cds = Instance.new("UIStroke")
			cds.Color = Color3.fromRGB(114, 137, 218)
			cds.Thickness = 1
			cds.Parent = copyDiscBtn
			hookButtonHover(copyDiscBtn, Color3.fromRGB(24, 32, 54), Color3.fromRGB(36, 48, 80), Color3.fromRGB(114, 137, 218), Color3.fromRGB(255, 255, 255))
			copyDiscBtn.MouseButton1Click:Connect(function()
				if setclipboard then
					pcall(setclipboard, cached.discordId)
					copyDiscBtn.Text = "✅ COPIED DISCORD ID!"
					task.delay(1.5, function()
						if copyDiscBtn and copyDiscBtn.Parent then
							copyDiscBtn.Text = "📋 COPY DISCORD ID (" .. cached.discordId .. ")"
						end
					end)
				end
			end)
		end

		addRealtimeRow("intel_social", "Friends & Followers", string.format("%d Friends  ·  %s Followers", cached.friendsCount, formatShortCount(cached.followersCount)), THEME.TextFrost)

		local groupText
		if cached.groupsCount > 0 then
			groupText = string.format("%d Groups (Primary: %s [%s])", cached.groupsCount, cached.primaryGroupName, cached.primaryGroupRank)
		else
			groupText = "0 Groups (No Affiliations)"
		end
		addMultiLineRow("Group Footprint", groupText, cached.groupsCount > 0 and THEME.TextCyan or THEME.TextDim)

		addSeparator()

		addInfoSectionHeader("USERNAME ALIAS HISTORY (RENAME AUDIT)")
		if #cached.pastNames == 0 then
			addRealtimeRow("intel_past", "Past Usernames", "Original Username (@" .. p.Name .. ")", THEME.TextDim)
		else
			addRealtimeRow("intel_past_count", "Total Renames", tostring(#cached.pastNames) .. " Previous Name(s)", Color3.fromRGB(255, 185, 90))
			local namesListStr = table.concat(cached.pastNames, ", ")
			addMultiLineRow("Past Usernames", namesListStr, Color3.fromRGB(255, 210, 150))
		end

		if cached.bio and cached.bio ~= "" then
			addSeparator()
			addInfoSectionHeader("PROFILE DESCRIPTION / BIO")
			local cleanBio = string.gsub(cached.bio, "[\r\n]+", " ")
			if #cleanBio > 200 then
				cleanBio = string.sub(cleanBio, 1, 197) .. "..."
			end
			addMultiLineRow("Profile Bio", cleanBio, THEME.TextFrost)
		end
	end

	updateRealtimeTelemetry = function()
		if not detailView.Visible or not selectedDetailPlr then return end
		local p = selectedDetailPlr
		local char = p.Character

		if isSpectating and spectateTarget == p then
			zoneMicRibbon.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
			zmStroke.Color = THEME.BorderBeam
			zoneMicLabel.Text = "🎙️ ZONE MIC: ACTIVE • Hearing RP & Spatial Mic (Target Head Zone)"
			zoneMicLabel.TextColor3 = THEME.TextCyan

			specBtn.Text = "👁 SPECTATING"
			specBtn.BackgroundColor3 = THEME.ActiveFly
			specStroke.Color = Color3.fromRGB(200, 200, 205)
			specBtn.TextColor3 = THEME.BtnActiveText
			stopSpecBtn.Visible = true
		else
			zoneMicRibbon.BackgroundColor3 = Color3.fromRGB(11, 22, 34)
			zmStroke.Color = Color3.fromRGB(24, 60, 94)
			zoneMicLabel.Text = "🎙️ ZONE MIC: STANDBY (Auto-attaches to Target Head on Spectate)"
			zoneMicLabel.TextColor3 = THEME.TextDim

			specBtn.Text = "👁 SPECTATE"
			specBtn.BackgroundColor3 = THEME.BtnOff
			specStroke.Color = THEME.BtnOffStroke
			specBtn.TextColor3 = THEME.TextCyan
			stopSpecBtn.Visible = isSpectating
		end

		if currentInfoTab == "server" then

			local ping = getLivePing()
			if realtimeLabels["ping"] then
				realtimeLabels["ping"].Text = tostring(ping) .. " ms"
				if ping < 80 then
					realtimeLabels["ping"].TextColor3 = Color3.fromRGB(0, 225, 140)
				elseif ping < 150 then
					realtimeLabels["ping"].TextColor3 = Color3.fromRGB(255, 200, 50)
				else
					realtimeLabels["ping"].TextColor3 = Color3.fromRGB(255, 80, 80)
				end
			end
			if realtimeLabels["fps"] then
				realtimeLabels["fps"].Text = string.format("%.1f FPS", FPS_TRACKER.current)
			end
			if realtimeLabels["uptime"] then
				realtimeLabels["uptime"].Text = formatPlayTime(workspace.DistributedGameTime)
			end
			if realtimeLabels["plrcount"] then
				realtimeLabels["plrcount"].Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)
			end
			if realtimeLabels["memory"] then
				realtimeLabels["memory"].Text = string.format("%.1f MB", StatsService:GetTotalMemoryUsageMb())
			end

			local joinT = playerJoinTimes[p]
			if realtimeLabels["playtime"] then
				realtimeLabels["playtime"].Text = formatPlayTime(joinT and (tick() - joinT) or 0)
			end

			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")

				if hum and realtimeLabels["health"] then
					local hp = math.max(hum.Health, 0)
					local maxHp = math.max(hum.MaxHealth, 1)
					local pct = math.floor((hp / maxHp) * 100)
					realtimeLabels["health"].Text = string.format("%.0f / %.0f (%d%%)", hp, maxHp, pct)
					if pct > 50 then
						realtimeLabels["health"].TextColor3 = Color3.fromRGB(0, 220, 100)
					elseif pct > 20 then
						realtimeLabels["health"].TextColor3 = Color3.fromRGB(255, 200, 40)
					else
						realtimeLabels["health"].TextColor3 = Color3.fromRGB(255, 60, 60)
					end
				end

				if hum and root and realtimeLabels["state"] then
					if hum.Health <= 0 then
						realtimeLabels["state"].Text = "Dead / Despawned"
						realtimeLabels["state"].TextColor3 = Color3.fromRGB(255, 60, 60)
					elseif hum.Sit then
						realtimeLabels["state"].Text = "Sitting / Driving Vehicle"
						realtimeLabels["state"].TextColor3 = Color3.fromRGB(255, 200, 60)
					elseif root.AssemblyLinearVelocity.Y > 3 then
						realtimeLabels["state"].Text = "Jumping / Airborne"
						realtimeLabels["state"].TextColor3 = THEME.TextCyan
					elseif root.AssemblyLinearVelocity.Y < -5 then
						realtimeLabels["state"].Text = "Falling"
						realtimeLabels["state"].TextColor3 = Color3.fromRGB(255, 140, 40)
					elseif root.AssemblyLinearVelocity.Magnitude > 1.5 then
						realtimeLabels["state"].Text = "Moving / Running"
						realtimeLabels["state"].TextColor3 = Color3.fromRGB(120, 240, 160)
					else
						realtimeLabels["state"].Text = "Idle / Standing"
						realtimeLabels["state"].TextColor3 = THEME.TextFrost
					end
				end

				if root and realtimeLabels["speed"] then
					realtimeLabels["speed"].Text = string.format("%.1f studs/s", root.AssemblyLinearVelocity.Magnitude)
				end

				if root and realtimeLabels["position"] then
					local pos = root.Position
					realtimeLabels["position"].Text = string.format("X: %.0f  Y: %.0f  Z: %.0f", pos.X, pos.Y, pos.Z)
				end

				if hum and realtimeLabels["walkspeed"] then
					realtimeLabels["walkspeed"].Text = string.format("%.0f  /  %.0f", hum.WalkSpeed, hum.JumpPower)
				end

				if root and realtimeLabels["distance"] then
					local myChar = player.Character
					local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
					if myRoot then
						local dist = (myRoot.Position - root.Position).Magnitude
						realtimeLabels["distance"].Text = string.format("%.1f studs", dist)
					else
						realtimeLabels["distance"].Text = "N/A (No local body)"
					end
				end
			else
				if realtimeLabels["health"] then
					realtimeLabels["health"].Text = "Not Spawned"
					realtimeLabels["health"].TextColor3 = Color3.fromRGB(255, 80, 80)
				end
				if realtimeLabels["state"] then realtimeLabels["state"].Text = "Waiting for character..." end
				if realtimeLabels["speed"] then realtimeLabels["speed"].Text = "0.0 studs/s" end
				if realtimeLabels["position"] then realtimeLabels["position"].Text = "N/A" end
				if realtimeLabels["distance"] then realtimeLabels["distance"].Text = "N/A" end
			end

			if realtimeLabels["team"] then
				if p.Team then
					realtimeLabels["team"].Text = p.Team.Name
					realtimeLabels["team"].TextColor3 = p.TeamColor.Color
				else
					realtimeLabels["team"].Text = "None (Neutral)"
					realtimeLabels["team"].TextColor3 = THEME.TextDim
				end
			end

			if realtimeLabels["zonemic"] then
				local micText, micColor = getPlayerMicStatus(p)
				realtimeLabels["zonemic"].Text = micText
				realtimeLabels["zonemic"].TextColor3 = micColor
			end

		elseif currentInfoTab == "inventory" then
			if realtimeLabels["inv_mic"] then
				local micText, micColor = getPlayerMicStatus(p)
				realtimeLabels["inv_mic"].Text = micText
				realtimeLabels["inv_mic"].TextColor3 = micColor
			end
		elseif currentInfoTab == "pfp" then

			if char and realtimeLabels["pfp_tool"] then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then
					realtimeLabels["pfp_tool"].Text = tool.Name
					realtimeLabels["pfp_tool"].TextColor3 = THEME.TextCyan
				else
					realtimeLabels["pfp_tool"].Text = "None (Hands Free)"
					realtimeLabels["pfp_tool"].TextColor3 = THEME.TextDim
				end
			end

			if char and realtimeLabels["pfp_rig"] then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					realtimeLabels["pfp_rig"].Text = hum.RigType == Enum.HumanoidRigType.R15 and "R15 (15 Parts)" or "R6 (Classic 6 Parts)"
				end
			end

			if realtimeLabels["pfp_follow"] then
				pcall(function()
					if p.FollowUserId and p.FollowUserId > 0 then
						local followPlr = Players:GetPlayerByUserId(p.FollowUserId)
						realtimeLabels["pfp_follow"].Text = followPlr and ("Following: @" .. followPlr.Name) or ("Follow ID: " .. tostring(p.FollowUserId))
						realtimeLabels["pfp_follow"].TextColor3 = THEME.TextCyan
					else
						realtimeLabels["pfp_follow"].Text = "Not following anyone"
						realtimeLabels["pfp_follow"].TextColor3 = THEME.TextDim
					end
				end)
			end
		end
	end

	local function showPlayerDetail(plrData)
		selectedDetailPlr = plrData
		listView.Visible = false
		if addBlacklistView then addBlacklistView.Visible = false end
		detailView.Visible = true

		local isBl = isPlayerBlacklisted(plrData.UserId)
		local isStaff, roleName, rank = checkPlayerStaff(plrData)

		if isBl then
			blToggleBtn.Text = "✅ UNBLACKLIST"
			blToggleBtn.TextColor3 = Color3.fromRGB(140, 255, 180)
			blToggleBtn.BackgroundColor3 = Color3.fromRGB(16, 32, 24)
			bltStroke.Color = Color3.fromRGB(40, 200, 100)
		else
			blToggleBtn.Text = "🚫 BLACKLIST"
			blToggleBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
			blToggleBtn.BackgroundColor3 = Color3.fromRGB(26, 12, 16)
			bltStroke.Color = Color3.fromRGB(180, 40, 60)
		end

		if isBl then
			detailName.Text = "⛔ " .. plrData.DisplayName .. "  [BLACKLISTED]"
			detailName.TextColor3 = Color3.fromRGB(255, 50, 80)
			local loc = ADMIN_SYS.locateBlacklistedPlayer and ADMIN_SYS.locateBlacklistedPlayer(plrData.UserId)
			if loc and loc.status == "OTHER_SERVER" then
				detailUser.Text = string.format("@%s  |  ⛔ BLACKLISTED  ·  📍 In %s (%d/%d)", plrData.Name, loc.serverTitle, loc.total or 0, loc.max or 60)
				gotoBtn.Text = "🚀 JOIN"
				gotoBtn.BackgroundColor3 = Color3.fromRGB(20, 48, 30)
				gotoBtn.TextColor3 = Color3.fromRGB(140, 255, 180)
			elseif loc and loc.status == "CURRENT_SERVER" then
				detailUser.Text = "@" .. plrData.Name .. "  |  ⛔ BLACKLISTED  ·  🟢 Current Server"
				gotoBtn.Text = "⚡ GO TO"
				gotoBtn.BackgroundColor3 = THEME.BtnOff
				gotoBtn.TextColor3 = THEME.TextFrost
			else
				detailUser.Text = "@" .. plrData.Name .. "  |  ⛔ BLACKLISTED  ·  🔴 " .. (loc and loc.serverTitle or "Offline")
				gotoBtn.Text = "⚡ GO TO"
				gotoBtn.BackgroundColor3 = THEME.BtnOff
				gotoBtn.TextColor3 = THEME.TextFrost
			end
			detailUser.TextColor3 = Color3.fromRGB(220, 220, 225)
		elseif isStaff then
			detailName.Text = "🚨 " .. plrData.DisplayName .. "  [STAFF]"
			detailName.TextColor3 = Color3.fromRGB(255, 75, 105)
			detailUser.Text = "@" .. plrData.Name .. "  |  " .. string.upper(roleName) .. " (Rank: " .. tostring(rank) .. ")"
			detailUser.TextColor3 = Color3.fromRGB(255, 140, 160)
		else
			local gInfo = GANG_SYS and GANG_SYS.getPlayerGang(plrData.UserId)
			if gInfo then
				local tagDisp = gInfo.gangTag ~= "" and gInfo.gangTag or ("[" .. gInfo.gangName .. "]")
				local dCol = gInfo.tagColor or Color3.fromRGB(255, 90, 180)
				if typeof(dCol) == "ColorSequence" and #dCol.Keypoints > 0 then
					dCol = dCol.Keypoints[1].Value
				elseif typeof(dCol) ~= "Color3" then
					dCol = Color3.fromRGB(255, 90, 180)
				end
				if gInfo.isTagHidden then
					detailName.Text = plrData.DisplayName .. "  " .. tagDisp .. " 🕶️"
					detailName.TextColor3 = dCol
					detailUser.Text = string.format("@%s  |  🏴‍☠️ Gang: %s [Tag Off]  ·  ID: %d", plrData.Name, gInfo.gangName, plrData.UserId)
					detailUser.TextColor3 = Color3.fromRGB(255, 175, 90)
				else
					detailName.Text = plrData.DisplayName .. "  " .. tagDisp
					detailName.TextColor3 = dCol
					detailUser.Text = string.format("@%s  |  🏴‍☠️ Gang: %s  ·  ID: %d", plrData.Name, gInfo.gangName, plrData.UserId)
					detailUser.TextColor3 = Color3.fromRGB(255, 190, 220)
				end
			else
				detailName.Text = plrData.DisplayName
				detailName.TextColor3 = THEME.TextCyan
				detailUser.Text = "@" .. plrData.Name .. "  |  ID: " .. tostring(plrData.UserId)
				detailUser.TextColor3 = THEME.TextDim
			end
		end

		getCachedThumbnailAsync(plrData.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100, function(thumb)
			detailAvatar.Image = thumb
		end)

		buildServerInfoUI()
		updateRealtimeTelemetry()
	end

	backBtn.MouseButton1Click:Connect(function()
		listView.Visible = true
		detailView.Visible = false
		if addBlacklistView then addBlacklistView.Visible = false end
		selectedDetailPlr = nil
	end)

	blToggleBtn.MouseButton1Click:Connect(function()
		if selectedDetailPlr then
			local _nowBl = toggleBlacklistPlayer(selectedDetailPlr)
			showPlayerDetail(selectedDetailPlr)
			if refreshPlayerList then refreshPlayerList() end
		end
	end)

	stopSpecBtn.MouseButton1Click:Connect(function()
		stopSpectating()
		updateRealtimeTelemetry()
	end)

	specBtn.MouseButton1Click:Connect(function()
		if not selectedDetailPlr or selectedDetailPlr == player then return end
		if isSpectating and spectateTarget == selectedDetailPlr then
			stopSpectating()
		else
			spectatePlayer(selectedDetailPlr)
		end
		updateRealtimeTelemetry()
	end)

	gotoBtn.MouseButton1Click:Connect(function()
		if selectedDetailPlr and selectedDetailPlr ~= player then
			local loc = ADMIN_SYS.locateBlacklistedPlayer and ADMIN_SYS.locateBlacklistedPlayer(selectedDetailPlr.UserId)
			if loc and loc.status == "OTHER_SERVER" and loc.serverId then
				ADMIN_SYS.teleportToServer(loc.serverId)
			else
				spectatePlayer(selectedDetailPlr)
			end
		end
	end)

	srvInfoBtn.MouseButton1Click:Connect(function()
		buildServerInfoUI()
		updateRealtimeTelemetry()
	end)

	pfpInfoBtn.MouseButton1Click:Connect(function()
		buildPfpInfoUI()
		updateRealtimeTelemetry()
	end)

	invInfoBtn.MouseButton1Click:Connect(function()
		buildInventoryUI()
		updateRealtimeTelemetry()
	end)

	intelInfoBtn.MouseButton1Click:Connect(function()
		buildIntelUI()
		updateRealtimeTelemetry()
	end)

	-- =========================================================
	-- GLOBAL ROBLOX SEARCH & DIRECT BLACKLIST VIEW
	-- =========================================================
	addBlacklistView = Instance.new("Frame")
	addBlacklistView.Name = "AddBlacklistView"
	addBlacklistView.Size = UDim2.new(1, 0, 1, 0)
	addBlacklistView.BackgroundTransparency = 1
	addBlacklistView.Visible = false
	addBlacklistView.Parent = pfContent

	local blNavBar = Instance.new("Frame")
	blNavBar.Size = UDim2.new(1, -16, 0, 30)
	blNavBar.Position = UDim2.new(0, 8, 0, 6)
	blNavBar.BackgroundTransparency = 1
	blNavBar.Parent = addBlacklistView

	local blBackBtn = Instance.new("TextButton")
	blBackBtn.Size = UDim2.new(0, 74, 1, 0)
	blBackBtn.Position = UDim2.new(0, 0, 0, 0)
	blBackBtn.BackgroundColor3 = THEME.BtnOff
	blBackBtn.Font = Enum.Font.GothamBold
	blBackBtn.Text = "< BACK"
	blBackBtn.TextColor3 = THEME.TextCyan
	blBackBtn.TextSize = 10.5
	blBackBtn.Parent = blNavBar
	local blbCorner = Instance.new("UICorner")
	blbCorner.CornerRadius = UDim.new(0, 6)
	blbCorner.Parent = blBackBtn
	local blbStroke = Instance.new("UIStroke")
	blbStroke.Color = THEME.BtnOffStroke
	blbStroke.Thickness = 1
	blbStroke.Parent = blBackBtn
	hookButtonHover(blBackBtn, THEME.BtnOff, Color3.fromRGB(36, 44, 58), THEME.TextCyan, Color3.fromRGB(255, 255, 255))

	local blNavTitle = Instance.new("TextLabel")
	blNavTitle.Size = UDim2.new(1, -84, 1, 0)
	blNavTitle.Position = UDim2.new(0, 80, 0, 0)
	blNavTitle.BackgroundTransparency = 1
	blNavTitle.Font = Enum.Font.GothamBold
	blNavTitle.Text = "ROBLOX SEARCH & BLACKLIST"
	blNavTitle.TextColor3 = THEME.TextCyan
	blNavTitle.TextSize = 10.5
	blNavTitle.TextXAlignment = Enum.TextXAlignment.Left
	blNavTitle.Parent = blNavBar

	-- Search Input Bar
	local blSearchFrame = Instance.new("Frame")
	blSearchFrame.Size = UDim2.new(1, -16, 0, 32)
	blSearchFrame.Position = UDim2.new(0, 8, 0, 42)
	blSearchFrame.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
	blSearchFrame.Parent = addBlacklistView
	local blsfCorner = Instance.new("UICorner")
	blsfCorner.CornerRadius = UDim.new(0, 6)
	blsfCorner.Parent = blSearchFrame
	local blsfStroke = Instance.new("UIStroke")
	blsfStroke.Color = Color3.fromRGB(220, 40, 60)
	blsfStroke.Thickness = 1
	blsfStroke.Parent = blSearchFrame

	local blSearchIcon = Instance.new("TextLabel")
	blSearchIcon.Size = UDim2.new(0, 26, 1, 0)
	blSearchIcon.BackgroundTransparency = 1
	blSearchIcon.Font = Enum.Font.GothamBold
	blSearchIcon.Text = "🔍"
	blSearchIcon.TextColor3 = Color3.fromRGB(255, 80, 100)
	blSearchIcon.TextSize = 11
	blSearchIcon.Parent = blSearchFrame

	local blSearchBox = Instance.new("TextBox")
	blSearchBox.Size = UDim2.new(1, -104, 1, 0)
	blSearchBox.Position = UDim2.new(0, 28, 0, 0)
	blSearchBox.BackgroundTransparency = 1
	blSearchBox.Font = Enum.Font.Gotham
	blSearchBox.PlaceholderText = "Type Roblox Username or User ID..."
	blSearchBox.PlaceholderColor3 = THEME.TextDim
	blSearchBox.Text = ""
	blSearchBox.TextColor3 = THEME.TextFrost
	blSearchBox.TextSize = 10.5
	blSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	blSearchBox.ClearTextOnFocus = false
	blSearchBox.Parent = blSearchFrame

	local blSearchBtn = Instance.new("TextButton")
	blSearchBtn.Size = UDim2.new(0, 72, 1, -4)
	blSearchBtn.Position = UDim2.new(1, -74, 0, 2)
	blSearchBtn.BackgroundColor3 = Color3.fromRGB(36, 14, 20)
	blSearchBtn.Font = Enum.Font.GothamBold
	blSearchBtn.Text = "SEARCH"
	blSearchBtn.TextColor3 = Color3.fromRGB(255, 140, 160)
	blSearchBtn.TextSize = 9.5
	blSearchBtn.AutoButtonColor = false
	blSearchBtn.Parent = blSearchFrame
	local blsbCorner = Instance.new("UICorner")
	blsbCorner.CornerRadius = UDim.new(0, 4)
	blsbCorner.Parent = blSearchBtn
	local blsbStroke = Instance.new("UIStroke")
	blsbStroke.Color = Color3.fromRGB(255, 60, 80)
	blsbStroke.Thickness = 1
	blsbStroke.Parent = blSearchBtn
	hookButtonHover(blSearchBtn, Color3.fromRGB(36, 14, 20), Color3.fromRGB(60, 20, 30), Color3.fromRGB(255, 140, 160), Color3.fromRGB(255, 255, 255))

	local blStatusLbl = Instance.new("TextLabel")
	blStatusLbl.Size = UDim2.new(1, -16, 0, 16)
	blStatusLbl.Position = UDim2.new(0, 8, 0, 78)
	blStatusLbl.BackgroundTransparency = 1
	blStatusLbl.Font = Enum.Font.Gotham
	blStatusLbl.Text = "Enter any Roblox username/ID to locate & blacklist directly"
	blStatusLbl.TextColor3 = THEME.TextDim
	blStatusLbl.TextSize = 9.5
	blStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
	blStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
	blStatusLbl.Parent = addBlacklistView

	-- Result Card
	local blResultCard = Instance.new("Frame")
	blResultCard.Size = UDim2.new(1, -16, 0, 126)
	blResultCard.Position = UDim2.new(0, 8, 0, 98)
	blResultCard.BackgroundColor3 = THEME.CardBg
	blResultCard.BorderSizePixel = 0
	blResultCard.Visible = false
	blResultCard.Parent = addBlacklistView
	local rcCorner = Instance.new("UICorner")
	rcCorner.CornerRadius = UDim.new(0, 8)
	rcCorner.Parent = blResultCard
	local rcStroke = Instance.new("UIStroke")
	rcStroke.Color = Color3.fromRGB(220, 40, 60)
	rcStroke.Thickness = 1
	rcStroke.Parent = blResultCard

	local rcAvatar = Instance.new("ImageLabel")
	rcAvatar.Size = UDim2.new(0, 54, 0, 54)
	rcAvatar.Position = UDim2.new(0, 10, 0, 10)
	rcAvatar.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	rcAvatar.BorderSizePixel = 0
	rcAvatar.Parent = blResultCard
	local rcaCorner = Instance.new("UICorner")
	rcaCorner.CornerRadius = UDim.new(0, 8)
	rcaCorner.Parent = rcAvatar
	local rcaStroke = Instance.new("UIStroke")
	rcaStroke.Color = Color3.fromRGB(255, 60, 80)
	rcaStroke.Thickness = 1
	rcaStroke.Parent = rcAvatar

	local rcDispName = Instance.new("TextLabel")
	rcDispName.Size = UDim2.new(1, -78, 0, 18)
	rcDispName.Position = UDim2.new(0, 72, 0, 10)
	rcDispName.BackgroundTransparency = 1
	rcDispName.Font = Enum.Font.GothamBold
	rcDispName.Text = "Player Name"
	rcDispName.TextColor3 = Color3.fromRGB(255, 255, 255)
	rcDispName.TextSize = 12
	rcDispName.TextXAlignment = Enum.TextXAlignment.Left
	rcDispName.TextTruncate = Enum.TextTruncate.AtEnd
	rcDispName.Parent = blResultCard

	local rcUserName = Instance.new("TextLabel")
	rcUserName.Size = UDim2.new(1, -78, 0, 16)
	rcUserName.Position = UDim2.new(0, 72, 0, 28)
	rcUserName.BackgroundTransparency = 1
	rcUserName.Font = Enum.Font.Gotham
	rcUserName.Text = "@Username · ID: 00000"
	rcUserName.TextColor3 = THEME.TextCyan
	rcUserName.TextSize = 10
	rcUserName.TextXAlignment = Enum.TextXAlignment.Left
	rcUserName.TextTruncate = Enum.TextTruncate.AtEnd
	rcUserName.Parent = blResultCard

	local rcLocation = Instance.new("TextLabel")
	rcLocation.Size = UDim2.new(1, -78, 0, 16)
	rcLocation.Position = UDim2.new(0, 72, 0, 46)
	rcLocation.BackgroundTransparency = 1
	rcLocation.Font = Enum.Font.Gotham
	rcLocation.Text = "📍 Location checking..."
	rcLocation.TextColor3 = THEME.TextDim
	rcLocation.TextSize = 9.5
	rcLocation.TextXAlignment = Enum.TextXAlignment.Left
	rcLocation.TextTruncate = Enum.TextTruncate.AtEnd
	rcLocation.Parent = blResultCard

	local rcActionBtn = Instance.new("TextButton")
	rcActionBtn.Size = UDim2.new(1, -20, 0, 32)
	rcActionBtn.Position = UDim2.new(0, 10, 0, 84)
	rcActionBtn.BackgroundColor3 = Color3.fromRGB(180, 25, 45)
	rcActionBtn.Font = Enum.Font.GothamBold
	rcActionBtn.Text = "⛔ BLACKLIST THIS PLAYER"
	rcActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rcActionBtn.TextSize = 10.5
	rcActionBtn.AutoButtonColor = false
	rcActionBtn.Parent = blResultCard
	local rcabCorner = Instance.new("UICorner")
	rcabCorner.CornerRadius = UDim.new(0, 6)
	rcabCorner.Parent = rcActionBtn
	local rcabStroke = Instance.new("UIStroke")
	rcabStroke.Color = Color3.fromRGB(255, 70, 95)
	rcabStroke.Thickness = 1
	rcabStroke.Parent = rcActionBtn

	-- Saved Blacklist Vault List
	local vHeader = Instance.new("TextLabel")
	vHeader.Size = UDim2.new(1, -16, 0, 18)
	vHeader.Position = UDim2.new(0, 8, 0, 230)
	vHeader.BackgroundTransparency = 1
	vHeader.Font = Enum.Font.GothamBold
	vHeader.Text = "SAVED BLACKLIST TARGETS"
	vHeader.TextColor3 = THEME.TextCyan
	vHeader.TextSize = 10
	vHeader.TextXAlignment = Enum.TextXAlignment.Left
	vHeader.Parent = addBlacklistView

	local vScroll = Instance.new("ScrollingFrame")
	vScroll.Size = UDim2.new(1, -16, 1, -254)
	vScroll.Position = UDim2.new(0, 8, 0, 250)
	vScroll.BackgroundTransparency = 1
	vScroll.BorderSizePixel = 0
	vScroll.ScrollBarThickness = 3
	vScroll.ScrollBarImageColor3 = THEME.BorderBeam
	vScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	vScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	vScroll.Parent = addBlacklistView

	local vLayout = Instance.new("UIListLayout")
	vLayout.SortOrder = Enum.SortOrder.LayoutOrder
	vLayout.Padding = UDim.new(0, 4)
	vLayout.Parent = vScroll

	local currentSearchedUser = nil

	local function updateResultCardUI()
		if not currentSearchedUser then
			blResultCard.Visible = false
			return
		end
		local u = currentSearchedUser
		blResultCard.Visible = true
		rcDispName.Text = u.displayName
		rcUserName.Text = string.format("@%s  ·  ID: %d", u.name, u.userId)

		local loc = ADMIN_SYS.locateBlacklistedPlayer and ADMIN_SYS.locateBlacklistedPlayer(u.userId)
		if loc and loc.status == "CURRENT_SERVER" then
			rcLocation.Text = "🟢 Active in This Server"
			rcLocation.TextColor3 = Color3.fromRGB(100, 255, 160)
		elseif loc and loc.status == "OTHER_SERVER" then
			rcLocation.Text = string.format("📍 In %s (👥 %d/%d)", loc.serverTitle or "Server", loc.total or 0, loc.max or 60)
			rcLocation.TextColor3 = Color3.fromRGB(120, 220, 255)
		else
			rcLocation.Text = "🔴 Offline / Inactive"
			rcLocation.TextColor3 = THEME.TextDim
		end

		getCachedThumbnailAsync(u.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100, function(thumb)
			rcAvatar.Image = thumb
		end)

		local isBl = isPlayerBlacklisted(u.userId)
		if isBl then
			rcActionBtn.Text = "✅ BLACKLISTED  ·  [ 🗑️ UNLIST ]"
			rcActionBtn.BackgroundColor3 = Color3.fromRGB(36, 12, 18)
			rcActionBtn.TextColor3 = Color3.fromRGB(255, 140, 160)
			rcabStroke.Color = Color3.fromRGB(255, 50, 70)
		else
			rcActionBtn.Text = "⛔ BLACKLIST THIS PLAYER"
			rcActionBtn.BackgroundColor3 = Color3.fromRGB(180, 25, 45)
			rcActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			rcabStroke.Color = Color3.fromRGB(255, 70, 95)
		end
	end

	rcActionBtn.MouseButton1Click:Connect(function()
		if not currentSearchedUser then return end
		local u = currentSearchedUser
		local isBl = isPlayerBlacklisted(u.userId)
		if isBl then
			ADMIN_SYS.unblacklistUserId(u.userId)
			blStatusLbl.Text = "✅ Removed @" .. u.name .. " from Blacklist."
			blStatusLbl.TextColor3 = Color3.fromRGB(100, 255, 160)
		else
			ADMIN_SYS.blacklistUser(u.userId, u.name, u.displayName)
			blStatusLbl.Text = "⛔ Successfully Blacklisted @" .. u.name .. "!"
			blStatusLbl.TextColor3 = Color3.fromRGB(255, 80, 100)
		end
		updateResultCardUI()
		if refreshVaultList then refreshVaultList() end
	end)

	refreshVaultList = function()
		for _, child in ipairs(vScroll:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end

		local allBl = ADMIN_SYS.getBlacklistedUsers and ADMIN_SYS.getBlacklistedUsers() or {}
		local list = {}
		local seenIds = {}
		for rawKey, rec in pairs(allBl) do
			local idStr = tostring(rawKey)
			local numId = tonumber(idStr) or 0
			if numId > 0 and not seenIds[idStr] then
				seenIds[idStr] = true
				table.insert(list, {
					idStr = idStr,
					userId = numId,
					name = rec.Name or rec.name or idStr,
					displayName = rec.DisplayName or rec.displayName or rec.Name or rec.name or idStr,
					addedAt = rec.AddedAt or rec.addedAt or 0
				})
			end
		end
		table.sort(list, function(a, b) return a.addedAt > b.addedAt end)

		vHeader.Text = string.format("SAVED BLACKLIST TARGETS (%d)", #list)

		for idx, item in ipairs(list) do
			local row = Instance.new("Frame")
			row.Name = "VRow_" .. item.idStr
			row.Size = UDim2.new(1, 0, 0, 36)
			row.BackgroundColor3 = THEME.CardBg
			row.BorderSizePixel = 0
			row.LayoutOrder = idx
			row.Parent = vScroll
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = row
			local s = Instance.new("UIStroke")
			s.Color = Color3.fromRGB(120, 25, 38)
			s.Thickness = 1
			s.Parent = row

			local av = Instance.new("ImageLabel")
			av.Size = UDim2.new(0, 26, 0, 26)
			av.Position = UDim2.new(0, 5, 0.5, -13)
			av.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
			av.BorderSizePixel = 0
			av.Parent = row
			local avc = Instance.new("UICorner")
			avc.CornerRadius = UDim.new(0, 4)
			avc.Parent = av
			getCachedThumbnailAsync(item.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(thumb)
				av.Image = thumb
			end)

			local disp = (item.displayName and item.displayName ~= item.name) and (" (" .. item.displayName .. ")") or ""
			local nLbl = Instance.new("TextLabel")
			nLbl.Size = UDim2.new(1, -125, 0, 16)
			nLbl.Position = UDim2.new(0, 36, 0, 3)
			nLbl.BackgroundTransparency = 1
			nLbl.Font = Enum.Font.GothamBold
			nLbl.Text = "@" .. item.name .. disp
			nLbl.TextColor3 = Color3.fromRGB(255, 120, 140)
			nLbl.TextSize = 10
			nLbl.TextXAlignment = Enum.TextXAlignment.Left
			nLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nLbl.Parent = row

			local loc = ADMIN_SYS.locateBlacklistedPlayer and ADMIN_SYS.locateBlacklistedPlayer(item.userId)
			local locTxt = "🔴 Offline"
			local locCol = THEME.TextDim
			if loc and loc.status == "CURRENT_SERVER" then
				locTxt = "🟢 In This Server"
				locCol = Color3.fromRGB(100, 255, 160)
			elseif loc and loc.status == "OTHER_SERVER" then
				locTxt = string.format("📍 In %s", loc.serverTitle or "Server")
				locCol = Color3.fromRGB(120, 220, 255)
			end
			local sLbl = Instance.new("TextLabel")
			sLbl.Size = UDim2.new(1, -125, 0, 14)
			sLbl.Position = UDim2.new(0, 36, 0, 19)
			sLbl.BackgroundTransparency = 1
			sLbl.Font = Enum.Font.Gotham
			sLbl.Text = string.format("ID: %s  ·  %s", item.idStr, locTxt)
			sLbl.TextColor3 = locCol
			sLbl.TextSize = 8.5
			sLbl.TextXAlignment = Enum.TextXAlignment.Left
			sLbl.TextTruncate = Enum.TextTruncate.AtEnd
			sLbl.Parent = row

			local unBtn = Instance.new("TextButton")
			unBtn.Size = UDim2.new(0, 76, 0, 22)
			unBtn.Position = UDim2.new(1, -82, 0.5, -11)
			unBtn.BackgroundColor3 = Color3.fromRGB(40, 14, 20)
			unBtn.Font = Enum.Font.GothamBold
			unBtn.Text = "🗑️ UNLIST"
			unBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
			unBtn.TextSize = 8.5
			unBtn.AutoButtonColor = false
			unBtn.Parent = row
			local ubc = Instance.new("UICorner")
			ubc.CornerRadius = UDim.new(0, 4)
			ubc.Parent = unBtn
			local ubs = Instance.new("UIStroke")
			ubs.Color = Color3.fromRGB(255, 60, 80)
			ubs.Thickness = 1
			ubs.Parent = unBtn
			hookButtonHover(unBtn, Color3.fromRGB(40, 14, 20), Color3.fromRGB(60, 20, 30), Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 255, 255))
			unBtn.MouseButton1Click:Connect(function()
				ADMIN_SYS.unblacklistUserId(item.idStr)
				if currentSearchedUser and currentSearchedUser.userId == item.userId then
					updateResultCardUI()
				end
				refreshVaultList()
			end)
		end

		if #list == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 36)
			empty.BackgroundTransparency = 1
			empty.Font = Enum.Font.Gotham
			empty.Text = "No players currently in your blacklist."
			empty.TextColor3 = THEME.TextDim
			empty.TextSize = 9.5
			empty.TextXAlignment = Enum.TextXAlignment.Center
			empty.Parent = vScroll
		end
	end

	local isSearching = false
	local function doSearch()
		if isSearching then return end
		local raw = blSearchBox.Text
		local query = string.gsub(raw, "^%s*(.-)%s*$", "%1")
		if query == "" then
			blStatusLbl.Text = "⚠️ Please enter a Roblox username or User ID."
			blStatusLbl.TextColor3 = Color3.fromRGB(255, 180, 60)
			currentSearchedUser = nil
			updateResultCardUI()
			return
		end

		isSearching = true
		blStatusLbl.Text = "⏳ Searching Roblox for '" .. query .. "'..."
		blStatusLbl.TextColor3 = THEME.TextCyan
		blResultCard.Visible = false

		task.spawn(function()
			local targetId = nil
			local targetName = nil
			local targetDisp = nil

			-- 1. If digits, try as UserId first
			local num = tonumber(query)
			if num and num > 0 then
				local ok, name = pcall(function()
					return Players:GetNameFromUserIdAsync(num)
				end)
				if ok and name and name ~= "" then
					targetId = num
					targetName = name
					targetDisp = name
				end
			end

			-- 2. If not found by ID, search by Username
			if not targetId then
				local cleanName = string.gsub(query, "^@", "")
				local ok, uid = pcall(function()
					return Players:GetUserIdFromNameAsync(cleanName)
				end)
				if ok and uid and uid > 0 then
					targetId = uid
					local nameOk, resolvedName = pcall(function()
						return Players:GetNameFromUserIdAsync(uid)
					end)
					targetName = (nameOk and resolvedName) or cleanName
					targetDisp = targetName
				end
			end

			-- 3. Resolve DisplayName if possible
			if targetId then
				local localP = Players:GetPlayerByUserId(targetId)
				if localP then
					targetName = localP.Name
					targetDisp = localP.DisplayName
				else
					pcall(function()
						if UserService and type(UserService.GetUserInfosByUserIdsAsync) == "function" then
							local infos = UserService:GetUserInfosByUserIdsAsync({targetId})
							if infos and infos[1] and infos[1].DisplayName then
								targetDisp = infos[1].DisplayName
							end
						end
					end)
				end
			end

			isSearching = false

			if not targetId then
				blStatusLbl.Text = "❌ No Roblox user found matching '" .. query .. "'. Check spelling."
				blStatusLbl.TextColor3 = Color3.fromRGB(255, 80, 100)
				currentSearchedUser = nil
				updateResultCardUI()
				return
			end

			blStatusLbl.Text = "✅ User located on Roblox! Ready to blacklist."
			blStatusLbl.TextColor3 = Color3.fromRGB(100, 255, 160)
			currentSearchedUser = {
				userId = targetId,
				name = targetName or query,
				displayName = targetDisp or targetName or query,
			}
			updateResultCardUI()
		end)
	end

	blSearchBtn.MouseButton1Click:Connect(doSearch)
	blSearchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then doSearch() end
	end)

	blBackBtn.MouseButton1Click:Connect(function()
		addBlacklistView.Visible = false
		detailView.Visible = false
		listView.Visible = true
	end)

	addBlNavBtn.MouseButton1Click:Connect(function()
		listView.Visible = false
		detailView.Visible = false
		addBlacklistView.Visible = true
		refreshVaultList()
	end)

	local function createPlayerRow(plrData)
		local isBl = isPlayerBlacklisted(plrData.UserId)
		local isStaff, roleName = checkPlayerStaff(plrData)

		local row = Instance.new("TextButton")
		row.Name = (isBl and "00_" or (isStaff and "01_" or "10_")) .. plrData.Name
		row.Size = UDim2.new(1, -4, 0, 48)
		row.BackgroundColor3 = isBl and Color3.fromRGB(30, 10, 16) or (isStaff and Color3.fromRGB(24, 12, 18) or THEME.CardBg)
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = ""
		row.LayoutOrder = isBl and -2000 or (isStaff and -1000 or 0)
		row.Parent = plrScroll

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 8)
		rCorner.Parent = row

		local rStroke = Instance.new("UIStroke")
		rStroke.Color = isBl and Color3.fromRGB(255, 30, 50) or (isStaff and Color3.fromRGB(255, 50, 80) or THEME.CardStroke)
		rStroke.Thickness = (isBl or isStaff) and 1.5 or 1
		rStroke.Parent = row

		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 34, 0, 34)
		avatar.Position = UDim2.new(0, 8, 0.5, -17)
		avatar.BackgroundColor3 = isBl and Color3.fromRGB(42, 12, 18) or (isStaff and Color3.fromRGB(36, 14, 22) or Color3.fromRGB(24, 24, 28))
		avatar.Parent = row
		local avCorner = Instance.new("UICorner")
		avCorner.CornerRadius = UDim.new(0, 17)
		avCorner.Parent = avatar
		local avStroke = Instance.new("UIStroke")
		avStroke.Color = isBl and Color3.fromRGB(255, 40, 60) or (isStaff and Color3.fromRGB(255, 60, 90) or THEME.BorderBase)
		avStroke.Thickness = (isBl or isStaff) and 1.5 or 1
		avStroke.Parent = avatar

		getCachedThumbnailAsync(plrData.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(thumb)
			avatar.Image = thumb
		end)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, (isBl or isStaff) and -195 or -140, 0, 18)
		nameLabel.Position = UDim2.new(0, 50, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		if isBl then
			nameLabel.Text = "⛔ " .. plrData.DisplayName
			nameLabel.TextColor3 = Color3.fromRGB(255, 60, 80)
		elseif isStaff then
			nameLabel.Text = "🚨 " .. plrData.DisplayName
			nameLabel.TextColor3 = Color3.fromRGB(255, 80, 110)
		else
			nameLabel.Text = plrData.DisplayName
			nameLabel.TextColor3 = THEME.TextFrost
		end
		nameLabel.TextSize = 11
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row

		local userLabel = Instance.new("TextLabel")
		userLabel.Size = UDim2.new(1, -140, 0, 14)
		userLabel.Position = UDim2.new(0, 50, 0, 26)
		userLabel.BackgroundTransparency = 1
		userLabel.Font = Enum.Font.Gotham
		local gRowInfo = GANG_SYS and GANG_SYS.getPlayerGang(plrData.UserId)
		if isBl then
			userLabel.Text = "@" .. plrData.Name .. " • ⚠️ BLACKLISTED"
			userLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
		elseif isStaff then
			userLabel.Text = "@" .. plrData.Name .. " • [" .. string.upper(roleName or "STAFF") .. "]"
			userLabel.TextColor3 = Color3.fromRGB(255, 130, 160)
		elseif gRowInfo then
			local tagDisp = gRowInfo.gangTag ~= "" and gRowInfo.gangTag or ("[" .. gRowInfo.gangName .. "]")
			if gRowInfo.isTagHidden then
				userLabel.Text = "@" .. plrData.Name .. " • 🏴‍☠️ " .. tagDisp .. " 🕶️"
				userLabel.TextColor3 = Color3.fromRGB(255, 175, 90)
			else
				userLabel.Text = "@" .. plrData.Name .. " • 🏴‍☠️ " .. tagDisp
				local rowCol = gRowInfo.tagColor or Color3.fromRGB(255, 185, 90)
				if typeof(rowCol) == "ColorSequence" and #rowCol.Keypoints > 0 then
					rowCol = rowCol.Keypoints[1].Value
				elseif typeof(rowCol) ~= "Color3" then
					rowCol = Color3.fromRGB(255, 185, 90)
				end
				userLabel.TextColor3 = rowCol
			end
		else
			userLabel.Text = "@" .. plrData.Name
			userLabel.TextColor3 = THEME.TextDim
		end
		userLabel.TextSize = 10
		userLabel.TextXAlignment = Enum.TextXAlignment.Left
		userLabel.TextTruncate = Enum.TextTruncate.AtEnd
		userLabel.Parent = row

		if isBl then
			local bPill = Instance.new("Frame")
			bPill.Size = UDim2.new(0, 72, 0, 16)
			bPill.Position = UDim2.new(1, -190, 0, 7)
			bPill.BackgroundColor3 = Color3.fromRGB(210, 20, 45)
			bPill.BorderSizePixel = 0
			bPill.Parent = row
			local bpc = Instance.new("UICorner")
			bpc.CornerRadius = UDim.new(0, 3)
			bpc.Parent = bPill
			local bpt = Instance.new("TextLabel")
			bpt.Size = UDim2.new(1, 0, 1, 0)
			bpt.BackgroundTransparency = 1
			bpt.Font = Enum.Font.GothamBold
			bpt.Text = "⛔ BLACKLIST"
			bpt.TextColor3 = Color3.fromRGB(255, 255, 255)
			bpt.TextSize = 8.5
			bpt.Parent = bPill
		elseif isStaff then
			local sPill = Instance.new("Frame")
			sPill.Size = UDim2.new(0, 52, 0, 16)
			sPill.Position = UDim2.new(1, -170, 0, 7)
			sPill.BackgroundColor3 = Color3.fromRGB(220, 30, 65)
			sPill.BorderSizePixel = 0
			sPill.Parent = row
			local spCorner = Instance.new("UICorner")
			spCorner.CornerRadius = UDim.new(0, 3)
			spCorner.Parent = sPill
			local spText = Instance.new("TextLabel")
			spText.Size = UDim2.new(1, 0, 1, 0)
			spText.BackgroundTransparency = 1
			spText.Font = Enum.Font.GothamBold
			spText.Text = "STAFF"
			spText.TextColor3 = Color3.fromRGB(255, 255, 255)
			spText.TextSize = 9
			spText.Parent = sPill
		end

		local healthBar = Instance.new("Frame")
		healthBar.Size = UDim2.new(0, 50, 0, 4)
		healthBar.Position = UDim2.new(1, -114, 0.5, 6)
		healthBar.BackgroundColor3 = Color3.fromRGB(30, 12, 16)
		healthBar.BorderSizePixel = 0
		healthBar.Parent = row
		local hbCorner = Instance.new("UICorner")
		hbCorner.CornerRadius = UDim.new(0, 2)
		hbCorner.Parent = healthBar

		local healthFill = Instance.new("Frame")
		healthFill.Size = UDim2.new(1, 0, 1, 0)
		healthFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
		healthFill.BorderSizePixel = 0
		healthFill.Parent = healthBar
		local hfCorner = Instance.new("UICorner")
		hfCorner.CornerRadius = UDim.new(0, 2)
		hfCorner.Parent = healthFill

		local statusDot = Instance.new("Frame")
		statusDot.Size = UDim2.new(0, 8, 0, 8)
		statusDot.Position = UDim2.new(1, -54, 0.5, -4)
		statusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
		statusDot.BorderSizePixel = 0
		statusDot.Parent = row
		local sdCorner = Instance.new("UICorner")
		sdCorner.CornerRadius = UDim.new(1, 0)
		sdCorner.Parent = statusDot

		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.new(0, 20, 0, 20)
		arrow.Position = UDim2.new(1, -30, 0.5, -10)
		arrow.BackgroundTransparency = 1
		arrow.Font = Enum.Font.GothamBold
		arrow.Text = ">"
		arrow.TextColor3 = (isBl or isStaff) and Color3.fromRGB(255, 60, 90) or THEME.TextCyan
		arrow.TextSize = 13
		arrow.Parent = row

		row.MouseEnter:Connect(function()
			if isBl then
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(44, 14, 22)}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 60, 90)}):Play()
			elseif isStaff then
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(36, 16, 26)}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 80, 120)}):Play()
			else
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 28, 32)}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = THEME.BorderBeam}):Play()
			end
		end)
		row.MouseLeave:Connect(function()
			if isBl then
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 10, 16)}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 30, 50)}):Play()
			elseif isStaff then
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(24, 12, 18)}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(255, 50, 80)}):Play()
			else
				TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = THEME.CardBg}):Play()
				TweenService:Create(rStroke, TweenInfo.new(0.15), {Color = THEME.CardStroke}):Play()
			end
		end)

		row.MouseButton1Click:Connect(function()
			showPlayerDetail(plrData)
		end)

		local function updateRow()
			local char = plrData.Character
			if char then
				local curHp, maxHp, isDowned = getLivePlayerHealth(plrData, char)
				local ratio = isDowned and 0 or math.clamp(curHp / math.max(maxHp, 1), 0, 1)
				healthFill.Size = UDim2.new(ratio, 0, 1, 0)
				if isDowned then
					healthFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
					statusDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
				elseif ratio > 0.5 then
					healthFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
					statusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
				elseif ratio > 0.2 then
					healthFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
					statusDot.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
				else
					healthFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
					statusDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
				end
			else
				healthFill.Size = UDim2.new(0, 0, 1, 0)
				statusDot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			end
		end

		return row, updateRow
	end

	local playerRows = {}
	local playerUpdateFns = {}

	refreshPlayerList = function()
		local currentPlayers = {}
		local query = string.lower(searchBox.Text or "")
		local staffCount = 0
		local blacklistCount = 0

		for _, p in ipairs(Players:GetPlayers()) do
			currentPlayers[p] = true
			local isBl = isPlayerBlacklisted(p.UserId)
			local isStaff, roleName = checkPlayerStaff(p)
			if isBl then
				blacklistCount = blacklistCount + 1
			end
			if isStaff then
				staffCount = staffCount + 1
			end

			local row = playerRows[p]
			if row then
				local expectedPrefix = isBl and "00_" or (isStaff and "01_" or "10_")
				local currentPrefix = string.sub(row.Name, 1, 3)
				if currentPrefix ~= expectedPrefix then
					pcall(function() row:Destroy() end)
					playerRows[p] = nil
					playerUpdateFns[p] = nil
				end
			end

			if not playerRows[p] then
				local newRow, updateFn = createPlayerRow(p)
				playerRows[p] = newRow
				playerUpdateFns[p] = updateFn
			end

			row = playerRows[p]
			if row then
				if query == "" then
					row.Visible = true
				else
					local nameMatch = string.find(string.lower(p.Name), query, 1, true)
					local dispMatch = string.find(string.lower(p.DisplayName), query, 1, true)
					local roleMatch = string.find(string.lower(roleName or ""), query, 1, true)
					local staffQueryMatch = (isStaff and string.find("staff", query, 1, true) ~= nil)
					local blQueryMatch = (isBl and (string.find("blacklist", query, 1, true) ~= nil or string.find("block", query, 1, true) ~= nil))
					local gInfo = GANG_SYS and GANG_SYS.getPlayerGang(p.UserId)
					local gangMatch = gInfo and (string.find(string.lower(gInfo.gangName), query, 1, true) ~= nil or string.find(string.lower(gInfo.gangTag), query, 1, true) ~= nil)
					row.Visible = (nameMatch ~= nil or dispMatch ~= nil or roleMatch ~= nil or staffQueryMatch or blQueryMatch or gangMatch)
				end
			end
		end

		for p, row in pairs(playerRows) do
			if not currentPlayers[p] then
				pcall(function() row:Destroy() end)
				playerRows[p] = nil
				playerUpdateFns[p] = nil
			end
		end

		pfCountLabel.Text = tostring(#Players:GetPlayers()) .. " ONLINE"

		pcall(function()
			if pfBlacklistBadge and pfBlacklistText then
				if blacklistCount > 0 then
					pfBlacklistBadge.BackgroundColor3 = Color3.fromRGB(50, 10, 18)
					if pfBlacklistStroke then pfBlacklistStroke.Color = Color3.fromRGB(255, 30, 50) end
					pfBlacklistText.Text = "⛔ " .. tostring(blacklistCount) .. " BLOCKED"
					pfBlacklistText.TextColor3 = Color3.fromRGB(255, 60, 80)
				else
					pfBlacklistBadge.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
					if pfBlacklistStroke then pfBlacklistStroke.Color = THEME.CardStroke end
					pfBlacklistText.Text = "⛔ 0 BLOCKED"
					pfBlacklistText.TextColor3 = THEME.TextDim
				end
			end
		end)

		pcall(function()
			if pfStaffBadge and pfStaffText then
				if staffCount > 0 then
					pfStaffBadge.BackgroundColor3 = Color3.fromRGB(44, 12, 20)
					if pfStaffStroke then pfStaffStroke.Color = Color3.fromRGB(255, 50, 80) end
					pfStaffText.Text = "🚨 " .. tostring(staffCount) .. " STAFF"
					pfStaffText.TextColor3 = Color3.fromRGB(255, 70, 100)
				else
					pfStaffBadge.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
					if pfStaffStroke then pfStaffStroke.Color = THEME.CardStroke end
					pfStaffText.Text = "🛡️ 0 STAFF"
					pfStaffText.TextColor3 = THEME.TextDim
				end
			end
		end)

		pcall(function()
			plrScroll.CanvasSize = UDim2.new(0, 0, 0, plrListLayout.AbsoluteContentSize.Y + 8)
		end)
	end

	onStaffDetected.Event:Connect(function()
		pcall(function()
			if plrFrame.Visible then
				refreshPlayerList()
			end
		end)
	end)

	onBlacklistChanged.Event:Connect(function()
		pcall(function()
			if plrFrame.Visible then
				refreshPlayerList()
				if addBlacklistView and addBlacklistView.Visible and refreshVaultList then
					refreshVaultList()
				end
			end
		end)
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(searchBox.Text)
		for p, row in pairs(playerRows) do
			if query == "" then
				row.Visible = true
			else
				local nameMatch = string.find(string.lower(p.Name), query, 1, true)
				local dispMatch = string.find(string.lower(p.DisplayName), query, 1, true)
				row.Visible = (nameMatch ~= nil or dispMatch ~= nil)
			end
		end
	end)

	spectateHud = Instance.new("Frame")
	spectateHud.Name = "AstrocynaSpectateHud"
	spectateHud.AnchorPoint = Vector2.new(0.5, 0)
	spectateHud.Size = UDim2.new(0, 360, 0, 46)
	spectateHud.Position = UDim2.new(0.5, 0, 0, 64)
	spectateHud.BackgroundColor3 = THEME.MainBg
	spectateHud.BackgroundTransparency = 0.15
	spectateHud.BorderSizePixel = 0
	spectateHud.Visible = false
	spectateHud.ClipsDescendants = true
	spectateHud.Parent = screenGui

	local shScale = Instance.new("UIScale")
	shScale.Name = "ResponsiveScale"
	shScale.Parent = spectateHud

	local function updateSpectateHudScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if vp.X > 0 then
			local bestScale = math.clamp((vp.X - 24) / 360, 0.65, 1.0)
			shScale.Scale = bestScale
		end
		spectateHud.AnchorPoint = Vector2.new(0.5, 0)
		spectateHud.Position = UDim2.new(0.5, 0, 0, 64)
	end
	updateSpectateHudScale()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateSpectateHudScale)
	end

	local shCorner = Instance.new("UICorner")
	shCorner.CornerRadius = UDim.new(0, 8)
	shCorner.Parent = spectateHud

	local shStroke = Instance.new("UIStroke")
	shStroke.Thickness = 1.5
	shStroke.Parent = spectateHud
	applyNeonSweep(shStroke, 110, 2.5, 1.8, 2.6)

	shAvatar = Instance.new("ImageLabel")
	shAvatar.Size = UDim2.new(0, 32, 0, 32)
	shAvatar.Position = UDim2.new(0, 8, 0.5, -16)
	shAvatar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	shAvatar.Parent = spectateHud
	local shaCorner = Instance.new("UICorner")
	shaCorner.CornerRadius = UDim.new(0, 16)
	shaCorner.Parent = shAvatar

	shTitle = Instance.new("TextLabel")
	shTitle.Size = UDim2.new(1, -150, 0, 16)
	shTitle.Position = UDim2.new(0, 46, 0, 6)
	shTitle.BackgroundTransparency = 1
	shTitle.Font = Enum.Font.GothamBold
	shTitle.Text = "SPECTATING: -"
	shTitle.TextColor3 = THEME.TextCyan
	shTitle.TextSize = 11
	shTitle.TextXAlignment = Enum.TextXAlignment.Left
	shTitle.TextTruncate = Enum.TextTruncate.AtEnd
	shTitle.Parent = spectateHud

	local shMicBadge = Instance.new("TextLabel")
	shMicBadge.Size = UDim2.new(1, -150, 0, 14)
	shMicBadge.Position = UDim2.new(0, 46, 0, 24)
	shMicBadge.BackgroundTransparency = 1
	shMicBadge.Font = Enum.Font.Gotham
	shMicBadge.Text = "🎙️ Zone Mic: ACTIVE (RP & Native)"
	shMicBadge.TextColor3 = Color3.fromRGB(0, 225, 140)
	shMicBadge.TextSize = 9
	shMicBadge.TextXAlignment = Enum.TextXAlignment.Left
	shMicBadge.Parent = spectateHud

	local shStopBtn = Instance.new("TextButton")
	shStopBtn.Size = UDim2.new(0, 88, 0, 28)
	shStopBtn.Position = UDim2.new(1, -96, 0.5, -14)
	shStopBtn.BackgroundColor3 = Color3.fromRGB(28, 14, 22)
	shStopBtn.Font = Enum.Font.GothamBold
	shStopBtn.Text = "⏹ STOP [X]"
	shStopBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
	shStopBtn.TextSize = 10
	shStopBtn.Parent = spectateHud
	local shbCorner = Instance.new("UICorner")
	shbCorner.CornerRadius = UDim.new(0, 5)
	shbCorner.Parent = shStopBtn
	local shbStroke = Instance.new("UIStroke")
	shbStroke.Color = Color3.fromRGB(255, 60, 90)
	shbStroke.Thickness = 1
	shbStroke.Parent = shStopBtn
	hookButtonHover(shStopBtn, Color3.fromRGB(28, 14, 22), Color3.fromRGB(48, 18, 30), Color3.fromRGB(220, 220, 225), Color3.fromRGB(255, 220, 230))

	shStopBtn.MouseButton1Click:Connect(function()
		stopSpectating()
		updateRealtimeTelemetry()
		if updateHackerLiveCards then pcall(updateHackerLiveCards) end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.X and isSpectating then
			stopSpectating()
			updateRealtimeTelemetry()
			if updateHackerLiveCards then pcall(updateHackerLiveCards) end
		end
	end)

	local plrUpdateTick = 0
	table.insert(activeAnimators, function(dt)

		FPS_TRACKER.frames = FPS_TRACKER.frames + 1
		FPS_TRACKER.timer = FPS_TRACKER.timer + dt
		if FPS_TRACKER.timer >= 0.5 then
			FPS_TRACKER.current = math.floor((FPS_TRACKER.frames / FPS_TRACKER.timer) + 0.5)
			FPS_TRACKER.frames = 0
			FPS_TRACKER.timer = 0
		end

		if isSpectating and spectateTarget then
			spectateHud.Visible = true
		else
			spectateHud.Visible = false
		end

		plrUpdateTick = plrUpdateTick + dt
		if plrUpdateTick < 0.1 then return end
		plrUpdateTick = 0

		if plrFrame.Visible then
			pfCountLabel.Text = tostring(#Players:GetPlayers()) .. " ONLINE"
			local currentStaff = 0
			local currentBl = 0
			for _, p in ipairs(Players:GetPlayers()) do
				if isPlayerBlacklisted(p.UserId) then currentBl = currentBl + 1 end
				local s = checkPlayerStaff(p)
				if s then currentStaff = currentStaff + 1 end
			end

			pcall(function()
				if pfBlacklistBadge and pfBlacklistText then
					if currentBl > 0 then
						pfBlacklistBadge.BackgroundColor3 = Color3.fromRGB(50, 10, 18)
						if pfBlacklistStroke then pfBlacklistStroke.Color = Color3.fromRGB(255, 30, 50) end
						pfBlacklistText.Text = "⛔ " .. tostring(currentBl) .. " BLOCKED"
						pfBlacklistText.TextColor3 = Color3.fromRGB(255, 60, 80)
					else
						pfBlacklistBadge.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
						if pfBlacklistStroke then pfBlacklistStroke.Color = THEME.CardStroke end
						pfBlacklistText.Text = "⛔ 0 BLOCKED"
						pfBlacklistText.TextColor3 = THEME.TextDim
					end
				end

				if pfStaffBadge and pfStaffText then
					if currentStaff > 0 then
						pfStaffBadge.BackgroundColor3 = Color3.fromRGB(44, 12, 20)
						if pfStaffStroke then pfStaffStroke.Color = Color3.fromRGB(255, 50, 80) end
						pfStaffText.Text = "🚨 " .. tostring(currentStaff) .. " STAFF"
						pfStaffText.TextColor3 = Color3.fromRGB(255, 70, 100)
					else
						pfStaffBadge.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
						if pfStaffStroke then pfStaffStroke.Color = THEME.CardStroke end
						pfStaffText.Text = "🛡️ 0 STAFF"
						pfStaffText.TextColor3 = THEME.TextDim
					end
				end
			end)

			if listView.Visible then
				for _, updateFn in pairs(playerUpdateFns) do
					pcall(updateFn)
				end
			elseif detailView.Visible then
				pcall(updateRealtimeTelemetry)
			end
		end
	end)

	Players.PlayerAdded:Connect(function(p)
		if isPlayerBlacklisted(p.UserId) then
			warn(string.format("🚨 [ASTROCYNA ALERT] Blacklisted Target Detected in Server: %s (@%s) [ID: %s]", p.DisplayName, p.Name, tostring(p.UserId)))
		end
		if plrFrame.Visible then
			refreshPlayerList()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if playerRows[p] then
			pcall(function() playerRows[p]:Destroy() end)
			playerRows[p] = nil
			playerUpdateFns[p] = nil
		end
		if selectedDetailPlr == p then
			listView.Visible = true
			detailView.Visible = false
			selectedDetailPlr = nil
		end
		pfCountLabel.Text = tostring(#Players:GetPlayers()) .. " ONLINE"
	end)

	togglePlayersGui = function()
		plrFrame.Visible = not plrFrame.Visible
		if plrFrame.Visible then
			plrFrame.Position = clampPositionToScreen(plrFrame.Position, plrFrame.Size)
			listView.Visible = true
			detailView.Visible = false
			refreshPlayerList()
		end
	end

	plrFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if plrFrame.Visible then
			listView.Visible = true
			detailView.Visible = false
			refreshPlayerList()
		end
	end)

	refreshPlayerList()

	makeDraggable(plrFrame, pfTopBar)
end

	buildAuraWindow = function()

	local auraFrame = Instance.new("Frame")
	auraFrame.Name = "AstrocynaAuraWindow"
	auraFrame.Size = UDim2.new(0, 320, 0, 340)
	auraFrame.Position = UDim2.new(0, 376, 0.5, -170)
	auraFrame.BackgroundColor3 = THEME.MainBg
	auraFrame.BackgroundTransparency = THEME.MainBgTransparency
	auraFrame.BorderSizePixel = 0
	auraFrame.Visible = false
	auraFrame.ClipsDescendants = true
	auraFrame.Parent = screenGui
	applyResponsiveWindowScale(auraFrame, 320, 340, false)

	local afCorner = Instance.new("UICorner")
	afCorner.CornerRadius = UDim.new(0, 10)
	afCorner.Parent = auraFrame

	local afBevel = Instance.new("UIGradient")
	afBevel.Rotation = 90
	afBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	afBevel.Parent = auraFrame

	local afStroke = Instance.new("UIStroke")
	afStroke.Thickness = 2.0
	afStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	afStroke.Parent = auraFrame
	applyNeonSweep(afStroke, 110, 2.5, 1.8, 2.6)

	local afTopBar = Instance.new("Frame")
	afTopBar.Size = UDim2.new(1, 0, 0, 42)
	afTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	afTopBar.BorderSizePixel = 0
	afTopBar.Parent = auraFrame

	local afTopCorner = Instance.new("UICorner")
	afTopCorner.CornerRadius = UDim.new(0, 10)
	afTopCorner.Parent = afTopBar

	local afTopStroke = Instance.new("UIStroke")
	afTopStroke.Color = Color3.fromRGB(48, 48, 54)
	afTopStroke.Thickness = 1
	afTopStroke.Parent = afTopBar

	local afTitle = Instance.new("TextLabel")
	afTitle.Size = UDim2.new(1, -98, 1, 0)
	afTitle.Position = UDim2.new(0, 14, 0, 0)
	afTitle.BackgroundTransparency = 1
	afTitle.Font = Enum.Font.GothamBold
	afTitle.Text = "ASTROCYNA // AURA & VFX"
	afTitle.TextColor3 = THEME.TextCyan
	afTitle.TextSize = 12
	afTitle.TextXAlignment = Enum.TextXAlignment.Left
	afTitle.Parent = afTopBar
	applyTextShimmer(afTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	attachAlwaysOnTopButton(auraFrame, afTopBar, "AuraWindow", -66, 8, 28, 26)

	local afClose = Instance.new("TextButton")
	afClose.Size = UDim2.new(0, 28, 0, 26)
	afClose.Position = UDim2.new(1, -34, 0, 8)
	afClose.BackgroundColor3 = THEME.BtnOff
	afClose.Font = Enum.Font.GothamBold
	afClose.Text = "X"
	afClose.TextColor3 = THEME.TextCyan
	afClose.TextSize = 11
	afClose.Parent = afTopBar
	local afcCorner = Instance.new("UICorner")
	afcCorner.CornerRadius = UDim.new(0, 5)
	afcCorner.Parent = afClose
	local afcStroke = Instance.new("UIStroke")
	afcStroke.Color = THEME.BtnOffStroke
	afcStroke.Thickness = 1
	afcStroke.Parent = afClose
	hookButtonHover(afClose, THEME.BtnOff, Color3.fromRGB(44, 44, 48), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
	afClose.MouseButton1Click:Connect(function() auraFrame.Visible = false end)

	toggleAuraMenu = function()
		auraFrame.Visible = not auraFrame.Visible
		if auraFrame.Visible then
			auraFrame.Position = clampPositionToScreen(auraFrame.Position, auraFrame.Size)
			pcall(syncAuraPowerButton)
		end
	end

	local afContent = Instance.new("Frame")
	afContent.Size = UDim2.new(1, 0, 1, -44)
	afContent.Position = UDim2.new(0, 0, 0, 44)
	afContent.BackgroundTransparency = 1
	afContent.Parent = auraFrame

	local afLayout = Instance.new("UIListLayout")
	afLayout.Padding = UDim.new(0, 8)
	afLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	afLayout.Parent = afContent

	local afPad = Instance.new("UIPadding")
	afPad.PaddingTop = UDim.new(0, 8)
	afPad.PaddingBottom = UDim.new(0, 8)
	afPad.PaddingLeft = UDim.new(0, 10)
	afPad.PaddingRight = UDim.new(0, 10)
	afPad.Parent = afContent

	local cardPower = Instance.new("Frame")
	cardPower.Size = UDim2.new(1, 0, 0, 50)
	cardPower.BackgroundColor3 = THEME.CardBg
	cardPower.BorderSizePixel = 0
	cardPower.Parent = afContent
	local cpCorner = Instance.new("UICorner")
	cpCorner.CornerRadius = UDim.new(0, 8)
	cpCorner.Parent = cardPower
	local cpStroke = Instance.new("UIStroke")
	cpStroke.Color = THEME.CardStroke
	cpStroke.Thickness = 1
	cpStroke.Parent = cardPower

	local auraPowerBtn = Instance.new("TextButton")
	auraPowerBtn.Size = UDim2.new(1, -16, 0, 36)
	auraPowerBtn.Position = UDim2.new(0, 8, 0, 7)
	auraPowerBtn.Font = Enum.Font.GothamBold
	auraPowerBtn.TextSize = 11
	auraPowerBtn.BorderSizePixel = 0
	auraPowerBtn.Parent = cardPower
	local apbCorner = Instance.new("UICorner")
	apbCorner.CornerRadius = UDim.new(0, 6)
	apbCorner.Parent = auraPowerBtn
	local apbStroke = Instance.new("UIStroke")
	apbStroke.Thickness = 1
	apbStroke.Parent = auraPowerBtn

	syncAuraPowerButton = function()
		if not auraPowerBtn or not auraPowerBtn.Parent then return end
		if isAuraEnabled then
			auraPowerBtn.Text = "✨ AURA SYSTEM: [ACTIVE]"
			auraPowerBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			auraPowerBtn.TextColor3 = THEME.BtnActiveText
			apbStroke.Color = THEME.BorderHighlight
		else
			auraPowerBtn.Text = "✨ AURA SYSTEM: [OFF / STANDBY]"
			auraPowerBtn.BackgroundColor3 = THEME.BtnOff
			auraPowerBtn.TextColor3 = THEME.BtnOffText
			apbStroke.Color = THEME.BtnOffStroke
		end
	end
	syncAuraPowerButton()

	auraPowerBtn.MouseButton1Click:Connect(function()
		toggleAura()
	end)

	local cardColor = Instance.new("Frame")
	cardColor.Size = UDim2.new(1, 0, 0, 56)
	cardColor.BackgroundColor3 = THEME.CardBg
	cardColor.BorderSizePixel = 0
	cardColor.Parent = afContent
	local ccCorner = Instance.new("UICorner")
	ccCorner.CornerRadius = UDim.new(0, 8)
	ccCorner.Parent = cardColor
	local ccStroke = Instance.new("UIStroke")
	ccStroke.Color = THEME.CardStroke
	ccStroke.Thickness = 1
	ccStroke.Parent = cardColor

	local acSwatch = Instance.new("Frame")
	acSwatch.Size = UDim2.new(0, 38, 0, 38)
	acSwatch.Position = UDim2.new(0, 8, 0, 9)
	acSwatch.BackgroundColor3 = auraColor
	acSwatch.BorderSizePixel = 0
	acSwatch.Parent = cardColor
	local acsCorner = Instance.new("UICorner")
	acsCorner.CornerRadius = UDim.new(0, 6)
	acsCorner.Parent = acSwatch
	local acsStroke = Instance.new("UIStroke")
	acsStroke.Color = THEME.BorderBeam
	acsStroke.Thickness = 1.5
	acsStroke.Parent = acSwatch

	local acInput = Instance.new("TextBox")
	acInput.Size = UDim2.new(1, -136, 0, 36)
	acInput.Position = UDim2.new(0, 54, 0, 10)
	acInput.PlaceholderText = "#00D7FF or 0,215,255"
	acInput.PlaceholderColor3 = THEME.TextDim
	acInput.Text = ""
	acInput.Font = Enum.Font.Gotham
	acInput.TextSize = 10
	acInput.TextColor3 = THEME.TextFrost
	acInput.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
	acInput.BorderSizePixel = 0
	acInput.ClearTextOnFocus = false
	acInput.Parent = cardColor
	local aciCorner = Instance.new("UICorner")
	aciCorner.CornerRadius = UDim.new(0, 6)
	aciCorner.Parent = acInput
	local aciStroke = Instance.new("UIStroke")
	aciStroke.Color = THEME.CardStroke
	aciStroke.Thickness = 1
	aciStroke.Parent = acInput

	local acApply = Instance.new("TextButton")
	acApply.Size = UDim2.new(0, 68, 0, 36)
	acApply.Position = UDim2.new(1, -76, 0, 10)
	acApply.Text = "APPLY"
	acApply.Font = Enum.Font.GothamBold
	acApply.TextSize = 10
	acApply.TextColor3 = Color3.fromRGB(20, 20, 24)
	acApply.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	acApply.BorderSizePixel = 0
	acApply.Parent = cardColor
	local acaCorner = Instance.new("UICorner")
	acaCorner.CornerRadius = UDim.new(0, 6)
	acaCorner.Parent = acApply
	hookButtonHover(acApply, Color3.fromRGB(235, 235, 240), Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 24), Color3.fromRGB(10, 10, 12))

	local function applyAuraColorInput()
		local txt = acInput.Text
		local newCol = nil
		if txt:match("^#") or #txt == 6 then
			txt = txt:gsub("#", "")
			if #txt == 6 then
				local r = tonumber(txt:sub(1, 2), 16)
				local g = tonumber(txt:sub(3, 4), 16)
				local b = tonumber(txt:sub(5, 6), 16)
				if r and g and b then newCol = Color3.fromRGB(r, g, b) end
			end
		else
			local r, g, b = txt:match("(%d+)[,%s]+(%d+)[,%s]+(%d+)")
			if r and g and b then newCol = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
		end
		if newCol then
			changeAuraColor(newCol)
			acSwatch.BackgroundColor3 = newCol
			acsStroke.Color = newCol
			acInput.Text = ""
			acInput.PlaceholderText = "Applied!"
		else
			acInput.Text = ""
			acInput.PlaceholderText = "❌ Invalid format"
		end
	end
	acApply.MouseButton1Click:Connect(applyAuraColorInput)
	acInput.FocusLost:Connect(function(enter) if enter then applyAuraColorInput() end end)

	local cardPalette = Instance.new("Frame")
	cardPalette.Size = UDim2.new(1, 0, 0, 78)
	cardPalette.BackgroundColor3 = THEME.CardBg
	cardPalette.BorderSizePixel = 0
	cardPalette.Parent = afContent
	local cpPalCorner = Instance.new("UICorner")
	cpPalCorner.CornerRadius = UDim.new(0, 8)
	cpPalCorner.Parent = cardPalette
	local cpPalStroke = Instance.new("UIStroke")
	cpPalStroke.Color = THEME.CardStroke
	cpPalStroke.Thickness = 1
	cpPalStroke.Parent = cardPalette

	local acPaletteLabel = Instance.new("TextLabel")
	acPaletteLabel.Text = "QUICK COLOR PALETTE"
	acPaletteLabel.Font = Enum.Font.GothamBold
	acPaletteLabel.TextSize = 10
	acPaletteLabel.TextColor3 = THEME.TextCyan
	acPaletteLabel.Size = UDim2.new(1, -16, 0, 18)
	acPaletteLabel.Position = UDim2.new(0, 8, 0, 8)
	acPaletteLabel.BackgroundTransparency = 1
	acPaletteLabel.TextXAlignment = Enum.TextXAlignment.Left
	acPaletteLabel.Parent = cardPalette

	local acPaletteRow = Instance.new("Frame")
	acPaletteRow.Size = UDim2.new(1, -16, 0, 34)
	acPaletteRow.Position = UDim2.new(0, 8, 0, 32)
	acPaletteRow.BackgroundTransparency = 1
	acPaletteRow.Parent = cardPalette

	local acPresets = {
		{ name = "Pure White", color = Color3.fromRGB(255, 255, 255) },
		{ name = "Frost Silver", color = Color3.fromRGB(225, 225, 230) },
		{ name = "Platinum Chrome", color = Color3.fromRGB(190, 190, 195) },
		{ name = "Metallic Silver", color = Color3.fromRGB(150, 150, 155) },
		{ name = "Graphite Slate", color = Color3.fromRGB(100, 100, 105) },
		{ name = "Obsidian Carbon", color = Color3.fromRGB(50, 50, 55) },
		{ name = "Jet Black", color = Color3.fromRGB(18, 18, 20) },
	}

	local acBtnWidth = (1 / #acPresets)
	for i, pr in ipairs(acPresets) do
		local pBtn = Instance.new("TextButton")
		pBtn.Size = UDim2.new(acBtnWidth, -4, 1, 0)
		pBtn.Position = UDim2.new((i - 1) * acBtnWidth, 2, 0, 0)
		pBtn.BackgroundColor3 = pr.color
		pBtn.Text = ""
		pBtn.BorderSizePixel = 0
		pBtn.Parent = acPaletteRow
		local prCorner = Instance.new("UICorner")
		prCorner.CornerRadius = UDim.new(0, 6)
		prCorner.Parent = pBtn
		local prStroke = Instance.new("UIStroke")
		prStroke.Color = Color3.fromRGB(255, 255, 255)
		prStroke.Transparency = 0.6
		prStroke.Thickness = 1
		prStroke.Parent = pBtn

		pBtn.MouseButton1Click:Connect(function()
			changeAuraColor(pr.color)
			acSwatch.BackgroundColor3 = pr.color
			acsStroke.Color = pr.color
			acInput.PlaceholderText = pr.name .. " selected!"
		end)
	end

	local acFooter = Instance.new("TextLabel")
	acFooter.Text = "ASTROCYNA CYBER TECH // 9-LAYER AURA VFX"
	acFooter.Font = Enum.Font.Gotham
	acFooter.TextSize = 8
	acFooter.TextColor3 = Color3.fromRGB(70, 105, 135)
	acFooter.Size = UDim2.new(1, 0, 0, 16)
	acFooter.BackgroundTransparency = 1
	acFooter.TextXAlignment = Enum.TextXAlignment.Center
	acFooter.Parent = afContent

	makeDraggable(auraFrame, afTopBar)
end

WIN_BUILDERS.buildBoombox = function()

	local boomboxFrame = Instance.new("Frame")
	boomboxFrame.Name = "AstrocynaBoomboxWindow"
	boomboxFrame.Size = UDim2.new(0, 350, 0, 520)
	boomboxFrame.Position = UDim2.new(0, 376, 0.5, -260)
	boomboxFrame.BackgroundColor3 = THEME.MainBg
	boomboxFrame.BackgroundTransparency = THEME.MainBgTransparency
	boomboxFrame.BorderSizePixel = 0
	boomboxFrame.Visible = false
	boomboxFrame.ClipsDescendants = true
	boomboxFrame.Parent = screenGui
	applyResponsiveWindowScale(boomboxFrame, 350, 520, false)

	local bfCorner = Instance.new("UICorner")
	bfCorner.CornerRadius = UDim.new(0, 10)
	bfCorner.Parent = boomboxFrame

	local bfBevel = Instance.new("UIGradient")
	bfBevel.Rotation = 90
	bfBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	bfBevel.Parent = boomboxFrame

	local bfStroke = Instance.new("UIStroke")
	bfStroke.Thickness = 2.0
	bfStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bfStroke.Parent = boomboxFrame
	applyNeonSweep(bfStroke, 110, 2.5, 1.8, 2.6)

	local bfTopBar = Instance.new("Frame")
	bfTopBar.Size = UDim2.new(1, 0, 0, 42)
	bfTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	bfTopBar.BorderSizePixel = 0
	bfTopBar.Parent = boomboxFrame

	local bfTopCorner = Instance.new("UICorner")
	bfTopCorner.CornerRadius = UDim.new(0, 10)
	bfTopCorner.Parent = bfTopBar

	local bfTopStroke = Instance.new("UIStroke")
	bfTopStroke.Color = Color3.fromRGB(48, 48, 54)
	bfTopStroke.Thickness = 1
	bfTopStroke.Parent = bfTopBar

	local bfTitle = Instance.new("TextLabel")
	bfTitle.Size = UDim2.new(1, -60, 1, 0)
	bfTitle.Position = UDim2.new(0, 14, 0, 0)
	bfTitle.BackgroundTransparency = 1
	bfTitle.Font = Enum.Font.GothamBold
	bfTitle.Text = "ASTROCYNA // BOOMBOX"
	bfTitle.TextColor3 = THEME.TextCyan
	bfTitle.TextSize = 12
	bfTitle.TextXAlignment = Enum.TextXAlignment.Left
	bfTitle.Parent = bfTopBar
	applyTextShimmer(bfTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local bfClose = Instance.new("TextButton")
	bfClose.Size = UDim2.new(0, 28, 0, 26)
	bfClose.Position = UDim2.new(1, -34, 0, 8)
	bfClose.BackgroundColor3 = THEME.BtnOff
	bfClose.Font = Enum.Font.GothamBold
	bfClose.Text = "X"
	bfClose.TextColor3 = THEME.TextCyan
	bfClose.TextSize = 11
	bfClose.Parent = bfTopBar
	local bfcCorner = Instance.new("UICorner")
	bfcCorner.CornerRadius = UDim.new(0, 5)
	bfcCorner.Parent = bfClose
	local bfcStroke = Instance.new("UIStroke")
	bfcStroke.Color = THEME.BtnOffStroke
	bfcStroke.Thickness = 1
	bfcStroke.Parent = bfClose
	hookButtonHover(bfClose, THEME.BtnOff, Color3.fromRGB(44, 44, 48), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
	bfClose.MouseButton1Click:Connect(function() boomboxFrame.Visible = false end)

	toggleBoomboxGui = function()
		boomboxFrame.Visible = not boomboxFrame.Visible
		if boomboxFrame.Visible then
			boomboxFrame.Position = clampPositionToScreen(boomboxFrame.Position, boomboxFrame.Size)
		end
	end

	local bfContent = Instance.new("ScrollingFrame")
	bfContent.Size = UDim2.new(1, 0, 1, -44)
	bfContent.Position = UDim2.new(0, 0, 0, 44)
	bfContent.BackgroundTransparency = 1
	bfContent.BorderSizePixel = 0
	bfContent.ScrollBarThickness = 4
	bfContent.ScrollBarImageColor3 = THEME.BorderBeam
	bfContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bfContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	bfContent.Parent = boomboxFrame

	local bfLayout = Instance.new("UIListLayout")
	bfLayout.Padding = UDim.new(0, 8)
	bfLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bfLayout.Parent = bfContent

	local bfPad = Instance.new("UIPadding")
	bfPad.PaddingTop = UDim.new(0, 8)
	bfPad.PaddingBottom = UDim.new(0, 12)
	bfPad.PaddingLeft = UDim.new(0, 10)
	bfPad.PaddingRight = UDim.new(0, 10)
	bfPad.Parent = bfContent

	local cardSource = Instance.new("Frame")
	cardSource.Size = UDim2.new(1, 0, 0, 140)
	cardSource.BackgroundColor3 = THEME.CardBg
	cardSource.BorderSizePixel = 0
	cardSource.Parent = bfContent
	local csCorner = Instance.new("UICorner")
	csCorner.CornerRadius = UDim.new(0, 8)
	csCorner.Parent = cardSource
	local csStroke = Instance.new("UIStroke")
	csStroke.Color = THEME.CardStroke
	csStroke.Thickness = 1
	csStroke.Parent = cardSource

	local csHeader = Instance.new("TextLabel")
	csHeader.Size = UDim2.new(1, -16, 0, 18)
	csHeader.Position = UDim2.new(0, 8, 0, 8)
	csHeader.BackgroundTransparency = 1
	csHeader.Font = Enum.Font.GothamBold
	csHeader.Text = "🎶 AUDIO SOURCE (ROBLOX ID / YOUTUBE URL)"
	csHeader.TextColor3 = THEME.TextCyan
	csHeader.TextSize = 10
	csHeader.TextXAlignment = Enum.TextXAlignment.Left
	csHeader.Parent = cardSource

	local bfMusicInput = Instance.new("TextBox")
	bfMusicInput.Size = UDim2.new(1, -16, 0, 32)
	bfMusicInput.Position = UDim2.new(0, 8, 0, 30)
	bfMusicInput.PlaceholderText = "Paste Roblox ID or YouTube URL here..."
	bfMusicInput.PlaceholderColor3 = THEME.TextDim
	bfMusicInput.Text = ""
	bfMusicInput.Font = Enum.Font.Gotham
	bfMusicInput.TextSize = 11
	bfMusicInput.TextColor3 = THEME.TextFrost
	bfMusicInput.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
	bfMusicInput.BorderSizePixel = 0
	bfMusicInput.ClearTextOnFocus = false
	bfMusicInput.Parent = cardSource
	local bfmiCorner = Instance.new("UICorner")
	bfmiCorner.CornerRadius = UDim.new(0, 6)
	bfmiCorner.Parent = bfMusicInput
	local bfmiStroke = Instance.new("UIStroke")
	bfmiStroke.Color = THEME.CardStroke
	bfmiStroke.Thickness = 1
	bfmiStroke.Parent = bfMusicInput

	local bfPlayBtn = Instance.new("TextButton")
	bfPlayBtn.Size = UDim2.new(1, -16, 0, 34)
	bfPlayBtn.Position = UDim2.new(0, 8, 0, 68)
	bfPlayBtn.Text = "▶ PLAY MUSIC"
	bfPlayBtn.Font = Enum.Font.GothamBold
	bfPlayBtn.TextSize = 12
	bfPlayBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
	bfPlayBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
	bfPlayBtn.BorderSizePixel = 0
	bfPlayBtn.Parent = cardSource
	local bfpbCorner = Instance.new("UICorner")
	bfpbCorner.CornerRadius = UDim.new(0, 6)
	bfpbCorner.Parent = bfPlayBtn
	local bfpbStroke = Instance.new("UIStroke")
	bfpbStroke.Color = THEME.BorderBeam
	bfpbStroke.Thickness = 1
	bfpbStroke.Parent = bfPlayBtn
	applyNeonSweep(bfpbStroke, 90, 3, 0.8, 1.6)
	hookButtonHover(bfPlayBtn, Color3.fromRGB(235, 235, 240), Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 24), Color3.fromRGB(10, 10, 12))

	local bfStatusLabel = Instance.new("TextLabel")
	bfStatusLabel.Size = UDim2.new(1, -16, 0, 22)
	bfStatusLabel.Position = UDim2.new(0, 8, 0, 108)
	bfStatusLabel.Text = "Status: Idle (Roblox Sound ID or YouTube Link)"
	bfStatusLabel.Font = Enum.Font.Gotham
	bfStatusLabel.TextSize = 9
	bfStatusLabel.TextColor3 = THEME.TextDim
	bfStatusLabel.BackgroundTransparency = 1
	bfStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bfStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	bfStatusLabel.Parent = cardSource

	bfPlayBtn.MouseButton1Click:Connect(function()
		local inputText = bfMusicInput.Text
		if boomboxCurrentSound or boomboxIsLoading then
			boomboxIsLoading = false
			boomboxStop()
			bfStatusLabel.Text = "Status: Stopped"
			bfStatusLabel.TextColor3 = THEME.TextDim
			bfPlayBtn.Text = "▶ PLAY MUSIC"
			bfPlayBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
			bfPlayBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
		else
			bfPlayBtn.Text = "⏳ LOADING..."
			bfPlayBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
			bfPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			bfStatusLabel.Text = "Status: Initializing..."
			bfStatusLabel.TextColor3 = THEME.TextDim

			task.spawn(function()
				local ok = boomboxPlay(inputText, function(msg, isSuccess, isWarn)
					bfStatusLabel.Text = msg
					if isSuccess and not isWarn then
						bfStatusLabel.TextColor3 = THEME.ActiveFly
					elseif isWarn then
						bfStatusLabel.TextColor3 = Color3.fromRGB(255, 190, 60)
					else
						bfStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
					end
				end)

				if ok then
					bfPlayBtn.Text = "■ STOP MUSIC"
					bfPlayBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					bfPlayBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
				else
					bfPlayBtn.Text = "▶ PLAY MUSIC"
					bfPlayBtn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
					bfPlayBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
				end
			end)
		end
	end)

	do
		local VOL_MAX = 5
		local VOL_STEP = 0.05
		local lastNonMuteVolume = 1

		local cardVolume = Instance.new("Frame")
		cardVolume.Size = UDim2.new(1, 0, 0, 94)
		cardVolume.BackgroundColor3 = THEME.CardBg
		cardVolume.BorderSizePixel = 0
		cardVolume.Parent = bfContent
		local cvCorner = Instance.new("UICorner")
		cvCorner.CornerRadius = UDim.new(0, 8)
		cvCorner.Parent = cardVolume
		local cvStroke = Instance.new("UIStroke")
		cvStroke.Color = THEME.CardStroke
		cvStroke.Thickness = 1
		cvStroke.Parent = cardVolume

		local cvHeader = Instance.new("TextLabel")
		cvHeader.Size = UDim2.new(0.6, -8, 0, 18)
		cvHeader.Position = UDim2.new(0, 8, 0, 8)
		cvHeader.BackgroundTransparency = 1
		cvHeader.Font = Enum.Font.GothamBold
		cvHeader.Text = "🔊 VOLUME"
		cvHeader.TextColor3 = THEME.TextCyan
		cvHeader.TextSize = 10
		cvHeader.TextXAlignment = Enum.TextXAlignment.Left
		cvHeader.Parent = cardVolume

		local cvValue = Instance.new("TextLabel")
		cvValue.Size = UDim2.new(0.4, -8, 0, 18)
		cvValue.Position = UDim2.new(0.6, 0, 0, 8)
		cvValue.BackgroundTransparency = 1
		cvValue.Font = Enum.Font.GothamBold
		cvValue.Text = "100%"
		cvValue.TextColor3 = THEME.TextFrost
		cvValue.TextSize = 11
		cvValue.TextXAlignment = Enum.TextXAlignment.Right
		cvValue.Parent = cardVolume

		local cvTrack = Instance.new("Frame")
		cvTrack.Size = UDim2.new(1, -24, 0, 8)
		cvTrack.Position = UDim2.new(0, 12, 0, 40)
		cvTrack.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
		cvTrack.BorderSizePixel = 0
		cvTrack.Parent = cardVolume
		local cvtCorner = Instance.new("UICorner")
		cvtCorner.CornerRadius = UDim.new(1, 0)
		cvtCorner.Parent = cvTrack
		local cvtStroke = Instance.new("UIStroke")
		cvtStroke.Color = THEME.CardStroke
		cvtStroke.Thickness = 1
		cvtStroke.Parent = cvTrack

		local cvFill = Instance.new("Frame")
		cvFill.Size = UDim2.new(0.2, 0, 1, 0)
		cvFill.BackgroundColor3 = THEME.BorderBeam
		cvFill.BorderSizePixel = 0
		cvFill.Parent = cvTrack
		local cvfCorner = Instance.new("UICorner")
		cvfCorner.CornerRadius = UDim.new(1, 0)
		cvfCorner.Parent = cvFill

		local cvKnob = Instance.new("Frame")
		cvKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		cvKnob.Size = UDim2.new(0, 16, 0, 16)
		cvKnob.Position = UDim2.new(0.2, 0, 0.5, 0)
		cvKnob.BackgroundColor3 = Color3.fromRGB(235, 250, 255)
		cvKnob.BorderSizePixel = 0
		cvKnob.ZIndex = 3
		cvKnob.Parent = cvTrack
		local cvkCorner = Instance.new("UICorner")
		cvkCorner.CornerRadius = UDim.new(1, 0)
		cvkCorner.Parent = cvKnob
		local cvkStroke = Instance.new("UIStroke")
		cvkStroke.Color = THEME.BorderBeam
		cvkStroke.Thickness = 1.5
		cvkStroke.Parent = cvKnob

		local cvHit = Instance.new("TextButton")
		cvHit.AnchorPoint = Vector2.new(0, 0.5)
		cvHit.Size = UDim2.new(1, 0, 0, 28)
		cvHit.Position = UDim2.new(0, 0, 0.5, 0)
		cvHit.BackgroundTransparency = 1
		cvHit.Text = ""
		cvHit.AutoButtonColor = false
		cvHit.ZIndex = 4
		cvHit.Parent = cvTrack

		local function setBoomboxVolume(v)
			v = math.clamp(math.floor((tonumber(v) or 1) / VOL_STEP + 0.5) * VOL_STEP, 0, VOL_MAX)
			BOOMBOX_YT_CONFIG.Volume = v
			if v > 0 then
				lastNonMuteVolume = v
			end
			local frac = v / VOL_MAX
			cvFill.Size = UDim2.new(frac, 0, 1, 0)
			cvKnob.Position = UDim2.new(frac, 0, 0.5, 0)
			cvValue.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
			if v > 1 then
				cvValue.TextColor3 = Color3.fromRGB(255, 190, 60)
			elseif v == 0 then
				cvValue.TextColor3 = Color3.fromRGB(255, 90, 90)
			else
				cvValue.TextColor3 = THEME.TextFrost
			end
			if boomboxCurrentSound and boomboxCurrentSound.Parent then
				boomboxCurrentSound.Volume = v
			end
		end

		local volDragging = false
		local function setFromInputX(x)
			local w = cvTrack.AbsoluteSize.X
			if w <= 0 then return end
			local frac = math.clamp((x - cvTrack.AbsolutePosition.X) / w, 0, 1)
			setBoomboxVolume(frac * VOL_MAX)
		end

		cvHit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				volDragging = true
				setFromInputX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if volDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromInputX(input.Position.X)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				volDragging = false
			end
		end)

		local cvBtnRow = Instance.new("Frame")
		cvBtnRow.Size = UDim2.new(1, -16, 0, 26)
		cvBtnRow.Position = UDim2.new(0, 8, 0, 58)
		cvBtnRow.BackgroundTransparency = 1
		cvBtnRow.Parent = cardVolume
		local cvRowLayout = Instance.new("UIListLayout")
		cvRowLayout.FillDirection = Enum.FillDirection.Horizontal
		cvRowLayout.Padding = UDim.new(0, 6)
		cvRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cvRowLayout.Parent = cvBtnRow

		local function makeVolBtn(text, order, onClick)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0.25, -5, 1, 0)
			b.LayoutOrder = order
			b.BackgroundColor3 = THEME.BtnOff
			b.Font = Enum.Font.GothamBold
			b.Text = text
			b.TextColor3 = THEME.TextFrost
			b.TextSize = 10
			b.BorderSizePixel = 0
			b.Parent = cvBtnRow
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 5)
			bc.Parent = b
			local bs = Instance.new("UIStroke")
			bs.Color = THEME.BtnOffStroke
			bs.Thickness = 1
			bs.Parent = b
			hookButtonHover(b, THEME.BtnOff, Color3.fromRGB(40, 40, 46), THEME.TextFrost, Color3.new(1, 1, 1))
			b.MouseButton1Click:Connect(onClick)
			return b
		end

		makeVolBtn("➖ -10%", 1, function()
			setBoomboxVolume((BOOMBOX_YT_CONFIG.Volume or 1) - 0.1)
		end)
		makeVolBtn("➕ +10%", 2, function()
			setBoomboxVolume((BOOMBOX_YT_CONFIG.Volume or 1) + 0.1)
		end)
		makeVolBtn("🔇 MUTE", 3, function()
			if (BOOMBOX_YT_CONFIG.Volume or 1) > 0 then
				setBoomboxVolume(0)
			else
				setBoomboxVolume(lastNonMuteVolume > 0 and lastNonMuteVolume or 1)
			end
		end)
		makeVolBtn("100%", 4, function()
			setBoomboxVolume(1)
		end)

		setBoomboxVolume(BOOMBOX_YT_CONFIG.Volume or 1)
	end

	local cardColor = Instance.new("Frame")
	cardColor.Size = UDim2.new(1, 0, 0, 128)
	cardColor.BackgroundColor3 = THEME.CardBg
	cardColor.BorderSizePixel = 0
	cardColor.Parent = bfContent
	local ccCorner = Instance.new("UICorner")
	ccCorner.CornerRadius = UDim.new(0, 8)
	ccCorner.Parent = cardColor
	local ccStroke = Instance.new("UIStroke")
	ccStroke.Color = THEME.CardStroke
	ccStroke.Thickness = 1
	ccStroke.Parent = cardColor

	local ccHeader = Instance.new("TextLabel")
	ccHeader.Size = UDim2.new(1, -16, 0, 18)
	ccHeader.Position = UDim2.new(0, 8, 0, 8)
	ccHeader.BackgroundTransparency = 1
	ccHeader.Font = Enum.Font.GothamBold
	ccHeader.Text = "🎨 BEAT-REACTIVE BOOMBOX COLOR"
	ccHeader.TextColor3 = THEME.TextCyan
	ccHeader.TextSize = 10
	ccHeader.TextXAlignment = Enum.TextXAlignment.Left
	ccHeader.Parent = cardColor

	local bfSwatch = Instance.new("Frame")
	bfSwatch.Size = UDim2.new(0, 36, 0, 36)
	bfSwatch.Position = UDim2.new(0, 8, 0, 30)
	bfSwatch.BackgroundColor3 = boomboxSelectedColor
	bfSwatch.BorderSizePixel = 0
	bfSwatch.Parent = cardColor
	local bfsCorner = Instance.new("UICorner")
	bfsCorner.CornerRadius = UDim.new(0, 6)
	bfsCorner.Parent = bfSwatch
	local bfsStroke = Instance.new("UIStroke")
	bfsStroke.Color = THEME.BorderBeam
	bfsStroke.Thickness = 1.5
	bfsStroke.Parent = bfSwatch

	local bfColorPicker = Instance.new("ImageButton")
	bfColorPicker.Size = UDim2.new(1, -54, 0, 16)
	bfColorPicker.Position = UDim2.new(0, 50, 0, 30)
	bfColorPicker.Image = "rbxassetid://6020299384"
	bfColorPicker.ScaleType = Enum.ScaleType.Stretch
	bfColorPicker.BackgroundColor3 = Color3.fromRGB(20, 30, 46)
	bfColorPicker.BorderSizePixel = 0
	bfColorPicker.Parent = cardColor
	local bfcpCorner = Instance.new("UICorner")
	bfcpCorner.CornerRadius = UDim.new(0, 4)
	bfcpCorner.Parent = bfColorPicker

	local bfColorInput = Instance.new("TextBox")
	bfColorInput.Size = UDim2.new(1, -54, 0, 18)
	bfColorInput.Position = UDim2.new(0, 50, 0, 49)
	bfColorInput.PlaceholderText = "#00D7FF or 0,215,255"
	bfColorInput.PlaceholderColor3 = THEME.TextDim
	bfColorInput.Text = ""
	bfColorInput.Font = Enum.Font.Gotham
	bfColorInput.TextSize = 10
	bfColorInput.TextColor3 = THEME.TextFrost
	bfColorInput.BackgroundColor3 = Color3.fromRGB(11, 18, 28)
	bfColorInput.BorderSizePixel = 0
	bfColorInput.ClearTextOnFocus = false
	bfColorInput.Parent = cardColor
	local bfciCorner = Instance.new("UICorner")
	bfciCorner.CornerRadius = UDim.new(0, 4)
	bfciCorner.Parent = bfColorInput
	local bfciStroke = Instance.new("UIStroke")
	bfciStroke.Color = THEME.CardStroke
	bfciStroke.Thickness = 1
	bfciStroke.Parent = bfColorInput

	bfColorPicker.MouseButton1Down:Connect(function(x)
		local relativeX = x - bfColorPicker.AbsolutePosition.X
		local percent = math.clamp(relativeX / bfColorPicker.AbsoluteSize.X, 0, 1)
		boomboxSelectedColor = Color3.fromHSV(percent, 1, 1)
		bfSwatch.BackgroundColor3 = boomboxSelectedColor
		bfsStroke.Color = boomboxSelectedColor
	end)

	bfColorInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local color = boomboxParseColor(bfColorInput.Text)
			if color then
				boomboxSelectedColor = color
				bfSwatch.BackgroundColor3 = color
				bfsStroke.Color = color
				bfColorInput.Text = ""
				bfColorInput.PlaceholderText = "Color applied!"
			else
				bfColorInput.Text = ""
				bfColorInput.PlaceholderText = "❌ Invalid format"
			end
		end
	end)

	local bfPaletteRow = Instance.new("Frame")
	bfPaletteRow.Size = UDim2.new(1, -16, 0, 30)
	bfPaletteRow.Position = UDim2.new(0, 8, 0, 82)
	bfPaletteRow.BackgroundTransparency = 1
	bfPaletteRow.Parent = cardColor

	local bfPresets = {
		{ name = "Cyan", color = Color3.fromRGB(0, 215, 255) },
		{ name = "Violet", color = Color3.fromRGB(209, 116, 255) },
		{ name = "Red", color = Color3.fromRGB(255, 46, 99) },
		{ name = "Gold", color = Color3.fromRGB(255, 210, 80) },
		{ name = "Lime", color = Color3.fromRGB(0, 240, 140) },
		{ name = "Frost", color = Color3.fromRGB(220, 250, 255) },
		{ name = "Navy", color = Color3.fromRGB(10, 45, 80) },
	}

	local bfBtnWidth = (1 / #bfPresets)
	for i, pr in ipairs(bfPresets) do
		local pBtn = Instance.new("TextButton")
		pBtn.Size = UDim2.new(bfBtnWidth, -4, 1, 0)
		pBtn.Position = UDim2.new((i - 1) * bfBtnWidth, 2, 0, 0)
		pBtn.BackgroundColor3 = pr.color
		pBtn.Text = ""
		pBtn.BorderSizePixel = 0
		pBtn.Parent = bfPaletteRow
		local prCorner = Instance.new("UICorner")
		prCorner.CornerRadius = UDim.new(0, 6)
		prCorner.Parent = pBtn
		local prStroke = Instance.new("UIStroke")
		prStroke.Color = Color3.fromRGB(255, 255, 255)
		prStroke.Transparency = 0.6
		prStroke.Thickness = 1
		prStroke.Parent = pBtn
		pBtn.MouseButton1Click:Connect(function()
			boomboxSelectedColor = pr.color
			bfSwatch.BackgroundColor3 = pr.color
			bfsStroke.Color = pr.color
			bfColorInput.PlaceholderText = pr.name .. " selected!"
		end)
	end

	local cardSettings = Instance.new("Frame")
	cardSettings.Size = UDim2.new(1, 0, 0, 146)
	cardSettings.BackgroundColor3 = THEME.CardBg
	cardSettings.BorderSizePixel = 0
	cardSettings.Parent = bfContent
	local csetCorner = Instance.new("UICorner")
	csetCorner.CornerRadius = UDim.new(0, 8)
	csetCorner.Parent = cardSettings
	local csetStroke = Instance.new("UIStroke")
	csetStroke.Color = THEME.CardStroke
	csetStroke.Thickness = 1
	csetStroke.Parent = cardSettings

	local csetHeader = Instance.new("TextLabel")
	csetHeader.Size = UDim2.new(1, -16, 0, 18)
	csetHeader.Position = UDim2.new(0, 8, 0, 8)
	csetHeader.BackgroundTransparency = 1
	csetHeader.Font = Enum.Font.GothamBold
	csetHeader.Text = "⚙️ 3D MODEL & ENVIRONMENTAL VFX"
	csetHeader.TextColor3 = THEME.TextCyan
	csetHeader.TextSize = 10
	csetHeader.TextXAlignment = Enum.TextXAlignment.Left
	csetHeader.Parent = cardSettings

	local bfModeBtn = Instance.new("TextButton")
	bfModeBtn.Size = UDim2.new(1, -16, 0, 32)
	bfModeBtn.Position = UDim2.new(0, 8, 0, 30)
	bfModeBtn.Text = "📦 Mode: Back (Attached to Character)"
	bfModeBtn.Font = Enum.Font.GothamBold
	bfModeBtn.TextSize = 11
	bfModeBtn.TextColor3 = THEME.TextFrost
	bfModeBtn.BackgroundColor3 = THEME.BtnOff
	bfModeBtn.BorderSizePixel = 0
	bfModeBtn.Parent = cardSettings
	local bfmbCorner = Instance.new("UICorner")
	bfmbCorner.CornerRadius = UDim.new(0, 6)
	bfmbCorner.Parent = bfModeBtn
	local bfmbStroke = Instance.new("UIStroke")
	bfmbStroke.Color = THEME.BtnOffStroke
	bfmbStroke.Thickness = 1
	bfmbStroke.Parent = bfModeBtn
	hookButtonHover(bfModeBtn, THEME.BtnOff, Color3.fromRGB(40, 40, 46), THEME.TextFrost, Color3.new(1,1,1))

	local lastModeTap = 0
	local function toggleBoomboxMode()
		local now = tick()
		if now - lastModeTap < 0.12 then return end
		lastModeTap = now
		if boomboxMode == "orbit" then
			boomboxMode = "back"
			bfModeBtn.Text = "📦 Mode: Back (Attached to Character)"
		else
			boomboxMode = "orbit"
			bfModeBtn.Text = "🔄 Mode: Orbit (Floating 3D)"
		end
	end
	bfModeBtn.MouseButton1Click:Connect(toggleBoomboxMode)
	if bfModeBtn.Activated then
		bfModeBtn.Activated:Connect(toggleBoomboxMode)
	end

	local bfThemeBtn = Instance.new("TextButton")
	bfThemeBtn.Size = UDim2.new(1, -16, 0, 32)
	bfThemeBtn.Position = UDim2.new(0, 8, 0, 68)
	bfThemeBtn.Text = "☀️ Sky Theme: Default Game Sky"
	bfThemeBtn.Font = Enum.Font.GothamBold
	bfThemeBtn.TextSize = 11
	bfThemeBtn.TextColor3 = THEME.TextFrost
	bfThemeBtn.BackgroundColor3 = THEME.BtnOff
	bfThemeBtn.BorderSizePixel = 0
	bfThemeBtn.Parent = cardSettings
	local bftbCorner = Instance.new("UICorner")
	bftbCorner.CornerRadius = UDim.new(0, 6)
	bftbCorner.Parent = bfThemeBtn
	local bftbStroke = Instance.new("UIStroke")
	bftbStroke.Color = THEME.BtnOffStroke
	bftbStroke.Thickness = 1
	bftbStroke.Parent = bfThemeBtn
	hookButtonHover(bfThemeBtn, THEME.BtnOff, Color3.fromRGB(40, 40, 46), THEME.TextFrost, Color3.new(1,1,1))

	local lastThemeTap = 0
	local function toggleBoomboxTheme()
		local now = tick()
		if now - lastThemeTap < 0.12 then return end
		lastThemeTap = now
		boomboxUseBoomboxTheme = not boomboxUseBoomboxTheme
		if boomboxUseBoomboxTheme then
			bfThemeBtn.Text = "🌌 Sky Theme: Boombox Cosmic"
		else
			bfThemeBtn.Text = "☀️ Sky Theme: Default Game Sky"
		end
	end
	bfThemeBtn.MouseButton1Click:Connect(toggleBoomboxTheme)
	if bfThemeBtn.Activated then
		bfThemeBtn.Activated:Connect(toggleBoomboxTheme)
	end

	local bfSmokeBtn = Instance.new("TextButton")
	bfSmokeBtn.Size = UDim2.new(1, -16, 0, 32)
	bfSmokeBtn.Position = UDim2.new(0, 8, 0, 106)
	bfSmokeBtn.Text = "💨 Smoke Particles: OFF"
	bfSmokeBtn.Font = Enum.Font.GothamBold
	bfSmokeBtn.TextSize = 11
	bfSmokeBtn.TextColor3 = THEME.TextFrost
	bfSmokeBtn.BackgroundColor3 = THEME.BtnOff
	bfSmokeBtn.BorderSizePixel = 0
	bfSmokeBtn.Parent = cardSettings
	local bfsbCorner = Instance.new("UICorner")
	bfsbCorner.CornerRadius = UDim.new(0, 6)
	bfsbCorner.Parent = bfSmokeBtn
	local bfsbStroke = Instance.new("UIStroke")
	bfsbStroke.Color = THEME.BtnOffStroke
	bfsbStroke.Thickness = 1
	bfsbStroke.Parent = bfSmokeBtn
	hookButtonHover(bfSmokeBtn, THEME.BtnOff, Color3.fromRGB(40, 40, 46), THEME.TextFrost, Color3.new(1,1,1))

	local lastSmokeTap = 0
	local function toggleBoomboxSmoke()
		local now = tick()
		if now - lastSmokeTap < 0.12 then return end
		lastSmokeTap = now
		boomboxIsSmokeEnabled = not boomboxIsSmokeEnabled
		if boomboxSmoke and boomboxSmoke.Parent then
			boomboxSmoke.Enabled = boomboxIsSmokeEnabled
		end
		if boomboxIsSmokeEnabled then
			bfSmokeBtn.Text = "💨 Smoke Particles: ON"
		else
			bfSmokeBtn.Text = "💨 Smoke Particles: OFF"
		end
	end
	bfSmokeBtn.MouseButton1Click:Connect(toggleBoomboxSmoke)
	if bfSmokeBtn.Activated then
		bfSmokeBtn.Activated:Connect(toggleBoomboxSmoke)
	end

	local bfFooter = Instance.new("TextLabel")
	bfFooter.Text = "ASTROCYNA AUDIO ENGINE // BEAT-REACTIVE 3D VFX"
	bfFooter.Font = Enum.Font.Gotham
	bfFooter.TextSize = 8
	bfFooter.TextColor3 = Color3.fromRGB(70, 105, 135)
	bfFooter.Size = UDim2.new(1, 0, 0, 16)
	bfFooter.BackgroundTransparency = 1
	bfFooter.TextXAlignment = Enum.TextXAlignment.Center
	bfFooter.Parent = bfContent

	makeDraggable(boomboxFrame, bfTopBar)
end

WIN_BUILDERS.buildHacker = function()
	local hackerFrame = Instance.new("Frame")
	hackerFrame.Name = "HackerWindow"
	hackerFrame.Size = UDim2.new(0, 520, 0, 540)
	hackerFrame.Position = UDim2.new(0.5, -260, 0.5, -270)
	hackerFrame.BackgroundColor3 = THEME.MainBg
	hackerFrame.BackgroundTransparency = THEME.MainBgTransparency
	hackerFrame.BorderSizePixel = 0
	hackerFrame.Visible = false
	hackerFrame.ClipsDescendants = true
	hackerFrame.Parent = screenGui
	hackerWindow = hackerFrame
	applyResponsiveWindowScale(hackerFrame, 520, 540, true)

	local hwCorner = Instance.new("UICorner")
	hwCorner.CornerRadius = UDim.new(0, 10)
	hwCorner.Parent = hackerFrame

	local hwBevel = Instance.new("UIGradient")
	hwBevel.Rotation = 90
	hwBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	hwBevel.Parent = hackerFrame

	local hwStroke = Instance.new("UIStroke")
	hwStroke.Thickness = 2.0
	hwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hwStroke.Parent = hackerFrame
	applyNeonSweep(hwStroke, 110, 2.5, 1.8, 2.6)

	local hwTopBar = Instance.new("Frame")
	hwTopBar.Size = UDim2.new(1, 0, 0, 42)
	hwTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	hwTopBar.BorderSizePixel = 0
	hwTopBar.Parent = hackerFrame

	local hwTopCorner = Instance.new("UICorner")
	hwTopCorner.CornerRadius = UDim.new(0, 10)
	hwTopCorner.Parent = hwTopBar

	local hwTopStroke = Instance.new("UIStroke")
	hwTopStroke.Color = Color3.fromRGB(48, 48, 54)
	hwTopStroke.Thickness = 1
	hwTopStroke.Parent = hwTopBar

	local hwLiveDot = Instance.new("Frame")
	hwLiveDot.Size = UDim2.new(0, 7, 0, 7)
	hwLiveDot.Position = UDim2.new(0, 12, 0.5, -3.5)
	hwLiveDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	hwLiveDot.BorderSizePixel = 0
	hwLiveDot.Parent = hwTopBar
	local ldCorner = Instance.new("UICorner")
	ldCorner.CornerRadius = UDim.new(1, 0)
	ldCorner.Parent = hwLiveDot

	local hwTitle = Instance.new("TextLabel")
	hwTitle.Size = UDim2.new(0, 240, 1, 0)
	hwTitle.Position = UDim2.new(0, 25, 0, 0)
	hwTitle.BackgroundTransparency = 1
	hwTitle.Font = Enum.Font.GothamBold
	hwTitle.Text = "ASTROCYNA // GAME INCIDENTS & VIOLATIONS"
	hwTitle.TextColor3 = THEME.TextCyan
	hwTitle.TextSize = 9.5
	hwTitle.TextXAlignment = Enum.TextXAlignment.Left
	hwTitle.Parent = hwTopBar
	applyTextShimmer(hwTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local hwBadge = Instance.new("Frame")
	hwBadge.Size = UDim2.new(0, 175, 0, 24)
	hwBadge.Position = UDim2.new(1, -247, 0.5, -12)
	hwBadge.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	hwBadge.Parent = hwTopBar

	local hwBadgeCorner = Instance.new("UICorner")
	hwBadgeCorner.CornerRadius = UDim.new(0, 5)
	hwBadgeCorner.Parent = hwBadge

	local hwBadgeStroke = Instance.new("UIStroke")
	hwBadgeStroke.Color = Color3.fromRGB(255, 90, 110)
	hwBadgeStroke.Thickness = 1
	hwBadgeStroke.Parent = hwBadge

	local hwBadgeText = Instance.new("TextLabel")
	hwBadgeText.Size = UDim2.new(1, -8, 1, 0)
	hwBadgeText.Position = UDim2.new(0, 4, 0, 0)
	hwBadgeText.BackgroundTransparency = 1
	hwBadgeText.Font = Enum.Font.GothamBold
	hwBadgeText.Text = "🚨 0 INCIDENTS (0 ONLINE)"
	hwBadgeText.TextColor3 = Color3.fromRGB(255, 110, 130)
	hwBadgeText.TextSize = 9.5
	hwBadgeText.TextTruncate = Enum.TextTruncate.None
	hwBadgeText.Parent = hwBadge

	local hwClose = Instance.new("TextButton")
	hwClose.Size = UDim2.new(0, 28, 0, 26)
	hwClose.Position = UDim2.new(1, -34, 0, 8)
	hwClose.BackgroundColor3 = THEME.BtnOff
	hwClose.Font = Enum.Font.GothamBold
	hwClose.Text = "X"
	hwClose.TextColor3 = THEME.TextCyan
	hwClose.TextSize = 11
	hwClose.Parent = hwTopBar

	local hwCloseCorner = Instance.new("UICorner")
	hwCloseCorner.CornerRadius = UDim.new(0, 5)
	hwCloseCorner.Parent = hwClose

	local hwCloseStroke = Instance.new("UIStroke")
	hwCloseStroke.Color = THEME.BtnOffStroke
	hwCloseStroke.Thickness = 1
	hwCloseStroke.Parent = hwClose
	hookButtonHover(hwClose, THEME.BtnOff, Color3.fromRGB(44, 44, 48), THEME.TextCyan, Color3.fromRGB(255, 255, 255))

	hwClose.MouseButton1Click:Connect(function()
		hackerFrame.Visible = false
	end)

	attachAlwaysOnTopButton(hackerFrame, hwTopBar, "HackerWindow", -66, 8, 28, 26)

	local filterFrame = Instance.new("Frame")
	filterFrame.Size = UDim2.new(1, -24, 0, 32)
	filterFrame.Position = UDim2.new(0, 12, 0, 48)
	filterFrame.BackgroundTransparency = 1
	filterFrame.Parent = hackerFrame

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(0, 108, 0, 26)
	searchBox.Position = UDim2.new(0, 0, 0, 3)
	searchBox.BackgroundColor3 = Color3.fromRGB(12, 22, 34)
	searchBox.Font = Enum.Font.Gotham
	searchBox.PlaceholderText = "🔍 Search..."
	searchBox.PlaceholderColor3 = THEME.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = THEME.TextFrost
	searchBox.TextSize = 10
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = filterFrame

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 6)
	sCorner.Parent = searchBox

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(48, 48, 54)
	sStroke.Thickness = 1
	sStroke.Parent = searchBox

	local currentFilter = "ALL"
	local filterButtons = {}
	local applyFilter = function() end

	local function createFilterBtn(text, filterType, xPos, width)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 0, 26)
		btn.Position = UDim2.new(0, xPos, 0, 3)
		btn.BackgroundColor3 = (filterType == currentFilter) and Color3.fromRGB(255, 255, 255) or THEME.BtnOff
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.TextColor3 = (filterType == currentFilter) and THEME.BtnActiveText or THEME.BtnOffText
		btn.TextSize = 8.5
		btn.Parent = filterFrame

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = (filterType == currentFilter) and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke
		bStroke.Thickness = 1
		bStroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			currentFilter = filterType
			for fType, fBtn in pairs(filterButtons) do
				local isActive = (fType == currentFilter)
				fBtn.BackgroundColor3 = isActive and Color3.fromRGB(255, 255, 255) or THEME.BtnOff
				fBtn.TextColor3 = isActive and THEME.BtnActiveText or THEME.BtnOffText
				local strk = fBtn:FindFirstChildOfClass("UIStroke")
				if strk then
					strk.Color = isActive and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke
				end
			end
			applyFilter()
		end)

		filterButtons[filterType] = btn
		return btn
	end

	createFilterBtn("ALL", "ALL", 112, 38)
	createFilterBtn("🚨 WANTED", "wanted_group", 154, 82)
	createFilterBtn("🔒 CUSTODY", "custody_group", 240, 80)
	createFilterBtn("📦 CONTRABAND", "contraband_group", 324, 90)
	createFilterBtn("📜 WARDEN / OTHER", "other_group", 418, 92)

	local searchDebounce = nil
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if searchDebounce then task.cancel(searchDebounce) end
		searchDebounce = task.delay(0.12, function()
			searchDebounce = nil
			applyFilter()
		end)
	end)

	local hwStopSpecFooterBtn = nil

	local scrollList = Instance.new("ScrollingFrame")
	scrollList.Size = UDim2.new(1, -24, 1, -135)
	scrollList.Position = UDim2.new(0, 12, 0, 86)
	scrollList.BackgroundTransparency = 1
	scrollList.BorderSizePixel = 0
	scrollList.ScrollBarThickness = 3
	scrollList.ScrollBarImageColor3 = THEME.CyanPrimary
	scrollList.ClipsDescendants = true
	scrollList.Parent = hackerFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollList

	local emptyCard = Instance.new("Frame")
	emptyCard.Name = "EmptyCard"
	emptyCard.Size = UDim2.new(1, 0, 0, 96)
	emptyCard.BackgroundColor3 = THEME.CardBg
	emptyCard.BorderSizePixel = 0
	emptyCard.Visible = false
	emptyCard.Parent = scrollList

	local ecCorner = Instance.new("UICorner")
	ecCorner.CornerRadius = UDim.new(0, 8)
	ecCorner.Parent = emptyCard

	local ecLabel = Instance.new("TextLabel")
	ecLabel.Name = "EmptyLabel"
	ecLabel.Size = UDim2.new(1, -24, 1, 0)
	ecLabel.Position = UDim2.new(0, 12, 0, 0)
	ecLabel.BackgroundTransparency = 1
	ecLabel.Font = Enum.Font.GothamBold
	ecLabel.Text = "🛡️ NO INCIDENTS RECORDED // SERVER CLEAN"
	ecLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
	ecLabel.TextSize = 11
	ecLabel.TextXAlignment = Enum.TextXAlignment.Center
	ecLabel.Parent = emptyCard

	local function matchFilterCategory(suspect, filter)
		if filter == "ALL" then return true end
		if not suspect.reasons then return false end

		if filter == "wanted_group" then
			return suspect.reasons["hostile"] ~= nil or suspect.reasons["wanted"] ~= nil or suspect.reasons["assault"] ~= nil or suspect.reasons["suspect"] ~= nil
		elseif filter == "custody_group" then
			return suspect.reasons["jailed"] ~= nil or suspect.reasons["cuffed"] ~= nil or suspect.reasons["sentence"] ~= nil
		elseif filter == "contraband_group" then
			return suspect.reasons["contraband"] ~= nil
		elseif filter == "other_group" then
			return suspect.reasons["cctv"] ~= nil or suspect.reasons["demerit"] ~= nil or suspect.reasons["rollcall"] ~= nil or suspect.reasons["summons"] ~= nil or suspect.reasons["votekick"] ~= nil or suspect.reasons["admin_action"] ~= nil
		end
		return suspect.reasons[filter] ~= nil
	end

	local function getHighestReason(reasons)
		if not reasons then return "Normal", Color3.fromRGB(160, 160, 165) end
		local order = {
			{ key = "hostile", icon = "🚨", color = Color3.fromRGB(255, 65, 65) },
			{ key = "wanted", icon = "⚠️", color = Color3.fromRGB(255, 145, 45) },
			{ key = "assault", icon = "⚔️", color = Color3.fromRGB(255, 90, 80) },
			{ key = "jailed", icon = "🔒", color = Color3.fromRGB(200, 110, 255) },
			{ key = "cuffed", icon = "⛓️", color = Color3.fromRGB(220, 180, 50) },
			{ key = "sentence", icon = "⛏️", color = Color3.fromRGB(210, 150, 80) },
			{ key = "contraband", icon = "📦", color = Color3.fromRGB(120, 220, 120) },
			{ key = "votekick", icon = "🗳️", color = Color3.fromRGB(255, 100, 150) },
			{ key = "admin_action", icon = "📜", color = Color3.fromRGB(255, 120, 160) },
			{ key = "demerit", icon = "⚠️", color = Color3.fromRGB(255, 110, 110) },
			{ key = "summons", icon = "📜", color = Color3.fromRGB(180, 130, 240) },
			{ key = "rollcall", icon = "📋", color = Color3.fromRGB(240, 180, 60) },
			{ key = "cctv", icon = "📹", color = Color3.fromRGB(0, 220, 255) },
			{ key = "suspect", icon = "🟡", color = Color3.fromRGB(255, 215, 60) },
		}

		for _, item in ipairs(order) do
			if reasons[item.key] then
				return item.icon .. " " .. reasons[item.key].detail, item.color
			end
		end

		for _, r in pairs(reasons) do
			return r.detail or "Incident", Color3.fromRGB(255, 145, 45)
		end
		return "Logged Incident", Color3.fromRGB(200, 200, 205)
	end

	applyFilter = function()
		local searchTxt = string.lower(searchBox.Text or "")
		local visibleCount = 0
		for _, row in ipairs(scrollList:GetChildren()) do
			if row:IsA("Frame") and string.find(row.Name, "Incident_") then
				local uidStr = string.gsub(row.Name, "Incident_", "")
				local suspect = hackerDetectedUsers[uidStr]
				if suspect then
					local matchesSearch = true
					if searchTxt ~= "" then
						local dName = string.lower(suspect.displayName or "")
						local uName = string.lower(suspect.name or "")
						matchesSearch = string.find(dName, searchTxt, 1, true) or string.find(uName, searchTxt, 1, true)
						if not matchesSearch and suspect.reasons then
							for _, r in pairs(suspect.reasons) do
								if string.find(string.lower(r.detail or ""), searchTxt, 1, true) then
									matchesSearch = true
									break
								end
							end
						end
					end
					local matchesFilter = matchFilterCategory(suspect, currentFilter)
					local isVis = (matchesSearch and matchesFilter)
					row.Visible = isVis
					if isVis then visibleCount = visibleCount + 1 end
				end
			end
		end
		if emptyCard then
			emptyCard.Visible = (visibleCount == 0)
			if visibleCount == 0 then
				ecLabel.Text = (searchTxt ~= "" or currentFilter ~= "ALL")
					and "NO INCIDENTS MATCH FILTER"
					or "🛡️ NO INCIDENTS RECORDED // SERVER CLEAN"
				ecLabel.TextColor3 = (searchTxt ~= "" or currentFilter ~= "ALL") and THEME.TextDim or Color3.fromRGB(0, 255, 140)
			end
		end
	end

	local function createIncidentRow(suspect)
		local row = Instance.new("Frame")
		row.Name = "Incident_" .. tostring(suspect.userId)
		row.Size = UDim2.new(1, 0, 0, 72)
		row.BackgroundColor3 = THEME.CardBg
		row.BorderSizePixel = 0
		row.Parent = scrollList

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 8)
		rCorner.Parent = row

		local rGrad = Instance.new("UIGradient")
		rGrad.Rotation = 90
		rGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 28)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 26))
		})
		rGrad.Parent = row

		local rStroke = Instance.new("UIStroke")
		rStroke.Color = THEME.CardStroke
		rStroke.Thickness = 1
		rStroke.Parent = row

		local thumb = Instance.new("ImageLabel")
		thumb.Name = "AvatarThumb"
		thumb.Size = UDim2.new(0, 48, 0, 48)
		thumb.Position = UDim2.new(0, 8, 0.5, -24)
		thumb.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
		thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(suspect.userId) .. "&w=150&h=150"
		thumb.Parent = row

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 6)
		tCorner.Parent = thumb

		local statusDot = Instance.new("Frame")
		statusDot.Name = "StatusDot"
		statusDot.Size = UDim2.new(0, 8, 0, 8)
		statusDot.Position = UDim2.new(0, 46, 0, 48)
		statusDot.BorderSizePixel = 0
		statusDot.Parent = row
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = statusDot

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.Size = UDim2.new(1, -210, 0, 18)
		nameLbl.Position = UDim2.new(0, 64, 0, 8)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextColor3 = THEME.TextFrost
		nameLbl.TextSize = 11
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local reasonLbl = Instance.new("TextLabel")
		reasonLbl.Name = "ReasonLabel"
		reasonLbl.Size = UDim2.new(1, -210, 0, 16)
		reasonLbl.Position = UDim2.new(0, 64, 0, 28)
		reasonLbl.BackgroundTransparency = 1
		reasonLbl.Font = Enum.Font.GothamBold
		reasonLbl.TextSize = 10
		reasonLbl.TextXAlignment = Enum.TextXAlignment.Left
		reasonLbl.TextTruncate = Enum.TextTruncate.AtEnd
		reasonLbl.Parent = row

		local metaLbl = Instance.new("TextLabel")
		metaLbl.Name = "MetaLabel"
		metaLbl.Size = UDim2.new(1, -210, 0, 14)
		metaLbl.Position = UDim2.new(0, 64, 0, 48)
		metaLbl.BackgroundTransparency = 1
		metaLbl.Font = Enum.Font.Gotham
		metaLbl.TextColor3 = THEME.TextDim
		metaLbl.TextSize = 8.5
		metaLbl.TextXAlignment = Enum.TextXAlignment.Left
		metaLbl.Parent = row

		local btnContainer = Instance.new("Frame")
		btnContainer.Name = "BtnContainer"
		btnContainer.Size = UDim2.new(0, 135, 0, 56)
		btnContainer.Position = UDim2.new(1, -143, 0.5, -28)
		btnContainer.BackgroundTransparency = 1
		btnContainer.Parent = row

		local function createActionBtn(text, x, y, w, h, bg, strokeColor, onClick)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, w, 0, h)
			btn.Position = UDim2.new(0, x, 0, y)
			btn.BackgroundColor3 = bg
			btn.Font = Enum.Font.GothamBold
			btn.Text = text
			btn.TextColor3 = THEME.TextFrost
			btn.TextSize = 8.5
			btn.Parent = btnContainer

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = btn

			local s = Instance.new("UIStroke")
			s.Color = strokeColor or THEME.BtnOffStroke
			s.Thickness = 1
			s.Parent = btn

			hookButtonHover(btn, bg, Color3.fromRGB(44, 44, 48), THEME.TextFrost, Color3.fromRGB(255, 255, 255))
			btn.MouseButton1Click:Connect(onClick)
			return btn
		end

		local specBtn = createActionBtn("👁️ SPECTATE", 0, 2, 134, 24, Color3.fromRGB(20, 28, 38), Color3.fromRGB(0, 160, 220), function()
			local targetPlr = Players:GetPlayerByUserId(suspect.userId)
			if not targetPlr or targetPlr == player then return end
			if isSpectating and spectateTarget == targetPlr then
				stopSpectating()
			else
				spectatePlayer(targetPlr)
			end
			if updateHackerLiveCards then pcall(updateHackerLiveCards) end
		end)
		specBtn.Name = "SpecBtn"

		createActionBtn("📋 ID", 0, 30, 64, 24, Color3.fromRGB(28, 28, 32), Color3.fromRGB(60, 60, 68), function()
			if setclipboard then
				setclipboard(tostring(suspect.userId))
			end
		end)

		createActionBtn("🗑️ REMOVE", 70, 30, 64, 24, Color3.fromRGB(34, 20, 24), Color3.fromRGB(180, 50, 70), function()
			removeDetectedHacker(suspect.userId)
		end)

		return row
	end

	refreshHackerList = function()
		local existingRows = {}
		for _, child in ipairs(scrollList:GetChildren()) do
			if child:IsA("Frame") and string.find(child.Name, "Incident_") then
				local uidStr = string.gsub(child.Name, "Incident_", "")
				existingRows[uidStr] = child
			elseif child:IsA("Frame") and child.Name ~= "EmptyCard" and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local onlinePlrsMap = {}
		for _, p in ipairs(Players:GetPlayers()) do
			onlinePlrsMap[p.UserId] = p
		end

		local list = {}
		for _, suspect in pairs(hackerDetectedUsers) do
			table.insert(list, suspect)
		end

		table.sort(list, function(a, b)
			local aOnline = (onlinePlrsMap[a.userId] ~= nil)
			local bOnline = (onlinePlrsMap[b.userId] ~= nil)
			if aOnline ~= bOnline then
				return aOnline
			end
			return (a.lastDetected or "") > (b.lastDetected or "")
		end)

		local maxCards = 60
		local searchTxt = string.lower(searchBox.Text or "")
		local count = 0
		local onlineCount = 0

		for idx, suspect in ipairs(list) do
			if idx > maxCards and (onlinePlrsMap[suspect.userId] == nil) then
				break
			end

			local uidStr = tostring(suspect.userId)
			local onlinePlr = onlinePlrsMap[suspect.userId]
			local isOnline = (onlinePlr ~= nil)
			if isOnline then onlineCount = onlineCount + 1 end

			local matchesSearch = true
			if searchTxt ~= "" then
				local dName = string.lower(suspect.displayName or "")
				local uName = string.lower(suspect.name or "")
				matchesSearch = string.find(dName, searchTxt, 1, true) or string.find(uName, searchTxt, 1, true)
				if not matchesSearch and suspect.reasons then
					for _, r in pairs(suspect.reasons) do
						if string.find(string.lower(r.detail or ""), searchTxt, 1, true) then
							matchesSearch = true
							break
						end
					end
				end
			end

			local matchesFilter = matchFilterCategory(suspect, currentFilter)
			local isVis = (matchesSearch and matchesFilter)
			if isVis then count = count + 1 end

			local reasonText, reasonColor = getHighestReason(suspect.reasons)

			local row = existingRows[uidStr]
			if not row then
				row = createIncidentRow(suspect)
			else
				existingRows[uidStr] = nil
			end

			row.LayoutOrder = idx
			row.Visible = isVis

			local nameLbl = row:FindFirstChild("NameLabel")
			if nameLbl then
				nameLbl.Text = tostring(suspect.displayName) .. " (@" .. tostring(suspect.name) .. ")"
			end

			local reasonLbl = row:FindFirstChild("ReasonLabel")
			if reasonLbl then
				reasonLbl.Text = reasonText
				reasonLbl.TextColor3 = reasonColor
			end

			local metaLbl = row:FindFirstChild("MetaLabel")
			if metaLbl then
				metaLbl.Text = string.format("Team: %s | Time: %s", tostring(suspect.team or "Unknown"), tostring(suspect.lastDetected or "-"))
			end

			local statusDot = row:FindFirstChild("StatusDot")
			if statusDot then
				statusDot.BackgroundColor3 = isOnline and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(90, 110, 130)
			end
		end

		for _, deadRow in pairs(existingRows) do
			deadRow:Destroy()
		end

		if emptyCard then
			emptyCard.Visible = (count == 0)
			if count == 0 then
				ecLabel.Text = (searchTxt ~= "" or currentFilter ~= "ALL")
					and "NO INCIDENTS MATCH FILTER"
					or "🛡️ NO INCIDENTS RECORDED // SERVER CLEAN"
				ecLabel.TextColor3 = (searchTxt ~= "" or currentFilter ~= "ALL") and THEME.TextDim or Color3.fromRGB(0, 255, 140)
			end
		end

		local totalFlagged = 0
		for _ in pairs(hackerDetectedUsers) do totalFlagged = totalFlagged + 1 end
		hwBadgeText.Text = string.format("🚨 %d INCIDENTS (%d ONLINE)", totalFlagged, onlineCount)
	end

	updateHackerLiveCards = function()
		if not hackerWindow or not hackerWindow.Visible then return end
		local totalCount = 0
		local onlineCount = 0

		for _, row in ipairs(scrollList:GetChildren()) do
			if row:IsA("Frame") and string.find(row.Name, "Incident_") then
				totalCount = totalCount + 1
				local uidStr = string.gsub(row.Name, "Incident_", "")
				local uid = tonumber(uidStr)
				local onlinePlr = uid and Players:GetPlayerByUserId(uid)
				local isOnline = (onlinePlr ~= nil)
				if isOnline then onlineCount = onlineCount + 1 end

				if row.Visible then
					local statusDot = row:FindFirstChild("StatusDot")
					if statusDot then
						statusDot.BackgroundColor3 = isOnline and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(90, 110, 130)
					end

					local btnContainer = row:FindFirstChild("BtnContainer")
					if btnContainer then
						local specBtn = btnContainer:FindFirstChild("SpecBtn")
						local specStroke = specBtn and specBtn:FindFirstChildOfClass("UIStroke")
						if specBtn then
							local isCurrentlySpec = (isSpectating and spectateTarget and onlinePlr and spectateTarget == onlinePlr)
							if isCurrentlySpec then
								specBtn.Text = "⏹ STOP SPECTATE"
								specBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 22)
								specBtn.TextColor3 = Color3.fromRGB(255, 210, 220)
								if specStroke then specStroke.Color = Color3.fromRGB(255, 60, 90) end
							elseif isOnline then
								specBtn.Text = "👁️ SPECTATE"
								specBtn.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
								specBtn.TextColor3 = THEME.TextFrost
								if specStroke then specStroke.Color = Color3.fromRGB(0, 160, 220) end
							else
								specBtn.Text = "👁️ SPECTATE"
								specBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
								specBtn.TextColor3 = THEME.TextDim
								if specStroke then specStroke.Color = Color3.fromRGB(36, 36, 42) end
							end
						end
					end
				end
			end
		end

		if hwStopSpecFooterBtn then
			hwStopSpecFooterBtn.Visible = (isSpectating == true)
		end

		local totalFlagged = 0
		for _ in pairs(hackerDetectedUsers) do totalFlagged = totalFlagged + 1 end
		hwBadgeText.Text = string.format("🚨 %d INCIDENTS (%d ONLINE)", totalFlagged, onlineCount)
	end

	task.spawn(function()
		while true do
			task.wait(2.0)
			if hackerWindow and hackerWindow.Visible then
				pcall(updateHackerLiveCards)
			end
		end
	end)

	local hwFooter = Instance.new("Frame")
	hwFooter.Size = UDim2.new(1, 0, 0, 40)
	hwFooter.Position = UDim2.new(0, 0, 1, -40)
	hwFooter.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	hwFooter.BorderSizePixel = 0
	hwFooter.Parent = hackerFrame

	local hwFooterCorner = Instance.new("UICorner")
	hwFooterCorner.CornerRadius = UDim.new(0, 10)
	hwFooterCorner.Parent = hwFooter

	local hwFooterStroke = Instance.new("UIStroke")
	hwFooterStroke.Color = Color3.fromRGB(48, 48, 54)
	hwFooterStroke.Thickness = 1
	hwFooterStroke.Parent = hwFooter

	local btnScanToggle = Instance.new("TextButton")
	btnScanToggle.Size = UDim2.new(0, 110, 0, 26)
	btnScanToggle.Position = UDim2.new(0, 10, 0.5, -13)
	btnScanToggle.BackgroundColor3 = isHackerWatchdogEnabled and Color3.fromRGB(18, 42, 32) or THEME.BtnOff
	btnScanToggle.Font = Enum.Font.GothamBold
	btnScanToggle.Text = isHackerWatchdogEnabled and "🛡️ MONITOR: ON" or "🛡️ MONITOR: OFF"
	btnScanToggle.TextColor3 = isHackerWatchdogEnabled and Color3.fromRGB(0, 225, 160) or THEME.BtnOffText
	btnScanToggle.TextSize = 9.5
	btnScanToggle.Parent = hwFooter

	local scanCorner = Instance.new("UICorner")
	scanCorner.CornerRadius = UDim.new(0, 6)
	scanCorner.Parent = btnScanToggle
	local scanStroke = Instance.new("UIStroke")
	scanStroke.Color = isHackerWatchdogEnabled and Color3.fromRGB(0, 215, 140) or THEME.BtnOffStroke
	scanStroke.Thickness = 1
	scanStroke.Parent = btnScanToggle

	btnScanToggle.MouseButton1Click:Connect(function()
		isHackerWatchdogEnabled = not isHackerWatchdogEnabled
		btnScanToggle.BackgroundColor3 = isHackerWatchdogEnabled and Color3.fromRGB(18, 42, 32) or THEME.BtnOff
		btnScanToggle.Text = isHackerWatchdogEnabled and "🛡️ MONITOR: ON" or "🛡️ MONITOR: OFF"
		btnScanToggle.TextColor3 = isHackerWatchdogEnabled and Color3.fromRGB(0, 225, 160) or THEME.BtnOffText
		scanStroke.Color = isHackerWatchdogEnabled and Color3.fromRGB(0, 215, 140) or THEME.BtnOffStroke
		if isHackerWatchdogEnabled then
			task.spawn(scanAllPlayersRealtime)
		end
	end)

	local btnRescan = Instance.new("TextButton")
	btnRescan.Size = UDim2.new(0, 80, 0, 26)
	btnRescan.Position = UDim2.new(0, 126, 0.5, -13)
	btnRescan.BackgroundColor3 = Color3.fromRGB(16, 32, 48)
	btnRescan.Font = Enum.Font.GothamBold
	btnRescan.Text = "⚡ RESCAN"
	btnRescan.TextColor3 = THEME.TextCyan
	btnRescan.TextSize = 9.5
	btnRescan.Parent = hwFooter

	local rsCorner = Instance.new("UICorner")
	rsCorner.CornerRadius = UDim.new(0, 6)
	rsCorner.Parent = btnRescan
	local rsStroke = Instance.new("UIStroke")
	rsStroke.Color = Color3.fromRGB(24, 64, 96)
	rsStroke.Thickness = 1
	rsStroke.Parent = btnRescan
	hookButtonHover(btnRescan, Color3.fromRGB(16, 32, 48), Color3.fromRGB(20, 48, 72), THEME.TextCyan, Color3.fromRGB(255, 255, 255))

	btnRescan.MouseButton1Click:Connect(function()
		btnRescan.Text = "SCANNING..."
		btnRescan.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
		local _found = scanAllPlayersRealtime()
		task.wait(0.2)
		btnRescan.Text = "⚡ RESCAN"
		btnRescan.BackgroundColor3 = Color3.fromRGB(16, 32, 48)
	end)

	local btnClearAll = Instance.new("TextButton")
	btnClearAll.Size = UDim2.new(0, 84, 0, 26)
	btnClearAll.Position = UDim2.new(0, 212, 0.5, -13)
	btnClearAll.BackgroundColor3 = Color3.fromRGB(24, 18, 26)
	btnClearAll.Font = Enum.Font.GothamBold
	btnClearAll.Text = "🗑️ CLEAR"
	btnClearAll.TextColor3 = Color3.fromRGB(220, 220, 225)
	btnClearAll.TextSize = 9.5
	btnClearAll.Parent = hwFooter

	local clrCorner = Instance.new("UICorner")
	clrCorner.CornerRadius = UDim.new(0, 6)
	clrCorner.Parent = btnClearAll
	local clrStroke = Instance.new("UIStroke")
	clrStroke.Color = Color3.fromRGB(58, 30, 42)
	clrStroke.Thickness = 1
	clrStroke.Parent = btnClearAll
	hookButtonHover(btnClearAll, Color3.fromRGB(24, 18, 26), Color3.fromRGB(48, 22, 32), Color3.fromRGB(220, 220, 225), Color3.fromRGB(255, 255, 255))

	local confirmClear = false
	btnClearAll.MouseButton1Click:Connect(function()
		if not confirmClear then
			confirmClear = true
			btnClearAll.Text = "SURE?"
			btnClearAll.BackgroundColor3 = Color3.fromRGB(180, 25, 50)
			btnClearAll.TextColor3 = Color3.fromRGB(255, 255, 255)
			task.delay(3, function()
				confirmClear = false
				btnClearAll.Text = "🗑️ CLEAR"
				btnClearAll.BackgroundColor3 = Color3.fromRGB(24, 18, 26)
				btnClearAll.TextColor3 = Color3.fromRGB(220, 220, 225)
			end)
		else
			confirmClear = false
			btnClearAll.Text = "🗑️ CLEAR"
			btnClearAll.BackgroundColor3 = Color3.fromRGB(24, 18, 26)
			btnClearAll.TextColor3 = Color3.fromRGB(220, 220, 225)
			clearAllDetectedHackers()
		end
	end)

	local footerInfo = Instance.new("TextLabel")
	footerInfo.Size = UDim2.new(0, 110, 1, 0)
	footerInfo.Position = UDim2.new(1, -118, 0, 0)
	footerInfo.BackgroundTransparency = 1
	footerInfo.Font = Enum.Font.Gotham
	footerInfo.Text = "📋 ATTRIBUTES"
	footerInfo.TextColor3 = THEME.TextDim
	footerInfo.TextSize = 8.5
	footerInfo.TextXAlignment = Enum.TextXAlignment.Right
	footerInfo.Parent = hwFooter

	hwStopSpecFooterBtn = Instance.new("TextButton")
	hwStopSpecFooterBtn.Name = "HwStopSpecFooterBtn"
	hwStopSpecFooterBtn.Size = UDim2.new(0, 96, 0, 26)
	hwStopSpecFooterBtn.Position = UDim2.new(0, 302, 0.5, -13)
	hwStopSpecFooterBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 22)
	hwStopSpecFooterBtn.Font = Enum.Font.GothamBold
	hwStopSpecFooterBtn.Text = "⏹ STOP SPEC"
	hwStopSpecFooterBtn.TextColor3 = Color3.fromRGB(255, 210, 220)
	hwStopSpecFooterBtn.TextSize = 9.5
	hwStopSpecFooterBtn.Visible = (isSpectating == true)
	hwStopSpecFooterBtn.Parent = hwFooter

	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 6)
	sfCorner.Parent = hwStopSpecFooterBtn

	local sfStroke = Instance.new("UIStroke")
	sfStroke.Color = Color3.fromRGB(255, 60, 90)
	sfStroke.Thickness = 1
	sfStroke.Parent = hwStopSpecFooterBtn
	hookButtonHover(hwStopSpecFooterBtn, Color3.fromRGB(38, 16, 22), Color3.fromRGB(58, 20, 30), Color3.fromRGB(255, 210, 220), Color3.fromRGB(255, 255, 255))

	hwStopSpecFooterBtn.MouseButton1Click:Connect(function()
		stopSpectating()
		if updateHackerLiveCards then pcall(updateHackerLiveCards) end
	end)

	makeDraggable(hackerFrame, hwTopBar)
end


WIN_BUILDERS.buildCheatDetector = function()
	local cheatFrame = Instance.new("Frame")
	cheatFrame.Name = "CheatDetectorWindow"
	cheatFrame.Size = UDim2.new(0, 520, 0, 540)
	cheatFrame.Position = UDim2.new(0.5, -260, 0.5, -270)
	cheatFrame.BackgroundColor3 = THEME.MainBg
	cheatFrame.BackgroundTransparency = THEME.MainBgTransparency
	cheatFrame.BorderSizePixel = 0
	cheatFrame.Visible = false
	cheatFrame.ClipsDescendants = true
	cheatFrame.Parent = screenGui
	ADMIN_SYS.cheatWindow = cheatFrame
	applyResponsiveWindowScale(cheatFrame, 520, 540, true)

	local cwCorner = Instance.new("UICorner")
	cwCorner.CornerRadius = UDim.new(0, 10)
	cwCorner.Parent = cheatFrame

	local cwBevel = Instance.new("UIGradient")
	cwBevel.Rotation = 90
	cwBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 12, 28)),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 10, 18))
	})
	cwBevel.Parent = cheatFrame

	local cwStroke = Instance.new("UIStroke")
	cwStroke.Thickness = 2.0
	cwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cwStroke.Parent = cheatFrame
	applyNeonSweep(cwStroke, 110, 2.5, 1.8, 2.6)

	local cwTopBar = Instance.new("Frame")
	cwTopBar.Size = UDim2.new(1, 0, 0, 42)
	cwTopBar.BackgroundColor3 = Color3.fromRGB(24, 12, 22)
	cwTopBar.BorderSizePixel = 0
	cwTopBar.Parent = cheatFrame

	local cwTopCorner = Instance.new("UICorner")
	cwTopCorner.CornerRadius = UDim.new(0, 10)
	cwTopCorner.Parent = cwTopBar

	local cwTopStroke = Instance.new("UIStroke")
	cwTopStroke.Color = Color3.fromRGB(64, 28, 48)
	cwTopStroke.Thickness = 1
	cwTopStroke.Parent = cwTopBar

	local cwLiveDot = Instance.new("Frame")
	cwLiveDot.Size = UDim2.new(0, 7, 0, 7)
	cwLiveDot.Position = UDim2.new(0, 12, 0.5, -3.5)
	cwLiveDot.BackgroundColor3 = Color3.fromRGB(255, 45, 120)
	cwLiveDot.BorderSizePixel = 0
	cwLiveDot.Parent = cwTopBar
	local cldCorner = Instance.new("UICorner")
	cldCorner.CornerRadius = UDim.new(1, 0)
	cldCorner.Parent = cwLiveDot

	local cwTitle = Instance.new("TextLabel")
	cwTitle.Size = UDim2.new(0, 240, 1, 0)
	cwTitle.Position = UDim2.new(0, 25, 0, 0)
	cwTitle.BackgroundTransparency = 1
	cwTitle.Font = Enum.Font.GothamBold
	cwTitle.Text = "ASTROCYNA // ANTI-CHEAT & EXPLOIT DETECTOR"
	cwTitle.TextColor3 = Color3.fromRGB(255, 60, 140)
	cwTitle.TextSize = 9.5
	cwTitle.TextXAlignment = Enum.TextXAlignment.Left
	cwTitle.Parent = cwTopBar
	applyTextShimmer(cwTitle, Color3.fromRGB(255, 60, 140), Color3.fromRGB(255, 180, 220), Color3.fromRGB(255, 255, 255), 1.3)

	local cwBadge = Instance.new("Frame")
	cwBadge.Size = UDim2.new(0, 175, 0, 24)
	cwBadge.Position = UDim2.new(1, -247, 0.5, -12)
	cwBadge.BackgroundColor3 = Color3.fromRGB(28, 14, 24)
	cwBadge.Parent = cwTopBar

	local cwBadgeCorner = Instance.new("UICorner")
	cwBadgeCorner.CornerRadius = UDim.new(0, 5)
	cwBadgeCorner.Parent = cwBadge

	local cwBadgeStroke = Instance.new("UIStroke")
	cwBadgeStroke.Color = Color3.fromRGB(255, 45, 120)
	cwBadgeStroke.Thickness = 1
	cwBadgeStroke.Parent = cwBadge

	local cwBadgeText = Instance.new("TextLabel")
	cwBadgeText.Size = UDim2.new(1, -8, 1, 0)
	cwBadgeText.Position = UDim2.new(0, 4, 0, 0)
	cwBadgeText.BackgroundTransparency = 1
	cwBadgeText.Font = Enum.Font.GothamBold
	cwBadgeText.Text = "⚡ 0 CHEATERS (0 ONLINE)"
	cwBadgeText.TextColor3 = Color3.fromRGB(255, 100, 160)
	cwBadgeText.TextSize = 9.5
	cwBadgeText.TextTruncate = Enum.TextTruncate.None
	cwBadgeText.Parent = cwBadge

	local cwClose = Instance.new("TextButton")
	cwClose.Size = UDim2.new(0, 28, 0, 26)
	cwClose.Position = UDim2.new(1, -34, 0, 8)
	cwClose.BackgroundColor3 = THEME.BtnOff
	cwClose.Font = Enum.Font.GothamBold
	cwClose.Text = "X"
	cwClose.TextColor3 = Color3.fromRGB(255, 100, 160)
	cwClose.TextSize = 11
	cwClose.Parent = cwTopBar

	local cwCloseCorner = Instance.new("UICorner")
	cwCloseCorner.CornerRadius = UDim.new(0, 5)
	cwCloseCorner.Parent = cwClose

	local cwCloseStroke = Instance.new("UIStroke")
	cwCloseStroke.Color = THEME.BtnOffStroke
	cwCloseStroke.Thickness = 1
	cwCloseStroke.Parent = cwClose
	hookButtonHover(cwClose, THEME.BtnOff, Color3.fromRGB(48, 18, 32), Color3.fromRGB(255, 100, 160), Color3.fromRGB(255, 255, 255))

	cwClose.MouseButton1Click:Connect(function()
		cheatFrame.Visible = false
	end)

	attachAlwaysOnTopButton(cheatFrame, cwTopBar, "CheatDetectorWindow", -66, 8, 28, 26)

	-- Filters & Search Row
	local filterFrame = Instance.new("Frame")
	filterFrame.Size = UDim2.new(1, -24, 0, 32)
	filterFrame.Position = UDim2.new(0, 12, 0, 48)
	filterFrame.BackgroundTransparency = 1
	filterFrame.Parent = cheatFrame

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(0, 110, 0, 26)
	searchBox.Position = UDim2.new(0, 0, 0, 3)
	searchBox.BackgroundColor3 = Color3.fromRGB(16, 12, 22)
	searchBox.Font = Enum.Font.Gotham
	searchBox.PlaceholderText = "🔍 Search..."
	searchBox.PlaceholderColor3 = THEME.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = THEME.TextFrost
	searchBox.TextSize = 10
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = filterFrame

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 6)
	sCorner.Parent = searchBox

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(56, 32, 48)
	sStroke.Thickness = 1
	sStroke.Parent = searchBox

	local currentFilter = "ALL"
	local filterButtons = {}
	local applyCheatFilter = function() end

	local function createFilterBtn(text, filterType, xPos, width)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 0, 26)
		btn.Position = UDim2.new(0, xPos, 0, 3)
		btn.BackgroundColor3 = (filterType == currentFilter) and Color3.fromRGB(255, 45, 120) or THEME.BtnOff
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.TextColor3 = (filterType == currentFilter) and Color3.fromRGB(255, 255, 255) or THEME.BtnOffText
		btn.TextSize = 8.5
		btn.Parent = filterFrame

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = (filterType == currentFilter) and Color3.fromRGB(255, 100, 160) or THEME.BtnOffStroke
		bStroke.Thickness = 1
		bStroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			currentFilter = filterType
			for fType, fBtn in pairs(filterButtons) do
				local isActive = (fType == currentFilter)
				fBtn.BackgroundColor3 = isActive and Color3.fromRGB(255, 45, 120) or THEME.BtnOff
				fBtn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or THEME.BtnOffText
				local strk = fBtn:FindFirstChildOfClass("UIStroke")
				if strk then
					strk.Color = isActive and Color3.fromRGB(255, 100, 160) or THEME.BtnOffStroke
				end
			end
			applyCheatFilter()
		end)

		filterButtons[filterType] = btn
		return btn
	end

	createFilterBtn("ALL", "ALL", 114, 38)
	createFilterBtn("⚡ MOVEMENT", "movement_group", 156, 86)
	createFilterBtn("💉 EXECUTOR", "executor_group", 246, 86)
	createFilterBtn("💬 CHAT & LAG", "chat_lag_group", 336, 86)

	local cheatSearchDebounce = nil
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if cheatSearchDebounce then task.cancel(cheatSearchDebounce) end
		cheatSearchDebounce = task.delay(0.12, function()
			cheatSearchDebounce = nil
			applyCheatFilter()
		end)
	end)

	local cwStopSpecFooterBtn = nil

	local scrollList = Instance.new("ScrollingFrame")
	scrollList.Size = UDim2.new(1, -24, 1, -135)
	scrollList.Position = UDim2.new(0, 12, 0, 86)
	scrollList.BackgroundTransparency = 1
	scrollList.BorderSizePixel = 0
	scrollList.ScrollBarThickness = 3
	scrollList.ScrollBarImageColor3 = Color3.fromRGB(255, 45, 120)
	scrollList.ClipsDescendants = true
	scrollList.Parent = cheatFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollList

	local EXECUTOR_KEYS = {
		{ key = "executor_bodymover", icon = "💉", label = "EXECUTOR", color = Color3.fromRGB(255, 45, 120) },
		{ key = "exploit_tool", icon = "🛠️", label = "TOOL", color = Color3.fromRGB(255, 130, 40) },
		{ key = "hitbox_expander", icon = "📦", label = "HITBOX", color = Color3.fromRGB(255, 180, 50) },
		{ key = "invis_desync", icon = "👻", label = "DESYNC", color = Color3.fromRGB(180, 100, 255) },
		{ key = "executor_chat", icon = "💬", label = "EXECUTOR CHAT", color = Color3.fromRGB(255, 90, 160) },
	}

	local MOVEMENT_KEYS = {
		{ key = "speed_hack", icon = "⚡", label = "SPEED", color = Color3.fromRGB(255, 60, 60) },
		{ key = "fly_hack", icon = "🕊️", label = "FLY", color = Color3.fromRGB(0, 220, 255) },
		{ key = "cframe_teleport", icon = "📍", label = "TELEPORT", color = Color3.fromRGB(255, 80, 80) },
		{ key = "infinite_jump", icon = "🦘", label = "INF JUMP", color = Color3.fromRGB(255, 160, 40) },
		{ key = "spinbot_fling", icon = "🌀", label = "SPINBOT", color = Color3.fromRGB(255, 40, 200) },
	}

	local CHAT_LAG_KEYS = {
		{ key = "anim_spam", icon = "⚡", label = "ANIM CRASHER", color = Color3.fromRGB(255, 60, 140) },
		{ key = "executor_chat", icon = "💬", label = "CMD SPAM", color = Color3.fromRGB(255, 90, 160) },
	}

	local function matchFilterCategory(suspect, filter)
		if filter == "ALL" then return true end
		if not suspect.reasons then return false end

		if filter == "executor_group" then
			for _, item in ipairs(EXECUTOR_KEYS) do
				if suspect.reasons[item.key] ~= nil then return true end
			end
			return false
		elseif filter == "movement_group" then
			for _, item in ipairs(MOVEMENT_KEYS) do
				if suspect.reasons[item.key] ~= nil then return true end
			end
			return false
		elseif filter == "chat_lag_group" then
			for _, item in ipairs(CHAT_LAG_KEYS) do
				if suspect.reasons[item.key] ~= nil then return true end
			end
			return false
		end
		return suspect.reasons[filter] ~= nil
	end

	local function getFilteredReason(reasons, filter)
		if not reasons then return "Normal", Color3.fromRGB(160, 160, 165), "" end

		local searchTables = {}
		if filter == "executor_group" then
			table.insert(searchTables, EXECUTOR_KEYS)
		elseif filter == "movement_group" then
			table.insert(searchTables, MOVEMENT_KEYS)
		elseif filter == "chat_lag_group" then
			table.insert(searchTables, CHAT_LAG_KEYS)
		else
			table.insert(searchTables, EXECUTOR_KEYS)
			table.insert(searchTables, MOVEMENT_KEYS)
			table.insert(searchTables, CHAT_LAG_KEYS)
		end

		for _, tbl in ipairs(searchTables) do
			for _, item in ipairs(tbl) do
				if reasons[item.key] then
					local detail = reasons[item.key].detail or item.label
					return string.format("[%s] %s %s", item.label, item.icon, detail), item.color, item.label
				end
			end
		end

		for k, r in pairs(reasons) do
			return string.format("[LOG] %s", r.detail or "Cheat Detected"), Color3.fromRGB(255, 60, 120), "LOG"
		end
		return "[EXPLOIT] Detected Exploit", Color3.fromRGB(255, 100, 160), "EXPLOIT"
	end

	local function getCategoryBadges(reasons)
		if not reasons then return {} end
		local badges = {}
		local hasExec = false
		local hasMove = false
		local hasChat = false

		for _, item in ipairs(EXECUTOR_KEYS) do
			if reasons[item.key] then
				hasExec = true
				break
			end
		end
		for _, item in ipairs(MOVEMENT_KEYS) do
			if reasons[item.key] then
				hasMove = true
				break
			end
		end
		for _, item in ipairs(CHAT_LAG_KEYS) do
			if reasons[item.key] then
				hasChat = true
				break
			end
		end

		if hasExec then
			table.insert(badges, "💉 EXECUTOR")
		end
		if hasMove then
			table.insert(badges, "⚡ MOVEMENT")
		end
		if hasChat then
			table.insert(badges, "💬 CHAT/LAG")
		end
		return badges
	end

	local emptyCard = Instance.new("Frame")
	emptyCard.Name = "EmptyCheatCard"
	emptyCard.Size = UDim2.new(1, 0, 0, 96)
	emptyCard.BackgroundColor3 = THEME.CardBg
	emptyCard.BorderSizePixel = 0
	emptyCard.Visible = false
	emptyCard.Parent = scrollList

	local ecCorner = Instance.new("UICorner")
	ecCorner.CornerRadius = UDim.new(0, 8)
	ecCorner.Parent = emptyCard

	local ecLabel = Instance.new("TextLabel")
	ecLabel.Name = "EmptyCheatLabel"
	ecLabel.Size = UDim2.new(1, -24, 1, 0)
	ecLabel.Position = UDim2.new(0, 12, 0, 0)
	ecLabel.BackgroundTransparency = 1
	ecLabel.Font = Enum.Font.GothamBold
	ecLabel.Text = "🛡️ NO CHEATERS DETECTED // SERVER CLEAN"
	ecLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
	ecLabel.TextSize = 11
	ecLabel.TextXAlignment = Enum.TextXAlignment.Center
	ecLabel.Parent = emptyCard

	applyCheatFilter = function()
		local searchTxt = string.lower(searchBox.Text or "")
		local visibleCount = 0
		for _, row in ipairs(scrollList:GetChildren()) do
			if row:IsA("Frame") and string.find(row.Name, "Cheat_") then
				local uidStr = string.gsub(row.Name, "Cheat_", "")
				local suspect = ADMIN_SYS.cheatDetectedUsers[uidStr]
				if suspect then
					local matchesSearch = true
					if searchTxt ~= "" then
						local dName = string.lower(suspect.displayName or "")
						local uName = string.lower(suspect.name or "")
						matchesSearch = string.find(dName, searchTxt, 1, true) or string.find(uName, searchTxt, 1, true)
						if not matchesSearch and suspect.reasons then
							for _, r in pairs(suspect.reasons) do
								if string.find(string.lower(r.detail or ""), searchTxt, 1, true) then
									matchesSearch = true
									break
								end
							end
						end
					end
					local matchesFilter = matchFilterCategory(suspect, currentFilter)
					local isVis = (matchesSearch and matchesFilter)
					row.Visible = isVis
					if isVis then visibleCount = visibleCount + 1 end
				end
			end
		end
		if emptyCard then
			emptyCard.Visible = (visibleCount == 0)
			if visibleCount == 0 then
				ecLabel.Text = (searchTxt ~= "" or currentFilter ~= "ALL")
					and "NO CHEATERS MATCH FILTER"
					or "🛡️ NO CHEATERS DETECTED // SERVER CLEAN"
				ecLabel.TextColor3 = (searchTxt ~= "" or currentFilter ~= "ALL") and THEME.TextDim or Color3.fromRGB(0, 255, 140)
			end
		end
	end

	local function createCheatRow(suspect)
		local row = Instance.new("Frame")
		row.Name = "Cheat_" .. tostring(suspect.userId)
		row.Size = UDim2.new(1, 0, 0, 72)
		row.BackgroundColor3 = THEME.CardBg
		row.BorderSizePixel = 0
		row.Parent = scrollList

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 8)
		rCorner.Parent = row

		local rGrad = Instance.new("UIGradient")
		rGrad.Rotation = 90
		rGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 14, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 10, 20))
		})
		rGrad.Parent = row

		local rStroke = Instance.new("UIStroke")
		rStroke.Color = Color3.fromRGB(72, 28, 54)
		rStroke.Thickness = 1
		rStroke.Parent = row

		local thumb = Instance.new("ImageLabel")
		thumb.Name = "AvatarThumb"
		thumb.Size = UDim2.new(0, 48, 0, 48)
		thumb.Position = UDim2.new(0, 8, 0.5, -24)
		thumb.BackgroundColor3 = Color3.fromRGB(16, 10, 20)
		thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(suspect.userId) .. "&w=150&h=150"
		thumb.Parent = row

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 6)
		tCorner.Parent = thumb

		local tStroke = Instance.new("UIStroke")
		tStroke.Color = Color3.fromRGB(255, 45, 120)
		tStroke.Thickness = 1
		tStroke.Parent = thumb

		local statusDot = Instance.new("Frame")
		statusDot.Name = "StatusDot"
		statusDot.Size = UDim2.new(0, 8, 0, 8)
		statusDot.Position = UDim2.new(0, 46, 0, 48)
		statusDot.BorderSizePixel = 0
		statusDot.Parent = row
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = statusDot

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.Size = UDim2.new(1, -210, 0, 18)
		nameLbl.Position = UDim2.new(0, 64, 0, 8)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextColor3 = THEME.TextFrost
		nameLbl.TextSize = 11
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local reasonLbl = Instance.new("TextLabel")
		reasonLbl.Name = "ReasonLabel"
		reasonLbl.Size = UDim2.new(1, -210, 0, 16)
		reasonLbl.Position = UDim2.new(0, 64, 0, 28)
		reasonLbl.BackgroundTransparency = 1
		reasonLbl.Font = Enum.Font.GothamBold
		reasonLbl.TextSize = 10
		reasonLbl.TextXAlignment = Enum.TextXAlignment.Left
		reasonLbl.TextTruncate = Enum.TextTruncate.AtEnd
		reasonLbl.Parent = row

		local metaLbl = Instance.new("TextLabel")
		metaLbl.Name = "MetaLabel"
		metaLbl.Size = UDim2.new(1, -210, 0, 14)
		metaLbl.Position = UDim2.new(0, 64, 0, 48)
		metaLbl.BackgroundTransparency = 1
		metaLbl.Font = Enum.Font.Gotham
		metaLbl.TextColor3 = THEME.TextDim
		metaLbl.TextSize = 8.5
		metaLbl.TextXAlignment = Enum.TextXAlignment.Left
		metaLbl.Parent = row

		local btnContainer = Instance.new("Frame")
		btnContainer.Name = "BtnContainer"
		btnContainer.Size = UDim2.new(0, 135, 0, 56)
		btnContainer.Position = UDim2.new(1, -143, 0.5, -28)
		btnContainer.BackgroundTransparency = 1
		btnContainer.Parent = row

		local function createCheatActionBtn(text, x, y, w, h, bg, strokeColor, onClick)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, w, 0, h)
			btn.Position = UDim2.new(0, x, 0, y)
			btn.BackgroundColor3 = bg
			btn.Font = Enum.Font.GothamBold
			btn.Text = text
			btn.TextColor3 = THEME.TextFrost
			btn.TextSize = 8.5
			btn.Parent = btnContainer

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = btn

			local s = Instance.new("UIStroke")
			s.Color = strokeColor or THEME.BtnOffStroke
			s.Thickness = 1
			s.Parent = btn

			hookButtonHover(btn, bg, Color3.fromRGB(48, 22, 36), THEME.TextFrost, Color3.fromRGB(255, 255, 255))
			btn.MouseButton1Click:Connect(onClick)
			return btn
		end

		local specBtn = createCheatActionBtn("👁️ SPECTATE", 0, 2, 134, 24, Color3.fromRGB(34, 16, 28), Color3.fromRGB(255, 45, 120), function()
			local targetPlr = Players:GetPlayerByUserId(suspect.userId)
			if not targetPlr or targetPlr == player then return end
			if isSpectating and spectateTarget == targetPlr then
				stopSpectating()
			else
				spectatePlayer(targetPlr)
			end
			if ADMIN_SYS.updateCheatLiveCards then pcall(ADMIN_SYS.updateCheatLiveCards) end
		end)
		specBtn.Name = "SpecBtn"

		createCheatActionBtn("📋 COPY", 0, 30, 64, 24, Color3.fromRGB(28, 16, 24), Color3.fromRGB(68, 36, 52), function()
			if setclipboard then
				local reasonLines = {}
				if suspect.reasons then
					for _, r in pairs(suspect.reasons) do
						table.insert(reasonLines, "- " .. tostring(r.detail) .. " (" .. tostring(r.time) .. ")")
					end
				end
				local txt = string.format("[ANTI-CHEAT REPORT]\nTarget: %s (@%s)\nUserId: %s\nTeam: %s\nDetected:\n%s",
					tostring(suspect.displayName), tostring(suspect.name), tostring(suspect.userId), tostring(suspect.team), table.concat(reasonLines, "\n"))
				setclipboard(txt)
			end
		end)

		createCheatActionBtn("🗑️ REMOVE", 70, 30, 64, 24, Color3.fromRGB(34, 18, 22), Color3.fromRGB(180, 50, 70), function()
			ADMIN_SYS.removeDetectedCheat(suspect.userId)
		end)

		return row
	end

	ADMIN_SYS.refreshCheatList = function()
		local existingRows = {}
		for _, child in ipairs(scrollList:GetChildren()) do
			if child:IsA("Frame") and string.find(child.Name, "Cheat_") then
				local uidStr = string.gsub(child.Name, "Cheat_", "")
				existingRows[uidStr] = child
			elseif child:IsA("Frame") and child.Name ~= "EmptyCheatCard" and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local onlinePlrsMap = {}
		for _, p in ipairs(Players:GetPlayers()) do
			onlinePlrsMap[p.UserId] = p
		end

		local list = {}
		for _, suspect in pairs(ADMIN_SYS.cheatDetectedUsers) do
			table.insert(list, suspect)
		end

		table.sort(list, function(a, b)
			local aOnline = (onlinePlrsMap[a.userId] ~= nil)
			local bOnline = (onlinePlrsMap[b.userId] ~= nil)
			if aOnline ~= bOnline then
				return aOnline
			end
			return (a.lastDetected or "") > (b.lastDetected or "")
		end)

		local maxCards = 60
		local searchTxt = string.lower(searchBox.Text or "")
		local count = 0
		local onlineCount = 0

		for idx, suspect in ipairs(list) do
			if idx > maxCards and (onlinePlrsMap[suspect.userId] == nil) then
				break
			end

			local uidStr = tostring(suspect.userId)
			local onlinePlr = onlinePlrsMap[suspect.userId]
			local isOnline = (onlinePlr ~= nil)
			if isOnline then onlineCount = onlineCount + 1 end

			local matchesSearch = true
			if searchTxt ~= "" then
				local dName = string.lower(suspect.displayName or "")
				local uName = string.lower(suspect.name or "")
				matchesSearch = string.find(dName, searchTxt, 1, true) or string.find(uName, searchTxt, 1, true)
				if not matchesSearch and suspect.reasons then
					for _, r in pairs(suspect.reasons) do
						if string.find(string.lower(r.detail or ""), searchTxt, 1, true) then
							matchesSearch = true
							break
						end
					end
				end
			end

			local matchesFilter = matchFilterCategory(suspect, currentFilter)
			local isVis = (matchesSearch and matchesFilter)
			if isVis then count = count + 1 end

			local reasonText, reasonColor = getFilteredReason(suspect.reasons, currentFilter)

			local row = existingRows[uidStr]
			if not row then
				row = createCheatRow(suspect)
			else
				existingRows[uidStr] = nil
			end

			row.LayoutOrder = idx
			row.Visible = isVis

			local nameLbl = row:FindFirstChild("NameLabel")
			if nameLbl then
				nameLbl.Text = tostring(suspect.displayName) .. " (@" .. tostring(suspect.name) .. ")"
			end

			local reasonLbl = row:FindFirstChild("ReasonLabel")
			if reasonLbl then
				reasonLbl.Text = reasonText
				reasonLbl.TextColor3 = reasonColor
			end

			local metaLbl = row:FindFirstChild("MetaLabel")
			if metaLbl then
				local catBadges = getCategoryBadges(suspect.reasons)
				local badgeSummary = (#catBadges > 0) and ("[" .. table.concat(catBadges, " ") .. "] | ") or ""
				metaLbl.Text = string.format("%sTeam: %s | Time: %s", badgeSummary, tostring(suspect.team or "Unknown"), tostring(suspect.lastDetected or "-"))
			end

			local statusDot = row:FindFirstChild("StatusDot")
			if statusDot then
				statusDot.BackgroundColor3 = isOnline and Color3.fromRGB(255, 45, 120) or Color3.fromRGB(90, 110, 130)
			end
		end

		for _, deadRow in pairs(existingRows) do
			deadRow:Destroy()
		end

		if emptyCard then
			emptyCard.Visible = (count == 0)
			if count == 0 then
				ecLabel.Text = (searchTxt ~= "" or currentFilter ~= "ALL")
					and "NO CHEATERS MATCH FILTER"
					or "🛡️ NO CHEATERS DETECTED // SERVER CLEAN"
				ecLabel.TextColor3 = (searchTxt ~= "" or currentFilter ~= "ALL") and THEME.TextDim or Color3.fromRGB(0, 255, 140)
			end
		end

		local totalFlagged = 0
		for _ in pairs(ADMIN_SYS.cheatDetectedUsers) do totalFlagged = totalFlagged + 1 end
		cwBadgeText.Text = string.format("⚡ %d CHEATERS (%d ONLINE)", totalFlagged, onlineCount)
	end

	ADMIN_SYS.updateCheatLiveCards = function()
		if not cheatFrame or not cheatFrame.Visible then return end
		local totalCount = 0
		local onlineCount = 0

		for _, row in ipairs(scrollList:GetChildren()) do
			if row:IsA("Frame") and string.find(row.Name, "Cheat_") then
				totalCount = totalCount + 1
				local uidStr = string.gsub(row.Name, "Cheat_", "")
				local uid = tonumber(uidStr)
				local onlinePlr = uid and Players:GetPlayerByUserId(uid)
				local isOnline = (onlinePlr ~= nil)
				if isOnline then onlineCount = onlineCount + 1 end

				if row.Visible then
					local statusDot = row:FindFirstChild("StatusDot")
					if statusDot then
						statusDot.BackgroundColor3 = isOnline and Color3.fromRGB(255, 45, 120) or Color3.fromRGB(90, 110, 130)
					end

					local reasonLbl = row:FindFirstChild("ReasonLabel")
					local rec = ADMIN_SYS.cheatDetectedUsers[uidStr]
					if reasonLbl and rec then
						local rTxt, rCol = getFilteredReason(rec.reasons, currentFilter)
						reasonLbl.Text = rTxt
						reasonLbl.TextColor3 = rCol
					end

					local metaLbl = row:FindFirstChild("MetaLabel")
					if metaLbl and onlinePlr then
						local char = onlinePlr.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local hpStr = hum and string.format("HP: %.0f/%.0f", hum.Health, hum.MaxHealth) or "Dead/No Char"
						local distStr = ""
						if hrp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							local d = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
							distStr = string.format(" | Dist: %.0fm", d)
						end
						local catBadges = rec and getCategoryBadges(rec.reasons) or {}
						local badgeSummary = (#catBadges > 0) and ("[" .. table.concat(catBadges, " ") .. "] | ") or ""
						metaLbl.Text = string.format("%sTeam: %s | %s%s | Time: %s", badgeSummary, tostring(onlinePlr.Team and onlinePlr.Team.Name or "Unknown"), hpStr, distStr, tostring(rec and rec.lastDetected or "-"))
					end

					local btnContainer = row:FindFirstChild("BtnContainer")
					if btnContainer then
						local specBtn = btnContainer:FindFirstChild("SpecBtn")
						local specStroke = specBtn and specBtn:FindFirstChildOfClass("UIStroke")
						if specBtn then
							local isCurrentlySpec = (isSpectating and spectateTarget and onlinePlr and spectateTarget == onlinePlr)
							if isCurrentlySpec then
								specBtn.Text = "⏹ STOP SPEC"
								specBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 22)
								specBtn.TextColor3 = Color3.fromRGB(255, 210, 220)
								if specStroke then specStroke.Color = Color3.fromRGB(255, 60, 90) end
							elseif isOnline then
								specBtn.Text = "👁️ SPECTATE"
								specBtn.BackgroundColor3 = Color3.fromRGB(34, 16, 28)
								specBtn.TextColor3 = THEME.TextFrost
								if specStroke then specStroke.Color = Color3.fromRGB(255, 45, 120) end
							else
								specBtn.Text = "👁️ SPECTATE"
								specBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
								specBtn.TextColor3 = THEME.TextDim
								if specStroke then specStroke.Color = Color3.fromRGB(36, 36, 42) end
							end
						end
					end
				end
			end
		end

		if cwStopSpecFooterBtn then
			cwStopSpecFooterBtn.Visible = (isSpectating == true)
		end

		local totalFlagged = 0
		for _ in pairs(ADMIN_SYS.cheatDetectedUsers) do totalFlagged = totalFlagged + 1 end
		cwBadgeText.Text = string.format("⚡ %d CHEATERS (%d ONLINE)", totalFlagged, onlineCount)
	end

	task.spawn(function()
		while true do
			task.wait(2.0)
			if cheatFrame and cheatFrame.Visible then
				pcall(ADMIN_SYS.updateCheatLiveCards)
			end
		end
	end)

	local cwFooter = Instance.new("Frame")
	cwFooter.Size = UDim2.new(1, 0, 0, 40)
	cwFooter.Position = UDim2.new(0, 0, 1, -40)
	cwFooter.BackgroundColor3 = Color3.fromRGB(22, 14, 20)
	cwFooter.BorderSizePixel = 0
	cwFooter.Parent = cheatFrame

	local cwFooterCorner = Instance.new("UICorner")
	cwFooterCorner.CornerRadius = UDim.new(0, 10)
	cwFooterCorner.Parent = cwFooter

	local cwFooterStroke = Instance.new("UIStroke")
	cwFooterStroke.Color = Color3.fromRGB(56, 28, 44)
	cwFooterStroke.Thickness = 1
	cwFooterStroke.Parent = cwFooter

	local btnWatchdogToggle = Instance.new("TextButton")
	btnWatchdogToggle.Size = UDim2.new(0, 110, 0, 26)
	btnWatchdogToggle.Position = UDim2.new(0, 10, 0.5, -13)
	btnWatchdogToggle.BackgroundColor3 = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(36, 16, 28) or THEME.BtnOff
	btnWatchdogToggle.Font = Enum.Font.GothamBold
	btnWatchdogToggle.Text = ADMIN_SYS.isCheatWatchdogEnabled and "🛡️ WATCHDOG: ON" or "🛡️ WATCHDOG: OFF"
	btnWatchdogToggle.TextColor3 = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(255, 60, 140) or THEME.BtnOffText
	btnWatchdogToggle.TextSize = 9.5
	btnWatchdogToggle.Parent = cwFooter

	local wdCorner = Instance.new("UICorner")
	wdCorner.CornerRadius = UDim.new(0, 6)
	wdCorner.Parent = btnWatchdogToggle
	local wdStroke = Instance.new("UIStroke")
	wdStroke.Color = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(255, 45, 120) or THEME.BtnOffStroke
	wdStroke.Thickness = 1
	wdStroke.Parent = btnWatchdogToggle

	btnWatchdogToggle.MouseButton1Click:Connect(function()
		ADMIN_SYS.isCheatWatchdogEnabled = not ADMIN_SYS.isCheatWatchdogEnabled
		btnWatchdogToggle.BackgroundColor3 = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(36, 16, 28) or THEME.BtnOff
		btnWatchdogToggle.Text = ADMIN_SYS.isCheatWatchdogEnabled and "🛡️ WATCHDOG: ON" or "🛡️ WATCHDOG: OFF"
		btnWatchdogToggle.TextColor3 = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(255, 60, 140) or THEME.BtnOffText
		wdStroke.Color = ADMIN_SYS.isCheatWatchdogEnabled and Color3.fromRGB(255, 45, 120) or THEME.BtnOffStroke
	end)

	local btnClearAllCheats = Instance.new("TextButton")
	btnClearAllCheats.Size = UDim2.new(0, 84, 0, 26)
	btnClearAllCheats.Position = UDim2.new(0, 130, 0.5, -13)
	btnClearAllCheats.BackgroundColor3 = Color3.fromRGB(28, 16, 24)
	btnClearAllCheats.Font = Enum.Font.GothamBold
	btnClearAllCheats.Text = "🗑️ CLEAR"
	btnClearAllCheats.TextColor3 = Color3.fromRGB(220, 220, 225)
	btnClearAllCheats.TextSize = 9.5
	btnClearAllCheats.Parent = cwFooter

	local cacCorner = Instance.new("UICorner")
	cacCorner.CornerRadius = UDim.new(0, 6)
	cacCorner.Parent = btnClearAllCheats
	local cacStroke = Instance.new("UIStroke")
	cacStroke.Color = Color3.fromRGB(68, 30, 48)
	cacStroke.Thickness = 1
	cacStroke.Parent = btnClearAllCheats
	hookButtonHover(btnClearAllCheats, Color3.fromRGB(28, 16, 24), Color3.fromRGB(56, 20, 36), Color3.fromRGB(220, 220, 225), Color3.fromRGB(255, 255, 255))

	local confirmCheatClear = false
	btnClearAllCheats.MouseButton1Click:Connect(function()
		if not confirmCheatClear then
			confirmCheatClear = true
			btnClearAllCheats.Text = "SURE?"
			btnClearAllCheats.BackgroundColor3 = Color3.fromRGB(180, 25, 50)
			btnClearAllCheats.TextColor3 = Color3.fromRGB(255, 255, 255)
			task.delay(3, function()
				confirmCheatClear = false
				btnClearAllCheats.Text = "🗑️ CLEAR"
				btnClearAllCheats.BackgroundColor3 = Color3.fromRGB(28, 16, 24)
				btnClearAllCheats.TextColor3 = Color3.fromRGB(220, 220, 225)
			end)
		else
			confirmCheatClear = false
			btnClearAllCheats.Text = "🗑️ CLEAR"
			btnClearAllCheats.BackgroundColor3 = Color3.fromRGB(28, 16, 24)
			btnClearAllCheats.TextColor3 = Color3.fromRGB(220, 220, 225)
			ADMIN_SYS.clearAllDetectedCheats()
		end
	end)

	local cwFooterInfo = Instance.new("TextLabel")
	cwFooterInfo.Size = UDim2.new(0, 110, 1, 0)
	cwFooterInfo.Position = UDim2.new(1, -118, 0, 0)
	cwFooterInfo.BackgroundTransparency = 1
	cwFooterInfo.Font = Enum.Font.Gotham
	cwFooterInfo.Text = "⚡ EXPLOIT ENGINE"
	cwFooterInfo.TextColor3 = Color3.fromRGB(255, 80, 150)
	cwFooterInfo.TextSize = 8.5
	cwFooterInfo.TextXAlignment = Enum.TextXAlignment.Right
	cwFooterInfo.Parent = cwFooter

	cwStopSpecFooterBtn = Instance.new("TextButton")
	cwStopSpecFooterBtn.Name = "CwStopSpecFooterBtn"
	cwStopSpecFooterBtn.Size = UDim2.new(0, 96, 0, 26)
	cwStopSpecFooterBtn.Position = UDim2.new(0, 222, 0.5, -13)
	cwStopSpecFooterBtn.BackgroundColor3 = Color3.fromRGB(38, 16, 22)
	cwStopSpecFooterBtn.Font = Enum.Font.GothamBold
	cwStopSpecFooterBtn.Text = "⏹ STOP SPEC"
	cwStopSpecFooterBtn.TextColor3 = Color3.fromRGB(255, 210, 220)
	cwStopSpecFooterBtn.TextSize = 9.5
	cwStopSpecFooterBtn.Visible = (isSpectating == true)
	cwStopSpecFooterBtn.Parent = cwFooter

	local csfCorner = Instance.new("UICorner")
	csfCorner.CornerRadius = UDim.new(0, 6)
	csfCorner.Parent = cwStopSpecFooterBtn

	local csfStroke = Instance.new("UIStroke")
	csfStroke.Color = Color3.fromRGB(255, 60, 90)
	csfStroke.Thickness = 1
	csfStroke.Parent = cwStopSpecFooterBtn
	hookButtonHover(cwStopSpecFooterBtn, Color3.fromRGB(38, 16, 22), Color3.fromRGB(58, 20, 30), Color3.fromRGB(255, 210, 220), Color3.fromRGB(255, 255, 255))

	cwStopSpecFooterBtn.MouseButton1Click:Connect(function()
		stopSpectating()
		if ADMIN_SYS.updateCheatLiveCards then pcall(ADMIN_SYS.updateCheatLiveCards) end
	end)

	makeDraggable(cheatFrame, cwTopBar)
end


WIN_BUILDERS.buildStaffRadar = function()
	ADMIN_SYS.staffRadarBanner = Instance.new("Frame")
	local staffRadarBanner = ADMIN_SYS.staffRadarBanner
	staffRadarBanner.Name = "StaffRadarBanner"
	staffRadarBanner.AnchorPoint = Vector2.new(0.5, 0)
	staffRadarBanner.Size = UDim2.new(0, 440, 0, 44)
	staffRadarBanner.Position = UDim2.new(0.5, 0, 0, 16)
	staffRadarBanner.BackgroundColor3 = Color3.fromRGB(30, 8, 14)
	staffRadarBanner.BackgroundTransparency = 0.12
	staffRadarBanner.BorderSizePixel = 0
	staffRadarBanner.Visible = false
	staffRadarBanner.ZIndex = 60
	staffRadarBanner.Parent = getPinnedGui and getPinnedGui() or screenGui
	applyResponsiveWindowScale(staffRadarBanner, 440, 44, false)

	local srbCorner = Instance.new("UICorner")
	srbCorner.CornerRadius = UDim.new(0, 8)
	srbCorner.Parent = staffRadarBanner

	local srbStroke = Instance.new("UIStroke")
	srbStroke.Color = Color3.fromRGB(255, 60, 80)
	srbStroke.Thickness = 1.8
	srbStroke.Parent = staffRadarBanner
	applyNeonSweep(srbStroke, 110, 2.0, 1.6, 2.5)

	local srbDot = Instance.new("Frame")
	srbDot.Size = UDim2.new(0, 8, 0, 8)
	srbDot.Position = UDim2.new(0, 12, 0.5, -4)
	srbDot.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	srbDot.BorderSizePixel = 0
	srbDot.ZIndex = 61
	srbDot.Parent = staffRadarBanner
	local dotC = Instance.new("UICorner")
	dotC.CornerRadius = UDim.new(1, 0)
	dotC.Parent = srbDot

	local srbTitle = Instance.new("TextLabel")
	srbTitle.Size = UDim2.new(1, -55, 0, 18)
	srbTitle.Position = UDim2.new(0, 26, 0, 4)
	srbTitle.BackgroundTransparency = 1
	srbTitle.Font = Enum.Font.GothamBold
	srbTitle.Text = "🚨 STAFF / ADMIN DETECTED IN SERVER"
	srbTitle.TextColor3 = Color3.fromRGB(255, 90, 110)
	srbTitle.TextSize = 11
	srbTitle.TextXAlignment = Enum.TextXAlignment.Left
	srbTitle.ZIndex = 61
	srbTitle.Parent = staffRadarBanner

	local srbDetail = Instance.new("TextLabel")
	srbDetail.Name = "DetailText"
	srbDetail.Size = UDim2.new(1, -55, 0, 16)
	srbDetail.Position = UDim2.new(0, 26, 0, 22)
	srbDetail.BackgroundTransparency = 1
	srbDetail.Font = Enum.Font.Gotham
	srbDetail.Text = "Staff radar active..."
	srbDetail.TextColor3 = Color3.fromRGB(255, 210, 220)
	srbDetail.TextSize = 10
	srbDetail.TextXAlignment = Enum.TextXAlignment.Left
	srbDetail.ZIndex = 61
	srbDetail.Parent = staffRadarBanner

	local srbClose = Instance.new("TextButton")
	srbClose.Size = UDim2.new(0, 22, 0, 22)
	srbClose.Position = UDim2.new(1, -30, 0.5, -11)
	srbClose.BackgroundColor3 = Color3.fromRGB(50, 15, 25)
	srbClose.Font = Enum.Font.GothamBold
	srbClose.Text = "X"
	srbClose.TextColor3 = Color3.fromRGB(220, 220, 225)
	srbClose.TextSize = 10
	srbClose.ZIndex = 61
	srbClose.Parent = staffRadarBanner
	local srbClsC = Instance.new("UICorner")
	srbClsC.CornerRadius = UDim.new(0, 4)
	srbClsC.Parent = srbClose
	srbClose.MouseButton1Click:Connect(function()
		staffRadarBanner.Visible = false
	end)

	ADMIN_SYS.showStaffAlertBanner = function(sPlr, roleName, rank)
		if not ADMIN_SYS.isStaffRadarEnabled or not ADMIN_SYS.staffRadarBanner then return end
		pcall(function()
			srbDetail.Text = string.format("Staff: %s (@%s) | Role: %s (Rank: %d)", sPlr.DisplayName, sPlr.Name, roleName or "Staff", rank or 0)
			staffRadarBanner.Visible = true
			task.delay(10, function()
				if staffRadarBanner and staffRadarBanner.Visible then
					staffRadarBanner.Visible = false
				end
			end)
		end)
	end

	-- =================================================================
	-- ADMIN JOIN BUBBLE NOTIFICATION (BOTTOM-RIGHT CORNER WITH INTRO/OUTRO)
	-- =================================================================
	local bubbleFrame = Instance.new("Frame")
	bubbleFrame.Name = "AdminAlertBubble"
	bubbleFrame.Size = UDim2.new(0, 360, 0, 92)
	bubbleFrame.AnchorPoint = Vector2.new(1, 1)
	bubbleFrame.Position = UDim2.new(1, 390, 1, -20)
	bubbleFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
	bubbleFrame.BackgroundTransparency = 0.05
	bubbleFrame.BorderSizePixel = 0
	bubbleFrame.ZIndex = 120
	bubbleFrame.Visible = false
	bubbleFrame.Parent = getPinnedGui and getPinnedGui() or screenGui
	applyResponsiveWindowScale(bubbleFrame, 320, 80, false)

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 12)
	bCorner.Parent = bubbleFrame

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(255, 255, 255)
	bStroke.Thickness = 1.6
	bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bStroke.Parent = bubbleFrame
	applyNeonSweep(bStroke, 120, 2.2, 1.4, 2.4)

	local bGrad = Instance.new("UIGradient")
	bGrad.Rotation = 90
	bGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 32)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(18, 18, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12))
	})
	bGrad.Parent = bubbleFrame

	local avHolder = Instance.new("Frame")
	avHolder.Size = UDim2.new(0, 52, 0, 52)
	avHolder.Position = UDim2.new(0, 12, 0.5, -26)
	avHolder.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
	avHolder.BorderSizePixel = 0
	avHolder.ZIndex = 121
	avHolder.Parent = bubbleFrame

	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(0, 10)
	avCorner.Parent = avHolder

	local avStroke = Instance.new("UIStroke")
	avStroke.Color = Color3.fromRGB(200, 200, 205)
	avStroke.Thickness = 1.2
	avStroke.Parent = avHolder

	local avImg = Instance.new("ImageLabel")
	avImg.Size = UDim2.new(1, 0, 1, 0)
	avImg.BackgroundTransparency = 1
	avImg.ZIndex = 122
	avImg.Parent = avHolder
	local aviCorner = Instance.new("UICorner")
	aviCorner.CornerRadius = UDim.new(0, 10)
	aviCorner.Parent = avImg

	local avDot = Instance.new("Frame")
	avDot.Size = UDim2.new(0, 10, 0, 10)
	avDot.Position = UDim2.new(1, -6, 1, -6)
	avDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	avDot.BorderSizePixel = 0
	avDot.ZIndex = 123
	avDot.Parent = avHolder
	local avdCorner = Instance.new("UICorner")
	avdCorner.CornerRadius = UDim.new(1, 0)
	avdCorner.Parent = avDot

	local topTag = Instance.new("TextLabel")
	topTag.Size = UDim2.new(1, -110, 0, 16)
	topTag.Position = UDim2.new(0, 72, 0, 8)
	topTag.BackgroundTransparency = 1
	topTag.Font = Enum.Font.GothamBold
	topTag.Text = "🚨 ADMIN DETECTED // INCOMING STAFF"
	topTag.TextColor3 = Color3.fromRGB(255, 255, 255)
	topTag.TextSize = 9.5
	topTag.TextXAlignment = Enum.TextXAlignment.Left
	topTag.ZIndex = 121
	topTag.Parent = bubbleFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -26, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 40)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
	closeBtn.TextSize = 10.5
	closeBtn.ZIndex = 123
	closeBtn.Parent = bubbleFrame
	local cbC = Instance.new("UICorner")
	cbC.CornerRadius = UDim.new(0, 4)
	cbC.Parent = closeBtn

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -100, 0, 18)
	nameLbl.Position = UDim2.new(0, 72, 0, 26)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Text = "DisplayName (@Username)"
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextSize = 12
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.ZIndex = 121
	nameLbl.Parent = bubbleFrame

	local countLbl = Instance.new("TextLabel")
	countLbl.Size = UDim2.new(1, -100, 0, 16)
	countLbl.Position = UDim2.new(0, 72, 0, 46)
	countLbl.BackgroundTransparency = 1
	countLbl.Font = Enum.Font.GothamBold
	countLbl.Text = "🛡️ Admin คนที่: 1  ·  ยศ: Moderator"
	countLbl.TextColor3 = Color3.fromRGB(230, 230, 235)
	countLbl.TextSize = 10
	countLbl.TextXAlignment = Enum.TextXAlignment.Left
	countLbl.TextTruncate = Enum.TextTruncate.AtEnd
	countLbl.ZIndex = 121
	countLbl.Parent = bubbleFrame

	local timeLbl = Instance.new("TextLabel")
	timeLbl.Size = UDim2.new(1, -100, 0, 14)
	timeLbl.Position = UDim2.new(0, 72, 0, 64)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Font = Enum.Font.Gotham
	timeLbl.Text = "⏰ เข้ามาเมื่อเวลา: 00:00:00"
	timeLbl.TextColor3 = Color3.fromRGB(150, 150, 155)
	timeLbl.TextSize = 9
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left
	timeLbl.ZIndex = 121
	timeLbl.Parent = bubbleFrame

	local currentBubbleTween = nil
	local bubbleDismissThread = nil

	local function cancelBubbleDismiss()
		if bubbleDismissThread then
			local t = bubbleDismissThread
			bubbleDismissThread = nil
			if t ~= coroutine.running() then
				pcall(task.cancel, t)
			end
		end
	end

	local function dismissBubble()
		cancelBubbleDismiss()
		if currentBubbleTween then
			currentBubbleTween:Cancel()
			currentBubbleTween = nil
		end
		local outroTween = TweenService:Create(bubbleFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 390, 1, -20),
			BackgroundTransparency = 1
		})
		currentBubbleTween = outroTween
		outroTween:Play()
		outroTween.Completed:Connect(function()
			if bubbleFrame.Position.X.Offset >= 380 then
				bubbleFrame.Visible = false
			end
		end)
	end

	closeBtn.MouseButton1Click:Connect(dismissBubble)
	if closeBtn.Activated then
		closeBtn.Activated:Connect(dismissBubble)
	end

	ADMIN_SYS.showAdminJoinBubble = function(sPlr, roleName, rank, joinTime, adminIndex)
		if not sPlr then return end
		pcall(function()
			nameLbl.Text = string.format("%s (@%s)", sPlr.DisplayName, sPlr.Name)
			countLbl.Text = string.format("🛡️ Admin คนที่: %d  ·  ยศ: %s", adminIndex or 1, roleName or "Staff")
			timeLbl.Text = string.format("⏰ เข้ามาเมื่อเวลา: %s", joinTime or os.date("%H:%M:%S"))
			avImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(sPlr.UserId) .. "&w=150&h=150"

			cancelBubbleDismiss()
			if currentBubbleTween then
				currentBubbleTween:Cancel()
				currentBubbleTween = nil
			end

			bubbleFrame.Position = UDim2.new(1, 390, 1, -20)
			bubbleFrame.BackgroundTransparency = 0.1
			bubbleFrame.Visible = true

			local introTween = TweenService:Create(bubbleFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, -20),
				BackgroundTransparency = 0.1
			})
			currentBubbleTween = introTween
			introTween:Play()

			bubbleDismissThread = task.delay(7, function()
				dismissBubble()
			end)
		end)
	end

	-- =================================================================
	-- ⛔ BLACKLIST TARGET MOVED BUBBLE NOTIFICATION (BOTTOM-RIGHT CORNER)
	-- =================================================================
	local blBubbleFrame = Instance.new("Frame")
	blBubbleFrame.Name = "BlacklistAlertBubble"
	blBubbleFrame.Size = UDim2.new(0, 360, 0, 92)
	blBubbleFrame.AnchorPoint = Vector2.new(1, 1)
	blBubbleFrame.Position = UDim2.new(1, 390, 1, -120)
	blBubbleFrame.BackgroundColor3 = Color3.fromRGB(24, 12, 16)
	blBubbleFrame.BackgroundTransparency = 0.05
	blBubbleFrame.BorderSizePixel = 0
	blBubbleFrame.ZIndex = 125
	blBubbleFrame.Visible = false
	blBubbleFrame.Parent = getPinnedGui and getPinnedGui() or screenGui
	applyResponsiveWindowScale(blBubbleFrame, 320, 80, false)

	local blbCorner = Instance.new("UICorner")
	blbCorner.CornerRadius = UDim.new(0, 12)
	blbCorner.Parent = blBubbleFrame

	local blbStroke = Instance.new("UIStroke")
	blbStroke.Color = Color3.fromRGB(255, 40, 70)
	blbStroke.Thickness = 1.6
	blbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blbStroke.Parent = blBubbleFrame
	applyNeonSweep(blbStroke, 120, 2.2, 1.4, 2.4)

	local blAvImg = Instance.new("ImageLabel")
	blAvImg.Size = UDim2.new(0, 48, 0, 48)
	blAvImg.Position = UDim2.new(0, 12, 0.5, -24)
	blAvImg.BackgroundColor3 = Color3.fromRGB(36, 16, 22)
	blAvImg.ZIndex = 126
	blAvImg.Parent = blBubbleFrame
	local blAvCorner = Instance.new("UICorner")
	blAvCorner.CornerRadius = UDim.new(0, 8)
	blAvCorner.Parent = blAvImg

	local blTopTag = Instance.new("TextLabel")
	blTopTag.Size = UDim2.new(1, -70, 0, 16)
	blTopTag.Position = UDim2.new(0, 68, 0, 8)
	blTopTag.BackgroundTransparency = 1
	blTopTag.Font = Enum.Font.GothamBold
	blTopTag.Text = "⛔ BLACKLIST TARGET MOVED"
	blTopTag.TextColor3 = Color3.fromRGB(255, 60, 90)
	blTopTag.TextSize = 10.5
	blTopTag.TextXAlignment = Enum.TextXAlignment.Left
	blTopTag.ZIndex = 126
	blTopTag.Parent = blBubbleFrame

	local blNameLbl = Instance.new("TextLabel")
	blNameLbl.Size = UDim2.new(1, -150, 0, 18)
	blNameLbl.Position = UDim2.new(0, 68, 0, 26)
	blNameLbl.BackgroundTransparency = 1
	blNameLbl.Font = Enum.Font.GothamBold
	blNameLbl.Text = "DisplayName (@Username)"
	blNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	blNameLbl.TextSize = 11.5
	blNameLbl.TextXAlignment = Enum.TextXAlignment.Left
	blNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	blNameLbl.ZIndex = 126
	blNameLbl.Parent = blBubbleFrame

	local blLocLbl = Instance.new("TextLabel")
	blLocLbl.Size = UDim2.new(1, -150, 0, 16)
	blLocLbl.Position = UDim2.new(0, 68, 0, 46)
	blLocLbl.BackgroundTransparency = 1
	blLocLbl.Font = Enum.Font.Gotham
	blLocLbl.Text = "📍 In Server #2 (24/30)"
	blLocLbl.TextColor3 = Color3.fromRGB(255, 180, 190)
	blLocLbl.TextSize = 10
	blLocLbl.TextXAlignment = Enum.TextXAlignment.Left
	blLocLbl.TextTruncate = Enum.TextTruncate.AtEnd
	blLocLbl.ZIndex = 126
	blLocLbl.Parent = blBubbleFrame

	local blJoinBtn = Instance.new("TextButton")
	blJoinBtn.Size = UDim2.new(0, 72, 0, 24)
	blJoinBtn.Position = UDim2.new(1, -80, 0.5, -12)
	blJoinBtn.BackgroundColor3 = Color3.fromRGB(24, 48, 32)
	blJoinBtn.Font = Enum.Font.GothamBold
	blJoinBtn.Text = "🚀 JOIN"
	blJoinBtn.TextColor3 = Color3.fromRGB(140, 255, 180)
	blJoinBtn.TextSize = 9.5
	blJoinBtn.ZIndex = 126
	blJoinBtn.Parent = blBubbleFrame
	local bljCorner = Instance.new("UICorner")
	bljCorner.CornerRadius = UDim.new(0, 5)
	bljCorner.Parent = blJoinBtn
	local bljStroke = Instance.new("UIStroke")
	bljStroke.Color = Color3.fromRGB(40, 200, 100)
	bljStroke.Thickness = 1
	bljStroke.Parent = blJoinBtn

	local blCloseBtn = Instance.new("TextButton")
	blCloseBtn.Size = UDim2.new(0, 18, 0, 18)
	blCloseBtn.Position = UDim2.new(1, -22, 0, 6)
	blCloseBtn.BackgroundTransparency = 1
	blCloseBtn.Font = Enum.Font.GothamBold
	blCloseBtn.Text = "✕"
	blCloseBtn.TextColor3 = Color3.fromRGB(200, 120, 130)
	blCloseBtn.TextSize = 11
	blCloseBtn.ZIndex = 127
	blCloseBtn.Parent = blBubbleFrame

	local currentTargetServerId = nil
	blJoinBtn.MouseButton1Click:Connect(function()
		if currentTargetServerId then
			ADMIN_SYS.teleportToServer(currentTargetServerId)
		end
	end)

	local currentBlBubbleTween = nil
	local blBubbleDismissThread = nil

	local function dismissBlBubble()
		if blBubbleDismissThread then
			pcall(task.cancel, blBubbleDismissThread)
			blBubbleDismissThread = nil
		end
		if currentBlBubbleTween then
			currentBlBubbleTween:Cancel()
			currentBlBubbleTween = nil
		end
		local outro = TweenService:Create(blBubbleFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 390, 1, -120),
			BackgroundTransparency = 1
		})
		currentBlBubbleTween = outro
		outro:Play()
		outro.Completed:Connect(function()
			if blBubbleFrame.Position.X.Offset >= 380 then
				blBubbleFrame.Visible = false
			end
		end)
	end

	blCloseBtn.MouseButton1Click:Connect(dismissBlBubble)

	ADMIN_SYS.showBlacklistMoveBubble = function(blRec, loc)
		if not blRec or not loc then return end
		currentTargetServerId = loc.serverId
		pcall(function()
			blNameLbl.Text = string.format("%s (@%s)", blRec.displayName or blRec.name or "User", blRec.name or "Unknown")
			blLocLbl.Text = string.format("📍 %s (%d/%d คน)", loc.serverTitle or loc.serverId, loc.total or 0, loc.max or 60)
			blAvImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(blRec.userId) .. "&w=150&h=150"

			if blBubbleDismissThread then
				pcall(task.cancel, blBubbleDismissThread)
				blBubbleDismissThread = nil
			end
			if currentBlBubbleTween then
				currentBlBubbleTween:Cancel()
				currentBlBubbleTween = nil
			end

			blBubbleFrame.Position = UDim2.new(1, 390, 1, -120)
			blBubbleFrame.BackgroundTransparency = 0.1
			blBubbleFrame.Visible = true

			local intro = TweenService:Create(blBubbleFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, -120),
				BackgroundTransparency = 0.1
			})
			currentBlBubbleTween = intro
			intro:Play()

			blBubbleDismissThread = task.delay(10, function()
				dismissBlBubble()
			end)
		end)
	end

	-- =================================================================
	-- 💉 EXPLOIT / EXECUTOR DETECTED BUBBLE NOTIFICATION (BOTTOM-RIGHT CORNER)
	-- =================================================================
	local expBubbleFrame = Instance.new("Frame")
	expBubbleFrame.Name = "ExploitAlertBubble"
	expBubbleFrame.Size = UDim2.new(0, 360, 0, 92)
	expBubbleFrame.AnchorPoint = Vector2.new(1, 1)
	expBubbleFrame.Position = UDim2.new(1, 390, 1, -220)
	expBubbleFrame.BackgroundColor3 = Color3.fromRGB(24, 10, 20)
	expBubbleFrame.BackgroundTransparency = 0.05
	expBubbleFrame.BorderSizePixel = 0
	expBubbleFrame.ZIndex = 130
	expBubbleFrame.Visible = false
	expBubbleFrame.Parent = getPinnedGui and getPinnedGui() or screenGui
	applyResponsiveWindowScale(expBubbleFrame, 320, 80, false)

	local expCorner = Instance.new("UICorner")
	expCorner.CornerRadius = UDim.new(0, 12)
	expCorner.Parent = expBubbleFrame

	local expStroke = Instance.new("UIStroke")
	expStroke.Color = Color3.fromRGB(255, 45, 120)
	expStroke.Thickness = 1.8
	expStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	expStroke.Parent = expBubbleFrame
	applyNeonSweep(expStroke, 120, 2.5, 1.4, 2.4)

	local expAvImg = Instance.new("ImageLabel")
	expAvImg.Size = UDim2.new(0, 48, 0, 48)
	expAvImg.Position = UDim2.new(0, 12, 0.5, -24)
	expAvImg.BackgroundColor3 = Color3.fromRGB(36, 16, 36)
	expAvImg.ZIndex = 131
	expAvImg.Parent = expBubbleFrame
	local expAvCorner = Instance.new("UICorner")
	expAvCorner.CornerRadius = UDim.new(0, 10)
	expAvCorner.Parent = expAvImg

	local expTopTag = Instance.new("TextLabel")
	expTopTag.Size = UDim2.new(1, -110, 0, 16)
	expTopTag.Position = UDim2.new(0, 68, 0, 8)
	expTopTag.BackgroundTransparency = 1
	expTopTag.Font = Enum.Font.GothamBold
	expTopTag.Text = "💉 EXECUTOR / EXPLOIT DETECTED"
	expTopTag.TextColor3 = Color3.fromRGB(255, 60, 130)
	expTopTag.TextSize = 9.5
	expTopTag.TextXAlignment = Enum.TextXAlignment.Left
	expTopTag.ZIndex = 131
	expTopTag.Parent = expBubbleFrame

	local expNameLbl = Instance.new("TextLabel")
	expNameLbl.Size = UDim2.new(1, -150, 0, 18)
	expNameLbl.Position = UDim2.new(0, 68, 0, 25)
	expNameLbl.BackgroundTransparency = 1
	expNameLbl.Font = Enum.Font.GothamBold
	expNameLbl.Text = "DisplayName (@Username)"
	expNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	expNameLbl.TextSize = 11.5
	expNameLbl.TextXAlignment = Enum.TextXAlignment.Left
	expNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	expNameLbl.ZIndex = 131
	expNameLbl.Parent = expBubbleFrame

	local expDetailLbl = Instance.new("TextLabel")
	expDetailLbl.Size = UDim2.new(1, -150, 0, 16)
	expDetailLbl.Position = UDim2.new(0, 68, 0, 45)
	expDetailLbl.BackgroundTransparency = 1
	expDetailLbl.Font = Enum.Font.GothamBold
	expDetailLbl.Text = "⚡ Speed Hack: 45.2 studs/s"
	expDetailLbl.TextColor3 = Color3.fromRGB(255, 175, 90)
	expDetailLbl.TextSize = 9.5
	expDetailLbl.TextXAlignment = Enum.TextXAlignment.Left
	expDetailLbl.TextTruncate = Enum.TextTruncate.AtEnd
	expDetailLbl.ZIndex = 131
	expDetailLbl.Parent = expBubbleFrame

	local expTimeLbl = Instance.new("TextLabel")
	expTimeLbl.Size = UDim2.new(1, -150, 0, 14)
	expTimeLbl.Position = UDim2.new(0, 68, 0, 64)
	expTimeLbl.BackgroundTransparency = 1
	expTimeLbl.Font = Enum.Font.Gotham
	expTimeLbl.Text = "⏰ เวลาที่ตรวจจับ: 00:00:00"
	expTimeLbl.TextColor3 = Color3.fromRGB(160, 150, 165)
	expTimeLbl.TextSize = 8.5
	expTimeLbl.TextXAlignment = Enum.TextXAlignment.Left
	expTimeLbl.ZIndex = 131
	expTimeLbl.Parent = expBubbleFrame

	ADMIN_SYS.expTargetPlr = nil
	local expSpecBtn = Instance.new("TextButton")
	expSpecBtn.Size = UDim2.new(0, 62, 0, 24)
	expSpecBtn.Position = UDim2.new(1, -72, 0.5, -4)
	expSpecBtn.BackgroundColor3 = Color3.fromRGB(48, 16, 36)
	expSpecBtn.Font = Enum.Font.GothamBold
	expSpecBtn.Text = "👁️ Spec"
	expSpecBtn.TextColor3 = Color3.fromRGB(255, 100, 180)
	expSpecBtn.TextSize = 9.5
	expSpecBtn.ZIndex = 132
	expSpecBtn.Parent = expBubbleFrame

	local expSpecCorner = Instance.new("UICorner")
	expSpecCorner.CornerRadius = UDim.new(0, 4)
	expSpecCorner.Parent = expSpecBtn

	local expSpecStroke = Instance.new("UIStroke")
	expSpecStroke.Color = Color3.fromRGB(255, 60, 130)
	expSpecStroke.Thickness = 1
	expSpecStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	expSpecStroke.Parent = expSpecBtn

	expSpecBtn.MouseButton1Click:Connect(function()
		local tPlr = ADMIN_SYS.expTargetPlr
		if tPlr and tPlr.Parent then
			pcall(spectatePlayer, tPlr)
		end
	end)

	local expBodyBtn = Instance.new("TextButton")
	expBodyBtn.Size = UDim2.new(1, -78, 1, 0)
	expBodyBtn.BackgroundTransparency = 1
	expBodyBtn.Text = ""
	expBodyBtn.ZIndex = 131
	expBodyBtn.Parent = expBubbleFrame
	expBodyBtn.MouseButton1Click:Connect(function()
		ADMIN_SYS.toggleCheatGui()
	end)

	local expCloseBtn = Instance.new("TextButton")
	expCloseBtn.Size = UDim2.new(0, 20, 0, 20)
	expCloseBtn.Position = UDim2.new(1, -26, 0, 6)
	expCloseBtn.BackgroundColor3 = Color3.fromRGB(36, 20, 36)
	expCloseBtn.Font = Enum.Font.GothamBold
	expCloseBtn.Text = "X"
	expCloseBtn.TextColor3 = Color3.fromRGB(220, 200, 225)
	expCloseBtn.TextSize = 10.5
	expCloseBtn.ZIndex = 133
	expCloseBtn.Parent = expBubbleFrame

	local expCloseCorner = Instance.new("UICorner")
	expCloseCorner.CornerRadius = UDim.new(0, 4)
	expCloseCorner.Parent = expCloseBtn

	local currentExpBubbleTween = nil
	local expBubbleDismissThread = nil

	local function dismissExpBubble()
		if expBubbleDismissThread then
			pcall(task.cancel, expBubbleDismissThread)
			expBubbleDismissThread = nil
		end
		if currentExpBubbleTween then
			currentExpBubbleTween:Cancel()
			currentExpBubbleTween = nil
		end
		local outro = TweenService:Create(expBubbleFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 390, 1, -220),
			BackgroundTransparency = 1
		})
		currentExpBubbleTween = outro
		outro:Play()
		outro.Completed:Connect(function()
			if expBubbleFrame.Position.X.Offset >= 380 then
				expBubbleFrame.Visible = false
			end
		end)
	end

	ADMIN_SYS.dismissExpBubble = dismissExpBubble
	expCloseBtn.MouseButton1Click:Connect(dismissExpBubble)

	ADMIN_SYS.showExploitAlertBubble = function(sPlr, detectType, detail)
		if not sPlr or isStaffOrAdmin(sPlr) then return end
		ADMIN_SYS.expTargetPlr = sPlr
		pcall(function()
			expNameLbl.Text = string.format("%s (@%s)", sPlr.DisplayName, sPlr.Name)
			local catTitle = "💉 EXECUTOR"
			local catColor = Color3.fromRGB(255, 45, 120)
			if detectType == "speed_hack" or detectType == "fly_hack" or detectType == "cframe_teleport" or detectType == "infinite_jump" or detectType == "spinbot_fling" then
				catTitle = "⚡ MOVEMENT"
				catColor = Color3.fromRGB(255, 80, 80)
			elseif detectType == "anim_spam" then
				catTitle = "💬 CHAT & LAG"
				catColor = Color3.fromRGB(255, 120, 200)
			end
			expTopTag.Text = string.format("%s // %s", catTitle, string.upper(detectType or "DETECTED"))
			expTopTag.TextColor3 = catColor
			expStroke.Color = catColor
			expDetailLbl.Text = tostring(detail or "Exploit Detected")
			expTimeLbl.Text = string.format("⏰ ตรวจพบเวลา: %s", os.date("%H:%M:%S"))
			expAvImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(sPlr.UserId) .. "&w=150&h=150"

			if expBubbleDismissThread then
				pcall(task.cancel, expBubbleDismissThread)
				expBubbleDismissThread = nil
			end
			if currentExpBubbleTween then
				currentExpBubbleTween:Cancel()
				currentExpBubbleTween = nil
			end

			expBubbleFrame.Position = UDim2.new(1, 390, 1, -220)
			expBubbleFrame.BackgroundTransparency = 0.05
			expBubbleFrame.Visible = true

			local intro = TweenService:Create(expBubbleFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -20, 1, -220),
				BackgroundTransparency = 0.05
			})
			currentExpBubbleTween = intro
			intro:Play()

			expBubbleDismissThread = task.delay(8, function()
				dismissExpBubble()
			end)
		end)
	end
end

WIN_BUILDERS.buildServerStaff = function()
	local W, H = 640, 520
	local SS_RED = Color3.fromRGB(255, 100, 120)
	local SS_HIDDEN = Color3.fromRGB(200, 150, 255)

	local ssFrame = Instance.new("Frame")
	ssFrame.Name = "ServerStaffWindow"
	ssFrame.Size = UDim2.new(0, W, 0, H)
	ssFrame.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
	ssFrame.BackgroundColor3 = THEME.MainBg
	ssFrame.BackgroundTransparency = THEME.MainBgTransparency
	ssFrame.BorderSizePixel = 0
	ssFrame.Visible = false
	ssFrame.ClipsDescendants = true
	ssFrame.Parent = screenGui
	ADMIN_SYS.serverStaffWindow = ssFrame
	applyResponsiveWindowScale(ssFrame, W, H, true)

	ssFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if ssFrame.Visible then
			pcall(ADMIN_SYS.decorateNativeServerList)
		end
	end)

	local function addCorner2(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
		return c
	end

	local function addStroke2(inst, color, thickness)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness or 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
		return s
	end

	local function mkLabel(parent, text, size, color, pos, sz, bold, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextSize = size
		l.TextColor3 = color
		l.Position = pos
		l.Size = sz
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end

	addCorner2(ssFrame, 10)

	local ssBevel = Instance.new("UIGradient")
	ssBevel.Rotation = 90
	ssBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	ssBevel.Parent = ssFrame

	local ssStroke = Instance.new("UIStroke")
	ssStroke.Thickness = 2.0
	ssStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ssStroke.Parent = ssFrame
	applyNeonSweep(ssStroke, 110, 2.5, 1.8, 2.6)

	-- Top bar
	local ssTopBar = Instance.new("Frame")
	ssTopBar.Size = UDim2.new(1, 0, 0, 42)
	ssTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	ssTopBar.BorderSizePixel = 0
	ssTopBar.Parent = ssFrame
	addCorner2(ssTopBar, 10)
	addStroke2(ssTopBar, Color3.fromRGB(48, 48, 54), 1)

	local ssDot = Instance.new("Frame")
	ssDot.Size = UDim2.new(0, 7, 0, 7)
	ssDot.Position = UDim2.new(0, 12, 0.5, -3.5)
	ssDot.BackgroundColor3 = Color3.fromRGB(255, 60, 100)
	ssDot.BorderSizePixel = 0
	ssDot.Parent = ssTopBar
	addCorner2(ssDot, 4)

	local ssTitle = mkLabel(ssTopBar, "ASTROCYNA // CROSS-SERVER SCANNER", 10.5, THEME.TextCyan, UDim2.new(0, 25, 0, 0), UDim2.new(0, 260, 1, 0), true)
	applyTextShimmer(ssTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local ssBadge = Instance.new("Frame")
	ssBadge.Size = UDim2.new(0, 250, 0, 24)
	ssBadge.Position = UDim2.new(1, -330, 0.5, -12)
	ssBadge.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	ssBadge.Parent = ssTopBar
	addCorner2(ssBadge, 5)
	addStroke2(ssBadge, Color3.fromRGB(255, 80, 110), 1)
	local ssBadgeText = mkLabel(ssBadge, "0 STAFF · 0 BLOCKED · 0 SERVERS", 8.5, Color3.fromRGB(220, 220, 225), UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), true, Enum.TextXAlignment.Center)
	ssBadgeText.TextTruncate = Enum.TextTruncate.None

	attachAlwaysOnTopButton(ssFrame, ssTopBar, "ServerStaffWindow", -70, 8, 28, 26)

	local ssClose = Instance.new("TextButton")
	ssClose.Size = UDim2.new(0, 28, 0, 26)
	ssClose.Position = UDim2.new(1, -36, 0, 8)
	ssClose.BackgroundColor3 = THEME.BtnOff
	ssClose.Font = Enum.Font.GothamBold
	ssClose.Text = "X"
	ssClose.TextColor3 = THEME.TextCyan
	ssClose.TextSize = 13
	ssClose.AutoButtonColor = false
	ssClose.Parent = ssTopBar
	addCorner2(ssClose, 6)
	addStroke2(ssClose, Color3.fromRGB(28, 60, 94), 1)
	hookButtonHover(ssClose, THEME.BtnOff, Color3.fromRGB(48, 20, 32), THEME.TextCyan, Color3.fromRGB(220, 220, 225))
	ssClose.MouseButton1Click:Connect(function()
		ssFrame.Visible = false
	end)

	-- Toolbar
	local function makeToolBtn(text, x, width)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, width, 0, 26)
		b.Position = UDim2.new(0, x, 0, 50)
		b.BackgroundColor3 = THEME.BtnOff
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.TextColor3 = THEME.TextCyan
		b.TextSize = 9.5
		b.AutoButtonColor = false
		b.Parent = ssFrame
		addCorner2(b, 6)
		addStroke2(b, THEME.BtnOffStroke, 1)
		return b
	end

	local refreshBtn = makeToolBtn("REFRESH ROSTER", 12, 114)
	local filterBtn = makeToolBtn("VIEW: STAFF ONLY", 134, 154)
	local nativeBtn = makeToolBtn("NATIVE LIST REVEAL: ON", 296, 180)

	local ssStatus = mkLabel(ssFrame, "Roster: loading...", 9.5, THEME.TextDim, UDim2.new(0, 14, 0, 82), UDim2.new(1, -28, 0, 16), false)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Name = "ServerList"
	listScroll.Position = UDim2.new(0, 10, 0, 104)
	listScroll.Size = UDim2.new(1, -20, 1, -114)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 3
	listScroll.ScrollBarImageColor3 = THEME.CyanPrimary
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.Parent = ssFrame
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listScroll

	local showMode = "STAFF" -- "STAFF", "BLACKLIST", "SAVED_BLACKLIST", "ALL"
	local lastSig = nil

	local function render(force)
		local scan = ADMIN_SYS.scanServerStaff()
		local rosterCount = 0
		for _ in pairs(ADMIN_SYS.serverStaffRoster) do rosterCount = rosterCount + 1 end

		local totalStaff, serversWithStaff = 0, 0
		local totalBlacklist, serversWithBlacklist = 0, 0
		local totalSaved = 0
		local allBl = ADMIN_SYS.getBlacklistedUsers and ADMIN_SYS.getBlacklistedUsers() or {}
		for _ in pairs(allBl) do
			totalSaved = totalSaved + 1
		end

		local sigParts = { showMode, tostring(rosterCount), tostring(totalSaved) }
		if showMode == "SAVED_BLACKLIST" then
			for idStr in pairs(allBl) do
				sigParts[#sigParts + 1] = "SBL:" .. idStr
			end
		elseif showMode == "BLACKLIST" then
			for _, e in ipairs(scan) do
				local bCount = e.blacklist and #e.blacklist or 0
				if bCount > 0 then
					serversWithBlacklist = serversWithBlacklist + 1
					totalBlacklist = totalBlacklist + bCount
					local ids = {}
					for _, b in ipairs(e.blacklist) do ids[#ids + 1] = b.idStr end
					sigParts[#sigParts + 1] = e.id .. ":BL:" .. table.concat(ids, ",")
				end
			end
		elseif showMode == "STAFF" then
			for _, e in ipairs(scan) do
				if #e.staff > 0 then
					serversWithStaff = serversWithStaff + 1
					totalStaff = totalStaff + #e.staff
					local ids = {}
					for _, s in ipairs(e.staff) do ids[#ids + 1] = s.idStr .. (s.incognito and ":i" or "") end
					sigParts[#sigParts + 1] = e.id .. ":ST:" .. table.concat(ids, ",")
				end
			end
		else -- "ALL"
			for i = 1, math.min(#scan, 50) do
				local e = scan[i]
				if #e.staff > 0 then totalStaff = totalStaff + #e.staff; serversWithStaff = serversWithStaff + 1 end
				local bCount = e.blacklist and #e.blacklist or 0
				if bCount > 0 then totalBlacklist = totalBlacklist + bCount; serversWithBlacklist = serversWithBlacklist + 1 end
				sigParts[#sigParts + 1] = e.id .. ":" .. tostring(#e.staff) .. ":" .. tostring(bCount)
			end
		end

		ssBadgeText.Text = string.format("%d STAFF · %d BLOCKED (%d SAVED) · %d SERVERS", totalStaff, totalBlacklist, totalSaved, #scan)
		if showMode == "SAVED_BLACKLIST" then
			ssStatus.Text = string.format("Blacklist Vault: %d saved targets · Click [UNLIST] to remove from blacklist", totalSaved)
		elseif showMode == "BLACKLIST" then
			ssStatus.Text = string.format("Active Blacklist: %d targets spotted in %d servers · Click [UNLIST] to remove", totalBlacklist, serversWithBlacklist)
		elseif rosterCount > 0 then
			ssStatus.Text = string.format("Roster: %d staff · Hidden staff tracked in realtime across all servers", rosterCount)
		else
			ssStatus.Text = "Roster loading · Hidden staff tracked across all servers"
		end

		local sig = table.concat(sigParts, "|")
		if sig == lastSig and not force then
			-- Lightning-fast in-place player count update without destroying or rebuilding UI
			local byId = {}
			for _, e in ipairs(scan) do byId[e.id] = e end
			for _, child in ipairs(listScroll:GetChildren()) do
				if child:IsA("GuiObject") and child.Name:sub(1, 4) == "Row_" then
					local srvId = child:GetAttribute("ServerId")
					local metaLbl = child:FindFirstChild("MetaLabel")
					if srvId and metaLbl and metaLbl:IsA("TextLabel") and byId[srvId] then
						local e = byId[srvId]
						local metaParts = {}
						if e.category and e.category ~= "" then table.insert(metaParts, e.category) end
						if e.serverType and e.serverType ~= "" then table.insert(metaParts, e.serverType) end
						table.insert(metaParts, string.format("👥 %d / %d players", e.total, e.max))
						metaLbl.Text = table.concat(metaParts, "  ·  ")
				end
			end
		end
			return
		end
		lastSig = sig

		for _, child in ipairs(listScroll:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end

		local order = 0

		-- Dedicated Saved Blacklist Management View
		if showMode == "SAVED_BLACKLIST" then
			local savedList = {}
			local seenIds = {}
			for rawKey, rec in pairs(allBl) do
				local idStr = tostring(rawKey)
				local numId = tonumber(idStr) or 0
				if numId > 0 and not seenIds[idStr] then
					seenIds[idStr] = true
					table.insert(savedList, {
						idStr = idStr,
						userId = numId,
						name = rec.Name or rec.name or idStr,
						displayName = rec.DisplayName or rec.displayName or rec.Name or rec.name or idStr,
						addedAt = rec.AddedAt or rec.addedAt or 0
					})
				end
			end
			table.sort(savedList, function(a, b) return a.addedAt > b.addedAt end)

			for _, b in ipairs(savedList) do
				order = order + 1
				local row = Instance.new("Frame")
				row.Name = "SavedBL_" .. b.idStr
				row.Size = UDim2.new(1, -8, 0, 48)
				row.BackgroundColor3 = THEME.CardBg
				row.BorderSizePixel = 0
				row.LayoutOrder = order
				row.Parent = listScroll
				addCorner2(row, 8)
				addStroke2(row, Color3.fromRGB(200, 35, 55), 1)

				local loc = ADMIN_SYS.locateBlacklistedPlayer and ADMIN_SYS.locateBlacklistedPlayer(b.userId)
				local locText = "🔴 Offline / Inactive"
				local locColor = THEME.TextDim
				if loc and loc.status == "CURRENT_SERVER" then
					locText = "🟢 Active in This Server"
					locColor = Color3.fromRGB(100, 255, 160)
				elseif loc and loc.status == "OTHER_SERVER" then
					locText = string.format("📍 In %s (👥 %d/%d)", loc.serverTitle or "Server", loc.total or 0, loc.max or 60)
					locColor = Color3.fromRGB(120, 220, 255)
			end

				local dispStr = (b.displayName and b.displayName ~= b.name) and (" (" .. b.displayName .. ")") or ""
				mkLabel(row, "⛔ @" .. b.name .. dispStr, 11, Color3.fromRGB(255, 120, 140), UDim2.new(0, 12, 0, 6), UDim2.new(1, -125, 0, 18), true)

				local metaStr = string.format("ID: %s   ·   %s", b.idStr, locText)
				mkLabel(row, metaStr, 9.5, locColor, UDim2.new(0, 12, 0, 25), UDim2.new(1, -125, 0, 16), false)

				local unblBtn = Instance.new("TextButton")
				unblBtn.Size = UDim2.new(0, 96, 0, 24)
				unblBtn.Position = UDim2.new(1, -106, 0.5, -12)
				unblBtn.BackgroundColor3 = Color3.fromRGB(42, 14, 20)
				unblBtn.Font = Enum.Font.GothamBold
				unblBtn.Text = "🗑️ UNLIST"
				unblBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
				unblBtn.TextSize = 8.5
				unblBtn.AutoButtonColor = false
				unblBtn.Parent = row
				addCorner2(unblBtn, 5)
				addStroke2(unblBtn, Color3.fromRGB(255, 60, 80), 1)
				hookButtonHover(unblBtn, Color3.fromRGB(42, 14, 20), Color3.fromRGB(65, 20, 30), Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 255, 255))
				unblBtn.MouseButton1Click:Connect(function()
					ADMIN_SYS.unblacklistUserId(b.idStr)
					render(true)
				end)
			end

			if order == 0 then
				local empty = mkLabel(listScroll, "No blacklisted players saved in your system.", 11, THEME.TextDim, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 40), false, Enum.TextXAlignment.Center)
				empty.LayoutOrder = 1
			end
			return
		end

		for _, e in ipairs(scan) do
			local staffCount = #e.staff
			local blacklistCount = e.blacklist and #e.blacklist or 0
			local shouldShow = false
			if showMode == "ALL" then
				shouldShow = true
			elseif showMode == "BLACKLIST" then
				shouldShow = (blacklistCount > 0)
			else
				shouldShow = (staffCount > 0)
			end

			if shouldShow then
				if showMode == "ALL" and order >= 50 then
					break
				end
				order = order + 1
				local totalLines = staffCount + blacklistCount
				local rowH = 44 + totalLines * 20 + (totalLines > 0 and 6 or 0)
				local row = Instance.new("Frame")
				row.Name = "Row_" .. e.id
				row:SetAttribute("ServerId", e.id)
				row.Size = UDim2.new(1, -8, 0, rowH)
				row.BackgroundColor3 = THEME.CardBg
				row.BorderSizePixel = 0
				row.LayoutOrder = order
				row.Parent = listScroll
				addCorner2(row, 8)

				local rowStrokeColor = THEME.CardStroke
				if blacklistCount > 0 then
					rowStrokeColor = Color3.fromRGB(255, 40, 70)
				elseif staffCount > 0 then
					rowStrokeColor = Color3.fromRGB(120, 40, 60)
				end
				addStroke2(row, rowStrokeColor, 1)

				-- 1. Line 1 Right-Side Elements: Status Pills
				local xOffset = -10

				if staffCount > 0 then
					local sPill = Instance.new("Frame")
					sPill.Size = UDim2.new(0, 76, 0, 20)
					sPill.Position = UDim2.new(1, xOffset - 76, 0, 8)
					sPill.BackgroundColor3 = Color3.fromRGB(60, 16, 28)
					sPill.BorderSizePixel = 0
					sPill.Parent = row
					addCorner2(sPill, 5)
					addStroke2(sPill, Color3.fromRGB(255, 70, 100), 1)
					local sText = mkLabel(sPill, string.format("%d STAFF", staffCount), 9.0, Color3.fromRGB(220, 220, 225), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)
					sText.TextTruncate = Enum.TextTruncate.None
					xOffset = xOffset - 82
				end

				if blacklistCount > 0 then
					local blPill = Instance.new("Frame")
					blPill.Size = UDim2.new(0, 88, 0, 20)
					blPill.Position = UDim2.new(1, xOffset - 88, 0, 8)
					blPill.BackgroundColor3 = Color3.fromRGB(60, 12, 20)
					blPill.BorderSizePixel = 0
					blPill.Parent = row
					addCorner2(blPill, 5)
					addStroke2(blPill, Color3.fromRGB(255, 50, 70), 1)
					local blText = mkLabel(blPill, string.format("⛔ %d BLOCKED", blacklistCount), 9.0, Color3.fromRGB(255, 120, 140), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)
					blText.TextTruncate = Enum.TextTruncate.None
					xOffset = xOffset - 94
				end

				-- 2. Line 1 Left-Side: Server Title (dynamically width-bounded)
				local titleText = e.title .. (e.isCurrent and "   (YOU ARE HERE)" or "")
				local titleColor = e.isCurrent and THEME.TextCyan or (blacklistCount > 0 and Color3.fromRGB(255, 120, 140) or THEME.TextFrost)
				local titleBound = math.abs(xOffset) + 10
				mkLabel(row, titleText, 11.5, titleColor, UDim2.new(0, 12, 0, 6), UDim2.new(1, -titleBound, 0, 18), true)

				-- 3. Line 2: Category / Mode / Player count cleanly unified on Left (no overlap with action buttons)
				local metaParts = {}
				if e.category and e.category ~= "" then table.insert(metaParts, e.category) end
				if e.serverType and e.serverType ~= "" then table.insert(metaParts, e.serverType) end
				table.insert(metaParts, string.format("👥 %d / %d players", e.total, e.max))
				local subText = table.concat(metaParts, "  ·  ")
				local subLbl = mkLabel(row, subText, 9.5, THEME.TextDim, UDim2.new(0, 12, 0, 25), UDim2.new(1, -titleBound, 0, 14), false)
				subLbl.Name = "MetaLabel"

				local lineY = 44
				-- 1. List blacklisted users first with instant UNLIST button
				if e.blacklist then
					for _, b in ipairs(e.blacklist) do
						local who = b.name and ("@" .. b.name) or ("ID " .. b.idStr)
						local disp = (b.displayName and b.displayName ~= b.name) and (" (" .. b.displayName .. ")") or ""
						local line = string.format("⛔  %s%s   ·   [BLACKLISTED TARGET]", who, disp)
						mkLabel(row, line, 10, Color3.fromRGB(255, 70, 90), UDim2.new(0, 14, 0, lineY), UDim2.new(1, -114, 0, 18), true)

						local unblBtn = Instance.new("TextButton")
						unblBtn.Size = UDim2.new(0, 84, 0, 18)
						unblBtn.Position = UDim2.new(1, -94, 0, lineY)
						unblBtn.BackgroundColor3 = Color3.fromRGB(40, 14, 20)
						unblBtn.Font = Enum.Font.GothamBold
						unblBtn.Text = "🗑️ UNLIST"
						unblBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
						unblBtn.TextSize = 8.5
						unblBtn.AutoButtonColor = false
						unblBtn.Parent = row
						addCorner2(unblBtn, 4)
						addStroke2(unblBtn, Color3.fromRGB(255, 60, 80), 1)
						hookButtonHover(unblBtn, Color3.fromRGB(40, 14, 20), Color3.fromRGB(60, 20, 30), Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 255, 255))
						unblBtn.MouseButton1Click:Connect(function()
							ADMIN_SYS.unblacklistUserId(b.idStr)
							render(true)
						end)

						lineY = lineY + 20
					end
				end

				-- 2. List staff
				for _, s in ipairs(e.staff) do
					local who = s.name and ("@" .. s.name) or ("ID " .. s.idStr)
					local line = string.format("●  %s   ·   %s%s", who, s.role or "Staff", (s.rank and s.rank > 0) and (" (Rank " .. tostring(s.rank) .. ")") or "")
					if s.incognito then line = line .. "   [INCOGNITO]" end
					mkLabel(row, line, 10, s.incognito and SS_HIDDEN or SS_RED, UDim2.new(0, 14, 0, lineY), UDim2.new(1, -28, 0, 18), true)
					lineY = lineY + 20
				end
			end
		end

		if order == 0 then
			local emptyMsg = "No entries detected right now."
			if showMode == "BLACKLIST" then
				emptyMsg = "No blacklisted targets detected in any other server right now."
			elseif showMode == "STAFF" then
				emptyMsg = "No staff detected in any server right now."
			elseif showMode == "SAVED_BLACKLIST" then
				emptyMsg = "No blacklisted players saved in your system."
			end
			local empty = mkLabel(listScroll, emptyMsg, 11, THEME.TextDim, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 40), false, Enum.TextXAlignment.Center)
			empty.LayoutOrder = 1
		end
	end

	ADMIN_SYS.refreshServerStaffGui = function(force)
		if not ssFrame.Visible then return end
		pcall(render, force == true)
	end

	ADMIN_SYS.showServerBrowserForBlacklist = function()
		local totalActiveBl = 0
		for _, e in ipairs(ADMIN_SYS.scanServerStaff()) do
			if e.blacklist and #e.blacklist > 0 then
				totalActiveBl = totalActiveBl + #e.blacklist
			end
		end
		if totalActiveBl > 0 then
			showMode = "BLACKLIST"
			filterBtn.Text = "VIEW: BLACKLIST SERVERS"
		else
			showMode = "SAVED_BLACKLIST"
			filterBtn.Text = "VIEW: ALL BLACKLISTS"
		end
		ssFrame.Visible = true
		if clampPositionToScreen then
			ssFrame.Position = clampPositionToScreen(ssFrame.Position, ssFrame.Size)
		end
		pcall(ADMIN_SYS.refreshStaffRoster, false)
		pcall(render, true)
	end

	ADMIN_SYS.toggleServerStaffGui = function()
		ssFrame.Visible = not ssFrame.Visible
		if ssFrame.Visible then
			if screenGui and not screenGui.Enabled and ssFrame.Parent ~= pinnedGui then
				local pGui = getPinnedGui and getPinnedGui() or pinnedGui
				if pGui then
					ssFrame.Parent = pGui
					ssFrame:SetAttribute("AlwaysOnTop", true)
					local pBtn = ssFrame:FindFirstChild("AlwaysOnTopPinBtn", true)
					if pBtn then
						pBtn.BackgroundColor3 = Color3.fromRGB(16, 42, 68)
						pBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
						local st = pBtn:FindFirstChildOfClass("UIStroke")
						if st then
							st.Color = THEME.BorderBeam
							st.Thickness = 1.4
						end
					end
				end
			end
			if clampPositionToScreen then
				ssFrame.Position = clampPositionToScreen(ssFrame.Position, ssFrame.Size)
			end
			pcall(ADMIN_SYS.refreshStaffRoster, false)
			pcall(render, false)
		end
	end

	refreshBtn.MouseButton1Click:Connect(function()
		ADMIN_SYS.invalidateServerStaffCache()
		ADMIN_SYS.refreshStaffRoster(true)
		pcall(render, true)
	end)

	filterBtn.MouseButton1Click:Connect(function()
		if showMode == "STAFF" then
			showMode = "BLACKLIST"
			filterBtn.Text = "VIEW: BLACKLIST SERVERS"
		elseif showMode == "BLACKLIST" then
			showMode = "SAVED_BLACKLIST"
			filterBtn.Text = "VIEW: ALL BLACKLISTS"
		elseif showMode == "SAVED_BLACKLIST" then
			showMode = "ALL"
			filterBtn.Text = "VIEW: ALL SERVERS"
		else
			showMode = "STAFF"
			filterBtn.Text = "VIEW: STAFF ONLY"
		end
		pcall(render, true)
	end)

	nativeBtn.MouseButton1Click:Connect(function()
		ADMIN_SYS.serverStaffRevealEnabled = not ADMIN_SYS.serverStaffRevealEnabled
		nativeBtn.Text = "NATIVE LIST REVEAL: " .. (ADMIN_SYS.serverStaffRevealEnabled and "ON" or "OFF")
		if not ADMIN_SYS.serverStaffRevealEnabled then
			pcall(ADMIN_SYS.clearNativeStaffMarks)
		end
	end)

	onBlacklistChanged.Event:Connect(function()
		pcall(function()
			if ssFrame.Visible then
				render(true)
			end
		end)
	end)

	-- Smooth decoupled periodic refresh (OFF RenderStepped)
	task.spawn(function()
		while true do
			task.wait(4.5)
			if ssFrame.Visible then
				pcall(render, false)
			end
		end
	end)

	makeDraggable(ssFrame, ssTopBar)end

WIN_BUILDERS.buildOutfits = function()
	local ofFrame = Instance.new("Frame")
	ofFrame.Name = "OutfitWindow"
	ofFrame.Size = UDim2.new(0, 730, 0, 520)
	ofFrame.Position = UDim2.new(0.5, -365, 0.5, -260)
	ofFrame.BackgroundColor3 = THEME.MainBg
	ofFrame.BackgroundTransparency = THEME.MainBgTransparency
	ofFrame.BorderSizePixel = 0
	ofFrame.Visible = false
	ofFrame.ClipsDescendants = true
	ofFrame.Parent = screenGui
	outfitWindow = ofFrame
	applyResponsiveWindowScale(ofFrame, 730, 520, true)

	local ofCorner = Instance.new("UICorner")
	ofCorner.CornerRadius = UDim.new(0, 10)
	ofCorner.Parent = ofFrame

	local ofBevel = Instance.new("UIGradient")
	ofBevel.Rotation = 90
	ofBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	ofBevel.Parent = ofFrame

	local ofStroke = Instance.new("UIStroke")
	ofStroke.Thickness = 2.0
	ofStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ofStroke.Parent = ofFrame
	applyNeonSweep(ofStroke, 110, 2.5, 1.8, 2.6)

	local ofTopBar = Instance.new("Frame")
	ofTopBar.Size = UDim2.new(1, 0, 0, 42)
	ofTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	ofTopBar.BorderSizePixel = 0
	ofTopBar.Parent = ofFrame

	local ofTopCorner = Instance.new("UICorner")
	ofTopCorner.CornerRadius = UDim.new(0, 10)
	ofTopCorner.Parent = ofTopBar

	local ofTopStroke = Instance.new("UIStroke")
	ofTopStroke.Color = Color3.fromRGB(48, 48, 54)
	ofTopStroke.Thickness = 1
	ofTopStroke.Parent = ofTopBar

	local ofLiveDot = Instance.new("Frame")
	ofLiveDot.Size = UDim2.new(0, 7, 0, 7)
	ofLiveDot.Position = UDim2.new(0, 12, 0.5, -3.5)
	ofLiveDot.BackgroundColor3 = Color3.fromRGB(0, 215, 255)
	ofLiveDot.BorderSizePixel = 0
	ofLiveDot.Parent = ofTopBar
	local ofldC = Instance.new("UICorner")
	ofldC.CornerRadius = UDim.new(1, 0)
	ofldC.Parent = ofLiveDot

	local ofTitle = Instance.new("TextLabel")
	ofTitle.Size = UDim2.new(0, 310, 1, 0)
	ofTitle.Position = UDim2.new(0, 26, 0, 0)
	ofTitle.BackgroundTransparency = 1
	ofTitle.Font = Enum.Font.GothamBold
	ofTitle.Text = "ASTROCYNA // ROLE WARDROBE & OUTFITS"
	ofTitle.TextColor3 = THEME.TextCyan
	ofTitle.TextSize = 12
	ofTitle.TextXAlignment = Enum.TextXAlignment.Left
	ofTitle.Parent = ofTopBar
	applyTextShimmer(ofTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local ofCloseBtn = Instance.new("TextButton")
	ofCloseBtn.Size = UDim2.new(0, 28, 0, 28)
	ofCloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
	ofCloseBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	ofCloseBtn.Font = Enum.Font.GothamBold
	ofCloseBtn.Text = "X"
	ofCloseBtn.TextColor3 = THEME.TextCyan
	ofCloseBtn.TextSize = 13
	ofCloseBtn.Parent = ofTopBar

	local ofCloseCorner = Instance.new("UICorner")
	ofCloseCorner.CornerRadius = UDim.new(0, 6)
	ofCloseCorner.Parent = ofCloseBtn

	local ofCloseStroke = Instance.new("UIStroke")
	ofCloseStroke.Color = Color3.fromRGB(28, 60, 94)
	ofCloseStroke.Thickness = 1
	ofCloseStroke.Parent = ofCloseBtn
	hookButtonHover(ofCloseBtn, Color3.fromRGB(28, 28, 32), Color3.fromRGB(48, 20, 32), THEME.TextCyan, Color3.fromRGB(220, 220, 225))
	ofCloseBtn.MouseButton1Click:Connect(function()
		ofFrame.Visible = false
	end)

	attachAlwaysOnTopButton(ofFrame, ofTopBar, "OutfitWindow", -68, -14, 28, 28, 0.5)

	-- =================================================================
	-- LEFT PANEL: REALTIME 3D VIEWPORT CHARACTER DISPLAY
	-- =================================================================
	local setPreviewRole = nil
	local defaultBtn = nil
	local defStroke = nil

	local previewPanel = Instance.new("Frame")
	previewPanel.Name = "PreviewPanel"
	previewPanel.Size = UDim2.new(0, 234, 1, -54)
	previewPanel.Position = UDim2.new(0, 10, 0, 46)
	previewPanel.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
	previewPanel.BorderSizePixel = 0
	previewPanel.Parent = ofFrame

	local ppCorner = Instance.new("UICorner")
	ppCorner.CornerRadius = UDim.new(0, 8)
	ppCorner.Parent = previewPanel

	local ppStroke = Instance.new("UIStroke")
	ppStroke.Color = Color3.fromRGB(24, 52, 82)
	ppStroke.Thickness = 1
	ppStroke.Parent = previewPanel

	-- Preview Header
	local ppTop = Instance.new("Frame")
	ppTop.Size = UDim2.new(1, 0, 0, 28)
	ppTop.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
	ppTop.BorderSizePixel = 0
	ppTop.Parent = previewPanel
	local pptC = Instance.new("UICorner")
	pptC.CornerRadius = UDim.new(0, 8)
	pptC.Parent = ppTop

	local ppLiveDot = Instance.new("Frame")
	ppLiveDot.Size = UDim2.new(0, 6, 0, 6)
	ppLiveDot.Position = UDim2.new(0, 10, 0.5, -3)
	ppLiveDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ppLiveDot.BorderSizePixel = 0
	ppLiveDot.Parent = ppTop
	local ppldC = Instance.new("UICorner")
	ppldC.CornerRadius = UDim.new(1, 0)
	ppldC.Parent = ppLiveDot

	local ppTitle = Instance.new("TextLabel")
	ppTitle.Size = UDim2.new(1, -28, 1, 0)
	ppTitle.Position = UDim2.new(0, 22, 0, 0)
	ppTitle.BackgroundTransparency = 1
	ppTitle.Font = Enum.Font.GothamBold
	ppTitle.Text = "REALTIME 3D MANNEQUIN"
	ppTitle.TextColor3 = Color3.fromRGB(0, 230, 190)
	ppTitle.TextSize = 9.5
	ppTitle.TextXAlignment = Enum.TextXAlignment.Left
	ppTitle.Parent = ppTop

	-- 3D ViewportFrame
	local ofViewport = Instance.new("ViewportFrame")
	ofViewport.Name = "CharacterDisplay"
	ofViewport.Size = UDim2.new(1, -12, 1, -134)
	ofViewport.Position = UDim2.new(0, 6, 0, 32)
	ofViewport.BackgroundTransparency = 1
	ofViewport.BorderSizePixel = 0
	ofViewport.LightColor = Color3.fromRGB(245, 250, 255)
	ofViewport.Ambient = Color3.fromRGB(150, 160, 180)
	ofViewport.LightDirection = Vector3.new(-1, -1.8, -1.2).Unit
	ofViewport.Parent = previewPanel

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 6)
	vpCorner.Parent = ofViewport

	local vpWorld = Instance.new("WorldModel")
	vpWorld.Parent = ofViewport

	local vpCam = Instance.new("Camera")
	vpCam.Parent = ofViewport
	ofViewport.CurrentCamera = vpCam

	-- Holographic Pedestal
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(0.2, 4.4, 4.4)
	pedestal.CFrame = CFrame.new(0, -3.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Material = Enum.Material.Neon
	pedestal.Color = Color3.fromRGB(0, 200, 255)
	pedestal.Anchored = true
	pedestal.CanCollide = false
	pedestal.Parent = vpWorld

	local pedRing = Instance.new("Part")
	pedRing.Name = "PedestalRing"
	pedRing.Shape = Enum.PartType.Cylinder
	pedRing.Size = Vector3.new(0.1, 4.8, 4.8)
	pedRing.CFrame = CFrame.new(0, -3.12, 0) * CFrame.Angles(0, 0, math.rad(90))
	pedRing.Material = Enum.Material.Glass
	pedRing.Color = Color3.fromRGB(10, 40, 70)
	pedRing.Transparency = 0.4
	pedRing.Anchored = true
	pedRing.CanCollide = false
	pedRing.Parent = vpWorld

	-- Preview Footer Info
	local prevInfoFrame = Instance.new("Frame")
	prevInfoFrame.Size = UDim2.new(1, -12, 0, 92)
	prevInfoFrame.Position = UDim2.new(0, 6, 1, -98)
	prevInfoFrame.BackgroundColor3 = Color3.fromRGB(13, 20, 32)
	prevInfoFrame.BorderSizePixel = 0
	prevInfoFrame.Parent = previewPanel

	local pifCorner = Instance.new("UICorner")
	pifCorner.CornerRadius = UDim.new(0, 6)
	pifCorner.Parent = prevInfoFrame

	local pifStroke = Instance.new("UIStroke")
	pifStroke.Color = Color3.fromRGB(24, 48, 76)
	pifStroke.Thickness = 1
	pifStroke.Parent = prevInfoFrame

	local prevRoleTitle = Instance.new("TextLabel")
	prevRoleTitle.Size = UDim2.new(1, -12, 0, 18)
	prevRoleTitle.Position = UDim2.new(0, 8, 0, 6)
	prevRoleTitle.BackgroundTransparency = 1
	prevRoleTitle.Font = Enum.Font.GothamBold
	prevRoleTitle.Text = "👔 Preview: Default Look"
	prevRoleTitle.TextColor3 = THEME.TextCyan
	prevRoleTitle.TextSize = 11.5
	prevRoleTitle.TextXAlignment = Enum.TextXAlignment.Left
	prevRoleTitle.Parent = prevInfoFrame

	local prevRoleSub = Instance.new("TextLabel")
	prevRoleSub.Size = UDim2.new(1, -12, 0, 14)
	prevRoleSub.Position = UDim2.new(0, 8, 0, 24)
	prevRoleSub.BackgroundTransparency = 1
	prevRoleSub.Font = Enum.Font.Gotham
	prevRoleSub.Text = "Original Player Appearance"
	prevRoleSub.TextColor3 = THEME.TextDim
	prevRoleSub.TextSize = 9
	prevRoleSub.TextXAlignment = Enum.TextXAlignment.Left
	prevRoleSub.Parent = prevInfoFrame

	defaultBtn = Instance.new("TextButton")
	defaultBtn.Name = "DefaultLookBtn"
	defaultBtn.Size = UDim2.new(1, -56, 0, 30)
	defaultBtn.Position = UDim2.new(0, 6, 0, 48)
	defaultBtn.BackgroundColor3 = Color3.fromRGB(48, 24, 60)
	defaultBtn.Font = Enum.Font.GothamBold
	defaultBtn.Text = "DEFAULT LOOK"
	defaultBtn.TextColor3 = Color3.fromRGB(220, 150, 255)
	defaultBtn.TextSize = 10.5
	defaultBtn.Parent = prevInfoFrame

	local defCorner = Instance.new("UICorner")
	defCorner.CornerRadius = UDim.new(0, 6)
	defCorner.Parent = defaultBtn

	defStroke = Instance.new("UIStroke")
	defStroke.Color = Color3.fromRGB(160, 70, 210)
	defStroke.Thickness = 1
	defStroke.Parent = defaultBtn
	local lastDefTap = 0
	local function onDefaultClicked()
		local now = tick()
		if now - lastDefTap < 0.12 then return end
		lastDefTap = now
		OUTFIT_SYS.resetDefault()
		if setPreviewRole then
			setPreviewRole(nil)
		end
		if OUTFIT_SYS.updateGuiButtons then
			pcall(OUTFIT_SYS.updateGuiButtons)
		end
	end
	defaultBtn.MouseButton1Click:Connect(onDefaultClicked)
	if defaultBtn.Activated then
		defaultBtn.Activated:Connect(onDefaultClicked)
	end

	local autoSpinBtn = Instance.new("TextButton")
	autoSpinBtn.Size = UDim2.new(0, 38, 0, 30)
	autoSpinBtn.Position = UDim2.new(1, -44, 0, 48)
	autoSpinBtn.BackgroundColor3 = Color3.fromRGB(18, 34, 54)
	autoSpinBtn.Font = Enum.Font.GothamBold
	autoSpinBtn.Text = "🔄"
	autoSpinBtn.TextColor3 = THEME.TextCyan
	autoSpinBtn.TextSize = 12
	autoSpinBtn.Parent = prevInfoFrame
	local asbC = Instance.new("UICorner")
	asbC.CornerRadius = UDim.new(0, 6)
	asbC.Parent = autoSpinBtn
	local asbS = Instance.new("UIStroke")
	asbS.Color = Color3.fromRGB(28, 64, 100)
	asbS.Thickness = 1
	asbS.Parent = autoSpinBtn

	-- 3D Camera & Rotation State
	local spinAngle = 0
	local autoRotate = true
	local camDistance = 5.8
	local camPitch = 0.12
	local camTargetY = 0.05
	local isDragging = false
	local dragStart = nil

	local function updatePreviewCam()
		if not vpCam then return end
		local rad = math.rad(spinAngle)
		local cx = math.sin(rad) * (camDistance * math.cos(camPitch))
		local cz = math.cos(rad) * (camDistance * math.cos(camPitch))
		local cy = camTargetY + camDistance * math.sin(camPitch)
		vpCam.CFrame = CFrame.new(Vector3.new(cx, cy, cz), Vector3.new(0, camTargetY, 0))
	end

	updatePreviewCam()

	autoSpinBtn.MouseButton1Click:Connect(function()
		autoRotate = not autoRotate
		if autoRotate then
			autoSpinBtn.BackgroundColor3 = Color3.fromRGB(18, 34, 54)
			asbS.Color = Color3.fromRGB(28, 64, 100)
		else
			autoSpinBtn.BackgroundColor3 = Color3.fromRGB(36, 20, 24)
			asbS.Color = Color3.fromRGB(120, 40, 50)
		end
	end)

	ofViewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStart = input.Position
		end
	end)

	ofViewport.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
			dragStart = nil
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if dragStart then
				local dx = input.Position.X - dragStart.X
				local dy = input.Position.Y - dragStart.Y
				spinAngle = (spinAngle - dx * 0.9) % 360
				camPitch = math.clamp(camPitch + dy * 0.005, -0.4, 0.55)
				dragStart = input.Position
				updatePreviewCam()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and ofFrame.Visible then
			local mPos = UserInputService:GetMouseLocation()
			local vpPos = ofViewport.AbsolutePosition
			local vpSize = ofViewport.AbsoluteSize
			if mPos.X >= vpPos.X and mPos.X <= vpPos.X + vpSize.X and mPos.Y >= vpPos.Y and mPos.Y <= vpPos.Y + vpSize.Y then
				camDistance = math.clamp(camDistance - input.Position.Z * 0.5, 3.2, 8.5)
				updatePreviewCam()
			end
		end
	end)

	UserInputService.TouchPinch:Connect(function(touchPositions, totalScale, velocity, state, gpe)
		if ofFrame.Visible and #touchPositions >= 2 then
			local p1 = touchPositions[1]
			local vpPos = ofViewport.AbsolutePosition
			local vpSize = ofViewport.AbsoluteSize
			if p1.X >= vpPos.X and p1.X <= vpPos.X + vpSize.X and p1.Y >= vpPos.Y and p1.Y <= vpPos.Y + vpSize.Y then
				camDistance = math.clamp(camDistance / math.max(0.1, totalScale), 3.2, 8.5)
				updatePreviewCam()
			end
		end
	end)

	-- =================================================================
	-- MANNEQUIN MODEL CONTROLLER
	-- =================================================================
	local activeMannequin = nil
	local currentPreviewRoleId = nil

	local function clearMannequin()
		if activeMannequin and activeMannequin.Parent then
			activeMannequin:Destroy()
			activeMannequin = nil
		end
	end

	local function rebuildMannequinBase()
		clearMannequin()
		local srcChar = player.Character
		if not srcChar then return nil end

		local prevArch = srcChar.Archivable
		srcChar.Archivable = true
		local cl = srcChar:Clone()
		srcChar.Archivable = prevArch

		if not cl then return nil end

		for _, desc in ipairs(cl:GetDescendants()) do
			if desc:IsA("LuaSourceContainer") or desc:IsA("Sound") or desc:IsA("BillboardGui") or desc:IsA("Highlight") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.CanCollide = false
				desc.Anchored = true
			end
		end

		local hum = cl:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayDistance = 0
			hum.NameDisplayDistance = 0
		end

		cl:PivotTo(CFrame.new(0, 0, 0))
		cl.Parent = vpWorld
		activeMannequin = cl
		return cl
	end

	local function applyOutfitToMannequin(roleId)
		local cl = activeMannequin
		if not cl or not cl.Parent then
			cl = rebuildMannequinBase()
			if not cl then return end
		end

		for _, item in ipairs(cl:GetChildren()) do
			local isMatch = false
			pcall(function()
				if item:GetAttribute("AstrocynaPreviewItem") or item:GetAttribute("AstrocynaOutfitItem") or item:GetAttribute("AstrocynaOutfitDecal") then
					isMatch = true
				elseif OUTFIT_SYS and type(OUTFIT_SYS.isGameOutfitItem) == "function" and OUTFIT_SYS.isGameOutfitItem(item.Name) then
					isMatch = true
				end
			end)
			if isMatch then
				item:Destroy()
			end
		end
		for _, part in ipairs(cl:GetChildren()) do
			if part:IsA("BasePart") then
				for _, d in ipairs(part:GetChildren()) do
					if d:IsA("Decal") and d:GetAttribute("AstrocynaPreviewItem") then
						d:Destroy()
					end
				end
			end
		end

		if not roleId then
			local snap = OUTFIT_SYS.defaultSnapshot
			if snap then
				if snap.bodyColors then
					local bc = cl:FindFirstChildOfClass("BodyColors")
					if bc then
						for k, v in pairs(snap.bodyColors) do pcall(function() bc[k] = v end) end
					end
				end
				if snap.shirtTemplate then
					local s = cl:FindFirstChildOfClass("Shirt")
					if s then s.ShirtTemplate = snap.shirtTemplate end
				end
				if snap.pantsTemplate then
					local p = cl:FindFirstChildOfClass("Pants")
					if p then p.PantsTemplate = snap.pantsTemplate end
				end
				if snap.limbDecals then
					for limbName, decals in pairs(snap.limbDecals) do
						local limb = cl:FindFirstChild(limbName)
						if limb then
							for dName, props in pairs(decals) do
								local d = limb:FindFirstChild(dName)
								if d and d:IsA("Decal") then
									if props.ColorMapContent ~= nil then pcall(function() d.ColorMapContent = props.ColorMapContent end) end
									if props.Texture ~= nil then pcall(function() d.Texture = props.Texture end) end
									pcall(function() d.Transparency = props.Transparency or 0 end)
								end
							end
						end
					end
				end
			end
			return
		end

		local outfits = ReplicatedStorage:FindFirstChild("Outfits")
		if not outfits then return end
		local outfitFolder = outfits:FindFirstChild(roleId)
		if not outfitFolder then return end

		for _, item in ipairs(outfitFolder:GetChildren()) do
			if item:IsA("Decal") then
				local isColorMap = false
				local val = nil
				pcall(function()
					val = item.ColorMapContent
					if val ~= nil then isColorMap = true end
				end)
				if val == nil then val = item.Texture end

				if item.Name == "Shirt" then
					for _, limbName in ipairs({"Torso", "Left Arm", "Right Arm"}) do
						local limb = cl:FindFirstChild(limbName)
						local s = limb and limb:FindFirstChild("Shirt")
						if s then
							pcall(function()
								if isColorMap then s.ColorMapContent = val else s.Texture = val end
								s.Transparency = 0
							end)
						end
					end
				elseif item.Name == "Pants" then
					for _, limbName in ipairs({"Torso", "Left Leg", "Right Leg"}) do
						local limb = cl:FindFirstChild(limbName)
						local p = limb and limb:FindFirstChild("Pants")
						if p then
							pcall(function()
								if isColorMap then p.ColorMapContent = val else p.Texture = val end
								p.Transparency = 0
							end)
						end
					end
				end

				local clone = item:Clone()
				clone:SetAttribute("AstrocynaPreviewItem", true)
				clone.Transparency = 0
				clone.Parent = cl
			elseif item:IsA("Accessory") or item:IsA("Configuration") then
				local clone = item:Clone()
				clone:SetAttribute("AstrocynaPreviewItem", true)
				clone.Parent = cl
				pcall(function()
					OUTFIT_SYS.attachOutfitItem(clone, cl, true)
				end)
			elseif item:IsA("BodyColors") then
				local bc = cl:FindFirstChildOfClass("BodyColors")
				if bc then
					bc.HeadColor3 = item.HeadColor3
					bc.TorsoColor3 = item.TorsoColor3
					bc.LeftArmColor3 = item.LeftArmColor3
					bc.RightArmColor3 = item.RightArmColor3
					bc.LeftLegColor3 = item.LeftLegColor3
					bc.RightLegColor3 = item.RightLegColor3
				end
			end
		end
	end

	setPreviewRole = function(roleId)
		currentPreviewRoleId = roleId
		pcall(function()
			if roleId == nil then
				prevRoleTitle.Text = "👔 Preview: Default Look"
				prevRoleTitle.TextColor3 = THEME.TextCyan
				prevRoleSub.Text = "Original Player Appearance"
				pifStroke.Color = Color3.fromRGB(24, 48, 76)
				pedestal.Color = Color3.fromRGB(0, 200, 255)
				applyOutfitToMannequin(nil)
			else
				local roleData = nil
				for _, r in ipairs(OUTFIT_SYS.roles) do
					if r.id == roleId then roleData = r; break end
				end
				local rName = roleData and roleData.name or roleId
				local rIcon = roleData and roleData.icon or "👔"
				local rCol = roleData and roleData.color or THEME.TextCyan
				local rDept = roleData and ("[" .. string.upper(roleData.dept) .. "] · " .. roleData.titleTh) or "Custom Role"

				prevRoleTitle.Text = rIcon .. " " .. rName
				prevRoleTitle.TextColor3 = rCol
				prevRoleSub.Text = rDept
				pifStroke.Color = rCol
				pedestal.Color = rCol
				applyOutfitToMannequin(roleId)
			end
		end)
		if OUTFIT_SYS.updateGuiButtons then
			pcall(OUTFIT_SYS.updateGuiButtons)
		end
	end

	-- =================================================================
	-- RIGHT PANEL: OUTFITS CATALOG & CONTROLS
	-- =================================================================
	local catalogPanel = Instance.new("Frame")
	catalogPanel.Name = "CatalogPanel"
	catalogPanel.Size = UDim2.new(1, -256, 1, -54)
	catalogPanel.Position = UDim2.new(0, 248, 0, 46)
	catalogPanel.BackgroundColor3 = Color3.fromRGB(9, 15, 24)
	catalogPanel.BorderSizePixel = 0
	catalogPanel.ClipsDescendants = true
	catalogPanel.Parent = ofFrame

	local cpCorner = Instance.new("UICorner")
	cpCorner.CornerRadius = UDim.new(0, 8)
	cpCorner.Parent = catalogPanel

	local cpStroke = Instance.new("UIStroke")
	cpStroke.Color = Color3.fromRGB(22, 44, 68)
	cpStroke.Thickness = 1
	cpStroke.Parent = catalogPanel

	-- Subbar inside Catalog Panel
	local ofSubBar = Instance.new("Frame")
	ofSubBar.Size = UDim2.new(1, -16, 0, 34)
	ofSubBar.Position = UDim2.new(0, 8, 0, 8)
	ofSubBar.BackgroundColor3 = Color3.fromRGB(12, 20, 30)
	ofSubBar.BorderSizePixel = 0
	ofSubBar.ZIndex = 10
	ofSubBar.Parent = catalogPanel

	local ofsbCorner = Instance.new("UICorner")
	ofsbCorner.CornerRadius = UDim.new(0, 6)
	ofsbCorner.Parent = ofSubBar

	local ofsbStroke = Instance.new("UIStroke")
	ofsbStroke.Color = Color3.fromRGB(24, 48, 72)
	ofsbStroke.Thickness = 1
	ofsbStroke.Parent = ofSubBar

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -140, 0, 26)
	searchBox.Position = UDim2.new(0, 8, 0.5, -13)
	searchBox.BackgroundColor3 = Color3.fromRGB(16, 26, 40)
	searchBox.Font = Enum.Font.Gotham
	searchBox.PlaceholderText = "Search role / team..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(100, 130, 160)
	searchBox.Text = ""
	searchBox.TextColor3 = THEME.TextCyan
	searchBox.TextSize = 10.5
	searchBox.ClearTextOnFocus = false
	searchBox.ZIndex = 11
	searchBox.Parent = ofSubBar

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 5)
	sbCorner.Parent = searchBox

	local sbStroke = Instance.new("UIStroke")
	sbStroke.Color = Color3.fromRGB(28, 56, 84)
	sbStroke.Thickness = 1
	sbStroke.Parent = searchBox

	local statusBadge = Instance.new("TextLabel")
	statusBadge.Size = UDim2.new(0, 120, 0, 26)
	statusBadge.Position = UDim2.new(1, -128, 0.5, -13)
	statusBadge.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	statusBadge.Font = Enum.Font.GothamBold
	statusBadge.Text = "Active: Default"
	statusBadge.TextColor3 = THEME.TextFrost
	statusBadge.TextSize = 9.5
	statusBadge.ZIndex = 11
	statusBadge.Parent = ofSubBar
	OUTFIT_SYS.activeStatusLabel = statusBadge

	local statCorner = Instance.new("UICorner")
	statCorner.CornerRadius = UDim.new(0, 5)
	statCorner.Parent = statusBadge

	local statStroke = Instance.new("UIStroke")
	statStroke.Color = Color3.fromRGB(28, 56, 84)
	statStroke.Thickness = 1
	statStroke.Parent = statusBadge

	-- Scrollable Grid of Role Cards
	local ofScroll = Instance.new("ScrollingFrame")
	ofScroll.Size = UDim2.new(1, -16, 1, -52)
	ofScroll.Position = UDim2.new(0, 8, 0, 46)
	ofScroll.BackgroundTransparency = 1
	ofScroll.BorderSizePixel = 0
	ofScroll.ScrollBarThickness = 3
	ofScroll.ScrollBarImageColor3 = THEME.CyanPrimary
	ofScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ofScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ofScroll.ClipsDescendants = true
	ofScroll.ZIndex = 1
	ofScroll.Parent = catalogPanel

	local sPad = Instance.new("UIPadding")
	sPad.PaddingLeft = UDim.new(0, 4)
	sPad.PaddingRight = UDim.new(0, 8)
	sPad.PaddingTop = UDim.new(0, 4)
	sPad.PaddingBottom = UDim.new(0, 8)
	sPad.Parent = ofScroll

	local ofGrid = Instance.new("UIGridLayout")
	ofGrid.CellSize = UDim2.new(0.5, -6, 0, 68)
	ofGrid.CellPadding = UDim2.new(0, 10, 0, 8)
	ofGrid.SortOrder = Enum.SortOrder.LayoutOrder
	ofGrid.Parent = ofScroll

	local function selectAndEquipRole(roleId)
		if not roleId then return end
		if OUTFIT_SYS then
			OUTFIT_SYS.activeOutfit = roleId
		end
		if setPreviewRole then
			pcall(function() setPreviewRole(roleId) end)
		end
		if OUTFIT_SYS and type(OUTFIT_SYS.updateGuiButtons) == "function" then
			pcall(OUTFIT_SYS.updateGuiButtons)
		end
		if OUTFIT_SYS and type(OUTFIT_SYS.applyOutfit) == "function" then
			pcall(function()
				OUTFIT_SYS.applyOutfit(roleId)
			end)
		end
		if setPreviewRole then
			pcall(function() setPreviewRole(roleId) end)
		end
		if OUTFIT_SYS and type(OUTFIT_SYS.updateGuiButtons) == "function" then
			pcall(OUTFIT_SYS.updateGuiButtons)
		end
	end

	local roleCards = {}

	for i, role in ipairs(OUTFIT_SYS.roles) do
		local card = Instance.new("Frame")
		card.Name = "RoleCard_" .. role.id
		card.BackgroundColor3 = THEME.CardBg
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = ofScroll

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = THEME.CardStroke
		cStroke.Thickness = 1
		cStroke.Parent = card

		local cGrad = Instance.new("UIGradient")
		cGrad.Rotation = 90
		cGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 28, 44)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 26))
		})
		cGrad.Parent = card

		local iconCircle = Instance.new("Frame")
		iconCircle.Size = UDim2.new(0, 36, 0, 36)
		iconCircle.Position = UDim2.new(0, 6, 0.5, -18)
		iconCircle.BackgroundColor3 = Color3.fromRGB(16, 24, 38)
		iconCircle.BorderSizePixel = 0
		iconCircle.Parent = card

		local icCorner = Instance.new("UICorner")
		icCorner.CornerRadius = UDim.new(1, 0)
		icCorner.Parent = iconCircle

		local icStroke = Instance.new("UIStroke")
		icStroke.Color = role.color
		icStroke.Thickness = 1.2
		icStroke.Parent = iconCircle

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.Text = role.icon
		iconLabel.TextSize = 16
		iconLabel.Parent = iconCircle

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -120, 0, 18)
		nameLabel.Position = UDim2.new(0, 46, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = role.name
		nameLabel.TextColor3 = role.color
		nameLabel.TextSize = 11.5
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -120, 0, 16)
		titleLabel.Position = UDim2.new(0, 46, 0, 24)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.Gotham
		titleLabel.Text = role.titleTh
		titleLabel.TextColor3 = THEME.TextDim
		titleLabel.TextSize = 9
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = card

		local deptLabel = Instance.new("TextLabel")
		deptLabel.Size = UDim2.new(1, -120, 0, 14)
		deptLabel.Position = UDim2.new(0, 46, 0, 42)
		deptLabel.BackgroundTransparency = 1
		deptLabel.Font = Enum.Font.GothamBold
		deptLabel.Text = "[" .. string.upper(role.dept) .. "]"
		deptLabel.TextColor3 = Color3.fromRGB(130, 160, 190)
		deptLabel.TextSize = 8.5
		deptLabel.TextXAlignment = Enum.TextXAlignment.Left
		deptLabel.Parent = card

		-- Clicking anywhere on the card or the button selects & equips the role immediately!
		local cardHit = Instance.new("TextButton")
		cardHit.Name = "CardHitArea"
		cardHit.Size = UDim2.new(1, -66, 1, 0)
		cardHit.BackgroundTransparency = 1
		cardHit.Text = ""
		cardHit.ZIndex = 5
		cardHit.Parent = card

		local equipBtn = Instance.new("TextButton")
		equipBtn.Name = "EquipButton"
		equipBtn.Size = UDim2.new(0, 60, 0, 28)
		equipBtn.Position = UDim2.new(1, -66, 0.5, -14)
		equipBtn.BackgroundColor3 = THEME.BtnOff
		equipBtn.Font = Enum.Font.GothamBold
		equipBtn.Text = "EQUIP"
		equipBtn.TextColor3 = THEME.TextCyan
		equipBtn.TextSize = 9.5
		equipBtn.ZIndex = 6
		equipBtn.Parent = card

		local ebCorner = Instance.new("UICorner")
		ebCorner.CornerRadius = UDim.new(0, 6)
		ebCorner.Parent = equipBtn

		local ebStroke = Instance.new("UIStroke")
		ebStroke.Color = THEME.BtnOffStroke
		ebStroke.Thickness = 1
		ebStroke.Parent = equipBtn

		local lastTap = 0
		local function onRoleClicked()
			local now = tick()
			if now - lastTap < 0.12 then return end
			lastTap = now
			selectAndEquipRole(role.id)
		end

		cardHit.MouseButton1Click:Connect(onRoleClicked)
		if cardHit.Activated then
			cardHit.Activated:Connect(onRoleClicked)
		end

		equipBtn.MouseButton1Click:Connect(onRoleClicked)
		if equipBtn.Activated then
			equipBtn.Activated:Connect(onRoleClicked)
		end

		OUTFIT_SYS.outfitButtons[role.id] = {
			btn = equipBtn,
			stroke = ebStroke,
			card = card,
			cardStroke = cStroke,
			role = role,
		}

		table.insert(roleCards, {
			card = card,
			role = role,
		})
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(searchBox.Text)
		for _, rc in ipairs(roleCards) do
			if q == "" then
				rc.card.Visible = true
			else
				local match = string.find(string.lower(rc.role.name), q, 1, true)
					or string.find(string.lower(rc.role.titleTh), q, 1, true)
					or string.find(string.lower(rc.role.dept), q, 1, true)
				rc.card.Visible = (match ~= nil)
			end
		end
	end)

	OUTFIT_SYS.updateGuiButtons = function()
		local active = OUTFIT_SYS.activeOutfit
		if statusBadge then
			if active then
				local activeRoleData = nil
				for _, r in ipairs(OUTFIT_SYS.roles) do
					if r.id == active then
						activeRoleData = r
						break
					end
				end
				local dispName = activeRoleData and activeRoleData.name or active
				statusBadge.Text = "Active: " .. dispName
				statusBadge.TextColor3 = Color3.fromRGB(0, 255, 180)
				statStroke.Color = Color3.fromRGB(0, 220, 150)
			else
				statusBadge.Text = "Active: Default"
				statusBadge.TextColor3 = THEME.TextFrost
				statStroke.Color = Color3.fromRGB(28, 56, 84)
			end
		end

		if defaultBtn and defaultBtn.Parent then
			if active == nil then
				defaultBtn.Text = "✓ DEFAULT ACTIVE"
				defaultBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				defaultBtn.TextColor3 = THEME.BtnActiveText
				if defStroke then defStroke.Color = Color3.fromRGB(200, 200, 205) end
			else
				defaultBtn.Text = "DEFAULT LOOK"
				defaultBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
				defaultBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
				if defStroke then defStroke.Color = Color3.fromRGB(60, 60, 68) end
			end
		end

		for rId, data in pairs(OUTFIT_SYS.outfitButtons) do
			local isCurrent = (active == rId)
			local isPreviewing = (currentPreviewRoleId == rId)
			if isCurrent then
				data.btn.Text = "✓ ACTIVE"
				data.btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				data.btn.TextColor3 = THEME.BtnActiveText
				data.stroke.Color = Color3.fromRGB(200, 200, 205)
				data.stroke.Thickness = 1.5
				data.cardStroke.Color = Color3.fromRGB(255, 255, 255)
				data.cardStroke.Thickness = 1.8
				data.card.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
			elseif isPreviewing then
				data.btn.Text = "EQUIP"
				data.btn.BackgroundColor3 = Color3.fromRGB(20, 40, 65)
				data.btn.TextColor3 = THEME.TextCyan
				data.stroke.Color = THEME.CyanPrimary
				data.stroke.Thickness = 1
				data.cardStroke.Color = THEME.CyanPrimary
				data.cardStroke.Thickness = 1.2
				data.card.BackgroundColor3 = Color3.fromRGB(14, 22, 34)
			else
				data.btn.Text = "EQUIP"
				data.btn.BackgroundColor3 = THEME.BtnOff
				data.btn.TextColor3 = THEME.TextCyan
				data.stroke.Color = THEME.BtnOffStroke
				data.stroke.Thickness = 1
				data.cardStroke.Color = THEME.CardStroke
				data.cardStroke.Thickness = 1
				data.card.BackgroundColor3 = THEME.CardBg
			end
		end
	end

	OUTFIT_SYS.refreshPreview = function()
		if ofFrame.Visible then
			setPreviewRole(OUTFIT_SYS.activeOutfit)
		end
	end

	OUTFIT_SYS.previewRole = function(roleId)
		setPreviewRole(roleId)
	end

	-- Real-time animator loop for 3D Viewport orbit and UI dot pulse
	table.insert(activeAnimators, function(dt)
		if ofFrame and ofFrame.Visible then
			if autoRotate and not isDragging then
				spinAngle = (spinAngle + (dt or 0.016) * 32) % 360
				updatePreviewCam()
			end

			local pulse = 0.35 * (math.sin(tick() * 4) + 1) / 2
			if ofLiveDot and ofLiveDot.Parent then
				ofLiveDot.BackgroundTransparency = pulse
			end
			if ppLiveDot and ppLiveDot.Parent then
				ppLiveDot.BackgroundTransparency = pulse
			end
		end
	end)

	pcall(function()
		setPreviewRole(OUTFIT_SYS.activeOutfit)
		OUTFIT_SYS.updateGuiButtons()
	end)

	makeDraggable(ofFrame, ofTopBar)
end

	local auraSweepTimer = 0
	table.insert(activeAnimators, function(dt)
		if not isAuraEnabled then return end
		auraSweepTimer = auraSweepTimer + dt
		if auraSweepTimer < 0.033 then return end
		auraSweepTimer = 0

		local emitters = OUTFIT_SYS and OUTFIT_SYS.auraEmitters
		if emitters and #emitters > 0 then
			local animSeq = getAuraNeonColorSequence(auraColor, tick())
			for _, emitter in ipairs(emitters) do
				if emitter.Parent and emitter.Name ~= "BlackShadow_Particle" then
					emitter.Color = animSeq
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		for _, animFn in ipairs(activeAnimators) do
			pcall(animFn, dt)
		end
	end)


WIN_BUILDERS.buildRadioInterceptor = function()
	local function addCorner(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
		return c
	end

	local function addStroke(inst, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
		return s
	end

	local function newLabel(parent, text, size, color, pos, sz, bold, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text or ""
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextSize = size or 11
		l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		if pos then l.Position = pos end
		if sz then l.Size = sz end
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end

	local RADIO_INTERCEPTOR = {
		Enabled = false,
		ActiveSpeaker = nil,
		ActiveSpeakerChannel = nil,
		ManualTarget = nil,
		SavedListeners = {},
		GraceTimer = 0,
		CurrentTab = "All", -- "All", "1. General", "2. Security", "3. Medical", "4. Command"
		JoinedChannel = nil,
		PillHud = nil,
		PillText = nil,
		RecentTransmissions = {
			General = {},
			Security = {},
			Medical = {},
			Command = {},
		},
		Channels = {
			{ Key = "General", Number = 1, Folder = "1. General", Label = "GENERAL", Color = Color3.fromRGB(150, 205, 255) },
			{ Key = "Security", Number = 2, Folder = "2. Security", Label = "SECURITY", Color = Color3.fromRGB(95, 155, 240) },
			{ Key = "Medical", Number = 3, Folder = "3. Medical", Label = "MEDICAL", Color = Color3.fromRGB(240, 100, 100) },
			{ Key = "Command", Number = 4, Folder = "4. Command", Label = "COMMAND", Color = Color3.fromRGB(235, 190, 80) },
		},
		refreshUI = nil,
	}

	local MAX_RADIO_LINES = 25
	local function addRadioTransmission(channelKey, who, text, kind, col)
		local chLines = RADIO_INTERCEPTOR.RecentTransmissions[channelKey]
		if not chLines then
			chLines = {}
			RADIO_INTERCEPTOR.RecentTransmissions[channelKey] = chLines
		end
		local timeStr = os.date("%H:%M:%S")
		table.insert(chLines, {
			Time = timeStr,
			Who = tostring(who or "Unknown"),
			Text = tostring(text or ""),
			Kind = kind or "Text",
			Color = col or Color3.fromRGB(255, 255, 255),
		})
		while #chLines > MAX_RADIO_LINES do
			table.remove(chLines, 1)
		end
		if RADIO_INTERCEPTOR.refreshUI then
			pcall(RADIO_INTERCEPTOR.refreshUI)
		end
	end

	local function isPlayerInChannel(folderName)
		local channelsFolder = workspace:FindFirstChild("Channels")
		local chFolder = channelsFolder and channelsFolder:FindFirstChild(folderName)
		if chFolder and chFolder:FindFirstChild(player.Name) then
			return true
		end
		local radioAttr = player:GetAttribute("RadioChannel")
		if typeof(radioAttr) == "string" then
			for _, c in ipairs(RADIO_INTERCEPTOR.Channels) do
				if c.Key == radioAttr and c.Folder == folderName then
					return true
				end
			end
		end
		return RADIO_INTERCEPTOR.JoinedChannel == folderName
	end

	local activeVoiceTaps = {} -- [Player] = { Listeners = {l1, l2, l3}, Grace = number, Channel = string }

	local function cleanupAllVoiceTaps()
		for targetPlr, data in pairs(activeVoiceTaps) do
			if data and data.Listeners then
				for _, l in ipairs(data.Listeners) do
					pcall(function() l:Destroy() end)
				end
			end
		end
		table.clear(activeVoiceTaps)
	end

	local function removeVoiceTapForPlayer(targetPlr)
		if not targetPlr then return end
		local data = activeVoiceTaps[targetPlr]
		if data and data.Listeners then
			for _, l in ipairs(data.Listeners) do
				pcall(function() l:Destroy() end)
			end
		end
		activeVoiceTaps[targetPlr] = nil
	end

	local function ensureAudioListenerOnCamera()
		pcall(function()
			if not isSpectating then
				SoundService:SetListener(Enum.ListenerType.Camera)
			end
			local cam = workspace.CurrentCamera
			if cam then
				local listener = cam:FindFirstChildOfClass("AudioListener") or cam:FindFirstChild("AudioListener")
				if not listener then
					local newListener = Instance.new("AudioListener")
					newListener.Name = "SpyVoiceListener"
					newListener.Parent = cam
				end
			end
		end)
	end
	local function forceJoinRadioChannel(folderName)
		pcall(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local radioEvent = remotes and remotes:FindFirstChild("RadioEvent")
			local channelsFolder = workspace:FindFirstChild("Channels")
			local ch = channelsFolder and channelsFolder:FindFirstChild(folderName)
			if radioEvent and ch then
				radioEvent:FireServer("Join", ch)
				RADIO_INTERCEPTOR.JoinedChannel = folderName
			end
		end)
	end

	local function forceLeaveRadioChannel(folderName)
		pcall(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local radioEvent = remotes and remotes:FindFirstChild("RadioEvent")
			local channelsFolder = workspace:FindFirstChild("Channels")
			local ch = folderName and channelsFolder and channelsFolder:FindFirstChild(folderName)
			if radioEvent then
				if ch then
					radioEvent:FireServer("Leave", ch)
				else
					radioEvent:FireServer("Leave")
				end
				if RADIO_INTERCEPTOR.JoinedChannel == folderName then
					RADIO_INTERCEPTOR.JoinedChannel = nil
				end
			end
		end)
	end

	local function updatePillHud()
		local activeNames = {}
		local primaryChannel = nil
		for targetPlr, data in pairs(activeVoiceTaps) do
			if targetPlr.Parent then
				table.insert(activeNames, targetPlr.DisplayName)
				primaryChannel = data.Channel or primaryChannel
			end
		end

		if #activeNames == 0 then
			if RADIO_INTERCEPTOR.PillHud and not RADIO_INTERCEPTOR.ManualTarget then
				RADIO_INTERCEPTOR.PillHud.Visible = false
			end
		elseif #activeNames == 1 then
			if RADIO_INTERCEPTOR.PillHud then
				RADIO_INTERCEPTOR.PillHud.Visible = true
				if RADIO_INTERCEPTOR.PillText then
					RADIO_INTERCEPTOR.PillText.Text = string.format("[INTERCEPTING] %s · %s", activeNames[1], primaryChannel or "RADIO")
				end
			end
		else
			if RADIO_INTERCEPTOR.PillHud then
				RADIO_INTERCEPTOR.PillHud.Visible = true
				if RADIO_INTERCEPTOR.PillText then
					local namesStr = table.concat(activeNames, ", ")
					if #namesStr > 28 then
						namesStr = string.format("%s + %d others", activeNames[1], #activeNames - 1)
					end
					RADIO_INTERCEPTOR.PillText.Text = string.format("[INTERCEPTING %d PLAYERS] %s · %s", #activeNames, namesStr, primaryChannel or "RADIO")
				end
			end
		end
	end

	local function attachVoiceTapForPlayer(targetPlr, channelLabel, channelFolder)
		if not targetPlr or targetPlr == player then return end

		-- If already tapped, refresh grace timer and channel
		if activeVoiceTaps[targetPlr] then
			activeVoiceTaps[targetPlr].Grace = 1.2
			if channelLabel then
				activeVoiceTaps[targetPlr].Channel = channelLabel
			end
			return
		end

		local char = targetPlr.Character
		local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		if not head then return end

		local outputTarget = player:FindFirstChild("MicrophoneOutput") 
			or SoundService:FindFirstChildOfClass("AudioDeviceOutput")
		if not outputTarget then return end

		local listenersList = {}

		-- 1. Tap MicrophoneGroup (Roblox Voice Chat mic at 0 studs distance)
		pcall(function()
			local l1 = Instance.new("AudioListener")
			l1.Name = "AstrocynaVoiceTap_Mic"
			l1.AudioInteractionGroup = "MicrophoneGroup"
			l1.Parent = head

			local w1 = Instance.new("Wire")
			w1.Name = "Wire"
			w1.SourceInstance = l1
			w1.TargetInstance = outputTarget
			w1.Parent = l1

			table.insert(listenersList, l1)
		end)

		-- 2. Tap Default Group (radio SFX, environment, tools)
		pcall(function()
			local l2 = Instance.new("AudioListener")
			l2.Name = "AstrocynaVoiceTap_Default"
			l2.AudioInteractionGroup = ""
			l2.Parent = head

			local w2 = Instance.new("Wire")
			w2.Name = "Wire"
			w2.SourceInstance = l2
			w2.TargetInstance = outputTarget
			w2.Parent = l2

			table.insert(listenersList, l2)
		end)

		-- 3. Tap NewbieGroup (newbie protected voice emitters)
		pcall(function()
			local l3 = Instance.new("AudioListener")
			l3.Name = "AstrocynaVoiceTap_Newbie"
			l3.AudioInteractionGroup = "NewbieGroup"
			l3.Parent = head

			local w3 = Instance.new("Wire")
			w3.Name = "Wire"
			w3.SourceInstance = l3
			w3.TargetInstance = outputTarget
			w3.Parent = l3

			table.insert(listenersList, l3)
		end)

		-- Boost / unmute any sounds in target character
		pcall(function()
			if char then
				for _, s in ipairs(char:GetDescendants()) do
					if s:IsA("Sound") and s.IsPlaying then
						if s.Volume == 0 then s.Volume = 1 end
						if s.RollOffMaxDistance < 500 then s.RollOffMaxDistance = 1000 end
					end
				end
			end
		end)

		activeVoiceTaps[targetPlr] = {
			Listeners = listenersList,
			Grace = 1.2,
			Channel = channelLabel or "RADIO"
		}

		RADIO_INTERCEPTOR.ActiveSpeaker = targetPlr
		RADIO_INTERCEPTOR.ActiveSpeakerChannel = channelLabel or "RADIO"

		-- Join channel on server if needed so native radio voice packet is also transmitted
		if channelFolder and not isPlayerInChannel(channelFolder) then
			forceJoinRadioChannel(channelFolder)
		end

		ensureAudioListenerOnCamera()
	end

	local function _startListeningToRadioTarget(targetPlr, channelLabel, channelFolder)
		attachVoiceTapForPlayer(targetPlr, channelLabel, channelFolder)
		updatePillHud()
	end

	local function stopListeningToRadioTarget()
		RADIO_INTERCEPTOR.ActiveSpeaker = nil
		RADIO_INTERCEPTOR.ActiveSpeakerChannel = nil

		cleanupAllVoiceTaps()
		ensureAudioListenerOnCamera()

		if RADIO_INTERCEPTOR.PillHud and not RADIO_INTERCEPTOR.ManualTarget then
			RADIO_INTERCEPTOR.PillHud.Visible = false
		end
	end

	local function _invokeRadioFunction(payload)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local radio = remotes and remotes:FindFirstChild("Radio")
		local radioFunc = radio and radio:FindFirstChild("Function")
		if radioFunc and radioFunc:IsA("RemoteFunction") then
			local ok, res = pcall(function()
				return radioFunc:InvokeServer(payload)
			end)
			return ok and typeof(res) == "table" and res or nil
		end
		return nil
	end




	-- Floating HUD Pill (Parented to pinnedGui so it stays active & visible even when main GUI is closed)
	local pill = Instance.new("Frame")
	pill.Name = "AstrocynaRadioPill"
	pill.Size = UDim2.new(0, 340, 0, 32)
	pill.Position = UDim2.new(0.5, -170, 0, 18)
	pill.BackgroundColor3 = THEME.MainBg
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.Visible = false
	pill.ZIndex = 85
	pill.Parent = getPinnedGui and getPinnedGui() or screenGui
	addCorner(pill, 16)
	local pStroke = addStroke(pill, Color3.fromRGB(0, 255, 140), 1.5, 0.2)
	applyNeonSweep(pStroke, 120, 2.5, 1.2, 2.0)

	local pIcon = newLabel(pill, "📻", 14, Color3.fromRGB(0, 255, 140), UDim2.new(0, 10, 0, 0), UDim2.new(0, 20, 1, 0), false, Enum.TextXAlignment.Center)
	pIcon.TextTruncate = Enum.TextTruncate.None
	local pText = newLabel(pill, "INTERCEPTING RADIO", 11, THEME.TextCyan, UDim2.new(0, 34, 0, 0), UDim2.new(1, -44, 1, 0), true)
	RADIO_INTERCEPTOR.PillHud = pill
	RADIO_INTERCEPTOR.PillText = pText

	local pillDragStart = nil
	local pillStartPos = nil
	local pillDragging = false
	local pillMoved = false

	pill.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pillDragging = true
			pillMoved = false
			pillDragStart = input.Position
			pillStartPos = pill.Position

			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					pillDragging = false
					if conn then conn:Disconnect() end
					if not pillMoved then
						if toggleRadioGui then toggleRadioGui() end
					end
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if pillDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if pillDragStart and pillStartPos then
				local delta = input.Position - pillDragStart
				if delta.Magnitude > 4 then
					pillMoved = true
					pill.Position = UDim2.new(pillStartPos.X.Scale, pillStartPos.X.Offset + delta.X, pillStartPos.Y.Scale, pillStartPos.Y.Offset + delta.Y)
				end
			end
		end
	end)

	pill.MouseEnter:Connect(function()
		pill.BackgroundTransparency = 0.05
	end)
	pill.MouseLeave:Connect(function()
		pill.BackgroundTransparency = 0.12
	end)

	-- Main Window Frame
	local rfFrame = Instance.new("Frame")
	rfFrame.Name = "AstrocynaRadioWindow"
	rfFrame.Size = UDim2.new(0, 530, 0, 520)
	rfFrame.Position = UDim2.new(0, 380, 0.5, -260)
	rfFrame.BackgroundColor3 = THEME.MainBg
	rfFrame.BackgroundTransparency = THEME.MainBgTransparency
	rfFrame.BorderSizePixel = 0
	rfFrame.Visible = false
	rfFrame.ClipsDescendants = true
	rfFrame.Parent = screenGui
	_radioWindow = rfFrame
	applyResponsiveWindowScale(rfFrame, 530, 520, false)

	local rfCorner = Instance.new("UICorner")
	rfCorner.CornerRadius = UDim.new(0, 10)
	rfCorner.Parent = rfFrame

	local rfBevel = Instance.new("UIGradient")
	rfBevel.Rotation = 90
	rfBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	rfBevel.Parent = rfFrame

	local rfStroke = Instance.new("UIStroke")
	rfStroke.Thickness = 2.0
	rfStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rfStroke.Parent = rfFrame
	applyNeonSweep(rfStroke, 110, 2.5, 1.8, 2.6)

	-- TopBar
	local rfTopBar = Instance.new("Frame")
	rfTopBar.Size = UDim2.new(1, 0, 0, 40)
	rfTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	rfTopBar.BorderSizePixel = 0
	rfTopBar.Parent = rfFrame

	local rfTopCorner = Instance.new("UICorner")
	rfTopCorner.CornerRadius = UDim.new(0, 10)
	rfTopCorner.Parent = rfTopBar

	local rfTopStroke = Instance.new("UIStroke")
	rfTopStroke.Color = Color3.fromRGB(48, 48, 54)
	rfTopStroke.Thickness = 1
	rfTopStroke.Parent = rfTopBar

	local rfTitle = Instance.new("TextLabel")
	rfTitle.Size = UDim2.new(1, -104, 1, 0)
	rfTitle.Position = UDim2.new(0, 14, 0, 0)
	rfTitle.BackgroundTransparency = 1
	rfTitle.Font = Enum.Font.GothamBold
	rfTitle.Text = "PRISON RP // WALKIE TALKIE INTERCEPTOR"
	rfTitle.TextColor3 = THEME.TextCyan
	rfTitle.TextSize = 12
	rfTitle.TextXAlignment = Enum.TextXAlignment.Left
	rfTitle.Parent = rfTopBar
	applyTextShimmer(rfTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local rfCloseBtn = Instance.new("TextButton")
	rfCloseBtn.Size = UDim2.new(0, 28, 0, 26)
	rfCloseBtn.Position = UDim2.new(1, -34, 0, 7)
	rfCloseBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	rfCloseBtn.Font = Enum.Font.GothamBold
	rfCloseBtn.Text = "X"
	rfCloseBtn.TextColor3 = THEME.TextCyan
	rfCloseBtn.TextSize = 11
	rfCloseBtn.Parent = rfTopBar
	local rfcCorner = Instance.new("UICorner")
	rfcCorner.CornerRadius = UDim.new(0, 5)
	rfcCorner.Parent = rfCloseBtn
	local rfcStroke = Instance.new("UIStroke")
	rfcStroke.Color = Color3.fromRGB(28, 60, 94)
	rfcStroke.Thickness = 1
	rfcStroke.Parent = rfCloseBtn
	hookButtonHover(rfCloseBtn, Color3.fromRGB(28, 28, 32), Color3.fromRGB(36, 18, 28), THEME.TextCyan, Color3.fromRGB(255, 120, 120))
	rfCloseBtn.MouseButton1Click:Connect(function()
		rfFrame.Visible = false
	end)

	attachAlwaysOnTopButton(rfFrame, rfTopBar, "RadioInterceptorWindow", -66, 7, 28, 26)

	makeDraggable(rfFrame, rfTopBar)

	-- Header Control Card (Status & Master Auto-Listen & Realistic FX Toggle)
	local ctrlCard = Instance.new("Frame")
	ctrlCard.Name = "ControlCard"
	ctrlCard.Size = UDim2.new(1, -20, 0, 78)
	ctrlCard.Position = UDim2.new(0, 10, 0, 48)
	ctrlCard.BackgroundColor3 = THEME.CardBg
	ctrlCard.BackgroundTransparency = 0.25
	ctrlCard.BorderSizePixel = 0
	ctrlCard.Parent = rfFrame
	addCorner(ctrlCard, 8)
	addStroke(ctrlCard, THEME.CardStroke, 1, 0.4)

	newLabel(ctrlCard, "LIVE FREQUENCY RADAR & EAVESDROPPING", 11.5, THEME.TextFrost, UDim2.new(0, 12, 0, 10), UDim2.new(1, -160, 0, 16), true)
	local cStatus = newLabel(ctrlCard, "● IDLE · NO ACTIVE TRANSMISSION", 9.5, THEME.TextDim, UDim2.new(0, 12, 0, 30), UDim2.new(1, -160, 0, 16), false)
	newLabel(ctrlCard, "Direct frequency scanner & audio eavesdropping", 8.5, Color3.fromRGB(140, 140, 150), UDim2.new(0, 12, 0, 50), UDim2.new(1, -160, 0, 16), false)

	-- Auto Listen Master Button
	local autoListenBtn = Instance.new("TextButton")
	autoListenBtn.Size = UDim2.new(0, 130, 0, 32)
	autoListenBtn.Position = UDim2.new(1, -142, 0.5, -16)
	autoListenBtn.BackgroundColor3 = THEME.BtnOff
	autoListenBtn.Font = Enum.Font.GothamBold
	autoListenBtn.Text = "AUTO-LISTEN: OFF"
	autoListenBtn.TextColor3 = THEME.BtnOffText
	autoListenBtn.TextSize = 9.5
	autoListenBtn.AutoButtonColor = false
	autoListenBtn.Parent = ctrlCard
	addCorner(autoListenBtn, 6)
	local autoStroke = addStroke(autoListenBtn, THEME.BtnOffStroke, 1, 0)

	local function updateAutoListenBtnVisual()
		if RADIO_INTERCEPTOR.Enabled then
			autoListenBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			autoListenBtn.TextColor3 = Color3.fromRGB(20, 20, 24)
			autoListenBtn.Text = "AUTO-LISTEN: ON"
			autoStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			autoListenBtn.BackgroundColor3 = THEME.BtnOff
			autoListenBtn.TextColor3 = THEME.BtnOffText
			autoListenBtn.Text = "AUTO-LISTEN: OFF"
			autoStroke.Color = THEME.BtnOffStroke
		end
	end

	hookButtonHover(autoListenBtn, THEME.BtnOff, Color3.fromRGB(44, 44, 50), THEME.BtnOffText, Color3.fromRGB(255, 255, 255))
	autoListenBtn.MouseButton1Click:Connect(function()
		RADIO_INTERCEPTOR.Enabled = not RADIO_INTERCEPTOR.Enabled
		updateAutoListenBtnVisual()
		if not RADIO_INTERCEPTOR.Enabled and not RADIO_INTERCEPTOR.ManualTarget then
			stopListeningToRadioTarget()
		end
	end)

	-- Sub Navigation Tabs Row
	local tabsRow = Instance.new("Frame")
	tabsRow.Size = UDim2.new(1, -20, 0, 30)
	tabsRow.Position = UDim2.new(0, 10, 0, 134)
	tabsRow.BackgroundTransparency = 1
	tabsRow.Parent = rfFrame

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Padding = UDim.new(0, 5)
	tabsLayout.Parent = tabsRow

	local tabDefs = {
		{ id = "All", label = "ALL CHANNELS" },
		{ id = "1. General", label = "CH 1 GEN" },
		{ id = "2. Security", label = "CH 2 SEC" },
		{ id = "3. Medical", label = "CH 3 MED" },
		{ id = "4. Command", label = "CH 4 CMD" },
	}

	local tabButtons = {}

	-- Scroll Container (Channels)
	local channelsScroll = Instance.new("ScrollingFrame")
	channelsScroll.Name = "ChannelsScroll"
	channelsScroll.Size = UDim2.new(1, -20, 1, -182)
	channelsScroll.Position = UDim2.new(0, 10, 0, 172)
	channelsScroll.BackgroundTransparency = 1
	channelsScroll.BorderSizePixel = 0
	channelsScroll.ScrollBarThickness = 4
	channelsScroll.ScrollBarImageColor3 = THEME.TextCyan
	channelsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	channelsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	channelsScroll.Parent = rfFrame

	local chLayout = Instance.new("UIListLayout")
	chLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chLayout.Padding = UDim.new(0, 8)
	chLayout.Parent = channelsScroll



	local function selectRadioSubTab(tabId)
		RADIO_INTERCEPTOR.CurrentTab = tabId
		for _, tb in ipairs(tabButtons) do
			local on = (tb.id == tabId)
			tb.btn.BackgroundColor3 = on and Color3.fromRGB(240, 240, 245) or THEME.BtnOff
			tb.btn.TextColor3 = on and Color3.fromRGB(20, 20, 24) or THEME.TextDim
			tb.stroke.Color = on and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke
		end
		channelsScroll.Visible = true
		if RADIO_INTERCEPTOR.refreshUI then
			pcall(RADIO_INTERCEPTOR.refreshUI)
		end
	end

	for i, td in ipairs(tabDefs) do
		local tbtn = Instance.new("TextButton")
		tbtn.Size = UDim2.new(0, (i == 1) and 106 or 96, 1, 0)
		tbtn.BackgroundColor3 = (td.id == "All") and Color3.fromRGB(240, 240, 245) or THEME.BtnOff
		tbtn.Font = Enum.Font.GothamBold
		tbtn.Text = td.label
		tbtn.TextColor3 = (td.id == "All") and Color3.fromRGB(20, 20, 24) or THEME.TextDim
		tbtn.TextSize = 8.5
		tbtn.AutoButtonColor = false
		tbtn.Parent = tabsRow
		addCorner(tbtn, 5)
		local tStroke = addStroke(tbtn, (td.id == "All") and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke, 1, 0)
		table.insert(tabButtons, { id = td.id, btn = tbtn, stroke = tStroke })

		tbtn.MouseButton1Click:Connect(function()
			selectRadioSubTab(td.id)
		end)
	end


	-- Refresh Channels UI
	RADIO_INTERCEPTOR.refreshUI = function()
		for _, c in ipairs(channelsScroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end

		local channelsFolder = workspace:FindFirstChild("Channels")
		if not channelsFolder then
			newLabel(channelsScroll, "workspace.Channels not loaded yet.", 11, THEME.TextDim, UDim2.new(0, 0, 0, 10), UDim2.new(1, 0, 0, 30), false, Enum.TextXAlignment.Center)
			return
		end

		local filteredChannels = {}
		for _, cDef in ipairs(RADIO_INTERCEPTOR.Channels) do
			if RADIO_INTERCEPTOR.CurrentTab == "All" or RADIO_INTERCEPTOR.CurrentTab == cDef.Folder then
				table.insert(filteredChannels, cDef)
			end
		end

		local _globalActiveTalker = nil
		local _globalActiveChannel = nil

		for chIdx, cDef in ipairs(filteredChannels) do
			local chFolder = channelsFolder:FindFirstChild(cDef.Folder)
			local memberFolders = chFolder and chFolder:GetChildren() or {}
			local memberCount = #memberFolders

			local chCard = Instance.new("Frame")
			chCard.Name = "ChannelCard_" .. cDef.Key
			chCard.Size = UDim2.new(1, -4, 0, 0)
			chCard.AutomaticSize = Enum.AutomaticSize.Y
			chCard.BackgroundColor3 = THEME.CardBg
			chCard.BackgroundTransparency = 0.2
			chCard.BorderSizePixel = 0
			chCard.LayoutOrder = chIdx
			chCard.Parent = channelsScroll
			addCorner(chCard, 8)
			addStroke(chCard, cDef.Color, 1.2, 0.3)

			local cPad = Instance.new("UIPadding")
			cPad.PaddingTop = UDim.new(0, 10)
			cPad.PaddingBottom = UDim.new(0, 10)
			cPad.PaddingLeft = UDim.new(0, 10)
			cPad.PaddingRight = UDim.new(0, 10)
			cPad.Parent = chCard

			local cardLayout = Instance.new("UIListLayout")
			cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
			cardLayout.Padding = UDim.new(0, 6)
			cardLayout.Parent = chCard

			-- Channel Header
			local headRow = Instance.new("Frame")
			headRow.Size = UDim2.new(1, 0, 0, 24)
			headRow.BackgroundTransparency = 1
			headRow.LayoutOrder = 1
			headRow.Parent = chCard

			newLabel(headRow, string.format("CH %d // %s", cDef.Number, cDef.Label), 11, cDef.Color, UDim2.new(0, 0, 0, 0), UDim2.new(0.6, 0, 1, 0), true)
			newLabel(headRow, string.format("%d CONNECTED", memberCount), 9.5, THEME.TextDim, UDim2.new(0.6, 0, 0, 0), UDim2.new(0.4, -80, 1, 0), false, Enum.TextXAlignment.Right)

			-- Join/Leave Remote Bypass Button
			local isJoined = isPlayerInChannel(cDef.Folder)
			local joinBtn = Instance.new("TextButton")
			joinBtn.Size = UDim2.new(0, 72, 0, 22)
			joinBtn.Position = UDim2.new(1, -72, 0, 1)
			joinBtn.BackgroundColor3 = isJoined and Color3.fromRGB(240, 240, 245) or THEME.BtnOff
			joinBtn.Font = Enum.Font.GothamBold
			joinBtn.Text = isJoined and "LEAVE" or "JOIN"
			joinBtn.TextColor3 = isJoined and Color3.fromRGB(20, 20, 24) or THEME.TextDim
			joinBtn.TextSize = 8.5
			joinBtn.AutoButtonColor = false
			joinBtn.Parent = headRow
			addCorner(joinBtn, 4)
			addStroke(joinBtn, isJoined and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke, 1, 0)
			hookButtonHover(joinBtn, joinBtn.BackgroundColor3, Color3.fromRGB(255, 255, 255), joinBtn.TextColor3, Color3.fromRGB(20, 20, 24))

			joinBtn.MouseButton1Click:Connect(function()
				if isJoined then
					forceLeaveRadioChannel(cDef.Folder)
				else
					forceJoinRadioChannel(cDef.Folder)
				end
				RADIO_INTERCEPTOR.refreshUI()
			end)

			-- Member List
			if memberCount == 0 then
				local emptyM = newLabel(chCard, "No active users tuned into this channel.", 9.5, Color3.fromRGB(110, 110, 120), nil, UDim2.new(1, 0, 0, 18), false)
				emptyM.LayoutOrder = 2
			else
				for mIdx, pFolder in ipairs(memberFolders) do
					local targetPlr = Players:FindFirstChild(pFolder.Name)
					local isActive = (pFolder:GetAttribute("Active") == true)
					if isActive and targetPlr and targetPlr ~= player then
						_globalActiveTalker = targetPlr
						_globalActiveChannel = cDef.Label
					end

					local isManualListening = (RADIO_INTERCEPTOR.ManualTarget == targetPlr)

					local mRow = Instance.new("Frame")
					mRow.Size = UDim2.new(1, 0, 0, 30)
					mRow.BackgroundColor3 = isActive and Color3.fromRGB(36, 18, 22) or Color3.fromRGB(16, 16, 20)
					mRow.BackgroundTransparency = 0.2
					mRow.BorderSizePixel = 0
					mRow.LayoutOrder = 10 + mIdx
					mRow.Parent = chCard
					addCorner(mRow, 5)
					addStroke(mRow, isActive and Color3.fromRGB(255, 100, 100) or THEME.CardStroke, 1, 0.4)

					newLabel(mRow, isActive and "● TALKING" or "○ IDLE", 8.5, isActive and Color3.fromRGB(255, 100, 100) or THEME.TextDim, UDim2.new(0, 8, 0, 0), UDim2.new(0, 68, 1, 0), true)

					local pNameText = targetPlr and string.format("%s (@%s)", targetPlr.DisplayName, targetPlr.Name) or pFolder.Name
					newLabel(mRow, pNameText, 10, isActive and Color3.fromRGB(255, 235, 235) or THEME.TextFrost, UDim2.new(0, 80, 0, 0), UDim2.new(1, -170, 1, 0), false)

					-- Listen Button
					local listenBtn = Instance.new("TextButton")
					listenBtn.Size = UDim2.new(0, 78, 0, 22)
					listenBtn.Position = UDim2.new(1, -84, 0.5, -11)
					listenBtn.BackgroundColor3 = isManualListening and Color3.fromRGB(240, 240, 245) or THEME.BtnOff
					listenBtn.Font = Enum.Font.GothamBold
					listenBtn.Text = isManualListening and "LISTENING" or "LISTEN"
					listenBtn.TextColor3 = isManualListening and Color3.fromRGB(20, 20, 24) or THEME.TextDim
					listenBtn.TextSize = 9
					listenBtn.AutoButtonColor = false
					listenBtn.Parent = mRow
					addCorner(listenBtn, 4)
					addStroke(listenBtn, isManualListening and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke, 1, 0)
					hookButtonHover(listenBtn, listenBtn.BackgroundColor3, Color3.fromRGB(255, 255, 255), listenBtn.TextColor3, Color3.fromRGB(20, 20, 24))

					listenBtn.MouseButton1Click:Connect(function()
						if isManualListening then
							RADIO_INTERCEPTOR.ManualTarget = nil
							removeVoiceTapForPlayer(targetPlr)
							updatePillHud()
						else
							RADIO_INTERCEPTOR.ManualTarget = targetPlr
							if not isPlayerInChannel(cDef.Folder) then
								forceJoinRadioChannel(cDef.Folder)
							end
							attachVoiceTapForPlayer(targetPlr, cDef.Label, cDef.Folder)
							updatePillHud()
						end
						RADIO_INTERCEPTOR.refreshUI()
					end)
				end
			end

			-- Live Radio Intercept Feed for this channel (Synced with native game radio)
			local chTrans = RADIO_INTERCEPTOR.RecentTransmissions[cDef.Key] or {}
			if #chTrans > 0 then
				local logBox = Instance.new("Frame")
				logBox.Name = "LiveFeed_" .. cDef.Key
				logBox.Size = UDim2.new(1, 0, 0, 0)
				logBox.AutomaticSize = Enum.AutomaticSize.Y
				logBox.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
				logBox.BackgroundTransparency = 0.35
				logBox.BorderSizePixel = 0
				logBox.LayoutOrder = 99
				logBox.Parent = chCard
				addCorner(logBox, 6)
				addStroke(logBox, cDef.Color, 0.9, 0.45)

				local lbPad = Instance.new("UIPadding")
				lbPad.PaddingTop = UDim.new(0, 5)
				lbPad.PaddingBottom = UDim.new(0, 5)
				lbPad.PaddingLeft = UDim.new(0, 8)
				lbPad.PaddingRight = UDim.new(0, 8)
				lbPad.Parent = logBox

				local lbLayout = Instance.new("UIListLayout")
				lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
				lbLayout.Padding = UDim.new(0, 3)
				lbLayout.Parent = logBox

				local headerLbl = newLabel(logBox, "📡 RECENT TRANSMISSIONS:", 9, cDef.Color, nil, UDim2.new(1, 0, 0, 14), true)
				headerLbl.LayoutOrder = 0

				local startIdx = math.max(1, #chTrans - 2)
				for i = startIdx, #chTrans do
					local item = chTrans[i]
					local tRow = Instance.new("TextLabel")
					tRow.Size = UDim2.new(1, 0, 0, 0)
					tRow.AutomaticSize = Enum.AutomaticSize.Y
					tRow.BackgroundTransparency = 1
					tRow.RichText = true
					tRow.Font = Enum.Font.Gotham
					tRow.TextSize = 9.5
					tRow.TextColor3 = item.Color or THEME.TextFrost
					tRow.TextWrapped = true
					tRow.TextXAlignment = Enum.TextXAlignment.Left
					tRow.Text = string.format("<font color=\"#6b94be\">[%s]</font> <b>%s:</b> %s", item.Time, item.Who, item.Text)
					tRow.LayoutOrder = i
					tRow.Parent = logBox
				end
			end
		end

		-- Update header status
		local activePlrList = {}
		for tPlr in pairs(activeVoiceTaps) do
			if tPlr.Parent then
				table.insert(activePlrList, tPlr.DisplayName)
			end
		end

		if #activePlrList == 0 then
			cStatus.Text = "● IDLE · NO ACTIVE TRANSMISSION"
			cStatus.TextColor3 = THEME.TextDim
		elseif #activePlrList == 1 then
			cStatus.Text = string.format("● LIVE TRANSMITTING: %s", activePlrList[1])
			cStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			cStatus.Text = string.format("● %d TRANSMITTING SIMULTANEOUSLY (%s)", #activePlrList, table.concat(activePlrList, ", "))
			cStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end

	-- Start background radio scanner engine
	local function startRadioBackgroundEngine()
		-- Hook game's native Radio Event (ReplicatedStorage.Remotes.Radio.Event)
		pcall(function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local radioFolder = remotes and remotes:FindFirstChild("Radio")
			local rEvent = radioFolder and radioFolder:FindFirstChild("Event")
			if rEvent and rEvent:IsA("RemoteEvent") then
				trackConnection(rEvent.OnClientEvent:Connect(function(action, payload)
					if action == "Line" and typeof(payload) == "table" and payload.Channel then
						local chKey = payload.Channel
						local who = payload.Who or "Radio"
						local text = payload.Text or (payload.Callout and payload.Callout) or (payload.Event and ("[" .. payload.Event .. "]")) or ""
						local col = (payload.Event == "Panic") and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 215, 120)
						addRadioTransmission(chKey, who, text, payload.Kind or "Event", col)
					end
				end))
			end
		end)

		-- Hook game's native TextChatService radio channels (RadioGeneral, RadioSecurity, etc.)
		pcall(function()
			local tcs = game:GetService("TextChatService")
			if tcs then
				trackConnection(tcs.MessageReceived:Connect(function(msg)
					if msg.TextChannel and string.sub(msg.TextChannel.Name, 1, 5) == "Radio" then
						local chKey = string.sub(msg.TextChannel.Name, 6)
						local sender = msg.TextSource and Players:GetPlayerByUserId(msg.TextSource.UserId)
						local who = sender and (sender.DisplayName .. " (@" .. sender.Name .. ")") or "Unknown"
						local col = sender and sender.TeamColor and sender.TeamColor.Color or Color3.fromRGB(180, 220, 255)
						addRadioTransmission(chKey, who, msg.Text, "Text", col)
					end
				end))
			end
		end)

		local radioAcc = 0
		-- Heartbeat loop: Scan talkers & route audio cleanly (throttled to 0.25s for 0 FPS stutter)
		trackConnection(RunService.Heartbeat:Connect(function(dt)
			radioAcc = radioAcc + (dt or 0.016)
			if radioAcc < 0.25 then return end
			radioAcc = 0

			local isListeningAnyChannel = false
			for _, chDef in ipairs(RADIO_INTERCEPTOR.Channels) do
				if isPlayerInChannel(chDef.Folder) then
					isListeningAnyChannel = true
					break
				end
			end

			-- Early exit when radio is inactive, not in any channel, and window is closed to save CPU
			if not RADIO_INTERCEPTOR.Enabled and not RADIO_INTERCEPTOR.ManualTarget and not isListeningAnyChannel and (not rfFrame or not rfFrame.Visible) then
				if activeVoiceTaps and next(activeVoiceTaps) ~= nil then
					cleanupAllVoiceTaps()
				end
				return
			end

			local channelsFolder = workspace:FindFirstChild("Channels")
			if not channelsFolder then return end

			-- Check manual target
			if RADIO_INTERCEPTOR.ManualTarget then
				local mPlr = RADIO_INTERCEPTOR.ManualTarget
				if mPlr and mPlr.Parent and mPlr.Character then
					attachVoiceTapForPlayer(mPlr, "MANUAL LISTEN")
					if activeVoiceTaps[mPlr] then
						activeVoiceTaps[mPlr].Grace = 999999
					end
				else
					RADIO_INTERCEPTOR.ManualTarget = nil
					cleanupAllVoiceTaps()
				end
			end

			-- Scan all channels for ALL active talkers simultaneously
			local currentlyActivePlrs = {}

			for _, chDef in ipairs(RADIO_INTERCEPTOR.Channels) do
				if RADIO_INTERCEPTOR.Enabled or isPlayerInChannel(chDef.Folder) then
					local chFolder = channelsFolder:FindFirstChild(chDef.Folder)
					if chFolder then
						for _, pFolder in ipairs(chFolder:GetChildren()) do
							if pFolder:IsA("Folder") and pFolder:GetAttribute("Active") == true then
								local foundPlr = Players:FindFirstChild(pFolder.Name)
								if foundPlr and foundPlr ~= player and foundPlr.Character then
									currentlyActivePlrs[foundPlr] = { Label = chDef.Label, Folder = chDef.Folder }
								end
							end
						end
					end
				end
			end

			-- Attach or refresh taps for all active talkers simultaneously
			for targetPlr, info in pairs(currentlyActivePlrs) do
				attachVoiceTapForPlayer(targetPlr, info.Label, info.Folder)
			end

			-- Handle decay and cleanup for talkers who stopped talking
			for targetPlr, data in pairs(activeVoiceTaps) do
				if targetPlr ~= RADIO_INTERCEPTOR.ManualTarget then
					if currentlyActivePlrs[targetPlr] then
						data.Grace = 1.2
					else
						data.Grace = data.Grace - dt
						if data.Grace <= 0 or not targetPlr.Parent or not targetPlr.Character then
							removeVoiceTapForPlayer(targetPlr)
						end
					end
				end
			end

			updatePillHud()
		end))
	end

	trackThread(task.spawn(startRadioBackgroundEngine))

	-- Auto-tune to Security channel on startup if not already in any channel
	trackThread(task.spawn(function()
		task.wait(2.0)
		local channelsFolder = workspace:FindFirstChild("Channels")
		if channelsFolder then
			local alreadyJoined = false
			for _, chDef in ipairs(RADIO_INTERCEPTOR.Channels) do
				if isPlayerInChannel(chDef.Folder) then
					alreadyJoined = true
					break
				end
			end
			if not alreadyJoined then
				forceJoinRadioChannel("2. Security")
			end
		end
	end))

	-- Auto-refresh UI when window is open
	trackThread(task.spawn(function()
		while true do
			task.wait(1.0)
			if rfFrame.Visible and RADIO_INTERCEPTOR.refreshUI then
				pcall(RADIO_INTERCEPTOR.refreshUI)
			end
		end
	end))

	toggleRadioGui = function()
		rfFrame.Visible = not rfFrame.Visible
		if rfFrame.Visible then
			if screenGui and not screenGui.Enabled and rfFrame.Parent ~= pinnedGui then
				local pGui = getPinnedGui and getPinnedGui() or pinnedGui
				if pGui then
					rfFrame.Parent = pGui
					rfFrame:SetAttribute("AlwaysOnTop", true)
					local pinBtn = rfFrame:FindFirstChild("AlwaysOnTopPinBtn", true)
					if pinBtn then
						pinBtn.BackgroundColor3 = Color3.fromRGB(16, 42, 68)
						pinBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
						local st = pinBtn:FindFirstChildOfClass("UIStroke")
						if st then
							st.Color = THEME.BorderBeam
							st.Thickness = 1.4
						end
					end
				end
			end
			if clampPositionToScreen then
				rfFrame.Position = clampPositionToScreen(rfFrame.Position, rfFrame.Size)
			end
			pcall(RADIO_INTERCEPTOR.refreshUI)
		end
	end
end


WIN_BUILDERS.buildGangs = function()
	local function addCorner(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
		return c
	end

	local function addStroke(inst, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		local c3 = color
		if typeof(c3) == "ColorSequence" then
			c3 = #c3.Keypoints > 0 and c3.Keypoints[1].Value or Color3.fromRGB(255, 90, 180)
		elseif typeof(c3) ~= "Color3" then
			c3 = Color3.fromRGB(255, 90, 180)
		end
		s.Color = c3
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
		return s
	end

	local function newLabel(parent, text, size, color, pos, sz, bold, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text or ""
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextSize = size or 11
		local c3 = color
		if typeof(c3) == "ColorSequence" then
			c3 = #c3.Keypoints > 0 and c3.Keypoints[1].Value or Color3.fromRGB(255, 255, 255)
		elseif typeof(c3) ~= "Color3" then
			c3 = Color3.fromRGB(255, 255, 255)
		end
		l.TextColor3 = c3
		if pos then l.Position = pos end
		if sz then l.Size = sz end
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end

	local gfFrame = Instance.new("Frame")
	gfFrame.Name = "AstrocynaGangWindow"
	gfFrame.Size = UDim2.new(0, 490, 0, 560)
	gfFrame.Position = UDim2.new(0, 360, 0.5, -280)
	gfFrame.BackgroundColor3 = THEME.MainBg
	gfFrame.BackgroundTransparency = THEME.MainBgTransparency
	gfFrame.BorderSizePixel = 0
	gfFrame.Visible = false
	gfFrame.ClipsDescendants = true
	gfFrame.Parent = screenGui
	gangWindow = gfFrame
	applyResponsiveWindowScale(gfFrame, 490, 560, false)

	addCorner(gfFrame, 10)
	local gfBevel = Instance.new("UIGradient")
	gfBevel.Rotation = 90
	gfBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	gfBevel.Parent = gfFrame

	local gfStroke = addStroke(gfFrame, Color3.fromRGB(255, 160, 60), 2.0, 0)
	applyNeonSweep(gfStroke, 110, 2.5, 1.8, 2.6)

	-- Top Bar
	local gfTopBar = Instance.new("Frame")
	gfTopBar.Size = UDim2.new(1, 0, 0, 42)
	gfTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	gfTopBar.BorderSizePixel = 0
	gfTopBar.Parent = gfFrame
	addCorner(gfTopBar, 10)
	addStroke(gfTopBar, Color3.fromRGB(48, 48, 54), 1)

	local gfIcon = newLabel(gfTopBar, "🏴‍☠️", 16, Color3.fromRGB(255, 175, 75), UDim2.new(0, 12, 0, 0), UDim2.new(0, 24, 1, 0), false, Enum.TextXAlignment.Center)
	gfIcon.TextTruncate = Enum.TextTruncate.None

	local gfTitle = newLabel(gfTopBar, "ASTROCYNA // GANG INSPECTOR", 12, Color3.fromRGB(255, 180, 80), UDim2.new(0, 40, 0, 4), UDim2.new(0, 240, 0, 18), true)
	applyTextShimmer(gfTitle, Color3.fromRGB(255, 180, 80), Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 255, 255), 1.4)
	newLabel(gfTopBar, "TERRITORY, ROSTERS & INTELLIGENCE", 8.5, THEME.TextDim, UDim2.new(0, 41, 0, 22), UDim2.new(0, 240, 0, 14), false)

	-- Top bar actions
	local gfCloseBtn = Instance.new("TextButton")
	gfCloseBtn.Size = UDim2.new(0, 28, 0, 28)
	gfCloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
	gfCloseBtn.BackgroundColor3 = Color3.fromRGB(36, 32, 34)
	gfCloseBtn.Font = Enum.Font.GothamBold
	gfCloseBtn.Text = "X"
	gfCloseBtn.TextColor3 = Color3.fromRGB(240, 130, 140)
	gfCloseBtn.TextSize = 12
	gfCloseBtn.AutoButtonColor = false
	gfCloseBtn.Parent = gfTopBar
	addCorner(gfCloseBtn, 6)
	addStroke(gfCloseBtn, Color3.fromRGB(60, 44, 48), 1)
	hookButtonHover(gfCloseBtn, Color3.fromRGB(36, 32, 34), Color3.fromRGB(215, 55, 65), Color3.fromRGB(240, 130, 140), Color3.fromRGB(255, 255, 255))
	gfCloseBtn.MouseButton1Click:Connect(function()
		gfFrame.Visible = false
	end)

	attachAlwaysOnTopButton(gfFrame, gfTopBar, "GangInspectorWindow", -68, -14, 28, 28, 0.5)

	local gfGameUiBtn = Instance.new("TextButton")
	gfGameUiBtn.Size = UDim2.new(0, 78, 0, 26)
	gfGameUiBtn.Position = UDim2.new(1, -152, 0.5, -13)
	gfGameUiBtn.BackgroundColor3 = Color3.fromRGB(18, 32, 48)
	gfGameUiBtn.Font = Enum.Font.GothamBold
	gfGameUiBtn.Text = "🌐 Game UI"
	gfGameUiBtn.TextColor3 = THEME.TextCyan
	gfGameUiBtn.TextSize = 10
	gfGameUiBtn.AutoButtonColor = false
	gfGameUiBtn.Parent = gfTopBar
	addCorner(gfGameUiBtn, 6)
	addStroke(gfGameUiBtn, THEME.BorderBeam, 1)
	hookButtonHover(gfGameUiBtn, Color3.fromRGB(18, 32, 48), Color3.fromRGB(28, 52, 78), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
	gfGameUiBtn.MouseButton1Click:Connect(function()
		pcall(GANG_SYS.openNativeGangMenu)
	end)

	local gfRefreshBtn = Instance.new("TextButton")
	gfRefreshBtn.Size = UDim2.new(0, 72, 0, 26)
	gfRefreshBtn.Position = UDim2.new(1, -198, 0.5, -13)
	gfRefreshBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	gfRefreshBtn.Font = Enum.Font.GothamBold
	gfRefreshBtn.Text = "🔄 Refresh"
	gfRefreshBtn.TextColor3 = THEME.TextFrost
	gfRefreshBtn.TextSize = 10
	gfRefreshBtn.AutoButtonColor = false
	gfRefreshBtn.Parent = gfTopBar
	addCorner(gfRefreshBtn, 6)
	addStroke(gfRefreshBtn, THEME.CardStroke, 1)
	hookButtonHover(gfRefreshBtn, Color3.fromRGB(24, 28, 36), Color3.fromRGB(36, 42, 54), THEME.TextFrost, Color3.fromRGB(255, 255, 255))

	-- Tab Switcher Bar
	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(1, -20, 0, 32)
	tabRow.Position = UDim2.new(0, 10, 0, 48)
	tabRow.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
	tabRow.BorderSizePixel = 0
	tabRow.Parent = gfFrame
	addCorner(tabRow, 8)
	addStroke(tabRow, THEME.CardStroke, 1)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabRow
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop = UDim.new(0, 3)
	tabPad.PaddingBottom = UDim.new(0, 3)
	tabPad.PaddingLeft = UDim.new(0, 4)
	tabPad.PaddingRight = UDim.new(0, 4)
	tabPad.Parent = tabRow

	local activeTab = "roster"
	local tabBtns = {}
	local tabPages = {}

	local function createTabBtn(id, labelText, order)
		local tb = Instance.new("TextButton")
		tb.Name = "Tab_" .. id
		tb.Size = UDim2.new(0.5, -3, 1, 0)
		tb.BackgroundColor3 = (activeTab == id) and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(20, 24, 32)
		tb.BackgroundTransparency = (activeTab == id) and 0.15 or 0.6
		tb.Font = Enum.Font.GothamBold
		tb.Text = labelText
		tb.TextColor3 = (activeTab == id) and Color3.fromRGB(255, 255, 255) or THEME.TextDim
		tb.TextSize = 11
		tb.AutoButtonColor = false
		tb.LayoutOrder = order
		tb.Parent = tabRow
		addCorner(tb, 6)
		local tbs = addStroke(tb, (activeTab == id) and Color3.fromRGB(255, 175, 80) or THEME.CardStroke, 1)
		tabBtns[id] = { btn = tb, stroke = tbs }
		return tb
	end

	createTabBtn("roster", "📡 Server Scan", 1)
	createTabBtn("profile", "📜 Gang Profile", 2)

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -20, 1, -90)
	body.Position = UDim2.new(0, 10, 0, 84)
	body.BackgroundTransparency = 1
	body.Parent = gfFrame

	local rosPage = Instance.new("Frame")
	rosPage.Name = "Page_Roster"
	rosPage.Size = UDim2.new(1, 0, 1, 0)
	rosPage.BackgroundTransparency = 1
	rosPage.Visible = true
	rosPage.Parent = body
	tabPages["roster"] = rosPage

	local profPage = Instance.new("Frame")
	profPage.Name = "Page_Profile"
	profPage.Size = UDim2.new(1, 0, 1, 0)
	profPage.BackgroundTransparency = 1
	profPage.Visible = false
	profPage.Parent = body
	tabPages["profile"] = profPage

	local renderServerRoster = function() end
	local renderProfile = function() end

	local function switchTab(tabId)
		activeTab = tabId
		for tid, pg in pairs(tabPages) do
			pg.Visible = (tid == tabId)
		end
		for tid, tData in pairs(tabBtns) do
			local isA = (tid == tabId)
			tData.btn.BackgroundColor3 = isA and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(20, 24, 32)
			tData.btn.BackgroundTransparency = isA and 0.15 or 0.6
			tData.btn.TextColor3 = isA and Color3.fromRGB(255, 255, 255) or THEME.TextDim
			tData.stroke.Color = isA and Color3.fromRGB(255, 175, 80) or THEME.CardStroke
		end
		if tabId == "roster" then
			renderServerRoster()
			if not GANG_SYS.isPreloadingRosters and GANG_SYS.rostersLoadedCount == 0 then
				task.spawn(function()
					pcall(GANG_SYS.fetchDirectory, false)
					GANG_SYS.fetchAllGangRosters(false)
				end)
			end
		elseif tabId == "profile" then
			renderProfile()
		end
	end

	for tid, tData in pairs(tabBtns) do
		tData.btn.MouseButton1Click:Connect(function()
			switchTab(tid)
		end)
	end

	gfRefreshBtn.MouseButton1Click:Connect(function()
		if activeTab == "roster" then
			renderServerRoster()
		elseif activeTab == "profile" then
			if GANG_SYS.selectedGangKey then
				task.spawn(function()
					GANG_SYS.fetchGangData(GANG_SYS.selectedGangKey)
					renderProfile()
				end)
			end
		end
	end)

	-- 2. Server Gang Scanner Page UI
	local rosHeader = newLabel(rosPage, "📡 SERVER GANG SCANNER [ LIVE ]", 11, Color3.fromRGB(255, 185, 90), UDim2.new(0, 4, 0, 4), UDim2.new(1, -110, 0, 16), true)
	local rosSub = newLabel(rosPage, "Scanning live nametags & gang affiliations in this server...", 9, THEME.TextDim, UDim2.new(0, 4, 0, 20), UDim2.new(1, -110, 0, 14), false)

	local rosScanBtn = Instance.new("TextButton")
	rosScanBtn.Size = UDim2.new(0, 92, 0, 26)
	rosScanBtn.Position = UDim2.new(1, -96, 0, 6)
	rosScanBtn.BackgroundColor3 = Color3.fromRGB(255, 145, 50)
	rosScanBtn.Font = Enum.Font.GothamBold
	rosScanBtn.Text = "🔄 Scan Now"
	rosScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rosScanBtn.TextSize = 10
	rosScanBtn.AutoButtonColor = false
	rosScanBtn.Parent = rosPage
	addCorner(rosScanBtn, 6)
	hookButtonHover(rosScanBtn, Color3.fromRGB(255, 145, 50), Color3.fromRGB(255, 175, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))
	rosScanBtn.MouseButton1Click:Connect(function()
		if GANG_SYS.isPreloadingRosters then return end
		rosScanBtn.Text = "⏳ Scanning..."
		task.spawn(function()
			pcall(GANG_SYS.fetchDirectory, true)
			pcall(GANG_SYS.syncServerGangRosters)
			renderServerRoster()
			GANG_SYS.fetchAllGangRosters(true, function(cur, total, isDone)
				if isDone then
					rosScanBtn.Text = "🔄 Scan Now"
					renderServerRoster()
				else
					rosSub.Text = string.format("⏳ Scanning Rosters: %d/%d Gangs...", cur, total)
				end
			end)
		end)
	end)

	local rosScroll = Instance.new("ScrollingFrame")
	rosScroll.Size = UDim2.new(1, 0, 1, -40)
	rosScroll.Position = UDim2.new(0, 0, 0, 40)
	rosScroll.BackgroundTransparency = 1
	rosScroll.BorderSizePixel = 0
	rosScroll.ScrollBarThickness = 4
	rosScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 160, 60)
	rosScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	rosScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rosScroll.Parent = rosPage

	local rosLayout = Instance.new("UIListLayout")
	rosLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rosLayout.Padding = UDim.new(0, 8)
	rosLayout.Parent = rosScroll

	renderServerRoster = function()
		for _, c in ipairs(rosScroll:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end

		pcall(GANG_SYS.syncServerGangRosters)

		local plrs = Players:GetPlayers()
		local gangsInServer = {}
		local gangOrder = {}
		local totalGangMembers = 0
		local totalHiddenTags = 0
		local unaffiliated = {}

		for _, p in ipairs(plrs) do
			local gInfo = GANG_SYS.getPlayerGang(p.UserId)
			if gInfo and gInfo.gangName and gInfo.gangName ~= "" then
				local gKey = gInfo.gangKey or gInfo.gangName
				if not gangsInServer[gKey] then
					local gCol = gInfo.tagColor or Color3.fromRGB(255, 90, 180)
					if typeof(gCol) == "ColorSequence" and #gCol.Keypoints > 0 then
						gCol = gCol.Keypoints[1].Value
					elseif typeof(gCol) ~= "Color3" then
						gCol = Color3.fromRGB(255, 90, 180)
					end
					gangsInServer[gKey] = {
						key = gKey,
						name = gInfo.gangName,
						tag = gInfo.gangTag ~= "" and gInfo.gangTag or ("[" .. gInfo.gangName .. "]"),
						color = gCol,
						members = {},
					}
					table.insert(gangOrder, gKey)
				end
				local isHidden = (gInfo.isTagHidden == true)
				table.insert(gangsInServer[gKey].members, {
					player = p,
					name = p.Name,
					displayName = p.DisplayName,
					userId = p.UserId,
					role = gInfo.role or "Member",
					isTagHidden = isHidden,
				})
				totalGangMembers = totalGangMembers + 1
				if isHidden then
					totalHiddenTags = totalHiddenTags + 1
				end
			else
				table.insert(unaffiliated, p)
			end
		end

		-- Sort gangs by member count descending
		table.sort(gangOrder, function(a, b)
			local countA = #gangsInServer[a].members
			local countB = #gangsInServer[b].members
			if countA ~= countB then return countA > countB end
			return gangsInServer[a].name < gangsInServer[b].name
		end)

		local suspects = GANG_SYS.scanSuspectAssociates(gangsInServer, unaffiliated)
		rosHeader.Text = string.format("📡 SERVER GANG SCANNER — %d GANGS DETECTED", #gangOrder)
		local hiddenSubText = totalHiddenTags > 0 and string.format(" (🕶️ %d with tag off)", totalHiddenTags) or ""
		local suspectSubText = #suspects > 0 and string.format("  ·  🤝 %d suspected allies", #suspects) or ""
		local scanStatus = GANG_SYS.isPreloadingRosters and string.format("  ·  ⏳ Background Scan (%d/%d)...", GANG_SYS.rostersLoadedCount, GANG_SYS.rostersTotalCount) or ""
		rosSub.Text = string.format("%d gang members online across %d gangs%s%s%s  ·  %d unaffiliated", totalGangMembers, #gangOrder, hiddenSubText, suspectSubText, scanStatus, #unaffiliated)

		if #gangOrder == 0 then
			local emptyCard = Instance.new("Frame")
			emptyCard.Size = UDim2.new(1, -4, 0, 160)
			emptyCard.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
			emptyCard.Parent = rosScroll
			addCorner(emptyCard, 10)
			addStroke(emptyCard, THEME.CardStroke, 1)

			newLabel(emptyCard, "📡", 32, Color3.fromRGB(255, 175, 75), UDim2.new(0, 0, 0, 20), UDim2.new(1, 0, 0, 36), false, Enum.TextXAlignment.Center)
			newLabel(emptyCard, "NO ACTIVE GANGS IN THIS SERVER", 12.5, THEME.TextFrost, UDim2.new(0, 0, 0, 64), UDim2.new(1, 0, 0, 20), true, Enum.TextXAlignment.Center)
			newLabel(emptyCard, string.format("Scanned all %d online players. No gang members detected in this server.", #plrs), 9.5, THEME.TextDim, UDim2.new(0, 20, 0, 88), UDim2.new(1, -40, 0, 20), false, Enum.TextXAlignment.Center)

			local rescanBtn = Instance.new("TextButton")
			rescanBtn.Size = UDim2.new(0, 140, 0, 28)
			rescanBtn.Position = UDim2.new(0.5, -70, 0, 116)
			rescanBtn.BackgroundColor3 = Color3.fromRGB(255, 145, 50)
			rescanBtn.Font = Enum.Font.GothamBold
			rescanBtn.Text = "🔄 Scan Again"
			rescanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			rescanBtn.TextSize = 10.5
			rescanBtn.AutoButtonColor = false
			rescanBtn.Parent = emptyCard
			addCorner(rescanBtn, 6)
			rescanBtn.MouseButton1Click:Connect(function()
				task.spawn(function()
					pcall(GANG_SYS.fetchDirectory, true)
					pcall(GANG_SYS.syncServerGangRosters)
					renderServerRoster()
					GANG_SYS.fetchAllGangRosters(true, function(_, _, isDone)
						if isDone then renderServerRoster() end
					end)
				end)
			end)
			return
		end

		-- Render each detected gang
		for gIdx, gKey in ipairs(gangOrder) do
			local g = gangsInServer[gKey]
			local mList = g.members

			-- Calculate card height: header (38px) + each member row (48px) + padding
			local cardH = 42 + (#mList * 48)
			local gangCard = Instance.new("Frame")
			gangCard.Name = "ServerGang_" .. gKey
			gangCard.Size = UDim2.new(1, -4, 0, cardH)
			gangCard.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
			gangCard.BorderSizePixel = 0
			gangCard.LayoutOrder = gIdx
			gangCard.Parent = rosScroll
			addCorner(gangCard, 10)
			local gcStroke = addStroke(gangCard, g.color, 1.2, 0.4)
			applyNeonSweep(gcStroke, 110, 2.4, 1.6, 2.5)

			-- Gang Header Bar
			local ghBar = Instance.new("Frame")
			ghBar.Size = UDim2.new(1, 0, 0, 38)
			ghBar.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
			ghBar.BorderSizePixel = 0
			ghBar.Parent = gangCard
			addCorner(ghBar, 10)

			local gIcon = newLabel(ghBar, "🏴‍☠️", 15, g.color, UDim2.new(0, 10, 0, 0), UDim2.new(0, 22, 1, 0), false, Enum.TextXAlignment.Center)
			gIcon.TextTruncate = Enum.TextTruncate.None

			newLabel(ghBar, g.tag .. " " .. g.name, 12, g.color, UDim2.new(0, 36, 0, 4), UDim2.new(1, -190, 0, 16), true)
			newLabel(ghBar, string.format("Detected in this server  ·  %d member%s active", #mList, #mList > 1 and "s" or ""), 8.5, THEME.TextDim, UDim2.new(0, 36, 0, 20), UDim2.new(1, -190, 0, 14), false)

			-- Count badge pill
			local countPill = Instance.new("Frame")
			countPill.Size = UDim2.new(0, 78, 0, 22)
			countPill.Position = UDim2.new(1, -170, 0.5, -11)
			countPill.BackgroundColor3 = Color3.fromRGB(34, 20, 32)
			countPill.BorderSizePixel = 0
			countPill.Parent = ghBar
			addCorner(countPill, 4)
			addStroke(countPill, g.color, 1, 0.5)
			newLabel(countPill, string.format("👥 %d Online", #mList), 9.5, g.color, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)

			-- Inspect Gang button
			local vGangBtn = Instance.new("TextButton")
			vGangBtn.Size = UDim2.new(0, 78, 0, 24)
			vGangBtn.Position = UDim2.new(1, -86, 0.5, -12)
			vGangBtn.BackgroundColor3 = Color3.fromRGB(255, 145, 50)
			vGangBtn.Font = Enum.Font.GothamBold
			vGangBtn.Text = "🔍 Profile"
			vGangBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			vGangBtn.TextSize = 10
			vGangBtn.AutoButtonColor = false
			vGangBtn.Parent = ghBar
			addCorner(vGangBtn, 6)
			hookButtonHover(vGangBtn, Color3.fromRGB(255, 145, 50), Color3.fromRGB(255, 175, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))
			vGangBtn.MouseButton1Click:Connect(function()
				inspectGangByKey(g.key)
			end)

			-- Members List inside Card
			local memContainer = Instance.new("Frame")
			memContainer.Size = UDim2.new(1, -16, 0, #mList * 48)
			memContainer.Position = UDim2.new(0, 8, 0, 40)
			memContainer.BackgroundTransparency = 1
			memContainer.Parent = gangCard

			local memLayout = Instance.new("UIListLayout")
			memLayout.SortOrder = Enum.SortOrder.LayoutOrder
			memLayout.Padding = UDim.new(0, 4)
			memLayout.Parent = memContainer

			for mIdx, m in ipairs(mList) do
				local mRow = Instance.new("Frame")
				mRow.Name = "Member_" .. m.name
				mRow.Size = UDim2.new(1, 0, 0, 44)
				mRow.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
				mRow.BorderSizePixel = 0
				mRow.LayoutOrder = mIdx
				mRow.Parent = memContainer
				addCorner(mRow, 6)
				addStroke(mRow, THEME.CardStroke, 1, 0.7)

				local av = Instance.new("ImageLabel")
				av.Size = UDim2.new(0, 32, 0, 32)
				av.Position = UDim2.new(0, 6, 0.5, -16)
				av.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
				av.Parent = mRow
				addCorner(av, 16)
				addStroke(av, THEME.BorderBase, 1)
				getCachedThumbnailAsync(m.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(th)
					if av and av.Parent then av.Image = th end
				end)

				if m.isTagHidden then
					newLabel(mRow, m.displayName, 11, THEME.TextFrost, UDim2.new(0, 44, 0, 6), UDim2.new(1, -210, 0, 16), true)

					local hBadge = Instance.new("Frame")
					hBadge.Size = UDim2.new(0, 62, 0, 15)
					hBadge.Position = UDim2.new(1, -204, 0, 7)
					hBadge.BackgroundColor3 = Color3.fromRGB(38, 22, 16)
					hBadge.BorderSizePixel = 0
					hBadge.Parent = mRow
					addCorner(hBadge, 3)
					addStroke(hBadge, Color3.fromRGB(255, 145, 50), 1, 0.5)
					newLabel(hBadge, "🕶️ TAG OFF", 8, Color3.fromRGB(255, 175, 75), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)

					newLabel(mRow, "@" .. m.name .. "  ·  " .. (m.role or "Member") .. "  ·  [Tag Hidden]", 9, Color3.fromRGB(255, 175, 90), UDim2.new(0, 44, 0, 24), UDim2.new(1, -140, 0, 14), false)
				else
					newLabel(mRow, m.displayName, 11, THEME.TextFrost, UDim2.new(0, 44, 0, 6), UDim2.new(1, -140, 0, 16), true)
					newLabel(mRow, "@" .. m.name .. "  ·  " .. (m.role or "Member"), 9, THEME.TextDim, UDim2.new(0, 44, 0, 24), UDim2.new(1, -140, 0, 14), false)
				end

				-- Live Health Bar
				local hBar = Instance.new("Frame")
				hBar.Size = UDim2.new(0, 44, 0, 4)
				hBar.Position = UDim2.new(1, -134, 0.5, -2)
				hBar.BackgroundColor3 = Color3.fromRGB(30, 12, 16)
				hBar.BorderSizePixel = 0
				hBar.Parent = mRow
				addCorner(hBar, 2)
				local hFill = Instance.new("Frame")
				hFill.Size = UDim2.new(1, 0, 1, 0)
				hFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
				hFill.BorderSizePixel = 0
				hFill.Parent = hBar
				addCorner(hFill, 2)

				local char = m.player.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						hFill.Size = UDim2.new(ratio, 0, 1, 0)
						if ratio <= 0.25 then hFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
						elseif ratio <= 0.5 then hFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40) end
					end
				end

				-- Spectate Button
				local specBtn = Instance.new("TextButton")
				specBtn.Size = UDim2.new(0, 72, 0, 24)
				specBtn.Position = UDim2.new(1, -78, 0.5, -12)
				specBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
				specBtn.Font = Enum.Font.GothamBold
				specBtn.Text = "👁️ Spec"
				specBtn.TextColor3 = THEME.TextCyan
				specBtn.TextSize = 9.5
				specBtn.AutoButtonColor = false
				specBtn.Parent = mRow
				addCorner(specBtn, 5)
				addStroke(specBtn, THEME.BorderBeam, 1)
				hookButtonHover(specBtn, Color3.fromRGB(18, 30, 48), Color3.fromRGB(28, 48, 76), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
				specBtn.MouseButton1Click:Connect(function()
					pcall(spectatePlayer, m.player)
				end)
			end
		end

		-- Suspected Gang Associates Card (Friends, Family, Territory, Radio, Proximity)
		if #suspects > 0 then
			local sCardH = 42 + (#suspects * 48)
			local sCard = Instance.new("Frame")
			sCard.Name = "SuspectAssociatesCard"
			sCard.Size = UDim2.new(1, -4, 0, sCardH)
			sCard.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
			sCard.BorderSizePixel = 0
			sCard.LayoutOrder = 5000
			sCard.Parent = rosScroll
			addCorner(sCard, 10)
			local scStroke = addStroke(sCard, Color3.fromRGB(255, 175, 75), 1.2, 0.4)
			applyNeonSweep(scStroke, 110, 2.4, 1.6, 2.5)

			local shBar = Instance.new("Frame")
			shBar.Size = UDim2.new(1, 0, 0, 38)
			shBar.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
			shBar.BorderSizePixel = 0
			shBar.Parent = sCard
			addCorner(shBar, 10)

			newLabel(shBar, "🤝", 15, Color3.fromRGB(255, 175, 75), UDim2.new(0, 10, 0, 0), UDim2.new(0, 22, 1, 0), false, Enum.TextXAlignment.Center)
			newLabel(shBar, "SUSPECTED GANG ASSOCIATES & ALLIES", 11.5, Color3.fromRGB(255, 185, 90), UDim2.new(0, 36, 0, 4), UDim2.new(1, -120, 0, 16), true)
			newLabel(shBar, "Detected via Friends, RP Family Name, Territory Defense, Radio Sync, or Proximity", 8.5, THEME.TextDim, UDim2.new(0, 36, 0, 20), UDim2.new(1, -120, 0, 14), false)

			local sPill = Instance.new("Frame")
			sPill.Size = UDim2.new(0, 88, 0, 22)
			sPill.Position = UDim2.new(1, -98, 0.5, -11)
			sPill.BackgroundColor3 = Color3.fromRGB(42, 30, 20)
			sPill.BorderSizePixel = 0
			sPill.Parent = shBar
			addCorner(sPill, 4)
			addStroke(sPill, Color3.fromRGB(255, 175, 75), 1, 0.5)
			newLabel(sPill, string.format("🤝 %d Allies", #suspects), 9, Color3.fromRGB(255, 185, 90), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)

			local sContainer = Instance.new("Frame")
			sContainer.Size = UDim2.new(1, -12, 0, #suspects * 48)
			sContainer.Position = UDim2.new(0, 6, 0, 40)
			sContainer.BackgroundTransparency = 1
			sContainer.Parent = sCard

			local sLayout = Instance.new("UIListLayout")
			sLayout.SortOrder = Enum.SortOrder.LayoutOrder
			sLayout.Padding = UDim.new(0, 4)
			sLayout.Parent = sContainer

			for sIdx, sPlr in ipairs(suspects) do
				local sRow = Instance.new("Frame")
				sRow.Name = "Suspect_" .. sPlr.name
				sRow.Size = UDim2.new(1, 0, 0, 44)
				sRow.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
				sRow.BorderSizePixel = 0
				sRow.LayoutOrder = sIdx
				sRow.Parent = sContainer
				addCorner(sRow, 6)
				addStroke(sRow, THEME.CardStroke, 1, 0.7)

				local av = Instance.new("ImageLabel")
				av.Size = UDim2.new(0, 32, 0, 32)
				av.Position = UDim2.new(0, 6, 0.5, -16)
				av.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
				av.Parent = sRow
				addCorner(av, 16)
				addStroke(av, THEME.BorderBase, 1)
				getCachedThumbnailAsync(sPlr.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(th)
					if av and av.Parent then av.Image = th end
				end)

				newLabel(sRow, sPlr.displayName .. "  [@" .. sPlr.name .. "]", 11, THEME.TextFrost, UDim2.new(0, 44, 0, 5), UDim2.new(1, -140, 0, 16), true)
				local reasonsStr = table.concat(sPlr.reasons, "  •  ")
				local rLbl = newLabel(sRow, reasonsStr, 8.5, Color3.fromRGB(255, 180, 95), UDim2.new(0, 44, 0, 23), UDim2.new(1, -140, 0, 16), false)
				rLbl.TextTruncate = Enum.TextTruncate.AtEnd

				-- Live Health Bar
				local hBar = Instance.new("Frame")
				hBar.Size = UDim2.new(0, 44, 0, 4)
				hBar.Position = UDim2.new(1, -134, 0.5, -2)
				hBar.BackgroundColor3 = Color3.fromRGB(30, 12, 16)
				hBar.BorderSizePixel = 0
				hBar.Parent = sRow
				addCorner(hBar, 2)
				local hFill = Instance.new("Frame")
				hFill.Size = UDim2.new(1, 0, 1, 0)
				hFill.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
				hFill.BorderSizePixel = 0
				hFill.Parent = hBar
				addCorner(hFill, 2)

				local char = sPlr.player.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						hFill.Size = UDim2.new(ratio, 0, 1, 0)
						if ratio <= 0.25 then hFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
						elseif ratio <= 0.5 then hFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40) end
					end
				end

				-- Spectate Button
				local specBtn = Instance.new("TextButton")
				specBtn.Size = UDim2.new(0, 72, 0, 24)
				specBtn.Position = UDim2.new(1, -78, 0.5, -12)
				specBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 48)
				specBtn.Font = Enum.Font.GothamBold
				specBtn.Text = "👁️ Spec"
				specBtn.TextColor3 = THEME.TextCyan
				specBtn.TextSize = 9.5
				specBtn.AutoButtonColor = false
				specBtn.Parent = sRow
				addCorner(specBtn, 5)
				addStroke(specBtn, THEME.BorderBeam, 1)
				hookButtonHover(specBtn, Color3.fromRGB(18, 30, 48), Color3.fromRGB(28, 48, 76), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
				specBtn.MouseButton1Click:Connect(function()
					pcall(spectatePlayer, sPlr.player)
				end)
			end
		end

		-- Footer card: Unaffiliated players summary
		local unCard = Instance.new("Frame")
		unCard.Name = "UnaffiliatedSummary"
		unCard.Size = UDim2.new(1, -4, 0, 34)
		unCard.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
		unCard.BorderSizePixel = 0
		unCard.LayoutOrder = 9999
		unCard.Parent = rosScroll
		addCorner(unCard, 6)
		addStroke(unCard, THEME.CardStroke, 1, 0.8)
		local unSummaryText = #suspects > 0
			and string.format("⚪ %d unaffiliated players in server  ·  🤝 %d suspected allies flagged above", #unaffiliated, #suspects)
			or string.format("⚪ %d players in server without any gang membership", #unaffiliated)
		newLabel(unCard, unSummaryText, 9, THEME.TextDim, UDim2.new(0, 12, 0, 0), UDim2.new(1, -24, 1, 0), false, Enum.TextXAlignment.Left)
	end

	GANG_SYS.onRosterUpdated = function()
		if activeTab == "roster" then
			renderServerRoster()
		end
	end

	-- 3. Profile Page UI
	local profScroll = Instance.new("ScrollingFrame")
	profScroll.Size = UDim2.new(1, 0, 1, 0)
	profScroll.BackgroundTransparency = 1
	profScroll.BorderSizePixel = 0
	profScroll.ScrollBarThickness = 4
	profScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 160, 60)
	profScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	profScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	profScroll.Parent = profPage

	local profLayout = Instance.new("UIListLayout")
	profLayout.SortOrder = Enum.SortOrder.LayoutOrder
	profLayout.Padding = UDim.new(0, 8)
	profLayout.Parent = profScroll

	renderProfile = function()
		for _, c in ipairs(profScroll:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
		end

		if not GANG_SYS.selectedGangKey then
			local emptyCard = Instance.new("Frame")
			emptyCard.Size = UDim2.new(1, -4, 0, 180)
			emptyCard.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
			emptyCard.Parent = profScroll
			addCorner(emptyCard, 10)
			addStroke(emptyCard, THEME.CardStroke, 1)

			newLabel(emptyCard, "🏴‍☠️", 32, Color3.fromRGB(255, 175, 75), UDim2.new(0, 0, 0, 24), UDim2.new(1, 0, 0, 40), false, Enum.TextXAlignment.Center)
			newLabel(emptyCard, "NO GANG SELECTED", 13, THEME.TextFrost, UDim2.new(0, 0, 0, 72), UDim2.new(1, 0, 0, 20), true, Enum.TextXAlignment.Center)
			newLabel(emptyCard, "Select a gang from the Server Scan or click 'Gang' on a player in Player List.", 10, THEME.TextDim, UDim2.new(0, 20, 0, 96), UDim2.new(1, -40, 0, 24), false, Enum.TextXAlignment.Center)

			local goScanBtn = Instance.new("TextButton")
			goScanBtn.Size = UDim2.new(0, 160, 0, 28)
			goScanBtn.Position = UDim2.new(0.5, -80, 0, 130)
			goScanBtn.BackgroundColor3 = Color3.fromRGB(255, 145, 50)
			goScanBtn.Font = Enum.Font.GothamBold
			goScanBtn.Text = "📡 View Server Scan"
			goScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			goScanBtn.TextSize = 11
			goScanBtn.AutoButtonColor = false
			goScanBtn.Parent = emptyCard
			addCorner(goScanBtn, 6)
			goScanBtn.MouseButton1Click:Connect(function()
				switchTab("roster")
			end)
			return
		end

		local gKey = GANG_SYS.selectedGangKey
		local gData = GANG_SYS.gangsByKey[gKey]

		if not gData or not gData.Members then
			local loadCard = Instance.new("Frame")
			loadCard.Size = UDim2.new(1, -4, 0, 120)
			loadCard.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
			loadCard.Parent = profScroll
			addCorner(loadCard, 8)
			addStroke(loadCard, THEME.CardStroke, 1)
			newLabel(loadCard, "Fetching gang profile from server: " .. tostring(gKey) .. "...", 11, THEME.TextCyan, UDim2.new(0, 0, 0.4, 0), UDim2.new(1, 0, 0, 24), true, Enum.TextXAlignment.Center)
			task.spawn(function()
				GANG_SYS.fetchGangData(gKey)
				if activeTab == "profile" and GANG_SYS.selectedGangKey == gKey then
					renderProfile()
				end
			end)
			return
		end

		-- Banner Card
		local banner = Instance.new("Frame")
		banner.Size = UDim2.new(1, -4, 0, 116)
		banner.BackgroundColor3 = Color3.fromRGB(16, 24, 38)
		banner.BorderSizePixel = 0
		banner.LayoutOrder = 1
		banner.Parent = profScroll
		addCorner(banner, 10)
		local bStroke = addStroke(banner, Color3.fromRGB(255, 160, 50), 1.5, 0.2)
		applyNeonSweep(bStroke, 110, 2.5, 1.8, 2.6)

		local emblem = Instance.new("ImageLabel")
		emblem.Size = UDim2.new(0, 72, 0, 72)
		emblem.Position = UDim2.new(0, 12, 0.5, -36)
		emblem.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
		emblem.Image = (gData.EmblemId and gData.EmblemId ~= "") and gData.EmblemId or "rbxassetid://119427531916831"
		emblem.ScaleType = Enum.ScaleType.Fit
		emblem.Parent = banner
		addCorner(emblem, 10)
		addStroke(emblem, Color3.fromRGB(255, 175, 75), 1.5)

		local gangTitle = (gData.Tag and gData.Tag ~= "" and ("[" .. gData.Tag .. "] ") or "") .. (gData.Name or gKey)
		newLabel(banner, gangTitle, 15, Color3.fromRGB(255, 195, 95), UDim2.new(0, 96, 0, 10), UDim2.new(1, -106, 0, 22), true)

		local rep = gData.Reputation or 0
		local cap = gData.Cap or 15
		local mCount = 0
		local inServerCount = 0
		if typeof(gData.Members) == "table" then
			for mKey, _ in pairs(gData.Members) do
				mCount = mCount + 1
				local uid = tonumber(string.match(tostring(mKey), "^(%d+)>")) or 0
				if uid > 0 and Players:GetPlayerByUserId(uid) then
					inServerCount = inServerCount + 1
				end
			end
		end

		local l1 = string.format("🏆 %s REP  ·  👥 %d/%d Total  ·  🟢 %d In Server  ·  %s", tostring(rep), mCount, cap, inServerCount, gData.RecruitOpen and "🟢 RECRUITING" or "🔒 CLOSED")
		newLabel(banner, l1, 9.5, THEME.TextCyan, UDim2.new(0, 96, 0, 34), UDim2.new(1, -106, 0, 16), true)

		local desc = gData.Description and gData.Description ~= "" and gData.Description or "No gang bio provided."
		local descL = newLabel(banner, desc, 9, THEME.TextDim, UDim2.new(0, 96, 0, 52), UDim2.new(1, -106, 0, 32), false)
		descL.TextWrapped = true

		local reg = gData.Region and ("📍 Region: " .. gData.Region) or "📍 Territory: Courtyard"
		newLabel(banner, reg, 8.5, Color3.fromRGB(180, 220, 255), UDim2.new(0, 96, 0, 88), UDim2.new(1, -106, 0, 16), false)

		-- Roster Title
		local rosTitleText = string.format("OFFICIAL MEMBERS ROSTER (%d)  —  🟢 %d In Server  ·  🌐 %d Offline / Other", mCount, inServerCount, mCount - inServerCount)
		local rosTitle = newLabel(profScroll, rosTitleText, 10.5, Color3.fromRGB(255, 185, 90), nil, UDim2.new(1, 0, 0, 20), true)
		rosTitle.LayoutOrder = 2

		-- Member list
		if typeof(gData.Members) == "table" then
			local mIdx = 2
			for mKey, mInfo in pairs(gData.Members) do
				mIdx = mIdx + 1
				local uid = tonumber(string.match(tostring(mKey), "^(%d+)>")) or 0
				local mName = typeof(mInfo) == "table" and mInfo.Name or "Unknown"
				local mRank = typeof(mInfo) == "table" and mInfo.Rank or "Member"

				local inServerPlr = uid > 0 and Players:GetPlayerByUserId(uid)

				local mRow = Instance.new("Frame")
				mRow.Name = "Member_" .. tostring(uid)
				mRow.Size = UDim2.new(1, -4, 0, 46)
				mRow.BackgroundColor3 = inServerPlr and Color3.fromRGB(20, 32, 46) or Color3.fromRGB(14, 18, 26)
				mRow.BorderSizePixel = 0
				mRow.LayoutOrder = inServerPlr and -100 or mIdx
				mRow.Parent = profScroll
				addCorner(mRow, 6)
				addStroke(mRow, inServerPlr and Color3.fromRGB(0, 215, 140) or THEME.CardStroke, 1)

				local mAv = Instance.new("ImageLabel")
				mAv.Size = UDim2.new(0, 32, 0, 32)
				mAv.Position = UDim2.new(0, 8, 0.5, -16)
				mAv.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
				mAv.Parent = mRow
				addCorner(mAv, 16)
				addStroke(mAv, THEME.BorderBase, 1)
				if uid > 0 then
					getCachedThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48, function(th)
						if mAv and mAv.Parent then mAv.Image = th end
					end)
				end

				newLabel(mRow, mName, 11, THEME.TextFrost, UDim2.new(0, 48, 0, 6), UDim2.new(1, -170, 0, 16), true)
				local rColor = (mRank == "Boss" and Color3.fromRGB(255, 195, 75)) or (mRank == "Underboss" and Color3.fromRGB(220, 140, 255)) or (mRank == "Captain" and Color3.fromRGB(100, 185, 255)) or THEME.TextDim
				newLabel(mRow, "Rank: " .. mRank .. "  ·  ID: " .. tostring(uid), 9, rColor, UDim2.new(0, 48, 0, 24), UDim2.new(1, -170, 0, 14), false)

				if inServerPlr then
					newLabel(mRow, "🟢 IN SERVER", 9, Color3.fromRGB(0, 235, 140), UDim2.new(1, -164, 0.5, -8), UDim2.new(0, 80, 0, 16), true, Enum.TextXAlignment.Right)

					local specBtn = Instance.new("TextButton")
					specBtn.Size = UDim2.new(0, 68, 0, 24)
					specBtn.Position = UDim2.new(1, -76, 0.5, -12)
					specBtn.BackgroundColor3 = Color3.fromRGB(16, 36, 56)
					specBtn.Font = Enum.Font.GothamBold
					specBtn.Text = "👁️ Spec"
					specBtn.TextColor3 = THEME.TextCyan
					specBtn.TextSize = 10
					specBtn.AutoButtonColor = false
					specBtn.Parent = mRow
					addCorner(specBtn, 6)
					addStroke(specBtn, THEME.BorderBeam, 1)
					hookButtonHover(specBtn, Color3.fromRGB(16, 36, 56), Color3.fromRGB(28, 54, 84), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
					specBtn.MouseButton1Click:Connect(function()
						pcall(spectatePlayer, inServerPlr)
					end)
				else
					newLabel(mRow, "🌐 OTHER / OFFLINE", 8.5, Color3.fromRGB(145, 160, 185), UDim2.new(1, -210, 0.5, -8), UDim2.new(0, 126, 0, 16), true, Enum.TextXAlignment.Right)

					local copyBtn = Instance.new("TextButton")
					copyBtn.Size = UDim2.new(0, 68, 0, 24)
					copyBtn.Position = UDim2.new(1, -76, 0.5, -12)
					copyBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
					copyBtn.Font = Enum.Font.Gotham
					copyBtn.Text = "📋 Copy ID"
					copyBtn.TextColor3 = THEME.TextDim
					copyBtn.TextSize = 9.5
					copyBtn.AutoButtonColor = false
					copyBtn.Parent = mRow
					addCorner(copyBtn, 6)
					addStroke(copyBtn, THEME.CardStroke, 1)
					copyBtn.MouseButton1Click:Connect(function()
						if setclipboard then pcall(setclipboard, tostring(uid)) end
					end)
				end
			end
		end

		-- Bottom actions
		local botRow = Instance.new("Frame")
		botRow.Size = UDim2.new(1, -4, 0, 36)
		botRow.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
		botRow.LayoutOrder = 999
		botRow.Parent = profScroll
		addCorner(botRow, 6)

		local backBtn = Instance.new("TextButton")
		backBtn.Size = UDim2.new(0, 140, 0, 26)
		backBtn.Position = UDim2.new(0, 8, 0.5, -13)
		backBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
		backBtn.Font = Enum.Font.GothamBold
		backBtn.Text = "⬅ Back to Server Scan"
		backBtn.TextColor3 = THEME.TextFrost
		backBtn.TextSize = 10
		backBtn.AutoButtonColor = false
		backBtn.Parent = botRow
		addCorner(backBtn, 5)
		backBtn.MouseButton1Click:Connect(function()
			switchTab("roster")
		end)

		local openGameBtn = Instance.new("TextButton")
		openGameBtn.Size = UDim2.new(0, 140, 0, 26)
		openGameBtn.Position = UDim2.new(1, -148, 0.5, -13)
		openGameBtn.BackgroundColor3 = Color3.fromRGB(255, 145, 50)
		openGameBtn.Font = Enum.Font.GothamBold
		openGameBtn.Text = "🌐 Open Game Menu"
		openGameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		openGameBtn.TextSize = 10
		openGameBtn.AutoButtonColor = false
		openGameBtn.Parent = botRow
		addCorner(openGameBtn, 5)
		openGameBtn.MouseButton1Click:Connect(function()
			pcall(GANG_SYS.openNativeGangMenu)
		end)
	end

	inspectGangByKey = function(gangKey)
		if not gangKey or gangKey == "" then return end
		GANG_SYS.selectedGangKey = gangKey
		if gfFrame then
			gfFrame.Visible = true
			if clampPositionToScreen then
				gfFrame.Position = clampPositionToScreen(gfFrame.Position, gfFrame.Size)
			end
			switchTab("profile")
		end
	end

	toggleGangGui = function()
		gfFrame.Visible = not gfFrame.Visible
		if gfFrame.Visible then
			if clampPositionToScreen then
				gfFrame.Position = clampPositionToScreen(gfFrame.Position, gfFrame.Size)
			end
			if activeTab == "roster" then
				renderServerRoster()
			elseif activeTab == "profile" then
				renderProfile()
			end
		end
	end

	makeDraggable(gfFrame, gfTopBar)
end

-- =====================================================================
-- 📍 MAP WAYPOINTS & TELEPORT SYSTEM (PRISON RP ENGINE)
-- =====================================================================
openGameUI = function(uiName)
	pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local guiTemplates = rs:FindFirstChild("GuiTemplates")
		if not guiTemplates then return end
		local targetGui = nil
		local mainCenter = guiTemplates:FindFirstChild("MainCenter")
		if mainCenter and mainCenter:FindFirstChild(uiName) then
			targetGui = mainCenter:FindFirstChild(uiName)
		end
		local mainMovable = guiTemplates:FindFirstChild("MainMovable")
		if not targetGui and mainMovable and mainMovable:FindFirstChild(uiName) then
			targetGui = mainMovable:FindFirstChild(uiName)
		end
		local center = guiTemplates:FindFirstChild("Center")
		if not targetGui and center and center:FindFirstChild(uiName) then
			targetGui = center:FindFirstChild(uiName)
		end
		if targetGui then
			local pGui = player:FindFirstChildOfClass("PlayerGui")
			if pGui then
				local mainGui = pGui:FindFirstChild("MainGui")
				local parentTarget = (mainGui and (mainGui:FindFirstChild("Center") or mainGui:FindFirstChild("Movable"))) or pGui
				local existing = parentTarget:FindFirstChild(uiName) or pGui:FindFirstChild(uiName)
				if existing then
					existing.Visible = not existing.Visible
				else
					local clone = targetGui:Clone()
					clone.Visible = true
					clone.Parent = parentTarget
				end
			end
		end
	end)
end

	function buildMainWindow()
	local ACCENT = THEME.CyanPrimary
	local ACCENT2 = Color3.fromRGB(150, 110, 255)
	local MAIN_W, MAIN_H, HEADER_H, SIDE_W = 740, 470, 54, 176
	local PANEL_BG = Color3.fromRGB(14, 24, 42)

	local function addCorner(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
		return c
	end

	local function addStroke(inst, color, thickness, transparency)
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness or 1
		s.Transparency = transparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
		return s
	end

	local function newLabel(parent, text, size, color, pos, sz, bold, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text
		l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		l.TextSize = size
		l.TextColor3 = color
		l.Position = pos
		l.Size = sz
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end

	-- =====================================================================
	-- MAIN WINDOW (Modern Cyber Glassmorphism Dashboard)
	-- =====================================================================
	local main = Instance.new("Frame")
	mainWindow = main
	main.Name = "MainFrame"
	main.Size = UDim2.new(0, MAIN_W, 0, MAIN_H)
	main.Position = UDim2.new(0, 45, 0.5, -math.floor(MAIN_H / 2))
	main.BackgroundColor3 = THEME.MainBg
	main.BackgroundTransparency = THEME.MainBgTransparency
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent = screenGui
	addCorner(main, 10)
	applyResponsiveWindowScale(main, MAIN_W, MAIN_H, true)

	local mainGrad = Instance.new("UIGradient")
	mainGrad.Rotation = 90
	mainGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.5, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient),
	})
	mainGrad.Parent = main

	local mainStroke = addStroke(main, THEME.BorderBase, 1.2, 0)
	applyNeonSweep(mainStroke, 80, 1.8, 1.0, 1.4)

	-- ---------------------------------------------------------------- Header
	local header = Instance.new("Frame")
	header.Name = "TopBar"
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.Parent = main

	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, -28, 0, 1)
	headerLine.Position = UDim2.new(0, 14, 1, -1)
	headerLine.BackgroundColor3 = THEME.CardStroke
	headerLine.BackgroundTransparency = 0.2
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header

	pcall(ensureIconAsset)

	local ResolvedIconId = ""
	if type(resolveIconAsset) == "function" then
		ResolvedIconId = resolveIconAsset("Icon name tag/Iconhud.png")
		if ResolvedIconId == "" then ResolvedIconId = resolveIconAsset("Iconhud.png") end
		if ResolvedIconId == "" then ResolvedIconId = resolveIconAsset(ICON_PATH) end
		if ResolvedIconId == "" then ResolvedIconId = resolveIconAsset("Icon.png") end
	end

	local logo = Instance.new("Frame")
	logo.Name = "LogoFrame"
	logo.Size = UDim2.new(0, 36, 0, 36)
	logo.Position = UDim2.new(0, 16, 0, 9)
	logo.BackgroundColor3 = THEME.CardBg
	logo.BackgroundTransparency = 0.1
	logo.BorderSizePixel = 0
	logo.Parent = header
	addCorner(logo, 8)
	addStroke(logo, THEME.CardStroke, 1, 0.2)

	local logoImg = Instance.new("ImageLabel")
	logoImg.Name = "LogoImage"
	logoImg.Size = UDim2.new(1, -6, 1, -6)
	logoImg.Position = UDim2.new(0.5, 0, 0.5, 0)
	logoImg.AnchorPoint = Vector2.new(0.5, 0.5)
	logoImg.BackgroundTransparency = 1
	logoImg.Image = (ResolvedIconId and ResolvedIconId ~= "") and ResolvedIconId or "rbxassetid://136672364093581"
	if ResolvedIconId == "" then
		logoImg.ImageColor3 = Color3.fromRGB(235, 235, 235)
	end
	logoImg.ScaleType = Enum.ScaleType.Fit
	logoImg.Parent = logo
	addCorner(logoImg, 6)

	local title = newLabel(header, "PRISON RP // SPY TOOL V1.2.0", 16, THEME.TextCyan, UDim2.new(0, 60, 0, 8), UDim2.new(0, 240, 0, 22), true)
	title.ZIndex = 2
	newLabel(header, "SPY TOOL // HIDE,WATCH,REPORT", 9, THEME.TextDim, UDim2.new(0, 61, 0, 30), UDim2.new(0, 280, 0, 14), false)

	local headerStats = newLabel(header, "60 FPS  ·  24 ms", 11, THEME.TextFrost, UDim2.new(1, -230, 0.5, -10), UDim2.new(0, 145, 0, 20), true, Enum.TextXAlignment.Right)

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 28, 0, 28)
	minBtn.Position = UDim2.new(1, -74, 0.5, -14)
	minBtn.BackgroundColor3 = THEME.BtnOff
	minBtn.Font = Enum.Font.GothamBold
	minBtn.Text = "-"
	minBtn.TextColor3 = THEME.BtnOffText
	minBtn.TextSize = 14
	minBtn.AutoButtonColor = false
	minBtn.Parent = header
	addCorner(minBtn, 6)
	addStroke(minBtn, THEME.BtnOffStroke, 1, 0)
	hookButtonHover(minBtn, THEME.BtnOff, Color3.fromRGB(48, 48, 54), THEME.BtnOffText, Color3.fromRGB(255, 255, 255))

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
	closeBtn.BackgroundColor3 = Color3.fromRGB(36, 32, 34)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(240, 130, 140)
	closeBtn.TextSize = 12
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	addCorner(closeBtn, 6)
	addStroke(closeBtn, Color3.fromRGB(60, 44, 48), 1, 0)
	hookButtonHover(closeBtn, Color3.fromRGB(36, 32, 34), Color3.fromRGB(215, 55, 65), Color3.fromRGB(240, 130, 140), Color3.fromRGB(255, 255, 255))
	closeBtn.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	-- ---------------------------------------------------------------- Sidebar
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Position = UDim2.new(0, 12, 0, HEADER_H + 10)
	sidebar.Size = UDim2.new(0, SIDE_W - 16, 1, -(HEADER_H + 10) - 44)
	sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	sidebar.BackgroundTransparency = 0.2
	sidebar.BorderSizePixel = 0
	sidebar.Parent = main
	addCorner(sidebar, 10)
	addStroke(sidebar, THEME.CardStroke, 1, 0.3)

	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sidebar
	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingTop = UDim.new(0, 8)
	sidePad.PaddingLeft = UDim.new(0, 8)
	sidePad.PaddingRight = UDim.new(0, 8)
	sidePad.Parent = sidebar

	local footerHint = newLabel(main, "[Left Browser / RightCtrl]  Toggle Spy Tool", 9, THEME.TextDim, UDim2.new(0, 20, 1, -32), UDim2.new(0, SIDE_W - 28, 0, 18), false, Enum.TextXAlignment.Center)

	-- ---------------------------------------------------------------- Content area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Position = UDim2.new(0, SIDE_W + 8, 0, HEADER_H + 10)
	contentArea.Size = UDim2.new(1, -(SIDE_W + 8) - 14, 1, -(HEADER_H + 10) - 14)
	contentArea.BackgroundTransparency = 1
	contentArea.ClipsDescendants = false
	contentArea.Parent = main

	local pages = {}

	local function makePage(id)
		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. id
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = ACCENT
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.Visible = false
		page.Parent = contentArea
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 10)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = page
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.Parent = page
		pages[id] = page
		return page
	end

	local function makeSection(page, text, order)
		local l = newLabel(page, text, 10, THEME.TextDim, UDim2.new(0, 2, 0, 0), UDim2.new(1, -2, 0, 16), true)
		l.LayoutOrder = order
		return l
	end

	local function makeGrid(page, order, cellH, cols)
		local g = Instance.new("Frame")
		g.BackgroundTransparency = 1
		g.Size = UDim2.new(1, 0, 0, 0)
		g.AutomaticSize = Enum.AutomaticSize.Y
		g.LayoutOrder = order
		g.Parent = page
		local lay = Instance.new("UIGridLayout")
		lay.CellSize = UDim2.new(1 / cols, -math.floor(10 * (cols - 1) / cols + 0.5), 0, cellH)
		lay.CellPadding = UDim2.new(0, 10, 0, 10)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = g
		return g
	end

	local function createCard(name, parent, order)
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.new(1, 0, 0, 92)
		card.BackgroundColor3 = PANEL_BG
		card.BackgroundTransparency = 0.28
		card.BorderSizePixel = 0
		card.LayoutOrder = order or 0
		card.Parent = parent
		addCorner(card, 12)

		local cGrad = Instance.new("UIGradient")
		cGrad.Rotation = 90
		cGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 44, 72)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 28)),
		})
		cGrad.Parent = card

		local cStroke = addStroke(card, Color3.fromRGB(255, 255, 255), 1, 0.5)
		local sg = Instance.new("UIGradient")
		sg.Rotation = 35
		sg.Color = ColorSequence.new(ACCENT, ACCENT2)
		sg.Parent = cStroke
		return card
	end

	local function addIconChip(card, glyph, accent)
		local chip = Instance.new("Frame")
		chip.Size = UDim2.new(0, 40, 0, 40)
		chip.Position = UDim2.new(0, 12, 0, 12)
		chip.BackgroundColor3 = Color3.fromRGB(10, 22, 40)
		chip.BorderSizePixel = 0
		chip.Parent = card
		addCorner(chip, 10)
		addStroke(chip, accent, 1, 0.35)
		local g = newLabel(chip, glyph, 19, accent, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)
		g.TextTruncate = Enum.TextTruncate.None
		return chip
	end

	local function addCardTexts(card, titleText, subText)
		local t = newLabel(card, titleText, 13, THEME.TextFrost, UDim2.new(0, 62, 0, 14), UDim2.new(1, -74, 0, 18), true)
		local s = newLabel(card, subText, 10, THEME.TextDim, UDim2.new(0, 62, 0, 34), UDim2.new(1, -74, 0, 16), false)
		return t, s
	end

	local function makeToggleCard(parent, order, name, glyph, accent, titleText, subText)
		local card = createCard(name, parent, order)
		addIconChip(card, glyph, accent)
		addCardTexts(card, titleText, subText)

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -24, 0, 26)
		btn.Position = UDim2.new(0, 12, 1, -36)
		btn.BackgroundColor3 = THEME.BtnOff
		btn.Font = Enum.Font.GothamBold
		btn.Text = "OFF"
		btn.TextColor3 = THEME.BtnOffText
		btn.TextSize = 11
		btn.AutoButtonColor = false
		btn.Parent = card
		addCorner(btn, 8)
		local stroke = addStroke(btn, THEME.BtnOffStroke, 1, 0)
		return card, btn, stroke
	end

	local function makeLaunchCard(parent, order, name, glyph, accent, titleText, subText, btnText, onClick)
		local card = createCard(name, parent, order)
		addIconChip(card, glyph, accent)
		local _, subLabel = addCardTexts(card, titleText, subText)

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -24, 0, 26)
		btn.Position = UDim2.new(0, 12, 1, -36)
		btn.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		btn.Font = Enum.Font.GothamBold
		btn.Text = btnText
		btn.TextColor3 = Color3.fromRGB(20, 20, 24)
		btn.TextSize = 11
		btn.AutoButtonColor = false
		btn.Parent = card
		addCorner(btn, 8)
		addStroke(btn, Color3.fromRGB(200, 200, 205), 1, 0.2)
		hookButtonHover(btn, Color3.fromRGB(235, 235, 240), Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 24), Color3.fromRGB(10, 10, 12))
		btn.MouseButton1Click:Connect(onClick)
		return card, btn, subLabel
	end

	-- ---------------------------------------------------------------- Tabs
	local TAB_DEFS = {
		{ id = "dashboard", icon = "🏠", name = "Dashboard" },
		{ id = "movement", icon = "🚀", name = "Movement" },
		{ id = "spy", icon = "🎭", name = "Spy & Visuals" },
		{ id = "wardrobe", icon = "👔", name = "Role Wardrobe" },
		{ id = "audio", icon = "🎵", name = "Boombox" },
		{ id = "watchdog", icon = "🛰️", name = "Watchdog" },
	}
	local tabButtons = {}
	local activeTabId = nil

	local function selectTab(id)
		activeTabId = id
		for pid, pg in pairs(pages) do
			pg.Visible = (pid == id)
		end
		for pid, t in pairs(tabButtons) do
			local on = (pid == id)
			t.btn.BackgroundColor3 = on and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(28, 28, 32)
			TweenService:Create(t.btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = on and 0 or 1 }):Play()
			t.label.TextColor3 = on and Color3.fromRGB(30, 30, 30) or THEME.TextDim
			if t.icon then
				t.icon.TextColor3 = on and Color3.fromRGB(30, 30, 30) or THEME.TextCyan
			end
			t.bar.Visible = false
			t.stroke.Transparency = on and 1 or 1
		end
	end

	for i, def in ipairs(TAB_DEFS) do
		makePage(def.id)

		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. def.id
		btn.Size = UDim2.new(1, 0, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(14, 52, 80)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn.Parent = sidebar
		addCorner(btn, 10)
		local tStroke = addStroke(btn, ACCENT, 1, 1)

		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(0, 3, 0.55, 0)
		bar.Position = UDim2.new(0, 0, 0.225, 0)
		bar.BackgroundColor3 = ACCENT
		bar.BorderSizePixel = 0
		bar.Visible = false
		bar.Parent = btn
		addCorner(bar, 2)

		local icon = newLabel(btn, def.icon, 15, THEME.TextCyan, UDim2.new(0, 10, 0, 0), UDim2.new(0, 26, 1, 0), false, Enum.TextXAlignment.Center)
		icon.TextTruncate = Enum.TextTruncate.None
		local label = newLabel(btn, def.name, 12, THEME.TextDim, UDim2.new(0, 42, 0, 0), UDim2.new(1, -48, 1, 0), true)

		tabButtons[def.id] = { btn = btn, label = label, bar = bar, stroke = tStroke, icon = icon }

		btn.MouseEnter:Connect(function()
			if activeTabId ~= def.id then
				TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.65 }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if activeTabId ~= def.id then
				TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			end
		end)
		btn.MouseButton1Click:Connect(function()
			selectTab(def.id)
		end)
	end

	-- ================================================================ PAGE: DASHBOARD
	local dashPage = pages["dashboard"]
	local statValues = {}
	local modulePills = {}
	local outfitSubLabel = nil

	makeSection(dashPage, "LIVE TELEMETRY", 1)
	local statsRow = Instance.new("Frame")
	statsRow.BackgroundTransparency = 1
	statsRow.Size = UDim2.new(1, 0, 0, 78)
	statsRow.LayoutOrder = 2
	statsRow.Parent = dashPage
	local statsGrid = Instance.new("UIGridLayout")
	statsGrid.CellSize = UDim2.new(0.25, -8, 1, 0)
	statsGrid.CellPadding = UDim2.new(0, 10, 0, 0)
	statsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	statsGrid.Parent = statsRow

	local function makeStat(id, labelText, accent, order)
		local tile = createCard("Stat_" .. id, statsRow, order)
		newLabel(tile, labelText, 10, THEME.TextDim, UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 14), true)
		statValues[id] = newLabel(tile, "--", 22, accent, UDim2.new(0, 12, 0, 28), UDim2.new(1, -24, 0, 30), true)
		local meter = Instance.new("Frame")
		meter.Size = UDim2.new(1, -24, 0, 3)
		meter.Position = UDim2.new(0, 12, 1, -12)
		meter.BackgroundColor3 = accent
		meter.BackgroundTransparency = 0.45
		meter.BorderSizePixel = 0
		meter.Parent = tile
		addCorner(meter, 2)
	end
	makeStat("fps", "FPS", Color3.fromRGB(0, 230, 160), 1)
	makeStat("ping", "PING (MS)", Color3.fromRGB(0, 215, 255), 2)
	makeStat("players", "PLAYERS", Color3.fromRGB(150, 110, 255), 3)
	makeStat("modules", "ACTIVE MODULES", Color3.fromRGB(255, 170, 60), 4)

	makeSection(dashPage, "MODULE STATUS", 3)
	local pillRow = Instance.new("Frame")
	pillRow.BackgroundTransparency = 1
	pillRow.Size = UDim2.new(1, 0, 0, 32)
	pillRow.LayoutOrder = 4
	pillRow.Parent = dashPage
	local pillGrid = Instance.new("UIGridLayout")
	pillGrid.CellSize = UDim2.new(0.2, -9, 1, 0)
	pillGrid.CellPadding = UDim2.new(0, 10, 0, 0)
	pillGrid.SortOrder = Enum.SortOrder.LayoutOrder
	pillGrid.Parent = pillRow

	for i, def in ipairs({
		{ "FLY", function() return isFlying end },
		{ "GHOST", function() return isInvis end },
		{ "SPY", function() return isDisguiseEnabled end },
		{ "ESP", function() return isEspEnabled end },
		{ "AURA", function() return isAuraEnabled end },
	}) do
		local pill = Instance.new("Frame")
		pill.BackgroundColor3 = PANEL_BG
		pill.BackgroundTransparency = 0.3
		pill.BorderSizePixel = 0
		pill.LayoutOrder = i
		pill.Parent = pillRow
		addCorner(pill, 8)
		local pStroke = addStroke(pill, THEME.BtnOffStroke, 1, 0.2)
		local pLabel = newLabel(pill, "● " .. def[1], 10, THEME.TextDim, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), true, Enum.TextXAlignment.Center)
		modulePills[i] = { label = pLabel, stroke = pStroke, name = def[1], check = def[2] }
	end

	makeSection(dashPage, "QUICK LAUNCH", 5)
	local chipGrid = makeGrid(dashPage, 6, 46, 3)

	local function makeChip(order, glyph, labelText, accent, onClick)
		local chip = Instance.new("TextButton")
		chip.Text = ""
		chip.AutoButtonColor = false
		chip.BackgroundColor3 = PANEL_BG
		chip.BackgroundTransparency = 0.3
		chip.BorderSizePixel = 0
		chip.LayoutOrder = order
		chip.Parent = chipGrid
		addCorner(chip, 10)
		addStroke(chip, accent, 1, 0.55)
		local g = newLabel(chip, glyph, 16, accent, UDim2.new(0, 10, 0, 0), UDim2.new(0, 26, 1, 0), false, Enum.TextXAlignment.Center)
		g.TextTruncate = Enum.TextTruncate.None
		newLabel(chip, labelText, 11, THEME.TextFrost, UDim2.new(0, 40, 0, 0), UDim2.new(1, -46, 1, 0), true)
		chip.MouseEnter:Connect(function()
			TweenService:Create(chip, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(24, 46, 74), BackgroundTransparency = 0.1 }):Play()
		end)
		chip.MouseLeave:Connect(function()
			TweenService:Create(chip, TweenInfo.new(0.15), { BackgroundColor3 = PANEL_BG, BackgroundTransparency = 0.3 }):Play()
		end)
		chip.MouseButton1Click:Connect(onClick)
	end

	makeChip(1, "👥", "Players Panel", Color3.fromRGB(0, 190, 255), function() togglePlayersGui() end)
	makeChip(2, "💬", "Live Chatlogs", Color3.fromRGB(0, 215, 255), function() toggleChatlogsGui() end)
	makeChip(3, "🎵", "Boombox", Color3.fromRGB(150, 110, 255), function() toggleBoomboxGui() end)
	makeChip(4, "👔", "Role Outfits", Color3.fromRGB(255, 170, 60), function() toggleOutfitGui() end)
	makeChip(5, "🚨", "Game Incidents", Color3.fromRGB(255, 90, 110), function() toggleHackerGui() end)
	makeChip(6, "✨", "Aura Settings", Color3.fromRGB(220, 130, 255), function() toggleAuraMenu() end)
	makeChip(7, "🛡️", "Server Staff", Color3.fromRGB(255, 110, 170), function() ADMIN_SYS.toggleServerStaffGui() end)
	makeChip(8, "🏴‍☠️", "Gang Inspector", Color3.fromRGB(255, 150, 50), function() toggleGangGui() end)
	makeChip(9, "⚡", "Anti-Cheat", Color3.fromRGB(255, 45, 120), function() ADMIN_SYS.toggleCheatGui() end)
	makeChip(10, "🥋", "Fight Styles", Color3.fromRGB(255, 180, 50), function() openGameUI("FightStyles") end)
	makeChip(11, "🎣", "Fishing Shop", Color3.fromRGB(80, 190, 255), function() openGameUI("RodShop") end)
	makeChip(12, "🎭", "Emotes Menu", Color3.fromRGB(0, 240, 255), function() EMOTE_SYS.toggleEmotesGui() end)

	-- ================================================================ PAGE: MOVEMENT
	local movePage = pages["movement"]
	makeSection(movePage, "FLIGHT & GHOST", 1)
	local moveGrid = makeGrid(movePage, 2, 92, 2)
	local _, flyBtn, fStroke = makeToggleCard(moveGrid, 1, "FlyCard", "🕊️", THEME.ActiveFly, "Smooth Flight & Noclip", "Instant Snap + IY Noclip Engine")
	local _, invisBtn, invStroke = makeToggleCard(moveGrid, 2, "InvisCard", "👻", THEME.ActiveInvis, "Ghost (Fake AFK)", "Others See You Stand Still")

	makeSection(movePage, "FLIGHT SPEED", 3)
	local speedCard = createCard("SpeedCard", movePage, 4)
	speedCard.Size = UDim2.new(1, 0, 0, 112)

	local SPEED_MIN, SPEED_MAX, SPEED_STEP = 20, 300, 5
	newLabel(speedCard, "Flight Speed", 12, THEME.TextFrost, UDim2.new(0, 16, 0, 12), UDim2.new(0.5, -16, 0, 18), true)
	local speedValue = newLabel(speedCard, tostring(SETTINGS.FLY_SPEED), 14, ACCENT, UDim2.new(0.5, 0, 0, 12), UDim2.new(0.5, -16, 0, 18), true, Enum.TextXAlignment.Right)

	local speedTrack = Instance.new("Frame")
	speedTrack.Size = UDim2.new(1, -32, 0, 8)
	speedTrack.Position = UDim2.new(0, 16, 0, 46)
	speedTrack.BackgroundColor3 = Color3.fromRGB(10, 18, 30)
	speedTrack.BorderSizePixel = 0
	speedTrack.Parent = speedCard
	addCorner(speedTrack, 4)
	addStroke(speedTrack, THEME.CardStroke, 1, 0)

	local speedFill = Instance.new("Frame")
	speedFill.Size = UDim2.new(0.3, 0, 1, 0)
	speedFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	speedFill.BorderSizePixel = 0
	speedFill.Parent = speedTrack
	addCorner(speedFill, 4)
	local speedFillGrad = Instance.new("UIGradient")
	speedFillGrad.Color = ColorSequence.new(ACCENT, ACCENT2)
	speedFillGrad.Parent = speedFill

	local speedKnob = Instance.new("Frame")
	speedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	speedKnob.Size = UDim2.new(0, 16, 0, 16)
	speedKnob.Position = UDim2.new(0.3, 0, 0.5, 0)
	speedKnob.BackgroundColor3 = Color3.fromRGB(235, 250, 255)
	speedKnob.BorderSizePixel = 0
	speedKnob.ZIndex = 3
	speedKnob.Parent = speedTrack
	addCorner(speedKnob, 8)
	addStroke(speedKnob, ACCENT, 1.5, 0)

	local speedHit = Instance.new("TextButton")
	speedHit.AnchorPoint = Vector2.new(0, 0.5)
	speedHit.Size = UDim2.new(1, 0, 0, 28)
	speedHit.Position = UDim2.new(0, 0, 0.5, 0)
	speedHit.BackgroundTransparency = 1
	speedHit.Text = ""
	speedHit.AutoButtonColor = false
	speedHit.ZIndex = 4
	speedHit.Parent = speedTrack

	local speedChips = {}
	local function setFlySpeed(v)
		v = math.clamp(math.floor((tonumber(v) or SETTINGS.FLY_SPEED) / SPEED_STEP + 0.5) * SPEED_STEP, SPEED_MIN, SPEED_MAX)
		SETTINGS.FLY_SPEED = v
		local frac = (v - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
		speedFill.Size = UDim2.new(frac, 0, 1, 0)
		speedKnob.Position = UDim2.new(frac, 0, 0.5, 0)
		speedValue.Text = tostring(v)
		for _, c in ipairs(speedChips) do
			local isActive = (c.value == v)
			c.btn.BackgroundColor3 = isActive and THEME.ActiveFly or THEME.BtnOff
			c.btn.TextColor3 = isActive and THEME.BtnActiveText or THEME.BtnOffText
			c.stroke.Color = isActive and Color3.fromRGB(200, 200, 205) or THEME.BtnOffStroke
		end
	end

	local speedDragging = false
	local function setSpeedFromX(x)
		local w = speedTrack.AbsoluteSize.X
		if w <= 0 then return end
		local frac = math.clamp((x - speedTrack.AbsolutePosition.X) / w, 0, 1)
		setFlySpeed(SPEED_MIN + frac * (SPEED_MAX - SPEED_MIN))
	end
	speedHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			speedDragging = true
			setSpeedFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if speedDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setSpeedFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			speedDragging = false
		end
	end)

	local chipRow = Instance.new("Frame")
	chipRow.Size = UDim2.new(1, -32, 0, 28)
	chipRow.Position = UDim2.new(0, 16, 0, 70)
	chipRow.BackgroundTransparency = 1
	chipRow.Parent = speedCard
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chipRow

	for i, spd in ipairs({45, 70, 120, 200}) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.25, -6, 1, 0)
		b.LayoutOrder = i
		b.BackgroundColor3 = THEME.BtnOff
		b.Font = Enum.Font.GothamBold
		b.Text = tostring(spd)
		b.TextColor3 = THEME.BtnOffText
		b.TextSize = 11
		b.AutoButtonColor = false
		b.Parent = chipRow
		addCorner(b, 8)
		local bStroke = addStroke(b, THEME.BtnOffStroke, 1, 0)
		table.insert(speedChips, { btn = b, stroke = bStroke, value = spd })
		b.MouseButton1Click:Connect(function()
			setFlySpeed(spd)
		end)
	end
	setFlySpeed(SETTINGS.FLY_SPEED)

	-- ================================================================ PAGE: SPY & VISUALS
	local spyPage = pages["spy"]
	makeSection(spyPage, "STEALTH & VISUALS", 1)
	local spyGrid = makeGrid(spyPage, 2, 92, 2)
	local _, disBtn, disStroke = makeToggleCard(spyGrid, 1, "DisguiseCard", "🕶️", THEME.ActiveDisguise, "Covert Spy Mode", "UGC Accessories + Watermark Spy Tag")
	local _, espBtn, espStroke = makeToggleCard(spyGrid, 2, "EspCard", "👁️", THEME.ActiveEsp, "Staff Native ESP", "Highlight + In-Game Staff Tags")
	local auraCardFrame, auraBtn, auStroke = makeToggleCard(spyGrid, 3, "AuraCard", "✨", THEME.ActiveAura, "Aura & Tactical VFX", "9-Layer Auras & Custom VFX")
	makeLaunchCard(spyGrid, 4, "RadioCardSpy", "📻", Color3.fromRGB(255, 255, 255), "Radio Interceptor", "Walkie Talkie Frequency Spy", "OPEN RADIO", function()
		toggleRadioGui()
	end)

	auraBtn.Size = UDim2.new(1, -74, 0, 26)
	auraBtn.Position = UDim2.new(0, 62, 1, -36)
	local auraConfigBtn = Instance.new("TextButton")
	auraConfigBtn.Size = UDim2.new(0, 42, 0, 26)
	auraConfigBtn.Position = UDim2.new(0, 12, 1, -36)
	auraConfigBtn.BackgroundColor3 = THEME.BtnOff
	auraConfigBtn.Font = Enum.Font.GothamBold
	auraConfigBtn.Text = "⚙"
	auraConfigBtn.TextColor3 = THEME.TextCyan
	auraConfigBtn.TextSize = 13
	auraConfigBtn.AutoButtonColor = false
	auraConfigBtn.Parent = auraCardFrame
	addCorner(auraConfigBtn, 8)
	addStroke(auraConfigBtn, THEME.BtnOffStroke, 1, 0)
	hookButtonHover(auraConfigBtn, THEME.BtnOff, Color3.fromRGB(24, 40, 62), THEME.TextCyan, Color3.fromRGB(255, 255, 255))
	auraConfigBtn.MouseButton1Click:Connect(function()
		toggleAuraMenu()
	end)

	-- ================================================================ PAGE: WARDROBE
	local wardrobePage = pages["wardrobe"]
	makeSection(wardrobePage, "ROLE OUTFITS", 1)
	local wardrobeGrid = makeGrid(wardrobePage, 2, 92, 2)
	local _, _, ofSub = makeLaunchCard(wardrobeGrid, 1, "OutfitCard", "👔", Color3.fromRGB(255, 255, 255), "Role Wardrobe & Outfits", "Equip Any Role Outfit Freely", "OPEN OUTFITS", function()
		toggleOutfitGui()
	end)
	outfitSubLabel = ofSub
	makeLaunchCard(wardrobeGrid, 2, "OutfitResetCard", "♻️", Color3.fromRGB(220, 220, 225), "Default Appearance", "Restore your original outfit", "RESTORE DEFAULT", function()
		pcall(function()
			OUTFIT_SYS.resetDefault()
		end)
	end)

	-- ================================================================ PAGE: BOOMBOX
	local audioPage = pages["audio"]
	makeSection(audioPage, "AUDIO ENGINE", 1)
	local audioGrid = makeGrid(audioPage, 2, 92, 2)
	makeLaunchCard(audioGrid, 1, "BoomboxCard", "🎵", Color3.fromRGB(255, 255, 255), "Astrocyna Boombox", "3D Beat-Reactive Audio & VFX", "OPEN BOOMBOX", function()
		toggleBoomboxGui()
	end)

	-- ================================================================ PAGE: WATCHDOG
	local watchPage = pages["watchdog"]
	makeSection(watchPage, "MONITORING TOOLS", 1)
	local watchGrid = makeGrid(watchPage, 2, 92, 2)
	makeLaunchCard(watchGrid, 1, "PlayersCard", "👥", Color3.fromRGB(255, 255, 255), "Players Panel", "Realtime Scan + Actions", "OPEN PLAYERS", function()
		togglePlayersGui()
	end)
	makeLaunchCard(watchGrid, 2, "ChatCard", "💬", Color3.fromRGB(220, 220, 225), "Live Chatlogs", "All Public & Team Logs", "VIEW CHAT", function()
		toggleChatlogsGui()
	end)
	makeLaunchCard(watchGrid, 3, "HackerCard", "🚨", Color3.fromRGB(255, 255, 255), "Game Incidents & Violations", "Built-in RP & Crime Monitor", "OPEN MONITOR", function()
		toggleHackerGui()
	end)
	makeLaunchCard(watchGrid, 4, "RadioCard", "📻", Color3.fromRGB(255, 255, 255), "Radio Interceptor", "Walkie Talkie Eavesdropper", "OPEN RADIO", function()
		toggleRadioGui()
	end)
	makeLaunchCard(watchGrid, 5, "GangCard", "🏴‍☠️", Color3.fromRGB(255, 150, 50), "Gang Inspector", "Server Gangs, Rosters & Territory", "VIEW GANGS", function()
		toggleGangGui()
	end)
	makeLaunchCard(watchGrid, 6, "AntiCheatCard", "⚡", Color3.fromRGB(255, 45, 120), "Anti-Cheat & Exploits", "Detect Movement, Tools & Injectors", "OPEN DETECTOR", function()
		ADMIN_SYS.toggleCheatGui()
	end)

	-- ---------------------------------------------------------------- Toggle button state updaters
	updateGuiFlyState = function()
		if isFlying then
			flyBtn.BackgroundColor3 = THEME.ActiveFly
			flyBtn.TextColor3 = THEME.BtnActiveText
			flyBtn.Text = "ACTIVE"
			fStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			flyBtn.BackgroundColor3 = THEME.BtnOff
			flyBtn.TextColor3 = THEME.BtnOffText
			flyBtn.Text = "OFF"
			fStroke.Color = THEME.BtnOffStroke
		end
	end

	updateGuiInvisState = function()
		if isInvis then
			invisBtn.BackgroundColor3 = THEME.ActiveInvis
			invisBtn.TextColor3 = THEME.BtnActiveText
			invisBtn.Text = "ACTIVE"
			invStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			invisBtn.BackgroundColor3 = THEME.BtnOff
			invisBtn.TextColor3 = THEME.BtnOffText
			invisBtn.Text = "OFF"
			invStroke.Color = THEME.BtnOffStroke
		end
	end

	updateGuiEspState = function()
		if isEspEnabled then
			espBtn.BackgroundColor3 = THEME.ActiveEsp
			espBtn.TextColor3 = THEME.BtnActiveText
			espBtn.Text = "ACTIVE"
			espStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			espBtn.BackgroundColor3 = THEME.BtnOff
			espBtn.TextColor3 = THEME.BtnOffText
			espBtn.Text = "OFF"
			espStroke.Color = THEME.BtnOffStroke
		end
	end

	updateGuiAuraState = function()
		if isAuraEnabled then
			auraBtn.BackgroundColor3 = THEME.ActiveAura
			auraBtn.TextColor3 = THEME.BtnActiveText
			auraBtn.Text = "ACTIVE"
			auStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			auraBtn.BackgroundColor3 = THEME.BtnOff
			auraBtn.TextColor3 = THEME.BtnOffText
			auraBtn.Text = "OFF"
			auStroke.Color = THEME.BtnOffStroke
		end
		pcall(syncAuraPowerButton)
	end

	updateGuiDisguiseState = function()
		if isDisguiseEnabled then
			disBtn.BackgroundColor3 = THEME.ActiveDisguise
			disBtn.TextColor3 = THEME.BtnActiveText
			disBtn.Text = "ACTIVE"
			disStroke.Color = Color3.fromRGB(200, 200, 205)
		else
			disBtn.BackgroundColor3 = THEME.BtnOff
			disBtn.TextColor3 = THEME.BtnOffText
			disBtn.Text = "OFF"
			disStroke.Color = THEME.BtnOffStroke
		end
	end

	flyBtn.MouseButton1Click:Connect(toggleFly)
	invisBtn.MouseButton1Click:Connect(toggleInvis)
	disBtn.MouseButton1Click:Connect(toggleDisguise)
	espBtn.MouseButton1Click:Connect(toggleEsp)
	auraBtn.MouseButton1Click:Connect(toggleAura)

	-- ---------------------------------------------------------------- Live telemetry loop
	task.spawn(function()
		while main.Parent do
			local fps = FPS_TRACKER.current or 60
			local ping = 0
			pcall(function() ping = getLivePing() end)
			local plrCount = #Players:GetPlayers()
			local activeCount = 0

			for _, p in ipairs(modulePills) do
				local on = false
				pcall(function() on = p.check() and true or false end)
				if on then activeCount = activeCount + 1 end
				p.label.TextColor3 = on and Color3.fromRGB(255, 255, 255) or THEME.TextDim
				p.stroke.Color = on and Color3.fromRGB(0, 215, 140) or THEME.BtnOffStroke
			end

			headerStats.Text = string.format("%d FPS  ·  %d ms", fps, ping)
			statValues.fps.Text = tostring(fps)
			statValues.ping.Text = tostring(ping)
			statValues.players.Text = tostring(plrCount) .. " / " .. tostring(Players.MaxPlayers)
			statValues.modules.Text = tostring(activeCount) .. " / " .. tostring(#modulePills)

			if outfitSubLabel then
				local activeRole = OUTFIT_SYS and OUTFIT_SYS.activeOutfit
				outfitSubLabel.Text = activeRole and ("Active: " .. tostring(activeRole)) or "Equip Any Role Outfit Freely"
			end
			task.wait(0.5)
		end
	end)

	-- ---------------------------------------------------------------- Minimize / drag / hotkey
	local isMinimized = false
	local function setMinimized(minimized)
		isMinimized = minimized
		if isMinimized then
			sidebar.Visible = false
			contentArea.Visible = false
			if footerHint then footerHint.Visible = false end
			if headerLine then headerLine.Visible = false end
			main:TweenSize(UDim2.new(0, MAIN_W, 0, HEADER_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
			minBtn.Text = "+"
		else
			main:TweenSize(UDim2.new(0, MAIN_W, 0, MAIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
			minBtn.Text = "-"
			task.delay(0.08, function()
				if not isMinimized then
					sidebar.Visible = true
					contentArea.Visible = true
					if footerHint then footerHint.Visible = true end
					if headerLine then headerLine.Visible = true end
				end
			end)
		end
	end

	local minDebounce = 0
	local function onMinClicked()
		local now = tick()
		if now - minDebounce < 0.15 then return end
		minDebounce = now
		setMinimized(not isMinimized)
	end
	minBtn.MouseButton1Click:Connect(onMinClicked)
	if minBtn.Activated then
		minBtn.Activated:Connect(onMinClicked)
	end

	pcall(updateGuiFlyState)
	pcall(updateGuiInvisState)
	pcall(updateGuiEspState)
	pcall(updateGuiAuraState)
	pcall(updateGuiDisguiseState)

	selectTab("dashboard")
	makeDraggable(main, header)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
			screenGui.Enabled = not screenGui.Enabled
			if screenGui.Enabled then
				main.Position = clampPositionToScreen(main.Position, main.Size)
			end
		end
	end)
	end


	function buildChatlogsWindow()

	local chatFrame = Instance.new("Frame")
	chatFrame.Name = "ChatlogsWindow"
	chatFrame.Size = UDim2.new(0, 360, 0, 280)
	chatFrame.Position = UDim2.new(0, 376, 0.5, -140)
	chatFrame.BackgroundColor3 = THEME.MainBg
	chatFrame.BackgroundTransparency = THEME.MainBgTransparency
	chatFrame.BorderSizePixel = 0
	chatFrame.Visible = false
	chatFrame.ClipsDescendants = true
	chatFrame.Parent = screenGui
	applyResponsiveWindowScale(chatFrame, 360, 280, false)

	local cfCorner = Instance.new("UICorner")
	cfCorner.CornerRadius = UDim.new(0, 10)
	cfCorner.Parent = chatFrame

	local cfBevel = Instance.new("UIGradient")
	cfBevel.Rotation = 90
	cfBevel.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, THEME.TopGradient),
		ColorSequenceKeypoint.new(0.35, THEME.MainBg),
		ColorSequenceKeypoint.new(1, THEME.BottomGradient)
	})
	cfBevel.Parent = chatFrame

	local cfStroke = Instance.new("UIStroke")
	cfStroke.Thickness = 2.0
	cfStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cfStroke.Parent = chatFrame
	applyNeonSweep(cfStroke, 110, 2.5, 1.8, 2.6)

	local cfTopBar = Instance.new("Frame")
	cfTopBar.Size = UDim2.new(1, 0, 0, 40)
	cfTopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	cfTopBar.BorderSizePixel = 0
	cfTopBar.Parent = chatFrame

	local cfTopCorner = Instance.new("UICorner")
	cfTopCorner.CornerRadius = UDim.new(0, 10)
	cfTopCorner.Parent = cfTopBar

	local cfTopStroke = Instance.new("UIStroke")
	cfTopStroke.Color = Color3.fromRGB(48, 48, 54)
	cfTopStroke.Thickness = 1
	cfTopStroke.Parent = cfTopBar

	local cfTitle = Instance.new("TextLabel")
	cfTitle.Size = UDim2.new(1, -134, 1, 0)
	cfTitle.Position = UDim2.new(0, 14, 0, 0)
	cfTitle.BackgroundTransparency = 1
	cfTitle.Font = Enum.Font.GothamBold
	cfTitle.Text = "ASTROCYNA // CHAT LOGS"
	cfTitle.TextColor3 = THEME.TextCyan
	cfTitle.TextSize = 12
	cfTitle.TextXAlignment = Enum.TextXAlignment.Left
	cfTitle.Parent = cfTopBar
	applyTextShimmer(cfTitle, THEME.TextCyan, Color3.fromRGB(200, 200, 205), Color3.fromRGB(255, 255, 255), 1.3)

	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.new(0, 52, 0, 26)
	clearBtn.Position = UDim2.new(1, -124, 0, 7)
	clearBtn.BackgroundColor3 = THEME.BtnOff
	clearBtn.Font = Enum.Font.GothamBold
	clearBtn.Text = "Clear"
	clearBtn.TextColor3 = THEME.TextFrost
	clearBtn.TextSize = 11
	clearBtn.Parent = cfTopBar

	local clrCorner = Instance.new("UICorner")
	clrCorner.CornerRadius = UDim.new(0, 5)
	clrCorner.Parent = clearBtn

	local clrStroke = Instance.new("UIStroke")
	clrStroke.Color = THEME.BtnOffStroke
	clrStroke.Thickness = 1
	clrStroke.Parent = clearBtn
	hookButtonHover(clearBtn, THEME.BtnOff, Color3.fromRGB(24, 42, 64), THEME.TextFrost, Color3.fromRGB(255, 255, 255))

	local cfCloseBtn = Instance.new("TextButton")
	cfCloseBtn.Size = UDim2.new(0, 28, 0, 26)
	cfCloseBtn.Position = UDim2.new(1, -34, 0, 7)
	cfCloseBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	cfCloseBtn.Font = Enum.Font.GothamBold
	cfCloseBtn.Text = "X"
	cfCloseBtn.TextColor3 = THEME.TextCyan
	cfCloseBtn.TextSize = 11
	cfCloseBtn.Parent = cfTopBar

	local cfcCorner = Instance.new("UICorner")
	cfcCorner.CornerRadius = UDim.new(0, 5)
	cfcCorner.Parent = cfCloseBtn

	local cfcStroke = Instance.new("UIStroke")
	cfcStroke.Color = Color3.fromRGB(28, 60, 94)
	cfcStroke.Thickness = 1
	cfcStroke.Parent = cfCloseBtn
	hookButtonHover(cfCloseBtn, Color3.fromRGB(28, 28, 32), Color3.fromRGB(36, 18, 28), THEME.TextCyan, Color3.fromRGB(255, 120, 120))

	chatScroll = Instance.new("ScrollingFrame")
	chatScroll.Size = UDim2.new(1, -16, 1, -52)
	chatScroll.Position = UDim2.new(0, 8, 0, 46)
	chatScroll.BackgroundTransparency = 1
	chatScroll.BorderSizePixel = 0
	chatScroll.ScrollBarThickness = 4
	chatScroll.ScrollBarImageColor3 = THEME.BorderBeam
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatScroll.Parent = chatFrame

	local chatList = Instance.new("UIListLayout")
	chatList.SortOrder = Enum.SortOrder.LayoutOrder
	chatList.Padding = UDim.new(0, 4)
	chatList.Parent = chatScroll

	if #pendingChatMessages > 0 then
		for _, m in ipairs(pendingChatMessages) do
			logChatMessage(m.senderName, m.message, m.teamColor)
		end
		table.clear(pendingChatMessages)
	end

	clearBtn.MouseButton1Click:Connect(function()
		for _, child in ipairs(chatScroll:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end)

	cfCloseBtn.MouseButton1Click:Connect(function()
		chatFrame.Visible = false
	end)

	attachAlwaysOnTopButton(chatFrame, cfTopBar, "ChatlogsWindow", -66, 7, 28, 26)

	toggleChatlogsGui = function()
		chatFrame.Visible = not chatFrame.Visible
		if chatFrame.Visible then
			chatFrame.Position = clampPositionToScreen(chatFrame.Position, chatFrame.Size)
		end
	end

		makeDraggable(chatFrame, cfTopBar)
	end


function createModernGui()
	parentGui = nil
	if typeof(gethui) == "function" then
		pcall(function() parentGui = gethui() end)
	end
	if not parentGui then
		local s, cg = pcall(function() return game:GetService("CoreGui") end)
		if s and cg then
			local canParent = pcall(function()
				local test = Instance.new("Folder")
				test.Parent = cg
				test:Destroy()
			end)
			if canParent then
				parentGui = cg
			end
		end
	end
	if not parentGui then
		parentGui = player:WaitForChild("PlayerGui")
	end

	local existing = parentGui:FindFirstChild("PrisonRPFakeAdminGui")
	if existing then existing:Destroy() end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PrisonRPFakeAdminGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parentGui

	local existingPinned = parentGui:FindFirstChild("AstrocynaPinnedGui")
	if existingPinned then existingPinned:Destroy() end

	pinnedGui = Instance.new("ScreenGui")
	pinnedGui.Name = "AstrocynaPinnedGui"
	pinnedGui.ResetOnSpawn = false
	pinnedGui.DisplayOrder = 15
	pinnedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pinnedGui.Parent = parentGui

	local existingMobile = parentGui:FindFirstChild("AstrocynaMobileToggleGui")
	if existingMobile then existingMobile:Destroy() end

	mobileToggleGui = Instance.new("ScreenGui")
	mobileToggleGui.Name = "AstrocynaMobileToggleGui"
	mobileToggleGui.ResetOnSpawn = false
	mobileToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mobileToggleGui.Parent = parentGui

	local mobileBtn = Instance.new("TextButton")
	mobileBtn.Name = "AstrocynaMobileToggleBtn"
	mobileBtn.Size = UDim2.new(0, 48, 0, 48)
	mobileBtn.Position = UDim2.new(0, 16, 0.45, 0)
	mobileBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	mobileBtn.BackgroundTransparency = 0.15
	mobileBtn.BorderSizePixel = 0
	mobileBtn.AutoButtonColor = false
	mobileBtn.Text = ""
	mobileBtn.ZIndex = 200
	mobileBtn.Visible = false
	mobileBtn.Parent = mobileToggleGui

	local mbCorner = Instance.new("UICorner")
	mbCorner.CornerRadius = UDim.new(0, 24)
	mbCorner.Parent = mobileBtn

	local mbStroke = Instance.new("UIStroke")
	mbStroke.Color = THEME.BorderBase
	mbStroke.Thickness = 1.4
	mbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mbStroke.Parent = mobileBtn

	local mbResolvedIcon = resolveIconAsset and (resolveIconAsset("Icon name tag/Iconhud.png") ~= "" and resolveIconAsset("Icon name tag/Iconhud.png") or (resolveIconAsset(ICON_PATH) ~= "" and resolveIconAsset(ICON_PATH) or resolveIconAsset("Icon.png"))) or ""
	local mbImg = Instance.new("ImageLabel")
	mbImg.Name = "Icon"
	mbImg.Size = UDim2.new(0, 26, 0, 26)
	mbImg.Position = UDim2.new(0.5, 0, 0.5, 0)
	mbImg.AnchorPoint = Vector2.new(0.5, 0.5)
	mbImg.BackgroundTransparency = 1
	mbImg.Image = mbResolvedIcon ~= "" and mbResolvedIcon or "rbxassetid://136672364093581"
	if mbResolvedIcon == "" then
		mbImg.ImageColor3 = Color3.fromRGB(235, 235, 235)
	end
	mbImg.ScaleType = Enum.ScaleType.Fit
	mbImg.Parent = mobileBtn

	local mbDot = Instance.new("Frame")
	mbDot.Name = "StatusDot"
	mbDot.Size = UDim2.new(0, 7, 0, 7)
	mbDot.Position = UDim2.new(1, -9, 0, 3)
	mbDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	mbDot.BorderSizePixel = 0
	mbDot.Parent = mobileBtn
	local mbdCorner = Instance.new("UICorner")
	mbdCorner.CornerRadius = UDim.new(1, 0)
	mbdCorner.Parent = mbDot

	table.insert(activeAnimators, function()
		if mbDot and mbDot.Parent then
			if screenGui.Enabled then
				mbDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				mbDot.BackgroundTransparency = 0.4 * (math.sin(tick() * 3) + 1) / 2
			else
				mbDot.BackgroundColor3 = Color3.fromRGB(90, 120, 140)
				mbDot.BackgroundTransparency = 0.5
			end
		end
	end)

	if savedGuiPositions["MobileToggleBtn"] then
		local s = savedGuiPositions["MobileToggleBtn"]
		mobileBtn.Position = clampPositionToScreen(UDim2.new(s.xScale or 0, s.xOffset or 0, s.yScale or 0, s.yOffset or 0), mobileBtn.Size, mobileBtn)
	end

	local mbDragging = false
	local mbDragStart, mbStartPos
	local mbTotalDist = 0

	mobileBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			mbDragging = true
			mbDragStart = input.Position
			mbStartPos = mobileBtn.Position
			mbTotalDist = 0

			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					if mbDragging then
						mbDragging = false
						if mbTotalDist < 9 then
							screenGui.Enabled = not screenGui.Enabled
							if screenGui.Enabled and mainWindow then
								pcall(function()
									mainWindow.Position = clampPositionToScreen(mainWindow.Position, mainWindow.Size, mainWindow)
								end)
							end
							pcall(function()
								TweenService:Create(mobileBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									Size = UDim2.new(0, 42, 0, 42)
								}):Play()
								task.delay(0.09, function()
									TweenService:Create(mobileBtn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
										Size = UDim2.new(0, 48, 0, 48)
									}):Play()
								end)
							end)
						else
							pcall(function()
								savedGuiPositions["MobileToggleBtn"] = {
									xScale = mobileBtn.Position.X.Scale,
									xOffset = mobileBtn.Position.X.Offset,
									yScale = mobileBtn.Position.Y.Scale,
									yOffset = mobileBtn.Position.Y.Offset,
								}
								saveGuiPositions()
							end)
						end
					end
					if conn then conn:Disconnect() end
				end
			end)
		end
	end)

	mobileBtn.InputChanged:Connect(function(input)
		if mbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - mbDragStart
			mbTotalDist = mbTotalDist + math.abs(delta.X) + math.abs(delta.Y)
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local newX = math.clamp(mbStartPos.X.Offset + delta.X, 0, math.max(0, vp.X - 52))
			local newY = math.clamp(mbStartPos.Y.Offset + delta.Y, 0, math.max(0, vp.Y - 52))
			mobileBtn.Position = UDim2.new(mbStartPos.X.Scale, newX, mbStartPos.Y.Scale, newY)
		end
	end)

	local function mountBrowserButton()
		local pGui = player:FindFirstChild("PlayerGui")
		local mainGui = pGui and pGui:FindFirstChild("MainGui")
		local leftFrame = mainGui and mainGui:FindFirstChild("Left")
		local browser = leftFrame and leftFrame:FindFirstChild("Browser")
		if not browser or browser:FindFirstChild("SpyTool") then return end

		local hudIconAsset = ""
		if type(resolveIconAsset) == "function" then
			hudIconAsset = resolveIconAsset("Icon name tag/Iconhud.png")
			if hudIconAsset == "" then hudIconAsset = resolveIconAsset("Iconhud.png") end
			if hudIconAsset == "" then hudIconAsset = resolveIconAsset(ICON_PATH) end
			if hudIconAsset == "" then hudIconAsset = resolveIconAsset("Icon.png") end
		end
		if hudIconAsset == "" then
			hudIconAsset = "rbxassetid://136672364093581"
		end

		if browser then
			local oldFake = browser:FindFirstChild("FakeAdmin")
			if oldFake then oldFake:Destroy() end

			local btn = browser:FindFirstChild("SpyTool")
			if not btn then
				btn = Instance.new("ImageButton")
				btn.Name = "SpyTool"
				btn.Size = UDim2.fromOffset(40, 40)
				btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				btn.BackgroundTransparency = 0.5
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.LayoutOrder = 95
				btn.ClipsDescendants = false

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = btn

				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 10)
				pad.PaddingRight = UDim.new(0, 10)
				pad.PaddingTop = UDim.new(0, 10)
				pad.PaddingBottom = UDim.new(0, 10)
				pad.Parent = btn

				local icon = Instance.new("ImageLabel")
				icon.Name = "Icon"
				icon.Size = UDim2.fromOffset(20, 20)
				icon.Position = UDim2.new(0, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.BackgroundTransparency = 1
				icon.Image = hudIconAsset
				icon.ImageColor3 = Color3.fromRGB(235, 235, 235)
				icon.ScaleType = Enum.ScaleType.Fit
				icon.Parent = btn

				local title = Instance.new("TextLabel")
				title.Name = "Title"
				title.BackgroundTransparency = 1
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.TextColor3 = Color3.fromRGB(235, 235, 235)
				title.Text = "Spy Tool"
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Size = UDim2.new(0, 0, 1, 0)
				title.AutomaticSize = Enum.AutomaticSize.X
				title.Position = UDim2.new(0, 28, 0, 0)
				title.Visible = false
				title.Parent = btn

				btn.Parent = browser

				local isHovered = false

				local function applyVisual(isToggled)
					if isToggled then
						local w = 48 + title.AbsoluteSize.X
						TweenService:Create(btn, TweenInfo.new(0.2), {
							BackgroundColor3 = Color3.fromRGB(235, 235, 235),
							BackgroundTransparency = 0,
							Size = UDim2.fromOffset(w, 40)
						}):Play()
						TweenService:Create(icon, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(30, 30, 30) }):Play()
						TweenService:Create(title, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(30, 30, 30) }):Play()
						title.Visible = true
					elseif isHovered then
						local w = 48 + title.AbsoluteSize.X
						TweenService:Create(btn, TweenInfo.new(0.2), {
							BackgroundColor3 = Color3.fromRGB(45, 45, 48),
							BackgroundTransparency = 0.3,
							Size = UDim2.fromOffset(w, 40)
						}):Play()
						TweenService:Create(icon, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(245, 245, 245) }):Play()
						TweenService:Create(title, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(245, 245, 245) }):Play()
						title.Visible = true
					else
						TweenService:Create(btn, TweenInfo.new(0.2), {
							BackgroundColor3 = Color3.fromRGB(30, 30, 30),
							BackgroundTransparency = 0.5,
							Size = UDim2.fromOffset(40, 40)
						}):Play()
						TweenService:Create(icon, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(235, 235, 235) }):Play()
						TweenService:Create(title, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(235, 235, 235) }):Play()
						title.Visible = false
					end
				end

				btn.MouseEnter:Connect(function()
					if screenGui.Enabled then return end
					isHovered = true
					applyVisual(false)
				end)

				btn.MouseLeave:Connect(function()
					if screenGui.Enabled then return end
					isHovered = false
					applyVisual(false)
				end)

				title:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					if isHovered or screenGui.Enabled then
						local w = 48 + title.AbsoluteSize.X
						TweenService:Create(btn, TweenInfo.new(0.2), { Size = UDim2.fromOffset(w, 40) }):Play()
					end
				end)

				btn.MouseButton1Click:Connect(function()
					screenGui.Enabled = not screenGui.Enabled
					if screenGui.Enabled and mainWindow then
						pcall(function()
							mainWindow.Position = clampPositionToScreen(mainWindow.Position, mainWindow.Size, mainWindow)
						end)
					end
				end)

				updateBrowserVisualFn = applyVisual
				applyVisual(screenGui.Enabled)
			else
				if updateBrowserVisualFn then
					updateBrowserVisualFn(screenGui.Enabled)
				end
			end

			if mobileBtn then
				mobileBtn.Visible = false
			end
		else
			if mobileBtn then
				mobileBtn.Visible = true
			end
		end

		pcall(function()
			local sMainGui = StarterGui:FindFirstChild("MainGui")
			local sBrowser = sMainGui and sMainGui:FindFirstChild("Left") and sMainGui.Left:FindFirstChild("Browser")
			if sBrowser then
				local oldSBtn = sBrowser:FindFirstChild("FakeAdmin")
				if oldSBtn then oldSBtn:Destroy() end

				if not sBrowser:FindFirstChild("SpyTool") then
					local sBtn = Instance.new("ImageButton")
				sBtn.Name = "SpyTool"
				sBtn.Size = UDim2.fromOffset(40, 40)
				sBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				sBtn.BackgroundTransparency = 0.5
				sBtn.BorderSizePixel = 0
				sBtn.AutoButtonColor = false
				sBtn.LayoutOrder = 95
				local sc = Instance.new("UICorner")
				sc.CornerRadius = UDim.new(0, 8)
				sc.Parent = sBtn
				local sp = Instance.new("UIPadding")
				sp.PaddingLeft = UDim.new(0, 10); sp.PaddingRight = UDim.new(0, 10)
				sp.PaddingTop = UDim.new(0, 10); sp.PaddingBottom = UDim.new(0, 10)
				sp.Parent = sBtn
				local sic = Instance.new("ImageLabel")
				sic.Name = "Icon"
				sic.Size = UDim2.fromOffset(20, 20)
				sic.Position = UDim2.new(0, 0, 0.5, 0)
				sic.AnchorPoint = Vector2.new(0, 0.5)
				sic.BackgroundTransparency = 1
				sic.Image = hudIconAsset
				sic.ImageColor3 = Color3.fromRGB(235, 235, 235)
				sic.ScaleType = Enum.ScaleType.Fit
				sic.Parent = sBtn
				local st = Instance.new("TextLabel")
				st.Name = "Title"
				st.BackgroundTransparency = 1
				st.Font = Enum.Font.GothamMedium
				st.TextSize = 13
				st.TextColor3 = Color3.fromRGB(235, 235, 235)
				st.Text = "Spy Tool"
				st.AutomaticSize = Enum.AutomaticSize.X
				st.Position = UDim2.new(0, 28, 0, 0)
				st.Visible = false
				st.Parent = sBtn
				sBtn.Parent = sBrowser
				end
			end
		end)
	end

	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if updateBrowserVisualFn then
			pcall(updateBrowserVisualFn, screenGui.Enabled)
		end
		if screenGui.Enabled and mainWindow then
			pcall(function()
				mainWindow.Position = clampPositionToScreen(mainWindow.Position, mainWindow.Size, mainWindow)
			end)
		end
	end)

	trackThread(task.spawn(function()
		task.wait(0.5)
		pcall(mountBrowserButton)
		while true do
			task.wait(8)
			pcall(mountBrowserButton)
		end
	end))

	trackConnection(player.CharacterAdded:Connect(function()
		task.wait(0.5)
		pcall(mountBrowserButton)
	end))

	-- =====================================================================
	-- MOBILE FLIGHT TOUCH HUD (▲ UP / ▼ DOWN)
	-- =====================================================================
	local flyHud = Instance.new("Frame")
	flyHud.Name = "AstrocynaMobileFlyHud"
	flyHud.Size = UDim2.new(0, 52, 0, 116)
	flyHud.Position = UDim2.new(1, -72, 0.5, -58)
	flyHud.BackgroundTransparency = 1
	flyHud.Visible = false
	flyHud.ZIndex = 180
	flyHud.Parent = mobileToggleGui

	local function createFlyTouchButton(parent, pos, text, subtext, color, stateKey)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.Position = pos
		btn.BackgroundColor3 = Color3.fromRGB(12, 22, 38)
		btn.BackgroundTransparency = 0.2
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.Parent = parent

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 24)
		c.Parent = btn

		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = 1.6
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = btn
		applyNeonSweep(s, 110, 2.0, 1.4, 2.4)

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, 24)
		t.Position = UDim2.new(0, 0, 0, 4)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.Text = text
		t.TextColor3 = color
		t.TextSize = 18
		t.Parent = btn

		local st = Instance.new("TextLabel")
		st.Size = UDim2.new(1, 0, 0, 14)
		st.Position = UDim2.new(0, 0, 0, 27)
		st.BackgroundTransparency = 1
		st.Font = Enum.Font.GothamBold
		st.Text = subtext
		st.TextColor3 = THEME.TextFrost
		st.TextSize = 9
		st.Parent = btn

		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mobileFlyState[stateKey] = true
				btn.BackgroundColor3 = Color3.fromRGB(48, 48, 54)
				btn.BackgroundTransparency = 0.05
			end
		end)

		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mobileFlyState[stateKey] = false
				btn.BackgroundColor3 = Color3.fromRGB(12, 22, 38)
				btn.BackgroundTransparency = 0.2
			end
		end)

		return btn
	end

	createFlyTouchButton(flyHud, UDim2.new(0, 2, 0, 0), "▲", "UP", THEME.CyanPrimary, "Up")
	createFlyTouchButton(flyHud, UDim2.new(0, 2, 0, 58), "▼", "DN", Color3.fromRGB(220, 130, 255), "Down")

	setMobileFlyHudVisible = function(vis)
		if flyHud then
			if vis and (UserInputService.TouchEnabled or not UserInputService.KeyboardEnabled) then
				flyHud.Visible = true
			else
				flyHud.Visible = false
				mobileFlyState.Up = false
				mobileFlyState.Down = false
			end
		end
	end

	pcall(buildMainWindow)
	trackThread(task.spawn(function()
		task.wait(0.08)
		pcall(buildChatlogsWindow)
		pcall(WIN_BUILDERS.buildPlayers)
		pcall(buildAuraWindow)
		task.wait(0.08)
		pcall(WIN_BUILDERS.buildBoombox)
		pcall(WIN_BUILDERS.buildHacker)
		pcall(WIN_BUILDERS.buildCheatDetector)
		task.wait(0.08)
		pcall(WIN_BUILDERS.buildStaffRadar)
		pcall(WIN_BUILDERS.buildServerStaff)
		pcall(WIN_BUILDERS.buildOutfits)
		pcall(startHackerWatchdog)
		pcall(WIN_BUILDERS.buildRadioInterceptor)
		pcall(WIN_BUILDERS.buildGangs)
	end))

	-- Gang system: background directory & server gang roster prefetch + live event hook
	trackThread(task.spawn(function()
		task.wait(2.5)
		pcall(GANG_SYS.fetchDirectory, false)
		pcall(GANG_SYS.syncServerGangRosters)

		pcall(function()
			local ev = GANG_SYS.getRemoteEvent()
			if ev then
				trackConnection(ev.OnClientEvent:Connect(function(action, ...)
					if action == "UpdateInterface" then
						local gKey, gData = ...
						if typeof(gKey) == "string" and typeof(gData) == "table" then
							GANG_SYS.gangsByKey[gKey] = gData
							if gData.Key then GANG_SYS.gangsByKey[gData.Key] = gData end
							if gData.Name then GANG_SYS.gangsByKey[gData.Name] = gData end
							if typeof(gData.Members) == "table" then
								for mKey, mData in pairs(gData.Members) do
									local uid = tonumber(string.match(tostring(mKey), "^(%d+)")) or tonumber(mKey)
									if uid then
										GANG_SYS.playerGangMap[uid] = {
											gangKey = gKey,
											gangName = gData.Name or gKey,
											gangTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. (gData.Name or gKey) .. "]"),
											role = typeof(mData) == "table" and mData.Rank or "Member",
											name = typeof(mData) == "table" and mData.Name or "Member",
											fromRoster = true,
										}
									end
								end
							end
							if gData.CreatorKey then
								local cUid = tonumber(string.match(tostring(gData.CreatorKey), "^(%d+)")) or tonumber(gData.CreatorKey)
								if cUid and not GANG_SYS.playerGangMap[cUid] then
									GANG_SYS.playerGangMap[cUid] = {
										gangKey = gKey,
										gangName = gData.Name or gKey,
										gangTag = (gData.Tag and gData.Tag ~= "") and gData.Tag or ("[" .. (gData.Name or gKey) .. "]"),
										role = "Boss",
										name = "Boss",
										fromRoster = true,
									}
								end
							end
							if GANG_SYS.onRosterUpdated then pcall(GANG_SYS.onRosterUpdated) end
						end
					end
				end))
			end
		end)
	end))

	-- Server browser staff visibility: roster loader + live decoration of the game's own server list
	trackThread(task.spawn(function()
		task.wait(2.0)
		pcall(ADMIN_SYS.refreshStaffRoster, true)
		while true do
			task.wait(6.0)
			pcall(ADMIN_SYS.refreshStaffRoster, false)
			pcall(ADMIN_SYS.decorateNativeServerList)
		end
	end))

	trackThread(task.spawn(function()
		task.wait(1.5)
		pcall(ADMIN_SYS.updateStaffRadar)
		while true do
			task.wait(2.0)
			if ADMIN_SYS.isStaffRadarEnabled then
				pcall(ADMIN_SYS.updateStaffRadar)
			end
			if isScanMonitorOpen and isScanMonitorOpen() then
				pcall(ADMIN_SYS.updateApbList)
			end
		end
	end))

	updateGuiFlyState()
	updateGuiInvisState()
	updateGuiDisguiseState()
	updateGuiEspState()
	updateGuiAuraState()

	pcall(function()
		if EMOTE_SYS and EMOTE_SYS.init then
			EMOTE_SYS.init()
		end
	end)

	trackThread(task.spawn(function()
		for _ = 1, 5 do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			task.wait(0.5)
		end
	end))
end

createModernGui()