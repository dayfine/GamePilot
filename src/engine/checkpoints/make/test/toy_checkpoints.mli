(** The engine over the toy game's terms ({!Toy_terms}). *)

include module type of struct
  include Engine_checkpoints.Make (Toy_terms)
end
