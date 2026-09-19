local ffi = require('ffi');
local d3d = require('d3d8');

local C = ffi.C;
local d3d8dev = d3d.get_device();

local _, viewport = d3d8dev:GetViewport();
local width = viewport and viewport.Width or 0;
local height = viewport and viewport.Height or 0;

local function matrixMultiply(m1, m2)
    return ffi.new('D3DXMATRIX', {
        --
        m1._11 * m2._11 + m1._12 * m2._21 + m1._13 * m2._31 + m1._14 * m2._41,
        m1._11 * m2._12 + m1._12 * m2._22 + m1._13 * m2._32 + m1._14 * m2._42,
        m1._11 * m2._13 + m1._12 * m2._23 + m1._13 * m2._33 + m1._14 * m2._43,
        m1._11 * m2._14 + m1._12 * m2._24 + m1._13 * m2._34 + m1._14 * m2._44,
        --
        m1._21 * m2._11 + m1._22 * m2._21 + m1._23 * m2._31 + m1._24 * m2._41,
        m1._21 * m2._12 + m1._22 * m2._22 + m1._23 * m2._32 + m1._24 * m2._42,
        m1._21 * m2._13 + m1._22 * m2._23 + m1._23 * m2._33 + m1._24 * m2._43,
        m1._21 * m2._14 + m1._22 * m2._24 + m1._23 * m2._34 + m1._24 * m2._44,
        --
        m1._31 * m2._11 + m1._32 * m2._21 + m1._33 * m2._31 + m1._34 * m2._41,
        m1._31 * m2._12 + m1._32 * m2._22 + m1._33 * m2._32 + m1._34 * m2._42,
        m1._31 * m2._13 + m1._32 * m2._23 + m1._33 * m2._33 + m1._34 * m2._43,
        m1._31 * m2._14 + m1._32 * m2._24 + m1._33 * m2._34 + m1._34 * m2._44,
        --
        m1._41 * m2._11 + m1._42 * m2._21 + m1._43 * m2._31 + m1._44 * m2._41,
        m1._41 * m2._12 + m1._42 * m2._22 + m1._43 * m2._32 + m1._44 * m2._42,
        m1._41 * m2._13 + m1._42 * m2._23 + m1._43 * m2._33 + m1._44 * m2._43,
        m1._41 * m2._14 + m1._42 * m2._24 + m1._43 * m2._34 + m1._44 * m2._44,
    });
end

local function vec4Transform(v, m)
    return ffi.new('D3DXVECTOR4', {
        m._11 * v.x + m._21 * v.y + m._31 * v.z + m._41 * v.w,
        m._12 * v.x + m._22 * v.y + m._32 * v.z + m._42 * v.w,
        m._13 * v.x + m._23 * v.y + m._33 * v.z + m._43 * v.w,
        m._14 * v.x + m._24 * v.y + m._34 * v.z + m._44 * v.w,
    });
end

local function worldToScreen(x, y, z, view, projection)
    local vplayer = ffi.new('D3DXVECTOR4', { x, y, z, 1 });

    local viewProj = matrixMultiply(view, projection);

    local pCamera = vec4Transform(vplayer, viewProj);

    if (pCamera.w == 0) then return; end
    local rhw = 1 / pCamera.w;

    local pNDC = ffi.new('D3DXVECTOR3', { pCamera.x * rhw, pCamera.y * rhw, pCamera.z * rhw })

    local pRaster = ffi.new('D3DXVECTOR2');
    pRaster.x = math.floor((pNDC.x + 1) * 0.5 * width);
    pRaster.y = math.floor((1 - pNDC.y) * 0.5 * height);

    return pRaster.x, pRaster.y, pNDC.z;
end

local function isFinite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge;
end

-- Reject null, low, unaligned and out-of-range 32-bit addresses before any raw read.
local function isPointer(value)
    return isFinite(value) and value >= 0x10000 and value <= 0xFFFF0000 and value % 4 == 0;
end

local function isDrawableIndex(index)
    if (not isFinite(index) or index < 1 or index > 0x8FF or index % 1 ~= 0) then return false; end
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local id = entity:GetServerId(index);
    return isFinite(id) and id > 0 and isPointer(entity:GetActorPointer(index));
end

local function getBone(actorPointer, bone)
    if (not isPointer(actorPointer) or not isFinite(bone) or bone < 0 or bone % 1 ~= 0) then return; end
    local skeletonBaseAddress = ashita.memory.read_uint32(actorPointer + 0x6B8);
    if (not isPointer(skeletonBaseAddress)) then return; end
    local skeletonOffsetAddress = ashita.memory.read_uint32(skeletonBaseAddress + 0x0C);
    if (not isPointer(skeletonOffsetAddress)) then return; end
    local skeletonAddress = ashita.memory.read_uint32(skeletonOffsetAddress);
    if (not isPointer(skeletonAddress)) then return; end
    local boneCount = ashita.memory.read_uint16(skeletonAddress + 0x32);
    if (not isFinite(boneCount) or boneCount <= bone) then return; end
    local generatorsAddress = skeletonAddress + 0x30 + 0x04 + 0x1E * boneCount + 4;
    local boneAddress = generatorsAddress + bone * 0x1A + 0x0E;
    if (boneAddress < 0x10000 or boneAddress + 12 > 0xFFFFFFFF) then return; end

    local bx, by, bz = ashita.memory.read_float(actorPointer + 0x678), ashita.memory.read_float(actorPointer + 0x680), ashita.memory.read_float(actorPointer + 0x67C);
    local dx, dy, dz = ashita.memory.read_float(boneAddress), ashita.memory.read_float(boneAddress + 8), ashita.memory.read_float(boneAddress + 4);
    if (not isFinite(bx) or not isFinite(by) or not isFinite(bz)
        or not isFinite(dx) or not isFinite(dy) or not isFinite(dz)) then return; end
    local x, y, z = bx + dx, by + dy, bz + dz;
    if (not isFinite(x) or not isFinite(y) or not isFinite(z)) then return; end
    return x, y, z, bz;
end

-- Same bone/vertical midpoint as upstream; invalid skeletons produce no geometry.
local function getActorPoint(index)
    if (not isDrawableIndex(index)) then return; end
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local id, pointer = entity:GetServerId(index), entity:GetActorPointer(index);
    local x, y, z, baseZ = getBone(pointer, 2);
    if (not x) then return; end
    if (not isFinite(baseZ)) then return; end
    z = (baseZ + z) / 2;
    if (not isFinite(z) or entity:GetServerId(index) ~= id or entity:GetActorPointer(index) ~= pointer) then return; end
    return x, y, z;
end

local function normalize(vec3)
    local length2 = vec3[1] ^ 2 + vec3[2] ^ 2 + vec3[3] ^ 2;
    if (length2 == 0) then return { 0, 0, 0 }; end
    local u = length2 ^ (-0.5);
    return { vec3[1] * u, vec3[2] * u, vec3[3] * u };
end

local function getTexture(path)
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileA(d3d8dev, path, texture_ptr) ~= C.S_OK) then
        return nil;
    end

    return d3d.gc_safe_release(ffi.cast('IDirect3DBaseTexture8*', texture_ptr[0]));
end

local rotateVector16;
do
    local angle = -math.pi / 16;
    local sin = math.sin(angle);
    local cos = math.cos(angle);

    local angle2 = math.pi / 16;
    local sin2 = math.sin(angle2);
    local cos2 = math.cos(angle2);
    -- Rotates vector v around axis k by pi/16 radians
    -- k must be magnitude 1
    function rotateVector16(k, v, flip)
        -- k . v
        local kv = k[1] * v[1] + k[2] * v[2] + k[3] * v[3];

        local rx, ry, rz
        if (flip) then
            local kvcos = kv * (1 - cos2);
            rx = v[1] * cos2 + (k[2] * v[3] - k[3] * v[2]) * sin2 + k[1] * kvcos;
            ry = v[2] * cos2 + (k[3] * v[1] - k[1] * v[3]) * sin2 + k[2] * kvcos;
            rz = v[3] * cos2 + (k[1] * v[2] - k[2] * v[1]) * sin2 + k[3] * kvcos;
        else
            local kvcos = kv * (1 - cos);

            rx = v[1] * cos + (k[2] * v[3] - k[3] * v[2]) * sin + k[1] * kvcos;
            ry = v[2] * cos + (k[3] * v[1] - k[1] * v[3]) * sin + k[2] * kvcos;
            rz = v[3] * cos + (k[1] * v[2] - k[2] * v[1]) * sin + k[3] * kvcos;
        end
        return { rx, ry, rz };
    end
end

return {
    matrixMultiply = matrixMultiply,
    vec4Transform = vec4Transform,
    worldToScreen = worldToScreen,
    getBone = getBone,
    getActorPoint = getActorPoint,
    isDrawableIndex = isDrawableIndex,
    isFinite = isFinite,
    sessionGeneration = 0,
    normalize = normalize,
    getTexture = getTexture,
    rotateVector16 = rotateVector16,
    width = width,
    height = height
};
