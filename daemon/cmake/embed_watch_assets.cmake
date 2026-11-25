# Writes OUTPUT, a C++ file defining gamepilot::watch_asset() (watch_assets.h)
# over the bytes of each file in NAMES (comma-separated, in DIR): the pages'
# scripts and styles, so the daemon serves them without reading files.
string(REPLACE "," ";" names "${NAMES}")
set(arrays "")
set(lookups "")
set(index 0)
foreach(name IN LISTS names)
  file(READ "${DIR}/${name}" hex HEX)
  string(LENGTH "${hex}" hex_length)
  math(EXPR size "${hex_length} / 2")
  string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," bytes "${hex}")
  if(name MATCHES "\\.js$")
    set(type "text/javascript; charset=utf-8")
  elseif(name MATCHES "\\.css$")
    set(type "text/css; charset=utf-8")
  else()
    message(FATAL_ERROR "embed_watch_assets: no type for ${name}")
  endif()
  string(APPEND arrays "const unsigned char kAsset${index}[${size}] = {${bytes}};\n")
  string(APPEND lookups
    "  if (name == \"${name}\") {\n"
    "    return WatchAsset{\"${type}\",\n"
    "                      {reinterpret_cast<const char*>(kAsset${index}),\n"
    "                       sizeof(kAsset${index})}};\n"
    "  }\n")
  math(EXPR index "${index} + 1")
endforeach()
file(WRITE "${OUTPUT}"
"// Generated from watch/page/{${NAMES}} by cmake/embed_watch_assets.cmake.\n"
"#include <optional>\n"
"#include <string_view>\n\n"
"#include \"watch_assets.h\"\n\n"
"namespace gamepilot {\n\n"
"namespace {\n"
"${arrays}"
"}  // namespace\n\n"
"std::optional<WatchAsset> watch_asset(std::string_view name) {\n"
"${lookups}"
"  return std::nullopt;\n"
"}\n\n"
"}  // namespace gamepilot\n")
