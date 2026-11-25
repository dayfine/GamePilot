(** The engine over the toy game ({!Toy_terms}, read by {!Toy_codec}, printed by
    {!Toy_text}, kept by {!Toy_saved}). *)

include module type of struct
  include Engine_checkpoints.Make (Toy_terms) (Toy_codec) (Toy_text) (Toy_saved)
end
