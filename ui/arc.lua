local buffers = grvl.buffers
local set_param = grvl.set_param

local Destinations = {}

Destinations['level_'] = function(prefix, x, y)
    local _lvl = Arc.control()
    local _fill = Arc.control()

    return function(props) 
        local chan = props.chan
        local id = prefix..chan
        local xx = { 42 - 4, 42 + 16 + 3 }
        local spec = params:lookup_param(id).controlspec

        _lvl{
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

Destinations['old_'] = function(prefix, x, y)
    local _old = Arc.control()

    return function(props) 
        local chan = props.chan
        local id = prefix..chan
        local spec = params:lookup_param(id).controlspec
        local xx = { 42 - 4, 56 }

        _old{
            n = tonumber(grvl.arc_vertical and y or x),
            sensitivity = 0.5, 
            controlspec = spec,
            state = { patcher.get_destination_plus_param(id), set_param, id },
            levels = { 4, 15, 15 },
            x = xx,
        }
    end
end

Destinations['pm_freq_'] = function(prefix, x, y)
    local _freq = Arc.control()
    local _mark = Arc.control()

    return function(props) 
        local chan = props.chan
        local id = prefix..chan
        local spec = params:lookup_param(id).controlspec
        local xx = { 42, 41 }

        if crops.mode == 'redraw' then
            _mark{
                n = tonumber(grvl.arc_vertical and y or x),
                controlspec = spec,
                state = { 0 },
                levels = { 0, 0, 4 },
                -- x = { 33, 33 },
                x = xx,
            }
        end
        _freq{
            n = tonumber(grvl.arc_vertical and y or x),
            sensitivity = 0.25, 
            controlspec = spec,
            state = { patcher.get_destination_plus_param(id), set_param, id },
            levels = { 0, 0, 15 },
            x = xx,
        }
    end
end

for i,window_thing in ipairs{ 'start', 'end' } do
    local is_start = i==1

    Destinations['loop_'..window_thing..'_'] = function(prefix, x, y)
        local _win = { enc = Arc.control(), ring = Components.arc.window() }

        return function(props)
            local chan = props.chan
            local id = prefix..chan
            local spec = params:lookup_param(id).controlspec

            if crops.mode == 'input' then
                _win.enc{
                    n = tonumber(grvl.arc_vertical and y or x),
                    sensitivity = spec.quantum*100, 
                    controlspec = spec,
                    state = { patcher.get_destination_plus_param(id), set_param, id },
                }
            elseif crops.mode == 'redraw' then
                local buf = patcher.get_destination_plus_param('buffer_'..chan)
                local ph = buffers[buf].phase_seconds
                local dur = buffers[buf].duration_seconds
                local show_phase = (
                    buffers[buf].recorded 
                    or buffers[buf].manual 
                    or buffers[buf].loaded
                )

                _win.ring{
                    n = tonumber(grvl.arc_vertical and y or x),
                    x = { 33, 64+32 }, 
                    phase = ph / dur,
                    show_phase = show_phase,
                    level_st = is_start and 15 or 4,
                    level_en = is_start and 4 or 15,
                    level_ph = 4,
                    st = patcher.get_destination_plus_param('loop_start_'..chan)/grvl.time_volt_scale,
                    en = patcher.get_destination_plus_param('loop_end_'..chan)/grvl.time_volt_scale,
                }
            end
        end
    end
end

Destinations['other'] = function(prefix, x, y)
    local _ctl = Arc.control()

    return function(props) 
        local chan = props.chan
        local id = prefix..chan
        local spec = params:lookup_param(id).controlspec

        _ctl{
            n = tonumber(grvl.arc_vertical and y or x),
            sensitivity = spec.quantum*100, 
            controlspec = spec,
            state = { patcher.get_destination_plus_param(id), set_param, id },
            -- levels = { 4, 15, 15 },
        }
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
                _params[y][x] = Destination(map[y][x], x, y)
            elseif map[y][x] then
                _params[y][x] = Destinations['other'](map[y][x], x, y)
            end
        end
    end

    return function()
        for y = 1,4 do for x = 1,4 do
            if grvl.arc_focus[y][x] > 0 and _params[y][x] then
                _params[y][x]{
                    rotated = rotated,
                    chan = grvl.grid_focus[(x <3) and 'left' or 'right']
                }
            end
        end end
    end
end

return App
