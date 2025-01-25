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

const SDL2Backend = @import("SDL2Backend.zig");
const DebugUI = @import("DebugUI.zig");
const Button = @import("Button.zig");
const Panel = @import("elements.zig").Panel;

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
    debug_ui: DebugUI,
    test_gui_handles: TestGUIHandles,

    pub fn create() !App {
        var app: App = undefined;

        app.debug_ui = DebugUI.init();
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
        const events = SDL2Backend.getEvents();

        if (events.flags.quit) {
            return error.Quit;
        }

        self.debug_ui.newFrame(events.mouse_x, events.mouse_y, events.flags.mouse_down, 1.0 / 60.0);
        self.debug_ui.primatives.clear();
        self.debug_ui.renderPanels();

        var stencil_creator = self.debug_ui.panels[self.test_gui_handles.main_panel].getStencilCreator();

        Button.create(&self.debug_ui, self.sdl2_backend, &stencil_creator, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text);
        Button.create(&self.debug_ui, self.sdl2_backend, &stencil_creator, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text);

        try self.sdl2_backend.renderSDL2(&self.debug_ui.primatives);

        c.SDL_Delay(@divTrunc(1000, 60));
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
