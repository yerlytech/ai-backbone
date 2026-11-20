import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { chmod, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import http from "node:http";
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";

const version = "1.65.1";
const install = `npx --yes playwright-core@${version} install chromium`;
const require = createRequire(import.meta.url);
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const printablePath = (value) => value.split(path.sep).join("/");

function playwright() {
  try {
    return require("playwright-core");
  } catch (firstError) {
    for (const entry of (process.env.PATH || "").split(path.delimiter)) {
      if (path.basename(entry) !== ".bin") continue;
      try {
        return createRequire(path.join(path.dirname(entry), "package.json"))("playwright-core");
      } catch {}
    }
    throw new Error(`playwright-core ${version} is unavailable; run through just browser (${firstError.message})`);
  }
}

function projectFolder() {
  const root = path.resolve(process.cwd());
  const name = path.basename(root).replace(/[^a-zA-Z0-9._-]/g, "-") || "project";
  const hash = createHash("sha256").update(root).digest("hex").slice(0, 12);
  return `${name}-${hash}`;
}

function dataRoot() {
  if (process.env.AI_BACKBONE_BROWSER_DATA) return path.resolve(process.env.AI_BACKBONE_BROWSER_DATA);
  if (process.platform === "win32") {
    return path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local"), "ai-backbone", "browser");
  }
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Application Support", "ai-backbone", "browser");
  }
  return path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share"), "ai-backbone", "browser");
}

function paths() {
  const root = dataRoot();
  const portable = root.replace(/\\/g, "/").toLowerCase();
  // Spec 045: signed-in browser state must never land in a synced folder.
  if (["/dropbox", "/onedrive", "/mobile documents", "/google drive", "/googledrive", "/icloud"].some((part) => portable.includes(part))) {
    throw new Error("The browser profile cannot be inside a cloud-synced folder.");
  }
  const profile = path.join(root, projectFolder());
  return { profile, state: path.join(profile, "state.json") };
}

async function prepareProfile(profile) {
  const defaults = path.join(profile, "Default");
  await mkdir(defaults, { recursive: true, mode: 0o700 });
  await chmod(profile, 0o700);
  await chmod(defaults, 0o700);
  const preferencesPath = path.join(defaults, "Preferences");
  let preferences = {};
  if (existsSync(preferencesPath)) {
    preferences = JSON.parse(await readFile(preferencesPath, "utf8"));
  }
  preferences.profile = {
    ...(preferences.profile || {}),
    credentials_enable_service: false,
    password_manager_enabled: false,
  };
  await writeFile(preferencesPath, `${JSON.stringify(preferences, null, 2)}\n`, { mode: 0o600 });
  await chmod(preferencesPath, 0o600);
}

async function writeState(state, value) {
  await writeFile(state, `${JSON.stringify(value)}\n`, { mode: 0o600 });
  await chmod(state, 0o600);
}

async function readState(state) {
  try {
    const value = JSON.parse(await readFile(state, "utf8"));
    if (!Number.isInteger(value.pid) || !Number.isInteger(value.port)) return null;
    return value;
  } catch {
    return null;
  }
}

function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function cdpAnswer(port) {
  return new Promise((resolve) => {
    const request = http.get({ host: "127.0.0.1", port, path: "/json/version", timeout: 1500 }, (response) => {
      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
        if (body.length > 65536) request.destroy();
      });
      response.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch {
          resolve(null);
        }
      });
    });
    request.on("timeout", () => request.destroy());
    request.on("error", () => resolve(null));
  });
}

async function waitForCdp(port, milliseconds = 20000) {
  const deadline = Date.now() + milliseconds;
  while (Date.now() < deadline) {
    const answer = await cdpAnswer(port);
    if (answer?.Browser) return answer;
    await delay(200);
  }
  throw new Error(`Chromium did not open its DevTools port within ${milliseconds / 1000} seconds.`);
}

function freePort() {
  return new Promise((resolve, reject) => {
    const server = http.createServer();
    const timer = setTimeout(() => {
      server.close();
      reject(new Error("Could not find a free loopback port within 5 seconds."));
    }, 5000);
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close((error) => {
        clearTimeout(timer);
        if (error) reject(error);
        else resolve(port);
      });
    });
  });
}

function chromiumPath() {
  const executable = playwright().chromium.executablePath();
  if (!existsSync(executable)) {
    throw new Error(`Playwright Chromium is missing. Install it with: ${install}`);
  }
  return executable;
}

async function open(url) {
  const { profile, state } = paths();
  const previous = await readState(state);
  if (previous && (await cdpAnswer(previous.port))) {
    if (url) await navigate(url);
    console.log("Reusing the open Chromium window.");
    return;
  }
  if (previous && alive(previous.pid)) {
    throw new Error("The saved Chromium process is still starting or not answering; try just browser-close before reopening it.");
  }
  await rm(state, { force: true });
  await prepareProfile(profile);
  const port = await freePort();
  const executable = chromiumPath();
  const args = [
    `--user-data-dir=${profile}`,
    "--remote-debugging-address=127.0.0.1",
    `--remote-debugging-port=${port}`,
    "--password-store=basic",
    "--no-first-run",
    "--no-default-browser-check",
  ];
  // Spec 045: only the self-test may run the console window headless.
  if (process.env.AI_BACKBONE_BROWSER_TEST === "1") args.push("--headless=new");
  if (url) args.push(url);
  const child = spawn(executable, args, { detached: true, stdio: "ignore" });
  child.unref();
  await writeState(state, { pid: child.pid, port });
  try {
    await waitForCdp(port);
  } catch (error) {
    if (alive(child.pid)) process.kill(child.pid);
    await rm(state, { force: true });
    throw error;
  }
  console.log("Chromium is open. Sign in yourself; the agent can now read the page.");
}

async function navigate(url) {
  const parsed = new URL(url);
  const { chromium } = playwright();
  const state = await requiredState();
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${state.port}`, { timeout: 10000 });
  const context = browser.contexts()[0];
  const page = context.pages()[0] || await context.newPage();
  await page.goto(parsed.href, { waitUntil: "domcontentloaded", timeout: 20000 });
  console.log(`${page.url()}\n${await page.title()}`);
}

async function requiredState() {
  const { state } = paths();
  const value = await readState(state);
  if (!value || !(await cdpAnswer(value.port))) {
    throw new Error("No console window is answering. Open one with: just browser");
  }
  return value;
}

async function close() {
  const { state } = paths();
  const value = await readState(state);
  if (!value) {
    await rm(state, { force: true });
    console.log("No console window state was saved.");
    return;
  }
  if (alive(value.pid)) process.kill(value.pid, "SIGTERM");
  const deadline = Date.now() + 5000;
  while (alive(value.pid) && Date.now() < deadline) await delay(100);
  if (alive(value.pid)) throw new Error(`Chromium PID ${value.pid} did not stop; the state file was kept.`);
  await rm(state, { force: true });
  console.log("Chromium is closed.");
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  switch (command) {
    case "open": return open(args[0]);
    case "go": return navigate(args[0]);
    case "close": return close();
    case "executable": console.log(printablePath(chromiumPath())); return;
    default: throw new Error("Usage: browser.mjs open [url] | go <url> | close | executable");
  }
}

main().then(() => process.exit(0), (error) => {
  console.error(error.message);
  process.exit(1);
});
