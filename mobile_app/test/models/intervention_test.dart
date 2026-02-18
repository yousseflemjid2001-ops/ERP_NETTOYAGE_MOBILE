import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/intervention.dart';

void main() {
  group('Intervention model', () {
    // ----------------------------------------
    // fromJson parsing
    // ----------------------------------------
    group('fromJson', () {
      test('parses all required fields correctly', () {
        final json = {
          'id': 'intervention-uuid-123',
          'scheduledDate': '2026-02-18',
          'status': 'SCHEDULED',
          'scheduledStartTime': '08:00',
          'scheduledEndTime': '12:00',
          'notes': 'Test intervention',
        };

        final intervention = Intervention.fromJson(json);

        expect(intervention.id, equals('intervention-uuid-123'));
        expect(intervention.scheduledDate, equals('2026-02-18'));
        expect(intervention.status, equals(InterventionStatus.scheduled));
        expect(intervention.notes, equals('Test intervention'));
      });

      test('parses nested site info', () {
        final json = {
          'id': 'test-id',
          'scheduledDate': '2026-02-18',
          'status': 'IN_PROGRESS',
          'site': {
            'name': 'Bureau Paris 8',
            'address': '1 Avenue Montaigne, 75008 Paris',
          },
          'contract': {
            'client': {'companyName': 'ACME Corp'},
          },
        };

        final intervention = Intervention.fromJson(json);

        expect(intervention.siteName, equals('Bureau Paris 8'));
        expect(
          intervention.siteAddress,
          equals('1 Avenue Montaigne, 75008 Paris'),
        );
        expect(intervention.clientName, equals('ACME Corp'));
        expect(intervention.status, equals(InterventionStatus.inProgress));
      });

      test('parses GPS coordinates as doubles', () {
        final json = {
          'id': 'gps-test',
          'scheduledDate': '2026-02-18',
          'status': 'COMPLETED',
          'gpsCheckInLat': 48.8566,
          'gpsCheckInLng': 2.3522,
          'gpsCheckOutLat': '48.8570',
          'gpsCheckOutLng': '2.3530',
        };

        final intervention = Intervention.fromJson(json);

        expect(intervention.checkInLatitude, closeTo(48.8566, 0.0001));
        expect(intervention.checkInLongitude, closeTo(2.3522, 0.0001));
        expect(intervention.checkOutLatitude, closeTo(48.8570, 0.0001));
        expect(intervention.checkOutLongitude, closeTo(2.3530, 0.0001));
      });

      test('handles null GPS coordinates gracefully', () {
        final json = {
          'id': 'no-gps',
          'scheduledDate': '2026-02-18',
          'status': 'SCHEDULED',
        };

        final intervention = Intervention.fromJson(json);

        expect(intervention.checkInLatitude, isNull);
        expect(intervention.checkInLongitude, isNull);
        expect(intervention.checkOutLatitude, isNull);
        expect(intervention.checkOutLongitude, isNull);
      });

      test('parses photo URLs list', () {
        final json = {
          'id': 'photos-test',
          'scheduledDate': '2026-02-18',
          'status': 'COMPLETED',
          'photoUrls': [
            'https://example.com/photo1.jpg',
            'https://example.com/photo2.jpg',
          ],
        };

        final intervention = Intervention.fromJson(json);

        expect(intervention.photoUrls.length, equals(2));
        expect(
          intervention.photoUrls.first,
          equals('https://example.com/photo1.jpg'),
        );
      });

      test('defaults photoUrls to empty list when absent', () {
        final json = {
          'id': 'no-photos',
          'scheduledDate': '2026-02-18',
          'status': 'SCHEDULED',
        };

        final intervention = Intervention.fromJson(json);
        expect(intervention.photoUrls, isEmpty);
      });
    });

    // ----------------------------------------
    // InterventionStatus
    // ----------------------------------------
    group('InterventionStatus', () {
      test('fromString maps all valid values', () {
        expect(
          InterventionStatus.fromString('SCHEDULED'),
          equals(InterventionStatus.scheduled),
        );
        expect(
          InterventionStatus.fromString('IN_PROGRESS'),
          equals(InterventionStatus.inProgress),
        );
        expect(
          InterventionStatus.fromString('COMPLETED'),
          equals(InterventionStatus.completed),
        );
        expect(
          InterventionStatus.fromString('CANCELLED'),
          equals(InterventionStatus.cancelled),
        );
        expect(
          InterventionStatus.fromString('RESCHEDULED'),
          equals(InterventionStatus.rescheduled),
        );
      });

      test('fromString falls back to scheduled for unknown value', () {
        expect(
          InterventionStatus.fromString('UNKNOWN'),
          equals(InterventionStatus.scheduled),
        );
        expect(
          InterventionStatus.fromString(''),
          equals(InterventionStatus.scheduled),
        );
      });

      test('label returns French display text', () {
        expect(InterventionStatus.scheduled.label, equals('Planifiée'));
        expect(InterventionStatus.inProgress.label, equals('En cours'));
        expect(InterventionStatus.completed.label, equals('Terminée'));
        expect(InterventionStatus.cancelled.label, equals('Annulée'));
      });
    });
  });
}
