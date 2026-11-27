(** The ["wild_rng"] game action's decisions: with a party slot free, the
    capture on the blind RNG steps ({!Wild_rng_steps}), then the catch's
    summary, which must show the shiny star. Ported from the program loop in
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_WildRng.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source; reset and blind
    sequence, shiny check, catch).

    Where it differs: the fork checks for the shiny sound before catching and
    resets on a miss, calibrating from the miss's stats; here the target is
    caught first and its summary read (no audio), a miss fails the checkpoint
    (the runner retries from the start state, the catch unsaved), and there is
    no calibration: on mGBA the same timings land on the same frames. The catch
    goes to the party, where its summary can be read: a full party fails before
    the first press. *)

type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
      (** {!Capture.run} on the blind steps, from the overworld *)
  shiny_at : int -> bool;  (** the member in this slot shows the star *)
  log : string -> unit;
}

(** How the action ended. *)
type end_ =
  | Shiny  (** Caught, and its summary shows the star. *)
  | Not_shiny  (** Caught, but no star: the RNG missed its target. *)
  | Capture_ended of Capture.end_  (** anything but [All_caught] *)
  | Party_full  (** No slot for the catch, found before the first press. *)

type result = {
  end_ : end_;
  capture : Capture.result option;  (** [None] when the capture never ran. *)
}
(** The action's end and the capture's own result. *)

val run : game_steps -> Capture_plan.t -> party:int -> result
(** From the overworld with [party] members. *)

val failure_code : end_ -> string option
(** [None] for [Shiny]; else ["wild_rng_not_shiny"], ["wild_rng_<capture end>"],
    ["wild_rng_party_full"]. *)

val message : result -> string
(** One line for the run log saying how the action ended. *)
