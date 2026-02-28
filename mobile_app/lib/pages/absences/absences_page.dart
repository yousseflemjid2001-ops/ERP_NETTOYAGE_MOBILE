import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../models/absence.dart';
import '../../config/theme.dart';

class AbsencesPage extends StatefulWidget {
  const AbsencesPage({super.key});

  @override
  State<AbsencesPage> createState() => AbsencesPageState();
}

class AbsencesPageState extends State<AbsencesPage>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();
  bool _isLoading = true;
  List<Absence> _absences = [];
  AbsenceBalance? _balance;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreFromCache();
    _loadData();
    // Auto-refresh every 30 seconds
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  /// Called externally when user switches to this tab.
  void refresh() {
    _silentRefresh();
  }

  /// Instantly populate fields from cache.
  void _restoreFromCache() {
    final cachedAbsences = _cache.get<List<Absence>>(CacheService.absencesList);
    final cachedBalance = _cache.get<AbsenceBalance>(
      CacheService.absencesBalance,
    );
    if (cachedAbsences != null) {
      _absences = cachedAbsences;
      _balance = cachedBalance;
      _isLoading = false;
    }
  }

  /// Silent refresh without showing loading spinner (used by timer).
  Future<void> _silentRefresh() async {
    final user = context.read<AuthProvider>().user;
    try {
      final absences = await _api.getMyAbsences(agentId: user?.id);
      _cache.put(CacheService.absencesList, absences);
      AbsenceBalance? balance;
      if (user != null) {
        try {
          balance = await _api.getAbsenceBalance(user.id);
          _cache.put(CacheService.absencesBalance, balance);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _absences = absences;
          if (balance != null) _balance = balance;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (_isLoading) setState(() {});
    final user = context.read<AuthProvider>().user;

    try {
      _absences = await _api.getMyAbsences(agentId: user?.id);
      _cache.put(CacheService.absencesList, _absences);
    } catch (_) {}

    try {
      if (user != null) {
        _balance = await _api.getAbsenceBalance(user.id);
        _cache.put(CacheService.absencesBalance, _balance!);
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Absences')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAbsenceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Demander'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    if (_balance != null) _buildBalanceCard(),
                    const SizedBox(height: 24),

                    // Absences List
                    const Text(
                      'Mes demandes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_absences.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 64,
                                color: AppTheme.textSecondary.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune demande d\'absence',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._absences.map(_buildAbsenceCard),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Solde de congés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceItem(
                  '${_balance!.vacationDaysRemaining}',
                  'Restants',
                  AppTheme.secondaryColor,
                ),
                _buildBalanceItem(
                  '${_balance!.vacationDaysUsed}',
                  'Utilisés',
                  AppTheme.warningColor,
                ),
                _buildBalanceItem(
                  '${_balance!.vacationDaysAllocated}',
                  'Total',
                  AppTheme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _balance!.vacationDaysAllocated > 0
                    ? _balance!.vacationDaysUsed /
                          _balance!.vacationDaysAllocated
                    : 0,
                backgroundColor: AppTheme.borderColor,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAbsenceCard(Absence absence) {
    final statusColor = _getStatusColor(absence.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  absence.absenceType.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        absence.absenceType.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_formatDate(absence.startDate)} → ${_formatDate(absence.endDate)}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    absence.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (absence.reason != null && absence.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                absence.reason!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${absence.totalDays} jour(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (absence.status == AbsenceStatus.pending) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => _cancelAbsence(absence),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AbsenceStatus status) {
    switch (status) {
      case AbsenceStatus.pending:
        return AppTheme.warningColor;
      case AbsenceStatus.approved:
        return AppTheme.secondaryColor;
      case AbsenceStatus.rejected:
        return AppTheme.errorColor;
      case AbsenceStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return date;
    }
  }

  Future<void> _cancelAbsence(Absence absence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette demande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.cancelAbsence(absence.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande annulée'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _showCreateAbsenceDialog() {
    AbsenceType? selectedType;
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nouvelle demande d\'absence',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Absence Type
                  const Text(
                    'Type d\'absence',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AbsenceType.values.map((type) {
                      final isSelected = selectedType == type;
                      return ChoiceChip(
                        label: Text('${type.icon} ${type.label}'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {
                            selectedType = selected ? type : null;
                          });
                        },
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date début',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                startDate = picked;
                                startDateController.text =
                                    '${picked.day}/${picked.month}/${picked.year}';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date fin',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                endDate = picked;
                                endDateController.text =
                                    '${picked.day}/${picked.month}/${picked.year}';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motif (optionnel)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          !isSubmitting &&
                              selectedType != null &&
                              startDate != null &&
                              endDate != null
                          ? () {
                              setSheetState(() => isSubmitting = true);
                              _submitAbsence(
                                selectedType!,
                                startDate!,
                                endDate!,
                                reasonController.text,
                              ).whenComplete(() {
                                if (context.mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              });
                            }
                          : null,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Soumettre la demande'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitAbsence(
    AbsenceType type,
    DateTime startDate,
    DateTime endDate,
    String reason,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      await _api.createAbsence(
        agentId: user.id,
        absenceType: type.value,
        startDate:
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        endDate:
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        reason: reason.isNotEmpty ? reason : null,
      );

      if (mounted) {
        Navigator.pop(context);
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande soumise avec succès !'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
