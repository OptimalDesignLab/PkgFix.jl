# PkgFix

This package is a wrapper over some of the commonly used parts of `Base.Pkg`.
Its purpose is to improve the behavior of these function to make installing
packages, particularly those not listed in `METADATA`, easier.

## Installation

Due to deficiancies in Julia's package manager (which this package attempts
to correct), `PkgFix` cannot be installed via the REQUIRE file.  Instead,
any package using it should put the following at the top of the package's
`build.jl` file:

```julia
if !isdir(joinpath(Pkg.dir(), "PkgFix"))
  Pkg.clone("https://github.com/OptimalDesignLab/PkgFix.jl.git")
end

using PkgFix  # from now on, use PkgFix instead of Pkg for everything
```

## Usage

The main purpose of this package is to make each operation do exactly
what its name implies, *and nothing more*.  For example, while `Pkg.clone`
clones a package and attempts to install its dependencies, `PkgFix.clone`
clones the repository only.  This scheme avoids certain kinds of problems
that can occur because `Pkg.clone` immediately attempts to resolve
dependencies without giving the user a chance to specify what version of
the package to build.

The list of functions with behavior different than `Pkg` (see the docstrings in the code or use the REPL help mode):

 * `add`
 * `clone`
 * `checkout`
 * `pin`
 * `free`

Note that some functions listed above (such as `pin` and `free`) are
incompatible with their counterparts in `Pkg`.  For this reason, it is
recommended to use `PkgFix` *exclusively* for package operations.
Note that this is not incompatible with using `REQUIRE` files to
install package.  The primary aim of `PkgFix` is to install packages that
cannot be installed through a `REQUIRE` file.

Functions that have the same behavior as those in `Pkg`

 * `status`
 * `rm`
 * `installed`
 * `resolve`
 * `build`
 * `dir`

See the `Pkg` documentation for those functions.
