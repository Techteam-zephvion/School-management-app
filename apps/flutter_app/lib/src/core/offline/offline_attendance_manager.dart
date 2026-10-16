import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart';

class OfflineAttendanceRecordItem {
  const OfflineAttendanceRecordItem({
    required this.studentId,
    required this.status,
    this.remarks,
  });

  final String studentId;
  final String status;
  final String? remarks;

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'status': status,
        if (remarks != null) 'remarks': remarks,
      };

  factory OfflineAttendanceRecordItem.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceRecordItem(
      studentId: json['studentId'] as String,
      status: json['status'] as String,
      remarks: json['remarks'] as String?,
    );
  }
}

class OfflineAttendanceBatch {
  const OfflineAttendanceBatch({
    required this.clientBatchId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    this.subjectId,
    required this.kind,
    required this.attendanceDate,
    this.periodNumber,
    required this.clientTimestamp,
    required this.records,
  });

  final String clientBatchId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String? subjectId;
  final String kind;
  final String attendanceDate;
  final int? periodNumber;
  final String clientTimestamp;
  final List<OfflineAttendanceRecordItem> records;

  Map<String, Object?> toJson() => {
        'clientBatchId': clientBatchId,
        'academicYearId': academicYearId,
        'classId': classId,
        'sectionId': sectionId,
        'subjectId': subjectId,
        'kind': kind,
        'attendanceDate': attendanceDate,
        'periodNumber': periodNumber,
        'clientTimestamp': clientTimestamp,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory OfflineAttendanceBatch.fromJson(Map<String, dynamic> json) {
    final recList = (json['records'] as List<dynamic>?) ?? const [];
    return OfflineAttendanceBatch(
      clientBatchId: json['clientBatchId'] as String,
      academicYearId: json['academicYearId'] as String,
      classId: json['classId'] as String,
      sectionId: json['sectionId'] as String,
      subjectId: json['subjectId'] as String?,
      kind: json['kind'] as String,
      attendanceDate: json['attendanceDate'] as String,
      periodNumber: json['periodNumber'] as int?,
      clientTimestamp: json['clientTimestamp'] as String? ?? DateTime.now().toIso8601String(),
      records: recList
          .map((r) => OfflineAttendanceRecordItem.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OfflineAttendanceNotifier extends Notifier<List<OfflineAttendanceBatch>> {
  static const _storageKey = 'schoolic_offline_attendance_queue';

  @override
  List<OfflineAttendanceBatch> build() {
    _loadQueue();
    return const [];
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        state = decoded
            .map((item) => OfflineAttendanceBatch.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _persist(List<OfflineAttendanceBatch> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(list.map((b) => b.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {}
  }

  Future<void> enqueueBatch(OfflineAttendanceBatch batch) async {
    final updated = [...state, batch];
    state = updated;
    await _persist(updated);
  }

  Future<void> removeBatch(String clientBatchId) async {
    final updated = state.where((b) => b.clientBatchId != clientBatchId).toList();
    state = updated;
    await _persist(updated);
  }

  Future<void> clearQueue() async {
    state = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  Future<Map<String, Object?>> syncAll({
    required ApiClient api,
    required AuthSession session,
  }) async {
    if (state.isEmpty) {
      return {'syncedCount': 0, 'totalBatches': 0, 'success': true};
    }

    final batchesPayload = state.map((b) => b.toJson()).toList();
    try {
      final result = await api.syncOfflineAttendance(batchesPayload, session: session);
      final syncedCount = result['totalSynced'] as int? ?? 0;
      final conflicts = result['totalConflicts'] as int? ?? 0;

      // Clear synced batches
      await clearQueue();

      return {
        'syncedCount': syncedCount,
        'totalBatches': batchesPayload.length,
        'conflictCount': conflicts,
        'success': true,
      };
    } catch (e) {
      return {
        'syncedCount': 0,
        'totalBatches': state.length,
        'error': e.toString(),
        'success': false,
      };
    }
  }
}

final offlineAttendanceProvider =
    NotifierProvider<OfflineAttendanceNotifier, List<OfflineAttendanceBatch>>(
  OfflineAttendanceNotifier.new,
);

final pendingOfflineCountProvider = Provider<int>((ref) {
  return ref.watch(offlineAttendanceProvider).length;
});
