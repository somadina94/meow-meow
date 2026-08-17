/**
 * AdminPayoutStatements — Admin page for viewing/triggering payout snapshots.
 * Spec §7: KYC-based payout statement (10 columns from Bank KYC).
 */
import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import AdminNav from '@/components/AdminNav';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { useToast } from '@/hooks/use-toast';
import { Download, RefreshCw, Loader2, IndianRupee, Users, Calendar, FileText, FileSpreadsheet, Archive, ArchiveRestore } from 'lucide-react';
import { generatePayoutSnapshot, getPayoutSnapshots } from '@/services/ledger-wallet.service';
import { generatePayoutSnapshotNow } from '@/services/billing.service';
import { useDebounce } from '@/hooks/useDebounce';
import { format } from 'date-fns';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';

// A6: single source of truth for INR currency formatting (admin payouts).
// Two-decimal precision required by financial spec; uses Indian grouping.
const inrCurrency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});
const fmtINR = (n: number | string | null | undefined) =>
  inrCurrency.format(Number(n ?? 0) || 0);
// Plain numeric string with 2dp grouping — used inside ₹-prefixed export labels.
const fmtINRNumber = (n: number | string | null | undefined) =>
  new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(n ?? 0) || 0);

interface PayoutRecord {
  id: string;
  user_id: string;
  app_sno: number | null;
  beneficiary_purpose: string | null;
  account_holder_name: string | null;
  full_name: string;
  mobile_number: string | null;
  email_address: string | null;
  address: string | null;
  bank_account_number: string | null;
  ifsc_code: string | null;
  upi_vpa: string | null;
  wallet_balance_at_snapshot: number;
  payment_status: string;
  snapshot_type: string;
  ist_month: string;
  ist_year: number;
  snapshot_ist_date: string;
  created_at: string;
}

// Spec §7 — 10 columns sourced from Bank KYC + 2 verification columns
const PAYOUT_HEADERS = [
  'Beneficiary ID / S.No',
  'GESS ID',
  'User ID',
  'Beneficiary Purpose',
  'Name',
  'Phone Number',
  'Email ID',
  'Address',
  'Account Number',
  'IFSC Code',
  'UPI VPA',
  'Amount (₹)',
  'Total Login Time',
  'Total Billing Time',
];

// Format seconds as HH:MM:SS
const fmtHMS = (secs: number): string => {
  const s = Math.max(0, Math.floor(secs || 0));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(r)}`;
};

const AdminPayoutStatements = () => {
  const { toast } = useToast();
  const [records, setRecords] = useState<PayoutRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isGenerating, setIsGenerating] = useState(false);
  const [monthFilter, setMonthFilter] = useState(format(new Date(), 'yyyy-MM'));
  // user_id -> { login_seconds, billing_seconds } for the active month
  const [timeMap, setTimeMap] = useState<Record<string, { login: number; billing: number }>>({});
  // user_id -> GESS ID (e.g. GESS_F_001)
  const [codeMap, setCodeMap] = useState<Record<string, string>>({});
  const [searchQuery, setSearchQuery] = useState('');
  const debouncedSearch = useDebounce(searchQuery, 400);
  // Global lookup matches (women not in current snapshot) — synthesized PayoutRecords.
  const [lookupRows, setLookupRows] = useState<PayoutRecord[]>([]);
  const [isLookingUp, setIsLookingUp] = useState(false);

  useEffect(() => { loadRecords(); }, [monthFilter]);

  // Global lookup across ALL women profiles when a search term is entered.
  // Returns women not present in current snapshot, hydrated with KYC + wallet info.
  useEffect(() => {
    const q = debouncedSearch.trim();
    if (q.length < 2) { setLookupRows([]); return; }
    let cancelled = false;
    (async () => {
      setIsLookingUp(true);
      try {
        const like = `%${q}%`;
        const { data: profs } = await supabase
          .from('profiles')
          .select('user_id, user_code, full_name, app_sno, gender')
          .eq('gender', 'female')
          .or(`user_code.ilike.${like},full_name.ilike.${like},user_id.eq.${/^[0-9a-f-]{36}$/i.test(q) ? q : '00000000-0000-0000-0000-000000000000'}`)
          .limit(50);
        if (cancelled || !profs?.length) { setLookupRows([]); return; }
        const ids = profs.map(p => p.user_id);
        const [kycRes, walletRes, codeRes] = await Promise.all([
          supabase.from('women_kyc').select('user_id, account_holder_name, full_name_as_per_bank, mobile_number, email_address, current_address, bank_account_number, ifsc_code, upi_vpa, beneficiary_purpose, verification_status').in('user_id', ids),
          supabase.from('wallets').select('user_id, balance').in('user_id', ids),
          supabase.from('profiles').select('user_id, user_code').in('user_id', ids),
        ]);
        const kMap = new Map((kycRes.data || []).map((k: any) => [k.user_id, k]));
        const wMap = new Map((walletRes.data || []).map((w: any) => [w.user_id, Number(w.balance || 0)]));
        const existing = new Set(records.map(r => r.user_id));
        const synth: PayoutRecord[] = profs
          .filter(p => !existing.has(p.user_id))
          .map(p => {
            const k: any = kMap.get(p.user_id) || {};
            return {
              id: `lookup-${p.user_id}`,
              user_id: p.user_id,
              app_sno: p.app_sno ?? null,
              beneficiary_purpose: k.beneficiary_purpose || null,
              account_holder_name: k.account_holder_name || null,
              full_name: k.full_name_as_per_bank || p.full_name || '—',
              mobile_number: k.mobile_number || null,
              email_address: k.email_address || null,
              address: k.current_address || null,
              bank_account_number: k.bank_account_number || null,
              ifsc_code: k.ifsc_code || null,
              upi_vpa: k.upi_vpa || null,
              wallet_balance_at_snapshot: wMap.get(p.user_id) || 0,
              payment_status: k.verification_status === 'approved' ? 'lookup' : 'kyc_pending',
              snapshot_type: 'lookup',
              ist_month: monthFilter,
              ist_year: new Date().getFullYear(),
              snapshot_ist_date: '',
              created_at: '',
            };
          });
        setLookupRows(synth);
        // Hydrate codeMap with these IDs too so the GESS column renders.
        const newCodes: Record<string, string> = {};
        (codeRes.data || []).forEach((p: any) => { if (p.user_code) newCodes[p.user_id] = p.user_code; });
        if (Object.keys(newCodes).length) setCodeMap(prev => ({ ...prev, ...newCodes }));
      } finally {
        if (!cancelled) setIsLookingUp(false);
      }
    })();
    return () => { cancelled = true; };
  }, [debouncedSearch, records, monthFilter]);

  // Fetch login + billing seconds whenever records or month change
  useEffect(() => {
    const ids = records.map(r => r.user_id).filter(Boolean);
    if (ids.length === 0) { setTimeMap({}); return; }
    (async () => {
      const { data, error } = await supabase.rpc('get_login_billing_seconds_bulk', {
        _user_ids: ids,
        _month: monthFilter,
      });
      if (error) {
        console.warn('[Payouts] time fetch failed:', error.message);
        setTimeMap({});
        return;
      }
      const map: Record<string, { login: number; billing: number }> = {};
      (data as Array<{ user_id: string; login_seconds: number; billing_seconds: number }> | null)?.forEach(row => {
        map[row.user_id] = {
          login: Number(row.login_seconds || 0),
          billing: Number(row.billing_seconds || 0),
        };
      });
      setTimeMap(map);
    })();
  }, [records, monthFilter]);

  // Fetch GESS user codes for visible records
  useEffect(() => {
    const ids = records.map(r => r.user_id).filter(Boolean);
    if (ids.length === 0) { setCodeMap({}); return; }
    (async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_id, user_code')
        .in('user_id', ids);
      if (error) { setCodeMap({}); return; }
      const map: Record<string, string> = {};
      (data || []).forEach((p: { user_id: string; user_code: string | null }) => {
        if (p.user_code) map[p.user_id] = p.user_code;
      });
      setCodeMap(map);
    })();
  }, [records]);

  // Realtime: refresh when snapshots change
  useEffect(() => {
    const channel = supabase
      .channel('admin-payout-snapshots-rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'women_payout_snapshots' }, () => {
        loadRecords();
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [monthFilter]);

  const loadRecords = async () => {
    setIsLoading(true);
    try {
      const data = (await getPayoutSnapshots(monthFilter)) as PayoutRecord[];
      // Dedupe: keep only the LATEST snapshot per user for the period.
      // Each Generate run zeroes the wallet, so the newest row already holds
      // only the new (incremental) balance — no old amounts carried over.
      const seen = new Set<string>();
      const latestPerUser: PayoutRecord[] = [];
      for (const r of data) {
        if (!r.user_id || seen.has(r.user_id)) continue;
        seen.add(r.user_id);
        latestPerUser.push(r);
      }
      setRecords(latestPerUser);
    } catch (err: any) {
      console.error('[Payouts] load failed:', err);
      toast({ title: 'Failed to load payouts', description: err?.message || 'Please retry', variant: 'destructive' });
      setRecords([]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleGenerate = async () => {
    setIsGenerating(true);
    try {
      // 1) Run both DB snapshot RPCs
      const [legacy, unified] = await Promise.all([
        generatePayoutSnapshot(),
        generatePayoutSnapshotNow(),
      ]);
      if (!legacy.success) {
        toast({ title: 'Error', description: legacy.error, variant: 'destructive' });
        return;
      }

      // 2) Re-fetch the freshly generated snapshot rows for THIS month, then
      //    dedupe to keep only the latest snapshot per user (incremental balance).
      const allFresh = (await getPayoutSnapshots(monthFilter)) as PayoutRecord[];
      const _seen = new Set<string>();
      const fresh: PayoutRecord[] = [];
      for (const r of allFresh) {
        if (!r.user_id || _seen.has(r.user_id)) continue;
        _seen.add(r.user_id);
        fresh.push(r);
      }
      setRecords(fresh);

      // 3) Build Excel from fresh rows (don't depend on async state)
      // Fetch login + billing seconds inline so the Excel matches the on-screen data.
      const ids = fresh.map(r => r.user_id).filter(Boolean);
      let freshTimes: Record<string, { login: number; billing: number }> = {};
      if (ids.length > 0) {
        const { data: tData, error: tErr } = await supabase.rpc('get_login_billing_seconds_bulk', {
          _user_ids: ids,
          _month: monthFilter,
        });
        if (tErr) console.warn('[Payouts] inline time fetch failed:', tErr.message);
        (tData as Array<{ user_id: string; login_seconds: number; billing_seconds: number }> | null)?.forEach(t => {
          freshTimes[t.user_id] = { login: Number(t.login_seconds || 0), billing: Number(t.billing_seconds || 0) };
        });
        setTimeMap(freshTimes);
      }

      // Fetch GESS codes inline so the Excel matches on-screen data
      let freshCodes: Record<string, string> = {};
      if (ids.length > 0) {
        const { data: pData } = await supabase
          .from('profiles')
          .select('user_id, user_code')
          .in('user_id', ids);
        (pData || []).forEach((p: { user_id: string; user_code: string | null }) => {
          if (p.user_code) freshCodes[p.user_id] = p.user_code;
        });
        setCodeMap(freshCodes);
      }

      const rows = fresh.map((r, i) => ({
        sno: r.app_sno ?? i + 1,
        gessId: freshCodes[r.user_id] || '—',
        userId: r.user_id || '—',
        purpose: r.beneficiary_purpose || 'Earnings Payout',
        name: r.account_holder_name || r.full_name || '—',
        phone: r.mobile_number || '—',
        email: r.email_address || '—',
        address: r.address || '—',
        account: r.bank_account_number || '—',
        ifsc: r.ifsc_code || '—',
        upi: r.upi_vpa || '—',
        amount: fmtINRNumber(r.wallet_balance_at_snapshot),
        loginTime: fmtHMS(freshTimes[r.user_id]?.login ?? 0),
        billingTime: fmtHMS(freshTimes[r.user_id]?.billing ?? 0),
      }));
      const total = fresh.reduce((s, r) => s + Number(r.wallet_balance_at_snapshot || 0), 0);

      // Timestamp in IST → YYYY-MM-DD_HH-mm-ss
      const istNow = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
      const pad = (n: number) => String(n).padStart(2, '0');
      const stamp = `${istNow.getFullYear()}-${pad(istNow.getMonth() + 1)}-${pad(istNow.getDate())}_${pad(istNow.getHours())}-${pad(istNow.getMinutes())}-${pad(istNow.getSeconds())}`;
      const filename = `payout-${stamp}.xlsx`;

      const wsData = [
        ['Payout Statement'],
        [`Period: ${monthFilter}`, '', 'Currency: INR', '', `Women: ${fresh.length}`, '', `Total: ${fmtINR(total)}`, '', `Generated (IST): ${stamp}`],
        [],
        PAYOUT_HEADERS,
        ...rows.map(r => [r.sno, r.gessId, r.userId, r.purpose, r.name, r.phone, r.email, r.address, r.account, r.ifsc, r.upi, r.amount, r.loginTime, r.billingTime]),
      ];
      const ws = XLSX.utils.aoa_to_sheet(wsData);
      ws['!cols'] = [{ wch: 10 }, { wch: 14 }, { wch: 38 }, { wch: 18 }, { wch: 20 }, { wch: 14 }, { wch: 24 }, { wch: 30 }, { wch: 18 }, { wch: 14 }, { wch: 22 }, { wch: 14 }, { wch: 16 }, { wch: 16 }];
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Payouts');

      // 4) Upload to Supabase Storage (never overwrite — unique filename)
      const arrayBuf = XLSX.write(wb, { bookType: 'xlsx', type: 'array' }) as ArrayBuffer;
      const blob = new Blob([arrayBuf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      const storagePath = `${monthFilter}/${filename}`;
      const { error: upErr } = await supabase.storage
        .from('payout-exports')
        .upload(storagePath, blob, { contentType: blob.type, upsert: false });
      if (upErr) console.warn('[Payouts] archive upload failed:', upErr.message);

      // 5) Auto-download to admin device
      XLSX.writeFile(wb, filename);

      const skipMsg = legacy.skipped ? ` • ${legacy.skipped} skipped (no KYC)` : '';
      const unifiedMsg = unified.success ? ` • ${unified.count ?? 0} unified statements` : '';
      const archiveMsg = upErr ? ' • archive failed' : ' • archived';
      toast({ title: 'Payout Generated', description: `${legacy.count} women${skipMsg}${unifiedMsg}${archiveMsg}.` });
      loadArchives();
    } catch (e: any) {
      toast({ title: 'Error', description: e?.message || 'Generation failed', variant: 'destructive' });
    } finally {
      setIsGenerating(false);
    }
  };

  // ─── Archived Exports (Storage) ───
  // Active = files in `payout-exports` bucket
  // Archived = files moved to `payout-exports-archive` bucket
  const [archives, setArchives] = useState<{ name: string; path: string; created_at?: string }[]>([]);
  const [view, setView] = useState<'active' | 'archived'>('active');
  const bucketName = view === 'active' ? 'payout-exports' : 'payout-exports-archive';

  const loadArchives = async () => {
    const { data, error } = await supabase.storage
      .from(bucketName)
      .list(monthFilter, { limit: 100, sortBy: { column: 'created_at', order: 'desc' } });
    if (error) { setArchives([]); return; }
    setArchives((data || []).filter(f => f.name.endsWith('.xlsx')).map(f => ({
      name: f.name,
      path: `${monthFilter}/${f.name}`,
      created_at: (f as any).created_at,
    })));
  };
  useEffect(() => { loadArchives(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [monthFilter, view]);

  const downloadArchive = async (path: string, name: string) => {
    const { data, error } = await supabase.storage.from(bucketName).download(path);
    if (error || !data) { toast({ title: 'Download failed', description: error?.message, variant: 'destructive' }); return; }
    const url = URL.createObjectURL(data);
    const a = document.createElement('a');
    a.href = url; a.download = name; a.click();
    URL.revokeObjectURL(url);
  };

  // Move file between active ↔ archive bucket (download + upload + delete original)
  const moveFile = async (path: string, from: string, to: string) => {
    const { data: file, error: dlErr } = await supabase.storage.from(from).download(path);
    if (dlErr || !file) throw new Error(dlErr?.message || 'Download failed');
    const { error: upErr } = await supabase.storage.from(to).upload(path, file, {
      contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      upsert: true,
    });
    if (upErr) throw new Error(upErr.message);
    const { error: rmErr } = await supabase.storage.from(from).remove([path]);
    if (rmErr) throw new Error(rmErr.message);
  };

  const archiveFile = async (path: string, name: string) => {
    try {
      await moveFile(path, 'payout-exports', 'payout-exports-archive');
      toast({ title: 'Archived', description: name });
      loadArchives();
    } catch (e: any) {
      toast({ title: 'Archive failed', description: e?.message, variant: 'destructive' });
    }
  };

  const restoreFile = async (path: string, name: string) => {
    try {
      await moveFile(path, 'payout-exports-archive', 'payout-exports');
      toast({ title: 'Restored', description: name });
      loadArchives();
    } catch (e: any) {
      toast({ title: 'Restore failed', description: e?.message, variant: 'destructive' });
    }
  };

  const buildRows = () => records.map((r, i) => ({
    sno: r.app_sno ?? i + 1,
    gessId: codeMap[r.user_id] || '—',
    userId: r.user_id || '—',
    purpose: r.beneficiary_purpose || 'Earnings Payout',
    name: r.account_holder_name || r.full_name || '—',
    phone: r.mobile_number || '—',
    email: r.email_address || '—',
    address: r.address || '—',
    account: r.bank_account_number || '—',
    ifsc: r.ifsc_code || '—',
    upi: r.upi_vpa || '—',
    amount: fmtINRNumber(r.wallet_balance_at_snapshot),
    loginTime: fmtHMS(timeMap[r.user_id]?.login ?? 0),
    billingTime: fmtHMS(timeMap[r.user_id]?.billing ?? 0),
  }));

  const totalAmount = records.reduce((s, r) => s + Number(r.wallet_balance_at_snapshot || 0), 0);

  // ─── CSV Export ───
  const exportCSV = () => {
    if (!records.length) return;
    const rows = buildRows();
    const escape = (v: string | number) => `"${String(v).replace(/"/g, '""')}"`;
    const csv = [
      PAYOUT_HEADERS.join(','),
      ...rows.map(r => [r.sno, escape(r.gessId), escape(r.userId), escape(r.purpose), escape(r.name), escape(r.phone), escape(r.email), escape(r.address), escape(r.account), r.ifsc, escape(r.upi), r.amount, r.loginTime, r.billingTime].join(',')),
    ].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `payout-${monthFilter}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  // ─── PDF Export ───
  const exportPDF = () => {
    if (!records.length) return;
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
    doc.setFontSize(18);
    doc.text('Payout Statement', 14, 16);
    doc.setFontSize(10);
    doc.text(`Period: ${monthFilter}  •  Currency: INR  •  Women: ${records.length}  •  Total: ${fmtINR(totalAmount)}`, 14, 23);

    const rows = buildRows().map(r => [String(r.sno), r.gessId, r.userId, r.purpose, r.name, r.phone, r.email, r.address, r.account, r.ifsc, r.upi, r.amount, r.loginTime, r.billingTime]);

    autoTable(doc, {
      startY: 30,
      head: [PAYOUT_HEADERS],
      body: rows,
      styles: { fontSize: 6, cellPadding: 1.2 },
      headStyles: { fillColor: [99, 102, 241], fontSize: 6 },
      columnStyles: { 11: { halign: 'right' }, 12: { halign: 'right' }, 13: { halign: 'right' } },
    });

    doc.save(`payout-${monthFilter}.pdf`);
  };

  // ─── Excel Export ───
  const exportExcel = () => {
    if (!records.length) return;
    const rows = buildRows();
    const wsData = [
      ['Payout Statement'],
      [`Period: ${monthFilter}`, '', 'Currency: INR', '', `Women: ${records.length}`, '', `Total: ${fmtINR(totalAmount)}`],
      [],
      PAYOUT_HEADERS,
      ...rows.map(r => [r.sno, r.gessId, r.userId, r.purpose, r.name, r.phone, r.email, r.address, r.account, r.ifsc, r.upi, r.amount, r.loginTime, r.billingTime]),
    ];
    const ws = XLSX.utils.aoa_to_sheet(wsData);
    ws['!cols'] = [{ wch: 10 }, { wch: 14 }, { wch: 38 }, { wch: 18 }, { wch: 20 }, { wch: 14 }, { wch: 24 }, { wch: 30 }, { wch: 18 }, { wch: 14 }, { wch: 22 }, { wch: 14 }, { wch: 16 }, { wch: 16 }];
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Payouts');
    XLSX.writeFile(wb, `payout-${monthFilter}.xlsx`);
  };

  // ─── Word Export ───
  const exportWord = () => {
    if (!records.length) return;
    const rows = buildRows();
    const tableRows = rows.map(r =>
      `<tr><td>${r.sno}</td><td>${r.gessId}</td><td style="font-family:monospace;font-size:8pt">${r.userId}</td><td>${r.purpose}</td><td>${r.name}</td><td>${r.phone}</td><td>${r.email}</td><td>${r.address}</td><td>${r.account}</td><td>${r.ifsc}</td><td>${r.upi}</td><td style="text-align:right">${r.amount}</td><td style="text-align:right">${r.loginTime}</td><td style="text-align:right">${r.billingTime}</td></tr>`
    ).join('');
    const html = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><style>body{font-family:Arial;font-size:11pt}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:4px 6px;font-size:9pt}th{background:#6366F1;color:#fff}h1{font-size:18pt}</style></head><body>
<h1>Payout Statement</h1><p>Period: ${monthFilter} • Currency: INR • Women: ${records.length} • Total: ${fmtINR(totalAmount)}</p>
<table><thead><tr>${PAYOUT_HEADERS.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${tableRows}</tbody></table></body></html>`;
    const blob = new Blob(['\ufeff', html], { type: 'application/msword' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `payout-${monthFilter}.doc`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <AdminNav>
      <div className="p-4 md:p-6 space-y-6 max-w-7xl mx-auto">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-foreground">Payout Statements</h1>
            <p className="text-sm text-muted-foreground">Monthly payout snapshots — sourced from Bank KYC</p>
          </div>
          <div className="flex gap-2 flex-wrap items-center">
            <Input
              type="search"
              placeholder="Search GESS ID, user UUID, name, phone…"
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-64"
            />
            <Input type="month" value={monthFilter} onChange={e => setMonthFilter(e.target.value)} className="w-40" />
            <Button variant="outline" size="sm" onClick={loadRecords} disabled={isLoading}>
              <RefreshCw className={`w-4 h-4 mr-1 ${isLoading ? 'animate-spin' : ''}`} /> Refresh
            </Button>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline" size="sm" disabled={!records.length}>
                  <Download className="w-4 h-4 mr-1" /> Export
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={exportPDF}>
                  <FileText className="w-4 h-4 mr-2" /> Export PDF
                </DropdownMenuItem>
                <DropdownMenuItem onClick={exportExcel}>
                  <FileSpreadsheet className="w-4 h-4 mr-2" /> Export Excel
                </DropdownMenuItem>
                <DropdownMenuItem onClick={exportCSV}>
                  <FileSpreadsheet className="w-4 h-4 mr-2" /> Export CSV
                </DropdownMenuItem>
                <DropdownMenuItem onClick={exportWord}>
                  <FileText className="w-4 h-4 mr-2" /> Export Word
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <Users className="w-8 h-8 text-primary" />
              <div>
                <p className="text-2xl font-bold">{records.length}</p>
                <p className="text-xs text-muted-foreground">Women in Payout</p>
              </div>
            </div>
          </Card>
          <Card className="p-4">
            <div className="flex items-center gap-3">
              <IndianRupee className="w-8 h-8 text-primary" />
              <div>
                <p className="text-2xl font-bold">{fmtINR(totalAmount)}</p>
                <p className="text-xs text-muted-foreground">Total Payout Amount</p>
              </div>
            </div>
          </Card>
        </div>

        {/* Generate Button — captures all women's current wallet balance + Bank KYC */}
        <Card className="p-4 flex flex-wrap gap-3 items-center">
          <Calendar className="w-5 h-5 text-muted-foreground" />
          <span className="text-sm text-muted-foreground">
            Generate a payout snapshot for all eligible women (closing wallet balance at this moment, sourced from Bank KYC):
          </span>
          <Button size="sm" onClick={handleGenerate} disabled={isGenerating}>
            {isGenerating ? <Loader2 className="w-4 h-4 mr-1 animate-spin" /> : <Download className="w-4 h-4 mr-1" />}
            Generate Now
          </Button>
        </Card>

        {/* Excel snapshots — Active / Archived toggle */}
        <Card className="p-4">
          <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
            <div>
              <h2 className="font-semibold text-foreground">
                {view === 'active' ? 'Excel Snapshots' : 'Archived Snapshots'}
              </h2>
              <p className="text-xs text-muted-foreground">
                {view === 'active'
                  ? 'Every Generate click and the 1st-of-month auto-run save a new timestamped .xlsx. Use Archive to move old files out of view.'
                  : 'Old snapshots moved to archive. Use Restore to bring them back to the active list.'}
              </p>
            </div>
            <div className="flex gap-2">
              <Button
                variant={view === 'active' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setView('active')}
              >
                Active
              </Button>
              <Button
                variant={view === 'archived' ? 'default' : 'outline'}
                size="sm"
                onClick={() => setView('archived')}
              >
                <Archive className="w-4 h-4 mr-1" /> Archived
              </Button>
              <Button variant="outline" size="sm" onClick={loadArchives}>
                <RefreshCw className="w-4 h-4 mr-1" /> Refresh
              </Button>
            </div>
          </div>
          {archives.length === 0 ? (
            <p className="text-sm text-muted-foreground py-2">
              No {view === 'active' ? 'snapshots' : 'archived files'} for {monthFilter}.
            </p>
          ) : (
            <ul className="divide-y">
              {archives.map(a => (
                <li key={a.path} className="flex items-center justify-between py-2 text-sm gap-2">
                  <div className="flex items-center gap-2 min-w-0 flex-1">
                    <FileSpreadsheet className="w-4 h-4 text-primary shrink-0" />
                    <span className="font-mono truncate">{a.name}</span>
                    {a.created_at && <span className="text-xs text-muted-foreground ml-2 shrink-0">{format(new Date(a.created_at), 'dd MMM yyyy HH:mm')}</span>}
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <Button variant="ghost" size="sm" onClick={() => downloadArchive(a.path, a.name)}>
                      <Download className="w-4 h-4 mr-1" /> Download
                    </Button>
                    {view === 'active' ? (
                      <Button variant="ghost" size="sm" onClick={() => archiveFile(a.path, a.name)} title="Move to archive">
                        <Archive className="w-4 h-4 mr-1" /> Archive
                      </Button>
                    ) : (
                      <Button variant="ghost" size="sm" onClick={() => restoreFile(a.path, a.name)} title="Restore to active">
                        <ArchiveRestore className="w-4 h-4 mr-1" /> Restore
                      </Button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>

        {/* Table — Spec §7: 10 columns from Bank KYC + GESS ID + User ID */}
        <Card className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Beneficiary ID / S.No</TableHead>
                <TableHead>GESS ID</TableHead>
                <TableHead>User ID</TableHead>
                <TableHead>Beneficiary Purpose</TableHead>
                <TableHead>Name</TableHead>
                <TableHead>Phone Number</TableHead>
                <TableHead>Email ID</TableHead>
                <TableHead>Address</TableHead>
                <TableHead>Account Number</TableHead>
                <TableHead>IFSC Code</TableHead>
                <TableHead>UPI VPA</TableHead>
                <TableHead className="text-right">Amount (₹)</TableHead>
                <TableHead className="text-right">Total Login Time</TableHead>
                <TableHead className="text-right">Total Billing Time</TableHead>
                <TableHead>Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                <TableRow><TableCell colSpan={15} className="text-center py-8"><Loader2 className="w-6 h-6 animate-spin mx-auto" /></TableCell></TableRow>
              ) : (() => {
                  const q = searchQuery.trim().toLowerCase();
                  const matchRow = (r: PayoutRecord) => {
                    const code = (codeMap[r.user_id] || '').toLowerCase();
                    return (
                      code.includes(q) ||
                      r.user_id?.toLowerCase().includes(q) ||
                      (r.full_name || '').toLowerCase().includes(q) ||
                      (r.account_holder_name || '').toLowerCase().includes(q) ||
                      (r.mobile_number || '').includes(q) ||
                      (r.email_address || '').toLowerCase().includes(q)
                    );
                  };
                  const snapshotMatches = q ? records.filter(matchRow) : records;
                  const filtered = q
                    ? [...snapshotMatches, ...lookupRows]
                    : records;
                  if (filtered.length === 0) {
                    return <TableRow><TableCell colSpan={15} className="text-center py-8 text-muted-foreground">{isLookingUp ? 'Searching…' : 'No payout records match'}</TableCell></TableRow>;
                  }
                  return filtered.map((r, i) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-mono text-xs">{r.app_sno ?? i + 1}</TableCell>
                    <TableCell className="font-mono text-xs">{codeMap[r.user_id] || '—'}</TableCell>
                    <TableCell className="font-mono text-[10px] text-muted-foreground" title={r.user_id}>{r.user_id?.slice(0, 8)}…</TableCell>
                    <TableCell className="text-xs">{r.beneficiary_purpose || 'Earnings Payout'}</TableCell>
                    <TableCell className="font-medium">{r.account_holder_name || r.full_name || '—'}</TableCell>
                    <TableCell className="text-xs font-mono">{r.mobile_number || '—'}</TableCell>
                    <TableCell className="text-xs">{r.email_address || '—'}</TableCell>
                    <TableCell className="text-xs max-w-[200px] truncate" title={r.address || ''}>{r.address || '—'}</TableCell>
                    <TableCell className="text-xs font-mono">{r.bank_account_number ? '****' + r.bank_account_number.slice(-4) : '—'}</TableCell>
                    <TableCell className="text-xs font-mono">{r.ifsc_code || '—'}</TableCell>
                    <TableCell className="text-xs font-mono">{r.upi_vpa || '—'}</TableCell>
                    <TableCell className="text-right font-semibold text-primary">{fmtINR(r.wallet_balance_at_snapshot)}</TableCell>
                    <TableCell className="text-right text-xs font-mono">{fmtHMS(timeMap[r.user_id]?.login ?? 0)}</TableCell>
                    <TableCell className="text-right text-xs font-mono">{fmtHMS(timeMap[r.user_id]?.billing ?? 0)}</TableCell>
                    <TableCell>
                      <Badge variant={r.payment_status === 'paid' ? 'default' : 'secondary'} className="text-xs">
                        {r.payment_status}
                      </Badge>
                    </TableCell>
                  </TableRow>
                ));
                })()}
            </TableBody>
          </Table>
        </Card>
      </div>
    </AdminNav>
  );
};

export default AdminPayoutStatements;
