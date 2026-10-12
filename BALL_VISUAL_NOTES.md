# Pool Club - rolling ball appearance

The balls are drawn by `shaders/billiard_ball.gdshader` via procedural Sprite2D instances created in `scripts/pool_board.gd`. No external image textures or third-party shaders are needed.

- Colored stripes now occupy roughly 20 percent of the visible diameter, and follow the sphere instead of being drawn as rectangles.
- Each ball tracks a quaternion `roll` orientation in `scripts/pool_physics.gd` based on its actual distance travelled.
- Tiny engraved pigment marks on solids, cue ball and eight ball make their rotation readable without adding numbers.
- Rim shading, warm specular lighting and felt contact shadows distinguish the balls from Carrom disks.
- A very subtle fast-motion shadow streak helps read rapid shots, without a distracting motion blur.
- The shot controls, physics constants, CPU, rules, sound, HUD and eight table appearances are preserved.

Adjust the stripe thickness in the shader's `smoothstep(0.185, 0.220, latitude)` line. Lower both values for a thinner band (for example, 0.15 and 0.18).
