local ThemeManager = {
    Library = nil,
    Folder = "LinoriaLib",
    Built = false,
}

function ThemeManager:SetLibrary(lib)
    self.Library = lib
    if lib and not lib.ThemeManager then
        lib.ThemeManager = self
    end
end

function ThemeManager:SetFolder(folder)
    self.Folder = folder or self.Folder
end

function ThemeManager:GetLibrary()
    return self.Library or getgenv().Library or Library
end

local function callIf(obj, names, ...)
    for _, name in ipairs(names) do
        if obj and type(obj[name]) == "function" then
            return obj[name](obj, ...)
        end
    end
end

function ThemeManager:ApplyTheme(theme)
    local lib = self:GetLibrary()
    if type(theme) == "table" and lib then
        for key, value in pairs(theme) do
            if typeof(value) == "Color3" then
                lib[key] = value
                callIf(lib, {"SetTheme", "ChangeTheme", "UpdateColorsUsingRegistry"}, key, value)
            end
        end
        if type(lib.UpdateColorsUsingRegistry) == "function" then
            lib:UpdateColorsUsingRegistry()
        end
    end
end

function ThemeManager:ApplyToTab(tab)
    self.Built = true
    local lib = self:GetLibrary()
    if not tab then return self end

    local box
    if type(tab.AddLeftGroupbox) == "function" then
        box = tab:AddLeftGroupbox("Theme")
    elseif type(tab.AddRightGroupbox) == "function" then
        box = tab:AddRightGroupbox("Theme")
    elseif type(tab.Section) == "function" then
        box = tab:Section({Name = "Theme", Side = 1})
    end

    if box then
        local accentDefault = lib and (lib.AccentColor or lib.Theme and (lib.Theme.Accent or lib.Theme.AccentColor)) or Color3.fromRGB(211, 170, 182)
        if type(box.AddLabel) == "function" then
            local label = box:AddLabel("Accent")
            if label and type(label.AddColorPicker) == "function" then
                label:AddColorPicker("AccentColor", {
                    Default = accentDefault,
                    Title = "Accent",
                    Callback = function(color)
                        if lib then
                            lib.AccentColor = color
                            if lib.Theme then lib.Theme.Accent = color end
                            if type(lib.UpdateColorsUsingRegistry) == "function" then lib:UpdateColorsUsingRegistry() end
                        end
                    end
                })
            end
        elseif type(box.ColorPicker) == "function" then
            box:ColorPicker({Name = "Accent", Flag = "AccentColor", Default = accentDefault})
        end
    end

    return self
end

return ThemeManager
