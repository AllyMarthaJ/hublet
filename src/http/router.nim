import options
import asynchttpserver
import asyncdispatch
import std/tables
import std/strutils 
import std/strformat
import std/strbasics
import std/sugar
import std/sequtils
import std/deques
import marshal 

type 
    RouteParams* = 
        Table[string, string]
    RouteHandler* = 
        proc (request: Request, params: RouteParams): Future[void] {.async gcsafe.}

    CompiledRoute* = ref object of RootObj
        pathComponent*: string
        paramName*: Option[string]
        isOptional: Option[bool]
        routes*: Table[string, CompiledRoute]

        get, post, put, delete: Option[RouteHandler]
    
    Router* = ref object of RootObj
        rootRoute*: CompiledRoute

proc initRouteParams*(): RouteParams = 
    initTable[string, string]()

proc toPathComponents(path: string, shouldStrip: bool = false): Deque[string] = 
    var newPath = path

    if shouldStrip:
        strip(newPath, false, true, { '/' })

    newPath.split("/").toDeque

proc toCompiledRoute(pathComponent: string): CompiledRoute = 
    let isParameter = pathComponent.startsWith(":")
    let isOptionalParameter = isParameter and pathComponent.endsWith("?")

    CompiledRoute(
        pathComponent: 
            if isParameter:
                "*"
            else:
                pathComponent,
        paramName: 
            if isParameter:
                if pathComponent.endsWith("?"):
                    some(pathComponent[1..^2])
                else:
                    some(pathComponent[1..^1])
            else:
                none(string),
        isOptional: 
            if isParameter:
                if isOptionalParameter:
                    some(true)
                else:
                    some(false)
            else:
                none(bool),
        routes: initTable[string, CompiledRoute](),
        get: none(RouteHandler),
        post: none(RouteHandler),
        put: none(RouteHandler),
        delete: none(RouteHandler)
    )

proc routeFor(route: CompiledRoute, pathComponent: string, params: var RouteParams): Option[CompiledRoute] = 
    let maybeAbsoluteRoute = route.routes.getOrDefault(pathComponent)
    let maybeWildcardRoute = route.routes.getOrDefault("*")

    return if not maybeAbsoluteRoute.isNil():
        some(maybeAbsoluteRoute)
    elif not maybeWildcardRoute.isNil():
        params[maybeWildcardRoute.paramName.get()] = pathComponent
        some(maybeWildcardRoute)
    else:
        none(CompiledRoute)

proc routeFor*(router: Router, path: string): tuple[route: Option[CompiledRoute], params: RouteParams] =
    var pathComponents = path.toPathComponents()

    # Root route; we know that it exists, so don't bother with it.
    discard pathComponents.popFirst()

    if pathComponents[0] == "":
        return (route: some(router.rootRoute), params: initRouteParams())

    var currentRoute = some(router.rootRoute)
    var params = initRouteParams()

    while pathComponents.len > 0 and currentRoute.isSome():
        let pathComponent = pathComponents.popFirst()

        if pathComponent == "":
            # Is this the last component to process?
            let canLookAhead = pathComponents.len > 0

            if not canLookAhead:
                # We're at the end of the path. 
                var tempParams = params # don't poison params.
                let tempRoute = currentRoute.get().routeFor(pathComponent, tempParams)
                let isOptional = tempRoute.isSome() and tempRoute.get().isOptional.isSome() and tempRoute.get().isOptional.get()
                
                # Only use the following path if it's optional.
                # So, for example /base/:param? should match /base/ and /base/param.
                # But /base/:param should not match /base/.
                if isOptional:
                    currentRoute = tempRoute
                
                break

        currentRoute = currentRoute.get().routeFor(pathComponent, params)
    
    (route: currentRoute, params: params) 

proc setHandler*(route: CompiledRoute, httpMethod: HttpMethod, handler: Option[RouteHandler]): CompiledRoute = 
    case httpMethod
    of HttpGet:
        route.get = handler
    of HttpPost:
        route.post = handler
    of HttpPut:
        route.put = handler
    of HttpDelete:
        route.delete = handler
    else:
        discard

    return route

proc addRoute*(route: CompiledRoute, subPath: string): CompiledRoute =
    var pathComponents = subPath.toPathComponents(true)
    var currentRoute = route

    echo &"Registering route {pathComponents}."

    while pathComponents.len > 0:
        let pathComponent = pathComponents.popFirst()
        let route = pathComponent.toCompiledRoute()

        let maybeRoute = currentRoute.routes.getOrDefault(route.pathComponent)

        if maybeRoute.isNil():
            currentRoute.routes[route.pathComponent] = route
            currentRoute = route
        else:
            currentRoute = maybeRoute
    
    currentRoute

proc addRoute*(router: Router, path: string): CompiledRoute = 
    # addRoute is relative to the parent route, so strip the leading '/'
    # to avoid creating a route with an empty path component.
    router.rootRoute.addRoute(path.strip(true, false, { '/' }))

proc newRouter*(): Router = 
    Router(
        rootRoute: "".toCompiledRoute()
    )

proc handleRequest(router: Router, request: Request): Future[void] {.async gcsafe.} =
    let (maybeRoute, params) = router.routeFor(request.url.path)

    if maybeRoute.isNone():        
        echo &"Request to resource which has no route. {request.url.path}" 
        await request.respond(Http404, "Not found\n", { "Content-Type": "text/plain" }.newHttpHeaders())
        return

    let route = maybeRoute.get()

    let handler = 
        case request.reqMethod
        of HttpGet:
            route.get
        of HttpPost:
            route.post
        of HttpPut:
            route.put
        of HttpDelete:
            route.delete
        else:
            none(RouteHandler)

    # If the route has no handler at all, we should return 404.
    let hasMethod = (@[route.get.isSome(), route.post.isSome(), route.put.isSome(), route.delete.isSome()]).any(value => value)
    if hasMethod and handler.isNone():
        await request.respond(Http405, "Method not allowed\n", { "Content-Type": "text/plain" }.newHttpHeaders())
        return
    elif handler.isNone():
        echo &"Request to resource which has no handler. {request.url.path}" 
        await request.respond(Http404, "Not found\n", { "Content-Type": "text/plain" }.newHttpHeaders())
        return
    else:
        await handler.get()(request, params)

proc curriedHandleRequest*(router: Router): proc (request: Request): Future[void] {.closure gcsafe.} =
    proc (request: Request): Future[void] {.closure gcsafe.} =
        handleRequest(router, request)