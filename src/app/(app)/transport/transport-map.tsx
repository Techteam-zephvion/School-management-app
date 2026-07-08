"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { createClient } from "@/lib/supabase/client";

export type BusLocation = { route_id: string; lat: number; lng: number; updated_at: string };
type RouteInfo = { id: string; name: string };

function busIcon() {
  return L.divIcon({
    className: "",
    html: `<div style="font-size:26px;line-height:1;filter:drop-shadow(0 1px 2px rgba(0,0,0,.35))">🚌</div>`,
    iconSize: [26, 26],
    iconAnchor: [13, 13],
  });
}

/** Keep the viewport framing all known bus markers as they move. */
function FitBounds({ points }: { points: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length === 1) {
      map.setView(points[0], Math.max(map.getZoom(), 14), { animate: true });
    } else if (points.length > 1) {
      map.fitBounds(L.latLngBounds(points).pad(0.25), { animate: true });
    }
  }, [map, points]);
  return null;
}

function relTime(iso: string): string {
  const secs = Math.round((Date.now() - new Date(iso).getTime()) / 1000);
  if (secs < 60) return `${secs}s ago`;
  if (secs < 3600) return `${Math.round(secs / 60)}m ago`;
  return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export type TransportMapProps = {
  routes: RouteInfo[];
  initial: BusLocation[];
  userId: string;
  height?: number;
};

export default function TransportMap({ routes, initial, userId, height = 360 }: TransportMapProps) {
  const routeName = useMemo(() => new Map(routes.map((r) => [r.id, r.name])), [routes]);
  const [locs, setLocs] = useState<Record<string, BusLocation>>(
    () => Object.fromEntries(initial.map((l) => [l.route_id, l]))
  );
  const routeIds = useMemo(() => routes.map((r) => r.id), [routes]);
  const idsKey = routeIds.join(",");
  const tick = useRef(0);
  const [, force] = useState(0);

  // Live updates: refresh the "x ago" labels every 15s, and stream location rows.
  useEffect(() => {
    const t = setInterval(() => force((n) => n + 1), 15000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (routeIds.length === 0) return;
    const supabase = createClient();
    let channel: ReturnType<typeof supabase.channel> | null = null;
    const ids = new Set(routeIds);
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (data.session?.access_token) supabase.realtime.setAuth(data.session.access_token);
      channel = supabase
        .channel(`bus_locations:${userId}:${tick.current++}`)
        .on("postgres_changes", { event: "*", schema: "public", table: "bus_locations" }, (payload) => {
          const row = payload.new as BusLocation | Record<string, never>;
          if (row && "route_id" in row && ids.has(row.route_id)) {
            setLocs((prev) => ({ ...prev, [row.route_id]: row as BusLocation }));
          }
        })
        .subscribe();
    })();
    return () => {
      if (channel) supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [idsKey, userId]);

  const active = Object.values(locs).filter((l) => routeName.has(l.route_id));
  const points = active.map((l) => [Number(l.lat), Number(l.lng)] as [number, number]);
  const center: [number, number] = points[0] ?? [20.5937, 78.9629]; // India fallback

  if (active.length === 0) {
    return (
      <div
        style={{ height }}
        className="flex flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border/60 bg-muted/30 text-center"
      >
        <span className="text-3xl">🚌</span>
        <p className="text-sm font-medium text-muted-foreground">No bus is sharing its location yet.</p>
        <p className="max-w-xs text-xs text-muted-foreground/70">
          When a driver starts sharing from the bus, it appears here live.
        </p>
      </div>
    );
  }

  return (
    // `isolate` keeps Leaflet's internal z-indexes (panes/controls go up to 1000)
    // in their own stacking context, so dialogs/menus still render above the map.
    <div style={{ height }} className="relative isolate z-0 overflow-hidden rounded-xl ring-1 ring-border/50">
      <MapContainer center={center} zoom={14} style={{ height: "100%", width: "100%" }} scrollWheelZoom>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        {active.map((l) => (
          <Marker key={l.route_id} position={[Number(l.lat), Number(l.lng)]} icon={busIcon()}>
            <Popup>
              <div className="text-sm">
                <p className="font-semibold">{routeName.get(l.route_id)}</p>
                <p className="text-muted-foreground">Updated {relTime(l.updated_at)}</p>
              </div>
            </Popup>
          </Marker>
        ))}
        <FitBounds points={points} />
      </MapContainer>
    </div>
  );
}
