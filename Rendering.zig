const std = @import("std");

const c = @cImport({
    @cInclude("GL/glew.h");
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

pub const Vertex = packed struct {
    position: zm.Vec2f,
    color: Primatives.Color,
};

const VERTEX_SHADER_SOURCE = @embedFile("shaders/base/shader.vert");
const FRAGMENT_SHADER_SOURCE = @embedFile("shaders/base/shader.frag");

pub fn create(opengl: *OpenGL) !Renderer {
    const shader: u32 = try opengl.add_shader(Renderer.VERTEX_SHADER_SOURCE, Renderer.FRAGMENT_SHADER_SOURCE);

    opengl.vertices = .{ .ui = undefined };

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
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Renderer.Vertex) * opengl.vertices.ui.len, null, c.GL_DYNAMIC_DRAW);

    c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Renderer.Vertex), null);
    c.__glewVertexAttribPointer.?(1, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE, @sizeOf(Renderer.Vertex), @ptrFromInt(@offsetOf(Renderer.Vertex, "color")));

    c.__glewEnableVertexAttribArray.?(0);
    c.__glewEnableVertexAttribArray.?(1);

    return Renderer{
        .vao = vao,
        .shader = shader,
    };
}

pub fn renderQuad(opengl: *OpenGL, bounds: *const Bounds, color: Primatives.Color) void {
    opengl.renderQuad(
        &opengl.vertices.ui,
        &opengl.vertex_count,
        &opengl.indices,
        &opengl.index_count,
        bounds,
    );

    for (0..4) |i| {
        opengl.vertices.ui[opengl.vertex_count - 4 + i].color = color;
    }
}

pub fn renderRectangles(self: *Renderer, opengl: *OpenGL, primatives: *const Primatives) !void {
    c.glClearColor(0.0, 0.0, 0.0, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    opengl.vertices = .{ .ui = undefined };
    opengl.vertex_count = 0;
    opengl.index_count = 0;
    opengl.indices = undefined;

    var i: usize = 0;
    while (i < primatives.clip_count) : (i += 1) {
        const rectangle_start = primatives.clips[i].rectangles_start;
        const rectangle_end = primatives.clips[i].rectangles_end;
        //const text_start = primatives.clips[i].text_start;
        //const text_end = primatives.clips[i].text_end;

        for (primatives.rectangles[rectangle_start..rectangle_end]) |rectangle| {
            const bounds = (&Bounds{
                .height = rectangle.height,
                .width = rectangle.width,
                .x = rectangle.x,
                .y = rectangle.y,
            }).clip(&primatives.clips[i].bounds);

            renderQuad(opengl, &bounds, rectangle.color);
        }
    }

    for (primatives.rectangles[primatives.defer_rectangles_offset..primatives.rectangles.len]) |rectangle| {
        const bounds = Bounds{
            .height = rectangle.height,
            .width = rectangle.width,
            .x = rectangle.x,
            .y = rectangle.y,
        };

        renderQuad(opengl, &bounds, rectangle.color);
    }

    c.__glewBindVertexArray.?(self.vao);
    c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * opengl.vertex_count, &opengl.vertices.ui);
    c.__glewBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * opengl.index_count, &opengl.indices);

    c.__glewUseProgram.?(self.shader);

    c.glDrawElements(c.GL_TRIANGLES, @intCast(opengl.index_count), c.GL_UNSIGNED_INT, null);

    c.glfwSwapBuffers(opengl.window);

    opengl.scroll_offset = .{ 0, 0 };
}

pub fn updateSize(self: *Renderer, width: f32, height: f32) void {
    self.window_size[0] = width;
    self.window_size[1] = height;
}
