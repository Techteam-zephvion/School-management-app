import type { LucideIcon } from "lucide-react";
import {
  LayoutDashboard,
  Users,
  ClipboardCheck,
  ChartColumnBig,
  BookOpen,
  CalendarClock,
  Megaphone,
  CalendarX2,
  Wallet,
  Bus,
  MessagesSquare,
  BarChart3,
  Building2,
  GraduationCap,
  UserCog,
  ShieldCheck,
} from "lucide-react";
import type { Role } from "@/lib/auth/session";

export type NavItem = {
  href: string;
  label: string;
  icon: LucideIcon;
  roles: Role[];
};

// Matches the EduSphere Figma sidebar (school_teacher portal/*.png) and the route
// map in doc 03 §2.1, role-filtered per the feature matrix in doc 01 §4.
export const primaryNav: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard, roles: ["school_admin", "teacher"] },
  { href: "/students", label: "Students", icon: Users, roles: ["school_admin", "teacher"] },
  { href: "/attendance", label: "Attendance", icon: ClipboardCheck, roles: ["school_admin", "teacher"] },
  { href: "/exams", label: "Marks & Exams", icon: ChartColumnBig, roles: ["school_admin", "teacher"] },
  { href: "/homework", label: "Homework", icon: BookOpen, roles: ["school_admin", "teacher"] },
  { href: "/timetable", label: "Timetable", icon: CalendarClock, roles: ["school_admin", "teacher"] },
  { href: "/notices", label: "Announcements", icon: Megaphone, roles: ["school_admin", "teacher"] },
  { href: "/leave", label: "Leave", icon: CalendarX2, roles: ["school_admin", "teacher"] },
  { href: "/settings/fees", label: "Fees", icon: Wallet, roles: ["school_admin", "teacher"] },
  { href: "/transport", label: "Transport", icon: Bus, roles: ["school_admin", "teacher"] },
  { href: "/messages", label: "Communication", icon: MessagesSquare, roles: ["school_admin", "teacher"] },
  { href: "/reports", label: "Reports", icon: BarChart3, roles: ["school_admin"] },
];

export const settingsNav: NavItem[] = [
  { href: "/settings/school", label: "School Profile", icon: Building2, roles: ["school_admin"] },
  { href: "/settings/classes", label: "Classes & Subjects", icon: GraduationCap, roles: ["school_admin"] },
  { href: "/settings/staff", label: "Staff", icon: UserCog, roles: ["school_admin"] },
  { href: "/settings/roles", label: "Roles", icon: ShieldCheck, roles: ["school_admin"] },
];

export const platformNav: NavItem[] = [
  { href: "/platform/schools", label: "Schools", icon: Building2, roles: ["super_admin"] },
];
