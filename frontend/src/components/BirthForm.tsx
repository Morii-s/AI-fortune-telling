import { useState } from 'react';
import { Calendar, Clock, MapPin, User, Sparkles } from 'lucide-react';
import type { BirthForm as BFT } from '../api/client';

const HOURS: [string, number][] = [
  ['00:00 子时',0],['01:00 丑时',1],['02:00 丑时',2],['03:00 寅时',3],['04:00 寅时',4],
  ['05:00 卯时',5],['06:00 卯时',6],['07:00 辰时',7],['08:00 辰时',8],['09:00 巳时',9],
  ['10:00 巳时',10],['11:00 午时',11],['12:00 午时',12],['13:00 未时',13],['14:00 未时',14],
  ['15:00 申时',15],['16:00 申时',16],['17:00 酉时',17],['18:00 酉时',18],['19:00 戌时',19],
  ['20:00 戌时',20],['21:00 亥时',21],['22:00 亥时',22],['23:00 子时',23],
];

interface Props { onSubmit: (d: BFT) => void; loading: boolean; }

export default function BirthForm({ onSubmit, loading }: Props) {
  const [y, sY] = useState('1990');
  const [m, sM] = useState('6');
  const [d, sD] = useState('15');
  const [h, sH] = useState(12);
  const [g, sG] = useState<'male'|'female'>('male');
  const [p, sP] = useState('北京');

  const go = (e: React.FormEvent) => { e.preventDefault();
    onSubmit({ birth_year:parseInt(y)||1990, birth_month:parseInt(m)||6, birth_day:parseInt(d)||15, birth_hour:h, gender:g, birth_place:p });
  };

  return (
    <form onSubmit={go} className="space-y-7">
      <div className="space-y-2">
        <label className="flex items-center gap-1.5 text-[13px] text-soft/70 tracking-wider">
          <Calendar className="w-3.5 h-3.5" /> 出生日期
        </label>
        <div className="grid grid-cols-3 gap-3">
          {[{l:'年',v:y,s:sY,p:'1990'},{l:'月',v:m,s:sM,p:'06'},{l:'日',v:d,s:sD,p:'15'}].map(f=>(
            <div key={f.l} className="relative">
              <input type="text" inputMode="numeric" value={f.v}
                onChange={e=>f.s(e.target.value.replace(/\D/g,''))}
                className="ux-input text-center" placeholder={f.p} />
              <span className="absolute right-1 top-1/2 -translate-y-1/2 text-[10px] text-faint">{f.l}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <label className="flex items-center gap-1.5 text-[13px] text-soft/70 tracking-wider">
          <Clock className="w-3.5 h-3.5" /> 出生时辰
        </label>
        <select value={h} onChange={e=>sH(Number(e.target.value))} className="ux-select">
          {HOURS.map(([l,v])=><option key={v} value={v}>{l}</option>)}
        </select>
      </div>

      <div className="space-y-2">
        <label className="flex items-center gap-1.5 text-[13px] text-soft/70 tracking-wider">
          <User className="w-3.5 h-3.5" /> 性别
        </label>
        <div className="flex gap-1 p-1 rounded-lg bg-line/40">
          {(['male','female'] as const).map(v=>(
            <button key={v} type="button" onClick={()=>sG(v)}
              className={`flex-1 py-2.5 text-sm rounded-md transition-all duration-200 ${
                g===v ? 'bg-panel text-ink shadow-sm' : 'text-faint hover:text-soft'
              }`}>{v==='male'?'男':'女'}</button>
          ))}
        </div>
      </div>

      <div className="space-y-2">
        <label className="flex items-center gap-1.5 text-[13px] text-soft/70 tracking-wider">
          <MapPin className="w-3.5 h-3.5" /> 出生地
        </label>
        <input type="text" value={p} onChange={e=>sP(e.target.value)}
          className="ux-input" placeholder="北京" />
      </div>

      <button type="submit" disabled={loading}
        className="w-full py-4 text-sm tracking-[0.15em] rounded-lg font-medium
                   border border-gold/50 bg-gold/[0.06] text-gold
                   hover:bg-gold/[0.12] hover:border-gold hover:shadow-[0_4px_20px_rgba(184,149,62,0.15)]
                   active:scale-[0.98]
                   disabled:opacity-30 disabled:cursor-not-allowed
                   transition-all duration-300 mt-3
                   flex items-center justify-center gap-2">
        <Sparkles className="w-4 h-4" />
        {loading ? '排算中…' : '查看今日运势'}
      </button>
    </form>
  );
}
