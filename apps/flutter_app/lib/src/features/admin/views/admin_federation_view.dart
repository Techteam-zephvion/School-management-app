import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminFederationView extends ConsumerStatefulWidget {
  const AdminFederationView({super.key});

  @override
  ConsumerState<AdminFederationView> createState() =>
      _AdminFederationViewState();
}

class _AdminFederationViewState extends ConsumerState<AdminFederationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  String? _error;
  String? _success;

  // Data
  List<Map<String, Object?>> _trusts = [];
  Map<String, Object?>? _selectedTrust;
  List<Map<String, Object?>> _campuses = [];
  Map<String, Object?>? _consolidatedStats;
  List<Map<String, Object?>> _transfers = [];

  List<Map<String, Object?>> _devices = [];
  List<Map<String, Object?>> _punches = [];

  List<Map<String, Object?>> _courseOutcomes = [];
  List<Map<String, Object?>> _examQuestions = [];
  List<Map<String, Object?>> _classes = [];
  List<Map<String, Object?>> _subjects = [];

  List<Map<String, Object?>> _alumni = [];
  List<Map<String, Object?>> _transcripts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    try {
      final trusts = await api.getEducationalTrusts(session: session);
      final transfers = await api.getCampusTransfers(session: session);
      final devices = await api.getBiometricDevices(session: session);
      final punches = await api.getBiometricPunches(
        session: session,
        limit: 50,
      );
      final outcomes = await api.getCourseOutcomes(session: session);
      final questions = await api.getExamQuestions(session: session);
      final alumni = await api.getAlumniProfiles(session: session);
      final transcripts = await api.getTranscriptRequests(session: session);
      final classes = await api.getClasses(session: session);
      final subjects = await api.getSubjects(session: session);

      Map<String, Object?>? selectedTrust;
      List<Map<String, Object?>> campuses = [];
      Map<String, Object?>? stats;

      if (trusts.isNotEmpty) {
        selectedTrust = trusts.first;
        final trustId = selectedTrust['id'] as String;
        campuses = await api.getTrustCampuses(
          session: session,
          trustId: trustId,
        );
        stats = await api.getTrustConsolidatedStats(
          session: session,
          trustId: trustId,
        );
      }

      if (mounted) {
        setState(() {
          _trusts = trusts;
          _selectedTrust = selectedTrust;
          _campuses = campuses;
          _consolidatedStats = stats;
          _transfers = transfers;
          _devices = devices;
          _punches = punches;
          _courseOutcomes = outcomes;
          _examQuestions = questions;
          _alumni = alumni;
          _transcripts = transcripts;
          _classes = classes;
          _subjects = subjects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Multi-Campus Federation & Biometrics',
            description: 'Enterprise trust hierarchy, biometric gates, OBE curriculum, and alumni transcripts',
            primaryAction: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              onPressed: _loadData,
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeedbackBanner.error(message: _error!),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeedbackBanner.success(message: _success!),
            ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(
                icon: Icon(Icons.hub_outlined, size: 18),
                text: 'Trust & Campuses',
              ),
              Tab(
                icon: Icon(Icons.fingerprint_rounded, size: 18),
                text: 'Biometrics & Turnstiles',
              ),
              Tab(
                icon: Icon(Icons.psychology_outlined, size: 18),
                text: 'OBE & Question Bank',
              ),
              Tab(
                icon: Icon(Icons.school_outlined, size: 18),
                text: 'Alumni & Transcripts',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildActiveTabContent(),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_tabController.index) {
      case 0:
        return _buildTrustTab();
      case 1:
        return _buildBiometricsTab();
      case 2:
        return _buildObeTab();
      case 3:
        return _buildAlumniTab();
      default:
        return _buildTrustTab();
    }
  }

  // ==========================================
  // TAB 1: Trust & Multi-Campus Federation
  // ==========================================
  Widget _buildTrustTab() {
    final campusesCount = _campuses.length;
    final totalStudents = _consolidatedStats?['totalStudents'] as int? ?? 0;
    final totalStaff = _consolidatedStats?['totalStaff'] as int? ?? 0;
    final feesCollected =
        _consolidatedStats?['totalFeesCollected'] as int? ?? 0;
    final feesPending = _consolidatedStats?['totalFeesPending'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatStrip(
          items: [
            StatItemData(label: 'Campuses', value: '$campusesCount'),
            StatItemData(label: 'Total Students', value: '$totalStudents'),
            StatItemData(label: 'Total Staff', value: '$totalStaff'),
            StatItemData(label: 'Fees Collected', value: '₹$feesCollected'),
            StatItemData(label: 'Fees Pending', value: '₹$feesPending'),
          ],
        ),
        const SizedBox(height: 18),

        // Trust Overview Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final titleWidget = Text(
              _selectedTrust != null
                  ? '${_selectedTrust!['name']}${(_selectedTrust!['trustCode'] ?? _selectedTrust!['code']) != null ? ' (${_selectedTrust!['trustCode'] ?? _selectedTrust!['code']})' : ''}'
                  : 'Educational Trust Federation',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            );

            final buttons = [
              OutlinedButton.icon(
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text('Create Trust'),
                onPressed: _showCreateTrustDialog,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Link this school'),
                onPressed: _showLinkSchoolDialog,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Initiate Transfer'),
                onPressed: _showInitiateTransferDialog,
              ),
            ];

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: buttons),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: titleWidget),
                ...buttons,
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // Campuses Grid
        if (_campuses.isEmpty)
          const EmptyStateView(
            title: 'No Campuses Linked',
            description: 'Create or link an educational trust to monitor federated campuses.',
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _campuses.map((campus) {
              final name = campus['name'] as String? ?? 'Campus';
              final code = campus['code'] as String? ?? '';
              final students = campus['studentCount'] as int? ?? 0;
              final staffCount = campus['staffCount'] as int? ?? 0;

              return Card(
                elevation: 1,
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_rounded, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code: $code',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '$students Students',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$staffCount Staff',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),

        // Inter-Campus Transfers Table
        const Text(
          'Inter-Campus Transfer Requests',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_transfers.isEmpty)
          const EmptyStateView(
            title: 'No Transfers Logged',
            description: 'No student or staff transfer requests found.',
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Entity Type')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Transfer Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _transfers.map((tx) {
                  final type = tx['entityType'] as String? ?? 'student';
                  final reason = tx['reason'] as String? ?? '';
                  final date = tx['transferDate'] as String? ?? 'Pending';
                  final status = tx['status'] as String? ?? 'pending';
                  final id = tx['id'] as String;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(reason)),
                      DataCell(Text(date)),
                      DataCell(StatusBadge.transferStatus(status)),
                      DataCell(
                        status == 'pending'
                            ? Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    tooltip: 'Approve & Complete',
                                    onPressed: () =>
                                        _updateTransferStatus(id, 'completed'),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: 'Reject',
                                    onPressed: () =>
                                        _updateTransferStatus(id, 'rejected'),
                                  ),
                                ],
                              )
                            : const Text(
                                'Processed',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 2: Hardware Biometrics & Turnstiles
  // ==========================================
  Widget _buildBiometricsTab() {
    final onlineCount = _devices.where((d) => d['status'] == 'online').length;
    final offlineCount = _devices.where((d) => d['status'] != 'online').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatStrip(
          items: [
            StatItemData(
              label: 'Registered Terminals',
              value: '${_devices.length}',
            ),
            StatItemData(label: 'Online', value: '$onlineCount'),
            StatItemData(
              label: 'Offline / Maintenance',
              value: '$offlineCount',
            ),
            StatItemData(
              label: 'Punches Streamed',
              value: '${_punches.length}',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Actions Row
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            const titleWidget = Text(
              'Hardware Gate Readers & Turnstiles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            );

            final buttons = [
              OutlinedButton.icon(
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sync Attendance'),
                onPressed: _reconcilePunches,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Register Terminal'),
                onPressed: _showRegisterDeviceDialog,
              ),
            ];

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: buttons),
                ],
              );
            }

            return Row(
              children: [
                const Expanded(child: titleWidget),
                ...buttons,
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // Device Cards
        if (_devices.isEmpty)
          const EmptyStateView(
            title: 'No Biometric Devices Registered',
            description: 'Register ZKTeco, Essl, or RFID turnstile devices to start tracking campus ingress.',
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _devices.map((device) {
              final name = device['name'] as String? ?? 'Terminal';
              final code = device['deviceCode'] as String? ?? '';
              final type =
                  device['deviceType'] as String? ?? 'facial_recognition';
              final loc = device['location'] as String? ?? 'Gate';
              final status = device['status'] as String? ?? 'offline';
              final ip = device['ipAddress'] as String? ?? '192.168.1.1';
              final id = device['id'] as String;

              return Card(
                elevation: 1,
                child: Container(
                  width: 290,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          StatusBadge.deviceStatus(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Code: $code | IP: $ip',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Location: $loc | Type: ${type.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const Divider(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Ping Device',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _sendHeartbeat(id),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),

        // Real-time Punch Stream Table
        const Text(
          'Raw Biometric Punch Stream',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_punches.isEmpty)
          const EmptyStateView(
            title: 'No Punch Logs Recorded',
            description: 'Punches recorded from physical gates will stream here in real time.',
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Terminal')),
                  DataColumn(label: Text('User Type')),
                  DataColumn(label: Text('Card / Token #')),
                  DataColumn(label: Text('Direction')),
                  DataColumn(label: Text('Punch Time')),
                  DataColumn(label: Text('Reconciled')),
                ],
                rows: _punches.map((punch) {
                  final dev = punch['deviceName'] as String? ?? 'Device';
                  final uType = punch['userType'] as String? ?? 'student';
                  final token = punch['cardOrTokenNumber'] as String? ?? '';
                  final dir = punch['punchType'] as String? ?? 'auto';
                  final time = punch['punchTimestamp'] as String? ?? '';
                  final status = punch['status'] as String? ?? 'pending';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          dev,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(uType.toUpperCase())),
                      DataCell(Text(token)),
                      DataCell(Text(dir.toUpperCase())),
                      DataCell(
                        Text(
                          time.length > 19
                              ? time.substring(0, 19).replaceAll('T', ' ')
                              : time,
                        ),
                      ),
                      DataCell(
                        status == 'reconciled'
                            ? const StatusBadge(
                                label: 'RECONCILED',
                                tone: BadgeTone.success,
                              )
                            : const StatusBadge(
                                label: 'PENDING',
                                tone: BadgeTone.warning,
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 3: Outcome-Based Education (OBE)
  // ==========================================
  Widget _buildObeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatStrip(
          items: [
            StatItemData(
              label: 'Course Outcomes',
              value: '${_courseOutcomes.length}',
            ),
            StatItemData(
              label: 'Question Bank',
              value: '${_examQuestions.length}',
            ),
            StatItemData(label: 'Classes Mapped', value: '${_classes.length}'),
            StatItemData(
              label: 'Subjects Covered',
              value: '${_subjects.length}',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Course Outcomes Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Course Learning Outcomes (CO-PO Mapping)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add CO'),
              onPressed: _showAddCourseOutcomeDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_courseOutcomes.isEmpty)
          const EmptyStateView(
            title: 'No Course Outcomes Defined',
            description: 'Add course outcomes to align curriculum with Bloom Taxonomy competencies.',
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Class & Subject')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Target Attainment')),
                ],
                rows: _courseOutcomes.map((co) {
                  final code = co['code'] as String? ?? 'CO1';
                  final cls = co['className'] as String? ?? 'Class';
                  final sub = co['subjectName'] as String? ?? 'Subject';
                  final desc = co['description'] as String? ?? '';
                  final target = co['targetAttainmentPercent'] as int? ?? 70;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text('$cls - $sub')),
                      DataCell(Text(desc)),
                      DataCell(Text('$target%')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Cognitive Question Bank
        Row(
          children: [
            const Expanded(
              child: Text(
                "Bloom's Taxonomy Question Bank",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_motion_rounded, size: 16),
              label: const Text('Generate Blueprint Paper'),
              onPressed: _showGenerateBlueprintDialog,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.playlist_add_rounded, size: 16),
              label: const Text('Add Question'),
              onPressed: _showAddQuestionDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_examQuestions.isEmpty)
          const EmptyStateView(
            title: 'No Exam Questions Registered',
            description: "Add tagged questions with Bloom's cognitive levels to build blueprinted assessment papers.",
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Question Text')),
                  DataColumn(label: Text('Bloom Level')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Marks')),
                  DataColumn(label: Text('Class & Subject')),
                ],
                rows: _examQuestions.map((q) {
                  final text = q['questionText'] as String? ?? '';
                  final bloom = q['bloomLevel'] as String? ?? 'understand';
                  final type = q['questionType'] as String? ?? 'short_answer';
                  final marks = q['marks'] as int? ?? 2;
                  final cls = q['className'] as String? ?? '';
                  final sub = q['subjectName'] as String? ?? '';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(StatusBadge.bloomLevel(bloom)),
                      DataCell(
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$marks M',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text('$cls ($sub)')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 4: Alumni Association & Transcripts
  // ==========================================
  Widget _buildAlumniTab() {
    final mentorCount = _alumni
        .where((a) => a['mentorshipAvailable'] == true)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatStrip(
          items: [
            StatItemData(label: 'Total Alumni', value: '${_alumni.length}'),
            StatItemData(label: 'Available Mentors', value: '$mentorCount'),
            StatItemData(
              label: 'Transcript Requests',
              value: '${_transcripts.length}',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Alumni Directory
        Row(
          children: [
            const Expanded(
              child: Text(
                'Alumni Directory & Mentorship Network',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Register Alumni'),
              onPressed: _showRegisterAlumniDialog,
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_alumni.isEmpty)
          const EmptyStateView(
            title: 'No Alumni Registered',
            description: 'Register graduating cohorts to foster alumni career connections and mentorship.',
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _alumni.map((alum) {
              final name = alum['fullName'] as String? ?? 'Alumni';
              final yr = alum['graduationYear'] as int? ?? 2020;
              final org = alum['currentOrganization'] as String? ?? '';
              final desig = alum['designation'] as String? ?? '';
              final email = alum['email'] as String? ?? '';
              final isMentor = alum['mentorshipAvailable'] as bool? ?? false;

              return Card(
                elevation: 1,
                child: Container(
                  width: 290,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'Class of $yr',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (org.isNotEmpty)
                        Text(
                          '$desig at $org',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const Divider(height: 16),
                      if (isMentor)
                        const StatusBadge(
                          label: 'MENTOR',
                          tone: BadgeTone.success,
                          icon: Icons.handshake_outlined,
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showEditAlumniDialog(alum),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),

        // Official Transcript Requests
        Row(
          children: [
            const Expanded(
              child: Text(
                'Official Credential & Transcript Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.post_add_rounded, size: 16),
              label: const Text('New Request'),
              onPressed: _showCreateTranscriptDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_transcripts.isEmpty)
          const EmptyStateView(
            title: 'No Transcript Requests',
            description: 'Official academic transcript and migration certificate requests will appear here.',
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Request #')),
                  DataColumn(label: Text('Alumni')),
                  DataColumn(label: Text('Document')),
                  DataColumn(label: Text('Copies')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _transcripts.map((tr) {
                  final reqNum = tr['requestNumber'] as String? ?? 'TR-001';
                  final name = tr['alumniName'] as String? ?? 'Alumni';
                  final doc = tr['documentType'] as String? ?? 'transcript';
                  final copies = tr['copies'] as int? ?? 1;
                  final status = tr['status'] as String? ?? 'submitted';
                  final id = tr['id'] as String;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          reqNum,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(name)),
                      DataCell(
                        Text(
                          doc.toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(Text('$copies')),
                      DataCell(StatusBadge.transcriptStatus(status)),
                      DataCell(
                        status == 'submitted'
                            ? OutlinedButton(
                                onPressed: () =>
                                    _updateTranscriptStatus(id, 'ready'),
                                child: const Text('Process'),
                              )
                            : status == 'ready'
                            ? ElevatedButton(
                                onPressed: () =>
                                    _updateTranscriptStatus(id, 'dispatched'),
                                child: const Text('Dispatch'),
                              )
                            : const Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // Dialogs & Actions
  // ==========================================

  Future<void> _updateTransferStatus(String transferId, String status) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .updateCampusTransferStatus(
            session: session,
            transferId: transferId,
            status: status,
          );
      setState(() => _success = 'Transfer request updated to $status');
      _loadData();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sendHeartbeat(String deviceId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .recordDeviceHeartbeat(session: session, deviceId: deviceId);
      setState(() => _success = 'Device heartbeat recorded successfully');
      _loadData();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _reconcilePunches() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .reconcileBiometricPunches(session: session);
      final count = res['reconciledCount'] as int? ?? 0;
      setState(
        () => _success =
            'Synchronized and reconciled $count biometric attendance punches',
      );
      _loadData();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _updateTranscriptStatus(String requestId, String status) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .updateTranscriptRequestStatus(
            session: session,
            requestId: requestId,
            status: status,
            feePaid: true,
          );
      setState(() => _success = 'Transcript request updated to $status');
      _loadData();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _showLinkSchoolDialog() {
    if (_trusts.isEmpty) {
      setState(() => _error = 'Create a trust before linking this school.');
      return;
    }
    var trustId = (_selectedTrust ?? _trusts.first)['id'] as String;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'Link this school to a trust',
          subtitle: 'The current school will become a campus in the selected federation.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .linkSchoolToTrust(session: session, trustId: trustId);
                  setState(
                    () => _success = 'School linked to the selected trust.',
                  );
                  await _loadData();
                } catch (e) {
                  setState(() => _error = 'Could not link school: $e');
                }
              },
              child: const Text('Link school'),
            ),
          ],
          child: DropdownButtonFormField<String>(
            initialValue: trustId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Educational trust'),
            items: _trusts
                .map(
                  (trust) => DropdownMenuItem(
                    value: trust['id'] as String,
                    child: Text(trust['name']?.toString() ?? 'Trust'),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setDialogState(() => trustId = value ?? trustId),
          ),
        ),
      ),
    );
  }

  void _showCreateTrustDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final regCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Create Educational Trust',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .createEducationalTrust(
                      session: session,
                      payload: {
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim().toUpperCase(),
                        'registrationNumber': regCtrl.text.trim(),
                      },
                    );
                setState(
                  () => _success = 'Educational trust created successfully',
                );
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Create Trust'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Trust / Society Name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Trust Code (e.g. DPES-NORTH)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: regCtrl,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInitiateTransferDialog() {
    if (_trusts.isEmpty) {
      setState(
        () => _error = 'Please create or link an educational trust first.',
      );
      return;
    }
    final reasonCtrl = TextEditingController();
    String? selectedTargetSchoolId;
    if (_campuses.length > 1) {
      selectedTargetSchoolId = _campuses[1]['id'] as String;
    } else if (_campuses.isNotEmpty) {
      selectedTargetSchoolId = _campuses[0]['id'] as String;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Initiate Inter-Campus Transfer',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.isEmpty || selectedTargetSchoolId == null)
                return;
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .createCampusTransfer(
                      session: session,
                      payload: {
                        'trustId': _selectedTrust!['id'],
                        'targetSchoolId': selectedTargetSchoolId,
                        'entityType': 'student',
                        'reason': reasonCtrl.text.trim(),
                      },
                    );
                setState(
                  () => _success = 'Campus transfer initiated successfully',
                );
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Submit Transfer'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Target Branch Campus',
              ),
              initialValue: selectedTargetSchoolId,
              items: _campuses.map((c) {
                return DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String? ?? 'Campus'),
                );
              }).toList(),
              onChanged: (val) => selectedTargetSchoolId = val,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Transfer Reason'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterDeviceDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.1.100');
    String deviceType = 'facial_recognition';

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Register Biometric Terminal / Turnstile',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  codeCtrl.text.isEmpty ||
                  locCtrl.text.isEmpty)
                return;
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .registerBiometricDevice(
                      session: session,
                      payload: {
                        'name': nameCtrl.text.trim(),
                        'deviceCode': codeCtrl.text.trim().toUpperCase(),
                        'location': locCtrl.text.trim(),
                        'ipAddress': ipCtrl.text.trim(),
                        'deviceType': deviceType,
                        'status': 'online',
                      },
                    );
                setState(
                  () => _success = 'Biometric device registered successfully',
                );
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Register Terminal'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Terminal Name (e.g. North Gate Reader)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Device Code (e.g. DEV-GT-01)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'Physical Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              decoration: const InputDecoration(labelText: 'IP Address'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Biometric Type'),
              initialValue: deviceType,
              items: const [
                DropdownMenuItem(
                  value: 'facial_recognition',
                  child: Text('Facial Recognition AI'),
                ),
                DropdownMenuItem(
                  value: 'fingerprint',
                  child: Text('Fingerprint Scanner'),
                ),
                DropdownMenuItem(
                  value: 'rfid_card',
                  child: Text('RFID Turnstile Barrier'),
                ),
                DropdownMenuItem(
                  value: 'turnstile',
                  child: Text('Turnstile Full Height Gate'),
                ),
              ],
              onChanged: (val) {
                if (val != null) deviceType = val;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCourseOutcomeDialog() {
    if (_classes.isEmpty || _subjects.isEmpty) {
      setState(
        () => _error = 'Please ensure classes and subjects are configured.',
      );
      return;
    }
    final codeCtrl = TextEditingController(text: 'CO1');
    final descCtrl = TextEditingController();
    String selectedClass = _classes.first['id'] as String;
    String selectedSubject = _subjects.first['id'] as String;

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Add Course Outcome (CO)',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .createCourseOutcome(
                      session: session,
                      payload: {
                        'classId': selectedClass,
                        'subjectId': selectedSubject,
                        'code': codeCtrl.text.trim().toUpperCase(),
                        'description': descCtrl.text.trim(),
                        'targetAttainmentPercent': 75,
                      },
                    );
                setState(
                  () => _success = 'Course outcome created successfully',
                );
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Save CO'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Class'),
              initialValue: selectedClass,
              items: _classes
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selectedClass = val!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Subject'),
              initialValue: selectedSubject,
              items: _subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selectedSubject = val!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'CO Code (e.g. CO1)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Competency',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    if (_classes.isEmpty || _subjects.isEmpty) {
      setState(
        () => _error = 'Please ensure classes and subjects are configured.',
      );
      return;
    }
    final textCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '3');
    String selectedClass = _classes.first['id'] as String;
    String selectedSubject = _subjects.first['id'] as String;
    String bloomLevel = 'understand';
    String questionType = 'short_answer';

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: "Add Question to Bloom's Taxonomy Bank",
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .createExamQuestion(
                      session: session,
                      payload: {
                        'classId': selectedClass,
                        'subjectId': selectedSubject,
                        'questionText': textCtrl.text.trim(),
                        'bloomLevel': bloomLevel,
                        'questionType': questionType,
                        'marks': int.tryParse(marksCtrl.text) ?? 2,
                      },
                    );
                setState(() => _success = 'Question added to question bank');
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Save Question'),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Class'),
                initialValue: selectedClass,
                items: _classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedClass = val!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Subject'),
                initialValue: selectedSubject,
                items: _subjects
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedSubject = val!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Cognitive Level'),
                initialValue: bloomLevel,
                items: const [
                  DropdownMenuItem(value: 'remember', child: Text('Remember')),
                  DropdownMenuItem(
                    value: 'understand',
                    child: Text('Understand'),
                  ),
                  DropdownMenuItem(value: 'apply', child: Text('Apply')),
                  DropdownMenuItem(value: 'analyze', child: Text('Analyze')),
                  DropdownMenuItem(value: 'evaluate', child: Text('Evaluate')),
                  DropdownMenuItem(value: 'create', child: Text('Create')),
                ],
                onChanged: (val) => bloomLevel = val!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(labelText: 'Question Text'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marksCtrl,
                decoration: const InputDecoration(labelText: 'Marks'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenerateBlueprintDialog() {
    if (_classes.isEmpty || _subjects.isEmpty) return;
    String selectedClass = _classes.first['id'] as String;
    String selectedSubject = _subjects.first['id'] as String;
    final marksCtrl = TextEditingController(text: '50');

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Generate Blueprinted Assessment Paper',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                final res = await ref
                    .read(apiClientProvider)
                    .generateBlueprintedPaper(
                      session: session,
                      classId: selectedClass,
                      subjectId: selectedSubject,
                      totalMarks: int.tryParse(marksCtrl.text) ?? 50,
                    );
                final qCount = res['questionCount'] as int? ?? 0;
                final actual = res['actualMarks'] as int? ?? 0;
                setState(
                  () => _success =
                      'Blueprinted paper generated successfully with $qCount questions ($actual marks total)',
                );
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Generate Blueprint'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Class'),
              initialValue: selectedClass,
              items: _classes
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selectedClass = val!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Subject'),
              initialValue: selectedSubject,
              items: _subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selectedSubject = val!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: marksCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Total Marks',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAlumniDialog(Map<String, Object?> alumni) {
    final nameCtrl = TextEditingController(
      text: alumni['fullName']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: alumni['email']?.toString() ?? '',
    );
    final yearCtrl = TextEditingController(
      text: '${alumni['graduationYear'] ?? DateTime.now().year}',
    );
    final orgCtrl = TextEditingController(
      text: alumni['currentOrganization']?.toString() ?? '',
    );
    final desigCtrl = TextEditingController(
      text: alumni['designation']?.toString() ?? '',
    );
    var isMentor = alumni['mentorshipAvailable'] == true;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'Edit alumni profile',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().length < 2 ||
                    emailCtrl.text.trim().isEmpty)
                  return;
                Navigator.pop(context);
                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .updateAlumniProfile(
                        session: session,
                        profileId: alumni['id'] as String,
                        payload: {
                          'fullName': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'graduationYear':
                              int.tryParse(yearCtrl.text) ??
                              DateTime.now().year,
                          'currentOrganization': orgCtrl.text.trim(),
                          'designation': desigCtrl.text.trim(),
                          'mentorshipAvailable': isMentor,
                        },
                      );
                  setState(() => _success = 'Alumni profile updated.');
                  await _loadData();
                } catch (e) {
                  setState(() => _error = 'Could not update alumni: $e');
                }
              },
              child: const Text('Save changes'),
            ),
          ],
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Graduation year'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(labelText: 'Organization'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desigCtrl,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isMentor,
                title: const Text('Available for mentorship'),
                onChanged: (value) =>
                    setDialogState(() => isMentor = value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegisterAlumniDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '2023');
    final orgCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    bool isMentor = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Register Alumni Profile',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .createAlumniProfile(
                        session: session,
                        payload: {
                          'fullName': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'graduationYear': int.tryParse(yearCtrl.text) ?? 2023,
                          'currentOrganization': orgCtrl.text.trim(),
                          'designation': desigCtrl.text.trim(),
                          'mentorshipAvailable': isMentor,
                        },
                      );
                  setState(() => _success = 'Alumni registered successfully');
                  _loadData();
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
              child: const Text('Save Alumni'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(labelText: 'Graduation Year'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organization / Company',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desigCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designation / Role',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for Student Mentorship'),
                value: isMentor,
                onChanged: (val) =>
                    setDialogState(() => isMentor = val ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTranscriptDialog() {
    if (_alumni.isEmpty) {
      setState(() => _error = 'Please register an alumni profile first.');
      return;
    }
    String selectedAlumni = _alumni.first['id'] as String;
    String docType = 'transcript';
    final notesCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'New Official Transcript Request',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .createTranscriptRequest(
                      session: session,
                      payload: {
                        'alumniId': selectedAlumni,
                        'documentType': docType,
                        'copies': 1,
                        'deliveryMode': 'digital',
                        'notes': notesCtrl.text.trim(),
                      },
                    );
                setState(
                  () => _success = 'Transcript request submitted successfully',
                );
                _loadData();
              } catch (e) {
                setState(() => _error = e.toString());
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Alumni Requester'),
              initialValue: selectedAlumni,
              items: _alumni
                  .map(
                    (a) => DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text(a['fullName'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => selectedAlumni = val!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Document Type'),
              initialValue: docType,
              items: const [
                DropdownMenuItem(
                  value: 'transcript',
                  child: Text('Official Academic Transcript'),
                ),
                DropdownMenuItem(
                  value: 'migration_certificate',
                  child: Text('Migration Certificate'),
                ),
                DropdownMenuItem(
                  value: 'recommendation_letter',
                  child: Text('Letter of Recommendation'),
                ),
                DropdownMenuItem(
                  value: 'duplicate_grade_sheet',
                  child: Text('Duplicate Grade Sheet'),
                ),
              ],
              onChanged: (val) => docType = val!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes / Higher Ed Institution',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
