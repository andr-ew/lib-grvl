local buffers = {}
        
function grvl.reset_buffer(buf)
    -- clock.cancel(timer)
    buffers[buf].phase_seconds = 0
    buffers[buf].duration_seconds = 0

    buffers[buf].timer_seconds = 0
    buffers[buf].recording = { false, false }
    buffers[buf].recorded = false
    buffers[buf].manual = false
    buffers[buf].loaded = false
    -- buffers[buf].loaded_seconds = 0
end

for buf = 1,2 do
    buffers[buf] = {}
    grvl.reset_buffer(buf)
end

grvl.buffers = buffers

local function process_param(arg) params:set(table.unpack(arg)) end

patterns = {}
for i = 1,8 do
    patterns[i] = pattern_time.new() 
    patterns[i].process = process_param 
end

grvl.active_src = 'none'

grvl.set_param = function(id, v)
    local t = { id, v }
    process_param(t)
    for i,pat in ipairs(patterns) do pat:watch(t) end
end

function grvl.of_param(id, is_dest)
    return {
        (is_dest==false) and params:get(id) or patcher.get_destination_plus_param(id),
        grvl.set_param, id,
    }            
end

grvl.grid_focus = { left = 1, right = 2 }
grvl.arc_vertical = false
grvl.arc_focus = {
    { 1, 1, 1, 1 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
    { 0, 0, 0, 0 },
}
