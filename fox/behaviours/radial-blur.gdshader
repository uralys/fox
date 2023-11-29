shader_type canvas_item;

uniform float value : hint_range(-6.283, 6.283, 0.1);
uniform int quality : hint_range(1, 100, 1);

uniform float occilation_speed : hint_range(0.0, 10.0, 0.1);

uniform float scale_value : hint_range(0.0, 10.0, 0.1);

uniform float xOffset : hint_range(-0.5, 0.5);
uniform float yOffset : hint_range(-0.5, 0.5);

vec2 rotated(vec2 pos, float rads){

    pos -= vec2(0.5,0.5);

    float tempvecx = pos.x * cos(rads) - pos.y * sin(rads);

    float tempvecy = pos.x * sin(rads) + pos.y * cos(rads);

    vec2 finalvalue = vec2(tempvecx,tempvecy) + vec2(0.5,0.5);

    return finalvalue;
}

vec2 scale(vec2 uv, float x, float y)
{
	mat2 scale = mat2(vec2(x, 0.0), vec2(0.0, y));

	uv -= 0.5;
	uv = uv * scale;
	uv += 0.5;

	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)
		return uv;

	return vec2(-20.0*scale_value,-20.0*scale_value);
}




void fragment(){

	COLOR = vec4(0,0,0,0);

	float i = 0.0;
	for (int j = 0; j < quality; j++ ){
		i += (value+ sin(TIME*occilation_speed)/2.0 )  /float(quality);

		COLOR += texture(TEXTURE,scale(rotated(UV,i)+vec2(xOffset/scale_value,yOffset/scale_value), scale_value,scale_value ));
	}

	float t = 1.0/float(quality);
	COLOR *= t;


}


void vertex(){

	VERTEX.y *= scale_value;
	VERTEX.x *= scale_value;
}