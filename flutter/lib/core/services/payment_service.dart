import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Razorpay payment service.
///
/// Flow:
/// 1. Client calls `razorpay-payment` edge function -> returns `order_id`.
/// 2. Razorpay native SDK opens checkout with that order_id.
/// 3. On success, Razorpay webhook (`razorpay-webhook`) credits the wallet
///    server-side via the canonical billing RPC. The client just shows a
///    success state and refreshes wallet.
///
/// Never credit the wallet directly from the client.
final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;
  Razorpay? _razorpay;

  void Function(PaymentSuccessResponse)? onSuccess;
  void Function(PaymentFailureResponse)? onError;
  void Function(ExternalWalletResponse)? onExternalWallet;

  void init({
    void Function(PaymentSuccessResponse)? onSuccess,
    void Function(PaymentFailureResponse)? onError,
    void Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    dispose();
    _razorpay = Razorpay();
    this.onSuccess = onSuccess;
    this.onError = onError;
    this.onExternalWallet = onExternalWallet;
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  void _handleSuccess(PaymentSuccessResponse r) {
    debugPrint('[Payment] success: ${r.paymentId}');
    onSuccess?.call(r);
  }

  void _handleError(PaymentFailureResponse r) {
    debugPrint('[Payment] error: ${r.code} ${r.message}');
    onError?.call(r);
  }

  void _handleExternalWallet(ExternalWalletResponse r) {
    debugPrint('[Payment] external wallet: ${r.walletName}');
    onExternalWallet?.call(r);
  }

  /// Create a Razorpay order via edge function.
  /// Returns map with `order_id`, `amount`, `currency`, `key_id`.
  Future<Map<String, dynamic>?> createOrder({
    required String userId,
    required int amountInRupees,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'razorpay-payment',
        body: {
          'action': 'create_order',
          'user_id': userId,
          'amount': amountInRupees,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) return null;
      return data;
    } catch (e) {
      debugPrint('[Payment] createOrder failed: $e');
      return null;
    }
  }

  /// Open the Razorpay checkout sheet.
  /// `keyId` and `orderId` come from createOrder().
  void openCheckout({
    required String keyId,
    required String orderId,
    required int amountInPaise,
    required String userEmail,
    required String userPhone,
    required String userName,
  }) {
    if (_razorpay == null) {
      throw StateError('PaymentService.init() not called');
    }
    final options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'Meow Meow',
      'description': 'Wallet Recharge',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'theme': {'color': '#6366F1'},
    };
    _razorpay!.open(options);
  }
}
