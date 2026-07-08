"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { toast } from "sonner";
import {
  Bus,
  Plus,
  Pencil,
  Trash2,
  MapPin,
  UserPlus,
  X,
  Loader2,
  Navigation,
  Phone,
  Clock,
  Users,
} from "lucide-react";
import {
  saveRoute,
  deleteRoute,
  addStop,
  deleteStop,
  assignStudentToBus,
  removeStudentFromBus,
} from "@/lib/actions/transport";
import type { RouteRow, StopRow, RiderRow, BusLoc } from "./page";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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
type Dialog =
  | { type: "route"; route?: RouteRow }
  | { type: "stops"; route: RouteRow }
  | { type: "assign"; route: RouteRow }
  | { type: "delete"; route: RouteRow }
  | null;

function fmtTime(t: string | null) {
  if (!t) return null;
  const [h, m] = t.split(":");
  return `${h.padStart(2, "0")}:${m}`;
}

export function TransportAdmin({
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
  const [dialog, setDialog] = useState<Dialog>(null);
  const [isPending, startTransition] = useTransition();

  const stopsByRoute = useMemo(() => {
    const m = new Map<string, StopRow[]>();
    for (const s of stops) (m.get(s.route_id) ?? m.set(s.route_id, []).get(s.route_id)!).push(s);
    return m;
  }, [stops]);
  const ridersByRoute = useMemo(() => {
    const m = new Map<string, RiderRow[]>();
    for (const r of riders) (m.get(r.routeId) ?? m.set(r.routeId, []).get(r.routeId)!).push(r);
    return m;
  }, [riders]);

  function run(fn: () => Promise<{ error?: string } | void>, ok?: string) {
    startTransition(async () => {
      const res = await fn();
      if (res?.error) toast.error(res.error);
      else {
        if (ok) toast.success(ok);
        setDialog(null);
        router.refresh();
      }
    });
  }

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        title="Transport"
        description="Bus routes, stops, riders and live tracking."
        action={
          <div className="flex items-center gap-2">
            <Button asChild variant="outline" className="gap-2">
              <Link href="/transport/drive">
                <Navigation className="size-4" /> Driver mode
              </Link>
            </Button>
            <Button onClick={() => setDialog({ type: "route" })} className="gap-2">
              <Plus className="size-4" /> New route
            </Button>
          </div>
        }
      />

      <Card className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
        <CardHeader>
          <CardTitle className="text-base">Live map</CardTitle>
          <CardDescription>Buses currently sharing their location.</CardDescription>
        </CardHeader>
        <CardContent>
          <LiveMapClient routes={routes} locations={locations} userId={userId} />
        </CardContent>
      </Card>

      {routes.length === 0 ? (
        <Card className="border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
          <CardContent className="flex flex-col items-center gap-3 py-14 text-center">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
              <Bus className="size-6" />
            </span>
            <p className="text-sm font-medium">No bus routes yet.</p>
            <p className="text-xs text-muted-foreground">Create your first route to add stops and riders.</p>
            <Button onClick={() => setDialog({ type: "route" })} className="mt-1 gap-2">
              <Plus className="size-4" /> New route
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {routes.map((route) => {
            const rStops = stopsByRoute.get(route.id) ?? [];
            const rRiders = ridersByRoute.get(route.id) ?? [];
            const full = route.capacity != null && rRiders.length >= route.capacity;
            return (
              <Card key={route.id} className="overflow-hidden border-0 shadow-md shadow-muted-foreground/5 ring-1 ring-border/50">
                <CardContent className="space-y-4 py-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="flex size-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
                          <Bus className="size-5" />
                        </span>
                        <div>
                          <p className="font-semibold">{route.name}</p>
                          <p className="text-xs text-muted-foreground">
                            {[route.vehicle_no, route.driver_name].filter(Boolean).join(" · ") || "No vehicle set"}
                          </p>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="secondary" className="gap-1">{formatMoney(route.fee_amount)} fee</Badge>
                      <Badge variant={full ? "destructive" : "outline"} className="gap-1">
                        <Users className="size-3" /> {rRiders.length}
                        {route.capacity != null ? `/${route.capacity}` : ""}
                      </Badge>
                      {route.driver_phone && (
                        <Badge variant="outline" className="gap-1">
                          <Phone className="size-3" /> {route.driver_phone}
                        </Badge>
                      )}
                    </div>
                  </div>

                  {/* stops */}
                  <div className="flex flex-wrap items-center gap-1.5">
                    {rStops.length === 0 ? (
                      <span className="text-xs text-muted-foreground">No stops yet.</span>
                    ) : (
                      rStops.map((s) => (
                        <span
                          key={s.id}
                          className="inline-flex items-center gap-1 rounded-full bg-muted/70 px-2.5 py-1 text-xs"
                        >
                          <MapPin className="size-3 text-muted-foreground" />
                          {s.name}
                          {fmtTime(s.pickup_time) && (
                            <span className="text-muted-foreground tabular-nums">· {fmtTime(s.pickup_time)}</span>
                          )}
                        </span>
                      ))
                    )}
                  </div>

                  {/* riders */}
                  {rRiders.length > 0 && (
                    <div className="rounded-lg border border-border/50">
                      {rRiders.map((r) => (
                        <div key={r.studentId} className="flex items-center gap-2 border-b border-border/40 px-3 py-2 last:border-0">
                          <span className="min-w-0 flex-1 truncate text-sm">{r.studentName}</span>
                          {r.stopName && <span className="truncate text-xs text-muted-foreground">{r.stopName}</span>}
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
                      ))}
                    </div>
                  )}

                  <div className="flex flex-wrap gap-2 pt-1">
                    <Button size="sm" variant="outline" className="gap-1.5" onClick={() => setDialog({ type: "assign", route })}>
                      <UserPlus className="size-4" /> Add student
                    </Button>
                    <Button size="sm" variant="outline" className="gap-1.5" onClick={() => setDialog({ type: "stops", route })}>
                      <MapPin className="size-4" /> Stops
                    </Button>
                    <Button size="sm" variant="outline" className="gap-1.5" onClick={() => setDialog({ type: "route", route })}>
                      <Pencil className="size-4" /> Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="gap-1.5 border-destructive/30 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      onClick={() => setDialog({ type: "delete", route })}
                    >
                      <Trash2 className="size-4" /> Delete
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* --- Route create/edit dialog --- */}
      <Dialog open={dialog?.type === "route"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{dialog?.type === "route" && dialog.route ? "Edit route" : "New route"}</DialogTitle>
            <DialogDescription>Set the bus fee that riders on this route are charged.</DialogDescription>
          </DialogHeader>
          <form
            action={(fd) => run(() => saveRoute(undefined, fd), "Route saved.")}
            className="space-y-4"
          >
            {dialog?.type === "route" && dialog.route && <input type="hidden" name="id" value={dialog.route.id} />}
            <Field label="Route name" name="name" placeholder="North Line" defaultValue={dialog?.type === "route" ? dialog.route?.name : ""} required />
            <div className="grid grid-cols-2 gap-4">
              <Field label="Bus fee (₹)" name="feeAmount" type="number" min="0" step="1" placeholder="1200" defaultValue={dialog?.type === "route" ? String(dialog.route?.fee_amount ?? "") : ""} required />
              <Field label="Capacity" name="capacity" type="number" min="0" placeholder="40" defaultValue={dialog?.type === "route" ? (dialog.route?.capacity != null ? String(dialog.route.capacity) : "") : ""} />
            </div>
            <div className="grid grid-cols-2 gap-4">
              <Field label="Driver name" name="driverName" placeholder="Ravi Kumar" defaultValue={dialog?.type === "route" ? dialog.route?.driver_name ?? "" : ""} />
              <Field label="Driver phone" name="driverPhone" placeholder="98xxxxxxx" defaultValue={dialog?.type === "route" ? dialog.route?.driver_phone ?? "" : ""} />
            </div>
            <Field label="Vehicle number" name="vehicleNo" placeholder="KA 01 AB 1234" defaultValue={dialog?.type === "route" ? dialog.route?.vehicle_no ?? "" : ""} />
            <DialogFooter>
              <DialogClose asChild>
                <Button type="button" variant="outline" disabled={isPending}>Cancel</Button>
              </DialogClose>
              <Button type="submit" disabled={isPending} className="gap-2">
                {isPending && <Loader2 className="size-4 animate-spin" />} Save route
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* --- Stops manager --- */}
      <Dialog open={dialog?.type === "stops"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Stops · {dialog?.type === "stops" ? dialog.route.name : ""}</DialogTitle>
            <DialogDescription>Add the pickup points along this route.</DialogDescription>
          </DialogHeader>
          {dialog?.type === "stops" && (
            <div className="space-y-3">
              <div className="max-h-56 space-y-1.5 overflow-y-auto">
                {(stopsByRoute.get(dialog.route.id) ?? []).length === 0 ? (
                  <p className="py-3 text-center text-sm text-muted-foreground">No stops yet.</p>
                ) : (
                  (stopsByRoute.get(dialog.route.id) ?? []).map((s) => (
                    <div key={s.id} className="flex items-center gap-2 rounded-lg border border-border/50 px-3 py-2">
                      <MapPin className="size-4 text-muted-foreground" />
                      <span className="flex-1 text-sm">{s.name}</span>
                      {fmtTime(s.pickup_time) && (
                        <span className="flex items-center gap-1 text-xs text-muted-foreground tabular-nums">
                          <Clock className="size-3" /> {fmtTime(s.pickup_time)}
                        </span>
                      )}
                      <button
                        type="button"
                        disabled={isPending}
                        onClick={() => run(() => deleteStop(s.id))}
                        aria-label={`Delete ${s.name}`}
                        className="flex size-6 items-center justify-center rounded text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                      >
                        <X className="size-3.5" />
                      </button>
                    </div>
                  ))
                )}
              </div>
              <form
                action={(fd) => {
                  fd.set("routeId", dialog.route.id);
                  run(() => addStop(undefined, fd), "Stop added.");
                }}
                className="flex items-end gap-2 border-t border-border/50 pt-3"
              >
                <div className="flex-1 space-y-1.5">
                  <Label htmlFor="stopName" className="text-xs">Stop name</Label>
                  <Input id="stopName" name="name" placeholder="Main Gate" required className="rounded-lg" />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="pickupTime" className="text-xs">Pickup</Label>
                  <Input id="pickupTime" name="pickupTime" type="time" className="rounded-lg" />
                </div>
                <Button type="submit" size="sm" disabled={isPending} className="gap-1.5">
                  <Plus className="size-4" /> Add
                </Button>
              </form>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* --- Assign rider --- */}
      <Dialog open={dialog?.type === "assign"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add student · {dialog?.type === "assign" ? dialog.route.name : ""}</DialogTitle>
            <DialogDescription>
              The route&apos;s bus fee of {dialog?.type === "assign" ? formatMoney(dialog.route.fee_amount) : ""} is added to
              their fees automatically.
            </DialogDescription>
          </DialogHeader>
          {dialog?.type === "assign" && (
            <AssignForm
              route={dialog.route}
              stops={stopsByRoute.get(dialog.route.id) ?? []}
              available={available}
              pending={isPending}
              onSubmit={(fd) => run(() => assignStudentToBus(undefined, fd), "Student added to the bus.")}
            />
          )}
        </DialogContent>
      </Dialog>

      {/* --- Delete route confirm --- */}
      <Dialog open={dialog?.type === "delete"} onOpenChange={(o) => !o && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete this route?</DialogTitle>
            <DialogDescription>
              {dialog?.type === "delete" && (
                <>
                  <span className="font-medium text-foreground">{dialog.route.name}</span> and its stops will be removed,
                  and its riders&apos; unpaid transport charges cleared. This can&apos;t be undone.
                </>
              )}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" disabled={isPending}>Cancel</Button>
            </DialogClose>
            <Button
              variant="destructive"
              disabled={isPending}
              className="gap-2"
              onClick={() => dialog?.type === "delete" && run(() => deleteRoute(dialog.route.id), "Route deleted.")}
            >
              {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />} Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function Field({
  label,
  name,
  ...props
}: { label: string; name: string } & React.ComponentProps<typeof Input>) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={name} className="text-sm font-medium text-foreground">{label}</Label>
      <Input id={name} name={name} className="rounded-lg" {...props} />
    </div>
  );
}

function AssignForm({
  route,
  stops,
  available,
  pending,
  onSubmit,
}: {
  route: RouteRow;
  stops: StopRow[];
  available: Student[];
  pending: boolean;
  onSubmit: (fd: FormData) => void;
}) {
  const [studentId, setStudentId] = useState("");
  const [stopId, setStopId] = useState("");
  return (
    <form
      action={(fd) => {
        fd.set("routeId", route.id);
        fd.set("studentId", studentId);
        fd.set("stopId", stopId);
        onSubmit(fd);
      }}
      className="space-y-4"
    >
      <div className="space-y-1.5">
        <Label className="text-sm font-medium text-foreground">Student</Label>
        <Select value={studentId} onValueChange={setStudentId}>
          <SelectTrigger className="w-full rounded-lg">
            <SelectValue placeholder={available.length === 0 ? "All students already assigned" : "Choose a student"} />
          </SelectTrigger>
          <SelectContent>
            {available.map((s) => (
              <SelectItem key={s.id} value={s.id}>
                {s.name} · {s.admissionNo}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1.5">
        <Label className="text-sm font-medium text-foreground">Stop (optional)</Label>
        <Select value={stopId} onValueChange={setStopId} disabled={stops.length === 0}>
          <SelectTrigger className="w-full rounded-lg">
            <SelectValue placeholder={stops.length === 0 ? "Add stops first" : "Choose a stop"} />
          </SelectTrigger>
          <SelectContent>
            {stops.map((s) => (
              <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <DialogFooter>
        <DialogClose asChild>
          <Button type="button" variant="outline" disabled={pending}>Cancel</Button>
        </DialogClose>
        <Button type="submit" disabled={pending || !studentId} className="gap-2">
          {pending && <Loader2 className="size-4 animate-spin" />} Add to bus
        </Button>
      </DialogFooter>
    </form>
  );
}

function LiveMapClient({ routes, locations, userId }: { routes: RouteRow[]; locations: BusLoc[]; userId: string }) {
  return <LiveMap routes={routes.map((r) => ({ id: r.id, name: r.name }))} initial={locations} userId={userId} />;
}
