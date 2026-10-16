enum AppRole {
  admin,
  teacher,
  student,
  parent,
  accountant,
  admissionsOfficer,
  principal;

  static AppRole fromString(String raw) {
    switch (raw) {
      case 'admin':
        return AppRole.admin;
      case 'teacher':
        return AppRole.teacher;
      case 'student':
        return AppRole.student;
      case 'parent':
        return AppRole.parent;
      case 'accountant':
        return AppRole.accountant;
      case 'admissions_officer':
      case 'admissionsOfficer':
        return AppRole.admissionsOfficer;
      case 'principal':
        return AppRole.principal;
      default:
        return AppRole.values.byName(raw);
    }
  }

  String toRoleString() {
    switch (this) {
      case AppRole.admissionsOfficer:
        return 'admissions_officer';
      default:
        return name;
    }
  }
}

enum AttendanceKind { daily, period }

enum AttendanceStatus { present, absent, late, excused }

class AuthSession {
  const AuthSession({
    required this.email,
    required this.roles,
    required this.schoolId,
    this.displayName,
    this.bearerToken,
    this.devNeonUserId,
  });

  final String email;
  final String? displayName;
  final List<AppRole> roles;
  final String schoolId;
  final String? bearerToken;
  final String? devNeonUserId;

  bool get isAdmin => roles.contains(AppRole.admin);
  bool get isTeacher => roles.contains(AppRole.teacher);
  bool get isAccountant => roles.contains(AppRole.accountant);
  bool get isAdmissionsOfficer => roles.contains(AppRole.admissionsOfficer);
  bool get isPrincipal => roles.contains(AppRole.principal);
  bool get isInstitutionalStaff =>
      isAdmin || isAccountant || isAdmissionsOfficer || isPrincipal;
  bool get isPortalUser =>
      roles.contains(AppRole.student) || roles.contains(AppRole.parent);

  Map<String, Object?> toJson() => {
        'email': email,
        'displayName': displayName,
        'roles': roles.map((role) => role.toRoleString()).toList(),
        'schoolId': schoolId,
        'bearerToken': bearerToken,
        'devNeonUserId': devNeonUserId,
      };

  AuthSession copyWith({
    String? email,
    String? displayName,
    List<AppRole>? roles,
    String? schoolId,
    String? bearerToken,
    String? devNeonUserId,
  }) =>
      AuthSession(
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        roles: roles ?? this.roles,
        schoolId: schoolId ?? this.schoolId,
        bearerToken: bearerToken ?? this.bearerToken,
        devNeonUserId: devNeonUserId ?? this.devNeonUserId,
      );

  static AuthSession fromJson(Map<String, Object?> json) => AuthSession(
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        roles: ((json['roles'] as List?) ?? const [])
            .map((role) => AppRole.fromString(role as String))
            .toList(),
        schoolId: json['schoolId'] as String,
        bearerToken: json['bearerToken'] as String?,
        devNeonUserId: json['devNeonUserId'] as String?,
      );
}

class SelectOption {
  const SelectOption({required this.id, required this.label});

  final String id;
  final String label;

  factory SelectOption.fromJson(Map<String, Object?> json, String labelKey) {
    return SelectOption(id: json['id'] as String, label: json[labelKey] as String);
  }
}

class StudentRow {
  const StudentRow({
    required this.id,
    required this.admissionNumber,
    required this.fullName,
    this.rollNumber,
  });

  final String id;
  final String admissionNumber;
  final String fullName;
  final String? rollNumber;

  factory StudentRow.fromJson(Map<String, Object?> json) => StudentRow(
        id: json['id'] as String,
        admissionNumber: json['admissionNumber'] as String? ?? '',
        fullName: json['fullName'] as String,
        rollNumber: json['rollNumber'] as String?,
      );
}
