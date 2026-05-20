// utils/depthUtils.js
// ─────────────────────────────────────────────────────────────
//  Depth render target helpers.
//
//  One job: create and maintain the WebGLRenderTarget that
//  holds the scene depth texture between render passes.
//
//  Relies on global THREE (loaded via CDN script tag before
//  this module is imported).
//
//  Contract satisfied (contracts/renderPassInterface.js):
//    resource: depth_texture
//      type:      THREE.DepthTexture
//      format:    THREE.DepthFormat
//      dataType:  THREE.UnsignedShortType
//      filtering: NearestFilter (both min + mag)
// ─────────────────────────────────────────────────────────────

/**
 * Create a WebGLRenderTarget with an attached DepthTexture.
 * The configuration here is the single source of truth —
 * never duplicate these settings inline in index.html.
 *
 * @param {number} width
 * @param {number} height
 * @returns {{ target: THREE.WebGLRenderTarget, depthTexture: THREE.DepthTexture }}
 */
export function createDepthTarget(width, height) {
  const depthTexture = new THREE.DepthTexture(width, height);
  depthTexture.type      = THREE.UnsignedShortType;
  depthTexture.format    = THREE.DepthFormat;
  depthTexture.minFilter = THREE.NearestFilter;
  depthTexture.magFilter = THREE.NearestFilter;

  const target = new THREE.WebGLRenderTarget(width, height, {
    minFilter:    THREE.NearestFilter,
    magFilter:    THREE.NearestFilter,
    depthTexture: depthTexture,
    depthBuffer:  true,
  });

  return { target, depthTexture };
}

/**
 * Resize an existing depth target to match new viewport dimensions.
 * Call this inside your window resize handler — after resizing
 * the renderer and updating the camera.
 *
 * @param {{ target: THREE.WebGLRenderTarget }} depthObj - return value of createDepthTarget
 * @param {number} width
 * @param {number} height
 */
export function resizeDepthTarget(depthObj, width, height) {
  depthObj.target.setSize(width, height);
}
