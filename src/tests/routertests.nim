import unittest2

import options
import std/tables

import ../http/router

suite "routeFor":
    suite "nested routes":
        setup:
            let router = newRouter()
            let nestedRoute = router.addRoute("/nested/route")

        test "without trailing slash":
            check:
                router.routeFor("/nested/route").route.get() == nestedRoute
                router.routeFor("/nested/route").params == initRouteParams()

                router.routeFor("/route").route.isNone() == true
                
        test "with trailing slash":
            check:
                router.routeFor("/nested/route/").route.get() == nestedRoute
                router.routeFor("/nested/route/").params == initRouteParams()

                router.routeFor("/route/").route.isNone() == true

    suite "non-nested routes":
        setup:
            let router = newRouter()
            let nonNestedRoute = router.addRoute("/nonNestedRoute")

        test "without trailing slash":
            check:
                router.routeFor("/nonNestedRoute").route.get() == nonNestedRoute
                router.routeFor("/nonNestedRoute").params == initRouteParams()

        test "with trailing slash":
            check:
                router.routeFor("/nonNestedRoute/").route.get() == nonNestedRoute
                router.routeFor("/nonNestedRoute/").params == initRouteParams()

    suite "nested routes with parameters":
        suite "with required parameters":
            setup: 
                let router = newRouter()
                let routeWithParam = router.addRoute("/required/:param")

                let secondRouteParent = router.addRoute("/required2")
                let secondRouteParentWithParam = router.addRoute("/required2/:param")   

            test "without trailing slash":
                check:
                    router.routeFor("/required/spoof").route.get() == routeWithParam
                    router.routeFor("/required/spoof").params == { "param": "spoof" }.toTable()

                    router.routeFor("/required").route.isNone() == true

                    router.routeFor("/required2/spoof").route.get() == secondRouteParentWithParam
                    router.routeFor("/required2/spoof").params == { "param": "spoof" }.toTable()

                    router.routeFor("/required2").route.get() == secondRouteParent
                    router.routeFor("/required2").params == initRouteParams()

            test "with trailing slash":
                check:
                    router.routeFor("/required/spoof/").route.get() == routeWithParam
                    router.routeFor("/required/spoof/").params == { "param": "spoof" }.toTable()

                    router.routeFor("/required/").route.isNone() == true

                    router.routeFor("/required2/spoof/").route.get() == secondRouteParentWithParam
                    router.routeFor("/required2/spoof/").params == { "param": "spoof" }.toTable()

                    router.routeFor("/required2/").route.get() == secondRouteParent
                    router.routeFor("/required2/").params == initRouteParams()
        # setup:
        #     let router = newRouter()

        #     let routeWithParam = router.addRoute("/required/:param")
        #     let routeWithOptionalParam = router.addRoute("/optional/:param?")
        #     let routeWithOptionalParamAndBase = router.addRoute("/base2")