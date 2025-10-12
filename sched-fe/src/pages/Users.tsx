import { useState, useEffect } from 'react';
import { ColumnDef } from '@tanstack/react-table';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '../components/ui/dialog';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '../components/ui/alert-dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import { UserPlus, Trash2, KeyRound, Shuffle } from 'lucide-react';
import { motion } from 'framer-motion';
import { DataTable } from '../components/data-table';
import { DataTableColumnHeader } from '../components/data-table/data-table-column-header';
import { Badge } from '../components/ui/badge';
import { format } from 'date-fns';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'ADMIN' | 'MANAGER';
  isActive: boolean;
  createdAt: string;
}

export default function Users() {
  const { theme } = useTheme();
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showResetPasswordDialog, setShowResetPasswordDialog] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [creating, setCreating] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [resettingPassword, setResettingPassword] = useState(false);

  // Create user form state
  const [newUser, setNewUser] = useState({
    name: '',
    email: '',
    password: '',
    role: 'MANAGER' as 'ADMIN' | 'MANAGER',
  });

  // Reset password form state
  const [newPassword, setNewPassword] = useState('');

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await api.get('/api/auth/users');
      setUsers(response.data);
    } catch (error) {
      toast.error('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateUser = async () => {
    if (!newUser.name || !newUser.email || !newUser.password) {
      toast.error('Please fill in all required fields');
      return;
    }

    if (newUser.password.length < 8) {
      toast.error('Password must be at least 8 characters');
      return;
    }

    setCreating(true);
    try {
      await api.post('/api/auth/users', newUser);
      toast.success('User created successfully');
      setShowCreateDialog(false);
      setNewUser({ name: '', email: '', password: '', role: 'MANAGER' });
      loadUsers();
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to create user');
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteUser = async () => {
    if (!selectedUser) return;

    setDeleting(true);
    try {
      await api.delete(`/api/auth/users/${selectedUser.id}`);
      toast.success('User deleted successfully');
      setShowDeleteDialog(false);
      setSelectedUser(null);
      loadUsers();
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to delete user');
    } finally {
      setDeleting(false);
    }
  };

  const handleResetPassword = async () => {
    if (!selectedUser) return;

    if (newPassword.length < 8) {
      toast.error('Password must be at least 8 characters');
      return;
    }

    setResettingPassword(true);
    try {
      await api.patch(`/api/auth/users/${selectedUser.id}/password`, {
        password: newPassword,
      });
      toast.success('Password reset successfully');
      setShowResetPasswordDialog(false);
      setSelectedUser(null);
      setNewPassword('');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to reset password');
    } finally {
      setResettingPassword(false);
    }
  };

  const openDeleteDialog = (user: User) => {
    setSelectedUser(user);
    setShowDeleteDialog(true);
  };

  const openResetPasswordDialog = (user: User) => {
    setSelectedUser(user);
    setNewPassword('');
    setShowResetPasswordDialog(true);
  };

  const generateRandomPassword = () => {
    const length = 16;
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';

    // Ensure at least one of each type
    password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[Math.floor(Math.random() * 26)];
    password += 'abcdefghijklmnopqrstuvwxyz'[Math.floor(Math.random() * 26)];
    password += '0123456789'[Math.floor(Math.random() * 10)];
    password += '!@#$%^&*'[Math.floor(Math.random() * 8)];

    // Fill the rest
    for (let i = password.length; i < length; i++) {
      password += charset[Math.floor(Math.random() * charset.length)];
    }

    // Shuffle the password
    password = password.split('').sort(() => Math.random() - 0.5).join('');

    setNewPassword(password);
    toast.success('Random password generated');
  };

  // Only ADMIN can access this page, but double-check
  if (currentUser?.role !== 'ADMIN') {
    return (
      <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            You do not have permission to access this page.
          </p>
        </Card>
      </div>
    );
  }

  // Column definitions
  const userColumns: ColumnDef<User>[] = [
    {
      accessorKey: 'name',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Name" />
      ),
      cell: ({ row }) => {
        return (
          <div>
            <div className="font-medium">{row.getValue('name')}</div>
            <div className="text-sm text-gray-500">{row.original.email}</div>
          </div>
        );
      },
    },
    {
      accessorKey: 'role',
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title="Role" />
      ),
      cell: ({ row }) => {
        const role = row.getValue('role') as string;
        return (
          <Badge variant="outline" className={
            role === 'ADMIN'
              ? theme === 'dark' ? 'text-white border-white' : 'text-black border-black'
              : theme === 'dark' ? 'text-gray-300 border-gray-300' : 'text-gray-600 border-gray-600'
          }>
            {role}
          </Badge>
        );
      },
    },
    {
      accessorKey: 'isActive',
      header: 'Status',
      cell: ({ row }) => {
        const isActive = row.getValue('isActive') as boolean;
        return (
          <Badge variant="outline" className={isActive ? 'text-green-600 border-green-600' : 'text-red-600 border-red-600'}>
            {isActive ? 'Active' : 'Inactive'}
          </Badge>
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
      id: 'actions',
      cell: ({ row }) => {
        const user = row.original;
        return (
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => openResetPasswordDialog(user)}
              className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}
            >
              <KeyRound className="h-4 w-4 mr-1" />
              Password
            </Button>
            {user.id !== currentUser?.id && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => openDeleteDialog(user)}
                className={
                  theme === 'dark'
                    ? 'border-red-800 bg-red-950 text-red-400 hover:bg-red-900 hover:text-red-300'
                    : 'border-red-600 text-red-600 hover:bg-red-50'
                }
              >
                <Trash2 className="h-4 w-4 mr-1" />
                Delete
              </Button>
            )}
          </div>
        );
      },
    },
  ];

  // Mobile card render
  const UserMobileCard = (user: User) => {
    return (
      <div className="space-y-3">
        <div>
          <p className={`font-semibold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            {user.name}
          </p>
          <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
            {user.email}
          </p>
        </div>

        <div className="flex gap-2">
          <Badge variant="outline" className={
            user.role === 'ADMIN'
              ? theme === 'dark' ? 'text-white border-white' : 'text-black border-black'
              : theme === 'dark' ? 'text-gray-300 border-gray-300' : 'text-gray-600 border-gray-600'
          }>
            {user.role}
          </Badge>
          <Badge variant="outline" className={user.isActive ? 'text-green-600 border-green-600' : 'text-red-600 border-red-600'}>
            {user.isActive ? 'Active' : 'Inactive'}
          </Badge>
        </div>

        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => openResetPasswordDialog(user)}
            className={`flex-1 ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
          >
            <KeyRound className="h-4 w-4 mr-1" />
            Password
          </Button>
          {user.id !== currentUser?.id && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => openDeleteDialog(user)}
              className={`flex-1 ${
                theme === 'dark'
                  ? 'border-red-800 bg-red-950 text-red-400 hover:bg-red-900 hover:text-red-300'
                  : 'border-red-600 text-red-600 hover:bg-red-50'
              }`}
            >
              <Trash2 className="h-4 w-4 mr-1" />
              Delete
            </Button>
          )}
        </div>
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
      {/* Users List */}
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <DataTable
          columns={userColumns}
          data={users}
          searchKey="name"
          searchPlaceholder="Search by name or email..."
          mobileCardRender={UserMobileCard}
          headerActions={
            <Button
              onClick={() => setShowCreateDialog(true)}
              className={`w-full sm:w-auto ${theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}`}
            >
              <UserPlus className="h-4 w-4 mr-2" />
              Create User
            </Button>
          }
        />
      </Card>

      {/* Create User Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
          <DialogHeader>
            <DialogTitle className={theme === 'dark' ? 'text-white' : ''}>Create New User</DialogTitle>
            <DialogDescription className={theme === 'dark' ? 'text-gray-400' : ''}>
              Create a new user account. The user will be able to log in with the provided credentials.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div>
              <Label htmlFor="name" className={theme === 'dark' ? 'text-gray-300' : ''}>
                Name
              </Label>
              <Input
                id="name"
                type="text"
                placeholder="John Doe"
                value={newUser.name}
                onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
                className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
              />
            </div>

            <div>
              <Label htmlFor="email" className={theme === 'dark' ? 'text-gray-300' : ''}>
                Email
              </Label>
              <Input
                id="email"
                type="email"
                placeholder="john@tcs.com"
                value={newUser.email}
                onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
              />
            </div>

            <div>
              <Label htmlFor="password" className={theme === 'dark' ? 'text-gray-300' : ''}>
                Password
              </Label>
              <Input
                id="password"
                type="password"
                placeholder="Minimum 8 characters"
                value={newUser.password}
                onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
                className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
              />
            </div>

            <div>
              <Label htmlFor="role" className={theme === 'dark' ? 'text-gray-300' : ''}>
                Role
              </Label>
              <Select
                value={newUser.role}
                onValueChange={(value: 'ADMIN' | 'MANAGER') => setNewUser({ ...newUser, role: value })}
              >
                <SelectTrigger className={`mt-1 w-full ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
                  <SelectItem value="MANAGER" className={theme === 'dark' ? 'text-white' : ''}>Manager</SelectItem>
                  <SelectItem value="ADMIN" className={theme === 'dark' ? 'text-white' : ''}>Admin</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setShowCreateDialog(false)}
              className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}
            >
              Cancel
            </Button>
            <Button
              onClick={handleCreateUser}
              disabled={creating}
              className={theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}
            >
              {creating ? 'Creating...' : 'Create User'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete User Dialog */}
      <AlertDialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <AlertDialogContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
          <AlertDialogHeader>
            <AlertDialogTitle className={theme === 'dark' ? 'text-white' : ''}>
              Delete User
            </AlertDialogTitle>
            <AlertDialogDescription className={theme === 'dark' ? 'text-gray-400' : ''}>
              Are you sure you want to delete {selectedUser?.name}? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}>
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteUser}
              className={
                theme === 'dark'
                  ? 'bg-red-950 text-red-400 hover:bg-red-900 border border-red-800'
                  : 'bg-red-600 text-white hover:bg-red-700'
              }
            >
              {deleting ? 'Deleting...' : 'Delete User'}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Reset Password Dialog */}
      <Dialog open={showResetPasswordDialog} onOpenChange={setShowResetPasswordDialog}>
        <DialogContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
          <DialogHeader>
            <DialogTitle className={theme === 'dark' ? 'text-white' : ''}>Reset Password</DialogTitle>
            <DialogDescription className={theme === 'dark' ? 'text-gray-400' : ''}>
              Reset password for {selectedUser?.name}. The user will need to use this new password to log in.
            </DialogDescription>
          </DialogHeader>

          <div>
            <div className="flex items-center justify-between mb-1">
              <Label htmlFor="newPassword" className={theme === 'dark' ? 'text-gray-300' : ''}>
                New Password
              </Label>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={generateRandomPassword}
                className={`h-8 px-2 ${theme === 'dark' ? 'text-gray-400 hover:text-white hover:bg-zinc-800' : 'text-gray-600 hover:text-black'}`}
              >
                <Shuffle className="h-4 w-4 mr-1" />
                Generate
              </Button>
            </div>
            <Input
              id="newPassword"
              type="text"
              placeholder="Minimum 8 characters"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            />
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setShowResetPasswordDialog(false)}
              className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}
            >
              Cancel
            </Button>
            <Button
              onClick={handleResetPassword}
              disabled={resettingPassword}
              className={theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}
            >
              {resettingPassword ? 'Resetting...' : 'Reset Password'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </motion.div>
  );
}
