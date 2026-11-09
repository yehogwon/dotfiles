// node mods/fuzzy-picker/fuzzy.test.js
import assert from "node:assert/strict";
import { terms, match, rank } from "./fuzzy.js";

// Letters in order, not together.
assert.deepEqual(match("cnvpf", "conv-pf-spec").positions, [0, 2, 3, 5, 6]);
assert.equal(match("xyz", "conv-pf-spec"), null);
assert.equal(match("fp", "pf"), null);
assert.deepEqual(match("CONV".toLowerCase(), "Conv-Spec").positions, [0, 1, 2, 3]);

// The best positions, not the first ones: a word start, letters in a row.
assert.deepEqual(match("pf", "profile-pf").positions, [8, 9]);
assert.deepEqual(match("spec", "s-p-e-c spec").positions, [8, 9, 10, 11]);

// Better matches score more.
const s = (q, x) => match(q, x).score;
assert.ok(s("conv", "conv-pf-spec") > s("conv", "cobalt-nova"), "letters in a row beat scattered");
assert.ok(s("ps", "pullback-spec") > s("ps", "cpus"), "word starts beat mid-word");
assert.ok(s("ab", "ab-x") > s("ab", "x-ab"), "earlier beats later");
assert.ok(s("fs", "flowSpec") > s("fs", "flowspec"), "camelCase hump counts as a word start");

// Words in the box: each must match somewhere.
assert.deepEqual(terms("  Server1   CONV "), ["server1", "conv"]);
const fields = [{ text: "1", weight: 1 }, { text: "server1", weight: 0.8 }, { text: "conv-pf-spec", weight: 1 }];
const r = rank(terms("serv conv"), fields);
assert.ok(r);
assert.deepEqual(r.hits, [[], [0, 1, 2, 3], [0, 1, 2, 3]]);
assert.equal(rank(terms("serv nothere"), fields), null);
assert.deepEqual(rank([], fields), { score: 0, hits: [[], [], []] });

// Weights: the same match counts more in a heavier field.
const heavy = rank(["blocked"], [{ text: "blocked", weight: 1 }]).score;
const light = rank(["blocked"], [{ text: "blocked", weight: 0.5 }]).score;
assert.ok(heavy > light);

console.log("ok");
