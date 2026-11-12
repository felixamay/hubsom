import { promises as fs } from "fs";
import path from "path";

function dataDir() {
  const override = process.env.HUBSOM_DATA_DIR?.trim();
  return override && override.length > 0
    ? override
    : path.join(process.cwd(), ".data");
}

export async function readJsonFile<T>(filename: string, fallback: T): Promise<T> {
  const file = path.join(dataDir(), filename);
  try {
    const raw = await fs.readFile(file, "utf8");
    const trimmed = raw.trim();
    if (!trimmed) {
      // Crash-after-truncate leaves a 0-byte file. Treat like first boot.
      await writeJsonFile(filename, fallback);
      return fallback;
    }
    return JSON.parse(trimmed) as T;
  } catch (error) {
    const err = error as NodeJS.ErrnoException;
    if (err.code === "ENOENT") {
      await writeJsonFile(filename, fallback);
      return fallback;
    }
    if (error instanceof SyntaxError) {
      throw new Error(
        `Corrupt data file ${filename}: ${error.message}. Refusing to overwrite stored orders, catalog, or accounts.`,
      );
    }
    throw error;
  }
}

export async function writeJsonFile<T>(filename: string, data: T): Promise<void> {
  const dir = dataDir();
  await fs.mkdir(dir, { recursive: true });
  const file = path.join(dir, filename);
  const tmp = path.join(
    dir,
    `.${filename}.${process.pid}.${Date.now()}.${Math.random().toString(36).slice(2)}.tmp`,
  );
  await fs.writeFile(tmp, JSON.stringify(data, null, 2), "utf8");
  await fs.rename(tmp, file);
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}
