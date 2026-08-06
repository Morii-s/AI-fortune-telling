import { useState } from 'react';
import { Calendar, Clock3, MapPin, UserRound, ArrowUpRight } from 'lucide-react';
import type { BirthForm as BFT } from '../api/client';

const HOURS: [string, number][] = [['00:00 子时', 0], ['01:00 丑时', 1], ['02:00 丑时', 2], ['03:00 寅时', 3], ['04:00 寅时', 4], ['05:00 卯时', 5], ['06:00 卯时', 6], ['07:00 辰时', 7], ['08:00 辰时', 8], ['09:00 巳时', 9], ['10:00 巳时', 10], ['11:00 午时', 11], ['12:00 午时', 12], ['13:00 未时', 13], ['14:00 未时', 14], ['15:00 申时', 15], ['16:00 申时', 16], ['17:00 酉时', 17], ['18:00 酉时', 18], ['19:00 戌时', 19], ['20:00 戌时', 20], ['21:00 亥时', 21], ['22:00 亥时', 22], ['23:00 子时', 23]];

interface Props { onSubmit: (data: BFT) => void; loading: boolean; }

export default function BirthForm({ onSubmit, loading }: Props) {
  const [year, setYear] = useState('1990'); const [month, setMonth] = useState('6'); const [day, setDay] = useState('15');
  const [hour, setHour] = useState(12); const [gender, setGender] = useState<'male' | 'female'>('male'); const [place, setPlace] = useState('北京');
  const go = (event: React.FormEvent) => { event.preventDefault(); onSubmit({ birth_year: Number(year) || 1990, birth_month: Number(month) || 6, birth_day: Number(day) || 15, birth_hour: hour, gender, birth_place: place }); };
  return <form onSubmit={go} className="birth-form">
    <div className="field-group"><label><Calendar size={15} /> 出生日期</label><div className="date-fields"><label className="date-field"><input required inputMode="numeric" value={year} onChange={(e) => setYear(e.target.value.replace(/\D/g, '').slice(0, 4))} /><span>年</span></label><label className="date-field"><input required inputMode="numeric" value={month} onChange={(e) => setMonth(e.target.value.replace(/\D/g, '').slice(0, 2))} /><span>月</span></label><label className="date-field"><input required inputMode="numeric" value={day} onChange={(e) => setDay(e.target.value.replace(/\D/g, '').slice(0, 2))} /><span>日</span></label></div></div>
    <div className="field-group"><label htmlFor="birth-hour"><Clock3 size={15} /> 出生时刻</label><select id="birth-hour" value={hour} onChange={(e) => setHour(Number(e.target.value))}>{HOURS.map(([name, value]) => <option key={value} value={value}>{name}</option>)}</select></div>
    <div className="field-group"><label><UserRound size={15} /> 性别</label><div className="segmented">{(['male', 'female'] as const).map((value) => <button key={value} type="button" className={gender === value ? 'selected' : ''} onClick={() => setGender(value)}>{value === 'male' ? '男' : '女'}</button>)}</div></div>
    <div className="field-group"><label htmlFor="birth-place"><MapPin size={15} /> 出生地</label><input id="birth-place" required value={place} onChange={(e) => setPlace(e.target.value)} placeholder="城市" /></div>
    <button className="primary-button" type="submit" disabled={loading}>{loading ? '排演中' : '开始今日排演'} <ArrowUpRight size={16} /></button>
  </form>;
}
