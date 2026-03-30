import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
import api from '../lib/api';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();
    const login = useAuthStore((state) => state.login);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const response = await api.post('/auth/login', { email, password });
            login(response.data.user, response.data.token);
            navigate('/');
        } catch (err: any) {
            setError(err.response?.data?.message || 'Login failed');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-bg-primary flex items-center justify-center p-4">
            <div className="w-full max-w-md">
                <div className="bg-surface-elevated border border-border-light rounded-2xl p-8 shadow-lg">
                    {/* Logo */}
                    <div className="text-center mb-8">
                        <div className="flex justify-center mb-4">
                            <img
                                src="/technieum-logo.png"
                                alt="Technieum"
                                className="h-14 w-auto max-w-[220px] object-contain mx-auto"
                            />
                        </div>
                        <h1 className="text-2xl font-semibold text-text-primary mb-2">Technieum AD suite</h1>
                        <p className="text-sm text-text-secondary">Security Assessment Platform</p>
                    </div>

                    <form onSubmit={handleSubmit} className="space-y-5">
                        {error && (
                            <div className="bg-critical/10 border border-critical/30 text-critical px-4 py-3 rounded-lg text-sm">
                                {error}
                            </div>
                        )}

                        <div>
                            <label className="block text-sm font-medium text-text-primary mb-2">
                                Email
                            </label>
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="w-full px-4 py-2.5 bg-bg-tertiary border border-border-medium rounded-lg text-text-primary text-sm focus:outline-none focus:border-accent-orange focus:ring-2 focus:ring-accent-orange/20 transition-all"
                                placeholder="you@example.com"
                                required
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-text-primary mb-2">
                                Password
                            </label>
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                className="w-full px-4 py-2.5 bg-bg-tertiary border border-border-medium rounded-lg text-text-primary text-sm focus:outline-none focus:border-accent-orange focus:ring-2 focus:ring-accent-orange/20 transition-all"
                                placeholder="••••••••"
                                required
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-accent-orange hover:bg-accent-orange-hover text-white font-medium py-3 rounded-lg transition-all duration-150 active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
                        >
                            {loading ? 'Signing in...' : 'Sign In'}
                        </button>
                    </form>

                    <div className="mt-6 pt-6 border-t border-border-light text-center">
                        <p className="text-xs text-text-tertiary mb-2">Demo credentials:</p>
                        <div className="inline-flex flex-col gap-1 text-xs text-text-secondary bg-bg-tertiary px-4 py-2 rounded-lg">
                            <span className="font-medium">admin@example.com</span>
                            <span className="font-medium">password123</span>
                        </div>
                    </div>
                </div>

                <p className="text-center text-xs text-text-tertiary mt-6">
                    Secure Active Directory security assessment and monitoring
                </p>
            </div>
        </div>
    );
}
