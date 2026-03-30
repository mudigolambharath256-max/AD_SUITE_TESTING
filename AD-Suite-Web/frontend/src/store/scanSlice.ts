import { StateCreator } from 'zustand';

export interface ScanState {
    scanStatus: 'idle' | 'running' | 'completed' | 'failed';
    scanProgress: number;
    scanMessage: string;
    scanResults: any | null;
    
    setScanStatus: (status: 'idle' | 'running' | 'completed' | 'failed') => void;
    setScanProgress: (progress: number) => void;
    setScanMessage: (message: string) => void;
    setScanResults: (results: any) => void;
    resetScan: () => void;
}

export const createScanSlice: StateCreator<ScanState> = (set) => ({
    scanStatus: 'idle',
    scanProgress: 0,
    scanMessage: '',
    scanResults: null,
    
    setScanStatus: (status) => set({ scanStatus: status }),
    setScanProgress: (progress) => set({ scanProgress: progress }),
    setScanMessage: (message) => set({ scanMessage: message }),
    setScanResults: (results) => set({ scanResults: results }),
    resetScan: () => set({ scanStatus: 'idle', scanProgress: 0, scanMessage: '', scanResults: null })
});
