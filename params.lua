for chan = 1,2 do
    local actions = {}

    -- function actions.record_feedback()
    --     local rec = params:get('record_'..chan)
    --     local fb = params:get('feedback_'..chan)/5

    --     if rec>0 then
    --         engine.rec_amp(chan, 1)
    --         engine.feedback_amp(chan, fb)
    --     else
    --         engine.rec_amp(chan, 0)
    --         engine.feedback_amp(chan, 1)
    --     end

    --     crops.dirty.grid = true
    --     crops.dirty.screen = true
    --     crops.dirty.arc = true
    -- end

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

    --TODO: looper-recorded decoupled phases have decoupled start/end
    function actions.rate_start_end()
        local rev_w = (params:get('reverse_write_'..chan)==0) and 1 or -1
        local oct_w = params:get('octave_write_'..chan)
        local r_w = 2^oct_w * rev_w
        local rev_r = (params:get('reverse_read_'..chan)==0) and 1 or -1
        local oct_r = params:get('octave_read_'..chan)
        local r_r = 2^oct_r * rev_r

        --TODO: rate
        local st = params:get('loop_start_'..chan)
        local en = params:get('loop_end_'..chan)

        engine.couple_phases(chan, params:get('couple_'..chan))

        if st < en then
            engine.rate_write(chan, r_w)
            engine.rate_read(chan, r_r)

            engine.start_minutes_write(chan, st/60)
            engine.end_minutes_write(chan, en/60)
            engine.start_minutes_read(chan, st/60)
            engine.end_minutes_read(chan, en/60)
        else
            engine.rate_write(chan, -r_w)
            engine.rate_read(chan, -r_r)

            engine.start_minutes_write(chan, en/60)
            engine.end_minutes_write(chan, st/60)
            engine.start_minutes_read(chan, en/60)
            engine.end_minutes_read(chan, st/60)
        end

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    params:add_separator('channel '..chan)
    
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, name = 'record', default = 1,
        action = function(v)
            engine.rec_enable(chan, v)

            crops.dirty.grid = true
        end
    }
    --TODO: play toggles rate==0 instead of level==0
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
        id = 'reverse_write_'..chan, name = 'reverse (write)',
        action = actions.rate_start_end,
    }
    params:add{
        type = 'number', id = 'octave_write_'..chan, name = 'octave (write)',
        min = -3, max = 2, default = 0,
        action = actions.rate_start_end
    }
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_read_'..chan, name = 'reverse (read)',
        action = actions.rate_start_end,
    }
    params:add{
        type = 'number', id = 'octave_read_'..chan, name = 'octave (read)',
        min = -3, max = 2, default = 0,
        action = actions.rate_start_end
    }
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'couple_'..chan, name = 'read/write couple', default = 1,
        action = actions.rate_start_end,
    }
    --TODO: rate slew

    params:add{
        type = 'control', id = 'bit_depth_'..chan, name = 'bit depth',
        controlspec = cs.def{ min = 4, max = 9, default = 9 },
        action = function(v) 
            engine.bit_depth(chan, v) 

            crops.dirty.grid = true
        end
    }
    params:add{
        type = 'number', id = 'silt_'..chan, name = 'silt',
        min = -5, max = 2, default = 1,
        action = function(v) 
            engine.head_offset(chan, v) 

            crops.dirty.grid = true
        end
    }
    
    --TODO: bitnoise?
    --TODO: drive

    params:add{
        type = 'control', id = 'output_level_'..chan, name = 'output level',
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        action = actions.play_output_level
    }
    params:add{
        type = 'control', id = 'output_pan_'..chan, name = 'output pan',
        controlspec = cs.def{ min = -5, max = 5, default = chan==1 and -4 or 4, units = 'v' },
        action = function(v)
            engine.out_pan(chan, v/5)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'control', id = 'feedback_'..chan, name = 'feedback',
        controlspec = cs.def{ min = 0, max = 5, default = 5/2, units = 'v' }, 
        action = function(v)
            engine.feedback_amp(chan, v/5)            

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    --TODO: rate (continuous control)

    local max_time = 7/4

    --TODO: refactor to use volts, maybe 0-7
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

    --TODO: interp

    --TODO: test & adjust quants
    params:add{
        type = 'control', id = 'mod_osc_freq_'..chan, name = 'mod osc freq',
        controlspec = cs.def{ min = 0, max = 17, default = 16 },
        action = function(v)
            local hz = (1/5) * 2^v
            engine.mod_freq(chan, hz)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'control', id = 'mod_osc_depth_'..chan, name = 'mod osc depth',
        controlspec = cs.def{ min = -5, max = 5, default = 1/10, units = 'v' },
        action = function(v)
            local depth = v * 10
            engine.mod_depth(chan, depth)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'option', id = 'mod_osc_type_'..chan, name = 'mod osc type',
        options = { 'in R', 'sin', 'tri', 'saw', 'sqr', 'noise' }, default = 3, 
        action = function(v)
            engine.mod_source(chan, v)

            crops.dirty.screen = true
        end
    }
    params:add{
        type = 'option', id = 'mod_osc_dest_'..chan, name = 'mod osc dest',
        options = { 'read phase', 'write phase', 'filter freq' }, default = 1,
        action = function(v)
            engine.mod_read_phase(chan, 0)
            engine.mod_write_phase(chan, 0)
            engine.mod_filter_freq(chan, 0)

            if v==1 then
                engine.mod_read_phase(chan, 1)
            elseif v==2 then
                engine.mod_write_phase(chan, 1)
            elseif v==3 then
                engine.mod_filter_freq(chan, 225)
            end
        end
    }
end
