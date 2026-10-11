module Presentation exposing (commun, disposition, marque, tableaux)

{-| Intention Matheval, composée dans le socle commun sans renderer applicatif.
-}

import MrJam
import MrJam.Contexte as Contexte
import MrJam.Disposition as Disposition
import MrJam.Tableaux as Tableaux


marque : Contexte.Contexte
marque =
    Contexte.pour "Matheval"


commun : MrJam.Interface valeur message
commun =
    MrJam.pour marque


disposition : Disposition.Interface message
disposition =
    Disposition.pour marque


tableaux : Tableaux.Interface ligne message
tableaux =
    Tableaux.pour marque
