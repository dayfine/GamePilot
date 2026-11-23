let glyph_table = "src/games/frlg/assets/font_latin_normal.glyphs"
let item_names_eng = "src/games/frlg/assets/item_names_eng.txt"
let tm_hm_moves_eng = "src/games/frlg/assets/tm_hm_moves_eng.txt"

let move_names =
  "third_party/Packages/Resources/PokemonFRLG/BattleMovesOCR.json"

let locate path =
  let rec up dir =
    let candidate = Filename.concat dir path in
    if Sys.file_exists candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else up parent
  in
  up (Sys.getcwd ())
