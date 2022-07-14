const root = @import("main.zig");

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

pub const directions = enum(i8) { left = -1, right = 1 };

pub const PLATFORM_LIMIT = 2;

pub const Platform = struct {
    rect: root.c.SDL_Rect,
    color: root.c.SDL_Color,

    pub fn render(self: *Platform, renderer: *root.c.SDL_Renderer) void {
        _ = root.c.SDL_SetRenderDrawColor(renderer, self.color.r, self.color.g, self.color.b, self.color.a);
        _ = root.c.SDL_RenderFillRect(renderer, &self.rect);
    }
};

pub const Player = struct {
    pogo_rect: root.c.SDL_Rect = root.c.SDL_Rect{ .x = POGO_INITIAL_X, .y = POGO_INITIAL_Y, .w = POGO_WIDTH, .h = POGO_HEIGHT },
    pogo_tip: root.c.SDL_Point = root.c.SDL_Point {
        .x = POGO_INITIAL_X + @divExact(POGO_WIDTH, 2),
        .y = POGO_INITIAL_Y + POGO_HEIGHT
    },
    body_rect: root.c.SDL_Rect = root.c.SDL_Rect{ .x = PLAYER_X, .y = PLAYER_Y, .w = PLAYER_WIDTH, .h = PLAYER_HEIGHT },
    vel_y: f32 = 0.0,
    angle: f16 = 0.0,
    charge_value: f32 = PLAYER_DEFAULT_CHARGE,
    is_charging: bool = false,
    on_ground: bool = false,

    pub fn render(self: *Player, renderer: *root.c.SDL_Renderer) void {
        const texture = root.c.SDL_CreateTexture(renderer, root.c.SDL_PIXELFORMAT_RGBA8888, root.c.SDL_TEXTUREACCESS_TARGET, 1, 1);

        _ = root.c.SDL_RenderCopyEx(renderer, texture, null, &self.pogo_rect, self.angle, &root.c.SDL_Point{
            .x = @divExact(self.pogo_rect.w, 2),
            .y = -@divExact(self.body_rect.h, 2),
            }, root.c.SDL_FLIP_NONE);

        _ = root.c.SDL_RenderCopyEx(renderer, texture, null, &self.body_rect, self.angle, &root.c.SDL_Point{
            .x = @divExact(self.body_rect.w, 2),
            .y = @divExact(self.body_rect.h, 2),
            }, root.c.SDL_FLIP_NONE);

        _ = root.c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        _ = root.c.SDL_RenderDrawPoint(renderer, self.pogo_tip.x, self.pogo_tip.y);
    }

    pub fn rotate(self: *Player, direction: directions) void {
        if (self.is_charging) return;
        self.*.angle += @intToFloat(f16, PLAYER_ROTATION_RATE * @enumToInt(direction));
        if (self.angle >= 360 or self.angle <= -360) self.*.angle = 0;
    }

    pub fn bounce(self: *Player) void {
        self.*.is_charging = false;
        if (!self.on_ground) return;
        self.*.on_ground = false;
        self.*.vel_y = -self.charge_value;
        self.*.charge_value = PLAYER_DEFAULT_CHARGE;
    }

    pub fn charge(self: *Player, dt: f32) void {
        root.std.debug.print("Player charge:\t{d}\n", .{self.charge_value});
        if (!self.on_ground) return;
        if (self.charge_value < PLAYER_CHARGE_LIMIT) {
            self.*.charge_value += PLAYER_CHARGE_RATE * dt;
            self.*.is_charging = true;
            self.*.on_ground = false;
        } else {
            self.*.charge_value = PLAYER_CHARGE_LIMIT;
            if (self.on_ground) self.bounce();
        }
    }

    fn update_pogo_tip(self: *Player) void {
        self.*.pogo_tip = root.myMath.getRotatedPoint(
            root.c.SDL_Point {
                .x = self.pogo_rect.x + @divExact(self.pogo_rect.w, 2),
                .y = self.pogo_rect.y + self.pogo_rect.h
            },
            root.c.SDL_Point{
                .x = self.pogo_rect.x + @divExact(self.pogo_rect.w, 2),
                .y = self.pogo_rect.y - @divExact(self.body_rect.h, 2),
            }, self.angle);
    }

    fn applyGravity(self: *Player, dt: f32) void {
        if (self.vel_y < PLAYER_VEL_Y_LIMIT) self.*.vel_y += PLAYER_GRAVITY * dt else self.*.vel_y = PLAYER_VEL_Y_LIMIT;
        self.*.pogo_rect.y += @floatToInt(i32, self.vel_y);
        self.*.body_rect.y = self.pogo_rect.y - self.body_rect.h;
    }

    fn collisionDetectionRect(self: *Player, platforms: [root.Platform.PLATFORM_LIMIT]root.Platform.Platform) void {
        for (platforms) |_, index| {
            if (root.c.SDL_HasIntersection(&self.pogo_rect, &platforms[index].rect) == 1) {
                if (!self.is_charging) self.bounce();
                self.*.on_ground = true;
                self.*.pogo_rect.y = platforms[index].rect.y - self.pogo_rect.h;
            }
        }
    }

    fn collisionDetectionPoint(self: *Player, platform: root.entity.Platform) void {
        if (root.c.SDL_PointInRect(&self.pogo_tip, &platform.rect) == 1) {
            if (!self.is_charging) self.bounce();
            self.*.on_ground = true;
            self.*.pogo_rect.y = platform.rect.y - self.pogo_rect.h;
        }
    }

    pub fn update(self: *Player, dt: f32, platforms: [root.entity.PLATFORM_LIMIT]root.entity.Platform) void {
        self.applyGravity(dt);
        self.update_pogo_tip();
        collisionDetectionPoint(self, platforms[0]);
    }
};
