extends ColorRect
## Full-screen G-force effect for the pilot (fighters):
##  - blackout (high positive G): the view tunnels in from the edges and the
##    whole screen dims;
##  - redout (strong negative G): the screen washes red.
## Strengths come from Aircraft.blackout / Aircraft.redout (0..1).

const SHADER := """
shader_type canvas_item;
uniform float blackout = 0.0;
uniform float redout = 0.0;
uniform float aspect = 1.7778;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(d);
	// Tunnel vision: the clear centre shrinks as the blackout grows.
	float edge = smoothstep(0.95 - 0.75 * blackout, 1.1 - 0.6 * blackout, r);
	float black = clamp(blackout * (0.35 + 0.65 * edge), 0.0, 0.95);
	float red_edge = smoothstep(0.3, 1.0, r);
	float red = redout * (0.4 + 0.3 * red_edge);
	vec3 col = mix(vec3(0.0), vec3(0.75, 0.02, 0.02), red / max(red + black, 0.001));
	COLOR = vec4(col, clamp(black + red - black * red, 0.0, 0.95));
}
"""

var aircraft: Aircraft


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var sh := Shader.new()
	sh.code = SHADER
	material = ShaderMaterial.new()
	material.shader = sh
	visible = false


func _process(_delta: float) -> void:
	if aircraft == null:
		return
	var b := aircraft.blackout
	var r := aircraft.redout
	visible = b > 0.001 or r > 0.001
	if visible:
		position = Vector2.ZERO
		size = get_viewport_rect().size
		material.set_shader_parameter("blackout", b)
		material.set_shader_parameter("redout", r)
		material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
