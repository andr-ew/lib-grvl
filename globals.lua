grvl = {}
    
local function process_param(arg) params:set(table.unpack(arg)) end

patterns = {}
for i = 1,8 do
    patterns[i] = pattern_time.new() 
    patterns[i].process = process_param 
end

set_param = function(id, v)
    local t = { id, v }
    process_param(t)
    for i,pat in ipairs(patterns) do pat:watch(t) end
end

function grvl.of_param(id)
    return {
        params:get(id),
        set_param, id,
    }            
end
