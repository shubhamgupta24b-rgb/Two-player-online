const norm = s => String(s).normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

function lev(a, b) {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      dp[i][j] = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return dp[a.length][b.length];
}

// Exact match on name/alias, or one typo allowed for answers of 7+ characters.
function isCorrect(guess, person) {
  const g = norm(guess);
  if (!g) return false;
  return [person.name, ...(person.aliases || [])].map(norm).some(c => g === c || (c.length >= 7 && lev(g, c) <= 1));
}
module.exports = { norm, isCorrect };
