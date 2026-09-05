shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D terrain_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seabed_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;
uniform float waterline = 0.0;
uniform float transition_width = 2.0;
uniform float grass_mix = 0.5;
varying vec3 terrain_color;
varying float terrain_height;

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 variant_uv(vec2 uv, vec2 cell) {
    vec2 random_value = hash22(cell);
    vec2 transformed = uv;
    float turn = floor(random_value.x * 4.0);
    if (turn < 1.0) {
        transformed = uv;
    } else if (turn < 2.0) {
        transformed = vec2(-uv.y, uv.x);
    } else if (turn < 3.0) {
        transformed = -uv;
    } else {
        transformed = vec2(uv.y, -uv.x);
    }
    if (random_value.y < 0.5) {
        transformed.x = -transformed.x;
    }
    return transformed + random_value * vec2(17.31, 11.73);
}

vec3 sample_base_variant(vec2 uv, vec2 cell) {
    return texture(terrain_map, variant_uv(uv, cell)).rgb;
}

vec3 sample_seabed_variant(vec2 uv, vec2 cell) {
    return texture(seabed_map, variant_uv(uv, cell)).rgb;
}

vec3 sample_shore_variant(vec2 uv, vec2 cell) {
    return texture(shore_map, variant_uv(uv, cell)).rgb;
}

vec3 sample_sand_variant(vec2 uv, vec2 cell) {
    return texture(sand_map, variant_uv(uv, cell)).rgb;
}

vec3 sample_grass_variant(vec2 uv, vec2 cell) {
    return texture(grass_map, variant_uv(uv, cell)).rgb;
}

vec4 region_weights(vec2 uv) {
    vec2 base = floor(uv);
    vec2 blend = smoothstep(vec2(0.18), vec2(0.82), fract(uv));
    return vec4(base, blend);
}

vec3 sample_base(vec2 uv, vec4 region) {
    vec3 lower = mix(sample_base_variant(uv, region.xy), sample_base_variant(uv, region.xy + vec2(1.0, 0.0)), region.z);
    vec3 upper = mix(sample_base_variant(uv, region.xy + vec2(0.0, 1.0)), sample_base_variant(uv, region.xy + vec2(1.0, 1.0)), region.z);
    return mix(lower, upper, region.w);
}

vec3 sample_seabed(vec2 uv, vec4 region) {
    vec3 lower = mix(sample_seabed_variant(uv, region.xy), sample_seabed_variant(uv, region.xy + vec2(1.0, 0.0)), region.z);
    vec3 upper = mix(sample_seabed_variant(uv, region.xy + vec2(0.0, 1.0)), sample_seabed_variant(uv, region.xy + vec2(1.0, 1.0)), region.z);
    return mix(lower, upper, region.w);
}

vec3 sample_shore(vec2 uv, vec4 region) {
    vec3 lower = mix(sample_shore_variant(uv, region.xy), sample_shore_variant(uv, region.xy + vec2(1.0, 0.0)), region.z);
    vec3 upper = mix(sample_shore_variant(uv, region.xy + vec2(0.0, 1.0)), sample_shore_variant(uv, region.xy + vec2(1.0, 1.0)), region.z);
    return mix(lower, upper, region.w);
}

vec3 sample_sand(vec2 uv, vec4 region) {
    vec3 lower = mix(sample_sand_variant(uv, region.xy), sample_sand_variant(uv, region.xy + vec2(1.0, 0.0)), region.z);
    vec3 upper = mix(sample_sand_variant(uv, region.xy + vec2(0.0, 1.0)), sample_sand_variant(uv, region.xy + vec2(1.0, 1.0)), region.z);
    return mix(lower, upper, region.w);
}

vec3 sample_grass(vec2 uv, vec4 region) {
    vec3 lower = mix(sample_grass_variant(uv, region.xy), sample_grass_variant(uv, region.xy + vec2(1.0, 0.0)), region.z);
    vec3 upper = mix(sample_grass_variant(uv, region.xy + vec2(0.0, 1.0)), sample_grass_variant(uv, region.xy + vec2(1.0, 1.0)), region.z);
    return mix(lower, upper, region.w);
}

vec3 sample_material_transition(vec2 uv) {
    vec4 region = region_weights(uv);
    float relative_height = terrain_height - waterline;
    float width = max(transition_width, 0.01);
    if (relative_height <= -2.0 * width) {
        return sample_seabed(uv, region);
    }
    if (relative_height < -width) {
        return mix(sample_seabed(uv, region), sample_shore(uv, region), smoothstep(-2.0 * width, -width, relative_height));
    }
    if (relative_height < 0.0) {
        return mix(sample_shore(uv, region), sample_sand(uv, region), smoothstep(-width, 0.0, relative_height));
    }
    if (relative_height < 1.5 * width) {
        vec3 land_pattern = mix(sample_base(uv, region), sample_grass(uv, region), grass_mix);
        return mix(sample_sand(uv, region), land_pattern, smoothstep(0.0, 1.5 * width, relative_height));
    }
    return mix(sample_base(uv, region), sample_grass(uv, region), grass_mix);
}

void vertex() {
    terrain_color = COLOR.rgb;
    terrain_height = VERTEX.y;
}

void fragment() {
    vec3 pattern = vec3(1.0);
    if (use_texture) {
        pattern = sample_material_transition(UV);
    }
    ALBEDO = terrain_color * pattern;
    ROUGHNESS = 0.95;
    METALLIC = 0.0;
}
