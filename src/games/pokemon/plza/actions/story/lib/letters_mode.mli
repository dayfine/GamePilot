(** Simplified Chinese's name keyboard switched to its English (letters) mode
    before the name is typed, ported from the fork's
    PokemonLZA_AutoStoryNewGame.cpp (dayfine/Arduino-Source#644). The keyboard
    opens in Pinyin (拼音), where a letter starts a Pinyin syllable (the fork's
    2026-11-15 frames); its English key (英文), the fourth key of the bottom row
    (globe, Shift, 拼音, 英文, 符号, Space), gives the Latin first page every other
    language types on ({!Switch_home.Keyboard_typing}): console B's frame of
    2026-11-26, opened in 英文, has the same four rows.

    The fork, at most 16 reads: on the English key, A (400 ms after); left when
    the cursor is right of its column; else down to the bottom row; else right.
    A read with no cursor waits 300 ms.

    Where it differs: the cursor reader reads only the four character rows
    ({!Switch_home.Code_keyboard.cursor}), not the bottom row, so the last steps
    are taken from the last key read: once the cursor reads on the bottom
    character row at or left of the English key's column, down onto the bottom
    row, right to the English key's column, A; then up, which must read the key
    above it ("v"), else the run fails (an A on another bottom key may have done
    something: the by-hand hint follows). Each press is the intro's (80 ms).
    Pressing the English key when the keyboard opened in English (as console B's
    did on 2026-11-26: the Switch keeps the last mode) is assumed to keep it. *)

val english_key_column : int
(** 3: the English key's column, under "4", "r", "f" and "v". *)

val switch : Switch_home.Keyboard_typing.game_steps -> (unit, string) result
(** Moves to the English key and presses A, then back up onto "v"; [Error] when
    the cursor never reads in 16 reads, or does not read on "v" after. *)
