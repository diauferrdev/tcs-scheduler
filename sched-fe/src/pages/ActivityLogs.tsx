import { useState, useEffect } from 'react';
import { ColumnDef } from '@tanstack/react-table';
import { api } from '@/lib/api';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import { format } from 'date-fns';
import { motion } from 'framer-motion';
import { DataTable } from '../components/data-table';
import { DataTableColumnHeader } from '../components/data-table/data-table-column-header';
import { Badge } from '../components/ui/badge';

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

const actionColors: Record<string, string> = {
  LOGIN: 'text-green-500',
  LOGOUT: 'text-gray-500',
  CREATE: 'text-blue-500',
  UPDATE: 'text-yellow-500',
  DELETE: 'text-red-500',
  VIEW: 'text-gray-400',
};

// Colunas da tabela
const activityLogColumns: ColumnDef<ActivityLog>[] = [
  {
    accessorKey: 'action',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Action" />
    ),
    cell: ({ row }) => {
      const action = row.getValue('action') as string;
      const color = actionColors[action] || 'text-gray-500';
      return (
        <Badge variant="outline" className={color}>
          {action}
        </Badge>
      );
    },
  },
  {
    accessorKey: 'resource',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Resource" />
    ),
    cell: ({ row }) => {
      const resource = row.getValue('resource') as string;
      return <span>{resource}</span>;
    },
  },
  {
    accessorKey: 'description',
    header: 'Description',
    cell: ({ row }) => {
      return <div className="max-w-md truncate">{row.getValue('description')}</div>;
    },
  },
  {
    accessorKey: 'user',
    header: 'User',
    cell: ({ row }) => {
      const user = row.getValue('user') as ActivityLog['user'];
      if (!user) return <span className="text-gray-400">System</span>;
      return (
        <div>
          <div className="font-medium">{user.name}</div>
          <div className="text-sm text-gray-500">{user.role}</div>
        </div>
      );
    },
  },
  {
    accessorKey: 'createdAt',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Date" />
    ),
    cell: ({ row }) => {
      return (
        <span className="text-sm">
          {format(new Date(row.getValue('createdAt')), 'MMM d, yyyy HH:mm')}
        </span>
      );
    },
  },
];

// Mobile Card Component
const ActivityLogMobileCard = (log: ActivityLog) => {
  const actionColor = actionColors[log.action] || 'text-gray-500';

  return (
    <div className="space-y-3">
      <div className="flex items-start justify-between gap-2">
        <p className="font-medium flex-1">{log.description}</p>
        <span className="text-xs text-gray-500 whitespace-nowrap">
          {format(new Date(log.createdAt), 'MMM d, HH:mm')}
        </span>
      </div>

      <div className="flex flex-wrap gap-2">
        <Badge variant="outline" className={`${actionColor} text-xs`}>
          {log.action}
        </Badge>

        <div className="text-xs text-gray-500">
          {log.resource}
        </div>

        {log.user && (
          <div className="text-xs text-gray-500">
            {log.user.name} ({log.user.role})
          </div>
        )}
      </div>

      {log.ipAddress && (
        <div className="text-xs text-gray-400">IP: {log.ipAddress}</div>
      )}
    </div>
  );
};

export default function ActivityLogs() {
  const { theme } = useTheme();
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterAction, setFilterAction] = useState<string>('all');
  const [filterResource, setFilterResource] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [debouncedSearch, setDebouncedSearch] = useState<string>('');

  // Debounce search query
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(searchQuery);
    }, 500);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  useEffect(() => {
    loadActivityLogs();
  }, [filterAction, filterResource, debouncedSearch]);

  const loadActivityLogs = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (filterAction !== 'all') params.append('action', filterAction);
      if (filterResource !== 'all') params.append('resource', filterResource);
      if (debouncedSearch.trim()) params.append('search', debouncedSearch.trim());
      params.append('limit', '100');

      const response = await api.get(`/api/activity-logs?${params.toString()}`);
      setLogs(response.data.logs);
    } catch (error) {
      toast.error('Failed to load activity logs');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <div className="animate-pulse space-y-4">
            <div className={`h-6 w-40 rounded ${theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-200'}`} />
            <div className={`h-10 w-full rounded ${theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-200'}`} />
            {[...Array(5)].map((_, i) => (
              <div key={i} className={`h-16 w-full rounded ${theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-200'}`} />
            ))}
          </div>
        </Card>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      transition={{ duration: 0.2, ease: 'easeInOut' }}
      className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8"
    >
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <DataTable
          columns={activityLogColumns}
          data={logs}
          mobileCardRender={ActivityLogMobileCard}
          headerActions={
            <div className="flex flex-col sm:flex-row gap-2 w-full sm:flex-1">
              <Input
                type="text"
                placeholder="Search by name or email..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className={`h-10 flex-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white placeholder:text-gray-500' : ''}`}
              />

              <Select value={filterAction} onValueChange={setFilterAction}>
                <SelectTrigger className={`h-10 w-full sm:w-[180px] ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
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
                <SelectTrigger className={`h-10 w-full sm:w-[180px] ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
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
          }
        />
      </Card>
    </motion.div>
  );
}
