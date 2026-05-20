// shaders/debug.vert.glsl
// ─────────────────────────────────────────────────────────────
//  Debug depth pass — vertex shader
//  Used by: DEBUG_DEPTH pass (Milestone 2+)
//
//  Paired with an OrthographicCamera(-1,1,1,-1,0,1) and a
//  PlaneGeometry(2,2) so the quad fills NDC exactly.
//  No MVP transform needed — position is already in NDC.
// ─────────────────────────────────────────────────────────────

varying vec2 vUv;

void main() {
  vUv         = uv;
  gl_Position = vec4(position, 1.0);
}
