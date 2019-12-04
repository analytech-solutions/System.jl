# SystemBindings.jl

This package provides a framework for detecting and utilizing system libraries from Julia.

# Usage

A major goal with SystemBindings.jl is to provide a framework that enables a simple, Julian way of bringing system C libraries into your Julia package.
The framework provides utilities for detecting system resources and it includes recipes for creating bindings to resources already on your system.
Another portion of the framework creates a local pseudo-package repository for the generated bindings to be used from your own packages.

As a user who merely wishes to use a system library from Julia, the details of how SystemBindings.jl works are not important.
All you need to know is how to get access to the library without investing much effort.
Therefore, we provide a simple mechanism for using C libraries on your system.

```jl
julia> using SystemBindings

julia> @sys using libc: time

julia> time(C_NULL)
1575474532

julia> @sys using libc

julia> printf("hi\n");
hi

julia> printf("hi\n");
hi
```

If you encounter a library that is not yet in the SystemBindings.jl repertoire of recipes, please create an issue and identify what OS and system library is required.
For customizing recipes to your secure computing environments, please consider consulting with [Analytech Solutions](mailto:team@analytech-solutions.com) directly for support.

More documentation on creating recipes will be published as the package matures.
