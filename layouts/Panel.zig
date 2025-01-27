const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const utils = @import("../utils.zig");
const Primatives = @import("../Primatives.zig");

const Bounds = utils.Bounds;
const Extents = utils.Extents;
const ElementLayout = DebugUI.ElementLayout;
const Rectangle = Primatives.Rectangle;
const Color = Primatives.Color;

const Panel = @This();

const PADDING = 5;
const GAP = 5;

pub const Direction = enum { Row, Column };

exhausted_space: f32,
direction: Direction,
bounds: Bounds,

pub fn iterLayout(self: *Panel, space: f32) Bounds {
    self.exhausted_space += space + GAP;

    return switch (self.direction) {
        .Column => Bounds{
            .x = self.bounds.x,
            .y = self.bounds.y + self.exhausted_space - (space + GAP),
            .width = self.bounds.width,
            .height = space,
        },
        .Row => Bounds{
            .x = self.bounds.x + self.exhausted_space - (space + GAP),
            .y = self.bounds.y,
            .width = space,
            .height = self.bounds.height,
        },
    };
}

pub fn getSpace(self: *Panel) Extents {
    const space = switch (self.direction) {
        .Column => self.bounds.height - self.exhausted_space,
        .Row => self.bounds.width - self.exhausted_space,
    };

    const secondary = switch (self.direction) {
        .Column => self.bounds.width,
        .Row => self.bounds.height,
    };

    return Extents{
        .height = if (self.direction == .Column) space else secondary,
        .width = if (self.direction == .Row) space else secondary,
    };
}

pub fn start(ui: *DebugUI, bounds: Bounds, direction: Direction) void {
    const element = ElementLayout{ .panel = Panel{
        .bounds = .{
            .x = bounds.x + PADDING,
            .y = bounds.y + PADDING,
            .width = bounds.width - PADDING * 2,
            .height = bounds.height - PADDING * 2,
        },
        .exhausted_space = 0,
        .direction = direction,
    } };

    ui.beginLayout(element);

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
