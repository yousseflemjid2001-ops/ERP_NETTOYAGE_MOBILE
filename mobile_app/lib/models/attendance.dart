class Attendance {
  final String id;
  final String userId;
  final String clockIn;
  final String? clockOut;
  final double? hoursWorked;
  final String? notes;
  final String? status;
  final double? breakMinutes;
  final String? createdAt;

  Attendance({
    required this.id,
    required this.userId,
    required this.clockIn,
    this.clockOut,
    this.hoursWorked,
    this.notes,
    this.status,
    this.breakMinutes,
    this.createdAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      clockIn: json['clockIn'] ?? '',
      clockOut: json['clockOut'],
      hoursWorked: json['hoursWorked']?.toDouble(),
      notes: json['notes'],
      status: json['status'],
      breakMinutes: json['breakMinutes']?.toDouble(),
      createdAt: json['createdAt'],
    );
  }
}

class ShiftStatus {
  final bool isOnShift;
  final Attendance? currentShift;

  ShiftStatus({
    required this.isOnShift,
    this.currentShift,
  });

  factory ShiftStatus.fromJson(Map<String, dynamic> json) {
    return ShiftStatus(
      isOnShift: json['isOnShift'] ?? false,
      currentShift: json['currentShift'] != null
          ? Attendance.fromJson(json['currentShift'])
          : null,
    );
  }
}

class DailySummary {
  final String date;
  final int totalShifts;
  final double totalHoursWorked;
  final double totalBreakMinutes;
  final double netWorkMinutes;
  final List<Attendance> shifts;
  final String currentStatus;

  DailySummary({
    required this.date,
    required this.totalShifts,
    required this.totalHoursWorked,
    required this.totalBreakMinutes,
    required this.netWorkMinutes,
    required this.shifts,
    required this.currentStatus,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      date: json['date'] ?? '',
      totalShifts: json['totalShifts'] ?? 0,
      totalHoursWorked: (json['totalHoursWorked'] ?? 0).toDouble(),
      totalBreakMinutes: (json['totalBreakMinutes'] ?? 0).toDouble(),
      netWorkMinutes: (json['netWorkMinutes'] ?? 0).toDouble(),
      shifts: (json['shifts'] as List<dynamic>?)
              ?.map((e) => Attendance.fromJson(e))
              .toList() ??
          [],
      currentStatus: json['currentStatus'] ?? 'off',
    );
  }
}
