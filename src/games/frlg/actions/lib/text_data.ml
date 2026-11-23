module Text = Frlg_text

let load_data path load =
  match Text.Data_files.locate path with
  | Some file -> load file
  | None -> Menu_input.fail ~repeats:true "no_text_data" (path ^ " not found")

let glyph_table =
  lazy (load_data Text.Data_files.glyph_table Text.Glyph_table.load)

let item_table =
  lazy (load_data Text.Data_files.item_names_eng Text.Item_names.load)

let move_table =
  lazy
    (load_data Text.Data_files.move_names
       (Text.Move_names.load ~language:"eng"))

let glyphs () = Lazy.force glyph_table
let item_names () = Lazy.force item_table
let move_names () = Lazy.force move_table

let species_table =
  lazy (load_data Text.Data_files.species_names_eng Text.Species_names.load)

let species_names () = Lazy.force species_table
