local App = {}

local function Channel()
    local _rec = Grid.toggle()
    local _play = Grid.toggle()
    local _clear = Grid.trigger()
    local _buffer = Grid.integer()
    
    local _bits = Grid.integer()
    local _uwrite = Grid.toggle()
    local _uread = Grid.toggle()

    local _start = Grid.integer()
    local _end = Grid.integer()
    local _reverse = Grid.toggle()
    local _oct = Grid.integer()

    return function(props)
        local chan = props.channel
        local left, right = props.side=='left', props.size=='right'

        _rec{
            x = left and 1 or 15, y = 1,
            levels = { 4, 15 },
            state = crops.of_param('record_'..chan),
        }
        _play{
            x = left and 2 or 16, y = 1,
            levels = { 4, 15 },
            state = crops.of_param('play_'..chan),
        }
        _clear{
            x = left and 1 or 16, y = 2,
            levels = { 4, 15 },
            input = function() params:delta('clear_'..chan) end,
        }
        _buffer{
            x = left and 4 or 12, y = 1,
            size = 2,
            levels = { 0, 15 },
            state = crops.of_param('buffer_'..chan),
        }

        _bits{
            x = left and 0 or 11, y = 4, size = 6, 
            min = params:lookup_param('bit_depth_'..chan).controlspec.minval,
            state = crops.of_param('bit_depth_'..chan),
        }
        _uwrite{
            x = left and 1 or 16, y = 7,
            levels = { 4, 15 },
            state = crops.of_param('ulaw_write_'..chan),
        }
        _uread{
            x = left and 1 or 16, y = 8,
            levels = { 4, 15 },
            state = crops.of_param('ulaw_read_'..chan),
        }
                

        _start{
            x = left and 1 or 9, y = 5,
            size = 8, min = 0,
            state = {
                util.round(params:get('loop_start_'..chan) * 4),
                function(v)
                    params:set('loop_start_'..chan, v / 4)
                end
            }
        }
        _end{
            x = left and 1 or 9, y = 6,
            size = 8, min = 0,
            state = {
                util.round(params:get('loop_end_'..chan) * 4),
                function(v)
                    params:set('loop_end_'..chan, v / 4)
                end
            }
        }
        _reverse{
            x = left and 2 or 9, y = 7,
            levels = { 4, 15 },
            state = crops.of_param('reverse_'..chan),
        }
        _oct{
            x = left and 3 or 10, y = 7,
            size = 5, min = -2,
            state = crops.of_param('octave_'..chan),
        }

    end
end

local function App()
    local _channels = {}
    for i = 1,2 do _channels[i] = Channel() end

    return function(props)
        _channels[1]{
            side = 'left', channel = 1,
        }
        _channels[2]{
            side = 'right', channel = 2,
        }
    end
end

return App
