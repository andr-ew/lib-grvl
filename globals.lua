grvl = {}
    
local function process_param(arg) params:set(table.unpack(arg)) end

patterns = {}
for i = 1,8 do
    patterns[i] = pattern_time.new() 
    patterns[i].process = process_param 
end

grvl.active_src = 'none'

set_param = function(id, v)
    local t = { id, v }
    process_param(t)
    for i,pat in ipairs(patterns) do pat:watch(t) end
end

function grvl.of_param(id, is_dest)
    return {
        (is_dest==false) and params:get(id) or patcher.get_destination_plus_param(id),
        set_param, id,
    }            
end
