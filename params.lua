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

local nicknames = {}
grvl.param_nicknames = nicknames

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

            if params:get('octave_write_'..chan) > 0 then
                params:set('octave_write_'..chan, 0, silent)
                vals.oct_w[chan] = 0
            end
            if params:get('reverse_write_'..chan) > 0 then
                params:set('reverse_write_'..chan, 0, silent)
                vals.oct_w[chan] = 0
            end
            params:set('rate_'..chan, 0, silent)
            vals.rate[chan] = 0

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

    vals.rate_linear = false
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
        local rate = vals.rate[chan]
        rate = (vals.rate_linear and (rate + 1) or 2^rate)

        local play = vals.play[chan]
        local rev_w = vals.rev_w[chan]
        local oct_w = vals.oct_w[chan] 
        vals.rate_w[chan] = 2^oct_w * rate * rev_w * play
        
        local play = vals.play[chan]
        local rev_r = vals.rev_r[chan]
        local oct_r = vals.oct_r[chan]
        vals.rate_r[chan] = 2^oct_r * rate * rev_r * play
        
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
                params:lookup_param('octave_write_'..chan):bang()
                params:lookup_param('reverse_write_'..chan):bang()
                params:lookup_param('rate_'..chan):bang()

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
                    params:lookup_param('octave_write_'..chan):bang()
                    params:lookup_param('reverse_write_'..chan):bang()
                    params:lookup_param('rate_'..chan):bang()

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
                    params:lookup_param('octave_write_'..chan):bang()
                    params:lookup_param('reverse_write_'..chan):bang()
                    params:lookup_param('rate_'..chan):bang()

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

local function clear(buf, reset)
    engine.clear_buf(buf)

    for chan = 1,2 do
        if buf == vals.buf[chan] then
            local len = vals.len_rel[chan]
            if (not buffers[buf].manual) or (len==0) or reset then
                params:set('record_'..chan, 0, silent)
                params:set('loop_start_'..chan, 0, silent)
                params:set('loop_end_'..chan, 0, silent)
                params:set('rate_'..chan, 0, silent)
                vals.rec[chan] = 0
                vals.st_rel[chan] = 0
                vals.en_rel[chan] = 0
                vals.rate[chan] = 0
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
            params:lookup_param('rate_'..chan):bang()
        end
    end
end

--add track params
for chan = 1,2 do
    params:add_separator('sep_chan_'..chan,'channel '..chan)

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
        type = 'control', id = 'level_'..chan, name = 'level',
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
        type = 'control', id = 'old_'..chan, name = 'ablation',
        controlspec = cs.def{ min = 0, max = 5, default = 5/2, units = 'v' }, 
        action = function(v)
            engine.feedback_amp(chan, v/5)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    nicknames['ablation'] = 'ABLTN'

    patcher.add_destination_and_param{
        type = 'control', id = 'rate_'..chan, name = 'abrasion (fine)',
        controlspec = cs.def{
            min = -5, max = 5, default = 0,
            quantum = 1/100/10, units = 'v',
        },
        action = function(v)
            vals.rate[chan] = v; update.rate(chan)
        end
    }
    nicknames['abrasion (fine)'] = 'FINE'
    patcher.add_destination_and_param{
        type = 'number', id = 'octave_write_'..chan, name = 'abrasion (coarse)',
        min = -3, max = 3, default = 0,
        action = function(v)
            vals.oct_w[chan] = v; update.rate(chan)
        end,
        formatter = function(p)
            return 2^p:get()
        end
    }
    nicknames['abrasion (coarse)'] = 'ABRSN'
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_write_'..chan, name = 'flow',
        action = function(v)
            vals.rev_w[chan] = (v == 0) and 1 or -1
            update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = 'octave_read_'..chan, name = 'abrasion (readonly)',
        min = -3, max = 3, default = 0,
        action = function(v)
            vals.oct_r[chan] = v; update.rate(chan)
        end
    }
    patcher.add_destination_and_param{
        type = 'binary', behavior = 'toggle',
        id = 'reverse_read_'..chan, name = 'flow (readonly)',
        action = function(v)
            vals.rev_r[chan] = (v == 0) and 1 or -1
            update.rate(chan)
        end
    }
    nicknames['abrasion (readonly)'] = 'READ'
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
        type = 'control', id = 'bits_fine_'..chan, name = 'sediment (fine)',
        controlspec = cs.def{ min = 1, max = 10, default = 9, units = 'v' },
        action = function(v)
            engine.bit_depth(chan, v)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    nicknames['sediment (fine)'] = 'SEDMT'
    patcher.add_destination_and_param{
        type = 'number', id = 'bit_depth_'..chan, name = 'sediment (coarse)',
        min = 4, max = 9, default = 9,
        action = function(v)
            params:set('bits_fine_'..chan, v)
        end
    }
    nicknames['sediment (coarse)'] = 'CRSED'
    patcher.add_destination_and_param{
        type = 'number', id = 'detritus_'..chan, name = 'detritus',
        min = 1, max = 6, default = 1,
        action = function(v)
            engine.read_gap(chan, v)

            crops.dirty.grid = true
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    nicknames['detritus'] = 'dtrts'
    patcher.add_destination_and_param{
        type = 'control', id = 'wet_dry_'..chan, name = 'wet/dry',
        controlspec = cs.def{ min = 0, max = 5, default = 2.5, units = 'v' },
        action = function(v)
            engine.wet_dry(chan, v/5)
            
            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    nicknames['wet/dry'] = 'WET/D'

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
        type = 'control', id = 'pm_freq_'..chan, name = 'PM frequency',
        controlspec = cs.def{ min = 0, max = 17, default = 16, units = 'v' },
        action = function(v)
            local hz = (1/5) * 2^v
            engine.mod_freq(chan, hz)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    nicknames['PM frequency'] = 'pm frq'
    patcher.add_destination_and_param{
        type = 'control', id = 'pm_freq_lag_'..chan, name = 'PM lag',
        controlspec = cs.def{ min = 0, max = 3, default = 0.25, units = 'v' },
        action = function(v)
            engine.mod_freq_slew(chan, v)

            crops.dirty.screen = true
            crops.dirty.arc = true
        end
    }
    patcher.add_destination_and_param{
        type = 'control', id = 'pm_depth_'..chan, name = 'PM depth',
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
    nicknames['PM depth'] = 'pm dep'

end
--add LFO params
for i = 1,2 do
    params:add_separator('lfo '..i)
    mod_src.lfos[i]:add_params('lfo_'..i)
end

--add screen/arc mapping params
do
    params:add_separator('sep_mappings', 'enc/arc mappings')

    -- grvl.map_ids = {}
    grvl.map_names = {}
    grvl.map_prefixes = {}

    local adding = false
    local id_start = 'sep_chan_1'
    local id_end = 'sep_mappings'

    for ii,p in ipairs(params.params) do
        if adding then
            if p.id == id_end then
                adding = false
            elseif p.t == params.tCONTROL or p.t == params.tNUMBER then
                local id = p.id
                local prefix = string.sub(id, 1, -2)

                -- table.insert(grvl.map_ids, id)
                
                if not tab.contains(grvl.map_prefixes, prefix) then
                    table.insert(grvl.map_names, p.name or p.id)
                    table.insert(grvl.map_prefixes, prefix)
                end
            end
        elseif p.id == id_start then
            adding = true
        end
    end

    local spaces = '      '
    local src_names = {
        'R1 C1'..spaces,
        spaces..'R1 C2',
        'R2 C1'..spaces,
        spaces..'R2 C2',
        'R3 C1'..spaces,
        spaces..'R3 C2',
        'R4 C1'..spaces,
        spaces..'R4 C2',
    }

    for i = 1,8 do
        local x1 = (i - 1)%2 + 1
        local x2 = x1 + 2
        local y = (i - 1)//2 + 1

        params:add{
            type = 'option', id = 'map_src_'..i, name = src_names[i],
            options = grvl.map_names, default = tab.key(grvl.map_prefixes, grvl.map[y][x1]),
            action = function(v)
                local prefix = grvl.map_prefixes[v]

                grvl.map[y][x1] = prefix
                grvl.map[y][x2] = prefix
            
                crops.dirty.screen = true
                crops.dirty.arc = true
            end
        }
    end
end

-- add engine options
do
    params:add_separator('engine options')

    for chan = 1,2 do
        params:add{
            id ='input_channel_'..chan, name = 'channel '..chan..' input',
            type = 'option', options = { 'L', 'R' },
            action = function(v)
                engine.adc_channel(chan, v - 1)
            end
        }
    end

    params:add{
        id = 'drive', name = 'drive', type = 'control',
        controlspec = cs.def { min = 0, max = 1, default = 0.01, step = 1/1000, quant = 1/1000 },
        action = function(v)
            for chan = 1,2 do
                engine.drive(chan, v)
            end
        end
    }
    params:add{
        id = 'bitnoise', name = 'bitnoise', type = 'control',
        controlspec = cs.def { min = 0, max = 1, default = 0.5, step = 1/1000, quant = 1/1000 },
        action = function(v)
            for chan = 1,2 do
                engine.bitnoise(chan, v)
            end
        end
    }
    params:add{
        type = 'option', id = 'pm_source', name = 'pm source',
        options = { 'in R', 'sin', 'tri', 'saw', 'sqr', 'noise' }, default = 3, 
        action = function(v)
            for chan = 1,2 do
                engine.mod_source(chan, v)
            end
        end
    }

    params:add{
        type = 'option', id = 'abrasion_fine_mode', name = 'abrasion (fine) mode',
        options = { 'exp', 'linear' }, default = 1, 
        action = function(v)
            vals.rate_linear = v==2
            
            for chan = 1,2 do update.rate(chan) end
        end
    }
    params:add{
        type = 'option', id = 'filter_bypass', name = 'filter bypass',
        options = { 'off', 'bypassed' }, default = 1, 
        action = function(v)
            for chan = 1,2 do
                engine.filter_enable(chan, (v==1) and 1 or 0)
            end
        end
    }
end

function grvl.reset_params()
    -- local silent = true

    for buf = 1,2 do
        -- params:set('record_'..chan, 0, silent)
        -- params:delta('clear_'..chan)

        clear(buf, true)
    end
end

local function action_read(file, silent, slot)
    print('pset action read', file, silent, slot)

    params:bang()
    
    grvl.reset_params()
end

params.action_read = action_read

--add pset params
do
    params:add_separator('pset')

    params:add{
        id = 'reset all params', type = 'binary', behavior = 'trigger',
        action = function()
            for _,p in ipairs(params.params) do if p.save then
                params:set(p.id, p.default or (p.controlspec and p.controlspec.default) or 0, true)
            end end

            params:bang()
        end
    }
    params:add{
        id = 'overwrite default pset', type = 'binary', behavior = 'trigger',
        action = function()
            params:write()
        end
    }
    params:add{
        id = 'autosave pset', type = 'option', options = { 'yes', 'no' },
        action = function()
            params:write()
        end
    }
end
