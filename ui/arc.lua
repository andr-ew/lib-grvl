local buffers = grvl.buffers

local Destinations = {}

Destinations['level_'] = function()
    local _lvl = Arc.control()
    local _fill = Arc.control()

    return function(props) 
        local id = props.id
        local xx = { 42 - 4, 42 + 16 + 3 }
        local spec = params:lookup_param(id).controlspec

        _lvl{
            n = props.n,
            sensitivity = 0.5, 
            controlspec = spec,
            state = grvl.of_param(id),
            levels = { 0, props.levels[1], props.levels[1] },
            -- x = { 33, 33 },
            x = xx,
        }
        if crops.mode == 'redraw' then
            _fill{
                n = props.n,
                controlspec = spec,
                state = { spec.default },
                levels = { 0, 0, props.levels[2] },
                -- x = { 33, 33 },
                x = xx,
            }
        end
    end
end

Destinations['old_'] = function(prefix)
    local _old = Arc.control()

    return function(props) 
        local id = props.id
        local spec = params:lookup_param(id).controlspec
        local xx = { 42 - 4, 56 }

        _old{
            n = props.n,
            sensitivity = 0.5, 
            controlspec = spec,
            state = grvl.of_param(id),
            levels = { props.levels[1], props.levels[2], props.levels[2] },
            x = xx,
        }
    end
end

Destinations['pm_freq_'] = function(prefix)
    local _freq = Arc.control()
    local _mark = Arc.control()

    return function(props) 
        local id = props.id
        local spec = params:lookup_param(id).controlspec
        local xx = { 42, 41 }

        if crops.mode == 'redraw' then
            _mark{
                n = props.n,
                controlspec = spec,
                state = { 0 },
                levels = { 0, 0, props.levels[1] },
                -- x = { 33, 33 },
                x = xx,
            }
        end
        _freq{
            n = props.n,
            sensitivity = 0.25, 
            controlspec = spec,
            state = grvl.of_param(id),
            levels = { 0, 0, props.levels[2] },
            x = xx,
        }
    end
end

for i,window_thing in ipairs{ 'start', 'end' } do
    local is_start = i==1

    Destinations['loop_'..window_thing..'_'] = function(prefix)
        local _win = { enc = Arc.control(), ring = Components.arc.window() }

        return function(props)
            local id = props.id
            local chan = props.chan
            local spec = params:lookup_param(id).controlspec

            if crops.mode == 'input' then
                _win.enc{
                    n = props.n,
                    sensitivity = spec.quantum*100, 
                    controlspec = spec,
                    state = grvl.of_param(id),
                }
            elseif crops.mode == 'redraw' then
                local buf = grvl.get_param('buffer_'..chan)
                local ph = buffers[buf].phase_seconds
                local dur = buffers[buf].duration_seconds
                local show_phase = (
                    buffers[buf].recorded 
                    or buffers[buf].manual 
                    or buffers[buf].loaded
                )

                _win.ring{
                    n = props.n,
                    x = { 33, 64+32 }, 
                    phase = ph / dur,
                    show_phase = show_phase,
                    level_st = is_start and 15 or 4,
                    level_en = is_start and 4 or 15,
                    level_ph = 4,
                    st = (
                        grvl.get_param('loop_start_'..chan)
                        / grvl.time_volt_scale
                    ),
                    en = (
                        grvl.get_param('loop_end_'..chan) 
                        / grvl.time_volt_scale
                    ),
                }
            end
        end
    end
end

Destinations['rate_'] = function()
    local spec = params:lookup_param('rate_1').controlspec

    local _rate = Arc.control()
    local _marks = {}
    for i = spec.minval, spec.maxval do
        _marks[i] = Arc.control()
    end

    return function(props) 
        local id = props.id
        local chan = props.chan
        local xx = { 64 - (5*5) + 1 , 5*5 + 1 }

        if crops.mode == 'redraw' then for i = spec.minval, spec.maxval do
            _marks[i]{
                n = props.n,
                controlspec = spec,
                state = { i },
                levels = { 0, 0, props.levels[1] },
                -- x = { 33, 33 },
                x = xx,
            }
        end end
        _rate{
            n = props.n,
            -- sensitivity = 0.25, 
            controlspec = spec,
            state = grvl.of_param(id),
            levels = { 0, 0, props.levels[2] },
            x = xx,
        }
    end
end

local Generic_destinations = {}

Generic_destinations['control'] = function()
    local _ctl = Arc.control()

    return function(props) 
        local id = props.id
        local chan = props.chan
        local spec = params:lookup_param(id).controlspec

        _ctl{
            n = props.n,
            sensitivity = spec.quantum*100, 
            controlspec = spec,
            state = grvl.of_param(id),
            levels = { 0, props.levels[1], props.levels[2] },
        }
    end
end

Generic_destinations['number'] = function()
    local _int = Arc.integer()
    local xx = { 42 - 4, 56 }

    return function(props) 
        local id = props.id
        local chan = props.chan
        local p = params:lookup_param(id)

        _int{
            n = props.n,
            sensitivity = 0.5, 
            min = p.min or 1,
            max = p.max,
            size = 2,
            -- sensitivity = 1,
            cycle = 64,
            -- indicator = 1,
            x = xx,
            -- x = { 1, 64 },
            state = grvl.of_param(id),
            levels = { 0, props.levels[2] }
    }
    end
end

local function App(args)
    local rotated = args.rotated

    local _destinations = {}
    for prefix,Destination in pairs(Destinations) do
        _destinations[prefix] = Patcher.arc.destination(Destination())
    end

    local _generic_destinations = {}
    for y = 1,4 do
        _generic_destinations[y] = {}
        for x = 1,4 do
            _generic_destinations[y][x] = {}

            for typ,Destination in pairs(Generic_destinations) do
                _generic_destinations[y][x][typ] = Patcher.arc.destination(Destination())
            end
        end
    end

    return function()
        local map = grvl.map

        for y = 1,4 do for x = 1,4 do
            if grvl.arc_focus[y][x] > 0 then
                local prefix = map[y][x]
                local chan = grvl.grid_focus[(x <3) and 'left' or 'right'] 
                local id = prefix..chan
                local p = params:lookup_param(id)
                local typ = p.controlspec and 'control' or 'number'

                local _destination = _destinations[prefix] or _generic_destinations[y][x][typ]

                _destination(id, grvl.active_src, {
                    id = id,
                    n = tonumber(grvl.arc_vertical and y or x),
                    rotated = rotated,
                    chan = chan,
                    levels = { 4, 15 }
                })
            end
        end end
    end
end

return App
