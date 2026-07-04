"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Trash2, Loader2 } from "lucide-react";
import { deleteHomework } from "@/lib/actions/homework";
import { Button } from "@/components/ui/button";

export function DeleteHomeworkButton({ id }: { id: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function remove() {
    if (!confirm("Delete this homework? This can't be undone.")) return;
    startTransition(async () => {
      const result = await deleteHomework(id);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success("Homework deleted.");
        router.push("/homework");
      }
    });
  }

  return (
    <Button
      variant="outline"
      size="sm"
      onClick={remove}
      disabled={isPending}
      className="gap-1.5 text-destructive hover:text-destructive"
    >
      {isPending ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
      Delete
    </Button>
  );
}
