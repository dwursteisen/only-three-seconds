local x = 139
local y = 191
local width = 103
local height = 59

function _draw()

    gfx.cls()
    local offset = math.cos(tiny.frame / 50) * 4

    gfx.dither(0x0001)

    for i = 1, 3 do

        local xx = math.perlin(0.1 * i, 0.2, tiny.frame / 100 * i)
        local yy = math.perlin(i / 3, 0.5 * i / 3, tiny.frame / 100)
        shape.circlef(xx * 256, yy * 256, 32 + i * 16, 2)
    end

    gfx.dither()
    spr.sdraw(256 * 0.5 - width * 0.5, 256 * 0.5 - height * 0.5 + offset, x, y, width, height)

    if ctrl.pressed(keys.space) then
        sfx.play(0)
        tiny.exit(1)
    end
end
