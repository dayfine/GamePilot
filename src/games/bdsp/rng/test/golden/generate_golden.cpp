//  Golden vectors for src/games/bdsp/rng, computed by the fork's C++ (D6: the
//  C++ is the oracle). Each output line holds its inputs and the C++'s outputs,
//  so the OCaml tests read the inputs from the line and check they give the same
//  text. regen_golden.sh builds and runs this; see it for the command.

#include <cinttypes>
#include <cmath>
#include <cstdio>
#include <limits>
#include <string>
#include <vector>
#include "Pokemon/Pokemon_BdspRng.h"
#include "Pokemon/Pokemon_Gf2Matrix.h"
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.h"
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
    return 0;
}
