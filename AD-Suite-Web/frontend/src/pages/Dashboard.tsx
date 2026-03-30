import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate, Link } from 'react-router-dom';
import { 
    PieChart, Pie, Cell, XAxis, YAxis, Tooltip, ResponsiveContainer,
    AreaChart, Area, CartesianGrid 
} from 'recharts';
import { 
    Shield, AlertTriangle, Download, 
    ArrowRight, Server, Search, TrendingUp, TrendingDown,
    Zap, RefreshCw
} from 'lucide-react';
import api from '../lib/api';
import { downloadAuthenticated } from '../lib/download';
import clsx from 'clsx';

interface DashboardStats {
    totalChecks: number;
    severityData: Record<string, number>;
    categoryData: Record<string, number>;
    activeScans: number;
    riskScore: number;
    postureScore: number;
    delta: number;
    trends: Array<{
        timestamp: number;
        totalFindings: number;
        riskScore: number;
        postureScore: number;
    }>;
}

interface RecentScan {
    id: string;
    timestamp: number;
    status: string;
    totalFindings: number;
}

const themeColors: Record<string, string> = {
    critical: '#f85149',
    high: '#f0883e',
    medium: '#d29922',
    low: '#58a6ff',
    info: '#8b9cb3'
};

export default function Dashboard() {
    const navigate = useNavigate();

    const { data: stats, isLoading, isRefetching } = useQuery<DashboardStats>({
        queryKey: ['dashboard-stats'],
        queryFn: async () => (await api.get('/dashboard/stats')).data,
        refetchInterval: 5000
    });

    const { data: recentRes } = useQuery<{ recent: RecentScan[] }>({
        queryKey: ['dashboard-recent'],
        queryFn: async () => (await api.get('/dashboard/recent')).data,
        refetchInterval: 5000
    });

    const recentScans = recentRes?.recent || [];

    const severityPieData = useMemo(() => {
        const data = stats?.severityData;
        if (!data || typeof data !== 'object') return [];
        return Object.entries(data)
            .filter(([_, value]) => typeof value === 'number' && value > 0)
            .map(([name, value]) => ({ 
                name: name.charAt(0).toUpperCase() + name.slice(1), 
                value, 
                rawName: name 
            }));
    }, [stats]);

    const trendData = useMemo(() => {
        if (!stats?.trends || !Array.isArray(stats.trends)) return [];
        return stats.trends.map(t => ({
            ...t,
            date: new Date(t.timestamp).toLocaleDateString([], { month: 'short', day: 'numeric' })
        }));
    }, [stats]);

    const handleDownloadScan = async (scanId: string) => {
        try {
            await downloadAuthenticated(
                `reports/export/${scanId}/json`,
                `AD_Suite_Scan_${scanId}.json`
            );
        } catch (e) {
            console.error(e);
        }
    };

    if (isLoading && !stats) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-4">
                <RefreshCw className="animate-spin text-accent-orange" size={48} />
                <p className="text-text-secondary font-medium uppercase tracking-widest text-xs">Initializing Security Analytics...</p>
            </div>
        );
    }

    const totalFindings = Object.values(stats?.severityData || {}).reduce((a, b) => a + (typeof b === 'number' ? b : 0), 0);

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-10">
            <header className="flex flex-col md:flex-row md:items-end justify-between gap-4">
                <div>
                    <div className="flex items-center gap-2 mb-1">
                        <h1 className="text-3xl font-bold text-text-primary tracking-tight">Security Command Center</h1>
                        {isRefetching && <RefreshCw size={14} className="text-accent-orange animate-spin" />}
                    </div>
                    <p className="text-text-secondary">Enterprise posture overview and threat intelligence</p>
                </div>
                <div className="flex items-center gap-3">
                    <button 
                        onClick={() => navigate('/scans')}
                        className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-accent-orange hover:bg-accent-orange-hover text-white font-semibold transition-all shadow-lg shadow-accent-orange/20"
                    >
                        <Zap size={18} /> Run New Scan
                    </button>
                </div>
            </header>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {/* Posture Card */}
                <div className="group bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm hover:border-accent-orange/50 transition-all">
                    <div className="flex items-center justify-between mb-4">
                        <span className="text-[10px] font-bold text-text-secondary uppercase tracking-widest">Posture Score</span>
                        <div className="p-2 rounded-xl bg-accent-orange/10"><Shield className="text-accent-orange" size={20} /></div>
                    </div>
                    <div className="flex items-end gap-3">
                        <div className="text-5xl font-bold text-white tracking-tighter">{stats?.postureScore || 100}%</div>
                    </div>
                    <div className="mt-4 h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                        <div className="h-full bg-accent-orange transition-all duration-1000" style={{ width: `${stats?.postureScore || 100}%` }} />
                    </div>
                </div>

                {/* Findings Delta */}
                <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm">
                    <div className="flex items-center justify-between mb-4">
                        <span className="text-[10px] font-bold text-text-secondary uppercase tracking-widest">Findings Delta</span>
                        <div className={clsx("p-2 rounded-xl", (stats?.delta || 0) > 0 ? "bg-critical/10" : "bg-green-500/10")}>
                            {(stats?.delta || 0) > 0 ? <TrendingUp className="text-critical" size={20} /> : <TrendingDown className="text-green-500" size={20} />}
                        </div>
                    </div>
                    <div className="text-4xl font-bold text-white tracking-tighter">{Math.abs(stats?.delta || 0)}</div>
                    <p className="mt-2 text-[10px] uppercase font-bold text-text-tertiary tracking-wider">
                        {(stats?.delta || 0) > 0 ? "Regression Detected" : "Posture Improved"}
                    </p>
                </div>

                {/* Identity Checks */}
                <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm">
                    <div className="flex items-center justify-between mb-4">
                        <span className="text-[10px] font-bold text-text-secondary uppercase tracking-widest">Identity Checks</span>
                        <div className="p-2 rounded-xl bg-info/10"><Server className="text-info" size={20} /></div>
                    </div>
                    <div className="text-4xl font-bold text-white tracking-tighter">{stats?.totalChecks || 0}</div>
                    <p className="mt-2 text-[10px] uppercase font-bold text-text-tertiary tracking-wider">Active Monitoring</p>
                </div>

                {/* Critical Count */}
                <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 border-l-4 border-l-critical shadow-sm">
                    <div className="flex items-center justify-between mb-4">
                        <span className="text-[10px] font-bold text-text-secondary uppercase tracking-widest">Critical Exposure</span>
                        <div className="p-2 rounded-xl bg-critical/10"><AlertTriangle className="text-critical" size={20} /></div>
                    </div>
                    <div className="text-4xl font-bold text-critical tracking-tighter">{stats?.severityData?.critical || 0}</div>
                    <p className="mt-2 text-[10px] uppercase font-bold text-text-tertiary tracking-wider">Remediation Pending</p>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-2 bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm">
                    <h2 className="text-sm font-bold text-white uppercase tracking-widest mb-8">Security Posture Trend</h2>
                    <div className="h-[300px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={trendData}>
                                <defs>
                                    <linearGradient id="colorRisk" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#E8500A" stopOpacity={0.3}/>
                                        <stop offset="95%" stopColor="#E8500A" stopOpacity={0}/>
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#333" />
                                <XAxis dataKey="date" stroke="#666" fontSize={10} tickLine={false} axisLine={false} />
                                <YAxis stroke="#666" fontSize={10} tickLine={false} axisLine={false} />
                                <Tooltip contentStyle={{ backgroundColor: '#0D0D0D', borderColor: '#333', borderRadius: '12px' }} />
                                <Area type="monotone" dataKey="riskScore" stroke="#E8500A" strokeWidth={3} fillOpacity={1} fill="url(#colorRisk)" />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm flex flex-col">
                    <h2 className="text-sm font-bold text-white uppercase tracking-widest mb-6">Severity Distribution</h2>
                    {severityPieData.length > 0 ? (
                        <div className="flex-grow flex items-center justify-center relative">
                            <ResponsiveContainer width="100%" height={250}>
                                <PieChart>
                                    <Pie data={severityPieData} cx="50%" cy="50%" innerRadius={60} outerRadius={85} paddingAngle={5} dataKey="value">
                                        {severityPieData.map((e, i) => <Cell key={i} fill={themeColors[e.rawName] || themeColors.info} stroke="none" />)}
                                    </Pie>
                                    <Tooltip contentStyle={{ backgroundColor: '#0D0D0D', borderColor: '#333', borderRadius: '12px' }} />
                                </PieChart>
                            </ResponsiveContainer>
                            <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                                <span className="text-3xl font-bold text-white">{totalFindings}</span>
                                <span className="text-[8px] text-text-tertiary uppercase font-bold tracking-widest">Total Reports</span>
                            </div>
                        </div>
                    ) : (
                        <div className="flex-grow flex items-center justify-center text-text-tertiary italic text-xs">Baseline Stable</div>
                    )}
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
                <div className="bg-bg-tertiary border border-border-medium rounded-2xl p-6 shadow-sm">
                    <h2 className="text-[10px] font-bold text-white mb-5 uppercase tracking-widest">Quick Actions</h2>
                    <div className="space-y-2">
                        <button onClick={() => navigate('/scans')} className="w-full p-4 rounded-xl border border-border-medium hover:border-accent-orange/40 transition-all flex items-center justify-between group">
                            <span className="text-xs font-bold text-text-primary uppercase">Run Full Suite</span>
                            <ArrowRight size={14} className="group-hover:translate-x-1 transition-transform" />
                        </button>
                        <button onClick={() => navigate('/scans?category=Kerberos_Security')} className="w-full p-4 rounded-xl border border-border-medium hover:border-accent-orange/40 transition-all flex items-center justify-between group">
                            <span className="text-xs font-bold text-text-primary uppercase">Kerberos Audit</span>
                            <ArrowRight size={14} className="group-hover:translate-x-1 transition-transform" />
                        </button>
                        <button onClick={() => navigate('/reports')} className="w-full p-4 rounded-xl bg-bg-secondary/50 border border-dashed border-border-medium hover:border-accent-orange/60 transition-all flex items-center justify-center gap-2 text-[10px] font-bold uppercase tracking-widest text-text-tertiary hover:text-white">
                            <Search size={14} /> View All Reports
                        </button>
                    </div>
                </div>

                <div className="lg:col-span-3 bg-bg-tertiary border border-border-medium rounded-2xl shadow-sm overflow-hidden">
                    <div className="px-6 py-5 border-b border-border-medium flex justify-between items-center bg-white/5">
                        <h2 className="text-sm font-bold text-white uppercase tracking-widest">Recent Activity</h2>
                        <Link to="/reports" className="text-[10px] font-bold text-accent-orange hover:text-white uppercase tracking-widest">Archive</Link>
                    </div>
                    <div className="overflow-x-auto">
                        <table className="w-full text-[10px]">
                            <thead>
                                <tr className="text-left bg-bg-secondary/30 uppercase tracking-widest text-text-tertiary">
                                    <th className="px-6 py-4">ID</th>
                                    <th className="px-6 py-4">Status</th>
                                    <th className="px-6 py-4">Findings</th>
                                    <th className="px-6 py-4">Timestamp</th>
                                    <th className="px-6 py-4 text-right">Action</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-border-medium/30">
                                {recentScans.map((s) => (
                                    <tr key={s.id} className="hover:bg-white/5 transition-colors group">
                                        <td className="px-6 py-4 font-mono text-text-secondary">{s.id}</td>
                                        <td className="px-6 py-4"><span className="text-green-500 font-bold uppercase tracking-tighter italic">Secured</span></td>
                                        <td className="px-6 py-4 font-bold text-white">{s.totalFindings}</td>
                                        <td className="px-6 py-4 text-text-tertiary">{new Date(s.timestamp).toLocaleString()}</td>
                                        <td className="px-6 py-4 text-right">
                                            <button onClick={() => handleDownloadScan(s.id)} className="p-2 text-text-tertiary hover:text-accent-orange transition-all"><Download size={14} /></button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
}
