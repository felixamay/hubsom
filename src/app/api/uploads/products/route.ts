import { randomBytes } from "crypto";
import { promises as fs } from "fs";
import path from "path";
import { NextResponse } from "next/server";
import { auth } from "@/auth";

export const runtime = "nodejs";

const MAX_BYTES = 5 * 1024 * 1024;
const MAX_FILES = 6;
const ALLOWED = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["image/gif", "gif"],
]);

function uploadDir() {
  return path.join(process.cwd(), "public", "uploads", "products");
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return NextResponse.json({ error: "Invalid upload payload" }, { status: 400 });
  }

  const files = form
    .getAll("files")
    .filter((entry): entry is File => entry instanceof File && entry.size > 0);

  if (!files.length) {
    return NextResponse.json({ error: "Choose at least one image" }, { status: 400 });
  }
  if (files.length > MAX_FILES) {
    return NextResponse.json(
      { error: `Upload up to ${MAX_FILES} images at a time` },
      { status: 400 },
    );
  }

  await fs.mkdir(uploadDir(), { recursive: true });

  const urls: string[] = [];
  for (const file of files) {
    const ext = ALLOWED.get(file.type);
    if (!ext) {
      return NextResponse.json(
        { error: `${file.name}: use JPG, PNG, WEBP, or GIF` },
        { status: 400 },
      );
    }
    if (file.size > MAX_BYTES) {
      return NextResponse.json(
        { error: `${file.name}: keep each image under 5MB` },
        { status: 400 },
      );
    }

    const buffer = Buffer.from(await file.arrayBuffer());
    const name = `${Date.now().toString(36)}-${randomBytes(4).toString("hex")}.${ext}`;
    await fs.writeFile(path.join(uploadDir(), name), buffer);
    urls.push(`/uploads/products/${name}`);
  }

  return NextResponse.json({ urls });
}
