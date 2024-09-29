import asyncdispatch, asynchttpserver, std/tables, options, strformat, asyncdispatch, sugar

import ../http/router, ../http/middleware

let get: RouteHandler = 
    proc (req: RoutedRequest) {.async gcsafe.} =
        let param = req.params["param"]
        await req.request.respond(Http200, &"Hello, {param}!\n", { "Content-Type": "text/plain" }.newHttpHeaders())

proc registerHelloWorld*(router: Router) =
    discard router
        .addRoute("/hello")
            .setHandler(HttpGet, some(get))
    # discard router
    #     .addRoute("/hello/:param?")
    #         .setHandler(HttpGet, some(get))
    discard router
        .addRoute("/world/:param")
            .setHandler(HttpGet, some(get))
    discard router
        .addRoute("/world")
            .setHandler(HttpGet, some(get))
    # discard router
    #     .addRoute("/hello/:param?/world/")
    #         .setHandler(HttpGet, some(get))