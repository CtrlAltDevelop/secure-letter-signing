import * as THREE from './vendor/three.module.min.js';

const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Scroll reveal
const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { threshold: 0.12 });
document.querySelectorAll('.rev').forEach(el => io.observe(el));

// Pointer tilt on screenshots
if (!reduce) {
  document.querySelectorAll('.tilt').forEach(el => {
    el.addEventListener('pointermove', e => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform = `rotateY(${x * 10}deg) rotateX(${-y * 8}deg) translateZ(8px)`;
    });
    el.addEventListener('pointerleave', () => { el.style.transform = ''; });
  });
}

// Hero scene: letter sheet, gold seal, wireframe shell, particles
const canvas = document.getElementById('gl');
let renderer;
try { renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true }); } catch { renderer = null; }
if (renderer) {
  const GOLD = 0xFBD57F, BLUE = 0x165EF6, LIGHT = 0xA4B9E4;
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100);
  camera.position.set(0, 0, 9);

  scene.add(new THREE.AmbientLight(0xffffff, 0.8));
  const key = new THREE.DirectionalLight(0xffffff, 2.2); key.position.set(3, 4, 6); scene.add(key);
  const rim = new THREE.PointLight(BLUE, 60, 20); rim.position.set(-4, -2, 3); scene.add(rim);

  const hero = new THREE.Group(); scene.add(hero);

  // sheet texture: bars that look like text, drawn on canvas
  const c = document.createElement('canvas'); c.width = 512; c.height = 704;
  const g = c.getContext('2d');
  g.fillStyle = '#fff'; g.fillRect(0, 0, 512, 704);
  g.fillStyle = '#165EF6'; g.fillRect(300, 48, 164, 16);
  g.fillStyle = '#A4B9E4'; g.fillRect(360, 74, 104, 8);
  g.fillStyle = '#BFA46F'; g.fillRect(48, 104, 416, 3);
  g.fillStyle = '#081528'; g.fillRect(250, 140, 214, 12);
  [0, 1, 2, 3, 4, 5, 6, 7, 8].forEach(i => {
    g.fillStyle = '#32568A55';
    const w = i % 4 === 3 ? 150 : 416; g.fillRect(464 - w, 190 + i * 30, w, 8);
  });
  g.fillStyle = '#BFA46F'; g.fillRect(48, 650, 416, 2);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  const sheet = new THREE.Mesh(new THREE.BoxGeometry(2.6, 3.6, 0.06), [
    new THREE.MeshStandardMaterial({ color: 0xdfe6f5 }), new THREE.MeshStandardMaterial({ color: 0xdfe6f5 }),
    new THREE.MeshStandardMaterial({ color: 0xdfe6f5 }), new THREE.MeshStandardMaterial({ color: 0xdfe6f5 }),
    new THREE.MeshStandardMaterial({ map: tex, roughness: 0.6 }), new THREE.MeshStandardMaterial({ color: 0xdfe6f5 })]);
  hero.add(sheet);

  // seal: gold torus + check stroke
  const seal = new THREE.Group(); seal.position.set(-0.6, -1.1, 0.25); hero.add(seal);
  const goldMat = new THREE.MeshStandardMaterial({ color: GOLD, metalness: 0.9, roughness: 0.25, emissive: 0x6b4a00, emissiveIntensity: 0.35 });
  seal.add(new THREE.Mesh(new THREE.TorusGeometry(0.55, 0.07, 24, 64), goldMat));
  const disc = new THREE.Mesh(new THREE.CircleGeometry(0.5, 48), new THREE.MeshStandardMaterial({ color: 0x0F203A, metalness: 0.3, roughness: 0.5 }));
  disc.position.z = 0.01; seal.add(disc);
  const check = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3([
    new THREE.Vector3(-0.22, -0.02, 0.05), new THREE.Vector3(-0.07, -0.18, 0.05), new THREE.Vector3(0.24, 0.17, 0.05)]), 16, 0.045, 12), goldMat);
  seal.add(check);

  // wireframe shell
  const shell = new THREE.Mesh(new THREE.IcosahedronGeometry(3.3, 1), new THREE.MeshBasicMaterial({ color: LIGHT, wireframe: true, transparent: true, opacity: 0.16 }));
  hero.add(shell);

  // particles
  const N = 700, pos = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    const r = 4 + Math.random() * 7, a = Math.random() * 6.283, z = (Math.random() - 0.5) * 10;
    pos[i * 3] = Math.cos(a) * r; pos[i * 3 + 1] = (Math.random() - 0.5) * 9; pos[i * 3 + 2] = z;
  }
  const pg = new THREE.BufferGeometry(); pg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(pg, new THREE.PointsMaterial({ color: GOLD, size: 0.035, transparent: true, opacity: 0.7, depthWrite: false }));
  scene.add(pts);

  const mouse = { x: 0, y: 0 };
  addEventListener('pointermove', e => { mouse.x = e.clientX / innerWidth - 0.5; mouse.y = e.clientY / innerHeight - 0.5; });

  function layout() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
    const narrow = w < 720, rtl = document.documentElement.dir === 'rtl';
    hero.position.set(narrow ? 0 : (rtl ? -3 : 3), narrow ? -2.6 : 0, 0);
    hero.scale.setScalar(narrow ? 0.5 : 1);
  }
  addEventListener('resize', layout);
  new MutationObserver(layout).observe(document.documentElement, { attributes: true, attributeFilter: ['dir'] });
  layout();

  let visible = true;
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }, { threshold: 0 }).observe(canvas);
  const clock = new THREE.Clock();
  function frame() {
    requestAnimationFrame(frame);
    if (!visible) return;
    const t = reduce ? 0 : clock.getElapsedTime(), sy = Math.min(scrollY / innerHeight, 1);
    hero.rotation.y = Math.sin(t * 0.5) * 0.35 + mouse.x * 0.6 + sy * 1.2;
    hero.rotation.x = -mouse.y * 0.4 + sy * 0.3;
    sheet.position.y = Math.sin(t * 0.9) * 0.12;
    seal.position.y = -1.1 + Math.sin(t * 0.9 + 1) * 0.16; seal.rotation.y = Math.sin(t * 0.7) * 0.5;
    shell.rotation.set(t * 0.08, t * 0.12, 0);
    pts.rotation.y = t * 0.03 + sy * 0.5;
    renderer.render(scene, camera);
  }
  frame();
}
