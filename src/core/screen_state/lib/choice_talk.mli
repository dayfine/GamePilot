(** A talk pressed through to its Yes/No question, one look at a time: each look
    gives one move. Ported from the fork's PLZA scene machine with the choice as
    its goal (PokemonLZA_AutoStorySceneMachine: [SceneTimeline::classify],
    [scene_screen_action], [SceneMashGoal::CHOICE]): a choice box is the goal
    and gets a deliberate pick, never a blind A; a page of text gets the talk
    button; anything else is waited on. As the fork's [ScreenObservation], a
    choice box is also a text box, so the choice is looked at first.

    Where it differs: the screen the pick leads to ({!look.past_choice}) also
    ends the talk once one of our presses has gone in, since that press can land
    on the box as it draws and take its default (on console B a frame shows the
    game 160-335 ms late). The fork's machine sees the choice before pressing
    on, so it has no such rule. *)

type look = {
  choice : bool;  (** the choice box shows, its cursor read *)
  page : bool;  (** a page of text waits for the talk button *)
  past_choice : bool;  (** the screen the default answer leads to *)
}

type move =
  | Pick  (** answer the choice deliberately: cursor read, then confirm *)
  | Next_page  (** press the talk button *)
  | Answered  (** a press of ours took the default answer: done *)
  | Wait  (** look again *)

val move : pressed:bool -> look -> move
(** The move for a look; [pressed]: a talk-button press of ours has gone in
    since the talk began. *)
