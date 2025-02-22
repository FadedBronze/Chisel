const std = @import("std");

const Primatives = @import("../Primatives.zig");
const DebugUI = @import("../DebugUI.zig");
const Bounds = @import("../utils.zig").Bounds;
const Extents = @import("../utils.zig").Extents;
const Element = DebugUI.Element;

const Dropdown = @This();

const PADDING = 8;

open: bool,

pub const CreateInfo = struct {
    selected: *u32,
    options: []const []const u8,
    tooltips: []const []const u8,
};

pub fn create(ui: *DebugUI, font_backend: anytype, create_info: CreateInfo, id: [*:0]const u8) void {
    std.debug.assert(create_info.options.len == create_info.tooltips.len and create_info.tooltips.len > 0);

    const max_text: []const u8 = largest_text: {
        var max_width: f32 = 0;
        var max_text: []const u8 = "";

        for (create_info.options) |option| {
            const new_width = font_backend.getLineWidth(0, option);

            if (new_width > max_width) {
                max_width = new_width;
                max_text = option;
            }
        }

        break :largest_text max_text;
    };

    const button_width = font_backend.getLineWidth(0, max_text) + PADDING * 2;

    var text_height: f32 = 0;

    const bounds = bounds: {
        switch (ui.currentLayout().*) {
            .grid => |*grid| {
                const space = grid.getCellBounds();
                const lines: f32 = @floatFromInt(font_backend.getRequiredLinesToFitWords(0, space.width - PADDING * 2, max_text));
                text_height = lines * font_backend.getLineHeight(0);
                break :bounds space;
            },
            .flex_strip => |*flex_strip| {
                switch (flex_strip.direction) {
                    .Row => {
                        text_height = font_backend.getLineHeight(0);
                        break :bounds flex_strip.iterLayout(button_width);
                    },
                    .Column => {
                        const space = flex_strip.getSpace();
                        const lines: f32 = @floatFromInt(font_backend.getRequiredLinesToFitWords(0, space - PADDING * 2, max_text));
                        text_height = lines * font_backend.getLineHeight(0);
                        const button_height = text_height + PADDING * 2;
                        break :bounds flex_strip.iterLayout(button_height);
                    },
                }
            },
            else => {
                std.debug.print("Button does not support this type of layout\n", .{});
                unreachable;
            },
        }
    };

    const remaining_vertical_space = bounds.height - text_height;

    const text_block = Primatives.TextBlock{
        .x = PADDING + bounds.x,
        .y = bounds.y + @divExact(remaining_vertical_space, 2),
        .width = bounds.width - PADDING * 2,
        .text = create_info.options[create_info.selected.*],
        .color = Primatives.Color.white(),
        .text_align = Primatives.TextAlign.Left,
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

    if (local_events.mouse_over and ui.active_element_id[0] == 0) {
        ui.active_element = Element{ .dropdown = Dropdown{ .open = false } };
        ui.setId(id);
    }

    if (!ui.compareId(id)) return;

    const hover = Primatives.Rectangle{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = bounds.height,
        .color = Primatives.Color.gray(122),
    };

    if (local_events.mouse_down and local_events.mouse_over) {
        ui.active_element.dropdown.open = !ui.active_element.dropdown.open;
    }

    if (local_events.mouse_held and local_events.mouse_over) {
        ui.primatives.addRectangle(hover);
    }

    if (local_events.hover_exit) {
        ui.active_element_id[0] = 0;
    }
}
