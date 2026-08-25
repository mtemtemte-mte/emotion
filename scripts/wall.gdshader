shader_type canvas_item;
// 일반 벽 색: center에서 radius만큼 원형으로 퍼지며 old_color -> emotion_color 로 전환
uniform vec4 old_color : source_color = vec4(0.30, 0.33, 0.40, 1.0);
uniform vec4 emotion_color : source_color = vec4(0.30, 0.33, 0.40, 1.0);
uniform vec2 center = vec2(0.0);
uniform float radius = 100000.0;
uniform float edge = 45.0; // 퍼지는 경계 부드럽게

// 캐릭터를 광원으로: 가까우면 밝고 멀수록 어두움 (거리 기반 명암)
uniform vec2 light_pos = vec2(0.0);
uniform float light_range = 520.0;  // 이 거리 밖은 최대로 어두움
uniform float light_bright = 1.35;  // 광원 바로 옆 밝기
uniform float light_dark = 0.45;    // 멀리 떨어진 곳 밝기

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = distance(world_pos, center);
	float t = 1.0 - smoothstep(radius - edge, radius + edge, d); // 원 안=1(새 색), 밖=0(옛 색)
	vec3 col = mix(old_color.rgb, emotion_color.rgb, t);
	// 명암: 광원(캐릭터) 거리로 밝기 결정
	float ld = distance(world_pos, light_pos);
	float lit = mix(light_bright, light_dark, clamp(ld / light_range, 0.0, 1.0));
	COLOR = vec4(col * lit, 1.0);
}
