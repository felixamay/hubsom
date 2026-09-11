import { requireUser } from "@/lib/auth/session";

export default async function SellerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireUser("/seller");
  return children;
}
