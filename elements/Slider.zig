const std = @import("std");

const Primatives = @import("../Primatives.zig");
const DebugUI = @import("../DebugUI.zig");
const Bounds = @import("../utils.zig").Bounds;
const Extents = @import("../utils.zig").Extents;
const Element = DebugUI.Element;

const Rectangle = Primatives.Rectangle;
const Color = Primatives.Color;
const TextBlock = Primatives.TextBlock;

const Slider = @This();

const HEIGHT = 20;
const KNOB_GROW_SIZE = 25;
const GAP = 2;

holding_knob: bool,

pub fn create(ui: *DebugUI, font_backend: anytype, min: f32, max: f32, value: *f32, label: []const u8, id: [*:0]const u8) void {
    const font_height = font_backend.getLineHeight(2);
    const actual_height = font_height + GAP + HEIGHT;

    const bounds = bounds: {
        switch (ui.currentLayout().*) {
            .grid => |*grid| {
                const max_bounds = grid.getCellBounds();
                break :bounds Bounds{
                    .x = max_bounds.x,
                    .y = max_bounds.y + @divExact(max_bounds.height - actual_height, 2),
                    .width = max_bounds.width,
                    .height = actual_height,
                };
            },
            .flex_strip => |*flex_strip| {
                const slider_height = HEIGHT + font_height + GAP;

                switch (flex_strip.direction) {
                    .Row => {
                        var bounds = flex_strip.iterLayout(250);
                        bounds.y += @divExact(bounds.height - actual_height, 2);
                        break :bounds bounds;
                    },
                    .Column => {
                        break :bounds flex_strip.iterLayout(slider_height);
                    },
                }
            },
            else => {
                std.debug.print("Slider does not support this type of layout\n", .{});
                unreachable;
            },
        }
    };

    // back
    ui.primatives.addRectangle(Rectangle{
        .x = bounds.x,
        .y = bounds.y + font_height + GAP,
        .width = bounds.width,
        .height = HEIGHT,
        .color = Color.gray(180),
    });

    // knob
    const knob_pos = (value.* - min) / (max - min);

    ui.primatives.addRectangle(Rectangle{
        .x = bounds.x + knob_pos * (bounds.width - HEIGHT),
        .y = bounds.y + font_height + GAP,
        .width = HEIGHT,
        .height = HEIGHT,
        .color = Color.gray(220),
    });

    var current_val_buffer: [10]u8 = undefined;
    const current_val_slice = ui.primatives.addString(std.fmt.bufPrint(&current_val_buffer, "{d:.2}\x00", .{(knob_pos * (max - min)) + min}) catch "0.00\x00");

    var max_val_buffer: [10]u8 = undefined;
    const max_val_slice = ui.primatives.addString(std.fmt.bufPrint(&max_val_buffer, "{d:.2}\x00", .{max}) catch "0.00\x00");

    // text
    ui.primatives.addText(TextBlock{
        .width = bounds.width,
        .color = Color.white(),
        .font_id = 2,
        .text = current_val_slice,
        .x = bounds.x,
        .y = bounds.y,
        .text_align = .Center,
        .text_break = .Word,
    });

    ui.primatives.addText(TextBlock{
        .width = bounds.width,
        .color = Color.white(),
        .font_id = 2,
        .text = max_val_slice,
        .x = bounds.x,
        .y = bounds.y,
        .text_align = .Right,
        .text_break = .Word,
    });

    ui.primatives.addText(TextBlock{
        .width = bounds.width,
        .color = Color.white(),
        .font_id = 2,
        .text = label,
        .x = bounds.x,
        .y = bounds.y,
        .text_align = .Left,
        .text_break = .Word,
    });

    const events = ui.getEvents(&bounds);

    if (events.mouse_over and ui.active_element_id[0] == 0) {
        ui.active_element = Element{ .slider = Slider{
            .holding_knob = false,
        } };
        ui.setId(id);
    }

    if (!ui.compareId(id)) return;

    const mouse_pos = @max(@min((ui.mouse_x - (HEIGHT / 2) - bounds.x) / (bounds.width - HEIGHT), 1.0), 0.0);

    if (events.mouse_down and std.math.fabs(mouse_pos - knob_pos) * (bounds.width - HEIGHT * 2) < KNOB_GROW_SIZE) {
        ui.active_element.slider.holding_knob = true;
    }

    if (events.mouse_up) {
        ui.active_element.slider.holding_knob = false;
    }

    if (ui.active_element.slider.holding_knob) {
        value.* = (mouse_pos * (max - min)) + min;

        ui.primatives.addRectangle(Rectangle{
            .x = bounds.x + knob_pos * (bounds.width - HEIGHT) - ((KNOB_GROW_SIZE - HEIGHT) / 2),
            .y = bounds.y + (font_height + GAP) - ((KNOB_GROW_SIZE - HEIGHT) / 2),
            .width = KNOB_GROW_SIZE,
            .height = KNOB_GROW_SIZE,
            .color = Color.gray(255),
        });
    }

    if (!ui.active_element.slider.holding_knob and !events.mouse_over) {
        ui.active_element_id[0] = 0;
    }
}
