import { useState, useEffect } from 'react';
import { api } from '../lib/api';
import { useAuth } from '../lib/auth';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Skeleton } from '../components/ui/skeleton';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import { Copy, Check, Link as LinkIcon } from 'lucide-react';
import { format } from 'date-fns';
import { Pagination, PaginationContent, PaginationItem, PaginationPrevious, PaginationNext } from '../components/ui/pagination';
import { motion } from 'framer-motion';

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

  const copyToClipboard = async (token: string, id: string) => {
    const link = `${window.location.origin}/book/${token}`;
    await navigator.clipboard.writeText(link);
    setCopiedId(id);
    toast.success('Link copied to clipboard!');
    setTimeout(() => setCopiedId(null), 2000);
  };

  const InvitationsSkeleton = () => (
    <div className="space-y-3">
      {[...Array(5)].map((_, i) => (
        <div key={i} className={`p-4 rounded-lg border ${theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-gray-50 border-gray-200'}`}>
          <div className="space-y-3">
            <Skeleton className={`h-5 w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            <div className="flex flex-wrap gap-2">
              <Skeleton className={`h-4 w-24 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
              <Skeleton className={`h-4 w-32 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            </div>
            <Skeleton className={`h-9 w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
          </div>
        </div>
      ))}
    </div>
  );

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
      className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8"
    >
      {/* Generate New Invitation Card */}
      <Card className={`p-6 mb-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <h3 className={`text-lg font-semibold mb-4 ${theme === 'dark' ? 'text-white' : ''}`}>
          Generate New Invitation
        </h3>

        <div className="space-y-3">
          <div>
            <Label htmlFor="email" className={`text-sm ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
              Guest Email (Optional)
            </Label>
            <Input
              id="email"
              type="email"
              placeholder="guest@company.com"
              value={guestEmail}
              onChange={(e) => setGuestEmail(e.target.value)}
              className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            />
            <p className={`text-xs mt-1 ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`}>
              Email is optional. The link can be shared with anyone.
            </p>
          </div>

          <Button
            onClick={generateInvitation}
            disabled={generating}
            className={`w-full sm:w-auto ${theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}`}
          >
            <LinkIcon className="h-4 w-4 mr-2" />
            {generating ? 'Generating...' : 'Generate Link'}
          </Button>
        </div>
      </Card>

      {/* Invitations List Card */}
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4">
          <h3 className={`text-lg font-semibold ${theme === 'dark' ? 'text-white' : ''}`}>
            Invitations
          </h3>
          <Select value={filterView} onValueChange={(val: 'mine' | 'all' | 'recent') => setFilterView(val)}>
            <SelectTrigger className={`w-full sm:w-[180px] ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
              <SelectItem value="mine">My Invitations</SelectItem>
              <SelectItem value="all">All Invitations</SelectItem>
              <SelectItem value="recent">Recent (10)</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {loading ? (
          <InvitationsSkeleton />
        ) : filteredInvitations.length === 0 ? (
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            No invitations found.
          </p>
        ) : (
          <div className="space-y-3">
            {filteredInvitations.map((invitation, idx) => (
              <motion.div
                key={invitation.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.05, duration: 0.3 }}
                className={`p-4 rounded-lg border ${
                  theme === 'dark' ? 'bg-black border-zinc-800' : 'bg-gray-50 border-gray-200'
                }`}
              >
                <div className="space-y-3">
                  {/* Link */}
                  <div className="flex items-start gap-2">
                    <span className={`text-sm font-mono break-all ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                      {window.location.origin}/book/{invitation.token}
                    </span>
                  </div>

                  {/* Metadata */}
                  <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs">
                    {invitation.email && (
                      <span className={theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}>
                        Email: {invitation.email}
                      </span>
                    )}
                    {invitation.createdBy && (
                      <span className={theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}>
                        By: {invitation.createdBy.name}
                      </span>
                    )}
                    <span className={theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}>
                      Created: {format(new Date(invitation.createdAt), 'MMM d, yyyy')}
                    </span>
                    <span className={theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}>
                      Expires: {format(new Date(invitation.expiresAt), 'MMM d, yyyy')}
                    </span>
                    {invitation.usedAt && (
                      <span className={theme === 'dark' ? 'text-green-400' : 'text-green-600'}>
                        Used: {format(new Date(invitation.usedAt), 'MMM d, yyyy')}
                      </span>
                    )}
                  </div>

                  {/* Copy Button */}
                  <Button
                    onClick={() => copyToClipboard(invitation.token, invitation.id)}
                    variant="outline"
                    size="sm"
                    disabled={!invitation.isActive || !!invitation.usedAt}
                    className={`w-full sm:w-auto ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
                  >
                    {copiedId === invitation.id ? (
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
              </motion.div>
            ))}
          </div>
        )}

        {/* Pagination */}
        {!loading && filteredInvitations.length > 0 && (
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
