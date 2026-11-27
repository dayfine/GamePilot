(** Standalone BDSP wild-battle catcher program ([bdsp.battle_catch]).

    GamePilot's own program wiring {!Battle_catch_options},
    {!Bdsp_actions.Battle_catch_steps}, and {!Pokemon_catch.Catch_runner} so a
    live battle (such as a parked shiny legendary from [bdsp.static_rng]) can be
    caught automatically without ever selecting Run. *)

val run : picture:Wire.box -> ?options:Run_options.t -> unit -> bool * string
(** Runs [bdsp.battle_catch] on the active BDSP battle screen using [picture]
    and checked [options]. Returns [(caught, summary_line)]. *)
