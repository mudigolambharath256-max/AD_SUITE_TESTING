import React, { useState } from 'react';
import { ChevronDown, ChevronRight, Search, Check, X } from 'lucide-react';

const CheckSelector = ({ selectedChecks, onSelectionChange, disabled = false, availableChecks = [] }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [expandedCategories, setExpandedCategories] = useState(new Set());

  // Group checks by category
  const checksByCategory = availableChecks.reduce((acc, check) => {
    if (!acc[check.category]) {
      acc[check.category] = {
        id: check.category,
        display: check.categoryDisplay,
        checks: []
      };
    }
    acc[check.category].checks.push(check);
    return acc;
  }, {});

  const categories = Object.values(checksByCategory);

  const filteredCategories = categories.filter(category => {
    if (!searchTerm) return true;

    const categoryMatch = category.display.toLowerCase().includes(searchTerm.toLowerCase());
    const checkMatch = category.checks.some(check =>
      check.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      check.name.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return categoryMatch || checkMatch;
  });

  const toggleCategoryExpansion = (categoryId) => {
    const newExpanded = new Set(expandedCategories);
    if (newExpanded.has(categoryId)) {
      newExpanded.delete(categoryId);
    } else {
      newExpanded.add(categoryId);
    }
    setExpandedCategories(newExpanded);
  };

  const handleCategorySelect = (category, checked) => {
    const newSelection = new Set(selectedChecks);
    const categoryCheckIds = category.checks.map(c => c.id);

    if (checked) {
      categoryCheckIds.forEach(checkId => newSelection.add(checkId));
    } else {
      categoryCheckIds.forEach(checkId => newSelection.delete(checkId));
    }
    onSelectionChange(newSelection);
  };

  const handleCheckSelect = (checkId, checked) => {
    const newSelection = new Set(selectedChecks);
    if (checked) {
      newSelection.add(checkId);
    } else {
      newSelection.delete(checkId);
    }
    onSelectionChange(newSelection);
  };

  const selectAll = () => {
    const allCheckIds = availableChecks.map(check => check.id);
    onSelectionChange(new Set(allCheckIds));
  };

  const clearAll = () => {
    onSelectionChange(new Set());
  };

  const getCategorySelectionState = (category) => {
    const categoryCheckIds = category.checks.map(c => c.id);
    const selectedCount = categoryCheckIds.filter(checkId => selectedChecks.has(checkId)).length;

    if (selectedCount === 0) return 'none';
    if (selectedCount === categoryCheckIds.length) return 'all';
    return 'indeterminate';
  };

  const totalSelected = selectedChecks.size;
  const totalCategories = categories.length;
  const selectedCategories = categories.filter(cat => getCategorySelectionState(cat) !== 'none').length;

  return (
    <div className="space-y-3">
      {/* Search and Actions */}
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search checks..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="input pl-10"
            disabled={disabled}
          />
        </div>
        <button
          onClick={selectAll}
          disabled={disabled}
          className="btn-secondary text-sm whitespace-nowrap"
        >
          Select All
        </button>
        <button
          onClick={clearAll}
          disabled={disabled}
          className="btn-secondary text-sm whitespace-nowrap"
        >
          Clear All
        </button>
      </div>

      {/* Selection Summary */}
      <div className="flex items-center justify-between text-sm text-text-secondary bg-bg-tertiary rounded px-3 py-2">
        <span>
          {totalSelected} checks selected across {selectedCategories}/{totalCategories} categories
        </span>
      </div>

      {/* Categories List */}
      <div className="space-y-2 max-h-96 overflow-y-auto">
        {filteredCategories.length === 0 ? (
          <div className="text-center py-8 text-text-muted">
            No checks found matching "{searchTerm}"
          </div>
        ) : (
          filteredCategories.map(category => {
            const selectionState = getCategorySelectionState(category);
            const isExpanded = expandedCategories.has(category.id);

            return (
              <div key={category.id} className="border border-border rounded-lg overflow-hidden">
                {/* Category Header */}
                <div className="flex items-center gap-2 p-3 bg-bg-tertiary hover:bg-bg-surface transition-colors">
                  <button
                    onClick={() => toggleCategoryExpansion(category.id)}
                    className="p-1 hover:bg-bg-primary rounded"
                    disabled={disabled}
                  >
                    {isExpanded ? (
                      <ChevronDown className="w-4 h-4" />
                    ) : (
                      <ChevronRight className="w-4 h-4" />
                    )}
                  </button>

                  <input
                    type="checkbox"
                    checked={selectionState === 'all'}
                    ref={input => {
                      if (input) input.indeterminate = selectionState === 'indeterminate';
                    }}
                    onChange={(e) => handleCategorySelect(category, e.target.checked)}
                    disabled={disabled}
                    className="w-4 h-4"
                  />

                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-text-primary truncate" title={category.display}>{category.display}</div>
                    <div className="text-xs text-text-muted">
                      {category.checks.length} checks
                    </div>
                  </div>

                  <div className="text-sm text-text-secondary">
                    {category.checks.filter(c => selectedChecks.has(c.id)).length}/{category.checks.length}
                  </div>
                </div>

                {/* Checks List */}
                {isExpanded && (
                  <div className="border-t border-border">
                    {category.checks.map(check => (
                      <div
                        key={check.id}
                        className="flex items-center gap-2 p-3 hover:bg-bg-tertiary transition-colors border-b border-border last:border-b-0"
                      >
                        <input
                          type="checkbox"
                          checked={selectedChecks.has(check.id)}
                          onChange={(e) => handleCheckSelect(check.id, e.target.checked)}
                          disabled={disabled}
                          className="w-4 h-4 ml-6"
                        />
                        <div className="flex-1 min-w-0">
                          <div className="font-mono text-sm text-accent-primary truncate" title={check.id}>{check.id}</div>
                          <div className="text-sm text-text-secondary truncate" title={check.name}>{check.name}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default CheckSelector;
