port module Survey exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Dict exposing (Dict)
import Element as Interface
import Element.Region as Region
import Html exposing (Html)
import Json.Decode as D
import Json.Encode as E
import MrJam
import MrJam.Accessibilite as A
import MrJam.AxesSpatiaux as Axes
import MrJam.Curseurs as Notes
import MrJam.Disposition as Disposition
import MrJam.Ecran as Ecran
import MrJam.Espace as Espace
import MrJam.Identite as Identite
import MrJam.Lectures as Lectures
import MrJam.Manipulation as Manipulation
import MrJam.Mathematiques as Math
import MrJam.Transitions as T
import Presentation as P
import Survey.Model as S exposing (Answer, Point, Production, Question)
import Time


port reductionAnimations : (Bool -> msg) -> Sub msg


port action : E.Value -> Cmd msg


port incoming : (E.Value -> msg) -> Sub msg


type Mode
    = Setup
    | Running
    | Finished


type HelpTopic
    = WelcomeHelp
    | ReaderHelp
    | RatingHelp
    | AxesHelp


type alias HelpState =
    { enabled : Bool
    , introSeen : Bool
    , ratingSeen : Bool
    , axesSeen : Bool
    }


type alias Model =
    { mode : Mode
    , levels : List String
    , available : List String
    , questions : List Question
    , index : Int
    , selected : String
    , exposed : Dict String Int
    , answers : Dict String Answer
    , reader : Bool
    , closing : Bool
    , espace : Espace.Modele
    , axes : Dict String Axes.Modele
    , ecran : Ecran.Dimensions
    , lectureTransition : T.Transition Bool
    , apercuNote : Maybe Float
    , referenceQuestion : Float
    , compare : Bool
    , compareId : String
    , help : HelpState
    , helpTopic : Maybe HelpTopic
    , helpContinue : Bool
    , menuOpen : Bool
    , informations : Bool
    , quitterQuestion : Maybe Int
    , message : String
    , skipped : List String
    , version : String
    , saveStatus : String
    , saveMessage : String
    }


type Msg
    = ToggleLevel String Bool
    | Begin
    | Recharger
    | Receive E.Value
    | Grade String
    | ApercuNote (Maybe Float)
    | ReferenceQuestion (Result Browser.Dom.Error Float)
    | EspaceChange Espace.Message
    | AxeChange String Axes.Message
    | Redimensionner Ecran.Dimensions
    | FrameLecture Time.Posix
    | ReduireAnimations Bool
    | Close
    | Closed
    | Place String String Float Bool
    | Confirm
    | Open String
    | NextProduction
    | GoQuestion Int
    | Skip
    | Finish
    | Return
    | Submit
    | RetrySave
    | Restart
    | ToggleMenu
    | Informations
    | Accueil
    | ConfirmerQuestion
    | AnnulerQuestion
    | ShowHelp HelpTopic
    | HelpNext
    | SkipHelp
    | DismissHelp
    | ResetHelp
    | Escape
    | Compare
    | CompareWith String
    | NoOp


main : Program E.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions =
            \m ->
                Sub.batch
                    [ incoming Receive
                    , Ecran.changements Redimensionner
                    , T.abonnement FrameLecture m.lectureTransition
                    , reductionAnimations ReduireAnimations
                    , Browser.Events.onKeyDown
                        (D.map
                            (\key ->
                                if key == "Escape" then
                                    Escape

                                else
                                    NoOp
                            )
                            (D.field "key" D.string)
                        )
                    ]
        }


init : E.Value -> ( Model, Cmd Msg )
init flags =
    ( { mode = Setup
      , levels = []
      , available = D.decodeValue (D.field "levels" (D.list D.string)) flags |> Result.withDefault []
      , questions = []
      , index = 0
      , selected = ""
      , exposed = Dict.empty
      , answers = Dict.empty
      , reader = False
      , closing = False
      , espace = Espace.initialiser
      , axes = Dict.empty
      , ecran = { largeur = 390, hauteur = 844 }
      , lectureTransition = T.initialiser False |> T.reduire (D.decodeValue (D.field "reductionAnimations" D.bool) flags |> Result.withDefault False)
      , apercuNote = Nothing
      , referenceQuestion = 140
      , compare = False
      , compareId = ""
      , help = helpFromFlags flags
      , helpTopic = Nothing
      , helpContinue = False
      , menuOpen = False
      , informations = False
      , quitterQuestion = Nothing
      , message = ""
      , skipped = []
      , version = D.decodeValue (D.field "version" D.string) flags |> Result.withDefault ""
      , saveStatus = "idle"
      , saveMessage = ""
      }
    , Ecran.initiale Redimensionner
    )


defaultHelp : HelpState
defaultHelp =
    { enabled = True
    , introSeen = False
    , ratingSeen = False
    , axesSeen = False
    }


helpDecoder : D.Decoder HelpState
helpDecoder =
    D.map4 HelpState
        (D.oneOf [ D.field "enabled" D.bool, D.succeed True ])
        (D.oneOf [ D.field "introSeen" D.bool, D.succeed False ])
        (D.oneOf [ D.field "ratingSeen" D.bool, D.succeed False ])
        (D.oneOf [ D.field "axesSeen" D.bool, D.succeed False ])


helpFromFlags : E.Value -> HelpState
helpFromFlags flags =
    D.decodeValue (D.field "help" helpDecoder) flags |> Result.withDefault defaultHelp


encodeHelp : HelpState -> E.Value
encodeHelp help =
    E.object
        [ ( "enabled", E.bool help.enabled )
        , ( "introSeen", E.bool help.introSeen )
        , ( "ratingSeen", E.bool help.ratingSeen )
        , ( "axesSeen", E.bool help.axesSeen )
        ]


practice : Question
practice =
    { id = "practice"
    , level = "Entraînement"
    , domain = "Un essai pour prendre la main"
    , statement = "Un rectangle a un périmètre de $30$ cm. Sa longueur dépasse sa largeur de $3$ cm. Déterminer ses dimensions en justifiant."
    , productions = [ { id = "practice-1", content = "Notons $x$ la largeur, en centimètres. La longueur est $x+3$.\n\nLe périmètre donne $2x+2(x+3)=30$, donc $4x=24$ et $x=6$.\n\nLe rectangle mesure donc $6$ cm sur $9$ cm. Ces dimensions donnent bien un périmètre de $30$ cm." } ]
    }


current : Model -> Question
current m =
    List.drop m.index m.questions |> List.head |> Maybe.withDefault practice


chosen : Model -> Production
chosen m =
    List.filter (\v -> v.id == m.selected) (current m).productions |> List.head |> Maybe.withDefault { id = "", content = "" }


getAnswer : String -> Model -> Answer
getAnswer id m =
    Dict.get id m.answers |> Maybe.withDefault S.answer


number : String -> Model -> Int
number id m =
    List.indexedMap Tuple.pair (current m).productions |> List.filter (\( _, v ) -> v.id == id) |> List.head |> Maybe.map (Tuple.first >> (+) 1) |> Maybe.withDefault 1


emit : String -> List ( String, E.Value ) -> Cmd Msg
emit kind fields =
    action (E.object (( "type", E.string kind ) :: fields))


persistHelp : HelpState -> Cmd Msg
persistHelp help =
    emit "help-state" [ ( "state", encodeHelp help ) ]


firstProductionId : List Question -> String
firstProductionId questions =
    List.head questions
        |> Maybe.andThen (List.head << .productions)
        |> Maybe.map .id
        |> Maybe.withDefault ""


markHelp : HelpTopic -> HelpState -> HelpState
markHelp topic help =
    case topic of
        WelcomeHelp ->
            { help | introSeen = True }

        RatingHelp ->
            { help | ratingSeen = True }

        AxesHelp ->
            { help | axesSeen = True }

        ReaderHelp ->
            help


showHelp : HelpTopic -> Bool -> Model -> ( Model, Cmd Msg )
showHelp topic continue m =
    let
        nextHelp =
            markHelp topic m.help
    in
    ( { m | help = nextHelp, helpTopic = Just topic, helpContinue = continue, menuOpen = False }
    , persistHelp nextHelp
    )


hideHelp : Model -> Model
hideHelp m =
    { m | helpTopic = Nothing, helpContinue = False }


showRatingHelpIfNeeded : Model -> ( Model, Cmd Msg )
showRatingHelpIfNeeded m =
    if m.reader && m.help.enabled && not m.help.ratingSeen then
        showHelp RatingHelp False m

    else
        ( m, Cmd.none )


event : Model -> String -> List ( String, E.Value ) -> Cmd Msg
event m kind fields =
    if m.mode == Running then
        emit "event" (( "event", E.string kind ) :: ( "questionId", E.string (current m).id ) :: ( "productionId", E.string m.selected ) :: fields)

    else
        Cmd.none


{-| Une ouverture interrompt les gestes, sans transformer un aperçu en réponse
validée. Les positions de départ reviennent avant le checkpoint d'ouverture.
-}
annulerGestes : Model -> Model
annulerGestes m =
    let
        annuler axe modele ( answers, modes ) =
            let
                resultat =
                    Axes.actualiser (reserveAxes m) m.selected (poignees axe m) (Axes.Terminer True) modele

                nouvelles =
                    case resultat.proposition of
                        Just ( id, valeur, _ ) ->
                            let
                                ancienne =
                                    Dict.get id answers |> Maybe.withDefault S.answer
                            in
                            Dict.insert id { ancienne | point = S.move axe valeur ancienne.point } answers

                        Nothing ->
                            answers
            in
            ( nouvelles, Dict.insert axe resultat.modele modes )

        ( reponsesAnnulees, gestesAnnules ) =
            Dict.foldl annuler ( m.answers, Dict.empty ) m.axes

        espace =
            m.espace
    in
    { m | answers = reponsesAnnulees, axes = gestesAnnules, espace = { espace | geste = Nothing } }


openQuestion : Int -> Model -> Model
openQuestion idx m =
    let
        base =
            annulerGestes m

        q =
            List.drop idx m.questions |> List.head |> Maybe.withDefault practice

        first =
            List.head q.productions |> Maybe.map .id |> Maybe.withDefault ""
    in
    { base | index = idx, selected = first, reader = True, closing = False, compare = False, message = "", quitterQuestion = Nothing, exposed = Dict.insert q.id (List.length q.productions) m.exposed }


avancer : Model -> ( Model, Cmd Msg )
avancer m =
    if m.index + 1 < List.length m.questions then
        updateCore (GoQuestion (m.index + 1)) m

    else
        updateCore Finish m


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    let
        ( changement, command ) =
            updateCore msg m

        nouveauLecteur =
            changement.reader && (not m.reader || changement.selected /= m.selected)

        next =
            if nouveauLecteur then
                { changement | lectureTransition = m.lectureTransition |> T.aller 0 False |> T.aller 220 True, apercuNote = Nothing }

            else if not changement.reader then
                { changement | lectureTransition = T.aller 0 False changement.lectureTransition, apercuNote = Nothing }

            else
                changement

        persist =
            case msg of
                Receive raw ->
                    D.decodeValue (D.field "type" D.string) raw |> Result.map (\kind -> List.member kind [ "session", "closed", "orbit" ]) |> Result.withDefault False

                Place _ _ _ committed ->
                    committed

                EspaceChange _ ->
                    False

                AxeChange _ (Axes.Terminer annule) ->
                    not annule

                AxeChange _ (Axes.Clavier _ _ _) ->
                    True

                AxeChange _ _ ->
                    False

                ApercuNote _ ->
                    False

                ReferenceQuestion _ ->
                    False

                Redimensionner _ ->
                    False

                FrameLecture _ ->
                    False

                ReduireAnimations _ ->
                    False

                NoOp ->
                    False

                Submit ->
                    False

                RetrySave ->
                    False

                _ ->
                    True
    in
    ( next
    , Cmd.batch
        [ command
        , if nouveauLecteur then
            Cmd.batch [ Lectures.reinitialiser (\_ -> NoOp), Lectures.mesurerReference "question-panel" ReferenceQuestion ]

          else
            Cmd.none
        , if persist && next.mode /= Setup && next.saveStatus /= "completed" then
            emit "checkpoint" [ ( "snapshot", encodeSnapshot next ) ]

          else
            Cmd.none
        ]
    )


encodeSnapshot : Model -> E.Value
encodeSnapshot m =
    E.object
        [ ( "answers", E.object (Dict.toList m.answers |> List.filter (\( k, _ ) -> not (String.startsWith "practice" k)) |> List.map (Tuple.mapSecond S.encodeAnswer)) )
        , ( "skippedQuestions", E.list E.string m.skipped )
        , ( "progress"
          , E.object
                [ ( "mode"
                  , E.string
                        (if m.mode == Finished then
                            "finished"

                         else
                            "running"
                        )
                  )
                , ( "index", E.int m.index )
                , ( "selected", E.string m.selected )
                , ( "exposed", E.object (Dict.toList m.exposed |> List.map (Tuple.mapSecond E.int)) )
                , ( "reader", E.bool m.reader )
                , ( "tour", E.int -1 )
                ]
          )
        ]


updateCore : Msg -> Model -> ( Model, Cmd Msg )
updateCore msg m =
    case msg of
        EspaceChange changement ->
            if m.reader then
                case changement of
                    Espace.Mesurer _ ->
                        ( { m | espace = (Espace.actualiser changement m.espace).modele }, Cmd.none )

                    _ ->
                        ( m, Cmd.none )

            else
                let
                    resultat =
                        Espace.actualiser changement m.espace

                    prochain =
                        { m | espace = resultat.modele }
                in
                case resultat.ouvrir of
                    Just id ->
                        updateCore (Open id) prochain

                    Nothing ->
                        ( prochain
                        , if resultat.tourne then
                            event m "orbit" []

                          else
                            Cmd.none
                        )

        AxeChange axe changement ->
            if m.reader then
                case changement of
                    Axes.Mesurer _ ->
                        let
                            resultat =
                                Axes.actualiser (reserveAxes m) m.selected (poignees axe m) changement (Dict.get axe m.axes |> Maybe.withDefault Axes.initialiser)
                        in
                        ( { m | axes = Dict.insert axe resultat.modele m.axes }, Cmd.none )

                    _ ->
                        ( m, Cmd.none )

            else
                let
                    resultat =
                        Axes.actualiser (reserveAxes m) m.selected (poignees axe m) changement (Dict.get axe m.axes |> Maybe.withDefault Axes.initialiser)

                    prochain =
                        { m | axes = Dict.insert axe resultat.modele m.axes }
                in
                case resultat.proposition of
                    Just ( id, valeur, validee ) ->
                        updateCore (Place id axe valeur validee) prochain

                    Nothing ->
                        case resultat.ouvrir of
                            Just id ->
                                updateCore (Open id) prochain

                            Nothing ->
                                ( prochain, Cmd.none )

        ApercuNote note ->
            ( { m | apercuNote = note }, Cmd.none )

        ReferenceQuestion resultat ->
            ( { m | referenceQuestion = Result.withDefault m.referenceQuestion resultat }, Cmd.none )

        Redimensionner dimensions ->
            ( { m | ecran = dimensions }
            , if m.mode == Running then
                Lectures.mesurerReference "question-panel" ReferenceQuestion

              else
                Cmd.none
            )

        FrameLecture maintenant ->
            ( { m | lectureTransition = T.mettreAJour maintenant m.lectureTransition }, Cmd.none )

        ReduireAnimations reduite ->
            ( { m | lectureTransition = T.reduire reduite m.lectureTransition }, Cmd.none )

        ToggleLevel level checked ->
            ( { m
                | levels =
                    if checked then
                        level :: m.levels

                    else
                        List.filter ((/=) level) m.levels
                , message = ""
              }
            , Cmd.none
            )

        Recharger ->
            ( m, emit "recharger" [] )

        Begin ->
            if List.isEmpty m.levels then
                ( { m | message = "Choisissez au moins un niveau pour continuer." }, Cmd.none )

            else
                ( m, emit "session" [ ( "levels", E.list E.string m.levels ) ] )

        Receive raw ->
            case D.decodeValue (D.field "type" D.string) raw of
                Ok "save-state" ->
                    ( { m | saveStatus = D.decodeValue (D.field "status" D.string) raw |> Result.withDefault "error", saveMessage = D.decodeValue (D.field "message" D.string) raw |> Result.withDefault "" }, Cmd.none )

                Ok "error" ->
                    ( { m | message = D.decodeValue (D.field "message" D.string) raw |> Result.withDefault "La connexion est indisponible.", saveStatus = "error" }, Cmd.none )

                Ok "restore" ->
                    let
                        field name decoder =
                            D.decodeValue (D.at [ "snapshot", name ] decoder) raw

                        progress name decoder fallback =
                            D.decodeValue (D.at [ "snapshot", "progress", name ] decoder) raw |> Result.withDefault fallback

                        restoredMode =
                            progress "mode" D.string "training"

                        qs =
                            D.decodeValue (D.field "questions" (D.list S.decodeQuestion)) raw |> Result.withDefault []

                        selectedSnapshot =
                            progress "selected" D.string ""

                        selectedProduction =
                            if List.any (\q -> List.any (\p -> p.id == selectedSnapshot) q.productions) qs then
                                selectedSnapshot

                            else
                                firstProductionId qs

                        restored =
                            { m
                                | questions = qs
                                , levels = D.decodeValue (D.field "levels" (D.list D.string)) raw |> Result.withDefault []
                                , version = D.decodeValue (D.field "bankVersion" D.string) raw |> Result.withDefault m.version
                                , answers = field "answers" (D.dict S.decodeAnswer) |> Result.withDefault Dict.empty
                                , skipped = field "skippedQuestions" (D.list D.string) |> Result.withDefault []
                                , index = progress "index" D.int 0
                                , selected = selectedProduction
                                , exposed = progress "exposed" (D.dict D.int) Dict.empty
                                , reader =
                                    if restoredMode == "training" then
                                        False

                                    else
                                        progress "reader" D.bool False
                                , mode =
                                    if restoredMode == "finished" then
                                        Finished

                                    else
                                        Running
                                , saveStatus = D.decodeValue (D.field "saveStatus" D.string) raw |> Result.withDefault "saved"
                            }
                    in
                    if restored.mode == Running && restored.reader then
                        showRatingHelpIfNeeded restored

                    else if restored.mode == Running && restored.help.enabled && not restored.help.introSeen then
                        showHelp WelcomeHelp True restored

                    else
                        ( restored, Cmd.none )

                Ok "session" ->
                    case D.decodeValue (D.field "questions" (D.list S.decodeQuestion)) raw of
                        Ok qs ->
                            if List.isEmpty qs then
                                ( { m | message = "Aucune question disponible pour cette sélection." }, Cmd.none )

                            else
                                let
                                    question =
                                        List.head qs |> Maybe.withDefault practice

                                    started =
                                        { m
                                            | questions = qs
                                            , mode = Running
                                            , selected = firstProductionId qs
                                            , exposed = Dict.singleton question.id (List.length question.productions)
                                            , answers = Dict.empty
                                            , reader = True
                                            , closing = False
                                            , index = 0
                                            , skipped = []
                                            , version = D.decodeValue (D.field "bankVersion" D.string) raw |> Result.withDefault m.version
                                        }
                                in
                                if started.help.enabled && not started.help.introSeen then
                                    showHelp WelcomeHelp True started

                                else
                                    showRatingHelpIfNeeded started

                        Err _ ->
                            ( { m | message = "Impossible de préparer les questions." }, Cmd.none )

                Ok "export" ->
                    ( m, emit "export" [] )

                Ok "closed" ->
                    updateCore Closed m

                Ok "orbit" ->
                    ( m, event m "orbit" [] )

                _ ->
                    ( m, Cmd.none )

        Grade str ->
            case String.toFloat str of
                Just n ->
                    let
                        a =
                            getAnswer m.selected m

                        grade =
                            toFloat (round (clamp 0 3 n * 4)) / 4

                        next =
                            { a | note = Just grade }
                    in
                    if a.note == Just grade then
                        ( m, Cmd.none )

                    else
                        ( { m
                            | answers = Dict.insert m.selected next m.answers
                            , message = ""
                            , helpTopic =
                                if m.helpTopic == Just RatingHelp then
                                    Nothing

                                else
                                    m.helpTopic
                            , helpContinue =
                                if m.helpTopic == Just RatingHelp then
                                    False

                                else
                                    m.helpContinue
                          }
                        , event m "grade" [ ( "value", E.float grade ), ( "initial", E.bool (a.initialNote == Nothing) ) ]
                        )

                Nothing ->
                    ( m, Cmd.none )

        Close ->
            if m.compare then
                ( { m | compare = False }, Cmd.none )

            else if not m.reader || m.closing then
                ( m, Cmd.none )

            else
                let
                    a =
                        getAnswer m.selected m

                    rated =
                        { a
                            | initialNote =
                                if a.initialNote == Nothing then
                                    a.note

                                else
                                    a.initialNote
                        }
                in
                updateCore Closed { m | answers = Dict.insert m.selected rated m.answers }

        Closed ->
            let
                next =
                    { m
                        | reader = False
                        , closing = False
                        , message = ""
                    }
            in
            if next.help.enabled && not next.help.axesSeen then
                let
                    ( withHelp, helpCommand ) =
                        showHelp AxesHelp False next
                in
                ( withHelp, Cmd.batch [ event m "close" [], helpCommand ] )

            else
                ( next
                , event m "close" []
                )

        Place id axis value committed ->
            let
                a =
                    getAnswer id m

                valid =
                    List.any (\v -> v.id == id) (current m).productions

                next =
                    { a
                        | point = S.move axis value a.point
                        , judged =
                            if committed then
                                S.touchAxis axis a.judged

                            else
                                a.judged
                    }
            in
            if valid && List.member axis [ "x", "y", "z" ] && not m.reader then
                ( { m
                    | answers = Dict.insert id next m.answers
                    , selected = id
                    , message = ""
                    , helpTopic =
                        if committed && axis == "x" && m.helpTopic == Just AxesHelp then
                            Nothing

                        else
                            m.helpTopic
                    , helpContinue =
                        if committed && axis == "x" && m.helpTopic == Just AxesHelp then
                            False

                        else
                            m.helpContinue
                  }
                , if committed then
                    event { m | selected = id } "place" [ ( "axis", E.string axis ), ( "coordinates", S.encodePoint next.point ) ]

                  else
                    Cmd.none
                )

            else
                ( m, Cmd.none )

        Confirm ->
            let
                a =
                    getAnswer m.selected m
            in
            if not m.reader then
                ( { m | answers = Dict.insert m.selected { a | judged = [ "x", "y", "z" ] } m.answers, message = "" }
                , event m "confirm-position" [ ( "coordinates", S.encodePoint a.point ) ]
                )

            else
                ( m, Cmd.none )

        Open id ->
            if List.any (\v -> v.id == id) (current m).productions then
                let
                    base =
                        annulerGestes m

                    next =
                        { base
                            | selected = id
                            , reader = True
                            , closing = False
                            , message = ""
                        }

                    ( withHelp, helpCommand ) =
                        showRatingHelpIfNeeded next
                in
                ( withHelp
                , Cmd.batch [ event { m | selected = id } "open" [], helpCommand ]
                )

            else
                ( m, Cmd.none )

        NextProduction ->
            if S.complete m.answers (current m) then
                avancer m

            else
                ( { m | quitterQuestion = Just (m.index + 1), menuOpen = False }, Cmd.none )

        ConfirmerQuestion ->
            case m.quitterQuestion of
                Just idx ->
                    if idx == m.index + 1 then
                        avancer { m | quitterQuestion = Nothing }

                    else
                        updateCore (GoQuestion idx) { m | quitterQuestion = Nothing }

                Nothing ->
                    ( m, Cmd.none )

        AnnulerQuestion ->
            ( { m | quitterQuestion = Nothing }, Cmd.none )

        GoQuestion idx ->
            if idx >= 0 && idx < List.length m.questions then
                let
                    next =
                        openQuestion idx m

                    ( withHelp, helpCommand ) =
                        showRatingHelpIfNeeded next
                in
                ( withHelp, Cmd.batch [ event withHelp "question" [], helpCommand ] )

            else
                ( m, Cmd.none )

        Skip ->
            updateCore NextProduction m

        Finish ->
            ( hideHelp { m | mode = Finished, reader = False }, event m "finish" [] )

        Return ->
            ( { m | mode = Running, reader = False }, Cmd.none )

        Restart ->
            ( { m | mode = Setup, reader = False, message = "", saveStatus = "idle", saveMessage = "" }, emit "restart" [] )

        Submit ->
            ( { m | saveStatus = "submitting", saveMessage = "" }, emit "submit" [ ( "snapshot", encodeSnapshot m ) ] )

        RetrySave ->
            ( m, emit "retry-save" [] )

        ToggleMenu ->
            ( { m | menuOpen = not m.menuOpen }, Cmd.none )

        Informations ->
            ( { m | informations = not m.informations, menuOpen = False }, Cmd.none )

        Accueil ->
            ( hideHelp { m | mode = Setup, reader = False, menuOpen = False }, Cmd.none )

        ShowHelp topic ->
            showHelp topic False m

        HelpNext ->
            case m.helpTopic of
                Just WelcomeHelp ->
                    if m.helpContinue && m.reader && m.help.enabled && not m.help.ratingSeen then
                        showHelp RatingHelp False (hideHelp m)

                    else
                        ( hideHelp m, Cmd.none )

                _ ->
                    ( hideHelp m, Cmd.none )

        SkipHelp ->
            let
                nextHelp =
                    { enabled = False
                    , introSeen = True
                    , ratingSeen = m.help.ratingSeen
                    , axesSeen = m.help.axesSeen
                    }
            in
            ( { m | help = nextHelp, helpTopic = Nothing, helpContinue = False }, persistHelp nextHelp )

        DismissHelp ->
            if m.helpTopic == Just WelcomeHelp then
                updateCore HelpNext m

            else
                ( hideHelp m, Cmd.none )

        ResetHelp ->
            showHelp WelcomeHelp True { m | help = defaultHelp }

        Escape ->
            if m.quitterQuestion /= Nothing then
                updateCore AnnulerQuestion m

            else if m.informations then
                updateCore Informations m

            else if m.menuOpen then
                updateCore ToggleMenu m

            else if m.helpTopic /= Nothing then
                updateCore DismissHelp m

            else
                updateCore Close m

        Compare ->
            let
                other =
                    (current m).productions |> List.filter (\v -> v.id /= m.selected) |> List.head |> Maybe.map .id |> Maybe.withDefault m.selected
            in
            ( { m | compare = True, compareId = other }, event m "compare" [] )

        CompareWith id ->
            ( { m | compareId = id }, Cmd.none )

        NoOp ->
            ( m, Cmd.none )


repere : String -> Interface.Attribute msg
repere =
    Manipulation.test


blocRiche : String -> Interface.Element Msg
blocRiche contenu =
    Math.document contenu


view : Model -> Html Msg
view m =
    P.disposition.cadre []
        (Interface.column [ Interface.width (Interface.maximum 1380 Interface.fill), Interface.centerX, Interface.padding 12, Interface.spacing 12 ]
            [ Interface.el [ Interface.width Interface.fill, Region.navigation, repere "topbar" ]
                (Disposition.bandeau
                    (if m.mode == Setup then
                        "Critères d’évaluations en mathématiques"

                     else
                        "Regards"
                    )
                    (if m.mode == Setup then
                        []

                     else
                        [ P.disposition.boutonMenu "help-menu" m.menuOpen ToggleMenu ]
                    )
                )
            , Interface.el [ Interface.width Interface.fill, Region.mainContent ]
                (case m.mode of
                    Setup ->
                        viewSetup m

                    Finished ->
                        viewFinish m

                    Running ->
                        viewWorkspace m
                )
            , if m.mode == Setup then
                Interface.none

              else if m.reader then
                Interface.none

              else
                viewSaveNotice m
            , if m.menuOpen then
                viewMenu m

              else
                Interface.none
            , if m.informations then
                Disposition.dialoguePour P.marque
                    "informations"
                    "Ma participation"
                    "Fermer"
                    Informations
                    [ MrJam.paragraphe "Ce questionnaire fonctionne sans compte personnel, sans mot de passe et sans adresse électronique."
                    , MrJam.paragraphe ("Niveaux sélectionnés : " ++ String.join ", " m.levels)
                    , MrJam.paragraphe "Les notes, les positions et les interactions sont conservées sous un identifiant aléatoire. La reprise est mémorisée sur cet appareil."
                    , P.commun.boutonSecondaire "Télécharger mes réponses" (Receive (E.object [ ( "type", E.string "export" ) ]))
                    ]

              else
                Interface.none
            , case m.quitterQuestion of
                Just _ ->
                    Disposition.dialoguePour P.marque
                        "question-incomplete"
                        "Évaluations incomplètes"
                        "Rester"
                        AnnulerQuestion
                        [ MrJam.paragraphe "Certaines rédactions n’ont pas de note ou leurs trois repères n’ont pas tous été évalués. Voulez-vous passer à la suite ? Vous pourrez revenir."
                        , P.commun.bouton "Passer quand même" ConfirmerQuestion
                        ]

                Nothing ->
                    Interface.none
            , Identite.piedDePage
            , if m.reader && m.mode == Running then
                viewReader m

              else
                Interface.none
            , if m.compare && m.mode == Running then
                viewCompare m (current m).productions

              else
                Interface.none
            , if m.mode /= Setup && (not m.reader || m.helpTopic == Just WelcomeHelp) then
                viewHelp m

              else
                Interface.none
            ]
        )


viewMenu : Model -> Interface.Element Msg
viewMenu _ =
    Disposition.dialoguePour P.marque
        "help-menu"
        "Menu"
        "Fermer"
        ToggleMenu
        [ P.commun.boutonSecondaire "Accueil" Accueil
        , P.commun.boutonSecondaire "Ma participation et mes informations" Informations
        , P.commun.lien "Mon compte administrateur" "admin/"
        , P.commun.boutonSecondaire "Accéder à l’aide" (ShowHelp WelcomeHelp)
        , P.commun.boutonSecondaire "Réinitialiser l’aide" ResetHelp
        ]


viewSetup : Model -> Interface.Element Msg
viewSetup m =
    MrJam.pile
        [ MrJam.paragraphe "Ce sondage fait partie d’un projet de recherche qui cherche à mettre en lumière les critères que les enseignantes et enseignants de mathématiques exploitent pour noter leurs élèves."
        , P.commun.avis MrJam.Information "Vos réponses et vos interactions sont enregistrées pour cette recherche sous un identifiant aléatoire, sans compte personnel. Vous pouvez reprendre sur ce navigateur. Les résultats sont accessibles uniquement à l’équipe de recherche."
        , if not (List.isEmpty m.questions) then
            P.commun.bouton "Reprendre ma participation" Return

          else
            P.commun.section "Quels niveaux avez-vous enseignés ?"
                (List.map
                    (\niveau ->
                        P.commun.caseACocher
                            (case niveau of
                                "Sup 1" ->
                                    "Études supérieures"

                                "1re spé" ->
                                    "1re"

                                "Tle spé" ->
                                    "Tle"

                                _ ->
                                    niveau
                            )
                            (List.member niveau m.levels)
                            (ToggleLevel niveau)
                    )
                    m.available
                    ++ [ if List.isEmpty m.available then
                            P.commun.bouton "Réessayer" Recharger

                         else
                            P.commun.bouton "Commencer" Begin
                       , if m.message == "" then
                            Interface.none

                         else
                            P.commun.avis MrJam.Erreur m.message
                       ]
                )
        ]


viewWorkspace : Model -> Interface.Element Msg
viewWorkspace m =
    let
        q =
            current m

        shown =
            q.productions

        a =
            getAnswer m.selected m

        done =
            List.filter (S.complete m.answers) m.questions |> List.length

        nomSuivant =
            if m.index + 1 == List.length m.questions then
                "Terminer la session"

            else
                "Énoncé suivant"
    in
    Interface.column
        [ Interface.width Interface.fill
        , Interface.spacing
            (if largeAxes m then
                12

             else
                8
            )
        , repere "workspace"
        ]
        [ P.disposition.panneau [ repere "question-panel", A.identifiant "question-panel" ]
            [ Interface.wrappedRow [ Interface.spacing 12, repere "question-meta" ]
                [ P.commun.texteSecondaire ("Question " ++ String.fromInt (m.index + 1) ++ " / " ++ String.fromInt (List.length m.questions)), P.disposition.etiquette q.level ]
            , blocRiche q.statement
            , P.disposition.progression "Progression de la session" (100 * toFloat done / toFloat (Basics.max 1 (List.length m.questions)))
            ]
        , Interface.wrappedRow [ Interface.width Interface.fill, Interface.spacing 8, repere "production-strip", Region.description "Toutes les rédactions" ]
            (List.map (\v -> P.disposition.boutonSelection (v.id == m.selected) ("Rédaction " ++ String.fromInt (number v.id m)) (Open v.id)) shown)
        , viewEvaluation m shown a
        , MrJam.actions
            [ if List.length shown > 1 then
                P.commun.boutonSecondaire "Comparer" Compare

              else
                Interface.none
            , P.disposition.boutonIdentifie "next-production" nomSuivant (Just NextProduction)
            ]
        , MrJam.actions
            [ if m.index == 0 then
                P.commun.boutonInactif "← Question précédente"

              else
                P.commun.boutonSecondaire "← Question précédente" (GoQuestion (m.index - 1))
            ]
        , Interface.el [ A.etat ]
            (P.commun.texteSecondaire
                (if m.message /= "" then
                    m.message

                 else
                    ""
                )
            )
        ]


largeAxes : Model -> Bool
largeAxes m =
    m.ecran.largeur >= 900 || (m.ecran.largeur >= 760 && m.ecran.largeur > m.ecran.hauteur)


reserveAxes : Model -> Float
reserveAxes m =
    if largeAxes m then
        42

    else
        0


poignees : String -> Model -> List Axes.Poignee
poignees axe m =
    List.map
        (\v ->
            let
                a =
                    getAnswer v.id m

                valeur =
                    case axe of
                        "x" ->
                            a.point.x

                        "y" ->
                            a.point.y

                        _ ->
                            a.point.z
            in
            { id = v.id, numero = number v.id m, valeur = valeur, attente = not (List.member axe a.judged) }
        )
        (current m).productions


viewEvaluation : Model -> List Production -> Answer -> Interface.Element Msg
viewEvaluation m shown a =
    let
        large =
            largeAxes m

        panneauAxes =
            P.disposition.panneau
                [ repere "axes-panel"
                , A.identifiant "axes-panel"
                , Region.description "Placer les rédactions sur les trois axes"
                , Interface.width
                    (if large then
                        Interface.px 300

                     else
                        Interface.fill
                    )
                , Interface.paddingXY 12
                    (if large then
                        14

                     else
                        4
                    )
                , Interface.alignTop
                , Interface.spacing
                    (if large then
                        16

                     else
                        4
                    )
                ]
                [ if large then
                    P.commun.texteSecondaire ("Vos repères · Rédaction " ++ String.fromInt (number m.selected m))

                  else
                    Interface.none
                , if m.helpTopic == Just AxesHelp then
                    Lectures.aide P.marque m.ecran "Placer la rédaction" "Déplacez les trois curseurs pour situer cette rédaction sur les trois axes." "Compris" DismissHelp

                  else
                    Interface.none
                , Interface.column [ Interface.width Interface.fill, Interface.spacing 2, repere "axis-sliders" ]
                    (List.map
                        (\( axe, negatif, positif ) ->
                            Axes.vue P.marque
                                axe
                                (if axe == "x" then
                                    "Lisibilité"

                                 else if axe == "y" then
                                    "Précision"

                                 else
                                    "Validité"
                                )
                                negatif
                                positif
                                (reserveAxes m)
                                (Dict.get axe m.axes |> Maybe.withDefault Axes.initialiser)
                                m.selected
                                m.reader
                                (AxeChange axe)
                                Open
                                (poignees axe m)
                        )
                        S.axes
                    )
                , Interface.el [ Interface.width Interface.fill, Interface.height (Interface.minimum 44 Interface.shrink) ]
                    (if List.length a.judged < 3 then
                        P.disposition.boutonIdentifie "confirm-position" "Conserver cette position" (Just Confirm)

                     else
                        P.commun.texteSecondaire "Les trois repères sont placés"
                    )
                ]

        objets =
            List.map
                (\v ->
                    let
                        reponse =
                            getAnswer v.id m
                    in
                    { identifiant = v.id, numero = number v.id m, contenu = v.content, point = reponse.point, attente = List.length reponse.judged < 3 }
                )
                shown

        hauteur =
            if large then
                if m.ecran.hauteur < 600 then
                    320

                else
                    450

            else
                clamp 350 650 (round (toFloat m.ecran.hauteur * 0.55))

        scene =
            Espace.vue 0 hauteur m.espace m.selected m.reader S.axes EspaceChange Open objets

        disposition =
            if large then
                Interface.row

            else
                Interface.column
    in
    disposition
        [ Interface.width Interface.fill
        , Interface.spacing
            (if large then
                20

             else
                8
            )
        , repere "evaluation-layout"
        , Interface.alignTop
        ]
        [ panneauAxes, scene ]


viewReader : Model -> Interface.Element Msg
viewReader m =
    let
        a =
            getAnswer m.selected m

        aide =
            case m.helpTopic of
                Just ReaderHelp ->
                    Lectures.aide P.marque m.ecran "Lire et noter" "Lisez les rédactions dans l’ordre de votre choix. Vous pouvez noter, fermer et revenir à tout moment. Les trois axes s’évaluent indépendamment de la note." "Fermer" DismissHelp

                Just RatingHelp ->
                    Lectures.aide P.marque m.ecran "Attribuer une note" "Déplacez ce curseur pour évaluer la production." "Compris" DismissHelp

                _ ->
                    Interface.none
    in
    Lectures.vue P.marque
        m.ecran
        m.referenceQuestion
        m.lectureTransition
        { identifiant = m.selected
        , titre = "Rédaction " ++ String.fromInt (number m.selected m)
        , fermer = Close
        , actions =
            [ Interface.el [ A.identifiant "reader-help-button" ] (P.disposition.boutonIcone "Aide sur la fiche de rédaction" "?" (ShowHelp ReaderHelp))
            , P.disposition.boutonIcone "Fermer la rédaction" "×" Close
            ]
        , contenu = Math.document (chosen m).content
        , commandes =
            [ aide
            , Interface.column [ Interface.width (Interface.maximum 640 Interface.fill), Interface.spacing 4, A.identifiant "rating" ]
                [ MrJam.paragraphe "Quelle note lui donneriez-vous ?"
                , Notes.note P.marque a.note m.apercuNote (String.fromFloat >> Grade) ApercuNote
                , Interface.el [ A.identifiant "grade-help" ]
                    (P.commun.texteSecondaire
                        (if a.note == Nothing then
                            "Note facultative. Vous pouvez fermer et revenir."

                         else
                            "Vous pourrez revenir sur cette note."
                        )
                    )
                ]
            , P.disposition.boutonIdentifie "validate-reading" "Fermer" (Just Close)
            , if m.message == "" then
                Interface.none

              else
                P.commun.avis MrJam.Erreur m.message
            , viewSaveNotice m
            ]
        }


viewCompare : Model -> List Production -> Interface.Element Msg
viewCompare m shown =
    let
        other =
            List.filter (\v -> v.id == m.compareId) shown |> List.head |> Maybe.withDefault (chosen m)
    in
    Disposition.dialoguePour P.marque
        "comparison"
        "Comparer les rédactions"
        "Fermer la comparaison"
        Close
        [ Interface.wrappedRow [ Interface.width Interface.fill, Interface.spacing 20, repere "comparison-columns" ]
            [ Interface.column [ Interface.width (Interface.minimum 240 Interface.fill), Interface.spacing 16 ] [ MrJam.sousTitre ("Rédaction " ++ String.fromInt (number m.selected m)), blocRiche (chosen m).content ]
            , Interface.column [ Interface.width (Interface.minimum 240 Interface.fill), Interface.spacing 16 ]
                [ P.commun.selecteur "Choisir la rédaction à comparer" (List.map (\v -> ( v.id, "Rédaction " ++ String.fromInt (number v.id m) )) shown) other.id CompareWith
                , blocRiche other.content
                ]
            ]
        ]


viewHelp : Model -> Interface.Element Msg
viewHelp m =
    case m.helpTopic of
        Nothing ->
            Interface.none

        Just WelcomeHelp ->
            Disposition.dialoguePour P.marque
                "help-dialog"
                "Comment se déroule l’évaluation ?"
                "Fermer l’aide"
                DismissHelp
                [ P.commun.texteSecondaire "Une aide quand vous en avez besoin"
                , MrJam.paragraphe "Vous allez être amené à juger des rédactions mathématiques, à leur attribuer une note, puis à les situer sur trois axes : lisibilité, précision et validité."
                , P.commun.texteSecondaire "Vous pourrez revenir sur vos choix à tout moment."
                , MrJam.actions
                    [ P.commun.boutonSecondaire "Passer l’aide" SkipHelp
                    , P.commun.bouton
                        (if m.helpContinue then
                            "Suivant"

                         else
                            "Fermer"
                        )
                        HelpNext
                    ]
                ]

        _ ->
            Interface.none


viewFinish : Model -> Interface.Element Msg
viewFinish m =
    let
        done =
            List.filter (S.complete m.answers) m.questions |> List.length

        pluriel =
            if done > 1 then
                "s"

            else
                ""
    in
    MrJam.pile
        [ Interface.el [ repere "finish-panel-mrjam" ]
            (P.commun.section "Merci pour votre regard"
                [ MrJam.paragraphe (String.fromInt done ++ " question" ++ pluriel ++ " entièrement évaluée" ++ pluriel ++ " sur " ++ String.fromInt (List.length m.questions) ++ ".")
                , P.commun.texteSecondaire
                    (if m.saveStatus == "completed" then
                        "Vos réponses ont bien été reçues. Merci pour votre participation."

                     else
                        "Vous pouvez encore revoir vos réponses, puis valider votre participation."
                    )
                , if m.saveStatus == "completed" then
                    P.commun.boutonSecondaire "Nouvelle participation" Restart

                  else
                    MrJam.actions
                        [ if m.saveStatus == "submitting" then
                            P.commun.boutonEnCours "Validation en cours…"

                          else
                            P.commun.bouton "Valider ma participation" Submit
                        , if m.saveStatus == "submitting" || m.saveStatus == "submit-error" then
                            P.commun.boutonInactif "Revenir aux questions"

                          else
                            P.commun.boutonSecondaire "Revenir aux questions" Return
                        ]
                ]
            )
        ]


viewSaveNotice : Model -> Interface.Element Msg
viewSaveNotice m =
    Interface.column [ Interface.width Interface.fill, Interface.spacing 8, repere "save-status", A.etat, A.compagnon ]
        [ P.commun.texteSecondaire
            (if m.saveMessage /= "" then
                m.saveMessage

             else if m.saveStatus == "completed" then
                "Participation enregistrée et validée."

             else if m.saveStatus == "saved" then
                "Réponses enregistrées."

             else if m.saveStatus == "error" || m.saveStatus == "submit-error" then
                "Enregistrement en attente. Vos réponses sont conservées sur cet appareil."

             else
                "Enregistrement en cours…"
            )
        , if m.saveStatus == "error" || m.saveStatus == "submit-error" then
            P.commun.boutonSecondaire "Réessayer l’enregistrement" RetrySave

          else
            Interface.none
        ]
