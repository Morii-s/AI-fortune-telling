interface Props { astrology: any; }
const E_COLORS: Record<string, string> = { '火象':'#C4463A','土象':'#B8953E','风象':'#059669','水象':'#2B3A67' };
const GLYPHS: Record<string, string> = { '太阳':'☉','月亮':'☽','水星':'☿','金星':'♀','火星':'♂','木星':'♃','土星':'♄' };

export default function StarChart({ astrology }: Props) {
  if (!astrology) return null;
  const { sun_sign, moon_sign, rising_sign, element, quality, ruling_planet, planet_signs } = astrology;
  const ec = E_COLORS[element] || '#888';

  return (
    <div>
      <div className="grid grid-cols-3 gap-4">
        {[{ l:'太阳星座', v:sun_sign, g:'☉' },{ l:'月亮星座', v:moon_sign||'-', g:'☽' },{ l:'上升星座', v:rising_sign||'-', g:'↑' }].map(item=>(
          <div key={item.l} className="text-center">
            <p className="text-[10px] text-faint tracking-widest mb-2">{item.l}</p>
            <div className="bg-page rounded-md px-3 py-3 border border-line">
              <p className="text-2xl mb-0.5">{item.g}</p>
              <p className="text-sm font-medium text-ink">{item.v}</p>
            </div>
          </div>
        ))}
      </div>
      <div className="flex justify-center gap-2 mt-4">
        {element && <span className="px-2.5 py-1 rounded-full text-[11px] font-medium text-panel" style={{ backgroundColor: ec }}>{element}</span>}
        {quality && <span className="px-2.5 py-1 rounded-full text-[11px] bg-page border border-line text-soft">{quality}星座</span>}
        {ruling_planet && <span className="px-2.5 py-1 rounded-full text-[11px] bg-page border border-line text-soft">守护星{ruling_planet}</span>}
      </div>
      {planet_signs && Object.keys(planet_signs).length>0 && (
        <>
          <div className="my-4 border-t border-dashed border-line" />
          <p className="text-[10px] text-faint tracking-widest text-center mb-3">行星落座</p>
          <div className="grid grid-cols-4 gap-2">
            {Object.entries(planet_signs).map(([name, info]: [string, any])=>(
              <div key={name} className="text-center bg-page rounded-md px-2 py-2.5 border border-line">
                <p className="text-lg mb-0.5">{GLYPHS[name] || '🪐'}</p>
                <p className="text-[10px] text-faint">{name}</p>
                <p className="text-[11px] text-soft mt-0.5">{info.sign}</p>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
