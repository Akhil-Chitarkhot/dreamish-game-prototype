shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float vignette = smoothstep(0.3, 0.75, length(uv));
    COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
