paramsMenu.highlightColors.r = 255
paramsMenu.highlightColors.g = 95
paramsMenu.highlightColors.b = 31

for chan = 1,2 do
    local actions = {}

    function actions.record_feedback()
        local rec = params:get('record_'..chan)
        local fb = params:get('feedback_'..chan)/5

        if rec>0 then
            engine.rec_amp(chan, 1)
            engine.feedback_amp(chan, fb)
        else
            engine.rec_amp(chan, 0)
            engine.feedback_amp(chan, 1)
        end

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    function actions.play_output_level()
        local play = params:get('play_'..chan)
        local out = params:get('output_level_'..chan)/5

        engine.out_amp(chan, out * play)
        
        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    function actions.clear()
        local buf = params:get('buffer_'..chan)
        
        engine.clear_buf(buf)

        crops.dirty.grid = true
    end

    --TODO: update separate rate_write & rate_read commands
    function actions.rate_start_end()
        local rev = (params:get('reverse_'..chan)==0) and 1 or -1
        local oct = params:get('octave_'..chan)
        --TODO: rate
        local st = params:get('loop_start_'..chan)
        local en = params:get('loop_end_'..chan)
        local r = 2^oct * rev

        if st < en then
            engine.rate(chan, r)
            engine.start_minutes(chan, st/60)
            engine.end_minutes(chan, en/60)
        else
            engine.rate(chan, -r)
            engine.start_minutes(chan, en/60)
            engine.end_minutes(chan, st/60)
        end

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    params:add_separator('channel '..chan)
    
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, name = 'record', default = 0,
        action = actions.record_feedback,
    }
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'play_'..chan, name = 'play', default = 1,
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
        action = function(v) 
            engine.buf(chan, v) 

            crops.dirty.grid = true
        end
    }

    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_'..chan, name = 'reverse',
        action = actions.rate_start_end,
    }

    --TODO: separate write & read params, couple param
    params:add{
        type = 'number', id = 'octave_'..chan, name = 'octave',
        min = -2, max = 2, default = 0,
        action = actions.rate_start_end
    }

    --TODO: bits & shape-toggles
    --TODO: feedback path options for bits (?)

    params:add{
        type = 'control', id = 'output_level_'..chan, name = 'output level',
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        action = actions.play_output_level
    }
    params:add{
        type = 'control', id = 'output_pan_'..chan, name = 'output pan',
        controlspec = cs.def{ min = -5, max = 5, default = 0, units = 'v' },
        action = function(v)
            engine.output_pan_(chan, v/5)            

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'control', id = 'feedback_'..chan, name = 'feedback',
        controlspec = cs.def{ min = 0, max = 5, default = 5/2, units = 'v' }, 
        action = actions.record_feedback
    }
    --TODO: rate (continuous control)

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
