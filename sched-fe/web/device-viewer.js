/**
 * DeviceViewer - Unified 3D Device Viewer Component
 *
 * A modular Babylon.js component for displaying 3D devices (phones, notebooks)
 * with customizable animations, media playback, and styling.
 *
 * @example
 * // Phone configuration
 * const phoneViewer = new DeviceViewer({
 *   canvasId: 'renderCanvas',
 *   deviceType: 'phone',
 *   bodyColor: '#020203',
 *   brightness: 1.4,
 *   animationSpeed: 0.4,
 *   entranceAnimation: 'spiral',
 *   loopAnimation: 'float',
 *   logoUrl: 'Tata_logo.svg',
 *   enableGlow: true
 * });
 *
 * // Notebook configuration
 * const notebookViewer = new DeviceViewer({
 *   canvasId: 'renderCanvas',
 *   deviceType: 'notebook',
 *   brightness: 1.4,
 *   notebookAngle: 75,
 *   rgbEnabled: true,
 *   entranceAnimation: 'opening',
 *   loopAnimation: 'float',
 *   logoUrl: 'Tata_logo.svg'
 * });
 *
 * viewer.loadImage(file);
 * viewer.loadVideo(file);
 * viewer.setAnimation('spin');
 */

class DeviceViewer {
    constructor(config = {}) {
        // Default configuration
        this.config = {
            canvasId: 'renderCanvas',
            deviceType: 'phone', // 'phone' or 'notebook'

            // Common properties
            brightness: 1.4,
            animationSpeed: 0.4,
            entranceAnimation: 'spiral',
            loopAnimation: 'float',
            enableGlow: true,
            glowIntensity: 0.5,
            logoUrl: null,
            enableInteraction: true, // Enable camera controls (set to false for mobile)

            // ═══════════════════════════════════════════════════════════════
            // 📱 PHONE - CONFIGURAÇÕES PADRÃO
            // ═══════════════════════════════════════════════════════════════
            phoneBodyColor: '#020203',
            phoneLogoColor: 'auto', // 'auto', 'black', 'white'
            phoneCameraPosition: {
                // 🎥 POSIÇÃO INICIAL DA CÂMERA (PHONE)
                // alpha: rotação horizontal (0 = frente, π = trás)
                // beta: rotação vertical (0 = topo, π/2 = lateral)
                // radius: distância da câmera (quanto maior, mais longe)
                alpha: 1.8009405166387853,
                beta: 1.1372112188031334,
                radius: 16.52852450194762  // ⬅️ Altere para mudar zoom inicial
            },

            // ═══════════════════════════════════════════════════════════════
            // 💻 NOTEBOOK - CONFIGURAÇÕES PADRÃO
            // ═══════════════════════════════════════════════════════════════
            notebookAngle: 100, // Ângulo da tampa (0 = fechado, 180 = aberto)
            notebookBodyColor: '#060606',
            rgbEnabled: true,
            notebookCameraPosition: {
                // 🎥 POSIÇÃO INICIAL DA CÂMERA (NOTEBOOK)
                alpha: 1.9346706939136518,
                beta: 1.5594442450722488,
                radius: 5.001937584247854  // ⬅️ Altere para mudar zoom inicial
            },
            defaultVideoPath: 'assets/videos/notebook-video.mp4',

            ...config
        };

        // Internal state - Common
        this.canvas = null;
        this.engine = null;
        this.scene = null;
        this.camera = null;
        this.device = null;
        this.screenMaterial = null;
        this.screenMesh = null;
        this.currentVideoTexture = null;
        this.currentAnimation = this.config.loopAnimation;
        this.animationStartTime = 0;
        this.isPlayingEntrance = false;
        this.animationSpeed = this.config.animationSpeed;

        // Phone-specific state
        this.bodyMaterial = null;
        this.logoMaterial = null;

        // Notebook-specific state
        this.lidGroup = null;
        this.currentAngle = this.config.notebookAngle;
        this.keyMaterials = [];
        this.keyMeshes = []; // Array to store key meshes (to exclude from glow)
        this.keyTextMaterials = [];
        this.keyTextMeshes = []; // Array to store text meshes for glow effect
        this.rgbEnabled = this.config.rgbEnabled;
        this.rgbHue = 0;
        this.notebookBodyMaterials = []; // Array to store all body materials for color change
        this.notebookLogoMaterial = null; // Logo material for RGB effect
        this.rgbGlowLayer = null; // Glow layer for RGB keyboard effect

        // Phone-specific state
        this.phoneBodyMaterial = null; // Phone body material for color change

        // Initialize
        this.init();
    }

    /**
     * Initialize the 3D viewer
     */
    init() {
        this.canvas = document.getElementById(this.config.canvasId);
        if (!this.canvas) {
            throw new Error(`Canvas element with id "${this.config.canvasId}" not found`);
        }

        this.engine = new BABYLON.Engine(this.canvas, true, {
            preserveDrawingBuffer: true,
            stencil: true,
            antialias: true,
            powerPreference: 'high-performance',
            doNotHandleContextLost: true
        });

        // Maximum quality settings
        this.engine.setHardwareScalingLevel(1); // Native resolution
        this.engine.enableOfflineSupport = false; // Better performance

        this.createScene();

        // Render loop with visibility check
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

        // Handle window resize
        window.addEventListener('resize', () => {
            if (this.engine) this.engine.resize();
        });
    }

    /**
     * Create the 3D scene
     */
    createScene() {
        this.scene = new BABYLON.Scene(this.engine);
        this.scene.clearColor = new BABYLON.Color4(0, 0, 0, 0);

        // Camera position based on device type
        const camPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        // Camera target based on device type (configurable)
        let camTargetConfig = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraTarget
            : this.config.phoneCameraTarget;

        // Default targets if not provided
        if (!camTargetConfig) {
            camTargetConfig = this.config.deviceType === 'notebook'
                ? { x: 0, y: 2, z: 0 }
                : { x: 0, y: 0, z: 0 };
        }

        const camTarget = new BABYLON.Vector3(
            camTargetConfig.x || 0,
            camTargetConfig.y || 0,
            camTargetConfig.z || 0
        );

        this.camera = new BABYLON.ArcRotateCamera(
            'camera',
            camPos.alpha,
            camPos.beta,
            camPos.radius,
            camTarget,
            this.scene
        );

        // Only attach controls if interaction is enabled (disabled for mobile)
        if (this.config.enableInteraction) {
            this.camera.attachControl(this.canvas, true);
        } else {
            // For mobile: Allow horizontal rotation (X-axis) but prevent vertical scroll interference
            // Only listen to horizontal pointer movements
            let lastPointerX = null;

            this.canvas.addEventListener('pointerdown', (evt) => {
                lastPointerX = evt.clientX;
                evt.preventDefault(); // Prevent default only when touching canvas
            }, { passive: false });

            this.canvas.addEventListener('pointermove', (evt) => {
                if (lastPointerX !== null) {
                    const deltaX = evt.clientX - lastPointerX;

                    // Only rotate horizontally (alpha), ignore vertical (beta)
                    this.camera.alpha -= deltaX * 0.01;

                    lastPointerX = evt.clientX;
                    evt.preventDefault(); // Prevent scroll while dragging horizontally
                }
            }, { passive: false });

            this.canvas.addEventListener('pointerup', () => {
                lastPointerX = null;
            });

            this.canvas.addEventListener('pointercancel', () => {
                lastPointerX = null;
            });
        }

        if (this.config.deviceType === 'notebook') {
            // ═══════════════════════════════════════════════════════════════
            // 📏 ZOOM DISABLED - NOTEBOOK (Fixed radius: 16)
            // ═══════════════════════════════════════════════════════════════
            this.camera.lowerRadiusLimit = 16;   // Locked at final value
            this.camera.upperRadiusLimit = 16;   // Locked at final value
            this.camera.lowerBetaLimit = 0.1;
            this.camera.upperBetaLimit = Math.PI / 1.5;
            this.camera.wheelPrecision = 1000;   // Effectively disables zoom
        } else {
            // ═══════════════════════════════════════════════════════════════
            // 📏 ZOOM DISABLED - PHONE (Fixed radius: 4.675)
            // ═══════════════════════════════════════════════════════════════
            this.camera.lowerRadiusLimit = 4.675;  // Locked at final value
            this.camera.upperRadiusLimit = 4.675;  // Locked at final value
            this.camera.lowerBetaLimit = 0.8;
            this.camera.upperBetaLimit = Math.PI / 2 + 0.3;
            this.camera.wheelPrecision = 1000;     // Effectively disables zoom
        }

        // Lights
        const hemisphericLight = new BABYLON.HemisphericLight(
            'hemisphericLight',
            new BABYLON.Vector3(0, 1, 0),
            this.scene
        );
        hemisphericLight.intensity = 0.5; // Reduced to prevent overexposure and white washing

        const directionalLight = new BABYLON.DirectionalLight(
            'directionalLight',
            new BABYLON.Vector3(-1, -2, -1),
            this.scene
        );
        directionalLight.position = new BABYLON.Vector3(5, 10, 5);
        directionalLight.intensity = 0.6; // Reduced to prevent white washing on keyboard

        const pointLight = new BABYLON.PointLight(
            'pointLight',
            this.config.deviceType === 'notebook'
                ? new BABYLON.Vector3(0, 8, -5)
                : new BABYLON.Vector3(0, 5, -5),
            this.scene
        );
        pointLight.intensity = this.config.deviceType === 'notebook' ? 0.3 : 0.3;

        // Add additional light for notebook lid (back side)
        if (this.config.deviceType === 'notebook') {
            const backLight = new BABYLON.PointLight(
                'backLight',
                new BABYLON.Vector3(0, 5, -8),  // Behind and above
                this.scene
            );
            backLight.intensity = 0.4;  // Balanced light to illuminate the lid without overexposure

            // Add a fill light from the side to reduce shadows
            const fillLight = new BABYLON.PointLight(
                'fillLight',
                new BABYLON.Vector3(-5, 3, -3),  // Left side, behind
                this.scene
            );
            fillLight.intensity = 0.3;
        }

        // Create device based on type
        if (this.config.deviceType === 'phone') {
            this.createPhone();
        } else if (this.config.deviceType === 'notebook') {
            this.createNotebook();
        }

        // Environment
        const hdrTexture = BABYLON.CubeTexture.CreateFromPrefilteredData(
            'https://playground.babylonjs.com/textures/environment.dds',
            this.scene
        );
        this.scene.environmentTexture = hdrTexture;
        this.scene.environmentIntensity = 0.5;

        // Glow layer
        if (this.config.enableGlow) {
            const gl = new BABYLON.GlowLayer('glow', this.scene);
            gl.intensity = this.config.glowIntensity;

            // Exclude screen from glow to prevent interference
            if (this.screenMesh) {
                gl.addExcludedMesh(this.screenMesh);
            }
        }

        // Register animation loop
        this.scene.registerBeforeRender(() => {
            this.updateAnimation();
        });

        // Add keyboard controls for camera positioning
        this.setupKeyboardControls();

        // Add mouse camera change logging
        this.setupMouseLogging();

        // Play entrance animation
        this.playEntranceAnimation(this.config.entranceAnimation);

        // Load default video for both notebook and phone
        if (this.config.defaultVideoPath) {
            this.scene.executeWhenReady(() => {
                this.loadDefaultVideo().then(() => {
                    this.hideLoadingScreen();
                }).catch(() => {
                    this.hideLoadingScreen();
                });
            });
        }
    }

    /**
     * Hide loading screen
     */
    hideLoadingScreen() {
        const loadingScreen = document.getElementById('loadingScreen');
        if (loadingScreen) {
            loadingScreen.classList.add('hidden');
            setTimeout(() => {
                loadingScreen.style.display = 'none';
            }, 500);
        }
    }

    // ==========================================
    // PHONE CREATION
    // ==========================================

    /**
     * Create phone model
     */
    createPhone() {
        this.device = new BABYLON.TransformNode('phone', this.scene);

        const bodyWidth = 1.5;
        const bodyHeight = 3.0;
        const bodyDepth = 0.09;
        const cornerRadius = 0.15;

        // Body material
        this.bodyMaterial = new BABYLON.PBRMetallicRoughnessMaterial('bodyMaterial', this.scene);
        const rgb = this.hexToRgb(this.config.phoneBodyColor);
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

        // Logo (if provided)
        if (this.config.logoUrl) {
            this.createPhoneLogo(bodyDepth);
        }

        // Side buttons
        this.createPhoneButtons(bodyWidth, bodyHeight, bodyDepth);

        // Front camera
        this.createPhoneFrontCamera(bodyDepth);
    }

    /**
     * Create phone body geometry
     */
    createPhoneBody(bodyWidth, bodyHeight, bodyDepth, cornerRadius) {
        // Main body center
        const bodyCenter = BABYLON.MeshBuilder.CreateBox('bodyCenter', {
            width: bodyWidth - (cornerRadius * 2),
            height: bodyHeight - (cornerRadius * 2),
            depth: bodyDepth
        }, this.scene);
        bodyCenter.parent = this.device;
        bodyCenter.material = this.bodyMaterial;

        // Top bar
        const bodyTop = BABYLON.MeshBuilder.CreateBox('bodyTop', {
            width: bodyWidth - (cornerRadius * 2),
            height: cornerRadius * 2,
            depth: bodyDepth
        }, this.scene);
        bodyTop.position.y = (bodyHeight / 2) - cornerRadius;
        bodyTop.parent = this.device;
        bodyTop.material = this.bodyMaterial;

        // Bottom bar
        const bodyBottom = BABYLON.MeshBuilder.CreateBox('bodyBottom', {
            width: bodyWidth - (cornerRadius * 2),
            height: cornerRadius * 2,
            depth: bodyDepth
        }, this.scene);
        bodyBottom.position.y = -(bodyHeight / 2) + cornerRadius;
        bodyBottom.parent = this.device;
        bodyBottom.material = this.bodyMaterial;

        // Left bar
        const bodyLeft = BABYLON.MeshBuilder.CreateBox('bodyLeft', {
            width: cornerRadius * 2,
            height: bodyHeight - (cornerRadius * 2),
            depth: bodyDepth
        }, this.scene);
        bodyLeft.position.x = -(bodyWidth / 2) + cornerRadius;
        bodyLeft.parent = this.device;
        bodyLeft.material = this.bodyMaterial;

        // Right bar
        const bodyRight = BABYLON.MeshBuilder.CreateBox('bodyRight', {
            width: cornerRadius * 2,
            height: bodyHeight - (cornerRadius * 2),
            depth: bodyDepth
        }, this.scene);
        bodyRight.position.x = (bodyWidth / 2) - cornerRadius;
        bodyRight.parent = this.device;
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
            corner.parent = this.device;
            corner.material = this.bodyMaterial;
        });
    }

    /**
     * Create phone screen with rounded corners
     */
    createPhoneScreen(bodyWidth, bodyHeight, bodyDepth, cornerRadius) {
        const screenWidth = bodyWidth - 0.015; // Borda muito fina
        const screenHeight = bodyHeight - 0.015; // Borda muito fina
        const screenCornerRadius = cornerRadius; // Match body corner radius

        this.screenMesh = BABYLON.MeshBuilder.CreatePlane('screen', {
            width: screenWidth,
            height: screenHeight
        }, this.scene);
        this.screenMesh.position.z = (bodyDepth / 2) + 0.001;
        this.screenMesh.parent = this.device;
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
        this.screenMaterial.setFloat("brightness", this.config.brightness);
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

    /**
     * Create phone screen shader (with rounded corners and emissive)
     */
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

                // Corner radius for rounding
                float cornerRadius = 0.07; // ← ALTERE ESTE VALOR para controlar o arredondamento (0.05 a 0.15)

                // Box size - closer to 0.5 means more visible area (almost full screen)
                vec2 boxSize = vec2(0.495, 0.495); // Maximum area, only corners are clipped

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

    /**
     * Create camera module on back of phone
     */
    createPhoneCameraModule(bodyDepth) {
        // 4 cameras arranged in 2x2 grid in upper left
        const cameraSize = 0.255;  // 15% smaller: 0.3 * 0.85 = 0.255

        // Grid 2x2 - upper left position, well spaced and far left
        const cameraPositions = [
            { x: -0.5, y: 1.25 },   // Top left
            { x: -0.2, y: 1.25 },  // Top right
            { x: -0.5, y: 0.96 },   // Bottom left
            { x: -0.2, y: 0.96 }   // Bottom right
        ];

        const cameraMaterial = new BABYLON.PBRMetallicRoughnessMaterial('cameraMaterial', this.scene);
        cameraMaterial.baseColor = new BABYLON.Color3(0.01, 0.01, 0.02);
        cameraMaterial.metallic = 0.85;
        cameraMaterial.roughness = 0.15;

        // Camera ring material (dark)
        const cameraRingMaterial = new BABYLON.StandardMaterial('cameraRingMaterial', this.scene);
        cameraRingMaterial.diffuseColor = new BABYLON.Color3(0.01, 0.01, 0.02);
        cameraRingMaterial.specularColor = new BABYLON.Color3(0.2, 0.2, 0.2);

        // Lens material with camera texture and glass reflections
        const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

        const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('lensMaterial', this.scene);

        // Base texture
        lensMaterial.baseTexture = lensTexture;
        lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);

        // Emissive for subtle glow
        lensMaterial.emissiveTexture = lensTexture;
        lensMaterial.emissiveColor = new BABYLON.Color3(0.2, 0.2, 0.2);

        // Glass-like properties with strong reflections
        lensMaterial.metallic = 0;
        lensMaterial.roughness = 0.05; // Very smooth glass surface

        // Environment reflection for glass effect
        lensMaterial.environmentIntensity = 1.5; // Strong environmental reflections

        // Add clear coat for extra glass shine
        lensMaterial.clearCoat.isEnabled = true;
        lensMaterial.clearCoat.intensity = 1.0;
        lensMaterial.clearCoat.roughness = 0.0; // Perfect glass surface
        lensMaterial.clearCoat.isTintEnabled = false;

        cameraPositions.forEach((pos, index) => {
            // Lens with camera texture - fills entire camera space, no border
            const lens = BABYLON.MeshBuilder.CreateCylinder(`lens${index}`, {
                diameter: cameraSize, // Full size, no border
                height: 0.01725 // 15% higher: 0.015 * 1.15 = 0.01725
            }, this.scene);
            lens.rotation.x = Math.PI / 2;
            lens.position.x = pos.x;
            lens.position.y = pos.y;
            lens.position.z = -(bodyDepth / 2) - 0.008625; // Adjusted for new height: 0.0075 * 1.15
            lens.parent = this.device;
            lens.material = lensMaterial;
        });
    }

    /**
     * Create logo on back of phone
     */
    createPhoneLogo(bodyDepth) {
        const logoPlane = BABYLON.MeshBuilder.CreatePlane('logoPlane', {
            width: 0.32,  // 20% smaller: 0.4 * 0.8 = 0.32
            height: 0.28  // 20% smaller: 0.35 * 0.8 = 0.28
        }, this.scene);
        logoPlane.position.y = 0;  // Centered vertically
        logoPlane.position.z = -(bodyDepth / 2) - 0.001;
        logoPlane.parent = this.device;

        const logoTexture = new BABYLON.Texture(this.config.logoUrl, this.scene, false, true);
        logoTexture.hasAlpha = true;

        this.logoMaterial = new BABYLON.StandardMaterial('logoMaterial', this.scene);
        this.logoMaterial.diffuseTexture = logoTexture;
        this.logoMaterial.diffuseTexture.hasAlpha = true;
        this.logoMaterial.useAlphaFromDiffuseTexture = true;
        this.logoMaterial.specularColor = new BABYLON.Color3(0, 0, 0);
        this.logoMaterial.emissiveColor = new BABYLON.Color3(0, 0, 0);
        this.logoMaterial.backFaceCulling = false;
        logoPlane.material = this.logoMaterial;

        // Set logo color based on body color
        this.updateLogoColor();
    }

    /**
     * Update logo color based on body color (phone only)
     */
    updateLogoColor() {
        if (!this.logoMaterial || !this.bodyMaterial) return;

        if (this.config.phoneLogoColor === 'auto') {
            const bodyColor = this.bodyMaterial.baseColor;
            const luminance = 0.299 * bodyColor.r + 0.587 * bodyColor.g + 0.114 * bodyColor.b;

            if (luminance < 0.5) {
                this.logoMaterial.diffuseColor = new BABYLON.Color3(1, 1, 1);
                this.logoMaterial.ambientColor = new BABYLON.Color3(0.95, 0.95, 0.95);
            } else {
                this.logoMaterial.diffuseColor = new BABYLON.Color3(0, 0, 0);
                this.logoMaterial.ambientColor = new BABYLON.Color3(0.05, 0.05, 0.05);
            }
        } else if (this.config.phoneLogoColor === 'white') {
            this.logoMaterial.diffuseColor = new BABYLON.Color3(1, 1, 1);
        } else if (this.config.phoneLogoColor === 'black') {
            this.logoMaterial.diffuseColor = new BABYLON.Color3(0, 0, 0);
        }
    }

    /**
     * Create side buttons (volume and power) - left side only
     */
    createPhoneButtons(bodyWidth, bodyHeight, bodyDepth) {
        // Button material - same as body but slightly darker
        const buttonMaterial = new BABYLON.PBRMetallicRoughnessMaterial('buttonMaterial', this.scene);
        const bodyColor = this.phoneBodyMaterial ? this.phoneBodyMaterial.baseColor : new BABYLON.Color3(0.09, 0.09, 0.09);
        buttonMaterial.baseColor = new BABYLON.Color3(
            bodyColor.r * 0.8,
            bodyColor.g * 0.8,
            bodyColor.b * 0.8
        );
        buttonMaterial.metallic = 0.95;
        buttonMaterial.roughness = 0.15;

        const buttonWidth = 0.017; // 15% less protruding
        const buttonDepth = bodyDepth * 0.6;
        const capRadius = buttonDepth / 2; // Radius for rounded caps

        // Volume button (left side, upper) - longer for both up/down
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
        volumeButton.parent = this.device;
        volumeButton.material = buttonMaterial;

        // Power button (left side, lower) - smaller
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
        powerButton.parent = this.device;
        powerButton.material = buttonMaterial;
    }

    /**
     * Create front camera (small, centered at top)
     */
    createPhoneFrontCamera(bodyDepth) {
        const cameraSize = 0.08; // Small camera

        // Lens material with camera texture and glass reflections
        const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

        const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('frontCameraLensMaterial', this.scene);

        // Base texture
        lensMaterial.baseTexture = lensTexture;
        lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);

        // Emissive for subtle glow
        lensMaterial.emissiveTexture = lensTexture;
        lensMaterial.emissiveColor = new BABYLON.Color3(0.2, 0.2, 0.2);

        // Glass-like properties with strong reflections
        lensMaterial.metallic = 0;
        lensMaterial.roughness = 0.05; // Very smooth glass surface

        // Environment reflection for glass effect
        lensMaterial.environmentIntensity = 1.5; // Strong environmental reflections

        // Add clear coat for extra glass shine
        lensMaterial.clearCoat.isEnabled = true;
        lensMaterial.clearCoat.intensity = 1.0;
        lensMaterial.clearCoat.roughness = 0.0; // Perfect glass surface
        lensMaterial.clearCoat.isTintEnabled = false;

        // Front camera lens
        const frontCamera = BABYLON.MeshBuilder.CreateCylinder('frontCamera', {
            diameter: cameraSize,
            height: 0.005
        }, this.scene);
        frontCamera.rotation.x = Math.PI / 2;
        frontCamera.position.x = 0; // Centered horizontally
        frontCamera.position.y = 1.35; // At the top
        frontCamera.position.z = (bodyDepth / 2) + 0.003; // In front of screen
        frontCamera.parent = this.device;
        frontCamera.material = lensMaterial;
    }

    // ==========================================
    // NOTEBOOK CREATION
    // ==========================================

    /**
     * Create notebook model (complete from notebook.js)
     */
    createNotebook() {
        this.device = new BABYLON.TransformNode('notebook', this.scene);

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
        this.lidGroup.parent = this.device;
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

        // Set initial angle (75 degrees by default)
        this.setNotebookAngle(this.currentAngle);

        // Create RGB glow layer for keyboard effect (only for letters, not keys)
        this.rgbGlowLayer = new BABYLON.GlowLayer('rgbGlow', this.scene, {
            mainTextureFixedSize: 512,
            blurKernelSize: 16 // Reduced blur to prevent glow bleeding onto keys
        });
        this.rgbGlowLayer.intensity = 0.25; // Reduced intensity to prevent washing out key colors

        // Exclude key meshes from glow layer (keys should NOT glow, only letters)
        this.keyMeshes.forEach(keyMesh => {
            this.rgbGlowLayer.addExcludedMesh(keyMesh);
        });

        // Initially disable glow if RGB is off
        if (!this.rgbEnabled) {
            this.rgbGlowLayer.intensity = 0;
        }

        // Set initial state based on RGB enabled/disabled
        if (!this.rgbEnabled) {
            // RGB is OFF: Set logo and text contrast based on body color
            this.updateLogoContrast();
            this.updateKeyboardTextContrast();
        }
        // Keys automatically follow body color as they're in notebookBodyMaterials

        // RGB animation loop
        this.scene.registerBeforeRender(() => {
            if (this.rgbEnabled) {
                // Enable glow layer for RGB effect
                if (this.rgbGlowLayer) {
                    this.rgbGlowLayer.intensity = 0.25; // Reduced to prevent washing out key colors
                }

                this.rgbHue += 0.5; // Smooth color transition
                if (this.rgbHue > 360) this.rgbHue = 0;

                // Animate LETTERS/TEXT with RGB colors (like the logo)
                // Base color: dark gray (for visibility on any background)
                // Emissive: RGB glow colors
                this.keyTextMaterials.forEach((mat, index) => {
                    const hue = (this.rgbHue + (index * 5)) % 360; // More spread for variety
                    const rgb = this.hslToRgb(hue / 360, 1.0, 0.5); // Full saturation, mid lightness

                    // Dark gray base for letters (visible on dark or light keys)
                    mat.diffuseColor = new BABYLON.Color3(0.3, 0.3, 0.3); // Dark gray base

                    // RGB glow on top (reduced from 3.5 to 2.5 to prevent washing out key colors)
                    mat.emissiveColor = new BABYLON.Color3(rgb.r * 2.5, rgb.g * 2.5, rgb.b * 2.5);

                    // Ensure emissive texture is active for RGB mode
                    if (!mat.emissiveTexture && mat._storedEmissiveTexture) {
                        mat.emissiveTexture = mat._storedEmissiveTexture;
                    }
                    mat.disableLighting = true; // Self-illuminated for RGB
                });

                // KEYS (teclas) always follow body color - they don't change for RGB
                // Keys are controlled separately and follow carcaça color

                // Animate notebook logo - change emissive color for RGB effect
                if (this.notebookLogoMaterial) {
                    const rgb = this.hslToRgb(this.rgbHue / 360, 1.0, 0.5);
                    // Use emissive to colorize the SVG with RGB colors
                    this.notebookLogoMaterial.emissiveColor = new BABYLON.Color3(rgb.r * 1.2, rgb.g * 1.2, rgb.b * 1.2);
                }
            } else {
                // Disable glow layer when RGB is off
                if (this.rgbGlowLayer) {
                    this.rgbGlowLayer.intensity = 0;
                }

                // Update text and logo contrast based on body color
                this.updateKeyboardTextContrast();
                this.updateLogoContrast();
            }
        });
    }

    /**
     * Create rounded base for notebook
     */
    createNotebookRoundedBase(width, depth, height, radius, material) {
        // Center piece
        const center = BABYLON.MeshBuilder.CreateBox('baseCenter', {
            width: width - (radius * 2),
            height: height,
            depth: depth - (radius * 2)
        }, this.scene);
        center.position.y = height / 2;
        center.parent = this.device;
        center.material = material;

        // 4 side pieces
        const top = BABYLON.MeshBuilder.CreateBox('baseTop', {
            width: width - (radius * 2),
            height: height,
            depth: radius * 2
        }, this.scene);
        top.position.y = height / 2;
        top.position.z = -(depth / 2) + radius;
        top.parent = this.device;
        top.material = material;

        const bottom = BABYLON.MeshBuilder.CreateBox('baseBottom', {
            width: width - (radius * 2),
            height: height,
            depth: radius * 2
        }, this.scene);
        bottom.position.y = height / 2;
        bottom.position.z = (depth / 2) - radius;
        bottom.parent = this.device;
        bottom.material = material;

        const left = BABYLON.MeshBuilder.CreateBox('baseLeft', {
            width: radius * 2,
            height: height,
            depth: depth - (radius * 2)
        }, this.scene);
        left.position.y = height / 2;
        left.position.x = -(width / 2) + radius;
        left.parent = this.device;
        left.material = material;

        const right = BABYLON.MeshBuilder.CreateBox('baseRight', {
            width: radius * 2,
            height: height,
            depth: depth - (radius * 2)
        }, this.scene);
        right.position.y = height / 2;
        right.position.x = (width / 2) - radius;
        right.parent = this.device;
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
            corner.parent = this.device;
            corner.material = material;
        });
    }

    /**
     * Create rounded lid for notebook
     */
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

        const bottom = BABYLON.MeshBuilder.CreateBox('lidBottom', {
            width: width - (radius * 2),
            height: radius * 2,
            depth: depth
        }, this.scene);
        bottom.position.y = radius;
        bottom.parent = parent;
        bottom.material = material;

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

    /**
     * Create keyboard with RGB lighting
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
                keyMesh.parent = this.device;

                const keyMat = new BABYLON.StandardMaterial(`keyMat_${rowIndex}_${keyIndex}`, this.scene);
                // Keys start with current body color (from lidMaterial)
                const currentBodyColor = this.notebookLidMaterial ?
                    this.notebookLidMaterial.diffuseColor.clone() :
                    new BABYLON.Color3(0.090, 0.090, 0.090); // RGB(23, 23, 23)
                keyMat.diffuseColor = currentBodyColor;
                keyMat.specularColor = new BABYLON.Color3(0.02, 0.02, 0.02); // Minimal specular to avoid white shine
                keyMat.emissiveColor = new BABYLON.Color3(0, 0, 0);
                keyMesh.material = keyMat;

                // Store key mesh (to exclude from glow layer)
                this.keyMeshes.push(keyMesh);

                // Store key material for RGB control
                this.keyMaterials.push(keyMat);

                // Add to notebookBodyMaterials so keys follow carcaça color automatically
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
        textMaterial.diffuseTexture = dynamicTexture; // For opaque black text on light body
        textMaterial.diffuseColor = new BABYLON.Color3(1.0, 1.0, 1.0); // White by default
        textMaterial.emissiveTexture = dynamicTexture; // For bright white text on dark body
        textMaterial._storedEmissiveTexture = dynamicTexture; // Store for later restoration
        textMaterial.emissiveColor = new BABYLON.Color3(2.0, 2.0, 2.0); // Bright white by default
        textMaterial.opacityTexture = dynamicTexture;
        textMaterial.useAlphaFromDiffuseTexture = true;
        textMaterial.backFaceCulling = false;
        textMaterial.disableLighting = true;
        textMaterial.specularColor = new BABYLON.Color3(0, 0, 0); // No specular shine
        textPlane.material = textMaterial;

        this.keyTextMaterials.push(textMaterial);
        this.keyTextMeshes.push(textPlane); // Store mesh for glow effect
        // Text contrast is updated automatically based on body color
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
        trackpadCenter.parent = this.device;
        trackpadCenter.material = trackpadMaterial;

        // 4 sides
        const trackpadTop = BABYLON.MeshBuilder.CreateBox('trackpadTop', {
            width: trackpadWidth - (trackpadRadius * 2),
            height: trackpadHeight,
            depth: trackpadRadius * 2
        }, this.scene);
        trackpadTop.position.y = trackpadPosY;
        trackpadTop.position.z = trackpadPosZ - (trackpadDepth / 2) + trackpadRadius;
        trackpadTop.parent = this.device;
        trackpadTop.material = trackpadMaterial;

        const trackpadBottom = BABYLON.MeshBuilder.CreateBox('trackpadBottom', {
            width: trackpadWidth - (trackpadRadius * 2),
            height: trackpadHeight,
            depth: trackpadRadius * 2
        }, this.scene);
        trackpadBottom.position.y = trackpadPosY;
        trackpadBottom.position.z = trackpadPosZ + (trackpadDepth / 2) - trackpadRadius;
        trackpadBottom.parent = this.device;
        trackpadBottom.material = trackpadMaterial;

        const trackpadLeft = BABYLON.MeshBuilder.CreateBox('trackpadLeft', {
            width: trackpadRadius * 2,
            height: trackpadHeight,
            depth: trackpadDepth - (trackpadRadius * 2)
        }, this.scene);
        trackpadLeft.position.x = -(trackpadWidth / 2) + trackpadRadius;
        trackpadLeft.position.y = trackpadPosY;
        trackpadLeft.position.z = trackpadPosZ;
        trackpadLeft.parent = this.device;
        trackpadLeft.material = trackpadMaterial;

        const trackpadRight = BABYLON.MeshBuilder.CreateBox('trackpadRight', {
            width: trackpadRadius * 2,
            height: trackpadHeight,
            depth: trackpadDepth - (trackpadRadius * 2)
        }, this.scene);
        trackpadRight.position.x = (trackpadWidth / 2) - trackpadRadius;
        trackpadRight.position.y = trackpadPosY;
        trackpadRight.position.z = trackpadPosZ;
        trackpadRight.parent = this.device;
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
            corner.parent = this.device;
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
        intelBadge.parent = this.device;

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
     * Create notebook screen (simple shader like notebook.js)
     */
    createNotebookScreen(screenWidth, screenHeight, baseHeight, baseDepth) {
        this.screenMesh = BABYLON.MeshBuilder.CreatePlane('screen', {
            width: screenWidth,
            height: screenHeight
        }, this.scene);
        this.screenMesh.position.y = baseDepth / 2;
        this.screenMesh.position.z = (baseHeight * 0.8) / 2 + 0.008; // Touching the frame, same as webcam
        this.screenMesh.parent = this.lidGroup;
        this.screenMesh.rotation.y = Math.PI;

        // Create simple notebook screen shader
        this.createNotebookScreenShader();

        this.screenMaterial = new BABYLON.ShaderMaterial("roundedScreenMaterial", this.scene, {
            vertex: "roundedScreen",
            fragment: "roundedScreen",
        }, {
            attributes: ["position", "uv"],
            uniforms: ["worldViewProjection", "textureSampler", "brightness"],
            needAlphaBlending: false
        });

        this.screenMaterial.setFloat("brightness", this.config.brightness);
        this.screenMaterial.backFaceCulling = false;
        this.screenMaterial.disableLighting = true;

        const defaultTexture = new BABYLON.DynamicTexture('defaultTexture', 2, this.scene, false);
        const defaultCtx = defaultTexture.getContext();
        defaultCtx.fillStyle = '#000000';
        defaultCtx.fillRect(0, 0, 2, 2);
        defaultTexture.update();
        this.screenMaterial.setTexture("textureSampler", defaultTexture);

        this.screenMesh.material = this.screenMaterial;
    }

    /**
     * Create notebook screen shader (simple brightness only)
     */
    createNotebookScreenShader() {
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
            uniform float brightness;

            void main(void) {
                vec4 texColor = texture2D(textureSampler, vUV);
                vec3 finalColor = texColor.rgb * brightness;
                gl_FragColor = vec4(finalColor, 1.0);
            }
        `;
    }

    /**
     * Create webcam
     */
    createNotebookWebcam(baseDepth, baseHeight) {
        // Small camera at top of screen (like phone front camera)
        const cameraSize = 0.1; // Small like phone front camera

        // Camera lens with texture
        const lensTexture = new BABYLON.Texture('assets/images/camera.png', this.scene);

        const lensMaterial = new BABYLON.PBRMetallicRoughnessMaterial('notebookCameraLens', this.scene);
        lensMaterial.baseTexture = lensTexture;
        lensMaterial.baseColor = new BABYLON.Color3(1, 1, 1);
        lensMaterial.emissiveTexture = lensTexture;
        lensMaterial.emissiveColor = new BABYLON.Color3(0.3, 0.3, 0.3);
        lensMaterial.metallic = 0;
        lensMaterial.roughness = 0.05; // Glass-like surface
        lensMaterial.environmentIntensity = 1.5;

        // Add clear coat for glass shine
        lensMaterial.clearCoat.isEnabled = true;
        lensMaterial.clearCoat.intensity = 1.0;
        lensMaterial.clearCoat.roughness = 0.0;

        const webcam = BABYLON.MeshBuilder.CreateCylinder('webcam', {
            diameter: cameraSize,
            height: 0.015 // Slightly thicker for visibility
        }, this.scene);
        webcam.rotation.x = Math.PI / 2;
        webcam.position.y = baseDepth - 0.15; // Top edge of screen (near top border)
        webcam.position.z = (baseHeight * 0.8) / 2 + 0.008; // Touching the frame
        webcam.parent = this.lidGroup;
        webcam.material = lensMaterial;
    }

    /**
     * Create Tata logo on notebook lid back
     */
    createNotebookLogo(baseDepth, baseHeight) {
        if (!this.config.logoUrl) return;

        const tataLogo = BABYLON.MeshBuilder.CreatePlane('tataLogo', {
            width: 0.8,  // 20% menor (1.0 * 0.8)
            height: 0.6  // 20% menor (0.75 * 0.8)
        }, this.scene);
        tataLogo.position.y = baseDepth / 2;
        tataLogo.position.z = -(baseHeight * 0.8) / 2 - 0.001; // Logo rente à tampa traseira
        tataLogo.rotation.y = 0;
        tataLogo.parent = this.lidGroup;

        this.notebookLogoMaterial = new BABYLON.StandardMaterial('tataLogoMaterial', this.scene);
        const tataLogoTexture = new BABYLON.Texture(this.config.logoUrl, this.scene);
        tataLogoTexture.hasAlpha = true;

        this.notebookLogoMaterial.emissiveTexture = tataLogoTexture;
        this.notebookLogoMaterial.emissiveColor = new BABYLON.Color3(1, 1, 1); // Will be RGB animated
        this.notebookLogoMaterial.opacityTexture = tataLogoTexture;
        this.notebookLogoMaterial.useAlphaFromDiffuseTexture = true;
        this.notebookLogoMaterial.backFaceCulling = false;
        this.notebookLogoMaterial.disableLighting = true; // Ignore scene lighting

        tataLogo.material = this.notebookLogoMaterial;

        // Add glow layer for logo only
        if (!this.logoGlowLayer) {
            this.logoGlowLayer = new BABYLON.GlowLayer("logoGlow", this.scene, {
                mainTextureFixedSize: 512,
                blurKernelSize: 64
            });
            this.logoGlowLayer.intensity = 0.6; // More visible glow
        }
        this.logoGlowLayer.addIncludedOnlyMesh(tataLogo);
    }

    /**
     * Create notebook hinges (cylinders connecting base to lid)
     */
    createNotebookHinges(baseWidth, baseDepth, baseHeight) {
        // Hinge material - uses Standard material so it can change color properly
        const hingeMaterial = new BABYLON.StandardMaterial('hingeMaterial', this.scene);
        hingeMaterial.diffuseColor = new BABYLON.Color3(0.090, 0.090, 0.090); // RGB(23, 23, 23) - Same as body
        hingeMaterial.specularColor = new BABYLON.Color3(0.5, 0.5, 0.5); // Metallic look
        hingeMaterial.specularPower = 128; // Very shiny for metallic appearance

        // Add hinge material to body materials so it changes with carcaça color
        this.notebookBodyMaterials.push(hingeMaterial);

        const hingeRadius = 0.06; // Small discrete cylinders
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
        leftHinge.parent = this.device;
        leftHinge.material = hingeMaterial;

        // Right hinge - espelhado no eixo X
        const rightHinge = BABYLON.MeshBuilder.CreateCylinder('rightHinge', {
            diameter: hingeRadius * 2,
            height: hingeLength,
            tessellation: 16
        }, this.scene);
        rightHinge.rotation.z = Math.PI / 2;
        rightHinge.position.x = -3.586; // Espelhado
        rightHinge.position.y = 0.164;  // Mesma posição
        rightHinge.position.z = -2.992; // Mesma posição
        rightHinge.parent = this.device;
        rightHinge.material = hingeMaterial;

        // Store references for position logging
        this.hinges = {
            left: leftHinge,
            right: rightHinge
        };
    }


    /**
     * Set notebook opening angle
     */
    setNotebookAngle(degrees) {
        if (!this.lidGroup) return;

        this.currentAngle = degrees;
        const radians = BABYLON.Tools.ToRadians(degrees);
        this.lidGroup.rotation.x = -radians + Math.PI / 2;
    }

    /**
     * Toggle RGB keyboard effect (notebook only)
     */
    toggleRGB(enabled) {
        this.rgbEnabled = enabled;

        // Control glow layer
        if (this.rgbGlowLayer) {
            this.rgbGlowLayer.intensity = enabled ? 0.25 : 0; // Reduced to prevent washing out key colors
        }

        if (enabled) {
            // RGB ON: Keys stay at current carcaça color (do not change)
            // Ensure text materials have emissive texture for RGB animation
            this.keyTextMaterials.forEach(mat => {
                if (!mat.emissiveTexture && mat._storedEmissiveTexture) {
                    mat.emissiveTexture = mat._storedEmissiveTexture;
                }
                mat.disableLighting = true;
            });
        } else {
            // RGB OFF: Keys already follow carcaça color (no change needed)
            // Just update logo and text contrast
            if (this.notebookLogoMaterial) {
                this.updateLogoContrast();
            }
            this.updateKeyboardTextContrast();
        }
    }

    /**
     * Update notebook logo contrast based on notebook body color (not background)
     */
    updateLogoContrast() {
        if (!this.notebookLogoMaterial || this.rgbEnabled) return;

        // Get notebook body color (lid material)
        let bodyColor;
        if (this.notebookLidMaterial && this.notebookLidMaterial.diffuseColor) {
            bodyColor = this.notebookLidMaterial.diffuseColor;
        } else {
            // Fallback to default RGB(23, 23, 23)
            bodyColor = new BABYLON.Color3(0.090, 0.090, 0.090);
        }

        // Calculate luminance of notebook body
        const luminance = 0.299 * bodyColor.r + 0.587 * bodyColor.g + 0.114 * bodyColor.b;

        // Threshold: if body is darker than 0.3, use white logo; otherwise use black
        if (luminance < 0.3) {
            // Dark body - white logo
            this.notebookLogoMaterial.emissiveColor = new BABYLON.Color3(1, 1, 1);
        } else {
            // Light body - black logo
            this.notebookLogoMaterial.emissiveColor = new BABYLON.Color3(0.1, 0.1, 0.1);
        }
    }

    /**
     * Update keyboard text contrast based on body color
     */
    updateKeyboardTextContrast() {
        if (this.rgbEnabled) return;

        // Get notebook body color (keys material)
        let bodyColor;
        if (this.notebookLidMaterial && this.notebookLidMaterial.diffuseColor) {
            bodyColor = this.notebookLidMaterial.diffuseColor;
        } else {
            bodyColor = new BABYLON.Color3(0.090, 0.090, 0.090); // RGB(23, 23, 23)
        }

        // Calculate luminance
        const luminance = 0.299 * bodyColor.r + 0.587 * bodyColor.g + 0.114 * bodyColor.b;

        // Update all key text materials
        this.keyTextMaterials.forEach(mat => {
            if (luminance < 0.5) {
                // Dark body - bright white emissive text
                mat.emissiveColor = new BABYLON.Color3(2.0, 2.0, 2.0);
                mat.diffuseColor = new BABYLON.Color3(1.0, 1.0, 1.0);
                mat.emissiveTexture = mat._storedEmissiveTexture; // Restore emissive texture
                mat.disableLighting = true; // Self-illuminated
                mat.specularColor = new BABYLON.Color3(0, 0, 0); // No specular shine
            } else {
                // Light body - completely remove emissive, use only opaque diffuse
                mat.emissiveColor = new BABYLON.Color3(0.0, 0.0, 0.0);
                mat.diffuseColor = new BABYLON.Color3(0.0, 0.0, 0.0);
                mat.emissiveTexture = null; // REMOVE emissive texture completely
                mat.disableLighting = false; // Normal lighting for opaque rendering
                mat.specularColor = new BABYLON.Color3(0, 0, 0); // No specular shine
            }
        });
    }

    /**
     * HSL to RGB conversion (for RGB keyboard)
     */
    hslToRgb(h, s, l) {
        let r, g, b;

        if (s === 0) {
            r = g = b = l;
        } else {
            const hue2rgb = (p, q, t) => {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1/6) return p + (q - p) * 6 * t;
                if (t < 1/2) return q;
                if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
                return p;
            };

            const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            const p = 2 * l - q;
            r = hue2rgb(p, q, h + 1/3);
            g = hue2rgb(p, q, h);
            b = hue2rgb(p, q, h - 1/3);
        }

        return { r, g, b };
    }

    // ==========================================
    // MEDIA LOADING (Common for both devices)
    // ==========================================

    /**
     * Load default video (notebook only)
     */
    loadDefaultVideo() {
        return new Promise((resolve, reject) => {
            const videoElement = document.createElement('video');
            videoElement.src = this.config.defaultVideoPath;
            videoElement.loop = true;
            videoElement.muted = true;
            videoElement.playsInline = true;
            videoElement.autoplay = true;

            videoElement.addEventListener('canplaythrough', () => {
                videoElement.play().then(() => {
                    const videoTexture = new BABYLON.VideoTexture(
                        'videoTexture',
                        videoElement,
                        this.scene,
                        false,
                        false,
                        BABYLON.Texture.TRILINEAR_SAMPLINGMODE
                    );

                    this.currentVideoTexture = videoTexture;
                    this.screenMaterial.setTexture("textureSampler", videoTexture);

                    if (this.config.deviceType === 'phone') {
                        this.screenMaterial.setInt("hasTexture", 1);
                    }

                    resolve();
                }).catch(reject);
            }, { once: true });

            videoElement.addEventListener('error', reject);
        });
    }

    /**
     * Load image onto screen
     */
    loadImage(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = (e) => {
                if (this.currentVideoTexture) {
                    this.currentVideoTexture.video.pause();
                    this.currentVideoTexture.dispose();
                    this.currentVideoTexture = null;
                }

                const texture = new BABYLON.Texture(
                    e.target.result,
                    this.scene,
                    false,
                    true,
                    BABYLON.Texture.TRILINEAR_SAMPLINGMODE
                );

                texture.anisotropicFilteringLevel = 16;

                texture.onLoadObservable.addOnce(() => {
                    this.screenMaterial.setTexture("textureSampler", texture);

                    if (this.config.deviceType === 'phone') {
                        this.screenMaterial.setInt("hasTexture", 1);
                    }

                    resolve();
                });
            };

            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    /**
     * Load video onto screen
     */
    loadVideo(file) {
        return new Promise((resolve, reject) => {
            if (this.currentVideoTexture) {
                this.currentVideoTexture.video.pause();
                this.currentVideoTexture.dispose();
                this.currentVideoTexture = null;
            }

            const videoUrl = URL.createObjectURL(file);
            const videoElement = document.createElement('video');
            videoElement.src = videoUrl;
            videoElement.loop = true;
            videoElement.muted = true;
            videoElement.playsInline = true;
            videoElement.crossOrigin = 'anonymous';
            videoElement.preload = 'auto';
            videoElement.autoplay = false;

            videoElement.addEventListener('canplaythrough', () => {
                const videoTexture = new BABYLON.VideoTexture(
                    'videoTexture',
                    videoElement,
                    this.scene,
                    true,
                    false,
                    BABYLON.Texture.TRILINEAR_SAMPLINGMODE,
                    {
                        autoPlay: false,
                        loop: true,
                        muted: true,
                        autoUpdateTexture: true
                    }
                );

                videoTexture.anisotropicFilteringLevel = 16;
                this.currentVideoTexture = videoTexture;

                this.screenMaterial.setTexture("textureSampler", videoTexture);

                if (this.config.deviceType === 'phone') {
                    this.screenMaterial.setInt("hasTexture", 1);
                }

                videoElement.play().then(() => {
                    resolve();
                }).catch(reject);
            }, { once: true });

            videoElement.addEventListener('error', reject);
        });
    }

    /**
     * Clear screen
     */
    clearScreen() {
        if (this.currentVideoTexture) {
            this.currentVideoTexture.video.pause();
            this.currentVideoTexture.dispose();
            this.currentVideoTexture = null;
        }

        const defaultTexture = new BABYLON.DynamicTexture('defaultTexture', 2, this.scene, false);
        const defaultCtx = defaultTexture.getContext();

        if (this.config.deviceType === 'phone') {
            defaultCtx.fillStyle = '#010102';
        } else {
            defaultCtx.fillStyle = '#000000';
        }

        defaultCtx.fillRect(0, 0, 2, 2);
        defaultTexture.update();

        this.screenMaterial.setTexture("textureSampler", defaultTexture);

        if (this.config.deviceType === 'phone') {
            this.screenMaterial.setInt("hasTexture", 0);
        }
    }

    // ==========================================
    // ENTRANCE ANIMATIONS (for both devices)
    // ==========================================

    /**
     * Play entrance animation
     */
    playEntranceAnimation(type = 'dramatic') {
        this.isPlayingEntrance = true;

        const animations = {
            dramatic: () => this.entranceDramatic(),
            fadeZoom: () => this.entranceFadeZoom(),
            spiral: () => this.entranceSpiral(),
            flip: () => this.entranceFlip(),
            opening: () => this.entranceOpening() // Special for notebook
        };

        const animation = animations[type] || animations.dramatic;
        animation();
    }

    /**
     * Dramatic entrance animation
     */
    entranceDramatic() {
        const duration = 1200;
        const startTime = Date.now();

        this.device.visibility = 0;
        this.device.rotation.y = -Math.PI * 4;
        this.device.rotation.x = Math.PI / 2;
        this.device.rotation.z = Math.PI / 3;
        this.device.scaling = new BABYLON.Vector3(0.2, 0.2, 0.2);
        this.device.position.y = 3;

        // Se for notebook, iniciar tampa fechada
        if (this.config.deviceType === 'notebook' && this.lidGroup) {
            this.setNotebookAngle(0);
        }

        // Get target camera position
        const targetCamPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        // Start camera from farther position
        const startAlpha = targetCamPos.alpha;
        const startBeta = targetCamPos.beta;
        const startRadius = targetCamPos.radius * 2.5;

        const interval = setInterval(() => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 4);

            this.device.visibility = Math.max(0, (progress - 0.1) * 1.11);
            this.device.rotation.y = -Math.PI * 4 * (1 - eased);
            this.device.rotation.x = Math.PI / 2 * (1 - eased);
            this.device.rotation.z = Math.PI / 3 * (1 - eased);
            this.device.scaling.set(0.2 + 0.8 * eased, 0.2 + 0.8 * eased, 0.2 + 0.8 * eased);
            this.device.position.y = 3 * (1 - eased);

            // Animate camera zoom in
            this.camera.radius = startRadius + (targetCamPos.radius - startRadius) * eased;

            // Se for notebook, animar abertura da tampa
            if (this.config.deviceType === 'notebook' && this.lidGroup) {
                const targetAngle = this.config.notebookAngle || 100;
                const currentAngle = targetAngle * eased;
                this.setNotebookAngle(currentAngle);
            }

            if (progress >= 1) {
                clearInterval(interval);
                this.resetDeviceState();
            }
        }, 16);
    }

    /**
     * Fade zoom entrance animation
     */
    entranceFadeZoom() {
        const duration = 1000;
        const startTime = Date.now();

        this.device.visibility = 0;
        this.device.rotation.set(0, 0, 0);
        this.device.scaling = new BABYLON.Vector3(0.1, 0.1, 0.1);
        this.device.position.y = 0;

        // Se for notebook, iniciar tampa fechada
        if (this.config.deviceType === 'notebook' && this.lidGroup) {
            this.setNotebookAngle(0);
        }

        // Get target camera position
        const targetCamPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        // Start camera from farther position
        const startRadius = targetCamPos.radius * 2;

        const interval = setInterval(() => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);

            this.device.visibility = eased;
            this.device.scaling.set(0.1 + 0.9 * eased, 0.1 + 0.9 * eased, 0.1 + 0.9 * eased);

            // Animate camera zoom in
            this.camera.radius = startRadius + (targetCamPos.radius - startRadius) * eased;

            // Se for notebook, animar abertura da tampa
            if (this.config.deviceType === 'notebook' && this.lidGroup) {
                const targetAngle = this.config.notebookAngle || 100;
                const currentAngle = targetAngle * eased;
                this.setNotebookAngle(currentAngle);
            }

            if (progress >= 1) {
                clearInterval(interval);
                this.resetDeviceState();
            }
        }, 16);
    }

    /**
     * Spiral entrance animation
     */
    entranceSpiral() {
        const duration = 1500;
        const startTime = Date.now();

        this.device.visibility = 0;
        this.device.rotation.set(0, 0, 0);
        this.device.scaling = new BABYLON.Vector3(0.5, 0.5, 0.5);
        this.device.position.set(5, 5, 0);

        // Se for notebook, iniciar tampa fechada
        if (this.config.deviceType === 'notebook' && this.lidGroup) {
            this.setNotebookAngle(0);
        }

        // Get target camera position
        const targetCamPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        // Start camera from farther position
        const startRadius = targetCamPos.radius * 2.5;

        const interval = setInterval(() => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);

            this.device.visibility = Math.max(0, (progress - 0.15) * 1.18);

            const spiralRadius = 5 * (1 - eased);
            const spiralAngle = progress * Math.PI * 4;
            this.device.position.x = Math.cos(spiralAngle) * spiralRadius;
            this.device.position.y = Math.sin(spiralAngle) * spiralRadius;
            this.device.rotation.y = spiralAngle;
            this.device.scaling.set(0.5 + 0.5 * eased, 0.5 + 0.5 * eased, 0.5 + 0.5 * eased);

            // Animate camera zoom in
            this.camera.radius = startRadius + (targetCamPos.radius - startRadius) * eased;

            // Se for notebook, animar abertura da tampa
            if (this.config.deviceType === 'notebook' && this.lidGroup) {
                const targetAngle = this.config.notebookAngle || 100;
                const currentAngle = targetAngle * eased;
                this.setNotebookAngle(currentAngle);
            }

            if (progress >= 1) {
                clearInterval(interval);
                this.resetDeviceState();
            }
        }, 16);
    }

    /**
     * Flip entrance animation
     */
    entranceFlip() {
        const duration = 900;
        const startTime = Date.now();

        this.device.visibility = 1;
        this.device.rotation.set(0, Math.PI, 0);
        this.device.scaling = new BABYLON.Vector3(1, 1, 1);
        this.device.position.y = 0;

        // Se for notebook, iniciar tampa fechada
        if (this.config.deviceType === 'notebook' && this.lidGroup) {
            this.setNotebookAngle(0);
        }

        // Get target camera position
        const targetCamPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        // Start camera from farther position
        const startRadius = targetCamPos.radius * 1.5;

        const interval = setInterval(() => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);

            this.device.rotation.y = Math.PI * (1 - eased);

            // Animate camera zoom in
            this.camera.radius = startRadius + (targetCamPos.radius - startRadius) * eased;

            // Se for notebook, animar abertura da tampa
            if (this.config.deviceType === 'notebook' && this.lidGroup) {
                const targetAngle = this.config.notebookAngle || 100;
                const currentAngle = targetAngle * eased;
                this.setNotebookAngle(currentAngle);
            }

            if (progress >= 1) {
                clearInterval(interval);
                this.resetDeviceState();
            }
        }, 16);
    }

    /**
     * Opening entrance animation (special for notebook - lid opens from 0° to 75°)
     */
    entranceOpening() {
        if (this.config.deviceType !== 'notebook') {
            // Fallback to dramatic for non-notebooks
            this.entranceDramatic();
            return;
        }

        const duration = 1200;
        const startTime = Date.now();
        const targetAngle = this.currentAngle; // Usually 100°

        this.device.visibility = 1;
        this.device.rotation.set(0, 0, 0);
        this.device.scaling = new BABYLON.Vector3(1, 1, 1);
        this.device.position.set(0, 0, 0);

        // Start with lid closed (0°)
        this.setNotebookAngle(0);

        // Get target camera position
        const targetCamPos = this.config.notebookCameraPosition;

        // Start camera from farther position
        const startRadius = targetCamPos.radius * 1.8;

        const interval = setInterval(() => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);

            // Smoothly open lid from 0° to target angle
            const currentAngle = targetAngle * eased;
            this.setNotebookAngle(currentAngle);

            // Animate camera zoom in
            this.camera.radius = startRadius + (targetCamPos.radius - startRadius) * eased;

            if (progress >= 1) {
                clearInterval(interval);
                this.resetDeviceState();
            }
        }, 16);
    }

    /**
     * Reset device state after entrance
     */
    resetDeviceState() {
        this.device.visibility = 1;
        this.device.rotation.set(0, 0, 0);
        this.device.scaling = new BABYLON.Vector3(1, 1, 1);
        this.device.position.set(0, 0, 0);
        this.resetCamera();
        this.animationStartTime = Date.now();
        this.isPlayingEntrance = false;

        // Restore notebook angle if needed
        if (this.config.deviceType === 'notebook') {
            this.setNotebookAngle(this.currentAngle);
        }
    }

    // ==========================================
    // LOOP ANIMATIONS (for both devices)
    // ==========================================

    /**
     * Update animation loop
     */
    updateAnimation() {
        if (!this.device || this.isPlayingEntrance) return;

        const time = (Date.now() - this.animationStartTime) / 1000;

        switch (this.currentAnimation) {
            case 'spin':
                this.animateSpin(time);
                break;
            case 'quickFlip':
                this.animateQuickFlip(time);
                break;
            case 'tilt':
                this.animateTilt(time);
                break;
            case 'float':
                this.animateFloat(time, false);
                break;
            case 'floatTilted':
                this.animateFloat(time, true);
                break;
        }
    }

    /**
     * Spin animation
     */
    animateSpin(time) {
        this.device.rotation.y = time * 0.3 * this.animationSpeed;
        this.device.rotation.x = 0;
        this.device.rotation.z = 0;
        this.device.position.y = 0;
    }

    /**
     * Quick flip animation
     */
    animateQuickFlip(time) {
        const cycleTime = 8 / this.animationSpeed;
        const t = (time % cycleTime) / cycleTime;

        let rotation;
        if (t < 0.75) {
            rotation = (t / 0.75) * Math.PI;
        } else {
            rotation = Math.PI + ((t - 0.75) / 0.25) * Math.PI;
        }

        this.device.rotation.y = rotation;
        this.device.rotation.x = 0;
        this.device.rotation.z = 0;
        this.device.position.y = 0;
    }

    /**
     * Tilt animation
     */
    animateTilt(time) {
        const period = 3.5 / this.animationSpeed;
        const maxTilt = Math.PI / 6;
        const tilt = Math.sin(time * (Math.PI * 2 / period)) * maxTilt;

        this.device.rotation.y = tilt;
        this.device.rotation.x = 0;
        this.device.rotation.z = 0;
        this.device.position.y = 0;
    }

    /**
     * Float animation
     */
    animateFloat(time, tilted) {
        const floatPeriod = 4 / this.animationSpeed;
        const floatHeight = 0.12;

        this.device.position.y = Math.sin(time * (Math.PI * 2 / floatPeriod)) * floatHeight;
        this.device.rotation.y = 0;

        if (tilted) {
            const tiltPeriod = 5 / this.animationSpeed;
            this.device.rotation.x = Math.sin(time * (Math.PI * 2 / tiltPeriod)) * 0.05;
            this.device.rotation.z = Math.sin(time * (Math.PI * 2 / (tiltPeriod * 1.3))) * 0.04;
        } else {
            this.device.rotation.x = 0;
            this.device.rotation.z = 0;
        }
    }

    // ==========================================
    // PUBLIC API
    // ==========================================

    /**
     * Set animation mode
     */
    setAnimation(animationType) {
        this.currentAnimation = animationType;
        this.animationStartTime = Date.now();

        this.device.position.set(0, 0, 0);
        this.device.rotation.set(0, 0, 0);
        this.device.scaling.set(1, 1, 1);

        if (this.config.deviceType === 'notebook') {
            this.setNotebookAngle(this.currentAngle);
        }

        this.resetCamera();
    }

    /**
     * Set animation speed
     */
    setAnimationSpeed(speed) {
        this.animationSpeed = speed;
    }

    /**
     * Set screen brightness
     */
    setBrightness(brightness) {
        if (this.screenMaterial) {
            this.screenMaterial.setFloat('brightness', brightness);
        }
    }

    /**
     * Set body color (phone only)
     */
    setBodyColor(hexColor) {
        if (this.bodyMaterial && this.config.deviceType === 'phone') {
            const rgb = this.hexToRgb(hexColor);
            this.bodyMaterial.baseColor = new BABYLON.Color3(rgb.r, rgb.g, rgb.b);
            this.updateLogoColor();
        }
    }

    /**
     * Set background color
     */
    setBackgroundColor(hexColor) {
        if (this.scene) {
            const rgb = this.hexToRgb(hexColor);
            this.scene.clearColor = new BABYLON.Color4(rgb.r, rgb.g, rgb.b, 1);
        }
    }

    /**
     * Set phone body color
     */
    setPhoneBodyColor(hexColor) {
        if (this.config.deviceType === 'phone' && this.phoneBodyMaterial) {
            const rgb = this.hexToRgb(hexColor);
            this.phoneBodyMaterial.baseColor = new BABYLON.Color3(rgb.r, rgb.g, rgb.b);
        }
    }

    /**
     * Set notebook body color
     */
    setNotebookBodyColor(hexColor) {
        if (this.config.deviceType === 'notebook' && this.notebookBodyMaterials.length > 0) {
            const rgb = this.hexToRgb(hexColor);
            const color = new BABYLON.Color3(rgb.r, rgb.g, rgb.b);

            // Apply color to all body materials (INCLUDING keys)
            this.notebookBodyMaterials.forEach(material => {
                if (material && material.diffuseColor) {
                    material.diffuseColor = color.clone();
                }
            });

            // Force material refresh for keys to ensure visual update
            this.keyMaterials.forEach(keyMat => {
                keyMat.markDirty(BABYLON.Material.AllDirtyFlag);
            });

            // Update logo and text contrast based on new body color (only if RGB is off)
            if (!this.rgbEnabled) {
                this.updateLogoContrast();
                this.updateKeyboardTextContrast();
            }
        }
    }

    /**
     * Get current camera position
     */
    getCameraPosition() {
        return {
            alpha: this.camera.alpha,
            beta: this.camera.beta,
            radius: this.camera.radius
        };
    }

    /**
     * Reset camera to default position
     */
    resetCamera() {
        if (!this.camera) return;

        const camPos = this.config.deviceType === 'notebook'
            ? this.config.notebookCameraPosition
            : this.config.phoneCameraPosition;

        BABYLON.Animation.CreateAndStartAnimation(
            'cameraAlpha',
            this.camera,
            'alpha',
            60,
            30,
            this.camera.alpha,
            camPos.alpha,
            BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );

        BABYLON.Animation.CreateAndStartAnimation(
            'cameraBeta',
            this.camera,
            'beta',
            60,
            30,
            this.camera.beta,
            camPos.beta,
            BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );

        BABYLON.Animation.CreateAndStartAnimation(
            'cameraRadius',
            this.camera,
            'radius',
            60,
            30,
            this.camera.radius,
            camPos.radius,
            BABYLON.Animation.ANIMATIONLOOPMODE_CONSTANT
        );
    }

    /**
     * Setup mouse logging for camera positioning
     */
    setupMouseLogging() {
        let lastLogTime = 0;
        const logInterval = 500; // Log every 500ms when mouse is used

        this.canvas.addEventListener('mouseup', () => {
            // Camera logging disabled to prevent interference with form inputs
            // const now = Date.now();
            // if (now - lastLogTime > logInterval) {
            //     lastLogTime = now;
            //     const device = this.config.deviceType;
            //     console.log(`[${device.toUpperCase()}] Camera Configuration (after mouse adjustment):`, {
            //         target: { x: this.camera.target.x, y: this.camera.target.y, z: this.camera.target.z },
            //         alpha: this.camera.alpha,
            //         beta: this.camera.beta,
            //         radius: this.camera.radius
            //     });
            // }
        });

        // Also log on wheel (zoom)
        this.canvas.addEventListener('wheel', () => {
            const now = Date.now();
            if (now - lastLogTime > logInterval) {
                lastLogTime = now;
                setTimeout(() => {
                    const device = this.config.deviceType;
                    console.log(`[${device.toUpperCase()}] Zoom: radius = ${this.camera.radius}`);
                }, 100);
            }
        });
    }

    /**
     * Setup keyboard controls for camera positioning
     * DISABLED: Interferes with form inputs
     */
    setupKeyboardControls() {
        // Keyboard controls disabled to prevent interference with form inputs
        return;
        /* DISABLED
        window.addEventListener('keydown', (event) => {
            const moveStep = 0.5;
            const rotateStep = 0.1;
            const device = this.config.deviceType;

            switch(event.key) {
                case 'ArrowLeft':
                    // Move camera target to the left (device appears more to the right)
                    this.camera.target.x -= moveStep;
                    event.preventDefault();
                    break;
                case 'ArrowRight':
                    // Move camera target to the right (device appears more to the left)
                    this.camera.target.x += moveStep;
                    event.preventDefault();
                    break;
                case 'ArrowUp':
                    // Move camera target up (device appears lower)
                    this.camera.target.y += moveStep;
                    event.preventDefault();
                    break;
                case 'ArrowDown':
                    // Move camera target down (device appears higher)
                    this.camera.target.y -= moveStep;
                    event.preventDefault();
                    break;
                case 'a':
                case 'A':
                    // Rotate left
                    this.camera.alpha -= rotateStep;
                    event.preventDefault();
                    break;
                case 'd':
                case 'D':
                    // Rotate right
                    this.camera.alpha += rotateStep;
                    event.preventDefault();
                    break;
                case 'w':
                case 'W':
                    // Rotate up
                    this.camera.beta -= rotateStep;
                    event.preventDefault();
                    break;
                case 's':
                case 'S':
                    // Rotate down
                    this.camera.beta += rotateStep;
                    event.preventDefault();
                    break;
                case '+':
                case '=':
                    this.camera.radius -= 0.5;
                    event.preventDefault();
                    break;
                case '-':
                case '_':
                    this.camera.radius += 0.5;
                    event.preventDefault();
                    break;
            }

            // Camera logging disabled to prevent interference with form inputs
            // console.log(`[${device.toUpperCase()}] Camera Configuration:`, {
            //     target: { x: this.camera.target.x, y: this.camera.target.y, z: this.camera.target.z },
            //     alpha: this.camera.alpha,
            //     beta: this.camera.beta,
            //     radius: this.camera.radius
            // });
        });
        */ // END DISABLED
    }

    /**
     * Utility: Convert hex to RGB
     */
    hexToRgb(hex) {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        return result ? {
            r: parseInt(result[1], 16) / 255,
            g: parseInt(result[2], 16) / 255,
            b: parseInt(result[3], 16) / 255
        } : { r: 0, g: 0, b: 0 };
    }


    /**
     * Pause rendering to save performance (soft pause - stops render loop)
     */
    pause() {
        if (!this.engine) return;

        console.log(`[DeviceViewer] ⏸️ Pausing viewer: ${this.config.canvasId}`);

        // Stop render loop
        this.engine.stopRenderLoop();

        // Pause video if playing
        if (this.currentVideoTexture && this.currentVideoTexture.video) {
            this.currentVideoTexture.video.pause();
        }

        this.isPaused = true;
    }

    /**
     * Resume rendering (if not disposed)
     */
    resume() {
        if (this.isDisposed) {
            // Re-initialize if disposed
            console.log(`[DeviceViewer] ♻️ Re-initializing disposed viewer: ${this.config.canvasId}`);
            this.isDisposed = false;
            this.init();
            return;
        }

        if (!this.engine || !this.scene) return;

        console.log(`[DeviceViewer] ▶️ Resuming viewer: ${this.config.canvasId}`);

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

        // Resume video if it was playing
        if (this.currentVideoTexture && this.currentVideoTexture.video) {
            this.currentVideoTexture.video.play().catch(e => {
                // Silently catch autoplay errors
            });
        }

        this.isPaused = false;
    }

    /**
     * Dispose engine and scene to free memory/CPU (aggressive optimization)
     */
    dispose() {
        if (!this.engine || this.isDisposed) {
            console.log(`[DeviceViewer] ⚠️ Already disposed or no engine: ${this.config.canvasId}`);
            return;
        }

        console.log(`[DeviceViewer] 🗑️ Starting disposal: ${this.config.canvasId}`);

        const memoryBefore = this.scene ? this.scene.totalVertices : 0;

        // Stop render loop
        this.engine.stopRenderLoop();
        console.log(`[DeviceViewer]   ✓ Render loop stopped`);

        // Dispose video texture
        if (this.currentVideoTexture) {
            this.currentVideoTexture.video.pause();
            this.currentVideoTexture.dispose();
            this.currentVideoTexture = null;
            console.log(`[DeviceViewer]   ✓ Video texture disposed`);
        }

        // Dispose scene and all meshes/materials
        if (this.scene) {
            const meshCount = this.scene.meshes.length;
            const materialCount = this.scene.materials.length;
            const textureCount = this.scene.textures.length;

            console.log(`[DeviceViewer]   📊 Disposing: ${meshCount} meshes, ${materialCount} materials, ${textureCount} textures`);

            this.scene.dispose();
            this.scene = null;
            console.log(`[DeviceViewer]   ✓ Scene disposed (freed ${memoryBefore} vertices)`);
        }

        // Dispose engine and WebGL context
        if (this.engine) {
            this.engine.dispose();
            this.engine = null;
            console.log(`[DeviceViewer]   ✓ Engine disposed (WebGL context released)`);
        }

        // Clear all references
        this.camera = null;
        this.device = null;
        this.notebookBodyMaterials = [];
        this.phoneBodyMaterials = [];

        this.isDisposed = true;
        this.isPaused = false;

        console.log(`[DeviceViewer] ✅ FULLY DISPOSED: ${this.config.canvasId} - Memory should be freed`);
    }
}

// Export for use in modules or as global
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DeviceViewer;
}

// Explicitly expose to global window object for browser scripts (Flutter interop)
if (typeof window !== 'undefined') {
    window.DeviceViewer = DeviceViewer;
    console.log('[DeviceViewer] ✅ Explicitly assigned to window.DeviceViewer');
}
