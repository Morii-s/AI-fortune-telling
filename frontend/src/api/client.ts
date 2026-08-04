const API_BASE = 'http://localhost:8000/api/v1';

export interface BirthForm {
  birth_year: number;
  birth_month: number;
  birth_day: number;
  birth_hour: number;
  birth_minute?: number;
  gender: string;
  birth_place?: string;
  birth_lat?: number;
}

export async function calculateFortune(data: BirthForm) {
  const url = `${API_BASE}/fortune/daily`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(errText || 'API error');
  }
  return res.json();
}

export async function getTodayHuangli() {
  const res = await fetch(`${API_BASE}/huangli/today`);
  if (!res.ok) throw new Error('API error');
  return res.json();
}

export async function healthCheck() {
  const url = import.meta.env.DEV ? 'http://localhost:8000/api/health' : '/api/health';
  return fetch(url).then(r => r.json());
}
