import { notFound } from "next/navigation";
import { AuthWorkspace } from "@/components/auth-workspace";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  if (!/^[1-9][0-9]{0,19}$/.test(id)) notFound();
  return <AuthWorkspace mode="goods-receipts" inventoryDocumentId={id} />;
}
