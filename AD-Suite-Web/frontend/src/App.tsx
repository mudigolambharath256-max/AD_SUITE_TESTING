import { Routes, Route, Navigate } from 'react-router-dom';
import { useEffect } from 'react';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Scans from './pages/Scans';
import NewScan from './pages/NewScan';
import ScanDetail from './pages/ScanDetail';
import Reports from './pages/Reports';
import Analysis from './pages/Analysis';
import AttackPath from './pages/AttackPath';
import Terminal from './pages/Terminal';
import Settings from './pages/Settings';
import Login from './pages/Login';
import { useAuthStore } from './store/authStore';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
    const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
    if (!isAuthenticated) return <Navigate to="/login" replace />;
    return <>{children}</>;
}

function AppRoutes() {
    return (
        <Layout>
            <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/scans" element={<Scans />} />
                <Route path="/scans/new" element={<NewScan />} />
                <Route path="/scans/:id" element={<ScanDetail />} />
                <Route path="/reports" element={<Reports />} />
                <Route path="/analysis" element={<Analysis />} />
                <Route path="/attack-path" element={<AttackPath />} />
                <Route path="/terminal" element={<Terminal />} />
                <Route path="/settings" element={<Settings />} />
            </Routes>
        </Layout>
    );
}

function App() {
    useEffect(() => {
        document.documentElement.setAttribute('data-theme', 'dark');
    }, []);

    return (
        <Routes>
            <Route path="/login" element={<Login />} />
            <Route
                path="/*"
                element={
                    <ProtectedRoute>
                        <AppRoutes />
                    </ProtectedRoute>
                }
            />
        </Routes>
    );
}

export default App;
