const std = @import("std");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

const Primatives = @import("Primatives.zig");
const utils = @import("utils.zig");
const InputEventInfo = utils.InputEventInfo;
const Bounds = utils.Bounds;
const SDFFontAtlas = @import("SDFFontAtlas.zig");
const OpenGL = @import("OpenGL.zig");

const zm = @import("zm");

const Renderer = @This();

shader: u32,
vao: u32,
vbo: u32,

pub const Vertex = packed struct {
    position: zm.Vec2f,
    color: Primatives.Color,
};

const VERTEX_SHADER_SOURCE = @embedFile("shaders/base/shader.vert");
const FRAGMENT_SHADER_SOURCE = @embedFile("shaders/base/shader.frag");

const VERTICES = 2048;
const INDICIES = 4096;

pub fn create(opengl: *OpenGL) !Renderer {
    const shader: u32 = try opengl.add_shader(Renderer.VERTEX_SHADER_SOURCE, Renderer.FRAGMENT_SHADER_SOURCE);

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
    c.glad_glBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Renderer.Vertex) * VERTICES, null, c.GL_DYNAMIC_DRAW);

    c.glad_glVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Renderer.Vertex), null);
    c.glad_glVertexAttribPointer.?(1, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE, @sizeOf(Renderer.Vertex), @ptrFromInt(@offsetOf(Renderer.Vertex, "color")));

    c.glad_glEnableVertexAttribArray.?(0);
    c.glad_glEnableVertexAttribArray.?(1);

    c.glad_glBindVertexArray.?(0);

    return Renderer{
        .vao = vao,
        .vbo = vbo,
        .shader = shader,
    };
}

pub fn renderRectangles(self: *Renderer, opengl: *OpenGL, rectangles: []const Primatives.Rectangle, current_clip_bounds: utils.Bounds) !void {
    var vertices: [VERTICES]Renderer.Vertex = undefined;
    var vertex_count: u32 = 0;

    var indices: [INDICIES]u32 = undefined;
    var index_count: u32 = 0;

    for (rectangles) |rectangle| {
        const bounds = (&Bounds{
            .height = rectangle.height,
            .width = rectangle.width,
            .x = rectangle.x,
            .y = rectangle.y,
        }).clip(&current_clip_bounds);

        opengl.renderQuad(
            &vertices,
            &vertex_count,
            &indices,
            &index_count,
            &bounds,
        );

        for (0..4) |i| {
            vertices[vertex_count - 4 + i].color = rectangle.color;
        }
    }

    // vao
    c.glad_glBindVertexArray.?(self.vao);
    c.glad_glBindBuffer.?(c.GL_ARRAY_BUFFER, self.vbo);
    c.glad_glBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * vertex_count, &vertices);
    c.glad_glBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * index_count, &indices);

    // shader
    c.glad_glUseProgram.?(self.shader);

    // draw
    c.glDrawElements(c.GL_TRIANGLES, @intCast(index_count), c.GL_UNSIGNED_INT, null);

    // unbind
    c.glad_glUseProgram.?(0);
    c.glad_glBindVertexArray.?(0);

    opengl.scroll_offset = .{ 0, 0 };
}

pub fn updateSize(self: *Renderer, width: f32, height: f32) void {
    self.window_size[0] = width;
    self.window_size[1] = height;
}
