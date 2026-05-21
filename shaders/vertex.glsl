// shaders/vertex.glsl
// ─────────────────────────────────────────────────────────────
//  Occlusion shader — vertex stage
//  Used by: OCCLUSION_FORWARD pass (Milestone 3+)
//
//  Contract satisfied (contracts/shaderInterface.js → VERTEX_OUTPUTS):
//    vScreenUV    vec2   M3  screen-space UV for depth texture lookup
//    vWorldNormal vec3   M5  world-space normal for lighting
//    vWorldPos    vec3   M5  world-space position
//    vViewDepth   float  M2  camera-space depth for debug HUD
// ─────────────────────────────────────────────────────────────

varying vec2  vScreenUV;
varying vec3  vWorldNormal;
varying vec3  vWorldPos;
varying float vViewDepth;

void main() {

  // ── Standard MVP transform ───────────────────────────────
  vec4 worldPos = modelMatrix * vec4(position, 1.0);
  vec4 clipPos  = projectionMatrix * viewMatrix * worldPos;
  gl_Position   = clipPos;

  // ── Screen UV (M3) ───────────────────────────────────────
  // Perspective divide converts clip coords to NDC [-1, 1].
  // Remap to [0, 1] for texture sampling.
  // This UV is then used in the fragment shader to sample the
  // depth texture at exactly this fragment's screen pixel.
  vScreenUV = (clipPos.xy / clipPos.w) * 0.5 + 0.5;

  // ── World-space outputs (M5) ─────────────────────────────
  vWorldPos    = worldPos.xyz;
  vWorldNormal = normalize(mat3(modelMatrix) * normal);

  // ── Camera-space depth (debug) ───────────────────────────
  // -viewPos.z = positive depth in front of camera
  vec4 viewPos = viewMatrix * worldPos;
  vViewDepth   = -viewPos.z;

}
