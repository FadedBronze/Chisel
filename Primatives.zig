const std = @import("std");

const Primatives = @This();

const MAX_RECTANGLES = 1024;
const MAX_TEXT = 1024;
const MAX_CHARS = 1024;
const MAX_CLIPS = 128;

rectangles: [MAX_RECTANGLES]Rectangle,
rectangle_count: usize,

string_buffer: [MAX_CHARS]u8,
string_count: usize,

text: [MAX_TEXT]TextBlock,
text_count: usize,

clips: [MAX_CLIPS]ClipRectangle,
clip_count: usize,
clip_stack: [MAX_CLIPS / 4]usize,
clip_stack_size: usize,

pub inline fn start_clip(self: *Primatives, x: f32, y: f32, width: f32, height: f32) void {
    self.clips[self.clip_count] = ClipRectangle{
        .width = width,
        .height = height,
        .x = x,
        .y = y,
        .rectangle_range_start = self.rectangle_count,
        .text_range_start = self.text_count,
        .rectangle_range_end = 0,
        .text_range_end = 0,
    };

    self.clip_stack[self.clip_stack_size] = self.clip_count;

    self.clip_stack_size += 1;
    self.clip_count += 1;
}

pub inline fn end_clip(self: *Primatives) void {
    const last_clip = self.clip_stack[self.clip_stack_size - 1];

    self.clips[last_clip].rectangle_range_end = self.rectangle_count;
    self.clips[last_clip].text_range_end = self.text_count;

    self.clip_stack_size -= 1;
}

pub inline fn clear(self: *Primatives) void {
    self.rectangle_count = 0;
    self.text_count = 0;
    self.string_count = 0;
    self.clip_count = 0;
    self.clip_stack_size = 0;
}

pub inline fn addRectangle(self: *Primatives, rectangle: Rectangle) void {
    self.rectangles[self.rectangle_count] = rectangle;
    self.rectangle_count += 1;
}

pub inline fn addText(self: *Primatives, text: TextBlock) void {
    self.text[self.text_count] = text;
    self.text_count += 1;
}

pub inline fn addString(self: *Primatives, string: []const u8) []u8 {
    const slice = self.string_buffer[self.string_count .. self.string_count + string.len];
    @memcpy(slice, string);
    self.string_count += string.len;
    return slice;
}

pub fn logPrimatives(self: *const Primatives) void {
    var i: usize = 0;
    while (i < self.text_count) {
        std.debug.print("{any}\n", .{self.text[i]});
        i += 1;
    }

    i = 0;
    while (i < self.rectangle_count) {
        std.debug.print("{any}\n", .{self.rectangles[i]});
        i += 1;
    }
}

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn black() Color {
        return Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }

    pub fn gray(brightness: u8) Color {
        return Color{ .r = brightness, .g = brightness, .b = brightness, .a = 255 };
    }

    pub fn white() Color {
        return Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    }
};

pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: Color,
};

pub const TextAlign = enum(u2) { Left, Right, Center };
pub const TextBreak = enum(u1) { Word, Letter };

pub const TextBlock = struct {
    x: f32,
    y: f32,
    width: f32,
    text_align: TextAlign,
    text_break: TextBreak,
    font_id: u32,
    color: Color,
    text: []const u8,
};

pub const ClipRectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    rectangle_range_start: usize,
    rectangle_range_end: usize,
    text_range_start: usize,
    text_range_end: usize,
};
