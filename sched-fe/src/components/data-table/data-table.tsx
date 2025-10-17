import * as React from 'react';
import {
  ColumnDef,
  ColumnFiltersState,
  SortingState,
  VisibilityState,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
  RowSelectionState,
} from '@tanstack/react-table';
import { useTheme } from '@/hooks/use-theme';
import { useIsMobile } from '@/hooks/use-mobile';
import { Input } from '@/components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Card } from '@/components/ui/card';
import { DataTablePagination } from './data-table-pagination';
import { DataTableViewOptions } from './data-table-view-options';

interface DataTableProps<TData, TValue> {
  columns: ColumnDef<TData, TValue>[];
  data: TData[];
  searchKey?: string;
  searchPlaceholder?: string;
  enableRowSelection?: boolean;
  onRowClick?: (row: TData) => void;
  mobileCardRender?: (row: TData) => React.ReactNode;
  headerActions?: React.ReactNode;
}

export function DataTable<TData, TValue>({
  columns,
  data,
  searchKey,
  searchPlaceholder = 'Search...',
  enableRowSelection = false,
  onRowClick,
  mobileCardRender,
  headerActions,
}: DataTableProps<TData, TValue>) {
  const { theme } = useTheme();
  const isMobile = useIsMobile();

  const [sorting, setSorting] = React.useState<SortingState>([]);
  const [columnFilters, setColumnFilters] = React.useState<ColumnFiltersState>([]);
  const [columnVisibility, setColumnVisibility] = React.useState<VisibilityState>({});
  const [rowSelection, setRowSelection] = React.useState<RowSelectionState>({});

  const table = useReactTable({
    data,
    columns,
    initialState: {
      pagination: {
        pageSize: 5,
      },
    },
    state: {
      sorting,
      columnFilters,
      columnVisibility,
      rowSelection,
    },
    enableRowSelection,
    onRowSelectionChange: setRowSelection,
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onColumnVisibilityChange: setColumnVisibility,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
  });

  // Mobile Card View
  if (isMobile && mobileCardRender) {
    return (
      <div className="space-y-4">
        {/* Search Bar */}
        {searchKey && (
          <div className="flex items-center gap-2">
            <Input
              placeholder={searchPlaceholder}
              value={(table.getColumn(searchKey)?.getFilterValue() as string) ?? ''}
              onChange={(event) =>
                table.getColumn(searchKey)?.setFilterValue(event.target.value)
              }
              className={`h-10 ${
                theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''
              }`}
            />
          </div>
        )}

        {/* Cards */}
        <div className="space-y-3">
          {table.getRowModel().rows?.length ? (
            table.getRowModel().rows.map((row) => (
              <Card
                key={row.id}
                onClick={() => onRowClick?.(row.original)}
                className={`p-4 transition-all ${
                  onRowClick ? 'cursor-pointer hover:shadow-md' : ''
                } ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}
              >
                {mobileCardRender(row.original)}
              </Card>
            ))
          ) : (
            <Card className={`p-8 text-center ${
              theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''
            }`}>
              <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
                No results found.
              </p>
            </Card>
          )}
        </div>

        {/* Mobile Pagination */}
        <DataTablePagination table={table} />
      </div>
    );
  }

  // Desktop Table View
  return (
    <div className="space-y-4">
      {/* Toolbar */}
      <div className="flex flex-col sm:flex-row items-center gap-2 items-center justify-between py-6">
        {headerActions && (
          <div className="w-full sm:w-auto">
            {headerActions}
          </div>
        )}
        {searchKey && (
          <Input
            placeholder={searchPlaceholder}
            value={(table.getColumn(searchKey)?.getFilterValue() as string) ?? ''}
            onChange={(event) =>
              table.getColumn(searchKey)?.setFilterValue(event.target.value)
            }
            className={`h-10 w-full sm:flex-1 sm:max-w-sm ${
              theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''
            }`}
          />
        )}
        <DataTableViewOptions table={table} />
      </div>

      {/* Table */}
      <div className={`overflow-hidden rounded-md border ${
        theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'
      }`}>
        <Table>
          <TableHeader className={theme === 'dark' ? 'bg-zinc-900' : 'bg-gray-50'}>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id} className={theme === 'dark' ? 'border-zinc-800' : ''}>
                {headerGroup.headers.map((header) => (
                  <TableHead
                    key={header.id}
                    className={theme === 'dark' ? 'text-gray-400' : 'text-gray-700'}
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  data-state={row.getIsSelected() && 'selected'}
                  onClick={() => onRowClick?.(row.original)}
                  className={`${
                    onRowClick ? 'cursor-pointer' : ''
                  } ${
                    theme === 'dark'
                      ? 'border-zinc-800 hover:bg-zinc-900'
                      : 'hover:bg-gray-50'
                  }`}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell
                      key={cell.id}
                      className={theme === 'dark' ? 'text-gray-300' : ''}
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className={`h-24 text-center ${
                    theme === 'dark' ? 'text-gray-400' : 'text-gray-600'
                  }`}
                >
                  No results found.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
      <DataTablePagination table={table} />
    </div>
  );
}
