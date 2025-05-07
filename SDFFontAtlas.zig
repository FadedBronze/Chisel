const c = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("stb_image_write.h");
    @cInclude("GL/glew.h");
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

const GlyphAtlasRecord = struct {
    position: GlyphAtlasPosition,
    extents: GlyphExtents,
    characterCode: u32,
    fontId: u32,
    baseline: i16,
    advanceWidth: u16,
};

const GlyphExtents = struct {
    w: u16,
    h: u16,
};

const GlyphAtlasPosition = struct {
    x: u16,
    y: u16,
};

pub const Vertex = struct {
    position: zm.Vec2f,
    texCoords: zm.Vec2f,
};

const VERTICES = 2048;
const INDICIES = 4096;

const GLYPH_SIZE = 32;
const ATLAS_SIDE_LENGTH = 256;
const GLYPHS_PER_EXTENT = ATLAS_SIDE_LENGTH / GLYPH_SIZE;

fn roundDownToPow2(n: u32) u32 {
    if (n == 0) return 0;
    return @as(u32, 1) << (31 - @clz(n));
}

const MAX_GLYPHS = roundDownToPow2(GLYPHS_PER_EXTENT * GLYPHS_PER_EXTENT) - 1;

//faces: []*c.FT_Face,
rendered_glyphs: [MAX_GLYPHS]GlyphAtlasRecord,
glyph_count: u16,
currentEviction: u16,
atlas_texture: u32,
free_type: c.FT_Library,
faces: [FONTS.len]c.FT_Face,
shader: u32,
vao: u32,

pub fn updateLruGlyph(self: *SDFFontAtlas, characterCode: u32, fontId: u32) bool {
    var foundGlyphIndex: i64 = -1;
    var isTransfer: bool = false;

    for (0..MAX_GLYPHS) |i| {
        if (self.rendered_glyphs[i].characterCode == characterCode and
            self.rendered_glyphs[i].fontId == fontId)
        {
            foundGlyphIndex = @intCast(i);
            break;
        }
    }

    if (foundGlyphIndex == -1) {
        if (self.glyph_count < MAX_GLYPHS) {
            self.heapify_up(self.glyph_count);

            self.rendered_glyphs[0].characterCode = characterCode;
            self.rendered_glyphs[0].fontId = fontId;
            self.rendered_glyphs[0].position.x = self.glyph_count % GLYPHS_PER_EXTENT;
            self.rendered_glyphs[0].position.y = self.glyph_count / GLYPHS_PER_EXTENT;

            self.glyph_count += 1;
        } else {
            if (self.currentEviction <= 1) {
                self.currentEviction = (MAX_GLYPHS + 1) / 2;
            } else {
                self.currentEviction -= 1;
            }

            const victimIndex = self.glyph_count - self.currentEviction;
            const prevPos = self.rendered_glyphs[victimIndex].position;
            const prevExtent = self.rendered_glyphs[victimIndex].extents;
            const prevBaseline = self.rendered_glyphs[victimIndex].baseline;
            const prevAdvanceWidth = self.rendered_glyphs[victimIndex].advanceWidth;

            self.heapify_up(victimIndex);
            self.rendered_glyphs[0].characterCode = characterCode;
            self.rendered_glyphs[0].fontId = fontId;
            self.rendered_glyphs[0].position = prevPos;
            self.rendered_glyphs[0].extents = prevExtent;
            self.rendered_glyphs[0].baseline = prevBaseline;
            self.rendered_glyphs[0].advanceWidth = prevAdvanceWidth;
        }
    } else {
        isTransfer = true;

        const foundIndex: usize = @intCast(foundGlyphIndex);
        const prevPos = self.rendered_glyphs[foundIndex].position;
        const prevExtent = self.rendered_glyphs[foundIndex].extents;
        const prevBaseline = self.rendered_glyphs[foundIndex].baseline;
        const prevAdvanceWidth = self.rendered_glyphs[foundIndex].advanceWidth;

        self.heapify_up(foundIndex);
        self.rendered_glyphs[0].characterCode = characterCode;
        self.rendered_glyphs[0].fontId = fontId;
        self.rendered_glyphs[0].position = prevPos;
        self.rendered_glyphs[0].extents = prevExtent;
        self.rendered_glyphs[0].baseline = prevBaseline;
        self.rendered_glyphs[0].advanceWidth = prevAdvanceWidth;
    }

    return isTransfer;
}

/// Takes a cell and replaces it with its parent and so on until reaching the root
fn heapify_up(self: *SDFFontAtlas, currentIdx: usize) void {
    if (currentIdx == 0) return;

    const nextIdx = if (currentIdx == 1) 0 else ((currentIdx - 1) / 2);

    const nextCharacter = self.rendered_glyphs[nextIdx];
    self.rendered_glyphs[currentIdx] = nextCharacter;

    if (nextIdx == 0) {
        return;
    }

    self.heapify_up(nextIdx);
}

pub fn create(opengl: *OpenGL) !SDFFontAtlas {
    const vertex_shader = @embedFile("shaders/sdf/shader.vert");
    const fragment_shader = @embedFile("shaders/sdf/shader.frag");

    var vao: u32 = undefined;
    c.__glewGenVertexArrays.?(1, &vao);
    c.__glewBindVertexArray.?(vao);

    var ebo: u32 = undefined;
    c.__glewGenBuffers.?(1, &ebo);
    c.__glewBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.__glewBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * INDICIES, null, c.GL_DYNAMIC_DRAW);

    var vbo: u32 = undefined;
    c.__glewGenBuffers.?(1, &vbo);
    c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Vertex) * VERTICES, null, c.GL_DYNAMIC_DRAW);

    c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.__glewVertexAttribPointer.?(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "texCoords")));

    c.__glewEnableVertexAttribArray.?(0);
    c.__glewEnableVertexAttribArray.?(1);

    // shader
    const shader = try opengl.add_shader(vertex_shader, fragment_shader);

    // texture
    var atlas_texture: u32 = undefined;
    c.__glewActiveTexture.?(c.GL_TEXTURE0);

    c.glGenTextures(1, &atlas_texture);
    c.glBindTexture(c.GL_TEXTURE_2D, atlas_texture);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, ATLAS_SIDE_LENGTH, ATLAS_SIDE_LENGTH, 0, c.GL_RED, c.GL_UNSIGNED_BYTE, null);

    // font
    var free_type: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&free_type) != c.FT_Err_Ok) return error.FontLibLoadFailed;

    var faces: [FONTS.len]c.FT_Face = undefined;

    for (FONTS, 0..) |path, i| {
        if (c.FT_New_Face(free_type, @ptrCast(path), 0, &faces[i]) != c.FT_Err_Ok) return error.FontFaceCreateFailed;
    }

    // unbind
    c.__glewBindVertexArray.?(0);

    return SDFFontAtlas{
        .rendered_glyphs = undefined,
        .glyph_count = 0,
        .currentEviction = 0,
        .faces = faces,
        .atlas_texture = atlas_texture,
        .free_type = free_type,
        .shader = shader,
        .vao = vao,
    };
}

pub fn drawCharacter(self: *SDFFontAtlas, opengl: *OpenGL, characterCode: u32, fontId: u32, position: zm.Vec2f, scale: u32, vertices: []Vertex, indices: []u32, vertex_count: *u32, index_count: *u32) !u32 {
    const glyph = try self.getGlyph(characterCode, fontId);

    const scaled_advance_width = @as(f32, @floatFromInt(glyph.advanceWidth)) / (GLYPH_SIZE * 64) * @as(f32, @floatFromInt(scale));

    if (characterCode == ' ') {
        return @intFromFloat(scaled_advance_width - 1);
    }

    const f32_x: f32 = @as(f32, @floatFromInt(glyph.position.x)) * GLYPH_SIZE;
    const f32_y: f32 = @as(f32, @floatFromInt(glyph.position.y)) * GLYPH_SIZE;
    const f32_width: f32 = @floatFromInt(glyph.extents.w);
    const f32_height: f32 = @floatFromInt(glyph.extents.h);

    const scaled_width = f32_width / GLYPH_SIZE * @as(f32, @floatFromInt(scale));
    const scaled_height = f32_height / GLYPH_SIZE * @as(f32, @floatFromInt(scale));
    const scaled_baseline = @as(f32, @floatFromInt(glyph.baseline)) / (GLYPH_SIZE * 64) * @as(f32, @floatFromInt(scale));

    const quad: utils.Bounds = .{
        .x = position[0],
        .y = position[1] - scaled_baseline,
        .width = scaled_width,
        .height = scaled_height,
    };

    opengl.renderQuad(
        @as([*]Vertex, @ptrCast(vertices)),
        vertex_count,
        @ptrCast(indices),
        index_count,
        &quad,
    );

    vertices[vertex_count.* - 4 + 0].texCoords = zm.Vec2f{ f32_x / ATLAS_SIDE_LENGTH, f32_y / ATLAS_SIDE_LENGTH };
    vertices[vertex_count.* - 4 + 1].texCoords = zm.Vec2f{ (f32_x + f32_width) / ATLAS_SIDE_LENGTH, f32_y / ATLAS_SIDE_LENGTH };
    vertices[vertex_count.* - 4 + 2].texCoords = zm.Vec2f{ (f32_x + f32_width) / ATLAS_SIDE_LENGTH, (f32_y + f32_height) / ATLAS_SIDE_LENGTH };
    vertices[vertex_count.* - 4 + 3].texCoords = zm.Vec2f{ f32_x / ATLAS_SIDE_LENGTH, (f32_y + f32_height) / ATLAS_SIDE_LENGTH };

    return @intFromFloat(scaled_advance_width);
}

pub fn getLineWidth(self: *const SDFFontAtlas, font_id: u32, text: []const u8) f32 {
    var width: f32 = 0;
    for (text) |char| {
        width += (self.getGlyph(char, font_id) catch continue).advanceWidth;
    }
    return width;
}

pub fn getLineHeight(self: *const SDFFontAtlas, font_id: u32) f32 {
    const bounds = self.faces[font_id].*.bbox;
    return @floatFromInt(bounds.yMax - bounds.yMin);
}

pub fn getRequiredLinesToFitLetters(self: *const SDFFontAtlas, font_id: u32, width: f32, text: []const u8) u32 {
    var lines: u32 = 0;
    var current_width: f32 = 0;

    for (text) |char| {
        const next_delta = (self.getGlyph(char, font_id) catch continue).advanceWidth;
        current_width += next_delta;

        if (current_width > width) {
            lines += 1;
            current_width = next_delta;
        }
    }

    return lines;
}

fn getCharactersThatFitOnLine(self: *const SDFFontAtlas, font_id: u32, width: f32, text: []const u8) u32 {
    var current_width: f32 = 0;
    var characters: u32 = 0;

    for (text) |char| {
        current_width += (self.getGlyph(char, font_id) catch continue).advanceWidth;
        characters += 1;

        if (current_width > width) {
            return characters - 1;
        }
    }

    return characters;
}

pub fn getRequiredLinesToFitWords(self: *const SDFFontAtlas, font_id: u32, width: f32, text: []const u8) u32 {
    var count: u32 = 0;
    var current_count: u32 = 0;
    var lines: u32 = 0;

    while (current_count < text.len) {
        self.getLineWidth(self, font_id, text);

        count = self.getCharactersThatFitOnLine(font_id, width + 1, text[current_count..]);

        while (current_count + count < text.len and text[current_count + count] != ' ') {
            count -= 1;
        }

        current_count += count + 1;
        lines += 1;
    }

    return lines;
}

pub fn renderText(self: *SDFFontAtlas, opengl: *OpenGL, text_blocks: []const Primatives.TextBlock) !void {
    var vertices: [VERTICES]Vertex = undefined;
    var vertex_count: u32 = 0;

    var indices: [INDICIES]u32 = undefined;
    var index_count: u32 = 0;

    var offset: f32 = 0;

    for (text_blocks) |text_block| {
        const font_id = text_block.font_id;

        offset += @floatFromInt(try self.drawCharacter(opengl, text_block.text[0], font_id, .{ 40.0, 40.0 }, text_block.size, &vertices, &indices, &vertex_count, &index_count));

        for (1..text_block.text.len) |i| {
            const char = text_block.text[i - 1];
            const next_char = text_block.text[i];

            const char_index = c.FT_Get_Char_Index(self.faces[font_id], char);
            const next_char_index = c.FT_Get_Char_Index(self.faces[font_id], next_char);

            var kerning: c.FT_Vector = undefined;

            if (c.FT_Get_Kerning(self.faces[font_id], char_index, next_char_index, c.FT_KERNING_DEFAULT, &kerning) != c.FT_Err_Ok) return error.KerningRequestFailed;
            const scaled_kerning: f32 = @as(f32, @floatFromInt(kerning.x)) / 64 * @as(f32, @floatFromInt(text_block.size));
            const scaled_kerning_y: f32 = @as(f32, @floatFromInt(kerning.y)) / 64 * @as(f32, @floatFromInt(text_block.size));

            offset += @floatFromInt(try self.drawCharacter(opengl, next_char, font_id, .{ 40.0 + offset + scaled_kerning, 40.0 + scaled_kerning_y }, text_block.size, &vertices, &indices, &vertex_count, &index_count));
        }
    }

    // shader
    c.__glewUseProgram.?(self.shader);

    // texture
    const location: c.GLint = c.__glewGetUniformLocation.?(self.shader, "tex");
    c.__glewUniform1i.?(location, 0);
    c.glBindTexture(c.GL_TEXTURE_2D, self.atlas_texture);

    // vao
    c.__glewBindVertexArray.?(self.vao);
    c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * vertex_count, &vertices);
    c.__glewBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * index_count, &indices);

    // draw
    c.glDrawElements(c.GL_TRIANGLES, @intCast(index_count), c.GL_UNSIGNED_INT, null);

    // unbind
    c.__glewUseProgram.?(0);
    c.__glewBindVertexArray.?(0);
}

pub fn getGlyph(self: *SDFFontAtlas, characterCode: u32, fontId: u32) !GlyphAtlasRecord {
    if (characterCode == ' ') {
        if (c.FT_Load_Glyph(self.faces[fontId], ' ', c.FT_LOAD_NO_HINTING) != c.FT_Err_Ok) return error.LoadFailed;
        const glyph = self.faces[fontId].*.glyph.*;

        return GlyphAtlasRecord{
            .advanceWidth = @intCast(glyph.metrics.horiAdvance),
            .baseline = 0,
            .extents = .{ .w = 0, .h = 0 },
            .fontId = fontId,
            .characterCode = characterCode,
            .position = .{ .x = std.math.maxInt(u16), .y = std.math.maxInt(u16) },
        };
    }

    const isTransfer = self.updateLruGlyph(characterCode, fontId);
    const glyph: *GlyphAtlasRecord = &self.rendered_glyphs[0];

    // pixels already be in the atlas otherwise have to place
    if (!isTransfer) {
        const font_face = self.faces[fontId];

        const letter = c.FT_Get_Char_Index(font_face, characterCode);

        if (c.FT_Set_Pixel_Sizes(font_face, GLYPH_SIZE, GLYPH_SIZE) != c.FT_Err_Ok) return error.SetPixelSizeFailed;
        if (c.FT_Load_Glyph(font_face, letter, c.FT_LOAD_NO_HINTING) != c.FT_Err_Ok) return error.LoadFailed;
        if (c.FT_Render_Glyph(font_face.*.glyph, c.FT_RENDER_MODE_SDF) != c.FT_Err_Ok) return error.RenderFailed;

        const bmp: *c.FT_Bitmap = &font_face.*.glyph.*.bitmap;

        //std.debug.print("{} {}\n", .{ bmp.rows, bmp.width });

        c.__glewActiveTexture.?(c.GL_TEXTURE0);

        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            @as(i32, @intCast(glyph.position.x * GLYPH_SIZE)),
            @as(i32, @intCast(glyph.position.y * GLYPH_SIZE)),
            @intCast(bmp.width),
            @intCast(bmp.rows),
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            bmp.buffer,
        );

        glyph.extents.w = @intCast(bmp.width);
        glyph.extents.h = @intCast(bmp.rows);
        // + font_face.*.glyph.*.bitmap_top * 64
        glyph.baseline = @intCast(font_face.*.glyph.*.metrics.horiBearingY - font_face.*.ascender);
        glyph.advanceWidth = @intCast(font_face.*.glyph.*.metrics.horiAdvance);
    }

    return glyph.*;
}
