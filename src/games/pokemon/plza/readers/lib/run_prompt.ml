let id = "run_prompt"

let area =
  Native_box.of_fractions
    { left = 0.004456; top = 0.635499; width = 0.065062; height = 0.077655 }

let probes ~picture ~assets =
  Button_detector.probe ~picture ~assets ~id Minus area

let shown m = Button_detector.shown m id Minus
