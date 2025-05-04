const c = @cImport({
    @cInclude("GL/glew.h");
    @cInclude("GLFW/glfw3.h");
});

const OpenGL = @import("./OpenGL.zig");
const OpenGLBackend = @This();
const InputEventInfo = @import("utils.zig").InputEventInfo;
const Primatives = @import("Primatives.zig");
const utils = @import("utils.zig");
const Bounds = utils.Bounds;

opengl: *OpenGL,

pub fn create(opengl: *OpenGL, width: f32, height: f32) !OpenGLBackend {
    try opengl.init(width, height);

    return OpenGLBackend{
        .opengl = opengl,
    };
}

pub fn getEvents(backend: *OpenGLBackend) InputEventInfo {
    c.glfwPollEvents();

    return InputEventInfo{
        .flags = .{
            .quit = c.glfwWindowShouldClose(backend.opengl.window) == c.GLFW_TRUE,
            .mouse_down = backend.opengl.mouse_down,
            ._padding = 0,
        },
        .mouse_x = backend.opengl.mouse_position[0],
        .mouse_y = backend.opengl.mouse_position[1],
        .scroll_x = backend.opengl.scroll_offset[0],
        .scroll_y = backend.opengl.scroll_offset[1],
        .input_keys = undefined,
        .input_keys_count = 0,
    };
}

pub fn render(backend: *OpenGLBackend, primatives: *const Primatives) !void {
    //try backend.opengl.renderer.renderRectangles(backend.opengl, primatives);
    try backend.opengl.atlas.renderText(primatives.text[0..primatives.text_count]);
}

pub fn updateSize(self: *OpenGLBackend, width: f32, height: f32) void {
    self.opengl.window_size[0] = width;
    self.opengl.window_size[1] = height;
}

pub fn getRequiredLinesToFitWords(self: *const OpenGLBackend, font_id: u32, width: f32, text: []const u8) u32 {
    return self.opengl.atlas.getRequiredLinesToFitWords(font_id, width, text);
}

pub fn getRequiredLinesToFitLetters(self: *const OpenGLBackend, font_id: u32, width: f32, text: []const u8) u32 {
    return self.opengl.atlas.getRequiredLinesToFitLetters(font_id, width, text);
}

pub fn getLineHeight(self: *const OpenGLBackend, font_id: u32) f32 {
    return self.opengl.atlas.getLineHeight(font_id);
}

pub fn getLineWidth(self: *const OpenGLBackend, font_id: u32, text: []const u8) f32 {
    return self.opengl.atlas.getLineWidth(font_id, text);
}
