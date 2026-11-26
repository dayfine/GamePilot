open Descriptor

(* plza's icon is cut from console B's capture of that page
   (core/switch_home/test/images/delete-save/za-page-delete-save-data-for-user.png). *)
let game =
  {
    game_id = "plza";
    game_name = "Pokémon Legends: Z-A";
    delete_save_icons =
      [ ("plza", "src/games/pokemon/plza/assets/delete-save-icon.png") ];
    switch_home = None;
  }

let autostory =
  {
    id = "plza.autostory";
    game;
    name = "AutoStory";
    group = [ "PLZA"; "Story" ];
    description = "Plays the story from a new game, checkpoint by checkpoint.";
    doc = "docs/guide/plza.autostory.md";
    checkpoints = Some "src/games/pokemon/plza/programs/autostory/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_story;
    options = Plza_story.New_game_choices.decls;
  }

let claim_gifts =
  {
    id = "plza.claim-gifts";
    game;
    name = "Claim Gifts";
    group = [ "PLZA"; "Gifts" ];
    description =
      "Claims the Mystery Gifts of its catalog that have not expired, puts \
       their Pokémon in the Boxes and saves.";
    doc = "docs/guide/plza.claim-gifts.md";
    checkpoints = Some "src/games/pokemon/plza/programs/claim_gifts/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_gifts;
    options =
      [
        {
          key = "language";
          value = One_of Plza_story.New_game_choices.tags;
          presence = Default "en";
          doc =
            "the game's language, by its language list's tag, in which the \
             Internet gifts' names are found in their list";
        };
      ];
  }

let bank_home =
  {
    id = "plza.bank-home";
    game;
    name = "Bank in HOME";
    group = [ "PLZA"; "Pokémon HOME" ];
    description =
      "Moves the claimed gifts from the game's box into their Pokémon HOME \
       boxes and saves HOME.";
    doc = "docs/guide/plza.bank-home.md";
    checkpoints = Some "src/games/pokemon/plza/programs/bank_home/plans";
    backends = [ Switch ];
    viewport = Native;
    rules = Plza_home;
    options = [];
  }

let all = [ autostory; claim_gifts; bank_home ]
