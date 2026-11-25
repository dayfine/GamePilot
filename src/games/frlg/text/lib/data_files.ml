let glyph_table = "src/games/frlg/assets/font_latin_normal.glyphs"
let small_glyph_table = "src/games/frlg/assets/font_latin_small.glyphs"
let item_names_eng = "src/games/frlg/assets/item_names_eng.txt"
let species_names_eng = "src/games/frlg/assets/species_names_eng.txt"
let easy_chat_words_eng = "src/games/frlg/assets/easy_chat_words_eng.txt"
let tm_hm_moves_eng = "src/games/frlg/assets/tm_hm_moves_eng.txt"

let move_names ~language =
  Printf.sprintf "src/games/frlg/assets/move_names_%s.txt" language

let locate = Repo_io.Repo_files.locate
