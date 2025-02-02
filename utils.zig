const DebugUI = @import("DebugUI.zig");
const Rectangle = @import("Primatives.zig").Rectangle;
const Color = @import("Primatives.zig").Color;
const std = @import("std");

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

    pub fn equals(self: *const Bounds, other: *const Bounds) bool {
        return std.math.approxEqRel(f32, self.x, other.x, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.y, other.y, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.width, other.width, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.height, other.height, std.math.floatEps(f32) * 3.0);
    }

    pub fn min_bounds() Bounds {
        return Bounds{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };
    }

    pub fn max_bounds() Bounds {
        return Bounds{
            .x = std.math.floatMin(f32),
            .y = std.math.floatMin(f32),
            .width = std.math.floatMax(f32),
            .height = std.math.floatMax(f32),
        };
    }
};

pub const Extents = struct {
    width: f32,
    height: f32,
};
