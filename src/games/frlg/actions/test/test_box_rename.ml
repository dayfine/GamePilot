(* Box_rename on a fake box screen: the title's name, the title menu's arrow
   (JUMP at first), the naming screen's coming and the name typed. *)

open Frlg_actions
module R = Box_rename

type fake = {
  mutable title : string;
  mutable menu_open : bool;
  mutable arrow : int;
  mutable naming : bool;
  mutable trace : string list;
  labels : string list;
  typed_as : string -> string;  (** what the naming screen keeps *)
}

let note f s = f.trace <- s :: f.trace

let press f (b : Wire.button) =
  note f (Wire.string_of_button b);
  match b with
  | A when f.menu_open && f.arrow = R.name_row ->
      f.menu_open <- false;
      f.naming <- true
  | A -> f.menu_open <- true
  | Down when f.menu_open -> f.arrow <- min 3 (f.arrow + 1)
  | Up when f.menu_open -> f.arrow <- max 0 (f.arrow - 1)
  | _ -> ()

let steps f : R.game_steps =
  {
    open_move_pokemon = (fun () -> note f "open");
    read_title =
      (fun candidates ->
        if List.mem f.title candidates then Some f.title else None);
    read_menu_label =
      (fun i -> if f.menu_open then List.nth_opt f.labels i else None);
    read_menu_row = (fun () -> if f.menu_open then Some f.arrow else None);
    await_naming_screen = (fun () -> f.naming);
    type_name =
      (fun name ->
        note f ("type " ^ name);
        f.naming <- false;
        f.title <- f.typed_as name);
    await_box_screen = (fun () -> not f.naming);
    press = press f;
    close = (fun () -> note f "close");
  }

let menu = [ "JUMP"; "WALLPAPER"; "NAME"; "CANCEL" ]

let renamed ?(title = "BOX1") ?(labels = menu) ?(typed_as = Fun.id) from to_ ()
    =
  let f =
    {
      title;
      menu_open = false;
      arrow = 0;
      naming = false;
      trace = [];
      labels;
      typed_as;
    }
  in
  let r : R.rename = { from; to_ } in
  let outcome =
    match R.run (steps f) ~log:ignore r with
    | () -> "ok"
    | exception Menu_input.Action_failed c -> c.code
  in
  Printf.sprintf "%s: %s; title %s" outcome
    (String.concat " " (List.rev f.trace))
    f.title

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "renamed, the arrow down to NAME"
      (renamed "BOX1" "Az!…'.,9")
      "ok: open Up A Down Down A type Az!…'.,9 close; title Az!…'.,9";
    case "already renamed: nothing typed"
      (renamed ~title:"Az!…'.,9" "BOX1" "Az!…'.,9")
      "ok: open close; title Az!…'.,9";
    case "another box: refused before a press"
      (renamed ~title:"BOX2" "BOX1" "X")
      "box_name_not_from: open; title BOX2";
    case "no NAME on the menu: no A on it"
      (renamed ~labels:[ "MOVE"; "SUMMARY"; "ITEM"; "MARK" ] "BOX1" "X")
      "box_menu_missing: open Up A; title BOX1";
    case "the title does not take the name"
      (renamed ~typed_as:(fun _ -> "BOX1") "BOX1" "X")
      "box_name_wrong: open Up A Down Down A type X; title BOX1";
  ]

let () = Table_test.run "box_rename" cases
