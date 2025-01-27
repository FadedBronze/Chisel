const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const utils = @import("../utils.zig");
const Primatives = @import("../Primatives.zig");
const layout = @import("index.zig");

const Bounds = utils.Bounds;
const Extents = utils.Extents;
const ElementLayout = layout.ElementLayout;
const Rectangle = Primatives.Rectangle;
const Color = Primatives.Color;

const Panel = @This();

const PADDING = 5;
const GAP = 5;

width_used: f32,
height_used: f32,
line_height: f32,
bounds: Bounds,

pub fn iterLayout(self: *Panel, bounds: Extents) Bounds {
    self.width_used += bounds.width;

    if (self.width_used > self.bounds.width) {
        self.width_used = bounds.width;
        self.height_used += self.line_height;
    }

    self.line_height = @max(self.line_height, bounds.height);

    return Bounds{
        .x = self.width_used + self.bounds.x - bounds.width,
        .y = self.height_used + self.bounds.y,
        .width = bounds.width,
        .height = bounds.height,
    };
}

pub fn getSpace(self: *Panel) Extents {
    return Extents{
        .width = self.bounds.width,
        .height = self.bounds.height - self.height_used - self.line_height,
    };
}

pub fn start(ui: *DebugUI, bounds: Bounds) void {
    ui.beginLayout(ElementLayout{ .panel = Panel{
        .bounds = .{
            .x = bounds.x + PADDING,
            .y = bounds.y + PADDING,
            .width = bounds.width - PADDING * 2,
            .height = bounds.height - PADDING * 2,
        },
        .line_height = 0,
        .width_used = 0,
        .height_used = 0,
    } });

    ui.primatives.addRectangle(Rectangle{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = bounds.height,
        .color = Color.gray(50),
    });
}

pub fn end(ui: *DebugUI) void {
    ui.endLayout();
}
