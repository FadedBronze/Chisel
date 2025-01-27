const DebugUI = @import("../DebugUI.zig");
const ElementLayout = DebugUI.ElementLayout;
const utils = @import("../utils.zig");

const Frame = @This();

const GAP = 5;

x: f32,
y: f32,

pub fn start(ui: *DebugUI, x: f32, y: f32) void {
    ui.beginLayout(ElementLayout{ .frame = Frame{
        .x = x,
        .y = y,
    } });
}

pub fn end(ui: *DebugUI) void {
    ui.endLayout();
}
