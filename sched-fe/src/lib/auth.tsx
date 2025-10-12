import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { api } from './api';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'ADMIN' | 'MANAGER' | 'GUEST';
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Detect iOS (including PWA mode)
const isIOS = () => {
  const ua = navigator.userAgent;
  const isIOSDevice = /iPad|iPhone|iPod/.test(ua);
  const isStandalone = 'standalone' in window.navigator && (window.navigator as any).standalone;

  if (isIOSDevice) {
    console.log('[Auth] iOS detected:', { isStandalone, userAgent: ua });
  }

  return isIOSDevice;
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const checkAuth = async () => {
    try {
      console.log('[Auth] Checking authentication...', { isIOS: isIOS() });
      const response = await api.get('/api/auth/me');
      console.log('[Auth] Authentication successful:', response.data.user);
      setUser(response.data.user);
    } catch (error: any) {
      console.log('[Auth] Authentication failed:', {
        status: error.response?.status,
        message: error.message,
        isIOS: isIOS(),
        cookies: document.cookie
      });
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    console.log('[Auth] Login attempt...', { email, isIOS: isIOS() });
    const response = await api.post('/api/auth/login', { email, password });
    console.log('[Auth] Login successful:', response.data.user);
    console.log('[Auth] Cookies after login:', document.cookie);
    setUser(response.data.user);
    setLoading(false);
  };

  const logout = async () => {
    console.log('[Auth] Logout attempt...');
    try {
      await api.post('/api/auth/logout');
    } catch (error) {
      // Ignore error
    } finally {
      setUser(null);
      window.location.href = '/login';
    }
  };

  useEffect(() => {
    // Small delay for iOS to ensure cookies are set
    const timer = setTimeout(() => {
      checkAuth();
    }, isIOS() ? 300 : 0);

    return () => clearTimeout(timer);
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, checkAuth }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
