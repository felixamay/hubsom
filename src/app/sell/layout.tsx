import { requireUser } from "@/lib/auth/session";

export default async function SellLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireUser("/sell");
  return children;
}
