local time_volt_scale = 5
local manual_seconds = 7/4
local max_seconds = 55
local silent = true
local timer_quant = 0.02

grvl.time_volt_scale = time_volt_scale
    
local buffers = grvl.buffers
local reset_buffer = grvl.reset_buffer

local vals = {}

grvl.values = vals

local update = {}

do
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
            local r_w = vals.rate_w[chan]

            clock.sleep(timer_quant)
            buffers[buf].timer_seconds = buffers[buf].timer_seconds + (timer_quant * r_w)

            if buffers[buf].timer_seconds > max_seconds then punch_out(true) end
        end
    end
    local function punch_in(chan, buf)
        buffers[buf].recording[chan] = true
        clock.run(tick, chan, buf)

        if buf == vals.buf[chan] then
            position('write', chan, 0)

            params:set('record_'..chan, 1, silent)
            vals.rec[chan] = 1

            params:set('loop_start_'..chan, 0, silent)
            params:set('loop_end_'..chan, time_volt_scale, silent)
            vals.st_rel[chan] = 0
            vals.en_rel[chan] = 1
        end
            
        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end
    local function punch_out(chan, buf)
        buffers[buf].recording[chan] = false --this line stops the clock
        buffers[buf].recorded = true
        
        if buffers[buf].manual then
            buffers[buf].duration_seconds = manual_seconds --TODO: scale based on current rate
        else
            buffers[buf].duration_seconds = buffers[buf].timer_seconds
        end
        
        if buf == vals.buf[chan] then
            position('write', chan, 0)

            if buffers[buf].manual then
                params:set('record_'..chan, 1, silent)
                vals.rec[chan] = 1
            end
        end

        crops.dirty.grid = true
        crops.dirty.screen = true
        crops.dirty.arc = true
    end

    vals.play = { 1, 1 }
    vals.rate = { 0, 0 }
    vals.rev_w = { 0, 0 } -- = (v == 0) and 1 or -1
    vals.oct_w = { 0, 0 }
    vals.rev_r = { 0, 0 } -- = (v == 0) and 1 or -1
    vals.oct_r = { 0, 0 }
    vals.couple = { 1, 1 }

    vals.rate_w = { 1, 1 }
    vals.rate_r = { 1, 1 }

    --TODO: call when start passes end / vice-versa
    function update.rate(chan)
        local play = vals.play[chan]
        local rate = vals.rate[chan]
        local rev_w = vals.rev_w[chan]
        local oct_w = vals.oct_w[chan] 
        vals.rate_w[chan] = 2^oct_w * 2^rate * rev_w * play
        
        local play = vals.play[chan]
        local rate = vals.rate[chan]
        local rev_r = vals.rev_r[chan]
        local oct_r = vals.oct_r[chan]
        vals.rate_r[chan] = 2^oct_r * 2^rate * rev_r * play
        
        local r_w = vals.rate_w[chan]
        local r_r = vals.rate_r[chan]

        local st, en = vals.st[chan], vals.en[chan]
        local flip = (st < en) and 1 or -1
            
        engine.rate_write(chan, r_w * flip)
        engine.rate_read(chan, r_r * flip)
    end
    
    vals.st_rel = { 0, 0 } -- = v / time_volt_scale
    vals.en_rel = { 0, 0 } -- = v / time_volt_scale
    vals.last_st_rel = { 0, 0 }
    vals.last_en_rel = { 0, 0 }
    vals.len_rel = { 0, 0 }
    vals.buf = { 1, 2 }
    vals.rec = { 0, 0 }
    vals.st = { 0, 0 }
    vals.en = { 0, 0 }
    vals.couple = { 1, 1 }

    function update.start_end(chan, silent)
        local st_rel = vals.st_rel[chan]
        local en_rel = vals.en_rel[chan]
        vals.len_rel[chan] = math.abs(en_rel - st_rel)
            
        local len_rel = vals.len_rel[chan]
        
        local buf = vals.buf[chan]
        if 
            len_rel > 0 and (not (
                buffers[buf].recording[chan]
                or buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            )) 
            -- and (not silent)
        then
            return update.buf_rec()
        end 

        if
            buffers[buf].recorded 
            or buffers[buf].manual 
            or buffers[buf].loaded
        then
            local len = buffers[buf].duration_seconds

            vals.st[chan] = st_rel * len
            vals.en[chan] = en_rel * len
        else
            vals.st[chan] = 0
            vals.en[chan] = max_seconds
        end

        local st, en = vals.st[chan], vals.en[chan]
        
        local flip = (vals.st_rel[chan] < vals.en_rel[chan]) and 1 or -1
        local flip_last = (vals.last_st_rel[chan] < vals.last_en_rel[chan]) and 1 or -1

        --TODO: looper-recorded decoupled phases have decoupled start/end
        if flip then
            engine.start_minutes_write(chan, st/60)
            engine.end_minutes_write(chan, en/60)
            engine.start_minutes_read(chan, st/60)
            engine.end_minutes_read(chan, en/60)
        else
            engine.start_minutes_write(chan, en/60)
            engine.end_minutes_write(chan, st/60)
            engine.start_minutes_read(chan, en/60)
            engine.end_minutes_read(chan, st/60)
        end

        if (flip ~= flip_last) and (not silent) then
            update.rate(chan)
        end
    end

    function update.buf_rec()
        for chan = 1,2 do
            local st_rel = vals.st_rel[chan]
            local en_rel = vals.en_rel[chan]
            vals.len_rel[chan] = math.abs(en_rel - st_rel)
                
            local len_rel = vals.len_rel[chan]
            local buf = vals.buf[chan]

            engine.buf(chan, buf)

            if len_rel > 0 and (not (
                buffers[buf].recording[chan]
                or buffers[buf].recorded 
                or buffers[buf].manual 
                or buffers[buf].loaded
            )) then
                buffers[buf].manual = true
                punch_out(chan, buf)

                update.buf_rec()
            
                params:lookup_param('loop_start_'..chan):bang()
                params:lookup_param('loop_end_'..chan):bang()
                params:lookup_param('record_'..chan):bang()

                return
            end
            
            local rec = vals.rec[chan] 
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

                    update.buf_rec()
                
                    params:lookup_param('loop_start_'..chan):bang()
                    params:lookup_param('loop_end_'..chan):bang()
                    params:lookup_param('record_'..chan):bang()

                    return
                end
            else
                engine.rec_enable(chan, 0)

                if rec > 0 then
                    punch_in(chan, buf)

                    update.buf_rec()
                
                    params:lookup_param('loop_start_'..chan):bang()
                    params:lookup_param('loop_end_'..chan):bang()
                    params:lookup_param('record_'..chan):bang()

                    return
                end
            end

            update.start_end(chan, silent)
            update.rate(chan)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    end
end

local function clear(buf)
    engine.clear_buf(buf)

    for chan = 1,2 do
        if buf == vals.buf[chan] then
            local len = vals.len_rel[chan]
            if (not buffers[buf].manual) or (len==0) then
                params:set('record_'..chan, 0, silent)
                params:set('loop_start_'..chan, 0, silent)
                params:set('loop_end_'..chan, 0, silent)
                vals.rec[chan] = 0
                vals.st_rel[chan] = 0
                vals.en_rel[chan] = 0
            end
        end
    end
            
    reset_buffer(buf)
    update.buf_rec()
                    
    for chan = 1,2 do
        if buf == vals.buf[chan] then
            params:lookup_param('loop_start_'..chan):bang()
            params:lookup_param('loop_end_'..chan):bang()
            params:lookup_param('record_'..chan):bang()
        end
    end
end

--add track params
for chan = 1,2 do
    params:add_separator('channel '..chan)

    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'record_'..chan, name = 'record', default = 0,
        action = function(v)
            vals.rec[chan] = v; update.buf_rec()
        end
    }
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'play_'..chan, name = 'play', default = 1,
        action = function(v)
            vals.play[chan] = v; update.rate(chan)
        end
    }
    --TODO: trigger dest
    params:add{
        type = 'binary', behavior = 'trigger',
        id = 'clear_'..chan, name = 'clear',
        action = function()
            clear(vals.buf[chan])
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = 'buffer_'..chan, name = 'buffer',
        min = 1, max = 2, default = chan,
        action = function(v)
            vals.buf[chan] = v; update.buf_rec()
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

    patcher.add_destination_and_param{
        type = 'control', id = 'level_'..chan, name = 'lvl',
        controlspec = cs.def{ min = 0, max = 5, default = 4, units = 'v' },
        action = function(v)
            engine.out_amp(chan, volt_amp(v))
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'pan_'..chan, name = 'pan',
        controlspec = cs.def{ min = -5, max = 5, default = chan==1 and -4 or 4, units = 'v' },
        action = function(v)
            engine.out_pan(chan, v/5)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'old_'..chan, name = 'old',
        controlspec = cs.def{ min = 0, max = 5, default = 5/2, units = 'v' }, 
        action = function(v)
            engine.feedback_amp(chan, v/5)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }

    patcher.add_destination_and_param{
        type = 'control', id = 'rate_'..chan, name = 'rate',
        controlspec = cs.def{ 
            min = -5, max = 5, default = 0,
            quantum = 1/100/10, units = 'v',
        },
        action = function(v)
            vals.rate[chan] = v; update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_write_'..chan, name = 'reverse (write)',
        action = function(v)
            vals.rev_w[chan] = (v == 0) and 1 or -1
            update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = 'octave_write_'..chan, name = 'octave (write)',
        min = -3, max = 2, default = 0,
        action = function(v)
            vals.oct_w[chan] = v; update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_read_'..chan, name = 'reverse (read)',
        action = function(v)
            vals.rev_r[chan] = (v == 0) and 1 or -1
            update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = 'octave_read_'..chan, name = 'octave (read)',
        min = -3, max = 2, default = 0,
        action = function(v)
            vals.oct_r[chan] = v; update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'couple_'..chan, name = 'read/write couple', default = 1,
        action = function(v)
            vals.couple[chan] = v
            
            engine.couple_phases(chan, v)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'rate_lag_'..chan, name = 'slew',
        controlspec = cs.def{ min = 0, max = 3, default = 0, units = 'v', },
        action = function(v)
            engine.rate_slew(chan, v)
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }

    patcher.add_destination_and_param{
        type = 'number', id = 'bit_depth_'..chan, name = 'bits',
        min = 4, max = 9, default = 9,
        action = function(v)
            engine.bit_depth(chan, v)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = 'detritus_'..chan, name = 'dtrts',
        min = 1, max = 6, default = 1,
        action = function(v)
            engine.read_gap(chan, v)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'wet_dry_'..chan, name = 'wet/dry',
        controlspec = cs.def{ min = 0, max = 5, default = 2.5, units = 'v' },
        action = function(v)
            engine.wet_dry(chan, v/5)
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }

    patcher.add_destination_and_param{
        type = 'control', id = 'loop_start_'..chan, name = 'start',
        controlspec = cs.def{ 
            min = 0, max = time_volt_scale, default = 0, units = 'v', 
            quantum = 1/100/2,
        },
        action = function(v)
            vals.last_st_rel[chan] = vals.st_rel[chan]
            vals.st_rel[chan] = v / time_volt_scale; update.start_end(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'loop_end_'..chan, name = 'end',
        controlspec = cs.def{ 
            min = 0, max = time_volt_scale, default = 0, units = 'v',
            quantum = 1/100/2,
        },
        action = function(v)
            vals.last_en_rel[chan] = vals.en_rel[chan]
            vals.en_rel[chan] = v / time_volt_scale; update.start_end(chan)
        end
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

    patcher.add_destination_and_param{
        type = 'control', id = 'lowpass_freq_'..chan, name = 'lp cut',
        controlspec = cs.def{ min = 0, max = 7, default = 7, units = 'v' },
        action = function(v)
            engine.lp_freq(chan, volt_cutoff(v))
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    } 
    patcher.add_destination_and_param{
        type = 'control', id = 'lowpass_q_'..chan, name = 'lp q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function(v)
            engine.lp_q(chan, volt_q(v))
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'highpass_freq_'..chan, name = 'hp cut',
        controlspec = cs.def{ min = 0, max = 7, default = 0, units = 'v' },
        action = function(v)
            engine.hp_freq(chan, volt_cutoff(v))
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    } 
    patcher.add_destination_and_param{
        type = 'control', id = 'highpass_q_'..chan, name = 'hp q',
        controlspec = cs.def{ min = 0, max = 5, default = 0, units = 'v' },
        action = function(v)
            engine.hp_rq(chan, volt_q(v, true))

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }

    patcher.add_destination_and_param{
        type = 'control', id = 'pm_freq_'..chan, name = 'pm frq',
        controlspec = cs.def{ min = 0, max = 17, default = 16, units = 'v' },
        action = function(v)
            local hz = (1/5) * 2^v
            engine.mod_freq(chan, hz)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'pm_freq_lag_'..chan, name = 'pm lag',
        controlspec = cs.def{ min = 0, max = 3, default = 0.25, units = 'v' },
        action = function(v)
            engine.mod_freq_slew(chan, v)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'pm_depth_'..chan, name = 'pm dep',
        controlspec = cs.def{ 
            min = 0, max = 5, default = 0, units = 'v',
            quantum = 1/100/5*2
        },
        action = function(v)
            local depth = v * 40
            engine.mod_depth(chan, depth)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    params:add{
        type = 'option', id = 'pm_source_'..chan, name = 'pm src',
        options = { 'in R', 'sin', 'tri', 'saw', 'sqr', 'noise' }, default = 3, 
        action = function(v)
            engine.mod_source(chan, v)

            crops.dirty.screen = true
        end
    }
end
