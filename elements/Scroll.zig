const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const Scroll = @This();
const Element = DebugUI.Element;
const FlexStrip = @import("../layouts/FlexStrip.zig");

pub const State = struct {
    scroll_pos: f32,
};

velocity: f32,
elapsed: f32,

const DECAY_TIME = 0.75;

pub fn start(ui: *DebugUI, id: u32) void {
    std.debug.assert(ui.currentLayout().* == .flex_strip);

    const events = ui.getEvents(&ui.currentLayout().flex_strip.bounds);

    if (events.mouse_over and ui.scroll_y != 0 and ui.active_element_id != id) {
        ui.active_element_id = id;
        ui.active_element = Element{ .scroll = Scroll{ .velocity = 0, .elapsed = 0 } };
    }

    var state = ui.getState(id);

    if (state.is_undefined) {
        state.retained.state.scroll.scroll_pos = 0;
    }

    if (ui.active_element_id == id) {
        state.retained.state.scroll.scroll_pos += ui.active_element.scroll.velocity * 25;

        //if (ui.active_element.scroll.clear_velocity) {
        //    ui.active_element.scroll.velocity = 0;
        //    ui.active_element.scroll.clear_velocity = false;
        //}

        if (ui.scroll_y == 0) {
            ui.active_element.scroll.elapsed = 0;
        }

        if (!events.mouse_over or events.mouse_down) {
            ui.active_element_id = 0;
        }
    }

    if (ui.currentLayout().flex_strip.direction == .Column) {
        ui.currentLayout().flex_strip.bounds.y += state.retained.state.scroll.scroll_pos;
    } else {
        ui.currentLayout().flex_strip.bounds.x += state.retained.state.scroll.scroll_pos;
    }
}

pub fn end(ui: *DebugUI, id: u32) void {
    std.debug.assert(ui.currentLayout().* == .flex_strip);

    var state = ui.getState(id);

    std.debug.assert(!state.is_undefined);

    if (ui.active_element_id != id) return;

    ui.active_element.scroll.elapsed += ui.delta_time;
    const lamba = @log(0.001) / DECAY_TIME;
    const decay = @exp(lamba * ui.active_element.scroll.elapsed);

    ui.active_element.scroll.velocity += ui.scroll_y * ui.delta_time * 45;
    ui.active_element.scroll.velocity *= decay;

    const overflow = FlexStrip.GAP - ui.currentLayout().flex_strip.exhausted_space + if (ui.currentLayout().flex_strip.direction == .Column) ui.currentLayout().flex_strip.bounds.height else ui.currentLayout().flex_strip.bounds.width;

    if (overflow - ui.active_element.scroll.velocity * 25 > state.retained.state.scroll.scroll_pos) {
        ui.active_element.scroll.velocity = 0;
        state.retained.state.scroll.scroll_pos = overflow;
    }

    if (0 - ui.active_element.scroll.velocity * 25 < state.retained.state.scroll.scroll_pos) {
        ui.active_element.scroll.velocity = 0;
        state.retained.state.scroll.scroll_pos = 0;
    }
}
