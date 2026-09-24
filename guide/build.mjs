import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, lstatSync, copyFileSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const guide = dirname(fileURLToPath(import.meta.url));
const repository = resolve(guide, '..');
const generated = resolve(repository, 'host/decision_kernel/build/dev/javascript');
const entry = resolve(generated, 'frameshift_decisions/frameshift_decisions.mjs');
const output = resolve(guide, 'dist');

if (!existsSync(entry)) {
  throw new Error('Compile the Gleam JavaScript target before building the guide.');
}

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });
cpSync(resolve(guide, 'src'), output, { recursive: true });

const copied = new Set();
function copyKernelModule(source) {
  const pathWithin = relative(generated, source);
  if (isAbsolute(pathWithin) || pathWithin === '..' || pathWithin.startsWith(`..${sep}`)) {
    throw new Error(`Generated import escapes build output: ${source}`);
  }
  if (copied.has(source)) return;
  if (!source.endsWith('.mjs')) throw new Error(`Unexpected generated import: ${source}`);
  copied.add(source);
  const destination = resolve(output, 'kernel', pathWithin);
  mkdirSync(dirname(destination), { recursive: true });
  copyFileSync(source, destination);
  const code = readFileSync(source, 'utf8');
  for (const match of code.matchAll(/(?:from\s*|import\s*)["'](\.[^"']+)["']/g)) {
    copyKernelModule(resolve(dirname(source), match[1]));
  }
}
copyKernelModule(entry);

let files = 0;
let bytes = 0;
function verifyDirectory(directory) {
  for (const name of readdirSync(directory)) {
    const path = join(directory, name);
    const stats = lstatSync(path);
    if (stats.isDirectory()) {
      verifyDirectory(path);
    } else if (stats.isFile()) {
      if (stats.size > 25 * 1024 * 1024) throw new Error(`Oversized static asset: ${path}`);
      files += 1;
      bytes += stats.size;
    } else {
      throw new Error(`Unexpected static asset type: ${path}`);
    }
  }
}
verifyDirectory(output);
console.log(`Guide built: ${files} files, ${bytes} bytes, ${copied.size} kernel modules.`);
