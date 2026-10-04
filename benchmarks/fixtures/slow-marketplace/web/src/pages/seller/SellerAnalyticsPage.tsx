import { useQuery } from '@tanstack/react-query';
import * as echarts from 'echarts';
import { useEffect, useRef } from 'react';
import { useParams } from 'react-router';
import * as XLSX from 'xlsx';
import { api } from '../../lib/api';

interface DailyRow {
  day: string;
  orders: number;
  grossCents: number;
  refundsCents: number;
}

// Seller analytics: 90-day revenue chart and a spreadsheet export.
export default function SellerAnalyticsPage() {
  const { storeId } = useParams();
  const chartRef = useRef<HTMLDivElement>(null);
  const { data: rows = [] } = useQuery({
    queryKey: ['analytics', storeId],
    queryFn: () => api<DailyRow[]>(`/api/stores/${storeId}/analytics/daily?days=90`),
  });

  useEffect(() => {
    if (!chartRef.current) return;
    const chart = echarts.init(chartRef.current);
    chart.setOption({
      xAxis: { type: 'category', data: rows.map((r) => r.day) },
      yAxis: { type: 'value' },
      series: [
        { name: 'Gross', type: 'line', data: rows.map((r) => r.grossCents / 100) },
        { name: 'Refunds', type: 'bar', data: rows.map((r) => r.refundsCents / 100) },
      ],
    });
    return () => chart.dispose();
  }, [rows]);

  const exportXlsx = () => {
    const sheet = XLSX.utils.json_to_sheet(rows.map((r) => ({ ...r, gross: r.grossCents / 100, refunds: r.refundsCents / 100 })));
    const book = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(book, sheet, 'Daily');
    XLSX.writeFile(book, `analytics-${storeId}.xlsx`);
  };

  return (
    <main>
      <h1>Analytics</h1>
      <div ref={chartRef} style={{ width: '100%', height: 360 }} />
      <button onClick={exportXlsx}>Download .xlsx</button>
    </main>
  );
}
