import assert from "node:assert/strict";
import { forkArgv, forkName, forkNote, viaShell } from "./argv.js";

const tail = ["--resume", "new", "--fork-session"];
assert.deepEqual(forkArgv(["claude", "--settings", "/s.json"], "new"), ["claude", "--settings", "/s.json", ...tail]);
assert.deepEqual(forkArgv(["claude", "--resume", "old", "--model", "opus"], "new"), ["claude", "--model", "opus", ...tail]);
assert.deepEqual(forkArgv(["claude", "-c", "--dangerously-skip-permissions", "fix it"], "new"), ["claude", "--dangerously-skip-permissions", ...tail]);
assert.deepEqual(forkArgv(["claude", "--resume=old", "--fork-session", "do x"], "new"), ["claude", ...tail]);
assert.deepEqual(forkArgv(["claude", "hello"], "new"), ["claude", ...tail]);
assert.deepEqual(forkArgv(["claude", "--settings", "/s.json", "--settings", "/s.json", "--settings", "/t.json"], "new"), ["claude", "--settings", "/s.json", "--settings", "/t.json", ...tail]);
assert.deepEqual(viaShell(["claude", "--model", "opus"]).slice(3), ["claude", "--model", "opus"]);
assert.match(forkNote("abc", "t2"), /fork of session abc\. .*terminal t2 /);
// A fork of a fork: the earlier note is the launch prompt, not a flag, so it isn't carried over.
assert.deepEqual(forkArgv(["claude", "--resume", "old", "--fork-session", forkNote("old", "t1")], "new"), ["claude", ...tail]);
assert.equal(forkName("my-session", "abcd1234-ef56"), "[F] my-session");
assert.equal(forkName(undefined, "abcd1234-ef56"), "[F] abcd1234");
assert.deepEqual(forkArgv(["claude", "--name", "old", "-n", "older", "--model", "opus"], "new", "[F] old"), ["claude", "--model", "opus", ...tail, "--name", "[F] old"]);
console.log("ok");
