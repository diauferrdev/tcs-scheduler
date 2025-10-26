/**
 * GlobeViewer - 3D Earth Globe with TCS Pace Port Locations
 *
 * Based on Babylon.js with WGS-84 coordinate system
 * Displays TCS offices worldwide with color-coded pins
 */

class GlobeViewer {
  constructor(config = {}) {
    this.config = {
      canvasId: 'globeCanvas',
      radius: 1.0,
      showAtmosphere: true,
      enableRotation: true,
      darkMode: false,
      pins: [
        { lat: -22.87, lon: -42.68, altitude: 760, color: [0, 1, 0.5], label: 'São Paulo' },
        { lat: 43.84, lon: -10.86, altitude: 76, color: [0, 1, 1], label: 'Toronto' },
        { lat: 40.82, lon: -16.25, altitude: 10, color: [1, 0.5, 0], label: 'New York' },
        { lat: 40.41, lon: -10.73, altitude: 244, color: [0.5, 1, 0], label: 'Pittsburgh' },
        { lat: 35.89, lon: 130.24, altitude: 40, color: [0, 0.3, 1], label: 'Tokyo' },
        { lat: 51.96, lon: -95.81, altitude: -2, color: [1, 0.3, 0.7], label: 'Amsterdam' },
        { lat: 51.42, lon: -90.02, altitude: 35, color: [1, 0.8, 0], label: 'London' },
        { lat: 48.58, lon: -92.50, altitude: 35, color: [0.5, 0, 1], label: 'Paris' },
        { lat: 1.60, lon: 166.55, altitude: 15, color: [1, 0, 0.5], label: 'Singapore' },
      ],
      ...config
    };

    this.canvas = null;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.globeRoot = null;
    this.isLoaded = false;
    this.texturesToLoad = 0;
    this.texturesLoaded = 0;

    console.log('[GlobeViewer] Initializing with config:', this.config);
    this.init();
  }

  init() {
    // Get canvas
    this.canvas = document.getElementById(this.config.canvasId);
    if (!this.canvas) {
      console.error(`[GlobeViewer] Canvas #${this.config.canvasId} not found!`);
      return;
    }

    console.log('[GlobeViewer] Canvas found, creating engine...');

    // Create engine with balanced settings
    this.engine = new BABYLON.Engine(this.canvas, true, {
      preserveDrawingBuffer: true,
      stencil: true, // Re-enabled for proper rendering
      antialias: true, // Re-enabled for quality
      powerPreference: 'high-performance',
    });

    // Create scene
    this.scene = new BABYLON.Scene(this.engine);
    this.scene.clearColor = new BABYLON.Color4(0, 0, 0, 0);

    // Setup camera
    this.setupCamera();

    // Setup lights
    this.setupLights();

    // Create globe
    this.createGlobe();

    // Place pins
    this.placePins();

    // Start render loop with visibility check
    this.engine.runRenderLoop(() => {
      // CRITICAL: Only render if canvas is actually visible in DOM
      if (!this.canvas || this.canvas.offsetParent === null) {
        // Canvas is hidden (display: none or Offstage) - skip rendering
        return;
      }

      // Also check opacity - skip rendering if invisible (fade-out)
      const opacity = parseFloat(window.getComputedStyle(this.canvas).opacity);
      if (opacity < 0.01) {
        // Canvas is faded out - skip rendering
        return;
      }

      this.scene.render();
    });

    // Handle resize
    window.addEventListener('resize', () => {
      this.engine.resize();
    });

    console.log('[GlobeViewer] ✅ Initialization complete');
  }

  setupCamera() {
    const radius = this.config.radius;
    this.camera = new BABYLON.ArcRotateCamera(
      'camera',
      -Math.PI / 2,
      Math.PI / 3,
      4 * radius,
      BABYLON.Vector3.Zero(),
      this.scene
    );
    this.camera.attachControl(this.canvas, true);
    // Zoom limits: allow small zoom in, no zoom out
    this.camera.lowerRadiusLimit = 3 * radius; // Can zoom in a bit (from 4x to 3x)
    this.camera.upperRadiusLimit = 4 * radius; // No zoom out (locked at starting position)
    this.camera.minZ = 0.01;
    this.camera.maxZ = 1000;
    this.camera.wheelPrecision = 50;
  }

  setupLights() {
    // Directional sunlight
    const sunLight = new BABYLON.DirectionalLight(
      'sun',
      new BABYLON.Vector3(-0.5, -0.3, -1),
      this.scene
    );
    sunLight.intensity = 0.7;
    sunLight.diffuse = new BABYLON.Color3(1, 0.98, 0.95);
    sunLight.specular = new BABYLON.Color3(0.05, 0.05, 0.05);

    // Ambient hemispheric light
    const ambientLight = new BABYLON.HemisphericLight(
      'ambient',
      new BABYLON.Vector3(0, 1, 0),
      this.scene
    );
    ambientLight.intensity = 0.6;
    ambientLight.diffuse = new BABYLON.Color3(0.9, 0.9, 0.9);
    ambientLight.groundColor = new BABYLON.Color3(0.6, 0.6, 0.6);
    ambientLight.specular = new BABYLON.Color3(0, 0, 0);
  }

  checkTextureLoaded() {
    this.texturesLoaded++;
    console.log(`[GlobeViewer] Texture loaded: ${this.texturesLoaded}/${this.texturesToLoad}`);

    if (this.texturesLoaded === this.texturesToLoad && !this.isLoaded) {
      this.isLoaded = true;

      // Now that all textures are loaded, freeze materials for performance
      if (this.earthMaterial) {
        this.earthMaterial.freeze();
        console.log('[GlobeViewer] Earth material frozen after texture load');
      }
      if (this.atmosphereMaterial) {
        this.atmosphereMaterial.freeze();
        console.log('[GlobeViewer] Atmosphere material frozen');
      }
      if (this.cloudsMaterial) {
        this.cloudsMaterial.freeze();
        console.log('[GlobeViewer] Clouds material frozen');
      }

      // Make globe visible and play entrance animation
      if (this.globeRoot) {
        this.globeRoot.setEnabled(true);
        this.playEntranceAnimation();
      }

      console.log('[GlobeViewer] ✅ All textures loaded, playing entrance animation');

      // Call onReady callback if provided
      if (this.config.onReady) {
        this.config.onReady();
      }
    }
  }

  playEntranceAnimation() {
    if (!this.globeRoot) return;

    // Start small and transparent
    this.globeRoot.scaling.setAll(0.5);

    const startTime = performance.now();
    const duration = 1200; // 1.2 seconds

    const animateEntrance = () => {
      const elapsed = performance.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);

      // Easing function (ease-out-cubic)
      const eased = 1 - Math.pow(1 - progress, 3);

      // Scale from 0.5 to 1.0
      const scale = 0.5 + (eased * 0.5);
      this.globeRoot.scaling.setAll(scale);

      if (progress < 1) {
        requestAnimationFrame(animateEntrance);
      }
    };

    animateEntrance();
  }

  createGlobe() {
    const radius = this.config.radius;

    // Globe root transform node
    this.globeRoot = new BABYLON.TransformNode('globeRoot', this.scene);

    // Start invisible until all textures load
    this.globeRoot.setEnabled(false);

    // Create Earth sphere - OPTIMIZED for performance (low poly)
    const globe = BABYLON.MeshBuilder.CreateSphere(
      'earth',
      { diameter: 2 * radius, segments: 32 }, // Reduced to 32 for better performance
      this.scene
    );
    globe.parent = this.globeRoot;

    // Earth material - simplified for performance
    const earthMaterial = new BABYLON.StandardMaterial('earthMaterial', this.scene);

    // Count textures to load (only day and clouds - removing heavy maps)
    this.texturesToLoad = 2;

    // Day map - main Earth texture (using 4K for better performance)
    const dayTexture = new BABYLON.Texture('/textures/Solarsystemscope_texture_8k_earth_daymap.jpg', this.scene);
    dayTexture.vScale = -1;
    dayTexture.uScale = -1;
    dayTexture.onLoadObservable.addOnce(() => this.checkTextureLoaded());
    earthMaterial.diffuseTexture = dayTexture;

    // Simplified specular (no texture, just color)
    earthMaterial.specularPower = 64;
    earthMaterial.specularColor = new BABYLON.Color3(0.1, 0.1, 0.1);

    globe.material = earthMaterial;

    // Store references for freezing after texture load
    this.earthMaterial = earthMaterial;

    // Atmosphere - optimized
    if (this.config.showAtmosphere) {
      const atmosphere = BABYLON.MeshBuilder.CreateSphere(
        'atmosphere',
        { diameter: 2 * radius * 1.025, segments: 24 }, // Heavily reduced for performance
        this.scene
      );
      atmosphere.parent = this.globeRoot;

      const atmosphereMaterial = new BABYLON.StandardMaterial('atmosphereMaterial', this.scene);
      atmosphereMaterial.diffuseColor = new BABYLON.Color3(0.5, 0.7, 1.0);
      atmosphereMaterial.alpha = 0.08;
      atmosphereMaterial.backFaceCulling = false;
      atmosphere.material = atmosphereMaterial;

      // Store reference for freezing after texture load
      this.atmosphereMaterial = atmosphereMaterial;
    }

    // Clouds layer - optimized
    const clouds = BABYLON.MeshBuilder.CreateSphere(
      'clouds',
      { diameter: 2 * radius * 1.01, segments: 24 }, // Heavily reduced for performance
      this.scene
    );
    clouds.parent = this.globeRoot;

    const cloudsMaterial = new BABYLON.StandardMaterial('cloudsMaterial', this.scene);
    const cloudsTexture = new BABYLON.Texture('/textures/Solarsystemscope_texture_8k_earth_clouds.jpg', this.scene);
    cloudsTexture.vScale = -1;
    cloudsTexture.uScale = -1;
    cloudsTexture.onLoadObservable.addOnce(() => this.checkTextureLoaded());
    cloudsMaterial.diffuseTexture = cloudsTexture;
    cloudsMaterial.opacityTexture = cloudsTexture;
    cloudsMaterial.emissiveColor = new BABYLON.Color3(0.1, 0.1, 0.1);
    cloudsMaterial.alpha = 0.3; // 50% more transparent (was 0.6)
    cloudsMaterial.backFaceCulling = false;
    cloudsMaterial.useAlphaFromDiffuseTexture = true;
    clouds.material = cloudsMaterial;

    // Store references for freezing after texture load
    this.clouds = clouds;
    this.cloudsMaterial = cloudsMaterial;

    // Auto-rotation with consistent speed using delta time
    if (this.config.enableRotation) {
      this.scene.registerBeforeRender(() => {
        // Get delta time in seconds for frame-rate independent rotation
        const deltaTime = this.engine.getDeltaTime() / 1000;

        // Rotation speed: radians per second (0.12 = ~7 seconds per full rotation)
        const earthSpeed = 0.12 * deltaTime;

        this.globeRoot.rotation.y += earthSpeed;
        // Rotate clouds only 0.5% faster than Earth - barely perceptible
        if (this.clouds) {
          this.clouds.rotation.y += earthSpeed * 0.5; // Just 0.5% faster
        }
      });
    }
  }

  geoToPosition(lat, lon, altitude = 0) {
    // WGS-84 ellipsoid parameters
    const a = 6378137.0; // Semi-major axis in meters
    const f = 1 / 298.257223563; // Flattening
    const e2 = f * (2 - f); // First eccentricity squared

    // Convert to radians
    const latRad = (lat * Math.PI) / 180;
    const lonRad = (lon * Math.PI) / 180;

    // Calculate radius of curvature
    const sinLat = Math.sin(latRad);
    const N = a / Math.sqrt(1 - e2 * sinLat * sinLat);

    // Calculate ECEF coordinates
    const X = (N + altitude) * Math.cos(latRad) * Math.cos(lonRad);
    const Y = (N + altitude) * Math.cos(latRad) * Math.sin(lonRad);
    const Z = (N * (1 - e2) + altitude) * sinLat;

    // Convert to Babylon.js coordinates
    // Babylon: +Y = up (North), +Z = forward (Greenwich), +X = right (East)
    // ECEF: X = Greenwich, Y = 90°E, Z = North
    const metersPerUnit = a / this.config.radius;
    return new BABYLON.Vector3(
      Y / metersPerUnit,
      Z / metersPerUnit,
      X / metersPerUnit
    );
  }

  surfaceNormal(lat, lon) {
    const latRad = (lat * Math.PI) / 180;
    const lonRad = (lon * Math.PI) / 180;

    return new BABYLON.Vector3(
      Math.cos(latRad) * Math.sin(lonRad),
      Math.sin(latRad),
      Math.cos(latRad) * Math.cos(lonRad)
    ).normalize();
  }

  placePins() {
    this.config.pins.forEach(pin => {
      this.placePin(pin);
    });
  }

  placePin(pin) {
    const { lat, lon, altitude = 0, color, label } = pin;
    const pos = this.geoToPosition(lat, lon, altitude);
    const up = this.surfaceNormal(lat, lon);
    const radius = this.config.radius;

    // Pin container
    const pinContainer = new BABYLON.TransformNode(`pin_${label}`, this.scene);
    pinContainer.parent = this.globeRoot;
    pinContainer.position = pos;

    // Pin shaft (thin stick)
    const shaftHeight = 0.15 * radius;
    const shaft = BABYLON.MeshBuilder.CreateCylinder(
      `shaft_${label}`,
      { height: shaftHeight, diameter: 0.004 * radius, tessellation: 6 },
      this.scene
    );
    shaft.parent = pinContainer;

    // Pin head (sphere on top)
    const headDiameter = 0.06 * radius;
    const head = BABYLON.MeshBuilder.CreateSphere(
      `head_${label}`,
      { diameter: headDiameter, segments: 16 },
      this.scene
    );
    head.parent = shaft;
    head.position.y = shaftHeight / 2;

    // Halo/glow
    const haloDiameter = 0.09 * radius;
    const halo = BABYLON.MeshBuilder.CreateSphere(
      `halo_${label}`,
      { diameter: haloDiameter, segments: 12 },
      this.scene
    );
    halo.parent = shaft;
    halo.position.y = shaftHeight / 2;

    // Align shaft with surface normal
    const yAxis = new BABYLON.Vector3(0, 1, 0);
    const rotationAxis = BABYLON.Vector3.Cross(yAxis, up);
    const angle = Math.acos(BABYLON.Vector3.Dot(yAxis, up));
    if (rotationAxis.length() > 0.001) {
      shaft.rotationQuaternion = BABYLON.Quaternion.RotationAxis(rotationAxis.normalize(), angle);
    }

    // Materials with office colors
    const pinColor = new BABYLON.Color3(color[0], color[1], color[2]);

    const pinMat = new BABYLON.StandardMaterial(`pinMat_${label}`, this.scene);
    pinMat.diffuseColor = pinColor;
    pinMat.emissiveColor = pinColor.scale(0.8);
    pinMat.specularColor = pinColor.scale(0.5);
    shaft.material = pinMat;
    head.material = pinMat;

    const haloMat = new BABYLON.StandardMaterial(`haloMat_${label}`, this.scene);
    haloMat.diffuseColor = pinColor;
    haloMat.emissiveColor = pinColor.scale(0.6);
    haloMat.alpha = 0.4;
    haloMat.backFaceCulling = false;
    halo.material = haloMat;

    // Gentle floating animation
    let floatTime = Math.random() * Math.PI * 2;
    this.scene.registerBeforeRender(() => {
      floatTime += 0.003;
      const floatOffset = Math.sin(floatTime) * 0.008 * radius;

      // Intelligent scaling based on camera distance
      const cameraDistance = BABYLON.Vector3.Distance(this.camera.position, BABYLON.Vector3.Zero());
      const minDist = 1.5 * radius;
      const minScale = 0.3;
      const scale = minScale + (cameraDistance - minDist) * 0.15;

      shaft.scaling.set(scale, scale, scale);
      head.scaling.setAll(scale);
      halo.scaling.setAll(scale * 1.08);
    });
  }

  /**
   * Pause rendering to save performance (soft pause - stops render loop)
   */
  pause() {
    if (!this.engine) return;

    console.log(`[GlobeViewer] ⏸️ Pausing viewer: ${this.config.canvasId}`);

    // Stop render loop
    this.engine.stopRenderLoop();

    this.isPaused = true;
  }

  /**
   * Resume rendering (if not disposed)
   */
  resume() {
    if (this.isDisposed) {
      // Re-initialize if disposed
      console.log(`[GlobeViewer] ♻️ Re-initializing disposed viewer: ${this.config.canvasId}`);
      this.isDisposed = false;
      this.init();
      return;
    }

    if (!this.engine || !this.scene) return;

    console.log(`[GlobeViewer] ▶️ Resuming viewer: ${this.config.canvasId}`);

    // Restart render loop with visibility check
    this.engine.runRenderLoop(() => {
      // CRITICAL: Only render if canvas is actually visible in DOM
      if (!this.canvas || this.canvas.offsetParent === null) {
        // Canvas is hidden (display: none or Offstage) - skip rendering
        return;
      }

      // Also check opacity - skip rendering if invisible (fade-out)
      const opacity = parseFloat(window.getComputedStyle(this.canvas).opacity);
      if (opacity < 0.01) {
        // Canvas is faded out - skip rendering
        return;
      }

      this.scene.render();
    });

    this.isPaused = false;
  }

  /**
   * Dispose engine and scene to free memory/CPU (aggressive optimization)
   */
  dispose() {
    if (!this.engine || this.isDisposed) {
      console.log(`[GlobeViewer] ⚠️ Already disposed or no engine: ${this.config.canvasId}`);
      return;
    }

    console.log(`[GlobeViewer] 🗑️ Starting disposal: ${this.config.canvasId}`);

    const memoryBefore = this.scene ? this.scene.totalVertices : 0;

    // Stop render loop
    this.engine.stopRenderLoop();
    console.log(`[GlobeViewer]   ✓ Render loop stopped`);

    // Dispose scene and all meshes/materials
    if (this.scene) {
      const meshCount = this.scene.meshes.length;
      const materialCount = this.scene.materials.length;
      const textureCount = this.scene.textures.length;

      console.log(`[GlobeViewer]   📊 Disposing: ${meshCount} meshes, ${materialCount} materials, ${textureCount} textures`);

      this.scene.dispose();
      this.scene = null;
      console.log(`[GlobeViewer]   ✓ Scene disposed (freed ${memoryBefore} vertices)`);
    }

    // Dispose engine and WebGL context
    if (this.engine) {
      this.engine.dispose();
      this.engine = null;
      console.log(`[GlobeViewer]   ✓ Engine disposed (WebGL context released)`);
    }

    // Clear all references
    this.globeRoot = null;
    this.clouds = null;
    this.camera = null;
    this.earthMaterial = null;
    this.atmosphereMaterial = null;
    this.cloudsMaterial = null;
    this.nightTexture = null;

    this.isDisposed = true;
    this.isLoaded = false;
    this.texturesLoaded = 0;
    this.isPaused = false;

    console.log(`[GlobeViewer] ✅ FULLY DISPOSED: ${this.config.canvasId} - Memory should be freed`);
  }
}

// Expose to window for Flutter
if (typeof window !== 'undefined') {
  window.GlobeViewer = GlobeViewer;
  console.log('[GlobeViewer] ✅ Class exposed to window');
}
