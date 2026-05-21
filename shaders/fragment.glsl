// shaders/fragment.glsl
// ─────────────────────────────────────────────────────────────
//  Occlusion shader — fragment stage
//  Used by: OCCLUSION_FORWARD pass (Milestone 3+)
//
//  Milestone progression (add one thing per milestone):
//    M3  depth sampling + linearisation → debug colour output
//    M4  occlusion test → green / red
//    M5  visual effects → fade + glow pulse
//
//  Contract satisfied (contracts/shaderInterface.js → FRAGMENT_UNIFORMS):
//    uDepthTexture  sampler2D  M2  pre-rendered scene depth
//    uResolution    vec2       M3  viewport size in pixels
//    uCameraNear    float      M3  camera near clip
//    uCameraFar     float      M3  camera far clip
//    uDepthBias     float      M4  self-occlusion guard (added at M4)
//    uTime          float      M5  elapsed seconds for pulse (added at M5)
//    uBaseColor     vec3       M5  diffuse colour (added at M5)
//    uLightDir      vec3       M5  key light direction (added at M5)
// ─────────────────────────────────────────────────────────────

precision highp float;

// ── Uniforms (M3) ────────────────────────────────────────────
uniform sampler2D uDepthTexture;
uniform vec2      uResolution;
uniform float     uCameraNear;
uniform float     uCameraFar;

// ── Varyings from vertex shader ──────────────────────────────
varying vec2  vScreenUV;
varying vec3  vWorldNormal;
varying vec3  vWorldPos;
varying float vViewDepth;

// ── Linearise depth ──────────────────────────────────────────
// Raw depth buffer values are non-linear (hyperbolic) — more
// precision near the camera, less far away. Both fragDepth and
// sceneDepth must be linearised before comparison, otherwise
// the test produces incorrect results at depth discontinuities.
//
// Formula: linearZ = (2·near·far) / (far + near − NDC_z·(far − near))
//          where NDC_z = raw × 2.0 − 1.0
float lineariseDepth(float raw) {
  float z = raw * 2.0 - 1.0;
  return (2.0 * uCameraNear * uCameraFar)
       / (uCameraFar + uCameraNear - z * (uCameraFar - uCameraNear));
}

void main() {

  // ── STEP 1: Sample scene depth at this screen position ────
  // vScreenUV is the perspective-correct screen UV computed
  // in the vertex shader from clip coords.
  // We sample the depth texture that was written in DEPTH_PREPASS.
  float rawScene   = texture2D(uDepthTexture, vScreenUV).r;
  float sceneDepth = lineariseDepth(rawScene);

  // ── STEP 2: This fragment's own linear depth ──────────────
  // gl_FragCoord.z is the raw NDC depth [0,1] of this fragment.
  float rawFrag  = gl_FragCoord.z;
  float fragDepth = lineariseDepth(rawFrag);

  // ── M3 DEBUG OUTPUT ───────────────────────────────────────
  // Visualise the scene depth sampled at the sphere's screen UV.
  // This proves vScreenUV is correctly computed — the depth
  // values shown on the sphere surface must make spatial sense
  // relative to what the camera can see.
  //
  // When the cube is between camera and sphere:
  //   → sampled sceneDepth = cube depth (shallow = warm/bright)
  // When the sphere is fully visible:
  //   → sampled sceneDepth = sphere depth (deeper = cooler)
  //
  // Orbit the camera around — the surface colouring must update
  // correctly. That proves depth sampling is working.

  float norm       = clamp(sceneDepth / uCameraFar, 0.0, 1.0);
  float brightness = 1.0 - norm;

  // Tinted gradient: warm yellow (near/shallow) → cool blue (far/deep)
  vec3 nearTint = vec3(1.00, 0.85, 0.20);
  vec3 farTint  = vec3(0.05, 0.15, 0.45);
  vec3 color    = mix(farTint, nearTint, brightness);

  // Subtle sphere surface contour lines to confirm it's 3D, not a flat quad
  float contour = abs(sin(fragDepth * 2.5)) * 0.08;
  color += contour;

  gl_FragColor = vec4(color, 1.0);

  // ── DEBUG SWITCHES ────────────────────────────────────────
  // Uncomment one at a time to isolate variables:

  // (a) Show only this fragment's own depth:
  // gl_FragColor = vec4(vec3(1.0 - fragDepth / uCameraFar), 1.0);

  // (b) Show only sampled scene depth:
  // gl_FragColor = vec4(vec3(1.0 - sceneDepth / uCameraFar), 1.0);

  // (c) Show vScreenUV directly (UV coordinates as RG):
  // gl_FragColor = vec4(vScreenUV, 0.0, 1.0);

}
