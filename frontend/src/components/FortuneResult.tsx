import { useEffect, useRef, useState } from 'react';
import { Activity, ArrowLeft, BriefcaseBusiness, Coins, Heart, Sparkles, Stars } from 'lucide-react';
import BaZiChart from './BaZiChart';
import StarChart from './StarChart';

interface Props { data: any; }
const CATS = [
  { key: 'love', label: '关系', icon: Heart }, { key: 'career', label: '事业', icon: BriefcaseBusiness },
  { key: 'wealth', label: '财富', icon: Coins }, { key: 'health', label: '身心', icon: Activity },
];

export default function FortuneResult({ data }: Props) {
  const [detail, setDetail] = useState<'bazi' | 'star' | null>(null); const [score, setScore] = useState(0); const [done, setDone] = useState(false); const raf = useRef(0);
  const fortune = data?.fortune; const target = (fortune?.overall_score ?? 0) * 10;
  const guidance = fortune?.guidance ?? [fortune?.advice, '留出二十分钟不被打扰的时间，让身体和注意力重新归位。'].filter(Boolean);
  useEffect(() => { if (!fortune) return; const start = performance.now(); setDone(false); const tick = (now: number) => { const p = Math.min((now - start) / 900, 1); setScore(Math.round(target * (1 - Math.pow(1 - p, 3)))); if (p < 1) raf.current = requestAnimationFrame(tick); else { setScore(target); window.setTimeout(() => setDone(true), 120); } }; raf.current = requestAnimationFrame(tick); return () => cancelAnimationFrame(raf.current); }, [fortune, target]);
  if (detail === 'bazi') return <div className="detail-view page-enter"><button className="text-button" onClick={() => setDetail(null)}><ArrowLeft size={14} /> 返回总览</button><div className="data-panel"><div className="panel-heading"><span className="section-number">02</span><div><p className="eyebrow">EASTERN CALCULATION</p><h2>八字排盘</h2></div></div><BaZiChart bazi={data.bazi} /></div></div>;
  if (detail === 'star') return <div className="detail-view page-enter"><button className="text-button" onClick={() => setDetail(null)}><ArrowLeft size={14} /> 返回总览</button><div className="data-panel"><div className="panel-heading"><span className="section-number">03</span><div><p className="eyebrow">WESTERN CALCULATION</p><h2>星座星盘</h2></div></div><StarChart astrology={data.astrology || data.astro} /></div></div>;
  if (!fortune) return null;
  return <div className="fortune-report">
    <div className="score-hero"><div><p className="eyebrow">TODAY'S RESONANCE</p><h1><span>{score}</span><small>/ 100</small></h1><p className="score-caption">综合运势</p></div><div className="score-orbit" aria-hidden="true"><span /><span /><span /></div></div>
    <div className="report-intro"><span className="report-line" /> <p>{fortune.overall_text}</p></div>
    <div className="fortune-grid">{CATS.map(({ key, label, icon: Icon }) => { const item = fortune[key]; if (!item) return null; return <article className="fortune-item" key={key}><div className="fortune-item-top"><span><Icon size={16} /> {label}</span><strong>{item.score * 10}</strong></div><div className="meter"><span className={done ? 'filled' : ''} style={{ '--meter': `${item.score * 10}%` } as React.CSSProperties} /></div><p>{item.text}</p></article>; })}</div>
    {fortune.lucky && <div className="lucky-row">{[['幸运色', fortune.lucky.color], ['幸运数', fortune.lucky.number], ['幸运方位', fortune.lucky.direction]].map(([label, value]) => <div key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>}
    {guidance.length > 0 && <section className="guidance-section"><div className="guidance-heading"><span className="eyebrow">PRACTICAL GUIDANCE</span><strong>今日行动建议</strong></div><div className="guidance-list">{guidance.map((item: string, index: number) => <div className="guidance-item" key={`${item}-${index}`}><span>0{index + 1}</span><p>{item}</p></div>)}</div></section>}
    {fortune.advice && <div className="advice-note"><Sparkles size={15} /><p>{fortune.advice}</p></div>}
    <div className="report-actions"><button onClick={() => setDetail('bazi')}><Stars size={15} /> 八字排盘</button><button onClick={() => setDetail('star')}><Stars size={15} /> 星盘详情</button></div>
  </div>;
}
