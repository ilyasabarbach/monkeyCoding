import { readFileSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
export function verifyRelease(release) {
  if (release === null) return null;
  const pin = '81b0270e9b0546f146d2446e917607acf3efa3edd5e9071199fea391db575fa6';
  if (release.package !== 'com.monkeycoding.aivox.helper' || release.versionCode !== 4 ||
      release.versionName !== '3.0.0' || release.certificateSha256 !== pin ||
      !/^[a-f0-9]{64}$/.test(release.sha256) || release.minSdk !== 21 || release.targetSdk !== 36 ||
      release.path !== `/downloads/aivox-helper/3.0.0-4/Aivox-Helper-3.0.0-4-${release.sha256}.apk`) {
    throw new Error('Unreviewed Helper release identity or distribution path');
  }
  const file = `${root}public${release.path}`;
  const bytes = readFileSync(file);
  if (bytes[0] !== 0x50 || bytes[1] !== 0x4b || statSync(file).size !== release.sizeBytes ||
      createHash('sha256').update(bytes).digest('hex') !== release.sha256) {
    throw new Error('Helper APK bytes do not match release receipt');
  }
  return release;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const release = verifyRelease(JSON.parse(readFileSync(`${root}src/data/helper-release.json`, 'utf8')));
  console.log(release ? `Helper bytes verified: ${release.sha256}` : 'PUBLIC_DOWNLOAD_PENDING_OWNER_DEPLOY: no signed artifact staged');
}
