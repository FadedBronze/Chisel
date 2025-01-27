const std = @import("std");

const Primatives = @import("../Primatives.zig");
const DebugUI = @import("../DebugUI.zig");
const Bounds = @import("../utils.zig").Bounds;
const Extents = @import("../utils.zig").Extents;
const Element = DebugUI.Element;

const Button = @This();

const PADDING = 8;

hover_duration: f32,

pub fn create(ui: *DebugUI, font_backend: anytype, text: []const u8, _: ?[]const u8, id: u32) bool {
    const button_width = font_backend.getLineWidth(0, text) + PADDING * 2;
    var text_height: f32 = 0;

    const bounds = bounds: {
        switch (ui.currentLayout().*) {
            .grid => |*grid| {
                const space = grid.getCellBounds();
                const lines: f32 = @floatFromInt(font_backend.getRequiredLinesToFitWords(0, space.width - PADDING * 2, text));
                text_height = lines * font_backend.getLineHeight(0);
                break :bounds space;
            },
            .panel => |*panel| {
                switch (panel.direction) {
                    .Row => {
                        text_height = font_backend.getLineHeight(0);
                        break :bounds panel.iterLayout(button_width);
                    },
                    .Column => {
                        const space = panel.getSpace();
                        const lines: f32 = @floatFromInt(font_backend.getRequiredLinesToFitWords(0, space.width - PADDING * 2, text));
                        text_height = lines * font_backend.getLineHeight(0);
                        const button_height = text_height + PADDING * 2;
                        break :bounds panel.iterLayout(button_height);
                    },
                }
            },
        }
    };

    const remaining_vertical_space = bounds.height - text_height;

    const text_block = Primatives.TextBlock{
        .x = PADDING + bounds.x,
        .y = bounds.y + @divExact(remaining_vertical_space, 2),
        .width = bounds.width - PADDING * 2,
        .text = text,
        .color = Primatives.Color.white(),
        .text_align = Primatives.TextAlign.Center,
        .text_break = Primatives.TextBreak.Word,
        .font_id = 0,
    };

    const base = Primatives.Rectangle{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = bounds.height,
        .color = Primatives.Color.gray(100),
    };

    ui.primatives.addRectangle(base);
    ui.primatives.addText(text_block);

    const local_events = ui.getEvents(&bounds);

    if (local_events.mouse_over and ui.active_element_id == 0) {
        ui.active_element = Element{ .button = Button{
            .hover_duration = 0,
        } };
        ui.active_element_id = id;
    }

    if (local_events.hover_exit) {
        ui.active_element_id = 0;
    }

    if (ui.active_element_id != id) return false;

    const hover = Primatives.Rectangle{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = bounds.height,
        .color = Primatives.Color.gray(122),
    };

    if (local_events.mouse_held and local_events.mouse_over) {
        ui.primatives.addRectangle(hover);
    }

    const tooltip_base = Primatives.Rectangle{
        .x = ui.mouse_x,
        .y = ui.mouse_y,
        .width = 120.0,
        .height = 12.0 + 5 * 2,
        .color = Primatives.Color.gray(122),
    };

    if (local_events.mouse_over) {
        ui.active_element.button.hover_duration += ui.delta_time;
    } else {
        ui.active_element.button.hover_duration = 0;
    }

    if (ui.active_element.button.hover_duration > 1.0) {
        ui.active_element.button.hover_duration = @min(ui.active_element.button.hover_duration, 15.0);
        ui.primatives.addRectangle(tooltip_base);
    }

    return local_events.mouse_down and local_events.mouse_over;
}
