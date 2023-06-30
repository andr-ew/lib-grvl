local App = {}

local function Channel()
    local _rec = Grid.toggle()
    local _play = Grid.toggle()
    local _clear = Grid.trigger()
    local _buffer = Grid.integer()

    local _reverse = Grid.toggle()

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

        _reverse{
            x = left and 2 or 9, y = 7,
            levels = { 4, 15 },
            state = crops.of_param('reverse_'..chan),
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
