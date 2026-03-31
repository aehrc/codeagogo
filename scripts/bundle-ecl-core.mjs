#!/usr/bin/env node
// Bundles @aehrc/ecl-core into a single IIFE file suitable for JavaScriptCore (no Node.js APIs).
//
// Prerequisites: run `npm install` in the scripts/ directory first.
//
// Usage: node scripts/bundle-ecl-core.mjs
//
// Output: Codeagogo/ecl-core-bundle.js
//
// The bundle exposes all ecl-core exports on a global `ECLCore` object.
// It includes minimal shims for `console`, `setTimeout`, `fetch`, and `process`
// so the code runs in bare JavaScriptCore without errors.

import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');

// Resolve dependencies from scripts/node_modules
const require = createRequire(resolve(__dirname, 'package.json'));
const { build } = require('esbuild');

// Entry point: the installed @aehrc/ecl-core package
const eclCoreEntry = require.resolve('@aehrc/ecl-core');

// Shims for APIs that don't exist in bare JavaScriptCore.
// antlr4ts bundles a vendored copy of Node's `util` module which references `process`.
const jscShims = `
// Minimal shims for JavaScriptCore compatibility
if (typeof globalThis.console === 'undefined') {
  globalThis.console = { log() {}, warn() {}, error() {}, info() {}, debug() {} };
}
if (typeof globalThis.setTimeout === 'undefined') {
  globalThis.setTimeout = function(fn) { fn(); return 0; };
  globalThis.clearTimeout = function() {};
}
if (typeof globalThis.fetch === 'undefined') {
  globalThis.fetch = function() {
    return Promise.reject(new Error('fetch not available — use Swift bridge for FHIR calls'));
  };
}
if (typeof globalThis.AbortController === 'undefined') {
  globalThis.AbortController = function() { this.signal = {}; this.abort = function() {}; };
}
if (typeof globalThis.process === 'undefined') {
  globalThis.process = {
    env: {},
    pid: 0,
    noDeprecation: true,
    throwDeprecation: false,
    traceDeprecation: false,
    stderr: { isTTY: false, columns: 80, getColorDepth: function() { return 1; }, write: function() {} },
    stdout: { write: function() {} },
    nextTick: function(fn) { fn(); },
    emitWarning: function() {},
    hrtime: function() { return [0, 0]; },
  };
}
`;

try {
  const result = await build({
    entryPoints: [eclCoreEntry],
    bundle: true,
    format: 'iife',
    globalName: 'ECLCore',
    platform: 'browser',
    target: 'es2020',
    outfile: resolve(projectRoot, 'Codeagogo', 'ecl-core-bundle.js'),
    minify: false,
    sourcemap: false,
    banner: { js: jscShims },
    // Stub out node-fetch — FHIR calls will be bridged from Swift
    external: ['node-fetch'],
    define: {
      'process.env.NODE_ENV': '"production"',
    },
    logLevel: 'info',
  });

  if (result.errors.length === 0) {
    console.log('✅ ecl-core-bundle.js created successfully');
  }
} catch (err) {
  console.error('❌ Bundle failed:', err);
  process.exit(1);
}
