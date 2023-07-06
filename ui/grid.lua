local App = {}

local function Channel()
    local _rec = Grid.toggle()
    local _play = Grid.toggle()
    local _clear = Grid.trigger()
    local _buffer = Grid.integer()
    
    local _bits = Grid.integer()
    local _silt = Grid.integer()

    local _start = Grid.integer()
    local _end = Grid.integer()
    local _reverse_write = Grid.toggle()
    local _oct_write = Grid.integer()
    local _reverse_read = Grid.toggle()
    local _oct_read = Grid.integer()
    local _couple1 = Grid.toggle()
    local _couple2 = Grid.toggle()

    local time_max = params:lookup_param('loop_end_1').controlspec.maxval

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
            x = left and 1 or 11, y = 4, size = 6, 
            min = params:lookup_param('bit_depth_'..chan).controlspec.minval,
            state = crops.of_param('bit_depth_'..chan),
        }
        _silt{
            x = left and 6 or 11, y = 1, 
            size = 3, flow = 'down', min = -1,
            state = {
                util.round(params:get('silt_'..chan)),
                function(v)
                    params:set('silt_'..chan, v)
                end
            }
        }

        _start{
            x = left and 1 or 9, y = 5,
            size = 8, min = 0,
            state = {
                util.round((params:get('loop_start_'..chan) / time_max) * 7),
                function(v)
                    params:set('loop_start_'..chan, (v/7) * time_max)
                end
            }
        }
        _end{
            x = left and 1 or 9, y = 6,
            size = 8, min = 0,
            state = {
                util.round((params:get('loop_end_'..chan) / time_max) * 7),
                function(v)
                    params:set('loop_end_'..chan, (v/7) * time_max)
                end
            }
        }
        _reverse_write{
            x = left and 1 or 9, y = 7,
            levels = { 4, 15 },
            state = crops.of_param('reverse_write_'..chan),
        }
        _oct_write{
            x = left and 2 or 10, y = 7,
            size = 6, min = -3,
            state = crops.of_param('octave_write_'..chan),
        }
        do
            local head = (params:get('couple_'..chan) > 0) and 'write_' or 'read_'
            _reverse_read{
                x = left and 1 or 9, y = 8,
                levels = { 4, 15 },
                state = crops.of_param('reverse_'..head..chan),
            }
            _oct_read{
                x = left and 2 or 10, y = 8,
                size = 6, min = -3,
                state = crops.of_param('octave_'..head..chan),
            }
        end
        _couple1{
            x = left and 8 or 16, y = 7,
            levels = { 4, 15 },
            state = crops.of_param('couple_'..chan),
        }
        _couple2{
            x = left and 8 or 16, y = 8,
            levels = { 4, 15 },
            state = crops.of_param('couple_'..chan),
        }
    end
end

local function App()
    local _channels = {}
    for i = 1,2 do _channels[i] = Channel() end

    local _focus_bg = Grid.fills()

    return function(props)
        _focus_bg{
            x = 7, y = 1, size = 16, wrap = 4, level = 4,
        }

        _channels[1]{
            side = 'left', channel = 1,
        }
        _channels[2]{
            side = 'right', channel = 2,
        }
    end
end

return App
