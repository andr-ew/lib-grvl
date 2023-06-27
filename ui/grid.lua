local App = {}

local function Channel()
    local _rec = Grid.toggle()
    local _play = Grid.toggle()
    local _clear = Grid.trigger()

    return function(props)
        local chan = props.channel
        local right = props.side=='right'
        local left = right and 8 or 0

        
    end
end

local function App()
    local _channels = {}
    for i = 1,2 do _channels[i] = Channel() end

    return function(props)
        -- for _,_channel in ipairs(_channels) do
        -- end

        _channels[1]{
            side = 'left', channel = 1,
        }
        _channels[2]{
            side = 'right', channel = 2,
        }
    end
end

return App
