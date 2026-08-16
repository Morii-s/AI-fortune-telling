import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowUpRight, Compass, Disc3, Menu, RotateCcw, Sparkles, Stars, X } from 'lucide-react';
import BirthForm from './components/BirthForm';
import FortuneResult from './components/FortuneResult';
import HuangliPanel from './components/HuangliPanel';
import ShengBei from './components/ShengBei';
import StarChart from './components/StarChart';
import { calculateFortune, type BirthForm as BFT } from './api/client';

type Phase = 'idle' | 'loading' | 'result';
const MSGS = ['校准出生时间', '读取星体位置', '展开五行关系', '融合今日黄历', '整理你的解读'];
const PROFILE_KEY = 'orbit.birth-profile';
const DAILY_REPORT_KEY = 'orbit.daily-report';

interface CachedReport { profile: BFT; date: string; data: any; }

function getShanghaiDate() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const value = (type: string) => parts.find((part) => part.type === type)?.value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}

function readStoredValue<T>(key: string): T | null {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? JSON.parse(raw) as T : null;
  } catch {
    return null;
  }
}

function storeValue(key: string, value: unknown) {
  try { window.localStorage.setItem(key, JSON.stringify(value)); } catch { /* Storage may be unavailable in private browsing. */ }
}

export default function App() {
  const [phase, setPhase] = useState<Phase>('idle');
  const [fortuneData, setFortuneData] = useState<any>(null);
  const [error, setError] = useState('');
  const [msgIdx, setMsgIdx] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);
  const [savedProfile, setSavedProfile] = useState<BFT | null>(() => readStoredValue<BFT>(PROFILE_KEY));
  const didRestoreSession = useRef(false);

  useEffect(() => {
    if (phase !== 'loading') return;
    const timer = window.setInterval(() => setMsgIdx((index) => (index + 1) % MSGS.length), 1250);
    return () => window.clearInterval(timer);
  }, [phase]);

  const submit = useCallback(async (data: BFT) => {
    setPhase('loading');
    setError('');
    setSavedProfile(data);
    storeValue(PROFILE_KEY, data);
    try {
      const response = await calculateFortune(data);
      if (response.code === 0) {
        setFortuneData(response.data);
        storeValue(DAILY_REPORT_KEY, { profile: data, date: getShanghaiDate(), data: response.data } satisfies CachedReport);
        setPhase('result');
      } else {
        setError(response.message || '分析暂时无法完成');
        setPhase('idle');
      }
    } catch {
      setError('未连接到命理服务，请确认后端已启动');
      setPhase('idle');
    }
  }, []);

  useEffect(() => {
    if (didRestoreSession.current) return;
    didRestoreSession.current = true;
    if (!savedProfile) return;
    const cached = readStoredValue<CachedReport>(DAILY_REPORT_KEY);
    const isCurrent = cached?.date === getShanghaiDate()
      && JSON.stringify(cached.profile) === JSON.stringify(savedProfile);
    if (isCurrent && cached) {
      setFortuneData(cached.data);
      setPhase('result');
      return;
    }
    void submit(savedProfile);
  }, [savedProfile, submit]);

  const reset = () => { setPhase('idle'); setFortuneData(null); setError(''); };

  if (phase === 'loading') return (
    <main className="loading-screen">
      <div className="loading-orbit" aria-hidden="true"><span /><span /><span /></div>
      <p className="eyebrow">PERSONAL CELESTIAL REPORT</p>
      <h1>正在为你排演</h1>
      <p className="loading-copy">{MSGS[msgIdx]}<span className="loading-dots">···</span></p>
      <div className="loading-track"><span style={{ width: `${((msgIdx + 1) / MSGS.length) * 100}%` }} /></div>
    </main>
  );

  return (
    <div className={`app-shell ${phase === 'result' ? 'is-result' : ''}`}>
      <header className="topbar">
        <a className="brand" href="#top" aria-label="回到首页"><span className="brand-mark"><Disc3 size={18} /></span><span>ORBIT / 命轨</span></a>
        <nav className={`topnav ${menuOpen ? 'open' : ''}`}>
          <a className="active" href="#top">今日排演</a>
          <a href="#ritual">仪式工具</a>
          <a href="#about">关于命轨</a>
        </nav>
        <button className="icon-button mobile-menu" onClick={() => setMenuOpen((open) => !open)} aria-label={menuOpen ? '关闭菜单' : '打开菜单'}>{menuOpen ? <X size={18} /> : <Menu size={18} />}</button>
        <span className="topbar-status"><i /> SYSTEM ONLINE</span>
      </header>

      <main id="top" className="main-frame">
        {phase === 'idle' ? (
          <section className="intro-layout page-enter">
            <div className="intro-copy">
              <p className="eyebrow">ASTROLOGY × BAZI × ALMANAC <span>01 / 03</span></p>
              <h1>把今天的<br /><em>星光</em>译成行动。</h1>
              <p className="intro-lede">一次输入，交叉读取东方命理与西方星盘。<br />让复杂的天象，落成一份清晰的今日指引。</p>
              <div className="intro-notes"><span><Compass size={15} /> 北京时间 · GMT+8</span><span><Sparkles size={15} /> AI 辅助解读</span></div>
            </div>
            <div className="form-panel">
              <div className="panel-heading"><span className="section-number">01</span><div><p className="eyebrow">YOUR ORIGIN</p><h2>从出生时刻开始</h2></div></div>
              {error && <div className="error-banner" role="alert">{error}</div>}
              <BirthForm onSubmit={submit} loading={false} initialData={savedProfile} />
              <p className="form-footnote">出生资料仅保存在当前设备，每日首次打开将自动更新今日建议。</p>
            </div>
          </section>
        ) : (
          <section className="result-layout page-enter">
            <div className="result-main"><div className="result-kicker"><span className="eyebrow">PERSONAL REPORT / {fortuneData?.date || getShanghaiDate()}</span><div className="result-actions"><span className="saved-status">资料已保存</span><button className="text-button" onClick={reset}><RotateCcw size={14} /> 修改资料</button></div></div><FortuneResult data={fortuneData} /></div>
            <aside className="ritual-rail" id="ritual"><div className="rail-label">DAILY RITUALS</div><div className="rail-panel"><HuangliPanel /></div><div className="rail-panel astrology-panel"><div className="rail-panel-head compact"><span className="eyebrow">STAR MAP / 今日星盘</span><Stars size={15} /></div><StarChart astrology={fortuneData?.astrology} /></div><div className="rail-panel cup-panel"><div className="rail-panel-head"><span className="eyebrow">DIVINATION TOOL</span><ArrowUpRight size={15} /></div><ShengBei /></div></aside>
          </section>
        )}
      </main>
      <footer id="about" className="footer"><span>ORBIT / 命轨</span><span>东方算法与西方星象的当代表达</span><span>v1.0 · PRIVATE SESSION</span></footer>
    </div>
  );
}
