import { useState, useEffect } from 'react';
import { api } from '../lib/api';
import { Card } from '../components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Skeleton } from '../components/ui/skeleton';
import { useTheme } from '../hooks/use-theme';
import { Calendar as CalendarIcon, TrendingUp, Users, Building2, Target } from 'lucide-react';
import { toast } from 'sonner';
import { ResponsiveBar } from '@nivo/bar';
import { ResponsiveLine } from '@nivo/line';
import { ResponsivePie } from '@nivo/pie';
import { motion } from 'framer-motion';
import { ColumnDef } from '@tanstack/react-table';
import { DataTable } from '../components/data-table';
import { DataTableColumnHeader } from '../components/data-table/data-table-column-header';
import PushNotificationSettings from '../components/PushNotificationSettings';

interface DashboardStats {
  totalBookings: number;
  thisMonthBookings: number;
  thisYearBookings: number;
  pendingBookings: number;
  uniqueCompanies: number;
  totalAttendeesThisYear: number;
}

interface TopCompany {
  company: string;
  visits: number;
}

const topCompaniesColumns: ColumnDef<TopCompany>[] = [
  {
    id: 'rank',
    header: 'Rank',
    cell: ({ row }) => {
      return <span className="text-gray-600">#{row.index + 1}</span>;
    },
  },
  {
    accessorKey: 'company',
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title="Company" />
    ),
    cell: ({ row }) => {
      return <div className="font-medium">{row.getValue('company')}</div>;
    },
  },
  {
    accessorKey: 'visits',
    header: ({ column }) => (
      <div className="text-right">
        <DataTableColumnHeader column={column} title="Visits" />
      </div>
    ),
    cell: ({ row }) => {
      return <div className="text-right font-medium">{row.getValue('visits')}</div>;
    },
  },
];

const TopCompanyMobileCard = (company: TopCompany & { index: number }) => {
  return (
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-gray-500">#{company.index + 1}</span>
        <span className="font-medium">{company.company}</span>
      </div>
      <span className="font-semibold">{company.visits} visits</span>
    </div>
  );
};

export default function Dashboard() {
  const { theme } = useTheme();

  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [monthlyData, setMonthlyData] = useState([]);
  const [sectorData, setSectorData] = useState([]);
  const [interestData, setInterestData] = useState([]);
  const [trendsData, setTrendsData] = useState([]);
  const [topCompanies, setTopCompanies] = useState([]);
  const [loading, setLoading] = useState(true);

  // Interactive controls state
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [sectorYear, setSectorYear] = useState(new Date().getFullYear());
  const [interestYear, setInterestYear] = useState(new Date().getFullYear());
  const [trendsPeriod, setTrendsPeriod] = useState(6);

  useEffect(() => {
    loadDashboardData();
  }, [selectedYear, sectorYear, interestYear, trendsPeriod]);

  const loadDashboardData = async () => {
    try {
      const [
        statsRes,
        monthlyRes,
        sectorRes,
        interestRes,
        trendsRes,
        companiesRes,
      ] = await Promise.all([
        api.get('/api/analytics/dashboard'),
        api.get(`/api/analytics/bookings-by-month/${selectedYear}`),
        api.get(`/api/analytics/bookings-by-sector?year=${sectorYear}`),
        api.get(`/api/analytics/bookings-by-interest?year=${interestYear}`),
        api.get(`/api/analytics/trends?months=${trendsPeriod}`),
        api.get('/api/analytics/top-companies?limit=10'),
      ]);

      setStats(statsRes.data);
      setMonthlyData(monthlyRes.data);
      setSectorData(sectorRes.data);
      setInterestData(interestRes.data);
      setTrendsData(trendsRes.data);
      setTopCompanies(companiesRes.data);
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
      toast.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const DashboardSkeleton = () => (
    <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Stats Cards Skeleton */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
        {[...Array(6)].map((_, i) => (
          <Card key={i} className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <Skeleton className={`h-4 w-16 mb-2 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
              <Skeleton className={`h-8 w-12 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            </div>
          </Card>
        ))}
      </div>

      {/* Charts Row 1 Skeleton */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {[...Array(2)].map((_, i) => (
          <Card key={i} className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex items-center justify-between mb-4">
              <Skeleton className={`h-6 w-40 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
              <Skeleton className={`h-10 w-32 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            </div>
            <Skeleton className={`h-[300px] w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
          </Card>
        ))}
      </div>

      {/* Charts Row 2 Skeleton */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {[...Array(2)].map((_, i) => (
          <Card key={i} className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <Skeleton className={`h-6 w-48 mb-4 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            <Skeleton className={`h-[300px] w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
          </Card>
        ))}
      </div>

      {/* Top Companies Table Skeleton */}
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <Skeleton className={`h-6 w-40 mb-4 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex items-center justify-between">
              <Skeleton className={`h-5 w-12 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
              <Skeleton className={`h-5 w-48 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
              <Skeleton className={`h-5 w-12 ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            </div>
          ))}
        </div>
      </Card>
    </div>
  );

  if (loading || !stats) {
    return <DashboardSkeleton />;
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      transition={{ duration: 0.2, ease: 'easeInOut' }}
      className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-4"
    >
        {/* Stats Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-8">
          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <CalendarIcon className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  Total
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.totalBookings}
              </p>
            </div>
          </Card>

          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <TrendingUp className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  This Month
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.thisMonthBookings}
              </p>
            </div>
          </Card>

          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <Building2 className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  Companies
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.uniqueCompanies}
              </p>
            </div>
          </Card>

          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <Users className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  Attendees
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.totalAttendeesThisYear}
              </p>
            </div>
          </Card>

          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <Target className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  Pending
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.pendingBookings}
              </p>
            </div>
          </Card>

          <Card className={`p-4 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex flex-col">
              <div className="flex items-center gap-2 mb-2">
                <CalendarIcon className={`h-4 w-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
                <p className={`text-xs font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  This Year
                </p>
              </div>
              <p className={`text-2xl font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                {stats.thisYearBookings}
              </p>
            </div>
          </Card>
        </div>

        {/* Charts Row 1 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          {/* Monthly Bookings Bar Chart */}
          <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex items-center justify-between mb-4">
              <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Bookings by Month
              </h3>
              <Select value={selectedYear.toString()} onValueChange={(val) => setSelectedYear(parseInt(val))}>
                <SelectTrigger className={`w-[120px] ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                  {Array.from({ length: 11 }, (_, i) => 2024 + i).map((year) => (
                    <SelectItem key={year} value={year.toString()}>
                      {year}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div style={{ height: '300px' }}>
              <ResponsiveBar
                data={monthlyData}
                keys={['threeHours', 'sixHours']}
                indexBy="month"
                margin={{ top: 20, right: 20, bottom: 50, left: 50 }}
                padding={0.3}
                valueScale={{ type: 'linear' }}
                indexScale={{ type: 'band', round: true }}
                colors={theme === 'dark' ? ['#818cf8', '#a78bfa'] : ['#93c5fd', '#c4b5fd']}
                borderColor={{ from: 'color', modifiers: [['darker', 1.6]] }}
                axisTop={null}
                axisRight={null}
                axisBottom={{
                  tickSize: 5,
                  tickPadding: 5,
                  tickRotation: -45,
                  legend: '',
                  legendPosition: 'middle',
                  legendOffset: 32,
                }}
                axisLeft={{
                  tickSize: 5,
                  tickPadding: 5,
                  tickRotation: 0,
                  legend: '',
                  legendPosition: 'middle',
                  legendOffset: -40,
                }}
                labelSkipWidth={12}
                labelSkipHeight={12}
                labelTextColor={{ from: 'color', modifiers: [['darker', 3]] }}
                legends={[]}
                theme={{
                  axis: {
                    ticks: {
                      text: {
                        fill: theme === 'dark' ? '#a3a3a3' : '#525252',
                        fontSize: 11
                      }
                    },
                    legend: {
                      text: {
                        fill: theme === 'dark' ? '#a3a3a3' : '#525252'
                      }
                    }
                  },
                  legends: {
                    text: {
                      fill: theme === 'dark' ? '#a3a3a3' : '#525252'
                    }
                  },
                  tooltip: {
                    container: {
                      background: theme === 'dark' ? '#18181b' : '#ffffff',
                      color: theme === 'dark' ? '#ffffff' : '#000000',
                    }
                  }
                }}
              />
            </div>
            <div className="flex justify-center gap-4 mt-2">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded" style={{ backgroundColor: theme === 'dark' ? '#6366f1' : '#2563eb' }}></div>
                <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>3h visits</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded" style={{ backgroundColor: theme === 'dark' ? '#8b5cf6' : '#7c3aed' }}></div>
                <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>6h visits</span>
              </div>
            </div>
          </Card>

          {/* Trends Line Chart */}
          <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex items-center justify-between mb-4">
              <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Trends
              </h3>
              <Select value={trendsPeriod.toString()} onValueChange={(val) => setTrendsPeriod(parseInt(val))}>
                <SelectTrigger className={`w-[140px] ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                  <SelectItem value="3">3 Months</SelectItem>
                  <SelectItem value="6">6 Months</SelectItem>
                  <SelectItem value="12">12 Months</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div style={{ height: '300px' }}>
              <ResponsiveLine
                data={[
                  {
                    id: 'bookings',
                    data: trendsData.map((d: any) => ({ x: d.month, y: d.bookings }))
                  },
                  {
                    id: 'attendees',
                    data: trendsData.map((d: any) => ({ x: d.month, y: d.attendees }))
                  }
                ]}
                margin={{ top: 20, right: 20, bottom: 50, left: 50 }}
                xScale={{ type: 'point' }}
                yScale={{ type: 'linear', min: 'auto', max: 'auto', stacked: false, reverse: false }}
                curve="monotoneX"
                axisTop={null}
                axisRight={null}
                axisBottom={{
                  tickSize: 5,
                  tickPadding: 5,
                  tickRotation: -45,
                  legend: '',
                  legendOffset: 36,
                  legendPosition: 'middle'
                }}
                axisLeft={{
                  tickSize: 5,
                  tickPadding: 5,
                  tickRotation: 0,
                  legend: '',
                  legendOffset: -40,
                  legendPosition: 'middle'
                }}
                colors={theme === 'dark' ? ['#34d399', '#22d3ee'] : ['#86efac', '#7dd3fc']}
                pointSize={8}
                pointColor={{ theme: 'background' }}
                pointBorderWidth={2}
                pointBorderColor={{ from: 'serieColor' }}
                pointLabelYOffset={-12}
                useMesh={true}
                legends={[]}
                theme={{
                  axis: {
                    ticks: {
                      text: {
                        fill: theme === 'dark' ? '#a3a3a3' : '#525252',
                        fontSize: 11
                      }
                    },
                    legend: {
                      text: {
                        fill: theme === 'dark' ? '#a3a3a3' : '#525252'
                      }
                    }
                  },
                  legends: {
                    text: {
                      fill: theme === 'dark' ? '#a3a3a3' : '#525252'
                    }
                  },
                  tooltip: {
                    container: {
                      background: theme === 'dark' ? '#18181b' : '#ffffff',
                      color: theme === 'dark' ? '#ffffff' : '#000000',
                    }
                  }
                }}
              />
            </div>
            <div className="flex justify-center gap-4 mt-2">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: theme === 'dark' ? '#10b981' : '#059669' }}></div>
                <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>Bookings</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: theme === 'dark' ? '#06b6d4' : '#0891b2' }}></div>
                <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>Attendees</span>
              </div>
            </div>
          </Card>
        </div>

        {/* Charts Row 2 */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          {/* Sector Pie Chart */}
          <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex items-center justify-between mb-4">
              <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Bookings by Sector
              </h3>
              <Select value={sectorYear.toString()} onValueChange={(val) => setSectorYear(parseInt(val))}>
                <SelectTrigger className={`w-[120px] ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                  {Array.from({ length: 11 }, (_, i) => 2024 + i).map((year) => (
                    <SelectItem key={year} value={year.toString()}>
                      {year}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div style={{ height: '300px' }}>
              <ResponsivePie
                data={sectorData.map((d: any) => ({ id: d.sector, label: d.sector, value: d.count }))}
                margin={{ top: 20, right: 20, bottom: 20, left: 20 }}
                innerRadius={0.6}
                padAngle={1}
                cornerRadius={3}
                activeOuterRadiusOffset={8}
                borderWidth={1}
                borderColor={{ from: 'color', modifiers: [['darker', 0.2]] }}
                colors={theme === 'dark'
                  ? ['#f87171', '#fb923c', '#fbbf24', '#a3e635', '#34d399', '#22d3ee', '#a78bfa']
                  : ['#fecaca', '#fed7aa', '#fef3c7', '#d9f99d', '#a7f3d0', '#a5f3fc', '#ddd6fe']
                }
                enableArcLinkLabels={false}
                arcLabelsSkipAngle={15}
                arcLabel={(d) => `${d.value}`}
                arcLabelsTextColor={{ from: 'color', modifiers: [['darker', 3]] }}
                theme={{
                  labels: {
                    text: {
                      fontSize: 12,
                      fontWeight: 600
                    }
                  },
                  tooltip: {
                    container: {
                      background: theme === 'dark' ? '#18181b' : '#ffffff',
                      color: theme === 'dark' ? '#ffffff' : '#000000',
                    }
                  }
                }}
              />
            </div>
            <div className="flex flex-wrap justify-center gap-3 mt-2">
              {sectorData.map((d: any, index: number) => {
                const colors = theme === 'dark'
                  ? ['#f87171', '#fb923c', '#fbbf24', '#a3e635', '#34d399', '#22d3ee', '#a78bfa']
                  : ['#fecaca', '#fed7aa', '#fef3c7', '#d9f99d', '#a7f3d0', '#a5f3fc', '#ddd6fe'];
                return (
                  <div key={d.sector} className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded" style={{ backgroundColor: colors[index % colors.length] }}></div>
                    <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                      {d.sector}
                    </span>
                  </div>
                );
              })}
            </div>
          </Card>

          {/* Interest Area Pie Chart */}
          <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
            <div className="flex items-center justify-between mb-4">
              <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Bookings by Interest Area
              </h3>
              <Select value={interestYear.toString()} onValueChange={(val) => setInterestYear(parseInt(val))}>
                <SelectTrigger className={`w-[120px] ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                  {Array.from({ length: 11 }, (_, i) => 2024 + i).map((year) => (
                    <SelectItem key={year} value={year.toString()}>
                      {year}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div style={{ height: '300px' }}>
              <ResponsivePie
                data={interestData.map((d: any) => ({ id: d.area, label: d.area, value: d.count }))}
                margin={{ top: 20, right: 20, bottom: 20, left: 20 }}
                innerRadius={0.6}
                padAngle={1}
                cornerRadius={3}
                activeOuterRadiusOffset={8}
                borderWidth={1}
                borderColor={{ from: 'color', modifiers: [['darker', 0.2]] }}
                colors={theme === 'dark'
                  ? ['#f87171', '#fb923c', '#fbbf24', '#a3e635', '#34d399', '#22d3ee', '#a78bfa']
                  : ['#fecaca', '#fed7aa', '#fef3c7', '#d9f99d', '#a7f3d0', '#a5f3fc', '#ddd6fe']
                }
                enableArcLinkLabels={false}
                arcLabelsSkipAngle={15}
                arcLabel={(d) => `${d.value}`}
                arcLabelsTextColor={{ from: 'color', modifiers: [['darker', 3]] }}
                theme={{
                  labels: {
                    text: {
                      fontSize: 12,
                      fontWeight: 600
                    }
                  },
                  tooltip: {
                    container: {
                      background: theme === 'dark' ? '#18181b' : '#ffffff',
                      color: theme === 'dark' ? '#ffffff' : '#000000',
                    }
                  }
                }}
              />
            </div>
            <div className="flex flex-wrap justify-center gap-3 mt-2">
              {interestData.map((d: any, index: number) => {
                const colors = theme === 'dark'
                  ? ['#f87171', '#fb923c', '#fbbf24', '#a3e635', '#34d399', '#22d3ee', '#a78bfa']
                  : ['#fecaca', '#fed7aa', '#fef3c7', '#d9f99d', '#a7f3d0', '#a5f3fc', '#ddd6fe'];
                return (
                  <div key={d.area} className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded" style={{ backgroundColor: colors[index % colors.length] }}></div>
                    <span className={`text-xs ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                      {d.area}
                    </span>
                  </div>
                );
              })}
            </div>
          </Card>
        </div>

        {/* Push Notification Settings */}
        <div className="mb-6">
          <PushNotificationSettings theme={theme} />
        </div>

        {/* Top Companies Table */}
        <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <DataTable
            columns={topCompaniesColumns}
            data={topCompanies.map((company: any, index: number) => ({
              ...company,
              index,
            }))}
            searchKey="company"
            searchPlaceholder="Search companies..."
            mobileCardRender={(row: any) => <TopCompanyMobileCard {...row} />}
            headerActions={
              <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Top Companies
              </h3>
            }
          />
        </Card>
      </motion.div>
  );
}
