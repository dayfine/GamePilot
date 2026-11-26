(** Claiming one Mystery Gift, from the main menu back to the main menu
    ({!Mystery_gift}'s presses). An Internet gift: Mystery Gift, the Internet
    list, the gift found by its name and claimed; a code gift: Mystery Gift, the
    code keyboard, the code typed and its gift claimed. Then the screen is read
    up to 30 s, each read held 1 s:

    - the gift's card: received; A past it, then off the list (Internet: B, yes)
      and off the link ({!Mystery_gift.disconnect});
    - the "already received" screen ({!already_received}): counted as done, A
      past it;
    - anything else: an unknown screen. The frame is kept in the run folder as
      [gift-<id>-unknown-screen.png] and the gift is not received.

    A claim stopped on the Internet list (its gift not listed below the cursor,
    or not reached) leaves the list first, with B and yes to "stop receiving?",
    then the link ({!Mystery_gift.disconnect}): B alone there only opens that
    question and cancels it (console B, 2026-11-25).

    After anything but a card, the main menu is brought back with B (1.5 s),
    read for 1.5 s after each, 8 at most, the link left once on the way
    ({!Mystery_gift.disconnect} after the fourth B). Ours, not yet run on a
    console: the way back from a screen no reader knows. *)

(** How one claim came out. *)
type claim =
  | Received  (** Its card showed: the gift is the save's (not saved yet). *)
  | Already_received
      (** The game says the save already has it: counted as done. *)
  | Not_received of string
      (** Nothing claimed, or no card after the claim; why. Back on the main
          menu. *)
  | Lost of string
      (** No main menu after the claim or after the way back: the run cannot go
          on to the next gift. *)

val already_received : Effects.measurements -> bool
(** The hook for the game's "already received" screen: [false] on every frame
    until its reader is written from a console capture of that screen (none
    exists yet). A gift claimed twice therefore ends as an unknown screen today.
*)

val after_claim_read :
  log:(string -> unit) -> Plza_gift_catalog.Gift_catalog.gift -> claim
(** {!claim}'s second half, after the claim's A: the screen read as above (a
    card, already received, or an unknown screen, its frame kept and named in
    the log line with the gift screens' last readings), then the way back to the
    main menu. The probes must be subscribed ({!Mystery_gift.probes}). *)

val claim :
  log:(string -> unit) ->
  picture:Wire.box ->
  assets:Plza_readers.Blob_assets.t ->
  gift_name:string option ->
  Plza_gift_catalog.Gift_catalog.gift ->
  claim
(** One gift claimed as above, from the main menu. [gift_name]: the uploaded
    template of an Internet gift's name in the game's language; an Internet gift
    without one, a code gift without its code and a HOME gift are [Not_received]
    before any press. *)
