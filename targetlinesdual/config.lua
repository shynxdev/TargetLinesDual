local imgui = require('imgui');
local settings = require('settings');

local defaultSettings = T {
    filter = 'All',
    persistent = T {
        selected = T {
            enabled = T { true },
            color = 0xFF00C8FF,
            width = T { 2.0 }
        }
    }
};

local s = settings.load(defaultSettings);
local function validateSelected()
    if (type(s.persistent) ~= 'table') then s.persistent = T {}; end
    if (type(s.persistent.selected) ~= 'table') then s.persistent.selected = T {}; end
    local selected = s.persistent.selected;
    if (type(selected.enabled) ~= 'table' or type(selected.enabled[1]) ~= 'boolean') then selected.enabled = T { true }; end
    if (type(selected.width) ~= 'table' or type(selected.width[1]) ~= 'number'
        or selected.width[1] ~= selected.width[1]) then selected.width = T { 2.0 }; end
    selected.width[1] = math.max(1, math.min(8, selected.width[1]));
    if (type(selected.color) ~= 'number' or selected.color ~= selected.color
        or selected.color < 0 or selected.color > 0xFFFFFFFF) then selected.color = 0xFF00C8FF; end
    selected.color = math.floor(selected.color);
end
validateSelected();
settings.register('settings', 'config_settings_cb', function(updated)
    s = updated;
    validateSelected();
end);

local filters = T {
    'All',
    'Alliance',
    'Party'
};

local showConfig = { false };
local config = T {};

local function cflip(c)
    local r, b = c[3], c[1];
    c[1] = r;
    c[3] = b;
    return c;
end

local function drawColorEditor(label, owner)
    local color = cflip({ imgui.ColorConvertU32ToFloat4(owner.color) });
    if (imgui.ColorEdit4(label, color)) then
        owner.color = imgui.ColorConvertFloat4ToU32(cflip(color));
        settings.save();
    end
end

config.drawWindow = function()
    if (showConfig[1]) then
        imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_TitleBg, { 0, 0.06, .16, .7 });
        imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0, 0.06, .16, .5 });
        imgui.PushStyleColor(ImGuiCol_Header, { 0, 0.06, .16, .7 });
        imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0, 0.06, .16, .9 });
        imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0, 0.06, .16, 1 });
        imgui.PushStyleColor(ImGuiCol_FrameBg, { 0, 0.06, .16, 1 });
        imgui.SetNextWindowSize({ 470, 330 }, ImGuiCond_FirstUseEver);

        if (imgui.Begin(('TargetLinesDual Config - v%s'):fmt(addon.version), showConfig, bit.bor(ImGuiWindowFlags_NoSavedSettings))) then
            imgui.BeginChild("Config Options", { 0, 0 }, true);
            if (imgui.BeginCombo('Filters', s.filter)) then
                for i = 1, 3 do
                    local isSelected = filters[i] == s.filter;

                    if (imgui.Selectable(filters[i], isSelected) and filters[i] ~= s.filter) then
                        s.filter = filters[i];
                        settings.save();
                    end

                    if (isSelected) then
                        imgui.SetItemDefaultFocus();
                    end
                end
                imgui.EndCombo();
            end

            imgui.Separator();
            imgui.Text('Persistent target lines');

            if (imgui.Checkbox('Selected target line', s.persistent.selected.enabled)) then
                settings.save();
            end
            if (imgui.SliderFloat('Selected line width', s.persistent.selected.width, 1.0, 8.0, '%.1f')) then
                settings.save();
            end
            drawColorEditor('Selected line color', s.persistent.selected);

            imgui.EndChild();
        end
        imgui.PopStyleColor(8);
        imgui.End();
    end
end

ashita.events.register('command', 'command_cb', function(e)
    -- Parse the command arguments
    local command_args = e.command:lower():args()
    if table.contains({ '/targetlinesdual', '/tld' }, command_args[1]) then
        -- Toggle the config menu
        showConfig[1] = not showConfig[1];
        e.blocked = true;
    end
end);

ashita.events.register('d3d_present', 'config_cb', function()
    config.drawWindow();
end);

return config;
