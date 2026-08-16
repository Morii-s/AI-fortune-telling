import { useEffect, useRef, useState } from 'react';
import { ArrowUp, Dices } from 'lucide-react';
import * as THREE from 'three';
import * as CANNON from 'cannon-es';

type Result = 'sheng' | 'yin' | 'xiao' | null;
const RESULT_LABELS: Record<Exclude<Result, null>, { title: string; desc: string }> = {
  sheng: { title: '圣杯', desc: '一平一凸 · 神明应允' }, yin: { title: '阴杯', desc: '两面皆凸 · 神明不允' }, xiao: { title: '笑杯', desc: '两面皆平 · 笑而不答' },
};

function makeCupGeometry() {
  const shape = new THREE.Shape();
  // A traditional jiaobei silhouette: two sharp tips, a convex outer back,
  // and a concave inner face where the paired cups meet.
  shape.moveTo(0, -0.86);
  shape.quadraticCurveTo(0.92, -0.68, 0.98, 0);
  shape.quadraticCurveTo(0.92, 0.68, 0, 0.86);
  shape.quadraticCurveTo(0.38, 0.45, 0.42, 0);
  shape.quadraticCurveTo(0.38, -0.45, 0, -0.86);
  return new THREE.ExtrudeGeometry(shape, { depth: 0.24, bevelEnabled: true, bevelSegments: 4, bevelSize: 0.045, bevelThickness: 0.055, curveSegments: 24 });
}

export default function ShengBei() {
  const mountRef = useRef<HTMLDivElement>(null); const activeRef = useRef(false); const bodiesRef = useRef<CANNON.Body[]>([]); const frameRef = useRef(0); const resultRef = useRef<Result>(null); const facesRef = useRef<[boolean, boolean]>([false, false]); const settledAtRef = useRef(0);
  const [result, setResult] = useState<Result>(null); const [rolling, setRolling] = useState(false);

  useEffect(() => {
    const mount = mountRef.current; if (!mount) return;
    const scene = new THREE.Scene(); scene.background = new THREE.Color(0x181a18);
    const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100); camera.position.set(0, 4.4, 7.8); camera.lookAt(0, 0, 0);
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true }); renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap; mount.appendChild(renderer.domElement);
    const ambient = new THREE.HemisphereLight(0xe7dfca, 0x151714, 2.1); scene.add(ambient);
    const key = new THREE.DirectionalLight(0xf3d29a, 3.2); key.position.set(-3, 7, 4); key.castShadow = true; scene.add(key);
    const rim = new THREE.PointLight(0x7d9a80, 2.2, 10); rim.position.set(3, 2, -2); scene.add(rim);
    const floor = new THREE.Mesh(new THREE.CylinderGeometry(3.15, 3.15, 0.12, 64), new THREE.MeshStandardMaterial({ color: 0x242721, roughness: .82, metalness: .08 })); floor.position.y = -1.13; floor.receiveShadow = true; scene.add(floor);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(2.62, .012, 8, 96), new THREE.MeshBasicMaterial({ color: 0xb18d51, transparent: true, opacity: .55 })); ring.rotation.x = Math.PI / 2; ring.position.y = -1.05; scene.add(ring);
    const geometry = makeCupGeometry(); geometry.center();
    const cupMaterial = new THREE.MeshStandardMaterial({ color: 0x7b3024, roughness: .34, metalness: .12, emissive: 0x180604, emissiveIntensity: .28 });
    const edgeMaterial = new THREE.MeshStandardMaterial({ color: 0xb76443, roughness: .28, metalness: .24, emissive: 0x250b06, emissiveIntensity: .2 });
    const meshes = [0, 1].map((index) => { const mesh = new THREE.Mesh(geometry, [cupMaterial, edgeMaterial]); mesh.castShadow = true; mesh.receiveShadow = true; mesh.scale.set(index ? 1.0 : -1.0, 1.0, 1.0); mesh.position.set(index ? .92 : -.92, -.5, index ? -.06 : .08); mesh.rotation.set(index ? .18 : -.12, index ? -.2 : .14, index ? .2 : -.12); scene.add(mesh); return mesh; });
    const world = new CANNON.World({ gravity: new CANNON.Vec3(0, -9.82, 0) }); world.broadphase = new CANNON.SAPBroadphase(world); world.allowSleep = true; world.defaultContactMaterial.friction = .58; world.defaultContactMaterial.restitution = .45;
    const groundBody = new CANNON.Body({ mass: 0, shape: new CANNON.Plane() }); groundBody.quaternion.setFromEuler(-Math.PI / 2, 0, 0); groundBody.position.y = -1.08; world.addBody(groundBody);
    const bodies = meshes.map((_, index) => { const body = new CANNON.Body({ mass: 1, shape: new CANNON.Box(new CANNON.Vec3(.34, .78, .14)), position: new CANNON.Vec3(index ? .92 : -.92, -.55, index ? -.06 : .08) }); body.linearDamping = .18; body.angularDamping = .15; body.allowSleep = true; world.addBody(body); return body; }); bodiesRef.current = bodies;
    const resize = () => { const width = mount.clientWidth || 320; const height = mount.clientHeight || 300; camera.aspect = width / height; camera.updateProjectionMatrix(); renderer.setSize(width, height, false); }; resize(); const observer = new ResizeObserver(resize); observer.observe(mount);
    let previous = performance.now();
    const animate = (now: number) => { frameRef.current = requestAnimationFrame(animate); const dt = Math.min((now - previous) / 1000, .033); previous = now; if (activeRef.current) { world.step(1 / 60, dt, 3); bodies.forEach((body, index) => { meshes[index].position.copy(body.position as unknown as THREE.Vector3); meshes[index].quaternion.copy(body.quaternion as unknown as THREE.Quaternion); }); const sleeping = bodies.every((body) => body.sleepState === CANNON.Body.SLEEPING); if (sleeping && !settledAtRef.current) settledAtRef.current = now; if (settledAtRef.current && now - settledAtRef.current > 320) { activeRef.current = false; setRolling(false); const [first, second] = facesRef.current; const next: Result = first === second ? (first ? 'xiao' : 'yin') : 'sheng'; resultRef.current = next; setResult(next); } } renderer.render(scene, camera); }; frameRef.current = requestAnimationFrame(animate);
    return () => { cancelAnimationFrame(frameRef.current); observer.disconnect(); geometry.dispose(); cupMaterial.dispose(); edgeMaterial.dispose(); renderer.dispose(); renderer.domElement.remove(); };
  }, []);

  const throwBei = () => { if (activeRef.current) return; const bodies = bodiesRef.current; if (!bodies.length) return; const [first, second] = bodies; settledAtRef.current = 0; facesRef.current = [Math.random() > .5, Math.random() > .5]; const resetBody = (body: CANNON.Body, x: number, z: number) => { body.wakeUp(); body.position.set(x, .15, z); body.velocity.set((Math.random() - .5) * 2.4, 4.3 + Math.random() * 1.8, (Math.random() - .5) * 1.8); body.angularVelocity.set((Math.random() - .5) * 7, (Math.random() - .5) * 7, (Math.random() - .5) * 7); body.quaternion.setFromEuler(0, 0, 0); }; resetBody(first, -.92, .08); resetBody(second, .92, -.06); setResult(null); resultRef.current = null; activeRef.current = true; setRolling(true); };

  return <div className="shengbei-3d"><div className="three-stage" ref={mountRef} aria-label="3D 圣杯物理投掷场景" /><div className="shengbei-meta"><span className="eyebrow">CANNON / RITUAL 01</span><span className="physics-state"><i className={rolling ? 'live' : ''} /> {rolling ? 'PHYSICS ACTIVE' : 'READY TO THROW'}</span></div>{result && <div className="shengbei-result page-enter"><strong>{RESULT_LABELS[result].title}</strong><span>{RESULT_LABELS[result].desc}</span></div>}<button className="throw-button" onClick={throwBei} disabled={rolling}><Dices size={15} /> {rolling ? '正在落定' : result ? '再次投掷' : '投掷圣杯'} <ArrowUp size={14} /></button></div>;
}
