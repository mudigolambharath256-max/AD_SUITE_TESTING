import api from './api';

export function downloadBlob(blob: Blob, filename: string): void {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
}

/** Download a file using the authenticated axios client (Bearer token). */
export async function downloadAuthenticated(apiPath: string, filename: string): Promise<void> {
    const res = await api.get(apiPath, { responseType: 'blob' });
    downloadBlob(res.data as Blob, filename);
}

export function getBackendOrigin(): string {
    const explicit = import.meta.env.VITE_BACKEND_ORIGIN as string | undefined;
    if (explicit) {
        return explicit.replace(/\/$/, '');
    }
    const api = import.meta.env.VITE_API_URL || 'http://localhost:3000/api';
    return api.replace(/\/api\/?$/, '') || 'http://localhost:3000';
}
