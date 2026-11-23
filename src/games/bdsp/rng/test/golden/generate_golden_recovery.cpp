//  Golden vectors for the ports of the fork's BlinkRecovery, RngCalibration
//  and AdvanceClock (src/games/bdsp/rng), computed by its C++ (D6). Same line
//  format as generate_golden.cpp, whose main calls the *_golden functions at
//  the bottom.

#include <algorithm>
#include <cinttypes>
#include <cstdio>
#include <string>
#include <vector>
#include "Common/Cpp/Logging/AbstractLogger.h"
#include "Pokemon/Pokemon_BdspRng.h"
#include "PokemonBDSP/Inference/Rng/PokemonBDSP_BlinkExtraction.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_AdvanceClock.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkRecovery.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_RngCalibration.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.h"

using namespace PokemonAutomation;
using namespace PokemonAutomation::Pokemon;
using namespace PokemonAutomation::NintendoSwitch::PokemonBDSP;

namespace{

std::string state_words(const Xorshift128State& s){
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%08x %08x %08x %08x", s.s0, s.s1, s.s2, s.s3);
    return buffer;
}

WallClock at_us(int64_t us){
    return WallClock(std::chrono::microseconds(us));
}

int64_t us_of(WallClock time){
    return std::chrono::duration_cast<std::chrono::microseconds>(time.time_since_epoch()).count();
}

//  Times are printed as whole microseconds since "from": the clock's tick with
//  libc++, to which the C++ truncates every duration it adds to a time.
std::string micros(WallClock time, WallClock from){
    return std::to_string(us_of(time) - us_of(from));
}

std::string float17(double x){
    char buffer[32];
    std::snprintf(buffer, sizeof(buffer), "%.17g", x);
    return buffer;
}


//  ---- Advance clock ----

void advance_clock_lines(FILE* out){
    const int64_t ANCHOR_US = 100000000;
    struct Clock{ uint64_t anchor_advance; double tick; uint8_t npcs; };
    const std::vector<Clock> CLOCKS{
        {0, 1.017, 1}, {1000, 1.0197, 2}, {777, 1.0197, 3}, {5, 1.0, 0}, {41, 0.5, 2},
    };
    const std::vector<int64_t> OFFSETS_US{-200000000, -3000000, -1, 0, 1, 512345, 1017001, 2500000, 61234567, 3600000000};
    const std::vector<uint64_t> ADVANCES{0, 1, 2, 4, 5, 41, 776, 777, 778, 999, 1000, 1001, 1003, 5000};
    for (const Clock& c : CLOCKS){
        AdvanceClock clock;
        clock.anchor_time = at_us(ANCHOR_US);
        clock.anchor_advance = c.anchor_advance;
        clock.tick_seconds = c.tick;
        clock.npcs = c.npcs;
        const std::string head = std::to_string(ANCHOR_US) + " " + std::to_string(c.anchor_advance)
            + " " + float17(c.tick) + " " + std::to_string(c.npcs);
        for (int64_t offset : OFFSETS_US){
            std::fprintf(out, "advance_at %s %" PRId64 " : %" PRIu64 "\n", head.c_str(),
                ANCHOR_US + offset, clock.advance_at(at_us(ANCHOR_US + offset)));
        }
        for (uint64_t advance : ADVANCES){
            std::fprintf(out, "time_of_advance %s %" PRIu64 " : %s %s\n", head.c_str(), advance,
                micros(clock.time_of_advance(advance), at_us(0)).c_str(),
                micros(clock.middle_of_advance(advance), at_us(0)).c_str());
        }
    }
}


//  ---- Hit calibration ----

BdspStaticTemplate starter_template(){
    BdspStaticTemplate ret;
    ret.species = "starter";
    ret.level = 5;
    ret.ability_kind = 3;
    ret.gender_ratio = 31;
    return ret;
}

const char* gender_text(BdspGender gender){
    return gender == BdspGender::Male ? "M" : gender == BdspGender::Female ? "F" : "G";
}

//  An observation as "nature gender shiny hp atk def spa spd spe level":
//  "-" for anything not read.
std::string observed_text(const BdspObservedStarter& o, int nature){
    std::string text = nature < 0 ? "-" : std::to_string(nature);
    text += std::string(" ") + (o.gender_known ? gender_text(o.gender) : "-");
    text += std::string(" ") + (o.shiny_known ? (o.shiny ? "1" : "0") : "-");
    for (int16_t stat : {o.stats.hp, o.stats.attack, o.stats.defense, o.stats.spatk, o.stats.spdef, o.stats.speed}){
        text += " " + (stat < 0 ? std::string("-") : std::to_string(stat));
    }
    return text + " " + std::to_string(o.level);
}

std::string stats_text(const StatReads& s){
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%d %d %d %d %d %d", s.hp, s.attack, s.defense, s.spatk, s.spdef, s.speed);
    return buffer;
}

//  What reading the summary of the Pokemon at "advance" would show, with only
//  the fields in "read" taken ("n"ature, "g"ender, "s"hiny, "t"stats).
BdspObservedStarter observe(const BdspPokemonResult& p, BdspStarter starter, const std::string& read){
    BdspObservedStarter o;
    o.base_stats = starter_base_stats(starter);
    if (read.find('n') != std::string::npos){
        o.nature = bdsp_nature_to_checker_value(p.nature);
    }
    if (read.find('g') != std::string::npos){
        o.gender = p.gender;
        o.gender_known = true;
    }
    if (read.find('s') != std::string::npos){
        o.shiny = p.shiny != BdspShiny::None;
        o.shiny_known = true;
    }
    if (read.find('t') != std::string::npos){
        o.stats = bdsp_expected_stats(p, o.base_stats, o.level);
    }
    return o;
}

void rng_calibration_lines(FILE* out){
    for (uint8_t nature = 0; nature < 26; nature++){
        std::fprintf(out, "nature_adjustment %u :", nature);
        for (size_t stat = 0; stat < 6; stat++){
            NatureAdjustment a = bdsp_nature_adjustment(nature, stat);
            std::fprintf(out, " %c", a == NatureAdjustment::POSITIVE ? '+' : a == NatureAdjustment::NEGATIVE ? '-' : '=');
        }
        std::fprintf(out, "\n");
    }

    const Xorshift128State seed{0x12345678, 0x9abcdef0, 0x0fedcba9, 0x87654321};
    const BdspStaticTemplate tmpl = starter_template();
    BdspStaticSearcher searcher(seed, tmpl, 0);
    struct Starter{ BdspStarter starter; int index; };
    const std::vector<Starter> STARTERS{{BdspStarter::Turtwig, 0}, {BdspStarter::Chimchar, 1}, {BdspStarter::Piplup, 2}};
    for (const Starter& s : STARTERS){
        for (uint64_t advance : {0, 7, 300}){
            BdspPokemonResult p = searcher.generate(advance);
            for (uint8_t level : {5, 50, 100}){
                std::fprintf(out, "expected_stats %s %d %" PRIu64 " %u : %s\n", state_words(seed).c_str(),
                    s.index, advance, level, stats_text(bdsp_expected_stats(p, starter_base_stats(s.starter), level)).c_str());
            }
        }
    }

    //  identify_hit_advance around an intended advance, with the hit at
    //  "offset" from it and the summary read in part.
    struct Hit{ uint64_t intended; int64_t offset; uint64_t radius; const char* read; int starter; };
    const std::vector<Hit> HITS{
        {1000, 0, 20, "ngst", 0}, {1000, 3, 20, "ngst", 1}, {1000, -7, 20, "ngst", 2},
        {1000, 25, 20, "ngst", 0}, {1000, 2, 20, "n", 0}, {1000, -1, 20, "t", 2},
        {1000, 4, 20, "g", 1}, {10, -9, 20, "ngst", 0}, {50000, 11, 40, "ngt", 1},
        {1000, 0, 0, "ngst", 0}, {1000, 0, 20, "", 0},
    };
    for (const Hit& h : HITS){
        uint64_t hit = (uint64_t)((int64_t)h.intended + h.offset);
        BdspObservedStarter o = observe(searcher.generate(hit), STARTERS[h.starter].starter, h.read);
        int nature = std::string(h.read).find('n') != std::string::npos ? searcher.generate(hit).nature : -1;
        BdspHitIdentification r = identify_hit_advance(seed, tmpl, h.intended, h.radius, o);
        std::fprintf(out, "identify %s %" PRIu64 " %" PRIu64 " %d %s : %d %" PRIu64 " %" PRId64 " %zu reason=%s\n",
            state_words(seed).c_str(), h.intended, h.radius, h.starter, observed_text(o, nature).c_str(),
            r.success ? 1 : 0, r.advance, r.offset, r.candidates, r.failure_reason.c_str());
    }
    //  Stats one point off, and a shiny read where nothing near is shiny.
    BdspObservedStarter off_by_one = observe(searcher.generate(1000), BdspStarter::Turtwig, "ngst");
    off_by_one.stats.attack++;
    BdspObservedStarter shiny = observe(searcher.generate(1000), BdspStarter::Turtwig, "s");
    shiny.shiny = true;
    for (const BdspObservedStarter& o : {off_by_one, shiny}){
        int nature = o.nature == NatureCheckerValue::UnableToDetect ? -1 : searcher.generate(1000).nature;
        BdspHitIdentification r = identify_hit_advance(seed, tmpl, 1000, 20, o);
        std::fprintf(out, "identify %s 1000 20 0 %s : %d %" PRIu64 " %" PRId64 " %zu reason=%s\n",
            state_words(seed).c_str(), observed_text(o, nature).c_str(),
            r.success ? 1 : 0, r.advance, r.offset, r.candidates, r.failure_reason.c_str());
    }

    for (uint64_t distance : {0, 1, 2, 499, 500, 501, 4000}){
        Xorshift128 to(seed);
        to.advance(distance);
        for (uint64_t search_max : {0, 500}){
            uint64_t advances = 0;
            bool ok = advances_between(seed, to.state(), search_max, advances);
            std::fprintf(out, "advances_between %s %s %" PRIu64 " : %d %" PRIu64 "\n", state_words(seed).c_str(),
                state_words(to.state()).c_str(), search_max, ok ? 1 : 0, ok ? advances : 0);
        }
    }
}


//  ---- Provisional state ----

const char* step_text(ProvisionalStep step){
    switch (step){
    case ProvisionalStep::KEEP_COLLECTING: return "keep";
    case ProvisionalStep::PROVISIONAL: return "provisional";
    case ProvisionalStep::CHANGED: return "changed";
    case ProvisionalStep::DROPPED: return "dropped";
    case ProvisionalStep::CONFIRMED: return "confirmed";
    }
    return "?";
}

//  Solves as "<state letter><events>" ("A44": state A from 44 rolls) or "-"
//  for a failed one, fed to update_provisional in order.
void provisional_line(FILE* out, size_t confirmation_events, const std::vector<std::string>& solves){
    const std::vector<Xorshift128State> STATES{{1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12}};
    ProvisionalState provisional;
    std::fprintf(out, "provisional %zu %zu", confirmation_events, solves.size());
    for (const std::string& solve : solves){
        std::fprintf(out, " %s", solve.c_str());
    }
    std::fprintf(out, " :");
    for (const std::string& solve : solves){
        bool solved = solve != "-";
        Xorshift128State state = solved ? STATES[solve[0] - 'A'] : Xorshift128State();
        size_t events = solved ? std::stoul(solve.substr(1)) : 0;
        ProvisionalStep step = update_provisional(provisional, solved, state, events, confirmation_events);
        std::fprintf(out, " %s", step_text(step));
    }
    std::fprintf(out, " | %d %u %zu %zu\n", provisional.held ? 1 : 0, provisional.state.s0,
        provisional.events, provisional.failed_solves);
}

void provisional_lines(FILE* out){
    provisional_line(out, 6, {"-", "-", "A44", "A50"});
    provisional_line(out, 6, {"A44", "B50", "B56"});
    provisional_line(out, 6, {"A44", "-", "-", "-", "-", "-", "A60"});
    provisional_line(out, 6, {"A44", "-", "-", "-", "-", "-", "-", "-", "B70", "B76"});
    provisional_line(out, 6, {"A44", "-", "-", "B50", "-", "-", "-", "-", "-", "-"});
    provisional_line(out, 1, {"A44", "-", "-", "C45"});
    provisional_line(out, 0, {"A44", "-", "A45"});
}



void blink_recovery_lines(FILE* out){
    provisional_lines(out);
}

}

void advance_clock_golden(FILE* out){ advance_clock_lines(out); }
void rng_calibration_golden(FILE* out){ rng_calibration_lines(out); }
void blink_recovery_golden(FILE* out){ blink_recovery_lines(out); }
