import { GraduationCap } from "lucide-react";
import { cn } from "@/lib/utils";

export function BrandMark({
  subtitle = "TEACHER PORTAL",
  className,
}: {
  subtitle?: string;
  className?: string;
}) {
  return (
    <div className={cn("flex items-center gap-3", className)}>
      <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground">
        <GraduationCap className="size-5" />
      </span>
      <span className="leading-tight">
        <span className="block text-lg font-bold text-foreground">
          EduSphere
        </span>
        <span className="block text-[11px] font-medium tracking-wide text-muted-foreground">
          {subtitle}
        </span>
      </span>
    </div>
  );
}
