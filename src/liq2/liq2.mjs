import * as fs from 'node:fs/promises'
import * as sysPath from 'node:path'

import { formatTerminalText, processCommand } from './lib'

const args = process.argv.slice(2);


(async () => {
  const { fetchOpts, url } = await processCommand(args)

  const response = await fetch(url, fetchOpts)

  const contentType = response.headers.get('Content-Type')
  const disposition = response.headers.get('Content-Disposition')
  const status = response.status

  if (disposition?.startsWith('attachment')) { // save the file
    let outputFileName = 'output'
    const [ , fileNameBit ] = disposition.split(/;\s*/)
    if (fileNameBit.startsWith('filename=')) {
      const [ , rawFileName ] = fileNameBit.split(/=\s*/)
      outputFileName = sysPath.basename(rawFileName.replace(/^['"]/, '').replace(/['"]$/, ''))
    }
    
    await fs.writeFile(outputFileName, (await response.blob()).stream())
    console.log(`Saved '${contentType}' file '${outputFileName}'.`)
  }
  else { // output to screen
    if (status >= 400) {
      const errorSource = status < 500 ? 'Client' : 'Server'
      console.error(formatTerminalText(`<error>${errorSource} error ${status}: ${response.statusText}<rst>`))
    }
    if (contentType.startsWith('application/json')) {
      console.log(JSON.stringify(await response.json(), null, '  '))
    }
    else {
      console.log(formatTerminalText(await response.text()))
    }
  }
})()
