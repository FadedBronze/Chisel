pub const Panel = @import("Panel.zig");
pub const Grid = @import("Grid.zig");

pub const ElementLayout = union(enum) { panel: Panel, grid: Grid };
