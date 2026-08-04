import { useState, useEffect } from 'react';
import { CalendarDays, CheckCircle, XCircle, Star } from 'lucide-react';
import { getTodayHuangli } from '../api/client';

interface HL {
  lunar_date?: string; day_ganzhi?: string; day_wuxing?: string;
  yi?: string[]; ji?: string[]; chong_sha?: string; chong_desc?: string;
  xi_shen?: string; fu_shen?: string; cai_shen?: string; pengzu?: string; jianchu?: string;
}

export default function HuangliPanel() {
  const [data, setData] = useState<HL | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    getTodayHuangli().then(r=>{if(r.code===0&&r.data)setData(r.data)}).catch(()=>{}).finally(()=>setLoading(false));
  }, []);
  if (loading) return <div className="space-y-2 animate-pulse"><div className="h-3 w-16 bg-line rounded"/><div className="h-3 w-28 bg-line rounded"/></div>;
  if (!data) return null;

  return (
    <div>
      <div className="flex items-center gap-2 mb-3">
        <CalendarDays className="w-3.5 h-3.5 text-accent-cn" />
        <h3 className="text-xs font-medium text-ink tracking-wider">今日黄历</h3>
      </div>
      <div className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5 mb-3">
        <span className="text-base font-medium text-ink">{data.lunar_date}</span>
        <span className="text-[12px] text-soft">{data.day_ganzhi}·五行属{data.day_wuxing}</span>
        {data.jianchu && <span className="text-[12px] text-accent-cn font-medium">·{data.jianchu}</span>}
      </div>
      <div className="space-y-2">
        <div className="flex items-start gap-1.5">
          <CheckCircle className="w-3 h-3 text-wx-wood mt-0.5 shrink-0" />
          <div className="flex flex-wrap gap-1">
            {data.yi && data.yi.length>0 ? data.yi.map((item,i)=>(
              <span key={i} className="text-[11px] px-1.5 py-0.5 rounded-full bg-wx-wood/8 text-wx-wood">{item}</span>
            )):<span className="text-[11px] text-faint">—</span>}
          </div>
        </div>
        <div className="flex items-start gap-1.5">
          <XCircle className="w-3 h-3 text-accent-cn mt-0.5 shrink-0" />
          <div className="flex flex-wrap gap-1">
            {data.ji && data.ji.length>0 ? data.ji.map((item,i)=>(
              <span key={i} className="text-[11px] px-1.5 py-0.5 rounded-full bg-accent-cn/8 text-accent-cn">{item}</span>
            )):<span className="text-[11px] text-faint">—</span>}
          </div>
        </div>
      </div>
      <div className="mt-3 flex flex-wrap gap-x-3 gap-y-0.5 text-[11px] text-soft/70">
        {data.chong_sha && <span>冲煞 {data.chong_sha}{data.chong_desc&&<span>（冲{data.chong_desc}）</span>}</span>}
        {data.xi_shen && <span className="flex items-center gap-1"><Star className="w-2.5 h-2.5"/>喜神{data.xi_shen}</span>}
        {data.fu_shen && <span>福神{data.fu_shen}</span>}
        {data.cai_shen && <span className="text-gold">财神{data.cai_shen}</span>}
      </div>
      {data.pengzu && <p className="mt-3 pt-3 border-t border-line text-[10px] text-faint/70 italic">{data.pengzu}</p>}
    </div>
  );
}
