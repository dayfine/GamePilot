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


//  ---- Blink recovery ----

//  recover_state_from_blinks waits on video, so RecoveryPoll below is its loop
//  body copied with the waits, the display, the logging and the keep-awake
//  nudges taken out and the watchers replaced by sample buffers. Everything
//  else it calls (update_provisional, build_blink_streams, the extraction, the
//  grid, the solver) is the fork's own code, linked in.

const int64_t CAPTURE_START_US = 1763900000000000;
const int64_t FRAME_US = 100000;    //  10 fps
const int64_t POLL_US = 1000000;    //  BlinkRecoveryConfig::poll_interval
//  Between the clean capture's provisional state (180 s) and its confirmation
//  (201 s): a dip on one of the second NPC's ticks without a blink.
const double MISREAD_SECONDS = 0.37 + 186 * 1.0197;

//  recover_state_from_blinks's loop, one pass per call (see above for what
//  is taken out). Returns the pass's outcome as text; "events"
//  is set once the streams are built and "done" when the loop would return.
struct RecoveryPoll{
    BlinkRecoveryConfig config;
    size_t give_up_after;
    size_t failed_solves = 0;
    std::vector<double> frozen_thresholds;
    std::vector<double> estimated_thresholds;
    std::vector<size_t> estimated_from;
    ProvisionalState provisional;
    std::vector<WallClock> newest_blink;
    WallClock deadline;
    WallClock start;

    RecoveryPoll(const BlinkRecoveryConfig& c, size_t watchers, WallClock now)
        : config(c)
        , give_up_after(c.max_failed_windows * c.window_events)
        , frozen_thresholds(watchers, -1)
        , estimated_thresholds(watchers, -1)
        , estimated_from(watchers, 0)
        , newest_blink(watchers, WallClock::min())
        , deadline(now + c.liveness_timeout)
        , start(now)
    {}

    //  trim_to_window, with EyeBlinkWatcher::discard_before on a buffer.
    static void trim(
        std::vector<std::vector<BlinkMatchSample>>& buffers,
        const std::vector<std::vector<BlinkEvent>>& streams,
        WallClock origin, size_t keep
    ){
        for (size_t c = 0; c < streams.size(); c++){
            if (streams[c].size() <= keep){
                continue;
            }
            double seconds = streams[c][streams[c].size() - keep].seconds - 1.0;
            WallClock keep_from = origin + std::chrono::duration_cast<WallDuration>(
                std::chrono::duration<double>(seconds)
            );
            auto first = std::lower_bound(buffers[c].begin(), buffers[c].end(), keep_from,
                [](const BlinkMatchSample& sample, WallClock cutoff){ return sample.timestamp < cutoff; });
            buffers[c].erase(buffers[c].begin(), first);
        }
    }

    bool thresholds_for(const std::vector<std::vector<BlinkMatchSample>>& matches, std::vector<double>& thresholds){
        for (size_t w = 0; w < matches.size(); w++){
            double threshold = frozen_thresholds[w];
            if (threshold <= 0){
                size_t counted = estimated_from[w];
                size_t held = matches[w].size();
                if (estimated_thresholds[w] <= 0
                    || held >= counted + counted / 4
                    || counted >= held + held / 4
                ){
                    estimated_thresholds[w] = auto_blink_threshold(matches[w]);
                    estimated_from[w] = matches[w].size();
                }
                threshold = estimated_thresholds[w];
            }
            if (!(threshold > 0)){
                return false;
            }
            thresholds.emplace_back(threshold);
        }
        return true;
    }

    std::string poll(std::vector<std::vector<BlinkMatchSample>>& buffers, WallClock now, long long& events_out, bool& done){
        if (failed_solves >= give_up_after){
            done = true;
            return "gave_up reason=no RNG state solved over " + std::to_string(give_up_after) + " blinks";
        }
        if (now > deadline){
            done = true;
            return "gave_up reason=no RNG state solved in "
                + std::to_string(config.liveness_timeout.count() / 60) + " minutes";
        }
        std::vector<std::vector<BlinkMatchSample>> matches;
        WallClock origin = WallClock::max();
        for (const std::vector<BlinkMatchSample>& buffer : buffers){
            matches.emplace_back(buffer);
            if (matches.back().empty()){
                return "no_samples";
            }
            origin = std::min(origin, matches.back()[0].timestamp);
        }
        std::vector<double> thresholds;
        if (!thresholds_for(matches, thresholds)){
            return "no_threshold";
        }
        std::vector<std::vector<BlinkEvent>> streams = build_blink_streams(matches, thresholds, origin);

        size_t events = 0;
        const std::vector<BlinkEvent>* longest = &streams[0];
        for (const std::vector<BlinkEvent>& stream : streams){
            events += stream.size();
            if (stream.size() > longest->size()){
                longest = &stream;
            }
        }
        events_out = (long long)events;
        if (!provisional.held){
            trim(buffers, streams, origin, config.window_events / streams.size());
        }
        bool fresh = false;
        for (size_t w = 0; w < streams.size(); w++){
            if (streams[w].empty()){
                continue;
            }
            WallClock newest = origin + std::chrono::duration_cast<WallDuration>(
                std::chrono::duration<double>(streams[w].back().seconds)
            );
            if (newest > newest_blink[w] + std::chrono::seconds(1)){
                fresh = true;
            }
            newest_blink[w] = std::max(newest_blink[w], newest);
        }
        if (!fresh){
            return "not_fresh";
        }
        if (longest->size() < 3){
            return "too_few_blinks";
        }
        TickFit fit = fit_tick_period(*longest);
        if (!(fit.period_seconds > 0)){
            return "no_tick_fit";
        }
        if (provisional.held && events < provisional.events + config.confirmation_events){
            return "confirming";
        }
        if (events < config.min_rolls_to_try){
            return "too_few_rolls";
        }

        std::vector<uint8_t> slots(streams.size());
        for (uint8_t c = 0; c < (uint8_t)streams.size(); c++){
            slots[c] = c;
        }
        BlinkSolveResult solved;
        std::vector<uint8_t> winning_slots;
        for (size_t attempt = 0; attempt < streams.size(); attempt++){
            std::vector<BlinkSample> samples;
            std::string failure;
            if (build_samples(streams, slots, fit.period_seconds, samples, failure)){
                BlinkSolveResult attempt_result = solve_state_from_samples(samples, nullptr);
                if (attempt_result.success){
                    solved = attempt_result;
                    winning_slots = slots;
                    break;
                }
            }
            std::rotate(slots.begin(), slots.begin() + 1, slots.end());
        }
        failed_solves = solved.success ? 0 : failed_solves + 1;
        if (solved.success && frozen_thresholds[0] <= 0){
            frozen_thresholds = thresholds;
        }
        const ProvisionalStep step = update_provisional(
            provisional, solved.success, solved.state, events, config.confirmation_events
        );
        switch (step){
        case ProvisionalStep::KEEP_COLLECTING:
            return "unsolved";
        case ProvisionalStep::PROVISIONAL:
        case ProvisionalStep::CHANGED:
            return std::string(step_text(step)) + " " + state_words(solved.state) + " " + std::to_string(events);
        case ProvisionalStep::DROPPED:
            return "dropped";
        case ProvisionalStep::CONFIRMED:
            break;
        }
        done = true;
        uint64_t anchor_advance = 0;
        double anchor_seconds = 0;
        size_t anchor_stream = 0;
        if (!last_blink_anchor(streams, winning_slots, fit.period_seconds, anchor_advance, anchor_seconds, anchor_stream)){
            return "gave_up reason=the RNG state was found but no blink could anchor the clock";
        }
        WallClock anchor_time = origin + std::chrono::duration_cast<WallDuration>(
            std::chrono::duration<double>(anchor_seconds)
        );
        char buffer[512];
        std::snprintf(buffer, sizeof(buffer), "confirmed %s %zu slots", state_words(solved.state).c_str(), events);
        std::string text = buffer;
        for (uint8_t slot : winning_slots){
            text += " " + std::to_string(slot);
        }
        std::snprintf(buffer, sizeof(buffer), " anchor %zu %" PRIu64 " %s %.17g %u thresholds",
            anchor_stream, anchor_advance, micros(anchor_time, start).c_str(), fit.period_seconds, config.npcs);
        text += buffer;
        for (double threshold : frozen_thresholds){
            std::snprintf(buffer, sizeof(buffer), " %.17g", threshold);
            text += buffer;
        }
        return text;
    }
};

//  One watcher's template match, in thousandths, every FRAME_US: resting at
//  0.850, every 97th frame a shallow 0.800 that is not a blink, and each blink
//  a 0.2 s dip to between 0.350 and 0.390 (a double blink dips twice, 0.35 s
//  apart). "extra" adds dips where the NPC did not blink: misreads.
std::vector<int> recovery_matches(
    const Xorshift128State& seed, uint8_t npcs, uint8_t slot, double period,
    double offset, double seconds, const std::vector<double>& extra
){
    std::vector<double> closed = extra;
    std::vector<BlinkTick> ticks = generate_blink_ticks(Xorshift128(seed), (size_t)(seconds / period), npcs, slot);
    for (size_t tick = 0; tick < ticks.size(); tick++){
        if (ticks[tick].blinked){
            closed.push_back(offset + tick * period);
            if (ticks[tick].type == BlinkType::Double){
                closed.push_back(offset + tick * period + 0.35);
            }
        }
    }
    std::sort(closed.begin(), closed.end());
    std::vector<int> milli;
    size_t frames = (size_t)(seconds * 1e6 / FRAME_US);
    for (size_t frame = 0; frame < frames; frame++){
        double t = (double)(frame * FRAME_US) / 1e6;
        int value = frame % 97 == 13u + slot ? 800 : 850;
        for (size_t c = 0; c < closed.size(); c++){
            if (t >= closed[c] && t - closed[c] < 0.2){
                value = 350 + 10 * (int)(c % 5);
            }
        }
        milli.push_back(value);
    }
    return milli;
}

//  "v*n": n frames of v in a row.
std::string runs_text(const std::vector<int>& milli){
    std::string text;
    size_t runs = 0;
    for (size_t c = 0; c < milli.size();){
        size_t end = c;
        while (end < milli.size() && milli[end] == milli[c]){
            end++;
        }
        text += " " + std::to_string(milli[c]) + "*" + std::to_string(end - c);
        runs++;
        c = end;
    }
    return std::to_string(runs) + text;
}

struct RecoveryCase{
    const char* name;
    Xorshift128State seed;
    uint8_t npcs;
    double seconds;
    std::vector<std::vector<double>> extra;     //  misread dips per watcher
    bool foreign_second;    //  the second watcher sees another seed's NPC
    bool flat;              //  no blinks at all
    int64_t liveness_seconds = 3600;
};

//  Polls the loop once a second over a capture that arrives in real time, as
//  the watchers would fill: "recover <npcs> <liveness> <start> <frame> <poll> <watchers>
//  <runs per watcher...>", then one line per pass that is not "no_samples" or
//  "not_fresh" and differs from the line before.
void recovery_line(FILE* out, const RecoveryCase& c){
    BlinkRecoveryConfig config;
    config.npcs = c.npcs;
    config.liveness_timeout = std::chrono::seconds(c.liveness_seconds);
    std::vector<std::vector<int>> captures;
    for (uint8_t slot = 0; slot < c.npcs; slot++){
        Xorshift128State seed = c.foreign_second && slot == 1 ? Xorshift128State(0xdeadbeef, 0xcafebabe, 0x8badf00d, 0x0badc0de) : c.seed;
        std::vector<double> extra = slot < c.extra.size() ? c.extra[slot] : std::vector<double>();
        std::vector<int> milli = c.flat
            ? std::vector<int>((size_t)(c.seconds * 1e6 / FRAME_US), 850)
            : recovery_matches(seed, c.npcs, slot, 1.0197, 0.3 + 0.07 * slot, c.seconds, extra);
        captures.push_back(milli);
    }
    std::fprintf(out, "recover %u %" PRId64 " %" PRId64 " %" PRId64 " %" PRId64 " %zu", c.npcs, c.liveness_seconds, CAPTURE_START_US, FRAME_US, POLL_US, captures.size());
    for (const std::vector<int>& milli : captures){
        std::fprintf(out, " %s", runs_text(milli).c_str());
    }
    std::fprintf(out, " : %s", c.name);

    WallClock start = at_us(CAPTURE_START_US);
    RecoveryPoll loop(config, captures.size(), start);
    std::vector<std::vector<BlinkMatchSample>> buffers(captures.size());
    std::vector<size_t> next(captures.size(), 0);
    std::string last;
    for (int64_t k = 1;; k++){
        int64_t now_us = CAPTURE_START_US + k * POLL_US;
        bool ended = true;
        for (size_t w = 0; w < captures.size(); w++){
            while (next[w] < captures[w].size() && CAPTURE_START_US + (int64_t)next[w] * FRAME_US <= now_us){
                BlinkMatchSample sample;
                sample.timestamp = at_us(CAPTURE_START_US + (int64_t)next[w] * FRAME_US);
                sample.match = captures[w][next[w]] / 1000.0;
                buffers[w].push_back(sample);
                next[w]++;
            }
            ended = ended && next[w] == captures[w].size();
        }
        long long events = -1;
        bool done = false;
        std::string outcome = loop.poll(buffers, at_us(now_us), events, done);
        std::string line = (events < 0 ? std::string("-") : std::to_string(events)) + " " + outcome;
        if (outcome != "no_samples" && outcome != "not_fresh" && line != last){
            std::fprintf(out, "\n  %" PRId64 " %s", k, line.c_str());
            last = line;
        }
        if (done){
            break;
        }
        if (ended){
            std::fprintf(out, "\n  %" PRId64 " capture_ended", k);
            break;
        }
    }
    std::fprintf(out, "\n");
}


void blink_recovery_lines(FILE* out){
    provisional_lines(out);
    const Xorshift128State seed{0x12345678, 0x9abcdef0, 0x0fedcba9, 0x87654321};
    const Xorshift128State seed3{0x6b2c0bc7, 0x3e5a4f1d, 0xa1d0e3b9, 0x55f0c2e4};
    recovery_line(out, {"clean", seed, 2, 400, {}, false, false});
    recovery_line(out, {"three", seed3, 3, 400, {}, false, false});
    recovery_line(out, {"misread", seed, 2, 500, {{}, {MISREAD_SECONDS}}, false, false});
    recovery_line(out, {"foreign", seed, 2, 1100, {}, true, false});
    recovery_line(out, {"flat", seed, 2, 120, {}, false, true, 60});
    recovery_line(out, {"short", seed, 2, 150, {}, false, false});
}

}

void advance_clock_golden(FILE* out){ advance_clock_lines(out); }
void rng_calibration_golden(FILE* out){ rng_calibration_lines(out); }
void blink_recovery_golden(FILE* out){ blink_recovery_lines(out); }
