const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const Scroll = @This();

pub const State = struct {
    scroll_pos: f32,
};

pub fn create(ui: *DebugUI, id: u32) void {
    std.debug.assert(ui.currentLayout().* == .flex_strip);

    var state = ui.getState(id);

    if (state.is_undefined) {
        state.retained.state.scroll.scroll_pos = 0;
    } else {
        state.retained.state.scroll.scroll_pos = 120;
    }

    ui.currentLayout().flex_strip.bounds.y = state.retained.state.scroll.scroll_pos;
}
