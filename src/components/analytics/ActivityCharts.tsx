import React from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  AreaChart,
  Area,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts';
import type {
  WeeklyDataPoint,
  PacePoint,
  TypeDistributionPoint,
  FeelingPoint,
} from '../../gamification/analytics';

// Custom dark tooltip
const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-xl border border-zinc-700 bg-surface-900/95 p-2.5 shadow-xl text-xs backdrop-blur-md">
        <p className="font-bold text-white mb-1">{label}</p>
        {payload.map((entry: any, index: number) => (
          <p key={`item-${index}`} className="flex items-center gap-1.5" style={{ color: entry.color || entry.fill }}>
            <span className="w-2 h-2 rounded-full" style={{ backgroundColor: entry.color || entry.fill }} />
            <span className="text-zinc-300 font-medium">{entry.name}:</span>
            <span className="font-bold text-white">{entry.value}</span>
          </p>
        ))}
      </div>
    );
  }
  return null;
};

// 1. Minutos activos (por día o semana)
export const MinutesBarChart: React.FC<{
  data: Array<{ label: string; workoutsMin: number; runsMin: number; restMin: number }>;
}> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-52">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <XAxis
            dataKey="label"
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={{ stroke: '#27272a' }} />
          <Tooltip content={<CustomTooltip />} />
          <Bar
            dataKey="workoutsMin"
            name="Entrenamientos (min)"
            stackId="a"
            fill="#22c55e"
            radius={[0, 0, 0, 0]}
          />
          <Bar dataKey="runsMin" name="Corridas (min)" stackId="a" fill="#06b6d4" radius={[0, 0, 0, 0]} />
          <Bar dataKey="restMin" name="Descanso (min)" stackId="a" fill="#a855f7" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
};

// 2. Km Corridos por semana
export const KmBarChart: React.FC<{ data: WeeklyDataPoint[] }> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-48">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <XAxis
            dataKey="label"
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={{ stroke: '#27272a' }} />
          <Tooltip content={<CustomTooltip />} />
          <Bar dataKey="km" name="Distancia (km)" fill="#06b6d4" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
};

// 3. Calorías Estimadas por semana
export const CaloriesAreaChart: React.FC<{ data: WeeklyDataPoint[] }> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-48">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id="calGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.8} />
              <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
            </linearGradient>
          </defs>
          <XAxis
            dataKey="label"
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={{ stroke: '#27272a' }} />
          <Tooltip content={<CustomTooltip />} />
          <Area
            type="monotone"
            dataKey="calories"
            name="Calorías (kcal)"
            stroke="#f59e0b"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#calGrad)"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};

// 4. Ritmo Medio (min/km)
export const PaceLineChart: React.FC<{ data: PacePoint[] }> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-48">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <XAxis
            dataKey="label"
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <YAxis
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
            domain={['dataMin - 1', 'dataMax + 1']}
          />
          <Tooltip content={<CustomTooltip />} />
          <Line
            type="monotone"
            dataKey="paceMinKm"
            name="Ritmo (min/km)"
            stroke="#38bdf8"
            strokeWidth={2.5}
            dot={{ r: 4, fill: '#38bdf8' }}
            activeDot={{ r: 6 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};

// 5. Distribución de Actividades (Dona)
export const TypePieChart: React.FC<{ data: TypeDistributionPoint[] }> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-52 flex items-center justify-center">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={45}
            outerRadius={70}
            paddingAngle={4}
            dataKey="value"
          >
            {data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} stroke="#18181b" strokeWidth={2} />
            ))}
          </Pie>
          <Tooltip content={<CustomTooltip />} />
          <Legend
            verticalAlign="bottom"
            height={36}
            formatter={(value) => <span className="text-[11px] text-zinc-300 font-semibold">{value}</span>}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
};

// 6. Tendencia de Sensación (1 a 5)
export const FeelingLineChart: React.FC<{ data: FeelingPoint[] }> = ({ data }) => {
  if (data.length === 0) return null;

  return (
    <div className="w-full h-44">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
          <XAxis
            dataKey="label"
            stroke="#71717a"
            fontSize={10}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <YAxis
            stroke="#71717a"
            fontSize={10}
            domain={[1, 5]}
            ticks={[1, 2, 3, 4, 5]}
            tickLine={false}
            axisLine={{ stroke: '#27272a' }}
          />
          <Tooltip content={<CustomTooltip />} />
          <Line
            type="monotone"
            dataKey="feeling"
            name="Sensación (1-5)"
            stroke="#e879f9"
            strokeWidth={2}
            dot={{ r: 3.5, fill: '#e879f9' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};
