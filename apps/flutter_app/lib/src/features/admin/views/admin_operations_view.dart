import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminOperationsView extends ConsumerStatefulWidget {
  const AdminOperationsView({
    required this.students,
    required this.staff,
    required this.classes,
    required this.sections,
    super.key,
  });

  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> staff;
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> sections;

  @override
  ConsumerState<AdminOperationsView> createState() =>
      _AdminOperationsViewState();
}

class _AdminOperationsViewState extends ConsumerState<AdminOperationsView> {
  int _tabIndex =
      0; // 0 = Leaves, 1 = Transport, 2 = Certificates, 3 = Calendar & PTM
  bool _loading = false;
  String? _error;
  String? _success;

  // 1. Leaves Data
  int _leaveSubTab = 0; // 0 = Student Leaves, 1 = Staff Leaves
  String _leaveStatusFilter = 'all';
  List<Map<String, Object?>> _studentLeaves = [];
  List<Map<String, Object?>> _staffLeaves = [];

  // 2. Transport Data
  int _transportSubTab = 0; // 0 = Routes & Stops, 1 = Vehicles & Drivers, 2 = Bus Passes, 3 = Trip Logs
  List<Map<String, Object?>> _routes = [];
  List<Map<String, Object?>> _vehicles = [];
  List<Map<String, Object?>> _drivers = [];
  List<Map<String, Object?>> _allocations = [];
  List<Map<String, Object?>> _logs = [];

  // 3. Certificates Data
  String _certTypeFilter = 'all';
  List<Map<String, Object?>> _certificates = [];

  // 4. Calendar & PTM Data
  List<Map<String, Object?>> _calendarEvents = [];
  List<Map<String, Object?>> _ptmSchedules = [];
  List<Map<String, Object?>> _ptmSlots = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentTabData();
  }

  Future<void> _loadCurrentTabData() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      switch (_tabIndex) {
        case 0:
          final sLeaves = await api.getStudentLeaves(
            session: session,
            status: _leaveStatusFilter == 'all' ? null : _leaveStatusFilter,
          );
          final stLeaves = await api.getStaffLeaves(
            session: session,
            status: _leaveStatusFilter == 'all' ? null : _leaveStatusFilter,
          );
          if (mounted) {
            setState(() {
              _studentLeaves = sLeaves;
              _staffLeaves = stLeaves;
            });
          }
          break;

        case 1:
          final routes = await api.getTransportRoutes(session: session);
          final vehicles = await api.getTransportVehicles(session: session);
          final drivers = await api.getTransportDrivers(session: session);
          final allocs = await api.getTransportAllocations(session: session);
          final logs = await api.getTransportLogs(session: session);
          if (mounted) {
            setState(() {
              _routes = routes;
              _vehicles = vehicles;
              _drivers = drivers;
              _allocations = allocs;
              _logs = logs;
            });
          }
          break;

        case 2:
          final certs = await api.getCertificates(
            session: session,
            certificateType: _certTypeFilter == 'all' ? null : _certTypeFilter,
          );
          if (mounted) {
            setState(() {
              _certificates = certs;
            });
          }
          break;

        case 3:
          final events = await api.getCalendarEvents(session: session);
          final schedules = await api.getPtmSchedules(session: session);
          final slots = await api.getPtmSlots(session: session);
          if (mounted) {
            setState(() {
              _calendarEvents = events;
              _ptmSchedules = schedules;
              _ptmSlots = slots;
            });
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load operations data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // --- Leave Actions ---
  Future<void> _reviewStudentLeaveDialog(Map<String, Object?> leave) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final notesCtrl = TextEditingController();
    String targetStatus = 'approved';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Review Student Leave',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: targetStatus == 'approved'
                    ? AppColors.statusSuccess
                    : AppColors.statusError,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .reviewStudentLeave(
                        session: session,
                        leaveId: leave['id'] as String,
                        status: targetStatus,
                        reviewerNotes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                  setState(() => _success = 'Student leave status updated.');
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to review leave: $e');
                }
              },
              child: Text(targetStatus == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${leave['studentName']} (${leave['admissionNumber']})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Duration: ${leave['startDate']} to ${leave['endDate']}'),
              const SizedBox(height: 6),
              Text('Reason: ${leave['reason']}'),
              if (leave['documentUrl'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Attachment: ${leave['documentUrl']}',
                  style: const TextStyle(color: AppColors.statusInfo),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: targetStatus,
                decoration: const InputDecoration(labelText: 'Decision'),
                items: const [
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approve Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Reject Leave'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => targetStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reviewer Notes (Optional)',
                  hintText: 'e.g. Medical prescription verified',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reviewStaffLeaveDialog(Map<String, Object?> leave) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final notesCtrl = TextEditingController();
    String targetStatus = 'approved';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Review Staff Leave',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: targetStatus == 'approved'
                    ? AppColors.statusSuccess
                    : AppColors.statusError,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .reviewStaffLeave(
                        session: session,
                        leaveId: leave['id'] as String,
                        status: targetStatus,
                        reviewerNotes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                  setState(() => _success = 'Staff leave status updated.');
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to review leave: $e');
                }
              },
              child: Text(targetStatus == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff: ${leave['staffName']} (${leave['staffCode'] ?? 'Staff'})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Type: ${leave['leaveType']?.toString().toUpperCase()}'),
              Text('Dates: ${leave['startDate']} to ${leave['endDate']}'),
              const SizedBox(height: 6),
              Text('Reason: ${leave['reason']}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: targetStatus,
                decoration: const InputDecoration(labelText: 'Decision'),
                items: const [
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approve Leave'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Reject Leave'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => targetStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Administrative remarks',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewSubstitutesModal(Map<String, Object?> leave) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<List<Map<String, Object?>>>(
        future: ref
            .read(apiClientProvider)
            .getStaffLeaveSubstitutes(
              session: session,
              leaveId: leave['id'] as String,
            ),
        builder: (ctx, snapshot) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timetable Substitute Suggestion Engine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Coverage for ${leave['staffName']} (${leave['startDate']} to ${leave['endDate']})',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Failed to calculate substitutes: ${snapshot.error}',
                      ),
                    ),
                  )
                else if (snapshot.data == null || snapshot.data!.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No teaching timetable periods require substitution for this staff leave.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final period = snapshot.data![idx];
                        final teachers =
                            (period['availableSubstitutes'] as List?) ?? [];
                        final assignment = period['assignment'] as Map?;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppColors.primaryBorder,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Period ${period['periodNumber']}: ${period['startTime']} - ${period['endTime']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Day ${period['dayOfWeek']}',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${period['className']} ${period['sectionName']} | Subject: ${period['subjectName']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (assignment != null) ...[
                                  StatusBadge(
                                    label:
                                        'Assigned: ${assignment['substituteName'] ?? 'Teacher'} · notified',
                                    tone: BadgeTone.success,
                                    icon: Icons.notifications_active_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                const Text(
                                  'Available Free Teachers:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (teachers.isEmpty)
                                  const Text(
                                    'No free teachers found for this slot.',
                                    style: TextStyle(
                                      color: AppColors.statusError,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: teachers.map<Widget>((t) {
                                      final teacher = t as Map<String, Object?>;
                                      return ActionChip(
                                        avatar: const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${teacher['fullName']} (${teacher['staffCode'] ?? 'Staff'})',
                                        ),
                                        tooltip:
                                            'Assign and notify this teacher',
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(apiClientProvider)
                                                .assignStaffLeaveSubstitute(
                                                  session: session,
                                                  leaveId:
                                                      leave['id'] as String,
                                                  timetableEntryId:
                                                      period['lessonId']
                                                          as String,
                                                  substituteStaffId:
                                                      teacher['id'] as String,
                                                );
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              setState(
                                                () => _success =
                                                    '${teacher['fullName']} assigned and notified.',
                                              );
                                              await _viewSubstitutesModal(
                                                leave,
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted)
                                              setState(
                                                () => _error =
                                                    'Could not assign substitute: $e',
                                              );
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Transport Actions ---
  Future<void> _createRouteDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final routeNumCtrl = TextEditingController();
    final routeNameCtrl = TextEditingController();
    final startPtCtrl = TextEditingController();
    final endPtCtrl = TextEditingController();
    String? selectedVehicleId;
    String? selectedDriverId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Add Transport Route',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (routeNumCtrl.text.isEmpty || routeNameCtrl.text.isEmpty)
                  return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .createTransportRoute(
                        session: session,
                        routeNumber: routeNumCtrl.text.trim(),
                        routeName: routeNameCtrl.text.trim(),
                        startPoint: startPtCtrl.text.trim(),
                        endPoint: endPtCtrl.text.trim(),
                        vehicleId: selectedVehicleId,
                        driverId: selectedDriverId,
                      );
                  setState(
                    () => _success = 'Transport route created successfully.',
                  );
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to create route: $e');
                }
              },
              child: const Text('Create Route'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: routeNumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route Number (e.g. R-01)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: routeNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route Name (e.g. North Corridor)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: startPtCtrl,
                decoration: const InputDecoration(labelText: 'Start Point'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endPtCtrl,
                decoration: const InputDecoration(labelText: 'End Point'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Assigned Vehicle',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Vehicle Assigned'),
                  ),
                  ..._vehicles.map(
                    (v) => DropdownMenuItem(
                      value: v['id'] as String,
                      child: Text('${v['vehicleNumber']} (${v['model']})'),
                    ),
                  ),
                ],
                onChanged: (val) => setDlgState(() => selectedVehicleId = val),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedDriverId,
                decoration: const InputDecoration(labelText: 'Assigned Driver'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Driver Assigned'),
                  ),
                  ..._drivers.map(
                    (d) => DropdownMenuItem(
                      value: d['id'] as String,
                      child: Text('${d['fullName']} (${d['phone']})'),
                    ),
                  ),
                ],
                onChanged: (val) => setDlgState(() => selectedDriverId = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createStopDialog(Map<String, Object?> route) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final nameCtrl = TextEditingController();
    final pickupCtrl = TextEditingController(text: '07:30');
    final dropCtrl = TextEditingController(text: '15:30');
    final feeCtrl = TextEditingController(text: '1500');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Add Stop to ${route['routeNumber']}',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(apiClientProvider)
                    .createTransportStop(
                      session: session,
                      routeId: route['id'] as String,
                      stopName: nameCtrl.text.trim(),
                      pickupTime: pickupCtrl.text.trim(),
                      dropTime: dropCtrl.text.trim(),
                      monthlyFeeAmount: int.tryParse(feeCtrl.text.trim()) ?? 0,
                    );
                setState(() => _success = 'Stop added to route.');
                _loadCurrentTabData();
              } catch (e) {
                setState(() => _error = 'Failed to add stop: $e');
              }
            },
            child: const Text('Add Stop'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Stop Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pickupCtrl,
              decoration: const InputDecoration(
                labelText: 'Pickup Time (HH:MM)',
                hintText: '07:30',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dropCtrl,
              decoration: const InputDecoration(
                labelText: 'Drop Time (HH:MM)',
                hintText: '15:30',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feeCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Fee (INR)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createVehicleDialog() async {
    final number = TextEditingController();
    final model = TextEditingController();
    final capacity = TextEditingController(text: '40');
    final saved = await _simpleFormDialog(
      title: 'Register vehicle',
      submitLabel: 'Register vehicle',
      fields: [
        (number, 'Vehicle number', TextInputType.text),
        (model, 'Model', TextInputType.text),
        (capacity, 'Seat capacity', TextInputType.number),
      ],
    );
    if (!saved) return;
    final session = ref.read(authControllerProvider).session;
    final seats = int.tryParse(capacity.text.trim());
    if (session == null ||
        number.text.trim().isEmpty ||
        model.text.trim().isEmpty ||
        seats == null)
      return;
    try {
      await ref
          .read(apiClientProvider)
          .createTransportVehicle(
            session: session,
            vehicleNumber: number.text.trim(),
            model: model.text.trim(),
            capacity: seats,
          );
      setState(() => _success = 'Vehicle registered.');
      await _loadCurrentTabData();
    } catch (error) {
      setState(() => _error = 'Unable to register vehicle: $error');
    }
  }

  Future<void> _createDriverDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final license = TextEditingController();
    final saved = await _simpleFormDialog(
      title: 'Register driver',
      submitLabel: 'Register driver',
      fields: [
        (name, 'Full name', TextInputType.name),
        (phone, 'Phone number', TextInputType.phone),
        (license, 'Driving licence number', TextInputType.text),
      ],
    );
    if (!saved) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null ||
        name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        license.text.trim().isEmpty)
      return;
    try {
      await ref
          .read(apiClientProvider)
          .createTransportDriver(
            session: session,
            fullName: name.text.trim(),
            phone: phone.text.trim(),
            licenseNumber: license.text.trim(),
          );
      setState(() => _success = 'Driver registered.');
      await _loadCurrentTabData();
    } catch (error) {
      setState(() => _error = 'Unable to register driver: $error');
    }
  }

  Future<void> _createTransportAllocationDialog() async {
    if (widget.students.isEmpty || _routes.isEmpty) return;
    var student = widget.students.first;
    var route = _routes.first;
    List<Map<String, Object?>> stops = const [];
    Map<String, Object?>? stop;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    Future<void> loadStops(StateSetter setDialogState) async {
      final loaded = await ref
          .read(apiClientProvider)
          .getTransportStops(session: session, routeId: route['id'] as String);
      setDialogState(() {
        stops = loaded;
        stop = loaded.isEmpty ? null : loaded.first;
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          if (stops.isEmpty && stop == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => loadStops(setDialogState),
            );
          }
          return AlertDialog(
            title: const Text('Allocate student transport'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, Object?>>(
                    initialValue: student,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: widget.students
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text('${item['fullName']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => student = value ?? student),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, Object?>>(
                    initialValue: route,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: _routes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              '${item['routeNumber']} • ${item['routeName']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      route = value ?? route;
                      stops = const [];
                      stop = null;
                      await loadStops(setDialogState);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, Object?>>(
                    key: ValueKey(route['id']),
                    initialValue: stop,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pickup stop'),
                    items: stops
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text('${item['stopName']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => stop = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: stop == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Allocate transport'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || stop == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .createTransportAllocation(
            session: session,
            studentId: student['id'] as String,
            routeId: route['id'] as String,
            stopId: stop!['id'] as String,
          );
      setState(() => _success = 'Student transport allocated.');
      await _loadCurrentTabData();
    } catch (error) {
      setState(() => _error = 'Unable to allocate transport: $error');
    }
  }

  Future<void> _createTransportLogDialog() async {
    if (_routes.isEmpty) return;
    var route = _routes.first;
    var tripType = 'pickup';
    var status = 'departed';
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Record transport checkpoint'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map<String, Object?>>(
                  initialValue: route,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Route'),
                  items: _routes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item['routeNumber']} • ${item['routeName']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => route = value ?? route),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tripType,
                  decoration: const InputDecoration(labelText: 'Trip type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'pickup',
                      child: Text('Morning pickup'),
                    ),
                    DropdownMenuItem(
                      value: 'drop',
                      child: Text('Afternoon drop'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => tripType = value ?? tripType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'departed',
                      child: Text('Departed'),
                    ),
                    DropdownMenuItem(
                      value: 'in_transit',
                      child: Text('In transit'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(value: 'delayed', child: Text('Delayed')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record checkpoint'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .createTransportLog(
            session: session,
            routeId: route['id'] as String,
            tripType: tripType,
            status: status,
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      setState(() => _success = 'Transport checkpoint recorded.');
      await _loadCurrentTabData();
    } catch (error) {
      setState(() => _error = 'Unable to record checkpoint: $error');
    }
  }

  Future<bool> _simpleFormDialog({
    required String title,
    required String submitLabel,
    required List<(TextEditingController, String, TextInputType)> fields,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 480,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final field in fields) ...[
                    TextField(
                      controller: field.$1,
                      keyboardType: field.$3,
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(submitLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- Certificate Actions ---
  Future<void> _issueCertificateDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    String? selectedStudentId = widget.students.isNotEmpty
        ? widget.students.first['id'] as String?
        : null;
    String certificateType = 'transfer_certificate';
    final reasonCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Issue Official Certificate',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStudentId == null) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .issueCertificate(
                        session: session,
                        studentId: selectedStudentId!,
                        certificateType: certificateType,
                        metadata: reasonCtrl.text.isNotEmpty
                            ? {'reason': reasonCtrl.text.trim()}
                            : null,
                      );
                  setState(
                    () => _success =
                        'Certificate generated with official serial code.',
                  );
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to issue certificate: $e');
                }
              },
              child: const Text('Issue Certificate'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                decoration: const InputDecoration(labelText: 'Student'),
                items: widget.students
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(
                          '${s['fullName']} (${s['admissionNumber']})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setDlgState(() => selectedStudentId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: certificateType,
                decoration: const InputDecoration(
                  labelText: 'Certificate Type',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'transfer_certificate',
                    child: Text('Transfer Certificate (TC)'),
                  ),
                  DropdownMenuItem(
                    value: 'bonafide',
                    child: Text('Bonafide Certificate'),
                  ),
                  DropdownMenuItem(
                    value: 'character_conduct',
                    child: Text('Character & Conduct Certificate'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => certificateType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Reason',
                  hintText: 'e.g. Relocation, Higher education, Passport',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _revokeCertificateDialog(Map<String, Object?> cert) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final reasonCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Revoke Official Certificate',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(apiClientProvider)
                    .revokeCertificate(
                      session: session,
                      certificateId: cert['id'] as String,
                      reason: reasonCtrl.text.trim().isEmpty
                          ? null
                          : reasonCtrl.text.trim(),
                    );
                setState(() => _success = 'Certificate revoked.');
                _loadCurrentTabData();
              } catch (e) {
                setState(() => _error = 'Failed to revoke certificate: $e');
              }
            },
            child: const Text('Revoke'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Certificate Number: ${cert['certificateNumber']}'),
            Text('Student: ${cert['studentName']}'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Revocation Reason',
                hintText: 'e.g. Duplicate issuance, clerical error',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // --- Calendar & PTM Actions ---
  Future<void> _createCalendarEventDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final startCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final endCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    String eventType = 'holiday';
    String targetAudience = 'all';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Add Institutional Calendar Event',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .createCalendarEvent(
                        session: session,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        eventType: eventType,
                        startDate: startCtrl.text.trim(),
                        endDate: endCtrl.text.trim(),
                        targetAudience: targetAudience,
                      );
                  setState(() => _success = 'Calendar event added.');
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to add calendar event: $e');
                }
              },
              child: const Text('Add Event'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: eventType,
                decoration: const InputDecoration(labelText: 'Event Type'),
                items: const [
                  DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                  DropdownMenuItem(value: 'exam', child: Text('Examination')),
                  DropdownMenuItem(
                    value: 'sports',
                    child: Text('Sports Event'),
                  ),
                  DropdownMenuItem(
                    value: 'cultural',
                    child: Text('Cultural Program'),
                  ),
                  DropdownMenuItem(value: 'ptm', child: Text('PTM Conference')),
                  DropdownMenuItem(
                    value: 'meeting',
                    child: Text('Staff Meeting'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => eventType = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'End Date (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: targetAudience,
                decoration: const InputDecoration(labelText: 'Target Audience'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone (All)')),
                  DropdownMenuItem(
                    value: 'students',
                    child: Text('Students Only'),
                  ),
                  DropdownMenuItem(
                    value: 'teachers',
                    child: Text('Teachers Only'),
                  ),
                  DropdownMenuItem(
                    value: 'parents',
                    child: Text('Parents Only'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => targetAudience = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPtmScheduleDialog() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
    );
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '13:00');
    int slotDuration = 15;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AppDialog(
          title: 'Schedule Parent-Teacher Meeting (PTM)',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(apiClientProvider)
                      .createPtmSchedule(
                        session: session,
                        title: titleCtrl.text.trim(),
                        eventDate: dateCtrl.text.trim(),
                        startTime: startCtrl.text.trim(),
                        endTime: endCtrl.text.trim(),
                        slotDurationMinutes: slotDuration,
                      );
                  setState(
                    () => _success =
                        'PTM Schedule created with automated slot generation.',
                  );
                  _loadCurrentTabData();
                } catch (e) {
                  setState(() => _error = 'Failed to create PTM schedule: $e');
                }
              },
              child: const Text('Generate Slots'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'PTM Title',
                  hintText: 'e.g. Term 1 Academic Progress Meet',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meeting Date (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Start Time (HH:MM)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'End Time (HH:MM)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: slotDuration,
                decoration: const InputDecoration(
                  labelText: 'Slot Duration (Minutes)',
                ),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 Minutes')),
                  DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                  DropdownMenuItem(value: 20, child: Text('20 Minutes')),
                  DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => slotDuration = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'School Operations',
          description: 'Student/staff leaves & substitute engine, transport routes & tracking, digital verifiable certificates, and calendar & PTMs.',
          primaryAction: _tabIndex == 1
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route, size: 18),
                  label: const Text('Add Route'),
                  onPressed: _createRouteDialog,
                )
              : _tabIndex == 2
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Issue Certificate'),
                  onPressed: _issueCertificateDialog,
                )
              : _tabIndex == 3
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text('Schedule PTM'),
                  onPressed: _createPtmScheduleDialog,
                )
              : null,
          secondaryActions: _tabIndex == 3
              ? [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text('Add Event'),
                    onPressed: _createCalendarEventDialog,
                  ),
                ]
              : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: FeedbackBanner(
              message: _error!,
              tone: FeedbackTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
          ),
        if (_success != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: FeedbackBanner(
              message: _success!,
              tone: FeedbackTone.success,
              onDismiss: () => setState(() => _success = null),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _buildStatStrip(),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              _buildTabItem(
                'Leaves & Substitutes',
                0,
                Icons.event_busy_outlined,
              ),
              _buildTabItem(
                'Transport Fleet',
                1,
                Icons.directions_bus_outlined,
              ),
              _buildTabItem(
                'Official Certificates',
                2,
                Icons.verified_outlined,
              ),
              _buildTabItem('Calendar & PTM', 3, Icons.calendar_month_outlined),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _buildActiveTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabItem(String label, int index, IconData icon) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _tabIndex = index);
          _loadCurrentTabData();
        },
        borderRadius: AppRadii.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainBackground : Colors.transparent,
            borderRadius: AppRadii.rMd,
            border: isSelected
                ? Border.all(
                    color: AppColors.primaryText.withValues(alpha: 0.2),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatStrip() {
    switch (_tabIndex) {
      case 0:
        final pendingStudent = _studentLeaves
            .where((l) => l['status'] == 'pending')
            .length;
        final pendingStaff = _staffLeaves
            .where((l) => l['status'] == 'pending')
            .length;
        return StatStrip(
          items: [
            StatItemData(
              label: 'Pending Student Leaves',
              value: '$pendingStudent',
              helper: 'Review Needed',
            ),
            StatItemData(
              label: 'Pending Staff Leaves',
              value: '$pendingStaff',
              helper: 'Substitutes Needed',
            ),
            StatItemData(
              label: 'Total Student Leaves',
              value: '${_studentLeaves.length}',
            ),
            StatItemData(
              label: 'Total Staff Leaves',
              value: '${_staffLeaves.length}',
            ),
          ],
        );
      case 1:
        final totalStops = _routes.fold<int>(
          0,
          (acc, r) => acc + ((r['totalStops'] as int?) ?? 0),
        );
        return StatStrip(
          items: [
            StatItemData(
              label: 'Transport Routes',
              value: '${_routes.length}',
              helper: 'Active Corridors',
            ),
            StatItemData(
              label: 'Fleet Vehicles',
              value: '${_vehicles.length}',
              helper: 'Buses & Vans',
            ),
            StatItemData(
              label: 'Registered Drivers',
              value: '${_drivers.length}',
            ),
            StatItemData(
              label: 'Active Bus Passes',
              value: '${_allocations.length}',
            ),
            StatItemData(label: 'Total Stops', value: '$totalStops'),
          ],
        );
      case 2:
        final validCerts = _certificates
            .where((c) => c['status'] == 'valid')
            .length;
        final revokedCerts = _certificates
            .where((c) => c['status'] == 'revoked')
            .length;
        return StatStrip(
          items: [
            StatItemData(
              label: 'Issued Certificates',
              value: '${_certificates.length}',
              helper: 'Verifiable',
            ),
            StatItemData(
              label: 'Valid Certificates',
              value: '$validCerts',
              helper: 'Active Records',
            ),
            StatItemData(
              label: 'Revoked Certificates',
              value: '$revokedCerts',
              helper: 'Cancelled',
            ),
          ],
        );
      case 3:
      default:
        final bookedSlots = _ptmSlots
            .where((s) => s['status'] == 'booked' || s['status'] == 'completed')
            .length;
        return StatStrip(
          items: [
            StatItemData(
              label: 'Calendar Events',
              value: '${_calendarEvents.length}',
              helper: 'Active Terms',
            ),
            StatItemData(
              label: 'PTM Schedules',
              value: '${_ptmSchedules.length}',
            ),
            StatItemData(
              label: 'Total Generated Slots',
              value: '${_ptmSlots.length}',
            ),
            StatItemData(
              label: 'Parent Bookings',
              value: '$bookedSlots',
              helper: 'Reserved',
            ),
          ],
        );
    }
  }

  Widget _buildActiveTabContent() {
    switch (_tabIndex) {
      case 0:
        return _buildLeavesTab();
      case 1:
        return _buildTransportTab();
      case 2:
        return _buildCertificatesTab();
      case 3:
        return _buildCalendarAndPtmTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ================= 1. LEAVES VIEW =================
  Widget _buildLeavesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Student Leaves'),
                    selected: _leaveSubTab == 0,
                    onSelected: (val) {
                      if (val) setState(() => _leaveSubTab = 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Staff Leaves & Substitutes'),
                    selected: _leaveSubTab == 1,
                    onSelected: (val) {
                      if (val) setState(() => _leaveSubTab = 1);
                    },
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _leaveStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Pending Only'),
                  ),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved Only'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Rejected Only'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _leaveStatusFilter = val);
                    _loadCurrentTabData();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _leaveSubTab == 0
              ? _buildStudentLeavesList()
              : _buildStaffLeavesList(),
        ),
      ],
    );
  }

  Widget _buildStudentLeavesList() {
    if (_studentLeaves.isEmpty) {
      return const EmptyStateView(
        title: 'No student leaves found',
        description: 'There are no student leave applications matching the active filters.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _studentLeaves.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final leave = _studentLeaves[idx];
        final status = leave['status'] as String? ?? 'pending';
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primaryBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  child: Text(
                    (leave['studentName'] as String? ?? 'S')[0],
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            leave['studentName'] as String? ?? 'Student',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${leave['admissionNumber'] ?? ''})',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(
                            label: status.toUpperCase(),
                            tone: status == 'approved'
                                ? BadgeTone.success
                                : status == 'rejected'
                                ? BadgeTone.error
                                : BadgeTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dates: ${leave['startDate']} to ${leave['endDate']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${leave['reason']}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      if (leave['reviewerNotes'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reviewer Remark: ${leave['reviewerNotes']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _reviewStudentLeaveDialog(leave),
                    child: const Text('Review'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffLeavesList() {
    if (_staffLeaves.isEmpty) {
      return const EmptyStateView(
        title: 'No staff leaves found',
        description: 'There are no staff leaves matching the current filter.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _staffLeaves.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final leave = _staffLeaves[idx];
        final status = leave['status'] as String? ?? 'pending';
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primaryBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.statusInfo.withValues(alpha: 0.1),
                  child: Text(
                    (leave['staffName'] as String? ?? 'T')[0],
                    style: const TextStyle(
                      color: AppColors.statusInfo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            leave['staffName'] as String? ?? 'Teacher',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primaryBorder,
                              ),
                            ),
                            child: Text(
                              (leave['leaveType'] as String? ?? 'casual')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(
                            label: status.toUpperCase(),
                            tone: status == 'approved'
                                ? BadgeTone.success
                                : status == 'rejected'
                                ? BadgeTone.error
                                : BadgeTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dates: ${leave['startDate']} to ${leave['endDate']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${leave['reason']}',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.people_alt_outlined, size: 16),
                      label: const Text('Substitutes'),
                      onPressed: () => _viewSubstitutesModal(leave),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () => _reviewStaffLeaveDialog(leave),
                        child: const Text('Review'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= 2. TRANSPORT VIEW =================
  Widget _buildTransportTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Routes & Stops'),
                selected: _transportSubTab == 0,
                onSelected: (val) {
                  if (val) setState(() => _transportSubTab = 0);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Vehicles & Drivers'),
                selected: _transportSubTab == 1,
                onSelected: (val) {
                  if (val) setState(() => _transportSubTab = 1);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Student Allocations'),
                selected: _transportSubTab == 2,
                onSelected: (val) {
                  if (val) setState(() => _transportSubTab = 2);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Live Checkpoint Logs'),
                selected: _transportSubTab == 3,
                onSelected: (val) {
                  if (val) setState(() => _transportSubTab = 3);
                },
              ),
              if (_transportSubTab == 0)
                FilledButton.icon(
                  onPressed: _createRouteDialog,
                  icon: const Icon(Icons.add_road, size: 16),
                  label: const Text('Add route'),
                ),
              if (_transportSubTab == 1) ...[
                FilledButton.icon(
                  onPressed: _createVehicleDialog,
                  icon: const Icon(Icons.directions_bus_outlined, size: 16),
                  label: const Text('Register vehicle'),
                ),
                OutlinedButton.icon(
                  onPressed: _createDriverDialog,
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: const Text('Register driver'),
                ),
              ],
              if (_transportSubTab == 2)
                FilledButton.icon(
                  onPressed: _createTransportAllocationDialog,
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Allocate student'),
                ),
              if (_transportSubTab == 3)
                FilledButton.icon(
                  onPressed: _createTransportLogDialog,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                  label: const Text('Record checkpoint'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _transportSubTab == 0
              ? _buildRoutesList()
              : _transportSubTab == 1
              ? _buildVehiclesAndDriversList()
              : _transportSubTab == 2
              ? _buildAllocationsList()
              : _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildRoutesList() {
    if (_routes.isEmpty) {
      return const EmptyStateView(
        title: 'No transport routes configured',
        description:
            'Click "Add Route" above to set up bus corridors and stops.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _routes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final r = _routes[idx];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primaryBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r['routeNumber'] as String? ?? 'R-01',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r['routeName'] as String? ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 16,
                      ),
                      label: const Text('Add Stop'),
                      onPressed: () => _createStopDialog(r),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Route Path: ${r['startPoint']}  ➔  ${r['endPoint']}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      size: 15,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r['vehicleNumber'] != null
                          ? '${r['vehicleNumber']} (${r['vehicleModel'] ?? ''})'
                          : 'No Vehicle',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.person,
                      size: 15,
                      color: AppColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r['driverName'] != null
                          ? '${r['driverName']} (${r['driverPhone'] ?? ''})'
                          : 'No Driver',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '${r['totalStops'] ?? 0} Stops',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehiclesAndDriversList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicles Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fleet Vehicles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_vehicles.isEmpty)
                  const EmptyStateView(
                    title: 'No vehicles registered',
                    description: 'Add buses, vans, and shuttles to the fleet.',
                  )
                else
                  ..._vehicles.map(
                    (v) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.directions_bus),
                        title: Text('${v['vehicleNumber']} (${v['model']})'),
                        subtitle: Text(
                          'Capacity: ${v['capacity']} Seats | Status: ${v['status']}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Drivers Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drivers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_drivers.isEmpty)
                  const EmptyStateView(
                    title: 'No drivers registered',
                    description: 'Add transport drivers and license details.',
                  )
                else
                  ..._drivers.map(
                    (d) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(d['fullName'] as String? ?? 'Driver'),
                        subtitle: Text(
                          'Phone: ${d['phone']} | DL: ${d['licenseNumber']}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationsList() {
    if (_allocations.isEmpty) {
      return const EmptyStateView(
        title: 'No student bus passes allocated',
        description: 'Allocate students to transport routes and pickup stops.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _allocations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final a = _allocations[idx];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.commute),
            title: Text('${a['studentName']} (${a['admissionNumber']})'),
            subtitle: Text(
              'Route: ${a['routeNumber']} - ${a['routeName']} | Stop: ${a['stopName']} (Pick: ${a['pickupTime']}, Drop: ${a['dropTime']})',
            ),
            trailing: Text(
              '₹${a['monthlyFeeAmount']}/mo',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      return const EmptyStateView(
        title: 'No live transport logs',
        description: 'Real-time bus dispatch checkpoint logs will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final l = _logs[idx];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: Text(
              '${l['routeNumber']} — ${l['tripType']?.toString().toUpperCase()}',
            ),
            subtitle: Text(
              'Stop: ${l['currentStopName'] ?? 'En Route'} | ${l['notes'] ?? ''}',
            ),
            trailing: Text('${l['status']}'),
          ),
        );
      },
    );
  }

  // ================= 3. CERTIFICATES VIEW =================
  Widget _buildCertificatesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: DropdownButton<String>(
            value: _certTypeFilter,
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All Certificate Types'),
              ),
              DropdownMenuItem(
                value: 'transfer_certificate',
                child: Text('Transfer Certificate (TC)'),
              ),
              DropdownMenuItem(
                value: 'bonafide',
                child: Text('Bonafide Certificate'),
              ),
              DropdownMenuItem(
                value: 'character_conduct',
                child: Text('Character & Conduct'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _certTypeFilter = val);
                _loadCurrentTabData();
              }
            },
          ),
        ),
        Expanded(
          child: _certificates.isEmpty
              ? const EmptyStateView(
                  title: 'No issued certificates found',
                  description: 'Click "Issue Certificate" above to generate serial-numbered verifiable certificates.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: _certificates.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final c = _certificates[idx];
                    final isRevoked = c['status'] == 'revoked';
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRevoked
                              ? AppColors.statusError.withValues(alpha: 0.5)
                              : AppColors.primaryBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    (isRevoked
                                            ? AppColors.statusError
                                            : AppColors.statusSuccess)
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isRevoked
                                    ? Icons.cancel_outlined
                                    : Icons.verified_outlined,
                                color: isRevoked
                                    ? AppColors.statusError
                                    : AppColors.statusSuccess,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c['certificateNumber'] as String? ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StatusBadge(
                                        label: isRevoked ? 'REVOKED' : 'VALID',
                                        tone: isRevoked
                                            ? BadgeTone.error
                                            : BadgeTone.success,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Student: ${c['studentName']} (${c['admissionNumber']}) | Issued: ${c['issueDate']}',
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Digital Verification Code: ${c['verificationCode']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRevoked) ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.statusError,
                                ),
                                onPressed: () => _revokeCertificateDialog(c),
                                child: const Text('Revoke'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= 4. CALENDAR & PTM VIEW =================
  Widget _buildCalendarAndPtmTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Events Column
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Institutional Calendar Events',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_calendarEvents.isEmpty)
                  const EmptyStateView(
                    title: 'No calendar events',
                    description: 'Add holidays, examinations, sports and institutional programs.',
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: _calendarEvents.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final e = _calendarEvents[idx];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              e['eventType'] == 'holiday'
                                  ? Icons.beach_access
                                  : e['eventType'] == 'exam'
                                  ? Icons.assignment_outlined
                                  : Icons.event,
                              color: AppColors.accent,
                            ),
                            title: Text(e['title'] as String? ?? 'Event'),
                            subtitle: Text(
                              '${e['startDate']} to ${e['endDate']} | Audience: ${e['targetAudience']}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                final session = ref
                                    .read(authControllerProvider)
                                    .session;
                                if (session == null) return;
                                try {
                                  await ref
                                      .read(apiClientProvider)
                                      .deleteCalendarEvent(
                                        session: session,
                                        eventId: e['id'] as String,
                                      );
                                  setState(
                                    () => _success = 'Calendar event removed.',
                                  );
                                  _loadCurrentTabData();
                                } catch (err) {
                                  setState(
                                    () =>
                                        _error = 'Failed to delete event: $err',
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // PTM Schedules & Slots Column
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PTM Schedules & Slots',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_ptmSchedules.isEmpty)
                  const EmptyStateView(
                    title: 'No PTM conferences scheduled',
                    description: 'Click "Schedule PTM" to generate slots for teachers and parents.',
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: _ptmSchedules.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, sIdx) {
                        final s = _ptmSchedules[sIdx];
                        return Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(s['title'] as String? ?? 'PTM'),
                            subtitle: Text(
                              'Date: ${s['eventDate']} (${s['startTime']} - ${s['endTime']}) | ${s['slotDurationMinutes']} min slots',
                            ),
                            children: [
                              Builder(
                                builder: (ctx) {
                                  final scheduleSlots = _ptmSlots
                                      .where(
                                        (slot) => slot['scheduleId'] == s['id'],
                                      )
                                      .toList();
                                  if (scheduleSlots.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'No slots generated for this PTM.',
                                      ),
                                    );
                                  }
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: scheduleSlots.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (ctx, slotIdx) {
                                      final slot = scheduleSlots[slotIdx];
                                      final isBooked =
                                          slot['status'] == 'booked' ||
                                          slot['status'] == 'completed';
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          '${slot['startTime']} - ${slot['endTime']}: ${slot['teacherName'] ?? 'Teacher'}',
                                        ),
                                        subtitle: isBooked
                                            ? Text(
                                                'Booked by: ${slot['studentName'] ?? 'Parent'}',
                                              )
                                            : const Text(
                                                'Available for reservation',
                                              ),
                                        trailing: StatusBadge(
                                          label:
                                              (slot['status'] as String? ??
                                                      'available')
                                                  .toUpperCase(),
                                          tone: isBooked
                                              ? BadgeTone.success
                                              : BadgeTone.neutral,
                                        ),
                                      );
                                    },
                                  );
                                },
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
    );
  }
}
