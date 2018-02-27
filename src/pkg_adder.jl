# this is a better implementatoin of Pkg.clone
module PkgFix

import Base.Pkg
import Base.Pkg.Reqs
using Base.Pkg.Types
using Base.Pkg.Git


"""
  Adds a package.  This clones the package, installs its dependencies, and
  executes the package's build script.

  This function uses Julia Pkg.resolve() to install dependencies, which is
  known to be unreliable, but its the only option at the moment.

  **Inputs**

   * repo: repository URL
   * branch_ish: see [`clone`](@ref)
"""
function add(repo::AbstractString, branch_ish="")

  clone(repo, branch_ish=branch_ish)
  resolve()  # add dependencies
  build()  # build this package

  return nothing
end


"""
  Clones a Julia package (and nothing more).  This function does not build
  the package nor install its dependencies

  **Inputs**

   * repo: the repository URL
   * branch_ish: a branch or tag to checkout after cloning.  This argument can 
                 be anything accepted by `git checkout`.  This argument is
                 optional.  

  **Implementation Notes**

  `branch_ish` is passed to [`PkgFix.checkout`](@ref), see that function
               for details

"""
function clone(repo::AbstractString, branch_ish="")


  repo_name = getRepoName(repo)
  repo_namd_ext = repo_name*".jl"
  start_dir = pwd()

  try
    cd(Pkg.dir())
    run(`git clone $repo`)

    # rename ot remove the .jl
    run(`mv $repo_name_ext $repo_name`)

    if branch_ish != ""
      checkout(repo_name, branch_ish)
    end

    # add the new repo to the global REQUIRE file
    # so it doesn't get removed the next time Pkg.add is run
    addRequirement(repo_name)
  catch x
    cd(start_dir)
    rethrow(x)
  end

  cd(start_dir)

  return nothing
end

"""
  Checks out a particular branch/tag/commit of a package.

  **Inputs**

   * pkg: the package name
   * branch_ish: the name of the thing to checkout (note that this argumetn
                 can be anything accepted by `git checkout`

  **Implementation Notes**

  If `branch_ish` is a commit, this function will checkout the commit to a new branch
  named `detached_from_branch_ish`, otherwise the `branch_ish` will be checkout
  out directly.

"""
function checkout(pkg::AbstractString, branch_ish)

  start_dir = pwd()

  try
    cd(joinpath(Pkg.dir(), pkg))

    if is_commit(pwd(), branch_ish)
      run(`git checkout -b detatched_from_$branch_ish`)
    else
      run(`git checkout $branch_ish`)
    end
  catch x
    cd(start_dir)
    rethrow(x)
  end

  cd(start_dir)

  return nothing
end
    

"""
  Given a git url, extracts the package name.  This assumes the url is of the
  format blah/blah/blah/Pkgname.jl.git
"""
function getRepoName(url::AbstractString)

  if !endswith(url, ".git")
    error("url $url does not end in .git")
  end

  url_stub = url[1:end-4]

  if !endswith(url_stub, ".jl")
    error("repository name does not end in .jl")
  end

  url_stub = url_stub[1:end-3]

  # find the final slash (which preceeds the start of the package name)
  idx = 0
  for i=length(url):-1:1
    if url[i] == '/'
      idx = i + 1  # record start of repo name
      break
    end
  end

  repo_name = url[idx:end]

  return repo_name
end

"""
  Add a package to the global REQUIRE file (if it is not already present).

  This function does not check if the directory for the package exists, it
  blindly adds to the REQUIRE file.

  This function does not support adding version requirements

  **Inputs**

   * repo_name: name of the package (not including the .jl extension)
"""
function addRequirement(repo_name::AbstractString)

  f = Pkg.Reqs.read(joinpath(Pkg.dir(), "REQUIRE"))
  already_required = false
  for i=1:length(f)
    if f[i].package == repo_name
      already_required = true
      break
    end
  end

  if !already_required
    line = Reqs.Requirement(repo_name, VersionSet())
    line_arr = Reqs.Line[line]
    f2 = open("REQUIRE", "a")
    Reqs.write(f2, line_arr)
    close(f2)
  end

  return nothing
end

"""
  This function determines if a git identifier is a commit or something else
  (ie. a branch or tag)

  **Inputs**

   * pkg_dir: path to directory containing the repo
   * hash: git object identifier

  **Outputs**

   * bool, true if hash represents a commit, false otherwise
"""
function is_commit(pkg_dir::AbstractString, hash::AbstractString)

  start_dir = pwd()
  cd(pkg_dir)
  
  iscommit = false
  try
    vals = readall(`git show-ref | grep $hash`)
    # make sure this is an exact match
    name = split(vals, '/')[end]
    if name[1:end-1] == hash
      iscommit = false
    else
      iscommit = true
    end
  catch x
    iscommit = true
  end

  cd(start_dir)
  return iscommit
end

"""
  This function pins a package so that the Julia package manager will not change
  its version.  Note that packages pinned by this function must be freed by
  PkgFix.free and not by Pkg.free.  Similarly, PkgFix.free cannot free packakages
  pinned by Pkg.pin.  You can tell if a package was pinned by PkgFix by inspecting
  the branch name shown by Pkg.status for `PKGFIX`.

  This function does not change the version of any other package.

  **Inputs**

   * pkg: the package name
"""
function pin(pkg::AbstractString)

  start_dir=pwd()
  try
    cd(joinpath(Pkg.dir(), pkg))
    # it appears as long as the branch names starts with pinned., then the 
    # package manager considers it pinned

    head = getHeadIdentifier(pkg)
    run(`git checkout -b pinned.PKGFIX$head.tmp`)
  catch x
    cd(start_dir)
    rethrow(x)
  end

  cd(start_dir)

  return nothing
end
    
"""
  This function frees a package pinned by PkgFree.pin.  It cannot free a
  a package pinned by the Julia package manager (it prints a warning and exits
  without making changes in this case).

  This function will restore the package to its state previous to pinning
  (if it was on a branch, it will return to that branch).

  This function does not change the version of any other packages.

  **Inputs**

   * pkg: the package name
"""
function free(pkg::AbstractString)
  start_dir = pwd()
  try
    cd(joinpath(Pkg.dir(), pkg))
    head = getHeadIdentifier(pkg)

    # make sure the format of head is the format written by pin
    if !startswith(head, "pinned")
      println(STDERR, "Warning: package $pkg is not pinned, not freeing...")
      cd(start_dir)
      return nothing
    end

    # remove the prefix pinned.
    head = head[8:end]

    # remove the suffix .tmp
    head = head[1:end-4]

    if !startswith(head, "PKGFIX")
      println(STDERR, "Warning: package was not pinned by PkgFix, not freeing...")
      cd(start_dir)
      return nothing
    end

    # if we get here, this package was pinned by PkgFee, so restore it
    # to the previous state
    old_head = head[7:end]
    run(`git checkout $old_head`)

  catch x
    cd(start_dir)
    rethrow(x)
  end

  cd(start_dir)

  return nothing
end

function getHeadIdentifier(pkg::AbstractString)

  start_dir = pwd()

  try
    cd(joinpath(Pkg.dir(), pkg))
    str = readcomp(`git rev-parse --abbrev-commit HEAD`)

    if str == "HEAD"  # the current head is not a branch
      str = readchomp(`git rev-parse HEAD`)
    end
  catch x
    cd(start_dir)
    rethrow(x)
  end

  cd(start_dir)
  return str
end


# functions that delegate to things in Pkg
function status()
  Pkg.status()
end

function rm(pkg::AbstractString)
  Pkg.rm(pkg)
end

function installed()
  Pkg.installed()
end

function installed(pkg::AbstractString)
  Pkg.installed(pkg)
end

function resolve()
  Pkg.resolve()
end

function build(pkg::AbstractString)
  Pkg.build()
end



  

end # end module
