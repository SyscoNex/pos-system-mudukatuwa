import { AuthWorkspace } from "@/components/auth-workspace";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export default function Page() {
  return <AuthWorkspace mode="warehouses" />;
}
