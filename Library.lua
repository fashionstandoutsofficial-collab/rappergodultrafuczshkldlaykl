if getgenv().Library and type(getgenv().Library) == "table" and getgenv().Library.Unload then
	pcall(function()
		getgenv().Library:Unload()
	end)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local localPlayerStart = os.clock()
while not LocalPlayer and os.clock() - localPlayerStart < 5 do
	task.wait()
	LocalPlayer = Players.LocalPlayer
end

if not LocalPlayer then
	warn("junt_ui could not find LocalPlayer; run this on the client")
	return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local PlaceDisplayName = game.Name
do
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
		PlaceDisplayName = info.Name
	end
end

local Library = {
	Flags = {},
	Items = {},
	Keybinds = {},
	Connections = {},
	ThemeObjects = {},
	Open = true,
	MenuKey = Enum.KeyCode.Insert,
	MenuKeybind = tostring(Enum.KeyCode.Insert),
	ConfigFolder = "junt_ui/configs",

	Registry = {},
	RegistryMap = {},
	HudRegistry = {},
	OpenedFrames = {},
	DependencyBoxes = {},
	Signals = {},
	NotifyOnError = true,
	Font = Enum.Font.Code,
	Black = Color3.new(0, 0, 0),
	RiskColor = Color3.fromRGB(255, 50, 50),

	Theme = {
		Bg = Color3.fromRGB(7, 7, 9),
		Bg2 = Color3.fromRGB(10, 10, 13),
		Bg3 = Color3.fromRGB(18, 18, 21),
		Bg4 = Color3.fromRGB(24, 24, 28),
		ControlTop = Color3.fromRGB(39, 36, 38),
		ControlBottom = Color3.fromRGB(12, 10, 12),
		Outline = Color3.fromRGB(38, 30, 34),
		Outline2 = Color3.fromRGB(28, 20, 24),
		Text = Color3.fromRGB(232, 210, 218),
		Dim = Color3.fromRGB(190, 164, 174),
		Faint = Color3.fromRGB(136, 110, 120),
		Accent = Color3.fromRGB(211, 170, 182),
		TabInactive = Color3.fromRGB(135, 125, 135),
		TabInactiveHover = Color3.fromRGB(165, 150, 165)
	}
}

Library.FontColor = Library.Theme.Text
Library.MainColor = Library.Theme.Bg3
Library.BackgroundColor = Library.Theme.Bg
Library.AccentColor = Library.Theme.Accent
Library.OutlineColor = Library.Theme.Outline
Library.AccentColorDark = Color3.fromRGB(150, 105, 120)


getgenv().Toggles = getgenv().Toggles or {}
getgenv().Options = getgenv().Options or {}
Toggles = getgenv().Toggles
Options = getgenv().Options

local function SyncLinoriaColors()
	Library.FontColor = Library.Theme.Text
	Library.MainColor = Library.Theme.Bg3
	Library.BackgroundColor = Library.Theme.Bg
	Library.AccentColor = Library.Theme.Accent
	Library.OutlineColor = Library.Theme.Outline
	local h, s, v = Color3.toHSV(Library.AccentColor)
	Library.AccentColorDark = Color3.fromHSV(h, s, math.max(v / 1.5, 0))
end

function Library:GetDarkerColor(color)
	local h, s, v = Color3.toHSV(color)
	return Color3.fromHSV(h, s, math.max(v / 1.5, 0))
end

function Library:AddToRegistry(instance, properties, isHud)
	local object = instance.Instance or instance
	local data = {Instance = object, Properties = properties or {}, Idx = #self.Registry + 1}
	table.insert(self.Registry, data)
	self.RegistryMap[object] = data
	if isHud then
		table.insert(self.HudRegistry, data)
	end
	for prop, key in pairs(data.Properties) do
		pcall(function()
			object[prop] = type(key) == "function" and key() or self[key] or key
		end)
	end
	return data
end

function Library:RemoveFromRegistry(instance)
	local object = instance.Instance or instance
	local data = self.RegistryMap[object]
	if not data then return end
	for i = #self.Registry, 1, -1 do
		if self.Registry[i] == data then
			table.remove(self.Registry, i)
		end
	end
	for i = #self.HudRegistry, 1, -1 do
		if self.HudRegistry[i] == data then
			table.remove(self.HudRegistry, i)
		end
	end
	self.RegistryMap[object] = nil
end

function Library:UpdateColorsUsingRegistry()
	SyncLinoriaColors()
	for _, data in ipairs(self.Registry) do
		local object = data.Instance
		if object and object.Parent then
			for prop, key in pairs(data.Properties) do
				pcall(function()
					object[prop] = type(key) == "function" and key() or self[key] or key
				end)
			end
		end
	end
end

function Library:GiveSignal(signal)
	table.insert(self.Signals, signal)
	return signal
end

function Library:SafeCallback(callback, ...)
	if not callback then return end
	if not self.NotifyOnError then
		return callback(...)
	end
	local ok, result = pcall(callback, ...)
	if not ok then
		warn(result)
		if self.Notify then
			pcall(function() self:Notify(tostring(result), 3) end)
		end
	end
	return ok, result
end

local function AddConnection(signal, callback)
	local c = signal:Connect(callback)
	table.insert(Library.Connections, c)
	table.insert(Library.Signals, c)
	return c
end

local function New(class, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	return obj
end

local function Tween(obj, props, time)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

function Library:Notify(data, duration)
	local title = "notification"
	local message = ""
	local time = duration or 3
	if typeof(data) == "table" then
		title = tostring(data.Title or data.title or data.Name or data.name or title)
		message = tostring(data.Text or data.text or data.Message or data.message or "")
		time = tonumber(data.Duration or data.duration or data.Time or data.time) or time
	else
		message = tostring(data or "")
	end

	if not self.NotificationGui or not self.NotificationGui.Parent then
		local notifyGui = New("ScreenGui", {
			Name = "junt_notifications",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			DisplayOrder = 1000,
			Parent = PlayerGui
		})
		local holder = New("Frame", {
			Parent = notifyGui,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(210, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y
		})
		New("UIListLayout", {
			Parent = holder,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right
		})
		self.NotificationGui = notifyGui
		self.NotificationHolder = holder
	end

	local notification = New("Frame", {
		Parent = self.NotificationHolder,
		Size = UDim2.fromOffset(210, 46),
		BackgroundColor3 = self.Theme.Bg2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true
	})
	New("UIStroke", {Parent = notification, Color = self.Theme.Outline, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})

	local inner = New("Frame", {
		Parent = notification,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundColor3 = self.Theme.Bg,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	New("UIStroke", {Parent = inner, Color = self.Theme.Outline2, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})

	local line = New("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, 2),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0
	})
	New("UIGradient", {
		Parent = line,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, self.Theme.Accent),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 248, 250)),
			ColorSequenceKeypoint.new(1, self.Theme.Accent)
		})
	})

	local titleLabel = New("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 13),
		Text = string.lower(title),
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	local messageLabel = New("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 19),
		Size = UDim2.new(1, -16, 0, 13),
		Text = string.lower(message),
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd
	})

	local scale = New("UIScale", {Parent = notification, Scale = 0.96})
	Tween(notification, {BackgroundTransparency = 0}, 0.12)
	Tween(inner, {BackgroundTransparency = 0}, 0.12)
	Tween(scale, {Scale = 1}, 0.12)

	local closed = false
	local function close()
		if closed then return end
		closed = true
		Tween(scale, {Scale = 0.96}, 0.12)
		Tween(notification, {BackgroundTransparency = 1}, 0.12)
		Tween(inner, {BackgroundTransparency = 1}, 0.12)
		task.delay(0.13, function()
			if notification and notification.Parent then
				notification:Destroy()
			end
		end)
	end

	task.delay(time, close)
	return {Close = close, Instance = notification}
end

Library.Notification = Library.Notify
Library.CreateNotification = Library.Notify

local function EnsureScale(obj, defaultScale)
	local scale = obj:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = New("UIScale", {Parent = obj, Scale = defaultScale or 1})
	elseif defaultScale and scale.Scale == 0 then
		scale.Scale = defaultScale
	end
	return scale
end

local function AnimateButton(button, idleColor, hoverColor)
	local scale = EnsureScale(button, 1)
	button.MouseEnter:Connect(function()
		Tween(scale, {Scale = 1.015}, 0.09)
		if hoverColor then
			Tween(button, {BackgroundColor3 = hoverColor}, 0.09)
		end
	end)
	button.MouseLeave:Connect(function()
		Tween(scale, {Scale = 1}, 0.09)
		if idleColor then
			Tween(button, {BackgroundColor3 = idleColor}, 0.09)
		end
	end)
	button.MouseButton1Down:Connect(function()
		Tween(scale, {Scale = 0.985}, 0.05)
	end)
	button.MouseButton1Up:Connect(function()
		Tween(scale, {Scale = 1.01}, 0.07)
		task.delay(0.07, function()
			if scale.Parent then
				Tween(scale, {Scale = 1}, 0.07)
			end
		end)
	end)
	return scale
end

local function AddSoftGlow(parent, accent)
	local glowOuter = New("Frame", {
		Parent = parent,
		Name = "GlowOuter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 18, 1, 18),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 0
	})
	local glowInner = New("Frame", {
		Parent = parent,
		Name = "GlowInner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 0
	})
	New("UICorner", {Parent = glowOuter, CornerRadius = UDim.new(0, 2)})
	New("UICorner", {Parent = glowInner, CornerRadius = UDim.new(0, 2)})
	return glowOuter, glowInner
end

local function AddReflection(parent, zi)
	local reflect = New("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0.55, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = (zi or 2) + 1,
		ClipsDescendants = false
	})
	New("UIGradient", {
		Parent = reflect,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   0.80),
			NumberSequenceKeypoint.new(0.5, 0.93),
			NumberSequenceKeypoint.new(1,   1.00)
		})
	})
	return reflect
end

local function BindTheme(obj, prop, themeKey)
	Library.ThemeObjects[themeKey] = Library.ThemeObjects[themeKey] or {}
	table.insert(Library.ThemeObjects[themeKey], {Object = obj, Property = prop})
end

local function BindThemeUpdater(themeKeys, updater)
	for _, themeKey in ipairs(themeKeys) do
		Library.ThemeObjects[themeKey] = Library.ThemeObjects[themeKey] or {}
		table.insert(Library.ThemeObjects[themeKey], {Updater = updater})
	end
end

local function ApplyTheme(themeKey, value)
	Library.Theme[themeKey] = value
	SyncLinoriaColors()
	local refs = Library.ThemeObjects[themeKey]
	if refs then
		for _, ref in ipairs(refs) do
			pcall(function()
				if ref.Updater then
					ref.Updater()
				elseif ref.Object and ref.Object.Parent then
					ref.Object[ref.Property] = value
				end
			end)
		end
	end
	Library:UpdateColorsUsingRegistry()
end

function Library:SetTheme(themeKey, value)
	local map = {
		FontColor = "Text",
		MainColor = "Bg3",
		BackgroundColor = "Bg",
		AccentColor = "Accent",
		OutlineColor = "Outline",
	}
	themeKey = map[themeKey] or themeKey
	if self.Theme[themeKey] ~= nil then
		ApplyTheme(themeKey, value)
	else
		self[themeKey] = value
		self:UpdateColorsUsingRegistry()
	end
end

function Library:ChangeColor(themeKey, value)
	return self:SetTheme(themeKey, value)
end

function Library:Unload()
	for _, connection in ipairs(self.Connections) do
		pcall(function() connection:Disconnect() end)
	end
	for _, signal in ipairs(self.Signals) do
		pcall(function() signal:Disconnect() end)
	end
	if self.OnUnloadCallback then
		pcall(self.OnUnloadCallback)
	end
	if self.Gui then
		pcall(function() self.Gui:Destroy() end)
	end
	if self.NotificationGui then
		pcall(function() self.NotificationGui:Destroy() end)
	end
	getgenv().junt_ui = nil
	getgenv().Library = nil
end

local function SerializeConfigValue(value)
	local valueType = typeof(value)
	if valueType == "Color3" then
		return {__type = "Color3", R = value.R, G = value.G, B = value.B}
	elseif valueType == "EnumItem" then
		return {__type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name}
	elseif type(value) == "table" then
		local copy = {}
		for k, v in pairs(value) do
			copy[k] = SerializeConfigValue(v)
		end
		return copy
	else
		return value
	end
end

local function DeserializeConfigValue(value)
	if type(value) ~= "table" then
		return value
	end
	if value.__type == "Color3" then
		return Color3.new(tonumber(value.R) or 1, tonumber(value.G) or 1, tonumber(value.B) or 1)
	elseif value.__type == "EnumItem" and value.EnumType == "Enum.KeyCode" and value.Name then
		return Enum.KeyCode[value.Name]
	end
	local copy = {}
	for k, v in pairs(value) do
		if k ~= "__type" then
			copy[k] = DeserializeConfigValue(v)
		end
	end
	return copy
end

function Library:GetConfig()
	local flags = {}
	for flag, value in pairs(self.Flags) do
		flags[flag] = SerializeConfigValue(value)
	end
	for flag, value in pairs(getgenv().Toggles or {}) do
		if type(value) == "table" and value.Get then
			pcall(function() flags[flag] = SerializeConfigValue(value:Get()) end)
		end
	end
	for flag, value in pairs(getgenv().Options or {}) do
		if type(value) == "table" and value.Get then
			pcall(function() flags[flag] = SerializeConfigValue(value:Get()) end)
		end
	end
	return HttpService:JSONEncode(flags)
end

function Library:LoadConfigFromString(config)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(config)
	end)
	if not ok or type(decoded) ~= "table" then
		return false, "bad config"
	end
	for flag, savedValue in pairs(decoded.Flags or decoded) do
		local value = DeserializeConfigValue(savedValue)
		self.Flags[flag] = value
		local item = self.Items[flag] or (getgenv().Toggles or {})[flag] or (getgenv().Options or {})[flag]
		if type(item) == "table" then
			pcall(function()
				if item.SetValue then item:SetValue(value) elseif item.Set then item:Set(value) end
			end)
		end
	end
	return true
end

function Library:SanitizeConfigName(name)
	name = tostring(name or "default"):lower():gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
	if name == "" then
		name = "default"
	end
	return name
end

function Library:EnsureConfigFolder()
	if not writefile or not readfile then
		return false, "file api missing"
	end
	if makefolder then
		pcall(function()
			if not isfolder or not isfolder("junt_ui") then
				makefolder("junt_ui")
			end
		end)
		pcall(function()
			if not isfolder or not isfolder(self.ConfigFolder) then
				makefolder(self.ConfigFolder)
			end
		end)
	end
	return true
end

function Library:GetConfigPath(name)
	return self.ConfigFolder .. "/" .. self:SanitizeConfigName(name) .. ".json"
end

function Library:ListConfigs()
	local ok = self:EnsureConfigFolder()
	if not ok or not listfiles then
		return {}
	end
	local configs = {}
	local success, files = pcall(listfiles, self.ConfigFolder)
	if success and type(files) == "table" then
		for _, file in ipairs(files) do
			local configName = tostring(file):match("([^/\\]+)%.json$")
			if configName then
				table.insert(configs, configName)
			end
		end
	end
	table.sort(configs)
	return configs
end

function Library:SaveConfig(name)
	local ok, reason = self:EnsureConfigFolder()
	if not ok then
		return false, reason
	end

	local flags = {}
	for flag, value in pairs(self.Flags) do
		flags[flag] = SerializeConfigValue(value)
	end

	local theme = {}
	for themeKey, value in pairs(self.Theme) do
		if typeof(value) == "Color3" then
			theme[themeKey] = SerializeConfigValue(value)
		end
	end

	local keybinds = {}
	for flag, bind in pairs(self.Keybinds) do
		keybinds[flag] = {
			Key = bind.Key and bind.Key.Name or nil,
			Mode = bind.Mode,
			State = bind.State and true or false
		}
	end

	local data = {
		Flags = flags,
		Theme = theme,
		Keybinds = keybinds
	}

	local encoded = HttpService:JSONEncode(data)
	local success, err = pcall(function()
		writefile(self:GetConfigPath(name), encoded)
	end)
	return success, success and "saved" or tostring(err)
end

function Library:LoadConfig(name)
	local ok, reason = self:EnsureConfigFolder()
	if not ok then
		return false, reason
	end
	local path = self:GetConfigPath(name)
	if isfile and not isfile(path) then
		return false, "config not found"
	end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not success or type(decoded) ~= "table" then
		return false, "bad config"
	end

	if type(decoded.Theme) == "table" then
		for themeKey, savedValue in pairs(decoded.Theme) do
			local value = DeserializeConfigValue(savedValue)
			if typeof(value) == "Color3" and self.Theme[themeKey] ~= nil then
				ApplyTheme(themeKey, value)
			end
		end
	end

	if type(decoded.Flags) == "table" then
		for flag, savedValue in pairs(decoded.Flags) do
			local value = DeserializeConfigValue(savedValue)
			self.Flags[flag] = value
			local item = self.Items[flag]
			if item and item.Set then
				pcall(function()
					item:Set(value)
				end)
			end
		end
	end

	if type(decoded.Keybinds) == "table" then
		for flag, savedBind in pairs(decoded.Keybinds) do
			local bind = self.Keybinds[flag]
			if bind then
				if savedBind.Mode then
					bind.Mode = savedBind.Mode
				end
				bind.State = savedBind.State and true or false
				if savedBind.Key and Enum.KeyCode[savedBind.Key] then
					local item = self.Items[flag]
					if item and item.Set then
						pcall(function()
							item:Set(Enum.KeyCode[savedBind.Key])
						end)
					else
						bind.Key = Enum.KeyCode[savedBind.Key]
					end
				end
			end
		end
	end

	self:RefreshKeybinds()
	return true, "loaded"
end

function Library:DeleteConfig(name)
	local ok, reason = self:EnsureConfigFolder()
	if not ok then
		return false, reason
	end
	local path = self:GetConfigPath(name)
	local deleteFunc = delfile or deletefile
	if not deleteFunc then
		return false, "delete api missing"
	end
	if isfile and not isfile(path) then
		return false, "config not found"
	end
	local success, err = pcall(deleteFunc, path)
	return success, success and "deleted" or tostring(err)
end

local function Stroke(parent, color, thickness, bindKey)
	local stroke = New("UIStroke", {
		Parent = parent,
		Color = color or Library.Theme.Outline,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	})
	if bindKey then
		BindTheme(stroke, "Color", bindKey)
	end
	return stroke
end

local function ApplyControlGradient(target)
	target.BackgroundColor3 = Library.Theme.ControlTop
	local gradient = target:FindFirstChild("ControlGradient")
	if not gradient then
		gradient = New("UIGradient", {
			Name = "ControlGradient",
			Parent = target,
			Rotation = 90
		})
	end
	local function updateGradient()
		if gradient and gradient.Parent then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Library.Theme.ControlTop),
				ColorSequenceKeypoint.new(1, Library.Theme.ControlBottom)
			})
		end
	end
	BindTheme(target, "BackgroundColor3", "ControlTop")
	BindThemeUpdater({"ControlTop", "ControlBottom"}, updateGradient)
	updateGradient()
	return gradient
end

local function MakeDraggable(frame, drag)
	local dragging = false
	local startMouse
	local startPos
	drag.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			startMouse = input.Position
			startPos = frame.Position
		end
	end)
	AddConnection(UIS.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	AddConnection(UIS.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - startMouse
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function Hex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function ColorFromHex(hex)
	hex = tostring(hex or ""):gsub("#", "")
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local function KeyFromValue(value)
	if typeof(value) == "EnumItem" then
		return value
	end
	local keyName = tostring(value or "")
	keyName = keyName:gsub("Enum.KeyCode.", ""):gsub("KeyCode.", "")
	keyName = keyName:gsub("Enum.UserInputType.", ""):gsub("UserInputType.", "")
	keyName = keyName:gsub("%s+", "")
	if keyName == "" or keyName == "nil" or keyName == "None" or keyName == "Unbound" then
		return nil
	end
	local mouseAliases = {
		MB1 = "MouseButton1",
		MB2 = "MouseButton2",
		MB3 = "MouseButton3",
		Mouse1 = "MouseButton1",
		Mouse2 = "MouseButton2",
		Mouse3 = "MouseButton3"
	}
	keyName = mouseAliases[keyName] or keyName
	return Enum.KeyCode[keyName] or Enum.UserInputType[keyName]
end


local function LinoriaKeyName(value)
	local key = KeyFromValue(value)
	if not key then return "None" end
	if key == Enum.UserInputType.MouseButton1 then return "MB1" end
	if key == Enum.UserInputType.MouseButton2 then return "MB2" end
	if key == Enum.UserInputType.MouseButton3 then return "MB3" end
	return key.Name
end

local function LinoriaRegisterOption(flag, object)
	if not flag then return object end
	Options[flag] = object
	return object
end

local function LinoriaRegisterToggle(flag, object)
	if not flag then return object end
	Toggles[flag] = object
	return object
end

local function LinoriaWrapLabel(label, group)
	if not label or label.__LinoriaWrapped then return label end
	label.__LinoriaWrapped = true
	function label:AddColorPicker(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Title or "color")
		local item = group:ColorPicker({
			Name = info.Title or info.Text or realFlag,
			Flag = realFlag,
			Default = info.Default or Color3.fromRGB(255, 255, 255),
			Callback = function(value)
				local opt = Options[realFlag]
				if opt then opt.Value = value end
				if info.Callback then info.Callback(value) end
			end
		})
		local opt = {
			Value = item:Get(),
			Type = "ColorPicker",
			SetValueRGB = function(self, color)
				item:Set(color)
				self.Value = item:Get()
			end,
			SetValue = function(self, color)
				item:Set(color)
				self.Value = item:Get()
			end,
			OnChanged = function(self, fn)
				self.Changed = fn
				if fn then fn(self.Value) end
				return self
			end
		}
		LinoriaRegisterOption(realFlag, opt)
		return label
	end
	label.AddColorpicker = label.AddColorPicker
	function label:AddKeyPicker(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Text or "keybind")
		local keyItem
		local opt = {
			Value = LinoriaKeyName(info.Default),
			Mode = info.Mode or "Toggle",
			Type = "KeyPicker",
			Toggled = false,
			SetValue = function(self, data)
				local keyValue = data
				local modeValue = self.Mode
				if type(data) == "table" then
					keyValue = data[1] or data.Key or data.Value or keyValue
					modeValue = data[2] or data.Mode or modeValue
				end
				if keyItem then
					keyItem:Set(keyValue)
					if modeValue and keyItem.SetMode then keyItem:SetMode(modeValue) end
				end
				self.Value = LinoriaKeyName(keyValue)
				self.Mode = modeValue or self.Mode
			end,
			GetState = function(self)
				if self.Mode == "Always" or self.Mode == "always" then return true end
				return self.Toggled and true or false
			end,
			OnChanged = function(self, fn)
				self.Changed = fn
				if fn then fn(self.Value) end
				return self
			end,
			OnClick = function(self, fn)
				self.Clicked = fn
				return self
			end,
			Update = function() end
		}
		keyItem = group:Keybind({
			Name = info.Text or realFlag,
			Flag = realFlag,
			Default = info.Default,
			Mode = info.Mode,
			Callback = function(state)
				opt.Toggled = state and true or false
				if info.Callback then info.Callback(state) end
				if info.OnClick then info.OnClick(state) end
				if opt.Clicked then opt.Clicked(state) end
			end
		})
		if info.Mode and keyItem.SetMode then keyItem:SetMode(info.Mode) end
		if realFlag == "MenuKeybind" then
			local k = KeyFromValue(info.Default)
			if k then Library.MenuKey = k; Library.MenuKeybind = tostring(k) end
		end
		LinoriaRegisterOption(realFlag, opt)
		return label
	end
	return label
end

local function LinoriaWrapToggle(toggle, group, flag, callback)
	if not toggle then return toggle end
	local wrapped = toggle
	wrapped.Type = "Toggle"
	wrapped.Value = toggle.Get and toggle:Get() or false
	function wrapped:SetValue(value)
		if toggle.Set then toggle:Set(value) end
		self.Value = toggle.Get and toggle:Get() or (value and true or false)
		if callback then callback(self.Value) end
	end
	wrapped.Set = wrapped.SetValue
	function wrapped:OnChanged(fn)
		self.Changed = fn
		if fn then fn(self.Value) end
		return self
	end
	function wrapped:AddColorPicker(colorFlag, info)
		info = info or {}
		local label = {Colorpicker = function(_, data) return group:ColorPicker(data) end}
		LinoriaWrapLabel(label, group):AddColorPicker(colorFlag, info)
		return self
	end
	function wrapped:AddKeyPicker(keyFlag, info)
		info = info or {}
		local label = {Keybind = function(_, data) return group:Keybind(data) end}
		LinoriaWrapLabel(label, group):AddKeyPicker(keyFlag, info)
		return self
	end
	LinoriaRegisterToggle(flag, wrapped)
	return wrapped
end

local function LinoriaWrapGroupbox(group)
	if not group or group.__LinoriaWrapped then return group end
	group.__LinoriaWrapped = true

	function group:AddDivider()
		return self:Label("")
	end

	function group:AddBlank(size)
		local l = self:Label("")
		return l
	end

	function group:AddLabel(text, wrap)
		return LinoriaWrapLabel(self:Label(tostring(text or "")), self)
	end

	function group:AddToggle(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Text or "toggle")
		local wrapper
		local item = self:Toggle({
			Name = info.Text or realFlag,
			Flag = realFlag,
			Default = info.Default or false,
			Callback = function(value)
				if wrapper then wrapper.Value = value end
				if info.Callback then info.Callback(value) end
				if wrapper and wrapper.Changed then wrapper.Changed(value) end
			end
		})
		wrapper = LinoriaWrapToggle(item, self, realFlag, nil)
		wrapper.Value = info.Default or false
		return wrapper
	end

	function group:AddSlider(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Text or "slider")
		local suffix = info.Suffix or ""
		local default = info.Default
		local item = self:Slider({
			Name = info.Text or realFlag,
			Flag = realFlag,
			Min = info.Min or 0,
			Max = info.Max or 100,
			Default = default or info.Min or 0,
			Callback = function(value)
				local opt = Options[realFlag]
				if opt then opt.Value = value end
				if info.Callback then info.Callback(value) end
			end
		})
		local opt = {
			Value = item:Get(),
			Type = "Slider",
			SetValue = function(self, value)
				item:Set(value)
				self.Value = item:Get()
			end,
			Set = function(self, value) self:SetValue(value) end,
			OnChanged = function(self, fn)
				self.Changed = fn
				if fn then fn(self.Value) end
				return self
			end
		}
		LinoriaRegisterOption(realFlag, opt)
		return opt
	end

	function group:AddDropdown(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Text or "dropdown")
		local values = info.Values or info.Items or {}
		local default = info.Default
		if type(default) == "number" then default = values[default] end
		if default == nil and not info.AllowNull then default = values[1] end
		local item = self:Dropdown({
			Name = info.Text or realFlag,
			Flag = realFlag,
			Items = values,
			Default = default,
			Callback = function(value)
				local opt = Options[realFlag]
				if opt then opt.Value = value end
				if info.Callback then info.Callback(value) end
			end
		})
		local opt = {
			Value = item:Get(),
			Values = values,
			Type = "Dropdown",
			SetValue = function(self, value)
				if type(value) == "number" then value = self.Values[value] end
				item:Set(value)
				self.Value = item:Get()
			end,
			Set = function(self, value) self:SetValue(value) end,
			Refresh = function(self, newValues)
				self.Values = newValues or {}
			end,
			OnChanged = function(self, fn)
				self.Changed = fn
				if fn then fn(self.Value) end
				return self
			end
		}
		LinoriaRegisterOption(realFlag, opt)
		return opt
	end

	function group:AddInput(flag, info)
		info = info or {}
		local realFlag = tostring(flag or info.Flag or info.Text or "input")
		local item = self:Textbox({
			Name = info.Text or realFlag,
			Flag = realFlag,
			Default = info.Default or "",
			Callback = function(value)
				local opt = Options[realFlag]
				if opt then opt.Value = value end
				if info.Callback then info.Callback(value) end
			end
		})
		local opt = {
			Value = item:Get(),
			Type = "Input",
			SetValue = function(self, value)
				item:Set(value)
				self.Value = item:Get()
			end,
			Set = function(self, value) self:SetValue(value) end,
			OnChanged = function(self, fn)
				self.Changed = fn
				if fn then fn(self.Value) end
				return self
			end
		}
		LinoriaRegisterOption(realFlag, opt)
		return opt
	end

	function group:AddButton(first, second)
		local text, func
		if type(first) == "table" then
			text = first.Text or first.Name or "Button"
			func = first.Func or first.Callback or second
		else
			text = tostring(first or "Button")
			func = second
		end
		local btn = self:Button({Name = text, Callback = func})
		local wrapper = {Instance = btn}
		function wrapper:AddButton(a, b)
			local t, f
			if type(a) == "table" then
				t = a.Text or a.Name or "Button"
				f = a.Func or a.Callback or b
			else
				t = tostring(a or "Button")
				f = b
			end
			group:Button({Name = t, Callback = f})
			return self
		end
		function wrapper:AddTooltip() return self end
		return wrapper
	end

	return group
end

local function LinoriaWrapTab(tab)
	if not tab or tab.__LinoriaWrapped then return tab end
	tab.__LinoriaWrapped = true
	function tab:AddLeftGroupbox(name)
		return LinoriaWrapGroupbox(self:Section(name or "Groupbox", "left"))
	end
	function tab:AddRightGroupbox(name)
		return LinoriaWrapGroupbox(self:Section(name or "Groupbox", "right"))
	end
	function tab:AddLeftTabbox(name)
		return {AddTab = function(_, tabName) return self:AddLeftGroupbox(tabName or name or "Tab") end}
	end
	function tab:AddRightTabbox(name)
		return {AddTab = function(_, tabName) return self:AddRightGroupbox(tabName or name or "Tab") end}
	end
	return tab
end

local function LinoriaCompatWrapWindow(window)
	if not window or window.__LinoriaWrapped then return window end
	window.__LinoriaWrapped = true
	function window:AddTab(name)
		return LinoriaWrapTab(self:Tab(tostring(name or "Tab")))
	end
	function window:AddLeftGroupbox(name)
		local tab = self.ActiveTab and LinoriaWrapTab(self.ActiveTab) or self:AddTab("Main")
		return tab:AddLeftGroupbox(name)
	end
	function window:AddRightGroupbox(name)
		local tab = self.ActiveTab and LinoriaWrapTab(self.ActiveTab) or self:AddTab("Main")
		return tab:AddRightGroupbox(name)
	end
	return window
end

function Library:RefreshKeybinds()
	if not self.KeybindBox or not self.KeybindInner then return end

	for _, row in ipairs(self.KeybindRows or {}) do
		if row and row.Parent then
			row:Destroy()
		end
	end
	self.KeybindRows = {}

	local entries = {}
	for _, bind in pairs(self.Keybinds) do
		if bind.Key and string.lower(bind.Name) ~= "menu" then
			local keyName = bind.Key.Name:lower()
			table.insert(entries, {
				Text = string.lower(bind.Name),
				Mode = string.lower(bind.Mode or "toggle"),
				Key = keyName,
				Active = bind.State and true or false
			})
		end
	end
	table.sort(entries, function(a, b)
		return (a.Text .. a.Key .. (a.Mode or "")) < (b.Text .. b.Key .. (b.Mode or ""))
	end)

	if #entries == 0 then
		table.insert(entries, {Text = "no keybinds", Key = "", Active = false})
	end

	local longest = 0
	local rowStartY = 22
	local rowHeight = 12
	for i, entry in ipairs(entries) do
		local rowText = entry.Key ~= "" and (entry.Text .. " : " .. entry.Key .. " : " .. (entry.Mode or "")) or entry.Text
		longest = math.max(longest, #rowText)
		local row = New("TextLabel", {
			Parent = self.KeybindInner,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, rowStartY + ((i - 1) * rowHeight)),
			Size = UDim2.new(1, -16, 0, rowHeight),
			Text = rowText,
			Font = Enum.Font.Code,
			TextSize = 10,
			TextColor3 = entry.Active and Library.Theme.Accent or Library.Theme.Faint,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd
		})
		table.insert(self.KeybindRows, row)
	end

	local lineCount = math.max(#entries, 1)
	local innerHeight = math.clamp(22 + (lineCount * rowHeight) + 6, 34, 110)
	local totalHeight = innerHeight + 12
	local boxWidth = math.clamp(26 + (longest * 6), 116, 190)

	self.KeybindBox.Size = UDim2.fromOffset(boxWidth, totalHeight)
	self.KeybindInner.Size = UDim2.new(1, -12, 0, innerHeight)
	if self.KeybindText then
		self.KeybindText.Visible = false
	end
end

function Library:CreateWindow(options)
	options = options or {}

	local gui = New("ScreenGui", {
		Name = "junt_ui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = 999,
		Parent = PlayerGui
	})
	self.Gui = gui

	local mainGlowLayers = {}
	local mainGlowSettings = {}
	local mainSize = options.Size or UDim2.fromOffset(560, 500)
	local halfW = math.floor(mainSize.X.Offset / 2)
	local halfH = math.floor(mainSize.Y.Offset / 2)
	local openMainPos = UDim2.new(0.5, -halfW, 0.5, -halfH)
	local closedMainPos = UDim2.new(0.5, -halfW, 0.5, -halfH + 12)

	for i = 1, 50 do
		local t = i / 50
		local pad = math.floor(1 + t * 20)
		local transparency = 0.968 + (t * 0.026)
		local glow = New("Frame", {
			Parent = gui,
			Size = mainSize + UDim2.fromOffset(pad * 2, pad * 2),
			Position = openMainPos - UDim2.fromOffset(pad, pad),
			BackgroundColor3 = self.Theme.Accent,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = 0
		})
		New("UICorner", {Parent = glow, CornerRadius = UDim.new(0, 2)})
		mainGlowLayers[i] = glow
		mainGlowSettings[i] = {Pad = pad, Transparency = transparency}
	end

	local main = New("Frame", {
		Parent = gui,
		Size = mainSize,
		Position = openMainPos,
		BackgroundColor3 = self.Theme.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1
	})
	BindTheme(main, "BackgroundColor3", "Bg")
	for _, glow in ipairs(mainGlowLayers) do
		BindTheme(glow, "BackgroundColor3", "Accent")
	end

	local function SyncMainGlow()
		local pos = main.Position
		local size = main.Size
		for i, glow in ipairs(mainGlowLayers) do
			local settings = mainGlowSettings[i]
			glow.Position = pos - UDim2.fromOffset(settings.Pad, settings.Pad)
			glow.Size = size + UDim2.fromOffset(settings.Pad * 2, settings.Pad * 2)
			glow.Visible = main.Visible
		end
	end

	local function SetGlowVisibilityFactor(factor)
		for i, glow in ipairs(mainGlowLayers) do
			local base = mainGlowSettings[i].Transparency
			glow.BackgroundTransparency = math.clamp(base + factor, 0, 1)
		end
	end

	local function CreateAttachedGlow(target, layerCount, maxPad, startTransparency, transparencyRange)
		local layers = {}
		local settings = {}
		for i = 1, layerCount do
			local t = i / layerCount
			local pad = math.floor(1 + t * maxPad)
			local transparency = startTransparency + (t * transparencyRange)
			local glow = New("Frame", {
				Parent = gui,
				Size = target.Size + UDim2.fromOffset(pad * 2, pad * 2),
				Position = target.Position - UDim2.fromOffset(pad, pad),
				BackgroundColor3 = self.Theme.Accent,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				ZIndex = 0,
				Visible = false
			})
			New("UICorner", {Parent = glow, CornerRadius = UDim.new(0, 2)})
			BindTheme(glow, "BackgroundColor3", "Accent")
			layers[i] = glow
			settings[i] = {Pad = pad, Transparency = transparency}
		end
		local function sync()
			local pos = target.Position
			local size = target.Size
			for i, glow in ipairs(layers) do
				local info = settings[i]
				glow.Position = pos - UDim2.fromOffset(info.Pad, info.Pad)
				glow.Size = size + UDim2.fromOffset(info.Pad * 2, info.Pad * 2)
				glow.Visible = target.Visible
			end
		end
		local function setFactor(factor)
			for i, glow in ipairs(layers) do
				local base = settings[i].Transparency
				glow.BackgroundTransparency = math.clamp(base + factor, 0, 1)
			end
		end
		target:GetPropertyChangedSignal("Position"):Connect(sync)
		target:GetPropertyChangedSignal("Size"):Connect(sync)
		sync()
		return {Sync = sync, SetFactor = setFactor, Layers = layers, Settings = settings}
	end

	local function ApplyAccentLineGradient(line, glow, wideGlow)
		local lineGradient = New("UIGradient", {Parent = line, Rotation = 0})
		local glowGradient = glow and New("UIGradient", {Parent = glow, Rotation = 0}) or nil
		local wideGlowGradient = wideGlow and New("UIGradient", {Parent = wideGlow, Rotation = 0}) or nil
		local function updateLineGradient()
			local accent = Library.Theme.Accent
			local bright = Color3.fromRGB(255, 248, 250)
			local colors = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, accent),
				ColorSequenceKeypoint.new(0.18, Color3.fromRGB(244, 218, 226)),
				ColorSequenceKeypoint.new(0.50, bright),
				ColorSequenceKeypoint.new(0.82, Color3.fromRGB(244, 218, 226)),
				ColorSequenceKeypoint.new(1.00, accent)
			})
			lineGradient.Color = colors
			if glowGradient then
				glowGradient.Color = colors
				glowGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0.00, 0.88),
					NumberSequenceKeypoint.new(0.18, 0.72),
					NumberSequenceKeypoint.new(0.50, 0.12),
					NumberSequenceKeypoint.new(0.82, 0.72),
					NumberSequenceKeypoint.new(1.00, 0.88)
				})
			end
			if wideGlowGradient then
				wideGlowGradient.Color = colors
				wideGlowGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0.00, 0.97),
					NumberSequenceKeypoint.new(0.18, 0.93),
					NumberSequenceKeypoint.new(0.50, 0.72),
					NumberSequenceKeypoint.new(0.82, 0.93),
					NumberSequenceKeypoint.new(1.00, 0.97)
				})
			end
		end
		BindThemeUpdater({"Accent"}, updateLineGradient)
		updateLineGradient()
	end

	local mainScale = New("UIScale", {Parent = main, Scale = 1})
	Stroke(main, self.Theme.Outline, 1, "Outline")

	local top = New("Frame", {
		Parent = main,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = self.Theme.Bg2,
		BorderSizePixel = 0
	})
	BindTheme(top, "BackgroundColor3", "Bg2")
	Stroke(top, self.Theme.Outline2, 1, "Outline2")

	local topBottomLine = New("Frame", {
		Parent = top,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 1, 1, 0),
		Size = UDim2.new(1, -2, 0, 2),
		BackgroundColor3 = self.Theme.Accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 0.04
	})
	BindTheme(topBottomLine, "BackgroundColor3", "Accent")

	local topBottomLineGlow = New("Frame", {
		Parent = top,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 1, 1, 2),
		Size = UDim2.new(1, -2, 0, 6),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.90,
		BorderSizePixel = 0
	})
	BindTheme(topBottomLineGlow, "BackgroundColor3", "Accent")

	local topBottomLineGlowWide = New("Frame", {
		Parent = top,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 1, 1, 4),
		Size = UDim2.new(1, -2, 0, 12),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.96,
		BorderSizePixel = 0
	})
	BindTheme(topBottomLineGlowWide, "BackgroundColor3", "Accent")

	local topBottomLineGradient = New("UIGradient", {
		Parent = topBottomLine,
		Rotation = 0
	})
	local topBottomLineGlowGradient = New("UIGradient", {
		Parent = topBottomLineGlow,
		Rotation = 0
	})
	local topBottomLineGlowWideGradient = New("UIGradient", {
		Parent = topBottomLineGlowWide,
		Rotation = 0
	})
	local function updateTopLineGradient()
		local accent = Library.Theme.Accent
		local bright = Color3.fromRGB(255, 248, 250)
		topBottomLineGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, accent),
			ColorSequenceKeypoint.new(0.18, Color3.fromRGB(244, 218, 226)),
			ColorSequenceKeypoint.new(0.50, bright),
			ColorSequenceKeypoint.new(0.82, Color3.fromRGB(244, 218, 226)),
			ColorSequenceKeypoint.new(1.00, accent)
		})
		topBottomLineGlowGradient.Color = topBottomLineGradient.Color
		topBottomLineGlowWideGradient.Color = topBottomLineGradient.Color
		topBottomLineGlowGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.88),
			NumberSequenceKeypoint.new(0.18, 0.72),
			NumberSequenceKeypoint.new(0.50, 0.12),
			NumberSequenceKeypoint.new(0.82, 0.72),
			NumberSequenceKeypoint.new(1.00, 0.88)
		})
		topBottomLineGlowWideGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 0.97),
			NumberSequenceKeypoint.new(0.18, 0.93),
			NumberSequenceKeypoint.new(0.50, 0.72),
			NumberSequenceKeypoint.new(0.82, 0.93),
			NumberSequenceKeypoint.new(1.00, 0.97)
		})
	end
	BindThemeUpdater({"Accent"}, updateTopLineGradient)
	updateTopLineGradient()

	local title = New("TextLabel", {
		Parent = top,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.fromOffset(150, 26),
		Text = options.Title or "junt.hax.club",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	BindTheme(title, "TextColor3", "Text")

	local tabHolder = New("Frame", {
		Parent = top,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -7, 0, 0),
		Size = UDim2.new(0.7, -7, 1, 0)
	})

	New("UIListLayout", {
		Parent = tabHolder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6)
	})

	local contentPanel = New("Frame", {
		Parent = main,
		BackgroundColor3 = self.Theme.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 29),
		Size = UDim2.new(1, -12, 1, -35)
	})
	BindTheme(contentPanel, "BackgroundColor3", "Bg")
	Stroke(contentPanel, self.Theme.Outline, 1, "Outline")

	local content = New("Frame", {
		Parent = contentPanel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12)
	})

	local watermarkBaseX = 194
	local watermarkShownY = -50
	local watermarkHiddenY = -44
	local watermarkShownPos = UDim2.new(0, watermarkBaseX, 1, watermarkShownY)
	local watermarkHiddenPos = UDim2.new(0, watermarkBaseX, 1, watermarkHiddenY)
	local watermark = New("Frame", {
		Parent = gui,
		Size = UDim2.fromOffset(250, 34),
		Position = watermarkShownPos,
		BackgroundColor3 = self.Theme.Bg2,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true
	})
	BindTheme(watermark, "BackgroundColor3", "Bg2")
	local watermarkScale = New("UIScale", {Parent = watermark, Scale = 1})
	Stroke(watermark, self.Theme.Outline, 1, "Outline")

	local watermarkInner = New("Frame", {
		Parent = watermark,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = self.Theme.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true
	})
	BindTheme(watermarkInner, "BackgroundColor3", "Bg")
	Stroke(watermarkInner, self.Theme.Outline2, 1, "Outline2")

	local watermarkLine = New("Frame", {
		Parent = watermarkInner,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, 2),
		BackgroundColor3 = self.Theme.Accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 0.04
	})
	BindTheme(watermarkLine, "BackgroundColor3", "Accent")

	local watermarkLineGlow = New("Frame", {
		Parent = watermarkInner,
		Position = UDim2.fromOffset(1, 2),
		Size = UDim2.new(1, -2, 0, 6),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.90,
		BorderSizePixel = 0
	})
	BindTheme(watermarkLineGlow, "BackgroundColor3", "Accent")

	local watermarkLineGlowWide = New("Frame", {
		Parent = watermarkInner,
		Position = UDim2.fromOffset(1, 4),
		Size = UDim2.new(1, -2, 0, 12),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.96,
		BorderSizePixel = 0
	})
	BindTheme(watermarkLineGlowWide, "BackgroundColor3", "Accent")
	ApplyAccentLineGradient(watermarkLine, watermarkLineGlow, watermarkLineGlowWide)

	local watermarkText = New("TextLabel", {
		Parent = watermarkInner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 1, -4),
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None
	})
	BindTheme(watermarkText, "TextColor3", "Text")
	local watermarkGlow = CreateAttachedGlow(watermark, 26, 14, 0.972, 0.022)

	local function updateWatermarkBounds()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local desiredWidth = math.max(210, watermarkText.TextBounds.X + 22)
		desiredWidth = math.min(desiredWidth, math.max(210, viewport.X - 16))
		watermark.Size = UDim2.fromOffset(desiredWidth, 34)

		local shownX = math.min(watermarkBaseX, math.max(8, viewport.X - desiredWidth - 8))
		watermarkShownPos = UDim2.new(0, shownX, 1, watermarkShownY)
		watermarkHiddenPos = UDim2.new(0, shownX, 1, watermarkHiddenY)
		if (not watermark.Visible) or math.abs(watermark.Position.Y.Offset - watermarkShownY) <= 1 then
			watermark.Position = watermarkShownPos
		end
	end

	local keybindShownPos = UDim2.new(0, 8, 1, -114)
	local keybindHiddenPos = UDim2.new(0, 8, 1, -108)
	local keybindBox = New("Frame", {
		Parent = gui,
		Size = UDim2.fromOffset(132, 54),
		Position = keybindShownPos,
		BackgroundColor3 = self.Theme.Bg2,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true
	})
	BindTheme(keybindBox, "BackgroundColor3", "Bg2")
	local keybindScale = New("UIScale", {Parent = keybindBox, Scale = 1})
	Stroke(keybindBox, self.Theme.Outline, 1, "Outline")

	local keybindInner = New("Frame", {
		Parent = keybindBox,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 42),
		BackgroundColor3 = self.Theme.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true
	})
	BindTheme(keybindInner, "BackgroundColor3", "Bg")
	Stroke(keybindInner, self.Theme.Outline2, 1, "Outline2")

	local keybindHeader = New("TextLabel", {
		Parent = keybindInner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 10),
		Text = "keybinds",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top
	})
	BindTheme(keybindHeader, "TextColor3", "Text")

	local keybindLine = New("Frame", {
		Parent = keybindInner,
		Position = UDim2.fromOffset(8, 16),
		Size = UDim2.new(1, -16, 0, 2),
		BackgroundColor3 = self.Theme.Accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 0.04
	})
	BindTheme(keybindLine, "BackgroundColor3", "Accent")

	local keybindLineGlow = New("Frame", {
		Parent = keybindInner,
		Position = UDim2.fromOffset(8, 17),
		Size = UDim2.new(1, -16, 0, 6),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.90,
		BorderSizePixel = 0
	})
	BindTheme(keybindLineGlow, "BackgroundColor3", "Accent")

	local keybindLineGlowWide = New("Frame", {
		Parent = keybindInner,
		Position = UDim2.fromOffset(8, 19),
		Size = UDim2.new(1, -16, 0, 12),
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.96,
		BorderSizePixel = 0
	})
	BindTheme(keybindLineGlowWide, "BackgroundColor3", "Accent")
	ApplyAccentLineGradient(keybindLine, keybindLineGlow, keybindLineGlowWide)

	local keybindText = New("TextLabel", {
		Parent = keybindInner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 1, -8),
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = self.Theme.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd
	})
	BindTheme(keybindText, "TextColor3", "Dim")
	local keybindGlow = CreateAttachedGlow(keybindBox, 22, 12, 0.975, 0.02)

	MakeDraggable(main, top)
	MakeDraggable(watermark, watermark)
	MakeDraggable(keybindBox, keybindBox)

	main:GetPropertyChangedSignal("Position"):Connect(SyncMainGlow)
	main:GetPropertyChangedSignal("Size"):Connect(SyncMainGlow)
	SyncMainGlow()

	self.KeybindText = keybindText
	self.KeybindBox = keybindBox
	self.KeybindFrame = keybindBox
	self.KeybindContainer = keybindInner
	self.KeybindInner = keybindInner
	self.KeybindRows = {}

	local window = {
		Gui = gui,
		Main = main,
		Watermark = watermark,
		KeybindBox = keybindBox,
		Tabs = {},
		ActiveTab = nil
	}

	function window:SetOpen(state)
		Library.Open = state
		if state then
			main.Visible = true
			main.Position = closedMainPos
			mainScale.Scale = 0.975
			SetGlowVisibilityFactor(0.006)
			SyncMainGlow()
			Tween(mainScale, {Scale = 1}, 0.16)
			Tween(main, {Position = openMainPos}, 0.16)
			for i, glow in ipairs(mainGlowLayers) do
				Tween(glow, {BackgroundTransparency = mainGlowSettings[i].Transparency}, 0.16)
			end
		else
			Tween(mainScale, {Scale = 0.975}, 0.14)
			Tween(main, {Position = closedMainPos}, 0.14)
			for i, glow in ipairs(mainGlowLayers) do
				Tween(glow, {BackgroundTransparency = math.clamp(mainGlowSettings[i].Transparency + 0.006, 0, 1)}, 0.14)
			end
			task.delay(0.15, function()
				if not Library.Open then
					main.Visible = false
					mainScale.Scale = 1
					main.Position = openMainPos
					SetGlowVisibilityFactor(0)
					SyncMainGlow()
				end
			end)
		end
	end

	function window:SetWatermark(state)
		if state then
			watermark.Visible = true
			watermark.Position = watermarkHiddenPos
			watermarkScale.Scale = 0.96
			watermarkGlow.SetFactor(0.01)
			watermarkGlow.Sync()
			Tween(watermarkScale, {Scale = 1}, 0.14)
			Tween(watermark, {Position = watermarkShownPos}, 0.14)
			for i, glow in ipairs(watermarkGlow.Layers) do
				Tween(glow, {BackgroundTransparency = watermarkGlow.Settings[i].Transparency}, 0.14)
			end
		else
			Tween(watermarkScale, {Scale = 0.96}, 0.12)
			Tween(watermark, {Position = watermarkHiddenPos}, 0.12)
			for i, glow in ipairs(watermarkGlow.Layers) do
				Tween(glow, {BackgroundTransparency = math.clamp(watermarkGlow.Settings[i].Transparency + 0.01, 0, 1)}, 0.12)
			end
			task.delay(0.13, function()
				if watermark.Parent then
					watermark.Visible = false
					watermarkScale.Scale = 1
					watermark.Position = watermarkShownPos
					watermarkGlow.SetFactor(0)
					watermarkGlow.Sync()
				end
			end)
		end
	end

	function window:SetKeybindBox(state)
		if state then
			keybindBox.Visible = true
			keybindBox.Position = keybindHiddenPos
			keybindScale.Scale = 0.96
			keybindGlow.SetFactor(0.01)
			keybindGlow.Sync()
			Tween(keybindScale, {Scale = 1}, 0.14)
			Tween(keybindBox, {Position = keybindShownPos}, 0.14)
			for i, glow in ipairs(keybindGlow.Layers) do
				Tween(glow, {BackgroundTransparency = keybindGlow.Settings[i].Transparency}, 0.14)
			end
		else
			Tween(keybindScale, {Scale = 0.96}, 0.12)
			Tween(keybindBox, {Position = keybindHiddenPos}, 0.12)
			for i, glow in ipairs(keybindGlow.Layers) do
				Tween(glow, {BackgroundTransparency = math.clamp(keybindGlow.Settings[i].Transparency + 0.01, 0, 1)}, 0.12)
			end
			task.delay(0.13, function()
				if keybindBox.Parent then
					keybindBox.Visible = false
					keybindScale.Scale = 1
					keybindBox.Position = keybindShownPos
					keybindGlow.SetFactor(0)
					keybindGlow.Sync()
				end
			end)
		end
	end

	task.spawn(function()
		while gui.Parent do
			local dt = RunService.RenderStepped:Wait()
			local fps = math.floor(1 / math.max(dt, 1 / 240))
			local infoText = Library.WatermarkText or string.format("junt.hax.club | %d fps | %s | %s", fps, PlaceDisplayName, os.date("%H:%M:%S"))
			watermarkText.Text = infoText
			updateWatermarkBounds()
		end
	end)

	AddConnection(UIS.InputBegan, function(input, gp)
		if gp then return end
		if input.KeyCode == Library.MenuKey then
			window:SetOpen(not Library.Open)
		end
		for _, bind in pairs(Library.Keybinds) do
			if bind.Key and (input.KeyCode == bind.Key or input.UserInputType == bind.Key) then
				local bindMode = string.lower(bind.Mode or "toggle")
				if bindMode == "toggle" then
					bind.State = not bind.State
					if bind.Callback then bind.Callback(bind.State) end
				elseif bindMode == "hold" then
					bind.State = true
					if bind.Callback then bind.Callback(true) end
				elseif bindMode == "always" then
					bind.State = true
				end
				if bind.Flag then Library.Flags[bind.Flag] = bind.State end
				Library:RefreshKeybinds()
			end
		end
	end)

	AddConnection(UIS.InputEnded, function(input, gp)
		if gp then return end
		for _, bind in pairs(Library.Keybinds) do
			if bind.Key and (input.KeyCode == bind.Key or input.UserInputType == bind.Key) and bind.Mode == "hold" then
				bind.State = false
				if bind.Flag then Library.Flags[bind.Flag] = bind.State end
				if bind.Callback then bind.Callback(false) end
				Library:RefreshKeybinds()
			end
		end
	end)

	local function CreateFloatingColorPicker(anchor, startColor, onChanged)
		local currentColor = startColor or Library.Theme.Accent
		local H, S, V = Color3.toHSV(currentColor)
		local draggingSV = false
		local draggingHue = false
		local open = false

		local popup = New("Frame", {
			Parent = gui,
			Size = UDim2.fromOffset(154, 128),
			BackgroundColor3 = Library.Theme.Bg2,
			BorderSizePixel = 0,
			Visible = false,
			Active = true,
			ZIndex = 140
		})
		BindTheme(popup, "BackgroundColor3", "Bg2")
		Stroke(popup, Library.Theme.Outline, 1, "Outline")

		local inner = New("Frame", {
			Parent = popup,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundColor3 = Library.Theme.Bg,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 141
		})
		BindTheme(inner, "BackgroundColor3", "Bg")
		Stroke(inner, Library.Theme.Outline2, 1, "Outline2")

		local sv = New("Frame", {
			Parent = inner,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(104, 68),
			BackgroundColor3 = Color3.fromHSV(H, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Active = true,
			ZIndex = 142
		})
		Stroke(sv, Library.Theme.Outline2, 1, "Outline2")

		local white = New("Frame", {
			Parent = sv,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 143
		})
		New("UIGradient", {
			Parent = white,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1)
			})
		})

		local black = New("Frame", {
			Parent = sv,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 144
		})
		New("UIGradient", {
			Parent = black,
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0)
			})
		})

		local svCursor = New("Frame", {
			Parent = sv,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(S, 0, 1 - V, 0),
			Size = UDim2.fromOffset(6, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 145
		})
		local svCursorStroke = Stroke(svCursor, Color3.fromRGB(235, 235, 235), 1)
		local svCursorInner = New("Frame", {
			Parent = svCursor,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(2, 2),
			BackgroundColor3 = Color3.fromRGB(235, 235, 235),
			BorderSizePixel = 0,
			ZIndex = 146
		})

		local hue = New("Frame", {
			Parent = inner,
			Position = UDim2.fromOffset(118, 6),
			Size = UDim2.fromOffset(10, 68),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 142
		})
		Stroke(hue, Library.Theme.Outline2, 1, "Outline2")
		New("UIGradient", {
			Parent = hue,
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
			})
		})

		local hueCursor = New("Frame", {
			Parent = hue,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, H, 0),
			Size = UDim2.fromOffset(14, 3),
			BackgroundColor3 = Color3.fromRGB(235, 235, 235),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 145
		})
		Stroke(hueCursor, Color3.new(0, 0, 0), 1)

		local function makeRGBBox(labelText, x)
			local label = New("TextLabel", {
				Parent = inner,
				Position = UDim2.fromOffset(x, 80),
				Size = UDim2.fromOffset(38, 10),
				BackgroundTransparency = 1,
				Text = string.upper(labelText),
				Font = Enum.Font.Code,
				TextSize = 10,
				TextColor3 = Library.Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 142
			})
			BindTheme(label, "TextColor3", "Text")

			local box = New("TextBox", {
				Parent = inner,
				Position = UDim2.fromOffset(x, 93),
				Size = UDim2.fromOffset(38, 17),
				BackgroundColor3 = Color3.fromRGB(24, 24, 26),
				BorderSizePixel = 0,
				Text = "0",
				PlaceholderText = "0",
				ClearTextOnFocus = false,
				Font = Enum.Font.Code,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(245, 228, 235),
				PlaceholderColor3 = Library.Theme.Faint,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 142
			})
			Stroke(box, Library.Theme.Outline2, 1, "Outline2")
			return box
		end

		local rBox = makeRGBBox("R", 6)
		local gBox = makeRGBBox("G", 54)
		local bBox = makeRGBBox("B", 102)

		local function pointInside(guiObject, point)
			local pos, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
			return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
		end

		local function positionPopup()
			local camera = workspace.CurrentCamera
			local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
			local preferredX = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6
			local fallbackX = anchor.AbsolutePosition.X - popup.AbsoluteSize.X - 6
			local x = preferredX
			if preferredX + popup.AbsoluteSize.X > viewport.X - 4 then
				x = fallbackX
			end
			if x < 4 then
				x = math.clamp(preferredX, 4, viewport.X - popup.AbsoluteSize.X - 4)
			end
			local y = anchor.AbsolutePosition.Y - 2
			if y + popup.AbsoluteSize.Y > viewport.Y - 4 then
				y = viewport.Y - popup.AbsoluteSize.Y - 4
			end
			if y < 4 then
				y = 4
			end
			popup.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end

		local function update(skipCallback)
			currentColor = Color3.fromHSV(H, S, V)
			if anchor and anchor.Parent then
				anchor.BackgroundColor3 = currentColor
			end
			sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
			svCursor.Position = UDim2.new(S, 0, 1 - V, 0)
			hueCursor.Position = UDim2.new(0.5, 0, H, 0)
			local r = math.floor(currentColor.R * 255 + 0.5)
			local g = math.floor(currentColor.G * 255 + 0.5)
			local b = math.floor(currentColor.B * 255 + 0.5)
			if not rBox:IsFocused() then rBox.Text = tostring(r) end
			if not gBox:IsFocused() then gBox.Text = tostring(g) end
			if not bBox:IsFocused() then bBox.Text = tostring(b) end
			if onChanged and not skipCallback then
				onChanged(currentColor)
			end
		end

		local function setSV(x, y)
			local pos, size = sv.AbsolutePosition, sv.AbsoluteSize
			S = math.clamp((x - pos.X) / size.X, 0, 1)
			V = 1 - math.clamp((y - pos.Y) / size.Y, 0, 1)
			update(false)
		end

		local function setHue(y)
			local pos, size = hue.AbsolutePosition, hue.AbsoluteSize
			H = math.clamp((y - pos.Y) / size.Y, 0, 1)
			update(false)
		end

		local function setFromRGBBoxes()
			local r = math.clamp(tonumber(rBox.Text) or 0, 0, 255)
			local g = math.clamp(tonumber(gBox.Text) or 0, 0, 255)
			local b = math.clamp(tonumber(bBox.Text) or 0, 0, 255)
			rBox.Text = tostring(math.floor(r + 0.5))
			gBox.Text = tostring(math.floor(g + 0.5))
			bBox.Text = tostring(math.floor(b + 0.5))
			H, S, V = Color3.toHSV(Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)))
			update(false)
		end

		local picker = {}
		function picker:SetOpen(state)
			open = state and true or false
			if open then
				if Library.ActiveFloatingColorPicker and Library.ActiveFloatingColorPicker ~= picker then
					Library.ActiveFloatingColorPicker:SetOpen(false)
				end
				Library.ActiveFloatingColorPicker = picker
				positionPopup()
				popup.Visible = true
			else
				popup.Visible = false
				draggingSV = false
				draggingHue = false
				if Library.ActiveFloatingColorPicker == picker then
					Library.ActiveFloatingColorPicker = nil
				end
			end
		end
		function picker:Toggle()
			picker:SetOpen(not open)
		end
		function picker:IsOpen()
			return open
		end
		function picker:Set(value)
			local newColor = typeof(value) == "Color3" and value or ColorFromHex(value)
			if newColor then
				H, S, V = Color3.toHSV(newColor)
				update(false)
			end
		end
		function picker:Get()
			return currentColor
		end

		local function beginSV(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSV = true
				setSV(input.Position.X, input.Position.Y)
			end
		end
		local function beginHue(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHue = true
				setHue(input.Position.Y)
			end
		end

		sv.InputBegan:Connect(beginSV)
		white.InputBegan:Connect(beginSV)
		black.InputBegan:Connect(beginSV)
		svCursor.InputBegan:Connect(beginSV)
		hue.InputBegan:Connect(beginHue)
		hueCursor.InputBegan:Connect(beginHue)
		rBox.FocusLost:Connect(setFromRGBBoxes)
		gBox.FocusLost:Connect(setFromRGBBoxes)
		bBox.FocusLost:Connect(setFromRGBBoxes)

		AddConnection(UIS.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingSV = false
				draggingHue = false
			end
		end)
		AddConnection(UIS.InputChanged, function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if draggingSV then
					setSV(input.Position.X, input.Position.Y)
				elseif draggingHue then
					setHue(input.Position.Y)
				end
			end
		end)
		AddConnection(UIS.InputBegan, function(input, gp)
			if gp or not open then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = input.Position
				if not pointInside(popup, pos) and not pointInside(anchor, pos) then
					picker:SetOpen(false)
				end
			end
		end)

		update(true)
		return picker
	end

	function window:Tab(name)
		local tabWidth = math.max(42, #name * 6 + 10)
		local button = New("TextButton", {
			Parent = tabHolder,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(tabWidth, 26),
			Text = string.lower(name),
			Font = Enum.Font.Code,
			TextSize = 10,
			TextColor3 = Library.Theme.TabInactive,
			AutoButtonColor = false
		})
		BindTheme(button, "TextColor3", "TabInactive")

		local page = New("ScrollingFrame", {
			Parent = content,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ClipsDescendants = true,
			CanvasSize = UDim2.fromOffset(0, 0),
			CanvasPosition = Vector2.new(0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ScrollBarImageColor3 = Library.Theme.Accent,
			ScrollBarImageTransparency = 1,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ScrollingEnabled = true,
			VerticalScrollBarInset = Enum.ScrollBarInset.None
		})
		BindTheme(page, "ScrollBarImageColor3", "Accent")

		local pageTopInset = 8

		local left = New("Frame", {
			Parent = page,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, pageTopInset),
			Size = UDim2.new(0.5, -5, 0, math.max(page.AbsoluteSize.Y - pageTopInset, 0))
		})

		local right = New("Frame", {
			Parent = page,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, pageTopInset),
			Size = UDim2.new(0.5, -5, 0, math.max(page.AbsoluteSize.Y - pageTopInset, 0))
		})

		local leftLayout = New("UIListLayout", {
			Parent = left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10)
		})

		local rightLayout = New("UIListLayout", {
			Parent = right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10)
		})

		local function updatePageCanvas()
			local contentHeight = math.max(leftLayout.AbsoluteContentSize.Y, rightLayout.AbsoluteContentSize.Y)
			local neededHeight = math.max(contentHeight + pageTopInset, page.AbsoluteSize.Y)
			neededHeight = math.ceil(neededHeight + 2)
			page.CanvasSize = UDim2.fromOffset(0, neededHeight)
			left.Size = UDim2.new(0.5, -5, 0, math.max(neededHeight - pageTopInset, 0))
			right.Size = UDim2.new(0.5, -5, 0, math.max(neededHeight - pageTopInset, 0))
		end

		leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePageCanvas)
		rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePageCanvas)
		page:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePageCanvas)
		task.defer(updatePageCanvas)

		local tab = {
			Button = button,
			Page = page,
			Left = left,
			Right = right,
			Active = false
		}

		button.MouseEnter:Connect(function()
			if not tab.Active then
				Tween(button, {TextColor3 = Library.Theme.TabInactiveHover}, 0.1)
			end
		end)
		button.MouseLeave:Connect(function()
			if not tab.Active then
				Tween(button, {TextColor3 = Library.Theme.TabInactive}, 0.1)
			end
		end)

		local function select()
			for _, other in ipairs(window.Tabs) do
				other.Active = false
				other.Page.Visible = false
				other.Page.Position = UDim2.fromOffset(0, 0)
				Tween(other.Button, {TextColor3 = Library.Theme.TabInactive}, 0.1)
			end
			tab.Active = true
			page.Visible = true
			page.CanvasPosition = Vector2.new(0, 0)
			task.defer(updatePageCanvas)
			page.Position = UDim2.fromOffset(8, 0)
			Tween(page, {Position = UDim2.fromOffset(0, 0)}, 0.14)
			window.ActiveTab = tab
			Tween(button, {TextColor3 = Library.Theme.Accent}, 0.1)
		end

		button.MouseButton1Click:Connect(select)
		table.insert(window.Tabs, tab)
		if not window.ActiveTab then select() end

		function tab:Section(titleText, side, customHeight)
			if typeof(titleText) == "table" then
				local Data = titleText
				titleText = Data.Name or Data.name or Data.Title or Data.title or "section"
				local sideValue = Data.Side or Data.side or side
				side = (sideValue == 2 or sideValue == "right" or sideValue == "Right") and "right" or "left"
				customHeight = Data.Height or Data.height or Data.Size or Data.size or customHeight
			end
			local parent = (side == "right") and right or left
			local lowerTitle = string.lower(tostring(titleText))

			local section = New("Frame", {
				Parent = parent,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = Color3.fromRGB(19, 19, 19),
				BorderSizePixel = 0,
				ClipsDescendants = false
			})
			Stroke(section, Library.Theme.Outline, 1, "Outline")

			local titleWidth = math.max(44, #lowerTitle * 7 + 4)
			local header = New("TextLabel", {
				Parent = section,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, -7),
				Size = UDim2.fromOffset(titleWidth, 13),
				Text = lowerTitle,
				Font = Enum.Font.Code,
				TextSize = 10,
				TextColor3 = Library.Theme.Accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5
			})
			BindTheme(header, "TextColor3", "Accent")

			local holder = New("Frame", {
				Parent = section,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 15),
				Size = UDim2.new(1, -20, 1, -22)
			})

			local layout = New("UIListLayout", {
				Parent = holder,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5)
			})

			local api = {}

			local function resize()

				section.Size = UDim2.new(1, 0, 0, math.max(32, layout.AbsoluteContentSize.Y + 32))
				task.defer(updatePageCanvas)
			end

			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

			function api:Label(text)
				if typeof(text) == "table" then
					local Data = text
					text = Data.Name or Data.name or Data.Text or Data.text or "label"
				end
				local label = New("TextLabel", {
					Parent = holder,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 14),
					Text = text,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left
				})
				BindTheme(label, "TextColor3", "Text")
				task.defer(resize)
				local labelApi = {Instance = label}
				function labelApi:Colorpicker(Data)
					Data = Data or {}
					Data.Name = Data.Name or Data.name or tostring(text)
					return api:Colorpicker(Data)
				end
				labelApi.ColorPicker = labelApi.Colorpicker
				function labelApi:Keybind(Data)
					Data = Data or {}
					Data.Name = Data.Name or Data.name or tostring(text)
					return api:Keybind(Data)
				end
				function labelApi:Set(value)
					label.Text = tostring(value)
				end
				return labelApi
			end

			function api:Button(text, callback)
				if typeof(text) == "table" then
					local Data = text
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "button"
				end
				local btn = New("TextButton", {
					Parent = holder,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false
				})
				local btnBack = New("Frame", {
					Parent = btn,
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ZIndex = 1,
					ClipsDescendants = true
				})
				ApplyControlGradient(btnBack)
				Stroke(btnBack, Library.Theme.Outline2, 1, "Outline2")
				AddReflection(btnBack, 1)
				local btnText = New("TextLabel", {
					Parent = btn,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Text = string.lower(text),
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					ZIndex = 2
				})
				BindTheme(btnText, "TextColor3", "Dim")
				AnimateButton(btn)
				btn.MouseEnter:Connect(function()
					Tween(btnBack, {BackgroundTransparency = 0.02}, 0.08)
					Tween(btnText, {TextColor3 = Library.Theme.Text}, 0.08)
				end)
				btn.MouseLeave:Connect(function()
					Tween(btnBack, {BackgroundTransparency = 0}, 0.08)
					Tween(btnText, {TextColor3 = Library.Theme.Dim}, 0.08)
				end)
				btn.MouseButton1Click:Connect(function()
					if callback then callback() end
				end)
				task.defer(resize)
				return btn
			end

			function api:Textbox(text, default, callback)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					default = Data.Default or Data.default or default
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "textbox"
				end
				local flag = flagOverride or string.lower(text)
				local value = tostring(default or "")
				Library.Flags[flag] = value

				local frame = New("Frame", {
					Parent = holder,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ClipsDescendants = true
				})
				ApplyControlGradient(frame)
				Stroke(frame, Library.Theme.Outline2, 1, "Outline2")
				AddReflection(frame, 1)

				local label = New("TextLabel", {
					Parent = frame,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(6, 0),
					Size = UDim2.new(0.45, -6, 1, 0),
					Text = flag,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3
				})
				BindTheme(label, "TextColor3", "Dim")

				local box = New("TextBox", {
					Parent = frame,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 0),
					Size = UDim2.new(0.55, -4, 1, 0),
					Text = value,
					PlaceholderText = "name",
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Right,
					ClearTextOnFocus = false,
					ZIndex = 3
				})
				BindTheme(box, "TextColor3", "Text")

				local item = {}
				function item:Set(v)
					value = tostring(v or "")
					box.Text = value
					Library.Flags[flag] = value
					if callback then callback(value) end
				end
				function item:Get()
					return value
				end

				box.Focused:Connect(function()
					Tween(label, {TextColor3 = Library.Theme.Text}, 0.08)
				end)
				box.FocusLost:Connect(function()
					item:Set(box.Text)
					Tween(label, {TextColor3 = Library.Theme.Dim}, 0.08)
				end)

				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			function api:ConfigList(getConfigs, onSelect)
				local selected = ""
				local frame = New("Frame", {
					Parent = holder,
					Size = UDim2.new(1, 0, 0, 92),
					BackgroundColor3 = Library.Theme.Bg,
					BorderSizePixel = 0,
					ClipsDescendants = true
				})
				BindTheme(frame, "BackgroundColor3", "Bg")
				Stroke(frame, Library.Theme.Outline2, 1, "Outline2")

				local header = New("TextLabel", {
					Parent = frame,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(8, 4),
					Size = UDim2.new(1, -16, 0, 12),
					Text = "saved configs",
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top
				})
				BindTheme(header, "TextColor3", "Text")

				local line = New("Frame", {
					Parent = frame,
					Position = UDim2.fromOffset(8, 18),
					Size = UDim2.new(1, -16, 0, 1),
					BackgroundColor3 = Library.Theme.Accent,
					BorderSizePixel = 0
				})
				BindTheme(line, "BackgroundColor3", "Accent")
				local lineGradient = New("UIGradient", {Parent = line})
				local function updateLineGradient()
					lineGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0.00, Library.Theme.Accent),
						ColorSequenceKeypoint.new(0.50, Color3.fromRGB(255, 248, 250)),
						ColorSequenceKeypoint.new(1.00, Library.Theme.Accent)
					})
				end
				BindThemeUpdater({"Accent"}, updateLineGradient)
				updateLineGradient()

				local list = New("ScrollingFrame", {
					Parent = frame,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(6, 23),
					Size = UDim2.new(1, -12, 1, -29),
					CanvasSize = UDim2.fromOffset(0, 0),
					ScrollBarThickness = 0,
					ScrollBarImageTransparency = 1,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ElasticBehavior = Enum.ElasticBehavior.Never,
					ClipsDescendants = true
				})

				local listLayout = New("UIListLayout", {
					Parent = list,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2)
				})

				local rows = {}
				local item = {}

				function item:Refresh(forceSelected)
					if forceSelected ~= nil then
						selected = tostring(forceSelected)
					end
					for _, row in ipairs(rows) do
						if row and row.Parent then
							row:Destroy()
						end
					end
					rows = {}

					local configs = {}
					local ok, result = pcall(function()
						return getConfigs and getConfigs() or {}
					end)
					if ok and type(result) == "table" then
						configs = result
					end

					if #configs == 0 then
						local none = New("TextLabel", {
							Parent = list,
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 16),
							Text = "none",
							Font = Enum.Font.Code,
							TextSize = 10,
							TextColor3 = Library.Theme.Faint,
							TextXAlignment = Enum.TextXAlignment.Left
						})
						BindTheme(none, "TextColor3", "Faint")
						table.insert(rows, none)
					else
						for _, configName in ipairs(configs) do
							local isSelected = selected ~= "" and configName == selected
							local row = New("TextButton", {
								Parent = list,
								BackgroundTransparency = isSelected and 0.88 or 1,
								BackgroundColor3 = Library.Theme.Accent,
								Size = UDim2.new(1, 0, 0, 16),
								Text = "  " .. tostring(configName),
								Font = Enum.Font.Code,
								TextSize = 10,
								TextColor3 = isSelected and Library.Theme.Accent or Library.Theme.Dim,
								TextXAlignment = Enum.TextXAlignment.Left,
								AutoButtonColor = false
							})
							BindTheme(row, "BackgroundColor3", "Accent")
							row.MouseEnter:Connect(function()
								if configName ~= selected then
									Tween(row, {TextColor3 = Library.Theme.Text}, 0.08)
								end
							end)
							row.MouseLeave:Connect(function()
								if configName ~= selected then
									Tween(row, {TextColor3 = Library.Theme.Dim}, 0.08)
								end
							end)
							row.MouseButton1Click:Connect(function()
								selected = configName
								if onSelect then
									onSelect(configName)
								end
								item:Refresh(configName)
							end)
							table.insert(rows, row)
						end
					end

					list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 2)
				end

				listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 2)
				end)

				task.defer(function()
					item:Refresh(selected)
					resize()
				end)

				return item
			end

			function api:Toggle(text, default, callback, colorBar)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					default = Data.Default or Data.default or default
					callback = Data.Callback or Data.callback or callback
					colorBar = Data.ColorBar or Data.colorBar or Data.Colors or Data.colors or colorBar
					text = Data.Name or Data.name or Data.Text or Data.text or "toggle"
				end
				local state = default or false
				local flag = flagOverride or string.lower(text)
				Library.Flags[flag] = state

				local swatchTotalWidth = 0
				if colorBar then
					if typeof(colorBar) == "table" then
						swatchTotalWidth = #colorBar * 16 + 4
					else
						swatchTotalWidth = 26
					end
				end

				local row = New("TextButton", {
					Parent = holder,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 14),
					Text = "",
					AutoButtonColor = false
				})

				local box = New("Frame", {
					Parent = row,
					Position = UDim2.fromOffset(0, 2),
					Size = UDim2.fromOffset(9, 9),
					BackgroundColor3 = Library.Theme.Bg3,
					BorderSizePixel = 0,
					ClipsDescendants = true
				})
				BindTheme(box, "BackgroundColor3", "Bg3")
				Stroke(box, Library.Theme.Outline2, 1, "Outline2")
				AddReflection(box, 3)

				local fill = New("Frame", {
					Parent = box,
					Position = UDim2.fromOffset(1, 1),
					Size = state and UDim2.fromOffset(7, 7) or UDim2.fromOffset(0, 7),
					BackgroundColor3 = Library.Theme.Accent,
					BorderSizePixel = 0,
					BackgroundTransparency = state and 0 or 1,
					ClipsDescendants = true
				})
				BindTheme(fill, "BackgroundColor3", "Accent")

				local label = New("TextLabel", {
					Parent = row,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(16, 0),
					Size = UDim2.new(1, -(16 + swatchTotalWidth + 4), 1, 0),
					Text = flag,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = state and Library.Theme.Text or Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left
				})

				local suppressRowClick = false
				local swatchColors = {}
				Library.Flags[flag .. "_colors"] = swatchColors

				local function makeColorSwatch(index, color, position, size)
					local swatch = New("TextButton", {
						Parent = row,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = position,
						Size = size,
						BackgroundColor3 = color,
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
						Active = true,
						ZIndex = 8
					})
					Stroke(swatch, Library.Theme.Outline2, 1, "Outline2")
					swatchColors[index] = color
					local picker = CreateFloatingColorPicker(swatch, color, function(newColor)
						swatchColors[index] = newColor
						Library.Flags[flag .. "_colors"] = swatchColors
					end)
					local lastSwatchToggle = 0
					local function openFromSwatch()
						local now = os.clock()
						if now - lastSwatchToggle < 0.15 then return end
						lastSwatchToggle = now
						suppressRowClick = true
						picker:Toggle()
						task.delay(0.22, function() suppressRowClick = false end)
					end

					local function isPointInsideSwatch(pos)
						local ap, as = swatch.AbsolutePosition, swatch.AbsoluteSize
						return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
					end

					swatch.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							openFromSwatch()
						end
					end)
					swatch.MouseButton1Click:Connect(openFromSwatch)
					AddConnection(UIS.InputBegan, function(input, gp)
						if input.UserInputType == Enum.UserInputType.MouseButton1 and swatch.Parent and isPointInsideSwatch(input.Position) then
							openFromSwatch()
						end
					end)
					return swatch, picker
				end

				if colorBar then
					if typeof(colorBar) == "table" then

						for idx, c in ipairs(colorBar) do
							local xOff = -(idx * 16) + 2
							makeColorSwatch(idx, c, UDim2.new(1, xOff, 0.5, 0), UDim2.fromOffset(12, 8))
						end
					else
						makeColorSwatch(1, colorBar, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(22, 8))
					end
				end

				row.MouseEnter:Connect(function()
					if not state then Tween(label, {TextColor3 = Library.Theme.Text}, 0.08) end
				end)
				row.MouseLeave:Connect(function()
					if not state then Tween(label, {TextColor3 = Library.Theme.Dim}, 0.08) end
				end)

				local item = {}

				function item:Set(v)
					state = v and true or false
					Library.Flags[flag] = state
					Tween(fill, {
						Size = state and UDim2.fromOffset(7, 7) or UDim2.fromOffset(0, 7),
						BackgroundTransparency = state and 0 or 1
					}, 0.08)
					Tween(label, {TextColor3 = state and Library.Theme.Text or Library.Theme.Dim}, 0.08)
					if callback then callback(state) end
				end

				function item:Get() return state end

				function item:Keybind(Data)
					Data = Data or {}
					Data.Name = Data.Name or Data.name or text
					Data.Flag = Data.Flag or Data.flag or (flag .. "_key")
					return api:Keybind(Data)
				end

				function item:Colorpicker(Data)
					Data = Data or {}
					Data.Name = Data.Name or Data.name or text
					Data.Flag = Data.Flag or Data.flag or (flag .. "_color")
					return api:ColorPicker(Data)
				end

				item.ColorPicker = item.Colorpicker

				row.MouseButton1Click:Connect(function()
					if suppressRowClick then return end
					item:Set(not state)
				end)

				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			function api:Slider(text, min, max, default, callback)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					min = Data.Min or Data.min or Data.Minimum or Data.minimum or min
					max = Data.Max or Data.max or Data.Maximum or Data.maximum or max
					default = Data.Default or Data.default or default
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "slider"
				end
				local value = default or min
				local flag = flagOverride or string.lower(text)
				local dragging = false
				Library.Flags[flag] = value

				local frame = New("Frame", {
					Parent = holder,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 28)
				})

				local nameLabel = New("TextLabel", {
					Parent = frame,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, -40, 0, 12),
					Text = flag,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left
				})
				BindTheme(nameLabel, "TextColor3", "Dim")

				local valueLabel = New("TextLabel", {
					Parent = frame,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(36, 12),
					Text = tostring(value),
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Right
				})
				BindTheme(valueLabel, "TextColor3", "Dim")

				local bar = New("Frame", {
					Parent = frame,
					Position = UDim2.fromOffset(0, 15),
					Size = UDim2.new(1, 0, 0, 7),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ClipsDescendants = true
				})
				ApplyControlGradient(bar)
				Stroke(bar, Library.Theme.Outline2, 1, "Outline2")
				AddReflection(bar, 1)

				local fill = New("Frame", {
					Parent = bar,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
					BackgroundColor3 = Library.Theme.Accent,
					BorderSizePixel = 0
				})
				BindTheme(fill, "BackgroundColor3", "Accent")

				local item = {}

				function item:Set(v)
					value = math.clamp(tonumber(v) or min, min, max)
					Library.Flags[flag] = value
					local pct = (value - min) / (max - min)
					valueLabel.Text = tostring(value)
					Tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, dragging and 0.04 or 0.08)
					if callback then callback(value) end
				end

				function item:Get() return value end

				local function setFromX(x)
					local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
					item:Set(math.floor((min + (max - min) * pct) * 10 + 0.5) / 10)
				end

				bar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						setFromX(input.Position.X)
					end
				end)
				AddConnection(UIS.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
				end)
				AddConnection(UIS.InputChanged, function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						setFromX(input.Position.X)
					end
				end)

				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			function api:Dropdown(text, values, default, callback)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					values = Data.Items or Data.items or Data.Options or Data.options or values
					default = Data.Default or Data.default or default
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "dropdown"
				end
				values = values or {}
				local current = default or values[1] or "none"
				local flag = flagOverride or string.lower(text)
				local open = false
				Library.Flags[flag] = current

				local frame = New("Frame", {
					Parent = holder,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ClipsDescendants = true
				})
				ApplyControlGradient(frame)
				Stroke(frame, Library.Theme.Outline2, 1, "Outline2")

				local mainButton = New("TextButton", {
					Parent = frame,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					Text = "",
					AutoButtonColor = false,
					LayoutOrder = 1,
					ClipsDescendants = true
				})
				AddReflection(mainButton, 1)

				local nameLabel = New("TextLabel", {
					Parent = mainButton,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(6, 0),
					Size = UDim2.new(1, -64, 1, 0),
					Text = flag,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left
				})
				BindTheme(nameLabel, "TextColor3", "Dim")

				local valueLabel = New("TextLabel", {
					Parent = mainButton,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -22, 0.5, 0),
					Size = UDim2.fromOffset(72, 12),
					Text = tostring(current):lower(),
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Right
				})
				BindTheme(valueLabel, "TextColor3", "Dim")

				local arrow = New("TextLabel", {
					Parent = mainButton,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.fromOffset(10, 10),
					Text = "▾",
					Font = Enum.Font.Code,
					TextSize = 12,
					TextColor3 = Library.Theme.Faint
				})
				BindTheme(arrow, "TextColor3", "Faint")

				New("UIListLayout", {Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder})

				mainButton.MouseEnter:Connect(function()
					Tween(frame, {BackgroundTransparency = 0.02}, 0.08)
					Tween(nameLabel, {TextColor3 = Library.Theme.Text}, 0.08)
					Tween(valueLabel, {TextColor3 = Library.Theme.Text}, 0.08)
				end)
				mainButton.MouseLeave:Connect(function()
					if not open then Tween(frame, {BackgroundTransparency = 0}, 0.08) end
					Tween(nameLabel, {TextColor3 = Library.Theme.Dim}, 0.08)
					Tween(valueLabel, {TextColor3 = Library.Theme.Dim}, 0.08)
				end)

				local item = {}

				function item:Set(v)
					current = v
					Library.Flags[flag] = v
					valueLabel.Text = tostring(v):lower()
					if callback then callback(v) end
				end

				function item:Get() return current end

				for i, value in ipairs(values) do
					local opt = New("TextButton", {
						Parent = frame,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 16),
						Text = "   " .. tostring(value):lower(),
						Font = Enum.Font.Code,
						TextSize = 10,
						TextColor3 = Library.Theme.Dim,
						AutoButtonColor = false,
						LayoutOrder = i + 1,
						TextXAlignment = Enum.TextXAlignment.Left
					})
					BindTheme(opt, "TextColor3", "Dim")
					opt.MouseEnter:Connect(function() Tween(opt, {TextColor3 = Library.Theme.Text}, 0.08) end)
					opt.MouseLeave:Connect(function() Tween(opt, {TextColor3 = Library.Theme.Dim}, 0.08) end)
					opt.MouseButton1Click:Connect(function()
						item:Set(value)
						open = false
						arrow.Text = "▾"
						Tween(frame, {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 0}, 0.12)
						task.defer(resize)
					end)
				end

				mainButton.MouseButton1Click:Connect(function()
					open = not open
					arrow.Text = open and "▴" or "▾"
					Tween(frame, {Size = UDim2.new(1, 0, 0, open and (20 + #values * 16) or 20), BackgroundTransparency = open and 0.02 or 0}, 0.12)
					task.defer(resize)
				end)

				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			function api:Keybind(text, defaultKey, mode, callback)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					defaultKey = Data.Default or Data.default or Data.Key or Data.key or defaultKey
					mode = Data.Mode or Data.mode or mode
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "keybind"
				end
				local key = KeyFromValue(defaultKey)
				local flag = flagOverride or string.lower(text):gsub("%s+", "_")
				mode = string.lower(tostring(mode or "toggle"))
				if mode ~= "hold" and mode ~= "always" then mode = "toggle" end
				local waiting = false

				local row = New("Frame", {
					Parent = holder,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16)
				})

				local label = New("TextLabel", {
					Parent = row,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, -58, 1, 0),
					Text = string.lower(text),
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left
				})
				BindTheme(label, "TextColor3", "Dim")

				local keyButton = New("TextButton", {
					Parent = row,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(42, 15),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false
				})

				local keyButtonBack = New("Frame", {
					Parent = keyButton,
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ZIndex = 1,
					ClipsDescendants = true
				})
				ApplyControlGradient(keyButtonBack)
				Stroke(keyButtonBack, Library.Theme.Outline2, 1, "Outline2")
				AddReflection(keyButtonBack, 1)

				local keyButtonLabel = New("TextLabel", {
					Parent = keyButton,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					Text = key and key.Name:lower() or "none",
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = key and Library.Theme.Text or Library.Theme.Faint,
					ZIndex = 2
				})
				BindTheme(keyButtonLabel, "TextColor3", key and "Text" or "Faint")
				AnimateButton(keyButton)

				row.MouseEnter:Connect(function() Tween(label, {TextColor3 = Library.Theme.Text}, 0.08) end)
				row.MouseLeave:Connect(function() Tween(label, {TextColor3 = Library.Theme.Dim}, 0.08) end)
				keyButton.MouseEnter:Connect(function() Tween(keyButtonBack, {BackgroundTransparency = 0.03}, 0.08) end)
				keyButton.MouseLeave:Connect(function() Tween(keyButtonBack, {BackgroundTransparency = 0}, 0.08) end)

				local currentMode = string.lower(mode or "toggle")
				if currentMode ~= "toggle" and currentMode ~= "hold" and currentMode ~= "always" then
					currentMode = "toggle"
				end

				local bind = {
					Name = string.lower(text),
					Key = key,
					Mode = currentMode,
					State = currentMode == "always",
					Callback = callback,
					Button = keyButton,
					Flag = flag
				}

				Library.Keybinds[flag] = bind
				Library.Flags[flag] = bind.State
				Library.Flags[flag .. "_key"] = key
				Library.Flags[flag .. "_mode"] = bind.Mode
				if bind.Mode == "always" and bind.Callback then
					task.defer(function()
						bind.Callback(true)
					end)
				end
				Library:RefreshKeybinds()

				local item = {}

				function item:Set(newKey)
					if typeof(newKey) == "EnumItem" then
						key = newKey
						bind.Key = key
						Library.Flags[flag .. "_key"] = key
						keyButtonLabel.Text = key.Name:lower()
						keyButtonLabel.TextColor3 = Library.Theme.Text
						if flag == "menu" or flag == "MenuKeybind" then Library.MenuKey = key; Library.MenuKeybind = tostring(key) end
						Library:RefreshKeybinds()
					end
				end

				function item:Get() return key end

				function item:SetMode(newMode)
					newMode = string.lower(tostring(newMode or "toggle"))
					if newMode ~= "toggle" and newMode ~= "hold" and newMode ~= "always" then
						newMode = "toggle"
					end

					local wasAlways = bind.Mode == "always"
					bind.Mode = newMode
					Library.Flags[flag .. "_mode"] = bind.Mode

					if newMode == "always" then
						bind.State = true
						if bind.Callback then bind.Callback(true) end
					elseif wasAlways then
						bind.State = false
						if bind.Callback then bind.Callback(false) end
					elseif newMode == "hold" then
						bind.State = false
					end
					Library.Flags[flag] = bind.State

					Library:RefreshKeybinds()
				end

				function item:GetMode()
					return bind.Mode
				end

				local modeDropdownOpen = false
				local modeDropdown = New("Frame", {
					Parent = row,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 1, 3),
					Size = UDim2.fromOffset(62, 52),
					BackgroundColor3 = Library.Theme.Bg2,
					BorderSizePixel = 0,
					Visible = false,
					Active = true,
					ZIndex = 60
				})
				Stroke(modeDropdown, Library.Theme.Outline, 1, "Outline")

				local modeDropdownInner = New("Frame", {
					Parent = modeDropdown,
					Position = UDim2.fromOffset(3, 3),
					Size = UDim2.new(1, -6, 1, -6),
					BackgroundColor3 = Library.Theme.Bg,
					BorderSizePixel = 0,
					ZIndex = 61
				})
				Stroke(modeDropdownInner, Library.Theme.Outline2, 1, "Outline2")

				local function pointInside(guiObject, point)
					local pos, size = guiObject.AbsolutePosition, guiObject.AbsoluteSize
					return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
				end

				local function setModeDropdownOpen(state)
					modeDropdownOpen = state and true or false
					modeDropdown.Visible = modeDropdownOpen
				end

				local modeOptions = {"toggle", "hold", "always"}
				for idx, modeName in ipairs(modeOptions) do
					local opt = New("TextButton", {
						Parent = modeDropdownInner,
						Position = UDim2.fromOffset(3, 2 + ((idx - 1) * 15)),
						Size = UDim2.new(1, -6, 0, 14),
						BackgroundTransparency = 1,
						Text = modeName,
						Font = Enum.Font.Code,
						TextSize = 10,
						TextColor3 = Library.Theme.Dim,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = false,
						ZIndex = 62
					})
					opt.MouseEnter:Connect(function()
						Tween(opt, {TextColor3 = Library.Theme.Text}, 0.08)
					end)
					opt.MouseLeave:Connect(function()
						Tween(opt, {TextColor3 = (bind.Mode == modeName and Library.Theme.Accent or Library.Theme.Dim)}, 0.08)
					end)
					opt.MouseButton1Click:Connect(function()
						item:SetMode(modeName)
						for _, child in ipairs(modeDropdownInner:GetChildren()) do
							if child:IsA("TextButton") then
								child.TextColor3 = (child.Text == bind.Mode and Library.Theme.Accent or Library.Theme.Dim)
							end
						end
						setModeDropdownOpen(false)
					end)
				end

				local function refreshModeDropdownColors()
					for _, child in ipairs(modeDropdownInner:GetChildren()) do
						if child:IsA("TextButton") then
							child.TextColor3 = (child.Text == bind.Mode and Library.Theme.Accent or Library.Theme.Dim)
						end
					end
				end

				keyButton.MouseButton2Click:Connect(function()
					if waiting then return end
					refreshModeDropdownColors()
					setModeDropdownOpen(not modeDropdownOpen)
				end)

				AddConnection(UIS.InputBegan, function(input, gp)
					if gp or not modeDropdownOpen then return end
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
						local pos = input.Position
						if not pointInside(modeDropdown, pos) and not pointInside(keyButton, pos) then
							setModeDropdownOpen(false)
						end
					end
				end)

				keyButton.MouseButton1Click:Connect(function()
					if waiting then return end
					waiting = true
					keyButtonLabel.Text = "..."
					Tween(keyButtonBack, {BackgroundTransparency = 0.03}, 0.08)
					local temp
					temp = UIS.InputBegan:Connect(function(input, gp)
						if gp then return end
						if input.UserInputType == Enum.UserInputType.Keyboard then
							item:Set(input.KeyCode)
							waiting = false
							Tween(keyButtonBack, {BackgroundTransparency = 0}, 0.08)
							temp:Disconnect()
						elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
							item:Set(input.UserInputType)
							waiting = false
							Tween(keyButtonBack, {BackgroundTransparency = 0}, 0.08)
							temp:Disconnect()
						end
					end)
				end)

				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			function api:ColorPicker(text, default, callback)
				local flagOverride
				if typeof(text) == "table" then
					local Data = text
					flagOverride = Data.Flag or Data.flag
					default = Data.Default or Data.default or default
					callback = Data.Callback or Data.callback or callback
					text = Data.Name or Data.name or Data.Text or Data.text or "colorpicker"
				end
				local currentColor = default or Library.Theme.Accent
				local flag = flagOverride or string.lower(text)

				local frame = New("Frame", {
					Parent = holder,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = Library.Theme.ControlTop,
					BorderSizePixel = 0,
					ClipsDescendants = false
				})
				ApplyControlGradient(frame)
				Stroke(frame, Library.Theme.Outline2, 1, "Outline2")
				local frameReflect = AddReflection(frame, 1)
				frameReflect.ZIndex = 1
				frameReflect.Active = false

				local button = New("TextButton", {
					Parent = frame,
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 3
				})

				local label = New("TextLabel", {
					Parent = button,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(6, 0),
					Size = UDim2.new(1, -46, 1, 0),
					Text = flag,
					Font = Enum.Font.Code,
					TextSize = 10,
					TextColor3 = Library.Theme.Dim,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 4
				})
				BindTheme(label, "TextColor3", "Dim")

				local preview = New("TextButton", {
					Parent = button,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -7, 0.5, 0),
					Size = UDim2.fromOffset(26, 12),
					BackgroundColor3 = currentColor,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
					Active = true,
					ZIndex = 5
				})
				Stroke(preview, Library.Theme.Outline2, 1, "Outline2")

				local picker = CreateFloatingColorPicker(preview, currentColor, function(newColor)
					currentColor = newColor
					Library.Flags[flag] = newColor
					if callback then callback(newColor) end
				end)

				button.MouseEnter:Connect(function()
					Tween(frame, {BackgroundTransparency = 0.02}, 0.08)
					Tween(label, {TextColor3 = Library.Theme.Text}, 0.08)
				end)
				button.MouseLeave:Connect(function()
					if not picker:IsOpen() then
						Tween(frame, {BackgroundTransparency = 0}, 0.08)
					end
					Tween(label, {TextColor3 = Library.Theme.Dim}, 0.08)
				end)

				local lastToggle = 0
				local function toggleOpen()
					local now = os.clock()
					if now - lastToggle < 0.18 then return end
					lastToggle = now
					picker:Toggle()
				end

				button.MouseButton1Click:Connect(toggleOpen)
				preview.MouseButton1Click:Connect(toggleOpen)
				frameReflect.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						toggleOpen()
					end
				end)

				local item = {}
				function item:Set(value)
					local newColor = typeof(value) == "Color3" and value or ColorFromHex(value)
					if newColor then
						currentColor = newColor
						picker:Set(newColor)
					end
				end
				function item:Get()
					return currentColor
				end

				Library.Flags[flag] = currentColor
				Library.Items[flag] = item
				task.defer(resize)
				return item
			end

			local RawButton = api.Button
			function api:Button(Data, Callback)
				if Data == nil then
					local Group = {}
					function Group:Add(Name, PressCallback)
						return RawButton(api, {Name = Name, Callback = PressCallback})
					end
					return Group
				end
				if typeof(Data) == "table" and Data.Name and Data.Callback then
					local Group = {}
					function Group:Add(Name, PressCallback)
						return RawButton(api, {Name = Name, Callback = PressCallback})
					end
					RawButton(api, Data)
					return Group
				end
				return RawButton(self, Data, Callback)
			end

			function api:Searchbox(Data)
				Data = Data or {}
				local currentItems = Data.Items or Data.items or {}
				local item = api:Dropdown({
					Name = Data.Name or Data.name or "Searchbox",
					Flag = Data.Flag or Data.flag,
					Items = currentItems,
					Default = Data.Default or Data.default or currentItems[1],
					Callback = Data.Callback or Data.callback
				})
				function item:Refresh(newItems)
					currentItems = newItems or currentItems
				end
				return item
			end

			api.Colorpicker = api.ColorPicker
			api.TextBox = api.Textbox

			return api
		end

		return tab
	end

	function window:Page(Data)
		Data = Data or {}
		local page = self:Tab(Data.Name or Data.name or Data.Title or Data.title or "page")
		page.Columns = Data.Columns or Data.columns or 2
		page.SubPages = {}
		function page:SubPage(SubData)
			SubData = SubData or {}
			local subPage = self
			subPage.Name = SubData.Name or SubData.name or subPage.Name
			return subPage
		end
		return page
	end

	function window:Notify(Data, Duration)
		return Library:Notify(Data, Duration)
	end

	LinoriaCompatWrapWindow(window)
	self.CurrentWindow = window
	self.Gui = gui
	return window
end

function Library:Window(Data)
	Data = Data or {}
	local window = self:CreateWindow({
		Title = Data.Name or Data.name or Data.Title or Data.title or "junt.hax.club",
		Size = Data.Size or Data.size or UDim2.fromOffset(560, 500)
	})
	self.CurrentWindow = window
	self.Gui = window.Gui
	return window
end

function Library:Create(Data)
	return self:Window(Data)
end



function Library:Notification(title, message, duration)
	if duration ~= nil then
		return self:Notify({Title = title, Text = message, Duration = duration})
	end
	return self:Notify(title, message)
end

function Library:Watermark(text)
	self.WatermarkText = tostring(text or "")
	local obj = {}
	function obj:Set(value)
		Library.WatermarkText = tostring(value or "")
		if Library.CurrentWindow then
			Library.CurrentWindow:SetWatermark(true)
		end
	end
	function obj:SetVisible(state)
		if Library.CurrentWindow then
			Library.CurrentWindow:SetWatermark(state and true or false)
		end
	end
	obj.SetVisibility = obj.SetVisible
	obj.SetText = obj.Set
	obj:Set(self.WatermarkText)
	return obj
end

function Library:KeybindList()
	local obj = {}
	function obj:SetVisible(state)
		if Library.CurrentWindow then
			Library.CurrentWindow:SetKeybindBox(state and true or false)
		end
	end
	obj.SetVisibility = obj.SetVisible
	function obj:Refresh()
		Library:RefreshKeybinds()
	end
	obj:SetVisible(true)
	return obj
end

function Library:ArmorViewer()
	local obj = {Visible = false}
	function obj:SetVisible(state)
		self.Visible = state and true or false
	end
	function obj:SetPlayer(player)
		self.Player = player
	end
	return obj
end

function Library:TargetHud()
	local obj = {Player = nil, Bars = {}}
	function obj:SetPlayer(player)
		self.Player = player
	end
	function obj:AddBar(color)
		local bar = {Color = color or Library.Theme.Accent, Percentage = 100}
		function bar:SetPercentage(value)
			self.Percentage = math.clamp(tonumber(value) or 0, 0, 100)
		end
		table.insert(self.Bars, bar)
		return bar
	end
	function obj:SetVisible(state)
		self.Visible = state and true or false
	end
	return obj
end

function Library:CreateSettingsPage(window, watermark, keybindList)
	window = window or self.CurrentWindow
	if not window then return nil end
	LinoriaCompatWrapWindow(window)

	local tab = window:AddTab("UI Settings")
	local configBox = tab:AddLeftGroupbox("Config Manager")
	local themeBox = tab:AddRightGroupbox("Theme Editor")
	local utilityBox = tab:AddRightGroupbox("Utilities")

	local selectedConfig = "default"
	local nameInput = configBox:AddInput("config_name", {
		Text = "Config name",
		Default = selectedConfig,
		Finished = true,
		Callback = function(value)
			selectedConfig = Library:SanitizeConfigName(value)
		end
	})

	local savedList
	local function refreshConfigs()
		local configs = Library:ListConfigs()
		if savedList and savedList.Refresh then
			pcall(function() savedList:Refresh(configs) end)
		end
	end

	savedList = configBox:AddDropdown("config_list", {
		Text = "Saved configs",
		Values = Library:ListConfigs(),
		AllowNull = true,
		Callback = function(value)
			if value and value ~= "" then
				selectedConfig = Library:SanitizeConfigName(value)
				if nameInput and nameInput.SetValue then
					nameInput:SetValue(selectedConfig)
				end
			end
		end
	})

	configBox:AddButton({Text = "Save", Func = function()
		Library:SaveConfig(selectedConfig)
		refreshConfigs()
	end}):AddButton({Text = "Load", Func = function()
		Library:LoadConfig(selectedConfig)
	end})

	configBox:AddButton({Text = "Delete", Func = function()
		Library:DeleteConfig(selectedConfig)
		refreshConfigs()
	end}):AddButton({Text = "Refresh", Func = refreshConfigs})

	utilityBox:AddButton({Text = "Test notification", Func = function()
		Library:Notify("Notification test", 3)
	end})
	utilityBox:AddButton({Text = "Unload", Func = function()
		Library:Unload()
	end})

	local themeItems = {
		{"Accent", "Accent"},
		{"Background", "Bg"},
		{"Background 2", "Bg2"},
		{"Background 3", "Bg3"},
		{"Control top", "ControlTop"},
		{"Control bottom", "ControlBottom"},
		{"Text", "Text"},
		{"Dim text", "Dim"},
		{"Faint text", "Faint"},
		{"Outline", "Outline"},
		{"Outline 2", "Outline2"},
	}

	for _, data in ipairs(themeItems) do
		local label, key = data[1], data[2]
		themeBox:AddLabel(label):AddColorPicker("theme_" .. string.gsub(string.lower(label), "%s+", "_"), {
			Title = label,
			Default = Library.Theme[key],
			Callback = function(color)
				Library:SetTheme(key, color)
			end
		})
	end

	refreshConfigs()
	return tab
end

Library.CreateSettingsTab = Library.CreateSettingsPage
Library.CreateSettings = Library.CreateSettingsPage

getgenv().Library = Library
return Library
