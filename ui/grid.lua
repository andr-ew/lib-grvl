local buffers = grvl.buffers
local set_param = grvl.set_param

local function Channel()
    local _rec = Patcher.grid.destination(Grid.toggle())
    -- local _play = Patcher.grid.destination(Grid.toggle())
    local _clear = Grid.trigger()
    
    local src_held = { 0, 0 }
    local function set_active_src(left, v)
        src_held = v

        grvl.active_src = 'none'

        for i = 1,2 do if src_held[i] > 0 then
            grvl.active_src = patcher.sources[
                params:get('patcher_source_'..((left and 0 or 2) + i))
            ]
        end end

        crops.dirty.screen = true
        crops.dirty.grid = true
        crops.dirty.arc = true
    end
    local _patcher_source = Grid.momentaries()

    local _buffer = Patcher.grid.destination(Grid.integer())

    local _patrecs = {}
    for i = 1,4 do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    local _bits = Patcher.grid.destination(Grid.integer())
    local _detritus = Patcher.grid.destination(Grid.integer())

    local _start = Patcher.grid.destination(Grid.integer())
    local _end = Patcher.grid.destination(Grid.integer())

    local _reverse_write = Patcher.grid.destination(Grid.toggle())
    local _oct_write = Patcher.grid.destination(Grid.integer())
    local _reverse_read = Patcher.grid.destination(Grid.toggle())
    local _oct_read = Patcher.grid.destination(Grid.integer())
    local _couple1 = Patcher.grid.destination(Grid.toggle())
    local _couple2 = Patcher.grid.destination(Grid.toggle())

    local time_max = params:lookup_param('loop_end_1').controlspec.maxval

    return function(props)
        local chan = props.channel
        local left, right = props.side=='left', props.size=='right'

        if crops.device == 'grid' and crops.mode == 'redraw' then
            local g = crops.handler
            local buf = patcher.get_destination_plus_param('buffer_'..chan)

            --draw end
            do
                local x = (left and 1 or 9) + util.round(
                    (patcher.get_destination_plus_param('loop_end_'..chan) / time_max) * 7
                )
                g:led(x, 5, 4)
            end

            --draw phase
            if 
                buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            then
                local ph = buffers[buf].phase_seconds
                local dur = buffers[buf].duration_seconds

                local x = (left and 1 or 9) + util.round((ph / dur) * 7)
                g:led(x, 5, 4)
            end
        end

        _rec('record_'..chan, grvl.active_src, {
            x = left and 1 or 16, y = 1,
            levels = { 4, 15 },
            state = grvl.of_param('record_'..chan, true),
        })
        -- _play('play_'..chan, grvl.active_src, {
        --     x = left and 2 or 16, y = 1,
        --     levels = { 4, 15 },
        --     state = grvl.of_param('play_'..chan),
        -- })
        
        _patcher_source{
            x = (left and 2 or 15), y = 1, size = 2, flow = 'down',
            levels = { 0, 4 },
            state = crops.of_variable(src_held, set_active_src, left)
        }
        
        _clear{
            x = left and 1 or 16, y = 2,
            levels = { 4, 15 },
            input = function() params:delta('clear_'..chan) end,
        }
        _buffer('buffer_'..chan, grvl.active_src, {
            x = left and 3 or 13, y = 1,
            size = 2,
            levels = { 0, 15 },
            state = grvl.of_param('buffer_'..chan),
        })

        for i,_patrec in ipairs(_patrecs) do
            _patrec{
                x = (left and 5 or 11) + (i-1)%2, y = 1 + (i-1)//2,
                pattern = patterns[(left and 0 or 4) + i],
            }
        end

        _bits('bit_depth_'..chan, grvl.active_src, {
            x = left and 1 or 11, y = 4, size = 6, 
            min = params:lookup_param('bit_depth_'..chan).min,
            state = {
                util.round(patcher.get_destination_plus_param('bit_depth_'..chan)),
                set_param, 'bit_depth_'..chan
            }
        })
        _detritus('detritus_'..chan, grvl.active_src, {
            x = (left and 1 or 11) + 6 - 1, y = 3, size = 6, flow = 'left',
            state = {
                util.round(patcher.get_destination_plus_param('detritus_'..chan)),
                set_param, 'detritus_'..chan
            }
        })

        _start('loop_start_'..chan, grvl.active_src, {
            x = left and 1 or 9, y = 5,
            size = 8, min = 0,
            state = {
                util.round(
                    (patcher.get_destination_plus_param('loop_start_'..chan) / time_max) * 7
                ),
                function(v)
                    set_param('loop_start_'..chan, (v/7) * time_max)
                end
            }
        })
        _end('loop_end_'..chan, grvl.active_src, {
            x = left and 1 or 9, y = 6,
            size = 8, min = 0,
            state = {
                util.round(
                    (patcher.get_destination_plus_param('loop_end_'..chan) / time_max) * 7
                ),
                function(v)
                    set_param('loop_end_'..chan, (v/7) * time_max)
                end
            }
        })
        _reverse_write('reverse_write_'..chan, grvl.active_src, {
            x = left and 1 or 9, y = 7,
            levels = { 4, 15 },
            state = grvl.of_param('reverse_write_'..chan),
        })
        _oct_write('octave_write_'..chan, grvl.active_src, {
            x = left and 2 or 10, y = 7,
            size = 6, min = -3,
            state = grvl.of_param('octave_write_'..chan),
        })
        do
            local head = (
                patcher.get_destination_plus_param('couple_'..chan) > 0
            ) and 'write_' or 'read_'
            _reverse_read('reverse_'..head..chan, grvl.active_src, {
                x = left and 1 or 9, y = 8,
                levels = { 4, 15 },
                state = grvl.of_param('reverse_'..head..chan),
            })
            _oct_read('octave_'..head..chan, grvl.active_src, {
                x = left and 2 or 10, y = 8,
                size = 6, min = -3,
                state = grvl.of_param('octave_'..head..chan),
            })
        end
        _couple1('couple_'..chan, grvl.active_src, {
            x = left and 8 or 16, y = 7,
            levels = { 4, 15 },
            state = grvl.of_param('couple_'..chan),
        })
        _couple2('couple_'..chan, grvl.active_src, {
            x = left and 8 or 16, y = 8,
            levels = { 4, 15 },
            state = grvl.of_param('couple_'..chan),
        })
    end
end

local function App()
    local _channels = {}
    for i = 1,2 do _channels[i] = Channel() end

    local _arc_focus = Components.grid.arc_focus()
    local _norns_focus = Components.grid.norns_focus()

    local function set_grid_focus(side, v)
        grvl.grid_focus[side] = v
        
        crops.dirty.screen = true
        crops.dirty.grid = true
        crops.dirty.arc = true
    end
    local _grid_focuses = { left = Grid.integer(), right = Grid.integer() }

    return function(props)
        -- _focus_bg{
        --     x = 7, y = 1, size = 16, wrap = 4, level = 4,
        -- }

        if arc_connected then
            _arc_focus{
                x = 7, y = 1, levels = { 4, 15 },
                view = grvl.arc_focus, tall = false,
                vertical = { 
                    grvl.arc_vertical, 
                    function(v) grvl.arc_vertical = v end 
                },
                action = function(vertical, x, y)
                    crops.dirty.screen = true 
                    crops.dirty.grid = true
                    crops.dirty.arc = true
                end
            }
        else
            _norns_focus{
                x = 7, y = 1, levels = { 4, 15 },
                state = crops.of_variable(grvl.norns_focus, function(v) 
                    grvl.norns_focus = v

                    crops.dirty.grid = true
                    crops.dirty.screen = true
                end)
            }
        end


        for side,_focus in pairs(_grid_focuses) do
            _focus{
                x = side == 'left' and 3 or 13, y = 2, size = 2, levels = { 4, 15 },
                state = crops.of_variable(grvl.grid_focus[side], set_grid_focus, side)
            }
        end

        _channels[1]{
            side = 'left', channel = grvl.grid_focus.left,
        }
        _channels[2]{
            side = 'right', channel = grvl.grid_focus.right,
        }
    end
end

return App
