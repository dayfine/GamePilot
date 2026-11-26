(* The party and its members' summaries on a Scripted_screen, as FireRed
   answers the presses (pokefirered pokemon_summary_screen.c): START opens the
   menu on POKéMON; A on it the party; A on a slot its menu; A on SUMMARY
   (row 0) that member's info page. On the summary RIGHT and LEFT turn the
   page (1 to 3), DOWN and UP go to the next or previous member on the same
   page (no wrap), and B goes back to the shown member's menu; B from the menu
   goes to the party, from the party to the overworld. Every change shows 200
   ms after its press, plus the press's capture latency. *)

module S = Scripted_screen

type member = {
  species : string;  (** the name the info page shows (["BLASTOISE"]) *)
  level : int;
  moves : string list;  (** the moves page's names (["SURF"]) *)
  draw_ms : int;
      (** after a DOWN to this member, how long its info page shows no text
          before it is drawn (0: drawn with the switch) *)
}

let member ?(draw_ms = 0) ?(moves = [ "TACKLE" ]) species level =
  { species; level; moves; draw_ms }

let show_ms = 200

let page_of (m : member) page : S.screen =
  Summary_page { page; species = m.species; level = m.level; moves = m.moves }

(* [lost_b] B presses on the member's menu after the summary are dropped (the
   menu still drawing). *)
let react ?(lost_b = 0) members =
  let slot = ref 1 and dropped = ref 0 in
  let n = List.length members in
  let nth i = List.nth members (i - 1) in
  fun screen (p : S.press) ->
    let at_ms = p.at_ms + show_ms + S.latency_of screen p in
    let show s = S.show screen ~at_ms s in
    let switch_to i page =
      slot := i;
      let m = nth i in
      if m.draw_ms > 0 then (
        show (page_of { m with species = "" } page);
        S.show screen ~at_ms:(at_ms + m.draw_ms) (page_of m page))
      else show (page_of m page)
    in
    match (p.buttons, S.screen_at screen p.at_ms) with
    | [ Wire.Start ], _ -> show (S.Start_menu 1)
    | [ Wire.A ], S.Start_menu 1 -> show (S.Party 1)
    | [ Wire.A ], S.Party s ->
        slot := s;
        show (S.Member_menu 0)
    | [ Wire.A ], S.Member_menu 0 -> show (page_of (nth !slot) 1)
    | [ Wire.Right ], S.Summary_page { page; _ } when page < 3 ->
        show (page_of (nth !slot) (page + 1))
    | [ Wire.Left ], S.Summary_page { page; _ } when page > 1 ->
        show (page_of (nth !slot) (page - 1))
    | [ Wire.Down ], S.Summary_page { page; _ } when !slot < n ->
        switch_to (!slot + 1) page
    | [ Wire.Up ], S.Summary_page { page; _ } when !slot > 1 ->
        switch_to (!slot - 1) page
    | [ Wire.B ], S.Summary_page _ -> show (S.Member_menu 0)
    | [ Wire.B ], S.Member_menu _ when !dropped < lost_b -> incr dropped
    | [ Wire.B ], S.Member_menu _ -> show (S.Party !slot)
    | [ Wire.B ], S.Party _ -> show S.Overworld
    | _ -> ()

(* The presses of one kind. *)
let count screen button =
  List.length
    (List.filter (fun (p : S.press) -> p.buttons = [ button ]) screen.S.presses)
