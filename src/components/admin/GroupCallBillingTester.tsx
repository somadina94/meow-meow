import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { CheckCircle2, XCircle, Loader2, FlaskConical } from "lucide-react";

type Check = { check: string; expected: number | string; actual: number | string; pass: boolean };

interface Report {
  success: boolean;
  error?: string;
  session_id?: string;
  minutes?: number;
  man_id?: string;
  woman_id?: string;
  pricing?: { group_man_rate: number; group_woman_rate: number };
  man_balance_before?: number;
  man_balance_after?: number;
  woman_balance_before?: number;
  woman_balance_after?: number;
  expected_debit?: number;
  expected_credit?: number;
  actual_debit?: number;
  actual_credit?: number;
  checks?: Check[];
  all_passed?: boolean;
}

export function GroupCallBillingTester() {
  const [running, setRunning] = useState(false);
  const [report, setReport] = useState<Report | null>(null);

  const runTest = async () => {
    setRunning(true);
    setReport(null);
    try {
      const { data, error } = await supabase.rpc("simulate_group_call_billing", {
        p_man_id: undefined as unknown as string,
        p_woman_id: undefined as unknown as string,
        p_minutes: 5,
      });
      if (error) throw error;
      const r = data as unknown as Report;
      setReport(r);
      if (r.all_passed) toast.success("All billing checks passed");
      else toast.error(r.error ?? "Some checks failed — see report");
    } catch (e: any) {
      toast.error(e.message ?? "Simulation failed");
      setReport({ success: false, error: e.message });
    } finally {
      setRunning(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <FlaskConical className="h-5 w-5" />
          Group Call Billing — Live Test (5 min)
        </CardTitle>
        <CardDescription>
          Runs 5 simulated minutes of <code>private_group_call</code> billing through the
          canonical <code>bill_session_minute</code> RPC and verifies wallet debits, credits,
          and statement visibility. Auto-picks a male user with sufficient balance and the
          first female host.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <Button onClick={runTest} disabled={running}>
          {running ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Simulating…
            </>
          ) : (
            "Run 5-minute simulation"
          )}
        </Button>

        {report && (
          <div className="space-y-3 rounded-md border p-3 text-sm">
            {report.error && (
              <div className="rounded bg-destructive/10 p-2 text-destructive">
                {report.error}
              </div>
            )}

            {report.success && (
              <>
                <div className="flex items-center gap-2">
                  {report.all_passed ? (
                    <Badge className="bg-green-600 text-white">ALL PASSED</Badge>
                  ) : (
                    <Badge variant="destructive">FAILED</Badge>
                  )}
                  <span className="text-muted-foreground">
                    Session {report.session_id?.slice(0, 8)}… · {report.minutes} min
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <div className="font-semibold">Man</div>
                    <div className="text-xs text-muted-foreground">
                      {report.man_id?.slice(0, 8)}…
                    </div>
                    <div>Rate: ₹{report.pricing?.group_man_rate}/min</div>
                    <div>
                      Balance: ₹{report.man_balance_before} → ₹{report.man_balance_after}
                    </div>
                    <div>
                      Expected debit: ₹{report.expected_debit} · Actual: ₹{report.actual_debit}
                    </div>
                  </div>
                  <div>
                    <div className="font-semibold">Woman (host)</div>
                    <div className="text-xs text-muted-foreground">
                      {report.woman_id?.slice(0, 8)}…
                    </div>
                    <div>Rate: ₹{report.pricing?.group_woman_rate}/min</div>
                    <div>
                      Balance: ₹{report.woman_balance_before} → ₹{report.woman_balance_after}
                    </div>
                    <div>
                      Expected credit: ₹{report.expected_credit} · Actual: ₹{report.actual_credit}
                    </div>
                  </div>
                </div>

                <div className="space-y-1">
                  {report.checks?.map((c) => (
                    <div
                      key={c.check}
                      className="flex items-center justify-between rounded bg-muted/40 px-2 py-1"
                    >
                      <span className="flex items-center gap-2">
                        {c.pass ? (
                          <CheckCircle2 className="h-4 w-4 text-green-600" />
                        ) : (
                          <XCircle className="h-4 w-4 text-destructive" />
                        )}
                        <code className="text-xs">{c.check}</code>
                      </span>
                      <span className="text-xs text-muted-foreground">
                        expected {String(c.expected)} · actual {String(c.actual)}
                      </span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export default GroupCallBillingTester;
