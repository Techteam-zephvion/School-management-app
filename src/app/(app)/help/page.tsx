import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";

export default function HelpPage() {
  return (
    <Card className="max-w-xl">
      <CardHeader>
        <CardTitle>Help Center</CardTitle>
        <CardDescription>
          Need a hand? Email your platform administrator, or check back here
          once the knowledge base ships.
        </CardDescription>
      </CardHeader>
      <CardContent />
    </Card>
  );
}
