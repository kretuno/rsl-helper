import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/translation_service.dart';

class AdminDialog extends StatefulWidget {
  const AdminDialog({super.key});

  @override
  State<AdminDialog> createState() => _AdminDialogState();
}

class _AdminDialogState extends State<AdminDialog> {
  bool _isLoading = true;
  int _totalUsers = 0;
  List<Map<String, dynamic>> _usersList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Get total users count (highly optimized count query)
      final countSnapshot = await FirebaseFirestore.instance.collection('users').count().get();
      final total = countSnapshot.count ?? 0;

      // 2. Get recent active users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('savedAt', descending: true)
          .limit(20)
          .get();

      final List<Map<String, dynamic>> users = [];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final String? email = data['email'] as String?;
        final String? savedAtStr = data['savedAt'] as String?;
        final List<dynamic> countersData = data['counters'] as List<dynamic>? ?? [];

        // Parse counters for a quick summary
        String countersSummary = '';
        for (var c in countersData) {
          if (c is Map) {
            final id = c['id'] as String?;
            final current = c['current'] ?? 0;
            if (id != null) {
              String shortName = id.substring(0, 1).toUpperCase(); // A, V, S, P
              if (id == 'primal_mythical') shortName = 'M';
              if (id == 'primal_legendary') shortName = 'L';
              
              if (countersSummary.isNotEmpty) countersSummary += ' • ';
              countersSummary += '$shortName: $current';
            }
          }
        }

        DateTime? savedAt;
        if (savedAtStr != null) {
          savedAt = DateTime.tryParse(savedAtStr);
        }

        users.add({
          'uid': doc.id,
          'email': email ?? 'Anonymous (${doc.id.substring(0, 6)}...)',
          'savedAt': savedAt,
          'countersSummary': countersSummary.isEmpty ? 'No counters' : countersSummary,
        });
      }

      if (mounted) {
        setState(() {
          _totalUsers = total;
          _usersList = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final localDt = dt.toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${pad(localDt.day)}.${pad(localDt.month)}.${localDt.year} ${pad(localDt.hour)}:${pad(localDt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 600,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Панель администратора',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка загрузки данных',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadStats,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Повторить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Всего пользователей в облаке',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_totalUsers',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recent activity header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Последняя активность (20 пользователей)',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync_rounded, color: AppColors.gold, size: 20),
                          onPressed: _loadStats,
                          tooltip: 'Обновить данные',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Users list
                    Expanded(
                      child: _usersList.isEmpty
                          ? Center(
                              child: Text(
                                'Активность отсутствует',
                                style: GoogleFonts.inter(color: Colors.white24),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _usersList.length,
                              itemBuilder: (context, index) {
                                final user = _usersList[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.01),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['email'] as String,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user['countersSummary'] as String,
                                              style: GoogleFonts.inter(
                                                color: AppColors.gold.withOpacity(0.8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatDateTime(user['savedAt'] as DateTime?),
                                        style: GoogleFonts.inter(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
