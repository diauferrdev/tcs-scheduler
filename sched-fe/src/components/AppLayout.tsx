import { ReactNode, useState } from 'react';
import { useAuth } from '../lib/auth';
import { useTheme } from '../hooks/use-theme';
import { useIsMobile } from '../hooks/use-mobile';
import { useNavigate, useLocation } from 'react-router-dom';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from './ui/dropdown-menu';
import { Button } from './ui/button';
import { Moon, Sun, User, LogOut, LayoutDashboard, Calendar as CalendarIcon, Link as LinkIcon, Users, Activity } from 'lucide-react';
import { toast } from 'sonner';
import logoBlack from '../assets/tcs-logo-b.svg';
import logoWhite from '../assets/tcs-logo-w.svg';

interface AppLayoutProps {
  children: ReactNode;
}

export default function AppLayout({ children }: AppLayoutProps) {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const isMobile = useIsMobile();
  const navigate = useNavigate();
  const location = useLocation();
  const [, setMobileMenuOpen] = useState(false);

  const handleLogout = async () => {
    try {
      await logout();
      toast.success('Logged out successfully');
      navigate('/login');
    } catch (error) {
      toast.error('Failed to logout');
    }
  };

  const menuItems = [
    { path: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, roles: ['ADMIN', 'MANAGER'] },
    { path: '/calendar', label: 'Bookings', icon: CalendarIcon, roles: ['ADMIN', 'MANAGER'] },
    { path: '/invitations', label: 'Invitations', icon: LinkIcon, roles: ['ADMIN', 'MANAGER'] },
    { path: '/users', label: 'Users', icon: Users, roles: ['ADMIN'] },
    { path: '/activity-logs', label: 'Activity Logs', icon: Activity, roles: ['ADMIN'] },
  ].filter(item => item.roles.includes(user?.role || ''));

  const handleMenuItemClick = (path: string) => {
    navigate(path);
    setMobileMenuOpen(false);
  };

  const NavContent = ({ mobile = false }) => (
    <nav className="space-y-2">
      {menuItems.map((item, index) => {
        const Icon = item.icon;
        const isActive = location.pathname === item.path;
        return (
          <button
            key={item.path}
            onClick={() => mobile ? handleMenuItemClick(item.path) : navigate(item.path)}
            className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 ${
              isActive
                ? theme === 'dark'
                  ? 'bg-white text-black shadow-lg scale-[1.02]'
                  : 'bg-black text-white shadow-lg scale-[1.02]'
                : theme === 'dark'
                ? 'text-gray-400 hover:bg-zinc-800 hover:text-white hover:scale-[1.01]'
                : 'text-gray-600 hover:bg-gray-100 hover:text-black hover:scale-[1.01]'
            }`}
            style={{
              animationDelay: mobile ? `${index * 50}ms` : '0ms',
            }}
          >
            <Icon className="w-5 h-5" />
            <span className="font-medium">{item.label}</span>
          </button>
        );
      })}
    </nav>
  );

  return (
    <div className={`min-h-[100dvh] ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'} ${isMobile ? 'pb-20' : ''}`}>
      {/* Header */}
      <header className={`sticky top-0 z-40 border-b ${theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-white border-gray-200'}`}>
        <div className="flex items-center justify-between h-16 px-4 lg:px-6">
          {/* Logo */}
          <div className="flex items-center gap-2">
            <img
              src={theme === 'dark' ? logoWhite : logoBlack}
              alt="TCS Logo"
              className="h-12 w-auto"
            />
            {!isMobile && (
              <div className={`h-6 w-px mx-2 ${theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-300'}`} />
            )}
            {!isMobile && (
              <span className={`text-sm font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                Scheduler
              </span>
            )}
          </div>

          {/* Right: Theme + User Menu */}
          <div className="flex items-center gap-2">
            {/* Theme Toggle */}
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleTheme}
              className={theme === 'dark' ? 'text-white hover:bg-zinc-800' : 'text-black hover:bg-gray-100'}
            >
              {theme === 'dark' ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </Button>

            {/* User Menu */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className={theme === 'dark' ? 'text-white hover:bg-zinc-800' : 'text-black hover:bg-gray-100'}
                >
                  <User className="w-5 h-5" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : 'bg-white border-gray-200'}>
                <DropdownMenuLabel className={theme === 'dark' ? 'text-white' : 'text-black'}>
                  {user?.name}
                </DropdownMenuLabel>
                <DropdownMenuLabel className={`text-xs font-normal ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  {user?.email}
                </DropdownMenuLabel>
                <DropdownMenuSeparator className={theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-200'} />
                <DropdownMenuItem
                  onClick={handleLogout}
                  className={theme === 'dark' ? 'text-gray-300 hover:bg-zinc-800 hover:text-white' : 'text-gray-700 hover:bg-gray-100 hover:text-black'}
                >
                  <LogOut className="w-4 h-4 mr-2" />
                  Logout
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar (Desktop only) */}
        {!isMobile && (
          <aside className={`sticky top-16 h-[calc(100vh-4rem)] w-64 border-r ${theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-white border-gray-200'}`}>
            <div className="p-4">
              <NavContent />
            </div>
          </aside>
        )}

        {/* Main Content */}
        <main className="flex-1">
          {children}
        </main>
      </div>

      {/* Mobile Bottom Navigation */}
      {isMobile && (
        <nav className={`fixed bottom-0 left-0 right-0 z-50 border-t ${theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-white border-gray-200'}`}>
          <div className="flex items-center justify-around h-20 px-2">
            {menuItems.map((item) => {
              const Icon = item.icon;
              const isActive = location.pathname === item.path;
              return (
                <button
                  key={item.path}
                  onClick={() => navigate(item.path)}
                  className={`flex flex-col items-center justify-center gap-1 px-3 py-2 rounded-lg transition-all ${
                    isActive
                      ? theme === 'dark'
                        ? 'text-white'
                        : 'text-black'
                      : theme === 'dark'
                      ? 'text-gray-500'
                      : 'text-gray-400'
                  }`}
                >
                  <Icon className={`w-6 h-6 ${isActive ? 'scale-110' : ''} transition-transform`} />
                  <span className={`text-[10px] font-medium ${isActive ? 'font-semibold' : ''}`}>
                    {item.label}
                  </span>
                </button>
              );
            })}
          </div>
        </nav>
      )}
    </div>
  );
}
