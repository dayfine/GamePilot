//  Golden vectors for src/games/bdsp/rng, computed by the fork's C++ (D6: the
//  C++ is the oracle). Each output line holds its inputs and the C++'s outputs,
//  so the OCaml tests read the inputs from the line and check they give the same
//  text. regen_golden.sh builds and runs this; see it for the command.

#include <cinttypes>
#include <cmath>
#include <chrono>
#include <cstdio>
#include <limits>
#include <string>
#include <vector>
#include "Pokemon/Pokemon_BdspRng.h"
#include "Pokemon/Pokemon_Gf2Matrix.h"
#include "PokemonBDSP/Inference/Rng/PokemonBDSP_BlinkExtraction.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateReidentifier.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_StateSolver.h"

using namespace PokemonAutomation::Pokemon;
using namespace PokemonAutomation::NintendoSwitch::PokemonBDSP;

namespace{

const std::vector<Xorshift128State> SEEDS{
    {0x00000001, 0x00000000, 0x00000000, 0x00000000},
    {0x12345678, 0x9abcdef0, 0x0fedcba9, 0x87654321},
    {0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff},
    {0xdeadbeef, 0xcafebabe, 0x8badf00d, 0x0badc0de},
    {0x6b2c0bc7, 0x3e5a4f1d, 0xa1d0e3b9, 0x55f0c2e4},
};

std::string state_text(const Xorshift128State& s){
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%08x %08x %08x %08x", s.s0, s.s1, s.s2, s.s3);
    return buffer;
}

void xorshift128_lines(FILE* out){
    //  Outputs: 16 lines of 16 per seed, each line starting from the state the
    //  previous one ended in.
    for (const Xorshift128State& seed : SEEDS){
        Xorshift128 rng(seed);
        for (int line = 0; line < 16; line++){
            std::fprintf(out, "next %s 16 :", state_text(rng.state()).c_str());
            for (int c = 0; c < 16; c++){
                std::fprintf(out, " %08x", rng.next());
            }
            std::fprintf(out, "\n");
        }
    }
    const std::vector<uint64_t> COUNTS{
        0, 1, 7, 511, 512, 513, 1000, 65536, 1000000007,
        (uint64_t)1 << 40, ((uint64_t)1 << 62) - 1,
    };
    for (const Xorshift128State& seed : SEEDS){
        Xorshift128 stepped(seed);
        for (int c = 0; c < 100000; c++){
            stepped.next();
        }
        std::fprintf(out, "steps %s 100000 : %s\n",
            state_text(seed).c_str(), state_text(stepped.state()).c_str());
        Xorshift128 back(seed);
        for (int c = 0; c < 1000; c++){
            back.prev();
        }
        std::fprintf(out, "prevs %s 1000 : %s\n",
            state_text(seed).c_str(), state_text(back.state()).c_str());
        for (uint64_t count : COUNTS){
            Xorshift128 forward(seed);
            forward.advance(count);
            std::fprintf(out, "advance %s %" PRIu64 " : %s\n",
                state_text(seed).c_str(), count, state_text(forward.state()).c_str());
            Xorshift128 backward(seed);
            backward.rewind(count);
            std::fprintf(out, "rewind %s %" PRIu64 " : %s\n",
                state_text(seed).c_str(), count, state_text(backward.state()).c_str());
        }
        uint64_t seed0 = 0;
        uint64_t seed1 = 0;
        xorshift128_state_to_seed_pair(seed, seed0, seed1);
        std::fprintf(out, "seed_pair %s : %016" PRIx64 " %016" PRIx64 " %s\n",
            state_text(seed).c_str(), seed0, seed1, seed.to_string().c_str());
    }
    const std::vector<uint32_t> RAWS{
        0, 1, 2, 0x7fffffff, 0x80000000, 0x80000001, 0xfffffffe, 0xffffffff, 0x12345678,
    };
    for (uint32_t raw : RAWS){
        std::fprintf(out, "gen %08x : %08x\n", raw, bdsp_gen_transform(raw));
    }
}

std::vector<uint32_t> sample_rolls(){
    std::vector<uint32_t> rolls{0, 1, 0x7fffff, 0x800000, 0x3fffff, 0x400000, 0xffffffff, 0xff800000};
    Xorshift128 rng(SEEDS[1]);
    for (int c = 0; c < 40; c++){
        rolls.push_back(rng.next());
    }
    return rolls;
}

void blink_model_lines(FILE* out){
    const std::vector<uint32_t> rolls = sample_rolls();
    for (uint32_t roll : rolls){
        std::fprintf(out, "range_float %08x 3 12 : %.17g\n", roll, bdsp_range_float(roll, 3.0, 12.0));
        std::fprintf(out, "range_float %08x -1 0.5 : %.17g\n", roll, bdsp_range_float(roll, -1.0, 0.5));
        std::fprintf(out, "interval %08x : %.17g\n", roll, bdsp_pokemon_blink_interval(roll));
    }
    std::vector<double> intervals{
        3.285, 12.285, 3.2849999, 12.2850001, 3.0, 13.0, 7.785, 4.0, 10.123456789,
        std::numeric_limits<double>::quiet_NaN(),
    };
    for (uint32_t roll : rolls){
        double interval = bdsp_pokemon_blink_interval(roll);
        intervals.push_back(interval);
        intervals.push_back(interval + 0.05);
        intervals.push_back(interval - 0.1);
    }
    for (double interval : intervals){
        uint32_t fraction = 0;
        bool ok = bdsp_pokemon_blink_fraction(interval, fraction);
        std::fprintf(out, "fraction %.17g : %d %u\n", interval, ok ? 1 : 0, ok ? fraction : 0);
        uint32_t bucket = 0;
        double margin = 0;
        ok = bdsp_pokemon_blink_bucket_with_margin(interval, bucket, margin);
        std::fprintf(out, "bucket %.17g : %d %u %.17g\n", interval, ok ? 1 : 0,
            ok ? bucket : 0, ok ? margin : 0.0);
    }
    struct TickCase{ size_t ticks; uint8_t npcs; uint8_t slot; };
    const std::vector<TickCase> TICK_CASES{{200, 1, 0}, {200, 2, 0}, {200, 2, 1}, {120, 3, 2}};
    for (const Xorshift128State& seed : SEEDS){
        for (const TickCase& tick_case : TICK_CASES){
            std::fprintf(out, "ticks %s %zu %u %u : ", state_text(seed).c_str(),
                tick_case.ticks, tick_case.npcs, tick_case.slot);
            for (const BlinkTick& tick : generate_blink_ticks(
                Xorshift128(seed), tick_case.ticks, tick_case.npcs, tick_case.slot
            )){
                std::fputc(!tick.blinked ? '.' : tick.type == BlinkType::Single ? 'S' : 'D', out);
            }
            std::fprintf(out, "\n");
        }
    }
}

BdspStaticTemplate template_named(const std::string& name){
    BdspStaticTemplate ret;
    ret.species = name;
    if (name == "starter"){
        //  PokemonBDSP_RngTargets.cpp starter_template()
        ret.level = 5;
        ret.guaranteed_ivs = 0;
        ret.ability_kind = 3;
        ret.gender_ratio = 31;
    }else if (name == "legendary"){
        //  PokemonBDSP_RngTargets.cpp legendary_template()
        ret.level = 50;
        ret.guaranteed_ivs = 3;
        ret.ability_kind = 3;
        ret.gender_ratio = 255;
    }else if (name == "locked_hidden_female"){
        ret.level = 1;
        ret.guaranteed_ivs = 1;
        ret.ability_kind = 2;
        ret.gender_ratio = 254;
        ret.shiny_locked = true;
    }
    return ret;
}

std::string result_text(const BdspPokemonResult& r){
    char buffer[160];
    std::snprintf(buffer, sizeof(buffer), "%08x %08x %u %s %u %u %u %u %u %u",
        r.ec, r.pid, (unsigned)r.shiny, r.ivs.to_string().c_str(), r.ability,
        (unsigned)r.gender, r.nature, r.level, r.height, r.weight);
    return buffer;
}

void bdsp_rng_lines(FILE* out){
    const std::vector<std::pair<uint32_t, uint16_t>> SHINY_CASES{
        {0x00000000, 0}, {0x0001000f, 0}, {0x00010010, 0}, {0xabcd1234, 0xb9f9},
        {0xabcd1234, 0xb9f0}, {0xabcd1234, 0xb9e9}, {0xffffffff, 0}, {0x12345678, 0x444c},
    };
    for (const auto& c : SHINY_CASES){
        std::fprintf(out, "shiny %08x %u : %u %d\n", c.first, c.second,
            (unsigned)bdsp_get_shiny(c.first, c.second), bdsp_is_shiny(c.first, c.second) ? 1 : 0);
    }
    for (uint8_t nature = 0; nature <= 25; nature++){
        std::fprintf(out, "nature %u : %s\n", nature, bdsp_nature_name(nature));
    }
    const std::vector<std::string> TEMPLATES{"starter", "legendary", "locked_hidden_female"};
    const std::vector<std::pair<uint16_t, uint8_t>> TRAINERS{{0, 0xff}, {12345, 0xff}, {0, 3}};
    for (const Xorshift128State& seed : SEEDS){
        Xorshift128 rng(seed);
        for (int advance = 0; advance < 6; advance++, rng.next()){
            for (const std::string& name : TEMPLATES){
                for (const auto& trainer : TRAINERS){
                    std::fprintf(out, "generate %s %s %u %u : %s\n",
                        state_text(rng.state()).c_str(), name.c_str(), trainer.first, trainer.second,
                        result_text(bdsp_generate_static(rng, template_named(name), trainer.first, trainer.second)).c_str());
                }
            }
        }
    }
    const std::vector<uint64_t> AT{0, 1, 600, 3500, 100000};
    for (const Xorshift128State& seed : SEEDS){
        BdspStaticSearcher searcher(seed, template_named("starter"), 0);
        for (uint64_t advances : AT){
            std::fprintf(out, "searcher_generate %s starter 0 %" PRIu64 " : %s\n",
                state_text(seed).c_str(), advances, result_text(searcher.generate(advances)).c_str());
        }
        //  The starter's search: every shiny in the range (PokemonBDSP_TargetSelection.cpp)
        std::vector<BdspRngHit> hits = searcher.scan(1000, 60000,
            [](const BdspPokemonResult& r){ return r.shiny != BdspShiny::None; });
        std::fprintf(out, "scan_shiny %s starter 0 1000 60000 : %zu\n", state_text(seed).c_str(), hits.size());
        for (const BdspRngHit& hit : hits){
            std::fprintf(out, "  hit %" PRIu64 " %s %s\n", hit.advances,
                state_text(hit.state).c_str(), result_text(hit.result).c_str());
        }
        //  PIDs that were shiny for the TSV and had a bit flipped to stop it
        for (const std::string& name : {"starter", "locked_hidden_female"}){
            BdspStaticSearcher flipped_searcher(seed, template_named(name), 0);
            hits = flipped_searcher.scan(0, 60000,
                [](const BdspPokemonResult& r){ return bdsp_is_shiny(r.pid ^ 0x10000000, 0); });
            std::fprintf(out, "scan_unshinied %s %s 0 0 60000 : %zu\n",
                state_text(seed).c_str(), name.c_str(), hits.size());
            for (const BdspRngHit& hit : hits){
                std::fprintf(out, "  hit %" PRIu64 " %s %s\n", hit.advances,
                    state_text(hit.state).c_str(), result_text(hit.result).c_str());
            }
        }
        hits = searcher.scan(0, 2000,
            [](const BdspPokemonResult& r){ return r.nature == 3 && r.ivs.attack == 31; });
        std::fprintf(out, "scan_adamant_31atk %s starter 0 0 2000 : %zu\n", state_text(seed).c_str(), hits.size());
        for (const BdspRngHit& hit : hits){
            std::fprintf(out, "  hit %" PRIu64 " %s %s\n", hit.advances,
                state_text(hit.state).c_str(), result_text(hit.result).c_str());
        }
    }
}

Gf2Vec128 random_vector(Xorshift128& rng){
    uint64_t high = (uint64_t)rng.next() << 32;
    high |= rng.next();
    uint64_t low = (uint64_t)rng.next() << 32;
    low |= rng.next();
    return Gf2Vec128(high, low);
}

std::string vector_text(const Gf2Vec128& v){
    char buffer[40];
    std::snprintf(buffer, sizeof(buffer), "%016" PRIx64 "%016" PRIx64, v.high, v.low);
    return buffer;
}

void gf2_solve_line(FILE* out, const Xorshift128State& seed, size_t height, const Gf2Vec128& mask, bool flip_last){
    //  Rows drawn from the generator after a secret solution, masked to leave
    //  some columns free; constants are the rows times the secret, with the
    //  last flipped when asked (which contradicts a full-rank system).
    Xorshift128 rng(seed);
    Gf2Vec128 secret = random_vector(rng);
    std::vector<Gf2Vec128> rows;
    std::vector<bool> constants;
    for (size_t c = 0; c < height; c++){
        Gf2Vec128 row = random_vector(rng);
        row.high &= mask.high;
        row.low &= mask.low;
        rows.push_back(row);
        constants.push_back(row.dot(secret) != (flip_last && c + 1 == height));
    }
    Gf2SolveResult solved = gf2_solve_128(rows, constants);
    std::fprintf(out, "gf2_solve %s %zu %s %d : %d %s %zu", state_text(seed).c_str(), height,
        vector_text(mask).c_str(), flip_last ? 1 : 0, solved.consistent ? 1 : 0,
        vector_text(solved.solution).c_str(), solved.null_space_dimension);
    for (const Gf2Vec128& basis : solved.null_space_basis){
        std::fprintf(out, " %s", vector_text(basis).c_str());
    }
    std::fprintf(out, "\n");
}

std::string npc_result_text(const BlinkSolveResult& r){
    char buffer[160];
    std::snprintf(buffer, sizeof(buffer), "%d %s %" PRIu64 " %zu %zu reason=",
        r.success ? 1 : 0, state_text(r.state).c_str(), r.advances_to_last_blink,
        r.equations_used, r.null_space_dimension);
    return buffer + r.failure_reason;
}

//  "all": every blink's type is known, "none": no type, "even": types on even
//  sample indices only. "flip" inverts one sample's blink; "repeat" lists every
//  sample that many times, which repeats equations without adding any.
void solve_npc_line(
    FILE* out, const Xorshift128State& seed, size_t count, size_t stride,
    const std::string& types, long flip, size_t repeat = 1
){
    Xorshift128 rng(seed);
    std::vector<BlinkSample> samples;
    for (size_t c = 0; c < count; c++){
        if (c != 0){
            for (size_t skip = 1; skip < stride; skip++){
                rng.next();
            }
        }
        uint32_t roll = rng.next();
        BlinkSample sample;
        sample.advance = c * stride;
        sample.blinked = npc_blinks(roll) != ((long)c == flip);
        if (sample.blinked && (types == "all" || (types == "even" && c % 2 == 0))){
            sample.type = NPC_blink_type(roll);
        }
        for (size_t copy = 0; copy < repeat; copy++){
            samples.push_back(sample);
        }
    }
    std::fprintf(out, "solve_npc %s %zu %zu %s %ld %zu : %s\n", state_text(seed).c_str(),
        count, stride, types.c_str(), flip, repeat, npc_result_text(solve_state_from_samples(samples)).c_str());
}

void solve_pokemon_line(FILE* out, const PokemonBlinkSolveRequest& request){
    PokemonBlinkSolveResult r = solve_state_from_pokemon_blinks(request);
    std::fprintf(out, "solve_pokemon %.17g %zu %zu", request.tolerance_seconds,
        request.max_attempts, request.intervals.size());
    for (double interval : request.intervals){
        std::fprintf(out, " %.17g", interval);
    }
    std::fprintf(out, " : %d %s %" PRIu64 " %zu %zu %zu %zu %zu %.17g %zu %.17g reason=%s\n",
        r.success ? 1 : 0, state_text(r.state).c_str(), r.advances_to_last_interval,
        r.observations_used, r.observations_discarded, r.equations_used,
        r.null_space_dimension, r.attempts, r.weakest_margin_used,
        r.mistimed_intervals, r.worst_residual_seconds, r.failure_reason.c_str());
}

//  Intervals timed from "seed": each off by up to "jitter" seconds, plus
//  "outlier_seconds" on every index in "outliers".
std::vector<double> timed_intervals(
    const Xorshift128State& seed, size_t count, double jitter,
    const std::vector<size_t>& outliers, double outlier_seconds
){
    Xorshift128 rng(seed);
    Xorshift128 noise(Xorshift128State(0x0badf00d, 0x12345678, 0x9e3779b9, 0x7f4a7c15));
    std::vector<double> intervals;
    for (size_t c = 0; c < count; c++){
        double interval = bdsp_pokemon_blink_interval(rng.next());
        double unit = (double)noise.next() / 4294967296.0;
        interval += (2 * unit - 1) * jitter;
        for (size_t index : outliers){
            if (index == c){
                interval += outlier_seconds;
            }
        }
        intervals.push_back(interval);
    }
    return intervals;
}

void state_solver_lines(FILE* out){
    const Gf2Vec128 ALL(~(uint64_t)0, ~(uint64_t)0);
    const Gf2Vec128 FIVE_FREE(0xfffffffffffffffeull & 0xfeffffffffffffffull & 0xffffffefffffffffull,
                              0xfffffffffffffff7ull & 0xff7fffffffffffffull);
    gf2_solve_line(out, SEEDS[1], 200, ALL, false);
    gf2_solve_line(out, SEEDS[1], 200, ALL, true);
    gf2_solve_line(out, SEEDS[3], 200, FIVE_FREE, false);
    gf2_solve_line(out, SEEDS[3], 200, FIVE_FREE, true);
    gf2_solve_line(out, SEEDS[4], 100, ALL, false);
    gf2_solve_line(out, SEEDS[0], 128, ALL, false);
    gf2_solve_line(out, SEEDS[2], 3, ALL, false);
    gf2_solve_line(out, SEEDS[2], 0, ALL, false);

    for (const Xorshift128State& seed : SEEDS){
        for (size_t count : {100, 300, 400, 600}){
            for (size_t stride : {1, 3}){
                for (const char* types : {"all", "none", "even"}){
                    solve_npc_line(out, seed, count, stride, types, -1);
                }
            }
        }
    }
    //  Around the fewest blinks that can work, where a solution may be loose.
    for (size_t count = 250; count <= 450; count += 10){
        solve_npc_line(out, SEEDS[1], count, 1, "none", -1);
    }
    //  A blink invented or missed, early and late.
    for (long flip : {0, 7, 150, 399}){
        solve_npc_line(out, SEEDS[3], 400, 1, "all", flip);
        solve_npc_line(out, SEEDS[4], 400, 2, "even", flip);
    }
    //  Repeated samples: too many unknown bits, or a loose solution that the
    //  repeats themselves then contradict.
    for (size_t count : {200, 330, 360}){
        solve_npc_line(out, SEEDS[1], count, 1, "all", -1, 2);
        solve_npc_line(out, SEEDS[2], count, 1, "none", -1, 2);
    }

    for (double tolerance : {0.0, 0.02, 0.05, 0.1, 0.2, 0.25, 0.3}){
        std::fprintf(out, "recommended %.17g : %zu\n", tolerance, recommended_pokemon_blink_count(tolerance));
    }

    const size_t COUNT = recommended_pokemon_blink_count(0.1);
    for (const Xorshift128State& seed : SEEDS){
        PokemonBlinkSolveRequest request;
        request.intervals = timed_intervals(seed, COUNT, 0, {}, 0);
        solve_pokemon_line(out, request);
        request.intervals = timed_intervals(seed, COUNT, 0.04, {}, 0);
        solve_pokemon_line(out, request);
        //  Outliers that land in the confident set force leave-one-out trials.
        request.intervals = timed_intervals(seed, COUNT, 0.04, {3}, 1.3);
        solve_pokemon_line(out, request);
        request.intervals = timed_intervals(seed, COUNT, 0.04, {3, 17, 40}, 0.7);
        solve_pokemon_line(out, request);
        request.max_attempts = 1;
        solve_pokemon_line(out, request);
        request.max_attempts = 64;
        //  The timing is worse than the tolerance claims.
        request.intervals = timed_intervals(seed, COUNT, 0.25, {}, 0);
        request.tolerance_seconds = 0.05;
        solve_pokemon_line(out, request);
        request.tolerance_seconds = 0.1;
        request.intervals = timed_intervals(seed, 20, 0, {}, 0);
        solve_pokemon_line(out, request);
    }
    PokemonBlinkSolveRequest request;
    request.intervals = timed_intervals(SEEDS[1], 40, 0.02, {}, 0);
    request.intervals[5] = 20.0;
    request.intervals[6] = -1.0;
    request.intervals[7] = std::numeric_limits<double>::quiet_NaN();
    solve_pokemon_line(out, request);
    request.intervals.resize(36);
    solve_pokemon_line(out, request);
    request.tolerance_seconds = 0;
    solve_pokemon_line(out, request);
    request.tolerance_seconds = 0.1;
    request.intervals.clear();
    solve_pokemon_line(out, request);
}

using PokemonAutomation::WallClock;

//  Capture timestamps are whole microseconds near a real epoch time; the OCaml
//  reads them as seconds (us / 1e6), which is what the C++ computes from them.
const int64_t CAPTURE_START_US = 1763900000000000;
const int64_t FRAME_US = 66667;     //  15 fps
const size_t CAPTURE_FRAMES = 3000; //  200 s, past the 180 s auto threshold

std::vector<BlinkMatchSample> match_samples(int64_t start_us, int64_t step_us, const std::vector<int>& milli){
    std::vector<BlinkMatchSample> samples;
    for (size_t c = 0; c < milli.size(); c++){
        BlinkMatchSample sample;
        sample.timestamp = WallClock(std::chrono::microseconds(start_us + (int64_t)c * step_us));
        sample.match = milli[c] / 1000.0;
        samples.push_back(sample);
    }
    return samples;
}

//  One watcher's template match, in thousandths, for the NPC at "slot" of
//  "npcs" ticking every "period" seconds from "seed": resting near 0.85, each
//  blink a 0.2 s dip to 0.35 (a double blink dips twice, 0.35 s apart), and
//  now and then a shallow dip that is not a blink.
std::vector<int> synthetic_matches(
    const Xorshift128State& seed, uint8_t npcs, uint8_t slot, double period, double offset
){
    size_t ticks = (size_t)(CAPTURE_FRAMES * FRAME_US / 1e6 / period);
    std::vector<double> closed;
    std::vector<BlinkTick> blinks = generate_blink_ticks(Xorshift128(seed), ticks, npcs, slot);
    for (size_t tick = 0; tick < blinks.size(); tick++){
        if (blinks[tick].blinked){
            double at = offset + tick * period;
            closed.push_back(at);
            if (blinks[tick].type == BlinkType::Double){
                closed.push_back(at + 0.35);
            }
        }
    }
    Xorshift128 noise(Xorshift128State(0x31415926, 0x53589793, 0x23846264, 0x33832795 + slot));
    std::vector<int> milli;
    for (size_t frame = 0; frame < CAPTURE_FRAMES; frame++){
        double t = frame * FRAME_US / 1e6;
        int jitter = (int)(noise.next() % 17) - 8;
        int value = 850 + jitter;
        if (noise.next() % 211 == 0){
            value = 800 + jitter;
        }
        for (double at : closed){
            if (t >= at && t - at < 0.2){
                value = 350 + jitter;
            }
        }
        milli.push_back(value);
    }
    return milli;
}

std::string events_text(const std::vector<BlinkEvent>& events){
    std::string text = std::to_string(events.size());
    char buffer[40];
    for (const BlinkEvent& event : events){
        std::snprintf(buffer, sizeof(buffer), " %.17g%c", event.seconds,
            event.type == BlinkType::Single ? 'S' : 'D');
        text += buffer;
    }
    return text;
}

std::string fit_text(const TickFit& fit){
    char buffer[80];
    std::snprintf(buffer, sizeof(buffer), "%.17g %.17g %.17g", fit.period_seconds, fit.rms_ticks, fit.worst_ticks);
    return buffer;
}

void blinks_lines(FILE* out, const std::vector<Blink>& blinks){
    for (const Blink& blink : blinks){
        std::fprintf(out, "\n  blink %.17g %.17g %zu", blink.seconds, blink.depth, blink.frames);
    }
}

void matches_inputs(FILE* out, int64_t start_us, int64_t step_us, const std::vector<int>& milli){
    std::fprintf(out, " %" PRId64 " %" PRId64 " %zu", start_us, step_us, milli.size());
    for (int value : milli){
        std::fprintf(out, " %d", value);
    }
}

//  The whole extraction of one watcher: threshold, blinks, events, period.
std::vector<BlinkEvent> extract_stream_line(FILE* out, const std::vector<int>& milli, TickFit& fit){
    std::vector<BlinkMatchSample> samples = match_samples(CAPTURE_START_US, FRAME_US, milli);
    double threshold = auto_blink_threshold(samples);
    std::vector<Blink> blinks = extract_blinks(samples, threshold);
    std::vector<BlinkEvent> events = group_blinks(blinks);
    fit = fit_tick_period(events);
    std::fprintf(out, "extract_stream");
    matches_inputs(out, CAPTURE_START_US, FRAME_US, milli);
    std::fprintf(out, " : threshold %.17g", threshold);
    blinks_lines(out, blinks);
    std::fprintf(out, "\n  events %s\n  fit %s\n", events_text(events).c_str(), fit_text(fit).c_str());
    return events;
}

std::string streams_inputs(const std::vector<std::vector<BlinkEvent>>& streams, const std::vector<uint8_t>& slots){
    //  The slots, then each stream's events.
    std::string text = std::to_string(slots.size());
    for (uint8_t slot : slots){
        text += " " + std::to_string(slot);
    }
    text += " " + std::to_string(streams.size());
    for (const std::vector<BlinkEvent>& stream : streams){
        text += " " + events_text(stream);
    }
    return text;
}

void build_samples_line(FILE* out, const std::vector<std::vector<BlinkEvent>>& streams, const std::vector<uint8_t>& slots, double period){
    std::vector<BlinkSample> samples;
    std::string reason;
    bool ok = build_samples(streams, slots, period, samples, reason);
    std::fprintf(out, "build_samples %.17g %s : ", period, streams_inputs(streams, slots).c_str());
    if (!ok){
        std::fprintf(out, "fail reason=%s\n", reason.c_str());
        return;
    }
    std::fprintf(out, "ok %zu", samples.size());
    for (const BlinkSample& sample : samples){
        if (sample.blinked){
            std::fprintf(out, " %" PRIu64 "%c", sample.advance,
                !sample.type ? '?' : *sample.type == BlinkType::Single ? 'S' : 'D');
        }
    }
    std::fprintf(out, "\n  solve %s\n", npc_result_text(solve_state_from_samples(samples)).c_str());
}

void anchor_line(FILE* out, const std::vector<std::vector<BlinkEvent>>& streams, const std::vector<uint8_t>& slots, double period){
    uint64_t advance = 0;
    double seconds = 0;
    size_t stream_index = 0;
    bool ok = last_blink_anchor(streams, slots, period, advance, seconds, stream_index);
    std::fprintf(out, "anchor %.17g %s : ", period, streams_inputs(streams, slots).c_str());
    if (ok){
        std::fprintf(out, "1 %" PRIu64 " %.17g %zu\n", advance, seconds, stream_index);
    }else{
        std::fprintf(out, "0\n");
    }
}

BlinkEvent event_at(double seconds, BlinkType type = BlinkType::Single){
    BlinkEvent event;
    event.seconds = seconds;
    event.type = type;
    return event;
}

void blink_extraction_lines(FILE* out){
    struct Capture{ size_t seed; uint8_t npcs; };
    for (const Capture& capture : {Capture{1, 2}, Capture{4, 3}}){
        std::vector<std::vector<BlinkEvent>> streams;
        std::vector<uint8_t> slots;
        double period = 0;
        for (uint8_t slot = 0; slot < capture.npcs; slot++){
            std::vector<int> milli = synthetic_matches(SEEDS[capture.seed], capture.npcs, slot, 1.0197, 0.3 + 0.07 * slot);
            TickFit fit;
            streams.push_back(extract_stream_line(out, milli, fit));
            slots.push_back(slot);
            if (slot == 0){
                period = fit.period_seconds;
            }
        }
        build_samples_line(out, streams, slots, period);
        anchor_line(out, streams, slots, period);
        //  The nominal tick instead of the fitted one.
        build_samples_line(out, streams, slots, 1.017);
    }

    //  Short captures: thresholds that cannot be estimated, and extraction at
    //  a given threshold and origin.
    std::vector<int> dips;
    for (size_t c = 0; c < 40; c++){
        dips.push_back(c % 9 == 4 ? 300 : c % 9 == 5 ? 600 : 840 + (int)(c % 3));
    }
    struct Short{ std::vector<int> milli; int64_t step_us; double threshold; int64_t origin_us; };
    const std::vector<Short> SHORTS{
        {dips, FRAME_US, 0.3, 0},
        {dips, FRAME_US, 0.5, CAPTURE_START_US - 2000000},
        {dips, FRAME_US, 0.0, 0},
        {dips, 5000000, 0.3, 0},
        {{850}, FRAME_US, 0.3, 0},
        {{}, FRAME_US, 0.3, 0},
        {{0, 0, 0, 0}, FRAME_US, 0.3, 0},
        {std::vector<int>(3000, 850), FRAME_US, 0.3, 0},
    };
    for (const Short& item : SHORTS){
        std::vector<BlinkMatchSample> samples = match_samples(CAPTURE_START_US, item.step_us, item.milli);
        WallClock origin = item.origin_us == 0
            ? WallClock::min()
            : WallClock(std::chrono::microseconds(item.origin_us));
        std::fprintf(out, "extract_short %.17g %" PRId64, item.threshold, item.origin_us);
        matches_inputs(out, CAPTURE_START_US, item.step_us, item.milli);
        std::fprintf(out, " : threshold %.17g", auto_blink_threshold(samples));
        blinks_lines(out, extract_blinks(samples, item.threshold, origin));
        std::fprintf(out, "\n");
    }

    const std::vector<std::vector<double>> GAPS{
        {}, {1.0}, {1.0, 1.3, 1.9, 2.2}, {1.0, 1.55, 1.6, 3.0, 3.54}, {0.1, 0.2, 0.3},
    };
    for (const std::vector<double>& seconds : GAPS){
        std::vector<Blink> blinks;
        for (double at : seconds){
            Blink blink;
            blink.seconds = at;
            blinks.push_back(blink);
        }
        for (double window : {0.55, 0.25}){
            std::fprintf(out, "group %.17g %zu", window, seconds.size());
            for (double at : seconds){
                std::fprintf(out, " %.17g", at);
            }
            std::fprintf(out, " : %s\n", events_text(group_blinks(blinks, window)).c_str());
        }
    }

    const std::vector<std::vector<double>> TIMES{
        {}, {0.0, 1.0}, {0.0, 1.0197, 3.0591, 8.1576},
        {10.0, 11.017, 15.085, 21.187, 22.204, 40.5},
        {0.0, 0.5, 1.0, 1.5},
    };
    for (const std::vector<double>& times : TIMES){
        std::vector<BlinkEvent> events;
        for (double at : times){
            events.push_back(event_at(at));
        }
        for (const std::pair<double, double>& range : {std::pair<double, double>{1.0, 1.04}, {0.9, 1.1}}){
            std::fprintf(out, "fit %.17g %.17g %zu", range.first, range.second, times.size());
            for (double at : times){
                std::fprintf(out, " %.17g", at);
            }
            std::fprintf(out, " : %s\n", fit_text(fit_tick_period(events, range.first, range.second)).c_str());
        }
    }

    //  Hand-placed streams for the failures and edge cases of build_samples
    //  and last_blink_anchor.
    const std::vector<BlinkEvent> A{event_at(2.0), event_at(5.05, BlinkType::Double), event_at(9.1)};
    const std::vector<BlinkEvent> B{event_at(1.5, BlinkType::Double), event_at(9.1)};
    const std::vector<BlinkEvent> CROWDED{event_at(2.0), event_at(2.3), event_at(4.0)};
    struct Placement{ std::vector<std::vector<BlinkEvent>> streams; std::vector<uint8_t> slots; double period; };
    const std::vector<Placement> PLACEMENTS{
        {{A}, {0}, 1.0},
        {{A, B}, {0, 1}, 1.0},
        {{B, A}, {1, 0}, 1.0},
        {{A, B}, {0, 1}, 0.0},
        {{A, {}}, {0, 1}, 1.0},
        {{A}, {0, 1}, 1.0},
        {{}, {}, 1.0},
        {{CROWDED}, {0}, 1.0},
    };
    for (const Placement& item : PLACEMENTS){
        build_samples_line(out, item.streams, item.slots, item.period);
        anchor_line(out, item.streams, item.slots, item.period);
    }

    struct Step{ double elapsed; double period; uint8_t npcs; uint64_t previous; };
    const std::vector<Step> STEPS{
        {10.2, 1.02, 2, 100}, {0.4, 1.02, 2, 100}, {0.6, 1.02, 3, 7}, {-1.0, 1.02, 2, 5},
        {5.0, 0.0, 2, 5}, {5.0, 1.0, 0, 5}, {1000.0, 1.0197, 1, 0},
    };
    for (const Step& step : STEPS){
        uint64_t advance = 0;
        bool ok = step_blink_anchor(step.elapsed, step.period, step.npcs, step.previous, advance);
        std::fprintf(out, "step_anchor %.17g %.17g %u %" PRIu64 " : %d %" PRIu64 "\n",
            step.elapsed, step.period, step.npcs, step.previous, ok ? 1 : 0, advance);
    }
}

void reidentify_line(FILE* out, const ReidentifyRequest& request){
    ReidentifyResult r = reidentify_advances(request);
    std::fprintf(out, "reidentify %s %" PRIu64 " %" PRIu64 " %u", state_text(request.base_state).c_str(),
        request.search_min, request.search_max, request.npcs);
    if (request.method == ReidentifyMethod::Intervals){
        std::fprintf(out, " intervals %zu", request.intervals.size());
        for (uint32_t interval : request.intervals){
            std::fprintf(out, " %u", interval);
        }
    }else{
        std::fprintf(out, " types %zu", request.types.size());
        for (BlinkType type : request.types){
            std::fprintf(out, " %c", type == BlinkType::Single ? 'S' : 'D');
        }
    }
    std::fprintf(out, " : %d %d %zu %" PRIu64 " %" PRIu64 " reason=%s\n", r.success ? 1 : 0,
        r.ambiguous ? 1 : 0, r.match_count, r.advances_to_first_blink, r.advances_to_last_blink,
        r.failure_reason.c_str());
}

//  What a watcher of every "npcs"th roll sees from the first blink at or after
//  "from": the ticks between its next "count" blinks and their types.
ReidentifyRequest observed_request(
    const Xorshift128State& seed, uint8_t npcs, uint64_t from, size_t count,
    uint64_t search_min, uint64_t search_max, ReidentifyMethod method
){
    std::vector<uint32_t> rolls;
    Xorshift128 rng(seed);
    for (uint64_t c = 0; c < from + 64 * npcs * (count + 1); c++){
        rolls.push_back(rng.next());
    }
    ReidentifyRequest request;
    request.base_state = seed;
    request.search_min = search_min;
    request.search_max = search_max;
    request.npcs = npcs;
    request.method = method;
    uint64_t position = from;
    while (!npc_blinks(rolls[position])){
        position++;
    }
    uint32_t since = 0;
    request.types.push_back(NPC_blink_type(rolls[position]));
    while (request.intervals.size() < count){
        position += npcs;
        since++;
        if (npc_blinks(rolls[position])){
            request.intervals.push_back(since);
            request.types.push_back(NPC_blink_type(rolls[position]));
            since = 0;
        }
    }
    if (method == ReidentifyMethod::Types){
        request.intervals.clear();
    }else{
        request.types.clear();
    }
    return request;
}

void reidentifier_lines(FILE* out){
    const Xorshift128State& seed = SEEDS[3];
    const ReidentifyMethod INTERVALS = ReidentifyMethod::Intervals;
    const ReidentifyMethod TYPES = ReidentifyMethod::Types;
    reidentify_line(out, observed_request(seed, 1, 3000, 10, 0, 10000, INTERVALS));
    reidentify_line(out, observed_request(seed, 2, 3001, 12, 0, 10000, INTERVALS));
    reidentify_line(out, observed_request(seed, 3, 5000, 8, 4000, 6000, INTERVALS));
    reidentify_line(out, observed_request(seed, 1, 3000, 1, 0, 10000, INTERVALS));
    reidentify_line(out, observed_request(seed, 1, 3000, 3, 0, 10000, INTERVALS));
    reidentify_line(out, observed_request(seed, 1, 3000, 10, 3100, 10000, INTERVALS));

    ReidentifyRequest request = observed_request(seed, 1, 3000, 10, 0, 10000, INTERVALS);
    request.intervals[4]++;
    reidentify_line(out, request);
    request.intervals[4] = 0;
    reidentify_line(out, request);
    request = observed_request(seed, 2, 3001, 12, 0, 10000, INTERVALS);
    request.npcs = 0;
    reidentify_line(out, request);
    request.npcs = 2;
    request.search_min = 10001;
    reidentify_line(out, request);
    request.search_min = 0;
    request.intervals.clear();
    reidentify_line(out, request);

    reidentify_line(out, observed_request(seed, 1, 3000, 40, 0, 10000, TYPES));
    reidentify_line(out, observed_request(seed, 1, 3000, 5, 0, 5000, TYPES));
    reidentify_line(out, observed_request(seed, 1, 3000, 13, 0, 5000, TYPES));
    reidentify_line(out, observed_request(seed, 3, 5000, 30, 1000, 8000, TYPES));
    reidentify_line(out, observed_request(seed, 2, 500, 20, 0, 1000, TYPES));
    reidentify_line(out, observed_request(seed, 2, 500, 10, 0, 1000, TYPES));
    //  Types alone rarely fit twice: the first window of 16 advances where
    //  four types do.
    for (uint64_t base = 0; base < 20000; base += 16){
        request = observed_request(seed, 1, base, 3, base, base + 15, TYPES);
        if (reidentify_advances(request).ambiguous){
            reidentify_line(out, request);
            break;
        }
    }
    request = observed_request(seed, 1, 3000, 40, 0, 10000, TYPES);
    request.types[7] = request.types[7] == BlinkType::Single ? BlinkType::Double : BlinkType::Single;
    reidentify_line(out, request);
    request.types.clear();
    reidentify_line(out, request);
}

void write_file(const std::string& path, void (*lines)(FILE*)){
    FILE* out = std::fopen(path.c_str(), "w");
    if (out == nullptr){
        std::perror(path.c_str());
        std::exit(1);
    }
    lines(out);
    std::fclose(out);
}

}

int main(int argc, char** argv){
    if (argc != 2){
        std::fprintf(stderr, "usage: %s <fixtures folder>\n", argv[0]);
        return 1;
    }
    const std::string folder = argv[1];
    write_file(folder + "/xorshift128.txt", xorshift128_lines);
    write_file(folder + "/blink_model.txt", blink_model_lines);
    write_file(folder + "/bdsp_rng.txt", bdsp_rng_lines);
    write_file(folder + "/state_solver.txt", state_solver_lines);
    write_file(folder + "/blink_extraction.txt", blink_extraction_lines);
    write_file(folder + "/reidentifier.txt", reidentifier_lines);
    return 0;
}
