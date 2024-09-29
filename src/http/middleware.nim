import router, asyncdispatch

proc makeLogMiddleware*(): RequestMiddleware {.gcsafe.} =  
    proc (request: RoutedRequest, next: RequestMiddlewareHandler): Future[void] {.async gcsafe.} =
        echo "Request: ", request.request.reqMethod, " ", request.request.url.path
        await next(request)
