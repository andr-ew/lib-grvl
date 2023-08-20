local Components = {
    grid = {},
    arc = {},
    screen = {},
}

--TODO: refactor to use states more correctly
function Components.grid.arc_focus()
    local held = {}

    return function(props)
        local tall = props.tall

        local vertical = props.vertical[1]
        local set_vertical = props.vertical[2]

        if crops.device == 'grid' then
            if crops.mode == 'input' then
                local x, y, z = table.unpack(crops.args)
                
                if
                    x >= props.x and x <= props.x + (3) 
                        and y >= props.y and y <= props.y + (tall and 5 or 3)
                then
                    local dx, dy = x - props.x + 1, y - props.y + 1

                    if z == 1 then
                        table.insert(held, { x = dx, y = dy })

                        if not tall then
                            if #held > 1 then
                                if held[1].x == held[2].x then 
                                    vertical = true
                                    set_vertical(true)
                                elseif held[1].y == held[2].y then 
                                    vertical = false
                                    set_vertical(false) 
                                end
                            end
                        end

                        for i = 1,tall and 6 or 4 do --y
                            for j = 1,4 do --x 
                                props.view[i][j] = (
                                    vertical and dx == j
                                )
                                    and 1 
                                    or ((not vertical and dy == i) and 1 or 0)
                            end 
                        end

                        props.action(vertical, dx, dy)
                    else
                        for i,v in ipairs(held) do
                            if v.x == dx and v.y == dy then table.remove(held, i) end
                        end
                    end
                end
            elseif crops.mode == 'redraw' then
                local g = crops.handler

                for i = 0,tall and 5 or 3 do for j = 0,3 do 
                    g:led(props.x + j, props.y + i, props.levels[props.view[i + 1][j + 1] + 1])
                end end
            end
        end
    end
end

return Components
