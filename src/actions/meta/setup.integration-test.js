import * as testing from '../../lib/testing'

const shell = require('shelljs')

const execOpts = {
  shell: shell.which('bash'),
  silent: true,
}

const checkDbFiles = (testConfig, playground) => {
  expect(shell.test('-d', `${testConfig.testHome}/.liquid-development`)).toBe(true)
  expect(shell.test('-d', `${testConfig.testHome}/.liquid-development/environments`)).toBe(true)
  expect(shell.test('-d', `${testConfig.testHome}/.liquid-development/work`)).toBe(true)
  expect(shell.test('-d', `${testConfig.testHome}/${playground}`)).toBe(true)
  expect(shell.test('-f', `${testConfig.testHome}/.liquid-development/settings.sh`)).toBe(true)

  const result = shell.exec(`source "${testConfig.testHome}/.liquid-development/settings.sh"; echo -n $LIQ_PLAYGROUND`, execOpts)
  expect(result.stderr).toEqual('')
  expect(result.stdout).toEqual(`${testConfig.testHome}/${playground}`)
  expect(result.code).toEqual(0)
}

describe(`'catalyst meta init'`, () =>{
  let testConfig
  beforeEach(() => {
    testConfig = testing.setup()
  })
  afterEach(() => testConfig.cleanup())

  test(`with no argument should ask for playground and initialize the liq DB and playground`, () => {
    const result = shell.exec(`HOME=${testConfig.testHome} catalyst meta init <<< $(echo)`, execOpts)

    expect(result.stderr).toEqual('')
    expect(result.stdout).toMatch(new RegExp(`^(Creating.*success[^\\\\n]*){5}(Initializing.*success[^\\\\n]*)$`, 'm'))
    expect(result.code).toEqual(0)

    checkDbFiles(testConfig, 'playground')
  })

  test(`with '-s' should supress output`, () => {
    const result = shell.exec(`HOME=${testConfig.testHome} catalyst meta init -s <<< $(echo)`, execOpts)

    expect(result.stderr).toEqual('')
    expect(result.stdout).toEqual('')
    expect(result.code).toEqual(0)

    checkDbFiles(testConfig, 'playground')
  })

  test(`with '-p "$HOME/sandbox"' should use and not query for playground value`, () => {
    // The descrepency between the description's use of '$HOME' and the tests use of ${testConfig.testHome} is because 'HOME' is only set for the commands called, not uses in the same string and testConfig is not available outside the test, so we fudge things a bit.
    const result = shell.exec(`HOME=${testConfig.testHome} catalyst meta init -s -p "${testConfig.testHome}/sandbox" <<< $(echo)`, execOpts)

    expect(result.stderr).toEqual('')
    expect(result.stdout).toEqual('')
    expect(result.code).toEqual(0)

    checkDbFiles(testConfig, 'sandbox')
  })

  test(`using invalid HOME ('/') will result in an error message.`, () => {
    // TODO: this assumes the user cannot write to '/', which should be valid in the test env, but maybe better to create a dir with specific perms just to be clear.
    const result = shell.exec(`HOME='/.' catalyst meta init -s <<< $(echo)`, execOpts)

    expect(result.stderr).toMatch(new RegExp(`.*Error creating .*`, 'ms'))
    expect(result.stdout).toEqual('')
    expect(result.code).toEqual(10)
  })
})
