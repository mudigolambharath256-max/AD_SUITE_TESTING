import React from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Play,
  GitBranch,
  Plug,
  FileText,
  Settings,
  Shield,
  Activity
} from 'lucide-react';

const Sidebar = ({ isCollapsed, onToggle }) => {
  const location = useLocation();

  const navItems = [
    { path: '/', label: 'Dashboard', icon: LayoutDashboard },
    { path: '/scans', label: 'Run Scans', icon: Play },
    { path: '/attack-path', label: 'Attack Path', icon: GitBranch },
    { path: '/integrations', label: 'Integrations', icon: Plug },
    { path: '/reports', label: 'Reports', icon: FileText },
    { path: '/settings', label: 'Settings', icon: Settings },
  ];

  return (
    <div className={`sidebar transition-all duration-300 ${isCollapsed ? 'w-12' : 'w-60'}`}>
      {/* Logo Section */}
      <div className="p-4 border-b border-border">
        <div className="flex items-center gap-3">
          <div className="flex-shrink-0">
            <Shield className="w-8 h-8 text-accent-primary" fill="currentColor" />
          </div>
          {!isCollapsed && (
            <div className="flex-1 min-w-0">
              <h1 className="text-lg font-bold text-text-primary">AD Suite</h1>
              <p className="text-xs text-text-secondary">Security Platform</p>
            </div>
          )}
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = location.pathname === item.path;

          return (
            <NavLink
              key={item.path}
              to={item.path}
              className={`sidebar-link ${isActive ? 'sidebar-link-active' : 'sidebar-link-inactive'
                }`}
              title={isCollapsed ? item.label : undefined}
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              {!isCollapsed && <span className="truncate">{item.label}</span>}
            </NavLink>
          );
        })}
      </nav>

      {/* Bottom Info Card */}
      <div className="p-2 border-t border-border">
        <div className="card p-3">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-2 h-2 bg-green-500 rounded-full"></div>
            {!isCollapsed && (
              <span className="text-xs text-text-secondary">System Ready</span>
            )}
          </div>
          {!isCollapsed && (
            <button
              onClick={() => window.location.href = '/scans'}
              className="btn-secondary text-xs w-full"
            >
              Quick Scan
            </button>
          )}
        </div>
      </div>

      {/* Mobile Toggle */}
      {isCollapsed && (
        <button
          onClick={onToggle}
          className="absolute -right-3 top-8 w-6 h-6 bg-accent-primary text-bg-primary rounded-full flex items-center justify-center shadow-lg active-scale"
          title="Expand sidebar"
        >
          <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      )}
    </div>
  );
};

export default Sidebar;
