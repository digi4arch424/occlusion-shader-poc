// ─────────────────────────────────────────────────────────────
//  vertex.glsl
//  Occlusion Shader PoC — Shared Vertex Shader
//
//  Milestones that use this:
//    M3  →  passes vScreenUV for depth texture sampling
//    M4  →  same, occlusion logic lives in fragment.glsl
//    M5  →  adds vWorldNormal for lighting blend
// ─────────────────────────────────────────────────────────────

varying vec2  vScreenUV;    // screen-space UV for depth texture lookup
varying vec3  vWorldNormal; // world-space normal for shading
varying vec3  vWorldPos;    // world-space position
varying float vViewDepth;   // linear camera-space depth (debug)

void main() {

  // Standard MVP transform
  vec4 worldPosition = modelMatrix * vec4(position, 1.0);
  vec4 clipPosition  = projectionMatrix * viewMatrix * worldPosition;

  gl_Position = clipPosition;

  // ── Screen UV ─────────────────────────────────────────────
  // Perspective-correct screen UV from clip coords.
  // Used to sample the pre-rendered depth texture in the
  // fragment shader at exactly this fragment's screen pixel.
  vScreenUV = (clipPosition.xy / clipPosition.w) * 0.5 + 0.5;

  // ── World-space outputs ───────────────────────────────────
  vWorldPos    = worldPosition.xyz;
  vWorldNormal = normalize(mat3(modelMatrix) * normal);

  // ── Camera-space depth (for debug) ───────────────────────
  // Negative Z in Three.js view space = in front of camera
  vec4 viewPos = viewMatrix * worldPosition;
  vViewDepth   = -viewPos.z;  // positive = in front of camera

}
