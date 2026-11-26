#!/usr/bin/env python3
"""Writes the English FRLG Easy Chat groups and their word lists, in the order the game lists them.

Reads a pret/pokefirered checkout (a sparse checkout works: files come through `git show HEAD:`)
and prints one line per group, in the order of the group grid (PopulateECGroups in
src/easy_chat.c):

    <group id> <shown> <name>|<word>|<word>|...

<group id> is the EC_GROUP_ constant's value; <shown> says when the grid lists the group:
`seen` (any Pokemon seen; its words only the seen species), `always`, `game_clear`
(FLAG_SYS_GAME_CLEAR) or `national` (the National Pokedex); <name> is the group's name and each
<word> a word as the word list shows it, top left first, two to a row (GetUnlockedWordsInECGroup):
a species or move group in its value list's order, any other group by each entry's
alphabeticalOrder, its disabled words left out. The groups the grid never shows (TRENDY SAYING)
are left out.

    python3 src/games/pokemon/frlg/assets/extract/extract_frlg_easy_chat_words.py ~/Projects/pokefirered \
        > src/games/pokemon/frlg/assets/easy_chat_words_eng.txt

Stdlib only.
"""

import re
import subprocess
import sys

# The group grid's order and when each group shows (PopulateECGroups): the POKéMON group (id
# 0x15, the decomp's EC_GROUP_POKEMON) first once any Pokemon is seen, TRAINER..ADJECTIVES,
# EVENTS and the two move groups after the game is clear, POKéMON2 (id 0) with the National Dex.
GRID = [
    ("POKEMON", 0x15, "seen", "easy_chat_group_pokemon2.h", "species"),
    ("TRAINER", 0x1, "always", "easy_chat_group_trainer.h", "words"),
    ("STATUS", 0x2, "always", "easy_chat_group_status.h", "words"),
    ("BATTLE", 0x3, "always", "easy_chat_group_battle.h", "words"),
    ("GREETINGS", 0x4, "always", "easy_chat_group_greetings.h", "words"),
    ("PEOPLE", 0x5, "always", "easy_chat_group_people.h", "words"),
    ("VOICES", 0x6, "always", "easy_chat_group_voices.h", "words"),
    ("SPEECH", 0x7, "always", "easy_chat_group_speech.h", "words"),
    ("ENDINGS", 0x8, "always", "easy_chat_group_endings.h", "words"),
    ("FEELINGS", 0x9, "always", "easy_chat_group_feelings.h", "words"),
    ("CONDITIONS", 0xA, "always", "easy_chat_group_conditions.h", "words"),
    ("ACTIONS", 0xB, "always", "easy_chat_group_actions.h", "words"),
    ("LIFESTYLE", 0xC, "always", "easy_chat_group_lifestyle.h", "words"),
    ("HOBBIES", 0xD, "always", "easy_chat_group_hobbies.h", "words"),
    ("TIME", 0xE, "always", "easy_chat_group_time.h", "words"),
    ("MISC", 0xF, "always", "easy_chat_group_misc.h", "words"),
    ("ADJECTIVES", 0x10, "always", "easy_chat_group_adjectives.h", "words"),
    ("EVENTS", 0x11, "game_clear", "easy_chat_group_events.h", "words"),
    ("MOVE_1", 0x12, "game_clear", "easy_chat_group_move_1.h", "moves"),
    ("MOVE_2", 0x13, "game_clear", "easy_chat_group_move_2.h", "moves"),
    ("POKEMON_2", 0x0, "national", "easy_chat_group_pokemon.h", "species"),
]
GROUP_NAME = re.compile(r'gEasyChatGroupName_(\w+)\[\] = _\("([^"]*)"\)')
NAME_OF = {
    "POKEMON": "Pokemon", "TRAINER": "Trainer", "STATUS": "Status", "BATTLE": "Battle",
    "GREETINGS": "Greetings", "PEOPLE": "People", "VOICES": "Voices", "SPEECH": "Speech",
    "ENDINGS": "Endings", "FEELINGS": "Feelings", "CONDITIONS": "Conditions", "ACTIONS": "Actions",
    "LIFESTYLE": "Lifestyle", "HOBBIES": "Hobbies", "TIME": "Time", "MISC": "Misc",
    "ADJECTIVES": "Adjectives", "EVENTS": "Events", "MOVE_1": "Move1", "MOVE_2": "Move2",
    "POKEMON_2": "Pokemon2",
}
WORD_TEXT = re.compile(r'(sEasyChatWord_\w+)\[\] = _\("([^"]*)"\)')
WORD_INFO = re.compile(r'\.text = (sEasyChatWord_\w+),\s*\.alphabeticalOrder = (\d+),\s*\.enabled = (\w+)')
VALUE = re.compile(r'(?:SPECIES|MOVE)_(\w+),')
NAMED = re.compile(r'\[(?:SPECIES|MOVE)_(\w+)\]\s*= _\("([^"]*)"\)')


def show(decomp, path):
    return subprocess.run(
        ["git", "-C", decomp, "show", "HEAD:" + path], capture_output=True, check=True, text=True
    ).stdout


def word_group(text):
    texts = dict(WORD_TEXT.findall(text))
    info = [(texts[t], int(order), enabled == "TRUE") for t, order, enabled in WORD_INFO.findall(text)]
    return [info[order][0] for _, order, _ in info if info[order][2]]


def main(decomp):
    group_names = dict(GROUP_NAME.findall(show(decomp, "src/strings.c")))
    species = dict(NAMED.findall(show(decomp, "src/data/text/species_names.h")))
    moves = dict(NAMED.findall(show(decomp, "src/data/text/move_names.h")))
    print("# FRLG English Easy Chat groups, made by src/games/pokemon/frlg/assets/extract/extract_frlg_easy_chat_words.py")
    print("# from pret/pokefirered src/data/easy_chat/ and src/easy_chat.c, in the group grid's order:")
    print("# <group id> <shown: seen|always|game_clear|national> <name>|<word>|... (the word list's order)")
    for key, group_id, shown, source, kind in GRID:
        text = show(decomp, "src/data/easy_chat/" + source)
        if kind == "words":
            words = word_group(text)
        else:
            table = species if kind == "species" else moves
            words = [table[v] for v in VALUE.findall(text)]
        print("%d %s %s" % (group_id, shown, "|".join([group_names[NAME_OF[key]]] + words)))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
