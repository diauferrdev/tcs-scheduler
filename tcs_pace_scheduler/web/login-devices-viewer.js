/**
 * Login Devices Viewer - Dual device scene for login page
 * Renders both notebook (below) and phone (above) in same scene
 */

class LoginDevicesViewer {
  constructor(config) {
    this.canvasId = config.canvasId;
    this.brightness = config.brightness || 1.2;
    this.canvas = null;
    this.engine = null;
    this.scene = null;
    this.camera = null;
    this.notebookModel = null;
    this.phoneModel = null;
    this.animations = {
      notebook: null,
      phone: null,
    };

    // Notebook-specific properties
    this.keyMeshes = [];
    this.keyTextMaterials = [];
    this.keyTextMeshes = [];
    this.keyMaterials = [];
    this.notebookBodyMaterials = [];
    this.notebookLidMaterial = null;
    this.notebookLogoMaterial = null;

    console.log('[LoginDevicesViewer] Initializing dual device viewer for canvas:', this.canvasId);
    this.init();
  }

  init() {
    this.canvas = document.getElementById(this.canvasId);
    if (!this.canvas) {
      console.error('[LoginDevicesViewer] Canvas not found:', this.canvasId);
      return;
    }

    // Create engine with antialiasing
    this.engine = new BABYLON.Engine(this.canvas, true, {
      preserveDrawingBuffer: true,
      stencil: true,
      disableWebGL2Support: false,
    });

    this.createScene();
    this.loadDevices();

    // Render loop
    this.engine.runRenderLoop(() => {
      if (this.scene) {
        this.scene.render();
      }
    });

    // Handle window resize
    window.addEventListener('resize', () => {
      this.engine.resize();
    });

    console.log('[LoginDevicesViewer] ✅ Viewer initialized successfully');
  }

  createScene() {
    this.scene = new BABYLON.Scene(this.engine);
    this.scene.clearColor = new BABYLON.Color4(0, 0, 0, 0); // Transparent background

    // Camera - positioned to see both devices from front
    // Using same alpha/beta from device-viewer for consistent orientation
    this.camera = new BABYLON.ArcRotateCamera(
      'camera',
      1.8,          // Alpha (horizontal rotation) - from device-viewer phone config
      1.2,          // Beta (vertical rotation) - from device-viewer
      14,           // Radius (distance from target) - adjusted for dual scene
      new BABYLON.Vector3(0, 2, 0), // Target (look at center point between devices)
      this.scene
    );
    this.camera.attachControl(this.canvas, true);

    // Camera limits
    this.camera.lowerRadiusLimit = 10;
    this.camera.upperRadiusLimit = 20;
    this.camera.lowerBetaLimit = 0.5;
    this.camera.upperBetaLimit = Math.PI / 2;

    // Smooth camera movement
    this.camera.inertia = 0.8;
    this.camera.angularSensibilityX = 2000;
    this.camera.angularSensibilityY = 2000;
    this.camera.wheelPrecision = 50;

    // WASD controls to move camera target (pan the view)
    this.setupCameraTargetControls();

    // Lighting setup - bright and clean
    const hemisphericLight = new BABYLON.HemisphericLight(
      'hemiLight',
      new BABYLON.Vector3(0, 1, 0),
      this.scene
    );
    hemisphericLight.intensity = this.brightness * 0.8;

    // Key light (main)
    const keyLight = new BABYLON.DirectionalLight(
      'keyLight',
      new BABYLON.Vector3(-1, -2, -1),
      this.scene
    );
    keyLight.intensity = this.brightness * 1.2;

    // Fill light (softer, from opposite side)
    const fillLight = new BABYLON.DirectionalLight(
      'fillLight',
      new BABYLON.Vector3(1, -1, 1),
      this.scene
    );
    fillLight.intensity = this.brightness * 0.6;

    // Rim light (from behind)
    const rimLight = new BABYLON.DirectionalLight(
      'rimLight',
      new BABYLON.Vector3(0, -1, 1),
      this.scene
    );
    rimLight.intensity = this.brightness * 0.4;

    console.log('[LoginDevicesViewer] Scene created');
  }

  loadDevices() {
    // Create notebook procedurally
    this.createNotebook();

    // Create phone procedurally
    this.createPhone();

    // Start entrance animation
    this.startEntranceAnimation();

    console.log('[LoginDevicesViewer] ✅ Devices created');
  }

  startEntranceAnimation() {
    console.log('[LoginDevicesViewer] 🎬 Starting combined entrance animations');

    // PHONE: Spiral animation (copied from device-viewer.js)
    // NOTEBOOK: Opening animation (copied from device-viewer.js)

    const duration = 1500;
    const startTime = performance.now();
    const targetNotebookAngle = 85; // Current angle setting

    // PHONE - Spiral setup
    this.phoneModel.visibility = 0;
    this.phoneModel.rotation.set(0, 0, 0);
    this.phoneModel.scaling = new BABYLON.Vector3(0.5, 0.5, 0.5);
    const phoneInitialX = this.phoneModel.position.x;
    const phoneInitialY = this.phoneModel.position.y;

    // NOTEBOOK - Opening setup
    this.notebookModel.visibility = 1;
    this.notebookModel.rotation.set(0, 0, 0);
    this.notebookModel.scaling = new BABYLON.Vector3(1, 1, 1);
    this.notebookModel.position.set(0, 0, 0);
    this.setNotebookAngle(0); // Start closed

    // Camera zoom setup
    const startRadius = this.camera.radius * 1.8;
    const targetRadius = 14;

    const interval = setInterval(() => {
      const elapsed = performance.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);

      // ═══════════════════════════════════════════════════════════
      // PHONE - Spiral animation (from device-viewer entranceSpiral)
      // ═══════════════════════════════════════════════════════════
      this.phoneModel.visibility = Math.max(0, (progress - 0.15) * 1.18);

      const spiralRadius = 5 * (1 - eased);
      const spiralAngle = progress * Math.PI * 4;
      this.phoneModel.position.x = phoneInitialX + Math.cos(spiralAngle) * spiralRadius;
      this.phoneModel.position.y = phoneInitialY + Math.sin(spiralAngle) * spiralRadius;
      this.phoneModel.rotation.y = spiralAngle;
      this.phoneModel.scaling.set(0.5 + 0.5 * eased, 0.5 + 0.5 * eased, 0.5 + 0.5 * eased);

      // ═══════════════════════════════════════════════════════════
      // NOTEBOOK - Opening animation (from device-viewer entranceOpening)
      // ═══════════════════════════════════════════════════════════
      const currentAngle = targetNotebookAngle * eased;
      this.setNotebookAngle(currentAngle);

      // ═══════════════════════════════════════════════════════════
      // CAMERA - Zoom in
      // ═══════════════════════════════════════════════════════════
      this.camera.radius = startRadius + (targetRadius - startRadius) * eased;

      if (progress >= 1) {
        clearInterval(interval);

        // Reset to final state
        this.phoneModel.position.x = phoneInitialX;
        this.phoneModel.position.y = phoneInitialY;
        this.phoneModel.rotation.set(0, 0, 0);
        this.phoneModel.scaling = new BABYLON.Vector3(1, 1, 1);
        this.phoneModel.visibility = 1;

        this.notebookModel.rotation.set(0, 0, 0);
        this.notebookModel.position.set(0, 0, 0);
        this.setNotebookAngle(targetNotebookAngle);

        this.camera.radius = targetRadius;

        console.log('[LoginDevicesViewer] ✅ Combined entrance animations complete');
      }
    }, 16);
  }

  // ==========================================
  // PHONE CREATION (copied from device-viewer.js)
  // ==========================================

  createPhone() {
    this.phoneModel = new BABYLON.TransformNode('phone', this.scene);

    const bodyWidth = 1.5;
    const bodyHeight = 3.0;
    const bodyDepth = 0.09;
    const cornerRadius = 0.15;

    // Body material
    this.bodyMaterial = new BABYLON.PBRMetallicRoughnessMaterial('bodyMaterial', this.scene);
    const rgb = this.hexToRgb('#171717'); // Default dark color
    this.bodyMaterial.baseColor = new BABYLON.Color3(rgb.r, rgb.g, rgb.b);
    this.bodyMaterial.metallic = 0.95;
    this.bodyMaterial.roughness = 0.12;

    // Store reference for color changes
    this.phoneBodyMaterial = this.bodyMaterial;

    // Create phone body
    this.createPhoneBody(bodyWidth, bodyHeight, bodyDepth, cornerRadius);

    // Create screen
    this.createPhoneScreen(bodyWidth, bodyHeight, bodyDepth, cornerRadius);

    // Camera module
    this.createPhoneCameraModule(bodyDepth);

    // Logo (TCS logo on back)
    this.createPhoneLogo(bodyDepth);

    // Side buttons
    this.createPhoneButtons(bodyWidth, bodyHeight, bodyDepth);

    // Front camera
    this.createPhoneFrontCamera(bodyDepth);

    // Position phone above notebook (floating)
    this.phoneModel.position = new BABYLON.Vector3(-2, 4, -1);
    // No manual rotation - let camera position determine front view
    this.phoneModel.rotation = new BABYLON.Vector3(0, 0, 0);

    // Start animation
    this.startPhoneAnimation();

    // Load default video
    this.loadPhoneVideo();
  }

  createPhoneLogo(bodyDepth) {
    const logoUrl = 'assets/Tata_logo.svg';

    const logoPlane = BABYLON.MeshBuilder.CreatePlane('logoPlane', {
      width: 0.32,
      height: 0.28
    }, this.scene);
    logoPlane.position.y = 0;
    logoPlane.position.z = -(bodyDepth / 2) - 0.001;
    logoPlane.parent = this.phoneModel;

    const logoTexture = new BABYLON.Texture(logoUrl, this.scene, false, true);
    logoTexture.hasAlpha = true;

    this.phoneLogoMaterial = new BABYLON.StandardMaterial('logoMaterial', this.scene);
    this.phoneLogoMaterial.diffuseTexture = logoTexture;
    this.phoneLogoMaterial.diffuseTexture.hasAlpha = true;
    this.phoneLogoMaterial.useAlphaFromDiffuseTexture = true;
    this.phoneLogoMaterial.emissiveColor = new BABYLON.Color3(1, 1, 1);
    this.phoneLogoMaterial.specularColor = new BABYLON.Color3(0, 0, 0);
    this.phoneLogoMaterial.backFaceCulling = false;
    this.phoneLogoMaterial.disableLighting = true;
    logoPlane.material = this.phoneLogoMaterial;
  }

  createPhoneBody(bodyWidth, bodyHeight, bodyDepth, cornerRadius) {
    // Main body center
    const bodyCenter = BABYLON.MeshBuilder.CreateBox('bodyCenter', {
      width: bodyWidth - (cornerRadius * 2),
      height: bodyHeight - (cornerRadius * 2),
      depth: bodyDepth
    }, this.scene);
    bodyCenter.parent = this.phoneModel;
    bodyCenter.material = this.bodyMaterial;

    // Top bar
    const bodyTop = BABYLON.MeshBuilder.CreateBox('bodyTop', {
      width: bodyWidth - (cornerRadius * 2),
      height: cornerRadius * 2,
      depth: bodyDepth
    }, this.scene);
    bodyTop.position.y = (bodyHeight / 2) - cornerRadius;
    bodyTop.parent = this.phoneModel;
    bodyTop.material = this.bodyMaterial;

    // Bottom bar
    const bodyBottom = BABYLON.MeshBuilder.CreateBox('bodyBottom', {
      width: bodyWidth - (cornerRadius * 2),
      height: cornerRadius * 2,
      depth: bodyDepth
    }, this.scene);
    bodyBottom.position.y = -(bodyHeight / 2) + cornerRadius;
    bodyBottom.parent = this.phoneModel;
    bodyBottom.material = this.bodyMaterial;

    // Left bar
    const bodyLeft = BABYLON.MeshBuilder.CreateBox('bodyLeft', {
      width: cornerRadius * 2,
      height: bodyHeight - (cornerRadius * 2),
      depth: bodyDepth
    }, this.scene);
    bodyLeft.position.x = -(bodyWidth / 2) + cornerRadius;
    bodyLeft.parent = this.phoneModel;
    bodyLeft.material = this.bodyMaterial;

    // Right bar
    const bodyRight = BABYLON.MeshBuilder.CreateBox('bodyRight', {
      width: cornerRadius * 2,
      height: bodyHeight - (cornerRadius * 2),
      depth: bodyDepth
    }, this.scene);
    bodyRight.position.x = (bodyWidth / 2) - cornerRadius;
    bodyRight.parent = this.phoneModel;
    bodyRight.material = this.bodyMaterial;

    // 4 rounded corners
    const cornerPositions = [
      { x: (bodyWidth / 2) - cornerRadius, y: (bodyHeight / 2) - cornerRadius },
      { x: -(bodyWidth / 2) + cornerRadius, y: (bodyHeight / 2) - cornerRadius },
      { x: (bodyWidth / 2) - cornerRadius, y: -(bodyHeight / 2) + cornerRadius },
      { x: -(bodyWidth / 2) + cornerRadius, y: -(bodyHeight / 2) + cornerRadius }
    ];

    cornerPositions.forEach((pos, index) => {
      const corner = BABYLON.MeshBuilder.CreateCylinder(`corner${index}`, {
        diameter: cornerRadius * 2,
        height: bodyDepth,
        tessellation: 24
      }, this.scene);
      corner.rotation.x = Math.PI / 2;
      corner.position.x = pos.x;
      corner.position.y = pos.y;
      corner.parent = this.phoneModel;
      corner.material = this.bodyMaterial;
    });
  }

  createPhoneScreen(bodyWidth, bodyHeight, bodyDepth, cornerRadius) {
    const screenWidth = bodyWidth - 0.015;
    const screenHeight = bodyHeight - 0.015;
    const screenCornerRadius = cornerRadius;

    this.screenMesh = BABYLON.MeshBuilder.CreatePlane('screen', {
      width: screenWidth,
      height: screenHeight
    }, this.scene);
    this.screenMesh.position.z = (bodyDepth / 2) + 0.001;
    this.screenMesh.parent = this.phoneModel;
    this.screenMesh.scaling.x = -1;

    // Create custom shader for rounded corners
    this.createPhoneScreenShader();

    this.screenMaterial = new BABYLON.ShaderMaterial("roundedScreenMaterial", this.scene, {
      vertex: "roundedScreen",
      fragment: "roundedScreen",
    }, {
      attributes: ["position", "uv"],
      uniforms: ["worldViewProjection", "textureSampler", "emissiveColor", "baseColor", "cornerRadiusX", "cornerRadiusY", "brightness", "hasTexture"],
      needAlphaBlending: true
    });

    // Calculate corner radius in UV space for both X and Y
    const cornerRadiusUVX = (screenCornerRadius / screenWidth) * 0.5;
    const cornerRadiusUVY = (screenCornerRadius / screenHeight) * 0.5;

    this.screenMaterial.setVector3("emissiveColor", new BABYLON.Vector3(0.03, 0.03, 0.04));
    this.screenMaterial.setVector3("baseColor", new BABYLON.Vector3(0.01, 0.01, 0.02));
    this.screenMaterial.setFloat("cornerRadiusX", cornerRadiusUVX);
    this.screenMaterial.setFloat("cornerRadiusY", cornerRadiusUVY);
    this.screenMaterial.setFloat("brightness", this.brightness);
    this.screenMaterial.setInt("hasTexture", 0);
    this.screenMaterial.backFaceCulling = false;
    this.screenMaterial.alphaMode = BABYLON.Engine.ALPHA_COMBINE;

    // Default texture
    const defaultTexture = new BABYLON.DynamicTexture('defaultTexture', 2, this.scene, false);
    const defaultCtx = defaultTexture.getContext();
    defaultCtx.fillStyle = '#010102';
    defaultCtx.fillRect(0, 0, 2, 2);
    defaultTexture.update();
    this.screenMaterial.setTexture("textureSampler", defaultTexture);

    this.screenMesh.material = this.screenMaterial;
  }

  createPhoneScreenShader() {
    BABYLON.Effect.ShadersStore["roundedScreenVertexShader"] = `
      precision highp float;
      attribute vec3 position;
      attribute vec2 uv;
      uniform mat4 worldViewProjection;
      varying vec2 vUV;

      void main(void) {
        gl_Position = worldViewProjection * vec4(position, 1.0);
        vUV = uv;
      }
    `;

    BABYLON.Effect.ShadersStore["roundedScreenFragmentShader"] = `
      precision highp float;
      varying vec2 vUV;
      uniform sampler2D textureSampler;
      uniform vec3 emissiveColor;
      uniform vec3 baseColor;
      uniform float cornerRadiusX;
      uniform float cornerRadiusY;
      uniform float brightness;
      uniform int hasTexture;

      float roundedBoxSDF(vec2 centerPos, vec2 size, float radius) {
        return length(max(abs(centerPos) - size + radius, 0.0)) - radius;
      }

      void main(void) {
        vec2 centered = vUV - 0.5;

        float cornerRadius = 0.07;

        vec2 boxSize = vec2(0.495, 0.495);

        float dist = roundedBoxSDF(centered, boxSize, cornerRadius);
        float alpha = 1.0 - smoothstep(-0.001, 0.001, dist);

        vec3 color;
        if (hasTexture == 1) {
          vec4 texColor = texture2D(textureSampler, vUV);
          color = texColor.rgb * brightness;
        } else {
          color = baseColor + emissiveColor;
        }
        gl_FragColor = vec4(color, alpha);
      }
    `;
  }

  createPhoneCameraModule(bodyDepth) {
    const cameraSize = 0.255;

    const cameraPositions = [
      { x: -0.5, y: 1.25 },
      { x: -0.2, y: 1.25 },
      { x: -0.5, y: 0.96 },
      { x: -0.2, y: 0.96 }
    ];

    const cameraMaterial = new BABYLON.PBRMetallicRoughnessMaterial('cameraMaterial', this.scene);
    cameraMaterial.baseColor = new BABYLON.Color3(0.01, 0.01, 0.02);
    cameraMaterial.metallic = 0.85;
    cameraMaterial.roughness = 0.15;

    const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

    const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('lensMaterial', this.scene);
    lensMaterial.baseTexture = lensTexture;
    lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);
    lensMaterial.emissiveTexture = lensTexture;
    lensMaterial.emissiveColor = new BABYLON.Color3(0.2, 0.2, 0.2);
    lensMaterial.metallic = 0;
    lensMaterial.roughness = 0.05;
    lensMaterial.environmentIntensity = 1.5;
    lensMaterial.clearCoat.isEnabled = true;
    lensMaterial.clearCoat.intensity = 1.0;
    lensMaterial.clearCoat.roughness = 0.0;
    lensMaterial.clearCoat.isTintEnabled = false;

    cameraPositions.forEach((pos, index) => {
      const lens = BABYLON.MeshBuilder.CreateCylinder(`lens${index}`, {
        diameter: cameraSize,
        height: 0.01725
      }, this.scene);
      lens.rotation.x = Math.PI / 2;
      lens.position.x = pos.x;
      lens.position.y = pos.y;
      lens.position.z = -(bodyDepth / 2) - 0.008625;
      lens.parent = this.phoneModel;
      lens.material = lensMaterial;
    });
  }

  createPhoneButtons(bodyWidth, bodyHeight, bodyDepth) {
    const buttonMaterial = new BABYLON.PBRMetallicRoughnessMaterial('buttonMaterial', this.scene);
    const bodyColor = this.phoneBodyMaterial ? this.phoneBodyMaterial.baseColor : new BABYLON.Color3(0.09, 0.09, 0.09);
    buttonMaterial.baseColor = new BABYLON.Color3(
      bodyColor.r * 0.8,
      bodyColor.g * 0.8,
      bodyColor.b * 0.8
    );
    buttonMaterial.metallic = 0.95;
    buttonMaterial.roughness = 0.15;

    const buttonWidth = 0.017;
    const buttonDepth = bodyDepth * 0.6;
    const capRadius = buttonDepth / 2;

    // Volume button
    const volumeHeight = 0.5;
    const volumeCenter = BABYLON.MeshBuilder.CreateBox('volumeCenter', {
      width: buttonWidth,
      height: volumeHeight - (capRadius * 2),
      depth: buttonDepth
    }, this.scene);
    volumeCenter.position.x = -(bodyWidth / 2) - 0.0085;
    volumeCenter.position.y = 0.5;

    const volumeTopCap = BABYLON.MeshBuilder.CreateCylinder('volumeTopCap', {
      diameter: buttonDepth,
      height: buttonWidth,
      tessellation: 16
    }, this.scene);
    volumeTopCap.rotation.z = Math.PI / 2;
    volumeTopCap.position.x = -(bodyWidth / 2) - 0.0085;
    volumeTopCap.position.y = 0.5 + (volumeHeight / 2) - capRadius;

    const volumeBottomCap = BABYLON.MeshBuilder.CreateCylinder('volumeBottomCap', {
      diameter: buttonDepth,
      height: buttonWidth,
      tessellation: 16
    }, this.scene);
    volumeBottomCap.rotation.z = Math.PI / 2;
    volumeBottomCap.position.x = -(bodyWidth / 2) - 0.0085;
    volumeBottomCap.position.y = 0.5 - (volumeHeight / 2) + capRadius;

    const volumeButton = BABYLON.Mesh.MergeMeshes([volumeCenter, volumeTopCap, volumeBottomCap], true, true);
    volumeButton.parent = this.phoneModel;
    volumeButton.material = buttonMaterial;

    // Power button
    const powerHeight = 0.25;
    const powerCenter = BABYLON.MeshBuilder.CreateBox('powerCenter', {
      width: buttonWidth,
      height: powerHeight - (capRadius * 2),
      depth: buttonDepth
    }, this.scene);
    powerCenter.position.x = -(bodyWidth / 2) - 0.0085;
    powerCenter.position.y = 0.05;

    const powerTopCap = BABYLON.MeshBuilder.CreateCylinder('powerTopCap', {
      diameter: buttonDepth,
      height: buttonWidth,
      tessellation: 16
    }, this.scene);
    powerTopCap.rotation.z = Math.PI / 2;
    powerTopCap.position.x = -(bodyWidth / 2) - 0.0085;
    powerTopCap.position.y = 0.05 + (powerHeight / 2) - capRadius;

    const powerBottomCap = BABYLON.MeshBuilder.CreateCylinder('powerBottomCap', {
      diameter: buttonDepth,
      height: buttonWidth,
      tessellation: 16
    }, this.scene);
    powerBottomCap.rotation.z = Math.PI / 2;
    powerBottomCap.position.x = -(bodyWidth / 2) - 0.0085;
    powerBottomCap.position.y = 0.05 - (powerHeight / 2) + capRadius;

    const powerButton = BABYLON.Mesh.MergeMeshes([powerCenter, powerTopCap, powerBottomCap], true, true);
    powerButton.parent = this.phoneModel;
    powerButton.material = buttonMaterial;
  }

  createPhoneFrontCamera(bodyDepth) {
    const cameraSize = 0.08;

    const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

    const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('frontCameraLensMaterial', this.scene);
    lensMaterial.baseTexture = lensTexture;
    lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);
    lensMaterial.emissiveTexture = lensTexture;
    lensMaterial.emissiveColor = new BABYLON.Color3(0.2, 0.2, 0.2);
    lensMaterial.metallic = 0;
    lensMaterial.roughness = 0.05;
    lensMaterial.environmentIntensity = 1.5;
    lensMaterial.clearCoat.isEnabled = true;
    lensMaterial.clearCoat.intensity = 1.0;
    lensMaterial.clearCoat.roughness = 0.0;
    lensMaterial.clearCoat.isTintEnabled = false;

    const frontCamera = BABYLON.MeshBuilder.CreateCylinder('frontCamera', {
      diameter: cameraSize,
      height: 0.005
    }, this.scene);
    frontCamera.rotation.x = Math.PI / 2;
    frontCamera.position.x = 0;
    frontCamera.position.y = 1.35;
    frontCamera.position.z = (bodyDepth / 2) + 0.003;
    frontCamera.parent = this.phoneModel;
    frontCamera.material = lensMaterial;
  }

  // ==========================================
  // NOTEBOOK CREATION (copied from device-viewer.js - simplified for login)
  // ==========================================

  createNotebook() {
    this.notebookModel = new BABYLON.TransformNode('notebook', this.scene);

    const baseWidth = 9;
    const baseDepth = 6;
    const baseHeight = 0.15;
    const cornerRadius = 0.12;
    const screenWidth = 8.8;
    const screenHeight = 5.5;

    // ===== BASE (Bottom part - keyboard) =====

    // Main base material - solid color RGB(23, 23, 23)
    const baseMaterial = new BABYLON.StandardMaterial('baseMaterial', this.scene);
    baseMaterial.diffuseColor = new BABYLON.Color3(0.090, 0.090, 0.090); // RGB(23, 23, 23)
    baseMaterial.specularColor = new BABYLON.Color3(0.25, 0.25, 0.25);
    baseMaterial.specularPower = 64;
    baseMaterial.backFaceCulling = false;

    // Store material reference for color changes
    this.notebookBodyMaterials.push(baseMaterial);

    // Create rounded base
    this.createNotebookRoundedBase(baseWidth, baseDepth, baseHeight, cornerRadius, baseMaterial);

    // Create keyboard with RGB
    this.createNotebookKeyboard();

    // Trackpad with rounded corners
    this.createNotebookTrackpad(baseHeight);

    // Intel badge
    this.createNotebookIntelBadge(baseHeight);

    // ===== LID (Top part - screen) =====

    this.lidGroup = new BABYLON.TransformNode('lidGroup', this.scene);
    this.lidGroup.parent = this.notebookModel;
    this.lidGroup.position.y = baseHeight;
    this.lidGroup.position.z = -baseDepth / 2;

    // Lid material - solid color RGB(23, 23, 23)
    const lidMaterial = new BABYLON.StandardMaterial('lidMaterial', this.scene);
    lidMaterial.diffuseColor = new BABYLON.Color3(0.090, 0.090, 0.090); // RGB(23, 23, 23)
    lidMaterial.specularColor = new BABYLON.Color3(0.25, 0.25, 0.25);
    lidMaterial.specularPower = 64;
    lidMaterial.backFaceCulling = false;

    // Store material references
    this.notebookLidMaterial = lidMaterial; // For logo contrast calculation
    this.notebookBodyMaterials.push(lidMaterial);

    // Lid back with rounded corners
    this.createNotebookRoundedLid(baseWidth, baseDepth, baseHeight * 0.8, cornerRadius, lidMaterial, this.lidGroup);

    // Screen
    this.createNotebookScreen(screenWidth, screenHeight, baseHeight, baseDepth);

    // Webcam
    this.createNotebookWebcam(baseDepth, baseHeight);

    // Tata logo on lid back
    this.createNotebookLogo(baseDepth, baseHeight);

    // Hinges connecting base to lid
    this.createNotebookHinges(baseWidth, baseDepth, baseHeight);

    // Set initial angle (85 degrees - more open)
    this.setNotebookAngle(85);

    // Position notebook at origin
    this.notebookModel.position = new BABYLON.Vector3(0, 0, 0);
    // No manual rotation - let camera position determine front view
    this.notebookModel.rotation = new BABYLON.Vector3(0, 0, 0);

    // Start animation
    this.startNotebookAnimation();

    // Load default video
    this.loadNotebookVideo();
  }

  createNotebookRoundedBase(width, depth, height, radius, material) {
    // Center piece
    const center = BABYLON.MeshBuilder.CreateBox('baseCenter', {
      width: width - (radius * 2),
      height: height,
      depth: depth - (radius * 2)
    }, this.scene);
    center.position.y = height / 2;
    center.parent = this.notebookModel;
    center.material = material;

    // 4 side pieces
    const top = BABYLON.MeshBuilder.CreateBox('baseTop', {
      width: width - (radius * 2),
      height: height,
      depth: radius * 2
    }, this.scene);
    top.position.y = height / 2;
    top.position.z = -(depth / 2) + radius;
    top.parent = this.notebookModel;
    top.material = material;

    const bottom = BABYLON.MeshBuilder.CreateBox('baseBottom', {
      width: width - (radius * 2),
      height: height,
      depth: radius * 2
    }, this.scene);
    bottom.position.y = height / 2;
    bottom.position.z = (depth / 2) - radius;
    bottom.parent = this.notebookModel;
    bottom.material = material;

    const left = BABYLON.MeshBuilder.CreateBox('baseLeft', {
      width: radius * 2,
      height: height,
      depth: depth - (radius * 2)
    }, this.scene);
    left.position.y = height / 2;
    left.position.x = -(width / 2) + radius;
    left.parent = this.notebookModel;
    left.material = material;

    const right = BABYLON.MeshBuilder.CreateBox('baseRight', {
      width: radius * 2,
      height: height,
      depth: depth - (radius * 2)
    }, this.scene);
    right.position.y = height / 2;
    right.position.x = (width / 2) - radius;
    right.parent = this.notebookModel;
    right.material = material;

    // 4 rounded corners
    const corners = [
      { x: (width / 2) - radius, z: -(depth / 2) + radius },
      { x: -(width / 2) + radius, z: -(depth / 2) + radius },
      { x: (width / 2) - radius, z: (depth / 2) - radius },
      { x: -(width / 2) + radius, z: (depth / 2) - radius }
    ];

    corners.forEach((pos, i) => {
      const corner = BABYLON.MeshBuilder.CreateCylinder(`baseCorner${i}`, {
        diameter: radius * 2,
        height: height,
        tessellation: 16
      }, this.scene);
      corner.position.y = height / 2;
      corner.position.x = pos.x;
      corner.position.z = pos.z;
      corner.parent = this.notebookModel;
      corner.material = material;
    });
  }

  createNotebookRoundedLid(width, height, depth, radius, material, parent) {
    // Center piece
    const center = BABYLON.MeshBuilder.CreateBox('lidCenter', {
      width: width - (radius * 2),
      height: height - (radius * 2),
      depth: depth
    }, this.scene);
    center.position.y = height / 2;
    center.parent = parent;
    center.material = material;

    // 4 side pieces
    const top = BABYLON.MeshBuilder.CreateBox('lidTop', {
      width: width - (radius * 2),
      height: radius * 2,
      depth: depth
    }, this.scene);
    top.position.y = height - radius;
    top.parent = parent;
    top.material = material;

    const bottom2 = BABYLON.MeshBuilder.CreateBox('lidBottom', {
      width: width - (radius * 2),
      height: radius * 2,
      depth: depth
    }, this.scene);
    bottom2.position.y = radius;
    bottom2.parent = parent;
    bottom2.material = material;

    const left = BABYLON.MeshBuilder.CreateBox('lidLeft', {
      width: radius * 2,
      height: height - (radius * 2),
      depth: depth
    }, this.scene);
    left.position.y = height / 2;
    left.position.x = -(width / 2) + radius;
    left.parent = parent;
    left.material = material;

    const right = BABYLON.MeshBuilder.CreateBox('lidRight', {
      width: radius * 2,
      height: height - (radius * 2),
      depth: depth
    }, this.scene);
    right.position.y = height / 2;
    right.position.x = (width / 2) - radius;
    right.parent = parent;
    right.material = material;

    // 4 rounded corners
    const corners = [
      { x: (width / 2) - radius, y: height - radius },
      { x: -(width / 2) + radius, y: height - radius },
      { x: (width / 2) - radius, y: radius },
      { x: -(width / 2) + radius, y: radius }
    ];

    corners.forEach((pos, i) => {
      const corner = BABYLON.MeshBuilder.CreateCylinder(`lidCorner${i}`, {
        diameter: radius * 2,
        height: depth,
        tessellation: 16
      }, this.scene);
      corner.rotation.x = Math.PI / 2;
      corner.position.y = pos.y;
      corner.position.x = pos.x;
      corner.parent = parent;
      corner.material = material;
    });
  }

  createNotebookScreen(screenWidth, screenHeight, baseHeight, baseDepth) {
    this.screenMeshNotebook = BABYLON.MeshBuilder.CreatePlane('screen', {
      width: screenWidth,
      height: screenHeight
    }, this.scene);
    this.screenMeshNotebook.position.y = baseDepth / 2;
    this.screenMeshNotebook.position.z = (baseHeight * 0.8) / 2 + 0.008;
    this.screenMeshNotebook.parent = this.lidGroup;
    this.screenMeshNotebook.rotation.y = Math.PI;

    // Create simple notebook screen shader
    this.createNotebookScreenShader();

    this.screenMaterialNotebook = new BABYLON.ShaderMaterial("notebookScreenMaterial", this.scene, {
      vertex: "notebookScreen",
      fragment: "notebookScreen",
    }, {
      attributes: ["position", "uv"],
      uniforms: ["worldViewProjection", "textureSampler", "brightness"],
      needAlphaBlending: false
    });

    this.screenMaterialNotebook.setFloat("brightness", this.brightness);
    this.screenMaterialNotebook.backFaceCulling = false;
    this.screenMaterialNotebook.disableLighting = true;

    const defaultTexture = new BABYLON.DynamicTexture('defaultTexture', 2, this.scene, false);
    const defaultCtx = defaultTexture.getContext();
    defaultCtx.fillStyle = '#000000';
    defaultCtx.fillRect(0, 0, 2, 2);
    defaultTexture.update();
    this.screenMaterialNotebook.setTexture("textureSampler", defaultTexture);

    this.screenMeshNotebook.material = this.screenMaterialNotebook;
  }

  createNotebookScreenShader() {
    BABYLON.Effect.ShadersStore["notebookScreenVertexShader"] = `
      precision highp float;
      attribute vec3 position;
      attribute vec2 uv;
      uniform mat4 worldViewProjection;
      varying vec2 vUV;

      void main(void) {
        gl_Position = worldViewProjection * vec4(position, 1.0);
        vUV = uv;
      }
    `;

    BABYLON.Effect.ShadersStore["notebookScreenFragmentShader"] = `
      precision highp float;
      varying vec2 vUV;
      uniform sampler2D textureSampler;
      uniform float brightness;

      void main(void) {
        vec4 texColor = texture2D(textureSampler, vUV);
        vec3 finalColor = texColor.rgb * brightness;
        gl_FragColor = vec4(finalColor, 1.0);
      }
    `;
  }

  createNotebookWebcam(baseDepth, baseHeight) {
    const cameraSize = 0.1;

    const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

    const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('notebookCameraLens', this.scene);
    lensMaterial.baseTexture = lensTexture;
    lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);
    lensMaterial.emissiveTexture = lensTexture;
    lensMaterial.emissiveColor = new BABYLON.Color3(0.3, 0.3, 0.3);
    lensMaterial.metallic = 0;
    lensMaterial.roughness = 0.05;
    lensMaterial.environmentIntensity = 1.5;
    lensMaterial.clearCoat.isEnabled = true;
    lensMaterial.clearCoat.intensity = 1.0;
    lensMaterial.clearCoat.roughness = 0.0;

    const webcam = BABYLON.MeshBuilder.CreateCylinder('webcam', {
      diameter: cameraSize,
      height: 0.015
    }, this.scene);
    webcam.rotation.x = Math.PI / 2;
    webcam.position.y = baseDepth - 0.15;
    webcam.position.z = (baseHeight * 0.8) / 2 + 0.008;
    webcam.parent = this.lidGroup;
    webcam.material = lensMaterial;
  }

  createNotebookHinges(baseWidth, baseDepth, baseHeight) {
    const hingeMaterial = new BABYLON.StandardMaterial('hingeMaterial', this.scene);
    hingeMaterial.diffuseColor = new BABYLON.Color3(0.090, 0.090, 0.090);
    hingeMaterial.specularColor = new BABYLON.Color3(0.5, 0.5, 0.5);
    hingeMaterial.specularPower = 128;

    const hingeRadius = 0.06;
    const hingeLength = 0.5;

    // Left hinge
    const leftHinge = BABYLON.MeshBuilder.CreateCylinder('leftHinge', {
      diameter: hingeRadius * 2,
      height: hingeLength,
      tessellation: 16
    }, this.scene);
    leftHinge.rotation.z = Math.PI / 2;
    leftHinge.position.x = 3.586;
    leftHinge.position.y = 0.164;
    leftHinge.position.z = -2.992;
    leftHinge.parent = this.notebookModel;
    leftHinge.material = hingeMaterial;

    // Right hinge
    const rightHinge = BABYLON.MeshBuilder.CreateCylinder('rightHinge', {
      diameter: hingeRadius * 2,
      height: hingeLength,
      tessellation: 16
    }, this.scene);
    rightHinge.rotation.z = Math.PI / 2;
    rightHinge.position.x = -3.586;
    rightHinge.position.y = 0.164;
    rightHinge.position.z = -2.992;
    rightHinge.parent = this.notebookModel;
    rightHinge.material = hingeMaterial;
  }

  setNotebookAngle(degrees) {
    if (!this.lidGroup) return;

    const radians = BABYLON.Tools.ToRadians(degrees);
    this.lidGroup.rotation.x = -radians + Math.PI / 2;
  }

  /**
   * Create keyboard with individual keys
   */
  createNotebookKeyboard() {
    const keyboardAreaWidth = 9 - 1.2;
    const keyboardAreaDepth = 3.8;

    const paddingH = 0.15;
    const paddingV = 0.1;
    const effectiveWidth = keyboardAreaWidth - (paddingH * 2);
    const effectiveDepth = keyboardAreaDepth - (paddingV * 2);

    const numRows = 6;
    const keySpacing = 0.04;
    const totalSpacingVertical = keySpacing * (numRows - 1);
    const keyDepth = (effectiveDepth - totalSpacingVertical) / numRows;

    const keyHeight = 0.034;
    const baseY = 0.15 + 0.015;
    const startZ = -2.2 + paddingV;
    const startX = -3.9 + paddingH;

    // Keyboard layout (inverted horizontally)
    const rows = [
      { keys: ['DEL', 'F12', 'F11', 'F10', 'F9', 'F8', 'F7', 'F6', 'F5', 'F4', 'F3', 'F2', 'F1', 'ESC'], widths: [1.5, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 1.3] },
      { keys: ['BACK', '=', '-', '0', '9', '8', '7', '6', '5', '4', '3', '2', '1', '`'], widths: [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1] },
      { keys: ['\\', ']', '[', 'P', 'O', 'I', 'U', 'Y', 'T', 'R', 'E', 'W', 'Q', 'TAB'], widths: [1.2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.3] },
      { keys: ['ENTER', "'", ';', 'L', 'K', 'J', 'H', 'G', 'F', 'D', 'S', 'A', 'CAPS'], widths: [2.0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5] },
      { keys: ['SHIFT', '/', '.', ',', 'M', 'N', 'B', 'V', 'C', 'X', 'Z', 'SHIFT'], widths: [2.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.0] },
      { keys: ['CTRL', 'MENU', 'FN', 'ALT', '', 'ALT', 'WIN', 'FN', 'CTRL'], widths: [1.25, 1, 1, 1.25, 4.5, 1.25, 1, 1, 1.25] }
    ];

    const calculateKeyWidth = (row) => {
      const totalWidthUnits = row.widths.reduce((sum, w) => sum + w, 0);
      const totalSpacingH = keySpacing * (row.keys.filter(k => k !== '').length - 1);
      return (effectiveWidth - totalSpacingH) / totalWidthUnits;
    };

    rows.forEach((row, rowIndex) => {
      const baseKeyWidth = calculateKeyWidth(row);
      let xOffset = startX;
      const zPos = startZ + (rowIndex * (keyDepth + keySpacing));

      row.keys.forEach((key, keyIndex) => {
        const currentKeyWidth = baseKeyWidth * row.widths[keyIndex];

        const keyMesh = BABYLON.MeshBuilder.CreateBox(`key_${rowIndex}_${keyIndex}`, {
          width: currentKeyWidth,
          height: keyHeight,
          depth: keyDepth
        }, this.scene);

        keyMesh.position.x = xOffset + (currentKeyWidth / 2);
        keyMesh.position.y = baseY + (keyHeight / 2);
        keyMesh.position.z = zPos;
        keyMesh.parent = this.notebookModel;

        const keyMat = new BABYLON.StandardMaterial(`keyMat_${rowIndex}_${keyIndex}`, this.scene);
        const currentBodyColor = this.notebookLidMaterial ?
          this.notebookLidMaterial.diffuseColor.clone() :
          new BABYLON.Color3(0.090, 0.090, 0.090);
        keyMat.diffuseColor = currentBodyColor;
        keyMat.specularColor = new BABYLON.Color3(0.02, 0.02, 0.02);
        keyMat.emissiveColor = new BABYLON.Color3(0, 0, 0);
        keyMesh.material = keyMat;

        this.keyMeshes.push(keyMesh);
        this.keyMaterials.push(keyMat);
        this.notebookBodyMaterials.push(keyMat);

        if (key !== '') {
          this.createNotebookKeyLabel(key, keyMesh, currentKeyWidth, keyDepth);
        }

        xOffset += currentKeyWidth + keySpacing;
      });
    });
  }

  /**
   * Create text label on notebook key
   */
  createNotebookKeyLabel(text, keyMesh, keyWidth, keyDepth) {
    const textureSize = 256;
    const dynamicTexture = new BABYLON.DynamicTexture(`keyLabel_${text}_${Math.random()}`, textureSize, this.scene, false);
    dynamicTexture.hasAlpha = true;

    const ctx = dynamicTexture.getContext();
    ctx.clearRect(0, 0, textureSize, textureSize);

    ctx.save();
    ctx.translate(textureSize, 0);
    ctx.scale(-1, 1);

    const fontSize = text.length > 2 ? 60 : 90;
    ctx.font = `bold ${fontSize}px Arial`;
    ctx.fillStyle = 'white';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    ctx.fillText(text, textureSize / 2, textureSize / 2);
    ctx.restore();
    dynamicTexture.update();

    const textPlane = BABYLON.MeshBuilder.CreatePlane(`keyText_${text}_${Math.random()}`, {
      width: keyWidth * 0.8,
      height: keyDepth * 0.7
    }, this.scene);

    textPlane.position.y = 0.045;
    textPlane.rotation.x = -Math.PI / 2;
    textPlane.parent = keyMesh;

    const textMaterial = new BABYLON.StandardMaterial(`keyTextMat_${text}_${Math.random()}`, this.scene);
    textMaterial.diffuseTexture = dynamicTexture;
    textMaterial.diffuseColor = new BABYLON.Color3(1.0, 1.0, 1.0);
    textMaterial.emissiveTexture = dynamicTexture;
    textMaterial._storedEmissiveTexture = dynamicTexture;
    textMaterial.emissiveColor = new BABYLON.Color3(2.0, 2.0, 2.0);
    textMaterial.opacityTexture = dynamicTexture;
    textMaterial.useAlphaFromDiffuseTexture = true;
    textMaterial.backFaceCulling = false;
    textMaterial.disableLighting = true;
    textMaterial.specularColor = new BABYLON.Color3(0, 0, 0);
    textPlane.material = textMaterial;

    this.keyTextMaterials.push(textMaterial);
    this.keyTextMeshes.push(textPlane);
  }

  /**
   * Create trackpad with rounded corners
   */
  createNotebookTrackpad(baseHeight) {
    const trackpadWidth = 2.5;
    const trackpadDepth = 1.4;
    const trackpadHeight = 0.008;
    const trackpadRadius = 0.1;
    const trackpadPosY = baseHeight + 0.004;
    const trackpadPosZ = 2.1;

    const trackpadMaterial = new BABYLON.StandardMaterial('trackpadMaterial', this.scene);
    trackpadMaterial.diffuseColor = new BABYLON.Color3(0.12, 0.12, 0.14);
    trackpadMaterial.specularColor = new BABYLON.Color3(0.2, 0.2, 0.2);

    // Center
    const trackpadCenter = BABYLON.MeshBuilder.CreateBox('trackpadCenter', {
      width: trackpadWidth - (trackpadRadius * 2),
      height: trackpadHeight,
      depth: trackpadDepth - (trackpadRadius * 2)
    }, this.scene);
    trackpadCenter.position.y = trackpadPosY;
    trackpadCenter.position.z = trackpadPosZ;
    trackpadCenter.parent = this.notebookModel;
    trackpadCenter.material = trackpadMaterial;

    // 4 sides
    const trackpadTop = BABYLON.MeshBuilder.CreateBox('trackpadTop', {
      width: trackpadWidth - (trackpadRadius * 2),
      height: trackpadHeight,
      depth: trackpadRadius * 2
    }, this.scene);
    trackpadTop.position.y = trackpadPosY;
    trackpadTop.position.z = trackpadPosZ - (trackpadDepth / 2) + trackpadRadius;
    trackpadTop.parent = this.notebookModel;
    trackpadTop.material = trackpadMaterial;

    const trackpadBottom = BABYLON.MeshBuilder.CreateBox('trackpadBottom', {
      width: trackpadWidth - (trackpadRadius * 2),
      height: trackpadHeight,
      depth: trackpadRadius * 2
    }, this.scene);
    trackpadBottom.position.y = trackpadPosY;
    trackpadBottom.position.z = trackpadPosZ + (trackpadDepth / 2) - trackpadRadius;
    trackpadBottom.parent = this.notebookModel;
    trackpadBottom.material = trackpadMaterial;

    const trackpadLeft = BABYLON.MeshBuilder.CreateBox('trackpadLeft', {
      width: trackpadRadius * 2,
      height: trackpadHeight,
      depth: trackpadDepth - (trackpadRadius * 2)
    }, this.scene);
    trackpadLeft.position.x = -(trackpadWidth / 2) + trackpadRadius;
    trackpadLeft.position.y = trackpadPosY;
    trackpadLeft.position.z = trackpadPosZ;
    trackpadLeft.parent = this.notebookModel;
    trackpadLeft.material = trackpadMaterial;

    const trackpadRight = BABYLON.MeshBuilder.CreateBox('trackpadRight', {
      width: trackpadRadius * 2,
      height: trackpadHeight,
      depth: trackpadDepth - (trackpadRadius * 2)
    }, this.scene);
    trackpadRight.position.x = (trackpadWidth / 2) - trackpadRadius;
    trackpadRight.position.y = trackpadPosY;
    trackpadRight.position.z = trackpadPosZ;
    trackpadRight.parent = this.notebookModel;
    trackpadRight.material = trackpadMaterial;

    // 4 corners
    const trackpadCorners = [
      { x: (trackpadWidth / 2) - trackpadRadius, z: trackpadPosZ - (trackpadDepth / 2) + trackpadRadius },
      { x: -(trackpadWidth / 2) + trackpadRadius, z: trackpadPosZ - (trackpadDepth / 2) + trackpadRadius },
      { x: (trackpadWidth / 2) - trackpadRadius, z: trackpadPosZ + (trackpadDepth / 2) - trackpadRadius },
      { x: -(trackpadWidth / 2) + trackpadRadius, z: trackpadPosZ + (trackpadDepth / 2) - trackpadRadius }
    ];

    trackpadCorners.forEach((pos, i) => {
      const corner = BABYLON.MeshBuilder.CreateCylinder(`trackpadCorner${i}`, {
        diameter: trackpadRadius * 2,
        height: trackpadHeight,
        tessellation: 16
      }, this.scene);
      corner.position.x = pos.x;
      corner.position.y = trackpadPosY;
      corner.position.z = pos.z;
      corner.parent = this.notebookModel;
      corner.material = trackpadMaterial;
    });
  }

  /**
   * Create Intel badge
   */
  createNotebookIntelBadge(baseHeight) {
    const intelBadge = BABYLON.MeshBuilder.CreatePlane('intelBadge', {
      width: 0.38,
      height: 0.38
    }, this.scene);
    intelBadge.position.x = -3.6;
    intelBadge.position.y = baseHeight + 0.005;
    intelBadge.position.z = 2.5;
    intelBadge.rotation.x = -Math.PI / 2;
    intelBadge.rotation.y = 0;
    intelBadge.rotation.z = 0;
    intelBadge.scaling.x = -1;
    intelBadge.parent = this.notebookModel;

    const intelBadgeMaterial = new BABYLON.StandardMaterial('intelBadgeMaterial', this.scene);
    const intelBadgeTexture = new BABYLON.Texture('assets/images/intel_core_ultra9.svg', this.scene);
    intelBadgeTexture.hasAlpha = true;

    intelBadgeMaterial.diffuseTexture = intelBadgeTexture;
    intelBadgeMaterial.emissiveTexture = intelBadgeTexture;
    intelBadgeMaterial.emissiveColor = new BABYLON.Color3(0.3, 0.3, 0.3);
    intelBadgeMaterial.opacityTexture = intelBadgeTexture;
    intelBadgeMaterial.useAlphaFromDiffuseTexture = true;
    intelBadgeMaterial.backFaceCulling = false;

    intelBadge.material = intelBadgeMaterial;
  }

  /**
   * Create Tata logo on notebook lid back
   */
  createNotebookLogo(baseDepth, baseHeight) {
    const logoUrl = 'assets/Tata_logo.svg';

    const tataLogo = BABYLON.MeshBuilder.CreatePlane('tataLogo', {
      width: 0.8,
      height: 0.6
    }, this.scene);
    tataLogo.position.y = baseDepth / 2;
    tataLogo.position.z = -(baseHeight * 0.8) / 2 - 0.001;
    tataLogo.rotation.y = 0;
    tataLogo.parent = this.lidGroup;

    this.notebookLogoMaterial = new BABYLON.StandardMaterial('tataLogoMaterial', this.scene);
    const tataLogoTexture = new BABYLON.Texture(logoUrl, this.scene);
    tataLogoTexture.hasAlpha = true;

    this.notebookLogoMaterial.emissiveTexture = tataLogoTexture;
    this.notebookLogoMaterial.emissiveColor = new BABYLON.Color3(1, 1, 1);
    this.notebookLogoMaterial.opacityTexture = tataLogoTexture;
    this.notebookLogoMaterial.useAlphaFromDiffuseTexture = true;
    this.notebookLogoMaterial.backFaceCulling = false;
    this.notebookLogoMaterial.disableLighting = true;

    tataLogo.material = this.notebookLogoMaterial;
  }

  // ==========================================
  // VIDEO LOADING
  // ==========================================

  loadPhoneVideo() {
    const videoPath = 'assets/videos/phone-video.mp4';

    const videoElement = document.createElement('video');
    videoElement.src = videoPath;
    videoElement.loop = true;
    videoElement.muted = true;
    videoElement.playsInline = true;
    videoElement.autoplay = true;

    videoElement.addEventListener('canplaythrough', () => {
      videoElement.play().then(() => {
        const videoTexture = new BABYLON.VideoTexture(
          'phoneVideoTexture',
          videoElement,
          this.scene,
          false,
          false,
          BABYLON.Texture.TRILINEAR_SAMPLINGMODE
        );

        this.screenMaterial.setTexture("textureSampler", videoTexture);
        this.screenMaterial.setInt("hasTexture", 1);

        console.log('[LoginDevicesViewer] ✅ Phone video loaded');
      }).catch(error => {
        console.error('[LoginDevicesViewer] ❌ Phone video play error:', error);
      });
    }, { once: true });

    videoElement.addEventListener('error', (error) => {
      console.error('[LoginDevicesViewer] ❌ Phone video load error:', error);
    });
  }

  loadNotebookVideo() {
    const videoPath = 'assets/videos/notebook-video.mp4';

    const videoElement = document.createElement('video');
    videoElement.src = videoPath;
    videoElement.loop = true;
    videoElement.muted = true;
    videoElement.playsInline = true;
    videoElement.autoplay = true;

    videoElement.addEventListener('canplaythrough', () => {
      videoElement.play().then(() => {
        const videoTexture = new BABYLON.VideoTexture(
          'notebookVideoTexture',
          videoElement,
          this.scene,
          false,
          false,
          BABYLON.Texture.TRILINEAR_SAMPLINGMODE
        );

        this.screenMaterialNotebook.setTexture("textureSampler", videoTexture);

        console.log('[LoginDevicesViewer] ✅ Notebook video loaded');
      }).catch(error => {
        console.error('[LoginDevicesViewer] ❌ Notebook video play error:', error);
      });
    }, { once: true });

    videoElement.addEventListener('error', (error) => {
      console.error('[LoginDevicesViewer] ❌ Notebook video load error:', error);
    });
  }

  // ==========================================
  // UTILITY FUNCTIONS
  // ==========================================

  hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
      r: parseInt(result[1], 16) / 255,
      g: parseInt(result[2], 16) / 255,
      b: parseInt(result[3], 16) / 255
    } : { r: 0, g: 0, b: 0 };
  }

  startNotebookAnimation() {
    if (!this.notebookModel) return;

    // Gentle floating animation for notebook
    this.animations.notebook = this.scene.onBeforeRenderObservable.add(() => {
      const time = performance.now() * 0.0005;

      // Subtle up-down float
      this.notebookModel.position.y = Math.sin(time) * 0.15;

      // Gentle rotation oscillation (no base offset)
      this.notebookModel.rotation.y = Math.sin(time * 0.5) * 0.05;
    });
  }

  startPhoneAnimation() {
    if (!this.phoneModel) return;

    // More pronounced floating for phone (it's "lighter")
    this.animations.phone = this.scene.onBeforeRenderObservable.add(() => {
      const time = performance.now() * 0.0005;

      // More noticeable up-down float
      this.phoneModel.position.y = 4 + Math.sin(time * 1.2) * 0.3;

      // Gentle rotation oscillation on multiple axes (no base offset)
      this.phoneModel.rotation.y = Math.sin(time * 0.8) * 0.1;
      this.phoneModel.rotation.x = Math.sin(time * 0.6) * 0.05;
    });
  }

  setupCameraTargetControls() {
    const panSpeed = 0.1; // Speed of target movement
    const keys = {
      w: false,
      a: false,
      s: false,
      d: false
    };

    // Track key states
    window.addEventListener('keydown', (e) => {
      const key = e.key.toLowerCase();
      if (key === 'w') keys.w = true;
      if (key === 'a') keys.a = true;
      if (key === 's') keys.s = true;
      if (key === 'd') keys.d = true;
    });

    window.addEventListener('keyup', (e) => {
      const key = e.key.toLowerCase();
      if (key === 'w') keys.w = false;
      if (key === 'a') keys.a = false;
      if (key === 's') keys.s = false;
      if (key === 'd') keys.d = false;
    });

    // Update camera target based on key states
    this.scene.onBeforeRenderObservable.add(() => {
      if (keys.w) {
        // Move target up
        this.camera.target.y += panSpeed;
      }
      if (keys.s) {
        // Move target down
        this.camera.target.y -= panSpeed;
      }
      if (keys.a) {
        // Move target left
        this.camera.target.x -= panSpeed;
      }
      if (keys.d) {
        // Move target right
        this.camera.target.x += panSpeed;
      }
    });

    console.log('[LoginDevicesViewer] ✅ WASD camera target controls enabled');
  }

  dispose() {
    if (this.animations.notebook) {
      this.scene.onBeforeRenderObservable.remove(this.animations.notebook);
    }
    if (this.animations.phone) {
      this.scene.onBeforeRenderObservable.remove(this.animations.phone);
    }
    if (this.scene) {
      this.scene.dispose();
    }
    if (this.engine) {
      this.engine.dispose();
    }
    console.log('[LoginDevicesViewer] Viewer disposed');
  }
}

// Make it globally available
window.LoginDevicesViewer = LoginDevicesViewer;
console.log('[LoginDevicesViewer] Class registered globally');
