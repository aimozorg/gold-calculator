import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionState {
  final bool active;
  final String plan;
  final DateTime? expiresAt;

  const SubscriptionState({required this.active, this.plan = 'بدون اشتراک', this.expiresAt});
}

class SubscriptionService {
  final SupabaseClient client;
  SubscriptionService(this.client);

  Future<SubscriptionState> current() async {
    final user = client.auth.currentUser;
    if (user == null) return const SubscriptionState(active: false);

    final row = await client
        .from('subscriptions')
        .select('plan,status,expires_at')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return const SubscriptionState(active: false);

    final status = row['status'] as String? ?? 'inactive';
    final expiresRaw = row['expires_at'] as String?;
    final expires = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    final valid = status == 'active' && (expires == null || expires.isAfter(DateTime.now().toUtc()));
    return SubscriptionState(
      active: valid,
      plan: row['plan'] as String? ?? 'اشتراک',
      expiresAt: expires,
    );
  }
}
