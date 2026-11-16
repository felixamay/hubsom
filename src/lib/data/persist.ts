import { promises as fs } from "fs";
import path from "path";

const DATA_DIR = path.join(process.cwd(), ".data");

const writeChains = new Map<string, Promise<unknown>>();

/** Serialize read-modify-write on one JSON file within this process. */
export async function withFileLock<T>(
  filename: string,
  fn: () => Promise<T>,
): Promise<T> {
  const previous = writeChains.get(filename) ?? Promise.resolve();
  const next = previous.then(fn, fn);
  writeChains.set(
    filename,
    next.then(
      () => undefined,
      () => undefined,
    ),
  );
  return next;
}

async function writeFileAtomic(file: string, contents: string) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(tmp, contents, "utf8");
  await fs.rename(tmp, file);
}

export async function readJsonFile<T>(filename: string, fallback: T): Promise<T> {
  const file = path.join(DATA_DIR, filename);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as T;
  } catch {
    await writeFileAtomic(file, JSON.stringify(fallback, null, 2));
    return fallback;
  }
}

export async function writeJsonFile<T>(filename: string, data: T): Promise<void> {
  const file = path.join(DATA_DIR, filename);
  await writeFileAtomic(file, JSON.stringify(data, null, 2));
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}
