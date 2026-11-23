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
#include "PokemonBDSP/Programs/RngManipulation/PokemonBDSP_BlinkModel.h"

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
        hits = searcher.scan(0, 2000,
            [](const BdspPokemonResult& r){ return r.nature == 3 && r.ivs.attack == 31; });
        std::fprintf(out, "scan_adamant_31atk %s starter 0 0 2000 : %zu\n", state_text(seed).c_str(), hits.size());
        for (const BdspRngHit& hit : hits){
            std::fprintf(out, "  hit %" PRIu64 " %s %s\n", hit.advances,
                state_text(hit.state).c_str(), result_text(hit.result).c_str());
        }
    }
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
    return 0;
}
