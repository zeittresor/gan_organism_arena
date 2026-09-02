shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec3 water_position;

void vertex() {
    water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase_a = water_position.x * 0.60 + water_position.z * 0.30 + TIME * 1.10;
    float phase_b = water_position.z * 0.90 - water_position.x * 0.25 - TIME * 0.80;
    VERTEX.y += sin(phase_a) * 0.09 + cos(phase_b) * 0.05;
    float dx = cos(phase_a) * 0.054 + sin(phase_b) * 0.0125;
    float dz = cos(phase_a) * 0.027 - sin(phase_b) * 0.045;
    NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
    vec3 n = normalize(NORMAL);
    float grazing = pow(1.0 - clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0), 3.0);
    float ripple = sin(water_position.x * 1.90 + TIME * 1.40) * cos(water_position.z * 1.60 - TIME);
    float highlight = pow(max(0.0, ripple), 8.0);
    ALBEDO = mix(vec3(0.035, 0.25, 0.34), vec3(0.34, 0.61, 0.70), grazing);
    ALBEDO += vec3(0.15, 0.24, 0.25) * highlight;
    METALLIC = 0.12;
    SPECULAR = 0.90;
    ROUGHNESS = 0.18 + (1.0 - highlight) * 0.10;
    EMISSION = vec3(0.02, 0.07, 0.085) * (0.30 + highlight);
    ALPHA = 0.40 + grazing * 0.38 + highlight * 0.10;
}
