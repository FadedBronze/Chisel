const std = @import("std");

const Primatives = @import("../Primatives.zig");
const DebugUI = @import("../DebugUI.zig");
const Bounds = @import("../utils.zig").Bounds;
const Extents = @import("../utils.zig").Extents;
const Element = DebugUI.Element;

const Dropdown = @This();

const PADDING = 8;
const GAP = 0;
const DROPDOWN_GAP = 8;
const BORDER = 1;

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

    const border = Primatives.Rectangle{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = bounds.height,
        .color = Primatives.Color.gray(122),
    };

    const base = Primatives.Rectangle{
        .x = bounds.x + BORDER,
        .y = bounds.y + BORDER,
        .width = bounds.width - BORDER * 2,
        .height = bounds.height - BORDER * 2,
        .color = Primatives.Color.gray(50),
    };

    ui.primatives.addRectangle(border);
    ui.primatives.addRectangle(base);
    ui.primatives.addText(text_block);

    const local_events = ui.getEvents(&bounds);

    if (local_events.mouse_over and ui.active_element_id[0] == 0) {
        ui.active_element = Element{ .dropdown = Dropdown{ .open = false } };
        ui.setId(id);
    }

    if (!ui.compareId(id)) return;

    const hover = Primatives.Rectangle{
        .x = bounds.x + BORDER,
        .y = bounds.y + BORDER,
        .width = bounds.width - BORDER * 2,
        .height = bounds.height - BORDER * 2,
        .color = Primatives.Color.gray(70),
    };

    if (ui.active_element.dropdown.open) {
        const font_height = font_backend.getLineHeight(0);
        var total_height: f32 = bounds.y + bounds.height + BORDER + DROPDOWN_GAP;

        for (create_info.options, create_info.tooltips, 0..) |option, _, i| {
            const lines: f32 = @floatFromInt(font_backend.getRequiredLinesToFitWords(0, bounds.width - PADDING * 2, option));
            const height: f32 = font_height * lines + PADDING * 2;
            const y = total_height;
            total_height += height + GAP;

            const dropdown_bounds = .{
                .x = bounds.x + BORDER,
                .y = y,
                .width = bounds.width - BORDER * 2,
                .height = height,
            };

            const dropdown_events = ui.getEvents(&dropdown_bounds);

            const dropdown_base = Primatives.Rectangle{
                .x = dropdown_bounds.x,
                .y = dropdown_bounds.y,
                .width = dropdown_bounds.width,
                .height = dropdown_bounds.height,
                .color = if (dropdown_events.mouse_over)
                    Primatives.Color.gray(70)
                else if (i == create_info.selected.*)
                    Primatives.Color.gray(60)
                else
                    Primatives.Color.gray(50),
            };

            const dropdown_text_block = Primatives.TextBlock{
                .x = PADDING + bounds.x,
                .y = PADDING + total_height - height,
                .width = bounds.width,
                .text = option,
                .color = Primatives.Color.white(),
                .text_align = Primatives.TextAlign.Left,
                .text_break = Primatives.TextBreak.Word,
                .font_id = 0,
            };

            if (dropdown_events.mouse_down and dropdown_events.mouse_over) {
                create_info.selected.* = @intCast(i);
                ui.active_element.dropdown.open = false;
            }

            ui.primatives.deferAddText(dropdown_text_block);
            ui.primatives.deferAddRectangle(dropdown_base);
        }

        const dropdown_border = Primatives.Rectangle{
            .x = bounds.x,
            .y = bounds.y + bounds.height + DROPDOWN_GAP,
            .width = bounds.width,
            .height = total_height - (bounds.y + bounds.height + DROPDOWN_GAP + GAP) + BORDER,
            .color = Primatives.Color.gray(122),
        };

        ui.primatives.deferAddRectangle(dropdown_border);
    }

    if (local_events.mouse_down and local_events.mouse_over) {
        ui.active_element.dropdown.open = !ui.active_element.dropdown.open;
    }

    if (local_events.mouse_over) {
        ui.primatives.addRectangle(hover);
    }

    if (local_events.hover_exit and !ui.active_element.dropdown.open) {
        ui.active_element_id[0] = 0;
    }
}
