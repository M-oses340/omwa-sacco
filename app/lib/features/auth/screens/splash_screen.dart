import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: cs.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.account_balance,
                  color: cs.onPrimary, size: 50),
            ),
            const SizedBox(height: 20),
            Text('Omwa Sacco',
                style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text('United for Prosperity',
                style: TextStyle(
                    color: cs.onPrimary.withValues(alpha: 0.7),
                    fontSize: 14)),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: cs.onPrimary.withValues(alpha: 0.7),
                  strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
