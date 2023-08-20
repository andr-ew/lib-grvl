local time_volt_scale = 5
local manual_seconds = 7/4
local max_seconds = 55
local silent = true
local timer_quant = 0.02
    
local buffers = grvl.buffers
local reset_buffer = grvl.reset_buffer

-- add shared actions    
local actions = {}
do
    --TODO: 'rate' param
    local function get_rate_w(chan)
        local play = patcher.get_destination_plus_param('play_'..chan)
        local rev_w = (
            patcher.get_destination_plus_param('reverse_write_'..chan) == 0
        ) and 1 or -1
        local oct_w = patcher.get_destination_plus_param('octave_write_'..chan)
        return 2^oct_w * rev_w * play
    end
    local function get_rate_r(chan)
        local play = patcher.get_destination_plus_param('play_'..chan)
        local rev_r = (
            patcher.get_destination_plus_param('reverse_read_'..chan) == 0
        ) and 1 or -1
        local oct_r = patcher.get_destination_plus_param('octave_read_'..chan)
        return 2^oct_r * rev_r * play
    end

    local function position(head, chan, pos) 
        pos = pos or 0

        engine['pos_minutes_'..head](chan, pos/60) 
        engine['pos_trig_'..head](chan, 1)

        clock.run(function() 
            clock.sleep(0.03)
            engine['pos_trig_'..head](chan, 0)
        end)
    end

    local function tick(chan, buf)
        while buffers[buf].recording[chan] do
            local r_w = get_rate_w(chan)

            clock.sleep(timer_quant)
            buffers[buf].timer_seconds = buffers[buf].timer_seconds + (timer_quant * r_w)

            if buffers[buf].timer_seconds > max_seconds then punch_out(true) end
        end
    end
    local function punch_in(chan, buf)
        buffers[buf].recording[chan] = true
        clock.run(tick, chan, buf)

        if buf == patcher.get_destination_plus_param('buffer_'..chan) then
            position('write', chan, 0)

            params:set('record_'..chan, 1, silent)

            params:set('loop_start_'..chan, 0, silent)
            params:set('loop_end_'..chan, time_volt_scale, silent)
        end
    end
    local function punch_out(chan, buf)
        buffers[buf].recording[chan] = false --this line stops the clock
        buffers[buf].recorded = true
        
        if buffers[buf].manual then
            buffers[buf].duration_seconds = manual_seconds
        else
            buffers[buf].duration_seconds = buffers[buf].timer_seconds
        end
        
        if buf == patcher.get_destination_plus_param('buffer_'..chan) then
            position('write', chan, 0)

            if buffers[buf].manual then
                params:set('record_'..chan, 1, silent)
            end
        end
    end

    --TODO: support sample loading
    function actions.rate_start_end()
        for chan = 1,2 do
            local r_w = get_rate_w(chan)
            local r_r = get_rate_r(chan)
            local st_rel = patcher.get_destination_plus_param('loop_start_'..chan) 
                / time_volt_scale
            local en_rel = patcher.get_destination_plus_param('loop_end_'..chan) 
                / time_volt_scale

            local len_rel = math.abs(en_rel - st_rel)
            
            local buf = patcher.get_destination_plus_param('buffer_'..chan)

            engine.buf(chan, buf)

            if len_rel > 0 and (not (
                buffers[buf].recording[chan]
                or buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            )) then
                buffers[buf].manual = true
                punch_out(chan, buf)

                return actions.rate_start_end()
            end
            
            local rec = patcher.get_destination_plus_param('record_'..chan)
            local should_rec = len_rel > 0 and 1 or 0
                
            if
                buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            then
                engine.rec_enable(chan, rec & should_rec)
            elseif buffers[buf].recording[chan] then
                engine.rec_enable(chan, rec & should_rec)

                if rec < 1 then
                    punch_out(chan, buf)

                    return actions.rate_start_end()
                end
            else
                engine.rec_enable(chan, 0)

                if rec > 0 then
                    punch_in(chan, buf)

                    return actions.rate_start_end()
                end
            end

            local st, en

            if
                buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            then
                local len = buffers[buf].duration_seconds

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
            engine.couple_phases(chan, patcher.get_destination_plus_param('couple_'..chan))

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    end
end

local function add_param_dest(args)
    params:add(args)
    patcher.add_destination(args.id, args.action)
end
    
local function clear(buf)
    engine.clear_buf(buf)

    for chan = 1,2 do
        if buf == patcher.get_destination_plus_param('buffer_'..chan) then
            local len = math.abs(
                patcher.get_destination_plus_param('loop_end_'..chan) 
                - patcher.get_destination_plus_param('loop_start_'..chan)
            )

            if (not buffers[buf].manual) or (len==0) then
                params:set('record_'..chan, 0, silent)
                params:set('loop_start_'..chan, 0, silent)
                params:set('loop_end_'..chan, 0, silent)
            end
        end
    end
            
    reset_buffer(buf)
    actions.rate_start_end()
end

--add track params
for chan = 1,2 do
    params:add_separator('channel '..chan)

    add_param_dest{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, name = 'record', default = 0,
        action = actions.rate_start_end
    }
    add_param_dest{
        type = 'binary', behavior = 'toggle',
        id = 'play_'..chan, name = 'play', default = 1,
        action = actions.rate_start_end
    }
    params:add{
        type = 'binary', behavior = 'trigger',
        id = 'clear_'..chan, name = 'clear',
        action = function()
            local buf = patcher.get_destination_plus_param('buffer_'..chan)
            clear(buf)
        end
    }
    add_param_dest{
        type = 'number', id = 'buffer_'..chan, name = 'buffer',
        min = 1, max = 2, default = chan,
        action = actions.rate_start_end
    }
    add_param_dest{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_write_'..chan, name = 'reverse (write)',
        action = actions.rate_start_end,
    }
    add_param_dest{
        type = 'number', id = 'octave_write_'..chan, name = 'octave (write)',
        min = -3, max = 2, default = 0,
        action = actions.rate_start_end
    }
    add_param_dest{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_read_'..chan, name = 'reverse (read)',
        action = actions.rate_start_end,
    }
    add_param_dest{
        type = 'number', id = 'octave_read_'..chan, name = 'octave (read)',
        min = -3, max = 2, default = 0,
        action = actions.rate_start_end
    }
    add_param_dest{
        type = 'binary', behavior = 'toggle',
        id = 'couple_'..chan, name = 'read/write couple', default = 1,
        action = actions.rate_start_end,
    }
    --TODO: rate slew

    add_param_dest{
        type = 'number', id = 'bit_depth_'..chan, name = 'bit depth',
        min = 4, max = 9, default = 9,
        action = function() 
            engine.bit_depth(chan, patcher.get_destination_plus_param('bit_depth_'..chan))

            crops.dirty.grid = true
        end
    }
    add_param_dest{
        type = 'number', id = 'detritus_'..chan, name = 'detritus',
        min = 1, max = 6, default = 1,
        action = function() 
            engine.read_gap(chan, patcher.get_destination_plus_param('detritus_'..chan))

            crops.dirty.grid = true
        end
    }
    add_param_dest{
        type = 'control', id = 'wet_dry_'..chan, name = 'wet/dry',
        controlspec = cs.def{ min = 0, max = 5, default = 2.5, units = 'v' },
        action = function()
            engine.wet_dry(chan, patcher.get_destination_plus_param('wet_dry_'..chan)/5)
            
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

    add_param_dest{
        type = 'control', id = 'output_level_'..chan, name = 'output level',
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        action = function()
            engine.out_amp(
                chan, 
                volt_amp(patcher.get_destination_plus_param('output_level_'..chan))
            )
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    add_param_dest{
        type = 'control', id = 'output_pan_'..chan, name = 'output pan',
        controlspec = cs.def{ min = -5, max = 5, default = chan==1 and -4 or 4, units = 'v' },
        action = function()
            engine.out_pan(chan, patcher.get_destination_plus_param('output_pan_'..chan)/5)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    add_param_dest{
        type = 'control', id = 'feedback_'..chan, name = 'feedback',
        controlspec = cs.def{ min = 0, max = 5, default = 5/2, units = 'v' }, 
        action = function()
            engine.feedback_amp(
                chan, 
                patcher.get_destination_plus_param('feedback_'..chan)/5
            )

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    --TODO: rate (continuous control)

    add_param_dest{
        type = 'control', id = 'loop_start_'..chan, name = 'loop start',
        controlspec = cs.def{ min = 0, max = time_volt_scale, default = 0, units = 'v' },
        action = actions.rate_start_end,
    }
    add_param_dest{
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

    add_param_dest{
        type = 'control', id = 'lowpass_freq_'..chan, name = 'lowpass freq',
        controlspec = cs.def{ min = 0, max = 7, default = 7, units = 'v' },
        action = function()
            engine.lp_freq(
                chan, 
                volt_cutoff(patcher.get_destination_plus_param('lowpass_freq_'..chan))
            )
        end
    } 
    add_param_dest{
        type = 'control', id = 'lowpass_q_'..chan, name = 'lowpass q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function()
            engine.lp_q(
                chan, 
                volt_q(patcher.get_destination_plus_param('lowpass_q_'..chan))
            )
        end
    }
    add_param_dest{
        type = 'control', id = 'highpass_freq_'..chan, name = 'highpass freq',
        controlspec = cs.def{ min = 0, max = 7, default = 0, units = 'v' },
        action = function()
            engine.hp_freq(
                chan, 
                volt_cutoff(patcher.get_destination_plus_param('highpass_freq_'..chan))
            )
        end
    } 
    add_param_dest{
        type = 'control', id = 'highpass_q_'..chan, name = 'highpass q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function()
            engine.hp_rq(
                chan, 
                volt_q(patcher.get_destination_plus_param('highpass_q_'..chan), true)
            )
        end
    }

    --TODO: interp

    --TODO: test & adjust quants
    add_param_dest{
        type = 'control', id = 'silt_freq_'..chan, name = 'silt freq',
        controlspec = cs.def{ min = 0, max = 17, default = 16 },
        action = function()
            local hz = (1/5) * 2^patcher.get_destination_plus_param('silt_freq_'..chan)
            engine.mod_freq(chan, hz)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    add_param_dest{
        type = 'control', id = 'silt_depth_'..chan, name = 'silt depth',
        controlspec = cs.def{ min = -5, max = 5, default = 0, units = 'v' },
        action = function()
            local depth = patcher.get_destination_plus_param('silt_depth_'..chan) * 10
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
