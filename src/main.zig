const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0/@intToFloat(f32, FPS);
const PLAYER_WIDTH = 100;
const PLAYER_HEIGHT = 200;
const PLAYER_INITIAL_X = 100;
const PLAYER_INITIAL_Y = 100;

const directions = enum { left, right };

const Vec2 = struct {
    x: i32,
    y: i32,
};

const Player = struct {
    rect: c.SDL_Rect,
    angle: f16,

    fn update(self: *Player) void {
        _ = self;
    }
};

fn NewPlayer() Player {
    var player = Player{
        .rect = c.SDL_Rect{ .x = PLAYER_INITIAL_X, .y = PLAYER_INITIAL_Y, .w = PLAYER_WIDTH, .h = PLAYER_HEIGHT },
        .angle = 0.0,
    };

    return player;
}

fn RenderPlayer(renderer: *c.SDL_Renderer, player: Player) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &player.rect);
}

// TODO: implement PlayerMove 
fn PlayerMove(direction: directions, player: *Player) void {
    switch (direction) {
        directions.left => {
            std.debug.print("{d}\n", .{player.*.angle});
        },
        directions.right => {
            std.debug.print("{d}\n", .{player.*.angle});
        },
    }
}

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("PogoZig", 0, 0, 500, 500, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC | c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var player = NewPlayer();

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        const keyboard = c.SDL_GetKeyboardState(null);
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        if (keyboard[c.SDL_SCANCODE_Q] != 0) break :mainloop;

        if (keyboard[c.SDL_SCANCODE_A] != 0) PlayerMove(directions.left, &player);
        if (keyboard[c.SDL_SCANCODE_D] != 0) PlayerMove(directions.right, &player);

        player.update();

        _ = c.SDL_SetRenderDrawColor(renderer, 28, 28, 28, 255);
        _ = c.SDL_RenderClear(renderer);
        _ = RenderPlayer(renderer, player);
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000/FPS);
    }
}
