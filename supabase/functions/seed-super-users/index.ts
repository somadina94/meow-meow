import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
}

interface ResultItem {
  email: string
  status: string
  userId?: string
}

interface ErrorItem {
  email: string
  error: string
}

// Generate a secure random password
function generateSecurePassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%^&*';
  let password = '';
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  for (let i = 0; i < 16; i++) {
    password += chars[array[i] % chars.length];
  }
  return password;
}

// Helper to verify admin JWT
async function verifyAdminAuth(req: Request, supabase: any): Promise<{ isValid: boolean; error?: string; userId?: string }> {
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { isValid: false, error: 'Missing or invalid Authorization header' };
  }

  const token = authHeader.replace('Bearer ', '');
  
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return { isValid: false, error: 'Invalid or expired token' };
  }

  const { data: roleData } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .eq('role', 'admin')
    .maybeSingle();

  if (!roleData) {
    return { isValid: false, error: 'Unauthorized: Admin role required' };
  }

  return { isValid: true, userId: user.id };
}

/**
 * Idempotent profile seeding: only INSERT if no profile exists.
 * Never overwrites existing profiles to preserve admin changes.
 */
async function ensureProfile(supabase: any, userId: string, profileData: Record<string, any>): Promise<'created' | 'exists'> {
  const { data: existing } = await supabase
    .from('profiles')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle();

  if (existing) {
    return 'exists';
  }

  await supabase.from('profiles').insert({
    user_id: userId,
    ...profileData,
  });
  return 'created';
}

/**
 * Idempotent wallet seeding: only INSERT if no wallet exists.
 * Never resets existing balances.
 */
async function ensureWallets(supabase: any, userId: string, gender: 'men' | 'women'): Promise<void> {
  const { data: existingLegacy } = await supabase
    .from('wallets')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle();

  if (!existingLegacy) {
    await supabase.from('wallets').insert({
      user_id: userId,
      balance: 0,
      currency: 'INR'
    });
  }

  const { data: existingLedger } = await supabase
    .from('users_wallet')
    .select('user_id')
    .eq('user_id', userId)
    .maybeSingle();

  if (!existingLedger) {
    await supabase.from('users_wallet').insert({
      user_id: userId,
      balance: 0,
      currency: 'INR',
      gender
    });
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // SECURITY: Verify caller is an authenticated admin
    const authResult = await verifyAdminAuth(req, supabase);
    if (!authResult.isValid) {
      console.log(`[SECURITY] Unauthorized access attempt to seed-super-users: ${authResult.error}`);
      return new Response(JSON.stringify({ 
        success: false, 
        error: authResult.error 
      }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`[AUDIT] Admin ${authResult.userId} initiated seed-super-users`);

    // SECURITY: Use environment variable for password, fallback to random generation
    const password = Deno.env.get('SUPER_USER_TEST_PASSWORD') || generateSecurePassword();
    console.log(`[SECURITY] Using ${Deno.env.get('SUPER_USER_TEST_PASSWORD') ? 'configured' : 'generated'} password for test accounts`);
    
    const results: { females: ResultItem[], males: ResultItem[], admins: ResultItem[], errors: ErrorItem[], passwordNote?: string } = { 
      females: [], 
      males: [], 
      admins: [], 
      errors: [],
      passwordNote: Deno.env.get('SUPER_USER_TEST_PASSWORD') ? undefined : 'Generated random password - check logs for value'
    }

    // Create female super users (1-15)
    // CANONICAL PATTERN: female{1-15}@meow-meow.com (no zero-padding)
    // Must stay in sync with: chat-manager SUPER_USER_PATTERNS, admin-delete-user protected pattern
    for (let i = 1; i <= 15; i++) {
      const email = `female${i}@meow-meow.com`
      try {
        // Try to create auth user
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: `Female User ${i}`, gender: 'female' }
        })

        let userId: string;
        let authStatus: string;

        if (authError) {
          if (authError.message.includes('already been registered')) {
            // Look up existing user ID
            const { data: { users } } = await supabase.auth.admin.listUsers();
            const existingUser = users?.find((u: any) => u.email === email);
            if (!existingUser) {
              results.errors.push({ email, error: 'Auth user exists but could not be found' });
              continue;
            }
            userId = existingUser.id;
            authStatus = 'auth_exists';
          } else {
            results.errors.push({ email, error: authError.message });
            continue;
          }
        } else {
          userId = authData.user.id;
          authStatus = 'auth_created';
        }

        // Idempotent: only create profile/wallets if they don't exist
        const profileStatus = await ensureProfile(supabase, userId, {
          full_name: `Female User ${i}`,
          gender: 'female',
          country: 'India',
          primary_language: 'Hindi',
          preferred_language: 'hin_Deva',
          approval_status: 'approved',
          ai_approved: true,
          account_status: 'active',
          is_verified: true
        });

        await ensureWallets(supabase, userId, 'women');

        results.females.push({ 
          email, 
          status: profileStatus === 'exists' ? 'already exists (preserved)' : 'created',
          userId 
        });
      } catch (err) {
        results.errors.push({ email, error: String(err) })
      }
    }

    // Create male super users (1-15)
    for (let i = 1; i <= 15; i++) {
      const email = `male${i}@meow-meow.com`
      try {
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: `Male User ${i}`, gender: 'male' }
        })

        let userId: string;

        if (authError) {
          if (authError.message.includes('already been registered')) {
            const { data: { users } } = await supabase.auth.admin.listUsers();
            const existingUser = users?.find((u: any) => u.email === email);
            if (!existingUser) {
              results.errors.push({ email, error: 'Auth user exists but could not be found' });
              continue;
            }
            userId = existingUser.id;
          } else {
            results.errors.push({ email, error: authError.message });
            continue;
          }
        } else {
          userId = authData.user.id;
        }

        const profileStatus = await ensureProfile(supabase, userId, {
          full_name: `Male User ${i}`,
          gender: 'male',
          country: 'India',
          primary_language: 'Hindi',
          preferred_language: 'hin_Deva',
          approval_status: 'approved',
          ai_approved: true,
          account_status: 'active',
          is_verified: true
        });

        await ensureWallets(supabase, userId, 'men');

        results.males.push({ 
          email, 
          status: profileStatus === 'exists' ? 'already exists (preserved)' : 'created',
          userId 
        });
      } catch (err) {
        results.errors.push({ email, error: String(err) })
      }
    }

    // Create admin super users (1-15)
    for (let i = 1; i <= 15; i++) {
      const email = `admin${i}@meow-meow.com`
      try {
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: `Admin User ${i}`, gender: 'male' }
        })

        let userId: string;

        if (authError) {
          if (authError.message.includes('already been registered')) {
            const { data: { users } } = await supabase.auth.admin.listUsers();
            const existingUser = users?.find((u: any) => u.email === email);
            if (!existingUser) {
              results.errors.push({ email, error: 'Auth user exists but could not be found' });
              continue;
            }
            userId = existingUser.id;
          } else {
            results.errors.push({ email, error: authError.message });
            continue;
          }
        } else {
          userId = authData.user.id;
        }

        const profileStatus = await ensureProfile(supabase, userId, {
          full_name: `Admin User ${i}`,
          gender: 'male',
          country: 'India',
          primary_language: 'English',
          preferred_language: 'eng_Latn',
          approval_status: 'approved',
          ai_approved: true,
          account_status: 'active',
          is_verified: true
        });

        await ensureWallets(supabase, userId, 'men');

        // Admin role is always ensured (idempotent upsert)
        await supabase.from('user_roles').upsert({
          user_id: userId,
          role: 'admin'
        }, { onConflict: 'user_id,role' });

        results.admins.push({ 
          email, 
          status: profileStatus === 'exists' ? 'already exists (preserved)' : 'created',
          userId 
        });
      } catch (err) {
        results.errors.push({ email, error: String(err) })
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Super users seeded successfully',
      results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ 
      success: false, 
      error: errorMessage 
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
