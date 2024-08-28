package cortaya
import lin "core:math/linalg"
import "core:math"
Pixel :: [4]f32    

@export
shader :: proc(pixel: Pixel, pos: [2]f32) -> Pixel {
    np : Pixel = pixel

    hsl := lin.vector4_rgb_to_hsl(np)
    hsl[2] = math.pow(hsl[2], 1.2)
    
    np = lin.vector4_hsl_to_rgb(hsl[0], hsl[1], hsl[2])
    return np
}

