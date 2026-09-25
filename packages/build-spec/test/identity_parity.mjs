import { readFile } from 'node:fs/promises';
import { profileIdentity } from '../js/profile.mjs';

const lines = (await readFile(process.argv[2], 'utf8')).trimEnd().split('\n');
for (const line of lines) {
  const result = await profileIdentity(`${line}\n`);
  if (!result.ok) throw new Error(result.error);
  console.log(result.identity);
}
