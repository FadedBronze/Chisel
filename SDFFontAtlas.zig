const c = @cImport({
    @cInclude("freetype/freetype.h");
    @cInclude("stb_image_write.h");
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const utils = @import("utils.zig");
const std = @import("std");
const zm = @import("zm");

const OpenGL = @import("OpenGL.zig");
const Primatives = @import("Primatives.zig");

const SDFFontAtlas = @This();

const FONTS = [_][]const u8{
    "./assets/fonts/Sans.ttf",
};

pub fn getFontId(name: []const u8) !u32 {
    for (FONTS, 0..) |font, i| {
        if (std.mem.containsAtLeast(u8, font, 1, name)) {
            return @intCast(i);
        }
    }
    return error.NotFound;
}

pub const Vertex = struct {
    position: zm.Vec2f,
    texCoords: zm.Vec2f,
};

const Glyph = packed struct {
    advance_width: u16,
    lsb: i16,
    baseline_offset: i16,
    width: u16,
    height: u16,
    tex_x: u16,
    tex_y: u16,
    _padding: u16,
};

const VERTICES = 2048;
const INDICIES = 4096;

const CHARACTERS = [_]u8{
    '\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06', '\x07',
    '\x08', '\x09', '\x0A', '\x0B', '\x0C', '\x0D', '\x0E', '\x0F',
    '\x10', '\x11', '\x12', '\x13', '\x14', '\x15', '\x16', '\x17',
    '\x18', '\x19', '\x1A', '\x1B', '\x1C', '\x1D', '\x1E', '\x1F',
    ' ',    '!',    '"',    '#',    '$',    '%',    '&',    '\'',
    '(',    ')',    '*',    '+',    ',',    '-',    '.',    '/',
    '0',    '1',    '2',    '3',    '4',    '5',    '6',    '7',
    '8',    '9',    ':',    ';',    '<',    '=',    '>',    '?',
    '@',    'A',    'B',    'C',    'D',    'E',    'F',    'G',
    'H',    'I',    'J',    'K',    'L',    'M',    'N',    'O',
    'P',    'Q',    'R',    'S',    'T',    'U',    'V',    'W',
    'X',    'Y',    'Z',    '[',    '\\',   ']',    '^',    '_',
    '`',    'a',    'b',    'c',    'd',    'e',    'f',    'g',
    'h',    'i',    'j',    'k',    'l',    'm',    'n',    'o',
    'p',    'q',    'r',    's',    't',    'u',    'v',    'w',
    'x',    'y',    'z',    '{',    '|',    '}',    '~',    '\x7F',
};

const GLYPH_SIZE = 32;
const TOTAL_GLYPHS = CHARACTERS.len * FONTS.len;
const ATLAS_SIZE = (@as(comptime_int, @intFromFloat(@sqrt(@as(f32, @floatFromInt(TOTAL_GLYPHS)) * 2))) + 1) * GLYPH_SIZE;

glyph_list: [TOTAL_GLYPHS]Glyph,
shader: u32,
atlas_texture: u32,
vao: u32,
vbo: u32,
ebo: u32,

// simple shelf packing
pub fn initFontTexture(atlas_texture: *u32) ![TOTAL_GLYPHS]Glyph {
    var max_height: u16 = 0;
    var x_offset: u16 = 0;
    var y_offset: u16 = 0;
    var glyph_list: [TOTAL_GLYPHS]Glyph = undefined;

    // texture
    c.glad_glActiveTexture.?(c.GL_TEXTURE0);

    c.glGenTextures(1, atlas_texture);
    c.glBindTexture(c.GL_TEXTURE_2D, atlas_texture.*);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, ATLAS_SIZE, ATLAS_SIZE, 0, c.GL_RED, c.GL_UNSIGNED_BYTE, null);

    // font
    var free_type: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&free_type) != c.FT_Err_Ok) return error.FontLibLoadFailed;

    var faces: [FONTS.len]c.FT_Face = undefined;

    for (FONTS, 0..) |path, i| {
        if (c.FT_New_Face(free_type, @ptrCast(path), 0, &faces[i]) != c.FT_Err_Ok) return error.FontFaceCreateFailed;
    }

    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    for (0..FONTS.len) |i| {
        for (CHARACTERS, 0..) |char, j| {
            if (char <= 32 or char == 127) continue;

            const glyph_index = c.FT_Get_Char_Index(faces[i], char);

            if (c.FT_Set_Pixel_Sizes(faces[i], GLYPH_SIZE, GLYPH_SIZE) != c.FT_Err_Ok) return error.SetPixelSizeFailed;
            if (c.FT_Load_Glyph(faces[i], glyph_index, c.FT_LOAD_NO_HINTING) != c.FT_Err_Ok) return error.LoadFailed;
            if (c.FT_Render_Glyph(faces[i].*.glyph, c.FT_RENDER_MODE_SDF) != c.FT_Err_Ok) return error.RenderFailed;

            const bitmap = faces[i].*.glyph.*.bitmap;

            std.debug.assert(bitmap.width < ATLAS_SIZE);

            if (x_offset + bitmap.width > ATLAS_SIZE) {
                y_offset += max_height;
                x_offset = 0;
            }

            c.glTexSubImage2D(
                c.GL_TEXTURE_2D,
                0,
                x_offset,
                y_offset,
                @intCast(bitmap.width),
                @intCast(bitmap.rows),
                c.GL_RED,
                c.GL_UNSIGNED_BYTE,
                bitmap.buffer,
            );

            const height = faces[i].*.bbox.yMax - faces[i].*.bbox.yMin;

            glyph_list[i * CHARACTERS.len + j] = Glyph{
                .advance_width = @intCast(faces[i].*.glyph.*.metrics.horiAdvance),
                .baseline_offset = @intCast(faces[i].*.glyph.*.metrics.horiBearingY - faces[i].*.ascender + @divTrunc(height, 4)),
                .tex_x = x_offset,
                .tex_y = y_offset,
                .height = @intCast(bitmap.rows),
                .width = @intCast(bitmap.width),
                .lsb = @intCast(faces[i].*.glyph.*.metrics.horiBearingX),
                ._padding = 0,
            };

            max_height = @max(@as(u16, @intCast(bitmap.rows)), max_height);
            x_offset += @intCast(bitmap.width);
        }
    }

    return glyph_list;
}

pub fn create(opengl: *OpenGL) !SDFFontAtlas {
    const vertex_shader = @embedFile("shaders/sdf/shader.vert");
    const fragment_shader = @embedFile("shaders/sdf/shader.frag");

    var vao: u32 = undefined;
    c.glad_glGenVertexArrays.?(1, &vao);
    c.glad_glBindVertexArray.?(vao);

    var ebo: u32 = undefined;
    c.glad_glGenBuffers.?(1, &ebo);
    c.glad_glBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glad_glBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * INDICIES, null, c.GL_DYNAMIC_DRAW);

    var vbo: u32 = undefined;
    c.glad_glGenBuffers.?(1, &vbo);
    c.glad_glBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
    c.glad_glBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Vertex) * VERTICES, null, c.GL_DYNAMIC_DRAW);

    c.glad_glVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.glad_glVertexAttribPointer.?(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "texCoords")));

    c.glad_glEnableVertexAttribArray.?(0);
    c.glad_glEnableVertexAttribArray.?(1);

    // shader
    const shader = try opengl.add_shader(vertex_shader, fragment_shader);

    // font
    var atlas_texture: u32 = undefined;
    const glyph_list = try initFontTexture(&atlas_texture);

    // unbind
    c.glad_glBindVertexArray.?(0);

    return SDFFontAtlas{
        .shader = shader,
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .atlas_texture = atlas_texture,
        .glyph_list = glyph_list,
    };
}

fn getGlyph(atlas: *SDFFontAtlas, character_code: u16, font_id: u16) !Glyph {
    var charcode = character_code;

    if (character_code <= 32 or character_code == 128) charcode = '_';

    const index = font_id * CHARACTERS.len + charcode;

    if (index > TOTAL_GLYPHS) return error.OutOfRange;

    return atlas.glyph_list[index];
}

fn renderGlyph(
    opengl: *const OpenGL,
    vertices: []Vertex,
    indices: []u32,
    vertex_count: *u32,
    index_count: *u32,
    glyph: *const Glyph,
    scale_x: f32,
    scale_y: f32,
    x: f32,
    y: f32,
) !void {
    const width: f32 = @as(f32, @floatFromInt(glyph.width)) * scale_x;
    const height: f32 = @as(f32, @floatFromInt(glyph.height)) * scale_y;

    const baseline_offset = @as(f32, @floatFromInt(glyph.baseline_offset)) / 64.0 * scale_y;

    const tex_x = @as(f32, @floatFromInt(glyph.tex_x)) / ATLAS_SIZE;
    const tex_y = @as(f32, @floatFromInt(glyph.tex_y)) / ATLAS_SIZE;
    const tex_width = @as(f32, @floatFromInt(glyph.width)) / ATLAS_SIZE;
    const tex_height = @as(f32, @floatFromInt(glyph.height)) / ATLAS_SIZE;

    vertices[vertex_count.*] = Vertex{
        .texCoords = .{ tex_x, tex_y },
        .position = opengl.translateNDC(.{ x, y - baseline_offset }),
    };
    vertices[vertex_count.* + 1] = Vertex{
        .texCoords = .{ tex_x + tex_width, tex_y },
        .position = opengl.translateNDC(.{ x + width, y - baseline_offset }),
    };
    vertices[vertex_count.* + 2] = Vertex{
        .texCoords = .{ tex_x + tex_width, tex_y + tex_height },
        .position = opengl.translateNDC(.{ x + width, y + height - baseline_offset }),
    };
    vertices[vertex_count.* + 3] = Vertex{
        .texCoords = .{ tex_x, tex_y + tex_height },
        .position = opengl.translateNDC(.{ x, y + height - baseline_offset }),
    };

    indices[index_count.*] = vertex_count.*;
    indices[index_count.* + 1] = vertex_count.* + 1;
    indices[index_count.* + 2] = vertex_count.* + 2;

    indices[index_count.* + 3] = vertex_count.* + 2;
    indices[index_count.* + 4] = vertex_count.* + 3;
    indices[index_count.* + 5] = vertex_count.* + 0;

    vertex_count.* += 4;
    index_count.* += 6;
}

pub fn renderText(self: *SDFFontAtlas, opengl: *const OpenGL, text_blocks: []const Primatives.TextBlock) !void {
    var vertices: [VERTICES]Vertex = undefined;
    var vertex_count: u32 = 0;

    var indices: [INDICIES]u32 = undefined;
    var index_count: u32 = 0;

    for (text_blocks) |text_block| {
        const first_glyph = try self.getGlyph(text_block.text[0], @intCast(text_block.font_id));
        const scale_x: f32 = @as(f32, @floatFromInt(text_block.size)) / GLYPH_SIZE;
        const scale_y: f32 = @as(f32, @floatFromInt(text_block.size)) / GLYPH_SIZE;

        var last_lsb = @as(f32, @floatFromInt(first_glyph.lsb)) / 32 * scale_x;
        var offset = text_block.x - last_lsb;
        var y_offset = text_block.y;

        for (text_block.text) |char| {
            if (char == 0) continue;
            const glyph = try self.getGlyph(char, @intCast(text_block.font_id));

            const advance_width = @as(f32, @floatFromInt(glyph.advance_width)) / 64 * scale_x;

            if (offset + advance_width - text_block.x + last_lsb > text_block.width) {
                y_offset += GLYPH_SIZE;
                last_lsb = @as(f32, @floatFromInt(glyph.lsb)) / 32.0 * scale_x;
                offset = text_block.x - last_lsb;
            }

            try renderGlyph(opengl, &vertices, &indices, &vertex_count, &index_count, &glyph, scale_x, scale_y, offset, y_offset);
            offset += advance_width;
        }
    }

    // shader
    c.glad_glUseProgram.?(self.shader);

    // texture
    const location: c.GLint = c.glad_glGetUniformLocation.?(self.shader, "tex");
    c.glad_glUniform1i.?(location, 0);
    c.glBindTexture(c.GL_TEXTURE_2D, self.atlas_texture);

    // vao
    c.glad_glBindVertexArray.?(self.vao);
    c.glad_glBindBuffer.?(c.GL_ARRAY_BUFFER, self.vbo);
    c.glad_glBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);

    c.glad_glBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * vertex_count, &vertices);
    c.glad_glBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * index_count, &indices);

    // draw
    c.glDrawElements(c.GL_TRIANGLES, @intCast(index_count), c.GL_UNSIGNED_INT, null);

    // unbind
    c.glad_glUseProgram.?(0);
    c.glad_glBindVertexArray.?(0);
}
