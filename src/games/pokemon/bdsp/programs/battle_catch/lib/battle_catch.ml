module BCS = Bdsp_actions.Battle_catch_steps
module CR = Pokemon_catch.Catch_runner
module Opts = Battle_catch_options

let caught_line target (s : CR.summary) =
  Printf.sprintf
    "bdsp.battle_catch: CAUGHT %s (turns=%d balls=%d switches=%d heals=%d)"
    target s.turns s.balls_thrown s.switches s.heals

let paused_line target reason (s : CR.summary) =
  Printf.sprintf "bdsp.battle_catch: paused on %s (%s; turns=%d balls=%d)"
    target reason s.turns s.balls_thrown

let format_outcome target = function
  | CR.Caught s -> (true, caught_line target s)
  | CR.Paused { reason; summary } -> (false, paused_line target reason summary)
  | CR.No_balls s ->
      ( false,
        Printf.sprintf "bdsp.battle_catch: out of balls on %s (thrown=%d)"
          target s.balls_thrown )
  | CR.Foe_ended s ->
      ( false,
        Printf.sprintf "bdsp.battle_catch: foe ended on %s (turns=%d)" target
          s.turns )
  | CR.Failed { reason; summary } ->
      ( false,
        Printf.sprintf "bdsp.battle_catch: failed on %s (%s; turns=%d)" target
          reason summary.turns )

let run_checked ~picture (cfg : Opts.t) =
  Effects.show_log ("Starting bdsp.battle_catch: " ^ Opts.format_summary cfg);
  let steps =
    BCS.make ~log:Effects.show_log
      {
        picture;
        initial_active_slot = cfg.lead_slot;
        bag = cfg.bag;
        timing = BCS.default_timing;
      }
  in
  CR.run steps cfg.policy |> format_outcome cfg.target

let run ~picture ?(options = Run_options.none) () =
  match Opts.of_run_options options with
  | Error e -> (false, "bdsp.battle_catch: invalid options: " ^ e)
  | Ok cfg -> run_checked ~picture cfg
