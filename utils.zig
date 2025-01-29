const DebugUI = @import("DebugUI.zig");
const Rectangle = @import("Primatives.zig").Rectangle;
const Color = @import("Primatives.zig").Color;

pub const Bounds = struct {
    x: f32,
    y: f32,
    height: f32,
    width: f32,

    pub fn clip(self: *const Bounds, outer: *const Bounds) Bounds {
        return Bounds{
            .x = @max(outer.x, self.x),
            .y = @max(outer.y, self.y),
            .width = @min(outer.x + outer.width, self.x + self.width) - @max(outer.x, self.x),
            .height = @min(outer.y + outer.height, self.y + self.height) - @max(outer.y, self.y),
        };
    }
};

pub const Extents = struct {
    width: f32,
    height: f32,
};
