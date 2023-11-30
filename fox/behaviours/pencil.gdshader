shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 u_bgColor: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float u_bgColorFactor: hint_range(0.0, 1.0) = 0.4;
uniform vec4 u_patternColor: source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float u_threshold1: hint_range(0.0, 1.0) = 0.75;
uniform float u_threshold2: hint_range(0.0, 1.0) = 0.50;
uniform float u_threshold3: hint_range(0.0, 1.0) = 0.25;
uniform float u_threshold4: hint_range(0.0, 1.0) = 0.05;

uniform vec2 u_bgTiling = vec2(1.0, 1.0);
uniform vec2 u_patternTiling = vec2(1.0, 1.0);

uniform sampler2D u_bgTexture;
uniform sampler2D u_patternTexture;

const float C2_SQRT2 = 0.707106781;
const mat2 ROT_45 = mat2(vec2(C2_SQRT2, -C2_SQRT2), vec2(C2_SQRT2, C2_SQRT2));
const vec4 COLOR_WHITE = vec4(1.0, 1.0, 1.0, 1.0);

float getIntensity(vec3 color)
{
	return 0.299*color.r + 0.587*color.g + 0.114*color.b;
}

vec4 getPatternColor(vec2 uv, float intensity)
{
	vec2 patternUV1 = vec2(-uv.x, uv.y) * u_patternTiling;
	vec2 patternUV2 = uv * u_patternTiling;
	vec2 patternUV3 = ROT_45*(uv + vec2(0.2358, 0.9123)) * u_patternTiling;
	vec2 patternUV4 = (vec2(uv.x, -uv.y) + vec2(0.4123, 0.7218)) * u_patternTiling;
	vec4 pCol1 = texture(u_patternTexture, patternUV1);
	vec4 pCol2 = texture(u_patternTexture, patternUV2);
	vec4 pCol3 = texture(u_patternTexture, patternUV3);
	vec4 pCol4 = texture(u_patternTexture, patternUV4);

	if(intensity > u_threshold1)
		return vec4(1.0, 1.0, 1.0, 1.0);
	if(intensity > u_threshold2)
		return mix(pCol1, COLOR_WHITE, 0.5);
	if(intensity > u_threshold3)
		return mix(pCol1*pCol2, COLOR_WHITE, 0.3);
	if(intensity > u_threshold4)
		return mix(pCol1*pCol2*pCol3, COLOR_WHITE, 0.1);
	return pCol1*pCol2*pCol3*pCol4*0.8;
}

void fragment()
{
	vec4 origColor = texture(SCREEN_TEXTURE, SCREEN_UV);
	float intensity = getIntensity(origColor.rgb);
	vec4 bgColor = mix(texture(u_bgTexture, UV*u_bgTiling), u_bgColor, u_bgColorFactor);
	vec4 patternColor = getPatternColor(UV, intensity);
	vec4 color = mix(u_patternColor, bgColor, getIntensity(patternColor.rgb));
	COLOR = color;
}