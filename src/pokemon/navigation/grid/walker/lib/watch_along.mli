(** A reader shown a hold's frames without letting it stop the hold, which keeps
    whether it fired. A warp's fade can be over before the hold onto the warp
    ends, so a wait for it that starts after the hold sees nothing: the walk
    watches the hold with this, then waits on with the same reader if it has not
    fired. *)

type t

val create : (Effects.measurements -> bool) -> t

val see : t -> Effects.measurements -> unit
(** Shows the frame to the reader, until the reader has fired once. *)

val fired : t -> bool
