import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { HDRLoader } from 'three/examples/jsm/loaders/HDRLoader.js';

export class Simulator {
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  private controls: OrbitControls;
  private mixer?: THREE.AnimationMixer;
  private clock: THREE.Clock;
  private animations: Map<string, THREE.AnimationAction> = new Map();
  public robotModel?: THREE.Group;
  public groundMaterial?: THREE.MeshStandardMaterial;

  constructor(container: HTMLElement) {
    // --- Scene ---
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0x1a2a4f, 10, 25);

    // --- Camera ---
    this.camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 1000);
    this.camera.position.set(0.8, 1, 1.5);
    this.camera.lookAt(0, 0, 0);

    // --- Renderer ---
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setSize(container.clientWidth, container.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.7;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    container.appendChild(this.renderer.domElement);

    // --- Skybox and Environment Lighting ---
    const hdrLoader = new HDRLoader();
    hdrLoader.load('/Cyberpunk.hdr', (texture) => {
      texture.mapping = THREE.EquirectangularReflectionMapping;
      this.scene.background = texture;
      this.scene.environment = texture;
    });

    // --- Lighting ---
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.2);
    this.scene.add(ambientLight);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.3);
    directionalLight.position.set(3, 5, 4);
    this.scene.add(directionalLight);

    // --- Controls ---
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.target.set(0, 0.3, 0);
    
    // --- Camera Constraints ---
    // 1. Prevent camera from going below ground
    this.controls.maxPolarAngle = Math.PI / 2 - 0.05;
    // 2. Prevent zooming too far in or out
    this.controls.minDistance = 1.0;
    this.controls.maxDistance = 6.0;

    // --- Ground ---
    const textureLoader = new THREE.TextureLoader();
    const colorTexture = textureLoader.load('/rubber_tiles_diff_2k.jpg');
    const normalTexture = textureLoader.load('/rubber_tiles_nor_gl_2k.jpg');
    const roughnessTexture = textureLoader.load('/rubber_tiles_rough_2k.jpg');
    
    for (const texture of [colorTexture, normalTexture, roughnessTexture]) {
      texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
      texture.repeat.set(8, 8);
    }

    const groundGeometry = new THREE.PlaneGeometry(20, 20);
    this.groundMaterial = new THREE.MeshStandardMaterial({
        map: colorTexture,
        normalMap: normalTexture,
        roughnessMap: roughnessTexture,
        metalness: 0.1
    });
    const ground = new THREE.Mesh(groundGeometry, this.groundMaterial);
    ground.rotation.x = -Math.PI / 2;
    this.scene.add(ground);
    
    // --- Event Listeners ---
    this.clock = new THREE.Clock();
    window.addEventListener('resize', () => this.onWindowResize(container), false);
    this.animate();
  }

  public async loadRobotModel(url: string): Promise<void> {
    const loader = new GLTFLoader();
    try {
      const gltf = await loader.loadAsync(url);
      this.robotModel = gltf.scene;

      const masterScale = 0.4;
      this.robotModel.scale.set(masterScale, masterScale, masterScale);
      
      const box = new THREE.Box3().setFromObject(this.robotModel);
      const center = box.getCenter(new THREE.Vector3());
      this.robotModel.position.x -= center.x;
      this.robotModel.position.z -= center.z;
      this.robotModel.position.y -= box.min.y;
      
      this.scene.add(this.robotModel);
      console.log('Robot model loaded successfully.');

      this.mixer = new THREE.AnimationMixer(this.robotModel);
      gltf.animations.forEach((clip) => {
        const action = this.mixer!.clipAction(clip);
        this.animations.set(clip.name, action);
        console.log(`Found animation clip: ${clip.name}`);
      });
    } catch (error) {
      console.error('Error loading robot model:', error);
    }
  }

  public onWindowResize(container: HTMLElement): void {
    if (!container) return;
    this.camera.aspect = container.clientWidth / container.clientHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(container.clientWidth, container.clientHeight);
  }

  public playWheelAnimation(wheel: 'L' | 'R' | 'B', direction: 'Forward' | 'Backward') {
      const animName = `Wheel_${wheel}_${direction}`;
      const action = this.animations.get(animName);
      if (action) {
          action.reset().play();
      } else {
          console.warn(`Animation not found: ${animName}`);
      }
  }
  
  public stopWheelAnimation(wheel: 'L' | 'R' | 'B') {
      const forwardAction = this.animations.get(`Wheel_${wheel}_Forward`);
      const backwardAction = this.animations.get(`Wheel_${wheel}_Backward`);
      forwardAction?.stop();
      backwardAction?.stop();
  }

  private animate = (): void => {
    requestAnimationFrame(this.animate);

    const deltaTime = this.clock.getDelta();
    if (this.mixer) {
      this.mixer.update(deltaTime);
    }

    if (this.robotModel) {
      const targetPosition = new THREE.Vector3();
      this.robotModel.getWorldPosition(targetPosition);
      targetPosition.y += 0.4;

      this.controls.target.lerp(targetPosition, 0.1);
    }

    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }
}