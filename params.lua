local time_volt_scale = 5
local manual_seconds = 7/4
local max_seconds = 55
local silent = true

--add track params
for chan = 1,2 do
    local actions = {}

    do
        --TODO: 'rate' param
        local function get_rate_w()
            local play = params:get('play_'..chan)
            local rev_w = (params:get('reverse_write_'..chan)==0) and 1 or -1
            local oct_w = params:get('octave_write_'..chan)
            return 2^oct_w * rev_w * play
        end
        local function get_rate_r()
            local play = params:get('play_'..chan)
            local rev_r = (params:get('reverse_read_'..chan)==0) and 1 or -1
            local oct_r = params:get('octave_read_'..chan)
            return 2^oct_r * rev_r * play
        end

        local headroom
        local timer
        local timer_quant
        local timer_seconds
        local recording
        local recorded
        local manual
        local loaded
        local loaded_seconds

        local function reset()
            headroom = 5
            -- clock.cancel(timer)
            timer_quant = 0.02
            timer_seconds = 0
            recording = false
            recorded = false
            manual = false
            loaded = false
            loaded_seconds = 0
        end
        reset()
        
        function actions.clear()
            local buf = params:get('buffer_'..chan)
            
            engine.clear_buf(buf)

            local len = math.abs(params:get('loop_end_'..chan) - params:get('loop_start_'..chan))

            if (not manual) or (len==0) then
                params:set('record_'..chan, 0, silent)
                params:set('loop_start_'..chan, 0, silent)
                params:set('loop_end_'..chan, 0, silent)
                reset()
            end

            actions.rate_start_end()

            crops.dirty.grid = true
        end

        for _,head in ipairs{ 'read', 'write' } do
            actions['position_'..head] = function(pos)
                pos = pos or 0

                engine['pos_minutes_'..head](chan, pos/60) 
                engine['pos_trig_'..head](chan, 1)

                clock.run(function() 
                    clock.sleep(0.03)
                    engine['pos_trig_'..head](chan, 0)
                end)
            end
        end

        local function tick()
            while recording do
                local r_w = get_rate_w()

                clock.sleep(timer_quant)
                timer_seconds = timer_seconds + (timer_quant * r_w)

                if timer_seconds > max_seconds then punch_out(true) end
            end
        end

        local function punch_in()
            recording = true
            actions.position_write(0)

            timer = clock.run(tick)

            params:set('record_'..chan, 1, silent)

            params:set('loop_start_'..chan, 0, silent)
            params:set('loop_end_'..chan, time_volt_scale, silent)
        end
        local function punch_out(manual)
            actions.position_write(0)

            recording = false
            recorded = true
            
            params:set('record_'..chan, manual and 1 or 0, silent)
        end

        --TODO: sample loading action

        function actions.rate_start_end()
            local r_w = get_rate_w()
            local r_r = get_rate_r()
            local st_rel = params:get('loop_start_'..chan) / time_volt_scale
            local en_rel = params:get('loop_end_'..chan) / time_volt_scale

            local len_rel = math.abs(en_rel - st_rel)

            if len_rel > 0 and (not (recording or recorded or manual or loaded)) then
                manual = true
                punch_out(manual)
                return actions.rate_start_end()
            end
            
            local rec = params:get('record_'..chan)
            
            if recorded or loaded or manual then
                engine.rec_enable(chan, rec)
            elseif recording then
                engine.rec_enable(chan, 1)

                if rec < 1 then
                    punch_out()
                    return actions.rate_start_end()
                end
            else
                engine.rec_enable(chan, 0)

                if rec > 0 then
                    punch_in()
                    return actions.rate_start_end()
                end
            end

            local st, en

            if recorded or manual or loaded then
                local len = (
                    (manual and manual_seconds) 
                    or (loaded and loaded_seconds) 
                    or (recorded and timer_seconds)
                )
                st = st_rel * len 
                en = en_rel * len 
            else
                st = 0
                en = max_seconds
            end

            --TODO: looper-recorded decoupled phases have decoupled start/end
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
            engine.couple_phases(chan, params:get('couple_'..chan))


            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    end

    params:add_separator('channel '..chan)
    
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, name = 'record', default = 0,
        action = actions.rate_start_end
    }
    params:add{
        type = 'binary', behavior = 'toggle',
        id = 'play_'..chan, name = 'play', default = 1,
        action = actions.rate_start_end
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
        type = 'number', id = 'bit_depth_'..chan, name = 'bit depth',
        min = 4, max = 9, default = 9,
        action = function(v) 
            engine.bit_depth(chan, v) 

            crops.dirty.grid = true
        end
    }
    params:add{
        type = 'number', id = 'detritus_'..chan, name = 'detritus',
        min = 1, max = 6, default = 1,
        action = function(v) 
            engine.read_gap(chan, v) 

            crops.dirty.grid = true
        end
    }
    params:add{
        type = 'control', id = 'wet_dry_'..chan, name = 'wet/dry',
        controlspec = cs.def{ min = 0, max = 5, default = 2.5, units = 'v' },
        action = function(v)
            engine.wet_dry(chan, v/5)
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    
    --TODO: bitnoise?
    --TODO: drive

    --TODO: might need to use math.log10(amp) on norns
    local function ampdb(amp) return math.log(amp, 10) * 20.0 end

    local function dbamp(db) return 10.0^(db*0.05) end
    local function volt_amp(volt)
        local minval = -math.huge
        local maxval = 0
        local range = dbamp(maxval) - dbamp(minval)

        local scaled = volt/4
        local db = ampdb(scaled * scaled * range + dbamp(minval))
        local amp = dbamp(db)

        return amp
    end

    params:add{
        type = 'control', id = 'output_level_'..chan, name = 'output level',
        controlspec = cs.def{ min = 0, max = 10, default = 4, units = 'v' },
        action = function(v)
            engine.out_amp(chan, volt_amp(v))
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
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

    --TODO: refactor to use volts, maybe 0-7
    params:add{
        type = 'control', id = 'loop_start_'..chan, name = 'loop start',
        controlspec = cs.def{ min = 0, max = time_volt_scale, default = 0, units = 'v' },
        action = actions.rate_start_end,
    }
    params:add{
        type = 'control', id = 'loop_end_'..chan, name = 'loop end',
        controlspec = cs.def{ min = 0, max = time_volt_scale, default = 0, units = 'v' },
        action = actions.rate_start_end,
    }

    local function volt_cutoff(volt)
        return util.linexp(0, 7, 20, 20000, volt)
    end
    -- local function cutoff_volt(cut)
    --     return util.explin(20, 20000, 0, 7, cut)
    -- end
    local function volt_q(volt, inverse)
        return util.linexp(0, 1, 0.01, 1.5, (inverse and (5 - volt) or volt) / 5)
    end

    params:add{
        type = 'control', id = 'lowpass_freq_'..chan, name = 'lowpass freq',
        controlspec = cs.def{ min = 0, max = 7, default = 7, units = 'v' },
        action = function(v)
            engine.lp_freq(chan, volt_cutoff(v))
        end
    } 
    params:add{
        type = 'control', id = 'lowpass_q_'..chan, name = 'lowpass q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function(v)
            engine.lp_q(chan, volt_q(v))
        end
    }
    params:add{
        type = 'control', id = 'highpass_freq_'..chan, name = 'highpass freq',
        controlspec = cs.def{ min = 0, max = 7, default = 0, units = 'v' },
        action = function(v)
            engine.hp_freq(chan, volt_cutoff(v))
        end
    } 
    params:add{
        type = 'control', id = 'highpass_q_'..chan, name = 'highpass q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function(v)
            engine.hp_rq(chan, volt_q(v, true))
        end
    }

    --TODO: interp

    --TODO: test & adjust quants
    params:add{
        type = 'control', id = 'silt_freq_'..chan, name = 'silt freq',
        controlspec = cs.def{ min = 0, max = 17, default = 16 },
        action = function(v)
            local hz = (1/5) * 2^v
            engine.mod_freq(chan, hz)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'control', id = 'silt_depth_'..chan, name = 'silt depth',
        controlspec = cs.def{ min = -5, max = 5, default = 0, units = 'v' },
        action = function(v)
            local depth = v * 10
            engine.mod_depth(chan, depth)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'option', id = 'silt_source_'..chan, name = 'silt source',
        options = { 'in R', 'sin', 'tri', 'saw', 'sqr', 'noise' }, default = 3, 
        action = function(v)
            engine.mod_source(chan, v)

            crops.dirty.screen = true
        end
    }
    params:add{
        type = 'option', id = 'silt_dest_'..chan, name = 'silt dest',
        options = { 'read phase', 'write phase', 'filter freq', 'amplitude' }, default = 1,
        action = function(v)
            engine.mod_read_phase(chan, 0)
            engine.mod_write_phase(chan, 0)
            engine.mod_filter_freq(chan, 0)
            engine.mod_out_amp(chan, 0)

            if v==1 then
                engine.mod_read_phase(chan, 1)
            elseif v==2 then
                engine.mod_write_phase(chan, 1)
            elseif v==3 then
                engine.mod_filter_freq(chan, 225)
            elseif v==4 then
                engine.mod_out_amp(chan, 1)
            end
        end
    }
end

--add destination params
do
    local function action(dest, v)
        mod_src.crow.update()

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    patcher.add_assginment_params(action)
end

--add LFO params
for i = 1,2 do
    params:add_separator('lfo '..i)
    mod_src.lfos[i]:add_params('lfo_'..i)
end
