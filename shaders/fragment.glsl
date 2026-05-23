// shaders/fragment.glsl
// ─────────────────────────────────────────────────────────────
//  Occlusion shader — fragment stage
//  Used by: OCCLUSION_FORWARD pass (Milestone 3+)
//
//  Milestone progression (add one thing per milestone):
//    M3  depth sampling + linearisation → debug colour output
//    M4  occlusion test → visible (green) / occluded (red)
//    M5  visual effects → fade + glow pulse
//
//  Production role:
//    This shader represents the BIM overlay element.
//    It consumes depth information produced externally.
//    It does not produce depth. It only asks one question
//    per fragment: "is something physical in front of me?"
//
//  Contract (contracts/shaderInterface.js → FRAGMENT_UNIFORMS):
//    uDepthTexture  sampler2D  M2  scene depth from DEPTH_PREPASS
//    uResolution    vec2       M3  viewport size in pixels
//    uCameraNear    float      M3  camera near clip
//    uCameraFar     float      M3  camera far clip
//    uDepthBias     float      M4  edge flickering guard
//    uTime          float      M5  elapsed seconds for pulse
//    uBaseColor     vec3       M5  overlay diffuse colour
//    uLightDir      vec3       M5  key light direction
// ─────────────────────────────────────────────────────────────

precision highp float;

// ── Uniforms ─────────────────────────────────────────────────
uniform sampler2D uDepthTexture;  // M3
uniform vec2      uResolution;    // M3
uniform float     uCameraNear;    // M3
uniform float     uCameraFar;     // M3
uniform float     uDepthBias;     // M4 — added this milestone

// ── Varyings from vertex.glsl ────────────────────────────────
varying vec2  vScreenUV;
varying vec3  vWorldNormal;
varying vec3  vWorldPos;
varying float vViewDepth;

// ── Linearise depth ──────────────────────────────────────────
// Raw depth is non-linear (hyperbolic). Both depths must be
// linearised to the same scale before comparing them.
// Without this, the comparison produces wrong results near
// depth discontinuities (edges of occluders).
float lineariseDepth(float raw) {
  float z = raw * 2.0 - 1.0;
  return (2.0 * uCameraNear * uCameraFar)
       / (uCameraFar + uCameraNear - z * (uCameraFar - uCameraNear));
}

void main() {

  // ── STEP 1: Sample scene depth at this screen position ────
  // The depth texture contains occluder depths only (cube, floor).
  // The BIM overlay element (sphere) is excluded from the prepass
  // — it is a consumer of depth, not a contributor to it.
  float rawScene   = texture2D(uDepthTexture, vScreenUV).r;
  float sceneDepth = lineariseDepth(rawScene);

  // ── STEP 2: This fragment's own linear depth ──────────────
  float fragDepth = lineariseDepth(gl_FragCoord.z);

  // ── STEP 3: Occlusion test (M4) ──────────────────────────
  // Core question: is something in the physical scene
  // closer to the camera than this BIM overlay fragment?
  //
  // fragDepth  = how far this overlay pixel is from camera
  // sceneDepth = how far the nearest real surface is at this
  //              screen position (from the depth texture)
  //
  // If the real surface is closer → this pixel is behind it → occluded.
  //
  // uDepthBias: a small tolerance added to sceneDepth.
  // Where the overlay grazes the floor or another surface,
  // floating point precision causes fragDepth ≈ sceneDepth.
  // Without bias those edge pixels flicker between states.
  // The bias ensures a surface has to be meaningfully closer
  // before occlusion is declared.
  bool occluded = fragDepth > sceneDepth + uDepthBias;

  // ── M4 OUTPUT: debug colours ──────────────────────────────
  // Green = visible   (no real surface between camera and overlay)
  // Red   = occluded  (real surface is closer than the overlay)
  //
  // These are intentionally hard colours — easy to verify at a
  // glance that the occlusion boundary is correct before M5
  // replaces them with the production visual effect.
  if (occluded) {
    gl_FragColor = vec4(0.9, 0.08, 0.08, 1.0);  // red  — behind wall
  } else {
    gl_FragColor = vec4(0.08, 0.9, 0.35, 1.0);  // green — visible
  }

  // ── DEBUG SWITCHES ────────────────────────────────────────
  // Uncomment one at a time to step back through milestones:

  // (M3) Scene depth sampled at overlay position:
  // float norm = clamp(sceneDepth / uCameraFar, 0.0, 1.0);
  // gl_FragColor = vec4(mix(vec3(0.15,0.28,0.60), vec3(1.0,0.85,0.20), 1.0-norm), 1.0);

  // (M3) Raw vScreenUV as RG — confirms perspective correction:
  // gl_FragColor = vec4(vScreenUV, 0.0, 1.0);

  // (M4) Soft blend instead of hard cut — preview of M5:
  // float factor = clamp((fragDepth - sceneDepth) / (uDepthBias * 10.0), 0.0, 1.0);
  // gl_FragColor = vec4(mix(vec3(0.08,0.9,0.35), vec3(0.9,0.08,0.08), factor), 1.0);
}
