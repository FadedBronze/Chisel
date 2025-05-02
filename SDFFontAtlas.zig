const c = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("stb_image_write.h");
    @cInclude("GL/glew.h");
    @cInclude("GLFW/glfw3.h");
});

const utils = @import("utils.zig");

const std = @import("std");

const OpenGL = @import("OpenGL.zig");

const SDFFontAtlas = @This();

const FONTS = [_][]const u8{
    "./assets/fonts/Sans.ttf",
};

pub const GlyphId = struct {
    characterCode: u32,
    fontId: u32,

    pub fn getId(name: []const u8, character: u32) !GlyphId {
        for (FONTS, 0..) |font, i| {
            if (std.mem.containsAtLeast(u8, font, 1, name)) {
                return GlyphId{
                    .fontId = @intCast(i),
                    .characterCode = character,
                };
            }
        }
        return error.NotFound;
    }
};

const GlyphAtlasRecord = struct {
    id: GlyphId,
    position: GlyphAtlasPosition,
    extents: GlyphExtents,
};

const GlyphExtents = struct {
    w: u16,
    h: u16,
};

const GlyphAtlasPosition = struct {
    x: u16,
    y: u16,
};

const zm = @import("zm");

pub const Vertex = struct {
    position: zm.Vec2f,
    texCoords: zm.Vec2f,
};

const GLYPH_SIZE = 32;
const ATLAS_SIDE_LENGTH = 96;
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
opengl: *OpenGL,
atlas_texture: u32,
free_type: c.FT_Library,
faces: [FONTS.len]c.FT_Face,
shader: u32,
vao: u32,

pub fn update_lru_glyph(self: *SDFFontAtlas, id: GlyphId) bool {
    var foundGlyphIndex: i64 = -1;
    var isTransfer: bool = false;

    for (0..MAX_GLYPHS) |i| {
        if (self.rendered_glyphs[i].id.characterCode == id.characterCode and
            self.rendered_glyphs[i].id.fontId == id.fontId)
        {
            foundGlyphIndex = @intCast(i);
            break;
        }
    }

    if (foundGlyphIndex == -1) {
        if (self.glyph_count < MAX_GLYPHS) {
            self.heapify_up(self.glyph_count);

            self.rendered_glyphs[0].id = id;
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

            self.heapify_up(victimIndex);
            self.rendered_glyphs[0].id = id;
            self.rendered_glyphs[0].position = prevPos;
            self.rendered_glyphs[0].extents = prevExtent;
        }
    } else {
        isTransfer = true;

        const foundIndex: usize = @intCast(foundGlyphIndex);
        const prevPos = self.rendered_glyphs[foundIndex].position;
        const prevExtent = self.rendered_glyphs[foundIndex].extents;

        self.heapify_up(foundIndex);
        self.rendered_glyphs[0].id = id;
        self.rendered_glyphs[0].position = prevPos;
        self.rendered_glyphs[0].extents = prevExtent;
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

    opengl.vertices = .{ .font = undefined };

    var vao: u32 = undefined;
    c.__glewGenVertexArrays.?(1, &vao);
    c.__glewBindVertexArray.?(vao);

    var ebo: u32 = undefined;
    c.__glewGenBuffers.?(1, &ebo);
    c.__glewBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.__glewBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * opengl.indices.len, null, c.GL_DYNAMIC_DRAW);

    var vbo: u32 = undefined;
    c.__glewGenBuffers.?(1, &vbo);
    c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Vertex) * opengl.vertices.font.len, null, c.GL_DYNAMIC_DRAW);

    c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), null);
    c.__glewVertexAttribPointer.?(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@offsetOf(Vertex, "texCoords")));

    c.__glewEnableVertexAttribArray.?(0);
    c.__glewEnableVertexAttribArray.?(1);

    const shader = try opengl.add_shader(vertex_shader, fragment_shader);

    var atlas_texture: u32 = undefined;

    c.__glewActiveTexture.?(c.GL_TEXTURE0);

    c.glGenTextures(1, &atlas_texture);

    c.glBindTexture(c.GL_TEXTURE_2D, atlas_texture);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, ATLAS_SIDE_LENGTH, ATLAS_SIDE_LENGTH, 0, c.GL_RED, c.GL_UNSIGNED_BYTE, null);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    var free_type: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&free_type) != c.FT_Err_Ok) return error.FontLibLoadFailed;

    var faces: [FONTS.len]c.FT_Face = undefined;

    for (FONTS, 0..) |path, i| {
        //std.debug.print("{}\n", .{c.FT_New_Face(free_type, @ptrCast(path), 0, &faces[i])});
        if (c.FT_New_Face(free_type, @ptrCast(path), 0, &faces[i]) != c.FT_Err_Ok) return error.FontFaceCreateFailed;
    }

    return SDFFontAtlas{
        .rendered_glyphs = undefined,
        .glyph_count = 0,
        .currentEviction = 0,
        .faces = faces,
        .atlas_texture = atlas_texture,
        .opengl = opengl,
        .free_type = free_type,
        .shader = shader,
        .vao = vao,
    };
}

pub fn drawCharacter(self: *SDFFontAtlas, id: GlyphId, position: zm.Vec2f) !void {
    const glyph = try self.getGlyph(id);

    const f32_x: f32 = @floatFromInt(glyph.position.x);
    const f32_y: f32 = @floatFromInt(glyph.position.y);
    const f32_width: f32 = @floatFromInt(glyph.extents.w);
    const f32_height: f32 = @floatFromInt(glyph.extents.h);

    const quad: utils.Bounds = .{
        .x = position[0],
        .y = position[1],
        .width = f32_width,
        .height = f32_height,
    };

    self.opengl.renderQuad(
        &self.opengl.vertices.font,
        &self.opengl.vertex_count,
        &self.opengl.indices,
        &self.opengl.index_count,
        &quad,
    );

    self.opengl.vertices.font[self.opengl.vertex_count - 4].texCoords = zm.Vec2f{ f32_x / ATLAS_SIDE_LENGTH, f32_y / ATLAS_SIDE_LENGTH };
    self.opengl.vertices.font[self.opengl.vertex_count - 4 + 1].texCoords = zm.Vec2f{ (f32_x + f32_width) / ATLAS_SIDE_LENGTH, f32_y / ATLAS_SIDE_LENGTH };
    self.opengl.vertices.font[self.opengl.vertex_count - 4 + 2].texCoords = zm.Vec2f{ (f32_x + f32_width) / ATLAS_SIDE_LENGTH, (f32_y + f32_height) / ATLAS_SIDE_LENGTH };
    self.opengl.vertices.font[self.opengl.vertex_count - 4 + 3].texCoords = zm.Vec2f{ f32_x / ATLAS_SIDE_LENGTH, (f32_y + f32_height) / ATLAS_SIDE_LENGTH };

    for (self.opengl.vertices.font[self.opengl.vertex_count - 4 .. self.opengl.vertex_count]) |vertex| {
        std.debug.print("{any}\n", .{vertex});
    }

    std.debug.print("\n", .{});

    c.glBindTexture(c.GL_TEXTURE_2D, self.atlas_texture);
    c.__glewUseProgram.?(self.shader);
    c.__glewActiveTexture.?(c.GL_TEXTURE0);
    const location: c.GLint = c.__glewGetUniformLocation.?(self.shader, "tex");
    c.__glewUniform1i.?(location, 0);

    c.__glewBindVertexArray.?(self.vao);
    c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * self.opengl.vertex_count, &self.opengl.vertices.font);
    c.__glewBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * self.opengl.index_count, &self.opengl.indices);

    c.glDrawElements(c.GL_TRIANGLES, @intCast(self.opengl.index_count), c.GL_UNSIGNED_INT, null);

    c.glfwSwapBuffers(@ptrCast(self.opengl.window));
}

pub fn renderText(self: *SDFFontAtlas) !void {
    self.opengl.vertices = .{ .font = undefined };
    self.opengl.vertex_count = 0;
    self.opengl.index_count = 0;

    try self.drawCharacter(try GlyphId.getId("Sans", 'B'), .{ 120.0, 120.0 });

    //try self.drawCharacter(try GlyphId.getId("Sans", 'A'), .{ 60.0, 60.0 });

    //try self.drawCharacter(try GlyphId.getId("Sans", 'C'), .{ 60.0, 120.0 });

    //try self.drawCharacter(try GlyphId.getId("Sans", 'D'), .{ 120.0, 60.0 });
}

// untested
pub fn getGlyph(self: *SDFFontAtlas, id: GlyphId) !GlyphAtlasRecord {
    const isTransfer = self.update_lru_glyph(id);
    const glyph: *GlyphAtlasRecord = &self.rendered_glyphs[0];

    // pixels already be in the atlas otherwise have to place
    if (!isTransfer) {
        const font_face = self.faces[id.fontId];

        const letter = c.FT_Get_Char_Index(font_face, id.characterCode);

        if (c.FT_Set_Pixel_Sizes(font_face, 64, 64) != c.FT_Err_Ok) return error.SetPixelSizeFailed;
        if (c.FT_Load_Glyph(font_face, letter, c.FT_LOAD_NO_HINTING) != c.FT_Err_Ok) return error.LoadFailed;
        if (c.FT_Render_Glyph(font_face.*.glyph, c.FT_RENDER_MODE_SDF) != c.FT_Err_Ok) return error.RenderFailed;

        const bmp: *c.FT_Bitmap = &font_face.*.glyph.*.bitmap;

        c.__glewActiveTexture.?(c.GL_TEXTURE0);

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
    }

    return glyph.*;
}
