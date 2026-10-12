shader_type canvas_item;
render_mode unshaded;

// Small, glossy, painted resin spheres. The pigment follows the actual roll;
// light and the contact shadow stay fixed in table coordinates.
uniform vec4 ball_color : source_color = vec4(0.85, 0.24, 0.18, 1.0);
uniform int ball_kind = 0;  // 0 solid, 1 stripe, 2 cue, 3 eight
uniform vec4 ball_spin = vec4(0.0, 0.0, 0.0, 1.0); // world orientation quaternion

vec3 sphere_local(vec3 n) {
    // Quaternion inverse rotates the exposed hemisphere into paint space.
    vec3 q = -ball_spin.xyz;
    return n + 2.0 * cross(q, cross(q, n) + ball_spin.w * n);
}

float round_mark(vec3 surface, vec3 axis, float soft_radius) {
    return smoothstep(soft_radius - 0.010, soft_radius + 0.004, dot(surface, normalize(axis)));
}

void fragment() {
    vec2 xy = UV * 2.0 - vec2(1.0);
    float r = length(xy);
    if (r > 1.04) { discard; }

    // The silhouette is softened by one screen pixel, not a blurred texture.
    float feather = max(fwidth(r) * 0.65, 0.011);
    float coverage = 1.0 - smoothstep(1.0 - feather, 1.0 + feather, r);
    if (coverage < 0.004) { discard; }

    vec3 normal = normalize(vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy)))));
    vec3 paint = normalize(sphere_local(normal));
    vec3 cream = vec3(0.963, 0.945, 0.889);
    vec3 color = ball_color.rgb;

    if (ball_kind == 1) {
        // A genuinely narrow painted latitude on the sphere, not a flat box.
        // The stripe rolls over the near and far hemispheres as the ball moves.
        // A slight latitude tilt is important: otherwise rolling in one
        // common direction could spin around the stripe's symmetry axis,
        // making it visually motionless despite real sphere rotation.
        float latitude = abs(dot(paint, normalize(vec3(0.10, 0.95, 0.30))));
        float band = 1.0 - smoothstep(0.185, 0.220, latitude);
        color = mix(cream, color, band);
        float band_edge = (1.0 - smoothstep(0.210, 0.238, latitude)) * smoothstep(0.15, 0.19, latitude);
        color *= 1.0 - band_edge * 0.085;
        // A tiny maker's dot travels with the colored band; no ball numbers.
        float pip = round_mark(paint, vec3(0.23, 0.02, 0.973), 0.993);
        color = mix(color, cream, pip * band * 0.81);
    } else if (ball_kind == 2) {
        color = cream * vec3(1.01, 1.0, 0.987);
        // Restrained chalk / seam marking makes cue-ball spin perceptible.
        float cue_pip = round_mark(paint, vec3(-0.20, -0.12, 0.97), 0.990);
        color = mix(color, vec3(0.64, 0.76, 0.75), cue_pip * 0.65);
        float cue_dot = round_mark(paint, vec3(0.46, 0.22, 0.86), 0.996);
        color = mix(color, vec3(0.72, 0.75, 0.72), cue_dot * 0.31);
    } else if (ball_kind == 3) {
        color = vec3(0.085, 0.104, 0.108);
        // Ivory accent in place of an 8 numeral.
        float button = round_mark(paint, vec3(-0.13, 0.07, 0.98), 0.964);
        float inner = round_mark(paint, vec3(-0.13, 0.07, 0.98), 0.992);
        color = mix(color, vec3(0.86, 0.82, 0.68), button);
        color = mix(color, vec3(0.12, 0.14, 0.15), inner);
    } else {
        // A subtle enamel inlay on solids is what makes their rolling readable.
        float pip = round_mark(paint, vec3(-0.18, -0.08, 0.98), 0.987);
        float core = round_mark(paint, vec3(-0.18, -0.08, 0.98), 0.995);
        color = mix(color, cream, pip * 0.91);
        color = mix(color, ball_color.rgb * 0.80, core * 0.45);
        float second = round_mark(paint, vec3(0.56, 0.33, 0.76), 0.997);
        color = mix(color, cream, second * 0.52);
    }

    // Fixed soft room lighting: highlights do not rotate with the paint.
    vec3 light = normalize(vec3(-0.54, -0.66, 0.90));
    float diffuse = max(dot(normal, light), 0.0);
    float ambient = 0.55 + diffuse * 0.39;
    ambient *= mix(0.70, 1.0, smoothstep(0.0, 0.65, normal.z));
    ambient *= 1.0 - 0.075 * smoothstep(0.43, 1.0, xy.y);
    vec3 shaded = color * ambient;

    vec3 half_vector = normalize(light + vec3(0.0, 0.0, 1.0));
    float highlight = max(dot(normal, half_vector), 0.0);
    float glossy = pow(highlight, 48.0) * 0.30 + pow(highlight, 12.0) * 0.055;
    vec3 highlight_color = vec3(1.0, 0.985, 0.91);
    shaded += highlight_color * glossy;
    // Tidy dark meniscus at the outer lip; no hard ink outline.
    shaded *= 1.0 - 0.20 * smoothstep(0.87, 0.997, r);

    COLOR = vec4(clamp(shaded, vec3(0.0), vec3(1.0)), coverage);
}
