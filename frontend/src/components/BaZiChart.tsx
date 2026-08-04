interface Props { bazi: any; }
const WX_COLORS: Record<string, string> = {
  '木':'var(--color-wx-wood)','火':'var(--color-wx-fire)','土':'var(--color-wx-earth)','金':'var(--color-wx-metal)','水':'var(--color-wx-water)',
};

export default function BaZiChart({ bazi }: Props) {
  if (!bazi) return null;
  const pillars = [
    { l:'年柱', g:bazi.year, w:bazi.wuxing?.year, t:bazi.ten_gods?.year, n:bazi.nayin?.year },
    { l:'月柱', g:bazi.month, w:bazi.wuxing?.month, t:bazi.ten_gods?.month, n:bazi.nayin?.month },
    { l:'日柱', g:bazi.day, w:bazi.wuxing?.day, t:bazi.ten_gods?.day, n:bazi.nayin?.day },
    { l:'时柱', g:bazi.time, w:bazi.wuxing?.time, t:bazi.ten_gods?.time, n:bazi.nayin?.time },
  ];
  return (
    <div>
      <div className="grid grid-cols-4 gap-4">
        {pillars.map(p => {
          const wx = WX_COLORS[p.w?.[0] as string];
          return (
            <div key={p.l} className="text-center">
              <p className="text-[10px] text-faint tracking-widest mb-2">{p.l}</p>
              <div className="bg-page rounded-md px-3 py-3 border border-line">
                <p className="text-xl font-medium text-ink tracking-wide">{p.g}</p>
                {wx && <span className="inline-block w-2 h-2 rounded-full mt-1.5" style={{ backgroundColor: wx }} />}
              </div>
              <p className="text-[10px] text-soft/60 mt-1">{p.t || '-'}</p>
              <p className="text-[10px] text-faint">{p.n || '-'}</p>
            </div>
          );
        })}
      </div>
      <div className="my-5 border-t border-dashed border-line" />
      <div className="flex justify-center gap-4">
        <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-page border border-line text-sm">
          <span className="text-faint">日主</span><span className="text-ink font-medium">{bazi.day_master}</span>
          {bazi.day_master_wuxing && <span className="text-soft/60">（{bazi.day_master_wuxing}）</span>}
        </span>
        <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-page border border-line text-sm">
          <span className="text-faint">生肖</span><span className="text-ink font-medium">{bazi.shengxiao}</span>
        </span>
      </div>
    </div>
  );
}
