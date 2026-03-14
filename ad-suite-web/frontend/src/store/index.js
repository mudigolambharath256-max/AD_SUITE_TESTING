import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { get as idbGet, set as idbSet, del as idbDel } from 'idb-keyval';

// ─── IDB storage adapter for large data (findings) ───────────────────────────
const idbStorage = {
    getItem: async (name) => {
        const val = await idbGet(name);
        return val ?? null;
    },
    setItem: async (name, value) => {
        await idbSet(name, value);
    },
    removeItem: async (name) => {
        await idbDel(name);
    },
};

// ─── CONFIG SLICE (suite root, domain, IP, engine) ───────────────────────────
// Persisted to localStorage — small, fast, sync
const configSlice = (set) => ({
    suiteRoot: '',
    domain: '',
    serverIp: '',
    engine: 'adsi',
    suiteRootValid: false,
    availableChecks: [],

    setSuiteRoot: (v) => set({ suiteRoot: v }),
    setDomain: (v) => set({ domain: v }),
    setServerIp: (v) => set({ serverIp: v }),
    setEngine: (v) => set({ engine: v }),
    setSuiteRootValid: (v) => set({ suiteRootValid: v }),
    setAvailableChecks: (checks) => set({ availableChecks: checks }),
});

// ─── CHECK SELECTION SLICE ────────────────────────────────────────────────
// Persisted to localStorage
const selectionSlice = (set, get) => ({
    selectedCheckIds: [],           // array of check ID strings
    expandedCategories: {},         // { categoryId: bool }

    setSelectedCheckIds: (ids) => set({ selectedCheckIds: Array.isArray(ids) ? ids : [] }),
    toggleCheck: (id) => {
        const current = get().selectedCheckIds;
        const next = current.includes(id)
            ? current.filter(x => x !== id)
            : [...current, id];
        set({ selectedCheckIds: next });
    },
    toggleCategory: (categoryId, checkIds) => {
        const current = get().selectedCheckIds;
        const allSelected = checkIds.every(id => current.includes(id));
        const next = allSelected
            ? current.filter(id => !checkIds.includes(id))
            : [...new Set([...current, ...checkIds])];
        set({ selectedCheckIds: next });
    },
    selectAll: (allCheckIds) => set({ selectedCheckIds: allCheckIds }),
    clearAll: () => set({ selectedCheckIds: [] }),
    toggleCategoryExpand: (id) => set(state => ({
        expandedCategories: {
            ...state.expandedCategories,
            [id]: !state.expandedCategories[id]
        }
    })),
});

// ─── ACTIVE SCAN SLICE ────────────────────────────────────────────────
// activeScanId, status, progress → persist to localStorage
// findings → persist to IndexedDB (large)
// logLines → DO NOT persist (ephemeral, can be very large)
const scanSlice = (set, get) => ({
    activeScanId: null,
    scanStatus: 'idle',             // idle | running | complete | error | aborted
    progress: { current: 0, total: 0, currentCheckId: '', currentCheckName: '' },
    scanSummary: null,              // { duration, total, bySeverity } — localStorage persisted
    scanError: null,

    setActiveScan: (scanId) => set({
        activeScanId: scanId,
        scanStatus: 'running',
        progress: { current: 0, total: 0, currentCheckId: '', currentCheckName: '' },
        scanSummary: null,
        scanError: null
    }),

    setScanStatus: (status) => set({ scanStatus: status }),

    updateProgress: (progress) => set({ progress }),

    setScanSummary: (summary) => set({ scanSummary: summary }),
    setScanError: (err) => set({ scanStatus: 'error', scanError: err }),

    resetScan: () => set({
        activeScanId: null,
        scanStatus: 'idle',
        progress: { current: 0, total: 0, currentCheckId: '', currentCheckName: '' },
        scanSummary: null,
        scanError: null
    }),
});

// ─── HISTORY SLICE ────────────────────────────────────────────────────
// NOT persisted — always fetched fresh from DB
const historySlice = (set) => ({
    recentScans: [],
    historyLoading: false,
    setRecentScans: (scans) => set({ recentScans: scans }),
    setHistoryLoading: (v) => set({ historyLoading: v }),
});

// ─── REPORTS SLICE ────────────────────────────────────────────────────
// Persisted to localStorage
const reportsSlice = (set) => ({
    reportFilters: {
        dateFrom: null, dateTo: null,
        severities: [], categories: [], engines: [],
        search: '',
    },
    selectedScanIds: [],

    setReportFilters: (filters) => set({ reportFilters: filters }),
    updateReportFilter: (key, value) => set(state => ({
        reportFilters: { ...state.reportFilters, [key]: value }
    })),
    setSelectedScanIds: (ids) => set({ selectedScanIds: ids }),
    clearReportFilters: () => set({
        reportFilters: { dateFrom: null, dateTo: null, severities: [], categories: [], engines: [], search: '' }
    }),
});

// ─── STORE ASSEMBLY ──────────────────────────────────────────────────

// Slice 1: Config + Selection + Scan Summary + Reports (localStorage)
export const useAppStore = create(
    persist(
        (set, get) => ({
            ...configSlice(set, get),
            ...selectionSlice(set, get),
            ...scanSlice(set, get),
            ...reportsSlice(set),
        }),
        {
            name: 'ad-suite-app',
            storage: createJSONStorage(() => localStorage),
            // Explicitly list what to persist:
            partialize: (state) => ({
                suiteRoot: state.suiteRoot,
                domain: state.domain,
                serverIp: state.serverIp,
                engine: state.engine,
                suiteRootValid: state.suiteRootValid,
                availableChecks: state.availableChecks,
                selectedCheckIds: state.selectedCheckIds,
                expandedCategories: state.expandedCategories,
                activeScanId: state.activeScanId,
                scanStatus: state.scanStatus === 'running' ? 'running' : state.scanStatus,
                progress: state.progress,
                scanSummary: state.scanSummary,
                reportFilters: state.reportFilters,
                selectedScanIds: state.selectedScanIds,
            }),
        }
    )
);

// Slice 2: Large findings array (IndexedDB)
export const useFindingsStore = create(
    persist(
        (set, get) => ({
            findings: [],
            logLines: [],

            setFindings: (findings) => set({ findings }),
            addFinding: (finding) => set(state => ({ findings: [...state.findings, finding] })),
            appendLog: (line) => set(state => {
                const next = [...state.logLines, { ts: Date.now(), line }];
                return { logLines: next.length > 1000 ? next.slice(-1000) : next };
            }),
            clearFindings: () => set({ findings: [], logLines: [] }),
        }),
        {
            name: 'ad-suite-findings',
            storage: createJSONStorage(() => idbStorage),
            partialize: (state) => ({ findings: state.findings }),
            // logLines intentionally NOT persisted
        }
    )
);

// Slice 3: History (no persistence — always fresh from DB)
export const useHistoryStore = create((set) => ({
    recentScans: [],
    historyLoading: false,
    setRecentScans: (scans) => set({ recentScans: scans }),
    setHistoryLoading: (v) => set({ historyLoading: v }),
}));
