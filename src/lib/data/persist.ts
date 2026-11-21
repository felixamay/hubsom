import { promises as fs } from "fs";
import path from "path";

function dataDir() {
  return process.env.HUBSOM_DATA_DIR?.trim() || path.join(process.cwd(), ".data");
}

export async function readJsonFile<T>(filename: string, fallback: T): Promise<T> {
  const dir = dataDir();
  const file = path.join(dir, filename);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as T;
  } catch {
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(file, JSON.stringify(fallback, null, 2), "utf8");
    return fallback;
  }
}

export async function writeJsonFile<T>(filename: string, data: T): Promise<void> {
  const dir = dataDir();
  await fs.mkdir(dir, { recursive: true });
  const file = path.join(dir, filename);
  await fs.writeFile(file, JSON.stringify(data, null, 2), "utf8");
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}
