import * as fs from 'node:fs/promises'

import { PORT, PROTOCOL, SERVER } from './constants'

const methods = [ 'DELETE', 'GET', 'OPTIONS', 'POST', 'PUT', 'UNBIND' ]

const extToMime = (value) => {
  switch (value) {
    case 'txt':
      return 'text/plain'; break
    case 'terminal':
      return 'text/terminal'; break
    case 'md':
    case 'markdown':
      return 'text/markdown'; break
    case 'csv':
      return 'text/csv'; break
    case 'tsv':
      return 'text/tab-separated-values'; break
    case 'pdf':
      return 'application/pdf'; break
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; break
    default:
      return 'application/json'
  }
}

const processCommand = async (args) => {
  let method
  const pathBits = []
  const data = []
  let accept = 'text/terminal, text/plain;q=0.8, application/json;q=0.5'
  let setParams = false
  
  if (methods.includes(args[0])) {
    method = args[0].toLowerCase()
    args.shift()
  }

  for (const arg of args) {
    if (arg === '--' && setParams === false) {
      setParams = true
    }
    else if (setParams !== true) {
      pathBits.push(encodeURIComponent(arg))
    }
    else { // setup params
      let [ name, value = 'true', ...moreValue ] = arg.split(/\s*=\s*/)
      value = [value, ...moreValue].join('=')
      if (name === 'format') {
        accept = extToMime(value)
        data.push([ name, value ]) // everything should work with our without this
      }
      else if (name !== 'sendFormParam') {
        data.push([ name, value ])
      }
    }
  }

  const path = '/' + pathBits.join('/')

  if (method === undefined) {
    const api = JSON.parse(await fs.readFile(process.env.HOME + '/.liq/core-api.json'))
    const endpointSpec = api.find((s) => path.match(new RegExp(s.matcher)))

    method = endpointSpec.method
  }
  
  const query = data.length > 0 && method !== 'POST' ? '?' + new URLSearchParams(data).toString() : ''
  const url = `${PROTOCOL}://${SERVER}:${PORT}${path}${query}`

  const fetchOpts = {
    headers: {
      'Accept': accept
    },
    method
  }

  if (method === 'POST') {
    fetchOpts.headers['Content-Type'] = 'application/json'
    const indexdData = data.reduce((acc, d) => {
      acc[d[0]] = d[1]
      return acc
    }, {})
    fetchOpts.body = JSON.stringify(indexdData)
  }

  return {
    fetchOpts,
    url,
  }
}

export { processCommand }
