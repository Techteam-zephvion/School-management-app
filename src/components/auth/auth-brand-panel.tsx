import { GraduationCap, ClipboardCheck, BarChart3, MessagesSquare } from "lucide-react";

const FEATURES = [
  {
    icon: ClipboardCheck,
    title: "Manage Attendance",
    body: "Take daily attendance in one tap and track trends across your sections.",
  },
  {
    icon: BarChart3,
    title: "Grade Exams",
    body: "Enter marks and generate instant performance analytics per student.",
  },
  {
    icon: MessagesSquare,
    title: "Communicate",
    body: "Reach parents securely with notices, messages, and real-time alerts.",
  },
];

/**
 * The brand/hero half of the split-screen auth layout. Deep-navy gradient with
 * the EduSphere identity + feature highlights (mirrors the invite email). Hidden
 * on small screens, where the compact header in AuthLayout stands in for it.
 */
export function AuthBrandPanel() {
  return (
    <div className="relative hidden overflow-hidden bg-primary lg:flex lg:flex-col lg:justify-between lg:p-12 xl:p-16">
      {/* ambient gradient glows */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(60% 50% at 15% 0%, rgba(37,99,235,0.55) 0%, rgba(37,99,235,0) 60%), radial-gradient(50% 45% at 100% 100%, rgba(124,58,237,0.45) 0%, rgba(124,58,237,0) 55%)",
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-20 -top-24 size-72 rounded-full opacity-40 blur-3xl"
        style={{ background: "rgba(59,130,246,0.5)" }}
      />

      <div className="relative flex items-center gap-3">
        <span className="flex size-11 items-center justify-center rounded-xl bg-white/10 ring-1 ring-white/20 backdrop-blur">
          <GraduationCap className="size-6 text-white" />
        </span>
        <span className="leading-tight">
          <span className="block text-xl font-bold tracking-tight text-white">
            EduSphere
          </span>
          <span className="block text-xs font-medium tracking-wide text-white/60">
            TEACHER PORTAL
          </span>
        </span>
      </div>

      <div className="relative">
        <h2 className="max-w-md text-3xl font-bold leading-tight tracking-tight text-white xl:text-4xl">
          Everything your school needs, in one calm place.
        </h2>
        <p className="mt-4 max-w-md text-base leading-relaxed text-white/70">
          Attendance, homework, exams, fees, and parent communication — designed
          to save teachers time and keep families in the loop.
        </p>

        <ul className="mt-10 space-y-4">
          {FEATURES.map((f) => (
            <li key={f.title} className="flex items-start gap-4">
              <span className="mt-0.5 flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/10 ring-1 ring-white/15 backdrop-blur">
                <f.icon className="size-5 text-white" />
              </span>
              <span>
                <span className="block text-sm font-semibold text-white">
                  {f.title}
                </span>
                <span className="block text-sm leading-relaxed text-white/60">
                  {f.body}
                </span>
              </span>
            </li>
          ))}
        </ul>
      </div>

      <p className="relative text-xs text-white/40">
        EduSphere © 2026 · Trusted by schools to protect student data.
      </p>
    </div>
  );
}
