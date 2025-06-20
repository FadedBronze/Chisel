const DebugUI = @import("DebugUI.zig");
const Rectangle = @import("Primatives.zig").Rectangle;
const Color = @import("Primatives.zig").Color;
const std = @import("std");
const zm = @import("zm");

pub const InputEventFlags = packed struct {
    mouse_down: bool,
    quit: bool,
    _padding: u5,
};

pub const InputEventInfo = struct {
    flags: InputEventFlags,
    mouse_x: f32,
    mouse_y: f32,
    scroll_x: f32,
    scroll_y: f32,
    input_keys: [8]Key,
    input_keys_count: u32,
};

pub const Scancode = enum(u16) {
    SCANCODE_UNKNOWN = 0,
    SCANCODE_A = 4,
    SCANCODE_B = 5,
    SCANCODE_C = 6,
    SCANCODE_D = 7,
    SCANCODE_E = 8,
    SCANCODE_F = 9,
    SCANCODE_G = 10,
    SCANCODE_H = 11,
    SCANCODE_I = 12,
    SCANCODE_J = 13,
    SCANCODE_K = 14,
    SCANCODE_L = 15,
    SCANCODE_M = 16,
    SCANCODE_N = 17,
    SCANCODE_O = 18,
    SCANCODE_P = 19,
    SCANCODE_Q = 20,
    SCANCODE_R = 21,
    SCANCODE_S = 22,
    SCANCODE_T = 23,
    SCANCODE_U = 24,
    SCANCODE_V = 25,
    SCANCODE_W = 26,
    SCANCODE_X = 27,
    SCANCODE_Y = 28,
    SCANCODE_Z = 29,
    SCANCODE_1 = 30,
    SCANCODE_2 = 31,
    SCANCODE_3 = 32,
    SCANCODE_4 = 33,
    SCANCODE_5 = 34,
    SCANCODE_6 = 35,
    SCANCODE_7 = 36,
    SCANCODE_8 = 37,
    SCANCODE_9 = 38,
    SCANCODE_0 = 39,
    SCANCODE_RETURN = 40,
    SCANCODE_ESCAPE = 41,
    SCANCODE_BACKSPACE = 42,
    SCANCODE_TAB = 43,
    SCANCODE_SPACE = 44,
    SCANCODE_MINUS = 45,
    SCANCODE_EQUALS = 46,
    SCANCODE_LEFTBRACKET = 47,
    SCANCODE_RIGHTBRACKET = 48,
    SCANCODE_BACKSLASH = 49,
    SCANCODE_NONUSHASH = 50,
    SCANCODE_SEMICOLON = 51,
    SCANCODE_APOSTROPHE = 52,
    SCANCODE_GRAVE = 53,
    SCANCODE_COMMA = 54,
    SCANCODE_PERIOD = 55,
    SCANCODE_SLASH = 56,
    SCANCODE_CAPSLOCK = 57,
    SCANCODE_F1 = 58,
    SCANCODE_F2 = 59,
    SCANCODE_F3 = 60,
    SCANCODE_F4 = 61,
    SCANCODE_F5 = 62,
    SCANCODE_F6 = 63,
    SCANCODE_F7 = 64,
    SCANCODE_F8 = 65,
    SCANCODE_F9 = 66,
    SCANCODE_F10 = 67,
    SCANCODE_F11 = 68,
    SCANCODE_F12 = 69,
    SCANCODE_PRINTSCREEN = 70,
    SCANCODE_SCROLLLOCK = 71,
    SCANCODE_PAUSE = 72,
    SCANCODE_INSERT = 73,
    SCANCODE_HOME = 74,
    SCANCODE_PAGEUP = 75,
    SCANCODE_DELETE = 76,
    SCANCODE_END = 77,
    SCANCODE_PAGEDOWN = 78,
    SCANCODE_RIGHT = 79,
    SCANCODE_LEFT = 80,
    SCANCODE_DOWN = 81,
    SCANCODE_UP = 82,
    SCANCODE_NUMLOCKCLEAR = 83,
    SCANCODE_KP_DIVIDE = 84,
    SCANCODE_KP_MULTIPLY = 85,
    SCANCODE_KP_MINUS = 86,
    SCANCODE_KP_PLUS = 87,
    SCANCODE_KP_ENTER = 88,
    SCANCODE_KP_1 = 89,
    SCANCODE_KP_2 = 90,
    SCANCODE_KP_3 = 91,
    SCANCODE_KP_4 = 92,
    SCANCODE_KP_5 = 93,
    SCANCODE_KP_6 = 94,
    SCANCODE_KP_7 = 95,
    SCANCODE_KP_8 = 96,
    SCANCODE_KP_9 = 97,
    SCANCODE_KP_0 = 98,
    SCANCODE_KP_PERIOD = 99,
    SCANCODE_NONUSBACKSLASH = 100,
    SCANCODE_APPLICATION = 101,
    SCANCODE_POWER = 102,
    SCANCODE_KP_EQUALS = 103,
    SCANCODE_F13 = 104,
    SCANCODE_F14 = 105,
    SCANCODE_F15 = 106,
    SCANCODE_F16 = 107,
    SCANCODE_F17 = 108,
    SCANCODE_F18 = 109,
    SCANCODE_F19 = 110,
    SCANCODE_F20 = 111,
    SCANCODE_F21 = 112,
    SCANCODE_F22 = 113,
    SCANCODE_F23 = 114,
    SCANCODE_F24 = 115,
    SCANCODE_EXECUTE = 116,
    SCANCODE_HELP = 117,
    SCANCODE_MENU = 118,
    SCANCODE_SELECT = 119,
    SCANCODE_STOP = 120,
    SCANCODE_AGAIN = 121,
    SCANCODE_UNDO = 122,
    SCANCODE_CUT = 123,
    SCANCODE_COPY = 124,
    SCANCODE_PASTE = 125,
    SCANCODE_FIND = 126,
    SCANCODE_MUTE = 127,
    SCANCODE_VOLUMEUP = 128,
    SCANCODE_VOLUMEDOWN = 129,
    SCANCODE_KP_COMMA = 133,
    SCANCODE_KP_EQUALSAS400 = 134,
    SCANCODE_INTERNATIONAL1 = 135,
    SCANCODE_INTERNATIONAL2 = 136,
    SCANCODE_INTERNATIONAL3 = 137,
    SCANCODE_INTERNATIONAL4 = 138,
    SCANCODE_INTERNATIONAL5 = 139,
    SCANCODE_INTERNATIONAL6 = 140,
    SCANCODE_INTERNATIONAL7 = 141,
    SCANCODE_INTERNATIONAL8 = 142,
    SCANCODE_INTERNATIONAL9 = 143,
    SCANCODE_LANG1 = 144,
    SCANCODE_LANG2 = 145,
    SCANCODE_LANG3 = 146,
    SCANCODE_LANG4 = 147,
    SCANCODE_LANG5 = 148,
    SCANCODE_LANG6 = 149,
    SCANCODE_LANG7 = 150,
    SCANCODE_LANG8 = 151,
    SCANCODE_LANG9 = 152,
    SCANCODE_ALTERASE = 153,
    SCANCODE_SYSREQ = 154,
    SCANCODE_CANCEL = 155,
    SCANCODE_CLEAR = 156,
    SCANCODE_PRIOR = 157,
    SCANCODE_RETURN2 = 158,
    SCANCODE_SEPARATOR = 159,
    SCANCODE_OUT = 160,
    SCANCODE_OPER = 161,
    SCANCODE_CLEARAGAIN = 162,
    SCANCODE_CRSEL = 163,
    SCANCODE_EXSEL = 164,
    SCANCODE_KP_00 = 176,
    SCANCODE_KP_000 = 177,
    SCANCODE_THOUSANDSSEPARATOR = 178,
    SCANCODE_DECIMALSEPARATOR = 179,
    SCANCODE_CURRENCYUNIT = 180,
    SCANCODE_CURRENCYSUBUNIT = 181,
    SCANCODE_KP_LEFTPAREN = 182,
    SCANCODE_KP_RIGHTPAREN = 183,
    SCANCODE_KP_LEFTBRACE = 184,
    SCANCODE_KP_RIGHTBRACE = 185,
    SCANCODE_KP_TAB = 186,
    SCANCODE_KP_BACKSPACE = 187,
    SCANCODE_KP_A = 188,
    SCANCODE_KP_B = 189,
    SCANCODE_KP_C = 190,
    SCANCODE_KP_D = 191,
    SCANCODE_KP_E = 192,
    SCANCODE_KP_F = 193,
    SCANCODE_KP_XOR = 194,
    SCANCODE_KP_POWER = 195,
    SCANCODE_KP_PERCENT = 196,
    SCANCODE_KP_LESS = 197,
    SCANCODE_KP_GREATER = 198,
    SCANCODE_KP_AMPERSAND = 199,
    SCANCODE_KP_DBLAMPERSAND = 200,
    SCANCODE_KP_VERTICALBAR = 201,
    SCANCODE_KP_DBLVERTICALBAR = 202,
    SCANCODE_KP_COLON = 203,
    SCANCODE_KP_HASH = 204,
    SCANCODE_KP_SPACE = 205,
    SCANCODE_KP_AT = 206,
    SCANCODE_KP_EXCLAM = 207,
    SCANCODE_KP_MEMSTORE = 208,
    SCANCODE_KP_MEMRECALL = 209,
    SCANCODE_KP_MEMCLEAR = 210,
    SCANCODE_KP_MEMADD = 211,
    SCANCODE_KP_MEMSUBTRACT = 212,
    SCANCODE_KP_MEMMULTIPLY = 213,
    SCANCODE_KP_MEMDIVIDE = 214,
    SCANCODE_KP_PLUSMINUS = 215,
    SCANCODE_KP_CLEAR = 216,
    SCANCODE_KP_CLEARENTRY = 217,
    SCANCODE_KP_BINARY = 218,
    SCANCODE_KP_OCTAL = 219,
    SCANCODE_KP_DECIMAL = 220,
    SCANCODE_KP_HEXADECIMAL = 221,
    SCANCODE_LCTRL = 224,
    SCANCODE_LSHIFT = 225,
    SCANCODE_LALT = 226,
    SCANCODE_LGUI = 227,
    SCANCODE_RCTRL = 228,
    SCANCODE_RSHIFT = 229,
    SCANCODE_RALT = 230,
    SCANCODE_RGUI = 231,
    SCANCODE_MODE = 257,
    SCANCODE_AUDIONEXT = 258,
    SCANCODE_AUDIOPREV = 259,
    SCANCODE_AUDIOSTOP = 260,
    SCANCODE_AUDIOPLAY = 261,
    SCANCODE_AUDIOMUTE = 262,
    SCANCODE_MEDIASELECT = 263,
    SCANCODE_WWW = 264,
    SCANCODE_MAIL = 265,
    SCANCODE_CALCULATOR = 266,
    SCANCODE_COMPUTER = 267,
    SCANCODE_AC_SEARCH = 268,
    SCANCODE_AC_HOME = 269,
    SCANCODE_AC_BACK = 270,
    SCANCODE_AC_FORWARD = 271,
    SCANCODE_AC_STOP = 272,
    SCANCODE_AC_REFRESH = 273,
    SCANCODE_AC_BOOKMARKS = 274,
    SCANCODE_BRIGHTNESSDOWN = 275,
    SCANCODE_BRIGHTNESSUP = 276,
    SCANCODE_DISPLAYSWITCH = 277,
    SCANCODE_KBDILLUMTOGGLE = 278,
    SCANCODE_KBDILLUMDOWN = 279,
    SCANCODE_KBDILLUMUP = 280,
    SCANCODE_EJECT = 281,
    SCANCODE_SLEEP = 282,
    SCANCODE_APP1 = 283,
    SCANCODE_APP2 = 284,
    SCANCODE_AUDIOREWIND = 285,
    SCANCODE_AUDIOFASTFORWARD = 286,
    SCANCODE_SOFTLEFT = 287,
    SCANCODE_SOFTRIGHT = 288,
    SCANCODE_CALL = 289,
    SCANCODE_ENDCALL = 290,
    NUM_SCANCODES = 512,
};

pub const Key = packed struct {
    pressType: enum(u16) { DOWN, UP },
    value: Scancode,
};

pub const Bounds = struct {
    x: f32,
    y: f32,
    height: f32,
    width: f32,

    pub fn clip(self: *const Bounds, outer: *const Bounds) Bounds {
        var clipped = self.*;

        if (clipped.x < outer.x) {
            clipped.width -= (outer.x - clipped.x);
            clipped.x = outer.x;
        }

        const self_right = clipped.x + clipped.width;
        const outer_right = outer.x + outer.width;
        if (self_right > outer_right) {
            clipped.width -= (self_right - outer_right);
        }

        if (clipped.y < outer.y) {
            clipped.height -= (outer.y - clipped.y);
            clipped.y = outer.y;
        }

        const self_bottom = clipped.y + clipped.height;
        const outer_bottom = outer.y + outer.height;
        if (self_bottom > outer_bottom) {
            clipped.height -= (self_bottom - outer_bottom);
        }

        clipped.width = @max(clipped.width, 0);
        clipped.height = @max(clipped.height, 0);

        return clipped;
    }

    pub fn equals(self: *const Bounds, other: *const Bounds) bool {
        return std.math.approxEqRel(f32, self.x, other.x, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.y, other.y, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.width, other.width, std.math.floatEps(f32) * 3.0) and
            std.math.approxEqRel(f32, self.height, other.height, std.math.floatEps(f32) * 3.0);
    }

    pub fn min_bounds() Bounds {
        return Bounds{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };
    }

    pub fn max_bounds() Bounds {
        return Bounds{
            .x = std.math.floatMin(f32),
            .y = std.math.floatMin(f32),
            .width = std.math.floatMax(f32),
            .height = std.math.floatMax(f32),
        };
    }
};

pub const Extents = packed struct {
    width: f32,
    height: f32,
};

pub const Point = zm.Vec2f;
