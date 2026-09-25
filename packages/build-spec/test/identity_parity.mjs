import { readFile } from 'node:fs/promises';
import { profileIdentity } from '../js/profile.mjs';
import { buildIdentity } from '../js/build.mjs';
import { mappingIdentity } from '../js/mapping.mjs';
import { layoutIdentity } from '../js/layout.mjs';

const identity = process.argv[3] === 'assembly' ? buildIdentity
  : process.argv[3] === 'mapping' ? mappingIdentity
  : process.argv[3] === 'layout' ? layoutIdentity : profileIdentity;
const lines = (await readFile(process.argv[2], 'utf8')).trimEnd().split('\n');
for (const line of lines) {
  const result = await identity(`${line}\n`);
  if (!result.ok) throw new Error(result.error);
  console.log(result.identity);
}
