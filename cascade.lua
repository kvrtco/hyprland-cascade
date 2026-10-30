local mainMod = "SUPER"

-- Settings --
local cascade = {
    -- Direction of the cascade
    direction = "bottom-right",
    -- How much of a window sticks out ( 0.02 is 2% )
    -- After maxSpread is reached, carStep starts to decrease.
    cardStep = 0.02,
    -- A cap on the size of windows ( 0.1 is 90% )
    maxSpread = 0.1,

    -- So with 2% cardStep and 6 open windows,
    -- your focused window is going to be at max size of 90% of the screen ( 5 cards stacked behind * 2% cardStep ).
}
local directions = {
    ["top-left"] = { horizontal = "left", vertical = "top" },
    ["top-right"] = { horizontal = "right", vertical = "top" },
    ["bottom-left"] = { horizontal = "left", vertical = "bottom" },
    ["bottom-right"] = { horizontal = "right", vertical = "bottom" },
}
local cascadeDirection = directions[cascade.direction]

if not cascadeDirection then
    error('cascade.direction must be "top-left", "top-right", "bottom-left", or "bottom-right"')
end

if type(cascade.cardStep) ~= "number" or cascade.cardStep ~= cascade.cardStep or cascade.cardStep < 0 or cascade.cardStep == math.huge then
    error("cascade.cardStep must be a finite non-negative number")
end

if type(cascade.maxSpread) ~= "number" or cascade.maxSpread ~= cascade.maxSpread or cascade.maxSpread < 0 or cascade.maxSpread >= 1 or
    cascade.maxSpread == math.huge then
    error("cascade.maxSpread must be a finite number from 0 up to, but not including, 1")
end

local state = {
    order = {},
    focused_id = nil,
    windows = {},
}

local function target_id(target)
    return target.window and tostring(target.window.stable_id) or tostring(target.index)
end

local function index_of(list, value)
    for i, item in ipairs(list) do
        if item == value then
            return i
        end
    end
end

local function sync_order(ctx)
    local present = {}
    local targets = {}
    local focused_id
    local windows = {}

    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        present[id] = true
        targets[id] = target

        if target.window then
            windows[id] = target.window.address
        end

        if target.window and target.window.active then
            focused_id = id
        end
    end

    local order = {}
    local included = {}

    for _, id in ipairs(state.order) do
        if present[id] and not included[id] then
            table.insert(order, id)
            included[id] = true
        end
    end

    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        if not included[id] then
            table.insert(order, id)
            included[id] = true
        end
    end

    state.order = order
    state.windows = windows

    if focused_id ~= state.focused_id then
        local focused_index = index_of(state.order, focused_id)

        if focused_index and focused_index > 1 then
            local rotated = {}
            for i = focused_index, #state.order do
                table.insert(rotated, state.order[i])
            end
            for i = 1, focused_index - 1 do
                table.insert(rotated, state.order[i])
            end
            state.order = rotated
        end

        state.focused_id = focused_id
    end

    return targets
end

local function restack_windows()
    for i = #state.order, 1, -1 do
        local address = state.windows[state.order[i]]
        if address then
            hl.dispatch(hl.dsp.window.alter_zorder({
                mode = "top",
                window = "address:" .. address,
            }))
        end
    end
end

hl.layout.register("cascade", {
    recalculate = function(ctx)
        local targets = sync_order(ctx)
        local area = ctx.area

        if #state.order == 1 then
            targets[state.order[1]]:place(area)
            return
        end

        local count = #state.order
        if count == 0 then
            return
        end

        local spread = math.min(cascade.maxSpread, cascade.cardStep * (count - 1))
        local step = spread / (count - 1)
        local scale = 1 - spread

        for i, id in ipairs(state.order) do
            local target = targets[id]
            local xOffset = cascadeDirection.horizontal == "right" and spread - step * (i - 1) or step * (i - 1)
            local yOffset = cascadeDirection.vertical == "bottom" and spread - step * (i - 1) or step * (i - 1)

            target:place({
                x = area.x + area.w * xOffset,
                y = area.y + area.h * yOffset,
                w = area.w * scale,
                h = area.h * scale,
            })
        end
    end,

    layout_msg = function(ctx, message)
        if message == "refresh" then
            return true
        end

        local reorder_actions = {
            backward = -1,
            forward = 1,
        }
        if message ~= "next" and message ~= "prev" and not reorder_actions[message] and message ~= "end" and message ~= "top" then
            return "cascade: expected next, prev, backward, forward, end, top, or refresh"
        end

        local targets = sync_order(ctx)
        if #state.order < 2 then
            return true
        end

        if message == "top" then
            local target = targets[state.order[1]]
            if not target or not target.window then
                return "cascade: top card has no window"
            end

            hl.dispatch(hl.dsp.focus({
                window = "address:" .. target.window.address,
            }))
            return true
        end

        local focused_index = index_of(state.order, state.focused_id) or 1
        if reorder_actions[message] then
            local target_index = focused_index + reorder_actions[message]
            if target_index < 1 or target_index > #state.order then
                return true
            end
            state.order[focused_index], state.order[target_index] = state.order[target_index], state.order
                [focused_index]
            restack_windows()
            return true
        end

        if message == "end" then
            local focused_id = table.remove(state.order, focused_index)
            table.insert(state.order, focused_id)
            restack_windows()
            return true
        end

        local offset = message == "next" and 1 or -1
        local target_index = (focused_index - 1 + offset) % #state.order + 1
        local target = targets[state.order[target_index]]

        if not target or not target.window then
            return "cascade: target card has no window"
        end

        hl.dispatch(hl.dsp.focus({
            window = "address:" .. target.window.address,
        }))

        return true
    end,
})

hl.on("window.active", function()
    if hl.get_config("general.layout") ~= "lua:cascade" then
        return
    end

    hl.dispatch(hl.dsp.layout("refresh"))
    restack_windows()
end)

-- Allows cycling with arrow keys
local function focus_card_or_direction(direction, message)
    return function()
        local active_window = hl.get_active_window()
        local layout = hl.get_config("general.layout")
        if layout == "lua:cascade" and active_window and not active_window.floating then
            hl.dispatch(hl.dsp.layout(message))
        else
            hl.dispatch(hl.dsp.focus({ direction = direction }))
        end
    end
end

hl.bind(mainMod .. " + left", focus_card_or_direction("left", "next"), { repeating = true })
hl.bind(mainMod .. " + right", focus_card_or_direction("right", "prev"), { repeating = true })

-- For moving windows around the stack (for Numpad)
local function cascade_or_layout_action(cascade_message, layout_message)
    return function()
        local message = hl.get_config("general.layout") == "lua:cascade" and cascade_message or layout_message
        hl.dispatch(hl.dsp.layout(message))
    end
end

hl.bind(mainMod .. " + KP_Left", cascade_or_layout_action("forward", "swapcol l"), { repeating = true })
hl.bind(mainMod .. " + KP_Right", cascade_or_layout_action("backward", "swapcol r"), { repeating = true })
hl.bind(mainMod .. " + KP_Begin", cascade_or_layout_action("top", "fit toend"), { repeating = true })
hl.bind(mainMod .. " + KP_End", cascade_or_layout_action("end", "consume_or_expel prev"), { repeating = true })
hl.bind(mainMod .. " + KP_Next", cascade_or_layout_action("front", "consume_or_expel next"), { repeating = true })
