module S = Frlg_readers.Pc_screen

type look = {
  view : S.view;
  label : string option;
  species : string option;
  box_full : bool;
  remove_mail : bool;
}

type press = A | B | Up | Down | Left | Right | Wait | Done | Fail of string

type t = {
  targets : string list;  (** Still to store, the next first. *)
  stored : string list;  (** Newest first. *)
  booted : bool;
  boot_looks : int;
  others : int;
  storing : bool;  (** A on the chooser, the store not yet seen. *)
  next_box : bool;  (** The box was full: RIGHT once the question is back. *)
  boxes : int;
  message_seen : bool;  (** The last settled look read a message: B now. *)
  saw_mail : bool;  (** A slot for the current target held Mail. *)
  skip_mail : bool;  (** Just dismissed Mail dialog: DOWN past this slot. *)
}

let pc_list_tops = [ "SOMEONE'S PC"; "BILL'S PC" ]
let deposit_row = "DEPOSIT POKéMON"
let store_row = "STORE"
let max_others = 10
let boot_reads = 4
let box_count = 14
let last_slot = 5

let start targets =
  {
    targets;
    stored = [];
    booted = false;
    boot_looks = 0;
    others = 0;
    storing = false;
    next_box = false;
    boxes = 0;
    message_seen = false;
    saw_mail = false;
    skip_mail = false;
  }

let deposited t = List.rev t.stored
let finished t = t.targets = []

let settled t (v : S.view) =
  match v.screen with
  | Other -> false
  | Party_panel -> finished t || v.cursor <> None
  | _ -> true

let overworld t =
  if finished t then (t, Done)
  else if not t.booted then ({ t with booted = true }, A)
  else if t.boot_looks + 1 < boot_reads then
    ({ t with boot_looks = t.boot_looks + 1 }, Wait)
  else (t, Fail "the overworld came back before the deposit")

let label_is l (look : look) = look.label = Some l

let pc_list t (look : look) =
  match look.view.cursor with
  | _ when finished t -> (t, B)
  | Some c when c > 0 -> (t, Up)
  | _ when List.exists (fun l -> label_is l look) pc_list_tops -> (t, A)
  | _ -> (t, Fail "the PC list's top row did not read as a storage PC")

(* DEPOSIT is row 1; the menu wraps: the shorter way round. *)
let storage_menu t (look : look) =
  match look.view.cursor with
  | _ when finished t -> (t, B)
  | None -> (t, Fail "the storage menu's cursor did not read")
  | Some 1 when label_is deposit_row look -> (t, A)
  | Some 1 -> (t, Fail "the storage menu's row 2 did not read as DEPOSIT")
  | Some c -> (t, if c = 0 then Down else Up)

let holds_mail target =
  target
  ^ " holds Mail: the game will not store it (\"Please remove the MAIL.\")"

let party_panel t (look : look) =
  let t =
    if t.storing then
      {
        t with
        storing = false;
        stored = List.hd t.targets :: t.stored;
        targets = List.tl t.targets;
        saw_mail = false;
        skip_mail = false;
      }
    else t
  in
  match (t.targets, look.view.cursor) with
  | _ :: _, _ when look.remove_mail ->
      ({ t with saw_mail = true; skip_mail = true }, B)
  | [], _ -> (t, B)
  | _ :: _, Some c when t.skip_mail && c < last_slot ->
      ({ t with skip_mail = false }, Down)
  | target :: _, _ when t.skip_mail -> (t, Fail (holds_mail target))
  | target :: _, Some _ when look.species = Some target -> (t, A)
  | _ :: _, Some c when c < last_slot -> (t, Down)
  | target :: _, _ when t.saw_mail -> (t, Fail (holds_mail target))
  | target :: _, _ -> (t, Fail ("no " ^ target ^ " in the party panel"))

let mon_menu t (look : look) =
  if finished t then (t, B)
  else if look.view.cursor = Some 0 && label_is store_row look then (t, A)
  else (t, Fail "the Pokemon's menu is not on STORE")

let box_chooser t (look : look) =
  if look.box_full then ({ t with storing = false; next_box = true }, B)
  else if t.storing then (t, Wait)
  else if t.next_box then
    if t.boxes + 1 >= box_count then (t, Fail "every box is full")
    else ({ t with next_box = false; boxes = t.boxes + 1 }, Right)
  else ({ t with storing = true }, A)

(* B on a message only at the second look in a row: one still printing can
   have a menu right behind it ("Which PC should be accessed?", pokefirered
   pc.inc: message, waitmessage, then the list), and a B that lands as the
   list opens cancels it and turns the PC off (#244, console B,
   2026-11-25). *)
let on_message t =
  let t = { t with boot_looks = boot_reads } in
  if t.message_seen then ({ t with message_seen = false }, B)
  else ({ t with message_seen = true }, Wait)

let on_screen t (look : look) =
  match look.view.screen with
  | Overworld -> overworld t
  | Text -> on_message t
  | Pc_list -> pc_list t look
  | Storage_menu -> storage_menu t look
  | Party_panel -> party_panel t look
  | Mon_menu -> mon_menu t look
  | Box_chooser -> box_chooser t look
  | Yes_no when finished t -> (t, B)
  | Yes_no -> (t, Fail "a YES/NO before the deposit")
  | Box_grid -> (t, Fail "the box grid opened for a deposit")
  | Other -> (t, Wait)

let next t (look : look) =
  if settled t look.view then
    let message_seen = t.message_seen && look.view.screen = Text in
    on_screen { t with others = 0; message_seen } look
  else if t.others + 1 >= max_others then
    (t, Fail (Printf.sprintf "no PC screen settled in %d looks" max_others))
  else ({ t with others = t.others + 1 }, Wait)

let press_to_string = function
  | A -> "A"
  | B -> "B"
  | Up -> "UP"
  | Down -> "DOWN"
  | Left -> "LEFT"
  | Right -> "RIGHT"
  | Wait -> "wait"
  | Done -> "done"
  | Fail why -> "fail: " ^ why
