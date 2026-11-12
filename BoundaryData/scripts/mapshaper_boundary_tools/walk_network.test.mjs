// node --test walk_network.test.mjs
// One walk per connected network covering every arc, with as few arcs walked twice as possible.
import test from 'node:test';
import assert from 'node:assert/strict';
import { walkNetwork } from './boundary_tools.mjs';

const key = ([x, y]) => `${x},${y}`;
const segmentKey = (a, b) => [key(a), key(b)].sort().join('|');
/** How many times each segment is walked. */
function segmentUses(walks) {
  const uses = new Map();
  for (const walk of walks) {
    for (let i = 1; i < walk.length; i++) {
      const k = segmentKey(walk[i - 1], walk[i]);
      uses.set(k, (uses.get(k) || 0) + 1);
    }
  }
  return uses;
}
function assertCovers(walks, arcs) {
  const expected = segmentUses(arcs);
  const actual = segmentUses(walks);
  assert.deepEqual([...actual.keys()].sort(), [...expected.keys()].sort(), 'walks must cover exactly the arc segments');
}

test('一本道は往復せずにそのまま1本になる', () => {
  const arcs = [[[0, 0], [1, 0]], [[1, 0], [2, 0], [3, 0]]];
  const walks = walkNetwork(arcs, key);
  assert.equal(walks.length, 1);
  assertCovers(walks, arcs);
  assert.equal(walks[0].length, 4);
});

test('三叉路は1本にまとめ、往復は最も短い枝だけにする', () => {
  // 中心(0,0)から3方向へ。長さ3・2・1の枝。両端に長い2本を使い、短い1本だけ往復するのが最短。
  const arcs = [
    [[0, 0], [1, 0], [2, 0], [3, 0]],
    [[0, 0], [0, 1], [0, 2]],
    [[0, 0], [-1, 0]],
  ];
  const walks = walkNetwork(arcs, key);
  assert.equal(walks.length, 1);
  assertCovers(walks, arcs);
  const twice = [...segmentUses(walks)].filter(([, n]) => n === 2).map(([k]) => k);
  assert.deepEqual(twice, [segmentKey([0, 0], [-1, 0])]);
});

test('輪はそのまま閉じた1本になる', () => {
  const arcs = [[[0, 0], [1, 0], [1, 1]], [[1, 1], [0, 1], [0, 0]]];
  const walks = walkNetwork(arcs, key);
  assert.equal(walks.length, 1);
  assertCovers(walks, arcs);
  assert.ok([...segmentUses(walks).values()].every(n => n === 1));
  assert.equal(key(walks[0][0]), key(walks[0][walks[0].length - 1]));
});

test('離れた網は別々の線になる', () => {
  const arcs = [[[0, 0], [1, 0]], [[5, 5], [6, 5]], [[1, 0], [1, 1]]];
  const walks = walkNetwork(arcs, key);
  assert.equal(walks.length, 2);
  assertCovers(walks, arcs);
});

test('格子状の網も1本でたどれる', () => {
  // 3x3 の格子(交点はすべて次数2〜4、外周の辺の中点は次数3)。
  const arcs = [];
  for (let y = 0; y <= 2; y++) for (let x = 0; x < 2; x++) arcs.push([[x, y], [x + 1, y]]);
  for (let x = 0; x <= 2; x++) for (let y = 0; y < 2; y++) arcs.push([[x, y], [x, y + 1]]);
  const walks = walkNetwork(arcs, key);
  assert.equal(walks.length, 1);
  assertCovers(walks, arcs);
  // 奇数次の頂点は4つ(辺の中点)。2つを両端にすれば、往復は残り2つを結ぶ最短経路(2辺)で済む。
  const doubled = [...segmentUses(walks).values()].filter(n => n === 2).length;
  assert.ok(doubled <= 2, `doubled ${doubled}`);
});
