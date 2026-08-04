import { create } from 'zustand';

interface FortuneState {
  fortuneData: any | null;
  loading: boolean;
  error: string | null;
  setFortune: (data: any) => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  reset: () => void;
}

export const useFortuneStore = create<FortuneState>((set) => ({
  fortuneData: null,
  loading: false,
  error: null,
  setFortune: (data) => set({ fortuneData: data, error: null, loading: false }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error, loading: false }),
  reset: () => set({ fortuneData: null, loading: false, error: null }),
}));
