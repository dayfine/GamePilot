//  Link stubs for generate_golden: the ported sources name a few app-wide
//  symbols (error reporting, cancellation) whose real definitions pull in the
//  logger and the threading code. The generator never reaches them on a correct
//  run, so each stub aborts with a message instead.

#include <cstdio>
#include <cstdlib>
#include "Common/Cpp/CancellableScope.h"
#include "Common/Cpp/Exceptions.h"

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

void Cancellable::throw_if_cancelled() const{ unreachable("Cancellable::throw_if_cancelled", ""); }

}
