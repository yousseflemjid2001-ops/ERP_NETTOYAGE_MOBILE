class Absence {
  final String id;
  final String agentId;
  final AbsenceType absenceType;
  final String startDate;
  final String endDate;
  final int totalDays;
  final String? reason;
  final AbsenceStatus status;
  final String? requestedAt;
  final String? reviewedAt;
  final String? reviewNotes;
  final String? createdAt;

  Absence({
    required this.id,
    required this.agentId,
    required this.absenceType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.reason,
    required this.status,
    this.requestedAt,
    this.reviewedAt,
    this.reviewNotes,
    this.createdAt,
  });

  factory Absence.fromJson(Map<String, dynamic> json) {
    return Absence(
      id: json['id'] ?? '',
      agentId: json['agentId'] ?? '',
      absenceType: AbsenceType.fromString(json['absenceType'] ?? 'VACATION'),
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      totalDays: json['totalDays'] ?? 0,
      reason: json['reason'],
      status: AbsenceStatus.fromString(json['status'] ?? 'PENDING'),
      requestedAt: json['requestedAt'],
      reviewedAt: json['reviewedAt'],
      reviewNotes: json['reviewNotes'],
      createdAt: json['createdAt'],
    );
  }
}

class AbsenceBalance {
  final int year;
  final int vacationDaysAllocated;
  final int vacationDaysUsed;
  final int vacationDaysRemaining;
  final int sickDaysUsed;
  final int unpaidDaysUsed;
  final int authorizedDaysUsed;

  AbsenceBalance({
    required this.year,
    required this.vacationDaysAllocated,
    required this.vacationDaysUsed,
    required this.vacationDaysRemaining,
    required this.sickDaysUsed,
    required this.unpaidDaysUsed,
    required this.authorizedDaysUsed,
  });

  factory AbsenceBalance.fromJson(Map<String, dynamic> json) {
    return AbsenceBalance(
      year: json['year'] ?? 0,
      vacationDaysAllocated: json['vacationDaysAllocated'] ?? 0,
      vacationDaysUsed: json['vacationDaysUsed'] ?? 0,
      vacationDaysRemaining: json['vacationDaysRemaining'] ?? 0,
      sickDaysUsed: json['sickDaysUsed'] ?? 0,
      unpaidDaysUsed: json['unpaidDaysUsed'] ?? 0,
      authorizedDaysUsed: json['authorizedDaysUsed'] ?? 0,
    );
  }
}

enum AbsenceType {
  vacation('VACATION'),
  sickLeave('SICK_LEAVE'),
  unpaid('UNPAID'),
  authorized('AUTHORIZED');

  final String value;
  const AbsenceType(this.value);

  static AbsenceType fromString(String value) {
    return AbsenceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AbsenceType.vacation,
    );
  }

  String get label {
    switch (this) {
      case AbsenceType.vacation:
        return 'Congé';
      case AbsenceType.sickLeave:
        return 'Maladie';
      case AbsenceType.unpaid:
        return 'Sans solde';
      case AbsenceType.authorized:
        return 'Autorisée';
    }
  }

  String get icon {
    switch (this) {
      case AbsenceType.vacation:
        return '🏖️';
      case AbsenceType.sickLeave:
        return '🏥';
      case AbsenceType.unpaid:
        return '📅';
      case AbsenceType.authorized:
        return '✅';
    }
  }
}

enum AbsenceStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  final String value;
  const AbsenceStatus(this.value);

  static AbsenceStatus fromString(String value) {
    return AbsenceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AbsenceStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case AbsenceStatus.pending:
        return 'En attente';
      case AbsenceStatus.approved:
        return 'Approuvée';
      case AbsenceStatus.rejected:
        return 'Refusée';
      case AbsenceStatus.cancelled:
        return 'Annulée';
    }
  }
}
