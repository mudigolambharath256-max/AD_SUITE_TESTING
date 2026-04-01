import axios from 'axios';
import { useAuthStore } from '../store/authStore';

/** Dev: `/api` via Vite proxy (works when clients use http://<server-ip>:5173). Prod: same origin unless `VITE_API_URL` is set. */
function getDefaultApiBase(): string {
    const explicit = import.meta.env.VITE_API_URL;
    if (explicit) return explicit;
    if (import.meta.env.DEV) return '/api';
    if (typeof window !== 'undefined' && window.location?.origin) {
        return `${window.location.origin}/api`;
    }
    return 'http://localhost:3000/api';
}

const api = axios.create({
    baseURL: getDefaultApiBase(),
    headers: {
        'Content-Type': 'application/json'
    }
});

// Request interceptor to add auth token
api.interceptors.request.use((config) => {
    const token = useAuthStore.getState().token;
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// Response interceptor for error handling
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            useAuthStore.getState().logout();
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

export default api;
