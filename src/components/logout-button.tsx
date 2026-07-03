import { LogOut } from "lucide-react";
import { logout } from "@/lib/actions/auth";
import { Button } from "@/components/ui/button";

export function LogoutButton({
  variant = "outline",
}: {
  variant?: "outline" | "ghost";
}) {
  return (
    <form action={logout}>
      <Button type="submit" variant={variant} className="gap-2">
        <LogOut className="size-4" />
        Log out
      </Button>
    </form>
  );
}
