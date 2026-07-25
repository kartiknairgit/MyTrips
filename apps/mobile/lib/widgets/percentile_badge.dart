import 'package:flutter/material.dart';
import '../models/stats.dart';

/// Badge displaying mileage percentile with scope-aware text.
class PercentileBadge extends StatelessWidget {
  final MileagePercentile percentile;

  const PercentileBadge({
    super.key,
    required this.percentile,
  });

  @override
  Widget build(BuildContext context) {
    if (percentile.scope == PercentileScope.noData) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(
          children: [
            Icon(Icons.info_outline, color: Colors.white54, size: 32),
            SizedBox(height: 8),
            Text(
              'Insufficient Data',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final isGlobal = percentile.scope == PercentileScope.global;
    final scopeIcon = isGlobal ? Icons.public : Icons.flag;
    final scopeColor = isGlobal ? const Color(0xFFFF10F0) : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scopeColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(scopeIcon, color: scopeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                percentile.scope.displayName,
                style: TextStyle(
                  color: scopeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${percentile.percentile.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Percentile',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
