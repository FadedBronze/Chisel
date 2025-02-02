const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});
const std = @import("std");

const DebugUI = @import("DebugUI.zig");
const Primatives = @import("Primatives.zig");

const SDL2Backend = @This();

pub const InputEventFlags = packed struct {
    mouse_down: bool,
    quit: bool,
    _padding: u5,
};

pub const InputEventInfo = struct {
    flags: InputEventFlags,
    mouse_x: f32,
    mouse_y: f32,
    scroll_x: f32,
    scroll_y: f32,
};

renderer: *c.SDL_Renderer,
sans24: *c.TTF_Font,
sans18: *c.TTF_Font,
sans12: *c.TTF_Font,

pub fn create() !SDL2Backend {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        return error.SDLInitFailed;
    }

    if (c.TTF_Init() == -1) return error.TTFInitFailed;
    const sans24 = c.TTF_OpenFont("assets/Sans.ttf", 24) orelse return error.FontLoadFailed;
    const sans18 = c.TTF_OpenFont("assets/Sans.ttf", 18) orelse return error.FontLoadFailed;
    const sans12 = c.TTF_OpenFont("assets/Sans.ttf", 12) orelse return error.FontLoadFailed;

    const window = c.SDL_CreateWindow("wowza", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 800, 800, 0);
    const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE) orelse return error.SDLInitFailed;

    return SDL2Backend{ .renderer = renderer, .sans24 = sans24, .sans18 = sans18, .sans12 = sans12 };
}

pub fn getEvents() InputEventInfo {
    var global_events: InputEventInfo = InputEventInfo{
        .flags = .{
            ._padding = 0,
            .mouse_down = false,
            .quit = false,
        },
        .mouse_x = 0,
        .mouse_y = 0,
        .scroll_x = 0,
        .scroll_y = 0,
    };

    var event: c.SDL_Event = undefined;

    while (c.SDL_PollEvent(&event) == 1) {
        switch (event.type) {
            c.SDL_QUIT => {
                global_events.flags.quit = true;
            },
            c.SDL_MOUSEBUTTONDOWN => {
                global_events.flags.mouse_down = true;
            },
            c.SDL_MOUSEWHEEL => {
                global_events.scroll_x += @floatFromInt(event.wheel.x);
                global_events.scroll_y += @floatFromInt(event.wheel.y);
            },
            else => {},
        }
    }

    var mouse_x: i32 = undefined;
    var mouse_y: i32 = undefined;

    const state = c.SDL_GetMouseState(&mouse_x, &mouse_y);

    if (!global_events.flags.mouse_down) {
        global_events.flags.mouse_down = state & 1 != 0;
    }

    global_events.mouse_x = @floatFromInt(mouse_x);
    global_events.mouse_y = @floatFromInt(mouse_y);

    return global_events;
}

pub fn getLineWidth(self: *const SDL2Backend, font_id: u32, text: []const u8) f32 {
    var width: i32 = undefined;
    if (c.TTF_SizeUTF8(self.getFont(font_id), @ptrCast(text), &width, null) == -1) return 0.0;
    return @floatFromInt(width);
}

fn getFont(self: *const SDL2Backend, font_id: u32) *c.TTF_Font {
    return switch (font_id) {
        0 => self.sans24,
        1 => self.sans18,
        2 => self.sans12,
        else => unreachable,
    };
}

pub fn getLineHeight(self: *const SDL2Backend, font_id: u32) f32 {
    return @floatFromInt(c.TTF_FontHeight(self.getFont(font_id)));
}

pub fn getRequiredLinesToFitLetters(self: *const SDL2Backend, font_id: u32, width: f32, text: []const u8) u32 {
    var count: i32 = 0;
    var current_count: u32 = 0;
    var lines: u32 = 0;

    while (current_count < text.len) {
        if (c.TTF_MeasureUTF8(self.getFont(font_id), @ptrCast(text[current_count..]), @intFromFloat(width), null, &count) == -1) return 0;
        current_count += @intCast(count);
        lines += 1;
    }

    return lines;
}

pub fn getRequiredLinesToFitWords(self: *const SDL2Backend, font_id: u32, width: f32, text: []const u8) u32 {
    var count: u32 = 0;
    var current_count: u32 = 0;
    var lines: u32 = 0;

    while (current_count < text.len) {
        if (c.TTF_MeasureUTF8(
            self.getFont(font_id),
            @ptrCast(text[current_count..]),
            @as(i32, @intFromFloat(width)) + 1,
            null,
            @ptrCast(&count),
        ) == -1) return 0;

        while (current_count + count != text.len and text[current_count + count] != ' ') {
            count -= 1;
        }

        current_count += count + 1;
        lines += 1;
    }

    return lines;
}

fn renderText(self: *const SDL2Backend, text_blocks: []const Primatives.TextBlock) !void {
    var i: usize = 0;

    while (i < text_blocks.len) {
        const text_block = text_blocks[i];
        var lines: u32 = 0;
        var current_count: u32 = 0;
        var text: [256]u8 = undefined;

        @memcpy((&text)[0..text_block.text.len], text_block.text);
        text[text_block.text.len] = '\x00';

        while (current_count < text_block.text.len) {
            var original_count: u32 = 0;

            if (c.TTF_MeasureUTF8(
                self.getFont(text_block.font_id),
                @ptrCast(text[current_count..]),
                @as(i32, @intFromFloat(text_block.width)) + 1,
                null,
                @ptrCast(&original_count),
            ) == -1) return error.MeasureFailed;

            var count = original_count;

            if (text_block.text_break == .Word and current_count + count < text_block.text.len) {
                while (count != 0 and text_block.text[current_count + count] != ' ') {
                    count -= 1;
                }

                if (count == 0) {
                    count = original_count;
                }
            }

            const temp = text[current_count + count];
            text[current_count + count] = '\x00';

            var extent: i32 = 0;

            if (c.TTF_MeasureText(
                self.getFont(text_block.font_id),
                @ptrCast(text[current_count..]),
                @as(i32, @intFromFloat(text_block.width)) + 1,
                &extent,
                null,
            ) == -1) return error.MeasureFailed;

            const surface: *c.SDL_Surface = c.TTF_RenderText_Solid(
                self.getFont(text_block.font_id),
                @ptrCast(text[current_count..]),
                @bitCast(text_block.color),
            );

            text[current_count + count] = temp;

            const output_texture: *c.SDL_Texture = c.SDL_CreateTextureFromSurface(self.renderer, surface) orelse return error.FailedCreateSurface;
            const line_height = c.TTF_FontHeight(self.getFont(text_block.font_id));
            const lines_f32: f32 = @floatFromInt(lines);
            const line_height_f32: f32 = @floatFromInt(line_height);

            const extra = @as(i32, @intFromFloat(text_block.width)) - extent;

            var x: i32 = if (text_block.text_align == .Center)
                @as(i32, @intFromFloat(text_block.x)) + @divTrunc(extra, 2)
            else if (text_block.text_align == .Right)
                @as(i32, @intFromFloat(text_block.x)) + extra
            else
                @intFromFloat(text_block.x);

            var texture_rect: c.SDL_Rect = undefined;
            texture_rect.w = extent;
            texture_rect.h = line_height;
            texture_rect.x = x;
            texture_rect.y = @intFromFloat(text_block.y + lines_f32 * line_height_f32);

            current_count += count + 1;
            lines += 1;

            _ = c.SDL_RenderCopy(self.renderer, output_texture, null, &texture_rect);

            c.SDL_FreeSurface(surface);
            c.SDL_DestroyTexture(output_texture);
        }

        i += 1;
    }
}

pub fn renderRectangles(self: *const SDL2Backend, rectangles: []const Primatives.Rectangle) !void {
    var vertices: [1024]c.SDL_Vertex = undefined;
    var indices: [1024 * 6]i32 = undefined;
    var vertex_count: usize = 0;
    var index_count: usize = 0;

    var i: usize = 0;
    while (i < rectangles.len) : (i += 1) {
        vertices[vertex_count] = c.SDL_Vertex{
            .position = .{
                .x = rectangles[i].x,
                .y = rectangles[i].y,
            },
            .color = @bitCast(rectangles[i].color),
            .tex_coord = .{
                .x = 0,
                .y = 0,
            },
        };

        vertices[vertex_count + 1] = c.SDL_Vertex{
            .position = .{
                .x = rectangles[i].x + rectangles[i].width,
                .y = rectangles[i].y,
            },
            .color = @bitCast(rectangles[i].color),
            .tex_coord = .{
                .x = 0,
                .y = 0,
            },
        };

        vertices[vertex_count + 2] = c.SDL_Vertex{
            .position = .{
                .x = rectangles[i].x + rectangles[i].width,
                .y = rectangles[i].y + rectangles[i].height,
            },
            .color = @bitCast(rectangles[i].color),
            .tex_coord = .{
                .x = 0,
                .y = 0,
            },
        };

        vertices[vertex_count + 3] = c.SDL_Vertex{
            .position = .{
                .x = rectangles[i].x,
                .y = rectangles[i].y + rectangles[i].height,
            },
            .color = @bitCast(rectangles[i].color),
            .tex_coord = .{
                .x = 0,
                .y = 0,
            },
        };

        indices[index_count] = @as(i32, @intCast(vertex_count));
        indices[index_count + 1] = @as(i32, @intCast(vertex_count)) + 1;
        indices[index_count + 2] = @as(i32, @intCast(vertex_count)) + 2;
        indices[index_count + 3] = @as(i32, @intCast(vertex_count)) + 0;
        indices[index_count + 4] = @as(i32, @intCast(vertex_count)) + 2;
        indices[index_count + 5] = @as(i32, @intCast(vertex_count)) + 3;

        vertex_count += 4;
        index_count += 6;
    }

    if (c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255) == -1) return error.SDLDrawFailed;
    if (c.SDL_RenderGeometry(self.renderer, null, &vertices, @intCast(vertex_count), &indices, @intCast(index_count)) == -1) return error.SDLDrawFailed;
}

pub fn renderSDL2(self: *const SDL2Backend, primatives: *const Primatives) !void {
    if (c.SDL_RenderClear(self.renderer) == -1) return error.SDLDrawFailed;

    if (primatives.clip_count == 0) {
        try self.renderRectangles(primatives.rectangles[0..primatives.rectangle_count]);
        try self.renderText(primatives.text[0..primatives.text_count]);

        c.SDL_RenderPresent(self.renderer);
        return;
    }

    try self.renderRectangles(primatives.rectangles[0..primatives.clip_stack[0].rectangle_count]);
    try self.renderText(primatives.text[0..primatives.clip_stack[0].text_count]);

    var clip_count: usize = 0;

    var active_clip_index_stack: [64]usize = undefined;
    var active_clip_index_stack_size: usize = 0;

    var i: usize = 0;
    while (i < primatives.clip_stack_size - 1) : (i += 1) {
        const current_clip = primatives.clip_stack[i];
        const next_clip = primatives.clip_stack[i + 1];

        if (current_clip.type == .Begin) {
            active_clip_index_stack[active_clip_index_stack_size] = clip_count;
            active_clip_index_stack_size += 1;
        } else {
            active_clip_index_stack_size -= 1;
        }

        if (next_clip.type == .Begin) {
            clip_count += 1;
        }

        if (active_clip_index_stack_size == 0) {
            _ = c.SDL_RenderSetClipRect(self.renderer, null);
        } else {
            _ = c.SDL_RenderSetClipRect(self.renderer, null);
            const rect = c.SDL_Rect{
                .x = @intFromFloat(primatives.clips[active_clip_index_stack[active_clip_index_stack_size - 1]].x),
                .y = @intFromFloat(primatives.clips[active_clip_index_stack[active_clip_index_stack_size - 1]].y),
                .w = @intFromFloat(primatives.clips[active_clip_index_stack[active_clip_index_stack_size - 1]].width),
                .h = @intFromFloat(primatives.clips[active_clip_index_stack[active_clip_index_stack_size - 1]].height),
            };

            _ = c.SDL_RenderSetClipRect(self.renderer, &rect);
        }

        try self.renderRectangles(primatives.rectangles[current_clip.rectangle_count..next_clip.rectangle_count]);
        try self.renderText(primatives.text[current_clip.text_count..next_clip.text_count]);
    }

    const last_rectangle = primatives.clip_stack[primatives.clip_stack_size - 1].rectangle_count;
    const last_text = primatives.clip_stack[primatives.clip_stack_size - 1].text_count;

    _ = c.SDL_RenderSetClipRect(self.renderer, null);

    try self.renderRectangles(primatives.rectangles[last_rectangle..primatives.rectangle_count]);
    try self.renderText(primatives.text[last_text..primatives.text_count]);

    c.SDL_RenderPresent(self.renderer);
}
