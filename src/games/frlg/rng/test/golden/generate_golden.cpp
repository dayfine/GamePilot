//  Golden vectors for src/games/frlg/rng, computed by the fork's C++ (D6: the
//  C++ is the oracle). Each output line holds its inputs and the C++'s outputs,
//  so the OCaml tests read the inputs from the line and check they give the same
//  text. regen_golden.sh builds and runs this; see it for the command.
//
//  Usage: generate_golden <fixtures dir> <resource dir>
//  The resource dir holds PokemonFRLG/EncounterSlotsFR.json and the sliced
//  PokemonFRLG/RngSeeds/FR_Eng.json that regen_golden.sh writes.

#include <cinttypes>
#include <cstdio>
#include <string>
#include <vector>
#include "Common/Cpp/Json/JsonArray.h"
#include "Common/Cpp/Json/JsonObject.h"
#include "Common/Cpp/Json/JsonValue.h"
#include "Pokemon/Pokemon_AdvRng.h"
#include "PokemonFRLG/Programs/RngManipulation/PokemonFRLG_EncountersDatabase.h"
#include "PokemonFRLG/Programs/RngManipulation/PokemonFRLG_SeedsDatabase.h"

using namespace PokemonAutomation;
using namespace PokemonAutomation::Pokemon;
using namespace PokemonAutomation::NintendoSwitch::PokemonFRLG;

//  Free functions of Pokemon_AdvRng.cpp that its header does not declare.
namespace PokemonAutomation{
namespace Pokemon{
uint32_t increment_internal_rng_state(uint32_t state);
uint8_t slot_number_from_roll(uint8_t roll, size_t size, bool super_rod);
AdvShinyType shiny_type_from_pid(uint32_t pid, uint16_t tid_xor_sid);
}
}

std::string RESOURCES;

namespace{

const std::vector<uint32_t> STATES{
    0x00000000, 0x00000001, 0x00005a0e, 0x12345678, 0x80000000, 0xdeadbeef, 0xffffffff,
};
const std::vector<uint16_t> SEEDS{0x0000, 0x5a0e, 0x11c7, 0xd4de, 0xffff};
const std::vector<uint64_t> ADVANCES{0, 1, 2, 5, 100, 1000, 4567, 65535, 1000000, 33554431};

FILE* open_fixture(const std::string& dir, const char* name){
    std::string path = dir + "/" + name;
    FILE* out = std::fopen(path.c_str(), "w");
    if (out == nullptr){
        std::perror(path.c_str());
        std::exit(1);
    }
    return out;
}

const char* method_text(AdvRngMethod method){
    switch (method){
    case AdvRngMethod::Method1: return "m1";
    case AdvRngMethod::Method2: return "m2";
    case AdvRngMethod::Method3: return "m3";
    case AdvRngMethod::Method4: return "m4";
    default: return "any";
    }
}

std::string ivs_text(const AdvIVs& ivs){
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%d %d %d %d %d %d",
        ivs.hp, ivs.attack, ivs.defense, ivs.spatk, ivs.spdef, ivs.speed);
    return buffer;
}

void lcg_lines(FILE* out){
    for (uint32_t state : STATES){
        uint32_t s = state;
        std::fprintf(out, "next %08x 8 :", s);
        for (int c = 0; c < 8; c++){
            s = increment_internal_rng_state(s);
            std::fprintf(out, " %08x", s);
        }
        std::fprintf(out, "\n");
        //  The C++ has no jump: the oracle steps one by one.
        s = state;
        uint64_t done = 0;
        for (uint64_t count : ADVANCES){
            for (; done < count; done++){
                s = increment_internal_rng_state(s);
            }
            std::fprintf(out, "jump %08x %" PRIu64 " : %08x\n", state, count, s);
        }
    }
    for (uint16_t seed : SEEDS){
        for (uint64_t advance : ADVANCES){
            AdvRngState s = AdvRngSearcher(seed, advance, AdvRngMethod::Method1).state;
            std::fprintf(out, "state %04x %" PRIu64 " : %08x %08x %08x %08x %08x %08x\n",
                seed, advance, s.s0, s.s1, s.s2, s.s3, s.s4, s.s5);
        }
    }
}

void pokemon_lines(FILE* out){
    const AdvRngMethod methods[] = {AdvRngMethod::Method1, AdvRngMethod::Method2, AdvRngMethod::Method4};
    for (uint16_t seed : SEEDS){
        for (AdvRngMethod method : methods){
            for (int roaming = 0; roaming < 2; roaming++){
                AdvRngSearcher searcher(seed, 0, method, roaming != 0);
                for (uint64_t a = 0; a < 40; a++){
                    AdvPokemonResult p = searcher.generate_pokemon();
                    std::fprintf(out, "pokemon %04x %" PRIu64 " %s %d : %08x %d %d %d %s\n",
                        seed, a, method_text(method), roaming, p.pid, p.gender, (int)p.nature,
                        (int)p.ability, ivs_text(p.ivs).c_str());
                    searcher.advance_state();
                }
            }
        }
    }
    const std::vector<uint32_t> pids{0x00000000, 0x00000007, 0x00080000, 0x12345678, 0xffff0000, 0xbeefbee8, 0x5a0e5a09};
    const std::vector<uint16_t> tsvs{0x0000, 0x0007, 0x5a0e, 0xffff};
    for (uint32_t pid : pids){
        for (uint16_t tsv : tsvs){
            std::fprintf(out, "shiny %08x %04x : %d\n", pid, tsv, (int)shiny_type_from_pid(pid, tsv));
        }
    }
}

//  A filter as text: method nature ability gender shiny, then six "low-high" IV
//  ranges (hp atk def spa spd spe), then the gender threshold and TID ^ SID.
struct Filter{
    AdvRngFilters filters;
    int16_t gender_threshold;
    uint16_t tsv;
};

std::string filter_text(const Filter& f){
    const IvRanges& r = f.filters.ivs;
    char buffer[256];
    std::snprintf(buffer, sizeof(buffer), "%s %d %d %d %d %d-%d %d-%d %d-%d %d-%d %d-%d %d-%d %d %04x",
        method_text(f.filters.method), (int)f.filters.nature, (int)f.filters.ability,
        (int)f.filters.gender, (int)f.filters.shiny,
        r.hp.low, r.hp.high, r.attack.low, r.attack.high, r.defense.low, r.defense.high,
        r.spatk.low, r.spatk.high, r.spdef.low, r.spdef.high, r.speed.low, r.speed.high,
        f.gender_threshold, f.tsv);
    return buffer;
}

IvRanges all_ivs(int8_t low, int8_t high){
    IvRange r{low, high};
    return {r, r, r, r, r, r};
}

std::vector<Filter> static_filters(){
    std::vector<Filter> out;
    AdvRngFilters adamant{"", 0, AdvGender::Any, AdvNature::Adamant, AdvAbility::Any, all_ivs(20, 31), AdvShinyType::Any, AdvRngMethod::Any};
    out.push_back({adamant, 126, 0});
    AdvRngFilters female_m1{"", 0, AdvGender::Female, AdvNature::Any, AdvAbility::One, all_ivs(15, 31), AdvShinyType::Any, AdvRngMethod::Method1};
    out.push_back({female_m1, 126, 0});
    AdvRngFilters shiny{"", 0, AdvGender::Any, AdvNature::Any, AdvAbility::Any, all_ivs(0, 31), AdvShinyType::Star, AdvRngMethod::Any};
    out.push_back({shiny, 126, 0x5a0e});
    AdvRngFilters genderless{"", 0, AdvGender::Male, AdvNature::Timid, AdvAbility::Any, all_ivs(0, 31), AdvShinyType::Any, AdvRngMethod::Method4};
    out.push_back({genderless, -2, 0});
    AdvRngFilters method3{"", 0, AdvGender::Any, AdvNature::Any, AdvAbility::Any, all_ivs(0, 31), AdvShinyType::Any, AdvRngMethod::Method3};
    out.push_back({method3, 126, 0});
    return out;
}

std::string seeds_text(const std::vector<uint16_t>& seeds){
    std::string text;
    for (uint16_t seed : seeds){
        char buffer[8];
        std::snprintf(buffer, sizeof(buffer), "%s%04x", text.empty() ? "" : ",", seed);
        text += buffer;
    }
    return text;
}

void hits_line(FILE* out, const std::vector<AdvRngState>& hits){
    std::fprintf(out, " %zu", hits.size());
    for (const AdvRngState& h : hits){
        std::fprintf(out, " %04x:%" PRIu64 ":%s", h.seed, h.advance, method_text(h.method));
    }
    std::fprintf(out, "\n");
}

void static_search_lines(FILE* out){
    const std::vector<uint16_t> seeds{0x5a0e, 0x11c7, 0xd4de};
    for (Filter& f : static_filters()){
        for (int roaming = 0; roaming < 2; roaming++){
            AdvRngSearcher searcher(seeds[0], 0, AdvRngMethod::Method1, roaming != 0);
            std::vector<AdvRngState> hits = searcher.search(f.filters, seeds, 1000, 30000, f.gender_threshold, f.tsv);
            std::fprintf(out, "search_static %s 1000 30000 %d %s :",
                seeds_text(seeds).c_str(), roaming, filter_text(f).c_str());
            hits_line(out, hits);
        }
    }
}

struct Table{
    const char* type;
    const char* location;
    bool super_rod;
};

const std::vector<Table> TABLES{
    {"grass", "route_1", false},
    {"grass", "viridian_forest", false},
    {"grass", "tanoby_ruins_dilford_chamber", false},
    {"surfing", "cerulean_cave_1f", false},
    {"rocksmash", "kindle_road", false},
    {"oldrod", "celadon_city", false},
    {"goodrod", "fuchsia_city", false},
    {"superrod", "cerulean_cave_1f", false},
    {"superrod", "cerulean_cave_1f", true},
};

void slot_lines(FILE* out){
    for (size_t size : {12, 5, 3, 2, 1}){
        for (int super_rod = 0; super_rod < 2; super_rod++){
            std::fprintf(out, "slot %zu %d :", size, super_rod);
            for (int roll = 0; roll < 100; roll++){
                std::fprintf(out, " %d", slot_number_from_roll((uint8_t)roll, size, super_rod != 0));
            }
            std::fprintf(out, "\n");
        }
    }
}

void wild_lines(FILE* out, const EncountersDatabase& database){
    const AdvRngMethod methods[] = {AdvRngMethod::Method1, AdvRngMethod::Method2, AdvRngMethod::Method4};
    for (const Table& t : TABLES){
        const std::vector<AdvEncounterSlot>& slots = database.get_throw(t.type).at(t.location);
        std::fprintf(out, "table %s/%s :", t.type, t.location);
        for (const AdvEncounterSlot& s : slots){
            std::fprintf(out, " %s/%d/%d", s.species.c_str(), s.minlevel, s.maxlevel);
        }
        std::fprintf(out, "\n");
        for (AdvRngMethod method : methods){
            AdvRngWildSearcher searcher(0x5a0e, 0, slots, method);
            for (uint64_t a = 0; a < 30; a++){
                AdvWildPokemonResult p = searcher.generate_pokemon(t.super_rod);
                std::fprintf(out, "wild %s/%s 5a0e %" PRIu64 " %s %d : %s %08x %d %d %d %s %d %d\n",
                    t.type, t.location, a, method_text(method), t.super_rod, p.species.c_str(), p.pid,
                    p.gender, (int)p.nature, (int)p.ability, ivs_text(p.ivs).c_str(), p.slot, p.level);
                searcher.advance_state();
            }
        }
    }
}

void wild_search_lines(FILE* out, const EncountersDatabase& database){
    const std::vector<uint16_t> seeds{0x5a0e, 0x11c7};
    struct Target{ Table table; const char* species; uint8_t level; };
    const std::vector<Target> targets{
        {TABLES[0], "pidgey", 3},
        {TABLES[1], "pikachu", 5},
        {TABLES[2], "unown", 25},
        {TABLES[2], "unown-p", 25},
        {TABLES[8], "gyarados", 15},
    };
    for (const Target& t : targets){
        const std::vector<AdvEncounterSlot>& slots = database.get_throw(t.table.type).at(t.table.location);
        for (Filter& f : static_filters()){
            f.filters.species = t.species;
            f.filters.level = t.level;
            f.filters.ivs = all_ivs(10, 31);
            AdvRngWildSearcher searcher(seeds[0], 0, slots, AdvRngMethod::Any);
            std::vector<AdvRngState> hits = searcher.search(
                f.filters, seeds, 0, 3000, f.gender_threshold, t.table.super_rod, f.tsv);
            std::fprintf(out, "search_wild %s/%s %s %d %s 0 3000 %d %s :",
                t.table.type, t.table.location, t.species, t.level, seeds_text(seeds).c_str(),
                t.table.super_rod, filter_text(f).c_str());
            hits_line(out, hits);
        }
    }
}

//  The slice regen_golden.sh wrote, as the OCaml side builds its database: the
//  delays, then each column's name and raw seed strings, in the C++'s order.
void seed_table_lines(FILE* out, const std::string& path){
    JsonValue json = load_json_file(path);
    JsonObject& root = json.to_object_throw(path);
    std::fprintf(out, "delays :");
    for (auto& delay : root.get_array_throw("Delay", path)){
        std::fprintf(out, " %" PRId64, delay.to_integer_throw(path));
    }
    std::fprintf(out, "\n");
    int index = 0;
    for (auto& item : root){
        if (item.first == "Delay"){
            continue;
        }
        std::fprintf(out, "column %d : %s\n", index, item.first.c_str());
        std::fprintf(out, "seeds %d :", index);
        for (auto& seed : item.second.to_array_throw(path)){
            std::fprintf(out, " %s", seed.to_string_throw(path).c_str());
        }
        std::fprintf(out, "\n");
        index++;
    }
}

void find_seed_lines(FILE* out, const SeedsDatabase& database, const std::vector<uint16_t>& targets){
    for (uint16_t target : targets){
        for (SoundSetting sound : {SoundSetting::Mono, SoundSetting::Stereo}){
            for (int radius : {0, 3, 10}){
                SeedMatch m = database.find_seed(target, sound, radius);
                std::fprintf(out, "find_seed %04x %d %d :", target, (int)sound, radius);
                if (!m.found){
                    std::fprintf(out, " none\n");
                    continue;
                }
                std::fprintf(out, " %d %" PRIu64 " %d %d %d %s |", m.seed_position, m.seed_delay,
                    (int)m.seed_button, (int)m.extra_button, (int)m.sound, m.button_mode.c_str());
                for (uint16_t v : m.seed_values){
                    std::fprintf(out, " %04x", v);
                }
                std::fprintf(out, " | %s\n", m.column_name.c_str());
            }
        }
    }
}

void seeds_lines(FILE* out){
    const std::string json_path = seeds_json_path(true, Language::English);
    seed_table_lines(out, RESOURCES + json_path);
    SeedsDatabase database(json_path);
    //  Targets: seeds at a few rows of the slice, the same minus the blackout
    //  offset (found through the L variant), and seeds absent from it.
    JsonValue json = load_json_file(RESOURCES + json_path);
    JsonObject& root = json.to_object_throw();
    std::vector<uint16_t> targets{0x0000, 0x0024, 0xffff};
    for (auto& item : root){
        if (item.first == "Delay"){
            continue;
        }
        JsonArray& seeds = item.second.to_array_throw();
        for (size_t row : {0, 1, 7, 150, 298, 299}){
            uint16_t seed = (uint16_t)std::stoul(seeds[row].to_string_throw(), nullptr, 16);
            targets.push_back(seed);
            targets.push_back((uint16_t)(seed - BLACKOUT_SEED_OFFSET));
        }
    }
    find_seed_lines(out, database, targets);
}

}

int main(int argc, char** argv){
    if (argc != 3){
        std::fprintf(stderr, "usage: generate_golden <fixtures dir> <resource dir>\n");
        return 2;
    }
    const std::string dir = argv[1];
    RESOURCES = std::string(argv[2]) + "/";

    FILE* lcg = open_fixture(dir, "lcg.txt");
    lcg_lines(lcg);
    std::fclose(lcg);

    FILE* pokemon = open_fixture(dir, "pokemon_generation.txt");
    pokemon_lines(pokemon);
    static_search_lines(pokemon);
    std::fclose(pokemon);

    EncountersDatabase encounters("PokemonFRLG/EncounterSlotsFR.json");
    FILE* wild = open_fixture(dir, "wild_encounter.txt");
    slot_lines(wild);
    wild_lines(wild, encounters);
    wild_search_lines(wild, encounters);
    std::fclose(wild);

    FILE* seeds = open_fixture(dir, "seeds_database.txt");
    seeds_lines(seeds);
    std::fclose(seeds);
    return 0;
}
