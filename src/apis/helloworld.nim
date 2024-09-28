import asyncdispatch, asynchttpserver, std/tables, options, strformat, asyncdispatch, sugar

import ../http/router

let get: RouteHandler = 
    proc (req: Request, params: RouteParams) {.async gcsafe.} =
        let param = params["param"]
        await req.respond(Http200, &"Hello,!\n", { "Content-Type": "text/plain" }.newHttpHeaders())

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