const path = require('path')
const { importCost, cleanup, JAVASCRIPT, TYPESCRIPT } = require('import-cost')

function send(payload) {
  process.nextTick(() => {
    process.stdout.write(JSON.stringify(payload))
  })
}

function packageToObject(package) {
  return {
    name: package.name,
    line: package.line,
    size: typeof package.size !== 'undefined' ? package.size : -1,
    gzip: typeof package.gzip !== 'undefined' ? package.gzip : -1,
  }
}

async function readStdin() {
  return new Promise((resolve, reject) => {
    process.stdin.resume()
    process.stdin.setEncoding('utf-8')

    let data = ''
    process.stdin.on('data', chunk => {
      data += chunk
    })
    process.stdin.on('end', () => {
      resolve(data)
    })
    process.stdin.on('error', err => {
      reject(err)
    })
  })
}

async function main() {
  const file = process.argv[2]
  const language = path.extname(file).match(/^\.tsx?$/) ? TYPESCRIPT : JAVASCRIPT

  const fileContent = await readStdin()

  const emitter = importCost(file, fileContent, language)

  emitter.on('done', packages => {
    send({
      event: 'done',
      data: packages.map(packageToObject),
    })

    cleanup()
  })

  emitter.on('error', err => {
    send({
      event: 'error',
      error: err,
    })
  })
}

main()
  .catch(err => {
    send({event: 'error', error: err})
    process.exit(1)
  })
