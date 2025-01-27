const DebugUI = @import("DebugUI.zig");
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

const NEGLIGIBLE_DIFFERENCE = 0.001;

pub inline fn almost_le(a: anytype, b: anytype) bool {
    return a < b or almost_eq(a, b);
}

pub inline fn almost_ge(a: anytype, b: anytype) bool {
    return a > b or almost_eq(a, b);
}

pub inline fn almost_eq(a: anytype, b: anytype) bool {
    return a - b < NEGLIGIBLE_DIFFERENCE;
}
