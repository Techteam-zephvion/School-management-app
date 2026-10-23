import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../shared/components/app_dialog.dart';
import '../../shared/components/empty_state_view.dart';
import '../../shared/components/feedback_banner.dart';
import '../../shared/components/page_header.dart';
import '../../shared/components/stat_strip.dart';
import '../../shared/components/status_badge.dart';

class AdminCampusView extends ConsumerStatefulWidget {
  const AdminCampusView({
    required this.students,
    required this.staff,
    this.initialTab = 0,
    super.key,
  });

  final List<Map<String, Object?>> students;
  final List<Map<String, Object?>> staff;
  final int initialTab;

  @override
  ConsumerState<AdminCampusView> createState() => _AdminCampusViewState();
}

class _AdminCampusViewState extends ConsumerState<AdminCampusView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // General Status
  String? _error;
  String? _success;
  bool _loading = false;

  // 1. Library State
  List<Map<String, Object?>> _libraryBooks = [];
  List<Map<String, Object?>> _libraryLoans = [];
  Map<String, Object?>? _libraryStats;
  String _bookSearch = '';
  String _bookCategoryFilter = 'all';

  // 2. Inventory State
  List<Map<String, Object?>> _inventoryItems = [];
  List<Map<String, Object?>> _inventoryAllocations = [];
  List<Map<String, Object?>> _purchaseRequests = [];
  String _inventoryCategoryFilter = 'all';
  String _inventoryConditionFilter = 'all';

  // 3. Payroll State
  List<Map<String, Object?>> _salaryStructures = [];
  List<Map<String, Object?>> _payrollRecords = [];
  int _selectedPayrollMonth = DateTime.now().month;
  int _selectedPayrollYear = DateTime.now().year;

  // 4. Hostel & Visitors State
  List<Map<String, Object?>> _hostelRooms = [];
  List<Map<String, Object?>> _hostelAllocations = [];
  List<Map<String, Object?>> _visitorPasses = [];

  // 5. Health & Infirmary State
  List<Map<String, Object?>> _infirmaryVisits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadCurrentTabData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTabData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTabData() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      switch (_tabController.index) {
        case 0:
          final books = await api.getLibraryBooks(
            session: session,
            search: _bookSearch.isNotEmpty ? _bookSearch : null,
            category: _bookCategoryFilter != 'all' ? _bookCategoryFilter : null,
          );
          final loans = await api.getLibraryLoans(session: session);
          final stats = await api.getLibraryStats(session: session);
          if (mounted) {
            setState(() {
              _libraryBooks = books;
              _libraryLoans = loans;
              _libraryStats = stats;
            });
          }
          break;

        case 1:
          final items = await api.getInventoryItems(
            session: session,
            category: _inventoryCategoryFilter != 'all'
                ? _inventoryCategoryFilter
                : null,
            condition: _inventoryConditionFilter != 'all'
                ? _inventoryConditionFilter
                : null,
          );
          final reqs = await api.getInventoryPurchaseRequests(session: session);
          final allocations = await api.getInventoryAllocations(
            session: session,
          );
          if (mounted) {
            setState(() {
              _inventoryItems = items;
              _purchaseRequests = reqs;
              _inventoryAllocations = allocations;
            });
          }
          break;

        case 2:
          final structures = await api.getStaffSalaryStructures(
            session: session,
          );
          final records = await api.getStaffPayrollRecords(
            session: session,
            month: _selectedPayrollMonth,
            year: _selectedPayrollYear,
          );
          if (mounted) {
            setState(() {
              _salaryStructures = structures;
              _payrollRecords = records;
            });
          }
          break;

        case 3:
          final rooms = await api.getHostelRooms(session: session);
          final allocs = await api.getHostelAllocations(session: session);
          final passes = await api.getVisitorGatePasses(session: session);
          if (mounted) {
            setState(() {
              _hostelRooms = rooms;
              _hostelAllocations = allocs;
              _visitorPasses = passes;
            });
          }
          break;

        case 4:
          final visits = await api.getInfirmaryVisits(session: session);
          if (mounted) {
            setState(() {
              _infirmaryVisits = visits;
            });
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load campus operations data: $e';
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

  // ==========================================
  // 1. Library Handlers & Dialogs
  // ==========================================
  Future<void> _showAddBookDialog() async {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final copiesCtrl = TextEditingController(text: '1');
    String category = 'general';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Catalog New Library Book',
          subtitle: 'Enter book bibliographic details and shelf inventory',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final author = authorCtrl.text.trim();
                final location = locationCtrl.text.trim();
                final copies = int.tryParse(copiesCtrl.text.trim()) ?? 1;

                if (title.isEmpty || author.isEmpty || location.isEmpty) return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.createLibraryBook(
                    session: session,
                    payload: {
                      'title': title,
                      'author': author,
                      'isbn': isbnCtrl.text.trim().isNotEmpty
                          ? isbnCtrl.text.trim()
                          : null,
                      'category': category,
                      'shelfLocation': location,
                      'totalCopies': copies,
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to catalog book: $e')),
                    );
                  }
                }
              },
              child: const Text('Catalog Book'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Book Title *',
                  hintText: 'e.g. Fundamental Physics Vol 1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Author Name *',
                  hintText: 'e.g. H.C. Verma',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: isbnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ISBN Number',
                        hintText: '978-8177091878',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'general',
                          child: Text('General'),
                        ),
                        DropdownMenuItem(
                          value: 'science',
                          child: Text('Science'),
                        ),
                        DropdownMenuItem(
                          value: 'mathematics',
                          child: Text('Mathematics'),
                        ),
                        DropdownMenuItem(
                          value: 'literature',
                          child: Text('Literature'),
                        ),
                        DropdownMenuItem(
                          value: 'history',
                          child: Text('History'),
                        ),
                        DropdownMenuItem(
                          value: 'reference',
                          child: Text('Reference'),
                        ),
                        DropdownMenuItem(
                          value: 'periodical',
                          child: Text('Periodical'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shelf Location *',
                        hintText: 'e.g. Rack A-12',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: copiesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Copies *',
                        hintText: '1',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Book added to catalog successfully');
    }
  }

  Future<void> _showIssueLoanDialog() async {
    if (_libraryBooks.isEmpty) {
      setState(() => _error = 'No books in catalog to checkout.');
      return;
    }

    String? selectedBookId = _libraryBooks.first['id'] as String?;
    String memberType = 'student';
    String? selectedMemberId = widget.students.isNotEmpty
        ? widget.students.first['id'] as String?
        : null;
    final dueDateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 14))),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Issue Library Book Loan',
          subtitle: 'Check out book copy to student or staff member',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedBookId == null || selectedMemberId == null) return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.issueLibraryLoan(
                    session: session,
                    payload: {
                      'bookId': selectedBookId,
                      'memberType': memberType,
                      'memberId': selectedMemberId,
                      'dueDate': dueDateCtrl.text.trim(),
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to issue book: $e')),
                    );
                  }
                }
              },
              child: const Text('Confirm Issue'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBookId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select Book *'),
                items: _libraryBooks.map((b) {
                  final title = b['title'] as String? ?? 'Untitled';
                  final author = b['author'] as String? ?? '';
                  final avail = b['availableCopies'] as int? ?? 0;
                  return DropdownMenuItem<String>(
                    value: b['id'] as String?,
                    child: Text('$title by $author ($avail available)'),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedBookId = val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: memberType,
                      decoration: const InputDecoration(
                        labelText: 'Member Type *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            memberType = val;
                            selectedMemberId = val == 'student'
                                ? (widget.students.isNotEmpty
                                      ? widget.students.first['id'] as String?
                                      : null)
                                : (widget.staff.isNotEmpty
                                      ? widget.staff.first['id'] as String?
                                      : null);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: dueDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Due Date * (YYYY-MM-DD)',
                        hintText: '2026-11-01',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedMemberId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: memberType == 'student'
                      ? 'Select Student *'
                      : 'Select Staff *',
                ),
                items: memberType == 'student'
                    ? widget.students.map((s) {
                        final name = s['fullName'] as String? ?? 'Student';
                        final adm = s['admissionNumber'] as String? ?? '';
                        return DropdownMenuItem<String>(
                          value: s['id'] as String?,
                          child: Text('$name ($adm)'),
                        );
                      }).toList()
                    : widget.staff.map((st) {
                        final name = st['fullName'] as String? ?? 'Staff';
                        return DropdownMenuItem<String>(
                          value: st['id'] as String?,
                          child: Text(name),
                        );
                      }).toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedMemberId = val),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Book loan issued successfully');
    }
  }

  Future<void> _returnLoan(String loanId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    try {
      await api.returnLibraryLoan(
        session: session,
        loanId: loanId,
        payload: {
          'status': 'returned',
          'returnedAt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        },
      );
      _loadCurrentTabData();
      setState(() => _success = 'Book marked returned and inventory updated');
    } catch (e) {
      setState(() => _error = 'Failed to return book: $e');
    }
  }

  // ==========================================
  // 2. Inventory Handlers & Dialogs
  // ==========================================
  Future<void> _showAddInventoryItemDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    String category = 'lab_equipment';
    String condition = 'good';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Register Institutional Asset',
          subtitle: 'Track equipment, devices, and classroom furnishings',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final location = locationCtrl.text.trim();
                final qty = int.tryParse(quantityCtrl.text.trim()) ?? 1;
                final cost = int.tryParse(costCtrl.text.trim());

                if (code.isEmpty || name.isEmpty || location.isEmpty) return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.createInventoryItem(
                    session: session,
                    payload: {
                      'itemCode': code,
                      'name': name,
                      'category': category,
                      'quantity': qty,
                      'condition': condition,
                      'roomLocation': location,
                      'purchaseCost': cost != null ? cost * 100 : null, // paise
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to create asset: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Asset'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Asset Code *',
                        hintText: 'e.g. LAB-PHY-001',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'lab_equipment',
                          child: Text('Lab Equipment'),
                        ),
                        DropdownMenuItem(
                          value: 'sports_gear',
                          child: Text('Sports Gear'),
                        ),
                        DropdownMenuItem(
                          value: 'classroom',
                          child: Text('Classroom'),
                        ),
                        DropdownMenuItem(
                          value: 'it_hardware',
                          child: Text('IT Hardware'),
                        ),
                        DropdownMenuItem(
                          value: 'furniture',
                          child: Text('Furniture'),
                        ),
                        DropdownMenuItem(
                          value: 'consumables',
                          child: Text('Consumables'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Digital Spectrophotometer',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: condition,
                      decoration: const InputDecoration(
                        labelText: 'Condition *',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'good', child: Text('Good')),
                        DropdownMenuItem(value: 'fair', child: Text('Fair')),
                        DropdownMenuItem(
                          value: 'maintenance_required',
                          child: Text('Maintenance Req'),
                        ),
                        DropdownMenuItem(
                          value: 'damaged',
                          child: Text('Damaged'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => condition = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Room Location *',
                        hintText: 'e.g. Room 204 / Physics Lab',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Cost (₹)',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Asset registered in campus inventory');
    }
  }

  Future<void> _showAllocateInventoryDialog(Map<String, Object?> item) async {
    if (widget.staff.isEmpty) {
      setState(() => _error = 'Add a staff member before allocating an asset.');
      return;
    }
    var staffId = widget.staff.first['id'] as String;
    final purpose = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'Allocate ${item['name']}',
          subtitle: '${item['availableQuantity'] ?? 0} available',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allocate'),
            ),
          ],
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: staffId,
                decoration: const InputDecoration(
                  labelText: 'Allocate to staff member',
                ),
                items: widget.staff
                    .map(
                      (member) => DropdownMenuItem(
                        value: member['id'] as String,
                        child: Text(
                          member['fullName']?.toString() ??
                              member['name']?.toString() ??
                              'Staff member',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => staffId = value ?? staffId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true || purpose.text.trim().length < 2) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .allocateInventoryItem(
            session: session,
            itemId: item['id'] as String,
            payload: {
              'allocatedToStaffId': staffId,
              'purpose': purpose.text.trim(),
              'quantity': int.tryParse(quantity.text) ?? 1,
            },
          );
      setState(() => _success = 'Asset allocated successfully.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not allocate asset: $e');
    }
  }

  Future<void> _returnInventoryAllocation(String allocationId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .returnInventoryAllocation(
            session: session,
            allocationId: allocationId,
          );
      setState(() => _success = 'Asset return recorded.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not return asset: $e');
    }
  }

  Future<void> _showPurchaseRequestDialog() async {
    final name = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final cost = TextEditingController();
    var category = 'classroom';
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'New purchase requisition',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit requisition'),
            ),
          ],
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'lab_equipment',
                    child: Text('Lab equipment'),
                  ),
                  DropdownMenuItem(
                    value: 'sports_gear',
                    child: Text('Sports gear'),
                  ),
                  DropdownMenuItem(
                    value: 'classroom',
                    child: Text('Classroom'),
                  ),
                  DropdownMenuItem(
                    value: 'it_hardware',
                    child: Text('IT hardware'),
                  ),
                  DropdownMenuItem(
                    value: 'furniture',
                    child: Text('Furniture'),
                  ),
                  DropdownMenuItem(
                    value: 'consumables',
                    child: Text('Consumables'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => category = value ?? category),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cost,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated cost (₹)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true || name.text.trim().length < 2) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .createInventoryPurchaseRequest(
            session: session,
            payload: {
              'itemName': name.text.trim(),
              'category': category,
              'quantity': int.tryParse(quantity.text) ?? 1,
              'estimatedCost': (int.tryParse(cost.text) ?? 0) * 100,
            },
          );
      setState(() => _success = 'Purchase requisition submitted.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not submit requisition: $e');
    }
  }

  Future<void> _reviewPurchaseRequest(
    Map<String, Object?> request,
    String status,
  ) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .reviewInventoryPurchaseRequest(
            session: session,
            requestId: request['id'] as String,
            payload: {'status': status},
          );
      setState(() => _success = 'Requisition marked $status.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not update requisition: $e');
    }
  }

  // ==========================================
  // 3. Payroll Handlers & Dialogs
  // ==========================================
  Future<void> _showConfigureSalaryDialog(
    Map<String, Object?>? staffMember,
  ) async {
    final staffId =
        staffMember?['id'] as String? ??
        (widget.staff.isNotEmpty ? widget.staff.first['id'] as String? : null);
    if (staffId == null) return;

    final basicCtrl = TextEditingController(text: '35000');
    final hraCtrl = TextEditingController(text: '12000');
    final allowCtrl = TextEditingController(text: '5000');
    final pfCtrl = TextEditingController(text: '4200');
    final tdsCtrl = TextEditingController(text: '2500');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Configure Staff Salary Structure',
        subtitle: 'Define base pay, HRA, and statutory deductions (PF, TDS)',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final basic = int.tryParse(basicCtrl.text.trim()) ?? 0;
              final hra = int.tryParse(hraCtrl.text.trim()) ?? 0;
              final allow = int.tryParse(allowCtrl.text.trim()) ?? 0;
              final pf = int.tryParse(pfCtrl.text.trim()) ?? 0;
              final tds = int.tryParse(tdsCtrl.text.trim()) ?? 0;

              final session = ref.read(authControllerProvider).session;
              if (session == null) return;
              final api = ref.read(apiClientProvider);

              try {
                await api.upsertStaffSalaryStructure(
                  session: session,
                  payload: {
                    'staffId': staffId,
                    'basicSalary': basic * 100, // paise
                    'hra': hra * 100,
                    'allowances': allow * 100,
                    'pfDeduction': pf * 100,
                    'esiDeduction': 0,
                    'tdsDeduction': tds * 100,
                    'effectiveFrom': DateFormat('yyyy-MM-dd')
                        .format(DateTime.now()),
                  },
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to update salary: $e')),
                  );
                }
              }
            },
            child: const Text('Save Structure'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: basicCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Basic Salary (₹ / month) *',
                hintText: '35000',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hraCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'HRA (₹) *',
                      hintText: '12000',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: allowCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Allowances (₹)',
                      hintText: '5000',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pfCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PF Deduction (₹)',
                      hintText: '4200',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: tdsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'TDS Deduction (₹)',
                      hintText: '2500',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Salary structure saved');
    }
  }

  Future<void> _generateMonthlyPayrollRun() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    try {
      final res = await api.generateMonthlyPayroll(
        session: session,
        payload: {'month': _selectedPayrollMonth, 'year': _selectedPayrollYear},
      );
      _loadCurrentTabData();
      setState(() {
        _success =
            'Batch payroll generated (${res['generatedCount']} records generated for ${_monthName(_selectedPayrollMonth)} $_selectedPayrollYear)';
      });
    } catch (e) {
      setState(() => _error = 'Payroll generation failed: $e');
    }
  }

  Future<void> _markPayrollPaid(String recordId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    try {
      await api.markPayrollPaid(
        session: session,
        recordId: recordId,
        payload: {
          'paidOn': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'paymentReference':
              'BANK-TRANS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        },
      );
      _loadCurrentTabData();
      setState(() => _success = 'Salary record marked as PAID');
    } catch (e) {
      setState(() => _error = 'Failed to mark as paid: $e');
    }
  }

  // ==========================================
  // 4. Hostel & Visitor Handlers & Dialogs
  // ==========================================
  Future<void> _showAddHostelRoomDialog() async {
    final blockCtrl = TextEditingController(text: 'Block A');
    final roomCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '2');
    final feeCtrl = TextEditingController(text: '25000');
    String roomType = 'boys';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Add Hostel Room',
          subtitle: 'Create boarding room and bed capacity',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final block = blockCtrl.text.trim();
                final room = roomCtrl.text.trim();
                final cap = int.tryParse(capCtrl.text.trim()) ?? 2;
                final fee = int.tryParse(feeCtrl.text.trim()) ?? 0;

                if (block.isEmpty || room.isEmpty) return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.createHostelRoom(
                    session: session,
                    payload: {
                      'blockName': block,
                      'roomNumber': room,
                      'roomType': roomType,
                      'capacity': cap,
                      'termFee': fee * 100, // paise
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to add room: $e')),
                    );
                  }
                }
              },
              child: const Text('Create Room'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: blockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Block Name *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Room Number *',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: roomType,
                      decoration: const InputDecoration(
                        labelText: 'Room Type *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'boys',
                          child: Text('Boys Hostel'),
                        ),
                        DropdownMenuItem(
                          value: 'girls',
                          child: Text('Girls Hostel'),
                        ),
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('Staff Quarters'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => roomType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: capCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity (Beds) *',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Term Fee (₹)'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Hostel room created');
    }
  }

  Future<void> _showAllocateHostelDialog() async {
    final availableRooms = _hostelRooms
        .where(
          (room) =>
              (room['occupiedCount'] as int? ?? 0) <
              (room['capacity'] as int? ?? 0),
        )
        .toList();
    if (widget.students.isEmpty || availableRooms.isEmpty) {
      setState(
        () => _error = 'A student and an available hostel room are required.',
      );
      return;
    }
    var studentId = widget.students.first['id'] as String;
    var roomId = availableRooms.first['id'] as String;
    final bed = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'Allocate hostel bed',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allocate bed'),
            ),
          ],
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: studentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: widget.students
                    .map(
                      (student) => DropdownMenuItem(
                        value: student['id'] as String,
                        child: Text(
                          student['fullName']?.toString() ?? 'Student',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => studentId = value ?? studentId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: roomId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Room'),
                items: availableRooms
                    .map(
                      (room) => DropdownMenuItem(
                        value: room['id'] as String,
                        child: Text(
                          '${room['blockName']} · ${room['roomNumber']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => roomId = value ?? roomId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bed,
                decoration: const InputDecoration(labelText: 'Bed number'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true || bed.text.trim().isEmpty) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .allocateHostelBed(
            session: session,
            payload: {
              'studentId': studentId,
              'roomId': roomId,
              'bedNumber': bed.text.trim(),
            },
          );
      setState(() => _success = 'Hostel bed allocated.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not allocate hostel bed: $e');
    }
  }

  Future<void> _vacateHostelAllocation(String allocationId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .vacateHostelBed(session: session, allocationId: allocationId);
      setState(() => _success = 'Hostel bed vacated.');
      await _loadCurrentTabData();
    } catch (e) {
      setState(() => _error = 'Could not vacate bed: $e');
    }
  }

  Future<void> _showIssueGatePassDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(
      text:
          'PASS-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final vehicleCtrl = TextEditingController();
    String visitType = 'admin';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Issue Visitor Gate Pass',
          subtitle: 'Register campus guest check-in with security badge',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final purpose = purposeCtrl.text.trim();
                final badge = badgeCtrl.text.trim();

                if (name.isEmpty ||
                    phone.isEmpty ||
                    purpose.isEmpty ||
                    badge.isEmpty)
                  return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.createVisitorGatePass(
                    session: session,
                    payload: {
                      'visitorName': name,
                      'phone': phone,
                      'purpose': purpose,
                      'personToVisitType': visitType,
                      'badgeNumber': badge,
                      'vehicleNumber': vehicleCtrl.text.trim().isNotEmpty
                          ? vehicleCtrl.text.trim()
                          : null,
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to issue gate pass: $e')),
                    );
                  }
                }
              },
              child: const Text('Issue Pass'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Visitor Full Name *',
                  hintText: 'e.g. Ramesh Patel',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '+91 98765 43210',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: visitType,
                      decoration: const InputDecoration(labelText: 'Meeting *'),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administration / Principal'),
                        ),
                        DropdownMenuItem(
                          value: 'staff',
                          child: Text('Faculty Member'),
                        ),
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student Guardian Visit'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => visitType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit *',
                  hintText: 'e.g. Inquiring regarding fee receipt & transfer certificate',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: badgeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Badge Number *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: vehicleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        hintText: 'e.g. KA-05-MM-1234',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Visitor gate pass issued');
    }
  }

  Future<void> _checkoutVisitor(String passId) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final api = ref.read(apiClientProvider);

    try {
      await api.checkoutVisitorGatePass(session: session, passId: passId);
      _loadCurrentTabData();
      setState(() => _success = 'Visitor checked out successfully');
    } catch (e) {
      setState(() => _error = 'Failed to check out visitor: $e');
    }
  }

  // ==========================================
  // 5. Health & Infirmary Handlers & Dialogs
  // ==========================================
  Future<void> _showHealthProfileDialog() async {
    if (widget.students.isEmpty) {
      setState(
        () => _error = 'Add a student before creating a health profile.',
      );
      return;
    }
    var studentId = widget.students.first['id'] as String;
    final blood = TextEditingController();
    final allergies = TextEditingController();
    final conditions = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    Future<void> loadProfile(String id) async {
      final session = ref.read(authControllerProvider).session;
      if (session == null) return;
      try {
        final profile = await ref
            .read(apiClientProvider)
            .getStudentHealthProfile(session: session, studentId: id);
        blood.text = profile['bloodGroup']?.toString() ?? '';
        allergies.text = profile['allergies']?.toString() ?? '';
        conditions.text = profile['chronicConditions']?.toString() ?? '';
        contact.text = profile['emergencyContactName']?.toString() ?? '';
        phone.text = profile['emergencyContactPhone']?.toString() ?? '';
        notes.text = profile['doctorNotes']?.toString() ?? '';
      } catch (_) {
        blood.clear();
        allergies.clear();
        conditions.clear();
        contact.clear();
        phone.clear();
        notes.clear();
      }
    }

    await loadProfile(studentId);
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          title: 'Student health profile',
          subtitle: 'Emergency medical details available to authorised staff.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save profile'),
            ),
          ],
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: studentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: widget.students
                    .map(
                      (student) => DropdownMenuItem(
                        value: student['id'] as String,
                        child: Text(
                          student['fullName']?.toString() ?? 'Student',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  studentId = value;
                  await loadProfile(value);
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: blood,
                decoration: const InputDecoration(labelText: 'Blood group'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: allergies,
                decoration: const InputDecoration(labelText: 'Allergies'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conditions,
                decoration: const InputDecoration(
                  labelText: 'Chronic conditions',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contact,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact phone',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Doctor notes'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true ||
        blood.text.trim().length < 2 ||
        contact.text.trim().length < 2 ||
        phone.text.trim().length < 7)
      return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .upsertStudentHealthProfile(
            session: session,
            payload: {
              'studentId': studentId,
              'bloodGroup': blood.text.trim(),
              'allergies': allergies.text.trim(),
              'chronicConditions': conditions.text.trim(),
              'emergencyContactName': contact.text.trim(),
              'emergencyContactPhone': phone.text.trim(),
              'doctorNotes': notes.text.trim(),
            },
          );
      setState(() => _success = 'Health profile saved.');
    } catch (e) {
      setState(() => _error = 'Could not save health profile: $e');
    }
  }

  Future<void> _showLogInfirmaryVisitDialog() async {
    if (widget.students.isEmpty) {
      setState(() => _error = 'No students registered to log infirmary visit.');
      return;
    }

    String selectedStudentId = widget.students.first['id'] as String;
    final symptomsCtrl = TextEditingController();
    final treatmentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool parentNotified = false;
    bool followUpNeeded = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: 'Record Campus Infirmary Visit',
          subtitle:
              'Log student medical triage, treatments, and parental notice',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final symptoms = symptomsCtrl.text.trim();
                final treatment = treatmentCtrl.text.trim();
                if (symptoms.isEmpty || treatment.isEmpty) return;

                final session = ref.read(authControllerProvider).session;
                if (session == null) return;
                final api = ref.read(apiClientProvider);

                try {
                  await api.recordInfirmaryVisit(
                    session: session,
                    payload: {
                      'studentId': selectedStudentId,
                      'symptoms': symptoms,
                      'treatmentGiven': treatment,
                      'parentNotified': parentNotified,
                      'followUpNeeded': followUpNeeded,
                      'notes': notesCtrl.text.trim().isNotEmpty
                          ? notesCtrl.text.trim()
                          : null,
                    },
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to log visit: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Record'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student *'),
                items: widget.students.map((s) {
                  final name = s['fullName'] as String? ?? 'Student';
                  final adm = s['admissionNumber'] as String? ?? '';
                  return DropdownMenuItem<String>(
                    value: s['id'] as String,
                    child: Text('$name ($adm)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null)
                    setDialogState(() => selectedStudentId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symptomsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observed Symptoms *',
                  hintText: 'e.g. High fever (100.4 F), sore throat, nausea',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: treatmentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Treatment Given *',
                  hintText: 'e.g. Administered oral hydration, 250mg paracetamol, 1 hr bed rest',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Attending Notes',
                  hintText: 'Additional clinical observations',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: parentNotified,
                    onChanged: (v) =>
                        setDialogState(() => parentNotified = v ?? false),
                  ),
                  const Text(
                    'Parent Notified via Call/SMS',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  Checkbox(
                    value: followUpNeeded,
                    onChanged: (v) =>
                        setDialogState(() => followUpNeeded = v ?? false),
                  ),
                  const Text(
                    'Follow-Up Needed',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      _loadCurrentTabData();
      setState(() => _success = 'Infirmary visit recorded');
    }
  }

  // ==========================================
  // Helper Formatters
  // ==========================================
  String _monthName(int m) {
    if (m >= 1 && m <= 12) {
      const months = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return months[m];
    }
    return 'Month $m';
  }

  String _formatCurrency(num? amountPaise) {
    if (amountPaise == null) return '₹0';
    final inr = (amountPaise / 100).round();
    return '₹${NumberFormat('#,##,###').format(inr)}';
  }

  // ==========================================
  // Main UI Build
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Campus Operations Ecosystem',
          description: 'Enterprise physical campus management: library circulation, assets, staff payroll, hostels, and infirmary.',
          primaryAction: _tabController.index == 0
              ? ElevatedButton.icon(
                  onPressed: _showAddBookDialog,
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text('Add Book'),
                )
              : _tabController.index == 1
              ? ElevatedButton.icon(
                  onPressed: _showAddInventoryItemDialog,
                  icon: const Icon(Icons.add_box_rounded, size: 16),
                  label: const Text('Register Asset'),
                )
              : _tabController.index == 2
              ? ElevatedButton.icon(
                  onPressed: _generateMonthlyPayrollRun,
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text('Generate Payroll Run'),
                )
              : _tabController.index == 3
              ? ElevatedButton.icon(
                  onPressed: _showIssueGatePassDialog,
                  icon: const Icon(Icons.badge_rounded, size: 16),
                  label: const Text('Issue Gate Pass'),
                )
              : ElevatedButton.icon(
                  onPressed: _showLogInfirmaryVisitDialog,
                  icon: const Icon(Icons.medical_services_rounded, size: 16),
                  label: const Text('Log Visit'),
                ),
          secondaryActions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Module Data',
              onPressed: _loading ? null : _loadCurrentTabData,
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          FeedbackBanner.error(message: _error!),
        ],
        if (_success != null) ...[
          const SizedBox(height: 12),
          FeedbackBanner.success(message: _success!),
        ],
        const SizedBox(height: 16),

        // Subtabs Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.secondaryText,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.local_library_rounded, size: 18),
                text: 'Library Hub',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_rounded, size: 18),
                text: 'Inventory & Assets',
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                text: 'Staff Payroll',
              ),
              Tab(
                icon: Icon(Icons.apartment_rounded, size: 18),
                text: 'Hostel & Gate Passes',
              ),
              Tab(
                icon: Icon(Icons.health_and_safety_rounded, size: 18),
                text: 'Student Health & Infirmary',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLibraryTab(),
                _buildInventoryTab(),
                _buildPayrollTab(),
                _buildHostelTab(),
                _buildHealthTab(),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 1: Library Hub
  // ==========================================
  Widget _buildLibraryTab() {
    final titles =
        _libraryStats?['totalTitles'] as int? ?? _libraryBooks.length;
    final totalInv = _libraryStats?['totalInventory'] as int? ?? 0;
    final avail = _libraryStats?['totalAvailable'] as int? ?? 0;
    final activeLoans =
        _libraryStats?['activeLoans'] as int? ?? _libraryLoans.length;
    final fines = _libraryStats?['totalFinesPaise'] as int? ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatStrip(
            items: [
              StatItemData(label: 'Total Titles', value: titles.toString()),
              StatItemData(label: 'Total Copies', value: totalInv.toString()),
              StatItemData(
                label: 'Available on Shelf',
                value: avail.toString(),
              ),
              StatItemData(
                label: 'Active Loans',
                value: activeLoans.toString(),
              ),
              StatItemData(
                label: 'Outstanding Fines',
                value: _formatCurrency(fines),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search books by title, author, or ISBN...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (val) {
                    _bookSearch = val;
                    _loadCurrentTabData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _bookCategoryFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Categories')),
                  DropdownMenuItem(value: 'science', child: Text('Science')),
                  DropdownMenuItem(
                    value: 'mathematics',
                    child: Text('Mathematics'),
                  ),
                  DropdownMenuItem(
                    value: 'literature',
                    child: Text('Literature'),
                  ),
                  DropdownMenuItem(value: 'history', child: Text('History')),
                  DropdownMenuItem(
                    value: 'reference',
                    child: Text('Reference'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _bookCategoryFilter = val);
                    _loadCurrentTabData();
                  }
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showIssueLoanDialog,
                icon: const Icon(Icons.assignment_return_rounded, size: 16),
                label: const Text('Issue Loan'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Catalog Table
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Book Catalog & Circulation Inventory',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_libraryBooks.isEmpty)
                    const EmptyStateView(
                      icon: Icons.menu_book_rounded,
                      title: 'No books found',
                      description: 'Add books to the library catalog to begin circulation.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Book Title')),
                          DataColumn(label: Text('Author')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Shelf Location')),
                          DataColumn(label: Text('Copies (Avail/Total)')),
                          DataColumn(label: Text('ISBN')),
                        ],
                        rows: _libraryBooks.map((b) {
                          final title = b['title'] as String? ?? '';
                          final author = b['author'] as String? ?? '';
                          final cat = b['category'] as String? ?? 'general';
                          final shelf = b['shelfLocation'] as String? ?? '';
                          final total = b['totalCopies'] as int? ?? 1;
                          final av = b['availableCopies'] as int? ?? 0;
                          final isbn = b['isbn'] as String? ?? '—';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(author)),
                              DataCell(
                                StatusBadge(
                                  label: cat.toUpperCase(),
                                  tone: BadgeTone.info,
                                ),
                              ),
                              DataCell(Text(shelf)),
                              DataCell(Text('$av / $total')),
                              DataCell(Text(isbn)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Active Loans Table
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Active Borrowing & Loan Register',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_libraryLoans.isEmpty)
                    const Text('No active book loans currently recorded.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Book')),
                          DataColumn(label: Text('Member Type')),
                          DataColumn(label: Text('Issue Date')),
                          DataColumn(label: Text('Due Date')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _libraryLoans.map((loan) {
                          final loanId = loan['id'] as String;
                          final bookTitle =
                              loan['bookTitle'] as String? ?? 'Book';
                          final memberType =
                              (loan['memberType'] as String? ?? 'student')
                                  .toUpperCase();
                          final issuedAt = loan['issuedAt'] as String? ?? '';
                          final dueDate = loan['dueDate'] as String? ?? '';
                          final status = loan['status'] as String? ?? 'issued';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  bookTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(memberType)),
                              DataCell(Text(issuedAt)),
                              DataCell(Text(dueDate)),
                              DataCell(
                                status == 'issued'
                                    ? const StatusBadge(
                                        label: 'ISSUED',
                                        tone: BadgeTone.warning,
                                      )
                                    : const StatusBadge(
                                        label: 'RETURNED',
                                        tone: BadgeTone.success,
                                      ),
                              ),
                              DataCell(
                                status == 'issued'
                                    ? OutlinedButton(
                                        onPressed: () => _returnLoan(loanId),
                                        child: const Text('Return Book'),
                                      )
                                    : const Text('—'),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: Inventory & Assets
  // ==========================================
  Widget _buildInventoryTab() {
    final totalAssets = _inventoryItems.length;
    final goodCondition = _inventoryItems
        .where((i) => i['condition'] == 'good')
        .length;
    final maintenance = _inventoryItems
        .where((i) => i['condition'] == 'maintenance_required')
        .length;
    final pendingReqs = _purchaseRequests
        .where((p) => p['status'] == 'pending')
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatStrip(
            items: [
              StatItemData(
                label: 'Total Asset Types',
                value: totalAssets.toString(),
              ),
              StatItemData(
                label: 'In Good Condition',
                value: goodCondition.toString(),
              ),
              StatItemData(
                label: 'Requires Maintenance',
                value: maintenance.toString(),
              ),
              StatItemData(
                label: 'Pending Requisitions',
                value: pendingReqs.toString(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Campus Inventory & Equipment Register',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _inventoryCategoryFilter,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Categories'),
                            ),
                            DropdownMenuItem(
                              value: 'lab_equipment',
                              child: Text('Lab Equipment'),
                            ),
                            DropdownMenuItem(
                              value: 'sports_gear',
                              child: Text('Sports'),
                            ),
                            DropdownMenuItem(
                              value: 'classroom',
                              child: Text('Classroom'),
                            ),
                            DropdownMenuItem(
                              value: 'it_hardware',
                              child: Text('IT Hardware'),
                            ),
                            DropdownMenuItem(
                              value: 'furniture',
                              child: Text('Furniture'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _inventoryCategoryFilter = val);
                              _loadCurrentTabData();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _inventoryConditionFilter,
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Conditions'),
                            ),
                            DropdownMenuItem(
                              value: 'good',
                              child: Text('Good'),
                            ),
                            DropdownMenuItem(
                              value: 'fair',
                              child: Text('Fair'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance_required',
                              child: Text('Maintenance'),
                            ),
                            DropdownMenuItem(
                              value: 'damaged',
                              child: Text('Damaged'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _inventoryConditionFilter = val);
                              _loadCurrentTabData();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showAddInventoryItemDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Register asset'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_inventoryItems.isEmpty)
                    const EmptyStateView(
                      icon: Icons.inventory_2_rounded,
                      title: 'No inventory items recorded',
                      description: 'Register institutional equipment, sports gear, and laboratory apparatus.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Asset Code')),
                          DataColumn(label: Text('Item Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Quantity (Avail/Total)')),
                          DataColumn(label: Text('Condition')),
                          DataColumn(label: Text('Location')),
                          DataColumn(label: Text('Cost')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _inventoryItems.map((item) {
                          final code = item['itemCode'] as String? ?? '';
                          final name = item['name'] as String? ?? '';
                          final cat = item['category'] as String? ?? '';
                          final qty = item['quantity'] as int? ?? 1;
                          final avail = item['availableQuantity'] as int? ?? 0;
                          final unit = item['unit'] as String? ?? 'pcs';
                          final condition =
                              item['condition'] as String? ?? 'good';
                          final loc = item['roomLocation'] as String? ?? '';
                          final cost = item['purchaseCost'] as int?;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                StatusBadge(
                                  label: cat.toUpperCase(),
                                  tone: BadgeTone.info,
                                ),
                              ),
                              DataCell(Text('$avail / $qty $unit')),
                              DataCell(
                                StatusBadge.inventoryCondition(condition),
                              ),
                              DataCell(Text(loc)),
                              DataCell(
                                Text(
                                  cost != null ? _formatCurrency(cost) : '—',
                                ),
                              ),
                              DataCell(
                                OutlinedButton(
                                  onPressed: avail > 0
                                      ? () => _showAllocateInventoryDialog(item)
                                      : null,
                                  child: const Text('Allocate'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Active asset allocations',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_inventoryAllocations
                      .where((a) => a['status'] == 'active')
                      .isEmpty)
                    const Text('No assets are currently allocated.')
                  else
                    ..._inventoryAllocations
                        .where((a) => a['status'] == 'active')
                        .map(
                          (allocation) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${allocation['itemName'] ?? 'Asset'} · ${allocation['staffName'] ?? 'Staff'}',
                            ),
                            subtitle: Text(
                              '${allocation['quantity'] ?? 1} · ${allocation['purpose'] ?? ''}',
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _returnInventoryAllocation(
                                allocation['id'] as String,
                              ),
                              child: const Text('Record return'),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Purchase Requisitions
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Procurement & Purchase Requisitions',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _showPurchaseRequestDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('New requisition'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_purchaseRequests.isEmpty)
                    const Text('No purchase requisitions submitted.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Requisition Item')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Est. Cost')),
                          DataColumn(label: Text('Requested By')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _purchaseRequests.map((req) {
                          final name = req['itemName'] as String? ?? '';
                          final cat = req['category'] as String? ?? '';
                          final qty = req['quantity'] as int? ?? 1;
                          final cost = req['estimatedCost'] as int? ?? 0;
                          final staffName =
                              req['requestedByStaffName'] as String? ??
                              'Faculty';
                          final status = req['status'] as String? ?? 'pending';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(cat.toUpperCase())),
                              DataCell(Text(qty.toString())),
                              DataCell(Text(_formatCurrency(cost))),
                              DataCell(Text(staffName)),
                              DataCell(
                                StatusBadge(
                                  label: status.toUpperCase(),
                                  tone: status == 'approved'
                                      ? BadgeTone.success
                                      : status == 'rejected'
                                      ? BadgeTone.error
                                      : BadgeTone.warning,
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  tooltip: 'Update requisition status',
                                  onSelected: (value) =>
                                      _reviewPurchaseRequest(req, value),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'approved',
                                      child: Text('Approve'),
                                    ),
                                    PopupMenuItem(
                                      value: 'ordered',
                                      child: Text('Mark ordered'),
                                    ),
                                    PopupMenuItem(
                                      value: 'received',
                                      child: Text('Mark received'),
                                    ),
                                    PopupMenuItem(
                                      value: 'rejected',
                                      child: Text('Reject'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: Staff Payroll
  // ==========================================
  Widget _buildPayrollTab() {
    final totalStructures = _salaryStructures.length;
    final totalNetPaise = _payrollRecords.fold<int>(
      0,
      (acc, r) => acc + ((r['netSalary'] as int?) ?? 0),
    );
    final paidCount = _payrollRecords
        .where((r) => r['status'] == 'paid')
        .length;
    final draftCount = _payrollRecords
        .where((r) => r['status'] != 'paid')
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatStrip(
            items: [
              StatItemData(
                label: 'Configured Staff',
                value: totalStructures.toString(),
              ),
              StatItemData(
                label: 'Monthly Net Payroll',
                value: _formatCurrency(totalNetPaise),
              ),
              StatItemData(
                label: 'Disbursed (Paid)',
                value: paidCount.toString(),
              ),
              StatItemData(
                label: 'Pending Payout',
                value: draftCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Period Selector Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Payroll Period: ${_monthName(_selectedPayrollMonth)} $_selectedPayrollYear',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _selectedPayrollMonth,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(_monthName(i + 1)),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPayrollMonth = val);
                      _loadCurrentTabData();
                    }
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedPayrollYear,
                  items: [2025, 2026, 2027]
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPayrollYear = val);
                      _loadCurrentTabData();
                    }
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showConfigureSalaryDialog(null),
                  icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                  label: const Text('Configure Salary'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payroll Records Table
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Monthly Payroll Disbursement Run',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_payrollRecords.isEmpty)
                    const EmptyStateView(
                      icon: Icons.payments_rounded,
                      title: 'No payroll records generated for this month',
                      description: 'Click "Generate Payroll Run" to batch calculate staff salaries and deductions.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Staff Member')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Basic Pay')),
                          DataColumn(label: Text('Allowances')),
                          DataColumn(label: Text('Deductions')),
                          DataColumn(label: Text('Net Pay')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _payrollRecords.map((rec) {
                          final recordId = rec['id'] as String;
                          final name = rec['staffName'] as String? ?? 'Staff';
                          final role = rec['staffRole'] as String? ?? 'Teacher';
                          final basic = rec['basicSalary'] as int? ?? 0;
                          final allow = rec['allowances'] as int? ?? 0;
                          final ded = rec['deductions'] as int? ?? 0;
                          final net = rec['netSalary'] as int? ?? 0;
                          final status = rec['status'] as String? ?? 'draft';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(role)),
                              DataCell(Text(_formatCurrency(basic))),
                              DataCell(Text(_formatCurrency(allow))),
                              DataCell(Text(_formatCurrency(ded))),
                              DataCell(
                                Text(
                                  _formatCurrency(net),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(StatusBadge.payrollStatus(status)),
                              DataCell(
                                status != 'paid'
                                    ? ElevatedButton(
                                        onPressed: () =>
                                            _markPayrollPaid(recordId),
                                        child: const Text('Mark Paid'),
                                      )
                                    : const Icon(
                                        Icons.verified_rounded,
                                        size: 20,
                                        color: AppColors.statusSuccess,
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: Hostel & Gate Passes
  // ==========================================
  Widget _buildHostelTab() {
    final totalRooms = _hostelRooms.length;
    final totalCapacity = _hostelRooms.fold<int>(
      0,
      (acc, r) => acc + ((r['capacity'] as int?) ?? 0),
    );
    final totalOccupied = _hostelRooms.fold<int>(
      0,
      (acc, r) => acc + ((r['occupiedCount'] as int?) ?? 0),
    );
    final activeVisitors = _visitorPasses
        .where((v) => v['status'] == 'active')
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatStrip(
            items: [
              StatItemData(
                label: 'Total Hostel Rooms',
                value: totalRooms.toString(),
              ),
              StatItemData(
                label: 'Total Bed Capacity',
                value: totalCapacity.toString(),
              ),
              StatItemData(
                label: 'Occupied Beds',
                value: totalOccupied.toString(),
              ),
              StatItemData(
                label: 'Active Allocations',
                value: _hostelAllocations.length.toString(),
              ),
              StatItemData(
                label: 'Active Visitors On-Campus',
                value: activeVisitors.toString(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Hostel Rooms
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Hostel Blocks & Bed Availability',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showAddHostelRoomDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Room'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _showAllocateHostelDialog,
                        icon: const Icon(Icons.bed_rounded, size: 16),
                        label: const Text('Allocate bed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_hostelRooms.isEmpty)
                    const EmptyStateView(
                      icon: Icons.apartment_rounded,
                      title: 'No hostel rooms registered',
                      description:
                          'Add hostel blocks, room types, and bed capacities.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Block')),
                          DataColumn(label: Text('Room Number')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Beds (Occupied / Cap)')),
                          DataColumn(label: Text('Term Fee')),
                        ],
                        rows: _hostelRooms.map((room) {
                          final block = room['blockName'] as String? ?? '';
                          final roomNum = room['roomNumber'] as String? ?? '';
                          final type = (room['roomType'] as String? ?? 'boys')
                              .toUpperCase();
                          final cap = room['capacity'] as int? ?? 2;
                          final occ = room['occupiedCount'] as int? ?? 0;
                          final fee = room['termFee'] as int? ?? 0;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  block,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(roomNum)),
                              DataCell(
                                StatusBadge(label: type, tone: BadgeTone.info),
                              ),
                              DataCell(Text('$occ / $cap beds')),
                              DataCell(Text(_formatCurrency(fee))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Active hostel allocations',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_hostelAllocations
                      .where((a) => a['status'] == 'active')
                      .isEmpty)
                    const Text('No active hostel allocations.')
                  else
                    ..._hostelAllocations
                        .where((a) => a['status'] == 'active')
                        .map(
                          (allocation) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              allocation['studentName']?.toString() ??
                                  'Student',
                            ),
                            subtitle: Text(
                              '${allocation['blockName'] ?? ''} ${allocation['roomNumber'] ?? ''} · Bed ${allocation['bedNumber'] ?? ''}',
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _vacateHostelAllocation(
                                allocation['id'] as String,
                              ),
                              child: const Text('Vacate'),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Visitor Gate Passes
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Campus Gate Passes & Visitor Security Log',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showIssueGatePassDialog,
                        icon: const Icon(Icons.badge_rounded, size: 16),
                        label: const Text('New Pass'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_visitorPasses.isEmpty)
                    const Text('No visitor gate passes logged.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Badge #')),
                          DataColumn(label: Text('Visitor Name')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Purpose')),
                          DataColumn(label: Text('Check-In Time')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _visitorPasses.map((pass) {
                          final passId = pass['id'] as String;
                          final badge = pass['badgeNumber'] as String? ?? '';
                          final name = pass['visitorName'] as String? ?? '';
                          final phone = pass['phone'] as String? ?? '';
                          final purpose = pass['purpose'] as String? ?? '';
                          final checkIn = pass['checkInAt'] != null
                              ? DateFormat('HH:mm dd MMM').format(
                                  DateTime.parse(pass['checkInAt'] as String),
                                )
                              : '';
                          final status = pass['status'] as String? ?? 'active';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  badge,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(phone)),
                              DataCell(Text(purpose)),
                              DataCell(Text(checkIn)),
                              DataCell(
                                status == 'active'
                                    ? const StatusBadge(
                                        label: 'ON CAMPUS',
                                        tone: BadgeTone.warning,
                                      )
                                    : const StatusBadge(
                                        label: 'CHECKED OUT',
                                        tone: BadgeTone.success,
                                      ),
                              ),
                              DataCell(
                                status == 'active'
                                    ? OutlinedButton(
                                        onPressed: () =>
                                            _checkoutVisitor(passId),
                                        child: const Text('Check Out'),
                                      )
                                    : const Text('—'),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: Student Health & Infirmary
  // ==========================================
  Widget _buildHealthTab() {
    final visitsToday = _infirmaryVisits.length;
    final parentNotifiedCount = _infirmaryVisits
        .where((v) => v['parentNotified'] == true)
        .length;
    final followUpCount = _infirmaryVisits
        .where((v) => v['followUpNeeded'] == true)
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatStrip(
            items: [
              StatItemData(
                label: 'Total Infirmary Visits',
                value: visitsToday.toString(),
              ),
              StatItemData(
                label: 'Parents Notified',
                value: parentNotifiedCount.toString(),
              ),
              StatItemData(
                label: 'Follow-ups Required',
                value: followUpCount.toString(),
              ),
              StatItemData(
                label: 'Emergency Directory',
                value: '${widget.students.length} Students',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Daily Infirmary Visits Log
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.rMd,
              side: const BorderSide(color: AppColors.primaryBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Campus Infirmary Daily Log',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showLogInfirmaryVisitDialog,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Log Visit'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _showHealthProfileDialog,
                        icon: const Icon(
                          Icons.medical_information_outlined,
                          size: 16,
                        ),
                        label: const Text('Health profiles'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_infirmaryVisits.isEmpty)
                    const EmptyStateView(
                      icon: Icons.medical_services_rounded,
                      title: 'No infirmary visits recorded',
                      description: 'Log visits, symptoms, administered medications, and parent notifications.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Student')),
                          DataColumn(label: Text('Admission #')),
                          DataColumn(label: Text('Symptoms')),
                          DataColumn(label: Text('Treatment Administered')),
                          DataColumn(label: Text('Attending Staff')),
                          DataColumn(label: Text('Parent Notified')),
                        ],
                        rows: _infirmaryVisits.map((visit) {
                          final name =
                              visit['studentName'] as String? ?? 'Student';
                          final adm = visit['admissionNumber'] as String? ?? '';
                          final sym = visit['symptoms'] as String? ?? '';
                          final trt = visit['treatmentGiven'] as String? ?? '';
                          final staff =
                              visit['attendedByStaffName'] as String? ??
                              'Nurse';
                          final notified =
                              visit['parentNotified'] as bool? ?? false;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(adm)),
                              DataCell(Text(sym)),
                              DataCell(Text(trt)),
                              DataCell(Text(staff)),
                              DataCell(
                                notified
                                    ? const StatusBadge(
                                        label: 'NOTIFIED',
                                        tone: BadgeTone.success,
                                      )
                                    : const StatusBadge(
                                        label: 'NOT NOTIFIED',
                                        tone: BadgeTone.neutral,
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
