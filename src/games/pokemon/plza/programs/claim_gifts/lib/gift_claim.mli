(** Claiming one Mystery Gift, from the main menu back to the main menu
    ({!Mystery_gift}'s presses). An Internet gift: Mystery Gift, the Internet
    list, the gift found by its name and claimed; a code gift: Mystery Gift, the
    code keyboard, the code typed and its gift claimed, or, when the game says
    the code was used before (the info card after its +,
    {!Plza_readers.Info_card}), already received with no claim. Then the screen
    is read up to 30 s, each read held 1 s:

    - the gift's card: received;
    - the info card, the "received before" message ({!already_received}):
      already received;
    - anything else: an unknown screen. The frame is kept in the run folder as
      [gift-<id>-unknown-screen.png] and the gift is not received.

    Then, as after a claim stopped short of its A (its gift not listed, the list
    not shown, ...), back to the main menu, each press read first
    ({!Leave_gifts}): no A on the gift list but the claim's own. *)

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
(** The game's info card after the claim's A, taken for its message that the
    gift was received before ({!Plza_readers.Info_card}: read by its layout, in
    any language). *)

val after_claim_read :
  log:(string -> unit) -> Plza_gift_catalog.Gift_catalog.gift -> claim
(** {!claim}'s second half, after the claim's A: the screen read as above (a
    card, already received, or an unknown screen, its frame kept and named in
    the log line with the gift screens' last readings), then the way back to the
    main menu ({!Leave_gifts}). The probes must be subscribed
    ({!Mystery_gift.probes}). *)

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
