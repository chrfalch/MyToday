#!/usr/bin/env node
/**
 * npm run release [-- <version>] [--dry-run]
 *
 * Bumps the version in Info.plist, commits, creates a signed git tag, and
 * pushes it — which triggers the GitHub Actions Release workflow automatically.
 *
 * Requires:
 *   - git installed and repo configured with a remote named "origin"
 *   - gh CLI installed (https://cli.github.com) for status link printing
 *
 * Usage:
 *   npm run release              # prompts for version
 *   npm run release -- 1.2.3    # uses provided version
 *   npm run release:dry          # shows what would happen, makes no changes
 */

import { execSync } from "child_process";
import * as readline from "readline/promises";
import { stdin as input, stdout as output } from "process";

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");
const versionArg = args.find((a) => /^\d+\.\d+\.\d+$/.test(a));

// ── Helpers ───────────────────────────────────────────────────────────────────

function run(cmd, opts = {}) {
  if (DRY_RUN && !opts.readOnly) {
    console.log(`[dry-run] ${cmd}`);
    return "";
  }
  return execSync(cmd, { encoding: "utf8", stdio: opts.stdio ?? "pipe" }).trim();
}

function currentVersion() {
  return run(
    `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist`,
    { readOnly: true }
  );
}

function validateVersion(v) {
  if (!/^\d+\.\d+\.\d+$/.test(v)) {
    throw new Error(`Invalid version format: "${v}". Expected x.y.z`);
  }
}

function tagExists(tag) {
  try {
    run(`git rev-parse --verify "refs/tags/${tag}"`, { readOnly: true });
    return true;
  } catch {
    return false;
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  // Ensure working tree is clean
  const dirty = run("git status --porcelain", { readOnly: true });
  if (dirty) {
    console.error("Error: working tree has uncommitted changes. Commit or stash them first.");
    process.exit(1);
  }

  let version = versionArg;

  if (!version) {
    const current = currentVersion();
    const rl = readline.createInterface({ input, output });
    version = await rl.question(`Current version is ${current}. New version (x.y.z): `);
    rl.close();
    version = version.trim();
  }

  validateVersion(version);

  const tag = `v${version}`;

  if (tagExists(tag)) {
    console.error(`Error: tag ${tag} already exists.`);
    process.exit(1);
  }

  console.log(`\nReleasing MyToday ${version} (tag: ${tag})${DRY_RUN ? " [DRY RUN]" : ""}\n`);

  // 1. Update Info.plist
  console.log("1/4  Bumping version in Info.plist…");
  run(`/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" Info.plist`);

  // 2. Commit the version bump
  console.log("2/4  Committing version bump…");
  run(`git add Info.plist`);
  run(`git commit -m "chore: bump version to ${version}"`);

  // 3. Create annotated tag
  console.log(`3/4  Creating tag ${tag}…`);
  run(`git tag -a "${tag}" -m "Release ${tag}"`);

  // 4. Push commit + tag  → triggers the Release workflow
  console.log(`4/4  Pushing to origin…`);
  run(`git push origin HEAD "${tag}"`, { stdio: "inherit" });

  console.log(`\nDone! Tag ${tag} pushed.`);

  // Print link to the workflow run if gh is available
  try {
    const repo = run(`gh repo view --json nameWithOwner -q .nameWithOwner`, { readOnly: true });
    console.log(`\nFollow the release at: https://github.com/${repo}/actions`);
  } catch {
    // gh not installed — that's fine
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
