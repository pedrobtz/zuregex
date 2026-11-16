# Runs the finalizers of live `re` patterns and empties the cache while the
# DLL is still loaded, then unloads it. A C finalizer left registered after
# the DLL is gone points into unmapped code and crashes the next gc()
# (#168). unloadNamespace() and pkgload::unload() both call this first.
.onUnload <- function(libpath) {
  .Call(zuregex_unload_c)
  library.dynam.unload("zuregex", libpath)
}
