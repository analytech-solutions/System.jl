# System.jl

[![Build Status](https://github.com/analytech-solutions/System.jl/workflows/CI/badge.svg)](https://github.com/analytech-solutions/System.jl/actions)

A framework for interfacing with system-installed software from Julia.

System.jl allows for the use of trusted system software without relying on the binaries downloaded as Julia artifacts.
We view System.jl as an essential component for proprietary and secure computing environments.
This package does not yet support all platforms (only common Linux distributions at present), but it provides a path to that goal.
It also requires that the header files are installed for libraries so that bindings can be automatically generated from them.


# Usage

System.jl is a framework providing bindings to operating system and system-installed software API's.
System resources are available as Julia packages that encapsulate dynamically generated bindings (automatically created by [CBinding.jl](https://github.com/analytech-solutions/CBinding.jl) when you import the package).
These packages can be found in the `System.jl/pkgs` directory and are only available for use once System.jl has been imported.
Therefore, [similar to Revise.jl](https://timholy.github.io/Revise.jl/stable/config), `using System` must occur before any packages utilizing the framework are loaded, or just add it to your `~/.julia/config/startup.jl` file.

Bindings for a system resource are loaded with the `@sys using libxyz` macro syntax.
The bindings can always be referenced with the CBinding.jl `c"..."` string macro, but usually the bindings are free of name collisions so Julian names are available as well.

```jl
julia> using System

julia> @sys using libc.C99

julia> c"printf"("printf is the best!\n")
printf is the best!
20

julia> @sys using alsa.libasound

julia> for val in 0:Int(SND_PCM_STREAM_LAST)
          name = snd_pcm_stream_name(val)
          c"printf"("%s\n", name)
       end
PLAYBACK
CAPTURE
```


# Developing a framework package

Packages within the System.jl framework, found in `System.jl/pkgs`, are not known about by Pkg.jl when packages are installed.
Therefore, the framework packages are unable to use _any_ packages that are not referenced by the System.jl package itself (its dependencies are all Pkg.jl knows about).
Framework packages are generally light-weight uses of CBinding.jl, but the special `sys` package introduces tools to facilitate the process.

It provides the `@pkgconf` macro to automatically inject the dependency packages' compilation command line arguments and header file inclusions in order to prepare both the Julia and C definitions needed to declare the package's bindings.
The following example demonstrates the usage of this macro:

```jl
module libpkg
  using sys
  
  @pkgconf begin
    using libdep1, libdep2
    c`-I/path/to/include -L/path/to/libs -lpkg`
    c"""
      #include <pkg/header-1.h>
      #include <pkg/header-2.h>
    """ji
  end
end
```

And what the manually written equivalent might look like:

```jl
module libpkg
  using sys
  
  using libdep1
  using libdep2
  
  c`-L/dep1/lib -ldep1  -DDEP2_USE_DEP1=1 -L/dep2/lib -ldep2  -I/path/to/include -L/path/to/lib -lpkg`
  
  c"""
    #include <dep1/header-1.h>
    #include <dep1/header-2.h>
  """s
  
  c"""
    #include <dep2/header-1.h>
    #include <dep2/header-2.h>
  """s
  
  c"""
    #include <pkg/header-1.h>
    #include <pkg/header-2.h>
  """ji
end
```

Further details will become available as the package grows and is tested on more systems.

