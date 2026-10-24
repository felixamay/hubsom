import { NextResponse } from "next/server";
import {
  createSeller,
  ensureDefaultSeller,
  listSellers,
} from "@/lib/data/sellers";
import type { ProductCategory } from "@/types";

export async function GET() {
  const sellers = await listSellers();
  return NextResponse.json({ sellers, total: sellers.length });
}

export async function POST(request: Request) {
  const body = (await request.json()) as {
    name?: string;
    city?: string;
    region?: string;
    bio?: string;
    categories?: ProductCategory[];
    ensureDefault?: boolean;
  };

  if (body.ensureDefault) {
    const seller = await ensureDefaultSeller();
    return NextResponse.json({ seller });
  }

  if (!body.name?.trim()) {
    return NextResponse.json({ error: "name required" }, { status: 400 });
  }

  const seller = await createSeller({
    name: body.name,
    city: body.city,
    region: body.region,
    bio: body.bio,
    categories: body.categories,
  });

  return NextResponse.json({ seller }, { status: 201 });
}
