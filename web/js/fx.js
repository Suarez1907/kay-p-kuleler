// cannon-es ile süs amaçlı rijit-cisim fiziği: çöken taş parçaları, düşen kutular ve zafer konfetisi.
// (Bulmaca mantığı deterministik ızgara motorunda çalışır; bu katman yalnızca görseldir.)
import * as CANNON from '../vendor/cannon-es.js';
import * as THREE from 'three';

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.world = new CANNON.World({ gravity: new CANNON.Vec3(0, -14, 0) });
    this.world.defaultContactMaterial.restitution = 0.35;
    this.world.defaultContactMaterial.friction = 0.3;
    this.items = []; this.statics = [];
    this.geo = new THREE.BoxGeometry(1, 1, 1);
  }
  setStatics(cells) {
    for (const b of this.statics) this.world.removeBody(b);
    this.statics = [];
    for (const c of cells) {
      const b = new CANNON.Body({ mass: 0, shape: new CANNON.Box(new CANNON.Vec3(0.5, 0.5, 0.5)) });
      b.position.set(c[0], c[1], c[2]); this.world.addBody(b); this.statics.push(b);
    }
  }
  clear() { for (const it of this.items) { this.scene.remove(it.mesh); this.world.removeBody(it.body); } this.items = []; }
  spawn(pos, size, color, vel, life = 3) {
    const mesh = new THREE.Mesh(this.geo, new THREE.MeshStandardMaterial({ color, roughness: 0.8, transparent: true }));
    mesh.scale.setScalar(size); mesh.castShadow = true;
    this.scene.add(mesh);
    const body = new CANNON.Body({ mass: 1, shape: new CANNON.Box(new CANNON.Vec3(size / 2, size / 2, size / 2)) });
    body.position.set(pos.x, pos.y, pos.z); body.velocity.set(vel.x, vel.y, vel.z);
    body.angularVelocity.set(Math.random() * 6 - 3, Math.random() * 6 - 3, Math.random() * 6 - 3);
    this.world.addBody(body);
    this.items.push({ mesh, body, life, max: life });
  }
  shatter(cell, color) {
    for (let i = 0; i < 8; i++) {
      const p = new THREE.Vector3(cell[0] + (i & 1 ? .25 : -.25), cell[1] + (i & 2 ? .25 : -.25), cell[2] + (i & 4 ? .25 : -.25));
      this.spawn(p, 0.42, color, { x: (Math.random() - .5) * 2, y: Math.random() * 2, z: (Math.random() - .5) * 2 }, 2.5);
    }
  }
  confetti(at, colors) {
    for (let i = 0; i < 40; i++) {
      const a = Math.random() * Math.PI * 2, s = 2 + Math.random() * 3;
      this.spawn(new THREE.Vector3(at[0], at[1] + 0.5, at[2]), 0.12 + Math.random() * 0.1, colors[i % colors.length],
        { x: Math.cos(a) * s, y: 6 + Math.random() * 5, z: Math.sin(a) * s }, 3.5);
    }
  }
  update(dt) {
    if (!this.items.length) return;
    this.world.step(1 / 60, dt, 3);
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.life -= dt;
      it.mesh.position.copy(it.body.position); it.mesh.quaternion.copy(it.body.quaternion);
      it.mesh.material.opacity = Math.min(1, it.life / 0.6);
      if (it.life <= 0) { this.scene.remove(it.mesh); it.mesh.material.dispose(); this.world.removeBody(it.body); this.items.splice(i, 1); }
    }
  }
}
