import std/asynchttpserver
import std/asyncdispatch
import http/router, http/middleware

import apis/helloworld

# SSE example:
# let client = request.client

# await client.send("HTTP/1.1 200 OK\c\L")
# await client.send("Content-Type: text/event-stream\c\L")
# await client.send("Cache-Control: no-cache\c\L")
# await client.send("Connection: keep-alive\c\L")

# while true:
# # for i in 1..100: 
#     await client.send("data: { \"message\": \"Hey there\" }\c\L\c\L")
#     # await request.respond(Http200, "Hello, World!\n", { "Accept": "text/event-stream" }.newHttpHeaders())

#     await sleepAsync(100)
# discard


type tx = ref object of RootObj
    x: int

proc main {.async.} = 
    var server = newAsyncHttpServer()

    server.listen(Port(8080))

    let port = server.getPort
    echo "Listening on port ", $port.uint16

    let router = newRouter(@[makeLogMiddleware()])
    router.registerHelloWorld()

    while true:
        if server.shouldAcceptRequest():
            await server.acceptRequest(router.curriedHandleRequest)
        else:
            await sleepAsync(100)

    discard

waitFor main()