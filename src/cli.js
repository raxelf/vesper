#!/usr/bin/env node
import http from "node:http";
import { existsSync, readFileSync, copyFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const VERSION = "0.1.0";
const PORT = parseInt(process.env.VESPER_PORT || "8910", 10);
const BASE_URL = `http://127.0.0.1:${PORT}`;

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function findPluginFile() {
  const candidates = [
    join(__dirname, "../plugin/Vesper.server.lua"),
    join(__dirname, "plugin/Vesper.server.lua"),
    join(process.cwd(), "plugin/Vesper.server.lua"),
    join(process.cwd(), "vesper/plugin/Vesper.server.lua"),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  return null;
}

function installPlugin() {
  const pluginSrc = findPluginFile();
  if (!pluginSrc) {
    console.error("Error: Vesper.server.lua not found. Run this command inside the vesper repo or install via npm.");
    process.exit(1);
  }

  const homedir = process.env.HOME || process.env.USERPROFILE || "";
  const user = process.env.USER || process.env.USERNAME || "";
  const targets = [];

  // Linux Vinegar Flatpak
  const vinegarDir = join(homedir, ".var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users", user, "AppData/Local/Roblox/Plugins");
  if (existsSync(join(homedir, ".var/app/org.vinegarhq.Vinegar"))) {
    targets.push(vinegarDir);
  }

  // Linux Wine
  const wineDir = join(homedir, ".wine/drive_c/users", user, "AppData/Local/Roblox/Plugins");
  if (existsSync(join(homedir, ".wine"))) {
    targets.push(wineDir);
  }

  // macOS
  const macDir = join(homedir, "Library/Application Support/Roblox/Plugins");
  if (process.platform === "darwin" || existsSync(join(homedir, "Library/Application Support/Roblox"))) {
    targets.push(macDir);
  }

  // Windows
  if (process.env.LOCALAPPDATA) {
    targets.push(join(process.env.LOCALAPPDATA, "Roblox/Plugins"));
  }

  if (targets.length === 0) {
    targets.push(join(homedir, ".local/share/Roblox/Plugins"));
  }

  let installed = 0;
  for (const dir of targets) {
    try {
      mkdirSync(dir, { recursive: true });
      copyFileSync(pluginSrc, join(dir, "Vesper.server.lua"));
      console.log(`✔ Installed plugin to: ${join(dir, "Vesper.server.lua")}`);
      installed++;
    } catch {}
  }

  if (installed === 0) {
    console.error("Could not auto-detect Roblox Studio plugin directory.");
    console.log(`Please copy ${pluginSrc} into your Studio Plugins folder.`);
  } else {
    console.log("\nSetup complete!");
    console.log("1. Open Studio → Game Settings → Security → Turn on 'Allow HTTP Requests'");
    console.log("2. In the Plugins ribbon, click 'Vesper' and click Connect");
  }
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", chunk => { data += chunk; });
    req.on("end", () => resolve(data));
  });
}

function runServer() {
  const cleanup = () => {
    console.log("\n[Vesper] Server stopped.");
    process.exit(0);
  };
  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);

  let pendingQueue = [];
  let currentCmd = null;
  let lastPollTime = 0;
  let pollWaiter = null;

  const server = http.createServer(async (req, res) => {
    // Block browser pages (Origin set) and DNS rebinding (foreign Host) from reaching the bridge.
    const host = req.headers.host || "";
    if (req.headers.origin || !["127.0.0.1", "localhost"].includes(host.split(":")[0])) {
      res.writeHead(403, { "Content-Type": "text/plain" });
      res.end("ERROR: forbidden");
      return;
    }
    const url = new URL(req.url, `http://${host}`);

    if (url.pathname === "/poll" && req.method === "GET") {
      lastPollTime = Date.now();

      if (pendingQueue.length > 0) {
        currentCmd = pendingQueue.shift();
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ id: currentCmd.id, cmd: currentCmd.cmd, arg: currentCmd.arg }));
        return;
      }

      if (pollWaiter) {
        clearTimeout(pollWaiter.timer);
        pollWaiter.res.writeHead(200, { "Content-Type": "text/plain" });
        pollWaiter.res.end("NOOP");
      }

      const timer = setTimeout(() => {
        if (pollWaiter && pollWaiter.res === res) {
          pollWaiter = null;
          res.writeHead(200, { "Content-Type": "text/plain" });
          res.end("NOOP");
        }
      }, 1000);

      pollWaiter = { res, timer };
      return;
    }

    if (url.pathname === "/reply" && req.method === "POST") {
      lastPollTime = Date.now();
      const body = await readBody(req);
      if (currentCmd && req.headers["x-vesper-id"] === currentCmd.id) {
        currentCmd.resolve(body);
        currentCmd = null;
      }
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("OK");
      return;
    }

    if (url.pathname === "/cmd" && req.method === "POST") {
      try {
        const bodyText = await readBody(req);
        const { cmd, arg, timeout = 35000 } = JSON.parse(bodyText);

        const cmdObj = {
          id: Math.random().toString(36).slice(2),
          cmd,
          arg: arg || "",
          resolve: (result) => {
            if (!res.writableEnded) {
              res.writeHead(200, { "Content-Type": "text/plain" });
              res.end(result);
            }
          }
        };

        if (pollWaiter && !currentCmd) {
          clearTimeout(pollWaiter.timer);
          currentCmd = cmdObj;
          const pw = pollWaiter;
          pollWaiter = null;
          pw.res.writeHead(200, { "Content-Type": "application/json" });
          pw.res.end(JSON.stringify({ id: cmdObj.id, cmd: cmdObj.cmd, arg: cmdObj.arg }));
        } else {
          pendingQueue.push(cmdObj);
        }

        setTimeout(() => {
          if (currentCmd === cmdObj) currentCmd = null;
          const idx = pendingQueue.indexOf(cmdObj);
          if (idx !== -1) pendingQueue.splice(idx, 1);
          if (!res.writableEnded) {
            res.writeHead(504, { "Content-Type": "text/plain" });
            res.end("ERROR: Command timed out waiting for Studio response");
          }
        }, timeout);
      } catch (e) {
        res.writeHead(400, { "Content-Type": "text/plain" });
        res.end(`ERROR: ${e.message}`);
      }
      return;
    }

    if (url.pathname === "/status") {
      const studioConnected = Date.now() - lastPollTime < 3500;
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        version: VERSION,
        running: true,
        studioConnected,
        lastPollAgoMs: lastPollTime ? Date.now() - lastPollTime : null,
        queueLength: pendingQueue.length
      }));
      return;
    }

    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end(`Vesper server v${VERSION}`);
  });

  server.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.error(`Error: Port ${PORT} is already in use by another process.`);
    } else {
      console.error(`Failed to bind 127.0.0.1:${PORT}: ${err.message}`);
    }
    process.exit(1);
  });

  server.listen(PORT, "127.0.0.1", () => {
    console.log(`[Vesper] Server v${VERSION} listening on 127.0.0.1:${PORT}`);
    console.log(`[Vesper] Ready for Roblox Studio connection.`);
    console.log(`[Vesper] Press Ctrl+C to stop.`);
  });
}

async function isServerRunning() {
  try {
    const res = await fetch(`${BASE_URL}/status`, { signal: AbortSignal.timeout(500) });
    return res.ok;
  } catch {
    return false;
  }
}

async function sendCmd(cmd, arg, timeout) {
  if (!await isServerRunning()) {
    console.error(`Error: Vesper server is not running on port ${PORT}.`);
    console.error(`Start the server first with: vesper serve`);
    process.exit(1);
  }
  const res = await fetch(`${BASE_URL}/cmd`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cmd, arg, timeout })
  });
  return await res.text();
}

async function main() {
  const [,, subcmd, ...args] = process.argv;

  if (subcmd === "serve") {
    runServer();
    return;
  }

  if (subcmd === "status") {
    try {
      const res = await fetch(`${BASE_URL}/status`, { signal: AbortSignal.timeout(800) });
      if (res.ok) {
        const data = await res.json();
        console.log(`Vesper Server: Running (port ${PORT})`);
        console.log(`Roblox Studio: ${data.studioConnected ? "Connected" : "Disconnected"}`);
        if (data.lastPollAgoMs !== null) {
          console.log(`Last Studio poll: ${Math.round(data.lastPollAgoMs / 1000)}s ago`);
        }
      } else {
        console.log(`Vesper Server: Not running (port ${PORT})`);
      }
    } catch {
      console.log(`Vesper Server: Not running (port ${PORT})`);
    }
    return;
  }

  if (subcmd === "setup" || subcmd === "install-plugin") {
    installPlugin();
    return;
  }

  if (subcmd === "version" || subcmd === "--version" || subcmd === "-v") {
    console.log(`Vesper v${VERSION}`);
    process.exit(0);
  }

  if (!subcmd || subcmd === "--help" || subcmd === "-h" || subcmd === "help") {
    console.log(`Vesper v${VERSION} (Roblox Studio AI Bridge)

Usage:
  vesper serve                 Start bridge server (foreground, Ctrl+C to stop)
  vesper status                Check if server is running and Studio is connected
  vesper setup                 Auto-install Studio plugin to your Roblox Plugins folder
  vesper tree [path] [depth]   Dump hierarchy (default: Workspace, depth 4)
  vesper run <file.luau|code>  Execute batch Luau builder script in Studio
  vesper exec "<code/>"        Execute inline Luau commands
  vesper test <file|code> [s]  Run Luau in a Play session (default 20s), print PASS/FAIL + logs
  vesper version               Print current version`);
    process.exit(0);
  }

  if (subcmd === "tree") {
    const path = args[0] || "Workspace";
    const out = await sendCmd("tree", JSON.stringify({ path, depth: parseInt(args[1] || "4", 10) }));
    console.log(out);
    return;
  }

  if (subcmd === "test") {
    const last = args[args.length - 1];
    const timeout = args.length > 1 && /^\d+$/.test(last) ? parseInt(args.pop(), 10) : 20;
    let code = args.join(" ");
    if (!code) {
      console.error("Error: specify Luau code or file, e.g.: vesper test check.luau 30");
      process.exit(1);
    }
    if (existsSync(code)) code = readFileSync(code, "utf8");
    const out = await sendCmd("test", JSON.stringify({ code, timeout }), (timeout + 60) * 1000);
    console.log(out);
    return;
  }

  if (subcmd === "run" || subcmd === "exec") {
    let code = args.join(" ");
    if (!code) {
      console.error("Error: specify Luau code or a file path, e.g.: vesper run /tmp/build.luau");
      process.exit(1);
    }
    if (existsSync(code)) {
      code = readFileSync(code, "utf8");
    }
    const out = await sendCmd("run", code);
    console.log(out);
    return;
  }

  console.error(`Unknown command: ${subcmd}. Run 'vesper help' for usage.`);
  process.exit(1);
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
