import { Component, type ReactNode } from 'react';

interface Props { children: ReactNode; }
interface State { hasError: boolean; error: string | null; }

export default class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error: error.message };
  }

  componentDidCatch(error: Error) {
    console.error('App crashed:', error);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#08080b] flex items-center justify-center">
          <div className="text-center px-6">
            <p className="text-white/30 text-sm mb-4">页面出了点问题</p>
            <button
              onClick={this.handleRetry}
              className="px-6 py-2 text-sm text-white/50 border border-black/[0.12] rounded-lg hover:text-white/80 hover:border-black/[0.18] transition-colors"
            >
              重试
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
