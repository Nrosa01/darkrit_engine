---@diagnostic disable: invisible

local ru = Darkrit._internal.require_utils ---@module "require_utils"
local world = ru.require_module('entities.world') ---@module "entities.world"

---@diagnostic disable:invisible
---@param test_system Darkrit.TestSystem
return function(test_system)
    test_system.register("Entity System Tests", function(helper)
        helper:run("World Initialization", function(subtest)
            local new_world = world.new() ---@type Darkrit.World

            subtest("Entity count", function()
                assert(new_world:get_entity_count() == 0, "Entity count should be 0")
            end)

            subtest("Entities to add", function()
                assert(helper:is_empty_table(new_world._entities_to_add), "Entities to add should be empty")
            end)

            subtest("Entities list", function()
                assert(helper:is_empty_table(new_world.entities), "Entities list should be empty")
            end)
        end)

        helper:run("Entity Manipulation", function(subtest)
            local new_world = world.new()
            new_world:create_entity("Entity 1")
            new_world:create_entity("Entity 2")
            new_world:create_entity("Entity 3")

            subtest("Entity count after creation", function()
                new_world:update(0.016)
                assert(new_world:get_entity_count() == 3, "Entity count should be 3")
            end)

            subtest("Destroy entities by condition", function()
                new_world:destroy_entities_matches_condition(function(entity)
                    return entity.name == "Entity 2"
                end)
                new_world:update(0.016)
                assert(new_world:get_entity_count() == 2,
                    "Entity count should be 2 after destruction and it's " .. new_world:get_entity_count())
            end)

            subtest("Destroy two entities in a row", function()
                local entity_4 = new_world:create_entity("Entity 4")
                local entity_5 = new_world:create_entity("Entity 5")
                new_world:create_entity("Entity 6")
                new_world:update(0.016)
                new_world:destroy(entity_4)
                new_world:destroy(entity_5)
                new_world:update(0.016)
                assert(new_world:get_entity_count() == 3,
                    "Entity count should be 3 after destruction and it's " .. new_world:get_entity_count())
                -- Entities are not ordered, so we have to check that the only ones in the array are 1,3 and 6
                -- For that we are going to move table and reorder
                local ordered_entities = {}
                table.move(new_world.entities, 1, #new_world.entities, 1, ordered_entities)
                table.sort(ordered_entities, function(a, b)
                    return a.name < b.name
                end)
                assert(ordered_entities[1].name == "Entity 1", "Entity 1 should be the first entity")
                assert(ordered_entities[2].name == "Entity 3", "Entity 3 should be the second entity")
                assert(ordered_entities[3].name == "Entity 6", "Entity 6 should be the third entity")
            end)

            subtest("Destroy two entity the same frame it was created", function()
                local entity_7 = new_world:create_entity("Entity 7")
                local entity_8 = new_world:create_entity("Entity 8")
                new_world:create_entity("Entity 9")
                new_world:destroy(entity_7)
                new_world:destroy(entity_8)
                new_world:update(0.016)
                assert(new_world:get_entity_count() == 4,
                    "Entity count should be 3 after destruction and it's " .. new_world:get_entity_count())
                -- Entities are not ordered, so we have to check that the only ones in the array are 1,3 and 6
                -- For that we are going to move table and reorder
                local ordered_entities = {}
                table.move(new_world.entities, 1, #new_world.entities, 1, ordered_entities)
                table.sort(ordered_entities, function(a, b)
                    return a.name < b.name
                end)
                assert(ordered_entities[1].name == "Entity 1", "Entity 1 should be the first entity")
                assert(ordered_entities[2].name == "Entity 3", "Entity 3 should be the second entity")
                assert(ordered_entities[3].name == "Entity 6", "Entity 6 should be the third entity")
                assert(ordered_entities[4].name == "Entity 9", "Entity 6 should be the third entity")
            end)
        end)

        helper:run("World hook", function(subtest)
            local new_world = world.new()
            local event_1_triggered = false
            local event_2_triggered = false
            new_world:on("test_event", function()
                event_1_triggered = true
            end)

            new_world:on("test_event_2", function()
                event_2_triggered = true
            end)

            new_world:dispatch_outside("test_event")
            new_world:dispatch_outside("test_event_2")

            assert(event_1_triggered, "Event 1 should have been triggered")
            assert(event_2_triggered, "Event 2 should have been triggered")
        end)

        helper:run("Component manipulatiion", function(subtest)
            local ta = Darkrit.test_assets
            local comp1 = ta.DummyComp
            local comp2 = ta.DummyComp2
            local comp3 = ta.DummyComp3

            local new_world = world.new()
            local e1 = new_world:create_entity("Entity 1")
            e1:add_component(comp2)
            e1:add_component(comp1)
            local e2 = new_world:create_entity("Entity 2")
            local e3 = new_world:create_entity("Entity 3")

            new_world:update(0.016)

            subtest("Component queue sizes", function ()
                assert(#new_world._updateable_queue == 2, "Updaeable queue should be 2 and it's " .. #new_world._updateable_queue)
                assert(#new_world._render_queue == 2, "Render queue should be 2 and it's " .. #new_world._updateable_queue)
            end)

            subtest("Component order after addition", function (s)
                assert(new_world._updateable_queue[1] == e1.components[2], "Updateable component wasn't ordered correctly")
                assert(new_world._render_queue[1] == e1.components[1], "Drawable component wasn't ordered correctly")
            end)


            e2:add_component(comp3)
            local e4 = new_world:create_entity("Entity 4")
            local e5 = new_world:create_entity("Entity 5")
            e4:add_component(comp2)
            new_world:destroy(e4)
            new_world:update(0.016)

            subtest("Entity amount after deletion", function ()
                assert(#new_world.entities == 4, "Entity count should be 4 and it's " .. #new_world.entities)
            end)

            subtest("Components after deletion", function ()
                assert(#new_world._updateable_queue == 3, "Updaeable queue should be 2 and it's " .. #new_world._updateable_queue)
                assert(#new_world._render_queue == 3, "Render queue should be 2 and it's " .. #new_world._updateable_queue)
            end)

        end)
    end)
end
