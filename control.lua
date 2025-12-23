-- Scarecrow Fuel Management System
-- Adapted from GridFuelManager by mrudat
-- Automatically transfers fuel from scarecrow inventory to equipment grid burners

local PriorityQueue = require("priority-queue")

-- Module-level state references (will point to global tables after init)
local Scarecrows
local Queue

-- Helper: Add item to queue
local function enqueue(data)
  Queue:put(data, data.next_tick)
end

-- Get all items that match a fuel category, sorted by fuel value
local function get_fuel_items_for_category(fuel_category)
  local items = {}
  
  -- Iterate through all item prototypes to find matching fuel
  for name, prototype in pairs(prototypes.item) do
    if prototype.fuel_category == fuel_category and prototype.fuel_value > 0 then
      items[#items + 1] = {
        name = name,
        fuel_value = prototype.fuel_value,
        stack_fuel_value = prototype.fuel_value * prototype.stack_size
      }
    end
  end
  
  -- Sort by stack fuel value (descending)
  table.sort(items, function(a, b)
    return a.stack_fuel_value > b.stack_fuel_value
  end)
  
  return items
end

-- Get fuel items for multiple categories, merged and sorted
local function get_fuel_items_for_categories(fuel_categories)
  local all_items = {}
  local seen = {}
  
  for category, _ in pairs(fuel_categories) do
    local items = get_fuel_items_for_category(category)
    for _, item in ipairs(items) do
      if not seen[item.name] then
        seen[item.name] = true
        all_items[#all_items + 1] = item
      end
    end
  end
  
  -- Sort by stack fuel value (descending)
  table.sort(all_items, function(a, b)
    return a.stack_fuel_value > b.stack_fuel_value
  end)
  
  return all_items
end

-- Find all burner generators in an equipment grid
local function find_burner_generators(grid)
  local generators = {}
  
  if not grid or not grid.valid then
    return generators
  end
  
  for _, equipment in ipairs(grid.equipment) do
    local burner = equipment.burner
    if burner then
      local inventory = burner.inventory
      if inventory and inventory.valid then
        local burnt_result_inventory = burner.burnt_result_inventory
        if burnt_result_inventory and not burnt_result_inventory.valid then
          burnt_result_inventory = nil
        end
        
        local power = equipment.generator_power
        if power > 0 then
          generators[#generators + 1] = {
            equipment = equipment,
            power = power,
            burner = burner,
            inventory = inventory,
            burnt_result_inventory = burnt_result_inventory,
            fuel_categories = burner.fuel_categories
          }
        end
      end
    end
  end
  
  return generators
end

-- Handle fuel management for a single scarecrow
local function handle_scarecrow(data)
  local unit_number = data.unit_number
  local scarecrow_data = Scarecrows[unit_number]
  
  if not scarecrow_data then
    return
  end
  
  local entity = scarecrow_data.entity
  if not entity or not entity.valid then
    Scarecrows[unit_number] = nil
    return
  end
  
  local grid = entity.grid
  if not grid or not grid.valid then
    Scarecrows[unit_number] = nil
    return
  end
  
  local inventory = entity.get_inventory(defines.inventory.car_trunk)
  if not inventory or not inventory.valid then
    Scarecrows[unit_number] = nil
    return
  end
  
  local generators = scarecrow_data.generators
  local min_remaining_time = nil
  
  -- First pass: validate generators and calculate their remaining energy
  local generator_states = {}
  for i = #generators, 1, -1 do
    local generator = generators[i]
    local remove = false
    
    if not generator.equipment.valid then
      remove = true
    elseif not generator.burner.valid then
      remove = true
    elseif not generator.inventory.valid then
      remove = true
    elseif generator.burnt_result_inventory and not generator.burnt_result_inventory.valid then
      remove = true
    end
    
    if remove then
      table.remove(generators, i)
    else
      local gen_inventory = generator.inventory
      gen_inventory.sort_and_merge()
      
      -- Calculate remaining fuel energy
      local fuel_items = get_fuel_items_for_categories(generator.fuel_categories)
      local remaining_energy = 0
      for _, fuel_item in ipairs(fuel_items) do
        local count = gen_inventory.get_item_count(fuel_item.name)
        remaining_energy = remaining_energy + (count * fuel_item.fuel_value)
      end
      
      local remaining_time = remaining_energy / generator.power
      generator_states[#generator_states + 1] = {
        generator = generator,
        remaining_time = remaining_time,
        fuel_items = fuel_items,
        inventory = gen_inventory
      }
      
      if not min_remaining_time or remaining_time < min_remaining_time then
        min_remaining_time = remaining_time
      end
    end
  end
  
  -- Find the generator with lowest remaining fuel and fill it
  if #generator_states > 0 then
    table.sort(generator_states, function(a, b) return a.remaining_time < b.remaining_time end)
    local lowest = generator_states[1]
    local gen_inventory = lowest.inventory
    
    -- Try to fill with existing fuel types first
    local contents = gen_inventory.get_contents()
    for _, item_data in ipairs(contents) do
      local item_name = item_data.name
      local available = inventory.get_item_count(item_name)
      if available > 0 then
        local moved = gen_inventory.insert({name = item_name, count = available})
        if moved > 0 then
          inventory.remove({name = item_name, count = moved})
        end
      end
    end
    
    -- Add best fuel from inventory
    for _, fuel_item in ipairs(lowest.fuel_items) do
      local available = inventory.get_item_count(fuel_item.name)
      if available > 0 then
        local moved = gen_inventory.insert({name = fuel_item.name, count = available})
        if moved > 0 then
          inventory.remove({name = fuel_item.name, count = moved})
        end
      end
    end
  end
  
  -- Return burnt results to main inventory
  for _, generator in pairs(generators) do
    local burnt_result_inventory = generator.burnt_result_inventory
    if burnt_result_inventory then
      local contents = burnt_result_inventory.get_contents()
      for item_name, count in pairs(contents) do
        local moved = inventory.insert({name = item_name, count = count})
        if moved > 0 then
          burnt_result_inventory.remove({name = item_name, count = moved})
        end
      end
    end
  end
  
  -- Schedule next check
  if min_remaining_time and min_remaining_time > 0 then
    -- Check back when half the fuel is consumed
    data.next_tick = game.tick + math.floor(min_remaining_time / 2) + 1
    enqueue(data)
  else
    -- No fuel or unknown time - check every tick until fuel arrives
    data.next_tick = game.tick + 1
    enqueue(data)
  end
end

-- Process queue on tick
local function on_tick(event)
  local item = Queue:peek()
  if not item then return end
  
  if item.next_tick > event.tick then return end
  
  Queue:pop()
  handle_scarecrow(item)
end

-- Register a scarecrow with equipment grid
local function register_scarecrow(entity)
  if entity.name ~= "scarecrow" then return end
  
  local grid = entity.grid
  if not grid then
    return
  end
  
  local generators = find_burner_generators(grid)
  if #generators == 0 then
    return
  end
  
  local unit_number = entity.unit_number
  
  Scarecrows[unit_number] = {
    entity = entity,
    generators = generators
  }
  
  -- Schedule immediate check
  local queue_data = {
    unit_number = unit_number,
    next_tick = game.tick
  }
  enqueue(queue_data)
end

-- Unregister a scarecrow
local function unregister_scarecrow(entity)
  if entity.name ~= "scarecrow" then return end
  
  local unit_number = entity.unit_number
  Scarecrows[unit_number] = nil
end

-- Event handlers
local function on_built_entity(event)
  local entity = event.created_entity or event.entity or event.destination
  if entity and entity.valid then
    register_scarecrow(entity)
  end
end

local function on_destroyed_entity(event)
  local entity = event.entity
  if entity and entity.valid then
    unregister_scarecrow(entity)
  end
end

local function on_player_placed_equipment(event)
  if not event.equipment or not event.equipment.burner then return end
  
  local grid = event.grid
  if not grid or not grid.valid then return end
  
  -- Find which scarecrow owns this grid
  for unit_number, scarecrow_data in pairs(Scarecrows) do
    if scarecrow_data.entity.valid and scarecrow_data.entity.grid == grid then
      -- Re-scan for generators
      local generators = find_burner_generators(grid)
      scarecrow_data.generators = generators
      
      if #generators > 0 then
        -- Schedule immediate check
        local queue_data = {
          unit_number = unit_number,
          next_tick = game.tick
        }
        enqueue(queue_data)
      end
      break
    end
  end
end

-- Find all existing scarecrows on init/load
local function find_all_scarecrows()
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered({name = "scarecrow"})
    for _, entity in pairs(entities) do
      register_scarecrow(entity)
    end
  end
end

-- Initialize storage state
local function on_init()
  storage.Scarecrows = {}
  storage.Queue = {}
  
  Scarecrows = storage.Scarecrows
  Queue = PriorityQueue(storage.Queue)
  
  find_all_scarecrows()
end

-- Handle configuration changes
local function on_configuration_changed(event)
  -- Ensure storage tables exist
  storage.Scarecrows = storage.Scarecrows or {}
  storage.Queue = storage.Queue or {}
  
  Scarecrows = storage.Scarecrows
  Queue = PriorityQueue(storage.Queue)
  
  -- Re-scan for scarecrows (this will find unregistered ones with generators)
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered({name = "scarecrow"})
    for _, entity in pairs(entities) do
      local unit_number = entity.unit_number
      
      -- Check if this scarecrow has generators but isn't registered
      if entity.grid then
        local generators = find_burner_generators(entity.grid)
        if #generators > 0 and not Scarecrows[unit_number] then
          register_scarecrow(entity)
        end
      end
    end
  end
end

-- Load storage state (called when game loads)
local function on_load()
  Scarecrows = storage.Scarecrows
  Queue = PriorityQueue(storage.Queue)
end

-- Register events
script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

script.on_event(defines.events.on_built_entity, on_built_entity, {
  {filter = "name", name = "scarecrow"}
})

script.on_event(defines.events.on_robot_built_entity, on_built_entity, {
  {filter = "name", name = "scarecrow"}
})

script.on_event(defines.events.script_raised_built, on_built_entity)
script.on_event(defines.events.script_raised_revive, on_built_entity)

-- Event: Equipment placed in grid
script.on_event(defines.events.on_equipment_inserted, function(event)
  local grid = event.grid
  if not grid or not grid.valid then 
    return 
  end
  
  -- Check if this is a scarecrow's equipment grid
  local entity = grid.entity_owner
  if not entity or not entity.valid then 
    return 
  end
  
  if entity.name ~= "scarecrow" then 
    return 
  end
  
  local unit_number = entity.unit_number
  
  -- Rescan for burner generators
  local generators = find_burner_generators(grid)
  
  if #generators > 0 then
    -- Register or update the scarecrow with generators
    Scarecrows[unit_number] = {
      entity = entity,
      generators = generators
    }
    
    -- Schedule immediate fuel check
    enqueue({unit_number = unit_number, next_tick = game.tick})
  end
end)

script.on_event(defines.events.on_entity_died, on_destroyed_entity, {
  {filter = "name", name = "scarecrow"}
})

script.on_event(defines.events.on_player_mined_entity, on_destroyed_entity, {
  {filter = "name", name = "scarecrow"}
})

script.on_event(defines.events.on_robot_mined_entity, on_destroyed_entity, {
  {filter = "name", name = "scarecrow"}
})

script.on_event(defines.events.script_raised_destroy, on_destroyed_entity)

script.on_event(defines.events.on_player_placed_equipment, on_player_placed_equipment)

script.on_event(defines.events.on_tick, on_tick)
