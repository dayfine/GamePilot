module Text = Frlg_text

let read_shown () =
  let species = Text_data.species_names () in
  match
    Text.Line_reading.read (Text_data.glyphs ()) Text.Text_lines.summary_species
      (List.map snd species)
  with
  | Read { text; _ } ->
      Option.map fst (List.find_opt (fun (_, name) -> name = text) species)
  | No_match _ -> None

let read_member ~log slot =
  let species = Summary_paging.settled read_shown in
  log
    (Printf.sprintf "Party: slot %d is %s." slot
       (Option.value ~default:"unread" species));
  species

let read_all ~log =
  Summary_paging.each_member ~label:"party species" ~log (read_member ~log)
