// utils/orbitControls.js
// ─────────────────────────────────────────────────────────────
//  Lightweight orbit controls — no external dependency.
//
//  One job: translate mouse / touch input into spherical
//  coordinates, then write camera.position from them.
//
//  No scene knowledge. No Three.js scene/mesh imports.
//  Only needs: camera (THREE.Camera) + domElement (canvas).
//
//  Controls:
//    Left drag   → orbit
//    Right drag  → pan
//    Scroll      → zoom
//    Two fingers → pinch zoom
// ─────────────────────────────────────────────────────────────

/**
 * @param {THREE.PerspectiveCamera} camera
 * @param {HTMLCanvasElement}       domElement
 * @param {Object}                  options
 * @param {number}  options.theta     Initial horizontal angle (rad). Default 0.3
 * @param {number}  options.phi       Initial vertical angle   (rad). Default PI/5
 * @param {number}  options.radius    Initial distance from target.   Default 14
 * @param {Object}  options.target    Initial look-at point { x, y, z }.
 * @param {number}  options.minPhi    Minimum phi (clamp). Default 0.08
 * @param {number}  options.maxPhi    Maximum phi (clamp). Default PI - 0.08
 * @param {number}  options.minRadius Minimum zoom distance.  Default 2
 * @param {number}  options.maxRadius Maximum zoom distance.  Default 80
 * @returns {{ update: Function, state: Object }}
 */
export function createOrbitControls(camera, domElement, options = {}) {

  const state = {
    theta:  options.theta  ?? 0.3,
    phi:    options.phi    ?? Math.PI / 5,
    radius: options.radius ?? 14,
    target: options.target ?? { x: 0, y: 0, z: 0 },

    // Internal drag tracking — not part of public API
    _leftDown:  false,
    _rightDown: false,
    _lastX: 0,
    _lastY: 0,
  };

  const minPhi    = options.minPhi    ?? 0.08;
  const maxPhi    = options.maxPhi    ?? Math.PI - 0.08;
  const minRadius = options.minRadius ?? 2;
  const maxRadius = options.maxRadius ?? 80;

  // ── Core update — call after any state change ─────────────
  function update() {
    const { theta, phi, radius, target } = state;
    camera.position.set(
      target.x + radius * Math.sin(phi) * Math.sin(theta),
      target.y + radius * Math.cos(phi),
      target.z + radius * Math.sin(phi) * Math.cos(theta)
    );
    camera.lookAt(target.x, target.y, target.z);
  }

  // ── Mouse ─────────────────────────────────────────────────
  domElement.addEventListener('mousedown', e => {
    if (e.button === 0) state._leftDown  = true;
    if (e.button === 2) state._rightDown = true;
    state._lastX = e.clientX;
    state._lastY = e.clientY;
  });

  domElement.addEventListener('contextmenu', e => e.preventDefault());

  window.addEventListener('mouseup', () => {
    state._leftDown = state._rightDown = false;
  });

  window.addEventListener('mousemove', e => {
    const dx = e.clientX - state._lastX;
    const dy = e.clientY - state._lastY;
    state._lastX = e.clientX;
    state._lastY = e.clientY;

    if (state._leftDown) {
      state.theta -= dx * 0.006;

      // FIX: phi - dy (not + dy).
      // dy > 0 means mouse moved DOWN. Subtracting moves the
      // camera upward (phi decreases toward top of sphere),
      // which matches conventional viewport drag behaviour —
      // dragging down tilts the view to look downward at the scene.
      state.phi = Math.max(minPhi, Math.min(maxPhi,
                  state.phi - dy * 0.006));
      update();
    }

    if (state._rightDown) {
      // Pan: move target in the camera's local XY plane
      const panSpeed = state.radius * 0.001;

      // Derive right vector from camera forward × world up
      const fx = camera.position.x - state.target.x;
      const fz = camera.position.z - state.target.z;
      const len = Math.sqrt(fx * fx + fz * fz) || 1;

      // right = normalised(-fz, 0, fx)  (forward × Y)
      const rx = -fz / len;
      const rz =  fx / len;

      state.target.x += (rx * dx - 0) * panSpeed;
      state.target.z += (rz * dx)     * panSpeed;
      state.target.y -= dy            * panSpeed;
      update();
    }
  });

  domElement.addEventListener('wheel', e => {
    e.preventDefault();
    state.radius = Math.max(minRadius, Math.min(maxRadius,
                   state.radius + e.deltaY * 0.025));
    update();
  }, { passive: false });

  // ── Touch ─────────────────────────────────────────────────
  let _lastTouchDist = 0;

  domElement.addEventListener('touchstart', e => {
    if (e.touches.length === 1) {
      state._leftDown = true;
      state._lastX = e.touches[0].clientX;
      state._lastY = e.touches[0].clientY;
    }
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      _lastTouchDist = Math.sqrt(dx * dx + dy * dy);
    }
  }, { passive: true });

  domElement.addEventListener('touchend', () => {
    state._leftDown = false;
  }, { passive: true });

  domElement.addEventListener('touchmove', e => {
    if (e.touches.length === 1 && state._leftDown) {
      const dx = e.touches[0].clientX - state._lastX;
      const dy = e.touches[0].clientY - state._lastY;

      state.theta -= dx * 0.006;
      state.phi = Math.max(minPhi, Math.min(maxPhi,
                  state.phi - dy * 0.006));   // same fix applied

      state._lastX = e.touches[0].clientX;
      state._lastY = e.touches[0].clientY;
      update();
    }

    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.sqrt(dx * dx + dy * dy);

      state.radius = Math.max(minRadius, Math.min(maxRadius,
                     state.radius * (_lastTouchDist / dist)));
      _lastTouchDist = dist;
      update();
    }
  }, { passive: true });

  // Set initial camera position
  update();

  return { update, state };
}
