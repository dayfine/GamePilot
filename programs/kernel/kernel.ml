(* The effect set programs may use. Handlers (real, replay, sim) live elsewhere. *)

type seq = int

type _ Effect.t += Now : float Effect.t

let now () = Effect.perform Now
