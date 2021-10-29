initialized = false

local function save_position(position)

    state_file = fs.open('position', 'w')
    state_file.write(textutils.serialize(position))
    state_file.close()

    initialized = true
end


local function get_position()

    state_file = fs.open('position', 'r')
    position = textutils.unserialize(state_file.readAll())
    state_file.close()

    initialized = true
    return position
end


 -- Initalizes positon state
position = {0,0,0,'N'}

if fs.exists('position') then
    position = get_position()
end


function init()

    while true do
        print('')
        print('State not yet defined.')
        print('')
        print('Please enter my position:')
        write('x: ')
        x = read()
        write('y: ')
        y = read()
        write('z: ')
        z = read()
        write("heading (N, S, E, W): ")
        heading = read()

        if tonumber(x) and tonumber(y) and tonumber(z) and (heading=='N' or heading=='S' or heading=='E' or heading=='W') then
            position[1] = tonumber(x)
            position[2] = tonumber(y)
            position[3] = tonumber(z)
            position[4] = heading
            print('Done.')
            print('')
            break
        else
            print('Invalid entries, please try again!')
        end
    end

    save_position(position)
end


function set_world_position(x, y, z, h)
    -- This should only be used to intialize or reset the turtle. Pass (x, y, z, heading (string))
    position = {x, y, z, h}
    save_position(position)
end


function get_world_position()
    return position[1], position[2], position[3], position[4]
end


local_origin = {0,0,0}
function set_local_origin()
    local_origin[1] = position[1]
    local_origin[2] = position[2]
    local_origin[3] = position[3]
    position[5] = local_origin
    save_position(position)
end


function get_relative_position()
    return position[1] - local_origin[1], position[2] - local_origin[2], position[3] - local_origin[3]
end


local function copy_table(tbl)

    local new_table = {}
    for i, v in pairs(tbl) do
        new_table[i] = v
    end
    return new_table
end

-- Define commands to replace basic movement commands and automatically track the state

  -- Beware!!! The biggest threats to turtle safety (movement tracking) are:
    -- Mobs                (handled)
    -- Gravel / Sand       (handled)
    -- Running out of Fuel (handled!!)
    -- Blocks in the way   (handled!!!!)
  -- We will deal with all these

function check_fuel(min_fuel)
    return turtle.getFuelLevel() > (min_fuel or 1)
end

-- Turning

function get_new_direction(current_heading, n_right)

    headings = {'N', 'E', 'S', 'W'}
    heading_indicies = {['N']=0, ['E']=1, ['S']=2, ['W']=3}

    current_index = heading_indicies[current_heading]
    new_index = (current_index + n_right) % 4

    return headings[new_index + 1]
end

function left(n)

    if n == nil then n = 1 end

    for _ = 1, n do
        position[4] = get_new_direction(position[4], -1)
        save_position(position)
        turtle.turnLeft()
    end
end

function right(n)

    if n == nil then n = 1 end

    for _ = 1, n do
        position[4] = get_new_direction(position[4], 1)
        save_position(position)
        turtle.turnRight()
    end
end

-- Moving

-- Before we ever break a block, we must make sure it's not a blacklisted block.
blacklist = {'computercraft:turtle', 'minecraft:redstone_dust', 'minecraft:stone_bricks'}

function inspect()
    is_block, val = turtle.inspect()
    if is_block then
        return val.name
    else
        return ''
    end
end


function inspectUp()
    is_block, val = turtle.inspectUp()
    if is_block then
        return val.name
    else
        return ''
    end
end


function inspectDown()
    is_block, val = turtle.inspectDown()
    if is_block then
        return val.name
    else
        return ''
    end
end


function is_blacklisted(block_name)
    for _ , name in pairs(blacklist) do
        return true
    end
    return false
end


function forward(n)

    if n == nil then n = 1 end        -- n defaults to 1

    if turtle.getFuelLevel() < n then
        print('MOVER-API: Cannot go forward, out of fuel!')
        return false
    end

    for _ = 1, n do
        repeat 
            turtle.dig()
        until not turtle.detect() and not turtle.attack()  
                                       -- Keep digging and attacking until there are no blocks or mobs... Sorry cows :(

        local old_position = copy_table(position)

        if     position[4] == 'N' then -- Implements the logic of moving given the turtle heading.
            position[3] = position[3] - 1
        elseif position[4] == 'S' then
            position[3] = position[3] + 1
        elseif position[4] == 'E' then
            position[1] = position[1] + 1
        elseif position[4] == 'W' then
            position[1] = position[1] - 1
        end
        save_position(position)

        --[[if is_blacklisted(inspect()) then
            right()
            forward()
        end]] -- come back to this later, requires rewriting go_to function.
        
        if not turtle.forward() then   -- Finally we try to actually move forward!
            position = old_position    -- If it still doesn't work we revert. We must protect the position at all costs!
            save_position(position)
            return false
        end
    end
end

function backward(n)

    if n == nil then n = 1 end
    
    if turtle.getFuelLevel() < n then
        print('MOVER-API: Cannot go backward, out of fuel!')
        return false
    end

    right(2)
    forward(n)
    left(2)
end

function up(n)

    if n == nil then n = 1 end
    
    if turtle.getFuelLevel() < n then
        print('MOVER-API: Cannot go up, out of fuel!')
        return false
    end
    
    for _ = 1, n do
        repeat
            turtle.digUp()
        until not turtle.detectUp() and not turtle.attackUp()

        position[2] = position[2] + 1
        save_position(position)

        if not turtle.up() then
            position[2] = position[2] - 1
            save_position(position)
            return false
        end
    end
end

function down(n)

    if n == nil then n = 1 end
    
    if turtle.getFuelLevel() < n then
        print('MOVER-API: Cannot go down, out of fuel!')
        return false
    end
    
    for _ = 1, n do
        repeat
            turtle.digDown()
        until not turtle.detectDown() and not turtle.attackDown()

        position[2] = position[2] - 1
        save_position(position)

        if not turtle.down() then
            position[2] = position[2] + 1
            save_position(position)
            return false
        end
    end
end


function face(target_heading)

    headings = {'N', 'E', 'S', 'W'}
    heading_indicies = {['N']=0, ['E']=1, ['S']=2, ['W']=3}

    intial_index = heading_indicies[position[4]]
    target_index = heading_indicies[target_heading]

    n_right = (target_index - intial_index) % 4

    if n_right == 3 then
        left()
    else
        right(n_right)
    end
end

function go_to(x, y, z)

    dx = x - position[1]
    dy = y - position[2]
    dz = z - position[3]
    -- print(dx, dy, dz)
    -- go to correct y
    if dy > 0 then
        up(dy)
    else
        down(math.abs(dy))
    end

    -- go to correct x
    if dx > 0 then
        face('E')
        -- print('facing E: ', dx)
        forward(dx)
    elseif dx < 0 then
        face('W')
        -- print('facing W: ', math.abs(dx))
        forward(math.abs(dx))
    end

    -- go to correct x
    if dz > 0 then
        face('S')
        -- print('facing S: ', dz)
        forward(dz)
    elseif dz < 0 then
        face('N')
        -- print('facing N: ', math.abs(dz))
        forward(math.abs(dz))
    end
end


function go_to_relative_position(x,y,z)
    go_to(local_origin[1] + x, local_origin[2] + y, local_origin[3] + z)
end
