const http = require('http')

const VERSION = 'v2-buggy'
const COLOR = 'Green'

const server = http.createServer((req, res) => {
    // CORS and caching headers
    const headers = {
        'Content-Type': 'text/plain',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Cache-Control, Pragma, Expires, Authorization, X-Requested-With',
        'Access-Control-Max-Age': '86400',
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
    }

    if (req.method === 'OPTIONS') {
        res.writeHead(204, headers)
        return res.end()
    }

    if (req.url.startsWith('/health')) {
        res.writeHead(200, headers)
        return res.end(`OK from ${VERSION}(${COLOR})!`)
    }

    // BUG: /api/status returns 500 error - simulating a bug in new release
    if (req.url.startsWith('/api/status')) {
        res.writeHead(500, headers)
        return res.end('Internal Server Error - Bug in v2!')
    }

    res.writeHead(200, headers)
    res.end(`Hello from DevOps Demo ${VERSION}! Color: ${COLOR} | Time: ${new Date().toISOString()}`)
})

server.listen(3000, () => console.log(`${COLOR} ${VERSION} (BUGGY) running on port 3000`))
