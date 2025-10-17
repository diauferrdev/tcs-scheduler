# DataTable Component

Sistema de tabelas reutilizável e responsivo usando TanStack Table com suporte automático para desktop (tabela) e mobile (cards).

## 📦 Instalação

```bash
bun add @tanstack/react-table
```

## 🚀 Quick Start

```tsx
import { DataTable } from '@/components/data-table';
import { ColumnDef } from '@tanstack/react-table';

// 1. Defina seu tipo
interface User {
  id: string;
  name: string;
  email: string;
}

// 2. Defina as colunas
const columns: ColumnDef<User>[] = [
  {
    accessorKey: 'name',
    header: 'Name',
  },
  {
    accessorKey: 'email',
    header: 'Email',
  },
];

// 3. Use o componente
function MyPage() {
  const data = [/* seus dados */];

  return (
    <DataTable
      columns={columns}
      data={data}
      searchKey="name"
      searchPlaceholder="Search users..."
    />
  );
}
```

## 📱 Mobile vs Desktop

### Desktop
- Tabela completa com todas as colunas
- Sorting em todas as colunas
- Column visibility toggle
- Paginação com controles first/last
- Search bar

### Mobile
- Cards responsivos customizáveis
- Search bar simplificada
- Paginação adaptada (prev/next)
- Click handlers

## 🎯 Props do DataTable

| Prop | Tipo | Default | Descrição |
|------|------|---------|-----------|
| `columns` | `ColumnDef<TData>[]` | **required** | Definição das colunas |
| `data` | `TData[]` | **required** | Dados da tabela |
| `searchKey` | `string` | `undefined` | Chave da coluna para busca |
| `searchPlaceholder` | `string` | `'Search...'` | Placeholder do input de busca |
| `enableRowSelection` | `boolean` | `false` | Habilita checkbox de seleção |
| `onRowClick` | `(row: TData) => void` | `undefined` | Handler ao clicar na row |
| `mobileCardRender` | `(row: TData) => ReactNode` | `undefined` | Render customizado para mobile |

## 📝 Exemplos

### Coluna com Sorting

```tsx
import { DataTableColumnHeader } from '@/components/data-table';

{
  accessorKey: 'name',
  header: ({ column }) => (
    <DataTableColumnHeader column={column} title="Name" />
  ),
}
```

### Coluna com Formatação

```tsx
{
  accessorKey: 'amount',
  header: 'Amount',
  cell: ({ row }) => {
    const amount = parseFloat(row.getValue('amount'));
    const formatted = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount);
    return <div className="text-right font-medium">{formatted}</div>;
  },
}
```

### Coluna com Badge

```tsx
import { Badge } from '@/components/ui/badge';

{
  accessorKey: 'status',
  header: 'Status',
  cell: ({ row }) => {
    const status = row.getValue('status') as string;
    return (
      <Badge variant={status === 'active' ? 'default' : 'secondary'}>
        {status}
      </Badge>
    );
  },
}
```

### Coluna de Ações

```tsx
import { MoreHorizontal } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

{
  id: 'actions',
  cell: ({ row }) => {
    const item = row.original;

    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" className="h-8 w-8 p-0">
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => handleEdit(item)}>
            Edit
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleDelete(item)}>
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    );
  },
}
```

### Row Selection

```tsx
import { Checkbox } from '@/components/ui/checkbox';

// Coluna de seleção
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
}

// Usar com enableRowSelection
<DataTable
  columns={columns}
  data={data}
  enableRowSelection={true}
/>
```

### Mobile Card Render

```tsx
const MobileCard = (booking: Booking) => {
  return (
    <div className="space-y-2">
      <div className="flex items-start justify-between">
        <div>
          <h3 className="font-semibold">{booking.companyName}</h3>
          <p className="text-sm text-gray-500">{booking.contactEmail}</p>
        </div>
        <Badge>{booking.status}</Badge>
      </div>
      <div className="flex items-center justify-between text-sm text-gray-600">
        <span>{format(booking.date, 'MMM d, yyyy')}</span>
        <span>{booking.startTime}</span>
      </div>
    </div>
  );
};

<DataTable
  columns={columns}
  data={bookings}
  mobileCardRender={MobileCard}
/>
```

## 🎨 Customização com Theme

O componente já suporta dark mode automaticamente usando `useTheme()`:

```tsx
// Desktop table
<Table className={theme === 'dark' ? 'border-zinc-800' : ''}>
  {/* conteúdo */}
</Table>

// Mobile cards
<Card className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
  {/* conteúdo */}
</Card>
```

## 📦 Componentes Auxiliares

### DataTableColumnHeader
Header com sorting e hide column

```tsx
import { DataTableColumnHeader } from '@/components/data-table';

<DataTableColumnHeader column={column} title="Name" />
```

### DataTablePagination
Controles de paginação completos

```tsx
import { DataTablePagination } from '@/components/data-table';

<DataTablePagination table={table} />
```

### DataTableViewOptions
Toggle de visibilidade de colunas

```tsx
import { DataTableViewOptions } from '@/components/data-table';

<DataTableViewOptions table={table} />
```

## 🔧 API do TanStack Table

O componente expõe todas as funcionalidades do TanStack Table:

- **Sorting**: Click no header para ordenar
- **Filtering**: Use `searchKey` para busca global
- **Pagination**: Automático com controles
- **Row Selection**: `enableRowSelection={true}`
- **Column Visibility**: Toggle via dropdown
- **Column Ordering**: Programático via `columnVisibility`

## 📚 Exemplos Completos

Veja `example-usage.tsx` para um exemplo completo com:
- Checkbox selection
- Sorting columns
- Badge components
- Status indicators
- Action dropdowns
- Mobile card render
- Row click handlers

## 🎯 Casos de Uso

### 1. Lista de Usuários
```tsx
<DataTable
  columns={userColumns}
  data={users}
  searchKey="email"
  searchPlaceholder="Search by email..."
  enableRowSelection={true}
  mobileCardRender={UserMobileCard}
/>
```

### 2. Tabela de Bookings
```tsx
<DataTable
  columns={bookingColumns}
  data={bookings}
  searchKey="companyName"
  searchPlaceholder="Search companies..."
  onRowClick={(booking) => navigate(`/bookings/${booking.id}`)}
  mobileCardRender={BookingMobileCard}
/>
```

### 3. Activity Logs
```tsx
<DataTable
  columns={logColumns}
  data={logs}
  searchKey="description"
  searchPlaceholder="Search logs..."
  mobileCardRender={LogMobileCard}
/>
```

## 🚨 Troubleshooting

### Cards não aparecem no mobile
Certifique-se de passar `mobileCardRender`:
```tsx
<DataTable
  // ...
  mobileCardRender={(row) => <YourCardComponent {...row} />}
/>
```

### Sorting não funciona
Use `DataTableColumnHeader` no header:
```tsx
{
  accessorKey: 'name',
  header: ({ column }) => (
    <DataTableColumnHeader column={column} title="Name" />
  ),
}
```

### Search não funciona
Passe a `searchKey` correspondente à `accessorKey`:
```tsx
<DataTable
  columns={columns}
  data={data}
  searchKey="name" // deve corresponder a accessorKey
/>
```

## 📖 Documentação Adicional

- [TanStack Table Docs](https://tanstack.com/table/v8)
- [shadcn/ui Table](https://ui.shadcn.com/docs/components/table)
