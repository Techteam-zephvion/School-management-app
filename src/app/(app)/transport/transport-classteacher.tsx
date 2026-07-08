"use client";

import { Bus, MapPin, Clock } from "lucide-react";
import type { RouteRow, StopRow, RiderRow, BusLoc } from "./page";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { LiveMap } from "./live-map";

function fmtTime(t: string | null) {
  if (!t) return null;
  const [h, m] = t.split(":");
  return `${h.padStart(2, "0")}:${m}`;
}

export function TransportClassTeacher({
  routes,
  stops,
  riders,
  locations,
  userId,
}: {
  routes: RouteRow[];
  stops: StopRow[];
  riders: RiderRow[];
  locations: BusLoc[];
  userId: string;
}) {
  const routeName = new Map(routes.map((r) => [r.id, r.name]));
  const stopTime = new Map(stops.map((s) => [s.id, s.pickup_time]));

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader title="Transport" description="Track the buses your class rides, live." />

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
        </CardHeader>
        <CardContent className="divide-y divide-border/60 p-0">
          {riders.length === 0 ? (
            <div className="flex flex-col items-center gap-2 py-12 text-center">
              <span className="flex size-12 items-center justify-center rounded-2xl bg-muted/60">
                <Bus className="size-6 text-muted-foreground/70" />
              </span>
              <p className="text-sm font-medium text-muted-foreground">No students in your class take the bus.</p>
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
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}
