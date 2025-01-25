// ---- Game UI ------
// - place on screen somewhere (relative to corners & sides)
// - selectability (use arrow keys to select inputs)
// - non-nested menus & text with pages
// - sliders, buttons, tooltips
// - scrolling

// ---- Debug UI -----
// - recursive
// - dependant on data
// - input fields, checkboxes, buttons, dropdowns
// - inflexible layout
// - scrolling
// - docking
// - tooltips

const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const std = @import("std");

const Events = struct {
    flags: EventFlags,
    global: *const GlobalEvents,
};

const EventFlags = packed struct {
    mouse_over: bool,
    hover_enter: bool,
    hover_exit: bool,
    _padding: u5,
};

const GlobalEvents = struct {
    flags: GlobalEventFlags,
    mouse_x: f32,
    mouse_y: f32,
    last_mouse_x: f32,
    last_mouse_y: f32,
    delta_time: f32,

    pub fn create() GlobalEvents {
        return GlobalEvents{
            .flags = GlobalEventFlags{
                .last_mouse_held = false,
                .mouse_held = false,
                .queued_mouse_up = false,
                .quit = false,
                .mouse_down = false,
                .mouse_up = false,
                ._padding = 0,
            },
            .mouse_x = 0,
            .mouse_y = 0,
            .last_mouse_x = 0,
            .last_mouse_y = 0,
            .delta_time = 1.0 / 60.0,
        };
    }

    pub fn getEvents(self: *const GlobalEvents, stencil: *const PanelStencil, bounds: *const Bounds) ?Events {
        const hovering_now = stencil.x < self.mouse_x and self.mouse_x < stencil.x + bounds.width and
            stencil.y < self.mouse_y and self.mouse_y < stencil.y + bounds.height;

        if (!hovering_now) return null;

        const hovering_before = stencil.x < self.last_mouse_x and self.last_mouse_x < stencil.x + bounds.width and
            stencil.y < self.last_mouse_y and self.last_mouse_y < stencil.y + bounds.height;

        return Events{
            .flags = EventFlags{
                .hover_enter = !hovering_before and hovering_now,
                .hover_exit = hovering_before and !hovering_now,
                .mouse_over = hovering_now,
                ._padding = 0,
            },
            .global = self,
        };
    }
};

const GlobalEventFlags = packed struct {
    last_mouse_held: bool,
    mouse_held: bool,
    mouse_down: bool,
    mouse_up: bool,
    queued_mouse_up: bool,
    quit: bool,
    _padding: u2,
};

const SDL2Backend = struct {
    renderer: *c.SDL_Renderer,

    pub fn create() !SDL2Backend {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            return error.SDLInitFailed;
        }

        const window = c.SDL_CreateWindow("wowza", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 800, 800, 0);
        const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_SOFTWARE) orelse return error.SDLInitFailed;

        return SDL2Backend{
            .renderer = renderer,
        };
    }

    pub inline fn updateEvents(global_events: *GlobalEvents) void {
        if (global_events.flags.queued_mouse_up) {
            global_events.flags.mouse_held = false;
            global_events.flags.queued_mouse_up = false;
        }

        global_events.last_mouse_x = global_events.mouse_x;
        global_events.last_mouse_y = global_events.mouse_y;
        global_events.flags.last_mouse_held = global_events.flags.mouse_held;
    }

    pub fn getEvents(global_events: *GlobalEvents) !void {
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                c.SDL_QUIT => {
                    global_events.flags.quit = true;
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    global_events.flags.mouse_held = true;
                },
                c.SDL_MOUSEBUTTONUP => {
                    global_events.flags.queued_mouse_up = true;
                },
                else => {},
            }
        }

        var mouse_x: i32 = undefined;
        var mouse_y: i32 = undefined;

        _ = c.SDL_GetMouseState(&mouse_x, &mouse_y);

        global_events.mouse_x = @floatFromInt(mouse_x);
        global_events.mouse_y = @floatFromInt(mouse_y);

        global_events.flags.mouse_down = global_events.flags.mouse_held and !global_events.flags.last_mouse_held;
        global_events.flags.mouse_up = !global_events.flags.mouse_held and global_events.flags.last_mouse_held;
    }

    pub fn renderSDL2(self: *const SDL2Backend, ui: UI) !void {
        var vertices: [5096]c.SDL_Vertex = undefined;
        var indices: [5096 * 6]i32 = undefined;
        var vertex_count: usize = 0;
        var index_count: usize = 0;

        var i: usize = 0;
        while (i < ui.primatives.rectangle_count) : (i += 1) {
            vertices[vertex_count] = c.SDL_Vertex{
                .position = .{
                    .x = ui.primatives.rectangles[i].x,
                    .y = ui.primatives.rectangles[i].y,
                },
                .color = @bitCast(ui.primatives.rectangles[i].color),
                .tex_coord = .{
                    .x = 0,
                    .y = 0,
                },
            };

            vertices[vertex_count + 1] = c.SDL_Vertex{
                .position = .{
                    .x = ui.primatives.rectangles[i].x + ui.primatives.rectangles[i].width,
                    .y = ui.primatives.rectangles[i].y,
                },
                .color = @bitCast(ui.primatives.rectangles[i].color),
                .tex_coord = .{
                    .x = 0,
                    .y = 0,
                },
            };

            vertices[vertex_count + 2] = c.SDL_Vertex{
                .position = .{
                    .x = ui.primatives.rectangles[i].x + ui.primatives.rectangles[i].width,
                    .y = ui.primatives.rectangles[i].y + ui.primatives.rectangles[i].height,
                },
                .color = @bitCast(ui.primatives.rectangles[i].color),
                .tex_coord = .{
                    .x = 0,
                    .y = 0,
                },
            };

            vertices[vertex_count + 3] = c.SDL_Vertex{
                .position = .{
                    .x = ui.primatives.rectangles[i].x,
                    .y = ui.primatives.rectangles[i].y + ui.primatives.rectangles[i].height,
                },
                .color = @bitCast(ui.primatives.rectangles[i].color),
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
        if (c.SDL_RenderClear(self.renderer) == -1) return error.SDLDrawFailed;

        if (c.SDL_RenderGeometry(self.renderer, null, &vertices, @intCast(vertex_count), &indices, @intCast(index_count)) == -1) return error.SDLDrawFailed;

        c.SDL_RenderPresent(self.renderer);
    }
};

const MeaninglessText = struct {
    text: []const u8,
    more_text: ?[]const u8,
};

const TestGUIHandles = struct {
    hello_button: MeaninglessText,
    hello_button2: MeaninglessText,
    main_panel: u32,
};

const App = struct {
    sdl2_backend: SDL2Backend,
    debug_ui: UI,
    events: GlobalEvents,

    test_gui_handles: TestGUIHandles,

    buffer: [UI.getAllocationSize()]u8,
    fba: std.heap.FixedBufferAllocator,
    allocator: std.mem.Allocator,

    pub fn render_ui(self: *App) !void {
        self.debug_ui.renderPanels();
        var stencil_creator = self.debug_ui.panels[self.test_gui_handles.main_panel].getStencilCreator();

        Button.create(&self.debug_ui, &stencil_creator, &self.events, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text);
        Button.create(&self.debug_ui, &stencil_creator, &self.events, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text);
    }

    pub fn create() !App {
        var app: App = undefined;
        app.buffer = undefined;

        app.fba = std.heap.FixedBufferAllocator.init(&app.buffer);
        app.allocator = app.fba.allocator();

        app.events = GlobalEvents.create();

        app.debug_ui = try UI.init(app.allocator);
        app.sdl2_backend = try SDL2Backend.create();

        app.test_gui_handles.hello_button = MeaninglessText{
            .text = "Hello, World!",
            .more_text = "This is the world!",
        };

        app.test_gui_handles.hello_button2 = MeaninglessText{
            .text = "Hello, World!",
            .more_text = "This is the world!",
        };

        app.test_gui_handles.main_panel = app.debug_ui.addPanel(&Panel.create(20, 20, 300, 600));

        return app;
    }

    pub fn run(self: *App) !void {
        try SDL2Backend.getEvents(&self.events);

        if (self.events.flags.quit) {
            return error.Quit;
        }

        self.debug_ui.primatives.clear();

        try self.render_ui();

        SDL2Backend.updateEvents(&self.events);

        try self.sdl2_backend.renderSDL2(self.debug_ui);

        c.SDL_Delay(@divTrunc(1000, 60));
    }
};

const Button = struct {
    hover_duration: f32,

    const PADDING = 20;

    pub fn create(ui: *UI, stencil_creator: *PanelStencilCreator, global_events: *const GlobalEvents, text: []const u8, _: ?[]const u8) void {
        const bounds = Bounds{
            .width = stencil_creator.panel.width,
            .height = 24.0 + PADDING * 2,
        };

        const stencil = stencil_creator.getStencil(&bounds);

        const text_line = TextLine{
            .x = PADDING,
            .y = PADDING,
            .width = bounds.width,
            .text = text,
            .font_height = 24.0,
            .color = Color.white(),
        };

        const base = Rectangle{
            .x = stencil.x,
            .y = stencil.y,
            .width = bounds.width,
            .height = 24.0 + PADDING * 2,
            .color = Color.gray(100),
        };

        ui.primatives.addRectangles(&[_]Rectangle{base});
        ui.primatives.addTexts(&[_]TextLine{text_line});

        const events = global_events.getEvents(&stencil, &bounds) orelse return;

        if (events.flags.hover_enter) {
            ui.active_element.button = Button{
                .hover_duration = 0,
            };
        }

        const hover = Rectangle{
            .x = stencil.x,
            .y = stencil.y,
            .width = bounds.width,
            .height = 24.0 + PADDING * 2,
            .color = Color.gray(122),
        };

        if (events.global.flags.mouse_held and events.flags.mouse_over) {
            ui.primatives.addRectangles(&[_]Rectangle{hover});
        }

        const tooltip_base = Rectangle{
            .x = events.global.mouse_x,
            .y = events.global.mouse_y,
            .width = 120.0,
            .height = 12.0 + 5 * 2,
            .color = Color.gray(122),
        };

        if (events.flags.mouse_over) {
            ui.active_element.button.hover_duration += events.global.delta_time;
        } else {
            ui.active_element.button.hover_duration = 0;
        }

        if (ui.active_element.button.hover_duration > 1.0) {
            ui.active_element.button.hover_duration = @min(ui.active_element.button.hover_duration, 15.0);
            ui.primatives.addRectangles(&[_]Rectangle{tooltip_base});
        }
    }
};

const Color = packed struct {
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

const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    color: Color,
};

const TextLine = struct {
    x: f32,
    y: f32,
    width: f32,
    font_height: f32,
    color: Color,
    text: []const u8,
};

const PrimativesManager = struct {
    rectangles: []Rectangle,
    rectangle_count: usize,
    text: []TextLine,
    text_count: usize,

    pub inline fn clear(self: *PrimativesManager) void {
        self.rectangle_count = 0;
        self.text_count = 0;
    }

    pub inline fn addRectangles(self: *PrimativesManager, rectangles: []const Rectangle) void {
        @memcpy(self.rectangles[self.rectangle_count .. self.rectangle_count + rectangles.len], rectangles);
        self.rectangle_count += rectangles.len;
    }

    pub inline fn addTexts(self: *PrimativesManager, texts: []const TextLine) void {
        @memcpy(self.text[self.text_count .. self.text_count + texts.len], texts);
        self.text_count += texts.len;
    }

    pub fn log(self: *const PrimativesManager) void {
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
};

const Element = union(enum) { button: Button };

const UI = struct {
    panels: []Panel,
    panel_count: u32,
    active_element: Element,
    primatives: PrimativesManager,

    const MAX_PANELS = 64;
    const MAX_RECTANGLES = 1024;
    const MAX_TEXT_LINES = 1024;

    pub inline fn getAllocationSize() u32 {
        return @sizeOf(Panel) * MAX_PANELS + @sizeOf(Rectangle) * MAX_RECTANGLES + @sizeOf(TextLine) * (MAX_TEXT_LINES + 1);
    }

    pub fn init(allocator: std.mem.Allocator) !UI {
        const panels = try allocator.alloc(Panel, MAX_PANELS);
        const rectangles = try allocator.alloc(Rectangle, MAX_RECTANGLES);
        const text = try allocator.alloc(TextLine, MAX_TEXT_LINES);

        return UI{
            .panels = panels,
            .panel_count = 0,
            .active_element = undefined,
            .primatives = PrimativesManager{
                .rectangles = rectangles,
                .rectangle_count = 0,
                .text = text,
                .text_count = 0,
            },
        };
    }

    pub fn renderPanels(self: *UI) void {
        for (self.panels) |panel| {
            self.primatives.addRectangles(&[_]Rectangle{Rectangle{
                .color = Color.gray(50),
                .x = panel.x,
                .y = panel.y,
                .width = panel.width,
                .height = panel.height,
            }});
        }
    }

    pub fn addPanel(self: *UI, panel: *const Panel) u32 {
        self.panels[self.panel_count] = panel.*;
        self.panel_count += 1;
        return self.panel_count - 1;
    }
};

const Bounds = struct {
    height: f32,
    width: f32,
};

const PanelStencil = struct {
    x: f32,
    y: f32,
};

const PanelStencilCreator = struct {
    panel: *const Panel,
    height_used: f32,
    width_used: f32,
    max_height: f32,

    pub fn getStencil(self: *PanelStencilCreator, bounds: *const Bounds) PanelStencil {
        var offset_x = self.panel.x;
        var offset_y = self.panel.y;

        if (bounds.width < self.panel.width - self.width_used) {
            offset_x += self.width_used;
            offset_y += self.height_used;
            self.max_height = @max(self.max_height, bounds.height);
        } else {
            self.height_used += self.max_height;
            self.max_height = bounds.height;
            offset_x += 0;
            offset_y += self.height_used;
            self.width_used = bounds.width;
        }

        return PanelStencil{ .x = offset_x, .y = offset_y };
    }
};

const Panel = struct {
    x: f32,
    y: f32,
    height: f32,
    width: f32,

    pub fn create(x: f32, y: f32, width: f32, height: f32) Panel {
        return Panel{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    pub fn getStencilCreator(self: *const Panel) PanelStencilCreator {
        return PanelStencilCreator{
            .height_used = 0.0,
            .width_used = 0.0,
            .max_height = 0.0,
            .panel = self,
        };
    }
};

pub fn main() !void {
    var app = try App.create();
    var running = true;

    while (running) {
        app.run() catch |err| {
            if (err == error.Quit) running = false;
        };
    }
}
