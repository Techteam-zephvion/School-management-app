"use client";

import dynamic from "next/dynamic";
import type { TransportMapProps } from "./transport-map";

// Leaflet touches `window`, so the map must never render on the server.
const TransportMap = dynamic(() => import("./transport-map"), {
  ssr: false,
  loading: () => <div className="h-[360px] w-full animate-pulse rounded-xl bg-muted/50" />,
});

export function LiveMap(props: TransportMapProps) {
  return <TransportMap {...props} />;
}
