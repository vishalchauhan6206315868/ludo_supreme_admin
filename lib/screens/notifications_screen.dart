import 'package:flutter/material.dart';
import '../theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Push Notifications & Broadcasts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6ECF5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kOrange.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active, color: kOrange, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Push Notifications Service Status: Pending Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Backend FCM credentials integration pending product decision.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              statusChip('Pending FCM'),
            ]),
            const Divider(height: 32),
            const Text(
              'Technical Requirements for Integration:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text('1. Firebase Project Service Account Key (.json) must be placed in the backend.'),
            const SizedBox(height: 6),
            const Text('2. Client mobile app must register device FCM tokens to backend (/api/users/fcm-token).'),
            const SizedBox(height: 6),
            const Text('3. Admin broadcast endpoint (POST /api/admin/notifications) will be activated once FCM credentials are provided.'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Firebase FCM setup is not configured on the backend yet.')),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Test Broadcast (Disabled)'),
            ),
          ]),
        ),
      ]),
    );
  }
}
