import { useState, useEffect } from 'react';
import { ColumnDef } from '@tanstack/react-table';
import { api } from '../lib/api';
import { useAuth } from '../lib/auth';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import { Copy, Check, Link as LinkIcon, User, Mail, Calendar as CalendarIcon, AlertCircle } from 'lucide-react';
import { format } from 'date-fns';
import { motion } from 'framer-motion';
import { DataTable } from '../components/data-table';
import { DataTableColumnHeader } from '../components/data-table/data-table-column-header';
import { Badge } from '../components/ui/badge';

interface Invitation {
  id: string;
  token: string;
  email?: string;
  expiresAt: string;
  usedAt?: string;
  isActive: boolean;
  createdAt: string;
  createdBy?: {
    id: string;
    name: string;
    email: string;
  };
}

export default function Invitations() {
  const { theme } = useTheme();
  const { user } = useAuth();

  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [filteredInvitations, setFilteredInvitations] = useState<Invitation[]>([]);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [guestEmail, setGuestEmail] = useState('');
  const [filterView, setFilterView] = useState<'mine' | 'all' | 'recent'>('mine');
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize] = useState(15);

  useEffect(() => {
    loadInvitations();
  }, [page]);

  useEffect(() => {
    filterInvitations();
  }, [invitations, filterView, user]);

  useEffect(() => {
    setPage(1);
  }, [filterView]);

  const loadInvitations = async () => {
    try {
      const params = new URLSearchParams();
      params.append('limit', pageSize.toString());
      params.append('offset', ((page - 1) * pageSize).toString());

      const response = await api.get(`/api/invitations?${params.toString()}`);
      setInvitations(response.data.invitations);
      setTotal(response.data.total);
    } catch (error) {
      toast.error('Failed to load invitations');
    } finally {
      setLoading(false);
    }
  };

  const filterInvitations = () => {
    let filtered = [...invitations];

    if (filterView === 'mine') {
      filtered = filtered.filter(inv => inv.createdBy?.id === user?.id);
    } else if (filterView === 'recent') {
      filtered = filtered.slice(0, 10);
    }

    // Sort by most recent
    filtered.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    setFilteredInvitations(filtered);
  };

  const generateInvitation = async () => {
    setGenerating(true);
    try {
      const response = await api.post('/api/invitations', {
        email: guestEmail || undefined,
      });

      const invitationLink = `${window.location.origin}/book/${response.data.token}`;

      // Copy to clipboard
      await navigator.clipboard.writeText(invitationLink);
      toast.success('Invitation link generated and copied to clipboard!');

      setGuestEmail('');
      loadInvitations();
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to generate invitation');
    } finally {
      setGenerating(false);
    }
  };

  const copyToClipboard = async (token: string) => {
    const link = `${window.location.origin}/book/${token}`;
    await navigator.clipboard.writeText(link);
    setCopiedId(token);
    toast.success('Link copied to clipboard!');
    setTimeout(() => setCopiedId(null), 2000);
  };

  // Column definitions
  const invitationColumns: ColumnDef<Invitation>[] = [
    {
      accessorKey: 'token',
      header: 'Link',
      cell: ({ row }) => {
        const token = row.getValue('token') as string;
        const link = `${window.location.origin}/book/${token}`;
        return (
          <div className="font-mono text-sm max-w-xs truncate">
            {link}
          </div>
        );
      },
    },
    {
      accessorKey: 'email',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Email" />
      ),
      cell: ({ row }) => {
        const email = row.getValue('email') as string | undefined;
        if (!email) return <span className="text-gray-400 text-sm">No email</span>;
        return (
          <div className="flex items-center gap-2">
            <Mail className="h-4 w-4 text-gray-500" />
            <span className="text-sm">{email}</span>
          </div>
        );
      },
    },
    {
      accessorKey: 'createdBy',
      header: 'Created By',
      cell: ({ row }) => {
        const createdBy = row.getValue('createdBy') as Invitation['createdBy'];
        if (!createdBy) return <span className="text-gray-400 text-sm">System</span>;
        return (
          <div className="flex items-center gap-2">
            <User className="h-4 w-4 text-gray-500" />
            <div>
              <div className="text-sm font-medium">{createdBy.name}</div>
              <div className="text-xs text-gray-500">{createdBy.email}</div>
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: 'createdAt',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Created" />
      ),
      cell: ({ row }) => {
        return (
          <span className="text-sm">
            {format(new Date(row.getValue('createdAt')), 'MMM d, yyyy')}
          </span>
        );
      },
    },
    {
      accessorKey: 'expiresAt',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Expires" />
      ),
      cell: ({ row }) => {
        const expiresAt = new Date(row.getValue('expiresAt'));
        const isExpired = expiresAt < new Date();
        return (
          <div className="flex items-center gap-2">
            {isExpired && <AlertCircle className="h-4 w-4 text-red-500" />}
            <span className={`text-sm ${isExpired ? 'text-red-500' : ''}`}>
              {format(expiresAt, 'MMM d, yyyy')}
            </span>
          </div>
        );
      },
    },
    {
      accessorKey: 'usedAt',
      header: 'Status',
      cell: ({ row }) => {
        const usedAt = row.getValue('usedAt') as string | undefined;
        const isActive = row.original.isActive;
        const expiresAt = new Date(row.original.expiresAt);
        const isExpired = expiresAt < new Date();

        if (usedAt) {
          return (
            <Badge variant="outline" className="text-green-600 border-green-600">
              Used
            </Badge>
          );
        }
        if (isExpired) {
          return (
            <Badge variant="outline" className="text-red-500 border-red-500">
              Expired
            </Badge>
          );
        }
        if (isActive) {
          return (
            <Badge variant="outline" className="text-blue-500 border-blue-500">
              Active
            </Badge>
          );
        }
        return (
          <Badge variant="outline" className="text-gray-500 border-gray-500">
            Inactive
          </Badge>
        );
      },
    },
    {
      id: 'actions',
      cell: ({ row }) => {
        const invitation = row.original;
        const isDisabled = !invitation.isActive || !!invitation.usedAt;

        return (
          <Button
            onClick={() => copyToClipboard(invitation.token)}
            variant="outline"
            size="sm"
            disabled={isDisabled}
            className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}
          >
            {copiedId === invitation.token ? (
              <>
                <Check className="h-4 w-4 mr-2" />
                Copied!
              </>
            ) : (
              <>
                <Copy className="h-4 w-4 mr-2" />
                Copy
              </>
            )}
          </Button>
        );
      },
    },
  ];

  // Mobile card render
  const InvitationMobileCard = (invitation: Invitation) => {
    const isExpired = new Date(invitation.expiresAt) < new Date();
    const link = `${window.location.origin}/book/${invitation.token}`;

    return (
      <div className="space-y-3">
        <div className="flex items-start justify-between gap-2">
          <p className="font-mono text-xs break-all flex-1">{link}</p>
          <Badge variant="outline" className={
            invitation.usedAt ? 'text-green-600 border-green-600' :
            isExpired ? 'text-red-500 border-red-500' :
            invitation.isActive ? 'text-blue-500 border-blue-500' :
            'text-gray-500 border-gray-500'
          }>
            {invitation.usedAt ? 'Used' : isExpired ? 'Expired' : invitation.isActive ? 'Active' : 'Inactive'}
          </Badge>
        </div>

        <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs">
          {invitation.email && (
            <div className="flex items-center gap-1 text-gray-500">
              <Mail className="h-3 w-3" />
              <span>{invitation.email}</span>
            </div>
          )}
          {invitation.createdBy && (
            <div className="flex items-center gap-1 text-gray-500">
              <User className="h-3 w-3" />
              <span>{invitation.createdBy.name}</span>
            </div>
          )}
          <div className="flex items-center gap-1 text-gray-500">
            <CalendarIcon className="h-3 w-3" />
            <span>Created: {format(new Date(invitation.createdAt), 'MMM d')}</span>
          </div>
          <div className={`flex items-center gap-1 ${isExpired ? 'text-red-500' : 'text-gray-500'}`}>
            {isExpired && <AlertCircle className="h-3 w-3" />}
            <span>Expires: {format(new Date(invitation.expiresAt), 'MMM d')}</span>
          </div>
        </div>

        <Button
          onClick={() => copyToClipboard(invitation.token)}
          variant="outline"
          size="sm"
          disabled={!invitation.isActive || !!invitation.usedAt}
          className={`w-full ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
        >
          {copiedId === invitation.token ? (
            <>
              <Check className="h-4 w-4 mr-2" />
              Copied!
            </>
          ) : (
            <>
              <Copy className="h-4 w-4 mr-2" />
              Copy Link
            </>
          )}
        </Button>
      </div>
    );
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      transition={{ duration: 0.2, ease: 'easeInOut' }}
      className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8"
    >
      {/* Generate New Invitation Card */}
      <Card className={`p-6 mb-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <h3 className={`text-lg font-semibold mb-4 ${theme === 'dark' ? 'text-white' : ''}`}>
          Generate New Invitation
        </h3>

        <div className="space-y-3">
          <Label htmlFor="email" className={`text-sm ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
            Guest Email (Optional)
          </Label>
          <div className="flex flex-col sm:flex-row gap-3">
            <Input
              id="email"
              type="email"
              placeholder="guest@company.com"
              value={guestEmail}
              onChange={(e) => setGuestEmail(e.target.value)}
              className={`flex-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            />
            <Button
              onClick={generateInvitation}
              disabled={generating}
              className={`w-full sm:w-auto ${theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}`}
            >
              <LinkIcon className="h-4 w-4 mr-2" />
              {generating ? 'Generating...' : 'Generate Link'}
            </Button>
          </div>
          <p className={`text-xs ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`}>
            Email is optional. The link can be shared with anyone.
          </p>
        </div>
      </Card>

      {/* Invitations List Card */}
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <DataTable
          columns={invitationColumns}
          data={filteredInvitations}
          mobileCardRender={InvitationMobileCard}
          headerActions={
            <div className="flex flex-col sm:flex-row gap-2 w-full sm:flex-1">
              <Input
                type="text"
                placeholder="Search by email or token..."
                className={`h-10 flex-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white placeholder:text-gray-500' : ''}`}
              />

              <Select value={filterView} onValueChange={(val: 'mine' | 'all' | 'recent') => setFilterView(val)}>
                <SelectTrigger className={`h-10 w-full sm:w-[200px] ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                  <SelectItem value="mine">My Invitations</SelectItem>
                  <SelectItem value="all">All Invitations</SelectItem>
                  <SelectItem value="recent">Recent (10)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          }
        />
      </Card>
    </motion.div>
  );
}
