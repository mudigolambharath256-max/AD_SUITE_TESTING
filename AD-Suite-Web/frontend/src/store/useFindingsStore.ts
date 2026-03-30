import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { idbStorage } from './idbStorage';

interface Finding {
    CheckId: string;
    CheckName: string;
    Severity: string;
    Category: string;
    [key: string]: any;
}

export interface FindingsState {
    findings: Record<string, Finding[]>; // Maps scanId -> array of findings
    
    setFindings: (scanId: string, payload: Finding[]) => void;
    clearFindings: (scanId?: string) => void;
}

// useFindingsStore operates entirely asynchronously on IndexedDB to avoid breaking the 5MB localStorage caps
// and blocking the React render cycle during serialization of huge arrays.
export const useFindingsStore = create<FindingsState>()(
    persist(
        (set) => ({
            findings: {},
            
            setFindings: (scanId, payload) => set((state) => ({
                findings: { ...state.findings, [scanId]: payload }
            })),
            
            clearFindings: (scanId) => set((state) => {
                if (scanId) {
                    const next = { ...state.findings };
                    delete next[scanId];
                    return { findings: next };
                }
                return { findings: {} };
            })
        }),
        {
            name: 'ad-suite-findings-storage',
            storage: createJSONStorage(() => idbStorage)
        }
    )
);
