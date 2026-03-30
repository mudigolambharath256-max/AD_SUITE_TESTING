import { StateCreator } from 'zustand';

export interface ScanMetadata {
    id: string;
    timestamp: number;
    totalFindings: number;
    durationMs: number;
    status: 'success' | 'failed' | 'partial';
}

export interface HistoryState {
    recentScans: ScanMetadata[];
    
    addScanHistory: (scan: ScanMetadata) => void;
    clearHistory: () => void;
    removeScanHistory: (id: string) => void;
}

export const createHistorySlice: StateCreator<HistoryState> = (set) => ({
    recentScans: [],
    
    addScanHistory: (scan) => set((state) => ({
        // Keep the latest 50 scans to avoid blowing up localStorage
        recentScans: [scan, ...state.recentScans].slice(0, 50)
    })),
    
    clearHistory: () => set({ recentScans: [] }),
    
    removeScanHistory: (id) => set((state) => ({
        recentScans: state.recentScans.filter(s => s.id !== id)
    }))
});
