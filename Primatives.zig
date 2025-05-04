const std = @import("std");

const Primatives = @This();
const Bounds = @import("utils.zig").Bounds;

pub const MAX_RECTANGLES = 1024;
pub const MAX_TEXT = 1024;
const MAX_CHARS = 1024;
const MAX_CLIPS = 128;

rectangles: [MAX_RECTANGLES]Rectangle,
rectangle_count: usize,
defer_rectangles_offset: usize,

string_buffer: [MAX_CHARS]u8,
string_count: usize,

text: [MAX_TEXT]TextBlock,
text_count: usize,
defer_text_offset: usize,

prev_clips: [MAX_CLIPS / 2]Bounds,
prev_clip_count: usize,

clips: [MAX_CLIPS]Clip,
clip_count: usize,

finished_clip: bool,

pub fn init() Primatives {
    return Primatives{
        .rectangle_count = 0,
        .rectangles = undefined,
        .text_count = 0,
        .text = undefined,
        .string_buffer = undefined,
        .string_count = 0,
        .prev_clips = undefined,
        .prev_clip_count = 0,
        .clips = undefined,
        .clip_count = 0,
        .finished_clip = true,
        .defer_rectangles_offset = MAX_RECTANGLES,
        .defer_text_offset = MAX_TEXT,
    };
}

pub inline fn start_clip(self: *Primatives, x: f32, y: f32, width: f32, height: f32) void {
    if (!self.finished_clip) {
        self.clips[self.clip_count - 1].rectangles_end = self.rectangle_count;
        self.clips[self.clip_count - 1].text_end = self.text_count;
    } else if (self.prev_clip_count > 0) {
        const new_bounds = self.prev_clips[self.prev_clip_count - 1];

        self.clips[self.clip_count].bounds = new_bounds;
        self.clips[self.clip_count].rectangles_start = self.clips[self.clip_count - 1].rectangles_end;
        self.clips[self.clip_count].text_start = self.clips[self.clip_count - 1].text_end;
        self.clips[self.clip_count].rectangles_end = self.rectangle_count;
        self.clips[self.clip_count].text_end = self.text_count;
        self.clip_count += 1;
    }

    const new_bounds = Bounds{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };

    if (self.prev_clip_count > 0) {
        const clipped_bounds = new_bounds.clip(&self.prev_clips[self.prev_clip_count - 1]);
        self.clips[self.clip_count].bounds = clipped_bounds;
        self.prev_clips[self.prev_clip_count] = clipped_bounds;
    } else {
        self.clips[self.clip_count].bounds = new_bounds;
        self.prev_clips[0] = new_bounds;
    }

    self.prev_clip_count += 1;
    self.clips[self.clip_count].rectangles_start = self.rectangle_count;
    self.clips[self.clip_count].text_start = self.text_count;
    self.clip_count += 1;

    self.finished_clip = false;
}

pub inline fn end_clip(self: *Primatives) void {
    std.debug.assert(self.prev_clip_count > 0);

    if (self.finished_clip) {
        const new_bounds = self.prev_clips[self.prev_clip_count - 1];

        self.clips[self.clip_count].bounds = new_bounds;
        self.clips[self.clip_count].rectangles_start = self.clips[self.clip_count - 1].rectangles_end;
        self.clips[self.clip_count].text_start = self.clips[self.clip_count - 1].text_end;
        self.clip_count += 1;
    }

    self.clips[self.clip_count - 1].rectangles_end = self.rectangle_count;
    self.clips[self.clip_count - 1].text_end = self.text_count;
    self.prev_clip_count -= 1;
    self.finished_clip = true;
}

pub inline fn clear(self: *Primatives) void {
    self.rectangle_count = 0;
    self.text_count = 0;
    self.string_count = 0;
    self.clip_count = 0;
    self.defer_rectangles_offset = MAX_RECTANGLES;
    self.defer_text_offset = MAX_TEXT;
}

pub inline fn addRectangle(self: *Primatives, rectangle: Rectangle) void {
    self.rectangles[self.rectangle_count] = rectangle;
    self.rectangle_count += 1;
}

pub inline fn addText(self: *Primatives, text: TextBlock) void {
    self.text[self.text_count] = text;
    self.text_count += 1;
}

pub inline fn deferAddRectangle(self: *Primatives, rectangle: Rectangle) void {
    self.defer_rectangles_offset -= 1;
    self.rectangles[self.defer_rectangles_offset] = rectangle;
}

pub inline fn deferAddText(self: *Primatives, text: TextBlock) void {
    self.defer_text_offset -= 1;
    self.text[self.defer_text_offset] = text;
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
    size: u16,
    text_align: TextAlign,
    text_break: TextBreak,
    font_id: u32,
    color: Color,
    text: []const u8,
};

pub const Clip = struct {
    bounds: Bounds,
    text_start: usize,
    text_end: usize,
    rectangles_start: usize,
    rectangles_end: usize,
};
