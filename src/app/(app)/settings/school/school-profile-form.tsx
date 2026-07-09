"use client";

import { useActionState } from "react";
import { toast } from "sonner";
import { Building2 } from "lucide-react";
import { updateSchoolProfile } from "@/lib/actions/academic";
import type { Tables } from "@/lib/supabase/database.types";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function SchoolProfileForm({ school }: { school: Tables<"schools"> }) {
  const [state, formAction, pending] = useActionState(
    async (prev: Awaited<ReturnType<typeof updateSchoolProfile>>, fd: FormData) => {
      const result = await updateSchoolProfile(prev, fd);
      if (!result?.error) toast.success("School profile saved.");
      return result;
    },
    undefined
  );

  return (
    <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
      {/* Card header */}
      <div className="border-b border-slate-100 px-5 py-4">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Building2 className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Profile</h2>
            <p className="text-xs text-slate-500">Shown to parents and on official documents.</p>
          </div>
        </div>
      </div>

      <CardContent className="px-5 py-5">
        <form action={formAction} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="name" className="text-xs font-semibold text-slate-600">School name</Label>
            <Input id="name" name="name" defaultValue={school.name} required />
          </div>
          <div className="space-y-2">
            <Label htmlFor="address" className="text-xs font-semibold text-slate-600">Address</Label>
            <Input id="address" name="address" defaultValue={school.address ?? ""} />
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-2">
              <Label htmlFor="city" className="text-xs font-semibold text-slate-600">City</Label>
              <Input id="city" name="city" defaultValue={school.city ?? ""} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="state" className="text-xs font-semibold text-slate-600">State</Label>
              <Input id="state" name="state" defaultValue={school.state ?? ""} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="pincode" className="text-xs font-semibold text-slate-600">Pincode</Label>
              <Input id="pincode" name="pincode" defaultValue={school.pincode ?? ""} />
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="phone" className="text-xs font-semibold text-slate-600">Phone</Label>
              <Input id="phone" name="phone" defaultValue={school.phone ?? ""} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="email" className="text-xs font-semibold text-slate-600">Email</Label>
              <Input id="email" name="email" type="email" defaultValue={school.email ?? ""} />
            </div>
          </div>
          {state?.error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {state.error}
            </div>
          )}
          <div className="flex justify-end">
            <Button type="submit" disabled={pending} className="gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              {pending ? "Saving…" : "Save changes"}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
