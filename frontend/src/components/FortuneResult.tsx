import { useState, useEffect, useRef } from 'react';
import { Heart, Briefcase, Coins, Activity, Stars, ArrowLeft } from 'lucide-react';
import BaZiChart from './BaZiChart';
import StarChart from './StarChart';

interface Props { data: any; }

const CATS = [
  { key:'love', label:'爱情运势', icon: Heart, color:'#C4463A' },
  { key:'career', label:'事业运势', icon: Briefcase, color:'#2B3A67' },
  { key:'wealth', label:'财运运势', icon: Coins, color:'#B8953E' },
  { key:'health', label:'健康运势', icon: Activity, color:'#059669' },
];

export default function FortuneResult({ data }: Props) {
  const [detail, setDetail] = useState<'bazi'|'star'|null>(null);
  const [displayScore, setDisplayScore] = useState(0);
  const [progressDone, setProgressDone] = useState(false);
  const animRef = useRef<number>(0);
  const f = data.fortune;
  const overallScore = f?.overall_score ?? 0;

  // Score counter animation (interaction-design: Feedback within 100ms-1s)
  useEffect(() => {
    if (!f) return;

    const target = overallScore;
    const duration = 800;
    const start = Date.now();
    setProgressDone(false);
    const animate = () => {
      const elapsed = Date.now() - start;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setDisplayScore(Math.round(target * eased));
      if (progress < 1) animRef.current = requestAnimationFrame(animate);
      else { setDisplayScore(target); setTimeout(() => setProgressDone(true), 100); }
    };
    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [f, overallScore]);

  if (detail === 'bazi') return (
    <div className="animate-fade-in space-y-6">
      <button onClick={()=>setDetail(null)} className="inline-flex items-center gap-1.5 text-sm text-soft hover:text-gold transition-colors">
        <ArrowLeft className="w-4 h-4" /> 返回运势
      </button>
      <div className="card-mystic">
        <h3 className="text-lg font-medium text-ink mb-6">八字排盘</h3>
        <BaZiChart bazi={data.bazi} />
      </div>
    </div>
  );

  if (detail === 'star') return (
    <div className="animate-fade-in space-y-6">
      <button onClick={()=>setDetail(null)} className="inline-flex items-center gap-1.5 text-sm text-soft hover:text-gold transition-colors">
        <ArrowLeft className="w-4 h-4" /> 返回运势
      </button>
      <div className="card-mystic">
        <h3 className="text-lg font-medium text-ink mb-6">星座星盘</h3>
        <StarChart astrology={data.astrology || data.astro} />
      </div>
    </div>
  );

  if (!f) return null;
  const { overall_text, lucky, advice } = f;
  return (
    <div>
      <div className="text-center pb-10">
        <p className="number-display animate-counter">{displayScore}</p>
        <p className="mt-3 text-[12px] text-faint tracking-[0.25em]">综合运势</p>
        <p className="mt-4 text-base text-soft/80 leading-relaxed">{overall_text}</p>
      </div>

      <hr className="gold-rule" />

      <div className="py-10 grid grid-cols-2 gap-5">
        {CATS.map(c => {
          const it = f[c.key];
          if (!it) return null;
          const Icon = c.icon;
          return (
            <div key={c.key} className="card-accent card-mystic card-mystic--hover p-5">
              <div style={{ position:'absolute', left:0, top:12, bottom:12, width:3, borderRadius:'0 3px 3px 0', backgroundColor:c.color }} />
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Icon className="w-4 h-4" style={{ color: c.color }} />
                  <span className="text-sm font-medium text-ink/80">{c.label}</span>
                </div>
                <span className="text-2xl font-medium" style={{ color: c.color }}>{it.score}</span>
              </div>
              <div className="h-1 rounded-full bg-line overflow-hidden mb-3">
                <div className={`h-full rounded-full ${progressDone ? 'progress-fill--done' : 'progress-fill'}`} style={{ width: progressDone ? `${it.score * 10}%` : '0%', backgroundColor: c.color, transitionDelay: `${0.2}s` }} />
              </div>
              <p className="text-sm text-soft/70 leading-relaxed">{it.text}</p>
            </div>
          );
        })}
      </div>

      <hr className="gold-rule" />

      {lucky && (
        <div className="py-8 flex justify-center gap-16 text-center">
          {[{ l:'幸运色', v:lucky.color },{ l:'幸运数', v:lucky.number },{ l:'幸运方位', v:lucky.direction }].map(it=>(
            <div key={it.l}>
              <p className="text-[11px] text-faint tracking-widest mb-2 uppercase">{it.l}</p>
              <p className="text-lg text-ink/80 font-medium">{it.v}</p>
            </div>
          ))}
        </div>
      )}

      {advice && (
        <div className="py-6">
          <div className="card-mystic p-6 bg-gold/[0.03]">
            <p className="text-sm text-soft/80 leading-relaxed italic text-center">{advice}</p>
          </div>
        </div>
      )}

      <hr className="gold-rule" />

      <div className="pt-8 flex justify-center gap-10">
        <button onClick={()=>setDetail('bazi')} className="inline-flex items-center gap-1.5 text-sm text-faint hover:text-accent-cosmic transition-colors tracking-wider">
          <Stars className="w-3.5 h-3.5" /> 八字排盘
        </button>
        <button onClick={()=>setDetail('star')} className="inline-flex items-center gap-1.5 text-sm text-faint hover:text-accent-cosmic transition-colors tracking-wider">
          <Stars className="w-3.5 h-3.5" /> 星座星盘
        </button>
      </div>
    </div>
  );
}
