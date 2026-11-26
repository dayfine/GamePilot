(** Where one event of a running checkpoint is, as {!Runner.Make.run} reports it
    to whoever follows the run (the watch page's plan, the event states). *)

type 'reason t =
  | Started
  | Passed
  | Skipped of string
      (** the [skip_if] flag that held, or ["at its end"] when the checkpoint
          was already at its end ({!Runner.Make.run}) *)
  | Failed of 'reason
      (** why: a {!Log_line.Make.t} from the runner, its text once the engine
          prints it ([Program_engine]) *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** The same progress with its failure's reason mapped. *)
