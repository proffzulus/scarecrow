-- Equipment grid definition
data:extend({
  {
    type = "equipment-grid",
    name = "scarecrow-equipment-grid",
    width = 4,
    height = 4,
    equipment_categories = {"armor"}
  }
})

-- Scarecrow car (stationary box with equipment grid)
data:extend({
  {
    type = "car",
    name = "scarecrow",
    icon = "__scarecrow__/scarecrow.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "not-on-map"},
    minable = {mining_time = 0.5, result = "scarecrow"},
    max_health = 150,
    corpse = "small-remnants",
    dying_explosion = "explosion",
    energy_per_hit_point = 1,
    collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
    collision_mask = {layers={item=true, meltable=true, object=true, player=true, water_tile=true, is_object=true, is_lower_object=true}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    effectivity = 0.5,
    braking_power = "1000kW",
    energy_source = {
      type = "void"
    },
    consumption = "1W",
    friction = 1,
    render_layer = "object",
    animation = {
      layers = {
        {
          filename = "__scarecrow__/scarecrow_entity.png",
          priority = "extra-high",
          width = 113,
          height = 136,
          frame_count = 1,
          direction_count = 1,
          shift = util.by_pixel(2, -18),
          scale = 0.5
        },
      }
    },
    turret_animation = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1,
      frame_count = 1,
      direction_count = 1
    },
    light_animation = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1,
      frame_count = 1,
      direction_count = 1
    },
    stop_trigger_speed = 0.1,
    open_sound = {filename = "__base__/sound/wooden-chest-open.ogg", volume=0.5},
    close_sound = {filename = "__base__/sound/wooden-chest-close.ogg", volume = 0.5},
    rotation_speed = 0,
    weight = 100000,
    inventory_size = 16,
    equipment_grid = "scarecrow-equipment-grid",
    allow_passengers = false,
    has_belt_immunity = true,
	is_military_target = true
  }
})

-- Scarecrow item
data:extend({
  {
    type = "item-with-entity-data",
    name = "scarecrow",
    icon = "__scarecrow__/scarecrow.png",
    icon_size = 64,
    subgroup = "defensive-structure",
    order = "b[turret]-a[scarecrow]",
    place_result = "scarecrow",
    stack_size = 10
  }
})

-- Recipe
data:extend({
  {
    type = "recipe",
    name = "scarecrow",
    enabled = true,
    ingredients = {
      {type = "item", name = "wooden-chest", amount = 1},
      {type = "item", name = "wood", amount = 5}
    },
    results = {{type = "item", name = "scarecrow", amount = 1}}
  }
})
