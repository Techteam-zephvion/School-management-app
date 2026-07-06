"use client";

import { useState } from "react";
import Link from "next/link";
import { Menu, MessagesSquare, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { NotificationBell, type AppNotification } from "@/components/notification-bell";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { AppSidebar } from "@/components/app-sidebar";
import { logout } from "@/lib/actions/auth";
import type { Role } from "@/lib/auth/session";

function initials(name: string) {
  return (
    name
      .trim()
      .split(/\s+/)
      .map((p) => p[0])
      .slice(0, 2)
      .join("")
      .toUpperCase() || "?"
  );
}

export function AppTopbar({
  fullName,
  avatarUrl,
  role,
  schoolName,
  userId,
  notifications,
}: {
  fullName: string;
  avatarUrl: string | null;
  role: Role;
  schoolName: string;
  userId?: string;
  notifications?: AppNotification[];
}) {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <header className="flex h-16 shrink-0 items-center gap-3 border-b border-border bg-card px-4 sm:px-6">
      <Button
        variant="ghost"
        size="icon"
        className="lg:hidden"
        onClick={() => setMobileNavOpen(true)}
      >
        <Menu className="size-5" />
      </Button>
      <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
        <SheetContent side="left" className="w-64 p-0">
          <SheetTitle className="sr-only">Navigation</SheetTitle>
          <AppSidebar role={role} />
        </SheetContent>
      </Sheet>

      <div className="relative hidden max-w-sm flex-1 sm:block">
        <Search className="absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          placeholder="Search students, classes, or exams…"
          className="pl-9"
          disabled
        />
      </div>

      <div className="ml-auto flex items-center gap-1 sm:gap-2">
        {userId ? <NotificationBell userId={userId} initial={notifications ?? []} /> : null}
        <Button variant="ghost" size="icon" aria-label="Messages" asChild>
          <Link href="/messages">
            <MessagesSquare className="size-5" />
          </Link>
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-muted">
            <div className="hidden text-right sm:block">
              <div className="text-sm leading-tight font-semibold">{fullName}</div>
              <div className="text-xs leading-tight text-muted-foreground capitalize">
                {role.replace("_", " ")} · {schoolName}
              </div>
            </div>
            <Avatar className="size-9">
              {avatarUrl && <AvatarImage src={avatarUrl} alt={fullName} />}
              <AvatarFallback>{initials(fullName)}</AvatarFallback>
            </Avatar>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>
              <div className="font-semibold">{fullName}</div>
              <div className="text-xs font-normal text-muted-foreground capitalize">
                {role.replace("_", " ")} · {schoolName}
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <a href="/settings/profile">Profile settings</a>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild variant="destructive">
              <form action={logout} className="w-full">
                <button type="submit" className="w-full text-left">
                  Log out
                </button>
              </form>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
