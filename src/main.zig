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
const PLAYER_GRAVITY = 0.4;
const PLAYER_VEL_Y_LIMIT = 25;

const PLATFORM_LIMIT = 2;

const WINDOW_HEIGHT = 1000;
const WINDOW_WIDTH = 1200;

const directions = enum { left, right };

const Vec2 = struct {
    x: i32,
    y: i32,
};

const Platform = struct {
    rect: c.SDL_Rect,
    color: c.SDL_Color,

    fn render(self: *Platform, renderer: *c.SDL_Renderer) void {
        _ = c.SDL_SetRenderDrawColor(renderer, self.color.r, self.color.g, self.color.b, self.color.a);
        _ = c.SDL_RenderFillRect(renderer, &self.rect);
    }
};

const Player = struct {
    rect: c.SDL_Rect = c.SDL_Rect{ .x = PLAYER_INITIAL_X, .y = PLAYER_INITIAL_Y, .w = PLAYER_WIDTH, .h = PLAYER_HEIGHT },
    vel_y: f32 = 0.0,
    angle: f16 = 0.0,

    fn render(self: *Player, renderer: *c.SDL_Renderer) void {
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        _ = c.SDL_RenderFillRect(renderer, &self.rect);
    }

    fn move(self: *Player, direction: directions) void {
        switch (direction) {
            directions.left => {
                std.debug.print("{d}\n", .{self.*.angle});
            },
            directions.right => {
                std.debug.print("{d}\n", .{self.*.angle});
            },
        }
    }

    fn applyGravity(self: *Player) void {
        if (self.*.vel_y < PLAYER_VEL_Y_LIMIT) self.*.vel_y += PLAYER_GRAVITY
        else self.*.vel_y = PLAYER_VEL_Y_LIMIT;
        self.*.rect.y += @floatToInt(i32, self.*.vel_y);
    }

    fn collisionDetection(self: *Player, platforms: [PLATFORM_LIMIT]Platform) void {
        for (platforms) |_, index| {
            if (c.SDL_HasIntersection(&self.*.rect, &platforms[index].rect) == 1) {
                self.*.vel_y = 0.0;
            }
        }
    }

    fn update(self: *Player, platforms: [PLATFORM_LIMIT]Platform) void {
        self.applyGravity();
        collisionDetection(self, platforms);
    }
};

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("PogoZig", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_PRESENTVSYNC | c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var player = Player {};
    var platforms: [PLATFORM_LIMIT]Platform = undefined;
    var test_platform = Platform {
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
                else => {},
            }
        }

        if (keyboard[c.SDL_SCANCODE_Q] != 0) break :gameloop;
        if (keyboard[c.SDL_SCANCODE_A] != 0) player.move(directions.left);
        if (keyboard[c.SDL_SCANCODE_D] != 0) player.move(directions.right);

        player.update(platforms);

        _ = c.SDL_SetRenderDrawColor(renderer, 28, 28, 28, 255);
        _ = c.SDL_RenderClear(renderer);
        player.render(renderer);
        for (platforms) |_, index| {
            platforms[index].render(renderer);
        }
        c.SDL_RenderPresent(renderer);

        c.SDL_Delay(1000/FPS);
    }
}
