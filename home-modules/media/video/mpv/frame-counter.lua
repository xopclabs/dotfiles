local enabled = false
local timer = nil

local function update_frame_counter()
    local frame = mp.get_property_number("estimated-frame-number", 0)
    local total = mp.get_property_number("estimated-frame-count", 0)
    mp.set_osd_ass(0, 0, string.format("{\\an9\\fs18\\bord1}Frame: %d / %d", frame, total))
end

local function toggle()
    enabled = not enabled
    if enabled then
        update_frame_counter()
        timer = mp.add_periodic_timer(0.05, update_frame_counter)
    else
        if timer then
            timer:kill()
            timer = nil
        end
        mp.set_osd_ass(0, 0, "")
    end
end

mp.register_script_message("toggle-frame-counter", toggle)
