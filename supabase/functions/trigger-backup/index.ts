import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
}

interface BackupRequest {
  backup_type?: 'manual' | 'scheduled'
}

// Comprehensive list of ALL application tables
const BACKUP_TABLES = [
  'profiles', 'male_profiles', 'female_profiles', 'user_roles',
  'chat_messages', 'active_chat_sessions', 'matches',
  'wallet_transactions', 'wallets', 'gift_transactions', 'gifts',
  'chat_pricing', 'language_groups', 'language_limits',
  'admin_settings', 'app_settings', 'legal_documents',
  'moderation_reports', 'audit_logs', 'backup_logs',
  'notifications', 'women_kyc', 'withdrawal_requests',
  'attendance', 'absence_records',
  'private_groups', 'group_memberships', 'group_messages',
  'community_announcements', 'community_disputes',
  'admin_broadcast_messages', 'admin_user_messages',
  'monthly_statements', 'monthly_wallet_summary',
  'admin_revenue_transactions', 'chat_wait_queue',
  'language_community_messages', 'group_video_access',
  'platform_metrics', 'policy_violation_alerts',
  'user_status', 'password_reset_tokens',
]

// Tables that may have >10k rows — paginate these
const LARGE_TABLES = new Set([
  'chat_messages', 'wallet_transactions', 'notifications',
  'audit_logs', 'language_community_messages', 'group_messages',
])

const MAX_ROWS_PER_TABLE = 50000
const PAGE_SIZE = 1000

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  try {
    // Verify auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || supabaseServiceKey
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    const { data: { user }, error: authError } = await authClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check admin role
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)
    const { data: roleData } = await adminClient
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('role', 'admin')
      .maybeSingle()

    if (!roleData) {
      return new Response(
        JSON.stringify({ error: 'Admin access required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body: BackupRequest = await req.json().catch(() => ({}))
    const backupType = body.backup_type || 'manual'
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')

    console.log(`Starting ${backupType} backup triggered by ${user.id}`)

    // Create backup log entry
    const { data: backupLog, error: insertError } = await adminClient
      .from('backup_logs')
      .insert({
        backup_type: backupType,
        status: 'in_progress',
        triggered_by: user.id,
        started_at: new Date().toISOString()
      })
      .select()
      .single()

    if (insertError) {
      return new Response(
        JSON.stringify({ error: 'Failed to create backup log', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Respond immediately, then run backup in background
    const responsePromise = new Response(
      JSON.stringify({ success: true, message: 'Backup started', backup_id: backupLog.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

    // Run backup in background
    const backupPromise = (async () => {
      try {
        const backupData: Record<string, unknown[]> = {}
        const tableStats: Record<string, number> = {}
        const errors: string[] = []
        let totalRows = 0

        // ============================================
        // PHASE 1: Export all database tables
        // ============================================
        for (const table of BACKUP_TABLES) {
          try {
            if (LARGE_TABLES.has(table)) {
              // Paginated export for large tables
              const allRows: unknown[] = []
              let offset = 0
              let hasMore = true

              while (hasMore && offset < MAX_ROWS_PER_TABLE) {
                const { data, error } = await adminClient
                  .from(table)
                  .select('*')
                  .range(offset, offset + PAGE_SIZE - 1)
                  .order('created_at', { ascending: true })

                if (error) {
                  // If ordering by created_at fails, try without ordering
                  const { data: fallbackData, error: fallbackError } = await adminClient
                    .from(table)
                    .select('*')
                    .range(offset, offset + PAGE_SIZE - 1)

                  if (fallbackError) {
                    errors.push(`${table}: ${fallbackError.message}`)
                    break
                  }
                  if (fallbackData) allRows.push(...fallbackData)
                  hasMore = (fallbackData?.length || 0) === PAGE_SIZE
                } else {
                  if (data) allRows.push(...data)
                  hasMore = (data?.length || 0) === PAGE_SIZE
                }
                offset += PAGE_SIZE
              }

              if (allRows.length > 0) {
                backupData[table] = allRows
                tableStats[table] = allRows.length
                totalRows += allRows.length
              }
            } else {
              // Standard export for smaller tables (up to 10k)
              const { data, error } = await adminClient
                .from(table)
                .select('*')
                .limit(10000)

              if (error) {
                errors.push(`${table}: ${error.message}`)
                console.warn(`Skipping table ${table}: ${error.message}`)
              } else if (data && data.length > 0) {
                backupData[table] = data
                tableStats[table] = data.length
                totalRows += data.length
              }
            }
          } catch (e) {
            errors.push(`${table}: ${e instanceof Error ? e.message : 'unknown'}`)
          }
        }

        // ============================================
        // PHASE 2: Export storage bucket metadata & files
        // ============================================
        const storageBackup: Record<string, { files: unknown[]; totalFiles: number }> = {}

        try {
          const { data: buckets, error: bucketsError } = await adminClient.storage.listBuckets()

          if (!bucketsError && buckets) {
            for (const bucket of buckets) {
              try {
                const bucketFiles: unknown[] = []

                // List all files in the bucket (recursive via folders)
                const listFilesRecursive = async (path: string) => {
                  const { data: files, error: listError } = await adminClient.storage
                    .from(bucket.name)
                    .list(path, { limit: 1000 })

                  if (listError || !files) return

                  for (const file of files) {
                    const fullPath = path ? `${path}/${file.name}` : file.name

                    if (file.id) {
                      // It's a file — store metadata
                      const { data: urlData } = await adminClient.storage
                        .from(bucket.name)
                        .createSignedUrl(fullPath, 60 * 60 * 24 * 7) // 7-day signed URL

                      bucketFiles.push({
                        name: file.name,
                        path: fullPath,
                        bucket: bucket.name,
                        size: (file.metadata as any)?.size || null,
                        mimetype: (file.metadata as any)?.mimetype || null,
                        created_at: file.created_at,
                        updated_at: file.updated_at,
                        signed_url: urlData?.signedUrl || null,
                      })
                    } else {
                      // It's a folder — recurse
                      await listFilesRecursive(fullPath)
                    }
                  }
                }

                await listFilesRecursive('')

                if (bucketFiles.length > 0) {
                  storageBackup[bucket.name] = {
                    files: bucketFiles,
                    totalFiles: bucketFiles.length,
                  }
                }
              } catch (bucketErr) {
                errors.push(`storage/${bucket.name}: ${bucketErr instanceof Error ? bucketErr.message : 'unknown'}`)
              }
            }
          }
        } catch (storageErr) {
          errors.push(`storage_listing: ${storageErr instanceof Error ? storageErr.message : 'unknown'}`)
        }

        // ============================================
        // PHASE 3: Export auth users metadata
        // ============================================
        const authUsersBackup: unknown[] = []
        try {
          let page = 1
          let hasMore = true
          while (hasMore && page <= 100) {
            const { data: usersPage, error: usersError } = await adminClient.auth.admin.listUsers({
              page,
              perPage: 50,
            })
            if (usersError) {
              errors.push(`auth_users: ${usersError.message}`)
              break
            }
            if (usersPage?.users) {
              for (const u of usersPage.users) {
                authUsersBackup.push({
                  id: u.id,
                  email: u.email,
                  phone: u.phone,
                  created_at: u.created_at,
                  last_sign_in_at: u.last_sign_in_at,
                  email_confirmed_at: u.email_confirmed_at,
                  phone_confirmed_at: u.phone_confirmed_at,
                  role: u.role,
                  app_metadata: u.app_metadata,
                  user_metadata: u.user_metadata,
                })
              }
              hasMore = usersPage.users.length === 50
            } else {
              hasMore = false
            }
            page++
          }
        } catch (authErr) {
          errors.push(`auth_users: ${authErr instanceof Error ? authErr.message : 'unknown'}`)
        }

        // ============================================
        // Build the complete backup payload
        // ============================================
        const backupPayload = {
          backup_id: backupLog.id,
          backup_type: backupType,
          created_at: new Date().toISOString(),
          triggered_by: user.id,
          supabase_project_url: supabaseUrl,
          version: '2.0',
          summary: {
            tables_exported: Object.keys(backupData).length,
            tables_failed: errors.filter(e => !e.startsWith('storage') && !e.startsWith('auth')).length,
            total_rows: totalRows,
            table_stats: tableStats,
            storage_buckets_exported: Object.keys(storageBackup).length,
            total_storage_files: Object.values(storageBackup).reduce((sum, b) => sum + b.totalFiles, 0),
            auth_users_exported: authUsersBackup.length,
          },
          errors: errors.length > 0 ? errors : undefined,
          database: backupData,
          storage: Object.keys(storageBackup).length > 0 ? storageBackup : undefined,
          auth_users: authUsersBackup.length > 0 ? authUsersBackup : undefined,
        }

        const jsonStr = JSON.stringify(backupPayload)
        const sizeBytes = new TextEncoder().encode(jsonStr).length
        const storagePath = `backups/${timestamp}_${backupLog.id}.json`

        // Upload to Supabase Storage
        let uploadSuccess = false
        try {
          await adminClient.storage.createBucket('backups', {
            public: false,
            allowedMimeTypes: ['application/json'],
            fileSizeLimit: 500 * 1024 * 1024,
          }).catch(() => { /* bucket may already exist */ })

          const { error: uploadError } = await adminClient.storage
            .from('backups')
            .upload(storagePath, jsonStr, {
              contentType: 'application/json',
              upsert: true,
            })

          if (uploadError) {
            console.error('Storage upload failed:', uploadError.message)
            errors.push(`upload: ${uploadError.message}`)
          } else {
            uploadSuccess = true
          }
        } catch (storageErr) {
          console.error('Storage error:', storageErr)
          errors.push(`upload: ${storageErr instanceof Error ? storageErr.message : 'unknown'}`)
        }

        // Update backup log as completed
        const summary = backupPayload.summary
        const statusMsg = [
          `${summary.tables_exported} tables (${totalRows} rows)`,
          `${summary.auth_users_exported} auth users`,
          `${summary.storage_buckets_exported} storage buckets (${summary.total_storage_files} files)`,
          errors.length > 0 ? `${errors.length} warnings` : null,
        ].filter(Boolean).join(', ')

        await adminClient
          .from('backup_logs')
          .update({
            status: uploadSuccess ? 'completed' : 'failed',
            size_bytes: sizeBytes,
            storage_path: uploadSuccess ? storagePath : null,
            completed_at: new Date().toISOString(),
            error_message: uploadSuccess
              ? (errors.length > 0 ? statusMsg : null)
              : `Upload failed. ${statusMsg}`,
          })
          .eq('id', backupLog.id)

        console.log(`Backup ${backupLog.id} ${uploadSuccess ? 'completed' : 'failed'}: ${statusMsg}, ${(sizeBytes / 1024 / 1024).toFixed(2)} MB`)
      } catch (error) {
        console.error(`Backup ${backupLog.id} failed:`, error)
        await adminClient
          .from('backup_logs')
          .update({
            status: 'failed',
            error_message: error instanceof Error ? error.message : 'Unknown error',
            completed_at: new Date().toISOString(),
          })
          .eq('id', backupLog.id)
      }
    })()

    // Use EdgeRuntime waitUntil if available
    if (typeof (globalThis as any).EdgeRuntime !== 'undefined') {
      (globalThis as any).EdgeRuntime.waitUntil(backupPromise)
    }

    return responsePromise
  } catch (error) {
    console.error('Backup trigger error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
