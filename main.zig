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
const elements = @import("elements/index.zig");
const layouts = @import("layouts/index.zig");

const Bounds = @import("utils.zig").Bounds;

const Button = elements.Button;
const Slider = elements.Slider;
const Grid = layouts.Grid;
const Panel = layouts.Panel;

const MeaninglessText = struct {
    text: []const u8,
    more_text: ?[]const u8,
};

const TestGUIHandles = struct {
    hello_button: MeaninglessText,
    hello_button2: MeaninglessText,
    slider_value: f32,
    slider_value2: f32,
};

const App = struct {
    sdl2_backend: SDL2Backend,
    debug_ui: DebugUI,
    test_gui_handles: TestGUIHandles,
    show_middle_row: bool,

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

        app.show_middle_row = false;

        app.test_gui_handles.slider_value = 5.0;
        app.test_gui_handles.slider_value2 = 5.0;

        return app;
    }

    pub fn run(self: *App) !void {
        const events = SDL2Backend.getEvents();

        if (events.flags.quit) {
            return error.Quit;
        }

        self.debug_ui.newFrame(events.mouse_x, events.mouse_y, events.flags.mouse_down, 1.0 / 60.0);
        self.debug_ui.primatives.clear();

        Panel.start(&self.debug_ui, Bounds{
            .x = 20,
            .y = 20,
            .width = 300,
            .height = 600,
        });

        Grid.start(&self.debug_ui, Bounds{
            .x = 0,
            .y = 0,
            .width = 290,
            .height = 290,
        }, 2, 3);

        Grid.position(&self.debug_ui, 0, 0, 1, 1);
        _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3290);

        Grid.position(&self.debug_ui, 1, 0, 1, 1);
        if (Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text, 3294)) {
            self.show_middle_row = !self.show_middle_row;
        }

        if (self.show_middle_row) {
            Grid.position(&self.debug_ui, 0, 1, 2, 1);
            Grid.start(&self.debug_ui, Bounds{
                .x = 0,
                .y = 0,
                .width = 100,
                .height = 30,
            }, 3, 1);

            Grid.position(&self.debug_ui, 0, 0, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 122);

            Grid.position(&self.debug_ui, 1, 0, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 32324);

            Grid.position(&self.debug_ui, 2, 0, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3241);

            Grid.end(&self.debug_ui);

            Grid.position(&self.debug_ui, 1, 2, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text, 8790);

            Grid.position(&self.debug_ui, 0, 2, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text, 8732);
        } else {
            Grid.position(&self.debug_ui, 0, 1, 2, 1);
            Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value, "Wowza", 1234);

            Grid.position(&self.debug_ui, 0, 2, 2, 1);
            Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", 4321);
        }

        Grid.end(&self.debug_ui);

        Panel.end(&self.debug_ui);

        Panel.start(&self.debug_ui, Bounds{
            .x = 470,
            .y = 20,
            .width = 300,
            .height = 600,
        });
        _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 322341);
        _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3232441);
        _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3324241);
        Panel.end(&self.debug_ui);

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
