package cortaya
import "core:os"
import "core:fmt"
import "core:mem"
import "core:math"
import lin "core:math/linalg"
import rl "vendor:raylib"
import "core:slice"
import dl "core:dynlib"
import "core:time"

Image		:: rl.Image
Pixel		:: [4]f32    
Shader_Proc	:: proc(pixel: Pixel, pos: [2]f32) -> Pixel
Vec2		:: rl.Vector2

KEY_CROP	:: rl.KeyboardKey.C
KEY_EXPORT	:: rl.KeyboardKey.E
KEY_UP		:: rl.KeyboardKey.W
KEY_DOWN	:: rl.KeyboardKey.S
KEY_LEFT	:: rl.KeyboardKey.A
KEY_RIGHT	:: rl.KeyboardKey.D
KEY_ZOOM_IN	:: rl.KeyboardKey.UP
KEY_ZOOM_OUT	:: rl.KeyboardKey.DOWN

State :: struct {
    shader_proc : Shader_Proc,
    shader_time : os.File_Time,
    lib : dl.Library,
    filename : string,
}
state : State

camera_update :: proc(using camera: ^rl.Camera2D) {
    using state
    dt := rl.GetFrameTime()
    zoom_target_speed : f32
    ZOOM_MAX_SPEED :: 2
    @static zoom_speed : f32
    if rl.IsKeyDown(KEY_ZOOM_IN) do zoom_target_speed += ZOOM_MAX_SPEED
    if rl.IsKeyDown(KEY_ZOOM_OUT) do zoom_target_speed -= ZOOM_MAX_SPEED
    if zoom_target_speed != 0 do zoom_speed = zoom_target_speed
    else do zoom_speed *= 0.4
    zoom += zoom_speed * dt

    hm_target_speed : f32
    HM_MAX_SPEED :: 400
    @static hm_speed : f32
    if rl.IsKeyDown(KEY_RIGHT) do hm_target_speed += HM_MAX_SPEED
    if rl.IsKeyDown(KEY_LEFT) do hm_target_speed -= HM_MAX_SPEED
    if hm_target_speed != 0 do hm_speed = hm_target_speed
    else do hm_speed *= 0.4
    camera.target.x += hm_speed * dt
    if camera.target.x < 0 do camera.target.x = 0

    vm_target_speed : f32
    VM_MAX_SPEED :: 400
    @static vm_speed : f32
    if rl.IsKeyDown(KEY_DOWN) do vm_target_speed += VM_MAX_SPEED
    if rl.IsKeyDown(KEY_UP) do vm_target_speed -= VM_MAX_SPEED
    if vm_target_speed != 0 do vm_speed = vm_target_speed
    else do vm_speed *= 0.4
    camera.target.y += vm_speed * dt
    if camera.target.y < 0 do camera.target.y = 0

}



run :: proc() -> bool {
    using state
    defer delete(os.args)

    switch len(os.args) {
    case 1:
	fmt.eprintfln("Error: No input file")
	fmt.eprintfln("    usage: %s <filename>", os.args[0])
	return false
    case 2:
	filename = os.args[1]
    case:
	fmt.eprintfln("Error: Extra arguments after filename")
	fmt.eprintfln("    usage: %s <filename>", os.args[0])
	return false
    }
    
    rl.InitWindow(1000, 1000, "CortaYa")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    image := rl.LoadImage(rl.TextFormat("%s", filename))
    defer rl.UnloadImage(image)
    time.sleep(100 * time.Millisecond)
    if image == {} do return false

    image_size := int(image.width * image.height * 3)

    image_backing : [^]u8 = make([^]u8, image_size)
    defer free(image_backing)
    mem.copy(image_backing, image.data, image_size)
    
    texture := rl.LoadTextureFromImage(image)
    defer rl.UnloadTexture(texture)

    camera : rl.Camera2D
    camera.zoom = 1
    
    for !rl.WindowShouldClose() {
	current_time, _ := os.last_write_time_by_name("shader.so")
	if current_time > shader_time {
	    shader_time = current_time
	    rl.TraceLog(.INFO, "Reloading shader")
	    if lib != nil do unload_shader()
	    time.sleep(100 * time.Millisecond)
	    load_shader()
	    mem.copy(image.data, image_backing, image_size)
	    for i := 0; i < int(image.width); i += 1 do for j := 0; j < int(image.height); j += 1 {
		image_data := slice.from_ptr(cast([^]u8)image.data, image_size)
		pixel_addr := (j * int(image.width) + i) * 3
		pixel := Pixel{
		    f32(image_data[pixel_addr])/255,
		    f32(image_data[pixel_addr + 1])/255,
		    f32(image_data[pixel_addr + 2])/255,
		    1,
		}
		
		////////
		pixel = shader_proc(pixel, {f32(i)/f32(image.width), f32(j)/f32(image.height)})
		////////
		
		image_data[pixel_addr] = u8(pixel.r * 255)
		image_data[pixel_addr + 1] = u8(pixel.g * 255)
		image_data[pixel_addr + 2] = u8(pixel.b * 255)
	    }
	    rl.TraceLog(.INFO, "Reloaded shader")
	    rl.UpdateTexture(texture, image.data)
	}
	if rl.IsKeyPressed(KEY_EXPORT) {
	    cfilename := rl.TextFormat("%s", filename)
	    cfilename_wo_ext := rl.GetFileNameWithoutExt(cfilename)
	    ff := rl.TextFormat("%s_out.jpg", cfilename_wo_ext)
	    rl.ExportImage(image, ff)

	}

	mouse := rl.GetMousePosition()
	mouse = rl.GetScreenToWorld2D(mouse, camera)

	camera_update(&camera)
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)
	rl.BeginMode2D(camera)
	rl.DrawTextureEx(texture, {}, {}, 1, rl.WHITE)
	area(mouse, image)
	rl.EndMode2D()
	rl.EndDrawing()
    }

    return true
}

area :: proc(mouse: Vec2, image: Image) {
    using state
    @static points : [2]Vec2
    @static i: int
    area_rec := rl.Rectangle{
	min(points[0].x, points[1].x),
	min(points[0].y, points[1].y),
	abs(points[0].x - points[1].x),
	abs(points[0].y - points[1].y),
    }
    rl.DrawRectangleLinesEx(area_rec, 2, rl.GRAY)
    if rl.IsMouseButtonDown(.LEFT) do points[0] = mouse
    if rl.IsMouseButtonDown(.RIGHT) do points[1] = mouse

    for &point in points {
	if point.x <= 0 do point.x = 0
	if point.y <= 0 do point.y = 0
	rl.DrawCircle(i32(point.x), i32(point.y),10,  rl.GRAY)
    }
    if rl.IsKeyPressed(KEY_CROP) {
	cropped_image := rl.ImageCopy(image)
	defer rl.UnloadImage(cropped_image)
	rl.ImageCrop(&cropped_image, area_rec)

	cfilename := rl.TextFormat("%s", filename)
	cfilename_wo_ext := rl.GetFileNameWithoutExt(cfilename)
	ff := rl.TextFormat("%s_cropped.jpg", cfilename_wo_ext)
	
	rl.ExportImage(cropped_image, ff)
    }
	
}

load_shader :: proc() -> bool {
    using state
    ok: bool
    lib, ok = dl.load_library("./shader.so")
    if !ok {
	rl.TraceLog(.ERROR, "Could not load shader file")
	return false
    }
    shader_proc = cast(Shader_Proc)(dl.symbol_address(lib, "shader") or_else nil)
    if shader_proc == nil {
	rl.TraceLog(.ERROR, "Could not find symbol shader")
    }
    return true
}

unload_shader :: proc() {
    using state
    dl.unload_library(lib)
}

main :: proc()  {
    os.exit(0 if run() else 1) 
}
