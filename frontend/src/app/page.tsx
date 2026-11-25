import { FoundationWorkspace } from "@/components/foundation-workspace";

// Future authenticated content must never become a shared static page/RSC cache.
export const dynamic = "force-dynamic";

export default function Home() {
  return <FoundationWorkspace />;
}
