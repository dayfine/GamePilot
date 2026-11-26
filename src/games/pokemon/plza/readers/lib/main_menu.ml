let right_id = "main_menu_right"
let b_id = "main_menu_b"

let right_area =
  Native_box.of_fractions
    { left = 0.382; top = 0.081; width = 0.029; height = 0.056 }

let b_area =
  Native_box.of_fractions
    { left = 0.87; top = 0.940; width = 0.077; height = 0.044 }

let probes ~picture ~assets =
  Button_detector.probe ~picture ~assets ~id:right_id Right right_area
  @ Button_detector.probe ~picture ~assets ~id:b_id B b_area

type buttons = { right_arrow : bool; b_button : bool }

let buttons m =
  {
    right_arrow = Button_detector.shown m right_id Right;
    b_button = Button_detector.shown m b_id B;
  }

let shown m =
  let b = buttons m in
  b.right_arrow && b.b_button
