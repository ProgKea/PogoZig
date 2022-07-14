pub const std = @import("std");
pub const math = std.math;
pub const myMath = @import("myMath.zig");
pub const entity = @import("Entities.zig");
pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @intToFloat(f32, FPS);

const WINDOW_HEIGHT = 1000;
const WINDOW_WIDTH = 1200;

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("PogoZig", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var player = entity.Player{};
    var platforms: [entity.PLATFORM_LIMIT]entity.Platform = undefined;
    entity.Platform.init_array(&platforms);
    var test_platform = entity.Platform {
        .rect = c.SDL_Rect {
            .x = 100,
            .y = WINDOW_HEIGHT - 100,
            .w = WINDOW_WIDTH,
            .h = 100,
        },
        .color = c.SDL_Color {
            .r = 255,
            .g = 255,
            .b = 0,
            .a = 255,
        },
    };
    platforms[0] = test_platform;

    gameloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        const keyboard = c.SDL_GetKeyboardState(null);
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :gameloop,
                c.SDL_KEYUP => {
                    if (sdl_event.key.keysym.sym == c.SDLK_SPACE) {
                        player.bounce();
                    }
                },
                else => {},
            }
        }

        if (keyboard[c.SDL_SCANCODE_Q] != 0) break :gameloop;
        if (keyboard[c.SDL_SCANCODE_A] != 0) player.rotate(entity.directions.left);
        if (keyboard[c.SDL_SCANCODE_D] != 0) player.rotate(entity.directions.right);
        if (keyboard[c.SDL_SCANCODE_SPACE] != 0) player.charge(DELTA_TIME_SEC);

        player.update(DELTA_TIME_SEC, platforms);

        _ = c.SDL_SetRenderDrawColor(renderer, 28, 28, 28, 255);
        _ = c.SDL_RenderClear(renderer);
        player.render(renderer);
        _ = c.SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);
        for (platforms) |_, index| {
            platforms[index].render(renderer);
        }
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000 / FPS);
    }
}
