import { useState, useCallback, useEffect } from 'react';
import BirthForm from './components/BirthForm';
import FortuneResult from './components/FortuneResult';
import HuangliPanel from './components/HuangliPanel';
import ShengBei from './components/ShengBei';
import { calculateFortune, type BirthForm as BFT } from './api/client';

type Phase = 'idle' | 'loading' | 'result';
const MSGS = ['排算八字中…','推演星盘…','查阅今日黄历…','AI 正在融合解读…','五行生克交叉比对…','即将揭晓…'];

export default function App() {
  const [phase, setPhase] = useState<Phase>('idle');
  const [fortuneData, setFortuneData] = useState<any>(null);
  const [error, setError] = useState('');
  const [msgIdx, setMsgIdx] = useState(0);

  useEffect(() => {
    if (phase !== 'loading') return;
    const t = setInterval(() => setMsgIdx(i => (i + 1) % MSGS.length), 1600);
    return () => clearInterval(t);
  }, [phase]);

  const submit = useCallback(async (d: BFT) => {
    setPhase('loading'); setError(''); setFortuneData(null);
    try {
      const r = await calculateFortune(d);
      if (r.code === 0) { setFortuneData(r.data); setPhase('result'); }
      else { setError(r.message || '分析失败'); setPhase('idle'); }
    } catch { setError('网络错误'); setPhase('idle'); }
  }, []);

  const reset = () => { setPhase('idle'); setFortuneData(null); setError(''); };

  if (phase === 'idle') {
    return (
      <div className="min-h-screen bg-page flex items-center justify-center px-6 py-10">
        <div className="w-full max-w-[720px] animate-scale-in">
          <header className="text-center mb-10">
            <h1 className="text-3xl font-medium text-ink tracking-tight leading-tight">
              中西合璧<span className="text-gold mx-1">·</span>每日运势
            </h1>
            <p className="mt-3 text-sm text-faint tracking-wider">
              八字命理 &times; 星座星盘 &times; 今日黄历
            </p>
          </header>

          {error && (
            <div className="mb-5 text-sm text-accent-cn bg-accent-cn/5 rounded-lg px-4 py-3 border border-accent-cn/15">
              {error}
            </div>
          )}

          <div className="card-mystic px-14 py-12">
            <h2 className="text-lg font-medium text-ink mb-8">请输入您的出生信息</h2>
            <BirthForm onSubmit={submit} loading={false} />
          </div>
        </div>
      </div>
    );
  }

  if (phase === 'loading') {
    return (
      <div className="min-h-screen bg-page flex items-center justify-center">
        <div className="text-center space-y-6 animate-scale-in">
          <div className="w-16 h-16 mx-auto">
            <svg viewBox="0 0 64 64" className="w-full h-full">
              <circle cx="32" cy="32" r="28" fill="none" stroke="var(--color-line)" strokeWidth="1" className="animate-spin-slow" style={{ transformOrigin: '32px 32px' }} />
              <circle cx="32" cy="32" r="24" fill="none" stroke="var(--color-gold)" strokeWidth="0.5" className="animate-spin-slow" style={{ transformOrigin: '32px 32px', animationDirection: 'reverse', animationDuration: '16s' }} />
            </svg>
          </div>
          <p className="text-sm text-soft tracking-wider">{MSGS[msgIdx]}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-page">
      <div className="max-w-[1280px] mx-auto px-10 py-14 animate-fade-in">
        <div className="grid grid-cols-[1fr_310px] gap-8">
          <div className="min-w-0">
            <FortuneResult data={fortuneData} />
          </div>
          <div className="space-y-5 animate-fade-in-d1">
            <div className="card-mystic p-6">
              <HuangliPanel />
            </div>
            <div className="card-mystic p-6 flex items-center justify-center">
              <ShengBei />
            </div>
          </div>
        </div>

        <div className="mt-12 text-center animate-fade-in-d2">
          <button onClick={reset} className="text-sm text-faint hover:text-soft transition-colors tracking-wider">
            重新排算
          </button>
          <p className="mt-6 text-[11px] text-faint/50 tracking-wider">
            八字 lunar-python · 星盘 天文算法 · AI DeepSeek
          </p>
        </div>
      </div>
    </div>
  );
}
