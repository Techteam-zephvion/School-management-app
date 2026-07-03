"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { HelpCircle, Settings } from "lucide-react";
import { BrandMark } from "@/components/brand-mark";
import { cn } from "@/lib/utils";
import { primaryNav, settingsNav, platformNav, type NavItem } from "@/lib/nav";
import type { Role } from "@/lib/auth/session";

function NavLink({ item, active }: { item: NavItem; active: boolean }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className={cn(
        "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
        active
          ? "bg-sidebar-accent text-sidebar-accent-foreground"
          : "text-sidebar-foreground/80 hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground"
      )}
    >
      <Icon className="size-4.5 shrink-0" />
      {item.label}
    </Link>
  );
}

export function AppSidebar({ role }: { role: Role }) {
  const pathname = usePathname();
  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === href : pathname.startsWith(href);

  const nav = primaryNav.filter((item) => item.roles.includes(role));
  const settings = settingsNav.filter((item) => item.roles.includes(role));
  const platform = platformNav.filter((item) => item.roles.includes(role));

  return (
    <div className="flex h-full w-64 shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      <div className="px-4 py-5">
        <BrandMark />
      </div>
      <nav className="flex-1 space-y-1 overflow-y-auto px-3">
        {nav.map((item) => (
          <NavLink key={item.href} item={item} active={isActive(item.href)} />
        ))}

        {settings.length > 0 && (
          <>
            <div className="mt-4 mb-1 px-3 text-xs font-semibold tracking-wide text-muted-foreground">
              SETTINGS
            </div>
            {settings.map((item) => (
              <NavLink key={item.href} item={item} active={isActive(item.href)} />
            ))}
          </>
        )}

        {platform.length > 0 && (
          <>
            <div className="mt-4 mb-1 px-3 text-xs font-semibold tracking-wide text-muted-foreground">
              PLATFORM
            </div>
            {platform.map((item) => (
              <NavLink key={item.href} item={item} active={isActive(item.href)} />
            ))}
          </>
        )}
      </nav>
      <div className="space-y-1 border-t border-sidebar-border px-3 py-3">
        <NavLink
          item={{ href: "/settings/profile", label: "Settings", icon: Settings, roles: [role] }}
          active={isActive("/settings/profile")}
        />
        <NavLink
          item={{ href: "/help", label: "Help Center", icon: HelpCircle, roles: [role] }}
          active={isActive("/help")}
        />
      </div>
    </div>
  );
}
