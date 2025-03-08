const std = @import("std");

const c = @cImport({
    @cInclude("stb_image_write.h");
});

const utils = @import("utils.zig");
const Bounds = utils.Bounds;

const Primatives = @import("Primatives.zig");
const Color = Primatives.Color;

const zm = @import("zm");

pub const Contour = []zm.Vec2f;
pub const Glyph = []Contour;

const WIDTH = 512;
const HEIGHT = 512;

pub fn checkLineIntersectionWithHorizontalRay(p1: zm.Vec2f, p2: zm.Vec2f, height: f32) struct { intersected: bool, x: f32 } {
    const dir: zm.Vec2f = p2 - p1;
    const t: f32 = (height - p1[1]) / dir[1];

    return .{
        .intersected = t >= 0 and t <= 1,
        .x = p1[0] + t * dir[0],
    };
}

pub const SDFFontGenerator = struct {
    fn render_glyph(
        buffer: []Color,
        width: comptime_int,
        _: comptime_int,
        x_offset: u32,
        y_offset: u32,
        glyph_size: u32,
        glyph: *Glyph,
    ) void {
        const glyph_size_float: f32 = @floatFromInt(glyph_size);

        for (0..glyph_size) |y| {
            const MAX_INTERSECTIONS = 8;
            var intersections_buffer: [MAX_INTERSECTIONS]f32 = undefined;
            var intersections: []f32 = intersections_buffer[0..0];

            for (glyph.*) |contour| {
                var last: zm.Vec2f = zm.vec.scale(contour[contour.len - 1], glyph_size_float);

                for (0..contour.len - 1) |i| {
                    const current = zm.vec.scale(contour[i], glyph_size_float);
                    const intersection = checkLineIntersectionWithHorizontalRay(last, current, @floatFromInt(y));

                    if (intersection.intersected) {
                        intersections_buffer[intersections.len] = intersection.x;
                        intersections = intersections_buffer[0 .. intersections.len + 1];
                    }

                    last = current;
                }
            }

            for (0..intersections.len) |i| {
                for (i + 1..intersections.len) |j| {
                    if (intersections[i] > intersections[j]) {
                        const temp = intersections[i];
                        intersections[i] = intersections[j];
                        intersections[j] = temp;
                    }
                }
            }

            var current_intersections: u8 = 0;

            for (0..glyph_size) |x| {
                if (current_intersections < intersections.len and @as(f32, @floatFromInt(x)) > intersections[current_intersections]) {
                    current_intersections += 1;
                }

                if (current_intersections % 2 == 0) {
                    buffer[(y + y_offset) * width + x + x_offset] = Color.black();
                } else {
                    buffer[(y + y_offset) * width + x + x_offset] = Color.white();
                }
            }
        }
    }

    pub fn render(glyphs: []Glyph) void {
        var pixelbuffer: [WIDTH * HEIGHT]Color = undefined;
        @memset(&pixelbuffer, Color.black());

        const glyph_size = 256;

        const glyph_rows = @divTrunc(HEIGHT, glyph_size);
        const glyph_cols = @divTrunc(WIDTH, glyph_size);

        grid_render: for (0..glyph_rows) |y| {
            for (0..glyph_cols) |x| {
                const current_glyph: usize = y * glyph_cols + x;

                if (current_glyph >= glyphs.len) {
                    break :grid_render;
                }

                render_glyph(&pixelbuffer, WIDTH, HEIGHT, @intCast(x * glyph_size), @intCast(y * glyph_size), glyph_size, &glyphs[current_glyph]);
            }
        }

        _ = c.stbi_write_png("./assets/out.png", WIDTH, HEIGHT, 4, &pixelbuffer, WIDTH * 4);
    }
};
