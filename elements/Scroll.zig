const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const Scroll = @This();
const Element = DebugUI.Element;
const FlexStrip = @import("../layouts/FlexStrip.zig");
const Bounds = @import("../utils.zig").Bounds;

pub const State = struct {
    scroll_pos: f32,
};

velocity: f32,
elapsed: f32,

const DECAY: f32 = 0.25;

pub const Mode = enum {
    Smooth,
    Linear,
};

inline fn updateVelocity(velocity: f32, delta_time: f32, scroll_y: f32, mode: Mode) f32 {
    if (mode == .Smooth) {
        const lambda = -@log(delta_time) / DECAY;
        const decay = @exp(-lambda * delta_time);
        return (velocity + scroll_y * delta_time * 520.0) * decay;
    } else if (mode == .Linear) {
        return scroll_y * delta_time * 1000.0;
    } else unreachable;
}

pub fn start(ui: *DebugUI, id: [*:0]const u8) void {
    std.debug.assert(ui.currentLayout().* == .flex_strip);

    const state = ui.getState(id);

    if (state.is_undefined) return;

    if (ui.currentLayout().flex_strip.direction == .Column) {
        ui.currentLayout().flex_strip.bounds.y += state.retained.state.scroll.scroll_pos;
    } else {
        ui.currentLayout().flex_strip.bounds.x += state.retained.state.scroll.scroll_pos;
    }
}

pub fn getOriginalBounds(ui: *DebugUI, id: [*:0]const u8) Bounds {
    const layout_bounds = ui.currentLayout().flex_strip.bounds;

    var state = ui.getState(id);

    if (state.is_undefined) {
        state.retained.state.scroll.scroll_pos = 0;
    }

    const bounds = Bounds{
        .x = layout_bounds.x - if (ui.currentLayout().flex_strip.direction == .Column) 0 else state.retained.state.scroll.scroll_pos,
        .y = layout_bounds.y - if (ui.currentLayout().flex_strip.direction == .Row) 0 else state.retained.state.scroll.scroll_pos,
        .width = layout_bounds.width,
        .height = layout_bounds.height,
    };

    return bounds;
}

pub fn end(ui: *DebugUI, mode: Mode, id: [*:0]const u8) void {
    std.debug.assert(ui.currentLayout().* == .flex_strip);

    const bounds = getOriginalBounds(ui, id);
    const events = ui.getEvents(&bounds);
    const within = bounds.clip(&ui.scroll_bounds).equals(&bounds);

    if (ui.scroll_y != 0 and events.mouse_over and within) {
        ui.setId(id);
        ui.active_element = Element{
            .scroll = Scroll{
                .velocity = updateVelocity(0, ui.delta_time, ui.scroll_y, mode),
                .elapsed = 0,
            },
        };
        ui.scroll_bounds = bounds;
    }

    if (ui.compareId(id)) {
        ui.active_element.scroll.velocity = updateVelocity(ui.active_element.scroll.velocity, ui.delta_time, ui.scroll_y, mode);
        ui.active_element.scroll.elapsed += ui.delta_time;

        if (ui.scroll_y != 0) {
            ui.active_element.scroll.elapsed = 0;
        } else if (ui.active_element.scroll.elapsed > DECAY) {
            ui.active_element_id[0] = 0;
            ui.scroll_bounds = Bounds.max_bounds();
        }

        var state = ui.getState(id);
        state.retained.state.scroll.scroll_pos += ui.active_element.scroll.velocity;

        const old = state.retained.state.scroll.scroll_pos;
        const space_exhausted = ui.currentLayout().flex_strip.exhausted_space;

        state.retained.state.scroll.scroll_pos = std.math.clamp(
            state.retained.state.scroll.scroll_pos,
            -space_exhausted + FlexStrip.GAP + if (ui.currentLayout().flex_strip.direction == .Row) bounds.width else bounds.height,
            0,
        );

        if (state.retained.state.scroll.scroll_pos != old) {
            ui.active_element.scroll.velocity = 0;
        }
    }
}
