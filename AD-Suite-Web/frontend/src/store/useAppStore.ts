import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createConfigSlice, ConfigState } from './configSlice';
import { createSelectionSlice, SelectionState } from './selectionSlice';
import { createHistorySlice, HistoryState } from './historySlice';
import { createScanSlice, ScanState } from './scanSlice';

export type AppState = ConfigState & SelectionState & HistoryState & ScanState;

export const useAppStore = create<AppState>()(
    persist(
        (set, get, api) => ({
            ...createConfigSlice(set, get, api),
            ...createSelectionSlice(set, get, api),
            ...createHistorySlice(set, get, api),
            ...createScanSlice(set, get, api),
        }),
        {
            name: 'ad-suite-app-storage',
            storage: createJSONStorage(() => localStorage),
            partialize: (state) => ({
                suiteRoot: state.suiteRoot,
                domain: state.domain,
                serverIp: state.serverIp,
                targetIps: state.targetIps,
                enginePreference: state.enginePreference,
                recentScans: state.recentScans
            })
        }
    )
);
