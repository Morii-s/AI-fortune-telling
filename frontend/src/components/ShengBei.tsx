import { useRef, useEffect, useCallback, useState } from 'react';

/* ═══════════════════════════════════════════════
   圣杯 Canvas — 3D 月牙形渲染 + 物理引擎
   模拟两块筊杯的木制抛掷
   ═══════════════════════════════════════════════ */

const W = 340, H = 300;
const GROUND = H - 50;
const BLOCK_W = 44, BLOCK_H = 76;

type Block = {
  x: number; y: number;
  vx: number; vy: number;
  rot: number; av: number;
  settled: boolean;
};

type Result = 'sheng' | 'yin' | 'xiao' | null;

const RESULT_LABELS: Record<string, { title: string; desc: string; color: string }> = {
  sheng: { title: '圣杯', desc: '一平一凸 · 神明应允', color: '#059669' },
  yin:   { title: '阴杯', desc: '两面皆凸 · 神明不允', color: '#C4463A' },
  xiao:  { title: '笑杯', desc: '两面皆平 · 笑而不答', color: '#C9A050' },
};

/* ── 绘制月牙形筊杯 (crescent moon block) ── */
function drawCrescentBlock(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number, rot: number,
  flatUp: boolean // true = flat face visible, false = convex face visible
) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);

  const hw = w / 2, hh = h / 2;

  // ── Crescent shape: flat on one side, curved on the other ──
  ctx.beginPath();
  if (flatUp) {
    // Flat side facing up — we see the flat face
    ctx.moveTo(-hw, -hh * 0.1);
    ctx.lineTo(hw, -hh * 0.1);
    // Curved bottom (convex back)
    ctx.quadraticCurveTo(hw + 6, 0, hw, hh * 0.9);
    ctx.quadraticCurveTo(0, hh + 2, -hw, hh * 0.9);
    ctx.quadraticCurveTo(-hw - 6, 0, -hw, -hh * 0.1);
  } else {
    // Convex side facing up — rounded top, flat bottom
    ctx.moveTo(-hw, hh * 0.1);
    ctx.quadraticCurveTo(-hw - 6, 0, -hw, -hh * 0.9);
    ctx.quadraticCurveTo(0, -hh - 3, hw, -hh * 0.9);
    ctx.quadraticCurveTo(hw + 6, 0, hw, hh * 0.1);
    ctx.lineTo(-hw, hh * 0.1);
  }
  ctx.closePath();

  // ── 3D wood gradient ──
  const grad = ctx.createLinearGradient(0, -hh, 0, hh);
  if (flatUp) {
    // Flat face: lighter matte wood with subtle grain
    grad.addColorStop(0, '#f2dfb0');
    grad.addColorStop(0.2, '#e8cc8a');
    grad.addColorStop(0.5, '#d4a84c');
    grad.addColorStop(0.8, '#b8862c');
    grad.addColorStop(1, '#8b5e14');
  } else {
    // Convex face: curved highlight, darker sides for 3D depth
    grad.addColorStop(0, '#ecd48a');
    grad.addColorStop(0.15, '#d4a840');
    grad.addColorStop(0.35, '#c09030');
    grad.addColorStop(0.55, '#d4a840');
    grad.addColorStop(0.75, '#a06818');
    grad.addColorStop(1, '#603810');
  }
  ctx.fillStyle = grad;
  ctx.fill();

  // ── Wood grain lines ──
  ctx.save();
  ctx.clip();
  ctx.strokeStyle = 'rgba(0,0,0,0.06)';
  ctx.lineWidth = 0.7;
  for (let i = -hh; i < hh; i += 6) {
    const cy = i + Math.sin(i * 0.4) * 2;
    ctx.beginPath();
    ctx.moveTo(-hw - 2, cy);
    ctx.quadraticCurveTo(0, cy + Math.sin(i * 0.5) * 1.5, hw + 2, cy);
    ctx.stroke();
  }

  // ── Edge highlight (top ridge) ──
  if (!flatUp) {
    ctx.beginPath();
    ctx.moveTo(-hw * 0.6, -hh + 8);
    ctx.quadraticCurveTo(0, -hh + 2, hw * 0.6, -hh + 8);
    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  ctx.restore();

  // ── Dark edge outline ──
  ctx.strokeStyle = 'rgba(0,0,0,0.22)';
  ctx.lineWidth = 0.9;
  ctx.stroke();

  // ── Rim highlight (flat face edge) ──
  if (flatUp) {
    ctx.beginPath();
    ctx.moveTo(-hw, -hh * 0.1);
    ctx.lineTo(hw, -hh * 0.1);
    ctx.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx.lineWidth = 1.2;
    ctx.stroke();
  }

  ctx.restore();
}

export default function ShengBei() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const blocksRef = useRef<[Block, Block]>([
    { x: W * 0.35, y: GROUND, vx: 0, vy: 0, rot: 0, av: 0, settled: true },
    { x: W * 0.65, y: GROUND, vx: 0, vy: 0, rot: 0, av: 0, settled: true },
  ]);
  const animRef = useRef(0);
  const rafRef = useRef(0);
  const [result, setResult] = useState<Result>(null);

  const physicsTick = useCallback(() => {
    const [b1, b2] = blocksRef.current;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let allSettled = true;

    for (const b of [b1, b2]) {
      if (b.settled) continue;
      allSettled = false;

      // Gravity
      b.vy += 0.6;
      // Air friction on rotation
      b.av *= 0.994;
      // Move
      b.y += b.vy;
      b.x += b.vx;
      b.rot += b.av;

      // Wall bounce
      if (b.x < BLOCK_W / 2 + 8) { b.x = BLOCK_W / 2 + 8; b.vx *= -0.35; }
      if (b.x > W - BLOCK_W / 2 - 8) { b.x = W - BLOCK_W / 2 - 8; b.vx *= -0.35; }

      // Ground collision
      if (b.y >= GROUND) {
        b.y = GROUND;
        if (Math.abs(b.vy) < 0.5 && Math.abs(b.av) < 0.012) {
          b.vy = 0; b.vx = 0; b.av = 0; b.settled = true;
          // Snap rotation to nearest facing
          const mod = ((b.rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
          if (mod > Math.PI * 0.3 && mod < Math.PI * 0.7) b.rot = Math.PI * 0.5;
          else if (mod > Math.PI * 1.3 && mod < Math.PI * 1.7) b.rot = Math.PI * 1.5;
          else b.rot = 0;
        } else {
          b.vy *= -0.32;
          b.av *= 0.55;
          b.vx *= 0.65;
          if (Math.abs(b.vy) < 2) b.av *= 0.45;
        }
      }
    }

    if (allSettled && b1.settled && b2.settled) {
      cancelAnimationFrame(rafRef.current);
      const f1 = ((b1.rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
      const f2 = ((b2.rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
      const b1flat = f1 < 0.1 || Math.abs(f1 - Math.PI * 2) < 0.1;
      const b2flat = f2 < 0.1 || Math.abs(f2 - Math.PI * 2) < 0.1;
      if (b1flat && b2flat) setResult('xiao');
      else if (!b1flat && !b2flat) setResult('yin');
      else setResult('sheng');
      animRef.current = 0;
    }

    // ── Render ──
    ctx.clearRect(0, 0, W, H);

    // Ground shadow gradient
    const shadowGrad = ctx.createLinearGradient(0, GROUND, 0, GROUND + 12);
    shadowGrad.addColorStop(0, 'rgba(0,0,0,0.08)');
    shadowGrad.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = shadowGrad;
    ctx.fillRect(16, GROUND, W - 32, 12);

    // Ground line
    ctx.strokeStyle = 'rgba(0,0,0,0.06)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(20, GROUND);
    ctx.lineTo(W - 20, GROUND);
    ctx.stroke();

    const facing1 = ((b1.rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2) < Math.PI;
    const facing2 = ((b2.rot % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2) < Math.PI;

    // Drop shadows (elliptical)
    ctx.fillStyle = 'rgba(0,0,0,0.12)';
    ctx.beginPath();
    ctx.ellipse(b1.x, GROUND + 3, BLOCK_W * 0.55, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(b2.x, GROUND + 3, BLOCK_W * 0.55, 4, 0, 0, Math.PI * 2);
    ctx.fill();

    drawCrescentBlock(ctx, b1.x, b1.y, BLOCK_W, BLOCK_H, b1.rot, facing1);
    drawCrescentBlock(ctx, b2.x, b2.y, BLOCK_W, BLOCK_H, b2.rot, facing2);
  }, []);

  const loop = useCallback(() => {
    physicsTick();
    if (animRef.current === 0) return;
    rafRef.current = requestAnimationFrame(loop);
  }, [physicsTick]);

  useEffect(() => {
    physicsTick();
  }, [physicsTick]);

  const throwBei = useCallback(() => {
    if (animRef.current === 1) return;
    setResult(null);
    blocksRef.current = [
      { x: W * 0.35, y: GROUND, vx: -1.8 + Math.random() * 3.6, vy: -(7 + Math.random() * 6), rot: 0, av: 0.28 + Math.random() * 0.4, settled: false },
      { x: W * 0.65, y: GROUND, vx: -1.8 + Math.random() * 3.6, vy: -(7 + Math.random() * 6), rot: 0, av: 0.28 + Math.random() * 0.4, settled: false },
    ];
    animRef.current = 1;
    rafRef.current = requestAnimationFrame(loop);
  }, [loop]);

  return (
    <div className="flex flex-col items-center gap-4">
      <h3 className="text-xs text-faint tracking-widest">掷 圣 杯</h3>

      <canvas
        ref={canvasRef}
        width={W}
        height={H}
        style={{ width: W, height: H }}
      />

      {result && animRef.current === 0 && (
        <div className="text-center space-y-1">
          <p className="text-lg font-medium" style={{ color: RESULT_LABELS[result].color }}>
            {RESULT_LABELS[result].title}
          </p>
          <p className="text-xs text-faint">{RESULT_LABELS[result].desc}</p>
        </div>
      )}

      <button onClick={throwBei}
        className="px-8 py-2.5 text-sm rounded-lg border border-gold/30 bg-panel text-soft
                   hover:bg-gold/5 hover:border-gold/50 hover:text-gold
                   active:scale-[0.98]
                   transition-all duration-300 tracking-wider">
        {animRef.current === 1 ? '掷杯中…' : result ? '再掷一次' : '掷杯'}
      </button>
    </div>
  );
}
