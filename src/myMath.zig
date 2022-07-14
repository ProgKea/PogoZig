const root = @import("main.zig");

pub fn degreesToRadians(degree: f16) f16 {
    return degree * root.math.pi / 180;
}

pub fn getRotatedPoint(target_point: root.c.SDL_Point, rotation_point: root.c.SDL_Point, angle: f16) root.c.SDL_Point {
    const angle_in_radians = @as(f32, degreesToRadians(angle));
    root.std.debug.print("angle_in_radians: {d}\n", .{angle_in_radians});
    return root.c.SDL_Point {
        .x = @floatToInt(c_int, @intToFloat(f16, (target_point.x - rotation_point.x)) * (angle_in_radians) - @intToFloat(f16, (target_point.y - rotation_point.y)) * root.math.sin(angle_in_radians) + @intToFloat(f16, rotation_point.x)),
        .y = @floatToInt(c_int, @intToFloat(f16, (target_point.x - rotation_point.x)) * root.math.sin(angle_in_radians) + @intToFloat(f16, (target_point.y - rotation_point.y)) * root.math.cos(angle_in_radians) + @intToFloat(f16, rotation_point.y))
    };
}
