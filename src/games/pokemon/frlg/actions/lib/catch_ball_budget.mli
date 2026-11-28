(** Gen 3 capture ball budget calculator.

    Computes how many Poké Balls to carry for a wild capture at 99% cumulative
    catch probability using the Generation III (FireRed/LeafGreen) catch
    formula, given a species' base catch rate, the ball's catch-rate multiplier,
    and the catching strategy's HP/status assumption. Pure. *)

(** HP and status assumption for the catching strategy. *)
type catch_mode =
  | Throw_only
      (** Throws balls directly at full HP with no status condition (HP factor
          [1/3], status multiplier [1.0]). *)
  | Weakened_asleep
      (** False Swipe to 1 HP plus Sleep, as in [phase1] and [phase2] catch
          policies (HP factor [1.0], status multiplier [2.0]). *)

val catch_rate : string -> int option
(** Gen 3 base catch rate (3..255) for a FRLG species slug (e.g. ["oddish"],
    ["growlithe"], ["zapdos"]), or [None] if the species is not in the table. *)

val ball_multiplier : string -> float option
(** Gen 3 catch-rate multiplier for a ball slug: [1.0] for ["poke-ball"] and
    ["luxury-ball"], [1.5] for ["great-ball"], [2.0] for ["ultra-ball"], and
    [None] for ["master-ball"] or unknown balls. *)

val catch_probability :
  catch_rate:int -> ball:string -> mode:catch_mode -> float option
(** Single-ball catch probability in [[0.0, 1.0]] from the Gen 3 formula, or
    [None] if [ball] is unsupported. Returns [Some 1.0] for ["master-ball"] or
    when the modified catch rate reaches 255. *)

val balls_for_rate :
  catch_rate:int -> ball:string -> mode:catch_mode -> int option
(** Minimum ball count for at least 99% cumulative catch probability, clamped to
    [[5, 99]] for standard balls, or [Some 1] for ["master-ball"]. Returns
    [None] for an unknown ball slug. *)

val required : species:string -> ball:string -> mode:catch_mode -> int option
(** {!balls_for_rate} for a species slug, returning [Some 1] for ["master-ball"]
    regardless of species, or [None] when the species is not in {!catch_rate} or
    [ball] is unknown. *)

val catch_mode_of_string : string option -> catch_mode
(** Parses an optional plan ["catch_mode"] arg: ["phase1"] and ["phase2"] map to
    {!Weakened_asleep}; [None], ["throw_only"], or any other value maps to
    {!Throw_only}. *)
