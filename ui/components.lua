local Components = {
    grid = {},
    arc = {},
    norns = {},
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

function Components.grid.norns_focus()
    return function(props)
        if crops.device == 'grid' then
            if crops.mode == 'input' then
                local x, y, z = table.unpack(crops.args)

                if z == 1 then
                    if
                        x >= props.x and x <= props.x + 3
                        and y >= props.y and y <= props.y + 3
                    then
                        local dx, dy = x - props.x + 1, y - props.y + 1
                        
                        crops.set_state(
                            props.state, 
                            dy + (dx <3 and 0 or 4)
                        )                        
                    end
                end
            elseif crops.mode == 'redraw' then
                local g = crops.handler
                local v = crops.get_state(props.state) or 1

                for i = 1,8 do
                    local y = (i - 1)%4
                    local x = (i - 1)//4

                    for ii = 0,1 do
                        g:led(
                            props.x + ii + x*2, 
                            props.y + y, 
                            props.levels[v == i and 2 or 1]
                        )
                    end
                end
            end
        end
    end
end

function Components.arc.window()
    return function(props)
        if crops.device == 'arc' and crops.mode == 'redraw' then
            local off = props.rotated and 16 or 0
            local a = crops.handler

            local st = props.x[1] + math.ceil(
                props.st*(props.x[2] - props.x[1] + 2)
            )
            local en = props.x[1] - 1 + math.ceil(
                props.en*(props.x[2] - props.x[1] + 2)
            )
            local ph = props.x[1] + util.round(
                props.phase * (props.x[2] - props.x[1])
            )

            a:led(props.n, (st - 1) % 64 + 1 - off, props.level_st)
            a:led(props.n, (en - 1) % 64 + 1 - off, props.level_en)
            if props.show_phase then 
                a:led(props.n, (ph - 1) % 64 + 1 - off, props.level_ph)
            end
        end
    end
end

function Components.norns.toggle_hold()
    local downtime = nil
    local blink = false
    local blink_level = 2

    return function(props)
        if crops.device == 'key' and crops.mode == 'input' then
            local n, z = table.unpack(crops.args) 

            if n == props.n then
                if z==1 then
                    downtime = util.time()
                elseif z==0 then
                    if downtime and ((util.time() - downtime) > 0.5) then 
                        blink = true
                        blink_level = 1
                        crops.dirty.screen = true

                        clock.run(function() 
                            clock.sleep(0.1)
                            blink_level = 2
                            crops.dirty.screen = true

                            params:delta(props.id_hold)

                            clock.sleep(0.2)
                            blink_level = 1
                            crops.dirty.screen = true

                            clock.sleep(0.4)
                            blink = false
                            crops.dirty.screen = true
                        end)
                    else
                        _key.toggle{
                            n = props.n, edge = 'falling',
                            state = {
                                params:get(props.id_toggle), 
                                params.set, params, props.id_toggle,
                            },
                        }
                    end
                    
                    downtime = nil
                end
            end
        end

        _screen.text{
            x = k[props.n].x, y = k[props.n].y,
            text = blink and (
                props.label_hold or props.id_hold
            ) or (
                props.label_toggle or props.id_toggle
            ),
            level = props.levels[
                blink and blink_level or (params:get(props.id_toggle) + 1)
            ],
        }
    end
end

return Components
