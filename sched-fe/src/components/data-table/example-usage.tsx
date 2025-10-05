/**
 * EXEMPLO DE USO DO DATA TABLE COMPONENT
 *
 * Este arquivo demonstra como usar o componente DataTable reutilizável
 */

import { ColumnDef } from '@tanstack/react-table';
import { MoreHorizontal, Eye, Trash2 } from 'lucide-react';
import { DataTable } from './data-table';
import { DataTableColumnHeader } from './data-table-column-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Checkbox } from '@/components/ui/checkbox';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

// 1. DEFINA SEU TIPO DE DADOS
interface User {
  id: string;
  name: string;
  email: string;
  role: 'ADMIN' | 'MANAGER' | 'GUEST';
  status: 'active' | 'inactive';
  createdAt: string;
}

// 2. DEFINA AS COLUNAS
export const userColumns: ColumnDef<User>[] = [
  // Checkbox de seleção (opcional)
  {
    id: 'select',
    header: ({ table }) => (
      <Checkbox
        checked={
          table.getIsAllPageRowsSelected() ||
          (table.getIsSomePageRowsSelected() && 'indeterminate')
        }
        onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
        aria-label="Select all"
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onCheckedChange={(value) => row.toggleSelected(!!value)}
        aria-label="Select row"
      />
    ),
    enableSorting: false,
    enableHiding: false,
  },

  // Coluna com sorting
  {
    accessorKey: 'name',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Name" />
    ),
    cell: ({ row }) => {
      return <div className="font-medium">{row.getValue('name')}</div>;
    },
  },

  // Coluna com badge
  {
    accessorKey: 'role',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Role" />
    ),
    cell: ({ row }) => {
      const role = row.getValue('role') as string;
      return (
        <Badge variant={role === 'ADMIN' ? 'default' : 'secondary'}>
          {role}
        </Badge>
      );
    },
    filterFn: (row, id, value) => {
      return value.includes(row.getValue(id));
    },
  },

  // Coluna com status
  {
    accessorKey: 'status',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Status" />
    ),
    cell: ({ row }) => {
      const status = row.getValue('status') as string;
      return (
        <div className="flex items-center">
          <div
            className={`h-2 w-2 rounded-full mr-2 ${
              status === 'active' ? 'bg-green-500' : 'bg-gray-400'
            }`}
          />
          <span className="capitalize">{status}</span>
        </div>
      );
    },
  },

  // Coluna com formatação
  {
    accessorKey: 'createdAt',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Created" />
    ),
    cell: ({ row }) => {
      return new Date(row.getValue('createdAt')).toLocaleDateString();
    },
  },

  // Coluna de ações
  {
    id: 'actions',
    cell: ({ row }) => {
      const user = row.original;

      return (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" className="h-8 w-8 p-0">
              <span className="sr-only">Open menu</span>
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Actions</DropdownMenuLabel>
            <DropdownMenuItem onClick={() => console.log('View', user)}>
              <Eye className="mr-2 h-4 w-4" />
              View details
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              onClick={() => console.log('Delete', user)}
              className="text-red-600"
            >
              <Trash2 className="mr-2 h-4 w-4" />
              Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      );
    },
  },
];

// 3. DEFINA O RENDER DO CARD MOBILE (opcional)
const UserMobileCard = (user: User) => {
  return (
    <div className="space-y-2">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-semibold">{user.name}</h3>
          <p className="text-sm text-gray-500">{user.email}</p>
        </div>
        <Badge variant={user.role === 'ADMIN' ? 'default' : 'secondary'}>
          {user.role}
        </Badge>
      </div>
      <div className="flex items-center justify-between text-sm">
        <div className="flex items-center gap-2">
          <div
            className={`h-2 w-2 rounded-full ${
              user.status === 'active' ? 'bg-green-500' : 'bg-gray-400'
            }`}
          />
          <span className="capitalize text-gray-600">{user.status}</span>
        </div>
        <span className="text-gray-500">
          {new Date(user.createdAt).toLocaleDateString()}
        </span>
      </div>
    </div>
  );
};

// 4. USE O COMPONENTE
export function UserTableExample() {
  const users: User[] = [
    {
      id: '1',
      name: 'John Doe',
      email: 'john@example.com',
      role: 'ADMIN',
      status: 'active',
      createdAt: '2024-01-15',
    },
    {
      id: '2',
      name: 'Jane Smith',
      email: 'jane@example.com',
      role: 'MANAGER',
      status: 'active',
      createdAt: '2024-02-20',
    },
    // ... more data
  ];

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">Users</h1>

      <DataTable
        columns={userColumns}
        data={users}
        searchKey="name"
        searchPlaceholder="Search users..."
        enableRowSelection={true}
        onRowClick={(user) => console.log('Clicked:', user)}
        mobileCardRender={UserMobileCard}
      />
    </div>
  );
}

/**
 * RECURSOS DISPONÍVEIS:
 *
 * 1. DESKTOP:
 *    - Tabela completa com sorting
 *    - Column visibility toggle
 *    - Paginação com controles completos
 *    - Search bar
 *    - Row selection
 *
 * 2. MOBILE:
 *    - Cards responsivos
 *    - Search bar simplificada
 *    - Paginação adaptada
 *    - Click handlers
 *
 * 3. PROPS DO DataTable:
 *    - columns: ColumnDef[] - Definição das colunas
 *    - data: TData[] - Dados da tabela
 *    - searchKey?: string - Chave para busca (opcional)
 *    - searchPlaceholder?: string - Placeholder do search (opcional)
 *    - enableRowSelection?: boolean - Habilita seleção (default: false)
 *    - onRowClick?: (row) => void - Handler de click na row (opcional)
 *    - mobileCardRender?: (row) => ReactNode - Render customizado mobile (opcional)
 *
 * 4. COMPONENTES AUXILIARES:
 *    - DataTableColumnHeader - Header com sorting
 *    - DataTablePagination - Controles de paginação
 *    - DataTableViewOptions - Toggle de colunas
 */
