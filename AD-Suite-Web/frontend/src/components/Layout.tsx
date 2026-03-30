import { ReactNode, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, ScanSearch, FileText, Settings, LogOut, Menu, BarChart3, Network, TerminalSquare } from 'lucide-react';
import { useAuthStore } from '../store/authStore';

interface LayoutProps {
    children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
    const location = useLocation();
    const { user, logout } = useAuthStore();
    const [mobileNavOpen, setMobileNavOpen] = useState(false);

    const navigation = [
        { name: 'Dashboard', href: '/', icon: LayoutDashboard },
        { name: 'Scans', href: '/scans', icon: ScanSearch },
        { name: 'Reports', href: '/reports', icon: FileText },
        { name: 'Attack Path', href: '/attack-path', icon: Network },
        { name: 'Analysis', href: '/analysis', icon: BarChart3 },
        { name: 'Terminal', href: '/terminal', icon: TerminalSquare },
        { name: 'Settings', href: '/settings', icon: Settings }
    ];

    return (
        <div className="min-h-screen bg-bg-primary flex">
            {mobileNavOpen && (
                <button
                    type="button"
                    aria-label="Close menu"
                    className="fixed inset-0 z-40 bg-black/50 lg:hidden"
                    onClick={() => setMobileNavOpen(false)}
                />
            )}
            {/* Sidebar */}
            <div
                className={`fixed inset-y-0 left-0 z-50 w-64 bg-bg-secondary border-r border-border-light flex flex-col transition-transform duration-300 lg:static lg:translate-x-0 ${
                    mobileNavOpen ? 'translate-x-0' : '-translate-x-full'
                }`}
            >
                {/* Logo */}
                <div className="p-6 border-b border-border-light">
                    <div className="flex items-center gap-3">
                        <img
                            src="/technieum-logo.png"
                            alt=""
                            className="h-11 w-auto object-contain object-left shrink-0"
                        />
                        <div className="min-w-0">
                            <h1 className="text-lg font-semibold text-text-primary leading-snug">
                                Technieum AD suite
                            </h1>
                            <p className="text-xs text-text-secondary mt-0.5">Security Assessment</p>
                        </div>
                    </div>
                </div>

                {/* Navigation */}
                <nav className="flex-1 px-3 py-4 space-y-1">
                    {navigation.map((item) => {
                        const Icon = item.icon;
                        const isActive = location.pathname === item.href;
                        return (
                            <Link
                                key={item.name}
                                to={item.href}
                                onClick={() => setMobileNavOpen(false)}
                                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150 ${isActive
                                        ? 'bg-bg-active text-text-primary'
                                        : 'text-text-secondary hover:bg-bg-hover hover:text-text-primary'
                                    }`}
                            >
                                <Icon size={18} />
                                <span>{item.name}</span>
                            </Link>
                        );
                    })}
                </nav>

                {/* User Footer */}
                <div className="p-3 border-t border-border-light">
                    <div className="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-bg-hover transition-all duration-150 cursor-pointer group">
                        <div className="w-7 h-7 rounded-full bg-accent-orange-light flex items-center justify-center text-accent-orange font-semibold text-sm">
                            {user?.name.charAt(0)}
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-text-primary truncate">{user?.name}</p>
                            <p className="text-xs text-text-secondary truncate">{user?.email}</p>
                        </div>
                        <button
                            onClick={logout}
                            className="opacity-0 group-hover:opacity-100 p-1.5 hover:bg-bg-tertiary rounded-md transition-all duration-150"
                            title="Logout"
                        >
                            <LogOut size={16} className="text-text-secondary" />
                        </button>
                    </div>
                </div>
            </div>

            {/* Main content */}
            <div className="flex-1 flex flex-col overflow-hidden">
                {/* Top bar */}
                <div className="h-14 bg-bg-primary border-b border-border-light flex items-center justify-between px-6">
                    <div className="flex items-center gap-4">
                        <button
                            type="button"
                            className="lg:hidden p-2 hover:bg-bg-hover rounded-lg transition-colors"
                            aria-expanded={mobileNavOpen}
                            aria-label={mobileNavOpen ? 'Close navigation' : 'Open navigation'}
                            onClick={() => setMobileNavOpen((o) => !o)}
                        >
                            <Menu size={20} className="text-text-secondary" />
                        </button>
                        <div className="text-sm font-medium text-text-primary">
                            {navigation.find(n => n.href === location.pathname)?.name || 'Technieum AD suite'}
                        </div>
                    </div>
                    <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-accent-orange-light flex items-center justify-center text-accent-orange font-semibold text-xs cursor-pointer hover:bg-accent-orange hover:text-white transition-all">
                            {user?.name.charAt(0)}
                        </div>
                    </div>
                </div>

                {/* Page content */}
                <main className="flex-1 overflow-auto">
                    <div className="max-w-7xl mx-auto p-6">
                        {children}
                    </div>
                </main>
            </div>
        </div>
    );
}
