# 🔭 WebGL Occlusion Shader — Three.js PoC

> A progressive, milestone-driven proof-of-concept implementing **screen-space occlusion detection** using custom GLSL shaders and Three.js depth buffer access. No ML, no physics engines, no external render frameworks — pure WebGL.

![Three.js](https://img.shields.io/badge/Three.js-r128-black?logo=three.js)
![WebGL](https://img.shields.io/badge/WebGL-2.0-red?logo=webgl)
![GLSL](https://img.shields.io/badge/GLSL-ES300-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 📺 Live Demo

Open `index.html` directly in a browser — no build step required.

```bash
git clone https://github.com/YOUR_USERNAME/occlusion-shader-poc
cd occlusion-shader-poc
open index.html           # macOS
# or serve locally to avoid CORS on shader file imports:
python3 -m http.server 8080   # → http://localhost:8080
```

---

## 🎯 What This Demonstrates

A **depth-based occlusion shader** that:

1. Renders the full scene to an off-screen depth texture (Pass 1)
2. Passes that texture as a uniform into a custom fragment shader (Pass 2)
3. Compares each fragment's reconstructed depth against the sampled scene depth
4. Applies a visual effect when the fragment is behind something else

The sphere **fades out and glows** when hidden behind the cube, and returns to full shading when visible — driven purely by shader logic, not CPU raycasting.

---

## 📐 Interface Contracts

All data boundaries between JavaScript and GLSL, and between render passes, are defined in `contracts/` **before any implementation is written**. The code must satisfy the contracts; the contracts do not follow from the code.

### Shader Uniforms

Every uniform the fragment shader may read is declared in `contracts/shaderInterface.js`:

| Uniform | GLSL Type | Since | Purpose |
|---|---|---|---|
| `uDepthTexture` | `sampler2D` | M2 | Pre-rendered scene depth (Pass 1 output) |
| `uResolution` | `vec2` | M3 | Viewport size in pixels — must update on resize |
| `uCameraNear` | `float` | M3 | Camera near clip — required to linearise depth |
| `uCameraFar` | `float` | M3 | Camera far clip — required to linearise depth |
| `uDepthBias` | `float` | M4 | Small offset preventing self-occlusion z-fighting |
| `uTime` | `float` | M5 | Elapsed seconds, drives glow pulse |
| `uBaseColor` | `vec3` | M5 | Object diffuse colour |
| `uLightDir` | `vec3` | M5 | World-space key light direction |

`validateUniforms(material.uniforms, 'M4')` throws at init time if any required uniform for the current milestone is missing — wiring bugs are caught before the first frame renders.

### Vertex → Fragment Varyings

| Varying | Type | Since | Purpose |
|---|---|---|---|
| `vScreenUV` | `vec2` | M3 | Screen-space UV for depth texture lookup |
| `vWorldNormal` | `vec3` | M5 | Surface normal for diffuse shading |
| `vWorldPos` | `vec3` | M5 | World position for lighting |
| `vViewDepth` | `float` | M2 | Camera-space depth for debug HUD |

### Render Pass Contracts

Every pass is defined in `contracts/renderPassInterface.js` as a **producer/consumer pair**. No pass may read a resource it has not declared as consumed.

```
DEPTH_PREPASS
  consumes: [scene_geometry]
  produces: [depth_texture]
       ↓
OCCLUSION_FORWARD
  consumes: [depth_texture, scene_geometry]
  produces: [colour_buffer → screen]
```

**Frame loop by milestone** (authoritative — changing execution order requires updating the contract first):

| Milestone | Pass 1 | Pass 2 |
|---|---|---|
| M1 | `FORWARD` | — |
| M2 | `DEPTH_PREPASS` | `DEBUG_DEPTH` |
| M3 – M6 | `DEPTH_PREPASS` | `OCCLUSION_FORWARD` |

---

## 🧭 Milestone Structure

Six milestones, each gated by a locked acceptance checklist. A milestone is complete only when every check passes — not when the code "looks right."

```
M1 ──► M2 ──► M3 ──► M4 ──► M5 ──► M6
 ↓      ↓      ↓      ↓      ↓      ↓
Scene  Depth  Shader  Detect Effect Stress
       Buf    Access
```

---

### 🟢 Milestone 1 — Basic 3D Scene

**Acceptance checks** (`contracts/milestoneInterface.js → M1`):

```
☐  WebGLRenderer created and canvas mounted to DOM
☐  Scene contains at least 2 Mesh objects
☐  Sphere mesh present at Z < 0 (behind cube)
☐  Cube mesh present at origin
☐  PerspectiveCamera FOV 60, near 0.05, far 300
☐  At least 2 light sources in scene
☐  Camera position changes on mouse/touch drag
☐  requestAnimationFrame loop running (FPS > 0)
☐  No ShaderMaterial or RawShaderMaterial in scene
```

**Scene objects:**

| Object | Role | Material |
|--------|------|----------|
| Sphere (green) | Occlusion *target* | `MeshStandardMaterial` |
| Cube (blue) | *Occluder* | `MeshStandardMaterial` |

Perspective camera (FOV 60°) · Manual orbit controls (no external lib) · 4-light rig: ambient + PCF shadow key + rim + bounce · Grid floor, fog, live FPS + camera position HUD.

---

### 🟡 Milestone 2 — Depth Buffer Visualisation

**Acceptance checks:**

```
☐  WebGLRenderTarget created with depthTexture attached
☐  depthTexture uses DepthFormat + UnsignedShortType
☐  Scene renders to depthTarget before screen pass
☐  Full-screen debug quad renders greyscale depth
☐  Closer objects are brighter in debug view
☐  D key toggles debug depth view on/off
☐  depthTarget resizes correctly with window
```

**Depth target configuration** (`contracts/renderPassInterface.js → depth_texture`):

```js
const depthTexture = new THREE.DepthTexture(W, H);
depthTexture.type      = THREE.UnsignedShortType;
depthTexture.format    = THREE.DepthFormat;
depthTexture.minFilter = THREE.NearestFilter;
depthTexture.magFilter = THREE.NearestFilter;
```

A full-screen quad samples this texture and linearises it for display:

```glsl
float linearDepth(float d, float near, float far) {
  float z = d * 2.0 - 1.0;
  return (2.0 * near * far) / (far + near - z * (far - near));
}
```

---

### 🟠 Milestone 3 — Screen-Space Depth Access

**Acceptance checks:**

```
☐  Sphere uses ShaderMaterial (not MeshStandardMaterial)
☐  uDepthTexture, uResolution, uCameraNear, uCameraFar all set
☐  vScreenUV computed from clip coords in vertex shader
☐  Fragment shader reads texture2D(uDepthTexture, vScreenUV)
☐  lineariseDepth() applied to both raw samples
☐  Debug mode outputs depth visualisation on sphere surface
```

**Screen UV derivation** (vertex shader — satisfies `VERTEX_OUTPUTS.vScreenUV` contract):

```glsl
vec4 clipPos  = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
gl_Position   = clipPos;
vScreenUV     = (clipPos.xy / clipPos.w) * 0.5 + 0.5;
```

---

### 🔴 Milestone 4 — Occlusion Detection Logic

**Acceptance checks:**

```
☐  Sphere fragment is red when behind cube
☐  Sphere fragment is green when in front
☐  uDepthBias prevents self-occlusion at sphere surface
☐  Colour is stable — no per-frame flickering at edges
☐  Partially occluded sphere shows split green/red
☐  Occlusion state updates correctly as camera orbits
```

**Core occlusion rule** (`shaders/fragment.glsl` — implements M4 contract):

```glsl
float fragDepth  = lineariseDepth(gl_FragCoord.z,                       uCameraNear, uCameraFar);
float sceneDepth = lineariseDepth(texture2D(uDepthTexture, vScreenUV).r, uCameraNear, uCameraFar);

bool occluded = fragDepth > sceneDepth + uDepthBias;

gl_FragColor = occluded
  ? vec4(1.0, 0.1, 0.1, 1.0)   // red   — occluded
  : vec4(0.1, 1.0, 0.4, 1.0);  // green — visible
```

---

### 🔵 Milestone 5 — Visual Effects Layer

**Acceptance checks:**

```
☐  Hard red/green debug colours replaced by effect
☐  Sphere alpha < 0.3 when fully occluded
☐  Glow intensity oscillates with sin(uTime)
☐  Visible state uses proper diffuse + ambient shading
☐  Transition between states is smooth, not a hard cut
```

**Effect logic** (satisfies `FRAGMENT_UNIFORMS.uTime` and `uBaseColor` contracts):

```glsl
float pulse      = 0.55 + 0.45 * sin(uTime * 3.2);
vec3  glowColor  = vec3(1.0, 0.25 + pulse * 0.15, 0.05);
vec3  finalColor = mix(shadedColor, glowColor * pulse, occludedFactor * 0.85);
float alpha      = mix(1.0, 0.18, occludedFactor);
```

---

### 🟣 Milestone 6 — Stress Test Scene

**Acceptance checks:**

```
☐  At least 5 occluder boxes in scene
☐  Sphere follows Lissajous path in real time
☐  Camera auto-orbits (Space to toggle)
☐  Frame time ≤ 16.7 ms at 1080p (60 fps target)
☐  No z-fighting or depth inversion under motion
☐  On-screen draw calls + triangle count displayed
```

---

## 📁 Project Structure

```
occlusion-shader-poc/
│
├── index.html                    ← Entry point; milestone selector UI
├── README.md
│
├── contracts/                    ← Interfaces defined before implementation
│   ├── shaderInterface.js        ← Uniform + varying contracts; validateUniforms()
│   ├── renderPassInterface.js    ← Pass producer/consumer pairs; FRAME_LOOP map
│   └── milestoneInterface.js     ← Per-milestone acceptance checklists; printContract()
│
├── shaders/
│   ├── vertex.glsl               ← Position, vScreenUV, vWorldNormal, vViewDepth
│   └── fragment.glsl             ← Depth sample → linearise → occlude → effect
│
└── utils/
    ├── depthUtils.js             ← createDepthTarget(), resizeDepthTarget(), lineariseDepth()
    └── orbitControls.js          ← Manual orbit/pan/zoom; no external dependency
```

---

## 🔧 Technical Deep-Dive

### Why two render passes?

The depth texture must be fully populated **before** the sphere's fragment shader runs — otherwise the sphere would sample a depth buffer that doesn't yet include the occluder. Splitting into a depth pre-pass and a forward pass is the minimal correct architecture:

```
Frame N:
  [1] setRenderTarget(depthTarget) → render all geometry → depth_texture is complete
  [2] setRenderTarget(null)        → render scene → sphere reads from complete depth_texture
```

### Why linearise depth?

Raw depth buffer values follow a hyperbolic curve (more precision near the camera, less far away). A direct `rawFragDepth > rawSceneDepth` comparison gives incorrect results at depth discontinuities. Linearising both values to camera-space metres makes the comparison consistent across the frustum.

```
linearZ = (2 · near · far) / (far + near − NDC_z · (far − near))
  where  NDC_z = rawDepth × 2 − 1
```

### Why a depth bias?

The sphere's surface sits at exactly `fragDepth ≈ sceneDepth` — it self-occludes without a small tolerance added to `sceneDepth`. The default bias `0.02` is a named constant in `contracts/shaderInterface.js`, not a magic number in the shader.

---

## 🚀 Getting Started

**Requirements:** Any WebGL 2 browser (Chrome 56+, Firefox 51+, Safari 15+). No Node.js, no npm, no build tools.

```bash
# Option A — direct file open
open index.html

# Option B — local server (required if loading .glsl files as ES modules)
python3 -m http.server 8080

# Option C — VS Code Live Server
# Right-click index.html → "Open with Live Server"
```

**Controls:**

| Input | Action |
|-------|--------|
| Left drag | Orbit camera |
| Right drag | Pan camera |
| Scroll / Pinch | Zoom |
| `D` | Toggle depth debug view |
| `M` | Cycle milestones |
| `Space` | Pause / resume animation |

---

## 🧠 Further Reading

- [Learn OpenGL — Depth Testing](https://learnopengl.com/Advanced-OpenGL/Depth-testing)
- [Three.js — WebGLRenderTarget](https://threejs.org/docs/#api/en/renderers/WebGLRenderTarget)
- [GLSL — Built-in Variables](https://www.khronos.org/opengl/wiki/Built-in_Variable_(GLSL))
- [Inigo Quilez — Depth Buffer Tricks](https://iquilezles.org/articles/hwinterpolation/)
- [Real-Time Rendering — Visibility & Occlusion](https://www.realtimerendering.com/)

---

## 📄 License

MIT — use freely, attribution appreciated.

---

*Every implementation detail in this repo was derived from an explicit interface contract. If something is not in `contracts/`, it should not exist in code.*
