# Writes OUTPUT, a C++ file defining gamepilot::FUNCTION() (declared in HEADER)
# as the bytes of INPUT (the watch page or the hub's), so the daemon serves the
# page without reading files.
get_filename_component(name "${INPUT}" NAME)
file(READ "${INPUT}" hex HEX)
string(LENGTH "${hex}" hex_length)
math(EXPR size "${hex_length} / 2")
string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," bytes "${hex}")
file(WRITE "${OUTPUT}"
"// Generated from ${name} by cmake/embed_watch_page.cmake.\n"
"#include <string_view>\n\n"
"#include \"${HEADER}\"\n\n"
"namespace gamepilot {\n\n"
"namespace {\n"
"const unsigned char kPage[${size}] = {${bytes}};\n"
"}  // namespace\n\n"
"std::string_view ${FUNCTION}() {\n"
"  return {reinterpret_cast<const char*>(kPage), sizeof(kPage)};\n"
"}\n\n"
"}  // namespace gamepilot\n")
