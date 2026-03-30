import { get, set, del } from 'idb-keyval';
import { StateStorage } from 'zustand/middleware';

// Custom Zustand persist adapter for IndexedDB
// Required for storing large scan arrays since localStorage is synchronously constrained to 5MB
export const idbStorage: StateStorage = {
    getItem: async (name: string): Promise<string | null> => {
        try {
            const value = await get(name);
            return value || null;
        } catch (err) {
            console.error('[IDB Storage] Get Item Error:', err);
            return null;
        }
    },
    setItem: async (name: string, value: string): Promise<void> => {
        try {
            await set(name, value);
        } catch (err) {
            console.error('[IDB Storage] Set Item Error:', err);
        }
    },
    removeItem: async (name: string): Promise<void> => {
        try {
            await del(name);
        } catch (err) {
            console.error('[IDB Storage] Remove Item Error:', err);
        }
    },
};
