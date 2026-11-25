module S = Frlg_readers.Pc_screen
module D = Pc_deposit_steps

type look = {
  view : S.view;
  label : string option;
  species : string option;
  panel_empty : bool option;
}

type phase =
  | Opening of { booted : bool; boot_looks : int }
  | Browsing of { slot : int; blank_looks : int }
      (** The hand on this slot of the walk (0..29). *)
  | Choosing of string  (** A on the slot: its menu is coming. *)
  | Withdrawing of string  (** A on WITHDRAW. *)
  | Leaving of { species : string; overworld_seen : bool }

type t = { phase : phase; others : int }

let withdraw_row = "WITHDRAW POKéMON"
let mon_withdraw_row = "WITHDRAW"
let columns = 6
let box_slots = 30
let max_looks = 120

(* Looks at a slot whose panel shows something but no species, before the
   hand moves on: the panel may still be drawing. *)
let blank_reads = 2
let start = { phase = Opening { booted = false; boot_looks = 0 }; others = 0 }

let withdrawn t =
  match t.phase with Leaving { species; _ } -> Some species | _ -> None

let go t phase (press : D.press) = ({ t with phase }, press)

let opening t ~booted ~boot_looks (l : look) : t * D.press =
  let label_is s = l.label = Some s in
  match (l.view.screen, l.view.cursor) with
  | Overworld, _ when not booted ->
      go t (Opening { booted = true; boot_looks }) A
  | Overworld, _ when boot_looks + 1 < D.boot_reads ->
      go t (Opening { booted; boot_looks = boot_looks + 1 }) Wait
  | Overworld, _ -> (t, Fail "the overworld came back before the withdraw")
  | Text, _ -> go t (Opening { booted = true; boot_looks = D.boot_reads }) B
  | Pc_list, Some 0 when List.exists label_is D.pc_list_tops -> (t, A)
  | Pc_list, Some _ -> (t, Up)
  | Pc_list, None -> (t, Fail "the PC list's cursor did not read")
  | Storage_menu, Some 0 when label_is withdraw_row ->
      go t (Browsing { slot = 0; blank_looks = 0 }) A
  | Storage_menu, Some 0 ->
      (t, Fail "the storage menu's row 1 did not read as WITHDRAW")
  | Storage_menu, Some _ -> (t, Up)
  | Storage_menu, None -> (t, Fail "the storage menu's cursor did not read")
  | (Box_grid | Party_panel | Mon_menu | Box_chooser | Yes_no), _ ->
      (t, Fail "a box screen before WITHDRAW POKéMON")
  | Other, _ -> (t, Wait)

(* The walk's slot [k] in the box: RIGHT along even rows, LEFT along odd ones,
   DOWN at a row's end. *)
let move_from k : D.press =
  if (k + 1) mod columns = 0 then Down
  else if k / columns mod 2 = 0 then Right
  else Left

(* A box screen with a Pokémon's data can read as the overworld (Pc_box). *)
let on_box_screen (l : look) =
  match l.view.screen with Box_grid | Overworld -> true | _ -> false

let browsing t ~slot ~blank_looks (l : look) : t * D.press =
  match l.species with
  | _ when not (on_box_screen l) -> (t, Wait)
  | Some species -> go t (Choosing species) A
  | None when l.panel_empty <> Some true && blank_looks + 1 < blank_reads ->
      go t (Browsing { slot; blank_looks = blank_looks + 1 }) Wait
  | None when slot + 1 >= box_slots ->
      (t, Fail "no Pokemon in the box the PC opened on")
  | None ->
      go t (Browsing { slot = slot + 1; blank_looks = 0 }) (move_from slot)

let choosing t species (l : look) : t * D.press =
  match (l.view.screen, l.view.cursor) with
  | Mon_menu, Some 0 when l.label = Some mon_withdraw_row ->
      go t (Withdrawing species) A
  | Mon_menu, _ -> (t, Fail "the Pokemon's menu is not on WITHDRAW")
  | Text, _ -> (t, Fail "a message instead of the Pokemon's menu")
  | _ -> (t, Wait)

let withdrawing t species (l : look) : t * D.press =
  match l.view.screen with
  | Text -> (t, Fail "a message after WITHDRAW (the party is full?)")
  | (Box_grid | Overworld) when l.species = None && l.panel_empty = Some true ->
      go t (Leaving { species; overworld_seen = false }) B
  | _ -> (t, Wait)

let leaving t species ~overworld_seen (l : look) : t * D.press =
  match l.view.screen with
  | Overworld when overworld_seen -> (t, Done)
  | Overworld -> go t (Leaving { species; overworld_seen = true }) Wait
  | Other -> (t, Wait)
  | _ -> go t (Leaving { species; overworld_seen = false }) B

let on_screen t (l : look) =
  match t.phase with
  | Opening { booted; boot_looks } -> opening t ~booted ~boot_looks l
  | Browsing { slot; blank_looks } -> browsing t ~slot ~blank_looks l
  | Choosing species -> choosing t species l
  | Withdrawing species -> withdrawing t species l
  | Leaving { species; overworld_seen } -> leaving t species ~overworld_seen l

let next t (l : look) =
  match l.view.screen with
  | Other when t.others + 1 >= D.max_others ->
      ( t,
        D.Fail (Printf.sprintf "no PC screen settled in %d looks" D.max_others)
      )
  | Other -> ({ t with others = t.others + 1 }, D.Wait)
  | _ -> on_screen { t with others = 0 } l
