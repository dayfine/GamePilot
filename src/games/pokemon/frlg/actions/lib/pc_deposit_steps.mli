(** What a PC deposit presses on each screen it reads, from the overworld facing
    the PC to the overworld again with every member stored: the fork's PC dialog
    (Programs/AutoStory/PokemonFRLG_AutoStoryPcStorage.cpp, [frlg/lean]) for a
    DEPOSIT, pure so it runs in tests against looks made up by hand. Its bounds
    are the fork's (PokemonFRLG_AutoStoryPcRun.h: how many looks at a changing
    screen in a row, how many at the overworld after A).

    Where we differ: members are found by the species PKMN DATA shows under the
    hand, not by slot (DOWN until it shows, CANCEL fails); several in one visit;
    A is pressed only on a row whose label was read: the PC list's top row
    ("BILL'S PC" or "SOMEONE'S PC"), DEPOSIT POKéMON, and STORE on a Pokémon's
    menu, whose RELEASE is three rows below and never reached (the cursor is
    never moved there); the box is the first with room from the one the chooser
    opens on, RIGHT after "The BOX is full." (pokefirered's [Task_DepositMenu]
    prints it and waits for a key), where the fork names a box; a member holding
    Mail fails the deposit when the game says "Please remove the MAIL." over the
    party panel (pokefirered's [Task_DepositMenu] refuses it there) instead of
    choosing STORE again until the press bound runs out; on a message a wait
    first, B only when the next settled look reads a message too (the fork
    presses B on any message): "Which PC should be accessed?" is printed with no
    button wait and the PC list opens right behind it (pokefirered pc.inc:
    message, waitmessage, then the list), so a B on it can land as the list
    opens, cancel it and turn the PC off, as it did to {!Pc_box}'s walk on
    console B (2026-11-25). *)

type look = {
  view : Frlg_readers.Pc_screen.view;
  label : string option;  (** The text of the cursor's row, when read. *)
  species : string option;  (** PKMN DATA's species slug, on the party panel. *)
  box_full : bool;  (** "The BOX is full." over the box chooser. *)
  remove_mail : bool;
      (** "Please remove the MAIL." over the party panel: the member holds Mail.
      *)
}

(** The button a PC step presses next, a wait, or the walk done or failed (and
    why). *)
type press =
  | A
  | B
  | Up
  | Down
  | Left  (** Only in a withdraw ({!Pc_withdraw_steps}). *)
  | Right
  | Wait
  | Done
  | Fail of string

type t

val start : string list -> t
(** The species to deposit, in order. *)

val next : t -> look -> t * press

val deposited : t -> string list
(** The species stored so far, in order. *)

val pc_list_tops : string list
(** ["SOMEONE'S PC"; "BILL'S PC"]. *)

val deposit_row : string
(** ["DEPOSIT POKéMON"]. *)

val store_row : string
(** ["STORE"]. *)

val max_others : int
(** 10 looks in a row at a screen still changing: the fork's. *)

val boot_reads : int
(** 4 looks at the overworld after A at the PC: it did not boot. *)

val press_to_string : press -> string
