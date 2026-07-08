"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Bus, MapPin, Clock, UserPlus, X, Loader2 } from "lucide-react";
import { assignStudentToBus, removeStudentFromBus } from "@/lib/actions/transport";
import type { RouteRow, StopRow, RiderRow, BusLoc } from "./page";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { formatMoney } from "@/lib/utils";
import { LiveMap } from "./live-map";

type Student = { id: string; name: string; admissionNo: string };

function fmtTime(t: string | null) {
  if (!t) return null;
  const [h, m] = t.split(":");
  return `${h.padStart(2, "0")}:${m}`;
}

export function TransportClassTeacher({
  routes,
  stops,
  riders,
  available,
  locations,
  userId,
}: {
  routes: RouteRow[];
  stops: StopRow[];
  riders: RiderRow[];
  available: Student[];
  locations: BusLoc[];
  userId: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();
  const routeName = new Map(routes.map((r) => [r.id, r.name]));
  const stopTime = new Map(stops.map((s) => [s.id, s.pickup_time]));

  function run(fn: () => Promise<{ error?: string } | void>, ok?: string) {
    startTransition(async () => {
      const res = await fn();
      if (res?.error) toast.error(res.error);
      else {
        if (ok) toast.success(ok);
        setOpen(false);
        router.refresh();
      }
    });
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Transport"
        description="Track your class's buses and add students to a route."
        action={
          <Button onClick={() => setOpen(true)} disabled={routes.length === 0 || available.length === 0} className="gap-2">
            <UserPlus className="size-4" /> Add student to a bus
          </Button>
        }
      />

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Live map</CardTitle>
          <CardDescription>Buses carrying students from your class.</CardDescription>
        </CardHeader>
        <CardContent>
          <LiveMap routes={routes.map((r) => ({ id: r.id, name: r.name }))} initial={locations} userId={userId} />
        </CardContent>
      </Card>

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Bus riders in your class</CardTitle>
          <CardDescription>You can add or remove your own students; routes and stops are set by the admin.</CardDescription>
        </CardHeader>
        <CardContent className="divide-y divide-border/60 p-0">
          {riders.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-12 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <Bus className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No students in your class take the bus yet.</p>
              {routes.length > 0 && available.length > 0 && (
                <Button size="sm" variant="outline" className="mt-1 gap-1.5" onClick={() => setOpen(true)}>
                  <UserPlus className="size-4" /> Add a student
                </Button>
              )}
            </div>
          ) : (
            riders.map((r) => (
              <div key={r.studentId} className="flex items-center gap-3 px-5 py-3">
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{r.studentName}</p>
                  <p className="truncate text-xs text-muted-foreground">{r.admissionNo}</p>
                </div>
                <div className="flex flex-wrap items-center justify-end gap-2">
                  <Badge variant="secondary" className="gap-1">
                    <Bus className="size-3" /> {routeName.get(r.routeId) ?? "Route"}
                  </Badge>
                  {r.stopName && (
                    <Badge variant="outline" className="gap-1">
                      <MapPin className="size-3" /> {r.stopName}
                    </Badge>
                  )}
                  {r.stopId && fmtTime(stopTime.get(r.stopId) ?? null) && (
                    <Badge variant="outline" className="gap-1 tabular-nums">
                      <Clock className="size-3" /> {fmtTime(stopTime.get(r.stopId) ?? null)}
                    </Badge>
                  )}
                  <button
                    type="button"
                    disabled={isPending}
                    onClick={() => run(() => removeStudentFromBus(r.studentId), "Removed from bus.")}
                    aria-label={`Remove ${r.studentName}`}
                    className="flex size-6 items-center justify-center rounded text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                  >
                    <X className="size-3.5" />
                  </button>
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add a student to a bus</DialogTitle>
            <DialogDescription>Only students from your class, on a route the admin has created.</DialogDescription>
          </DialogHeader>
          <AssignForm
            routes={routes}
            stops={stops}
            available={available}
            pending={isPending}
            onSubmit={(fd) => run(() => assignStudentToBus(undefined, fd), "Student added to the bus.")}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
}

function AssignForm({
  routes,
  stops,
  available,
  pending,
  onSubmit,
}: {
  routes: RouteRow[];
  stops: StopRow[];
  available: Student[];
  pending: boolean;
  onSubmit: (fd: FormData) => void;
}) {
  const [studentId, setStudentId] = useState("");
  const [routeId, setRouteId] = useState("");
  const [stopId, setStopId] = useState("");
  const routeStops = stops.filter((s) => s.route_id === routeId);
  const route = routes.find((r) => r.id === routeId);

  return (
    <form
      action={(fd) => {
        fd.set("studentId", studentId);
        fd.set("routeId", routeId);
        fd.set("stopId", stopId);
        onSubmit(fd);
      }}
      className="space-y-4"
    >
      <div className="space-y-1.5">
        <Label className="text-sm font-medium text-foreground">Student (your class)</Label>
        <Select value={studentId} onValueChange={setStudentId}>
          <SelectTrigger className="w-full rounded-lg">
            <SelectValue placeholder={available.length === 0 ? "All your students are assigned" : "Choose a student"} />
          </SelectTrigger>
          <SelectContent>
            {available.map((s) => (
              <SelectItem key={s.id} value={s.id}>{s.name} · {s.admissionNo}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1.5">
        <Label className="text-sm font-medium text-foreground">Route</Label>
        <Select
          value={routeId}
          onValueChange={(v) => {
            setRouteId(v);
            setStopId("");
          }}
        >
          <SelectTrigger className="w-full rounded-lg">
            <SelectValue placeholder="Choose a route" />
          </SelectTrigger>
          <SelectContent>
            {routes.map((r) => (
              <SelectItem key={r.id} value={r.id}>{r.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1.5">
        <Label className="text-sm font-medium text-foreground">Stop (optional)</Label>
        <Select value={stopId} onValueChange={setStopId} disabled={!routeId || routeStops.length === 0}>
          <SelectTrigger className="w-full rounded-lg">
            <SelectValue placeholder={!routeId ? "Choose a route first" : routeStops.length === 0 ? "No stops on this route" : "Choose a stop"} />
          </SelectTrigger>
          <SelectContent>
            {routeStops.map((s) => (
              <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      {route && (
        <p className="text-xs text-muted-foreground">
          {formatMoney(route.fee_amount)} bus fee will be added to this student&apos;s fees.
        </p>
      )}
      <DialogFooter>
        <DialogClose asChild>
          <Button type="button" variant="outline" disabled={pending}>Cancel</Button>
        </DialogClose>
        <Button type="submit" disabled={pending || !studentId || !routeId} className="gap-2">
          {pending && <Loader2 className="size-4 animate-spin" />} Add to bus
        </Button>
      </DialogFooter>
    </form>
  );
}
