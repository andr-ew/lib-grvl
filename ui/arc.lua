local buffers = grvl.buffers
local set_param = grvl.set_param

local Destinations = {}

function Destinations.level(chan, x, y)
    local _gain = Arc.control()
    local _fill = Arc.control()

    return function(props) 
        local id = 'output_level_'..chan
        local xx = { 42 - 4, 42 + 16 + 3 }
        local spec = params:lookup_param(id).controlspec

        _gain{
            n = tonumber(grvl.arc_vertical and y or x),
            sensitivity = 0.5, 
            controlspec = spec,
            state = { patcher.get_destination_plus_param(id), set_param, id },
            levels = { 0, 4, 4 },
            -- x = { 33, 33 },
            x = xx,
        }
        if crops.mode == 'redraw' then
            _fill{
                n = tonumber(grvl.arc_vertical and y or x),
                controlspec = spec,
                state = { spec.default },
                levels = { 0, 0, 15 },
                -- x = { 33, 33 },
                x = xx,
            }
        end
    end
end

local function App(args)
    local map = args.map
    local rotated = args.rotated
    local wide = args.grid_wide

    local _params = {}
    for y = 1,4 do
        _params[y] = {}
        for x = 1,4 do
            local Destination = Destinations[map[y][x]]
            if Destination then
                _params[y][x] = Destination((x <3) and 1 or 2, x, y)
            end
        end
    end

    return function()
        for y = 1,4 do for x = 1,4 do
            if grvl.arc_focus[y][x] > 0 and _params[y][x] then
                _params[y][x]{ rotated = rotated }
            end
        end end
    end
end

return App
