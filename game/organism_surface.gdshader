shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D coat : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D specialized : source_color, filter_linear, repeat_disable;
uniform float coat_roughness = 0.65;
varying float coat_weight;
varying vec3 tissue_color;
varying vec2 coat_variant;
varying float tissue_kind;

vec2 varied_uv(vec2 uv, vec2 variation) {
    vec2 centered = uv - vec2(0.5);
    float turn = floor(variation.x * 4.0);
    if (turn < 1.0) {
        centered = centered;
    } else if (turn < 2.0) {
        centered = vec2(-centered.y, centered.x);
    } else if (turn < 3.0) {
        centered = -centered;
    } else {
        centered = vec2(centered.y, -centered.x);
    }
    if (variation.y < 0.5) {
        centered.x = -centered.x;
    }
    return centered + vec2(0.5) + variation * vec2(13.17, 7.91);
}

void vertex() {
    coat_weight = INSTANCE_CUSTOM.r;
    coat_variant = INSTANCE_CUSTOM.gb;
    tissue_kind = INSTANCE_CUSTOM.a;
    tissue_color = COLOR.rgb;
}

void fragment() {
    vec2 varied = varied_uv(UV, coat_variant);
    vec3 inherited_pattern = texture(coat, varied).rgb;
    float slot = floor(tissue_kind * 15.0 + 0.5);
    vec2 atlas_cell = vec2(mod(slot, 4.0), floor(slot / 4.0));
    vec2 local_uv = vec2(0.018) + fract(varied) * 0.964;
    vec3 specialized_pattern = texture(specialized, (atlas_cell + local_uv) * 0.25).rgb;
    float has_specialized_surface = step(0.5, slot);
    vec3 pattern = mix(inherited_pattern, specialized_pattern, has_specialized_surface);
    ALBEDO = tissue_color * mix(vec3(1.0), pattern, max(coat_weight, has_specialized_surface));
    ROUGHNESS = coat_roughness;
    METALLIC = 0.03;
}
