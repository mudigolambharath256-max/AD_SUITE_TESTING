import { StateCreator } from 'zustand';

export interface ConfigState {
    suiteRoot: string;
    domain: string;
    serverIp: string;
    targetIps: string[];
    enginePreference: 'powershell' | 'csharp' | 'both';
    
    setConfig: (config: Partial<Omit<ConfigState, 'setConfig'>>) => void;
    addTargetIp: (ip: string) => void;
    removeTargetIp: (ip: string) => void;
}

export const createConfigSlice: StateCreator<ConfigState> = (set) => ({
    suiteRoot: 'C:\\AD_SUITE',
    domain: '',
    serverIp: '',
    targetIps: [],
    enginePreference: 'both',
    
    setConfig: (config) => set((state) => ({ ...state, ...config })),
    
    addTargetIp: (ip) => set((state) => {
        if (state.targetIps.includes(ip)) return state;
        return { targetIps: [...state.targetIps, ip] };
    }),
    
    removeTargetIp: (ip) => set((state) => ({
        targetIps: state.targetIps.filter(i => i !== ip)
    }))
});
