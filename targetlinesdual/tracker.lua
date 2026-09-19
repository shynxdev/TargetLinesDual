local arcs = T {};
local helpers = require('helpers');
local playerId;

-- local function isMob(id)
--     return bit.band(id, 0xFF000000) ~= 0;
-- end

local function isMob(spawnFlags)
    return bit.band(spawnFlags, 0x10) ~= 0;
end

local function isPet(spawnFlags)
    return bit.band(spawnFlags, 0x100) ~= 0;
end

local function GetIndexFromId(id)
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();

    --Shortcut for monsters/static npcs..
    if (bit.band(id, 0x1000000) ~= 0) then
        local index = bit.band(id, 0xFFF);
        if (index >= 0x900) then
            index = index - 0x100;
        end

        if (index < 0x900) and (entMgr:GetServerId(index) == id) then
            return index;
        end
    end

    for i = 1, 0x8FF do
        if entMgr:GetServerId(i) == id then
            return i;
        end
    end

    return 0;
end

local timeouts = T {
    player = 10,
    enemy = 10,
    playerFriendly = 5,
    enemyFriendly = 5
};

local function handleActionPacket(e)
    local actorId = ashita.bits.unpack_be(e.data_raw, 0, 40, 32);
    local targetCount = ashita.bits.unpack_be(e.data_raw, 0, 72, 6);
    local targetId = ashita.bits.unpack_be(e.data_raw, 0, 150, 32);

    local type = ashita.bits.unpack_be(e.data_raw, 82, 4);

    if (targetCount > 0 and actorId ~= targetId) then
        local color;

        local actorIndex = GetIndexFromId(actorId);
        local targetIndex = GetIndexFromId(targetId);
        if (actorIndex == 0 or targetIndex == 0 or not helpers.isDrawableIndex(actorIndex) or not helpers.isDrawableIndex(targetIndex)) then return; end

        local actorFlags = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(actorIndex);
        local targetFlags = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(targetIndex);

        if (isMob(actorFlags) and not isPet(actorFlags)) then
            if (isMob(targetFlags)) then
                color = 'enemyFriendly';
            else
                color = 'enemy';
            end
        elseif (isMob(targetFlags)) then
            color = 'player';
        else
            color = 'playerFriendly';
        end

        local clock = os.clock();
        local firstClock = clock;
        if (arcs[actorIndex] and arcs[actorIndex].srcId == actorId) then
            local arc = arcs[actorIndex];

            if (type == 4 and color == 'playerFriendly') then
                clock = clock - timeouts.playerFriendly + 0.5;
            elseif (arc.dst == targetIndex and arc.dstId == targetId and os.clock() - arc.clock < timeouts[color]) then
                if (arc.color == 'player') then
                    -- clock = arc.clock;
                    firstClock = arc.firstClock or clock;
                end
                clock = clock - 1;
            end
        end


        arcs[actorIndex] = {
            dst = targetIndex,
            srcId = actorId,
            dstId = targetId,
            clock = clock,
            color = color,
            firstClock = firstClock
        };
    end
end

local deathMes = T { 6, 20, 97, 113, 406, 605, 646 };
local function handleMessagePacket(data)
    local message = struct.unpack('i2', data, 0x18 + 1);

    if (deathMes:contains(message)) then
        local target = struct.unpack('i2', data, 0x16 + 1);
        local targetId = struct.unpack('I4', data, 0x08 + 1);

        for src, arc in pairs(arcs) do
            if ((src == target and arc.srcId == targetId) or (arc.dst == target and arc.dstId == targetId)) then
                arc.clock = os.clock() - timeouts[arc.color] + 0.5;
            end
        end
    end
end

ashita.events.register('packet_in', 'action_tracker_cb', function(e)
    if (e.id == 0x000A or e.id == 0x000B) then
        helpers.zoning = e.id == 0x000B;
        helpers.sessionGeneration = helpers.sessionGeneration + 1;
        playerId = nil;
        for src in pairs(arcs) do arcs[src] = nil; end
        return;
    end
    if (e.id ~= 0x0028 and e.id ~= 0x0029) then return; end
    local memory = AshitaCore:GetMemoryManager();
    if (helpers.zoning or memory:GetPlayer():GetLoginStatus() ~= 2) then
        for src in pairs(arcs) do arcs[src] = nil; end
        playerId = nil;
        return;
    end
    local sourceIndex = memory:GetParty():GetMemberTargetIndex(0);
    if (memory:GetParty():GetMemberIsActive(0) == 0 or not helpers.isDrawableIndex(sourceIndex)) then
        for src in pairs(arcs) do arcs[src] = nil; end
        playerId = nil;
        return;
    end
    local currentId = memory:GetEntity():GetServerId(sourceIndex);
    if (playerId ~= nil and playerId ~= currentId) then
        for src in pairs(arcs) do arcs[src] = nil; end
    end
    playerId = currentId;
    if (type(e.data) ~= 'string') then return; end
    if (e.id == 0x0028 and #e.data >= 23) then
        handleActionPacket(e);
    elseif (e.id == 0x0029 and #e.data >= 26) then
        handleMessagePacket(e.data);
    end
end);

return arcs;
