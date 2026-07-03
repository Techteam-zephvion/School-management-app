import { GraduationCap } from "lucide-react";
import { AuthBrandPanel } from "@/components/auth/auth-brand-panel";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="grid min-h-screen w-full lg:grid-cols-[1.05fr_1fr] xl:grid-cols-[1.1fr_1fr]">
      <AuthBrandPanel />

      {/* form side -- soft blue gradient wash echoing the invite email */}
      <div
        className="relative flex flex-col items-center justify-center px-5 py-10 sm:px-8"
        style={{
          backgroundImage:
            "linear-gradient(180deg, #e9f0ff 0%, #f4f7fc 45%, #f8fafc 100%)",
        }}
      >
        {/* compact brand -- shown only when the side panel is hidden */}
        <div className="mb-8 flex items-center gap-3 lg:hidden">
          <span className="flex size-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <GraduationCap className="size-5" />
          </span>
          <span className="leading-tight">
            <span className="block text-lg font-bold text-foreground">
              EduSphere
            </span>
            <span className="block text-[11px] font-medium tracking-wide text-muted-foreground">
              TEACHER PORTAL
            </span>
          </span>
        </div>

        <div className="w-full max-w-md">{children}</div>
      </div>
    </div>
  );
}
