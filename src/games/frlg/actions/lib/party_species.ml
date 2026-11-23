open Frlg_readers
module M = Menu_input
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

let summary_timeout_ms = 5000
let info_page = 1

(* The menu goes as the summary starts fading in, which takes a while. *)
let summary_opening m =
  Option.is_some (Summary_screen.page m) || not (Party_actions.member_menu m)

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

(* The page's mark shows before its text is drawn: a species counts once two
   reads a moment apart agree on one. *)
let rec settled previous reads =
  let read = read_shown () in
  if read <> None && read = previous then read
  else if reads >= Summary_moves.max_reads then None
  else (
    wait Summary_moves.reread_ms;
    settled read (reads + 1))

(* In the member's menu: SUMMARY, the species, and back to the menu (B from
   the summary lands there, not on the party). *)
let read_summary ~log slot () =
  Party_actions.choose_member_row Member_menu.summary_row ~taken:summary_opening;
  ignore
    (M.await_screen ~timeout_ms:summary_timeout_ms ~code:"no_summary"
       "the summary" (fun m -> Summary_screen.page m = Some info_page));
  let species = settled None 1 in
  log
    (Printf.sprintf "Party: slot %d is %s." slot
       (Option.value ~default:"unread" species));
  M.press Wire.B;
  ignore
    (M.await_screen ~timeout_ms:summary_timeout_ms ~code:"no_member_menu"
       "the member's menu after the summary" Party_actions.member_menu);
  (* A B while the menu is still drawing is lost: B until it is gone. *)
  M.press_until ~max_presses:4 ~code:"no_party" "the member's menu closed"
    Wire.B ~cooldown_ms:M.close_press_ms (fun m ->
      not (Party_actions.member_menu m));
  species

let read_member ~log slot =
  let species = Party_actions.on_member_menu slot (read_summary ~log slot) in
  ignore
    (M.await_screen ~code:"no_party" "the party after the member's menu"
       Party_menu.party_menu);
  species

let read_party ~log () =
  Party_actions.open_party ();
  let shown =
    M.await_screen ~code:"no_party" "the party" Party_menu.party_menu
  in
  let species =
    List.init (Party_menu.members shown) (fun i -> read_member ~log (i + 1))
  in
  M.close "the party" Party_menu.party_menu;
  M.settle_back ~label:"party species" ~log;
  species

let read_all ~log = Effects.with_probes Summary_screen.probes (read_party ~log)
