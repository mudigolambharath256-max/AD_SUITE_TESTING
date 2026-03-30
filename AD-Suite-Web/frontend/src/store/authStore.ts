import { create } from 'zustand';

interface User {
    id: number;
    email: string;
    name: string;
    role: string;
}

interface AuthState {
    user: User | null;
    token: string | null;
    isAuthenticated: boolean;
    login: (user: User, token: string) => void;
    logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
    user: null,
    token: null,
    isAuthenticated: false,
    login: (user, token) => {
        localStorage.setItem('auth-storage', JSON.stringify({ user, token }));
        set({ user, token, isAuthenticated: true });
    },
    logout: () => {
        localStorage.removeItem('auth-storage');
        set({ user: null, token: null, isAuthenticated: false });
    }
}));

const stored = localStorage.getItem('auth-storage');
if (stored) {
    try {
        const { user, token } = JSON.parse(stored) as { user?: User; token?: string };
        if (user && token) {
            useAuthStore.setState({ user, token, isAuthenticated: true });
        }
    } catch {
        localStorage.removeItem('auth-storage');
    }
}
