-- gnattest-scm-1.rockspec
rockspec_format = "3.0"
package = "gnattest"
version = "0.1.0"
source = {
  url = "$NVIM_PLUGINS" .. package,
}
dependencies = {
  "lua >= 5.1",
}
test_dependencies = {
  "busted",
  "nlua",
}
build = {
  type = "builtin",
  copy_directories = {
    "plugin",
  },
}
