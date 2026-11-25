//  Link stubs for generate_golden: the ported sources name a few app-wide
//  symbols (error reporting, file reading, the resource folder) whose real
//  definitions pull in the logger and the framework. Errors abort with a
//  message; RESOURCE_PATH is the folder generate_golden was given.

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include "Common/Cpp/Exceptions.h"

extern std::string RESOURCES;

namespace PokemonAutomation{

[[noreturn]] static void unreachable(const char* what, const std::string& detail){
    std::fprintf(stderr, "generate_golden: %s: %s\n", what, detail.c_str());
    std::abort();
}

void Exception::log(Logger&) const{ unreachable("Exception::log", ""); }
std::string Exception::message() const{ return ""; }
std::string Exception::to_str() const{ return name(); }

InternalProgramError::InternalProgramError(Logger*, const char* location, std::string message)
    : m_location(location)
    , m_message(std::move(message))
{
    unreachable(m_location, m_message);
}
std::string InternalProgramError::message() const{ return m_message; }

FileException::FileException(Logger*, const char* location, std::string message, std::string file)
    : m_location(location)
    , m_message(std::move(message))
    , m_file(std::move(file))
{
    unreachable(m_location, m_message + ": " + m_file);
}
std::string FileException::message() const{ return m_message; }

ParseException::ParseException(std::string message)
    : m_message(std::move(message))
{
    unreachable("ParseException", m_message);
}

std::string file_to_string(const std::string& filename){
    std::ifstream file(filename, std::ios::binary);
    if (!file){
        unreachable("file_to_string", filename);
    }
    std::ostringstream text;
    text << file.rdbuf();
    return text.str();
}
void string_to_file(const std::string& filename, const std::string&){ unreachable("string_to_file", filename); }

const std::string& RESOURCE_PATH(){ return RESOURCES; }

}
