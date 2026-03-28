import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared PIN pad widget used by PinScreen and PinConfirmScreen.
class PinPad extends StatelessWidget {
  final bool isDark;
  final bool showBiometric;
  final VoidCallback? onBiometric;
  final void Function(String key) onKey;
  final VoidCallback onDelete;

  const PinPad({
    super.key,
    required this.isDark,
    required this.onKey,
    required this.onDelete,
    this.showBiometric = false,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildRow(context, ['1', '2', '3']),
          const SizedBox(height: 12),
          _buildRow(context, ['4', '5', '6']),
          const SizedBox(height: 12),
          _buildRow(context, ['7', '8', '9']),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NumKey(
                isDark: isDark,
                onTap: showBiometric && onBiometric != null ? onBiometric! : () {},
                child: Icon(
                  Icons.fingerprint,
                  color: showBiometric
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.2),
                  size: 32,
                ),
              ),
              _NumKey(
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onKey('0');
                },
                child: Text('0',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w500)),
              ),
              _NumKey(
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDelete();
                },
                child: Icon(Icons.backspace_outlined,
                    color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> keys) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys
          .map((k) => _NumKey(
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onKey(k);
                },
                child: Text(k,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _NumKey(
      {required this.child, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
