import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import net from "node:net";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const fixture = pathToFileURL(path.join(root, ".ai-backbone", "fixtures", "browser-page.html")).href;
const temporary = mkdtempSync(path.join(tmpdir(), "ai-backbone-browser-test-"));
const env = {
  ...process.env,
  AI_BACKBONE_BROWSER_DATA: path.join(temporary, "profiles"),
  AI_BACKBONE_BROWSER_TEST: "1",
};
let checks = 0;

function run(args, expected = 0) {
  const result = spawnSync("just", ["_browser", ...args], {
    cwd: root,
    env,
    encoding: "utf8",
    timeout: 130000,
  });
  if (result.error) throw result.error;
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  if (result.status !== expected) {
    throw new Error(`browser ${args.join(" ")} exited ${result.status}, expected ${expected}:\n${output.slice(-3000)}`);
  }
  return output;
}

function portOpen(port) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host: "127.0.0.1", port });
    const timer = setTimeout(() => {
      socket.destroy();
      resolve(false);
    }, 1500);
    socket.once("connect", () => {
      clearTimeout(timer);
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => {
      clearTimeout(timer);
      resolve(false);
    });
  });
}

function state() {
  const profiles = readdirSync(env.AI_BACKBONE_BROWSER_DATA);
  assert.equal(profiles.length, 1);
  const profile = path.join(env.AI_BACKBONE_BROWSER_DATA, profiles[0]);
  const statePath = path.join(profile, "state.json");
  return { profile, statePath, value: JSON.parse(readFileSync(statePath, "utf8")) };
}

async function main() {
  const probe = spawnSync("just", ["_browser", "executable"], { cwd: root, env, encoding: "utf8", timeout: 130000 });
  if (probe.status !== 0) {
    console.log("SKIP console window: Playwright Chromium is not installed or its pinned package is unavailable offline.");
    console.log("Install with: npx --yes playwright-core@1.65.1 install chromium");
    return;
  }

  let port;
  try {
    run(["open", fixture]);
    const first = state();
    port = first.value.port;
    assert.ok(Number.isInteger(first.value.pid));
    assert.ok(!first.profile.startsWith(`${root}${path.sep}`));
    assert.equal(statSync(first.statePath).mode & 0o777, 0o600);
    if (process.platform !== "win32") assert.equal(statSync(first.profile).mode & 0o777, 0o700);
    const preferences = JSON.parse(readFileSync(path.join(first.profile, "Default", "Preferences"), "utf8"));
    assert.equal(preferences.profile.credentials_enable_service, false);
    assert.equal(preferences.profile.password_manager_enabled, false);
    assert.equal(await portOpen(port), true);
    checks += 6;

    const reused = run(["open", fixture]);
    assert.match(reused, /Reusing the open Chromium window/);
    assert.equal(state().value.pid, first.value.pid);
    checks += 1;

    const initial = run(["look"]);
    assert.match(initial, /Console window fixture/);
    assert.match(initial, /Console fixture/);
    assert.ok(!initial.includes("fixture-password-value"));
    checks += 1;

    run(["click", "Mark reviewed"]);
    assert.match(run(["look"]), /Role click worked/);
    checks += 1;

    run(["click", "Display name"]);
    run(["type", "Ada Lovelace"]);
    assert.match(run(["look"]), /Name: Ada Lovelace/);
    checks += 1;

    run(["click", "Password"]);
    const refused = run(["type", "not-for-the-agent"], 1);
    assert.match(refused, /Refusing to read or type into a password field/);
    assert.ok(!refused.includes("not-for-the-agent"));
    const afterPassword = run(["look"]);
    assert.match(afterPassword, /Password length: 22/);
    assert.ok(!afterPassword.includes("fixture-password-value"));
    checks += 1;

    const input = path.join(temporary, "editor.json");
    writeFileSync(input, '{\n  "enabled": true,\n  "count": 2\n}\n');
    run(["click", "Code editor"]);
    const editor = run(["editor", input]);
    assert.match(editor, /\{"enabled":true,"count":2\}/);
    assert.ok(!editor.includes("old editor text"));
    checks += 1;

    run(["click", "Terminal command"]);
    const terminal = run(["term", "status --short"]);
    assert.match(terminal, /ran: status --short/);
    assert.match(terminal, /last: status --short/);
    checks += 1;

    assert.match(run(["go", "about:blank"]), /about:blank/);
    assert.match(run(["go", fixture]), /Console window fixture/);
    checks += 1;

    const screenshot = path.join(temporary, "console.png");
    const shot = run(["shot", screenshot]);
    assert.match(shot, /Screenshot:/);
    assert.equal(readFileSync(screenshot).subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
    checks += 1;

    run(["close"]);
    assert.equal(existsSync(first.statePath), false);
  } finally {
    try { run(["close"]); } catch {}
    if (port) {
      assert.equal(await portOpen(port), false);
      checks += 1;
    }
  }
  console.log(`console window fixture: ${checks} checks passed`);
}

main().then(() => {
  rmSync(temporary, { recursive: true, force: true });
  process.exit(0);
}, (error) => {
  console.error(error.message);
  rmSync(temporary, { recursive: true, force: true });
  process.exit(1);
});
