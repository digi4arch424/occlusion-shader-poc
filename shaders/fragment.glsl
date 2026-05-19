// ─────────────────────────────────────────────────────────────
//  fragment.glsl
//  Occlusion Shader PoC — Core Fragment Shader
//
//  Milestone progression:
//    M3  →  depth sampling + linearisation (debug output)
//    M4  →  occlusion test   (green = visible, red = occluded)
//    M5  →  visual effects   (fade + glow pulse)
//    M6  →  stress test      (same shader, more occluders)
// ─────────────────────────────────────────────────────────────

precision highp float;

// ── Varyings from vertex shader ───────────────────────────────
varying vec2  vScreenUV;
varying vec3  vWorldNormal;
varying vec3  vWorldPos;
varying float vViewDepth;

// ── Uniforms ──────────────────────────────────────────────────
uniform sampler2D uDepthTexture;   // pre-rendered scene depth (Pass 1)
uniform vec2      uResolution;     // viewport size in pixels
uniform float     uCameraNear;     // camera.near
uniform float     uCameraFar;      // camera.far
uniform float     uTime;           // elapsed seconds (for pulse effect)
uniform vec3      uBaseColor;      // object's base diffuse colour
uniform vec3      uLightDir;       // normalised key light direction
uniform float     uDepthBias;      // small offset to prevent self-occlusion

// ── Utility: linearise a raw depth buffer sample ─────────────
//
//  Raw depth is stored as a non-linear (perspective-hyperbolic)
//  value in [0, 1].  We convert to a linear camera-space distance
//  so that fragDepth > sceneDepth is a meaningful comparison.
//
//  Formula derivation:
//    NDC z  = rawDepth * 2.0 - 1.0
//    linearZ = (2 * near * far) / (far + near - NDC_z * (far - near))
//
float lineariseDepth(float rawDepth, float near, float far) {
  float ndcZ = rawDepth * 2.0 - 1.0;
  return (2.0 * near * far) / (far + near - ndcZ * (far - near));
}

// ── Utility: simple diffuse + ambient shading ─────────────────
vec3 shadeSurface(vec3 baseColor, vec3 normal, vec3 lightDir) {
  float NdotL   = max(dot(normalize(normal), normalize(lightDir)), 0.0);
  vec3  diffuse = baseColor * NdotL;
  vec3  ambient = baseColor * 0.25;
  return ambient + diffuse;
}

// ─────────────────────────────────────────────────────────────
void main() {

  // ── STEP 1: Sample pre-rendered scene depth ───────────────
  //
  //  vScreenUV was computed in the vertex shader from clip coords.
  //  We use it to look up the depth value that was written during
  //  Pass 1 (renderer.setRenderTarget(depthTarget)).
  //
  float rawSceneDepth = texture2D(uDepthTexture, vScreenUV).r;
  float sceneDepth    = lineariseDepth(rawSceneDepth, uCameraNear, uCameraFar);

  // ── STEP 2: Compute this fragment's linear depth ──────────
  //
  //  gl_FragCoord.z is the fragment's raw NDC depth [0,1].
  //  We linearise it the same way for an apples-to-apples compare.
  //
  float rawFragDepth = gl_FragCoord.z;
  float fragDepth    = lineariseDepth(rawFragDepth, uCameraNear, uCameraFar);

  // ── STEP 3: Occlusion test ────────────────────────────────
  //
  //  If this fragment is further from the camera than what was
  //  rendered in Pass 1, something is in front of it → occluded.
  //
  //  uDepthBias (≈ 0.02) prevents self-occlusion z-fighting.
  //
  bool occluded = fragDepth > sceneDepth + uDepthBias;

  // occludedFactor: smooth 0.0 (visible) → 1.0 (fully occluded)
  // Using step() here; swap for smoothstep() for a soft edge.
  float occludedFactor = step(1.0, float(occluded));

  // ── STEP 4: Shading ───────────────────────────────────────
  vec3 shadedColor = shadeSurface(uBaseColor, vWorldNormal, uLightDir);

  // ── STEP 5: Visual effect ─────────────────────────────────
  //
  //  Visible  → normal shading, full opacity
  //  Occluded → desaturated + pulsing red-orange glow + fade
  //
  float pulse     = 0.55 + 0.45 * sin(uTime * 3.2);
  vec3  glowColor = vec3(1.0, 0.25 + pulse * 0.15, 0.05);

  // Blend base shading with glow based on occlusion
  vec3 finalColor = mix(shadedColor, glowColor * pulse, occludedFactor * 0.85);

  // Fade out when occluded (alpha drops to ~0.18 so it's still hinted)
  float alpha = mix(1.0, 0.18, occludedFactor);

  // ── DEBUG MODE ────────────────────────────────────────────
  //  Uncomment ONE of these to debug individual stages:
  //
  //  (a) Raw depth texture:
  //      gl_FragColor = vec4(vec3(rawSceneDepth), 1.0);
  //
  //  (b) Linear depth (normalised for display):
  //      gl_FragColor = vec4(vec3(fragDepth / uCameraFar), 1.0);
  //
  //  (c) Hard occlusion:
  //      gl_FragColor = occluded
  //        ? vec4(1.0, 0.1, 0.1, 1.0)
  //        : vec4(0.1, 1.0, 0.4, 1.0);
  //      return;

  gl_FragColor = vec4(finalColor, alpha);
}
