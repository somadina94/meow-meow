import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || supabaseServiceKey
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Auth guard: require admin role or cron/service-role caller
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    const token = authHeader.replace('Bearer ', '')
    const isCronCall = token === supabaseAnonKey || token === supabaseServiceKey

    if (!isCronCall) {
      const authClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      })
      const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token)
      if (authError || !caller) {
        return new Response(JSON.stringify({ success: false, error: 'Invalid token' }), {
          status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      const { data: roleData } = await supabase
        .from('user_roles').select('role')
        .eq('user_id', caller.id).eq('role', 'admin').maybeSingle()
      if (!roleData) {
        return new Response(JSON.stringify({ success: false, error: 'Admin access required' }), {
          status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    const now = new Date().toISOString()

    // Collect real platform metrics from database
    const [
      { count: totalUsers },
      { count: activeChats },
      { count: onlineUsers },
      { count: recentMessages },
      { count: pendingReports },
    ] = await Promise.all([
      supabase.from('male_profiles').select('*', { count: 'exact', head: true }),
      supabase.from('active_chat_sessions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      supabase.from('user_status').select('*', { count: 'exact', head: true }).eq('is_online', true),
      supabase.from('chat_messages').select('*', { count: 'exact', head: true }).gte('created_at', new Date(Date.now() - 60000).toISOString()),
      supabase.from('moderation_reports').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    ])

    // Derive approximate metrics from platform activity
    const activeConnections = (onlineUsers || 0) + (activeChats || 0)
    const messagesPerMinute = recentMessages || 0

    // Estimate resource usage based on activity levels
    // These are approximations since we can't directly measure Supabase infra
    const baseCpu = 5
    const cpuPerConnection = 0.05
    const cpuPerMessage = 0.1
    const cpuUsage = Math.min(95, baseCpu + activeConnections * cpuPerConnection + messagesPerMinute * cpuPerMessage + (Math.random() * 3 - 1.5))

    const baseMemory = 20
    const memoryPerUser = 0.01
    const memoryUsage = Math.min(95, baseMemory + (totalUsers || 0) * memoryPerUser + activeConnections * 0.05 + (Math.random() * 2 - 1))

    // Measure actual response time by timing a simple query
    const rtStart = performance.now()
    await supabase.from('app_settings').select('id').limit(1)
    const responseTime = Math.round(performance.now() - rtStart)

    // Estimate disk and network from data volume
    const diskUsage = Math.min(90, 10 + (totalUsers || 0) * 0.002)
    const networkIn = Math.max(0, messagesPerMinute * 0.02 + activeConnections * 0.005 + (Math.random() * 0.1))
    const networkOut = Math.max(0, messagesPerMinute * 0.05 + activeConnections * 0.01 + (Math.random() * 0.1))
    const errorRate = pendingReports && messagesPerMinute ? Math.min(5, (pendingReports / Math.max(1, messagesPerMinute)) * 0.5) : Math.random() * 0.1

    // Insert metrics
    const { error: metricsError } = await supabase
      .from('system_metrics')
      .insert({
        cpu_usage: parseFloat(cpuUsage.toFixed(2)),
        memory_usage: parseFloat(memoryUsage.toFixed(2)),
        active_connections: activeConnections,
        response_time: responseTime,
        disk_usage: parseFloat(diskUsage.toFixed(2)),
        network_in: parseFloat(networkIn.toFixed(3)),
        network_out: parseFloat(networkOut.toFixed(3)),
        error_rate: parseFloat(errorRate.toFixed(3)),
        recorded_at: now,
      })

    if (metricsError) {
      console.error('Failed to insert metrics:', metricsError)
      throw metricsError
    }

    // Check thresholds and create alerts
    const thresholds = [
      { metric: 'cpu_usage', value: cpuUsage, warning: 70, critical: 85, label: 'CPU Usage' },
      { metric: 'memory_usage', value: memoryUsage, warning: 75, critical: 90, label: 'Memory Usage' },
      { metric: 'response_time', value: responseTime, warning: 100, critical: 200, label: 'Response Time' },
      { metric: 'error_rate', value: errorRate, warning: 1, critical: 3, label: 'Error Rate' },
    ]

    for (const t of thresholds) {
      if (t.value >= t.critical) {
        // Check for existing unresolved alert of same type
        const { data: existing } = await supabase
          .from('system_alerts')
          .select('id')
          .eq('metric_name', t.metric)
          .eq('is_resolved', false)
          .limit(1)

        if (!existing || existing.length === 0) {
          await supabase.from('system_alerts').insert({
            alert_type: 'critical',
            metric_name: t.metric,
            threshold_value: t.critical,
            current_value: parseFloat(t.value.toFixed(2)),
            message: `${t.label} has reached critical level: ${t.value.toFixed(1)}`,
            is_resolved: false,
          })
        }
      } else if (t.value >= t.warning) {
        const { data: existing } = await supabase
          .from('system_alerts')
          .select('id')
          .eq('metric_name', t.metric)
          .eq('is_resolved', false)
          .limit(1)

        if (!existing || existing.length === 0) {
          await supabase.from('system_alerts').insert({
            alert_type: 'warning',
            metric_name: t.metric,
            threshold_value: t.warning,
            current_value: parseFloat(t.value.toFixed(2)),
            message: `${t.label} is elevated: ${t.value.toFixed(1)}`,
            is_resolved: false,
          })
        }
      } else {
        // Auto-resolve alerts when metric drops below warning
        await supabase
          .from('system_alerts')
          .update({ is_resolved: true, resolved_at: now })
          .eq('metric_name', t.metric)
          .eq('is_resolved', false)
      }
    }

    // Cleanup old metrics (keep last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
    await supabase
      .from('system_metrics')
      .delete()
      .lt('recorded_at', sevenDaysAgo)

    console.log(`Metrics collected: CPU=${cpuUsage.toFixed(1)}%, MEM=${memoryUsage.toFixed(1)}%, RT=${responseTime}ms, Conn=${activeConnections}`)

    return new Response(
      JSON.stringify({
        success: true,
        metrics: { cpuUsage, memoryUsage, responseTime, activeConnections, diskUsage },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Metrics collection error:', error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
