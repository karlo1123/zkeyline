-- services
local players = game:GetService("Players");
local runService = game:GetService("RunService");

-- variables
local localPlayer = players.LocalPlayer;
local camera = workspace.CurrentCamera;
local normalIds = Enum.NormalId:GetEnumItems();
local ui, utils, pointers, theme = loadstring(game:HttpGet("https://raw.githubusercontent.com/Spoorloos/SplixPrivateDrawingLibrary/main/Library.lua", true))();
local ignoreList = {
    workspace.Players,
    workspace.Terrain,
    workspace.Ignore,
    workspace.CurrentCamera
};

-- modules
local modules = {};
for _, module in next, getloadedmodules() do
    local name = module and module.Name;
    if name == "ReplicationInterface" then
        modules.replication = require(module);
        modules.entryTable = debug.getupvalue(modules.replication.getEntry, 1);
    elseif name == "WeaponControllerInterface" then
        modules.weaponController = require(module);
    elseif name == "PublicSettings" then
        modules.settings = require(module);
    elseif name == "particle" then
        modules.particle = require(module);
    elseif name == "CharacterInterface" then
        modules.character = require(module);
    elseif name == "sound" then
        modules.sound = require(module);
    elseif name == "effects" then
        modules.effects = require(module);
    elseif name == "network" then
        modules.network = require(module);
        modules.remoteEvent = debug.getupvalue(modules.network.send, 1);
        modules.clientEvents = debug.getupvalue(getconnections(modules.remoteEvent.OnClientEvent)[1].Function, 1);
    elseif name == "physics" then
        modules.physics = require(module);
    elseif name == "BulletCheck" then
        modules.bulletcheck = require(module);
    end
end

-- functions
local function calculateDamage(distance, name, data)
    local damage = distance < data.range0 and data.damage0 or (distance < data.range1 and (((data.damage1 - data.damage0) / (data.range1 - data.range0)) * (distance - data.range0)) + data.damage0 or data.damage1);
    local multiplier = name == "Head" and data.multhead or (name == "Torso" and data.multtorso or data.multlimb or 1);
    return damage * multiplier;
end

do -- ui
    theme.font = 1;
    theme.accent = Color3.new(math.random(), math.random(), math.random());

    local window = ui:New({ name = "skyline" });
    window.uibind = Enum.KeyCode.RightShift;
    window.VisualPreview:SetPreviewState(false);

    local legit = window:Page({ name = "legit" });
    local rage = window:Page({ name = "rage" });
    do
        local ragebot = rage:Section({ name = "rage bot", side = "left" });
        ragebot:Toggle({ name = "enabled", pointer = "rage_ragebot_enabled" });
        ragebot:Toggle({ name = "shot limiter", pointer = "rage_ragebot_shotlimiter" });
        ragebot:Toggle({ name = "custom firerate", pointer = "rage_ragebot_customfirerate" });
        ragebot:Slider({ name = "firerate", min = 10, max = 1500, def = 250, pointer = "rage_ragebot_firerate" });
        ragebot:Dropdown({ name = "hitpart", options = {"Head", "Torso"}, pointer = "rage_ragebot_hitpart" });
        ragebot:Dropdown({ name = "target method", options = {"closest", "looking at"}, pointer = "rage_ragebot_targetmethod" });

        --local teleportbot = rage:Section({ name = "teleport bot", side = "left" });
        --teleportbot:Toggle({ name = "enabled", pointer = "rage_teleportbot_enabled" });
        --teleportbot:Toggle({ name = "knife mode", pointer = "rage_teleportbot_knifemode" });
        --teleportbot:Slider({ name = "point spacing", min = 1, max = 10, decimals = 0.5, def = 5, pointer = "rage_teleportbot_pointspacing" });
        --teleportbot:Slider({ name = "delay", min = 0, max = 2, decimals = 0.1, def = 1, pointer = "rage_teleportbot_delay" });

        local scanning = rage:Section({ name = "scanning", side = "right" });
        scanning:Toggle({ name = "enabled", pointer = "rage_scanning_enabled" });
        scanning:Toggle({ name = "fire position scanning", pointer = "rage_scanning_fireposscanning" });
        scanning:Slider({ name = "fire position radius", min = 1, max = 10, decimals = 0.5, def = 8.5, pointer = "rage_scanning_fireposscanning_radius" });
        scanning:Toggle({ name = "target scanning", pointer = "rage_scanning_targetscanning" });
        scanning:Slider({ name = "target radius", min = 1, max = 5, decimals = 0.5, def = 3.5, pointer = "rage_scanning_targetscanning_radius" });
        --scanning:Toggle({ name = "teleport scanning", pointer = "rage_scanning_teleportscanning" });
        --scanning:Slider({ name = "teleport radius", min = 1, max = 200, def = 20, pointer = "rage_scanning_teleportscanning_radius" });
    end

    local esp = window:Page({ name = "esp" });
    do
        --local enemy = esp:Section({ name = "enemy esp", side = "left" });
        --enemy:Toggle({ name = "enabled", pointer = "esp_enemy_enabled" });
        --enemy:Toggle({ name = "box", pointer = "esp_enemy_box" });

        --local friendly = esp:Section({ name = "friendly esp", side = "left" });
        --friendly:Toggle({ name = "enabled", pointer = "esp_friendly_enabled" });
        --friendly:Toggle({ name = "box", pointer = "esp_friendly_box" });
    end

    local visuals = window:Page({ name = "visuals" });
    local misc = window:Page({ name = "misc" });
    local settings = window:Page({ name = "settings" });
    do
        local interface = settings:Section({ name = "interface", side = "left" });
        interface:Keybind({ name = "hide key", def = window.uibind, callback = function(key)
            window.uibind = key;
        end })
    end

    window:Initialize();
end

do -- ragebot
    local lastShot = 0;
    local replicationPosition = Vector3.zero;
    local replicationAngles = Vector2.zero;
    local replicationTickOffset = 0;
    local health = {};

    -- functions
    local function scanTarget(position, data)
        local origins = { CFrame.new(replicationPosition, position) };
        local targets = { CFrame.new(position, replicationPosition) };

        if pointers.rage_scanning_enabled.current then
            for _, id in next, normalIds do
                local dir = Vector3.fromNormalId(id);

                if pointers.rage_scanning_fireposscanning.current then
                    table.insert(origins, origins[1] + dir * math.clamp(pointers.rage_scanning_fireposscanning_radius.current, 1, 9.5));
                end

                if pointers.rage_scanning_targetscanning.current then
                    table.insert(targets, targets[1] + dir * math.clamp(pointers.rage_scanning_targetscanning_radius.current, 1, 4.5));
                end
            end
        end

        for _, origin in next, origins do
            origin = origin.Position;
            for _, target in next, targets do
                target = target.Position

                local velocity = modules.physics.trajectory(origin, modules.settings.bulletAcceleration, target, data.bulletspeed);
                if modules.bulletcheck(origin, target, velocity, modules.settings.bulletAcceleration, data.penetrationdepth) then
                    return { origin = origin, target = target, velocity = velocity };
                end
            end
        end
    end

    local function getTarget(data)
        local _min = math.huge;
        local _player, _scan, _entry;
        for player, entry in next, modules.entryTable do
            local tpObject = entry and entry._thirdPersonObject;
            local char = tpObject and tpObject._character;
            if char and player.Team ~= localPlayer.Team and (health[player] or entry:getHealth()) > 0 then
                local cframe = camera.CFrame;
                local position = char[pointers.rage_ragebot_hitpart.current].Position;
                local scan = scanTarget(position, data);
                local dir = cframe.Position - position;
                local comparison = pointers.rage_ragebot_targetmethod.current == "looking at" and
                    cframe.LookVector:Dot(dir.Unit) or dir.Magnitude;

                if comparison < _min and scan then
                    _min = comparison;
                    _player = player;
                    _scan = scan;
                    _entry = entry;
                end
            end
        end
        return _player, _scan, _entry;
    end

    -- hooks
    local send = modules.network.send;
    function modules.network:send(name, ...)
        local args = { ... };
        if name == "repupdate" then
            replicationPosition = args[1];
            replicationAngles = args[2];
            args[3] += replicationTickOffset;
        elseif name == "newbullets" or name == "spotplayers" or name == "equip" then
            args[2] += replicationTickOffset;
        elseif name == "newgrenade" or name == "updatesight" then
            args[3] += replicationTickOffset;
        elseif name == "bullethit" then
            args[5] += replicationTickOffset;
        elseif name == "ping" then
            return;
        end
        return send(self, name, unpack(args));
    end

    -- connections
    utils:Connection(runService.Heartbeat, function()
        if pointers.rage_ragebot_enabled.current and modules.character.isAlive() then
            local controller = modules.weaponController.getController();
            local weapon = controller and controller:getActiveWeapon();
            local data = weapon and weapon._weaponData;
            if data and weapon.getFirerate then
                local deltaTime = tick() - lastShot;
                local fireRate = 60 / weapon:getFirerate();
                if deltaTime < (pointers.rage_ragebot_customfirerate.current and 60/pointers.rage_ragebot_firerate.current or fireRate) then
                    return;
                end

                lastShot = tick();

                local player, scan, entry = getTarget(data);
                if player and scan and entry then
                    -- firerate bypass
                    local syncedTime = modules.network:getTime();
                    if deltaTime < fireRate then
                        replicationTickOffset += fireRate - deltaTime;
                        modules.network:send("repupdate", replicationPosition, replicationAngles, syncedTime);
                    end

                    -- creating bullet(s)
                    local bulletCount = data.pelletcount or 1;
                    local bulletId = debug.getupvalue(weapon.fireRound, 10);
                    local bullets = table.create(bulletCount, { scan.velocity, bulletId });

                    for i, v in next, bullets do
                        v[2] += i;
                    end

                    debug.setupvalue(weapon.fireRound, 10, bulletId + bulletCount);

                    -- registering bullet(s)
                    modules.network:send("newbullets", {
                        firepos = scan.origin,
                        camerapos = replicationPosition,
                        bullets = bullets
                    }, syncedTime);

                    -- effects
                    modules.sound.PlaySoundId(data.firesoundid, data.firevolume, data.firepitch, weapon._barrelPart, nil, 0, 0.05);
                    modules.effects:muzzleflash(weapon._barrelPart, data.hideflash);

                    for _, bullet in next, bullets do
                        modules.particle.new({
                            size = 0.2,
                            bloom = 0.005,
                            brightness = 400,
                            dt = deltaTime,
                            position = scan.origin,
                            velocity = bullet[1],
                            life = modules.settings.bulletLifeTime,
                            acceleration = modules.settings.bulletAcceleration,
                            color = data.bulletcolor or Color3.fromRGB(200, 70, 70),
                            visualorigin = weapon._barrelPart.Position,
                            physicsignore = ignoreList,
                            penetrationdepth = data.penetrationdepth,
                            tracerless = data.tracerless
                        });
                    end

                    -- updating magazine
                    weapon._magCount -= 1;
                    if weapon._magCount < 1 then
                        local newCount = data.magsize + (data.chamber and 1 or 0) + weapon._magCount;
                        if weapon._spareCount >= newCount then
                            weapon._magCount += newCount;
                            weapon._spareCount -= newCount;
                        else
                            weapon._magCount += weapon._spareCount;
                            weapon._spareCount = 0;
                        end

                        modules.network:send("reload");
                    end

                    -- registering hit(s)
                    local hitPart = pointers.rage_ragebot_hitpart.current;
                    for _, bullet in next, bullets do
                        modules.network:send("bullethit", player, scan.target, hitPart, bullet[2], syncedTime);
                        modules.sound.PlaySound("hitmarker", nil, 1, 1.5);
                    end

                    -- updating health
                    if pointers.rage_ragebot_shotlimiter then
                        health[player] = (health[player] or entry:getHealth()) - calculateDamage((scan.target - replicationPosition).Magnitude, hitPart, data) * bulletCount;

                        if health[player] < 1 then
                            task.wait(1);
                            health[player] = nil;
                        end
                    end
                end
            end
        end
    end);
end
