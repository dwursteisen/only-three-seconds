local Player = {
    x = 0,
    y = 0,
    width = 16,
    height = 16,
    spr = 1,
    idle = 0.2,
    active = true,
    exit = false,
    flip = false
}

local Exit = {
    x = 0,
    y = 0,
    width = 16,
    height = 16,
    spr = 19
}

local Light = {
    r = 280,
    cooldown = 0.5,
    const_cooldown = 0.5
}

local Timer = {
    s = 3,
    active = true
}

local Particle = {
    x = 0,
    y = 0,
    ttl = 0,
    duration = 0,
    r = 0
}

local Walker = {
    x = 0,
    y = 0,
    width = 16,
    height = 16,
    spr = 4,
    cooldown = 1,
    dir = {0, 0}
}

local timer_spr = {{
    x = 0,
    y = 94,
    width = 131,
    height = 37
}, {
    x = 0,
    y = 142,
    width = 131,
    height = 37
}, {
    x = 0,
    y = 205,
    width = 131,
    height = 37
}}

local player = nil
local exit = nil
local target = nil
local light = nil
local timer = nil

local particles = nil
local enemies = nil
local walkers = nil

function _init()
    particles = {}
    enemies = {}
    walkers = {}
    exit = nil
    for s in all(map.entities["Spawn"]) do
        player = new(Player, s)
    end

    local ee = map.entities["Exit"]
    if ee ~= nil then
        for s in all(ee) do
            exit = new(Exit, s)
        end
    end

    local wal = map.entities["Walker"]
    if wal ~= nil then
        for e in all(wal) do
            local w = new(Walker, e)
            local cx = e.customFields.target.cx
            local cy = e.customFields.target.cy

            local dir = {
                x = math.max(-1, math.min(1, (cx * 16) - w.x)),
                y = math.max(-1, math.min(1, (cy * 16) - w.y))
            }
            w.dir = dir

            table.insert(enemies, w)
            table.insert(walkers, w)
        end
    end

    light = new(Light)
    timer = new(Timer)
end

function find_target(dir_x, dir_y, x, y)
    if map.flag(map.to(x + dir_x, y + dir_y)) > 0 then
        return {
            x = x,
            y = y
        }
    else
        return find_target(dir_x, dir_y, x + dir_x, y + dir_y)
    end
end

function player_jump(flip)
    player.active = false
    player.spr = 3
    player.idle = 10
    player.flip = flip

    for i = 1, 8 do
        local offset = 0
        if flip then
            offset = 8
        end
        table.insert(particles, new(Particle, {
            x = player.x + 4 + offset + math.rnd(2),
            y = player.y + 13 + math.rnd(2),
            ttl = 0.4,
            duration = 0.4,
            r = 3
        }))
    end

    sfx.play(0)
end

function _update()
    player.idle = player.idle - tiny.dt
    if player.idle < 0 then
        player.idle = 0.2
        player.spr = (player.spr + 1) % 3
    end

    if player.active and (not timer.active or exit == nil) then
        if ctrl.pressed(keys.left) then
            target = find_target(-16, 0, player.x, player.y)
            player_jump(true)
        elseif ctrl.pressed(keys.right) then
            target = find_target(16, 0, player.x, player.y)
            player_jump(false)
        elseif ctrl.pressed(keys.up) then
            target = find_target(0, -16, player.x, player.y)
            player_jump(false)
        elseif ctrl.pressed(keys.down) then
            target = find_target(0, 16, player.x, player.y)
            player_jump(false)
        end
    end

    if target ~= nil then
        player.x = juice.powOut2(player.x, target.x, 0.1)
        player.y = juice.powOut2(player.y, target.y, 0.1)

        if math.dst(player.x, player.y, target.x, target.y) < 2 then
            local cell = map.to(target.x, target.y)
            player.x = cell.cx * 16
            player.y = cell.cy * 16
            target = nil
            player.active = true
            player.idle = 0
        end
    end

    if exit ~= nil and player.x == exit.x and player.y == exit.y and not player.exit then
        player.exit = true
        light.cooldown = 1
        sfx.play(1)
    end

    if not timer.active then
        if player.exit then
            light.r = juice.powIn2(0, light.r, light.cooldown)
            light.cooldown = light.cooldown - tiny.dt
        elseif light.cooldown > 0 then
            light.r = juice.powIn2(32, light.r, light.cooldown / light.const_cooldown)
            light.cooldown = light.cooldown - tiny.dt
        else
            light.r = 32 + math.cos(tiny.frame / 10) * 4
        end
    end

    -- decrease the timer (if there is an)
    if timer.active and exit ~= nil then
        local now = math.ceil(timer.s)
        timer.s = timer.s - tiny.dt

        if math.ceil(timer.s) ~= now then 
            sfx.play(2)
        end

        if timer.s < 0 then
            timer.active = false
        end
    end

    if player.exit and light.cooldown < 0 then
        map.level(map.level() + 1)
        _init()
    end

    for k, p in rpairs(particles) do
        p.ttl = p.ttl - tiny.dt
        p.r = juice.powOut2(0, p.r, p.ttl / p.duration)
        if p.ttl < 0 then
            table.remove(particles, k)
        end
    end

    -- walkers
    for e in all(walkers) do
        if e.target ~= nil then
            e.x = juice.powOut2(e.x, e.target.x, 0.1)
            e.y = juice.powOut2(e.y, e.target.y, 0.1)

            if math.dst(e.x, e.y, e.target.x, e.target.y) < 2 then
                local cell = map.to(e.target.x, e.target.y)
                e.x = cell.cx * 16
                e.y = cell.cy * 16
                e.target = nil
                e.cooldown = 1
                e.dir.x = e.dir.x * -1
                e.dir.y = e.dir.y * -1
            end

        else
            e.cooldown = e.cooldown - tiny.dt
            if e.cooldown < 0 then
                e.target = find_target(e.dir.x, e.dir.y, e.x, e.y)
            end
        end
    end
end

function _draw()
    gfx.cls(1)
    shape.circlef(player.x + 8, player.y + 8, light.r, 0)
    gfx.to_sheet(1)

    gfx.cls()
    spr.sheet(0)
    map.draw()
    --
    if exit ~= nil then
        spr.draw(exit.spr, exit.x, exit.y)
    end

    -- particles
    for p in all(particles) do
        shape.circlef(p.x, p.y, p.r, 2)
    end

    for e in all(enemies) do
        spr.draw(e.spr, e.x, e.y)
    end

    -- player
    spr.draw(player.spr, player.x, player.y, player.flip)
    shape.circle(player.x + 8, player.y + 8, light.r, 3)

    spr.sheet(1)
    spr.sdraw()

    if timer.active and exit ~= nil then
        local index = 4 - math.ceil(timer.s)
        local s = timer_spr[index]
        if s ~= nil then
            spr.sheet(0)
            spr.sdraw(70, 4, s.x, s.y, s.width, s.height)
        end
    end
end
