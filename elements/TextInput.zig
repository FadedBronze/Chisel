const std = @import("std");

const Primatives = @import("../Primatives.zig");
const DebugUI = @import("../DebugUI.zig");
const Bounds = @import("../utils.zig").Bounds;
const Extents = @import("../utils.zig").Extents;
const Element = DebugUI.Element;

const TextInput = @This();
const Scancode = @import("../utils.zig").Scancode;

const PADDING = 8;
const BORDER = 1;
const CURSOR_WIDTH = 2;
const GAP_SIZE = 4;

selected: bool,
buffer: [512]u8,
gap_start: u32,
gap_end: u32,
buffer_size: u32,
holding_shift: bool,
holding_ctrl: bool,

fn gap_buffer_left(self: *TextInput) void {
    if (self.gap_start == 0) return;

    self.buffer[self.gap_end - 1] = self.buffer[self.gap_start - 1];

    self.gap_start -= 1;
    self.gap_end -= 1;
}

fn gap_buffer_right(self: *TextInput) void {
    if (self.gap_end == self.buffer_size) return;

    self.buffer[self.gap_start] = self.buffer[self.gap_end];

    self.gap_start += 1;
    self.gap_end += 1;
}

fn gap_buffer_insert(self: *TextInput, character: u8) void {
    if (self.gap_end == self.gap_start) {
        var i: u32 = self.buffer_size - 1;
        while (i >= self.gap_end) : (i -= 1) {
            self.buffer[i + GAP_SIZE] = self.buffer[i];
        }
        self.gap_end += GAP_SIZE;
        self.buffer_size += GAP_SIZE;
    }

    self.buffer[self.gap_start] = character;
    self.gap_start += 1;
}

fn gap_buffer_delete(self: *TextInput) void {
    if (self.gap_start <= 0) return;
    self.gap_start -= 1;
    self.buffer[self.gap_start] = 170;
}

fn get_output(self: *TextInput, output: []u8) []u8 {
    @memcpy(output[0..self.gap_start], self.buffer[0..self.gap_start]);
    const gap_size = self.gap_end - self.gap_start;
    @memcpy(output[self.gap_start .. self.buffer_size - gap_size], self.buffer[self.gap_end..self.buffer_size]);
    return output[0 .. self.buffer_size - gap_size];
}

const NumberInput = struct {
    start: f32,
    end: f32,
    value: *f32,
};

const CharInput = struct {
    text: []u8,
    text_size: *u32,
};

pub const InputCreateInfo = union(enum) {
    number: NumberInput,
    character: CharInput,
};

fn init(text: []const u8) TextInput {
    var input = TextInput{
        .buffer_size = @as(u32, @intCast(text.len)) + GAP_SIZE,
        .buffer = undefined,
        .gap_start = 0,
        .gap_end = GAP_SIZE,
        .selected = false,
        .holding_shift = false,
        .holding_ctrl = false,
    };
    @memcpy(input.buffer[GAP_SIZE .. GAP_SIZE + text.len], text);
    return input;
}

pub fn create(ui: *DebugUI, font_backend: anytype, create_info: InputCreateInfo, id: [*:0]const u8) void {
    var text_buffer: [10]u8 = undefined;
    const text = if (create_info == .character) create_info.character.text else number_text: {
        var slice = std.fmt.bufPrint(&text_buffer, "{d:.2}", .{create_info.number.value.*}) catch "0.00";
        slice = ui.primatives.addString(slice);
        break :number_text slice;
    };

    const const_text_size = if (create_info == .character) create_info.character.text_size.* else text.len;

    const font_height = font_backend.getLineHeight(0);
    const button_width = font_backend.getLineWidth(0, text[0..const_text_size]) + PADDING * 2;

    const bounds = bounds: {
        switch (ui.currentLayout().*) {
            .grid => |*grid| {
                const space = grid.getCellBounds();
                break :bounds space;
            },
            .flex_strip => |*flex_strip| {
                switch (flex_strip.direction) {
                    .Row => {
                        break :bounds flex_strip.iterLayout(button_width);
                    },
                    .Column => {
                        const button_height = font_height + PADDING * 2;
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

    const remaining_vertical_space = bounds.height - font_height;

    var display_text = text[0..const_text_size];

    const active_id = ui.compareId(id);

    if (active_id) {
        var display_temp_buffer: [16]u8 = undefined;
        var temp = ui.active_element.text_input.get_output(&display_temp_buffer);
        display_text = ui.primatives.addString(temp[0..temp.len]);
    }

    const text_block = Primatives.TextBlock{
        .x = PADDING + bounds.x,
        .y = bounds.y + @divExact(remaining_vertical_space, 2),
        .width = 10000,
        .text = display_text,
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
        .color = if (active_id and ui.active_element.text_input.selected) Primatives.Color.gray(144) else Primatives.Color.gray(122),
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

    ui.primatives.start_clip(base.x, base.y, base.width, base.height);
    ui.primatives.addText(text_block);
    ui.primatives.end_clip();

    const local_events = ui.getEvents(&bounds);

    if (local_events.mouse_over and ui.active_element_id[0] == 0) {
        ui.active_element = Element{ .text_input = TextInput.init(text[0..const_text_size]) };
        ui.setId(id);
    }

    if (!ui.compareId(id)) return;

    if (local_events.mouse_down and local_events.mouse_over) {
        ui.active_element.text_input.selected = true;

        var i: usize = 0;

        while (ui.active_element.text_input.gap_start != 0) {
            ui.active_element.text_input.gap_buffer_left();
        }

        while (i < const_text_size) : (i += 1) {
            const current = font_backend.getLineWidth(0, text[0..i]);
            const next = font_backend.getLineWidth(0, text[0 .. i + 1]);

            if (current + @divTrunc(next - current, 2) + PADDING + bounds.x < ui.mouse_x) {
                ui.active_element.text_input.gap_buffer_right();
            } else break;
        }
    }

    if (local_events.hover_exit) {
        if (create_info == .number) {
            var display_temp_buffer: [16]u8 = undefined;
            const slice = ui.active_element.text_input.get_output(&display_temp_buffer);
            const value = std.fmt.parseFloat(f32, slice) catch 0;
            create_info.number.value.* = std.math.clamp(value, create_info.number.start, create_info.number.end);
        }

        ui.active_element_id[0] = 0;
    }

    if (!ui.active_element.text_input.selected) return;
    const offset = font_backend.getLineWidth(0, text[0..ui.active_element.text_input.gap_start]);

    const cursor = Primatives.Rectangle{
        .x = PADDING + bounds.x + offset,
        .y = bounds.y + @divExact(remaining_vertical_space, 2),
        .width = CURSOR_WIDTH,
        .height = font_height,
        .color = if (ui.compareId(id) and ui.active_element.text_input.selected) Primatives.Color.gray(144) else Primatives.Color.gray(122),
    };

    ui.primatives.addRectangle(cursor);

    for (ui.keys) |key| {
        if (key.pressType == .UP) {
            if (key.value == .SCANCODE_LSHIFT or key.value == .SCANCODE_RSHIFT) {
                ui.active_element.text_input.holding_shift = false;
            }

            if (key.value == .SCANCODE_LCTRL or key.value == .SCANCODE_RCTRL) {
                ui.active_element.text_input.holding_ctrl = false;
            }
        }

        if (key.pressType == .DOWN) {
            if (key.value == .SCANCODE_LSHIFT or key.value == .SCANCODE_RSHIFT) {
                ui.active_element.text_input.holding_shift = true;
            }

            if (key.value == .SCANCODE_LCTRL or key.value == .SCANCODE_RCTRL) {
                ui.active_element.text_input.holding_ctrl = true;
            }

            const caps = ui.active_element.text_input.holding_shift;
            const ctrl = ui.active_element.text_input.holding_ctrl;

            if (key.value == .SCANCODE_RIGHT) {
                ui.active_element.text_input.gap_buffer_right();

                if (ctrl) {
                    while (ui.active_element.text_input.buffer[ui.active_element.text_input.gap_end - 1] != ' ' and ui.active_element.text_input.gap_end != ui.active_element.text_input.buffer_size) {
                        ui.active_element.text_input.gap_buffer_right();
                    }
                }
            }

            if (key.value == .SCANCODE_LEFT) {
                ui.active_element.text_input.gap_buffer_left();

                if (ctrl) {
                    while (ui.active_element.text_input.buffer[ui.active_element.text_input.gap_start] != ' ' and ui.active_element.text_input.gap_start != 0) {
                        ui.active_element.text_input.gap_buffer_left();
                    }
                }
            }

            if (key.value == .SCANCODE_BACKSPACE) {
                ui.active_element.text_input.gap_buffer_delete();

                if (ctrl) {
                    while (ui.active_element.text_input.buffer[ui.active_element.text_input.gap_start - 1] != ' ' and ui.active_element.text_input.gap_start != 1) {
                        ui.active_element.text_input.gap_buffer_delete();
                    }
                    ui.active_element.text_input.gap_buffer_delete();
                }
            }

            const int_key = @intFromEnum(key.value);

            if (int_key >= @intFromEnum(Scancode.SCANCODE_A) and int_key <= @intFromEnum(Scancode.SCANCODE_Z)) {
                ui.active_element.text_input.gap_buffer_insert(@as(u8, @intCast(int_key)) - @as(u8, @intCast(@intFromEnum(Scancode.SCANCODE_A))) + (if (caps) @as(u8, @intCast('A')) else @as(u8, 'a')));
            }

            if (key.value == .SCANCODE_SPACE) {
                ui.active_element.text_input.gap_buffer_insert(' ');
            }

            if (key.value == .SCANCODE_1) ui.active_element.text_input.gap_buffer_insert(if (caps) '!' else '1');
            if (key.value == .SCANCODE_2) ui.active_element.text_input.gap_buffer_insert(if (caps) '@' else '2');
            if (key.value == .SCANCODE_3) ui.active_element.text_input.gap_buffer_insert(if (caps) '#' else '3');
            if (key.value == .SCANCODE_4) ui.active_element.text_input.gap_buffer_insert(if (caps) '$' else '4');
            if (key.value == .SCANCODE_5) ui.active_element.text_input.gap_buffer_insert(if (caps) '%' else '5');
            if (key.value == .SCANCODE_6) ui.active_element.text_input.gap_buffer_insert(if (caps) '^' else '6');
            if (key.value == .SCANCODE_7) ui.active_element.text_input.gap_buffer_insert(if (caps) '&' else '7');
            if (key.value == .SCANCODE_8) ui.active_element.text_input.gap_buffer_insert(if (caps) '*' else '8');
            if (key.value == .SCANCODE_9) ui.active_element.text_input.gap_buffer_insert(if (caps) '(' else '9');
            if (key.value == .SCANCODE_0) ui.active_element.text_input.gap_buffer_insert(if (caps) ')' else '0');

            if (key.value == .SCANCODE_LEFTBRACKET) ui.active_element.text_input.gap_buffer_insert(if (!caps) '[' else '{');
            if (key.value == .SCANCODE_RIGHTBRACKET) ui.active_element.text_input.gap_buffer_insert(if (!caps) ']' else '}');

            if (key.value == .SCANCODE_BACKSLASH) ui.active_element.text_input.gap_buffer_insert(if (!caps) '\\' else '|');
            if (key.value == .SCANCODE_SLASH) ui.active_element.text_input.gap_buffer_insert(if (!caps) '/' else '?');
            if (key.value == .SCANCODE_SEMICOLON) ui.active_element.text_input.gap_buffer_insert(if (!caps) ';' else ':');
            if (key.value == .SCANCODE_APOSTROPHE) ui.active_element.text_input.gap_buffer_insert(if (!caps) '\'' else '"');
            if (key.value == .SCANCODE_MINUS) ui.active_element.text_input.gap_buffer_insert(if (!caps) '-' else '_');
            if (key.value == .SCANCODE_EQUALS) ui.active_element.text_input.gap_buffer_insert(if (!caps) '=' else '+');
            if (key.value == .SCANCODE_PERIOD) ui.active_element.text_input.gap_buffer_insert(if (!caps) '.' else '>');
            if (key.value == .SCANCODE_COMMA) ui.active_element.text_input.gap_buffer_insert(if (!caps) ',' else '<');
        }
    }

    if (create_info == .character) {
        create_info.character.text_size.* = @intCast(ui.active_element.text_input.get_output(create_info.character.text).len);
    }
}
