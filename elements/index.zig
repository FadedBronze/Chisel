pub const Slider = @import("Slider.zig");
pub const Button = @import("Button.zig");

pub const Element = union { button: Button, slider: Slider };
