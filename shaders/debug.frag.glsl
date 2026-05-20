// shaders/debug.frag.glsl
// ─────────────────────────────────────────────────────────────
//  Debug depth pass — fragment shader
//  Used by: DEBUG_DEPTH pass (Milestone 2+)
//
//  Samples the raw (non-linear) depth texture produced by
//  DEPTH_PREPASS, converts it to linear camera-space depth,
//  normalises by far, then outputs a tinted greyscale:
//
//    closer → brighter / warm white
//    farther → darker  / cool blue-black
//
//  This is debug output only — not part of occlusion logic.
// ─────────────────────────────────────────────────────────────

precision highp float;

uniform sampler2D uDepthTexture;
uniform float     uNear;
uniform float     uFar;

varying vec2 vUv;

// Convert raw depth buffer value [0,1] to linear camera-space depth (metres).
// Raw depth is hyperbolic — more precision near the camera, less far away.
// Linearising is required before any depth comparison in M3+.
//
// Formula: linearZ = (2 * near * far) / (far + near - NDC_z * (far - near))
//          where NDC_z = raw * 2.0 - 1.0
float lineariseDepth(float raw) {
  float z = raw * 2.0 - 1.0;
  return (2.0 * uNear * uFar) / (uFar + uNear - z * (uFar - uNear));
}

void main() {
  float raw        = texture2D(uDepthTexture, vUv).r;
  float linZ       = lineariseDepth(raw);
  float norm       = clamp(linZ / uFar, 0.0, 1.0);

  // Invert: closer = higher brightness
  float brightness = 1.0 - norm;

  // Tint: warm near, cool far — easier to read than flat greyscale
  vec3 nearTint = vec3(1.00, 0.95, 0.85);
  vec3 farTint  = vec3(0.05, 0.10, 0.20);
  vec3 color    = mix(farTint, nearTint, brightness);

  gl_FragColor = vec4(color, 1.0);
}
