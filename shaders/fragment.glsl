// shaders/fragment.glsl
// ─────────────────────────────────────────────────────────────
//  Occlusion shader — fragment stage
//  Used by: OCCLUSION_FORWARD pass (Milestone 3+)
//
//  Milestone progression:
//    M3  depth sampling + linearisation
//    M4  occlusion test → green / red
//    M5  visual effects → proper shading + fade + glow pulse
//
//  Production role:
//    Consumes depth from host pipeline.
//    Modifies BIM overlay appearance per fragment per frame.
//    Does not produce depth. Does not own the canvas.
//
//  Contract (contracts/shaderInterface.js → FRAGMENT_UNIFORMS):
//    uDepthTexture  sampler2D  M3
//    uResolution    vec2       M3
//    uCameraNear    float      M3
//    uCameraFar     float      M3
//    uDepthBias     float      M4
//    uTime          float      M5  ← added this milestone
//    uBaseColor     vec3       M5  ← added this milestone
//    uLightDir      vec3       M5  ← added this milestone
// ─────────────────────────────────────────────────────────────

precision highp float;

// ── Uniforms ─────────────────────────────────────────────────
uniform sampler2D uDepthTexture;
uniform vec2      uResolution;
uniform float     uCameraNear;
uniform float     uCameraFar;
uniform float     uDepthBias;
uniform float     uTime;       // M5: elapsed seconds — drives pulse
uniform vec3      uBaseColor;  // M5: overlay diffuse colour
uniform vec3      uLightDir;   // M5: world-space key light direction

// ── Varyings ─────────────────────────────────────────────────
varying vec2  vScreenUV;
varying vec3  vWorldNormal;
varying vec3  vWorldPos;
varying float vViewDepth;

// ── Linearise depth ──────────────────────────────────────────
float lineariseDepth(float raw) {
  float z = raw * 2.0 - 1.0;
  return (2.0 * uCameraNear * uCameraFar)
       / (uCameraFar + uCameraNear - z * (uCameraFar - uCameraNear));
}

// ── Diffuse + ambient shading ─────────────────────────────────
vec3 shadeSurface(vec3 baseColor, vec3 normal, vec3 lightDir) {
  float NdotL  = max(dot(normalize(normal), normalize(lightDir)), 0.0);
  vec3  diffuse = baseColor * NdotL;
  vec3  ambient = baseColor * 0.28;
  return ambient + diffuse;
}

void main() {

  // ── Depth sampling (M3) ───────────────────────────────────
  float rawScene   = texture2D(uDepthTexture, vScreenUV).r;
  float sceneDepth = lineariseDepth(rawScene);
  float fragDepth  = lineariseDepth(gl_FragCoord.z);

  // ── Occlusion factor (M5 — replaces M4 hard bool) ────────
  // smoothstep produces a soft ramp rather than a hard cut.
  // At the boundary (fragDepth ≈ sceneDepth + bias): factor = 0
  // Fully behind occluder (fragDepth >> sceneDepth): factor = 1
  // The transition width is 5× the bias — wide enough to be
  // smooth, narrow enough to stay spatially accurate.
  float occludedFactor = smoothstep(
    0.0,
    uDepthBias * 5.0,
    fragDepth - (sceneDepth + uDepthBias)
  );

  // ── M5: Visible state — proper surface shading ────────────
  // When fully visible (occludedFactor = 0) the overlay looks
  // like a real 3D object with diffuse + ambient lighting.
  // In production this would match the BIM element's material.
  vec3 shadedColor = shadeSurface(uBaseColor, vWorldNormal, uLightDir);

  // ── M5: Occluded state — pulsing glow ─────────────────────
  // When behind a surface the overlay signals its presence
  // with a warm pulsing glow — visible but clearly different
  // from the fully-lit state.
  //
  // pulse: oscillates between 0.1 and 1.0 at ~0.5 Hz
  // The overlay "breathes" to draw the eye without being jarring.
  float pulse     = 0.55 + 0.45 * sin(uTime * 3.2);
  vec3  glowColor = vec3(1.0, 0.30 + pulse * 0.12, 0.05);

  // ── M5: Blend between states ──────────────────────────────
  // Visible (0) → full shading
  // Occluded (1) → glow at pulse intensity
  vec3  finalColor = mix(shadedColor, glowColor * pulse, occludedFactor * 0.9);

  // Alpha: full opacity when visible, nearly transparent when
  // occluded — the overlay ghosts through the surface rather
  // than disappearing entirely.
  // In production this threshold is a design parameter
  // (how strongly should hidden BIM elements show through?).
  float alpha = mix(1.0, 0.15, occludedFactor);

  gl_FragColor = vec4(finalColor, alpha);

  // ── DEBUG SWITCHES ────────────────────────────────────────
  // Step back through milestones one at a time:

  // (M4) Hard red/green — confirm occlusion boundary is correct:
  // bool occluded = fragDepth > sceneDepth + uDepthBias;
  // gl_FragColor = occluded
  //   ? vec4(0.9, 0.08, 0.08, 1.0)
  //   : vec4(0.08, 0.9, 0.35, 1.0);

  // (M3) Sampled scene depth as warm/cool tint:
  // float norm = clamp(sceneDepth / uCameraFar, 0.0, 1.0);
  // gl_FragColor = vec4(mix(vec3(0.15,0.28,0.60), vec3(1.0,0.85,0.20), 1.0-norm), 1.0);
}
