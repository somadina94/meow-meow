import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Helper: always return 200 with JSON body to avoid FunctionsHttpError on the client
// The client checks data.success to determine success/failure
function jsonResponse(data: Record<string, unknown>, httpStatus = 200) {
  return new Response(JSON.stringify(data), {
    status: httpStatus,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ success: false, error: 'Method not allowed' }, 405)
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('[admin-create-user] Missing env vars')
      return jsonResponse({ success: false, error: 'Server configuration error' }, 500)
    }

    // Create admin client with service role key
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Verify caller is authenticated
    const authHeader = req.headers.get('authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonResponse({ success: false, error: 'Unauthorized: Missing authorization header' }, 401)
    }

    const token = authHeader.replace('Bearer ', '').trim()
    if (!token) {
      return jsonResponse({ success: false, error: 'Unauthorized: Empty token' }, 401)
    }

    const { data: { user: caller }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !caller) {
      console.error('[admin-create-user] Token validation failed:', authError?.message)
      return jsonResponse({ success: false, error: 'Unauthorized: Invalid or expired token' }, 401)
    }

    // Verify caller has admin role
    const { data: roleData, error: roleError } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', caller.id)
      .eq('role', 'admin')
      .maybeSingle()

    if (roleError) {
      console.error('[admin-create-user] Role lookup error:', roleError.message)
      return jsonResponse({ success: false, error: 'Failed to verify admin role' }, 500)
    }

    if (!roleData) {
      console.warn(`[admin-create-user] Non-admin user ${caller.id} attempted user creation`)
      return jsonResponse({ success: false, error: 'Forbidden: Admin role required' }, 403)
    }

    // Parse request body
    let body: Record<string, unknown>
    try {
      body = await req.json()
    } catch {
      return jsonResponse({ success: false, error: 'Invalid JSON in request body' }, 400)
    }

    const {
      email,
      password,
      full_name,
      gender,
      country,
      primary_language,
      role,
    } = body as {
      email?: string
      password?: string
      full_name?: string
      gender?: string
      country?: string
      primary_language?: string
      role?: string
    }

    // Validate required fields
    if (!email || typeof email !== 'string' || !email.trim().includes('@')) {
      return jsonResponse({ success: false, error: 'A valid email address is required' }, 400)
    }
    if (!password || typeof password !== 'string' || password.length < 6) {
      return jsonResponse({ success: false, error: 'Password must be at least 6 characters' }, 400)
    }
    if (!full_name || typeof full_name !== 'string' || !full_name.trim()) {
      return jsonResponse({ success: false, error: 'Full name is required' }, 400)
    }
    if (!gender || typeof gender !== 'string') {
      return jsonResponse({ success: false, error: 'Gender is required' }, 400)
    }

    const normalizedGender = gender.toLowerCase().trim()
    if (!['male', 'female'].includes(normalizedGender)) {
      return jsonResponse({ success: false, error: 'Gender must be "male" or "female"' }, 400)
    }

    const normalizedEmail = email.toLowerCase().trim()
    const normalizedName = full_name.trim()
    const normalizedCountry = (typeof country === 'string' && country.trim()) ? country.trim() : 'India'
    const normalizedLanguage = (typeof primary_language === 'string' && primary_language.trim()) ? primary_language.trim() : 'English'
    const assignAdminRole = role === 'admin'

    console.log(`[AUDIT] Admin ${caller.id} creating user: ${normalizedEmail} (${normalizedGender}, admin=${assignAdminRole})`)

    // Create the auth user — email confirmed immediately, no verification email sent
    const { data: authData, error: createError } = await supabase.auth.admin.createUser({
      email: normalizedEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: normalizedName, gender: normalizedGender },
    })

    if (createError) {
      console.error('[admin-create-user] Auth user creation failed:', createError.message)
      const msg = createError.message?.toLowerCase() || ''
      if (msg.includes('already') || msg.includes('exists') || msg.includes('registered') || msg.includes('duplicate')) {
        return jsonResponse({ success: false, error: `A user with email "${normalizedEmail}" already exists. Please use a different email address.`, code: 'USER_EXISTS' }, 409)
      }
      return jsonResponse({ success: false, error: createError.message }, 400)
    }

    if (!authData?.user?.id) {
      return jsonResponse({ success: false, error: 'User creation failed: no user ID returned' }, 500)
    }

    const userId = authData.user.id

    // Upsert main profile — auto-approved, no photo required
    const { error: profileError } = await supabase.from('profiles').upsert({
      user_id: userId,
      full_name: normalizedName,
      gender: normalizedGender,
      country: normalizedCountry,
      primary_language: normalizedLanguage,
      preferred_language: normalizedLanguage,
      approval_status: 'approved',
      ai_approved: true,
      account_status: 'active',
      is_verified: true,
    }, { onConflict: 'user_id' })

    if (profileError) {
      console.error('[admin-create-user] Profile upsert error:', profileError.message)
    }

    // Upsert gender-specific profile
    if (normalizedGender === 'female') {
      const { error: femaleErr } = await supabase.from('female_profiles').upsert({
        user_id: userId,
        full_name: normalizedName,
        country: normalizedCountry,
        primary_language: normalizedLanguage,
        approval_status: 'approved',
        ai_approved: true,
        account_status: 'active',
        is_verified: true,
        is_indian: normalizedCountry.toLowerCase().includes('india'),
      }, { onConflict: 'user_id' })

      if (femaleErr) {
        console.error('[admin-create-user] Female profile upsert error:', femaleErr.message)
      }
    } else {
      const { error: maleErr } = await supabase.from('male_profiles').upsert({
        user_id: userId,
        full_name: normalizedName,
        country: normalizedCountry,
        primary_language: normalizedLanguage,
        account_status: 'active',
        is_verified: true,
      }, { onConflict: 'user_id' })

      if (maleErr) {
        console.error('[admin-create-user] Male profile upsert error:', maleErr.message)
      }
    }

    // Upsert wallet with zero balance
    const { error: walletErr } = await supabase.from('wallets').upsert({
      user_id: userId,
      balance: 0,
      currency: 'INR',
    }, { onConflict: 'user_id' })

    if (walletErr) {
      console.error('[admin-create-user] Wallet upsert error:', walletErr.message)
    }

    // Upsert user status
    const { error: statusErr } = await supabase.from('user_status').upsert({
      user_id: userId,
      is_online: false,
    }, { onConflict: 'user_id' })

    if (statusErr) {
      console.error('[admin-create-user] User status upsert error:', statusErr.message)
    }

    // Assign admin role if requested
    if (assignAdminRole) {
      const { error: roleAssignErr } = await supabase.from('user_roles').upsert({
        user_id: userId,
        role: 'admin',
      }, { onConflict: 'user_id,role' })

      if (roleAssignErr) {
        console.error('[admin-create-user] Admin role assignment error:', roleAssignErr.message)
      }
    }

    console.log(`[AUDIT] User created successfully: ${normalizedEmail} (${userId})`)

    return jsonResponse({
      success: true,
      message: `User ${normalizedEmail} created successfully`,
      userId,
      email: normalizedEmail,
      gender: normalizedGender,
    })

  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error('[admin-create-user] Unexpected error:', msg)
    return jsonResponse({ success: false, error: `Server error: ${msg}` }, 500)
  }
})
