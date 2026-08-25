shader_type canvas_item;
// 레벨 높이(월드 Y)에 따라: 아래=진함, 위=연함. 색은 감정 색에서 뽑음.
uniform vec4 emotion_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float level_bottom = 640.0;    // 월드 Y 아래(진함)
uniform float level_top = -4915.0;     // 월드 Y 위(연함)
uniform float dark_mul : hint_range(0.0, 1.0) = 0.22;   // 아래 진하기
uniform float light_mix : hint_range(0.0, 1.0) = 0.62;  // 위 연하기(흰색 섞는 정도)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = clamp((world_pos.y - level_bottom) / (level_top - level_bottom), 0.0, 1.0);
	vec3 dark_c = emotion_color.rgb * dark_mul;                 // 진한 색
	vec3 light_c = mix(emotion_color.rgb, vec3(1.0), light_mix); // 연한 색
	COLOR = vec4(mix(dark_c, light_c, t), 1.0);
}
