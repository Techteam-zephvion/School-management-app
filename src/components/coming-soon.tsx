import { Construction } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";

export function ComingSoon({
  title,
  phase,
  description,
}: {
  title: string;
  phase: string;
  description?: string;
}) {
  return (
    <Card>
      <CardHeader className="items-center text-center">
        <Construction className="mb-2 size-10 text-muted-foreground" />
        <CardTitle className="text-xl">{title}</CardTitle>
        <CardDescription>
          {description ?? `This module ships in ${phase} of the build plan.`}
        </CardDescription>
      </CardHeader>
      <CardContent />
    </Card>
  );
}
