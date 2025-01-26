const DebugUI = @import("DebugUI.zig");
const Button = @import("Button.zig");
const Rectangle = @import("Primatives.zig").Rectangle;
const Color = @import("Primatives.zig").Color;

pub const Bounds = struct {
    x: f32,
    y: f32,
    height: f32,
    width: f32,
};

pub const Extents = struct {
    width: f32,
    height: f32,
};
