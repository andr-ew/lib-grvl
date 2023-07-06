grvl = {}
    
local function set_param(arg) params:set(table.unpack(arg)) end

patterns = {}
for i = 1, 10 do
    patterns[i] = pattern_time.new()
    patterns[i].process = set_param
end

function grvl.of_param(id)
    return {
        params:get(id),
        function(v)
            local t = { id, v }
            set_param(t)
            for i,pat in ipairs(patterns) do pat:watch(t) end
        end
    }            
end
