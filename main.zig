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

const Extents = @import("utils.zig").Extents;

pub const FlexStrip = @import("layouts/FlexStrip.zig");
pub const Scroll = @import("elements/Scroll.zig");
pub const Frame = @import("layouts/Frame.zig");
pub const Grid = @import("layouts/Grid.zig");
pub const Slider = @import("elements/Slider.zig");
pub const Button = @import("elements/Button.zig");

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

    fn ui(self: *App) void {
        {
            //Frame.start(&self.debug_ui, 20, 630);
            //FlexStrip.start(&self.debug_ui, Extents{
            //    .width = 700,
            //    .height = 50,
            //}, FlexStrip.Direction.Row, true);
            //Scroll.start(&self.debug_ui, 123203);

            //_ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 322341);
            //_ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3324241);
            //Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", 324222);
            //_ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3232441);

            //Scroll.end(&self.debug_ui, 123203);
            //FlexStrip.end(&self.debug_ui);
            //Frame.end(&self.debug_ui);
        }

        {
            Frame.start(&self.debug_ui, 20, 20);

            FlexStrip.start(&self.debug_ui, Extents{
                .width = 400,
                .height = 400,
            }, FlexStrip.Direction.Column, true);

            Scroll.start(&self.debug_ui, 1203);

            Grid.start(&self.debug_ui, Extents{
                .width = 400,
                .height = 600,
            }, 2, 6);

            Grid.position(&self.debug_ui, 0, 0, 1, 1);
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3290);

            Grid.position(&self.debug_ui, 1, 0, 1, 1);
            if (Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text, 3294)) {
                self.show_middle_row = !self.show_middle_row;
            }

            if (self.show_middle_row) {
                Grid.position(&self.debug_ui, 0, 1, 2, 1);
                Grid.start(&self.debug_ui, Extents{
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

                Grid.position(&self.debug_ui, 0, 2, 2, 1);

                FlexStrip.start(&self.debug_ui, Extents{
                    .width = 700,
                    .height = 50,
                }, FlexStrip.Direction.Row, false);
                Scroll.start(&self.debug_ui, 123203);

                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 322341);
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3324241);
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", 324222);
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, 3232441);

                Scroll.end(&self.debug_ui, 123203);
                FlexStrip.end(&self.debug_ui);
            } else {
                Grid.position(&self.debug_ui, 0, 1, 2, 1);
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value, "Wowza", 1234);

                Grid.position(&self.debug_ui, 0, 2, 2, 1);
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", 4321);
            }

            Grid.end(&self.debug_ui);
            Scroll.end(&self.debug_ui, 1203);
            FlexStrip.end(&self.debug_ui);
            Frame.end(&self.debug_ui);
        }
    }

    pub fn run(self: *App) !void {
        const events = SDL2Backend.getEvents();

        if (events.flags.quit) {
            return error.Quit;
        }

        self.debug_ui.newFrame(events.mouse_x, events.mouse_y, events.scroll_x, events.scroll_y, events.flags.mouse_down, 1.0 / 60.0);
        self.debug_ui.primatives.clear();

        self.ui();

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
