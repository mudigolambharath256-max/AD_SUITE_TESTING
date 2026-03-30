import React, { createContext, useContext, useState, useEffect } from 'react';

type TableDensity = 'comfortable' | 'compact' | 'spacious';

interface SettingsContextType {
    tableDensity: TableDensity;
    setTableDensity: (density: TableDensity) => void;
    terminalFontSize: number;
    setTerminalFontSize: (size: number) => void;
}

const SettingsContext = createContext<SettingsContextType | undefined>(undefined);

export function SettingsProvider({ children }: { children: React.ReactNode }) {
    // Load from local storage or use defaults
    const [tableDensity, setTableDensity] = useState<TableDensity>(() => {
        const saved = localStorage.getItem('adsuite_table_density');
        return (saved as TableDensity) || 'comfortable';
    });

    const [terminalFontSize, setTerminalFontSize] = useState<number>(() => {
        const saved = localStorage.getItem('adsuite_terminal_font_size');
        return saved ? parseInt(saved, 10) : 13;
    });

    // Save to local storage on change
    useEffect(() => {
        localStorage.setItem('adsuite_table_density', tableDensity);
    }, [tableDensity]);

    useEffect(() => {
        localStorage.setItem('adsuite_terminal_font_size', terminalFontSize.toString());
    }, [terminalFontSize]);

    return (
        <SettingsContext.Provider value={{ tableDensity, setTableDensity, terminalFontSize, setTerminalFontSize }}>
            {children}
        </SettingsContext.Provider>
    );
}

export function useSettings() {
    const context = useContext(SettingsContext);
    if (context === undefined) {
        throw new Error('useSettings must be used within a SettingsProvider');
    }
    return context;
}
