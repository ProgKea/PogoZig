const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @intToFloat(f32, FPS);

const POGO_WIDTH = 10;
const POGO_HEIGHT = 40;
const POGO_INITIAL_X = 400;
const POGO_INITIAL_Y = 400;

const PLAYER_WIDTH = 40;
const PLAYER_HEIGHT = 100;
const PLAYER_X = POGO_INITIAL_X - PLAYER_WIDTH / 2 + POGO_WIDTH / 2;
const PLAYER_Y = POGO_INITIAL_Y - PLAYER_HEIGHT;
const PLAYER_GRAVITY = 25;
const PLAYER_VEL_Y_LIMIT = 25;
const PLAYER_CHARGE_LIMIT = 20;
const PLAYER_DEFAULT_CHARGE = 9;
const PLAYER_CHARGE_RATE = 20;
const PLAYER_ROTATION_RATE = 5;

const PLATFORM_LIMIT = 2;

const WINDOW_HEIGHT = 1000;
const WINDOW_WIDTH = 1200;

const directions = enum(i8) { left = -1, right = 1 };

fn degreesToRadians(degree: f16) f16 {
    return degree * math.pi / 180;
}

fn getRotatedPoint(target_point: c.SDL_Point, rotation_point: c.SDL_Point, angle: f16) c.SDL_Point {
    const angle_in_radians = @as(f32, degreesToRadians(angle));
    std.debug.print("angle_in_radians: {d}\n", .{angle_in_radians});
    return c.SDL_Point {
        .x = @floatToInt(c_int, @intToFloat(f16, (target_point.x - rotation_point.x)) * (angle_in_radians) - @intToFloat(f16, (target_point.y - rotation_point.y)) * math.sin(angle_in_radians) + @intToFloat(f16, rotation_point.x)),
        .y = @floatToInt(c_int, @intToFloat(f16, (target_point.x - rotation_point.x)) * math.sin(angle_in_radians) + @intToFloat(f16, (target_point.y - rotation_point.y)) * math.cos(angle_in_radians) + @intToFloat(f16, rotation_point.y))
    };
}

const Platform = struct {
    rect: c.SDL_Rect,
    color: c.SDL_Color,

    fn render(self: *Platform, renderer: *c.SDL_Renderer) void {
        _ = c.SDL_SetRenderDrawColor(renderer, self.color.r, self.color.g, self.color.b, self.color.a);
        _ = c.SDL_RenderFillRect(renderer, &self.rect);
    }
};

const Player = struct {
    pogo_rect: c.SDL_Rect = c.SDL_Rect{ .x = POGO_INITIAL_X, .y = POGO_INITIAL_Y, .w = POGO_WIDTH, .h = POGO_HEIGHT },
    pogo_tip: c.SDL_Point = c.SDL_Point {
        .x = POGO_INITIAL_X + @divExact(POGO_WIDTH, 2),
        .y = POGO_INITIAL_Y + POGO_HEIGHT
    },
    body_rect: c.SDL_Rect = c.SDL_Rect{ .x = PLAYER_X, .y = PLAYER_Y, .w = PLAYER_WIDTH, .h = PLAYER_HEIGHT },
    vel_y: f32 = 0.0,
    angle: f16 = 0.0,
    charge_value: f32 = PLAYER_DEFAULT_CHARGE,
    is_charging: bool = false,
    on_ground: bool = false,

    fn render(self: *Player, renderer: *c.SDL_Renderer) void {
        const texture = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_TARGET, 1, 1);

        _ = c.SDL_RenderCopyEx(renderer, texture, null, &self.pogo_rect, self.angle, &c.SDL_Point{
            .x = @divExact(self.pogo_rect.w, 2),
            .y = -@divExact(self.body_rect.h, 2),
        }, c.SDL_FLIP_NONE);

        _ = c.SDL_RenderCopyEx(renderer, texture, null, &self.body_rect, self.angle, &c.SDL_Point{
            .x = @divExact(self.body_rect.w, 2),
            .y = @divExact(self.body_rect.h, 2),
        }, c.SDL_FLIP_NONE);

        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        _ = c.SDL_RenderDrawPoint(renderer, self.pogo_tip.x, self.pogo_tip.y);
    }

    fn rotate(self: *Player, direction: directions) void {
        self.*.angle += @intToFloat(f16, PLAYER_ROTATION_RATE * @enumToInt(direction));
        if (self.angle >= 360 or self.angle <= -360) self.*.angle = 0;
    }

    fn bounce(self: *Player) void {
        self.*.is_charging = false;
        if (!self.on_ground) return;
        self.*.on_ground = false;
        self.*.vel_y = -self.charge_value;
        self.*.charge_value = PLAYER_DEFAULT_CHARGE;
    }

    fn charge(self: *Player, dt: f32) void {
        std.debug.print("Player charge:\t{d}\n", .{self.charge_value});
        if (!self.on_ground) return;
        if (self.charge_value < PLAYER_CHARGE_LIMIT) {
            self.*.charge_value += PLAYER_CHARGE_RATE * dt;
            self.*.is_charging = true;
        } else {
            self.*.charge_value = PLAYER_CHARGE_LIMIT;
            if (self.on_ground) self.bounce();
        }
    }

    fn update_pogo_tip(self: *Player) void {
        self.*.pogo_tip = getRotatedPoint(
            c.SDL_Point {
                .x = self.pogo_rect.x + @divExact(self.pogo_rect.w, 2),
                .y = self.pogo_rect.y + self.pogo_rect.h
            },
            c.SDL_Point{
                .x = self.pogo_rect.x + @divExact(self.pogo_rect.w, 2),
                .y = self.pogo_rect.y - @divExact(self.body_rect.h, 2),
            }, self.angle);
    }

    fn applyGravity(self: *Player, dt: f32) void {
        if (self.vel_y < PLAYER_VEL_Y_LIMIT) self.*.vel_y += PLAYER_GRAVITY * dt else self.*.vel_y = PLAYER_VEL_Y_LIMIT;
        self.*.pogo_rect.y += @floatToInt(i32, self.vel_y);
        self.*.body_rect.y = self.pogo_rect.y - self.body_rect.h;
    }

    fn collisionDetectionRect(self: *Player, platforms: [PLATFORM_LIMIT]Platform) void {
        for (platforms) |_, index| {
            if (c.SDL_HasIntersection(&self.pogo_rect, &platforms[index].rect) == 1) {
                if (!self.is_charging) self.bounce();
                self.*.on_ground = true;
                self.*.pogo_rect.y = platforms[index].rect.y - self.pogo_rect.h;
            }
        }
    }

    fn collisionDetectionPoint(self: *Player, platforms: [PLATFORM_LIMIT]Platform) void {
        if (c.SDL_PointInRect(&self.pogo_tip, &platforms[0].rect) == 1) {
            if (!self.is_charging) self.bounce();
            self.*.on_ground = true;
            self.*.pogo_rect.y = platforms[0].rect.y - self.pogo_rect.h;
        }
    }

    fn update(self: *Player, dt: f32, platforms: [PLATFORM_LIMIT]Platform) void {
        self.applyGravity(dt);
        self.update_pogo_tip();
        collisionDetectionPoint(self, platforms);
    }
};

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

    var player = Player{};
    var platforms: [PLATFORM_LIMIT]Platform = undefined;
    var test_platform = Platform{
        .rect = c.SDL_Rect{
            .x = 100,
            .y = WINDOW_HEIGHT - 100,
            .w = WINDOW_WIDTH,
            .h = 100,
        },
        .color = c.SDL_Color{
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
        if (keyboard[c.SDL_SCANCODE_A] != 0) player.rotate(directions.left);
        if (keyboard[c.SDL_SCANCODE_D] != 0) player.rotate(directions.right);
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
