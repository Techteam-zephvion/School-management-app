const NEON_AUTH_URL = 'https://ep-polished-silence-b52ozwm7.neonauth.c-7.us-east-2.aws.neon.tech/neondb/auth';
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  throw new Error('DATABASE_URL environment variable is required.');
}
const DEMO_PASSWORD = 'Schoolic@2026';
const ORIGIN = 'https://schoolic.pages.dev';

import { execFileSync } from 'node:child_process';

function executeSql(query: string, params: any[] = []): any[] {
  const stdout = execFileSync(
    'curl',
    [
      '-4',
      '-sS',
      '-X',
      'POST',
      'https://ep-polished-silence-b52ozwm7.c-7.us-east-2.aws.neon.tech/sql',
      '-H',
      `neon-connection-string: ${DATABASE_URL}`,
      '-H',
      'Content-Type: application/json',
      '-d',
      JSON.stringify({ query, params }),
    ],
    { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
  );
  const data = JSON.parse(stdout);
  return data.rows || [];
}

async function sql(strings: TemplateStringsArray, ...values: any[]): Promise<any[]> {
  let query = '';
  const params: any[] = [];
  for (let i = 0; i < strings.length; i++) {
    query += strings[i];
    if (i < values.length) {
      params.push(values[i]);
      query += `$${params.length}`;
    }
  }
  return executeSql(query, params);
}

function makeUuid(prefix: string, index: number): string {
  return `${prefix}${index.toString().padStart(12, '0')}`;
}

interface UserToProvision {
  name: string;
  email: string;
  role: 'admin' | 'teacher' | 'student';
  staffCode?: string;
  subjectName?: string;
  subjectCode?: string;
  admissionNo?: string;
  rollNo?: string;
  classGrade?: number;
  sectionName?: string;
  guardianName?: string;
  guardianPhone?: string;
  relationship?: string;
  feeAmount?: number;
  feeStatus?: 'paid' | 'partial' | 'pending';
  feePaid?: number;
}

const USERS_LIST: UserToProvision[] = [
  // 1 Admin
  {
    name: 'Dr. Meera Das',
    email: 'admin@portfolio.schoolic.test',
    role: 'admin',
    staffCode: 'ADM-001',
  },
  // 5 Teachers
  {
    name: 'Priya Menon',
    email: 'teacher-login@portfolio.schoolic.test',
    role: 'teacher',
    staffCode: 'TCH-101',
    subjectName: 'Mathematics',
    subjectCode: 'MATH',
  },
  {
    name: 'Arjun Rao',
    email: 'teacher.rao@portfolio.schoolic.test',
    role: 'teacher',
    staffCode: 'TCH-102',
    subjectName: 'Science',
    subjectCode: 'SCI',
  },
  {
    name: 'Sara Iyer',
    email: 'teacher.iyer@portfolio.schoolic.test',
    role: 'teacher',
    staffCode: 'TCH-103',
    subjectName: 'English',
    subjectCode: 'ENG',
  },
  {
    name: 'Vikramaditya Sengupta',
    email: 'teacher.sengupta@portfolio.schoolic.test',
    role: 'teacher',
    staffCode: 'TCH-104',
    subjectName: 'Social Studies',
    subjectCode: 'SST',
  },
  {
    name: 'Dr. Anita Kulkarni',
    email: 'teacher.kulkarni@portfolio.schoolic.test',
    role: 'teacher',
    staffCode: 'TCH-105',
    subjectName: 'Computer Science',
    subjectCode: 'CS',
  },
  // 10 Students
  {
    name: 'Aarav Sharma',
    email: 'student@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-001',
    rollNo: '06A-01',
    classGrade: 6,
    sectionName: 'A',
    guardianName: 'Nisha Sharma',
    guardianPhone: '+91-90000-02001',
    relationship: 'Mother',
    feeAmount: 40000,
    feeStatus: 'paid',
    feePaid: 40000,
  },
  {
    name: 'Anika Nair',
    email: 'student.anika@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-002',
    rollNo: '06A-02',
    classGrade: 6,
    sectionName: 'A',
    guardianName: 'Vikram Nair',
    guardianPhone: '+91-90000-02002',
    relationship: 'Father',
    feeAmount: 40000,
    feeStatus: 'partial',
    feePaid: 20000,
  },
  {
    name: 'Ishaan Gupta',
    email: 'student.ishaan@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-003',
    rollNo: '06A-03',
    classGrade: 6,
    sectionName: 'A',
    guardianName: 'Ritika Gupta',
    guardianPhone: '+91-90000-02003',
    relationship: 'Mother',
    feeAmount: 40000,
    feeStatus: 'paid',
    feePaid: 40000,
  },
  {
    name: 'Maya Krishnan',
    email: 'student.maya@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-004',
    rollNo: '06B-01',
    classGrade: 6,
    sectionName: 'B',
    guardianName: 'Dev Krishnan',
    guardianPhone: '+91-90000-02004',
    relationship: 'Father',
    feeAmount: 40000,
    feeStatus: 'pending',
    feePaid: 0,
  },
  {
    name: 'Kabir Ali',
    email: 'student.kabir@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-005',
    rollNo: '06B-02',
    classGrade: 6,
    sectionName: 'B',
    guardianName: 'Farah Ali',
    guardianPhone: '+91-90000-02005',
    relationship: 'Mother',
    feeAmount: 40000,
    feeStatus: 'paid',
    feePaid: 40000,
  },
  {
    name: 'Diya Patel',
    email: 'student.diya@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-006',
    rollNo: '07A-01',
    classGrade: 7,
    sectionName: 'A',
    guardianName: 'Mohan Patel',
    guardianPhone: '+91-90000-02006',
    relationship: 'Father',
    feeAmount: 42000,
    feeStatus: 'paid',
    feePaid: 42000,
  },
  {
    name: 'Rohan Sen',
    email: 'student.rohan@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-007',
    rollNo: '07A-02',
    classGrade: 7,
    sectionName: 'A',
    guardianName: 'Ananya Sen',
    guardianPhone: '+91-90000-02007',
    relationship: 'Mother',
    feeAmount: 42000,
    feeStatus: 'partial',
    feePaid: 21000,
  },
  {
    name: 'Tara Joseph',
    email: 'student.tara@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-008',
    rollNo: '07B-01',
    classGrade: 7,
    sectionName: 'B',
    guardianName: 'Leena Joseph',
    guardianPhone: '+91-90000-02008',
    relationship: 'Mother',
    feeAmount: 42000,
    feeStatus: 'paid',
    feePaid: 42000,
  },
  {
    name: 'Vivaan Mehta',
    email: 'student.vivaan@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-009',
    rollNo: '08A-01',
    classGrade: 8,
    sectionName: 'A',
    guardianName: 'Kavita Mehta',
    guardianPhone: '+91-90000-02009',
    relationship: 'Mother',
    feeAmount: 45000,
    feeStatus: 'paid',
    feePaid: 45000,
  },
  {
    name: 'Naina Roy',
    email: 'student.naina@portfolio.schoolic.test',
    role: 'student',
    admissionNo: 'PA-010',
    rollNo: '08B-01',
    classGrade: 8,
    sectionName: 'B',
    guardianName: 'Amit Roy',
    guardianPhone: '+91-90000-02010',
    relationship: 'Father',
    feeAmount: 45000,
    feeStatus: 'pending',
    feePaid: 0,
  },
];

async function getOrCreateNeonUser(sql: any, name: string, email: string, passwordHash: string): Promise<string> {
  const normalizedEmail = email.trim().toLowerCase();

  // 1. Check if user already exists in neon_auth.user
  const [existing] = await sql`
    SELECT id FROM neon_auth.user WHERE email = ${normalizedEmail} LIMIT 1
  `;
  if (existing?.id) {
    return existing.id;
  }

  // 2. Insert into neon_auth.user and neon_auth.account with verified password hash
  const [newUser] = await sql`
    INSERT INTO neon_auth.user (id, name, email, "emailVerified", "createdAt", "updatedAt", role, banned)
    VALUES (gen_random_uuid(), ${name}, ${normalizedEmail}, true, now(), now(), 'user', false)
    RETURNING id
  `;

  await sql`
    INSERT INTO neon_auth.account (id, "userId", "accountId", "providerId", password, "createdAt", "updatedAt")
    VALUES (gen_random_uuid(), ${newUser.id}, ${newUser.id}, 'credential', ${passwordHash}, now(), now())
  `;

  return newUser.id;
}

async function main() {
  console.log('🚀 Starting Schoolic Production Demo Accounts Seeding...');

  const SCHOOL_ID = '10000000-0000-4000-8000-000000000001';
  const ACADEMIC_YEAR_ID = '10000000-0000-4000-8000-000000000101';

  try {
    // 0. Fetch template password hash from verified Schoolic@2026 account
    const [templateAcc] = await sql`
      SELECT password FROM neon_auth.account WHERE password IS NOT NULL LIMIT 1
    `;
    const passwordHash = templateAcc?.password;
    if (!passwordHash) {
      throw new Error('Could not find existing password hash in neon_auth.account');
    }

    // 1. Resolve Neon Auth User IDs for all 16 users
    console.log('🔑 Provisioning Neon Auth user accounts...');
    const userNeonMap = new Map<string, string>();
    for (const u of USERS_LIST) {
      process.stdout.write(`   Provisioning ${u.email}... `);
      const neonUserId = await getOrCreateNeonUser(sql, u.name, u.email, passwordHash);
      userNeonMap.set(u.email, neonUserId);
      console.log(`OK (Neon ID: ${neonUserId})`);
    }

    console.log('💾 Beginning Database Seeding...');
    const tx = sql;
      // 1. School
      await tx`
        INSERT INTO schools (id, name, code, updated_at)
        VALUES (${SCHOOL_ID}, 'Schoolic Portfolio Academy', 'PORTFOLIO', now())
        ON CONFLICT (id) DO UPDATE SET name = excluded.name, code = excluded.code, updated_at = now()
      `;

      // 2. Academic Year
      await tx`
        INSERT INTO academic_years (id, school_id, name, starts_on, ends_on, is_active, updated_at)
        VALUES (${ACADEMIC_YEAR_ID}, ${SCHOOL_ID}, '2026-2027', '2026-06-01', '2027-04-30', true, now())
        ON CONFLICT (id) DO UPDATE SET is_active = true, updated_at = now()
      `;

      // 3. Classes
      const classMap = new Map<number, string>([
        [6, '10000000-0000-4000-8000-000000000401'],
        [7, '10000000-0000-4000-8000-000000000402'],
        [8, '10000000-0000-4000-8000-000000000403'],
      ]);
      for (const [grade, classId] of classMap.entries()) {
        await tx`
          INSERT INTO classes (id, school_id, name, sort_order, updated_at)
          VALUES (${classId}, ${SCHOOL_ID}, ${'Grade ' + grade}, ${grade}, now())
          ON CONFLICT (id) DO UPDATE SET name = excluded.name, sort_order = excluded.sort_order, updated_at = now()
        `;
      }

      // 4. Sections
      const sectionMap = new Map<string, string>([
        ['6A', '10000000-0000-4000-8000-000000000501'],
        ['6B', '10000000-0000-4000-8000-000000000502'],
        ['7A', '10000000-0000-4000-8000-000000000503'],
        ['7B', '10000000-0000-4000-8000-000000000504'],
        ['8A', '10000000-0000-4000-8000-000000000505'],
        ['8B', '10000000-0000-4000-8000-000000000506'],
      ]);
      for (const [code, secId] of sectionMap.entries()) {
        const grade = parseInt(code[0]);
        const secName = code[1];
        const classId = classMap.get(grade)!;
        await tx`
          INSERT INTO sections (id, school_id, class_id, name, updated_at)
          VALUES (${secId}, ${SCHOOL_ID}, ${classId}, ${secName}, now())
          ON CONFLICT (id) DO UPDATE SET name = excluded.name, updated_at = now()
        `;
      }

      // 5. Subjects
      const subjectsData = [
        { id: '10000000-0000-4000-8000-000000000601', name: 'Mathematics', code: 'MATH' },
        { id: '10000000-0000-4000-8000-000000000602', name: 'Science', code: 'SCI' },
        { id: '10000000-0000-4000-8000-000000000603', name: 'English', code: 'ENG' },
        { id: '10000000-0000-4000-8000-000000000604', name: 'Social Studies', code: 'SST' },
        { id: '10000000-0000-4000-8000-000000000605', name: 'Computer Science', code: 'CS' },
      ];
      for (const subj of subjectsData) {
        await tx`
          INSERT INTO subjects (id, school_id, name, code, updated_at)
          VALUES (${subj.id}, ${SCHOOL_ID}, ${subj.name}, ${subj.code}, now())
          ON CONFLICT (id) DO UPDATE SET name = excluded.name, code = excluded.code, updated_at = now()
        `;
      }

      // 6. App Users & User Roles
      const appUserIds = new Map<string, string>();
      for (let i = 0; i < USERS_LIST.length; i++) {
        const u = USERS_LIST[i];
        const neonUserId = userNeonMap.get(u.email)!;
        // Check existing user by email or neon_user_id
        const [existing] = await tx`
          SELECT id FROM app_users WHERE email = ${u.email} OR neon_user_id = ${neonUserId} LIMIT 1
        `;
        let userId = existing?.id;
        if (!userId) {
          userId = makeUuid('10000000-0000-4000-8000-', 200 + i + 1);
        }
        appUserIds.set(u.email, userId);

        await tx`
          INSERT INTO app_users (id, school_id, neon_user_id, email, display_name, is_active, updated_at)
          VALUES (${userId}, ${SCHOOL_ID}, ${neonUserId}, ${u.email}, ${u.name}, true, now())
          ON CONFLICT (id) DO UPDATE SET
            neon_user_id = excluded.neon_user_id,
            email = excluded.email,
            display_name = excluded.display_name,
            is_active = true,
            updated_at = now()
        `;

        await tx`
          INSERT INTO user_roles (id, user_id, role, updated_at)
          VALUES (gen_random_uuid(), ${userId}, ${u.role}, now())
          ON CONFLICT (user_id, role) DO UPDATE SET updated_at = now()
        `;
      }

      // 7. Staff (Admin & 5 Teachers)
      const staffList = [
        {
          id: '10000000-0000-4000-8000-000000000301',
          code: 'ADM-001',
          name: 'Dr. Meera Das',
          email: 'admin@portfolio.schoolic.test',
          phone: '+91-98450-01001',
          isTeacher: false,
        },
        {
          id: '10000000-0000-4000-8000-000000000302',
          code: 'TCH-101',
          name: 'Priya Menon',
          email: 'teacher-login@portfolio.schoolic.test',
          phone: '+91-98450-01101',
          isTeacher: true,
        },
        {
          id: '10000000-0000-4000-8000-000000000303',
          code: 'TCH-102',
          name: 'Arjun Rao',
          email: 'teacher.rao@portfolio.schoolic.test',
          phone: '+91-98450-01102',
          isTeacher: true,
        },
        {
          id: '10000000-0000-4000-8000-000000000304',
          code: 'TCH-103',
          name: 'Sara Iyer',
          email: 'teacher.iyer@portfolio.schoolic.test',
          phone: '+91-98450-01103',
          isTeacher: true,
        },
        {
          id: '10000000-0000-4000-8000-000000000305',
          code: 'TCH-104',
          name: 'Vikramaditya Sengupta',
          email: 'teacher.sengupta@portfolio.schoolic.test',
          phone: '+91-98450-01104',
          isTeacher: true,
        },
        {
          id: '10000000-0000-4000-8000-000000000306',
          code: 'TCH-105',
          name: 'Dr. Anita Kulkarni',
          email: 'teacher.kulkarni@portfolio.schoolic.test',
          phone: '+91-98450-01105',
          isTeacher: true,
        },
      ];

      for (const s of staffList) {
        const userId = appUserIds.get(s.email)!;
        await tx`
          INSERT INTO staff (id, school_id, user_id, staff_code, full_name, email, phone, is_teacher, updated_at)
          VALUES (${s.id}, ${SCHOOL_ID}, ${userId}, ${s.code}, ${s.name}, ${s.email}, ${s.phone}, ${s.isTeacher}, now())
          ON CONFLICT (id) DO UPDATE SET
            user_id = excluded.user_id,
            full_name = excluded.full_name,
            email = excluded.email,
            phone = excluded.phone,
            is_teacher = excluded.is_teacher,
            updated_at = now()
        `;
      }

      // Link Class Teachers
      await tx`UPDATE sections SET class_teacher_staff_id = '10000000-0000-4000-8000-000000000302' WHERE id = '10000000-0000-4000-8000-000000000501'`; // 6A -> Priya Menon
      await tx`UPDATE sections SET class_teacher_staff_id = '10000000-0000-4000-8000-000000000303' WHERE id = '10000000-0000-4000-8000-000000000503'`; // 7A -> Arjun Rao
      await tx`UPDATE sections SET class_teacher_staff_id = '10000000-0000-4000-8000-000000000304' WHERE id = '10000000-0000-4000-8000-000000000505'`; // 8A -> Sara Iyer

      // 8. Teacher Assignments
      const assignments = [
        // Priya Menon (Math) -> 6A, 6B
        { id: '10000000-0000-4000-8000-000000000901', staffId: '10000000-0000-4000-8000-000000000302', sec: '6A', subj: '10000000-0000-4000-8000-000000000601', classId: classMap.get(6)! },
        { id: '10000000-0000-4000-8000-000000000902', staffId: '10000000-0000-4000-8000-000000000302', sec: '6B', subj: '10000000-0000-4000-8000-000000000601', classId: classMap.get(6)! },
        // Arjun Rao (Science) -> 7A, 7B
        { id: '10000000-0000-4000-8000-000000000903', staffId: '10000000-0000-4000-8000-000000000303', sec: '7A', subj: '10000000-0000-4000-8000-000000000602', classId: classMap.get(7)! },
        { id: '10000000-0000-4000-8000-000000000904', staffId: '10000000-0000-4000-8000-000000000303', sec: '7B', subj: '10000000-0000-4000-8000-000000000602', classId: classMap.get(7)! },
        // Sara Iyer (English) -> 8A, 8B
        { id: '10000000-0000-4000-8000-000000000905', staffId: '10000000-0000-4000-8000-000000000304', sec: '8A', subj: '10000000-0000-4000-8000-000000000603', classId: classMap.get(8)! },
        { id: '10000000-0000-4000-8000-000000000906', staffId: '10000000-0000-4000-8000-000000000304', sec: '8B', subj: '10000000-0000-4000-8000-000000000603', classId: classMap.get(8)! },
        // Vikramaditya Sengupta (Social Studies) -> 6B, 7B
        { id: '10000000-0000-4000-8000-000000000907', staffId: '10000000-0000-4000-8000-000000000305', sec: '6B', subj: '10000000-0000-4000-8000-000000000604', classId: classMap.get(6)! },
        { id: '10000000-0000-4000-8000-000000000908', staffId: '10000000-0000-4000-8000-000000000305', sec: '7B', subj: '10000000-0000-4000-8000-000000000604', classId: classMap.get(7)! },
        // Anita Kulkarni (CS) -> 7A, 8A
        { id: '10000000-0000-4000-8000-000000000909', staffId: '10000000-0000-4000-8000-000000000306', sec: '7A', subj: '10000000-0000-4000-8000-000000000605', classId: classMap.get(7)! },
        { id: '10000000-0000-4000-8000-000000000910', staffId: '10000000-0000-4000-8000-000000000306', sec: '8A', subj: '10000000-0000-4000-8000-000000000605', classId: classMap.get(8)! },
      ];

      for (const a of assignments) {
        const secId = sectionMap.get(a.sec)!;
        await tx`
          INSERT INTO teacher_assignments (id, school_id, staff_id, academic_year_id, class_id, section_id, subject_id, can_take_daily_attendance, updated_at)
          VALUES (${a.id}, ${SCHOOL_ID}, ${a.staffId}, ${ACADEMIC_YEAR_ID}, ${a.classId}, ${secId}, ${a.subj}, true, now())
          ON CONFLICT (id) DO UPDATE SET can_take_daily_attendance = true, updated_at = now()
        `;
      }

      // 9. Students, Enrollments, & Guardians (10 Students)
      const studentsList = USERS_LIST.filter((u) => u.role === 'student');
      const studentIdMap = new Map<string, string>();

      for (let i = 0; i < studentsList.length; i++) {
        const s = studentsList[i];
        const studentId = `10000000-0000-4000-8000-0000000007${(i + 1).toString().padStart(2, '0')}`;
        const enrollmentId = `10000000-0000-4000-8000-0000000008${(i + 1).toString().padStart(2, '0')}`;
        const guardianId = `10000000-0000-4000-8000-0000000008${(i + 50).toString().padStart(2, '0')}`;

        studentIdMap.set(s.admissionNo!, studentId);
        const userId = appUserIds.get(s.email)!;
        const classId = classMap.get(s.classGrade!)!;
        const secCode = `${s.classGrade}${s.sectionName}`;
        const sectionId = sectionMap.get(secCode)!;

        // Student Table
        await tx`
          INSERT INTO students (id, school_id, user_id, admission_number, full_name, guardian_name, guardian_phone, is_active, updated_at)
          VALUES (${studentId}, ${SCHOOL_ID}, ${userId}, ${s.admissionNo!}, ${s.name}, ${s.guardianName!}, ${s.guardianPhone!}, true, now())
          ON CONFLICT (id) DO UPDATE SET
            user_id = excluded.user_id,
            full_name = excluded.full_name,
            guardian_name = excluded.guardian_name,
            guardian_phone = excluded.guardian_phone,
            is_active = true,
            updated_at = now()
        `;

        // Enrollment
        await tx`
          INSERT INTO student_enrollments (id, school_id, student_id, academic_year_id, class_id, section_id, roll_number, updated_at)
          VALUES (${enrollmentId}, ${SCHOOL_ID}, ${studentId}, ${ACADEMIC_YEAR_ID}, ${classId}, ${sectionId}, ${s.rollNo!}, now())
          ON CONFLICT (id) DO UPDATE SET
            class_id = excluded.class_id,
            section_id = excluded.section_id,
            roll_number = excluded.roll_number,
            updated_at = now()
        `;

        // Guardian
        await tx`
          INSERT INTO student_guardians (id, school_id, student_id, app_user_id, relationship, updated_at)
          VALUES (${guardianId}, ${SCHOOL_ID}, ${studentId}, ${userId}, ${s.relationship!}, now())
          ON CONFLICT (student_id, app_user_id) DO UPDATE SET relationship = excluded.relationship, updated_at = now()
        `;
      }

      // 10. Fee Structures & Allocations
      const feeStructId = '10000000-0000-4000-8000-000000000651';
      await tx`
        INSERT INTO fee_structures (id, school_id, academic_year_id, name, code, description, amount, frequency, due_date, updated_at)
        VALUES (${feeStructId}, ${SCHOOL_ID}, ${ACADEMIC_YEAR_ID}, 'Term 1 Composite Academic Fee', 'TERM-1-2026', 'Comprehensive tuition, lab, library, and extracurricular activities for Term 1.', 40000, 'term', '2026-11-15', now())
        ON CONFLICT (id) DO UPDATE SET amount = excluded.amount, due_date = excluded.due_date, updated_at = now()
      `;

      for (let i = 0; i < studentsList.length; i++) {
        const s = studentsList[i];
        const studentId = studentIdMap.get(s.admissionNo!)!;
        const allocId = makeUuid('10000000-0000-4000-8000-', 660 + i + 1);
        const paymentId = makeUuid('10000000-0000-4000-8000-', 670 + i + 1);

        await tx`
          INSERT INTO student_fee_allocations (id, school_id, student_id, fee_structure_id, academic_year_id, amount, due_date, status, updated_at)
          VALUES (${allocId}, ${SCHOOL_ID}, ${studentId}, ${feeStructId}, ${ACADEMIC_YEAR_ID}, ${s.feeAmount!}, '2026-11-15', ${s.feeStatus!}, now())
          ON CONFLICT (id) DO UPDATE SET status = excluded.status, amount = excluded.amount, updated_at = now()
        `;

        if (s.feePaid && s.feePaid > 0) {
          const receiptNo = `REC-2026-${(i + 1).toString().padStart(4, '0')}`;
          await tx`
            INSERT INTO fee_payments (id, school_id, allocation_id, student_id, receipt_number, amount_paid, payment_method, transaction_reference, notes, updated_at)
            VALUES (${paymentId}, ${SCHOOL_ID}, ${allocId}, ${studentId}, ${receiptNo}, ${s.feePaid}, 'upi', ${'CF-PAY-' + receiptNo}, 'Cashfree Verified Payment', now())
            ON CONFLICT (school_id, receipt_number) DO UPDATE SET amount_paid = excluded.amount_paid, updated_at = now()
          `;
        }
      }

      // 11. Attendance Sessions & Records
      // Create period sessions across Grade 6A, 6B, 7A, 7B, 8A
      const sessions = [
        { id: '10000000-0000-4000-8000-000000001001', sec: '6A', subj: '10000000-0000-4000-8000-000000000601', staff: '10000000-0000-4000-8000-000000000302', date: '2026-10-19', period: 1, classId: classMap.get(6)! },
        { id: '10000000-0000-4000-8000-000000001002', sec: '6A', subj: '10000000-0000-4000-8000-000000000601', staff: '10000000-0000-4000-8000-000000000302', date: '2026-10-20', period: 1, classId: classMap.get(6)! },
        { id: '10000000-0000-4000-8000-000000001003', sec: '6B', subj: '10000000-0000-4000-8000-000000000601', staff: '10000000-0000-4000-8000-000000000302', date: '2026-10-19', period: 2, classId: classMap.get(6)! },
        { id: '10000000-0000-4000-8000-000000001004', sec: '7A', subj: '10000000-0000-4000-8000-000000000602', staff: '10000000-0000-4000-8000-000000000303', date: '2026-10-19', period: 3, classId: classMap.get(7)! },
        { id: '10000000-0000-4000-8000-000000001005', sec: '7B', subj: '10000000-0000-4000-8000-000000000602', staff: '10000000-0000-4000-8000-000000000303', date: '2026-10-20', period: 2, classId: classMap.get(7)! },
        { id: '10000000-0000-4000-8000-000000001006', sec: '8A', subj: '10000000-0000-4000-8000-000000000603', staff: '10000000-0000-4000-8000-000000000304', date: '2026-10-19', period: 4, classId: classMap.get(8)! },
        { id: '10000000-0000-4000-8000-000000001007', sec: '8B', subj: '10000000-0000-4000-8000-000000000603', staff: '10000000-0000-4000-8000-000000000304', date: '2026-10-20', period: 3, classId: classMap.get(8)! },
      ];

      for (const ses of sessions) {
        const secId = sectionMap.get(ses.sec)!;
        await tx`
          INSERT INTO attendance_sessions (id, school_id, academic_year_id, class_id, section_id, subject_id, taken_by_staff_id, kind, attendance_date, period_number, notes, updated_at)
          VALUES (${ses.id}, ${SCHOOL_ID}, ${ACADEMIC_YEAR_ID}, ${ses.classId}, ${secId}, ${ses.subj}, ${ses.staff}, 'period', ${ses.date}, ${ses.period}, 'Regular academic session roll-call.', now())
          ON CONFLICT (id) DO UPDATE SET notes = excluded.notes, updated_at = now()
        `;
      }

      // Add Attendance Records for each student
      let recordCount = 0;
      for (const s of studentsList) {
        const studentId = studentIdMap.get(s.admissionNo!)!;
        const secCode = `${s.classGrade}${s.sectionName}`;
        const matchingSessions = sessions.filter((x) => x.sec === secCode);

        for (const ses of matchingSessions) {
          recordCount++;
          const recId = `20000000-0000-4000-8000-${recordCount.toString().padStart(12, '0')}`;
          const isLate = s.admissionNo === 'PA-002' || s.admissionNo === 'PA-007';
          const status = isLate ? 'late' : 'present';
          const remarks = isLate ? 'Arrived during assembly' : null;

          await tx`
            INSERT INTO attendance_records (id, school_id, session_id, student_id, status, remarks, updated_at)
            VALUES (${recId}, ${SCHOOL_ID}, ${ses.id}, ${studentId}, ${status}, ${remarks}, now())
            ON CONFLICT (id) DO UPDATE SET status = excluded.status, remarks = excluded.remarks, updated_at = now()
          `;
        }
      }

      // 12. Homework Assignments & Submissions
      const hwAssignments = [
        {
          id: '10000000-0000-4000-8000-000000001101',
          staffId: '10000000-0000-4000-8000-000000000302',
          sec: '6A',
          subj: '10000000-0000-4000-8000-000000000601',
          classId: classMap.get(6)!,
          title: 'Fractions & Decimals Problem Set 4',
          instructions: 'Complete exercises 4.1 to 4.3 in Chapter 4 notebook. Show all intermediate calculation steps.',
          dueDate: '2026-10-28',
        },
        {
          id: '10000000-0000-4000-8000-000000001102',
          staffId: '10000000-0000-4000-8000-000000000303',
          sec: '7A',
          subj: '10000000-0000-4000-8000-000000000602',
          classId: classMap.get(7)!,
          title: 'Acids, Bases & Salts Lab Observations',
          instructions: 'Write the experimental setup and chemical color indicators table observed during Tuesday lab.',
          dueDate: '2026-10-29',
        },
        {
          id: '10000000-0000-4000-8000-000000001103',
          staffId: '10000000-0000-4000-8000-000000000304',
          sec: '8A',
          subj: '10000000-0000-4000-8000-000000000603',
          classId: classMap.get(8)!,
          title: 'The Merchant of Venice Character Analysis',
          instructions: 'Analyze Portias courtroom speech in Act IV Scene 1. Minimum 300 words with quotes.',
          dueDate: '2026-10-30',
        },
      ];

      for (const hw of hwAssignments) {
        const secId = sectionMap.get(hw.sec)!;
        await tx`
          INSERT INTO homework_assignments (id, school_id, owner_staff_id, academic_year_id, class_id, section_id, subject_id, title, instructions, due_date, status, updated_at)
          VALUES (${hw.id}, ${SCHOOL_ID}, ${hw.staffId}, ${ACADEMIC_YEAR_ID}, ${hw.classId}, ${secId}, ${hw.subj}, ${hw.title}, ${hw.instructions}, ${hw.dueDate}, 'published', now())
          ON CONFLICT (id) DO UPDATE SET title = excluded.title, instructions = excluded.instructions, updated_at = now()
        `;
      }

      // Add submissions for students in 6A
      const students6A = studentsList.filter((s) => s.classGrade === 6 && s.sectionName === 'A');
      for (let i = 0; i < students6A.length; i++) {
        const s = students6A[i];
        const studentId = studentIdMap.get(s.admissionNo!)!;
        const subId = makeUuid('10000000-0000-4000-8000-', 1200 + i + 1);
        await tx`
          INSERT INTO homework_submissions (id, school_id, assignment_id, student_id, content, status, marks_obtained, teacher_feedback, reviewed_by_staff_id, submitted_at, reviewed_at, updated_at)
          VALUES (${subId}, ${SCHOOL_ID}, '10000000-0000-4000-8000-000000001101', ${studentId}, 'Attached solution steps for exercises 4.1 through 4.3.', 'reviewed', ${23 + i}, 'Good handwriting and structured calculation steps.', '10000000-0000-4000-8000-000000000302', now(), now(), now())
          ON CONFLICT (assignment_id, student_id) DO UPDATE SET status = excluded.status, marks_obtained = excluded.marks_obtained, teacher_feedback = excluded.teacher_feedback, updated_at = now()
        `;
      }

      // 13. Exams & Marks
      const examsList = [
        { id: '10000000-0000-4000-8000-000000001301', name: 'Mid-Term Mathematics Assessment', classId: classMap.get(6)!, sec: '6A', subj: '10000000-0000-4000-8000-000000000601', maxMarks: 50, date: '2026-09-25' },
        { id: '10000000-0000-4000-8000-000000001302', name: 'Mid-Term Science Assessment', classId: classMap.get(7)!, sec: '7A', subj: '10000000-0000-4000-8000-000000000602', maxMarks: 50, date: '2026-09-26' },
        { id: '10000000-0000-4000-8000-000000001303', name: 'Mid-Term English Assessment', classId: classMap.get(8)!, sec: '8A', subj: '10000000-0000-4000-8000-000000000603', maxMarks: 50, date: '2026-09-27' },
      ];

      for (const ex of examsList) {
        const secId = sectionMap.get(ex.sec)!;
        await tx`
          INSERT INTO exams (id, school_id, academic_year_id, class_id, section_id, subject_id, name, exam_date, max_marks, status, updated_at)
          VALUES (${ex.id}, ${SCHOOL_ID}, ${ACADEMIC_YEAR_ID}, ${ex.classId}, ${secId}, ${ex.subj}, ${ex.name}, ${ex.date}, ${ex.maxMarks}, 'published', now())
          ON CONFLICT (id) DO UPDATE SET name = excluded.name, max_marks = excluded.max_marks, updated_at = now()
        `;
      }

      // Record marks for students6A
      for (let i = 0; i < students6A.length; i++) {
        const s = students6A[i];
        const studentId = studentIdMap.get(s.admissionNo!)!;
        const markId = makeUuid('10000000-0000-4000-8000-', 1400 + i + 1);
        const marks = 42 + i * 2;
        await tx`
          INSERT INTO exam_marks (id, school_id, exam_id, student_id, recorded_by_staff_id, marks_obtained, remarks, updated_at)
          VALUES (${markId}, ${SCHOOL_ID}, '10000000-0000-4000-8000-000000001301', ${studentId}, '10000000-0000-4000-8000-000000000302', ${marks}, 'Excellent conceptual clarity.', now())
          ON CONFLICT (exam_id, student_id) DO UPDATE SET marks_obtained = excluded.marks_obtained, remarks = excluded.remarks, updated_at = now()
        `;
      }

    console.log('✅ Database seeding completed successfully!');
    console.log('📋 SUMMARY OF PROVISIONED DEMO ACCOUNTS:');
    console.log('------------------------------------------------------------------------------------------');
    console.log('Role       | Display Name             | Email                                | Password');
    console.log('------------------------------------------------------------------------------------------');
    for (const u of USERS_LIST) {
      console.log(`${u.role.padEnd(10)} | ${u.name.padEnd(24)} | ${u.email.padEnd(36)} | ${DEMO_PASSWORD}`);
    }
    console.log('------------------------------------------------------------------------------------------');
  } catch (err) {
    console.error('❌ Error executing seeding script:', err);
    process.exit(1);
  }
}

main().catch(console.error);
