const std = @import("std");

const c = @cImport({
    @cInclude("stb_image_write.h");
});

const utils = @import("utils.zig");
const Bounds = utils.Bounds;

const Primatives = @import("Primatives.zig");
const Color = Primatives.Color;

const zm = @import("zm");

const Contour = []zm.Vec2f;
const Glyph = struct {
    bounds: Bounds,
    contours: []Contour,
};

const WIDTH = 512;
const HEIGHT = 512;

pub fn checkLineIntersectionWithHorizontalRay(p1: zm.Vec2f, p2: zm.Vec2f, height: f32) struct { intersected: bool, x: f32 } {
    const m = (p2[1] - p1[1]) / (p2[0] - p1[0]);
    const b = p1[1] - m * p1[0];
    const x = (height - b) / m;
    const y = m * x + b;

    return .{
        .within = y > p2[1] and y < p1[1] or y < p2[1] and y > p1[1],
        .x = x,
    };
}

pub const SDFFontGenerator = struct {
    //fn render_glyph(buffer: []Color, width: comptime_int, _: comptime_int, x_offset: u32, y_offset: u32, glyph_size: u32, glyph: *Glyph,) void {
    //    for (0..glyph_size) |y| {
    //        for (glyph.contours) |contour| {
    //            for (0..contour.len-1) |i| {
    //                const current = contour[i];
    //                const next = contour[i+1];

    //                checkLineIntersectionWithHorizontalRay(current, next, y);
    //            }
    //        }

    //        for (0..glyph_size) |x| {
    //            buffer[(y + y_offset) * width + x + x_offset];
    //        }
    //    }
    //}

    pub fn render(_: []Glyph) void {
        var pixelbuffer: [WIDTH * HEIGHT]Color = undefined;
        @memset(&pixelbuffer, Color.black());

        const glyph_size = 32;

        const glyph_rows = @divTrunc(HEIGHT, glyph_size);
        const glyph_cols = @divTrunc(WIDTH, glyph_size);

        for (0..glyph_rows) |y| {
            for (0..glyph_cols) |x| {
                const current_glyph = y * glyph_cols + x;
                std.debug.print("{} {} {}\n", .{ x, y, current_glyph });
                //            render_glyph(&pixelbuffer, WIDTH, HEIGHT, x * glyph_size, y * glyph_size, glyph_size, glyphs[current_glyph]);
            }
        }

        _ = c.stbi_write_png("./assets/out.png", WIDTH, HEIGHT, 4, &pixelbuffer, WIDTH * 4);
    }
};
