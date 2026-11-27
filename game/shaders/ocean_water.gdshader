shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Textures PBR océaniques 1K déjà présentes dans assets/textures/water/ocean_1k.
uniform sampler2D ocean_base_color : source_color, repeat_enable;
uniform sampler2D ocean_normal : hint_normal, repeat_enable;
uniform sampler2D ocean_roughness : repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.018, 0.105, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.045, 0.31, 0.37);
uniform float normal_scale = 0.42;
uniform float wave_height = 0.22;
uniform float wave_speed = 0.72;
uniform float uv_scale = 0.075;
uniform float foam_strength = 0.24;
uniform float rain_intensity = 0.0;
uniform float shoreline_foam_strength = 0.0;

varying vec3 world_position;

void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase_a = dot(world.xz, normalize(vec2(0.82, 0.57))) * 0.055 - TIME * wave_speed;
    float phase_b = dot(world.xz, normalize(vec2(-0.34, 0.94))) * 0.092 - TIME * wave_speed * 0.63;
    float phase_c = dot(world.xz, normalize(vec2(0.98, -0.18))) * 0.17 - TIME * wave_speed * 1.18;
    VERTEX.y += sin(phase_a) * wave_height;
    VERTEX.y += sin(phase_b) * wave_height * 0.34;
    VERTEX.y += sin(phase_c) * wave_height * 0.10;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = world_position.xz * uv_scale;
    vec2 drift_a = uv + vec2(TIME * 0.012, -TIME * 0.008);
    vec2 drift_b = uv * 1.73 + vec2(-TIME * 0.009, TIME * 0.014);

    vec3 n_a = texture(ocean_normal, drift_a).rgb;
    vec3 n_b = texture(ocean_normal, drift_b).rgb;
    vec3 blended_normal = normalize(mix(n_a, n_b, 0.48) * 2.0 - 1.0);
    NORMAL_MAP = blended_normal;
    NORMAL_MAP_DEPTH = normal_scale;

    float swell = sin(uv.x * 2.2 + uv.y * 1.35 - TIME * 0.22) * 0.5 + 0.5;
    float secondary_swell = sin(uv.x * 1.15 - uv.y * 2.0 - TIME * 0.15) * 0.5 + 0.5;
    float shallow = clamp(0.22 + UV.y * 0.30 + swell * 0.10, 0.0, 0.66);
    vec3 water = mix(deep_color, shallow_color, shallow);
    vec3 pbr_color = texture(ocean_base_color, drift_a).rgb;
    water = mix(water, pbr_color, 0.22);

    float crest = smoothstep(0.88, 0.98, swell * 0.72 + secondary_swell * 0.28);
    float foam_noise = texture(ocean_roughness, drift_b * 2.8).r;
    float foam = crest * foam_strength * smoothstep(0.20, 0.82, foam_noise);
    water = mix(water, vec3(0.72, 0.83, 0.81), foam);

    // Ecume côtière : ruban irrégulier au contact de l'enrochement de la Baie.
    // La courbe reprend le tracé du rivage construit dans baie_des_rois.gd.
    float coast_t = clamp((world_position.z - (-570.0 - 115.0)) / 230.0, 0.0, 1.0);
    float coast_x = -1790.0 + 38.0 + sin(coast_t * 3.14159265) * 12.0;
    float shore_distance = world_position.x - coast_x;
    float shore_band = 1.0 - smoothstep(4.0, 20.0, shore_distance);
    float shore_variation = 0.68 + 0.32 * sin(world_position.z * 0.72 - TIME * 1.4 + swell * 3.0);
    float shore_foam = shore_band * shore_variation * shoreline_foam_strength;
    water = mix(water, vec3(0.78, 0.86, 0.83), shore_foam);

    // Pluie : petits anneaux lumineux animés, activables depuis le système météo.
    vec2 rain_uv = world_position.xz * 0.42;
    vec2 rain_cell = fract(rain_uv) - 0.5;
    vec2 rain_id = floor(rain_uv);
    float rain_seed = fract(sin(dot(rain_id, vec2(127.1, 311.7))) * 43758.5453);
    float rain_phase = fract(TIME * (0.65 + rain_seed * 0.55) + rain_seed);
    float rain_ring = abs(length(rain_cell) - rain_phase * 0.48);
    float rain_ripple = (1.0 - smoothstep(0.012, 0.045, rain_ring)) * (1.0 - rain_phase) * rain_intensity;
    water = mix(water, vec3(0.48, 0.66, 0.69), rain_ripple * 0.18);

    ALBEDO = water;
    ROUGHNESS = clamp(texture(ocean_roughness, drift_a).r * 0.48 + 0.08, 0.08, 0.42);
    METALLIC = 0.025;
    SPECULAR = 0.82;

    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
    ALBEDO = mix(ALBEDO, vec3(0.20, 0.34, 0.39), fresnel * 0.22);
}
