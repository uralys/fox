// added parameters to original shader: https://godotshaders.com/shader/ripple-gradient-shader-2/
shader_type canvas_item;

uniform float speed: hint_range(0, 5, 0.1) = 1;
uniform float colorSet: hint_range(0, 7) = 0.0;
uniform float brightness: hint_range(0.1, 0.9, 0.01) = 0.5;
uniform float amplitude: hint_range(0.1, 0.9, 0.01) = 0.5;
uniform float frequency: hint_range(0, 125, 0.1) = 10.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    float currentColor = TIME * speed;

    if(colorSet > 0.0){
      currentColor = colorSet;
    }

    float wave1 = sin(uv.x * frequency + currentColor) * amplitude;
    float wave2 = cos(uv.y * frequency + currentColor) * amplitude;
    uv += wave1 + wave2;

    vec3 color1 = vec3(brightness + (1.0 - brightness) * sin(currentColor), brightness + (1.0 - brightness) * cos(currentColor),brightness - (1.0 - brightness) * sin(currentColor));
    vec3 color2 = vec3(brightness + (1.0 - brightness ) * cos(currentColor), brightness + (1.0 - brightness) * sin(currentColor), brightness + (1.0 - brightness) * cos(currentColor));
    vec3 gradient_color = mix(color1, color2, uv.y);

    COLOR = vec4(gradient_color, 1.0);
}