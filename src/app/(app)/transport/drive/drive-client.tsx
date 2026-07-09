"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Navigation, Radio, Square, ArrowLeft, MapPin } from "lucide-react";
import { updateBusLocation } from "@/lib/actions/transport";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

const THROTTLE_MS = 5000;

export function DriveClient({ routes }: { routes: { id: string; name: string }[] }) {
  const [routeId, setRouteId] = useState("");
  const [sharing, setSharing] = useState(false);
  const [coords, setCoords] = useState<{ lat: number; lng: number } | null>(null);
  const [sentAt, setSentAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const watchId = useRef<number | null>(null);
  const lastSent = useRef(0);
  const sending = useRef(false);

  function start() {
    if (!routeId) return;
    if (!("geolocation" in navigator)) {
      setError("This device can't share a location.");
      return;
    }
    setError(null);
    setSharing(true);
    watchId.current = navigator.geolocation.watchPosition(
      async (pos) => {
        const { latitude: lat, longitude: lng, heading, speed } = pos.coords;
        setCoords({ lat, lng });
        const now = Date.now();
        if (now - lastSent.current < THROTTLE_MS || sending.current) return;
        lastSent.current = now;
        sending.current = true;
        const res = await updateBusLocation(routeId, lat, lng, heading ?? null, speed ?? null);
        sending.current = false;
        if (res?.error) {
          setError(res.error);
        } else {
          setSentAt(Date.now());
        }
      },
      (err) => {
        setError(err.code === err.PERMISSION_DENIED ? "Location permission denied." : "Couldn't get your location.");
        stop();
      },
      { enableHighAccuracy: true, maximumAge: 2000, timeout: 15000 }
    );
    toast.success("Sharing this bus's location.");
  }

  function stop() {
    if (watchId.current != null) navigator.geolocation.clearWatch(watchId.current);
    watchId.current = null;
    setSharing(false);
  }

  const routeName = routes.find((r) => r.id === routeId)?.name;

  return (
    <div className="mx-auto max-w-lg space-y-6 pb-8">
      <Link
        href="/transport"
        className="group inline-flex items-center gap-1.5 text-sm text-slate-500 transition-colors hover:text-slate-900"
      >
        <ArrowLeft className="size-4 transition-transform group-hover:-translate-x-0.5" /> Transport
      </Link>
      <PageHeader title="Driver mode" description="Share this bus's live location with the school." />

      <Card className="overflow-hidden border border-slate-200/80 bg-white shadow-sm shadow-slate-950/5 ring-1 ring-slate-900/[0.02]">
        <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
          <span className="flex size-9 items-center justify-center rounded-xl bg-blue-50 text-blue-700 ring-1 ring-blue-100">
            <Navigation className="size-4.5" />
          </span>
          <div>
            <h2 className="text-base font-semibold text-slate-900">Share location</h2>
            <p className="text-xs text-slate-500">Select your route and start broadcasting.</p>
          </div>
        </div>
        <CardContent className="space-y-5 p-5">
          <div className="space-y-2">
            <Label className="text-xs font-semibold text-slate-600">Which bus are you driving?</Label>
            <Select value={routeId} onValueChange={setRouteId} disabled={sharing}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder={routes.length === 0 ? "No routes yet" : "Choose your route"} />
              </SelectTrigger>
              <SelectContent>
                {routes.map((r) => (
                  <SelectItem key={r.id} value={r.id}>{r.name}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {sharing ? (
            <div className="flex flex-col items-center gap-4 rounded-2xl border border-slate-200/80 bg-slate-50/60 px-5 py-7 text-center">
              <span className="relative flex size-16 items-center justify-center rounded-full bg-blue-50 text-blue-700 ring-1 ring-blue-100">
                <span className="absolute inline-flex size-16 animate-ping rounded-full bg-blue-200/50" />
                <Radio className="size-7" />
              </span>
              <div>
                <p className="text-sm font-semibold text-slate-900">Sharing {routeName}</p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {coords ? `${coords.lat.toFixed(5)}, ${coords.lng.toFixed(5)}` : "Getting a GPS fix…"}
                  {sentAt && " · sent just now"}
                </p>
              </div>
              <Button variant="destructive" onClick={stop} className="gap-2">
                <Square className="size-4" /> Stop sharing
              </Button>
            </div>
          ) : (
            <Button onClick={start} disabled={!routeId} className="w-full gap-2 bg-primary text-primary-foreground hover:bg-primary/80">
              <Navigation className="size-4" /> Start sharing location
            </Button>
          )}

          {error && (
            <div className="flex items-start gap-3 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              <MapPin className="mt-0.5 size-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <p className="text-center text-xs text-slate-400">
            Keep this page open while driving. Class teachers and parents see the bus move on their map.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
