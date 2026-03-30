import { StateCreator } from 'zustand';

export interface SelectionState {
    selectedChecks: Set<string>;
    expandedCategories: Set<string>;
    activeScanId: string | null;
    
    toggleCheckSelection: (checkId: string) => void;
    clearSelections: () => void;
    toggleCategoryExpansion: (category: string) => void;
    setActiveScanId: (id: string | null) => void;
}

export const createSelectionSlice: StateCreator<SelectionState> = (set) => ({
    selectedChecks: new Set(),
    expandedCategories: new Set(),
    activeScanId: null,
    
    toggleCheckSelection: (checkId) => set((state) => {
        const next = new Set(state.selectedChecks);
        if (next.has(checkId)) next.delete(checkId);
        else next.add(checkId);
        return { selectedChecks: next };
    }),
    
    clearSelections: () => set({ selectedChecks: new Set() }),
    
    toggleCategoryExpansion: (category) => set((state) => {
        const next = new Set(state.expandedCategories);
        if (next.has(category)) next.delete(category);
        else next.add(category);
        return { expandedCategories: next };
    }),
    
    setActiveScanId: (id) => set({ activeScanId: id })
});
