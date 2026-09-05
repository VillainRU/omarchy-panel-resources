const assert = require('node:assert/strict')
const { spawn } = require('node:child_process')
const { createInterface } = require('node:readline')
const path = require('node:path')

async function run(command, args, scenario) {
  const proc = spawn(command, args, { cwd: path.join(__dirname, '..') })
  let stderr = ''
  proc.stderr.on('data', chunk => { stderr += chunk })
  const queue = [], waiters = []
  const lines = createInterface({ input: proc.stdout })
  lines.on('line', line => {
    const value = JSON.parse(line)
    if (waiters.length) waiters.shift()(value)
    else queue.push(value)
  })
  const deadline = setTimeout(() => proc.kill('SIGKILL'), 12000)
  const exited = new Promise(resolve => proc.on('exit', (code, signal) => {
    clearTimeout(deadline)
    while (waiters.length) waiters.shift()(null)
    resolve({ code, signal })
  }))
  const next = () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waiters.push(resolve))
  try { await scenario(proc, next) }
  finally { proc.stdin.end() }
  const result = await exited
  assert.equal(result.code, 0, stderr || JSON.stringify(result))
  assert.doesNotMatch(stderr, /unexpected disabled NVIDIA read/)
}

async function main() {
  await run('bin/panel-resources-collect', ['--watch','--control','--enabled-metrics','cpu.load'], async (proc, next) => {
    assert.equal((await next()).complete, true)
    proc.stdin.write('CONFIG 1000 cpu.load 0\n')
    let snapshot = await next()
    assert.equal(snapshot.complete, false)
    assert.ok(snapshot.metrics.every(m => m.id === 'cpu.load'))
    assert.ok(snapshot.metrics.every(m => m.label === undefined))
    proc.stdin.write('CONFIG 1000 cpu.load 1\n')
    snapshot = await next()
    assert.ok(snapshot.metrics.some(m => m.id === 'memory.ram'))
    proc.stdin.write('CONFIG 1000 - 0\n')
    assert.deepEqual((await next()).metrics, [])
    proc.stdin.write('RESCAN\n')
    assert.equal((await next()).complete, true)
    // Closing the control pipe must stop the real collector promptly.
  })
  await run('bash', ['tests/collector-fixture.sh','--watch','--control','--enabled-metrics','cpu.load'], async (proc, next) => {
    assert.equal((await next()).gpuVendor, 'nvidia')
    proc.stdin.write('CONFIG 1000 cpu.load 0\n')
    assert.equal((await next()).complete, false)
    assert.equal((await next()).complete, false)
    assert.equal((await next()).complete, false)
    proc.stdin.write('CONFIG 1000 gpu.load 0\n')
    assert.ok((await next()).metrics.some(m => m.id === 'gpu.load'))
    proc.stdin.write('CONFIG 1000 cpu.temp 0\n')
    assert.ok((await next()).metrics.some(m => m.id === 'cpu.temp'))
    proc.stdin.write('FAULT\n')
    const failed = await next()
    assert.equal(failed.sampled, 'cpu.temp')
    assert.deepEqual(failed.metrics, [])
    assert.equal(failed.complete, false)
    proc.stdin.write('RECOVER\n')
    assert.ok((await next()).metrics.some(m => m.id === 'cpu.temp'))
  })
  console.log('Collector control, popup, NVIDIA and EOF regressions passed')
}
main().catch(error => { console.error(error); process.exitCode = 1 })
