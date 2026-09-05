const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const repo = path.resolve(__dirname, '..')
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'panel-resources-runtime-'))
try {
  for (const name of ['Service.qml', 'Model.js']) fs.copyFileSync(path.join(repo, name), path.join(temporary, name))
  fs.copyFileSync(path.join(__dirname, 'runtime/shell.qml'), path.join(temporary, 'shell.qml'))
  const result = spawnSync('quickshell', ['-p', temporary, '--no-color'], {
    env: { ...process.env, PANEL_RESOURCES_TEST_REPO: repo, QT_QPA_PLATFORM: 'offscreen' },
    encoding: 'utf8', timeout: 25000
  })
  const output = result.stdout + result.stderr
  assert.equal(result.status, 0, output)
  assert.match(output, /RUNTIME PASS:/)
  assert.doesNotMatch(output, /RUNTIME FAIL:|ReferenceError|TypeError|Binding loop/)
  console.log(output)
} finally {
  fs.rmSync(temporary, { recursive: true, force: true })
}
