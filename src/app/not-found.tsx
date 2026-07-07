import Link from "next/link";
import type { Metadata } from "next";
import { Compass, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";

export const metadata: Metadata = { title: "Page not found — EduSphere" };

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-background px-6 text-center">
      <span className="flex size-16 items-center justify-center rounded-2xl bg-primary/10 text-primary">
        <Compass className="size-8" />
      </span>
      <div className="space-y-2">
        <p className="text-sm font-semibold tracking-widest text-primary uppercase">404</p>
        <h1 className="text-2xl font-bold tracking-tight">This page doesn&apos;t exist</h1>
        <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">
          The link may be broken or the page may have moved. Let&apos;s get you back on track.
        </p>
      </div>
      <Button asChild className="gap-2">
        <Link href="/">
          <ArrowLeft className="size-4" /> Back to home
        </Link>
      </Button>
    </div>
  );
}
