class Intervention {
  final String id;
  final String? contractId;
  final String? siteId;
  final String? siteName;
  final String? siteAddress;
  final String? clientName;
  final String scheduledDate;
  final String? scheduledStartTime;
  final String? scheduledEndTime;
  final String? actualStartTime;
  final String? actualEndTime;
  final InterventionStatus status;
  final String? notes;
  final List<String> photoUrls;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? createdAt;

  Intervention({
    required this.id,
    this.contractId,
    this.siteId,
    this.siteName,
    this.siteAddress,
    this.clientName,
    required this.scheduledDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.actualStartTime,
    this.actualEndTime,
    required this.status,
    this.notes,
    this.photoUrls = const [],
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.createdAt,
  });

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      id: json['id'] ?? '',
      contractId: json['contractId'],
      siteId: json['siteId'],
      siteName: json['site']?['name'] ?? json['siteName'],
      siteAddress: json['site']?['address'] ?? json['siteAddress'],
      clientName: json['contract']?['client']?['companyName'] ?? json['clientName'],
      scheduledDate: json['scheduledDate'] ?? '',
      scheduledStartTime: json['scheduledStartTime'],
      scheduledEndTime: json['scheduledEndTime'],
      actualStartTime: json['actualStartTime'],
      actualEndTime: json['actualEndTime'],
      status: InterventionStatus.fromString(json['status'] ?? 'SCHEDULED'),
      notes: json['notes'],
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      checkInLatitude: _parseDouble(json['gpsCheckInLat'] ?? json['checkInLatitude']),
      checkInLongitude: _parseDouble(json['gpsCheckInLng'] ?? json['checkInLongitude']),
      checkOutLatitude: _parseDouble(json['gpsCheckOutLat'] ?? json['checkOutLatitude']),
      checkOutLongitude: _parseDouble(json['gpsCheckOutLng'] ?? json['checkOutLongitude']),
      createdAt: json['createdAt'],
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

enum InterventionStatus {
  scheduled('SCHEDULED'),
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  rescheduled('RESCHEDULED');

  final String value;
  const InterventionStatus(this.value);

  static InterventionStatus fromString(String value) {
    return InterventionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InterventionStatus.scheduled,
    );
  }

  String get label {
    switch (this) {
      case InterventionStatus.scheduled:
        return 'Planifiée';
      case InterventionStatus.inProgress:
        return 'En cours';
      case InterventionStatus.completed:
        return 'Terminée';
      case InterventionStatus.cancelled:
        return 'Annulée';
      case InterventionStatus.rescheduled:
        return 'Reprogrammée';
    }
  }
}
