_keyboard = Grid.integer()

function render_grid()
    _keyboard{
        x = 1,
        y = 1,
        size = 5,
        min = -2,
        levels = { 4, 15 },
        state = crops.of_param('note'),
    }
end

crops.connect_grid(render_grid, g)

