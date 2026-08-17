import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Women's KYC submission screen — 9 sections matching the React WomenKYCForm.
///
/// Writes to the existing `women_kyc` table. Any modification resets
/// `kyc_status` to `pending` (handled server-side).
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _supabase = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String _status = 'not_submitted';
  String? _rejectionReason;

  // Backing data (flat map keyed by db column name).
  final Map<String, String> _v = {};

  // 9 sections × representative fields (kept short — the React form has
  // ~60 fields; mirror the schema 1:1 in production).
  static const Map<String, List<_F>> _sections = {
    '1. Personal Information': [
      _F('full_name_as_per_bank', 'Full name (as per bank)', required: true),
      _F('fathers_name', "Father's name"),
      _F('mothers_name', "Mother's name"),
      _F('date_of_birth', 'Date of birth (YYYY-MM-DD)', required: true),
      _F('gender', 'Gender'),
      _F('marital_status', 'Marital status'),
      _F('nationality', 'Nationality'),
      _F('occupation', 'Occupation'),
      _F('annual_income_range', 'Annual income range'),
    ],
    '2. Contact Information': [
      _F('mobile_number', 'Mobile number'),
      _F('email_address', 'Email address'),
      _F('current_address', 'Current address'),
      _F('permanent_address', 'Permanent address'),
      _F('city', 'City'),
      _F('state', 'State'),
      _F('pincode', 'PIN code'),
    ],
    '3. Identity Documents': [
      _F('aadhaar_number', 'Aadhaar (12 digits)', required: true),
      _F('pan_number', 'PAN number', required: true),
      _F('voter_id_number', 'Voter ID'),
      _F('passport_number', 'Passport number'),
      _F('driving_license_number', 'Driving license'),
    ],
    '4. Bank Account Details': [
      _F('bank_name', 'Bank name', required: true),
      _F('bank_account_number', 'Account number', required: true),
      _F('ifsc_code', 'IFSC code', required: true),
      _F('account_holder_name', 'Account holder name', required: true),
      _F('account_type', 'Account type (savings/current)'),
      _F('branch_name', 'Branch name'),
    ],
    '5. UPI Details (optional)': [
      _F('upi_id', 'UPI ID'),
      _F('upi_holder_name', 'UPI holder name'),
    ],
    '6. Tax Information': [
      _F('gst_number', 'GST number (if applicable)'),
      _F('tax_residency_status', 'Tax residency status'),
    ],
    '7. Nominee Details': [
      _F('nominee_name', 'Nominee name'),
      _F('nominee_relationship', 'Relationship'),
      _F('nominee_mobile', 'Nominee mobile'),
    ],
    '8. Emergency Contact': [
      _F('emergency_contact_name', 'Emergency contact name'),
      _F('emergency_contact_relationship', 'Relationship'),
      _F('emergency_contact_mobile', 'Mobile'),
    ],
    '9. Declaration': [
      _F('declaration_signed_name', 'Type your full name to sign',
          required: true),
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _supabase
          .from('women_kyc')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        _status = (row['kyc_status'] as String?) ?? 'pending';
        _rejectionReason = row['rejection_reason'] as String?;
        for (final entry in row.entries) {
          if (entry.value != null && entry.value is String) {
            _v[entry.key] = entry.value as String;
          }
        }
      }
    } catch (e) {
      debugPrint('[KYC] load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'user_id': userId,
      'kyc_status': 'pending', // any modification resets to pending
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      ..._v,
    };

    try {
      await _supabase
          .from('women_kyc')
          .upsert(payload, onConflict: 'user_id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted for review')),
      );
      setState(() {
        _status = 'pending';
        _rejectionReason = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final readOnly = _status == 'approved' || _status == 'pending';
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: Column(
        children: [
          _StatusBanner(status: _status, reason: _rejectionReason),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final s in _sections.entries) ...[
                    Text(s.key,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final f in s.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          initialValue: _v[f.key],
                          enabled: !readOnly,
                          decoration: InputDecoration(
                            labelText: f.label + (f.required ? ' *' : ''),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (f.required && (val == null || val.trim().isEmpty)) {
                              return 'Required';
                            }
                            return null;
                          },
                          onSaved: (v) => _v[f.key] = v?.trim() ?? '',
                          onChanged: (v) => _v[f.key] = v.trim(),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (!readOnly)
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit for review'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _F {
  final String key;
  final String label;
  final bool required;
  const _F(this.key, this.label, {this.required = false});
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String? reason;
  const _StatusBanner({required this.status, this.reason});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String text;
    switch (status) {
      case 'approved':
        bg = AppColors.success;
        text = 'KYC approved — payouts enabled.';
        break;
      case 'pending':
        bg = Colors.orange;
        text = 'KYC under review.';
        break;
      case 'rejected':
        bg = Colors.red;
        text = 'KYC rejected${reason != null ? ': $reason' : ''}. Please update.';
        break;
      default:
        bg = Colors.grey;
        text = 'KYC not submitted.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: bg.withOpacity(0.15),
      child: Text(text, style: TextStyle(color: bg, fontWeight: FontWeight.w600)),
    );
  }
}
