# 🔭 WebGL Occlusion Shader — Three.js PoC

> A progressive, milestone-driven proof-of-concept implementing **screen-space occlusion detection** using custom GLSL shaders and Three.js depth buffer access. Built as a verified stepping stone toward a production BIM overlay pipeline. No ML, no physics engines, no external render frameworks — pure WebGL.

![Three.js](https://img.shields.io/badge/Three.js-r128-black?logo=three.js)
![WebGL](https://img.shields.io/badge/WebGL-2.0-red?logo=webgl)
![GLSL](https://img.shields.io/badge/GLSL-ES300-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 📺 Live Demo

Hosted on GitHub Pages — no build step, no install, no local server required.

Live site: https://digi4arch424.github.io/occlusion-shader-poc/

---

## 🎯 What This Demonstrates

A **depth-based occlusion shader** that:

1. Renders occluder geometry to an off-screen depth texture (Pass 1)
2. Passes that texture as a uniform into a custom fragment shader (Pass 2)
3. Compares each fragment's depth against the sampled scene depth per frame
4. Fades and pulses the overlay element when it is behind a surface

The sphere represents a **BIM overlay element** — a pipe, duct, or structural member. The boxes represent **physical world surfaces**. The shader asks one question per pixel per frame: *is there a real surface closer to the camera than this overlay element?*

---

## 🏗 Production Pipeline Architecture

### The PoC canvas is a depth source simulator

This canvas exists to simulate what a real pipeline hands the shader. In production the canvas is removed entirely. The shader receives:

```
Input:  depth texture        ← from depth estimation system
        screen-space UV      ← from host renderer
Output: occlusion factor     → drives BIM overlay opacity / highlight
```

### The real pipeline

```
┌────────────────────────┐       depth texture      ┌──────────────────────┐
│  Depth Estimation      │ ───────────────────────► │  Occlusion Shader    │
│  (separate system)     │                           │  (this PoC)          │
│                        │                           │                      │
│  video frame → depth   │                           │  sample → compare    │
│  not our concern here  │                           │  → occlusion factor  │
└────────────────────────┘                           └──────────────────────┘
         +                                                    +
┌────────────────────────┐                           ┌──────────────────────┐
│  Video Stream          │ ── background layer ────► │  BIM Overlay         │
│  (host application)    │                           │  rendered on top     │
└────────────────────────┘                           └──────────────────────┘
```

The occlusion shader's public interface is defined entirely by its uniforms — `uDepthTexture`, `uDepthBias`. Everything else is internal implementation that disappears when it moves to production.

### Single WebGL context — recommended

For this pipeline, a **single WebGL context with a unified render graph** is the correct architectural choice. The requirements that mandate it:

| Requirement | Why single context is needed |
|---|---|
| Frame-perfect compositing | Video frame and BIM overlay must be composited in the same render tick — separate contexts cannot guarantee synchronisation |
| Shared camera model | VPS → scene transform must be applied to both the depth prepass and the BIM overlay geometry from a single camera matrix |
| Shared depth / occlusion logic | The depth texture produced in Pass 1 must be readable in Pass 2 — this requires shared GPU memory, only possible in the same context |
| Synchronised per-frame updates | `uTime`, camera uniforms, and depth texture must all update atomically in a single `requestAnimationFrame` — two contexts have independent loops |

**The isolation risk:** if both pipelines share the same WebGL context, they share the GPU memory budget. Expensive work in the host application (high-resolution video decoding, complex BIM geometry) reduces the budget available to the occlusion shader. This must be profiled during integration.

---

## ⚡ Performance Recommendations for Production

When the occlusion shader is plugged into a real BIM model, the number of overlay elements can reach into the thousands. Three optimisations should be treated as requirements, not afterthoughts.

### 1. Instancing — highest priority

If many BIM elements share the same geometry (all circular pipes, all rectangular ducts, all I-beams), they can be batched into a **single draw call** regardless of count using `THREE.InstancedMesh`.

```
Without instancing:  1000 pipes = 1000 draw calls per frame
With instancing:     1000 pipes = 1 draw call per frame
```

Each instance can carry its own transform and a custom attribute for per-element occlusion state. The occlusion shader runs once per fragment across all instances — the GPU handles the parallelism.

```js
// Example: 1000 pipe instances, one draw call
const instancedPipes = new THREE.InstancedMesh(pipeGeometry, occlusionMaterial, 1000);
```

### 2. Frustum culling

Only draw BIM elements that fall within the camera's current view frustum. Elements outside the frame contribute zero visible pixels but still cost draw calls if not culled.

Three.js applies frustum culling automatically to standard meshes. For instanced geometry, per-instance culling requires a custom implementation or a library such as `three-instanced-mesh`.

**Rule of thumb:** a large BIM model viewed from any single camera position typically has 60–80% of its elements outside the frustum. Culling them is free performance.

### 3. Level of Detail (LOD)

Distant BIM elements can use simplified geometry with fewer triangles. A pipe 50 metres away does not need 48 radial segments — 8 segments are visually indistinguishable at that distance but cost 6× fewer triangles.

```js
const lod = new THREE.LOD();
lod.addLevel(highDetailPipe, 0);    // < 10m: full geometry
lod.addLevel(medDetailPipe,  10);   // 10–30m: reduced
lod.addLevel(lowDetailPipe,  30);   // > 30m: minimal
```

The occlusion shader is unaffected by LOD changes — it operates on screen-space depth, not on geometry complexity.

---

## 📐 Interface Contracts

All data boundaries between JavaScript and GLSL, and between render passes, are defined in `contracts/` **before any implementation is written**.

### Shader Uniforms

| Uniform | GLSL Type | Since | Purpose |
|---|---|---|---|
| `uDepthTexture` | `sampler2D` | M2 | Pre-rendered scene depth (Pass 1 output) |
| `uResolution` | `vec2` | M3 | Viewport size — updated on resize |
| `uCameraNear` | `float` | M3 | Camera near clip — required for linearisation |
| `uCameraFar` | `float` | M3 | Camera far clip — required for linearisation |
| `uDepthBias` | `float` | M4 | Prevents edge flickering at depth discontinuities |
| `uTime` | `float` | M5 | Elapsed seconds — drives glow pulse |
| `uBaseColor` | `vec3` | M5 | Overlay diffuse colour |
| `uLightDir` | `vec3` | M5 | World-space key light direction |

### Render Pass Contracts

```
DEPTH_PREPASS
  renders:  occluder geometry only (BIM overlay elements excluded)
  produces: depth_texture
       ↓
OCCLUSION_FORWARD
  consumes: depth_texture
  renders:  full scene including BIM overlay elements
  produces: colour_buffer → screen
```

### Why BIM overlay elements are excluded from Pass 1

BIM overlay elements are **depth consumers**, not depth contributors. They read from the depth texture to determine their own visibility. Including them in the pass that writes the depth texture creates a GPU read/write conflict on the same texture — the driver silently drops their depth writes.

This is architecturally correct: the depth texture represents the physical world. BIM elements are not part of the physical world — they are overlaid onto it.

---

## 🧭 Milestone Structure

Six milestones, each gated by a locked acceptance checklist defined in `contracts/milestoneInterface.js`.

```
M1 ──► M2 ──► M3 ──► M4 ──► M5 ──► M6
 ↓      ↓      ↓      ↓      ↓      ↓
Scene  Depth  Shader  Detect Effect Stress
       Buf    Access
```

---

### 🟢 M1 — Basic 3D Scene ✅
Perspective camera · manual orbit controls · sphere (BIM overlay) + cube (occluder) · 4-light rig · no shaders.

### 🟡 M2 — Depth Buffer Visualisation ✅
`WebGLRenderTarget` + `DepthTexture` · two-pass frame loop · greyscale debug quad · D key toggle.

### 🟠 M3 — Screen-Space Depth Access ✅
Sphere → `ShaderMaterial` · `vScreenUV` from clip coords · depth sampled and linearised per fragment · shader architecture separated into three boot phases.

### 🔴 M4 — Occlusion Detection Logic ✅
`fragDepth > sceneDepth + uDepthBias` · `depthTest: false` on overlay material (GPU must not discard fragments before shader runs) · green = visible, red = occluded.

### 🔵 M5 — Visual Effects Layer ✅
Diffuse + ambient shading for visible state · `smoothstep` replaces hard bool · pulsing warm glow + alpha fade when occluded · `uTime`, `uBaseColor`, `uLightDir` uniforms.

### 🟣 M6 — Stress Test ✅
6 occluders (3 rotating) · sphere on Lissajous path · auto-orbiting camera (Space to toggle) · performance HUD: frame time, fps, draw calls, triangles.

---

## 📁 Project Structure

```
occlusion-shader-poc/
│
├── index.html                    ← Entry point — always current milestone
├── README.md
│
├── contracts/                    ← Interfaces defined before implementation
│   ├── shaderInterface.js        ← Uniform + varying contracts; validateUniforms()
│   ├── renderPassInterface.js    ← Pass producer/consumer pairs; FRAME_LOOP map
│   └── milestoneInterface.js     ← Per-milestone acceptance checklists
│
├── shaders/
│   ├── vertex.glsl               ← vScreenUV, vWorldNormal, vViewDepth
│   ├── fragment.glsl             ← depth sample → linearise → occlude → effect
│   ├── debug.vert.glsl           ← fullscreen quad passthrough
│   └── debug.frag.glsl           ← linearised depth as tinted greyscale
│
└── utils/
    ├── depthUtils.js             ← createDepthTarget(), resizeDepthTarget()
    └── orbitControls.js          ← Manual orbit/pan/zoom — no external dependency
```

---

## 🔧 Technical Notes

### Why linearise depth?
Raw depth buffer values are non-linear. A direct comparison would produce incorrect results at depth discontinuities. Both values must be converted to linear camera-space metres before comparing.

```
linearZ = (2 · near · far) / (far + near − NDC_z · (far − near))
  where NDC_z = rawDepth × 2 − 1
```

### Why `depthTest: false` on the overlay material?
Hardware depth testing discards fragments **before** the fragment shader runs. If the overlay is behind an occluder, its fragments would be thrown away before the occlusion test could execute. The shader must own the visibility decision — `depthTest: false` delegates that responsibility from the GPU to the GLSL code.

### Why exclude the overlay from Pass 1?
The overlay reads from the depth texture in its fragment shader. Rendering it during the pass that writes to that texture creates a GPU read/write conflict. The driver silently drops the overlay's depth writes. Solution: `sphere.visible = false` during Pass 1, `true` during Pass 2.

---

## 🚀 Deployment

Push to `main` → GitHub Pages serves automatically. No build step.

```bash
git add .
git commit -m "your message"
git push
```

---

## 🧠 Further Reading

- [Learn OpenGL — Depth Testing](https://learnopengl.com/Advanced-OpenGL/Depth-testing)
- [Three.js — WebGLRenderTarget](https://threejs.org/docs/#api/en/renderers/WebGLRenderTarget)
- [Three.js — InstancedMesh](https://threejs.org/docs/#api/en/objects/InstancedMesh)
- [Inigo Quilez — Depth Buffer Tricks](https://iquilezles.org/articles/hwinterpolation/)
- [Real-Time Rendering — Visibility & Occlusion](https://www.realtimerendering.com/)

---

## 📄 License

MIT — use freely, attribution appreciated.

---

*Every implementation detail in this repo was derived from an explicit interface contract. If something is not in `contracts/`, it should not exist in code.*
