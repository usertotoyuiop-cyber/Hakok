--[[
	NurHub Visual  |  v1.0 MM2
	Только визуал: ESP, Chams, Corner/3D Box, Hat, Trails, FOV, World, Skin Changer (visual), Stats.
	Без Drawing API: Frame / UIStroke / Highlight / PointLight / Trail.
	Меню: кнопка NH или RightShift.  Telegram: https://t.me/NurHuboffical

	Счётчик «NurHub online»: по умолчанию публичный канал ntfy.sh (без регистрации).
	Для своего сервера впишите Firebase Realtime Database URL в ONLINE_CFG.firebase
	(правила БД: ".read": true, ".write": true).
]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local RepStorage   = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local VERSION = "1.0"
local TG_LINK = "https://t.me/NurHuboffical"
local ENV = (typeof(getgenv) == "function" and getgenv()) or _G

local ONLINE_CFG = {
	firebase = "",                                  -- например "https://nurhub-xxxx-default-rtdb.firebaseio.com"
	topic    = "nurhub-mm2-online-v1-7kq2x9",       -- публичный канал ntfy.sh
	beat     = 300,                                 -- как часто сообщаем «я онлайн» (сек)
	poll     = 45,                                  -- как часто обновляем счётчик (сек)
}

-- выгружаем прошлый запуск
if ENV.NurHubMM2Unload then pcall(ENV.NurHubMM2Unload) end

local conns = {}
local function track(c)
	conns[#conns + 1] = c
	return c
end

----------------------------------------------------------------
-- Утилиты
----------------------------------------------------------------
local function mount(g)
	local ok = pcall(function()
		g.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	end)
	if not ok or not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
end
local function new(class, props, parent)
	local o = Instance.new(class)
	if props then
		for k, v in pairs(props) do o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, c, th, tr)
	return new("UIStroke", { Color = c, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function tw(o, t, props, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end
local orderN = 0
local function ord()
	orderN += 1
	return orderN
end
local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

do -- остатки старых запусков
	local roots = { LP:FindFirstChildOfClass("PlayerGui") }
	pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
	pcall(function() if typeof(gethui) == "function" then table.insert(roots, gethui()) end end)
	for _, r in ipairs(roots) do
		for _, n in ipairs({ "NurHubMM2_UI", "NurHubMM2_ESP" }) do
			local o = r:FindFirstChild(n)
			if o then pcall(function() o:Destroy() end) end
		end
	end
end

local C = {
	bg = Color3.fromRGB(13, 13, 19), side = Color3.fromRGB(16, 16, 24), card = Color3.fromRGB(21, 20, 31),
	drawer = Color3.fromRGB(15, 15, 23), line = Color3.fromRGB(38, 36, 54), text = Color3.fromRGB(235, 235, 245),
	sub = Color3.fromRGB(135, 133, 158), off = Color3.fromRGB(50, 48, 70), track = Color3.fromRGB(34, 33, 50),
	field = Color3.fromRGB(11, 11, 17), accent = Color3.fromRGB(122, 92, 255), accent2 = Color3.fromRGB(88, 140, 255),
}

----------------------------------------------------------------
-- НАСТРОЙКИ (одна таблица: UI и ESP читают её напрямую)
----------------------------------------------------------------
local PURPLE = Color3.fromRGB(150, 110, 255)
local RED, BLUE = Color3.fromRGB(255, 70, 70), Color3.fromRGB(70, 140, 255)
local CFG = {
	esp = { on = true, team = false, maxDist = 1500, roles = true },
	box2d = { on = false, color = WHITE },
	corner = { on = false, color = WHITE, len = 28 },
	fill = { on = false, c1 = Color3.fromRGB(12, 12, 20), c2 = PURPLE, trans = 0.5 },
	box3d = { on = false, color = Color3.fromRGB(80, 200, 255) },
	name = { on = false, color = WHITE },
	dist = { on = false, color = Color3.fromRGB(190, 190, 210) },
	health = { on = false, color = Color3.fromRGB(70, 230, 120) },
	chams = { on = false, color = PURPLE, trans = 0.5 },
	outline = { on = false, color = WHITE },
	glow = { on = false, color = PURPLE, range = 16, bright = 2 },
	tracer = { on = false, color = WHITE, origin = "Bottom" },
	skel = { on = false, color = WHITE },
	head = { on = false, color = Color3.fromRGB(255, 90, 110) },
	arrows = { on = false, color = WHITE, radius = 130, size = 14, murder = RED, sheriff = BLUE },
	fov = { on = false, val = 90 },
	hat = { on = false, color = Color3.fromRGB(150, 90, 230), trans = 0.4, scope = "Everyone", size = 100, lines = 24, rainbow = true, fill = false, mode = "Lines", shimmer = false },
	trail = { on = false, color = Color3.fromRGB(122, 92, 255), len = 1.2, width = 0.8, scope = "Only me" },
	pcolor = {}, acolor = {},
	target = { mode = "All", userId = 0 },
	avatar = { on = false, color = WHITE },
	wall = { on = false, hid = Color3.fromRGB(255, 60, 60), vis = Color3.fromRGB(70, 255, 110) },
	fps = { on = false, color = WHITE, custom = false, value = 999, x = 0.02, y = 0.03 },
	third = { on = false, dist = 12 },
	steps = { on = false, color = Color3.fromRGB(122, 92, 255), life = 2.5, shape = "Circle", scope = "Only me", dist = 2.4, delay = 0 },
	gun = { on = false, color = Color3.fromRGB(255, 200, 50), text = true, textColor = WHITE, tracer = false },
	coin = { on = false, color = Color3.fromRGB(255, 215, 60), text = true, textColor = WHITE },
	xray = { on = false, amount = 0.6 },
	walk = { on = false, val = 32 }, jump = { on = false, val = 90 }, spin = { on = false, val = 360 },
	noclip = { on = false }, fly = { on = false, val = 60 }, farm = { on = false, fly = 60, delay = 0.3 },
	shader = { on = false, preset = "4K" },
	wbright = { on = false, val = 0.1 }, wglow = { on = false, int = 1, thr = 0.9 }, wdark = { on = false, val = 0.4 },
	wgrade = { on = false, sat = 0.2, con = 0.1 }, wblur = { on = false, val = 8 }, wfog = { on = false, val = 0.3 },
	wrays = { on = false, val = 0.3 }, wtime = { on = false, val = 12 }, wfull = { on = false }, wshadow = { on = false },
	skin = { on = true, gun = "", knife = "" },
}

----------------------------------------------------------------
-- X: общие хелперы (настройки, файлы, роли MM2, аватары, перевод)
----------------------------------------------------------------
local X = {
	SET = { lang = "en", scale = 1, trans = 0, accent = C.accent },
	refresh = {}, transReg = {}, trReg = {}, accReg = {}, lists = {}, hatInfo = {}, searchReg = {}, pageSF = {},
	plist = Players:GetPlayers(), ov = nil, DICT = nil,
}
track(Players.PlayerAdded:Connect(function() X.plist = Players:GetPlayers() end))
track(Players.PlayerRemoving:Connect(function(p)
	local l = {}
	for _, q in ipairs(Players:GetPlayers()) do
		if q ~= p then l[#l + 1] = q end
	end
	X.plist = l
end))

do
	local DIR = "NurHubMM2"
	local mem = ENV.NurHubMM2Mem or {}
	ENV.NurHubMM2Mem = mem
	local fsOk = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
	pcall(function()
		if fsOk and typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(DIR) then makefolder(DIR) end
	end)
	function X.fsRead(name)
		if fsOk then
			local ok, res = pcall(function()
				if isfile(DIR .. "/" .. name) then return readfile(DIR .. "/" .. name) end
				return nil
			end)
			if ok then return res end
			return nil
		end
		return mem[name]
	end
	function X.fsWrite(name, str)
		if fsOk then pcall(writefile, DIR .. "/" .. name, str) else mem[name] = str end
	end
	function X.accent2Of(col)
		local h, s, v = col:ToHSV()
		return Color3.fromHSV((h + .07) % 1, s * .9, math.clamp(v + .05, 0, 1))
	end
	function X.saveSettings()
		local s = X.SET
		local a = s.accent
		pcall(function()
			X.fsWrite("settings.json", HttpService:JSONEncode({ lang = s.lang, scale = s.scale, trans = s.trans, accent = { a.R, a.G, a.B } }))
		end)
	end
	local raw = X.fsRead("settings.json")
	if raw then
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(t) == "table" then
			X.SET.lang = (t.lang == "ru") and "ru" or "en"
			X.SET.scale = math.clamp(tonumber(t.scale) or 1, .5, 1.3)
			X.SET.trans = math.clamp(tonumber(t.trans) or 0, 0, .6)
			if type(t.accent) == "table" and #t.accent == 3 then
				X.SET.accent = Color3.new(t.accent[1], t.accent[2], t.accent[3])
				C.accent = X.SET.accent
				C.accent2 = X.accent2Of(C.accent)
			end
		end
	end
end

-- прозрачность меню
function X.regT(inst)
	X.transReg[#X.transReg + 1] = inst
	inst.BackgroundTransparency = X.SET.trans
end
function X.applyTrans()
	for _, i in ipairs(X.transReg) do i.BackgroundTransparency = X.SET.trans end
end
-- обновление UI после загрузки конфига
function X.reg(fn) X.refresh[#X.refresh + 1] = fn end
function X.refreshAll()
	for _, f in ipairs(X.refresh) do pcall(f) end
end
-- акцентный цвет (живая перекраска)
function X.acc(fn)
	X.accReg[#X.accReg + 1] = fn
	fn()
end
function X.setAccent(col, nosave)
	C.accent, C.accent2, X.SET.accent = col, X.accent2Of(col), col
	for _, f in ipairs(X.accReg) do pcall(f) end
	if not nosave then X.saveSettings() end
end
-- поиск по функциям
function X.regSearch(name, box)
	if X.inDrawer or not X.curTab then return end
	X.searchReg[#X.searchReg + 1] = { name = name, tab = X.curTab, box = box }
end
-- перевод
function X.tr(s)
	local d = X.DICT and X.DICT[s]
	if X.SET.lang == "ru" and d then return d end
	return s
end
function X.tl(inst, en, fmt)
	X.trReg[#X.trReg + 1] = { i = inst, en = en, f = fmt }
	local s = X.tr(en)
	inst.Text = fmt and fmt(s) or s
end

-- роли MM2 (по инструментам Knife / Gun), кэш 0.25 c
do
	local roleCache = setmetatable({}, { __mode = "k" })
	local function hasTool(plr, n)
		local c, b = plr.Character, plr:FindFirstChild("Backpack")
		return (c and c:FindFirstChild(n)) or (b and b:FindFirstChild(n)) or nil
	end
	function X.roleOf(plr)
		local now = os.clock()
		local c = roleCache[plr]
		if c and now - c.t < 0.25 then return c.r end
		local r = "Innocent"
		if hasTool(plr, "Knife") then r = "Murderer" elseif hasTool(plr, "Gun") then r = "Sheriff" end
		if not c then
			c = {}
			roleCache[plr] = c
		end
		c.t, c.r = now, r
		return r
	end
end
X.ROLE_COL = { Murderer = RED, Sheriff = BLUE }

-- аватары (headshot)
do
	local cache, waiting = {}, {}
	function X.getAvatar(uid, cb)
		if cache[uid] then
			cb(cache[uid])
			return
		end
		if waiting[uid] then
			table.insert(waiting[uid], cb)
			return
		end
		waiting[uid] = { cb }
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			local list = waiting[uid]
			waiting[uid] = nil
			if ok and url then
				cache[uid] = url
				for _, f in ipairs(list) do pcall(f, url) end
			end
		end)
	end
end

-- цвет-переопределение для текущего игрока в ESP
function X.cc(c) return X.ov or c end

-- видимость за стеной (кэш 0.1 c)
do
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local cache = setmetatable({}, { __mode = "k" })
	function X.visibleTo(char)
		local now = os.clock()
		local c = cache[char]
		if c and now - c.t < 0.1 then return c.v end
		local cam = Workspace.CurrentCamera
		local head = char:FindFirstChild("Head") or char.PrimaryPart
		local v = false
		if cam and head then
			rp.FilterDescendantsInstances = { char, LP.Character }
			local o = cam.CFrame.Position
			v = Workspace:Raycast(o, head.Position - o, rp) == nil
		end
		if not c then
			c = {}
			cache[char] = c
		end
		c.t, c.v = now, v
		return v
	end
end

-- фильтр «ESP for...»
function X.passTarget(plr, role)
	local m = CFG.target.mode
	if m == "All" then return true end
	if m == "Murder" then return role == "Murderer" end
	if m == "Sheriff" then return role == "Sheriff" end
	return plr.UserId == CFG.target.userId
end

-- HTTP (для счётчика онлайна)
function X.reqFn()
	if typeof(request) == "function" then return request end
	if typeof(http_request) == "function" then return http_request end
	if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request end
	if typeof(http) == "table" and typeof(http.request) == "function" then return http.request end
	if typeof(fluxus) == "table" and typeof(fluxus.request) == "function" then return fluxus.request end
	return nil
end
function X.httpGet(url)
	local rf = X.reqFn()
	if rf then
		local ok, r = pcall(rf, { Url = url, Method = "GET" })
		if ok and type(r) == "table" then
			local code = r.StatusCode or r.status_code or 200
			if code >= 200 and code < 300 and type(r.Body) == "string" then return r.Body end
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	if ok and type(body) == "string" then return body end
	return nil
end

----------------------------------------------------------------
-- ОКНО: слева меню, справа «ESP Editor» (предпросмотр)
----------------------------------------------------------------
local MAIN_W, H, SIDE, PREV_W, GAP = 640, 470, 128, 252, 12
local FULL_W = MAIN_W + GAP + PREV_W

local gui = new("ScreenGui", {
	Name = "NurHubMM2_UI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
mount(gui)

local Root = new("Frame", {
	Name = "Root", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
	Size = UDim2.fromOffset(FULL_W, H), BackgroundTransparency = 1, Visible = false,
}, gui)
local fitScale = new("UIScale", { Scale = 1 }, Root)
local Anim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, Root)
local animScale = new("UIScale", { Scale = .9 }, Anim)

local Main = new("CanvasGroup", {
	Size = UDim2.fromOffset(MAIN_W, H), BackgroundColor3 = C.bg, BorderSizePixel = 0, GroupTransparency = 1,
}, Anim)
corner(Main, 16)
stroke(Main, C.line, 1)

local Preview = new("CanvasGroup", {
	Position = UDim2.fromOffset(MAIN_W + GAP, 0), Size = UDim2.fromOffset(PREV_W, H),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, GroupTransparency = 1, Visible = false,
}, Anim)
corner(Preview, 16)
stroke(Preview, C.line, 1)

-- масштаб под размер экрана (телефон / маленькие окна)
local function fit()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	fitScale.Scale = math.clamp(math.min((vs.X - 24) / FULL_W, (vs.Y - 24) / H), 0.35, 1) * X.SET.scale
end
do
	local sig
	local function hook()
		if sig then sig:Disconnect() end
		sig = nil
		local cam = Workspace.CurrentCamera
		if cam then sig = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
		fit()
	end
	hook()
	track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook))
	track({ Disconnect = function() if sig then sig:Disconnect() end end })
end

-- единый менеджер перетаскивания (одно подключение вместо сотен)
local drag = { move = nil, fin = nil, sc = nil }
local function beginDrag(move, fin, scroller)
	drag.move, drag.fin, drag.sc = move, fin, scroller
	if scroller then scroller.ScrollingEnabled = false end
end
track(UIS.InputChanged:Connect(function(i)
	if drag.move and isMove(i) then drag.move(i) end
end))
track(UIS.InputEnded:Connect(function(i)
	if drag.move and isPress(i) then
		local fin, sc = drag.fin, drag.sc
		drag.move, drag.fin, drag.sc = nil, nil, nil
		if sc then sc.ScrollingEnabled = true end
		if fin then fin() end
	end
end))

-- перетаскивание за область (с поправкой на UIScale); короткий клик -> onClick
local function makeDraggable(handle, target, onClick, scaleObj)
	handle.InputBegan:Connect(function(i)
		if not isPress(i) then return end
		local moved = false
		local startMouse, startPos = i.Position, target.Position
		beginDrag(function(m)
			local d = m.Position - startMouse
			if d.Magnitude > 5 then moved = true end
			if moved then
				local k = scaleObj and scaleObj.Scale or 1
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / k, startPos.Y.Scale, startPos.Y.Offset + d.Y / k)
			end
		end, function()
			if not moved and onClick then onClick() end
		end)
	end)
end

-- иконки из Frame
local function Icon(kind, parent, size)
	local box = new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1,
	}, parent)
	new("UIScale", { Scale = (size or 20) / 20 }, box)
	local ss, ff = {}, {}
	local function ring(w, h, x, y, th, rad)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1, BorderSizePixel = 0,
		}, box)
		corner(f, rad or math.max(w, h) / 2)
		ss[#ss + 1] = stroke(f, WHITE, th or 2)
	end
	local function solid(w, h, x, y, rot, rad)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0, BackgroundColor3 = WHITE, BorderSizePixel = 0,
		}, box)
		if rad then corner(f, rad) end
		ff[#ff + 1] = f
	end
	if kind == "eye" then
		ring(18, 12, 10, 10, 2); solid(6, 6, 10, 10, 0, 3)
	elseif kind == "info" then
		ring(16, 16, 10, 10, 2); solid(2, 2, 10, 6, 0, 1); solid(2, 6, 10, 12)
	elseif kind == "user" then
		ring(8, 8, 10, 6, 2); ring(16, 9, 10, 15, 2, 4)
	elseif kind == "globe" then
		ring(17, 17, 10, 10, 2); solid(17, 2, 10, 10); ring(7, 17, 10, 10, 2)
	elseif kind == "grid" then
		solid(7, 7, 5, 5, 0, 2); solid(7, 7, 15, 5, 0, 2); solid(7, 7, 5, 15, 0, 2); solid(7, 7, 15, 15, 0, 2)
	elseif kind == "cfg" then
		ring(17, 17, 10, 10, 2, 4); solid(9, 2, 10, 7); solid(9, 2, 10, 10); solid(9, 2, 10, 13)
	elseif kind == "gear" then
		ring(11, 11, 10, 10, 2); solid(3, 20, 10, 10, 0, 1); solid(20, 3, 10, 10, 0, 1)
	elseif kind == "sword" then
		solid(3, 17, 11, 8, 45, 1); solid(11, 2, 7, 13, 45, 1); solid(3, 6, 4, 16, 45, 1)
	elseif kind == "bars" then
		solid(4, 8, 4, 14, 0, 1); solid(4, 13, 10, 11.5, 0, 1); solid(4, 18, 16, 9, 0, 1)
	end
	local api = {}
	function api.paint(col, t)
		for _, s in ipairs(ss) do tw(s, t or .2, { Color = col }) end
		for _, f in ipairs(ff) do tw(f, t or .2, { BackgroundColor3 = col }) end
	end
	api.paint(C.sub, 0)
	return api
end

local function Arrow(parent, pos)
	local c = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = pos, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1 }, parent)
	for _, d in ipairs({ { 3.5, 45 }, { 8.5, -45 } }) do
		corner(new("Frame", {
			AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(d[1], 6), Size = UDim2.fromOffset(7, 2),
			Rotation = d[2], BackgroundColor3 = C.sub, BorderSizePixel = 0,
		}, c), 1)
	end
	return c
end

-- шапка бокового меню
local Side = new("Frame", { Size = UDim2.new(0, SIDE, 1, 0), BackgroundColor3 = C.side, BorderSizePixel = 0 }, Main)
new("Frame", { Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.line, BorderSizePixel = 0 }, Side)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 18), Size = UDim2.new(1, -20, 0, 26),
	Font = Enum.Font.GothamBlack, Text = "NURHUB", TextSize = 21, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
}, Side)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -20, 0, 14),
	Font = Enum.Font.GothamMedium, Text = "visual  •  v" .. VERSION .. " MM2", TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
}, Side)
local dragZone = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1 }, Side)
makeDraggable(dragZone, Root, nil, fitScale)
local dragTop = new("Frame", { Position = UDim2.fromOffset(SIDE, 0), Size = UDim2.new(1, -SIDE, 0, 12), BackgroundTransparency = 1 }, Main)
makeDraggable(dragTop, Root, nil, fitScale)

local navList = new("Frame", { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -134), BackgroundTransparency = 1 }, Side)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, navList)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, navList)

-- профиль внизу: аватар, ник, юзернейм
do
	local prof = new("Frame", { Position = UDim2.new(0, 8, 1, -60), Size = UDim2.new(1, -16, 0, 52), BackgroundColor3 = C.card, BorderSizePixel = 0 }, Side)
	corner(prof, 10)
	stroke(prof, C.line, 1)
	local avF = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.field, BorderSizePixel = 0 }, prof)
	corner(avF, 18)
	local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, avF)
	corner(img, 18)
	X.getAvatar(LP.UserId, function(u) if img.Parent then img.Image = u end end)
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Color3.fromRGB(70, 220, 120), BorderSizePixel = 0,
	}, avF)
	corner(dot, 6)
	stroke(dot, C.card, 2)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 9), Size = UDim2.new(1, -58, 0, 16), Font = Enum.Font.GothamBold,
		Text = LP.DisplayName, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, prof)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 26), Size = UDim2.new(1, -58, 0, 14), Font = Enum.Font.Gotham,
		Text = "@" .. LP.Name, TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, prof)
end

local Content = new("Frame", {
	Position = UDim2.new(0, SIDE + 14, 0, 14), Size = UDim2.new(1, -(SIDE + 28), 1, -28), BackgroundTransparency = 1,
}, Main)

local tabs, pages, ptok = {}, {}, {}
local current
local onTabChanged

local function paintTab(name, sel, anim)
	local t = tabs[name]
	local d = anim and .22 or 0
	tw(t.btn, d, { BackgroundTransparency = sel and 0 or 1 })
	tw(t.lbl, d, { TextColor3 = sel and WHITE or C.sub })
	t.icon.paint(sel and WHITE or C.sub, d)
end

local function switchTab(name)
	if name == current then return end
	local prev = current
	current = name
	ptok[prev] = (ptok[prev] or 0) + 1
	local my = ptok[prev]
	local old, nxt = pages[prev], pages[name]
	tw(old, .18, { GroupTransparency = 1, Position = UDim2.new(0, 0, 0, -12) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(.2, function()
		if ptok[prev] == my and current ~= prev then old.Visible = false end
	end)
	nxt.Position = UDim2.new(0, 0, 0, 22)
	nxt.GroupTransparency = 1
	nxt.Visible = true
	tw(nxt, .45, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	for n in pairs(tabs) do paintTab(n, n == name, true) end
	if onTabChanged then onTabChanged(name) end
end

-- страница: заголовок + прокрутка, возвращает ScrollingFrame
local function createTab(name, iconKind, sub)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.accent, BackgroundTransparency = 1,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = ord(),
	}, navList)
	corner(btn, 10)
	local bg = new("UIGradient", { Color = ColorSequence.new(C.accent, C.accent2), Rotation = 0 }, btn)
	X.acc(function() bg.Color = ColorSequence.new(C.accent, C.accent2) end)
	local holder = new("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 }, btn)
	local icon = Icon(iconKind, holder, 18)
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamMedium, Text = name, TextSize = 13, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)
	btn.MouseEnter:Connect(function()
		if current ~= name then tw(lbl, .15, { TextColor3 = C.text }); icon.paint(C.text, .15) end
	end)
	btn.MouseLeave:Connect(function()
		if current ~= name then tw(lbl, .15, { TextColor3 = C.sub }); icon.paint(C.sub, .15) end
	end)
	btn.MouseButton1Click:Connect(function() switchTab(name) end)

	local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1 }, Content)
	local title = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -150, 0, 24), Font = Enum.Font.GothamBold, RichText = true,
		TextSize = 16, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
		Text = name .. ' <font color="rgb(135,133,158)">· ' .. sub .. "</font>",
	}, cg)
	tabs[name] = { btn = btn, lbl = lbl, icon = icon, title = title, sub = sub }
	local sf = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.accent, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, cg)
	X.acc(function() sf.ScrollBarImageColor3 = C.accent end)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), PaddingTop = UDim.new(0, 2) }, sf)
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	pages[name] = cg
	X.curTab = name
	X.pageSF[name] = sf
	return sf
end

-- применение языка ко всем зарегистрированным подписям
function X.applyLang()
	for _, r in ipairs(X.trReg) do
		if r.i.Parent then
			local s = X.tr(r.en)
			r.i.Text = r.f and r.f(s) or s
		end
	end
	for n, t in pairs(tabs) do
		t.lbl.Text = X.tr(n)
		t.title.Text = X.tr(n) .. ' <font color="rgb(135,133,158)">· ' .. X.tr(t.sub) .. "</font>"
	end
	if X.onLang then pcall(X.onLang) end
end

-- две колонки внутри страницы
local function Columns(sf)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, sf)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12),
		VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local function col(o)
		local c = new("Frame", { Size = UDim2.new(.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = o }, holder)
		new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, c)
		return c
	end
	return col(1), col(2)
end

----------------------------------------------------------------
-- Компоненты
----------------------------------------------------------------
local ROW = 28

local function Card(parent, title)
	local outer = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = ord(),
	}, parent)
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, outer)
	if title then
		local t = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Font = Enum.Font.GothamBold,
			TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
		}, outer)
		X.tl(t, title, function(s) return X.SET.lang == "ru" and s or string.upper(s) end)
		new("UIPadding", { PaddingLeft = UDim.new(0, 3) }, t)
	end
	local panel = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = 2,
	}, outer)
	corner(panel, 10)
	X.regT(panel)
	stroke(panel, C.line, 1)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	}, panel)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	return panel
end

local function Label(parent, text, color, size)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham, TextSize = size or 12, TextColor3 = color or C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ord(),
	}, parent)
	X.tl(l, text)
	return l
end

local function Button(parent, text, cb, fill)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = fill or C.drawer, BorderSizePixel = 0, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, LayoutOrder = ord(),
	}, parent)
	X.tl(b, text)
	corner(b, 9)
	X.regSearch(text, b)
	if not fill then stroke(b, C.line, 1) end
	b.MouseEnter:Connect(function() tw(b, .15, { BackgroundColor3 = fill and fill:Lerp(WHITE, .12) or Color3.fromRGB(30, 29, 44) }) end)
	b.MouseLeave:Connect(function() tw(b, .15, { BackgroundColor3 = fill or C.drawer }) end)
	b.MouseButton1Click:Connect(function() if cb then cb(b) end end)
	return b
end

-- ползунок привязан к полю таблицы (opts.div — делитель, opts.fmt — формат)
local function Slider(parent, title, min, max, tbl, key, opts)
	opts = opts or {}
	local div = opts.div or 1
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = ord() }, parent)
	local tl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(.62, 0, 0, 16), Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	X.tl(tl, title)
	local val = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(.38, 0, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	local bar = new("Frame", { Position = UDim2.fromOffset(0, 23), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = C.track, BorderSizePixel = 0 }, row)
	corner(bar, 3)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, bar)
	corner(fill, 3)
	local fg = new("UIGradient", { Color = ColorSequence.new(C.accent, C.accent2) }, fill)
	X.acc(function() fg.Color = ColorSequence.new(C.accent, C.accent2) end)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, fill)
	corner(knob, 7)
	local hit = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 24),
	}, row)
	local function show()
		local v = tbl[key]
		fill.Size = UDim2.new(math.clamp((v * div - min) / (max - min), 0, 1), 0, 1, 0)
		val.Text = opts.fmt and opts.fmt(v) or tostring(v)
	end
	show()
	X.reg(show)
	X.regSearch(title, row)
	local function upd(i)
		local p = math.clamp((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		tbl[key] = math.floor(min + (max - min) * p + .5) / div
		show()
		if opts.onChange then opts.onChange(tbl[key]) end
	end
	hit.InputBegan:Connect(function(i)
		if isPress(i) then
			beginDrag(upd, opts.onEnd, hit:FindFirstAncestorOfClass("ScrollingFrame"))
			upd(i)
		end
	end)
end

-- HSV-палитра: быстрые цвета + Hue / Saturation / Brightness
local QUICK = {
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 70, 85), Color3.fromRGB(255, 190, 50), Color3.fromRGB(80, 235, 130),
	Color3.fromRGB(70, 215, 255), Color3.fromRGB(80, 120, 255), Color3.fromRGB(170, 100, 255), Color3.fromRGB(255, 100, 200),
}
local function ColorBar(parent, label, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = ord() }, parent)
	local tl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), Font = Enum.Font.GothamMedium,
		TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	X.tl(tl, label)
	local bar = new("TextButton", {
		Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, row)
	corner(bar, 4)
	local grad = new("UIGradient", {}, bar)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, bar)
	corner(knob, 6)
	stroke(knob, Color3.fromRGB(18, 18, 24), 2)
	local function upd(i) onChange(math.clamp((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)) end
	bar.InputBegan:Connect(function(i)
		if isPress(i) then
			beginDrag(upd, nil, bar:FindFirstAncestorOfClass("ScrollingFrame"))
			upd(i)
		end
	end)
	return { grad = grad, set = function(a) tw(knob, .06, { Position = UDim2.new(a, 0, .5, 0) }) end }
end

local function ColorPicker(parent, tbl, key)
	local h, s, v = tbl[key]:ToHSV()
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = ord() }, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, top)
	local prev = new("Frame", { Size = UDim2.fromOffset(26, 16), BorderSizePixel = 0, LayoutOrder = 0 }, top)
	corner(prev, 4)
	stroke(prev, Color3.fromRGB(70, 68, 92), 1)
	local hueB, satB, valB
	local function refresh()
		local c = Color3.fromHSV(h, s, v)
		prev.BackgroundColor3 = c
		satB.grad.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
		valB.grad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
		hueB.set(h); satB.set(s); valB.set(v)
		return c
	end
	for i, c in ipairs(QUICK) do
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = c, BorderSizePixel = 0, LayoutOrder = i,
		}, top)
		corner(b, 4)
		stroke(b, Color3.fromRGB(60, 58, 80), 1)
		b.MouseButton1Click:Connect(function()
			h, s, v = c:ToHSV()
			tbl[key] = refresh()
		end)
	end
	hueB = ColorBar(parent, "Hue", function(a) h = math.min(a, .999); tbl[key] = refresh() end)
	satB = ColorBar(parent, "Saturation", function(a) s = a; tbl[key] = refresh() end)
	valB = ColorBar(parent, "Brightness", function(a) v = a; tbl[key] = refresh() end)
	local keys = {}
	for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, .999), 1, 1)) end
	hueB.grad.Color = ColorSequence.new(keys)
	refresh()
	X.reg(function() h, s, v = tbl[key]:ToHSV(); refresh() end)
	return { set = function(c) h, s, v = c:ToHSV(); refresh() end }
end

-- маленькая подпись фиксированной высоты (для шторок)
X.FLabel = function(parent, text)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), Font = Enum.Font.GothamMedium,
		TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ord(),
	}, parent)
	X.tl(l, text)
	return l
end

-- палитра градиентов: готовые пары + два редактируемых цвета
local GRADS = {
	{ Color3.fromRGB(12, 12, 20), Color3.fromRGB(150, 110, 255) }, { Color3.fromRGB(255, 80, 100), Color3.fromRGB(255, 190, 70) },
	{ Color3.fromRGB(40, 220, 160), Color3.fromRGB(60, 140, 255) }, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(70, 70, 90) },
	{ Color3.fromRGB(255, 100, 200), Color3.fromRGB(110, 90, 255) }, { Color3.fromRGB(0, 0, 0), Color3.fromRGB(230, 230, 240) },
}
local function GradientPicker(parent, tbl, k1, k2)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = ord() }, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	X.FLabel(parent, "Top color")
	local p1 = ColorPicker(parent, tbl, k1)
	X.FLabel(parent, "Bottom color")
	local p2 = ColorPicker(parent, tbl, k2)
	for i, g in ipairs(GRADS) do
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(24, 20), BackgroundColor3 = WHITE, BorderSizePixel = 0, LayoutOrder = i,
		}, row)
		corner(b, 5)
		stroke(b, Color3.fromRGB(60, 58, 80), 1)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(g[1], g[2]) }, b)
		b.MouseButton1Click:Connect(function()
			tbl[k1], tbl[k2] = g[1], g[2]
			p1.set(g[1]); p2.set(g[2])
		end)
	end
end

-- выпадающий список (раскрывается внутри панели)
local function Dropdown(parent, title, list, tbl, key)
	local IT, GAPY = 22, 2
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = ord() }, parent)
	local tl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.GothamMedium,
		TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	X.tl(tl, title)
	local head = new("TextButton", {
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.field, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
	}, holder)
	corner(head, 6)
	stroke(head, C.line, 1)
	local curLbl = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0),
		Font = Enum.Font.GothamMedium, Text = tbl[key], TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, head)
	local arrow = Arrow(head, UDim2.new(1, -14, .5, 0))
	local listH = #list * IT + (#list - 1) * GAPY + 8
	local box = new("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, listH), BackgroundColor3 = C.field, BorderSizePixel = 0 }, holder)
	corner(box, 6)
	stroke(box, C.line, 1)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, box)
	new("UIListLayout", { Padding = UDim.new(0, GAPY), SortOrder = Enum.SortOrder.LayoutOrder }, box)
	local btns, open = {}, false
	local function render()
		curLbl.Text = tbl[key]
		for n, b in pairs(btns) do b.TextColor3 = (n == tbl[key]) and WHITE or C.sub end
	end
	local function setOpen(v)
		open = v
		tw(holder, .25, { Size = UDim2.new(1, 0, 0, v and (46 + listH) or 44) })
		tw(arrow, .25, { Rotation = v and 180 or 0 })
	end
	for i, n in ipairs(list) do
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, IT), BackgroundColor3 = C.accent, BackgroundTransparency = 1, AutoButtonColor = false,
			Text = n, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, LayoutOrder = i,
		}, box)
		corner(b, 5)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
		btns[n] = b
		b.MouseEnter:Connect(function() tw(b, .12, { BackgroundTransparency = .75 }) end)
		b.MouseLeave:Connect(function() tw(b, .12, { BackgroundTransparency = 1 }) end)
		b.MouseButton1Click:Connect(function()
			tbl[key] = n
			render()
			setOpen(false)
		end)
	end
	head.MouseButton1Click:Connect(function() setOpen(not open) end)
	render()
	X.reg(render)
end

-- шторка с прокруткой внутри (если настроек много)
X.attachDrawer = function(box, head, arrowPos, builder)
	local arrow = Arrow(head, arrowPos)
	local drawer = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, ROW + 6), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C.drawer,
		BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent,
		ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never,
	}, box)
	X.acc(function() drawer.ScrollBarImageColor3 = C.accent end)
	corner(drawer, 8)
	stroke(drawer, C.line, 1)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, drawer)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12),
	}, drawer)
	local open = false
	local function calc()
		local h, n = 0, 0
		for _, c in ipairs(drawer:GetChildren()) do
			if c:IsA("GuiObject") and c.Visible then
				h += c.Size.Y.Offset
				n += 1
			end
		end
		local ch = h + math.max(n - 1, 0) * 8 + 18
		local vh = math.min(ch, 210)
		drawer.CanvasSize = UDim2.fromOffset(0, ch)
		drawer.Size = UDim2.new(1, 0, 0, vh)
		return ROW + 6 + vh + 2
	end
	local function resize()
		local target = calc()
		if open then tw(box, .22, { Size = UDim2.new(1, 0, 0, target) }) end
	end
	local function hook(c)
		if c:IsA("GuiObject") then
			c:GetPropertyChangedSignal("Size"):Connect(resize)
			c:GetPropertyChangedSignal("Visible"):Connect(resize)
		end
	end
	local pv = X.inDrawer
	X.inDrawer = true
	builder(drawer)
	X.inDrawer = pv
	for _, c in ipairs(drawer:GetChildren()) do hook(c) end
	drawer.ChildAdded:Connect(function(c) hook(c); resize() end)
	head.MouseButton1Click:Connect(function()
		open = not open
		local target = calc()
		tw(box, .35, { Size = UDim2.new(1, 0, 0, open and target or ROW) })
		tw(arrow, .28, { Rotation = open and 180 or 0 })
	end)
end

-- переключатель привязан к tbl[key]; со стрелкой и шторкой, если есть builder(drawer)
local function Toggle(parent, title, tbl, key, builder)
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = ord() }, parent)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, box)
	local tl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	X.tl(tl, title)
	local sw = new("TextButton", {
		AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, 0, ROW / 2), Size = UDim2.fromOffset(36, 18),
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", BackgroundColor3 = C.off,
	}, box)
	corner(sw, 9)
	local swGrad = new("UIGradient", { Color = ColorSequence.new(C.accent, C.accent2), Enabled = false }, sw)
	X.acc(function() swGrad.Color = ColorSequence.new(C.accent, C.accent2) end)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, .5), Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 3, .5, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, sw)
	corner(knob, 6)
	local function paint(anim)
		local on = tbl[key]
		local d = anim and .2 or 0
		swGrad.Enabled = on
		tw(sw, d, { BackgroundColor3 = on and WHITE or C.off })
		tw(knob, d, { Position = on and UDim2.new(1, -15, .5, 0) or UDim2.new(0, 3, .5, 0) }, Enum.EasingStyle.Back)
	end
	paint(false)
	X.reg(function() paint(true) end)
	X.regSearch(title, box)
	sw.MouseButton1Click:Connect(function()
		tbl[key] = not tbl[key]
		paint(true)
	end)
	if builder then
		X.attachDrawer(box, head, UDim2.new(1, -52, .5, 0), builder)
	else
		head.MouseButton1Click:Connect(function()
			tbl[key] = not tbl[key]
			paint(true)
		end)
	end
end

-- строка-шторка без переключателя
X.DrawerRow = function(parent, title, builder)
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = ord() }, parent)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, box)
	local tl = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Font = Enum.Font.GothamMedium,
		TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, head)
	X.tl(tl, title)
	X.regSearch(title, box)
	X.attachDrawer(box, head, UDim2.new(1, -10, .5, 0), builder)
end

-- сетка кнопок-вариантов (шейдеры и т.п.)
X.Grid = function(parent, list, get, set, cols)
	cols = cols or 2
	local rows = math.ceil(#list / cols)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, rows * 24 + (rows - 1) * 4), BackgroundTransparency = 1, LayoutOrder = ord() }, parent)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -4 * (cols - 1) / cols - 1, 0, 24), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local btns = {}
	local function render()
		for n, b in pairs(btns) do
			local on = get() == n
			tw(b, .2, { BackgroundColor3 = on and C.accent or C.field, TextColor3 = on and WHITE or C.sub })
		end
	end
	for i, n in ipairs(list) do
		local b = new("TextButton", {
			Text = n, AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = 11, BorderSizePixel = 0,
			BackgroundColor3 = C.field, TextColor3 = C.sub, LayoutOrder = i,
		}, holder)
		corner(b, 6)
		btns[n] = b
		b.MouseButton1Click:Connect(function()
			set(n)
			render()
		end)
	end
	X.reg(render)
	X.acc(render)
end

-- поле ввода: возвращает контейнер и TextBox
X.TextBox = function(parent, placeholder)
	local f = new("Frame", { BackgroundColor3 = C.field, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ord() }, parent)
	corner(f, 8)
	stroke(f, C.line, 1)
	local tb = new("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = C.text, PlaceholderColor3 = C.sub, PlaceholderText = X.tr(placeholder), Text = "",
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	return f, tb
end

-- список игроков с аватаром и ником (ник шерифа синий, убийцы красный)
X.PlayerList = function(parent, height, onPick, withColor, isSel, ctbl)
	ctbl = ctbl or CFG.pcolor
	local sf = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.field, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
		ScrollingDirection = Enum.ScrollingDirection.Y, LayoutOrder = ord(),
	}, parent)
	corner(sf, 8)
	stroke(sf, C.line, 1)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, sf)
	local rows = {}
	local function rebuild()
		for _, r in pairs(rows) do r.f:Destroy() end
		rows = {}
		local i = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP then
				i += 1
				local f = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i,
				}, sf)
				corner(f, 8)
				local st = stroke(f, C.accent, 1.5, 1)
				local av = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.field, BorderSizePixel = 0 }, f)
				corner(av, 14)
				local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, av)
				corner(img, 14)
				X.getAvatar(plr.UserId, function(u) if img.Parent then img.Image = u end end)
				local nm = new("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -(withColor and 78 or 50), 1, 0),
					Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd, Text = plr.DisplayName,
				}, f)
				local sw
				if withColor then
					sw = new("TextButton", {
						AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -6, .5, 0), Size = UDim2.fromOffset(22, 22),
						BorderSizePixel = 0, AutoButtonColor = false, Text = "", BackgroundColor3 = C.off,
					}, f)
					corner(sw, 11)
					stroke(sw, C.line, 1)
					sw.MouseButton1Click:Connect(function()
						local cur = ctbl[plr.UserId]
						local idx = 0
						for k, q in ipairs(QUICK) do
							if cur == q then idx = k end
						end
						idx += 1
						ctbl[plr.UserId] = QUICK[idx] -- после последнего цвета: сброс (nil)
					end)
				end
				f.MouseButton1Click:Connect(function() onPick(plr) end)
				rows[plr] = { f = f, nm = nm, st = st, sw = sw }
			end
		end
	end
	local function upd()
		for plr, r in pairs(rows) do
			r.nm.TextColor3 = X.ROLE_COL[X.roleOf(plr)] or C.text
			r.st.Color = C.accent
			r.st.Transparency = (isSel and isSel(plr)) and 0 or 1
			if r.sw then r.sw.BackgroundColor3 = ctbl[plr.UserId] or C.off end
		end
	end
	rebuild()
	upd()
	X.lists[#X.lists + 1] = { rebuild = rebuild, upd = upd, frame = sf }
end

----------------------------------------------------------------
-- Рисование линий / стрелок (общее для ESP и превью)
----------------------------------------------------------------
local function mkLine(parent)
	return new("Frame", { AnchorPoint = Vector2.new(.5, .5), BorderSizePixel = 0, BackgroundColor3 = WHITE, Visible = false, Size = UDim2.fromOffset(0, 1) }, parent)
end
local function setLine(f, a, b, col, th)
	local d = b - a
	f.Size = UDim2.fromOffset(d.Magnitude, th)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = col
	f.Visible = true
end
local function hideList(l)
	if l then
		for _, f in ipairs(l) do f.Visible = false end
	end
end

-- стрелка-указатель: цветной наконечник + белый хвост (ровные срезы)
local function mkArrow(parent)
	local c = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(34, 28), BackgroundTransparency = 1, Visible = false }, parent)
	local sc = new("UIScale", { Scale = 1 }, c)
	local N = 10
	local function tri(x0, w, h, col, tr, dx)
		local list = {}
		for i = 0, N - 1 do
			local fh = math.max(1, h * (1 - i / N))
			list[#list + 1] = new("Frame", {
				AnchorPoint = Vector2.new(0, .5), Position = UDim2.fromOffset(x0 + i * (w / N) + dx, 14 + dx),
				Size = UDim2.fromOffset(w / N + .7, fh), BackgroundColor3 = col, BackgroundTransparency = tr, BorderSizePixel = 0,
			}, c)
		end
		return list
	end
	tri(17, 16, 26, Color3.new(0, 0, 0), .55, 1)
	tri(2, 10, 16, Color3.new(0, 0, 0), .55, 1)
	return { frame = c, scale = sc, head = tri(17, 16, 26, WHITE, 0, 0), tail = tri(2, 10, 16, WHITE, 0, 0) }
end
local function paintArrow(a, col, size, tailCol)
	if a.lc ~= col or a.lt ~= tailCol then
		a.lc, a.lt = col, tailCol
		for _, f in ipairs(a.head) do f.BackgroundColor3 = col end
		for _, f in ipairs(a.tail) do f.BackgroundColor3 = tailCol or WHITE end
	end
	if a.ls ~= size then
		a.ls = size
		a.scale.Scale = size / 24
	end
end

----------------------------------------------------------------
-- ESP слой (экранные Frame, без Drawing)
----------------------------------------------------------------
local espGui = new("ScreenGui", {
	Name = "NurHubMM2_ESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
mount(espGui)

local TH = 1.5
local function mkBox()
	return new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Visible = false }, espGui)
end
local function mkText()
	return new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 14), Font = Enum.Font.GothamBold, TextSize = 11, TextScaled = false,
		TextStrokeTransparency = .35, TextStrokeColor3 = Color3.new(0, 0, 0), Visible = false,
	}, espGui)
end

local R15 = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
local EDGES = {}
for i = 0, 7 do
	for _, b in ipairs({ 1, 2, 4 }) do
		if bit32.band(i, b) == 0 then EDGES[#EDGES + 1] = { i, i + b } end
	end
end

local S = {}
local function hideAll(d)
	for _, v in pairs(d) do
		if typeof(v) == "Instance" then
			if v:IsA("GuiObject") then
				v.Visible = false
			elseif v:IsA("Highlight") or v:IsA("Light") then
				v.Enabled = false
			end
		elseif type(v) == "table" then
			for _, f in ipairs(v) do
				if typeof(f) == "Instance" and f:IsA("GuiObject") then f.Visible = false end
			end
		end
	end
end
local function destroyData(d)
	for _, v in pairs(d) do
		if typeof(v) == "Instance" then
			pcall(function() v:Destroy() end)
		elseif type(v) == "table" then
			for _, x in ipairs(v) do
				if typeof(x) == "Instance" then pcall(function() x:Destroy() end) end
			end
		end
	end
end

local function setCorners(list, x0, y0, x1, y1, l, t, col)
	local spec = {
		{ x0, y0, l, t }, { x0, y0, t, l }, { x1 - l, y0, l, t }, { x1 - t, y0, t, l },
		{ x0, y1 - t, l, t }, { x0, y1 - l, t, l }, { x1 - l, y1 - t, l, t }, { x1 - t, y1 - l, t, l },
	}
	for i, s in ipairs(spec) do
		local f = list[i]
		f.Position = UDim2.fromOffset(s[1], s[2])
		f.Size = UDim2.fromOffset(s[3], s[4])
		f.BackgroundColor3 = col
		f.Visible = true
	end
end
-- длина уголка: не больше заданной в настройке и пропорциональна размеру бокса
-- (на расстоянии уголки уменьшаются вместе с игроком и никогда не растут)
local function cornerLen(w, h)
	return math.max(2, math.min(CFG.corner.len, math.min(w, h) * 0.28))
end

local function drawPlayer(d, plr, char, hum, root, cam, vs, role)
	-- Chams + Outline (Highlight)
	if CFG.chams.on or CFG.outline.on or CFG.wall.on then
		local hl = d.hl
		if not hl then
			hl = new("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, espGui)
			d.hl = hl
		end
		if hl.Adornee ~= char then hl.Adornee = char end
		local fc, oc = X.cc(CFG.chams.color), X.cc(CFG.outline.color)
		if CFG.wall.on then
			local c2 = X.visibleTo(char) and CFG.wall.vis or CFG.wall.hid
			fc, oc = c2, c2
		end
		hl.FillColor = fc
		hl.FillTransparency = CFG.chams.on and CFG.chams.trans or 1
		hl.OutlineColor = oc
		hl.OutlineTransparency = (CFG.outline.on or CFG.wall.on) and 0 or 1
		hl.Enabled = true
	elseif d.hl then
		d.hl.Enabled = false
	end

	-- Glow (PointLight)
	if CFG.glow.on then
		local l = d.light
		if not l or l.Parent ~= root then
			if l then l:Destroy() end
			l = new("PointLight", { Shadows = false }, root)
			d.light = l
		end
		l.Color = CFG.glow.color
		l.Range = CFG.glow.range
		l.Brightness = CFG.glow.bright
		l.Enabled = true
	elseif d.light then
		d.light.Enabled = false
	end

	-- Стрелки (игрок вне экрана)
	local rp = cam:WorldToViewportPoint(root.Position)
	local off = rp.Z <= 0 or rp.X < 0 or rp.X > vs.X or rp.Y < 0 or rp.Y > vs.Y
	if CFG.arrows.on and off then
		local a = d.arrow
		if not a then
			a = mkArrow(espGui)
			d.arrow = a
			d.arrowF = a.frame
		end
		local center = vs / 2
		local dir
		if rp.Z > 0 then
			dir = Vector2.new(rp.X, rp.Y) - center
		else
			local v = cam.CFrame:PointToObjectSpace(root.Position)
			dir = Vector2.new(v.X, -v.Y)
		end
		if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
		dir = dir.Unit
		local R = math.min(CFG.arrows.radius, math.min(vs.X, vs.Y) / 2 - 24)
		local pos = center + dir * R
		a.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
		a.frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
		local acol = CFG.acolor[plr.UserId] or (role == "Murderer" and CFG.arrows.murder) or (role == "Sheriff" and CFG.arrows.sheriff) or CFG.arrows.color
		paintArrow(a, acol, CFG.arrows.size, WHITE)
		a.frame.Visible = true
	elseif d.arrowF then
		d.arrowF.Visible = false
	end

	-- Границы персонажа
	local needBox = CFG.box2d.on or CFG.corner.on or CFG.fill.on or CFG.box3d.on or CFG.name.on or CFG.dist.on or CFG.health.on or CFG.avatar.on
	local pts, allFront
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	if needBox then
		local cf = root.CFrame * CFrame.new(0, -0.25, 0)
		pts, allFront = {}, true
		for i = 0, 7 do
			local x = (i % 2) * 2 - 1
			local y = (math.floor(i / 2) % 2) * 2 - 1
			local z = math.floor(i / 4) * 2 - 1
			local p = cam:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(x * 2, y * 2.95, z * 1)))
			pts[i] = p
			if p.Z <= 0 then
				allFront = false
			else
				x0 = math.min(x0, p.X); y0 = math.min(y0, p.Y)
				x1 = math.max(x1, p.X); y1 = math.max(y1, p.Y)
			end
		end
		if allFront then
			local tp = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2.7, 0))
			local bp = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))
			if tp.Z > 0 and bp.Z > 0 then
				local hgt = math.abs(bp.Y - tp.Y)
				local cx = (tp.X + bp.X) / 2
				x0, x1 = cx - hgt * .28, cx + hgt * .28
				y0, y1 = math.min(tp.Y, bp.Y), math.max(tp.Y, bp.Y)
			end
		end
	end
	local rect = pts ~= nil and allFront

	-- заливка (градиент)
	if CFG.fill.on and rect then
		local f = d.fill
		if not f then
			f = mkBox()
			d.fill = f
			d.fillG = new("UIGradient", { Rotation = 90 }, f)
		end
		f.Position = UDim2.fromOffset(x0, y0)
		f.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
		f.BackgroundTransparency = CFG.fill.trans
		d.fillG.Color = ColorSequence.new(CFG.fill.c1, CFG.fill.c2)
		f.Visible = true
	elseif d.fill then
		d.fill.Visible = false
	end

	-- Box 2D
	if CFG.box2d.on and rect then
		local b = d.box
		if not b then
			b = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espGui)
			d.box = b
			d.boxS = new("UIStroke", { Thickness = TH, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		end
		b.Position = UDim2.fromOffset(x0, y0)
		b.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
		d.boxS.Color = X.cc(CFG.box2d.color)
		b.Visible = true
	elseif d.box then
		d.box.Visible = false
	end

	-- Corner Box: уголки масштабируются вместе с игроком
	if CFG.corner.on and rect then
		if not d.cn then
			d.cn = {}
			for i = 1, 8 do d.cn[i] = mkBox() end
		end
		local w, h = x1 - x0, y1 - y0
		setCorners(d.cn, x0, y0, x1, y1, cornerLen(w, h), h < 40 and 1 or 2, X.cc(CFG.corner.color))
	else
		hideList(d.cn)
	end

	-- Box 3D
	if CFG.box3d.on and pts then
		if not d.e3 then
			d.e3 = {}
			for i = 1, 12 do d.e3[i] = mkLine(espGui) end
		end
		for i, e in ipairs(EDGES) do
			local a, b = pts[e[1]], pts[e[2]]
			if a.Z > 0 and b.Z > 0 then
				setLine(d.e3[i], Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y), X.cc(CFG.box3d.color), TH)
			else
				d.e3[i].Visible = false
			end
		end
	else
		hideList(d.e3)
	end

	-- Ник
	if CFG.name.on and rect then
		local t = d.name
		if not t then
			t = mkText()
			d.name = t
			t.AnchorPoint = Vector2.new(.5, 1)
		end
		t.Position = UDim2.fromOffset((x0 + x1) / 2, y0 - 2)
		t.Text = plr.DisplayName
		t.TextColor3 = CFG.name.color
		t.Visible = true
	elseif d.name then
		d.name.Visible = false
	end

	-- Аватар (круг с аватаркой слева от игрока)
	if CFG.avatar.on and rect then
		local a = d.av
		if not a then
			a = new("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0, Visible = false }, espGui)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, a)
			d.avS = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, a)
			local img = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, a)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, img)
			d.av = a
			X.getAvatar(plr.UserId, function(u) if img.Parent then img.Image = u end end)
		end
		a.Position = UDim2.fromOffset(x0 - 9, y0)
		d.avS.Color = X.cc(CFG.avatar.color)
		a.Visible = true
	elseif d.av then
		d.av.Visible = false
	end

	-- Дистанция
	if CFG.dist.on and rect then
		local t = d.dist
		if not t then
			t = mkText()
			d.dist = t
			t.AnchorPoint = Vector2.new(.5, 0)
		end
		t.Position = UDim2.fromOffset((x0 + x1) / 2, y1 + 2)
		t.Text = math.floor((cam.CFrame.Position - root.Position).Magnitude) .. "m"
		t.TextColor3 = CFG.dist.color
		t.Visible = true
	elseif d.dist then
		d.dist.Visible = false
	end

	-- Здоровье
	if CFG.health.on and rect then
		local bg = d.hpBg
		if not bg then
			bg = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = .35, BorderSizePixel = 0, Visible = false }, espGui)
			d.hpBg = bg
			d.hpFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, bg)
		end
		local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		bg.Position = UDim2.fromOffset(x0 - 5, y0)
		bg.Size = UDim2.fromOffset(2, y1 - y0)
		d.hpFill.Size = UDim2.fromScale(1, frac)
		d.hpFill.BackgroundColor3 = CFG.health.color
		bg.Visible = true
	elseif d.hpBg then
		d.hpBg.Visible = false
	end

	-- Голова (кольцо)
	local head = char:FindFirstChild("Head")
	if CFG.head.on and head then
		local hp = cam:WorldToViewportPoint(head.Position)
		if hp.Z > 0 then
			local up = cam.CFrame.UpVector * (head.Size.Y / 2)
			local pt = cam:WorldToViewportPoint(head.Position + up)
			local pb = cam:WorldToViewportPoint(head.Position - up)
			local diam = math.max(6, math.abs(pt.Y - pb.Y))
			local r = d.ring
			if not r then
				r = new("Frame", { AnchorPoint = Vector2.new(.5, .5), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espGui)
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, r)
				d.ringS = new("UIStroke", { Thickness = TH, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, r)
				d.ring = r
			end
			r.Position = UDim2.fromOffset(hp.X, hp.Y)
			r.Size = UDim2.fromOffset(diam, diam)
			d.ringS.Color = X.cc(CFG.head.color)
			r.Visible = true
		elseif d.ring then
			d.ring.Visible = false
		end
	elseif d.ring then
		d.ring.Visible = false
	end

	-- Skeleton
	if CFG.skel.on then
		local list = hum.RigType == Enum.HumanoidRigType.R15 and R15 or R6
		if not d.sk then
			d.sk = {}
			for i = 1, 14 do d.sk[i] = mkLine(espGui) end
		end
		for i = 1, 14 do
			local pr, line = list[i], d.sk[i]
			local a = pr and char:FindFirstChild(pr[1])
			local b = pr and char:FindFirstChild(pr[2])
			if a and b then
				local pa = cam:WorldToViewportPoint(a.Position)
				local pb = cam:WorldToViewportPoint(b.Position)
				if pa.Z > 0 and pb.Z > 0 then
					setLine(line, Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), X.cc(CFG.skel.color), TH)
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end
	else
		hideList(d.sk)
	end

	-- Tracers
	if CFG.tracer.on and rp.Z > 0 then
		local o = Vector2.new(vs.X / 2, vs.Y)
		if CFG.tracer.origin == "Top" then
			o = Vector2.new(vs.X / 2, 0)
		elseif CFG.tracer.origin == "Crosshair" then
			o = Vector2.new(vs.X / 2, vs.Y / 2)
		end
		if not d.tr then d.tr = mkLine(espGui) end
		setLine(d.tr, o, Vector2.new(rp.X, rp.Y), X.cc(CFG.tracer.color), TH)
	elseif d.tr then
		d.tr.Visible = false
	end
end

local function inTeam(plr)
	return CFG.esp.team and LP.Team ~= nil and plr.Team == LP.Team
end

local espErrShown = false
track(RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	local camPos = cam.CFrame.Position
	local plist = X.plist
	for i = 1, #plist do
		local plr = plist[i]
		if plr ~= LP then
			local d = S[plr]
			if not d then
				d = {}
				S[plr] = d
			end
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
			local role = X.roleOf(plr)
			if not CFG.esp.on or not hum or not root or hum.Health <= 0
				or (camPos - root.Position).Magnitude > CFG.esp.maxDist or inTeam(plr) or not X.passTarget(plr, role) then
				if not d.hidden then
					hideAll(d)
					d.hidden = true
				end
			else
				d.hidden = false
				X.ov = CFG.pcolor[plr.UserId] or (CFG.esp.roles and X.ROLE_COL[role]) or nil
				local ok, err = pcall(drawPlayer, d, plr, char, hum, root, cam, vs, role)
				X.ov = nil
				if not ok and not espErrShown then
					espErrShown = true
					warn("[NurHub] ESP error: " .. tostring(err))
				end
			end
		end
	end
end))

----------------------------------------------------------------
-- HAT / TRAILS / FOV
----------------------------------------------------------------
local hats, trails = {}, {}
local alive = true

local function destroyTrail(t)
	if t then
		pcall(function() t.tr:Destroy() end)
		pcall(function() t.a0:Destroy() end)
		pcall(function() t.a1:Destroy() end)
	end
end

local function updateHat(plr, cam)
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local h = hats[plr]
	local want = CFG.hat.on and head and hum and hum.Health > 0 and (CFG.hat.scope == "Everyone" or plr == LP)
	if not want then
		if h then
			pcall(function() h:Destroy() end)
			hats[plr] = nil
			X.hatInfo[plr] = nil
		end
		return
	end
	local info = X.hatInfo[plr]
	if not h or not h.Parent then
		h = new("Part", {
			Name = "NH_Hat", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
			Size = Vector3.new(1, 1, 1), Transparency = 1, Material = Enum.Material.Neon,
		}, Workspace)
		new("SpecialMesh", { MeshId = "rbxassetid://1033714" }, h)
		hats[plr] = h
		info = { sig = "" }
		X.hatInfo[plr] = info
	end
	local k = CFG.hat.size / 100
	local R_, HGT = 1.7 * k, 1.0 * k
	local n = math.max(3, math.floor(CFG.hat.lines))
	local sig = n .. "|" .. tostring(CFG.hat.rainbow)
	if info.sig ~= sig then
		for _, c in ipairs(h:GetChildren()) do
			if not c:IsA("SpecialMesh") then c:Destroy() end
		end
		info.sig = sig
		info.rim, info.beams = {}, {}
		info.k, info.col, info.tr = nil, nil, nil
		local apex = new("Attachment", { Name = "Apex" }, h)
		info.apex = apex
		for i = 1, n do info.rim[i] = new("Attachment", { Name = "R" .. i }, h) end
		local function beam(a0, a1, c0, c1)
			info.beams[#info.beams + 1] = new("Beam", {
				Attachment0 = a0, Attachment1 = a1, Width0 = .06, Width1 = .06, FaceCamera = true, LightEmission = 1,
				LightInfluence = 0, Segments = 1, Color = ColorSequence.new(c0, c1),
			}, h)
		end
		for i = 1, n do
			local j = i % n + 1
			local c0 = CFG.hat.rainbow and Color3.fromHSV((i - 1) / n, .9, 1) or CFG.hat.color
			local c1 = CFG.hat.rainbow and Color3.fromHSV((j - 1) / n, .9, 1) or CFG.hat.color
			beam(apex, info.rim[i], c0, c0)
			beam(info.rim[i], info.rim[j], c0, c1)
		end
	end
	if not CFG.hat.rainbow and info.col ~= CFG.hat.color then
		info.col = CFG.hat.color
		for _, b in ipairs(info.beams) do b.Color = ColorSequence.new(CFG.hat.color) end
	end
	local btr = math.clamp(CFG.hat.trans * .6, 0, .9)
	if info.tr ~= btr then
		info.tr = btr
		for _, b in ipairs(info.beams) do b.Transparency = NumberSequence.new(btr) end
	end
	if info.k ~= k then
		info.k = k
		info.apex.Position = Vector3.new(0, HGT / 2, 0)
		for i, at in ipairs(info.rim) do
			local ang = (i - 1) / n * math.pi * 2
			at.Position = Vector3.new(math.cos(ang) * R_, -HGT / 2, math.sin(ang) * R_)
		end
		local mesh = h:FindFirstChildOfClass("SpecialMesh")
		if mesh then mesh.Scale = Vector3.new(1.7 * k, 1.1 * k, 1.7 * k) end
	end
	local close = plr == LP and cam ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.8
	local mode = CFG.hat.mode
	local showLines, showSolid = mode ~= "Solid", mode ~= "Lines"
	for _, b in ipairs(info.beams) do b.Enabled = showLines and not close end
	h.Transparency = (showSolid and not close) and CFG.hat.trans or 1
	h.Color = (CFG.hat.shimmer and showSolid) and Color3.fromHSV((os.clock() * .25) % 1, .7, 1) or CFG.hat.color
	h.CFrame = CFrame.new(head.Position + Vector3.new(0, head.Size.Y / 2 + HGT / 2 + .05, 0))
end

local function updateTrail(plr)
	local char = plr.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	local t = trails[plr]
	if CFG.trail.on and root and (CFG.trail.scope == "Everyone" or plr == LP) then
		if not t or not t.tr.Parent or t.a0.Parent ~= root then
			destroyTrail(t)
			local a0 = new("Attachment", { Name = "NH_T0" }, root)
			local a1 = new("Attachment", { Name = "NH_T1" }, root)
			local tr = new("Trail", { Name = "NH_Trail", Attachment0 = a0, Attachment1 = a1, FaceCamera = true, MinLength = 0.05 }, root)
			t = { a0 = a0, a1 = a1, tr = tr }
			trails[plr] = t
		end
		local w = CFG.trail.width
		t.a0.Position = Vector3.new(0, w / 2, 0)
		t.a1.Position = Vector3.new(0, -w / 2, 0)
		t.tr.Lifetime = CFG.trail.len
		t.tr.Color = ColorSequence.new(CFG.trail.color)
		t.tr.Transparency = NumberSequence.new(0.1, 1)
		t.tr.LightEmission = 1
		t.tr.Enabled = true
	elseif t then
		destroyTrail(t)
		trails[plr] = nil
	end
end

track(RunService.RenderStepped:Connect(function()
	if not CFG.hat.on and next(hats) == nil then return end
	local cam = Workspace.CurrentCamera
	local plist = X.plist
	for i = 1, #plist do updateHat(plist[i], cam) end
end))

task.spawn(function()
	while alive do
		if CFG.trail.on or next(trails) ~= nil then
			for _, plr in ipairs(X.plist) do pcall(updateTrail, plr) end
		end
		task.wait(0.2)
	end
end)

track(Players.PlayerRemoving:Connect(function(p)
	local d = S[p]
	if d then
		destroyData(d)
		S[p] = nil
	end
	if hats[p] then pcall(function() hats[p]:Destroy() end); hats[p] = nil end
	if trails[p] then destroyTrail(trails[p]); trails[p] = nil end
end))

-- Custom FOV
local fovOn, fovSaved = false, nil
pcall(function() RunService:UnbindFromRenderStep("NH_FOV") end)
RunService:BindToRenderStep("NH_FOV", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	if CFG.fov.on then
		if not fovOn then fovSaved = cam.FieldOfView end
		fovOn = true
		cam.FieldOfView = CFG.fov.val
	elseif fovOn then
		fovOn = false
		cam.FieldOfView = fovSaved or 70
	end
end)

----------------------------------------------------------------
-- ESP EDITOR (предпросмотр справа)
----------------------------------------------------------------
do
	local STAGE_W, STAGE_H = PREV_W - 24, 400
	local SC_W, SC_H = 160, 320
	local OX, OY = (STAGE_W - SC_W) / 2, STAGE_H - SC_H - 4
	local BX, BY, BW, BH = 12, 72, 136, 222
	local FX, FY = BX + 8, BY + 6

	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamBold, Text = "ESP Editor", TextSize = 16, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, Preview)
	local sub = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 14),
		Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, Preview)
	X.tl(sub, "live preview of your settings")

	local stage = new("Frame", {
		Position = UDim2.fromOffset(12, 58), Size = UDim2.fromOffset(STAGE_W, STAGE_H), BackgroundColor3 = C.field, BorderSizePixel = 0, ClipsDescendants = true,
	}, Preview)
	corner(stage, 12)
	stroke(stage, C.line, 1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(24, 21, 38), Color3.fromRGB(10, 10, 16)) }, stage)
	local scene = new("Frame", { Position = UDim2.fromOffset(OX, OY), Size = UDim2.fromOffset(SC_W, SC_H), BackgroundTransparency = 1 }, stage)

	local function pvFrame(x, y, w, h, col, rad)
		local f = new("Frame", {
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col or WHITE, BorderSizePixel = 0, Visible = false,
		}, scene)
		if rad then corner(f, rad) end
		return f
	end

	local gl1 = pvFrame(BX - 18, BY - 18, BW + 36, BH + 36, WHITE, 44)
	local gl2 = pvFrame(BX - 36, BY - 36, BW + 72, BH + 72, WHITE, 60)
	local floorShadow = pvFrame(BX + 14, BY + BH - 8, 108, 12, Color3.new(0, 0, 0), 6)
	floorShadow.BackgroundTransparency = .55
	floorShadow.Visible = true
	local pvFill = pvFrame(BX, BY, BW, BH, WHITE, 0)
	local pvFillG = new("UIGradient", { Rotation = 90 }, pvFill)

	local BASE = Color3.fromRGB(72, 70, 96)
	local pieces = {}
	for _, p in ipairs({
		{ 43, 0, 34, 34, 17 }, { 30, 37, 60, 70, 8 }, { 10, 37, 18, 68, 7 },
		{ 92, 37, 18, 68, 7 }, { 31, 110, 28, 100, 7 }, { 61, 110, 28, 100, 7 },
	}) do
		local f = pvFrame(FX + p[1], FY + p[2], p[3], p[4], BASE, p[5])
		f.Visible = true
		local s = stroke(f, WHITE, 1.5)
		s.Enabled = false
		pieces[#pieces + 1] = { f = f, s = s }
	end

	local pv3, pvSk = {}, {}
	for i = 1, 12 do pv3[i] = mkLine(scene) end
	for i = 1, 14 do pvSk[i] = mkLine(scene) end
	local pvTr = mkLine(scene)
	local pvBox = pvFrame(BX, BY, BW, BH, WHITE, 0)
	pvBox.BackgroundTransparency = 1
	local pvBoxS = new("UIStroke", { Thickness = TH, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pvBox)
	local pvCn = {}
	for i = 1, 8 do pvCn[i] = pvFrame(0, 0, 4, 4, WHITE, 0) end
	local pvRing = pvFrame(FX + 60 - 20, FY + 17 - 20, 40, 40, WHITE, 20)
	pvRing.BackgroundTransparency = 1
	local pvRingS = new("UIStroke", { Thickness = TH, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pvRing)

	local pvHatBox = new("Frame", {
		Position = UDim2.fromOffset(FX + 30, FY + 3 - 30), Size = UDim2.fromOffset(60, 30), BackgroundTransparency = 1, ClipsDescendants = true, Visible = false,
	}, scene)
	local pvHat = new("Frame", {
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(30, 30), Size = UDim2.fromOffset(42, 42),
		Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0,
	}, pvHatBox)

	local function pvText()
		return new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 14), Font = Enum.Font.GothamBold, TextSize = 12,
			TextStrokeTransparency = .35, TextStrokeColor3 = Color3.new(0, 0, 0), Visible = false,
		}, scene)
	end
	local pvName, pvDist = pvText(), pvText()
	pvName.Text = LP.DisplayName
	pvName.AnchorPoint = Vector2.new(.5, 1)
	pvDist.Text = "37m"
	pvDist.AnchorPoint = Vector2.new(.5, 0)
	pvDist.Position = UDim2.fromOffset(BX + BW / 2, BY + BH + 3)
	local pvHpBg = pvFrame(BX - 6, BY, 2, BH, Color3.new(0, 0, 0), 0)
	pvHpBg.BackgroundTransparency = .35
	local pvHpFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, pvHpBg)
	local pvArrow = mkArrow(scene)
	pvArrow.frame.Position = UDim2.fromOffset(SC_W / 2 - 6, 20)

	local J = {
		head = { 60, 18 }, neck = { 60, 38 }, lsh = { 32, 42 }, rsh = { 88, 42 }, lel = { 20, 72 }, rel = { 100, 72 },
		lh = { 20, 102 }, rh = { 100, 102 }, pel = { 60, 108 }, lhip = { 45, 112 }, rhip = { 75, 112 },
		lkn = { 45, 160 }, rkn = { 75, 160 }, lft = { 45, 205 }, rft = { 75, 205 },
	}
	local BONES = {
		{ "head", "neck" }, { "neck", "pel" }, { "neck", "lsh" }, { "lsh", "lel" }, { "lel", "lh" },
		{ "neck", "rsh" }, { "rsh", "rel" }, { "rel", "rh" }, { "pel", "lhip" }, { "lhip", "lkn" },
		{ "lkn", "lft" }, { "pel", "rhip" }, { "rhip", "rkn" }, { "rkn", "rft" },
	}
	local function jp(n) return Vector2.new(FX + J[n][1], FY + J[n][2]) end
	local function pvCorner3(i)
		local fx0, fy0, fx1, fy1 = BX, BY + 14, BX + 122, BY + BH
		local back = bit32.band(i, 4) ~= 0 and 14 or 0
		local x = (bit32.band(i, 1) ~= 0 and fx1 or fx0) + back
		local y = (bit32.band(i, 2) ~= 0 and fy1 or fy0) - back
		return Vector2.new(x, y)
	end

	function X.pvUpdate(t)
		local e = CFG.esp.on
		for _, p in ipairs(pieces) do
			local col = BASE
			if e and CFG.chams.on then col = BASE:Lerp(CFG.chams.color, 1 - CFG.chams.trans) end
			p.f.BackgroundColor3 = col
			p.s.Enabled = e and CFG.outline.on
			p.s.Color = CFG.outline.color
		end
		local g = e and CFG.glow.on
		gl1.Visible = g; gl2.Visible = g
		if g then
			gl1.BackgroundColor3 = CFG.glow.color; gl2.BackgroundColor3 = CFG.glow.color
			gl1.BackgroundTransparency = math.clamp(1 - CFG.glow.bright / 9, .6, .92)
			gl2.BackgroundTransparency = math.clamp(1 - CFG.glow.bright / 18, .8, .96)
		end
		pvFill.Visible = e and CFG.fill.on
		if pvFill.Visible then
			pvFill.BackgroundTransparency = CFG.fill.trans
			pvFillG.Color = ColorSequence.new(CFG.fill.c1, CFG.fill.c2)
		end
		pvBox.Visible = e and CFG.box2d.on
		pvBoxS.Color = CFG.box2d.color
		if e and CFG.corner.on then
			setCorners(pvCn, BX, BY, BX + BW, BY + BH, cornerLen(BW, BH), 2, CFG.corner.color)
		else
			for _, f in ipairs(pvCn) do f.Visible = false end
		end
		if e and CFG.box3d.on then
			for i, ed in ipairs(EDGES) do setLine(pv3[i], pvCorner3(ed[1]), pvCorner3(ed[2]), CFG.box3d.color, TH) end
		else
			hideList(pv3)
		end
		if e and CFG.skel.on then
			for i, b in ipairs(BONES) do setLine(pvSk[i], jp(b[1]), jp(b[2]), CFG.skel.color, TH) end
		else
			hideList(pvSk)
		end
		pvRing.Visible = e and CFG.head.on
		pvRingS.Color = CFG.head.color
		if e and CFG.tracer.on then
			local o = Vector2.new(SC_W / 2, STAGE_H - OY)
			if CFG.tracer.origin == "Top" then
				o = Vector2.new(SC_W / 2, -OY)
			elseif CFG.tracer.origin == "Crosshair" then
				o = Vector2.new(SC_W / 2, STAGE_H / 2 - OY)
			end
			setLine(pvTr, o, Vector2.new(FX + 60, FY + 72), CFG.tracer.color, TH)
		else
			pvTr.Visible = false
		end
		pvHatBox.Visible = CFG.hat.on
		if CFG.hat.on then
			pvHat.BackgroundColor3 = CFG.hat.color
			pvHat.BackgroundTransparency = CFG.hat.trans
		end
		pvName.Visible = e and CFG.name.on
		pvName.TextColor3 = CFG.name.color
		pvName.Position = UDim2.fromOffset(BX + BW / 2, BY - 4 - (CFG.hat.on and 28 or 0))
		pvDist.Visible = e and CFG.dist.on
		pvDist.TextColor3 = CFG.dist.color
		pvHpBg.Visible = e and CFG.health.on
		if pvHpBg.Visible then
			pvHpFill.Size = UDim2.fromScale(1, 0.7 + 0.3 * math.sin(t * 1.5))
			pvHpFill.BackgroundColor3 = CFG.health.color
		end
		pvArrow.frame.Visible = e and CFG.arrows.on
		if pvArrow.frame.Visible then
			pvArrow.frame.Rotation = (t * 50) % 360
			paintArrow(pvArrow, CFG.arrows.color, math.min(CFG.arrows.size, 30))
		end
	end
end

----------------------------------------------------------------
-- Меню: открыть / закрыть, предпросмотр показываем только в Visual
----------------------------------------------------------------
local menuOpen = false
local menuTok, pvTok = 0, 0

local function showPreview(v)
	pvTok += 1
	local my = pvTok
	if v then
		Preview.Visible = true
		tw(Preview, .5, { GroupTransparency = 0 })
	else
		tw(Preview, .22, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(.25, function()
			if pvTok == my then Preview.Visible = false end
		end)
	end
end
onTabChanged = function(name)
	if menuOpen then showPreview(name == "Visual") end
end

local function setMenu(open)
	if open == menuOpen then return end
	menuOpen = open
	menuTok += 1
	local my = menuTok
	if open then
		Root.Visible = true
		tw(Main, .4, { GroupTransparency = 0 })
		tw(animScale, .5, { Scale = 1 }, Enum.EasingStyle.Back)
		if current == "Visual" then showPreview(true) end
	else
		tw(Main, .25, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(animScale, .28, { Scale = .9 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		showPreview(false)
		task.delay(.3, function()
			if menuTok == my then Root.Visible = false end
		end)
	end
end

track(RunService.RenderStepped:Connect(function()
	if menuOpen and current == "Visual" and X.pvUpdate then X.pvUpdate(os.clock()) end
end))

----------------------------------------------------------------
-- MM2 ФУНКЦИИ: FPS, third person, следы, xray, мир, игрок, фарм, телепорты, конфиги
----------------------------------------------------------------
local function runMM2()
	for _, n in ipairs({ "NH_CC", "NH_Bloom", "NH_Rays", "NH_Blur" }) do
		local o = Lighting:FindFirstChild(n)
		if o then o:Destroy() end
	end

	------------------------------------------------ Show FPS
	local fpsLbl = new("TextLabel", {
		Name = "NH_FPS", BackgroundColor3 = Color3.fromRGB(14, 14, 20), BackgroundTransparency = .2,
		Size = UDim2.fromOffset(84, 26), Font = Enum.Font.GothamBold, TextSize = 14, Text = "60 FPS", BorderSizePixel = 0, Visible = false,
	}, espGui)
	corner(fpsLbl, 8)
	stroke(fpsLbl, C.line, 1)
	local acc, cnt, shown = 0, 0, 60
	X.fpsNow = 60
	track(RunService.RenderStepped:Connect(function(dt)
		acc += dt
		cnt += 1
		if acc >= .5 then
			shown = math.floor(cnt / acc + .5)
			X.fpsNow = shown
			acc, cnt = 0, 0
		end
		if fpsLbl.Visible ~= CFG.fps.on then fpsLbl.Visible = CFG.fps.on end
		if CFG.fps.on then
			fpsLbl.Text = (CFG.fps.custom and CFG.fps.value or shown) .. " FPS"
			fpsLbl.TextColor3 = CFG.fps.color
			fpsLbl.AnchorPoint = Vector2.new(CFG.fps.x, CFG.fps.y)
			fpsLbl.Position = UDim2.fromScale(CFG.fps.x, CFG.fps.y)
		end
	end))

	------------------------------------------------ Third person
	local saved
	track(RunService.RenderStepped:Connect(function()
		if CFG.third.on then
			if not saved then saved = { LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance, LP.CameraMode } end
			pcall(function()
				LP.CameraMode = Enum.CameraMode.Classic
				LP.CameraMaxZoomDistance = math.max(CFG.third.dist, LP.CameraMinZoomDistance)
				LP.CameraMinZoomDistance = CFG.third.dist
				LP.CameraMaxZoomDistance = CFG.third.dist
			end)
		elseif saved then
			pcall(function()
				LP.CameraMaxZoomDistance = saved[2]
				LP.CameraMinZoomDistance = saved[1]
				LP.CameraMode = saved[3]
			end)
			saved = nil
		end
	end))

	------------------------------------------------ Следы игрока (с анимацией)
	local stepParams = RaycastParams.new()
	stepParams.FilterType = Enum.RaycastFilterType.Exclude
	local live, lastPos = 0, {}
	local function mkPart(round, size, cf, col)
		local p = new("Part", {
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
			Material = Enum.Material.Neon, Color = col, Transparency = .1, Name = "NH_Step",
		}, Workspace)
		if round then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(.05, size, size)
			p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
		else
			p.Size = Vector3.new(size, .05, size)
			p.CFrame = cf
		end
		return p
	end
	local function spawnStep(pos, look, side)
		if live > 160 then return end
		local col, life, shape = CFG.steps.color, CFG.steps.life, CFG.steps.shape
		local base = CFrame.lookAt(pos, pos + look)
		local parts = {}
		local function add(round, size, cf, grow)
			local p = mkPart(round, size, cf, col)
			parts[#parts + 1] = p
			local goal = round and Vector3.new(.05, size * grow, size * grow) or Vector3.new(size * grow, .05, size * grow)
			TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = goal }):Play()
		end
		if shape == "Circle" then
			add(true, 1.2, base, 2.2)
		elseif shape == "Square" then
			add(false, 1.1, base, 1.8)
		elseif shape == "Diamond" then
			add(false, 1.1, base * CFrame.Angles(0, math.rad(45), 0), 1.8)
		else
			add(true, .55, base * CFrame.new(side * .22, 0, -.45), 1.5)
			add(true, .38, base * CFrame.new(side * .22, 0, .35), 1.5)
		end
		live += #parts
		task.delay(life + .2, function()
			for _, p in ipairs(parts) do pcall(function() p:Destroy() end) end
			live -= #parts
		end)
	end
	track(RunService.Heartbeat:Connect(function()
		if not CFG.steps.on then return end
		for _, plr in ipairs(X.plist) do
			if CFG.steps.scope == "Everyone" or plr == LP then
				local ch = plr.Character
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air then
					local st = lastPos[plr]
					if not st then
						lastPos[plr] = { pos = root.Position, side = 1 }
					else
						local d = root.Position - st.pos
						local flat = Vector3.new(d.X, 0, d.Z)
						if flat.Magnitude >= CFG.steps.dist and os.clock() - (st.t or 0) >= CFG.steps.delay then
							stepParams.FilterDescendantsInstances = { ch }
							local r = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), stepParams)
							if r then spawnStep(r.Position + Vector3.new(0, .06, 0), flat.Unit, st.side) end
							st.side = -st.side
							st.t = os.clock()
							st.pos = root.Position
						end
					end
				end
			end
		end
	end))
	track(Players.PlayerRemoving:Connect(function(p) lastPos[p] = nil end))

	------------------------------------------------ Xray (только при включении, без постоянных rescan)
	local xr = {}
	local function skip(p)
		if p.Size.Magnitude < 6 then return true end
		local m = p:FindFirstAncestorOfClass("Model")
		while m do
			if m:FindFirstChildOfClass("Humanoid") then return true end
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") or nil
		end
		return false
	end
	local function xrOne(p)
		if p:IsA("BasePart") and not p:IsA("Terrain") and not skip(p) then
			xr[p] = true
			p.LocalTransparencyModifier = CFG.xray.amount
		end
	end
	local was, lastAmt = false, nil
	task.spawn(function()
		while alive do
			if CFG.xray.on then
				if not was then
					was, lastAmt = true, CFG.xray.amount
					local n = 0
					for _, p in ipairs(Workspace:GetDescendants()) do
						xrOne(p)
						n += 1
						if n % 600 == 0 then task.wait() end
					end
				elseif lastAmt ~= CFG.xray.amount then
					lastAmt = CFG.xray.amount
					for p in pairs(xr) do
						if p.Parent then p.LocalTransparencyModifier = lastAmt else xr[p] = nil end
					end
				end
			elseif was then
				was = false
				for p in pairs(xr) do
					if p.Parent then p.LocalTransparencyModifier = 0 end
				end
				xr = {}
			end
			task.wait(.3)
		end
	end)

	------------------------------------------------ Мир: шейдеры + свет
	local cc = new("ColorCorrectionEffect", { Name = "NH_CC" }, Lighting)
	local bloom = new("BloomEffect", { Name = "NH_Bloom", Intensity = 0, Size = 24, Threshold = 2 }, Lighting)
	local rays = new("SunRaysEffect", { Name = "NH_Rays", Intensity = 0, Spread = .6 }, Lighting)
	local blur = new("BlurEffect", { Name = "NH_Blur", Size = 0 }, Lighting)

	local PRESETS = {
		["Sakura"]    = { tint = Color3.fromRGB(255, 226, 236), sat = 0.15, contrast = 0.05, bloom = 0.4, weather = "sakura" },
		["Blood"]     = { tint = Color3.fromRGB(255, 165, 165), sat = 0.1, contrast = 0.2, bright = -0.08, bloom = 0.3, weather = "blood" },
		["4K"]        = { sat = 0.25, contrast = 0.22, bright = 0.02, bloom = 0.5, rays = 0.1 },
		["Snow"]      = { tint = Color3.fromRGB(226, 240, 255), sat = -0.1, bright = 0.05, weather = "snow" },
		["Sunset"]    = { tint = Color3.fromRGB(255, 200, 150), sat = 0.25, rays = 0.25, bloom = 0.6 },
		["Rain"]      = { tint = Color3.fromRGB(190, 205, 225), sat = -0.2, contrast = 0.1, bright = -0.05, weather = "rain" },
		["Neon"]      = { tint = Color3.fromRGB(220, 190, 255), sat = 0.5, contrast = 0.25, bloom = 1.2 },
		["Noir"]      = { sat = -1, contrast = 0.3 },
		["Vintage"]   = { tint = Color3.fromRGB(255, 235, 200), sat = -0.25, contrast = 0.1 },
		["Cyberpunk"] = { tint = Color3.fromRGB(200, 170, 255), sat = 0.45, contrast = 0.2, bloom = 0.9 },
		["Ocean"]     = { tint = Color3.fromRGB(170, 215, 255), sat = 0.2, bright = 0.02, rays = 0.15 },
		["Matrix"]    = { tint = Color3.fromRGB(150, 255, 170), sat = -0.2, contrast = 0.25, bloom = 0.5 },
		["Autumn"]    = { tint = Color3.fromRGB(255, 205, 150), sat = 0.2, weather = "leaves" },
		["Dreamy"]    = { tint = Color3.fromRGB(255, 230, 245), sat = 0.1, bright = 0.06, bloom = 1.0, rays = 0.2 },
	}
	X.PRESET_LIST = { "Sakura", "Blood", "4K", "Snow", "Sunset", "Rain", "Neon", "Noir", "Vintage", "Cyberpunk", "Ocean", "Matrix", "Autumn", "Dreamy" }

	local weatherPart = new("Part", {
		Name = "NH_Weather", Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		Transparency = 1, Size = Vector3.new(90, 1, 90), CastShadow = false,
	})
	local emitters, curWeather = {}, nil
	local WEATHER = {
		snow = function(e)
			e.Rate = 260; e.Lifetime = NumberRange.new(5, 6); e.Speed = NumberRange.new(6, 9)
			e.Size = NumberSequence.new(0.3); e.Color = ColorSequence.new(WHITE)
			e.Transparency = NumberSequence.new(0.1); e.Acceleration = Vector3.new(2, 0, 1)
			e.RotSpeed = NumberRange.new(-60, 60); e.SpreadAngle = Vector2.new(12, 12)
		end,
		rain = function(e)
			e.Rate = 650; e.Lifetime = NumberRange.new(0.4, 0.45); e.Speed = NumberRange.new(95, 110)
			e.Size = NumberSequence.new(0.14); e.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
			e.Transparency = NumberSequence.new(0.35); e.SpreadAngle = Vector2.new(3, 3)
			e.Orientation = Enum.ParticleOrientation.VelocityParallel
		end,
		sakura = function(e)
			e.Rate = 70; e.Lifetime = NumberRange.new(7, 9); e.Speed = NumberRange.new(3, 6)
			e.Size = NumberSequence.new(0.5)
			e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 200), Color3.fromRGB(255, 205, 225))
			e.Transparency = NumberSequence.new(0.05); e.Acceleration = Vector3.new(3, 0, 1.5)
			e.RotSpeed = NumberRange.new(-120, 120); e.SpreadAngle = Vector2.new(25, 25)
		end,
		blood = function(e)
			e.Rate = 130; e.Lifetime = NumberRange.new(2.5, 3); e.Speed = NumberRange.new(12, 16)
			e.Size = NumberSequence.new(0.35); e.Color = ColorSequence.new(Color3.fromRGB(170, 0, 10))
			e.Transparency = NumberSequence.new(0.1); e.SpreadAngle = Vector2.new(6, 6)
		end,
		leaves = function(e)
			e.Rate = 60; e.Lifetime = NumberRange.new(7, 9); e.Speed = NumberRange.new(3, 6)
			e.Size = NumberSequence.new(0.5)
			e.Color = ColorSequence.new(Color3.fromRGB(230, 120, 40), Color3.fromRGB(150, 80, 30))
			e.Transparency = NumberSequence.new(0.05); e.Acceleration = Vector3.new(4, 0, 2)
			e.RotSpeed = NumberRange.new(-150, 150); e.SpreadAngle = Vector2.new(25, 25)
		end,
	}
	local function setWeather(kind)
		if kind == curWeather then return end
		curWeather = kind
		for k, e in pairs(emitters) do e.Enabled = (k == kind) end
		if kind then
			if not emitters[kind] then
				local e = new("ParticleEmitter", { EmissionDirection = Enum.NormalId.Bottom, LockedToPart = false, Rotation = NumberRange.new(0, 360) }, weatherPart)
				WEATHER[kind](e)
				emitters[kind] = e
			end
			emitters[kind].Enabled = true
			weatherPart.Parent = Workspace.CurrentCamera
		else
			weatherPart.Parent = nil
		end
	end

	local orig, active = nil, false
	local function snap()
		orig = {
			Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
			GlobalShadows = Lighting.GlobalShadows, ExposureCompensation = Lighting.ExposureCompensation,
		}
	end
	local function neutral()
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = 0, 0, 0, WHITE
		bloom.Intensity, bloom.Threshold = 0, 2
		rays.Intensity = 0
		blur.Size = 0
	end
	local function restore()
		neutral()
		setWeather(nil)
		if orig then
			for k, v in pairs(orig) do pcall(function() Lighting[k] = v end) end
		end
	end
	local function anyOn()
		return CFG.shader.on or CFG.wbright.on or CFG.wglow.on or CFG.wdark.on or CFG.wgrade.on or CFG.wblur.on
			or CFG.wfog.on or CFG.wrays.on or CFG.wfull.on or CFG.wshadow.on
	end
	local function sigOf()
		return table.concat({
			tostring(CFG.shader.on), CFG.shader.preset, tostring(CFG.wbright.on), CFG.wbright.val, tostring(CFG.wglow.on), CFG.wglow.int, CFG.wglow.thr,
			tostring(CFG.wdark.on), CFG.wdark.val, tostring(CFG.wgrade.on), CFG.wgrade.sat, CFG.wgrade.con, tostring(CFG.wfog.on), CFG.wfog.val,
			tostring(CFG.wrays.on), CFG.wrays.val, tostring(CFG.wfull.on), tostring(CFG.wshadow.on),
		}, "|")
	end
	local function apply()
		local p = (CFG.shader.on and PRESETS[CFG.shader.preset]) or {}
		local bright = (p.bright or 0) + (CFG.wbright.on and CFG.wbright.val or 0) - (CFG.wdark.on and CFG.wdark.val * .5 or 0)
		local contrast = (p.contrast or 0) + (CFG.wgrade.on and CFG.wgrade.con or 0)
		local sat = (p.sat or 0) + (CFG.wgrade.on and CFG.wgrade.sat or 0)
		cc.Brightness = math.clamp(bright, -1, 1)
		cc.Contrast = math.clamp(contrast, -1, 1)
		cc.Saturation = math.clamp(sat, -1, 1)
		cc.TintColor = p.tint or WHITE
		bloom.Intensity = (p.bloom or 0) + (CFG.wglow.on and CFG.wglow.int or 0)
		bloom.Threshold = CFG.wglow.on and CFG.wglow.thr or (p.bloom and 1.2 or 2)
		rays.Intensity = math.clamp((p.rays or 0) + (CFG.wrays.on and CFG.wrays.val or 0), 0, 1)
		Lighting.ExposureCompensation = orig.ExposureCompensation - (CFG.wdark.on and CFG.wdark.val * 1.5 or 0)
		Lighting.Brightness = orig.Brightness + (CFG.wfull.on and 2 or 0)
		if CFG.wfull.on then
			Lighting.Ambient = Color3.fromRGB(170, 170, 170)
			Lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
		else
			Lighting.Ambient = orig.Ambient
			Lighting.OutdoorAmbient = orig.OutdoorAmbient
		end
		if CFG.wfog.on then
			Lighting.FogStart = 0
			Lighting.FogEnd = math.max(30, 2200 * (1 - CFG.wfog.val) ^ 2)
			Lighting.FogColor = Color3.fromRGB(180, 180, 190)
		else
			Lighting.FogStart = orig.FogStart
			Lighting.FogEnd = orig.FogEnd
			Lighting.FogColor = orig.FogColor
		end
		Lighting.GlobalShadows = (not CFG.wshadow.on) and orig.GlobalShadows
		setWeather(p.weather)
	end
	task.spawn(function()
		local lastSig, lastApply = "", 0
		while alive do
			if anyOn() then
				if not active then
					active = true
					snap()
					lastSig = ""
				end
				local sg, now = sigOf(), os.clock()
				if sg ~= lastSig or now - lastApply > .5 then
					lastSig, lastApply = sg, now
					pcall(apply)
				end
			elseif active then
				active = false
				restore()
			end
			task.wait(.1)
		end
	end)

	-- время суток + motion blur + погода за камерой
	local savedClock, lastLook = nil, Vector3.new(0, 0, -1)
	track(RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if weatherPart.Parent and cam then weatherPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 38, 0)) end
		if CFG.wtime.on then
			if not savedClock then savedClock = Lighting.ClockTime end
			Lighting.ClockTime = CFG.wtime.val
		elseif savedClock then
			Lighting.ClockTime = savedClock
			savedClock = nil
		end
		if CFG.wblur.on and cam then
			local look = cam.CFrame.LookVector
			local ang = math.acos(math.clamp(look:Dot(lastLook), -1, 1))
			lastLook = look
			local goal = math.clamp(ang * CFG.wblur.val * 30, 0, 28)
			blur.Size = blur.Size + (goal - blur.Size) * .4
		elseif cam and blur.Size ~= 0 and not active then
			blur.Size = 0
		end
	end))

	------------------------------------------------ Монеты / пушка (сканер + ESP)
	local coins, guns = {}, {}
	X.coins, X.guns = coins, guns
	local function scan(v)
		if v.Name == "Coin_Server" and v:IsA("BasePart") then
			coins[v] = true
		elseif v.Name == "GunDrop" and (v:IsA("BasePart") or v:IsA("Model")) then
			guns[v] = true
		end
	end
	track(Workspace.DescendantAdded:Connect(function(v)
		scan(v)
		if CFG.xray.on then xrOne(v) end
	end))
	task.spawn(function()
		local n = 0
		for _, v in ipairs(Workspace:GetDescendants()) do
			scan(v)
			n += 1
			if n % 800 == 0 then task.wait() end
		end
	end)

	local gunO, coinO = {}, {}
	local shownAny = false
	local function posOf(i)
		if i:IsA("Model") then return i:GetPivot().Position end
		return i.Position
	end
	track(RunService.RenderStepped:Connect(function()
		if not (CFG.coin.on or CFG.gun.on) and not shownAny then return end
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local vs = cam.ViewportSize
		local anyShown = false
		for g in pairs(guns) do
			local o = gunO[g]
			if not g.Parent then
				guns[g] = nil
				if o then
					for _, x in pairs(o) do pcall(function() x:Destroy() end) end
					gunO[g] = nil
				end
			elseif CFG.gun.on then
				if not o then
					o = {
						hl = new("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = .45 }, espGui),
						txt = mkText(), ln = mkLine(espGui),
					}
					gunO[g] = o
				end
				anyShown = true
				if o.hl.Adornee ~= g then o.hl.Adornee = g end
				o.hl.FillColor = CFG.gun.color
				o.hl.OutlineColor = CFG.gun.color
				o.hl.Enabled = true
				local p = cam:WorldToViewportPoint(posOf(g))
				if p.Z > 0 then
					if CFG.gun.text then
						o.txt.Text = "Gun"
						o.txt.TextColor3 = CFG.gun.textColor
						o.txt.AnchorPoint = Vector2.new(.5, 1)
						o.txt.Position = UDim2.fromOffset(p.X, p.Y - 10)
						o.txt.Visible = true
					else
						o.txt.Visible = false
					end
					if CFG.gun.tracer then
						local org = Vector2.new(vs.X / 2, vs.Y)
						if CFG.tracer.origin == "Top" then
							org = Vector2.new(vs.X / 2, 0)
						elseif CFG.tracer.origin == "Crosshair" then
							org = Vector2.new(vs.X / 2, vs.Y / 2)
						end
						setLine(o.ln, org, Vector2.new(p.X, p.Y), CFG.gun.color, TH)
					else
						o.ln.Visible = false
					end
				else
					o.txt.Visible = false
					o.ln.Visible = false
				end
			elseif o then
				o.hl.Enabled = false
				o.txt.Visible = false
				o.ln.Visible = false
			end
		end
		for c in pairs(coins) do
			local o = coinO[c]
			if not c.Parent then
				coins[c] = nil
				if o then
					o.f:Destroy()
					coinO[c] = nil
				end
			elseif CFG.coin.on then
				local p = cam:WorldToViewportPoint(c.Position)
				if p.Z > 0 and (cam.CFrame.Position - c.Position).Magnitude < CFG.esp.maxDist then
					if not o then
						local f = new("Frame", {
							AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
						}, espGui)
						corner(f, 6)
						local s = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
						local t = new("TextLabel", {
							BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 0, -2),
							Size = UDim2.fromOffset(60, 12), Font = Enum.Font.GothamBold, TextSize = 11, Text = "Coin", TextStrokeTransparency = .35,
						}, f)
						o = { f = f, s = s, t = t }
						coinO[c] = o
					end
					anyShown = true
					o.f.Position = UDim2.fromOffset(p.X, p.Y)
					o.s.Color = CFG.coin.color
					o.t.Visible = CFG.coin.text
					o.t.TextColor3 = CFG.coin.textColor
					o.f.Visible = true
				elseif o then
					o.f.Visible = false
				end
			elseif o then
				o.f.Visible = false
			end
		end
		shownAny = anyShown
	end))

	------------------------------------------------ Игрок: speed / jump / spin / noclip / fly / autofarm
	local bv, bg
	local oldWalk, oldJump
	local farmT, farmWait, cool = nil, 0, {}
	local function cleanFly()
		if bv then bv:Destroy(); bv = nil end
		if bg then bg:Destroy(); bg = nil end
	end
	track(RunService.Heartbeat:Connect(function(dt)
		if not (CFG.walk.on or CFG.jump.on or CFG.spin.on or CFG.fly.on or CFG.farm.on or oldWalk or oldJump or bv) then return end
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then
			cleanFly()
			return
		end
		if CFG.walk.on then
			oldWalk = oldWalk or hum.WalkSpeed
			hum.WalkSpeed = CFG.walk.val
		elseif oldWalk then
			hum.WalkSpeed = oldWalk
			oldWalk = nil
		end
		if CFG.jump.on then
			oldJump = oldJump or hum.JumpPower
			hum.UseJumpPower = true
			hum.JumpPower = CFG.jump.val
		elseif oldJump then
			hum.JumpPower = oldJump
			oldJump = nil
		end
		if CFG.spin.on then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(CFG.spin.val * dt), 0) end

		-- fly / удержание на месте при автофарме
		if CFG.fly.on or CFG.farm.on then
			if not bv or bv.Parent ~= root then
				cleanFly()
				bv = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero }, root)
				bg = new("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 1e4 }, root)
			end
			local cam = Workspace.CurrentCamera
			local vel = Vector3.zero
			if CFG.fly.on and not CFG.farm.on and cam then
				local md = hum.MoveDirection
				local lv = cam.CFrame.LookVector
				if md.Magnitude > 0 then
					local flat = Vector3.new(lv.X, 0, lv.Z)
					local fwd = flat.Magnitude > 0 and md:Dot(flat.Unit) or 0
					vel = md * CFG.fly.val + Vector3.new(0, lv.Y * CFG.fly.val * math.max(fwd, 0), 0)
				end
				if hum.Jump then vel += Vector3.new(0, CFG.fly.val, 0) end
				bg.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(lv.X, 0, lv.Z))
			else
				bg.CFrame = root.CFrame
			end
			bv.Velocity = vel
		else
			cleanFly()
		end

		-- автофарм монет
		if CFG.farm.on then
			farmWait -= dt
			if farmWait <= 0 then
				if farmT and not farmT.Parent then farmT = nil end
				if not farmT then
					local best, bd, now = nil, math.huge, os.clock()
					for part in pairs(coins) do
						if part.Parent and (not cool[part] or cool[part] < now) then
							local d = (part.Position - root.Position).Magnitude
							if d < bd then best, bd = part, d end
						end
					end
					farmT = best
				end
				if farmT then
					local to = farmT.Position - root.Position
					local d = to.Magnitude
					if d < 3 then
						cool[farmT] = os.clock() + 4
						farmT = nil
						farmWait = CFG.farm.delay
					else
						root.CFrame = root.CFrame + to.Unit * math.min(d, CFG.farm.fly * dt)
					end
				end
			end
		else
			farmT = nil
		end
	end))
	track(RunService.Stepped:Connect(function()
		if CFG.noclip.on or CFG.farm.on then
			local ch = LP.Character
			if ch then
				for _, p in ipairs(ch:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			end
		end
	end))

	------------------------------------------------ Телепорты
	local function myRoot()
		local c = LP.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	function X.tpPlayer(plr)
		local r = myRoot()
		local t = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if r and t then
			r.CFrame = t.CFrame * CFrame.new(0, 0, 3)
			return true
		end
		return false
	end
	function X.tpSpawn()
		local r = myRoot()
		if not r then return false end
		local lobby = Workspace:FindFirstChild("Lobby")
		local sp = nil
		if lobby and lobby:FindFirstChild("Spawns") then sp = lobby.Spawns:FindFirstChildWhichIsA("BasePart", true) end
		sp = sp or Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if sp then
			r.CFrame = sp.CFrame * CFrame.new(0, 4, 0)
			return true
		end
		return false
	end
	local function getMap()
		for _, m in ipairs(Workspace:GetChildren()) do
			if m:IsA("Model") and m.Name ~= "Lobby" and (m:FindFirstChild("CoinContainer") or m:FindFirstChild("Spawns")) and not Players:GetPlayerFromCharacter(m) then
				return m
			end
		end
		return nil
	end
	function X.tpMap()
		local r = myRoot()
		if not r then return false end
		local m = getMap()
		if m then
			local sp = m:FindFirstChild("Spawns")
			local part = sp and sp:FindFirstChildWhichIsA("BasePart", true)
			if part then
				r.CFrame = part.CFrame * CFrame.new(0, 4, 0)
			else
				r.CFrame = CFrame.new(m:GetPivot().Position + Vector3.new(0, 15, 0))
			end
			return true
		end
		for c in pairs(coins) do
			if c.Parent then
				r.CFrame = c.CFrame * CFrame.new(0, 3, 0)
				return true
			end
		end
		return false
	end
	function X.tpRole(role)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and X.roleOf(p) == role then return X.tpPlayer(p) end
		end
		return false
	end

	-- обновление списков игроков (ники, роли, выбор)
	task.spawn(function()
		while alive do
			for _, l in ipairs(X.lists) do
				if l.frame.Parent then pcall(l.upd) end
			end
			task.wait(.8)
		end
	end)
	local function relist()
		for _, l in ipairs(X.lists) do
			if l.frame.Parent then
				pcall(l.rebuild)
				pcall(l.upd)
			end
		end
	end
	track(Players.PlayerAdded:Connect(function() task.delay(.6, relist) end))
	track(Players.PlayerRemoving:Connect(function() task.delay(.2, relist) end))

	------------------------------------------------ Конфиги (5 слотов)
	local SKIP = { pcolor = true, target = true, acolor = true }
	local function ser(v)
		if typeof(v) == "Color3" then return { __c = { v.R, v.G, v.B } } end
		if type(v) == "table" then
			local o = {}
			for k, x in pairs(v) do
				if type(k) == "string" then o[k] = ser(x) end
			end
			return o
		end
		return v
	end
	local function deser(dst, src)
		for k, v in pairs(src) do
			local cur = dst[k]
			if type(v) == "table" then
				if v.__c then
					dst[k] = Color3.new(v.__c[1], v.__c[2], v.__c[3])
				elseif type(cur) == "table" then
					deser(cur, v)
				end
			elseif cur ~= nil and type(cur) == type(v) then
				dst[k] = v
			end
		end
	end
	local slots = {}
	local function writeSlots()
		local o = {}
		for i = 1, 5 do
			if slots[i] then o[tostring(i)] = slots[i] end
		end
		pcall(function() X.fsWrite("configs.json", HttpService:JSONEncode(o)) end)
	end
	do
		local raw = X.fsRead("configs.json")
		if raw then
			local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and type(t) == "table" then
				for i = 1, 5 do
					local s = t[tostring(i)]
					if type(s) == "table" and s.name and type(s.data) == "table" then slots[i] = s end
				end
			end
		end
	end
	X.cfgApi = {
		slots = function() return slots end,
		count = function()
			local n = 0
			for i = 1, 5 do
				if slots[i] then n += 1 end
			end
			return n
		end,
		save = function(name)
			name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if name == "" then name = "config" end
			local idx
			for i = 1, 5 do
				if slots[i] and slots[i].name == name then idx = i end
			end
			if not idx then
				for i = 1, 5 do
					if not slots[i] then
						idx = i
						break
					end
				end
			end
			if not idx then return nil end
			local snapshot = {}
			for k, v in pairs(CFG) do
				if not SKIP[k] then snapshot[k] = ser(v) end
			end
			slots[idx] = { name = name, data = snapshot }
			writeSlots()
			return idx
		end,
		load = function(i)
			local s = slots[i]
			if not s then return false end
			deser(CFG, s.data)
			X.refreshAll()
			return true
		end,
		delete = function(i)
			slots[i] = nil
			writeSlots()
		end,
	}

	------------------------------------------------ Выгрузка
	X.extraUnload = function()
		pcall(restore)
		pcall(function() cc:Destroy(); bloom:Destroy(); rays:Destroy(); blur:Destroy(); weatherPart:Destroy() end)
		pcall(cleanFly)
		for p in pairs(xr) do
			if p.Parent then p.LocalTransparencyModifier = 0 end
		end
		if saved then
			pcall(function()
				LP.CameraMaxZoomDistance = saved[2]
				LP.CameraMinZoomDistance = saved[1]
				LP.CameraMode = saved[3]
			end)
		end
		if savedClock then Lighting.ClockTime = savedClock end
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then
			if oldWalk then hum.WalkSpeed = oldWalk end
			if oldJump then hum.JumpPower = oldJump end
		end
		for _, o in pairs(coinO) do pcall(function() o.f:Destroy() end) end
		for _, o in pairs(gunO) do
			for _, x in pairs(o) do pcall(function() x:Destroy() end) end
		end
	end
end

local okRun, errRun = pcall(runMM2)
if not okRun then warn("[NurHub] MM2 module error: " .. tostring(errRun)) end

----------------------------------------------------------------
-- SKIN CHANGER (visual): каталог, поиск иконок/моделей в игре, применение к Knife / Gun
-- Всё локально (видишь только ты). Если модель скина в игре не найдена — применяется цветовая тема.
----------------------------------------------------------------
do
	local DATA = {
		Gun = "Aurora|L;Amerilaser|G;America|V;Aquarium|L;Arctic|L;Bauble|G;Blaster|G;Blizzard|G;Borealis|G;Cavern|L;"
			.. "Chroma Bauble|C;Chroma Constellation|C;Chroma Darkbringer|C;Chroma Emberbow|C;Chroma Evergun|C;Chroma Laser|C;"
			.. "Chroma Lightbringer|C;Chroma Luger|C;Chroma Sands|C;Chroma Shark|C;Chroma Snowcannon|C;Chroma Swirly Gun|C;"
			.. "Chroma Traveler's Gun|C;Chroma Vampire's Gun|C;Chroma Watergun|C;Chromatic|L;Constellation|G;Cursed|L;Darkbringer|G;"
			.. "Darkshot|G;Elderwood Revolver|G;Emberbow|A;Energized|L;Evergun|G;Flora|G;Flowerwood Gun|G;Frostfade|L;Frozen|L;Ghost|L;"
			.. "Ginger|L;Ginger Luger|G;Gingerscope|A;Golden|V;Green Luger|G;Hallowgun|G;Harvester|A;Iceblaster|G;Icebeam|G;"
			.. "Icepiercer|A;Immortal|G;Jinglegun|G;Laser|V;Latte|L;Lightbringer|G;Luger|G;Lugercane|G;Nightsky|L;Ocean|G;Overseer|L;"
			.. "Palms|L;Pearlshine|G;Plasmabeam|G;Predator|L;Rainbow Gun|G;Raygun|G;Red Luger|G;Ripper|L;Sands|G;Shadow|L;Shark|G;"
			.. "Snowcannon|G;Soul|G;Spectral|L;Spectre|G;Splash|L;Sugar|G;Sunrise|G;Swirly Gun|G;Traveler|L;Traveler's Gun|G;Tree|L;"
			.. "Treat|G;Vampire|L;Vampire's Gun|G;Viper|L;Watergun|G;Xenoshot|G",
		Knife = "Gold Vampire's Edge|U;Corrupt|U;Dartbringer|U;SharkSeeker|U;Nik's Scythe|U;Traveler's Axe|A;Celestial|A;Vampire's Axe|A;"
			.. "Icebreaker|A;Swirly Axe|A;Elderwood Scythe|A;Batwing|A;Hallowscythe|A;Logchopper|A;Icewing|A;Emberscythe|A;"
			.. "Chroma Alienbeam|C;Chroma Blizzard|C;Chroma Heart Wand|C;Chroma Sunset|C;Chroma Snowstorm|C;Chroma Treat|C;Chroma Sweet|C;"
			.. "Chroma Snow Dagger|C;Chroma Ornament|C;Chroma Darkbringer|C;Chroma Lightbringer|C;Chroma Candleflame|C;"
			.. "Chroma Elderwood Blade|C;Chroma Cookiecane|C;Chroma Deathshard|C;Chroma Gingerblade|C;Chroma Fire Bunny|C;Chroma Slasher|C;"
			.. "Chroma Fang|C;Chroma Gemstone|C;Chroma Heat|C;Chroma Seer|C;Chroma Saw|C;Chroma Tides|C;Chroma Boneblade|C;"
			.. "Chroma Embersickle|C;Chroma Mortal|C;Chroma Emberscythe|C;Chroma Icecream|C;Chroma Beachy|C;Chroma Evergreen|C;"
			.. "Chroma Sunrise|C;Chroma Constellation|C;Turkey|G;Alienbeam|G;Darksword|G;Sakura|G;Spirit|G;Rainbow|G;Bloom|G;Heart Wand|G;"
			.. "Sweet|G;Flowerwood|G;Xenoknife|G;Snow Dagger|G;Waves|G;Snowstorm|G;Heartblade|G;Candy|G;Australis|G;Pearl|G;Candleflame|G;"
			.. "Elderwood Blade|G;Phantom|G;Ornament|G;Plasmablade|G;Swirly Blade|G;Iceflake|G;Eternalcane|G;Nightblade|G;Pixel|G;Slasher|G;"
			.. "Cookiecane|G;BattleAxe II|G;Gingerblade|G;Old Glory|G;Virtual|G;Gemstone|G;Vampire's Edge|G;Nebula|G;Deathshard|G;BattleAxe|G;"
			.. "Tides|G;Heat|G;Eternal IV|G;Frostsaber|G;Eternal III|G;Spider|G;Clockwork|G;Bioblade|G;Fang|G;Chill|G;Handsaw|G;Eternal|G;"
			.. "Hallow's Edge|G;Eternal II|G;Xmas|G;Hallow's Blade|G;Ice Shard|G;Ice Dragon|G;Ghostblade|G;Boneblade|G;Saw|G;Frostbite|G;"
			.. "Prismatic|G;Pumpking|G;Eggblade|G;Winter's Edge|G;Snowflake|G;Flames|G;Peppermint|G;Blue Seer|G;Seer|G;Red Seer|G;"
			.. "Cookieblade|G;Purple Seer|G;Orange Seer|G;Yellow Seer|G;Gingermint|G;Minty|G;Bat|G;Spectre|G;Lightbringer|G;Darkbringer|G;"
			.. "Mortal|G;Embersickle|G;Beachy|G;Icecream|G;Evergreen|G;Constellation|G;Sunrise|G;Sunset|G;Blizzard|G;Treat|G;"
			.. "Ghost|V;Blood|V;Prince|V;Shadow|V;Phaser|V;Cowboy|V;Splitter|V;Blue Elite|L",
	}
	local RAR = {
		U = { "Unique", Color3.fromRGB(255, 190, 60) }, A = { "Ancient", Color3.fromRGB(255, 85, 95) },
		C = { "Chroma", Color3.fromRGB(90, 230, 215) }, G = { "Godly", Color3.fromRGB(176, 88, 255) },
		V = { "Vintage", Color3.fromRGB(235, 215, 150) }, L = { "Legendary", Color3.fromRGB(255, 105, 190) },
	}
	local KW = {
		{ { "blue", "ice", "frost", "snow", "blizzard", "chill", "winter", "arctic", "frozen", "ocean", "water", "wave", "tides", "aqua", "splash", "pearl", "beachy", "borealis", "australis", "celestial" }, Color3.fromRGB(95, 190, 255) },
		{ { "red", "fire", "flame", "heat", "ember", "candle", "blood", "ripper", "vampire", "cursed", "harvester", "pumpking", "hallow", "spider" }, Color3.fromRGB(255, 80, 70) },
		{ { "green", "mint", "xeno", "bio", "viper", "alien", "tree", "evergreen", "virtual" }, Color3.fromRGB(90, 230, 130) },
		{ { "purple", "phantom", "soul", "spirit", "nebula", "spectre", "spectral", "shadow", "dark", "night", "ghost", "constellation", "immortal", "mortal" }, Color3.fromRGB(160, 110, 255) },
		{ { "gold", "sun", "glory", "america", "light", "sands", "orange", "yellow", "turkey", "corrupt" }, Color3.fromRGB(255, 200, 70) },
		{ { "candy", "sweet", "sugar", "treat", "cookie", "ginger", "heart", "sakura", "bloom", "flora", "flower", "latte", "ornament", "bauble", "xmas" }, Color3.fromRGB(255, 130, 190) },
	}
	local function norm(s) return (string.lower(tostring(s)):gsub("[^%w]", "")) end
	local function colorFor(name, rar)
		local ln = string.lower(name)
		for _, g in ipairs(KW) do
			for _, w in ipairs(g[1]) do
				if string.find(ln, w, 1, true) then return g[2] end
			end
		end
		return RAR[rar][2]
	end

	local SK = {
		cat = { Gun = {}, Knife = {} }, by = { Gun = {}, Knife = {} }, keys = {}, img = {}, imgK = { Gun = {}, Knife = {} },
		src = { Gun = {}, Knife = {} }, applied = {}, scanned = false, scanning = false, listeners = {}, RAR = RAR,
	}
	X.skin = SK
	for kind, str in pairs(DATA) do
		for item in string.gmatch(str, "[^;]+") do
			local name, r = string.match(item, "^(.-)|(%a)$")
			if name and RAR[r] then
				local ln = string.lower(name)
				local e = {
					name = name, key = norm(name), rar = r, kind = kind, col = colorFor(name, r),
					rb = (string.find(ln, "chroma", 1, true) ~= nil) or ln == "rainbow" or ln == "rainbow gun" or ln == "prismatic",
				}
				SK.cat[kind][#SK.cat[kind] + 1] = e
				SK.by[kind][name] = e
				SK.keys[e.key] = SK.keys[e.key] or {}
				SK.keys[e.key][kind] = true
			end
		end
		table.sort(SK.cat[kind], function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	end

	function SK.imageFor(e) return SK.imgK[e.kind][e.key] or SK.img[e.key] end
	function SK.hasModel(e) local s = SK.src[e.kind][e.key]; return s ~= nil and s.inst.Parent ~= nil end
	function SK.countModels(kind)
		local n = 0
		for _, e in ipairs(SK.cat[kind]) do
			if SK.hasModel(e) then n += 1 end
		end
		return n
	end

	-- ---- поиск иконок (база предметов игры) и моделей
	local function toAsset(v)
		if type(v) == "number" then return "rbxassetid://" .. v end
		if type(v) ~= "string" or v == "" then return nil end
		if string.find(v, "^rbxassetid://") or string.find(v, "^rbxasset://") or string.find(v, "^http") then return v end
		local id = string.match(v, "(%d+)$")
		if id then return "rbxassetid://" .. id end
		return nil
	end
	local function harvest(root)
		local seen, stack, n = {}, { { root, 0 } }, 0
		while #stack > 0 and n < 40000 do
			local it = table.remove(stack)
			local t, depth = it[1], it[2]
			if not seen[t] then
				seen[t] = true
				n += 1
				local nm = rawget(t, "ItemName") or rawget(t, "DisplayName")
				local im = rawget(t, "Image") or rawget(t, "Icon") or rawget(t, "Thumbnail")
				if type(nm) == "string" and im ~= nil then
					local a = toAsset(im)
					if a then
						local ty = rawget(t, "ItemType")
						local k = norm(nm)
						if ty == "Gun" or ty == "Knife" then SK.imgK[ty][k] = a else SK.img[k] = SK.img[k] or a end
					end
				end
				if depth < 5 then
					for _, v in pairs(t) do
						if type(v) == "table" and not seen[v] then stack[#stack + 1] = { v, depth + 1 } end
					end
				end
			end
		end
	end
	local function scanIcons()
		local ok, desc = pcall(function() return RepStorage:GetDescendants() end)
		if not ok then return end
		local mods = {}
		for i, d in ipairs(desc) do
			if d:IsA("ModuleScript") then
				local ln, nm = string.lower(d:GetFullName()), string.lower(d.Name)
				if string.find(ln, "database", 1, true) or string.find(ln, "inventory", 1, true) or nm == "item" or nm == "items"
					or nm == "weapons" or nm == "knives" or nm == "guns" or nm == "skins" or nm == "itemdb" then
					mods[#mods + 1] = d
					if #mods >= 40 then break end
				end
			end
			if i % 1500 == 0 then task.wait() end
		end
		for _, m in ipairs(mods) do
			task.spawn(function()
				local okr, res = pcall(require, m)
				if okr and type(res) == "table" then pcall(harvest, res) end
			end)
		end
		task.wait(3)
	end
	local function scanModels()
		local roots = { RepStorage, game:GetService("ReplicatedFirst"), game:GetService("StarterPack"), Lighting }
		local n = 0
		for _, r in ipairs(roots) do
			local ok, desc = pcall(function() return r:GetDescendants() end)
			if ok then
				for _, d in ipairs(desc) do
					n += 1
					if n % 1500 == 0 then task.wait() end
					local cls = d.ClassName
					if cls == "Tool" or cls == "Model" or cls == "MeshPart" or cls == "Folder" then
						local kinds = SK.keys[norm(d.Name)]
						if kinds then
							local pl = string.lower(d:GetFullName())
							local isK = string.find(pl, "knife", 1, true) or string.find(pl, "knives", 1, true) or string.find(pl, "blade", 1, true) or string.find(pl, "melee", 1, true)
							local isG = string.find(pl, "gun", 1, true) or string.find(pl, "revolver", 1, true) or string.find(pl, "pistol", 1, true)
							local hint = nil
							if isK and not isG then hint = "Knife" elseif isG and not isK then hint = "Gun" end
							local score = (cls == "Tool" and 2 or 0) + (d:FindFirstChild("Handle") and 1 or 0) + (hint and 2 or 0)
							local hasPart = d:IsA("BasePart") or d:FindFirstChildWhichIsA("BasePart", true) ~= nil
							if score >= 2 and hasPart then
								for kind in pairs(kinds) do
									if hint == nil or hint == kind then
										local k = norm(d.Name)
										local cur = SK.src[kind][k]
										if not cur or score > cur.score then SK.src[kind][k] = { inst = d, score = score } end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	function SK.scan()
		if SK.scanned or SK.scanning then return end
		SK.scanning = true
		task.spawn(function()
			pcall(scanIcons)
			pcall(scanModels)
			SK.scanned, SK.scanning = true, false
			for _, f in ipairs(SK.listeners) do pcall(f) end
		end)
	end

	-- ---- применение к инструменту
	local function findTools(kind)
		local out = {}
		local ch = LP.Character
		local t = ch and ch:FindFirstChild(kind)
		if t and t:IsA("Tool") then out[#out + 1] = t end
		local bp = LP:FindFirstChildOfClass("Backpack")
		t = bp and bp:FindFirstChild(kind)
		if t and t:IsA("Tool") then out[#out + 1] = t end
		return out
	end
	local function clear(tool)
		local st = SK.applied[tool]
		if not st then return end
		SK.applied[tool] = nil
		if st.folder then pcall(function() st.folder:Destroy() end) end
		if st.hl then pcall(function() st.hl:Destroy() end) end
		for p, tr in pairs(st.hid) do
			pcall(function() if p.Parent then p.Transparency = tr end end)
		end
	end
	local function weld(p0, p1, c0)
		return new("Weld", { Part0 = p0, Part1 = p1, C0 = c0, C1 = CFrame.new() }, p1)
	end
	local function attachModel(tool, handle, srcInst, st)
		local clone = srcInst:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") then d:Destroy() end
		end
		local parts = {}
		if clone:IsA("BasePart") then parts[1] = clone end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then parts[#parts + 1] = d end
		end
		if #parts == 0 then
			clone:Destroy()
			return false
		end
		local root = (clone:IsA("Tool") and clone:FindFirstChild("Handle")) or (clone:IsA("Model") and clone.PrimaryPart) or (clone:IsA("BasePart") and clone) or nil
		if not root or not root:IsA("BasePart") then root = parts[1] end
		local rels = {}
		for _, p in ipairs(parts) do rels[p] = root.CFrame:ToObjectSpace(p.CFrame) end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end
		end
		local rel = CFrame.new()
		if srcInst:IsA("Tool") then rel = tool.Grip * srcInst.Grip:Inverse() end
		local holder = new("Model", { Name = "NH_Skin" })
		if clone:IsA("BasePart") then
			clone.Parent = holder
		else
			for _, c in ipairs(clone:GetChildren()) do c.Parent = holder end
			clone:Destroy()
		end
		for _, p in ipairs(parts) do
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, false, true
			p.Name = "NH_" .. p.Name
		end
		weld(handle, root, rel)
		for _, p in ipairs(parts) do
			if p ~= root then weld(root, p, rels[p]) end
		end
		for _, p in ipairs(tool:GetDescendants()) do
			if p:IsA("BasePart") then
				st.hid[p] = p.Transparency
				p.Transparency = 1
			end
		end
		holder.Parent = tool
		st.folder, st.attached = holder, true
		return true
	end
	local function applyTheme(tool, handle, e, st)
		local hl = new("Highlight", {
			Name = "NH_SkinHL", FillColor = e.col, OutlineColor = e.col, FillTransparency = .45, OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = handle,
		}, tool)
		st.hl, st.entry = hl, e
	end
	local function applyTo(tool, kind, e)
		clear(tool)
		local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
		if not handle then return end
		local st = { name = e.name, kind = kind, hid = {}, attached = false }
		SK.applied[tool] = st
		local s = SK.src[kind][e.key]
		local ok = false
		if s and s.inst.Parent then
			local okc, res = pcall(attachModel, tool, handle, s.inst, st)
			ok = okc and res
			if not ok and st.folder then
				pcall(function() st.folder:Destroy() end)
				st.folder = nil
				for p, tr in pairs(st.hid) do pcall(function() p.Transparency = tr end) end
				st.hid = {}
			end
		end
		if not ok then applyTheme(tool, handle, e, st) end
	end
	local function maintain(tool, st)
		if st.attached then
			if not st.folder or not st.folder.Parent then
				clear(tool)
				return
			end
			for _, p in ipairs(tool:GetDescendants()) do
				if p:IsA("BasePart") and not p:IsDescendantOf(st.folder) then
					if st.hid[p] == nil then st.hid[p] = p.Transparency end
					if p.Transparency ~= 1 then p.Transparency = 1 end
				end
			end
		elseif st.hl and not st.hl.Parent then
			clear(tool)
		end
	end
	function SK.refresh()
		for _, kind in ipairs({ "Gun", "Knife" }) do
			local want = CFG.skin.on and CFG.skin[string.lower(kind)] or ""
			local e = (want ~= "") and SK.by[kind][want] or nil
			for _, tool in ipairs(findTools(kind)) do
				local st = SK.applied[tool]
				if not e then
					if st then clear(tool) end
				elseif not st or st.name ~= e.name then
					applyTo(tool, kind, e)
				else
					maintain(tool, st)
				end
			end
		end
		for tool in pairs(SK.applied) do
			if not tool.Parent then clear(tool) end
		end
	end
	function SK.select(kind, name)
		local key = string.lower(kind)
		if CFG.skin[key] == name then CFG.skin[key] = "" else CFG.skin[key] = name end
		pcall(SK.refresh)
	end
	function SK.clearAll()
		for tool in pairs(SK.applied) do clear(tool) end
	end
	task.spawn(function()
		while alive do
			pcall(SK.refresh)
			task.wait(.25)
		end
	end)
	-- Chroma / Rainbow: плавная смена цвета подсветки
	track(RunService.Heartbeat:Connect(function()
		if next(SK.applied) == nil then return end
		local hue = (os.clock() * .3) % 1
		for _, st in pairs(SK.applied) do
			if st.hl and st.entry and st.entry.rb then
				st.hl.FillColor = Color3.fromHSV(hue, .8, 1)
				st.hl.OutlineColor = Color3.fromHSV(hue, .6, 1)
			end
		end
	end))
end

----------------------------------------------------------------
-- «NurHub online»: сколько людей сейчас используют скрипт
----------------------------------------------------------------
do
	local P = { count = nil, status = "connecting" }
	X.presence = P
	local id = string.sub((string.gsub(HttpService:GenerateGUID(false), "-", "")), 1, 10)
	local base = "https://ntfy.sh/" .. ONLINE_CFG.topic
	local fb = nil
	if type(ONLINE_CFG.firebase) == "string" and ONLINE_CFG.firebase ~= "" then fb = (string.gsub(ONLINE_CFG.firebase, "/+$", "")) end
	local function useFb() return fb ~= nil and X.reqFn() ~= nil end

	local function publish(state)
		local msg = "NH1|" .. id .. "|" .. state
		local rf = X.reqFn()
		if rf then
			local ok, r = pcall(rf, { Url = base, Method = "POST", Body = msg })
			if ok and type(r) == "table" then
				local code = r.StatusCode or r.status_code or 200
				return code >= 200 and code < 300
			end
			return false
		end
		return X.httpGet(base .. "/publish?message=" .. HttpService:UrlEncode(msg)) ~= nil
	end
	local function readCount()
		local body = X.httpGet(base .. "/json?poll=1&since=" .. math.ceil(ONLINE_CFG.beat * 1.4 / 60) .. "m")
		if not body then return nil end
		local state = {}
		for line in string.gmatch(body, "[^\r\n]+") do
			local ok, o = pcall(function() return HttpService:JSONDecode(line) end)
			if ok and type(o) == "table" and o.event == "message" and type(o.message) == "string" then
				local uid, st = string.match(o.message, "^NH1|(%w+)|(%a+)$")
				if uid then state[uid] = (st == "on") end
			end
		end
		local n = 0
		for _, on in pairs(state) do
			if on then n += 1 end
		end
		if state[id] == nil then n += 1 end
		return n
	end
	local function fbBeat()
		local rf = X.reqFn()
		local ok, r = pcall(rf, {
			Url = fb .. "/nurhub_online/" .. id .. ".json", Method = "PUT",
			Headers = { ["Content-Type"] = "application/json" }, Body = '{"t":{".sv":"timestamp"}}',
		})
		if not ok or type(r) ~= "table" then return nil end
		local code = r.StatusCode or r.status_code or 200
		if code < 200 or code >= 300 then return nil end
		local ok2, j = pcall(function() return HttpService:JSONDecode(r.Body) end)
		if ok2 and type(j) == "table" and tonumber(j.t) then return tonumber(j.t) end
		return nil
	end
	local function fbCount(now)
		local body = X.httpGet(fb .. "/nurhub_online.json")
		if not body then return nil end
		local ok, j = pcall(function() return HttpService:JSONDecode(body) end)
		if not ok then return nil end
		local n, pruned = 0, 0
		if type(j) == "table" then
			for uid, v in pairs(j) do
				local t = type(v) == "table" and tonumber(v.t) or nil
				if t then
					local age = now - t
					if age <= ONLINE_CFG.beat * 1400 then
						n += 1
					elseif age > 3600000 and pruned < 3 then
						pruned += 1
						pcall(X.reqFn(), { Url = fb .. "/nurhub_online/" .. uid .. ".json", Method = "DELETE" })
					end
				end
			end
		end
		return math.max(n, 1)
	end

	function P.bye()
		pcall(function()
			if useFb() then
				X.reqFn()({ Url = fb .. "/nurhub_online/" .. id .. ".json", Method = "DELETE" })
			else
				publish("off")
			end
		end)
	end

	task.spawn(function()
		local lastBeat, fails = 0, 0
		while alive do
			local okc, n = pcall(function()
				if useFb() then
					local t = fbBeat()
					if t then return fbCount(t) end
					return nil
				end
				local now = os.clock()
				if lastBeat == 0 or now - lastBeat >= ONLINE_CFG.beat then
					if publish("on") then lastBeat = now end
				end
				return readCount()
			end)
			if okc and n then
				P.count, P.status, fails = n, "live", 0
			else
				fails += 1
				if fails >= 2 then P.status = "offline" end
			end
			task.wait(ONLINE_CFG.poll)
		end
	end)
end

----------------------------------------------------------------
-- Выгрузка скрипта
----------------------------------------------------------------
local function unload()
	alive = false
	pcall(function() if X.presence and X.presence.bye then X.presence.bye() end end)
	pcall(function() if X.skin then X.skin.clearAll() end end)
	pcall(function() RunService:UnbindFromRenderStep("NH_FOV") end)
	if fovOn then
		local cam = Workspace.CurrentCamera
		if cam then cam.FieldOfView = fovSaved or 70 end
	end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if X.extraUnload then pcall(X.extraUnload) end
	for _, d in pairs(S) do destroyData(d) end
	for _, h in pairs(hats) do pcall(function() h:Destroy() end) end
	for _, t in pairs(trails) do destroyTrail(t) end
	pcall(function() gui:Destroy() end)
	pcall(function() espGui:Destroy() end)
	ENV.NurHubMM2Unload = nil
end
ENV.NurHubMM2Unload = unload

----------------------------------------------------------------
-- Страницы меню
----------------------------------------------------------------
X.langHooks = {}
X.onLang = function()
	for _, f in ipairs(X.langHooks) do pcall(f) end
end
local function pct(v) return math.floor(v * 100 + .5) .. "%" end
-- шторка: палитра цвета + (необязательно) дополнительные элементы
local function cpick(tbl, key, extra)
	return function(d)
		X.FLabel(d, "Color")
		ColorPicker(d, tbl, key)
		if extra then extra(d) end
	end
end

------------------------------------------------ Visual
do
	local sf = createTab("Visual", "eye", "ESP & effects")
	local L, R = Columns(sf)

	local c1 = Card(L, "ESP")
	Toggle(c1, "ESP enabled", CFG.esp, "on", function(d)
		Toggle(d, "Team check", CFG.esp, "team")
		Toggle(d, "Role colors", CFG.esp, "roles")
		Slider(d, "Max distance", 100, 3000, CFG.esp, "maxDist")
	end)

	local c2 = Card(L, "Boxes")
	Toggle(c2, "Box 2D", CFG.box2d, "on", cpick(CFG.box2d, "color"))
	Toggle(c2, "Corner Box", CFG.corner, "on", cpick(CFG.corner, "color", function(d)
		Slider(d, "Corner size", 6, 60, CFG.corner, "len")
	end))
	Toggle(c2, "Box 3D", CFG.box3d, "on", cpick(CFG.box3d, "color"))
	Toggle(c2, "Fill", CFG.fill, "on", function(d)
		GradientPicker(d, CFG.fill, "c1", "c2")
		Slider(d, "Transparency", 0, 100, CFG.fill, "trans", { div = 100, fmt = pct })
	end)

	local c3 = Card(L, "Info")
	Toggle(c3, "Name", CFG.name, "on", cpick(CFG.name, "color"))
	Toggle(c3, "Avatar", CFG.avatar, "on", cpick(CFG.avatar, "color"))
	Toggle(c3, "Distance", CFG.dist, "on", cpick(CFG.dist, "color"))
	Toggle(c3, "Health bar", CFG.health, "on", cpick(CFG.health, "color"))

	local c4 = Card(R, "Body")
	Toggle(c4, "Chams", CFG.chams, "on", cpick(CFG.chams, "color", function(d)
		Slider(d, "Transparency", 0, 100, CFG.chams, "trans", { div = 100, fmt = pct })
	end))
	Toggle(c4, "Outline", CFG.outline, "on", cpick(CFG.outline, "color"))
	Toggle(c4, "Glow", CFG.glow, "on", cpick(CFG.glow, "color", function(d)
		Slider(d, "Range", 4, 60, CFG.glow, "range")
		Slider(d, "Brightness", 1, 10, CFG.glow, "bright")
	end))
	Toggle(c4, "Skeleton", CFG.skel, "on", cpick(CFG.skel, "color"))
	Toggle(c4, "Head ring", CFG.head, "on", cpick(CFG.head, "color"))

	local c5 = Card(R, "Lines")
	Toggle(c5, "Tracers", CFG.tracer, "on", cpick(CFG.tracer, "color", function(d)
		Dropdown(d, "Origin", { "Bottom", "Top", "Crosshair" }, CFG.tracer, "origin")
	end))
	Toggle(c5, "Arrows", CFG.arrows, "on", cpick(CFG.arrows, "color", function(d)
		Slider(d, "Radius", 60, 300, CFG.arrows, "radius")
		Slider(d, "Size", 8, 30, CFG.arrows, "size")
		X.FLabel(d, "Murderer color")
		ColorPicker(d, CFG.arrows, "murder")
		X.FLabel(d, "Sheriff color")
		ColorPicker(d, CFG.arrows, "sheriff")
		X.FLabel(d, "Per-player color (tap swatch)")
		X.PlayerList(d, 110, function() end, true, nil, CFG.acolor)
	end))
	Toggle(c5, "Wall check", CFG.wall, "on", function(d)
		X.FLabel(d, "Hidden color")
		ColorPicker(d, CFG.wall, "hid")
		X.FLabel(d, "Visible color")
		ColorPicker(d, CFG.wall, "vis")
	end)

	local c6 = Card(R, "Extras")
	Toggle(c6, "Custom FOV", CFG.fov, "on", function(d) Slider(d, "FOV", 30, 120, CFG.fov, "val") end)
	Toggle(c6, "Hat", CFG.hat, "on", cpick(CFG.hat, "color", function(d)
		Slider(d, "Transparency", 0, 100, CFG.hat, "trans", { div = 100, fmt = pct })
		Slider(d, "Size", 50, 200, CFG.hat, "size", { fmt = function(v) return v .. "%" end })
		Slider(d, "Lines", 6, 48, CFG.hat, "lines")
		Toggle(d, "Rainbow", CFG.hat, "rainbow")
		Toggle(d, "Shimmer", CFG.hat, "shimmer")
		Dropdown(d, "Mode", { "Lines", "Solid", "Both" }, CFG.hat, "mode")
		Dropdown(d, "Show for", { "Everyone", "Only me" }, CFG.hat, "scope")
	end))
	Toggle(c6, "Trails", CFG.trail, "on", cpick(CFG.trail, "color", function(d)
		Slider(d, "Length", 2, 50, CFG.trail, "len", { div = 10 })
		Slider(d, "Width", 2, 30, CFG.trail, "width", { div = 10 })
		Dropdown(d, "Show for", { "Everyone", "Only me" }, CFG.trail, "scope")
	end))
	Toggle(c6, "Footsteps", CFG.steps, "on", cpick(CFG.steps, "color", function(d)
		Slider(d, "Lifetime", 5, 60, CFG.steps, "life", { div = 10 })
		Slider(d, "Distance", 10, 60, CFG.steps, "dist", { div = 10 })
		Slider(d, "Delay", 0, 20, CFG.steps, "delay", { div = 20, fmt = function(v) return v .. "s" end })
		Dropdown(d, "Shape", { "Circle", "Square", "Diamond", "Foot" }, CFG.steps, "shape")
		Dropdown(d, "Show for", { "Everyone", "Only me" }, CFG.steps, "scope")
	end))
end

------------------------------------------------ Players
do
	local sf = createTab("Players", "user", "targets & colors")
	local sel = nil
	local c1 = Card(sf, "ESP target")
	Dropdown(c1, "ESP for", { "All", "Murder", "Sheriff", "Player" }, CFG.target, "mode")
	Label(c1, "Pick a player below and press «ESP only this player».")
	local c2 = Card(sf, "Players")
	X.PlayerList(c2, 190, function(plr) sel = plr end, true, function(plr)
		return sel == plr or (CFG.target.mode == "Player" and CFG.target.userId == plr.UserId)
	end)
	Label(c2, "Tap a player to select. The right swatch sets a custom ESP color (tap to cycle).")
	Button(c2, "ESP only this player", function()
		if sel then
			CFG.target.mode = "Player"
			CFG.target.userId = sel.UserId
			X.refreshAll()
		end
	end)
	Button(c2, "Teleport to player", function()
		if sel and X.tpPlayer then X.tpPlayer(sel) end
	end)
	Button(c2, "Reset player colors", function()
		for k in pairs(CFG.pcolor) do CFG.pcolor[k] = nil end
		for k in pairs(CFG.acolor) do CFG.acolor[k] = nil end
	end)
end

------------------------------------------------ World
do
	local sf = createTab("World", "globe", "shaders & light")
	local L, R = Columns(sf)

	local c1 = Card(L, "Shaders")
	Toggle(c1, "Shader preset", CFG.shader, "on")
	X.Grid(c1, X.PRESET_LIST or { "4K" }, function() return CFG.shader.preset end, function(n)
		CFG.shader.preset = n
		CFG.shader.on = true
		X.refreshAll()
	end, 2)

	local c2 = Card(L, "Light")
	Toggle(c2, "Brightness", CFG.wbright, "on", function(d)
		Slider(d, "Amount", -50, 50, CFG.wbright, "val", { div = 100 })
	end)
	Toggle(c2, "Glow (bloom)", CFG.wglow, "on", function(d)
		Slider(d, "Intensity", 0, 30, CFG.wglow, "int", { div = 10 })
		Slider(d, "Threshold", 0, 20, CFG.wglow, "thr", { div = 10 })
	end)
	Toggle(c2, "Darkness", CFG.wdark, "on", function(d)
		Slider(d, "Amount", 0, 100, CFG.wdark, "val", { div = 100, fmt = pct })
	end)
	Toggle(c2, "Color grade", CFG.wgrade, "on", function(d)
		Slider(d, "Saturation", -100, 100, CFG.wgrade, "sat", { div = 100 })
		Slider(d, "Contrast", -50, 50, CFG.wgrade, "con", { div = 100 })
	end)
	Toggle(c2, "Motion blur", CFG.wblur, "on", function(d) Slider(d, "Strength", 1, 20, CFG.wblur, "val") end)
	Toggle(c2, "Fog", CFG.wfog, "on", function(d)
		Slider(d, "Density", 0, 100, CFG.wfog, "val", { div = 100, fmt = pct })
	end)
	Toggle(c2, "Sun rays", CFG.wrays, "on", function(d)
		Slider(d, "Intensity", 0, 100, CFG.wrays, "val", { div = 100, fmt = pct })
	end)
	Toggle(c2, "Time of day", CFG.wtime, "on", function(d)
		Slider(d, "Hour", 0, 48, CFG.wtime, "val", { div = 2 })
	end)
	Toggle(c2, "Fullbright", CFG.wfull, "on")
	Toggle(c2, "No shadows", CFG.wshadow, "on")

	local c3 = Card(R, "View")
	Toggle(c3, "X-ray", CFG.xray, "on", function(d)
		Slider(d, "Transparency", 10, 95, CFG.xray, "amount", { div = 100, fmt = pct })
	end)
	Toggle(c3, "Third person", CFG.third, "on", function(d) Slider(d, "Distance", 4, 40, CFG.third, "dist") end)
	Toggle(c3, "Show FPS", CFG.fps, "on", cpick(CFG.fps, "color", function(d)
		Toggle(d, "Custom FPS value", CFG.fps, "custom")
		Slider(d, "Value", 1, 999, CFG.fps, "value")
		Slider(d, "Position X", 0, 100, CFG.fps, "x", { div = 100 })
		Slider(d, "Position Y", 0, 100, CFG.fps, "y", { div = 100 })
	end))

	local c4 = Card(R, "Items")
	Toggle(c4, "Gun ESP", CFG.gun, "on", cpick(CFG.gun, "color", function(d)
		Toggle(d, "Show text", CFG.gun, "text")
		X.FLabel(d, "Text color")
		ColorPicker(d, CFG.gun, "textColor")
		Toggle(d, "Tracer", CFG.gun, "tracer")
	end))
	Toggle(c4, "Coin ESP", CFG.coin, "on", cpick(CFG.coin, "color", function(d)
		Toggle(d, "Show text", CFG.coin, "text")
		X.FLabel(d, "Text color")
		ColorPicker(d, CFG.coin, "textColor")
	end))
end

------------------------------------------------ Misc
do
	local sf = createTab("Misc", "grid", "movement & farm")
	local L, R = Columns(sf)

	local c1 = Card(L, "Movement")
	Toggle(c1, "Walk speed", CFG.walk, "on", function(d) Slider(d, "Speed", 16, 200, CFG.walk, "val") end)
	Toggle(c1, "Jump power", CFG.jump, "on", function(d) Slider(d, "Power", 50, 300, CFG.jump, "val") end)
	Toggle(c1, "Spin", CFG.spin, "on", function(d) Slider(d, "Speed", 60, 1440, CFG.spin, "val") end)
	Toggle(c1, "Noclip", CFG.noclip, "on")
	Toggle(c1, "Fly", CFG.fly, "on", function(d) Slider(d, "Speed", 20, 200, CFG.fly, "val") end)

	local c2 = Card(R, "Farming")
	Toggle(c2, "Auto farm coins", CFG.farm, "on", function(d)
		Slider(d, "Fly speed", 20, 150, CFG.farm, "fly")
		Slider(d, "Delay", 0, 20, CFG.farm, "delay", { div = 20, fmt = function(v) return v .. "s" end })
	end)
	Label(c2, "Flies to the nearest coin and collects it automatically.")

	local c3 = Card(R, "Teleport")
	Button(c3, "To lobby", function() if X.tpSpawn then X.tpSpawn() end end)
	Button(c3, "To map", function() if X.tpMap then X.tpMap() end end)
	Button(c3, "To Murderer", function() if X.tpRole then X.tpRole("Murderer") end end)
	Button(c3, "To Sheriff", function() if X.tpRole then X.tpRole("Sheriff") end end)
	X.PlayerList(c3, 130, function(plr) if X.tpPlayer then X.tpPlayer(plr) end end)
	Label(c3, "Tap a player in the list to teleport to them.")
end

------------------------------------------------ Skins (visual skin changer)
do
	local sf = createTab("Skins", "sword", "visual changer")
	local lay = sf:FindFirstChildOfClass("UIListLayout")
	if lay then lay:Destroy() end
	sf.ScrollingEnabled = false
	sf.AutomaticCanvasSize = Enum.AutomaticSize.None
	sf.ScrollBarThickness = 0
	local SK = X.skin
	local kind = "Gun"
	local cards = { Gun = {}, Knife = {} }
	local grids, built = {}, {}
	local updSel

	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, sf)
	local seg = new("Frame", { Size = UDim2.fromOffset(150, 30), BackgroundColor3 = C.field, BorderSizePixel = 0 }, bar)
	corner(seg, 8)
	stroke(seg, C.line, 1)
	local segBtns = {}
	for i, k in ipairs({ "Gun", "Knife" }) do
		local b = new("TextButton", {
			Position = UDim2.new((i - 1) * .5, 2, 0, 2), Size = UDim2.new(.5, -4, 1, -4), BackgroundColor3 = C.accent, BackgroundTransparency = 1,
			BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.sub,
		}, seg)
		X.tl(b, k)
		corner(b, 6)
		segBtns[k] = b
	end
	local sbox, sinput = X.TextBox(bar, "Search weapons...")
	sbox.Position = UDim2.fromOffset(158, 0)
	sbox.Size = UDim2.new(1, -228, 0, 30)
	local reset = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(62, 30), BackgroundColor3 = C.drawer,
		BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE,
	}, bar)
	X.tl(reset, "Reset")
	corner(reset, 8)
	stroke(reset, C.line, 1)
	local status = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.GothamMedium,
		TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, sf)

	for _, k in ipairs({ "Gun", "Knife" }) do
		local g = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
			ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
		}, sf)
		X.acc(function() g.ScrollBarImageColor3 = C.accent end)
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, g)
		new("UIGridLayout", { CellSize = UDim2.new(.25, -9, 0, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, g)
		grids[k] = g
	end

	local function setStatus()
		local cur = CFG.skin[string.lower(kind)]
		local s = X.tr("Selected") .. ": " .. ((cur ~= "" and cur) or "-") .. "    •    "
		if SK.scanned then
			s = s .. "3D: " .. SK.countModels(kind) .. "/" .. #SK.cat[kind]
		else
			s = s .. X.tr("Scanning game data...")
		end
		status.Text = s
	end

	local function drawSil(p, e)
		local col = e.col
		local function r(x, y, w, h, rot, rad, tr)
			local f = new("Frame", {
				AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, x, .5, y), Size = UDim2.fromOffset(w, h), Rotation = rot or 0,
				BackgroundColor3 = col, BackgroundTransparency = tr or 0, BorderSizePixel = 0,
			}, p)
			corner(f, rad or 2)
		end
		if e.kind == "Gun" then
			r(6, -6, 40, 9, 0, 3); r(-16, -3, 20, 15, 0, 3); r(-14, 12, 9, 20, 14, 3); r(28, -6, 6, 5, 0, 1, .3)
		else
			r(9, -5, 40, 8, -30, 4); r(-10, 6, 5, 16, -30, 2); r(-19, 11, 16, 7, -30, 3)
		end
	end

	local function makeCard(g, e, i)
		local rc = SK.RAR[e.rar][2]
		local card = new("TextButton", { BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = i }, g)
		corner(card, 10)
		local st = stroke(card, rc, 1.5, .2)
		local sil = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -28) }, card)
		drawSil(sil, e)
		local img = new("ImageLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -28), ScaleType = Enum.ScaleType.Fit, Visible = false,
		}, card)
		new("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -3), Size = UDim2.new(1, -8, 0, 16),
			Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.text, Text = e.name, TextTruncate = Enum.TextTruncate.AtEnd,
		}, card)
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 4), Size = UDim2.fromOffset(60, 10), Font = Enum.Font.GothamBold, TextSize = 8,
			TextColor3 = rc, Text = string.upper(SK.RAR[e.rar][1]), TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		local chk = new("Frame", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false,
		}, card)
		corner(chk, 8)
		new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(6, 9), Size = UDim2.fromOffset(2, 5), Rotation = -45, BackgroundColor3 = WHITE, BorderSizePixel = 0 }, chk)
		new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(2, 9), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0 }, chk)
		cards[e.kind][#cards[e.kind] + 1] = { e = e, card = card, st = st, chk = chk, img = img, sil = sil, rc = rc, ln = string.lower(e.name) }
		card.MouseButton1Click:Connect(function()
			SK.select(e.kind, e.name)
			updSel()
		end)
	end

	updSel = function()
		for _, k in ipairs({ "Gun", "Knife" }) do
			local sel = CFG.skin[string.lower(k)]
			for _, c in ipairs(cards[k]) do
				local on = sel == c.e.name
				c.chk.Visible = on
				c.chk.BackgroundColor3 = C.accent
				c.st.Thickness = on and 2.5 or 1.5
				c.st.Color = on and WHITE or c.rc
				c.st.Transparency = on and 0 or .2
			end
		end
		setStatus()
	end
	X.acc(function() if updSel then updSel() end end)
	X.reg(function() if updSel then updSel() end end)

	local function applyFilter()
		local q = string.lower(sinput.Text)
		for _, c in ipairs(cards[kind]) do
			c.card.Visible = q == "" or string.find(c.ln, q, 1, true) ~= nil
		end
	end
	sinput:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	local function refreshImages()
		for _, k in ipairs({ "Gun", "Knife" }) do
			for _, c in ipairs(cards[k]) do
				local a = SK.imageFor(c.e)
				if a and not c.img.Visible then
					c.img.Image = a
					c.img.Visible = true
					c.sil.Visible = false
					task.delay(4, function()
						if c.img.Parent and not c.img.IsLoaded then
							c.img.Visible = false
							c.sil.Visible = true
						end
					end)
				end
			end
		end
		setStatus()
	end
	SK.listeners[#SK.listeners + 1] = refreshImages

	local function buildKind(k)
		if built[k] then return end
		built[k] = true
		task.spawn(function()
			for i, e in ipairs(SK.cat[k]) do
				if not alive then return end
				makeCard(grids[k], e, i)
				if i % 12 == 0 then task.wait() end
			end
			updSel()
			applyFilter()
			if SK.scanned then refreshImages() end
		end)
	end

	local function setKind(k)
		kind = k
		for n, b in pairs(segBtns) do
			local on = n == k
			tw(b, .2, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and WHITE or C.sub })
		end
		for n, g in pairs(grids) do g.Visible = (n == k) end
		buildKind(k)
		applyFilter()
		setStatus()
	end
	for n, b in pairs(segBtns) do b.MouseButton1Click:Connect(function() setKind(n) end) end
	reset.MouseButton1Click:Connect(function()
		CFG.skin[string.lower(kind)] = ""
		pcall(SK.refresh)
		updSel()
	end)
	X.langHooks[#X.langHooks + 1] = setStatus

	local prevTab = onTabChanged
	onTabChanged = function(name)
		if prevTab then prevTab(name) end
		if name == "Skins" then
			SK.scan()
			setKind(kind)
		end
	end
end

------------------------------------------------ Stats
do
	local sf = createTab("Stats", "bars", "live overview")
	local function upperFmt(s) return X.SET.lang == "ru" and s or string.upper(s) end

	local hero = new("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = WHITE, BorderSizePixel = 0, LayoutOrder = 1 }, sf)
	corner(hero, 14)
	local hst = stroke(hero, WHITE, 1.5, 0)
	local hg = new("UIGradient", { Rotation = 25 }, hero)
	local hsg = new("UIGradient", {}, hst)
	X.acc(function()
		hg.Color = ColorSequence.new(C.accent, C.accent2)
		hg.Transparency = NumberSequence.new(.62, .9)
		hsg.Color = ColorSequence.new(C.accent, C.accent2)
	end)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -110, 0, 30), Font = Enum.Font.GothamBlack,
		Text = "NURHUB", TextSize = 25, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
	}, hero)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -110, 0, 14), Font = Enum.Font.GothamMedium,
		Text = "Murder Mystery 2  ·  visual suite", TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, hero)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 59), Size = UDim2.new(1, -110, 0, 14), Font = Enum.Font.Gotham,
		Text = "t.me/NurHuboffical", TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, hero)
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(64, 26), BackgroundColor3 = C.bg, BackgroundTransparency = .25, BorderSizePixel = 0,
	}, hero)
	corner(pill, 13)
	stroke(pill, C.line, 1)
	new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, Text = "v" .. VERSION, TextSize = 13, TextColor3 = WHITE,
	}, pill)

	local function tile(parent, order, title, small)
		local t = new("Frame", { BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order }, parent)
		corner(t, 12)
		X.regT(t)
		local st = stroke(t, C.line, 1)
		local cap = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 12), Font = Enum.Font.GothamBold,
			TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
		}, t)
		X.tl(cap, title, upperFmt)
		local val = new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(12, small and 28 or 26), Size = UDim2.new(1, -24, 0, small and 24 or 34),
			Font = Enum.Font.GothamBlack, TextSize = small and 20 or 28, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "-",
		}, t)
		local sub
		if not small then
			sub = new("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 0, 14), Font = Enum.Font.Gotham,
				TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
			}, t)
		end
		return { f = t, st = st, val = val, sub = sub }
	end

	local row1 = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, LayoutOrder = 2 }, sf)
	new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row1)
	local tVer = tile(row1, 1, "Version")
	tVer.val.Text = VERSION
	X.tl(tVer.sub, "stable build")
	local tOn = tile(row1, 2, "Online")
	X.tl(tOn.sub, "players on server")
	local tNh = tile(row1, 3, "NurHub online")
	local nhG = new("UIGradient", {}, tNh.st)
	X.acc(function() nhG.Color = ColorSequence.new(C.accent, C.accent2) end)
	tNh.st.Thickness = 1.5
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(255, 190, 60), BorderSizePixel = 0,
	}, tNh.f)
	corner(dot, 5)
	TweenService:Create(dot, TweenInfo.new(.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = .7 }):Play()

	local row2 = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = 3 }, sf)
	new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row2)
	local tPing = tile(row2, 1, "Ping", true)
	local tFps = tile(row2, 2, "FPS", true)
	local tSes = tile(row2, 3, "Session", true)

	Button(sf, "Copy Telegram link", function(b)
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, TG_LINK)
		elseif typeof(toclipboard) == "function" then
			pcall(toclipboard, TG_LINK)
		end
		b.Text = X.tr("Copied!")
		task.delay(1.5, function()
			if b.Parent then b.Text = X.tr("Copy Telegram link") end
		end)
	end, C.accent)

	local t0 = os.clock()
	local function getPing()
		local ok, v = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
		if ok and type(v) == "number" then return math.floor(v + .5) end
		return nil
	end
	local function upd()
		tOn.val.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		local P = X.presence
		if P and P.count then tNh.val.Text = tostring(P.count) else tNh.val.Text = "..." end
		local st = P and P.status or "connecting"
		if st == "live" then
			dot.BackgroundColor3 = Color3.fromRGB(70, 230, 120)
			tNh.sub.Text = X.tr("using the script now")
		elseif st == "offline" then
			dot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			tNh.sub.Text = X.tr("offline")
		else
			dot.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
			tNh.sub.Text = X.tr("connecting...")
		end
		local pg = getPing()
		tPing.val.Text = pg and (pg .. " ms") or "-"
		tFps.val.Text = tostring(X.fpsNow or 60)
		local s = math.floor(os.clock() - t0)
		tSes.val.Text = string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
	end
	X.langHooks[#X.langHooks + 1] = upd
	task.spawn(function()
		while alive do
			if menuOpen and current == "Stats" then pcall(upd) end
			task.wait(1)
		end
	end)
	pcall(upd)
end

------------------------------------------------ Config
do
	local sf = createTab("Config", "cfg", "save & load")
	local api = X.cfgApi
	if not api then
		Label(Card(sf, "Configs"), "Config module is unavailable.")
	else
		local c1 = Card(sf, "Save current settings")
		local _, nameBox = X.TextBox(c1, "Config name")
		local msg = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "", LayoutOrder = ord(),
		}, c1)
		local c2 = Card(sf, "Slots (max 5)")
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = ord() }, c2)
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
		local rebuild
		local function mini(row, txt, xoff, col, cb)
			local b = new("TextButton", {
				AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, xoff, .5, 0), Size = UDim2.fromOffset(56, 24), BackgroundColor3 = col,
				BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, Text = X.tr(txt),
			}, row)
			corner(b, 6)
			b.MouseButton1Click:Connect(cb)
		end
		rebuild = function()
			for _, c in ipairs(holder:GetChildren()) do
				if c:IsA("Frame") then c:Destroy() end
			end
			local slots = api.slots()
			for i = 1, 5 do
				local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.field, BorderSizePixel = 0, LayoutOrder = i }, holder)
				corner(row, 8)
				stroke(row, C.line, 1)
				new("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0), Font = Enum.Font.GothamMedium,
					TextSize = 12, TextColor3 = slots[i] and C.text or C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
					Text = i .. ".  " .. (slots[i] and slots[i].name or X.tr("Empty")),
				}, row)
				if slots[i] then
					mini(row, "Load", -68, C.accent, function()
						if api.load(i) then msg.Text = X.tr("Loaded") end
					end)
					mini(row, "Delete", -8, Color3.fromRGB(190, 60, 70), function()
						api.delete(i)
						rebuild()
					end)
				end
			end
		end
		rebuild()
		X.langHooks[#X.langHooks + 1] = rebuild
		Button(c1, "Save config", function()
			local idx = api.save(nameBox.Text)
			if idx then
				msg.Text = X.tr("Saved")
				rebuild()
			else
				msg.Text = X.tr("No free slots - delete one")
			end
		end, C.accent)
	end
end

------------------------------------------------ Settings
do
	local sf = createTab("Settings", "gear", "interface")
	X.saveSoon = function() X.dirty = os.clock() end
	task.spawn(function()
		while alive do
			if X.dirty and os.clock() - X.dirty > 1 then
				X.dirty = nil
				X.saveSettings()
			end
			task.wait(.5)
		end
	end)

	local c1 = Card(sf, "Language")
	X.Grid(c1, { "English", "Русский" }, function() return X.SET.lang == "ru" and "Русский" or "English" end, function(n)
		X.SET.lang = (n == "Русский") and "ru" or "en"
		X.applyLang()
		X.saveSettings()
	end, 2)

	local c2 = Card(sf, "Interface")
	Slider(c2, "UI scale", 50, 130, X.SET, "scale", { div = 100, fmt = pct, onChange = fit, onEnd = X.saveSettings })
	Slider(c2, "Menu transparency", 0, 60, X.SET, "trans", { div = 100, fmt = pct, onChange = X.applyTrans, onEnd = X.saveSettings })

	local c3 = Card(sf, "Accent color")
	local proxy = setmetatable({}, {
		__index = function() return X.SET.accent end,
		__newindex = function(_t, _k, v)
			X.setAccent(v, true)
			X.saveSoon()
		end,
	})
	ColorPicker(c3, proxy, "accent")

	local c4 = Card(sf, "Skin changer")
	Toggle(c4, "Skin changer enabled", CFG.skin, "on")

	local c5 = Card(sf, "Controls")
	Label(c5, "Open / close the menu: RightShift or the NH button.")
	Button(c5, "Unload script", unload, Color3.fromRGB(190, 60, 70))
end

----------------------------------------------------------------
-- Глобальный поиск по функциям
----------------------------------------------------------------
do
	local wrap = new("Frame", {
		Position = UDim2.new(1, -150, 0, 14), Size = UDim2.fromOffset(136, 24), BackgroundColor3 = C.field, BorderSizePixel = 0, ZIndex = 5,
	}, Main)
	corner(wrap, 8)
	stroke(wrap, C.line, 1)
	local box = new("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = C.text, PlaceholderColor3 = C.sub, PlaceholderText = "Search...", Text = "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, wrap)
	local res = new("Frame", {
		Position = UDim2.new(1, -214, 0, 42), Size = UDim2.fromOffset(200, 0), BackgroundColor3 = C.card, BorderSizePixel = 0, Visible = false, ZIndex = 20,
	}, Main)
	corner(res, 8)
	stroke(res, C.line, 1)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, res)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, res)

	local function jump(e)
		switchTab(e.tab)
		task.delay(.35, function()
			local sfp = X.pageSF[e.tab]
			if sfp and e.box.Parent then
				local k = math.max(Main.AbsoluteSize.X / MAIN_W, .1)
				local y = (e.box.AbsolutePosition.Y - sfp.AbsolutePosition.Y) / k + sfp.CanvasPosition.Y
				sfp.CanvasPosition = Vector2.new(0, math.max(0, y - 6))
			end
		end)
	end
	local function refreshResults()
		for _, c in ipairs(res:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		local q = string.lower(box.Text)
		if q == "" then
			res.Visible = false
			return
		end
		local n = 0
		for _, e in ipairs(X.searchReg) do
			if string.find(string.lower(e.name), q, 1, true) or string.find(string.lower(X.tr(e.name)), q, 1, true) then
				n += 1
				if n > 8 then break end
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.accent, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
					Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
					Text = " " .. X.tr(e.name) .. "  ·  " .. X.tr(e.tab), LayoutOrder = n, ZIndex = 21,
				}, res)
				corner(b, 5)
				b.MouseEnter:Connect(function() tw(b, .1, { BackgroundTransparency = .75 }) end)
				b.MouseLeave:Connect(function() tw(b, .1, { BackgroundTransparency = 1 }) end)
				b.MouseButton1Click:Connect(function()
					box.Text = ""
					jump(e)
				end)
			end
		end
		res.Size = UDim2.fromOffset(200, math.min(n, 8) * 26 + 8)
		res.Visible = n > 0
	end
	box:GetPropertyChangedSignal("Text"):Connect(refreshResults)
end

----------------------------------------------------------------
-- Кнопка NH + горячая клавиша
----------------------------------------------------------------
do
	local nh = new("TextButton", {
		Name = "NH", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, 36, .5, 0), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.bg,
		AutoButtonColor = false, Font = Enum.Font.GothamBlack, Text = "NH", TextSize = 15, TextColor3 = WHITE, ZIndex = 50,
	}, gui)
	corner(nh, 22)
	local nst = stroke(nh, C.accent, 2)
	X.acc(function() nst.Color = C.accent end)
	makeDraggable(nh, nh, function() setMenu(not menuOpen) end)
	track(UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Enum.KeyCode.RightShift then setMenu(not menuOpen) end
	end))
end

----------------------------------------------------------------
-- Русский перевод
----------------------------------------------------------------
X.DICT = {
	["Visual"] = "Визуал", ["Players"] = "Игроки", ["World"] = "Мир", ["Misc"] = "Прочее", ["Skins"] = "Скины", ["Stats"] = "Статистика",
	["Config"] = "Конфиги", ["Settings"] = "Настройки",
	["ESP & effects"] = "ESP и эффекты", ["targets & colors"] = "цели и цвета", ["shaders & light"] = "шейдеры и свет",
	["movement & farm"] = "движение и фарм", ["visual changer"] = "визуальный скинченджер", ["live overview"] = "онлайн-обзор",
	["save & load"] = "сохранение", ["interface"] = "интерфейс",
	["ESP"] = "ESP", ["Boxes"] = "Боксы", ["Info"] = "Информация", ["Body"] = "Тело", ["Lines"] = "Линии", ["Extras"] = "Дополнительно",
	["ESP target"] = "Цель ESP", ["Shaders"] = "Шейдеры", ["Light"] = "Свет", ["View"] = "Обзор", ["Items"] = "Предметы",
	["Movement"] = "Движение", ["Farming"] = "Фарм", ["Teleport"] = "Телепорт", ["Language"] = "Язык", ["Interface"] = "Интерфейс",
	["Accent color"] = "Цвет акцента", ["Skin changer"] = "Скинченджер", ["Controls"] = "Управление",
	["Save current settings"] = "Сохранить текущие настройки", ["Slots (max 5)"] = "Слоты (макс. 5)", ["Configs"] = "Конфиги",
	["ESP enabled"] = "ESP включён", ["Team check"] = "Проверка команды", ["Role colors"] = "Цвета ролей", ["Max distance"] = "Макс. дистанция",
	["Box 2D"] = "Бокс 2D", ["Corner Box"] = "Угловой бокс", ["Box 3D"] = "Бокс 3D", ["Fill"] = "Заливка", ["Name"] = "Ник", ["Avatar"] = "Аватар",
	["Distance"] = "Дистанция", ["Health bar"] = "Здоровье", ["Chams"] = "Chams", ["Outline"] = "Обводка", ["Glow"] = "Свечение",
	["Skeleton"] = "Скелет", ["Head ring"] = "Кольцо головы", ["Tracers"] = "Трейсеры", ["Arrows"] = "Стрелки", ["Wall check"] = "Проверка стен",
	["Custom FOV"] = "Свой FOV", ["Hat"] = "Шляпа", ["Trails"] = "Трейлы", ["Footsteps"] = "Следы",
	["Shader preset"] = "Шейдер", ["Brightness"] = "Яркость", ["Glow (bloom)"] = "Свечение (bloom)", ["Darkness"] = "Затемнение",
	["Color grade"] = "Цветокоррекция", ["Motion blur"] = "Размытие движения", ["Fog"] = "Туман", ["Sun rays"] = "Лучи солнца",
	["Time of day"] = "Время суток", ["Fullbright"] = "Полная яркость", ["No shadows"] = "Без теней", ["X-ray"] = "Рентген",
	["Third person"] = "Вид от 3-го лица", ["Show FPS"] = "Показать FPS", ["Custom FPS value"] = "Свой FPS", ["Gun ESP"] = "ESP пушки",
	["Coin ESP"] = "ESP монет", ["Show text"] = "Показывать текст", ["Tracer"] = "Трейсер", ["Walk speed"] = "Скорость ходьбы",
	["Jump power"] = "Сила прыжка", ["Spin"] = "Вращение", ["Noclip"] = "Noclip", ["Fly"] = "Полёт", ["Auto farm coins"] = "Автофарм монет",
	["Skin changer enabled"] = "Скинченджер включён", ["Rainbow"] = "Радуга", ["Shimmer"] = "Переливание",
	["Corner size"] = "Размер уголков", ["Transparency"] = "Прозрачность", ["Range"] = "Радиус", ["Radius"] = "Радиус", ["Size"] = "Размер",
	["FOV"] = "FOV", ["Lines"] = "Линии", ["Length"] = "Длина", ["Width"] = "Ширина", ["Lifetime"] = "Время жизни", ["Delay"] = "Задержка",
	["Amount"] = "Количество", ["Intensity"] = "Интенсивность", ["Threshold"] = "Порог", ["Saturation"] = "Насыщенность",
	["Contrast"] = "Контраст", ["Strength"] = "Сила", ["Density"] = "Плотность", ["Hour"] = "Час", ["Value"] = "Значение",
	["Position X"] = "Позиция X", ["Position Y"] = "Позиция Y", ["Speed"] = "Скорость", ["Power"] = "Сила", ["Fly speed"] = "Скорость полёта",
	["UI scale"] = "Масштаб меню", ["Menu transparency"] = "Прозрачность меню", ["Origin"] = "Начало", ["Mode"] = "Режим",
	["Show for"] = "Показывать для", ["Shape"] = "Форма", ["ESP for"] = "ESP для",
	["Color"] = "Цвет", ["Top color"] = "Верхний цвет", ["Bottom color"] = "Нижний цвет", ["Murderer color"] = "Цвет убийцы",
	["Sheriff color"] = "Цвет шерифа", ["Per-player color (tap swatch)"] = "Цвет для игрока (нажми на кружок)",
	["Hidden color"] = "Цвет за стеной", ["Visible color"] = "Цвет в видимости", ["Text color"] = "Цвет текста", ["Hue"] = "Оттенок",
	["ESP only this player"] = "ESP только на этого игрока", ["Teleport to player"] = "Телепорт к игроку", ["Reset player colors"] = "Сбросить цвета игроков",
	["To lobby"] = "В лобби", ["To map"] = "На карту", ["To Murderer"] = "К убийце", ["To Sheriff"] = "К шерифу", ["Save config"] = "Сохранить конфиг",
	["Copy Telegram link"] = "Копировать ссылку Telegram", ["Unload script"] = "Выгрузить скрипт", ["Reset"] = "Сброс", ["Copied!"] = "Скопировано!",
	["Pick a player below and press «ESP only this player»."] = "Выбери игрока ниже и нажми «ESP только на этого игрока».",
	["Tap a player to select. The right swatch sets a custom ESP color (tap to cycle)."] = "Нажми на игрока, чтобы выбрать. Кружок справа задаёт свой цвет ESP (нажимай для смены).",
	["Flies to the nearest coin and collects it automatically."] = "Летит к ближайшей монете и собирает её автоматически.",
	["Tap a player in the list to teleport to them."] = "Нажми на игрока в списке, чтобы телепортироваться к нему.",
	["Open / close the menu: RightShift or the NH button."] = "Открыть / закрыть меню: RightShift или кнопка NH.",
	["Config module is unavailable."] = "Модуль конфигов недоступен.", ["live preview of your settings"] = "предпросмотр настроек",
	["Version"] = "Версия", ["Online"] = "Онлайн", ["NurHub online"] = "NurHub онлайн", ["Ping"] = "Пинг", ["FPS"] = "FPS", ["Session"] = "Сессия",
	["stable build"] = "стабильная сборка", ["players on server"] = "игроков на сервере", ["using the script now"] = "пользуются скриптом сейчас",
	["connecting..."] = "подключение...", ["offline"] = "нет связи", ["Gun"] = "Пушка", ["Knife"] = "Нож", ["Selected"] = "Выбрано",
	["Scanning game data..."] = "Сканирую данные игры...", ["Empty"] = "Пусто", ["Saved"] = "Сохранено", ["Loaded"] = "Загружено",
	["No free slots - delete one"] = "Нет свободных слотов - удали один", ["Load"] = "Загр.", ["Delete"] = "Удал.",
	["Search weapons..."] = "Поиск оружия...",
}
X.applyLang()
X.applyTrans()

----------------------------------------------------------------
-- Старт
----------------------------------------------------------------
current = "Visual"
pages["Visual"].Visible = true
pages["Visual"].GroupTransparency = 0
for n in pairs(tabs) do paintTab(n, n == "Visual", false) end
setMenu(true)
