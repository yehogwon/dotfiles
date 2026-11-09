// Fuzzy matching for the picker, fzf-style: a term's letters must appear in order,
// not necessarily together ("cnvpf" finds "conv-pf-spec"). Letters in a row and
// letters starting a word score more; skipped letters cost a little.

const CHAR = 16;     // each matched letter
const CONSEC = 12;   // right after the previous matched letter
const START = 10;    // the text's first letter
const BOUNDARY = 8;  // after a space, -, _, /, ., :, @ or ·
const CAMEL = 6;     // an upper-case letter after a lower-case one
const LEAD = 0.1;    // per letter before the first match: earlier is better
const isBoundary = (c) => /[\s\-_/.:@·]/.test(c);
const isLower = (c) => c !== c.toUpperCase() && c === c.toLowerCase();
const isUpper = (c) => c !== c.toLowerCase() && c === c.toUpperCase();

// The search box's words, lower-cased. Each one has to match somewhere.
export function terms(query) {
  return (query ?? "").trim().toLowerCase().split(/\s+/).filter(Boolean);
}

// The best match of one lower-case term in text: { score, positions } (indexes
// into text), or null. Positions are the best-scoring ones, not the first found:
// "pf" in "profile-pf" takes the second "pf", a word start, letters in a row.
export function match(term, text) {
  const n = text?.length ?? 0;
  const m = term.length;
  if (!m) return { score: 0, positions: [] };
  if (m > n) return null;
  const low = text.toLowerCase();
  const bonus = [];
  for (let j = 0; j < n; j++) {
    const prev = j ? text[j - 1] : "";
    bonus.push(j === 0 ? START : isBoundary(prev) ? BOUNDARY : isLower(prev) && isUpper(text[j]) ? CAMEL : 0);
  }
  // S[j]: the best score with term[i] at text[j] (-Infinity: impossible).
  // back[i][j]: where term[i - 1] was for that score.
  let prev = null;
  const back = [];
  for (let i = 0; i < m; i++) {
    const S = new Array(n).fill(-Infinity);
    const B = new Array(n).fill(-1);
    // A gap from k to j costs (j - k - 1): the best earlier k is the one with the
    // highest prev[k] + k + 1, kept as j moves right (k up to j - 2).
    let far = -Infinity;
    let farAt = -1;
    for (let j = 0; j < n; j++) {
      if (i > 0 && j >= 2 && prev[j - 2] + j - 1 > far) {
        far = prev[j - 2] + j - 1;
        farAt = j - 2;
      }
      if (low[j] !== term[i]) continue;
      const own = CHAR + bonus[j];
      if (i === 0) {
        S[j] = own - LEAD * j;
        continue;
      }
      const next = j >= 1 ? prev[j - 1] + CONSEC : -Infinity;
      const gap = far - j;
      if (next === -Infinity && gap === -Infinity) continue;
      if (next >= gap) {
        S[j] = own + next;
        B[j] = j - 1;
      } else {
        S[j] = own + gap;
        B[j] = farAt;
      }
    }
    back.push(B);
    prev = S;
  }
  let end = -1;
  for (let j = 0; j < n; j++) if (prev[j] > -Infinity && (end < 0 || prev[j] > prev[end])) end = j;
  if (end < 0) return null;
  const positions = new Array(m);
  for (let i = m - 1, j = end; i >= 0; i--) {
    positions[i] = j;
    j = back[i][j];
  }
  return { score: prev[end], positions };
}

// Every term against a row's fields ({ text, weight }). Each term counts once, in
// the field where it scores best (score × weight); a term matching nowhere drops
// the row. Returns { score, hits }: hits[i] are the matched positions in field i.
export function rank(ts, fields) {
  const hits = fields.map(() => []);
  let total = 0;
  for (const t of ts) {
    let best = null;
    let at = -1;
    fields.forEach((f, i) => {
      const r = f.text ? match(t, f.text) : null;
      if (r && (!best || r.score * f.weight > best.score * fields[at].weight)) {
        best = r;
        at = i;
      }
    });
    if (!best) return null;
    total += best.score * fields[at].weight;
    hits[at].push(...best.positions);
  }
  return { score: total, hits };
}
