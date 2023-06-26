local cs_lvl = cs.def{ min = 0, max = 5, default = 4, units = 'v' }

for chan = 1,2 do
    local actions = {}

    function actions.record_feedback()
        -- update engine.rec_amp & engine.feedback_amp based on record & feedback
        
        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    function actions.play_output_level()
        -- upade engine.out_amp based on play & out_level

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    function actions.clear()
        -- clear buffer based on channel assignment

        crops.dirty.grid = true
    end

    --TODO: update separate rate_write & rate_read commands
    function actions.rate_start_end()
        -- update engine.rate based on reverse, oct, and rate 

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    params:add_separator('channel '..chan)
    
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, id = 'record',
        action = actions.record_feedback,
    }
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'play_'..chan, id = 'play',
        action = actions.play_output_level,
    }
    params:add{
        type = 'binary', behavior = 'trigger',
        id = 'clear_'..chan, name = 'clear',
        action = actions.clear
    }
    params:add{
        type = 'number', id = 'buffer_'..chan, name = 'buffer',
        min = 1, max = 2, default = chan,
        action = function(v) engine.buf(chan, v) end
    }

    --TODO: separate write & read params, couple params
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_'..chan, id = 'reverse',
        action = actions.rec_feedback,
    }
    params:add{
        type = 'number', id = 'octave_'..chan, name = 'octave',
        min = -2, max = 2, default = 0,
        action = actions.rate
    }

    --TODO: bits & shape-toggles

    params:add{
        type = 'control', id = 'output_level_'..chan, name = 'output level',
        controlspec = cs_lvl,
        action = actions.play_output_level
    }
    params:add{
        type = 'control', id = 'output_pan_'..chan, name = 'output pan',
        controlspec = cs.def{ min = -5, max = 5, default = 0, units = 'v' }
        action = function(v)
            engine.output_pan_(chan, v/5)            
        end
    }
    params:add{
        type = 'control', id = 'feedback_'..chan, name = 'feedback',
        controlspec = cs_lvl, action = actions.record_feedback
    }

    local max_time = 4

    params:add{
        type = 'control', id = 'loop_start_'..chan, name = 'loop start',
        controlspec = cs.def{ min = 0, max = max_time, default = 0 },
        action = actions.rate_start_end,
    }
    params:add{
        type = 'control', id = 'loop_end_'..chan, name = 'loop end',
        controlspec = cs.def{ min = 0, max = max_time, default = max_time },
        action = actions.rate_start_end,
    }

    --TODO: smooth, interp
end
