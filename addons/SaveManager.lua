local SaveManager = {
	Library = nil,
	Folder = "configs",
	Ignore = {},
	IgnoreTheme = false
}

function SaveManager:SetLibrary(library)
	self.Library = library
	return self
end

function SaveManager:IgnoreThemeSettings()
	self.IgnoreTheme = true
	return self
end

function SaveManager:SetIgnoreIndexes(indexes)
	self.Ignore = {}
	for _, value in ipairs(indexes or {}) do
		self.Ignore[value] = true
	end
	return self
end

function SaveManager:SetFolder(folder)
	self.Folder = tostring(folder or self.Folder)
	local library = self.Library or getgenv().Library
	if library then
		library.ConfigFolder = self.Folder
		if library.EnsureConfigFolder then library:EnsureConfigFolder() end
	end
	return self
end

function SaveManager:GetConfigs()
	local library = self.Library or getgenv().Library
	if library and library.ListConfigs then
		return library:ListConfigs()
	end
	return {}
end

function SaveManager:Save(name)
	local library = self.Library or getgenv().Library
	if library and library.SaveConfig then
		return library:SaveConfig(name or self.SelectedConfig or "default")
	end
end

function SaveManager:Load(name)
	local library = self.Library or getgenv().Library
	if library and library.LoadConfig then
		return library:LoadConfig(name or self.SelectedConfig or "default")
	end
end

function SaveManager:Delete(name)
	local library = self.Library or getgenv().Library
	if library and library.DeleteConfig then
		return library:DeleteConfig(name or self.SelectedConfig or "default")
	end
end

function SaveManager:BuildConfigSection(tab)
	if not tab or not tab.AddLeftGroupbox then return self end
	local box = tab:AddLeftGroupbox("Configs")
	local selected = self.SelectedConfig or "default"
	local nameInput = box:AddInput("config_name", {
		Text = "Config name",
		Default = selected,
		Finished = true,
		Callback = function(value)
			selected = tostring(value or "default")
			self.SelectedConfig = selected
		end
	})
	local list
	local function refresh()
		local configs = self:GetConfigs()
		if list and list.Refresh then list:Refresh(configs) end
	end
	list = box:AddDropdown("config_list", {
		Text = "Saved configs",
		Values = self:GetConfigs(),
		AllowNull = true,
		Callback = function(value)
			if value then
				selected = tostring(value)
				self.SelectedConfig = selected
				if nameInput and nameInput.SetValue then nameInput:SetValue(selected) end
			end
		end
	})
	box:AddButton({Text = "Save", Func = function()
		self:Save(selected)
		refresh()
	end}):AddButton({Text = "Load", Func = function()
		self:Load(selected)
	end})
	box:AddButton({Text = "Delete", Func = function()
		self:Delete(selected)
		refresh()
	end}):AddButton({Text = "Refresh", Func = refresh})
	refresh()
	return self
end

return SaveManager
