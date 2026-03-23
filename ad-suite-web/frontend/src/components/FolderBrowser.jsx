import React, { useState, useEffect } from 'react';
import { ChevronRight, Folder, FolderOpen, HardDrive, ArrowLeft, Home, Monitor } from 'lucide-react';
import { browseFolder } from '../lib/api';

const FolderBrowser = ({ isOpen, onClose, onSelectPath, initialPath = 'drives' }) => {
  const [currentPath, setCurrentPath] = useState(initialPath);
  const [items, setItems] = useState([]);
  const [parentPath, setParentPath] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [isDriveList, setIsDriveList] = useState(false);

  const loadFolder = async (path) => {
    setLoading(true);
    setError(null);
    try {
      const result = await browseFolder(path);
      if (result.error) {
        setError(result.error);
      } else {
        setItems(result.items || []);
        setCurrentPath(result.currentPath);
        setParentPath(result.parentPath);
        setIsDriveList(result.isDriveList || false);
      }
    } catch (err) {
      setError(err.message || 'Failed to load folder');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadFolder('drives');
    }
  }, [isOpen]);

  const handleFolderClick = (item) => {
    if (item.isDirectory) {
      loadFolder(item.path);
    }
  };

  const handleParentClick = () => {
    if (parentPath) {
      loadFolder(parentPath);
    }
  };

  const handleHomeClick = () => {
    loadFolder('drives');
  };

  const handleSelect = () => {
    if (isDriveList) {
      setError('Please select a folder, not the drive list');
      return;
    }
    onSelectPath(currentPath);
    onClose();
  };

  const handleDoubleClick = (item) => {
    if (item.isDirectory) {
      handleFolderClick(item);
    }
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-bg-primary rounded-lg shadow-xl w-full max-w-4xl max-h-[80vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-border">
          <h3 className="text-lg font-semibold text-text-primary">Select Folder</h3>
          <div className="flex items-center gap-2">
            <button
              onClick={handleHomeClick}
              className="p-2 hover:bg-bg-secondary rounded transition-colors"
              title="Go to root"
            >
              <Home className="w-4 h-4 text-text-secondary" />
            </button>
            <button
              onClick={handleParentClick}
              disabled={!parentPath}
              className="p-2 hover:bg-bg-secondary rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              title="Go to parent"
            >
              <ArrowLeft className="w-4 h-4 text-text-secondary" />
            </button>
            <button
              onClick={onClose}
              className="p-2 hover:bg-bg-secondary rounded transition-colors"
            >
              ×
            </button>
          </div>
        </div>

        {/* Current Path */}
        <div className="px-4 py-2 bg-bg-secondary border-b border-border">
          <div className="flex items-center gap-2 text-sm text-text-secondary">
            {isDriveList ? (
              <>
                <Monitor className="w-4 h-4" />
                <span className="font-mono">This PC - Select a drive</span>
              </>
            ) : (
              <>
                <HardDrive className="w-4 h-4" />
                <span className="font-mono">{currentPath}</span>
              </>
            )}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="px-4 py-2 bg-severity-critical bg-opacity-10 border border-severity-critical text-severity-critical text-sm">
            {error}
          </div>
        )}

        {/* File List */}
        <div className="flex-1 overflow-auto p-4">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-accent-primary"></div>
            </div>
          ) : (
            <div className="space-y-1">
              {items.map((item, index) => (
                <div
                  key={index}
                  className={`flex items-center gap-3 p-2 rounded cursor-pointer hover:bg-bg-secondary transition-colors ${item.isDirectory ? 'font-medium' : ''
                    }`}
                  onClick={() => handleFolderClick(item)}
                  onDoubleClick={() => handleDoubleClick(item)}
                >
                  {item.isDrive ? (
                    <HardDrive className="w-5 h-5 text-accent-primary flex-shrink-0" />
                  ) : item.isDirectory ? (
                    <FolderOpen className="w-5 h-5 text-accent-primary flex-shrink-0" />
                  ) : (
                    <div className="w-5 h-5 flex items-center justify-center">
                      <div className="w-4 h-4 bg-bg-tertiary rounded"></div>
                    </div>
                  )}

                  <div className="flex-1 min-w-0">
                    <div className="text-text-primary truncate">{item.name}</div>
                    {!item.isDirectory && !item.isDrive && (
                      <div className="text-xs text-text-secondary">
                        {formatFileSize(item.size)}
                      </div>
                    )}
                  </div>

                  {(item.isDirectory || item.isDrive) && (
                    <ChevronRight className="w-4 h-4 text-text-secondary flex-shrink-0" />
                  )}
                </div>
              ))}

              {items.length === 0 && !loading && !error && (
                <div className="text-center py-8 text-text-secondary">
                  <Folder className="w-12 h-12 mx-auto mb-2 opacity-50" />
                  <div>Empty folder</div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between p-4 border-t border-border">
          <div className="text-sm text-text-secondary">
            {items.length} items
          </div>
          <div className="flex gap-2">
            <button
              onClick={onClose}
              className="btn-secondary"
            >
              Cancel
            </button>
            <button
              onClick={handleSelect}
              className="btn-primary"
              disabled={isDriveList}
            >
              Select Current Folder
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default FolderBrowser;
