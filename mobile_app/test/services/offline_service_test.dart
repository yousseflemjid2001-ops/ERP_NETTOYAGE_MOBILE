import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/offline_service.dart';

void main() {
  group('OfflineService', () {
    late OfflineService service;

    setUp(() {
      service = OfflineService();
    });

    // ----------------------------------------
    // OfflineAction serialization
    // ----------------------------------------
    group('OfflineAction serialization', () {
      test('toJson / fromJson round-trip', () {
        final action = OfflineAction(
          id: 'test-uuid-123',
          type: 'checkIn',
          payload: {'missionId': 'mission-1', 'lat': 48.8566, 'lng': 2.3522},
        );

        final json = action.toJson();
        final restored = OfflineAction.fromJson(json);

        expect(restored.id, equals(action.id));
        expect(restored.type, equals(action.type));
        expect(restored.payload['missionId'], equals('mission-1'));
        expect(restored.payload['lat'], equals(48.8566));
        expect(restored.retryCount, equals(0));
      });

      test('retryCount persists in JSON', () {
        final action = OfflineAction(
          id: 'retry-test',
          type: 'clockIn',
          payload: {},
          retryCount: 3,
        );

        final restored = OfflineAction.fromJson(action.toJson());
        expect(restored.retryCount, equals(3));
      });

      test('createdAt persists in JSON', () {
        final date = DateTime(2026, 2, 18, 10, 30, 0);
        final action = OfflineAction(
          id: 'date-test',
          type: 'clockOut',
          payload: {},
          createdAt: date,
        );

        final restored = OfflineAction.fromJson(action.toJson());
        expect(restored.createdAt.year, equals(2026));
        expect(restored.createdAt.month, equals(2));
        expect(restored.createdAt.day, equals(18));
      });
    });

    // ----------------------------------------
    // SyncResult
    // ----------------------------------------
    group('SyncResult', () {
      test('hasSync is true when synced > 0', () {
        final result = SyncResult(synced: 3, failed: 0);
        expect(result.hasSync, isTrue);
        expect(result.hasFailures, isFalse);
      });

      test('hasFailures is true when failed > 0', () {
        final result = SyncResult(synced: 0, failed: 2);
        expect(result.hasFailures, isTrue);
        expect(result.hasSync, isFalse);
      });

      test('toString shows both counts', () {
        final result = SyncResult(synced: 5, failed: 1);
        expect(result.toString(), contains('5'));
        expect(result.toString(), contains('1'));
      });
    });
  });
}
