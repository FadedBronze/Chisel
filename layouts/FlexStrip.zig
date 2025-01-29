const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const utils = @import("../utils.zig");

const Bounds = utils.Bounds;
const Extents = utils.Extents;
const ElementLayout = DebugUI.ElementLayout;

const FlexStrip = @This();

const Primatives = @import("../Primatives.zig");
const Rectangle = Primatives.Rectangle;
const Color = Primatives.Color;

pub const GAP = 5;
const PADDING = 5;

pub const Direction = enum { Row, Column };

exhausted_space: f32,
direction: Direction,
bounds: Bounds,

pub fn iterLayout(self: *FlexStrip, space: f32) Bounds {
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

pub fn peekLayout(self: *FlexStrip, space: f32) Bounds {
    return switch (self.direction) {
        .Column => Bounds{
            .x = self.bounds.x,
            .y = self.bounds.y + self.exhausted_space,
            .width = self.bounds.width,
            .height = space,
        },
        .Row => Bounds{
            .x = self.bounds.x + self.exhausted_space,
            .y = self.bounds.y,
            .width = space,
            .height = self.bounds.height,
        },
    };
}

pub fn getSpace(self: *FlexStrip) f32 {
    return switch (self.direction) {
        .Column => self.bounds.width,
        .Row => self.bounds.height,
    };
}

pub fn start(ui: *DebugUI, extents: Extents, direction: Direction, render_background: bool) void {
    var final_bounds: Bounds = undefined;

    switch (ui.currentLayout().*) {
        .grid => |*grid| {
            final_bounds = grid.getCellBounds();
        },
        .flex_strip => |*flex_strip| {
            switch (flex_strip.direction) {
                .Row => {
                    final_bounds = flex_strip.iterLayout(extents.width);
                },
                .Column => {
                    final_bounds = flex_strip.iterLayout(extents.height);
                },
            }
        },
        .frame => |frame| {
            final_bounds.x = frame.x;
            final_bounds.y = frame.y;
            final_bounds.width = extents.width;
            final_bounds.height = extents.height;
        },
    }

    if (render_background) {
        ui.primatives.addRectangle(Rectangle{
            .color = Color.gray(50),
            .width = final_bounds.width,
            .height = final_bounds.height,
            .x = final_bounds.x,
            .y = final_bounds.y,
        });

        ui.primatives.start_clip(final_bounds.x + PADDING, final_bounds.y + PADDING, final_bounds.width - PADDING * 2, final_bounds.height - PADDING * 2);
    } else {
        ui.primatives.start_clip(final_bounds.x, final_bounds.y, final_bounds.width, final_bounds.height);
    }

    ui.beginLayout(ElementLayout{ .flex_strip = FlexStrip{
        .bounds = if (render_background) Bounds{
            .width = final_bounds.width - PADDING * 2,
            .height = final_bounds.height - PADDING * 2,
            .x = final_bounds.x + PADDING,
            .y = final_bounds.y + PADDING,
        } else final_bounds,
        .exhausted_space = 0,
        .direction = direction,
    } });
}

pub fn end(ui: *DebugUI) void {
    ui.primatives.end_clip();
    ui.endLayout();
}
