params:add{
    type = 'number',
    id = 'note',
    min = -2,
    max = 2,
    default = -1,
    action = function(value)
        engine.rate_b(2^value)

        crops.dirty.grid = true
    end
}
