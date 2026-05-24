local HttpService = game:GetService("HttpService")

local SaveManager = {
    Library = nil,
    Folder = "LinoriaLib",
    SubFolder = "configs",
    Ignore = {},
    Built = false,
    SelectedConfig = "default",
}

function SaveManager:SetLibrary(lib)
    self.Library = lib
    if lib and not lib.SaveManager then
        lib.SaveManager = self
    end
end

function SaveManager:SetFolder(folder)
    self.Folder = folder or self.Folder
    self:BuildFolders()
end

function SaveManager:SetSubFolder(folder)
    self.SubFolder = folder or self.SubFolder
    self:BuildFolders()
end

function SaveManager:IgnoreThemeSettings()
    return self
end

function SaveManager:SetIgnoreIndexes(list)
    self.Ignore = {}
    if type(list) == "table" then
        for _, key in ipairs(list) do
            self.Ignore[key] = true
        end
    end
    return self
end

function SaveManager:GetLibrary()
    return self.Library or getgenv().Library or Library
end

function SaveManager:GetFolderPath()
    return tostring(self.Folder) .. "/" .. tostring(self.SubFolder)
end

function SaveManager:BuildFolders()
    if isfolder and makefolder then
        if not isfolder(self.Folder) then pcall(makefolder, self.Folder) end
        local path = self:GetFolderPath()
        if not isfolder(path) then pcall(makefolder, path) end
    end
end

function SaveManager:GetPath(name)
    self:BuildFolders()
    name = tostring(name or self.SelectedConfig or "default")
    if not name:match("%.json$") then name = name .. ".json" end
    return self:GetFolderPath() .. "/" .. name
end

function SaveManager:GetConfig()
    local lib = self:GetLibrary()
    if lib and type(lib.GetConfig) == "function" then
        return lib:GetConfig()
    end
    local data = {}
    local flags = lib and lib.Flags or getgenv().Options or {}
    for key, value in pairs(flags or {}) do
        if not self.Ignore[key] then
            if typeof(value) == "Color3" then
                data[key] = {Color = value:ToHex()}
            elseif type(value) ~= "function" and typeof(value) ~= "Instance" then
                data[key] = value
            end
        end
    end
    return HttpService:JSONEncode(data)
end

function SaveManager:LoadConfigString(str)
    local lib = self:GetLibrary()
    if lib and type(lib.LoadConfig) == "function" then
        return lib:LoadConfig(str)
    end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(str) end)
    if not ok then return false, decoded end
    local setFlags = lib and lib.SetFlags or {}
    for key, value in pairs(decoded) do
        if type(setFlags[key]) == "function" then
            pcall(setFlags[key], value)
        elseif lib and lib.Flags then
            lib.Flags[key] = value
        end
    end
    return true
end

function SaveManager:Save(name)
    name = name or self.SelectedConfig
    local path = self:GetPath(name)
    if writefile then
        writefile(path, self:GetConfig())
    end
    return true
end

function SaveManager:Load(name)
    name = name or self.SelectedConfig
    local path = self:GetPath(name)
    if isfile and readfile and isfile(path) then
        return self:LoadConfigString(readfile(path))
    end
    return false, "config not found"
end

function SaveManager:Delete(name)
    name = name or self.SelectedConfig
    local path = self:GetPath(name)
    if isfile and delfile and isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function SaveManager:RefreshConfigList()
    local path = self:GetFolderPath()
    local list = {}
    if listfiles and isfolder and isfolder(path) then
        for _, file in ipairs(listfiles(path)) do
            local clean = file:gsub("\\", "/"):match("([^/]+)%.json$")
            if clean then table.insert(list, clean) end
        end
    end
    table.sort(list)
    return list
end

function SaveManager:BuildConfigSection(tab)
    self.Built = true
    local box
    if tab and type(tab.AddLeftGroupbox) == "function" then
        box = tab:AddLeftGroupbox("Configs")
    elseif tab and type(tab.AddRightGroupbox) == "function" then
        box = tab:AddRightGroupbox("Configs")
    elseif tab and type(tab.Section) == "function" then
        box = tab:Section({Name = "Configs", Side = 1})
    end
    if not box then return self end

    local input
    if type(box.AddInput) == "function" then
        input = box:AddInput("ConfigName", {
            Text = "Config name",
            Default = self.SelectedConfig,
            Callback = function(v) self.SelectedConfig = tostring(v or "default") end,
        })
        box:AddButton({Text = "Save", Func = function() self:Save(self.SelectedConfig) end})
        box:AddButton({Text = "Load", Func = function() self:Load(self.SelectedConfig) end})
        box:AddButton({Text = "Delete", Func = function() self:Delete(self.SelectedConfig) end})
    elseif type(box.Textbox) == "function" then
        input = box:Textbox({Name = "Config name", Flag = "ConfigName", Default = self.SelectedConfig, Callback = function(v) self.SelectedConfig = tostring(v or "default") end})
        box:Button({Name = "Save", Callback = function() self:Save(self.SelectedConfig) end})
        box:Button({Name = "Load", Callback = function() self:Load(self.SelectedConfig) end})
        box:Button({Name = "Delete", Callback = function() self:Delete(self.SelectedConfig) end})
    end
    return self
end

function SaveManager:LoadAutoloadConfig()
    return self:Load("autoload")
end

return SaveManager
