import React from 'react';
import { ENGINES } from '../lib/categories';

const EngineSelector = ({ selectedEngine, onEngineChange, disabled = false }) => {
  return (
    <div className="flex flex-wrap gap-2">
      {ENGINES.map((engine) => (
        <button
          key={engine.id}
          onClick={() => !disabled && onEngineChange(engine.id)}
          disabled={disabled}
          title={engine.desc}
          className={`px-4 py-2 rounded-lg font-medium transition-all duration-200 active-scale ${
            selectedEngine === engine.id
              ? 'bg-accent-primary text-bg-primary shadow-lg'
              : 'bg-bg-tertiary text-text-secondary hover:text-text-primary hover:bg-bg-surface border border-border'
          } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          {engine.label}
        </button>
      ))}
    </div>
  );
};

export default EngineSelector;
