local ThemeManager = {
	Library = nil,
	Folder = "themes"
}

function ThemeManager:SetLibrary(library)
	self.Library = library
	return self
end

function ThemeManager:SetFolder(folder)
	self.Folder = tostring(folder or self.Folder)
	return self
end

local function applyColor(library, key, color)
	if library and library.SetTheme then
		library:SetTheme(key, color)
	elseif library then
		library[key] = color
		if library.UpdateColorsUsingRegistry then
			library:UpdateColorsUsingRegistry()
		end
	end
end

function ThemeManager:ApplyToTab(tab)
	local library = self.Library or getgenv().Library
	if not tab or not tab.AddRightGroupbox then return self end
	local box = tab:AddRightGroupbox("Theme")
	if box.AddDivider then box:AddDivider() end
	local themes = {
		{"Accent", "Accent"},
		{"Background", "Bg"},
		{"Background 2", "Bg2"},
		{"Text", "Text"},
		{"Dim Text", "Dim"},
		{"Outline", "Outline"},
	}
	for _, item in ipairs(themes) do
		local name, key = item[1], item[2]
		local default = library and library.Theme and library.Theme[key] or Color3.fromRGB(255, 255, 255)
		box:AddLabel(name):AddColorPicker("theme_" .. string.lower(name):gsub("%s+", "_"), {
			Title = name,
			Default = default,
			Callback = function(color)
				applyColor(library, key, color)
			end
		})
	end
	return self
end

return ThemeManager
