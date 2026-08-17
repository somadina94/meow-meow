/**
 * StatementTab — Bank-style transaction statement for dashboard.
 * Columns: S.No, Date, Type, Description, Start Time, End Time, Duration, Rate, Debit, Credit, Balance
 * Export: PDF, Excel, Word
 */
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Filter, Wallet, RefreshCw, Download, FileText, FileSpreadsheet } from 'lucide-react';
import { getStatement, getMenBalance, getWomenBalance, type StatementRow } from '@/services/ledger-wallet.service';
import { format } from 'date-fns';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';
import { cn } from '@/lib/utils';

interface StatementTabProps {
  userId: string;
  gender?: 'male' | 'female';
}

// Session-style transaction types written by canonical billing RPCs (men debits + women credits)
const SESSION_TYPES = [
  // Canonical names written by bill_session_minute (transaction_type)
  'session_charge', 'session_earning',
  // session_type column values (when used as transaction_type by older rows)
  'chat', 'audio_call', 'video_call', 'group_call', 'private_group_call',
  // Legacy explicit aliases
  'chat_charge', 'audio_call_charge', 'video_call_charge', 'group_call_charge', 'private_group_call_charge',
  'chat_earning', 'audio_call_earning', 'video_call_earning', 'group_call_earning', 'private_group_call_earning',
];

// Anything that increases the wallet (credit side of unified ledger)
const CREDIT_TYPES = [
  'credit', 'recharge', 'refund',
  'session_earning',
  'chat_earning', 'audio_call_earning', 'video_call_earning',
  'group_call_earning', 'private_group_call_earning',
  'gift_received', 'gift_earning', 'tip_earning', 'tip_received',
];

const SESSION_KIND_LABEL: Record<string, string> = {
  chat: 'Chat',
  audio_call: 'Audio Call',
  video_call: 'Video Call',
  group_call: 'Group Call',
  private_group_call: 'Group Call',
};

const getTypeLabel = (row: StatementRow) => {
  const t = row.transaction_type;
  // Prefer the session category (chat / audio / video / group) for session rows
  if ((t === 'session_charge' || t === 'session_earning') && row.session_type) {
    const base = SESSION_KIND_LABEL[row.session_type] ?? row.session_type;
    return t === 'session_earning' ? `${base} Earning` : base;
  }
  const labels: Record<string, string> = {
    recharge: 'Wallet Recharge', credit: 'Credit', refund: 'Refund',
    chat: 'Chat', audio_call: 'Audio Call', video_call: 'Video Call',
    group_call: 'Group Call', private_group_call: 'Group Call',
    chat_charge: 'Chat', audio_call_charge: 'Audio Call', video_call_charge: 'Video Call',
    group_call_charge: 'Group Call', private_group_call_charge: 'Group Call',
    debit: 'Debit', withdrawal: 'Withdrawal', withdrawal_fee: 'Withdrawal Fee', payout: 'Payout',
    gift: 'Gift Sent', gift_charge: 'Gift Sent', gift_debit: 'Gift Sent',
    gift_received: 'Gift Received', gift_earning: 'Gift Received', gift_credit: 'Gift Received',
    tip: 'Tip Sent', tip_charge: 'Tip Sent', tip_earning: 'Tip Received', tip_received: 'Tip Received',
    chat_earning: 'Chat Earning', audio_call_earning: 'Audio Earning',
    video_call_earning: 'Video Earning', group_call_earning: 'Group Earning',
    private_group_call_earning: 'Group Earning',
    earning: 'Earning',
  };
  return labels[t] || t?.replace(/_/g, ' ');
};

const isCredit = (type: string) => CREDIT_TYPES.includes(type);
// A row represents a billed session minute when it has duration + rate metadata
const isSession = (row: StatementRow) =>
  SESSION_TYPES.includes(row.transaction_type) ||
  (row.duration_seconds != null && row.rate_per_minute != null);

const getTypeWithRate = (row: StatementRow): string => {
  const label = getTypeLabel(row);
  if (isSession(row) && row.rate_per_minute != null) {
    return `${label} — ₹${row.rate_per_minute.toFixed(2)}/min`;
  }
  return label;
};

const getDurationDisplay = (row: StatementRow): string => {
  if (!isSession(row)) return '—';
  if (row.duration_seconds == null) return '—';
  const totalSecs = Math.round(row.duration_seconds);
  const m = Math.floor(totalSecs / 60);
  const s = totalSecs % 60;
  return `${m} min : ${s.toString().padStart(2, '0')} sec`;
};

const getStartTime = (row: StatementRow): string => {
  if (!isSession(row) || row.duration_seconds == null) return '—';
  const endDate = new Date(row.created_at);
  const startDate = new Date(endDate.getTime() - row.duration_seconds * 1000);
  return format(startDate, 'HH:mm:ss');
};

const getEndTime = (row: StatementRow): string => {
  if (!isSession(row) || row.duration_seconds == null) return '—';
  return format(new Date(row.created_at), 'HH:mm:ss');
};

const getRateDisplay = (row: StatementRow): string => {
  if (!isSession(row) || row.rate_per_minute == null) return '—';
  return `₹${row.rate_per_minute.toFixed(2)}/min`;
};

const computeSummary = (rows: StatementRow[], walletBalance: number) => {
  const totalDebit = rows.reduce((s, r) => s + (r.debit || 0), 0);
  const totalCredit = rows.reduce((s, r) => s + (r.credit || 0), 0);
  // Use actual wallet balance as closing balance to match what user sees
  const closingBalance = walletBalance;
  const openingBalance = closingBalance - totalCredit + totalDebit;
  return { openingBalance, closingBalance, totalDebit, totalCredit };
};

const buildTableRows = (rows: StatementRow[]) =>
  rows.map((row, i) => ({
    sno: i + 1,
    date: format(new Date(row.created_at), 'dd MMM yyyy HH:mm'),
    type: getTypeWithRate(row),
    description: row.description || '—',
    startTime: getStartTime(row),
    endTime: getEndTime(row),
    duration: getDurationDisplay(row),
    rate: getRateDisplay(row),
    debit: row.debit ? row.debit.toFixed(2) : '—',
    credit: row.credit ? row.credit.toFixed(2) : '—',
    balance: row.running_balance?.toFixed(2) ?? '—',
  }));

const STATIC_HEADERS_PREFIX = ['#', 'Date & Time (IST)', 'Type', 'Description', 'Start Time', 'End Time', 'Duration', 'Rate'];

const toDateInputValue = (date: Date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const StatementTab: React.FC<StatementTabProps> = ({ userId, gender = 'male' }) => {
  const isMale = gender === 'male';
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const DEBIT_LABEL = isMale ? 'TOTAL CHARGED' : 'TOTAL WITHDRAWN';
  const CREDIT_LABEL = isMale ? 'TOTAL RECHARGED' : 'TOTAL EARNED';
  const DEBIT_COL = isMale ? 'Debit (₹)' : 'Withdrawn (₹)';
  const CREDIT_COL = isMale ? 'Credit (₹)' : 'Earned (₹)';
  const TITLE = isMale ? '💰 Wallet Statement' : '💰 Earnings Statement';
  const HEADERS = [...STATIC_HEADERS_PREFIX, DEBIT_COL, CREDIT_COL, 'Balance (₹)'];
  const [statement, setStatement] = useState<StatementRow[]>([]);
  const [walletBalance, setWalletBalance] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [dateRange, setDateRange] = useState({
    from: toDateInputValue(monthStart),
    to: toDateInputValue(now),
  });

  const loadStatement = useCallback(async () => {
    if (!userId) return;
    setIsLoading(true);
    setErrorMessage(null);
    try {
      const [data, balance] = await Promise.all([
        getStatement(userId, dateRange.from, dateRange.to),
        isMale
          ? getMenBalance(userId)
          : getWomenBalance(userId).then(w => w.balance),
      ]);
      setStatement(data);
      setWalletBalance(balance);
    } catch (error) {
      setStatement([]);
      setErrorMessage(error instanceof Error ? error.message : 'Statement unavailable');
    }
    setIsLoading(false);
  }, [userId, dateRange.from, dateRange.to, isMale]);

  useEffect(() => {
    loadStatement();
  }, [loadStatement]);

  // Real-time: auto-refresh when wallet_transactions change for this user
  // (wallet_transactions is the canonical source of truth — see ledger unification)
  useEffect(() => {
    if (!userId) return;
    const channel = supabase
      .channel(`statement-realtime-${userId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'wallet_transactions',
        filter: `user_id=eq.${userId}`,
      }, () => { loadStatement(); })
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'wallets',
        filter: `user_id=eq.${userId}`,
      }, () => { loadStatement(); })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [userId, loadStatement]);

  const summary = computeSummary(statement, walletBalance);
  const tableRows = buildTableRows(statement);

  // ─── PDF Export ───
  const exportPDF = () => {
    if (!statement.length) return;
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });

    doc.setFontSize(18);
    doc.text(isMale ? 'Wallet Statement' : 'Earnings Statement', 14, 16);
    doc.setFontSize(10);
    doc.text(`${dateRange.from} to ${dateRange.to}  •  Currency: INR  •  Timestamps in IST (UTC+5:30)`, 14, 23);

    const summaryY = 30;
    doc.setFontSize(9);
    const cols = [
      { label: 'OPENING BALANCE', value: `₹${summary.openingBalance.toFixed(2)}` },
      { label: DEBIT_LABEL, value: `₹${summary.totalDebit.toFixed(2)}` },
      { label: CREDIT_LABEL, value: `₹${summary.totalCredit.toFixed(2)}` },
      { label: 'CLOSING BALANCE', value: `₹${summary.closingBalance.toFixed(2)}` },
    ];
    const colW = 60;
    cols.forEach((c, i) => {
      const x = 14 + i * colW;
      doc.setFont('helvetica', 'normal');
      doc.text(c.label, x, summaryY);
      doc.setFont('helvetica', 'bold');
      doc.text(c.value, x, summaryY + 5);
    });

    const rows = tableRows.map(r => [
      String(r.sno), r.date, r.type, r.description, r.startTime, r.endTime, r.duration, r.rate, r.debit, r.credit, r.balance,
    ]);

    autoTable(doc, {
      startY: summaryY + 12,
      head: [HEADERS],
      body: rows,
      styles: { fontSize: 7, cellPadding: 1.5 },
      headStyles: { fillColor: [99, 102, 241], fontSize: 7 },
      columnStyles: { 8: { halign: 'right' }, 9: { halign: 'right' }, 10: { halign: 'right' } },
    });

    doc.save(`wallet-statement-${dateRange.from}-to-${dateRange.to}.pdf`);
  };

  // ─── Excel Export ───
  const exportExcel = () => {
    if (!statement.length) return;
    const wsData = [
      [isMale ? 'Wallet Statement' : 'Earnings Statement'],
      [`Period: ${dateRange.from} to ${dateRange.to}`, '', 'Currency: INR', '', 'Timestamps in IST (UTC+5:30)'],
      [],
      ['OPENING BALANCE', `₹${summary.openingBalance.toFixed(2)}`, '', DEBIT_LABEL, `₹${summary.totalDebit.toFixed(2)}`, '', CREDIT_LABEL, `₹${summary.totalCredit.toFixed(2)}`, '', 'CLOSING BALANCE', `₹${summary.closingBalance.toFixed(2)}`],
      [],
      HEADERS,
      ...tableRows.map(r => [r.sno, r.date, r.type, r.description, r.startTime, r.endTime, r.duration, r.rate, r.debit, r.credit, r.balance]),
    ];
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    ws['!cols'] = [{ wch: 4 }, { wch: 20 }, { wch: 28 }, { wch: 36 }, { wch: 10 }, { wch: 10 }, { wch: 10 }, { wch: 14 }, { wch: 10 }, { wch: 10 }, { wch: 12 }];
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Statement');
    XLSX.writeFile(wb, `wallet-statement-${dateRange.from}-to-${dateRange.to}.xlsx`);
  };

  // ─── Word/HTML Export ───
  const exportWord = () => {
    if (!statement.length) return;
    const rows = tableRows.map(r =>
      `<tr><td>${r.sno}</td><td>${r.date}</td><td>${r.type}</td><td>${r.description}</td><td>${r.startTime}</td><td>${r.endTime}</td><td>${r.duration}</td><td>${r.rate}</td><td style="text-align:right">${r.debit}</td><td style="text-align:right">${r.credit}</td><td style="text-align:right">${r.balance}</td></tr>`
    ).join('');

    const html = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><style>
body{font-family:Arial,sans-serif;font-size:11pt}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #ccc;padding:4px 6px;font-size:9pt}
th{background:#6366F1;color:#fff;font-weight:bold}
h1{font-size:18pt;margin-bottom:4pt}
</style></head><body>
<h1>${isMale ? 'Wallet Statement' : 'Earnings Statement'}</h1>
<p>${dateRange.from} to ${dateRange.to} • Currency: INR • Timestamps in IST (UTC+5:30)</p>
<table><tr>
<td style="background:#f3f4f6;padding:8px"><small>OPENING BALANCE</small><br><b>₹${summary.openingBalance.toFixed(2)}</b></td>
<td style="background:#f3f4f6;padding:8px"><small>${DEBIT_LABEL}</small><br><b>₹${summary.totalDebit.toFixed(2)}</b></td>
<td style="background:#f3f4f6;padding:8px"><small>${CREDIT_LABEL}</small><br><b>₹${summary.totalCredit.toFixed(2)}</b></td>
<td style="background:#f3f4f6;padding:8px"><small>CLOSING BALANCE</small><br><b>₹${summary.closingBalance.toFixed(2)}</b></td>
</tr></table>
<br>
<table><thead><tr>${HEADERS.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows}</tbody></table>
</body></html>`;

    const blob = new Blob(['\ufeff', html], { type: 'application/msword' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `wallet-statement-${dateRange.from}-to-${dateRange.to}.doc`;
    a.click();
    URL.revokeObjectURL(url);
  };

  if (isLoading) {
    return (
      <div className="flex-1 p-4 space-y-3">
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-16 w-full" />
        <Skeleton className="h-16 w-full" />
        <Skeleton className="h-16 w-full" />
      </div>
    );
  }

  return (
    <div className="flex-1 overflow-y-auto">
      {/* Header */}
      <div className="px-4 py-3 border-b border-border/30 flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold text-foreground">{TITLE}</h2>
          <p className="text-xs text-muted-foreground">{statement.length} transactions • Currency: INR</p>
        </div>
        <div className="flex gap-1">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8" disabled={!statement.length} title="Export">
                <Download className="w-4 h-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={exportPDF}>
                <FileText className="w-4 h-4 mr-2" /> Export PDF
              </DropdownMenuItem>
              <DropdownMenuItem onClick={exportExcel}>
                <FileSpreadsheet className="w-4 h-4 mr-2" /> Export Excel
              </DropdownMenuItem>
              <DropdownMenuItem onClick={exportWord}>
                <FileText className="w-4 h-4 mr-2" /> Export Word
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <Button variant="ghost" size="icon" className="h-8 w-8" onClick={loadStatement}>
            <RefreshCw className="w-4 h-4" />
          </Button>
        </div>
      </div>

      {/* Date Filter */}
      <div className="px-4 py-2 flex gap-2 items-center border-b border-border/30">
        <Filter className="w-4 h-4 text-muted-foreground shrink-0" />
        <Input type="date" value={dateRange.from}
          onChange={e => setDateRange(p => ({ ...p, from: e.target.value }))}
          className="h-8 text-xs flex-1" />
        <span className="text-xs text-muted-foreground">to</span>
        <Input type="date" value={dateRange.to}
          onChange={e => setDateRange(p => ({ ...p, to: e.target.value }))}
          className="h-8 text-xs flex-1" />
        <Button size="sm" variant="outline" className="h-8 text-xs" onClick={loadStatement}>Go</Button>
      </div>

      {/* Summary Cards */}
      {statement.length > 0 && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-0 border-b border-border/30">
          {[
            { label: 'OPENING BALANCE', value: summary.openingBalance },
            { label: DEBIT_LABEL, value: summary.totalDebit },
            { label: CREDIT_LABEL, value: summary.totalCredit },
            { label: 'CLOSING BALANCE', value: summary.closingBalance },
          ].map((item, i) => (
            <div key={i} className={cn('text-center py-3', i < 3 && 'border-r border-border/30')}>
              <p className="text-[9px] text-muted-foreground font-medium tracking-wider">{item.label}</p>
              <p className="text-sm font-bold text-foreground">₹{item.value.toFixed(2)}</p>
            </div>
          ))}
        </div>
      )}

      {/* Transaction Table */}
      <div className="overflow-x-auto">
        {errorMessage ? (
          <div className="text-center py-16 px-4">
            <Wallet className="w-12 h-12 text-muted-foreground/20 mx-auto mb-3" />
            <p className="text-destructive text-sm font-medium">Statement unavailable</p>
            <p className="text-muted-foreground text-xs mt-1">{errorMessage}</p>
          </div>
        ) : statement.length === 0 ? (
          <div className="text-center py-16">
            <Wallet className="w-12 h-12 text-muted-foreground/20 mx-auto mb-3" />
            <p className="text-muted-foreground text-sm">No transactions found</p>
          </div>
        ) : (
          <table className="w-full text-xs">
            <thead>
              <tr className="bg-muted/50 border-b border-border/30">
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground w-8">#</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Date & Time</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Type</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Description</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Start</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">End</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Duration</th>
                <th className="px-2 py-2 text-left font-semibold text-muted-foreground">Rate</th>
                <th className="px-2 py-2 text-right font-semibold text-muted-foreground">{DEBIT_COL}</th>
                <th className="px-2 py-2 text-right font-semibold text-muted-foreground">{CREDIT_COL}</th>
                <th className="px-2 py-2 text-right font-semibold text-muted-foreground">Balance (₹)</th>
              </tr>
            </thead>
            <tbody>
              {statement.map((row, index) => (
                <tr key={row.id} className="border-b border-border/20 hover:bg-muted/30">
                  <td className="px-2 py-2 text-muted-foreground">{index + 1}</td>
                  <td className="px-2 py-2 whitespace-nowrap text-foreground">
                    {format(new Date(row.created_at), 'dd MMM yyyy HH:mm')}
                  </td>
                  <td className="px-2 py-2 whitespace-nowrap text-foreground font-medium">
                    {getTypeWithRate(row)}
                  </td>
                  <td className="px-2 py-2 text-muted-foreground max-w-[200px] truncate">
                    {row.description || '—'}
                  </td>
                  <td className="px-2 py-2 text-muted-foreground">{getStartTime(row)}</td>
                  <td className="px-2 py-2 text-muted-foreground">{getEndTime(row)}</td>
                  <td className="px-2 py-2 text-foreground italic">{getDurationDisplay(row)}</td>
                  <td className="px-2 py-2 text-primary font-medium">{getRateDisplay(row)}</td>
                  <td className="px-2 py-2 text-right text-destructive font-medium">
                    {row.debit ? row.debit.toFixed(2) : '—'}
                  </td>
                  <td className="px-2 py-2 text-right text-primary font-medium">
                    {row.credit ? row.credit.toFixed(2) : '—'}
                  </td>
                  <td className="px-2 py-2 text-right font-semibold text-foreground">
                    {row.running_balance?.toFixed(2) ?? '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <div className="h-20" />
    </div>
  );
};

export default StatementTab;
