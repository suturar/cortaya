package cortaya
import lin "core:math/linalg"
import rl "vendor:raylib"
import "core:math"

@export
shader :: proc(pixel: rl.Color, pos: [2]f32) -> rl.Color {
    np : rl.Color = pixel

    hsv := rl.ColorToHSV(np)
    hsv[2] = math.pow(hsv[2], 1)
    hsv[1] = math.pow(hsv[1], 0.5)
    np = rl.ColorFromHSV(hsv.x, hsv.y, hsv.z)
    return np
}

