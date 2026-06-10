#!/usr/bin/env node
// dev-workflow SessionStart bootstrap.
// Fail-open: this hook must NEVER wedge or slow a session. Any error → emit
// nothing and exit 0. It only prints a short digest to stdout, which Claude
// Code injects as session context.
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

try {
  const here = dirname(fileURLToPath(import.meta.url));
  const digest = readFileSync(join(here, 'dev-workflow-bootstrap.md'), 'utf8');
  process.stdout.write(digest);
} catch {
  // swallow — never block a session on a bootstrap hook
}
process.exit(0);
