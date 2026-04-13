// ============================================================
// 📊 WIDGET — Tableau de bord des statistiques
// ============================================================

import 'package:flutter/material.dart';

class AnimalStatsDashboard extends StatelessWidget {
  final Map<String, int> stats;

  const AnimalStatsDashboard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = (stats['actif'] ?? 0) +
        (stats['mort'] ?? 0) +
        (stats['vendu'] ?? 0) +
        (stats['tue'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Tableau de bord',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Total: $total animaux',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(
                label: 'Actifs',
                count: stats['actif'] ?? 0,
                color: const Color(0xFF059669),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Morts',
                count: stats['mort'] ?? 0,
                color: const Color(0xFF6B7280),
                icon: Icons.coronavirus_outlined,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Vendus',
                count: stats['vendu'] ?? 0,
                color: const Color(0xFF2563EB),
                icon: Icons.sell_outlined,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Tués',
                count: stats['tue'] ?? 0,
                color: const Color(0xFFDC2626),
                icon: Icons.cut_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}