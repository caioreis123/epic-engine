/**
 * OpenCode Plugin Adapter for turn-hook.py.
 *
 * Bridges OpenCode lifecycle events to the unified turn-hook.py state machine
 * whenever AGENT_TURN_STATE or SPAWN_TURN_STATE is defined in the environment.
 */
import { spawnSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TURN_HOOK_PATH = path.resolve(__dirname, "..", "turn-hook.py");

function callTurnHook(event, payload) {
  const stateFile = process.env.AGENT_TURN_STATE || process.env.SPAWN_TURN_STATE;
  if (!stateFile) {
    return { continue: true };
  }

  const result = spawnSync("python3", [TURN_HOOK_PATH, event, "--state", stateFile], {
    input: JSON.stringify(payload || {}),
    encoding: "utf-8",
    timeout: 10000,
  });

  if (result.status === 2) {
    return { block: true, reason: result.stderr?.trim() || "Blocked by turn-hook budget policy" };
  }

  try {
    return JSON.parse(result.stdout || "{}");
  } catch {
    return { continue: true };
  }
}

export default function opencodeTurnHookPlugin() {
  return {
    name: "opencode-turn-hook",
    onPrompt: (payload) => callTurnHook("prompt", payload),
    onToolUse: (payload) => callTurnHook("tool", payload),
    onStop: (payload) => callTurnHook("stop", payload),
  };
}
