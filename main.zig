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

const utils = @import("utils.zig");
const Extents = utils.Extents;
const InputEventInfo = utils.InputEventInfo;

const FlexStrip = @import("layouts/FlexStrip.zig");
const Scroll = @import("elements/Scroll.zig");
const Frame = @import("layouts/Frame.zig");
const Grid = @import("layouts/Grid.zig");
const Slider = @import("elements/Slider.zig");
const Dropdown = @import("elements/Dropdown.zig");
const Button = @import("elements/Button.zig");
const TextInput = @import("elements/TextInput.zig");
const InputCreateInfo = TextInput.InputCreateInfo;
const Element = DebugUI.Element;

const MeaninglessText = struct {
    text: []const u8,
    more_text: ?[]const u8,
};

const TestGUIHandles = struct {
    selected: u32,
    hello_button: MeaninglessText,
    hello_button2: MeaninglessText,
    edit_text: [256]u8,
    edit_text_len: u32,
    slider_value: f32,
    slider_value2: f32,
    some_object: SomeObject,
};

const GUISchema = struct {
    elements: []Element,
};

const SomeObject = struct {
    position_x: f32,
    position_y: f32,
    size: f32,
    name: [32:0]u8,
    state: enum(u32) {
        Flying,
        Swimming,
        Eating,
        Walking,
        Running,
    },
};

pub fn generate_gui(comptime T: type, object: *T, ui: *DebugUI, font_backend: anytype, x: f32, y: f32, width: f32, height: f32) void {
    const info = @typeInfo(T);
    const name = @typeName(T);

    Frame.start(ui, x, y);
    FlexStrip.start(ui, Extents{
        .width = width,
        .height = height,
    }, FlexStrip.Direction.Column, true);
    Scroll.start(ui, "12203");

    switch (info) {
        .Struct => |s| {
            inline for (s.fields) |field| {
                Grid.start(ui, Extents{ .height = 60, .width = width }, 3, 1);

                const field_info = @typeInfo(field.type);
                var id: [field.name.len + name.len + 2]u8 = undefined;
                @memcpy(id[0..name.len], name);
                @memcpy(id[name.len .. name.len + field.name.len], field.name);
                id[name.len + field.name.len] = 'L';
                id[name.len + field.name.len + 1] = 0;

                Grid.position(ui, 0, 0, 1, 1);
                _ = Button.create(ui, font_backend, field.name, null, @ptrCast(&id));

                id[name.len + field.name.len] = 0;

                Grid.position(ui, 1, 0, 2, 1);

                switch (field_info) {
                    .Float => {
                        TextInput.create(ui, font_backend, InputCreateInfo{
                            .number = .{
                                .start = 0.0,
                                .value = &@field(object, field.name),
                                .end = 100.0,
                            },
                        }, @ptrCast(&id));
                    },
                    .Array => |a| {
                        const array_type = @typeInfo(a.child);

                        if (array_type == .Int and a.sentinel != null and @as(*const u8, @ptrCast(a.sentinel)).* == 0 and array_type.Int.bits == 8 and array_type.Int.signedness == .unsigned) {
                            const field_ref = &@field(object, field.name);
                            var text_size: u32 = @intCast(std.mem.span(@as([*:0]const u8, @ptrCast(field_ref))).len);

                            TextInput.create(ui, font_backend, InputCreateInfo{
                                .character = .{
                                    .text = field_ref,
                                    .text_size = &text_size,
                                },
                            }, @ptrCast(&id));

                            field_ref[text_size] = 0;
                        }
                    },
                    .Enum => |e| {
                        //if ()
                        const names = names: {
                            var names: [e.fields.len][]const u8 = undefined;

                            inline for (e.fields, 0..) |enum_field, i| {
                                names[i] = enum_field.name;
                            }

                            break :names names;
                        };

                        Dropdown.create(ui, font_backend, Dropdown.CreateInfo{
                            .selected = @as(*u32, @ptrCast(&@field(object, field.name))),
                            .options = &names,
                            .tooltips = &names,
                        }, @ptrCast(&id));
                    },
                    else => {},
                }

                Grid.end(ui);
            }
        },
        else => {},
    }

    Scroll.end(ui, Scroll.Mode.Smooth, "12203");
    FlexStrip.end(ui);
    Frame.end(ui);
}

const App = struct {
    sdl2_backend: SDL2Backend,
    debug_ui: DebugUI,
    test_gui_handles: TestGUIHandles,
    show_middle_row: bool,
    window_size: [2]f32,

    pub fn create() !App {
        var app: App = undefined;

        app.window_size[0] = 1200;
        app.window_size[1] = 900;

        app.debug_ui = DebugUI.init();
        app.sdl2_backend = try SDL2Backend.create(app.window_size[0], app.window_size[1]);

        app.test_gui_handles.selected = 0;

        app.test_gui_handles.hello_button = MeaninglessText{
            .text = "Hello, World!",
            .more_text = "This is the world!",
        };

        app.test_gui_handles.hello_button2 = MeaninglessText{
            .text = "Hello, World!",
            .more_text = "This is the world!",
        };

        app.test_gui_handles.some_object = SomeObject{
            .name = ("SomeObject" ++ "\x00" ** 22).*,
            .position_x = 0,
            .position_y = 0,
            .state = .Walking,
            .size = 0,
        };

        const text = "hi";
        @memcpy(app.test_gui_handles.edit_text[0..text.len], text);
        app.test_gui_handles.edit_text_len = text.len;

        app.show_middle_row = false;

        app.test_gui_handles.slider_value = 5.0;
        app.test_gui_handles.slider_value2 = 5.0;

        return app;
    }

    fn ui(self: *App, events: *const InputEventInfo) void {
        DebugUI.start(&self.debug_ui, Extents{
            .width = self.window_size[0],
            .height = self.window_size[1],
        }, events);

        generate_gui(SomeObject, &self.test_gui_handles.some_object, &self.debug_ui, self.sdl2_backend, 425, 20, 450, 200);

        {
            Frame.start(&self.debug_ui, 20, 630);
            FlexStrip.start(&self.debug_ui, Extents{
                .width = 700,
                .height = 50,
            }, FlexStrip.Direction.Row, true);
            Scroll.start(&self.debug_ui, "12333203");

            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3223413");
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3324241");
            Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", "3242322");
            _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3232441");

            Scroll.end(&self.debug_ui, Scroll.Mode.Smooth, "12333203");
            FlexStrip.end(&self.debug_ui);
            Frame.end(&self.debug_ui);
        }

        {
            Frame.start(&self.debug_ui, 20, 20);

            FlexStrip.start(&self.debug_ui, Extents{
                .width = 400,
                .height = 500,
            }, FlexStrip.Direction.Column, true);

            Scroll.start(&self.debug_ui, "1203");

            Grid.start(&self.debug_ui, Extents{
                .width = 400,
                .height = 800,
            }, 2, 6);

            Grid.position(&self.debug_ui, 0, 0, 1, 1);
            TextInput.create(&self.debug_ui, self.sdl2_backend, InputCreateInfo{
                .character = .{
                    .text = &self.test_gui_handles.edit_text,
                    .text_size = &self.test_gui_handles.edit_text_len,
                },
            }, "3290");

            Grid.position(&self.debug_ui, 1, 0, 1, 1);
            if (Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button2.text, self.test_gui_handles.hello_button2.more_text, "3294")) {
                self.show_middle_row = !self.show_middle_row;
            }

            if (self.show_middle_row) {
                Grid.position(&self.debug_ui, 0, 2, 2, 1);

                FlexStrip.start(&self.debug_ui, Extents{
                    .width = 700,
                    .height = 50,
                }, FlexStrip.Direction.Row, false);
                Scroll.start(&self.debug_ui, "123203");

                TextInput.create(&self.debug_ui, self.sdl2_backend, InputCreateInfo{ .number = .{
                    .value = &self.test_gui_handles.slider_value2,
                    .start = 5,
                    .end = 20,
                } }, "322341");
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3324241");
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", "324222");
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3232441");

                Scroll.end(&self.debug_ui, Scroll.Mode.Smooth, "123203");
                FlexStrip.end(&self.debug_ui);

                Grid.position(&self.debug_ui, 0, 1, 2, 1);
                Grid.start(&self.debug_ui, Extents{
                    .width = 100,
                    .height = 30,
                }, 3, 1);

                Grid.position(&self.debug_ui, 0, 0, 1, 1);

                _ = Dropdown.create(&self.debug_ui, self.sdl2_backend, Dropdown.CreateInfo{
                    .selected = &self.test_gui_handles.selected,
                    .options = &[_][]const u8{ "food", "drinks" },
                    .tooltips = &[_][]const u8{ "food is a superpower it makes you not hungry", "drinks are great cuz water yk?" },
                }, "122");

                Grid.position(&self.debug_ui, 1, 0, 1, 1);
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "32324");

                Grid.position(&self.debug_ui, 2, 0, 1, 1);
                _ = Button.create(&self.debug_ui, self.sdl2_backend, self.test_gui_handles.hello_button.text, self.test_gui_handles.hello_button.more_text, "3241");

                Grid.end(&self.debug_ui);
            } else {
                Grid.position(&self.debug_ui, 0, 1, 2, 1);
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value, "Wowza", "1234");

                Grid.position(&self.debug_ui, 0, 2, 2, 1);
                Slider.create(&self.debug_ui, self.sdl2_backend, 5, 20, &self.test_gui_handles.slider_value2, "Wowzers", "4321");
            }

            Grid.end(&self.debug_ui);
            Scroll.end(&self.debug_ui, Scroll.Mode.Smooth, "1203");
            FlexStrip.end(&self.debug_ui);
            Frame.end(&self.debug_ui);
        }

        DebugUI.end(&self.debug_ui, self.sdl2_backend) catch unreachable;
    }

    pub fn run(self: *App) !void {
        const events = self.sdl2_backend.getEvents();

        if (events.flags.quit) {
            return error.Quit;
        }

        self.ui(&events);
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
