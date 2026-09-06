shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec3 water_position;
uniform float world_time = 0.0;

void vertex() {
    water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase_a = dot(water_position.xz, vec2(0.42, 0.18)) + world_time * 0.75;
    float phase_b = dot(water_position.xz, vec2(-0.21, 0.48)) - world_time * 0.55;
    float phase_c = dot(water_position.xz, vec2(0.16, -0.30)) + world_time * 0.38;
    VERTEX.y += sin(phase_a) * 0.12 + sin(phase_b) * 0.065 + sin(phase_c) * 0.035;
    float dx = cos(phase_a) * 0.050 + cos(phase_b) * -0.014 + cos(phase_c) * 0.006;
    float dz = cos(phase_a) * 0.022 + cos(phase_b) * 0.031 - cos(phase_c) * 0.010;
    NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
    vec3 n = normalize(NORMAL);
    vec3 view_dir = normalize(VIEW);
    float fresnel = pow(1.0 - clamp(abs(dot(n, view_dir)), 0.0, 1.0), 2.0);
    float band_a = 0.5 + 0.5 * sin(dot(water_position.xz, vec2(0.42, 0.18)) + world_time * 0.75);
    float band_b = 0.5 + 0.5 * sin(dot(water_position.xz, vec2(-0.21, 0.48)) - world_time * 0.55);
    float broad_ripple = 0.5 + 0.5 * sin(dot(water_position.xz, vec2(0.16, -0.30)) + world_time * 0.38);
    float crest_a = smoothstep(0.68, 0.94, band_a);
    float crest_b = smoothstep(0.72, 0.96, band_b);
    float foam = clamp(crest_a * 0.52 + crest_b * 0.34, 0.0, 1.0);
    vec3 deep = vec3(0.025, 0.19, 0.27);
    vec3 surface = vec3(0.16, 0.48, 0.59);
    ALBEDO = mix(deep, surface, 0.25 * fresnel + 0.16 * broad_ripple);
    ALBEDO += vec3(0.12, 0.25, 0.29) * foam;
    METALLIC = 0.08;
    SPECULAR = 0.82;
    ROUGHNESS = 0.26 - foam * 0.08;
    EMISSION = vec3(0.012, 0.045, 0.060) * (0.45 + fresnel * 0.55);
    ALPHA = 0.48 + fresnel * 0.25 + foam * 0.08;
}
