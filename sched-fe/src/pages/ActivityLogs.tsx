import { useState, useEffect } from 'react';
import { api } from '../lib/api';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Skeleton } from '../components/ui/skeleton';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import { format } from 'date-fns';
import { Activity, User as UserIcon, Calendar as CalendarIcon, Link as LinkIcon, Key, Search } from 'lucide-react';
import { Pagination, PaginationContent, PaginationItem, PaginationPrevious, PaginationNext } from '../components/ui/pagination';
import { motion } from 'framer-motion';

interface ActivityLog {
  id: string;
  action: string;
  resource: string;
  resourceId?: string;
  description: string;
  metadata?: any;
  ipAddress?: string;
  userAgent?: string;
  createdAt: string;
  user?: {
    id: string;
    name: string;
    email: string;
    role: string;
  };
}

const actionIcons: Record<string, any> = {
  LOGIN: Key,
  LOGOUT: Key,
  CREATE: CalendarIcon,
  UPDATE: CalendarIcon,
  DELETE: CalendarIcon,
  VIEW: Activity,
};

const actionColors: Record<string, string> = {
  LOGIN: 'text-green-500',
  LOGOUT: 'text-gray-500',
  CREATE: 'text-blue-500',
  UPDATE: 'text-yellow-500',
  DELETE: 'text-red-500',
  VIEW: 'text-gray-400',
};

const resourceIcons: Record<string, any> = {
  USER: UserIcon,
  BOOKING: CalendarIcon,
  INVITATION: LinkIcon,
  SESSION: Key,
};

export default function ActivityLogs() {
  const { theme } = useTheme();
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterAction, setFilterAction] = useState<string>('all');
  const [filterResource, setFilterResource] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize] = useState(20);

  useEffect(() => {
    loadActivityLogs();
  }, [filterAction, filterResource, searchQuery, page]);

  // Reset page when filters change
  useEffect(() => {
    setPage(1);
  }, [filterAction, filterResource, searchQuery]);

  const loadActivityLogs = async () => {
    try {
      const params = new URLSearchParams();
      if (filterAction !== 'all') params.append('action', filterAction);
      if (filterResource !== 'all') params.append('resource', filterResource);
      params.append('limit', pageSize.toString());
      params.append('offset', ((page - 1) * pageSize).toString());

      const response = await api.get(`/api/activity-logs?${params.toString()}`);
      let filteredLogs = response.data.logs;

      // Client-side search filter
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase();
        filteredLogs = filteredLogs.filter((log: ActivityLog) =>
          log.user?.name.toLowerCase().includes(query) ||
          log.user?.email.toLowerCase().includes(query) ||
          log.description.toLowerCase().includes(query)
        );
      }

      setLogs(filteredLogs);
      setTotal(response.data.total);
    } catch (error) {
      toast.error('Failed to load activity logs');
    } finally {
      setLoading(false);
    }
  };

  const getActionIcon = (action: string) => {
    const Icon = actionIcons[action] || Activity;
    return Icon;
  };

  const getResourceIcon = (resource: string) => {
    const Icon = resourceIcons[resource] || Activity;
    return Icon;
  };


  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
      className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8"
    >
      {/* Activity Logs List */}
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <h3 className={`text-lg font-semibold mb-4 ${theme === 'dark' ? 'text-white' : ''}`}>
          Activity Logs
        </h3>

        {/* Filters */}
        <div className="flex flex-col gap-3 mb-6">
          <div className="relative">
            <Search className={`absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`} />
            <Input
              type="text"
              placeholder="Search by name or email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className={`pl-10 h-10 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white placeholder:text-gray-500' : ''}`}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <Select value={filterAction} onValueChange={setFilterAction}>
              <SelectTrigger className={`h-10 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
                <SelectValue placeholder="All Actions" />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                <SelectItem value="all">All Actions</SelectItem>
                <SelectItem value="LOGIN">Login</SelectItem>
                <SelectItem value="LOGOUT">Logout</SelectItem>
                <SelectItem value="CREATE">Create</SelectItem>
                <SelectItem value="UPDATE">Update</SelectItem>
                <SelectItem value="DELETE">Delete</SelectItem>
              </SelectContent>
            </Select>

            <Select value={filterResource} onValueChange={setFilterResource}>
              <SelectTrigger className={`h-10 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
                <SelectValue placeholder="All Resources" />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                <SelectItem value="all">All Resources</SelectItem>
                <SelectItem value="USER">Users</SelectItem>
                <SelectItem value="BOOKING">Bookings</SelectItem>
                <SelectItem value="INVITATION">Invitations</SelectItem>
                <SelectItem value="SESSION">Sessions</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        {loading ? (
          <div className="space-y-3">
            {[...Array(10)].map((_, i) => (
              <div key={i} className={`p-4 rounded-lg border ${theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-gray-50 border-gray-200'}`}>
                <div className="flex items-start gap-3">
                  <Skeleton className={`h-5 w-5 rounded-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
                  <div className="flex-1 space-y-2">
                    <Skeleton className={`h-5 w-3/4 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
                    <div className="flex gap-3">
                      <Skeleton className={`h-4 w-24 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
                      <Skeleton className={`h-4 w-20 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
                      <Skeleton className={`h-4 w-16 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : logs.length === 0 ? (
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            No activity logs found.
          </p>
        ) : (
          <div className="space-y-3">
            {logs.map((log) => {
              const ActionIcon = getActionIcon(log.action);
              const ResourceIcon = getResourceIcon(log.resource);
              const actionColor = actionColors[log.action] || 'text-gray-500';

              return (
                <div
                  key={log.id}
                  className={`p-4 rounded-lg border ${
                    theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-gray-50 border-gray-200'
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className={`mt-1 ${actionColor}`}>
                      <ActionIcon className="h-5 w-5" />
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2 mb-2">
                        <p className={`font-medium ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                          {log.description}
                        </p>
                        <span className={`text-xs whitespace-nowrap ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`}>
                          {format(new Date(log.createdAt), 'MMM d, yyyy HH:mm')}
                        </span>
                      </div>

                      <div className="flex flex-wrap gap-3 text-xs">
                        {log.user && (
                          <span className={`flex items-center gap-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                            <UserIcon className="h-3 w-3" />
                            {log.user.name} ({log.user.role})
                          </span>
                        )}

                        <span className={`flex items-center gap-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                          <ResourceIcon className="h-3 w-3" />
                          {log.resource}
                        </span>

                        <span className={`px-2 py-0.5 rounded ${actionColor} bg-opacity-10`}>
                          {log.action}
                        </span>

                        {log.ipAddress && (
                          <span className={theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}>
                            IP: {log.ipAddress}
                          </span>
                        )}
                      </div>

                      {log.metadata && Object.keys(log.metadata).length > 0 && (
                        <details className={`mt-2 text-xs ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`}>
                          <summary className="cursor-pointer hover:underline">Additional details</summary>
                          <pre className={`mt-2 p-2 rounded ${theme === 'dark' ? 'bg-zinc-950' : 'bg-gray-100'}`}>
                            {JSON.stringify(log.metadata, null, 2)}
                          </pre>
                        </details>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Pagination */}
        {!loading && logs.length > 0 && (
          <div className={`mt-6 pt-4 border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}>
            <Pagination>
              <PaginationContent className={theme === 'dark' ? 'text-white' : ''}>
                <PaginationItem>
                  <PaginationPrevious
                    onClick={() => setPage(p => Math.max(1, p - 1))}
                    className={`cursor-pointer ${page === 1 ? 'pointer-events-none opacity-50' : ''} ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800 hover:text-white' : ''}`}
                  />
                </PaginationItem>
                <PaginationItem>
                  <span className={`text-sm px-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                    Page {page} of {Math.ceil(total / pageSize)}
                  </span>
                </PaginationItem>
                <PaginationItem>
                  <PaginationNext
                    onClick={() => setPage(p => p + 1)}
                    className={`cursor-pointer ${page >= Math.ceil(total / pageSize) ? 'pointer-events-none opacity-50' : ''} ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800 hover:text-white' : ''}`}
                  />
                </PaginationItem>
              </PaginationContent>
            </Pagination>
          </div>
        )}
      </Card>
    </motion.div>
  );
}
