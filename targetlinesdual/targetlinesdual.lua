addon.name    = 'targetlinesdual';
addon.author  = 'Jyouya; persistent-target changes for SHYNX';
addon.version = '0.1.1-test';
addon.desc    = 'FFXII style action lines with a selected-target overlay';

require('common');

local drawArc  = require('drawArc');
local arcs     = require('tracker');
local helpers  = require('helpers');
local settings = require('settings');

local config   = require('config');

local s        = settings.get();
settings.register('settings', 'targetlinesdual_settings_cb', function(updated)
    s = updated;
end);

local playerId = nil;
local sessionGeneration = nil;


local function getArcsForIndex(targetIndex, res)
    res = res or T {};
    for k, v in pairs(arcs) do
        if (k == targetIndex or v.dst == targetIndex) then
            if (not res[k]) then
                res[k] = v;
                getArcsForIndex(v.dst, res);
            end
        end
    end

    return res;
end

local function getPartyArcs(alliance)
    local party = AshitaCore:GetMemoryManager():GetParty()
    local res = T {};
    for i = 0, alliance and 17 or 5 do
        if (party:GetMemberIsActive(i) ~= 0) then
            local targetIndex = party:GetMemberTargetIndex(i);
            getArcsForIndex(targetIndex, res);
        end
    end

    return res;
end

local color    = T {
    player = 0xFF0088FF,
    enemy = 0xFFFF1133,
    playerFriendly = 0xFF00FF66,
    enemyFriendly = 0xFFFF8800
};
-- pet color 0xFFFF00AA

local timeouts = T {
    player = 10,
    enemy = 10,
    playerFriendly = 5,
    enemyFriendly = 5
};

-- Cyan reads only the active selection; it never reads or changes action arcs.
-- Slot 0 is the current cursor, including the active sub-target cursor.
local function drawSelectedTargetLine()
    if (not s.persistent.selected.enabled[1]) then return; end
    local memory = AshitaCore:GetMemoryManager();
    local entity = memory:GetEntity();
    local source = memory:GetParty():GetMemberTargetIndex(0);
    local target = memory:GetTarget();
    if (not target:GetIsActive(0) or target:GetIsActive(0) == 0) then return; end
    local index = target:GetTargetIndex(0);
    local id = target:GetServerId(0);
    if (source == index or not helpers.isDrawableIndex(source) or not helpers.isDrawableIndex(index)
        or not id or id == 0 or entity:GetServerId(index) ~= id
        or target:GetActorPointer(0) ~= entity:GetActorPointer(index)) then return; end
    local sourceStatus, targetStatus = entity:GetStatus(source), entity:GetStatus(index);
    if (sourceStatus == nil or targetStatus == nil or sourceStatus == 2 or sourceStatus == 3
        or targetStatus == 2 or targetStatus == 3) then return; end

    local x1, y1, z1 = helpers.getActorPoint(source);
    local x2, y2, z2 = helpers.getActorPoint(index);
    if (not x1 or not x2) then return; end
    -- Recheck selection identity after reading positions; never retain a target object.
    if (target:GetIsActive(0) == 0 or target:GetTargetIndex(0) ~= index
        or target:GetServerId(0) ~= id or entity:GetServerId(index) ~= id) then return; end
    drawArc(x1, y1, z1, x2, y2, z2, s.persistent.selected.color, 1, false, s.persistent.selected.width[1]);
end

ashita.events.register('load', 'load_cb', function()
    ashita.events.register('d3d_present', 'present_cb', function()
        local entity = AshitaCore:GetMemoryManager():GetEntity();
        local party = AshitaCore:GetMemoryManager():GetParty();
        if (helpers.zoning or AshitaCore:GetMemoryManager():GetPlayer():GetLoginStatus() ~= 2
            or party:GetMemberIsActive(0) == 0) then
            for src in pairs(arcs) do arcs[src] = nil; end
            playerId = nil; sessionGeneration = nil;
            return;
        end
        local sourceIndex = party:GetMemberTargetIndex(0);
        if (not helpers.isDrawableIndex(sourceIndex)) then
            for src in pairs(arcs) do arcs[src] = nil; end
            playerId = nil; sessionGeneration = nil;
            return;
        end
        local currentId = entity:GetServerId(sourceIndex);
        if (currentId == nil or currentId == 0) then
            for src in pairs(arcs) do arcs[src] = nil; end
            playerId = nil; sessionGeneration = nil;
            return;
        end
        -- The tracker already clears on zone packets; retain any new-zone actions.
        if (playerId ~= nil and playerId ~= currentId and sessionGeneration == helpers.sessionGeneration) then
            for src in pairs(arcs) do arcs[src] = nil; end
        end
        playerId = currentId; sessionGeneration = helpers.sessionGeneration;
        for src, v in pairs(arcs) do
            if (not helpers.isDrawableIndex(src) or not helpers.isDrawableIndex(v.dst)
                or entity:GetServerId(src) ~= v.srcId or entity:GetServerId(v.dst) ~= v.dstId
                or os.clock() - v.clock > timeouts[v.color]) then
                arcs[src] = nil;
            end
        end
        local filteredArcs
        if (s.filter == 'All') then
            filteredArcs = arcs;
        else
            filteredArcs = getPartyArcs(s.filters == 'Alliance');
        end

        for src, v in pairs(filteredArcs) do
            local dTime = os.clock() - v.clock;
            local timeout = timeouts[v.color];

            local dFirstTime = v.firstClock and os.clock() - v.firstClock;

            local lineType = v.color;

            if (dTime > timeout) then
                arcs[src] = nil;
            elseif (lineType == 'player' and dFirstTime and dFirstTime > 2.5) then
                local x2, y2, z2 = helpers.getActorPoint(src);
                local x1, y1, z1 = helpers.getActorPoint(v.dst);
                if (not x1 or not x2) then arcs[src] = nil; goto next_arc; end

                local t = math.max((3 - dFirstTime) * 2, 0);

                if (t > 0) then
                    drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t);
                end
            elseif (dTime > timeout - 0.5) then
                local x2, y2, z2 = helpers.getActorPoint(src);
                local x1, y1, z1 = helpers.getActorPoint(v.dst);
                if (not x1 or not x2) then arcs[src] = nil; goto next_arc; end

                local t = math.min(1 - (0.5 - math.min(timeout - dTime, 1)) * 2, 1);

                drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t);
            else
                local x1, y1, z1 = helpers.getActorPoint(src);
                local x2, y2, z2 = helpers.getActorPoint(v.dst);
                if (not x1 or not x2) then arcs[src] = nil; goto next_arc; end

                local t = math.min(1 - (0.5 - math.min(dTime, 1)) * 2, 1);

                drawArc(x1, y1, z1, x2, y2, z2, color[v.color], t, true);
            end
            ::next_arc::
        end

        drawSelectedTargetLine();
    end);
end);
