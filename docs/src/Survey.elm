port module Survey exposing (main)

import Browser
import Browser.Events
import Dict exposing (Dict)
import Element as Interface
import Element.Region as Region
import Html exposing (Html, button, div, h1, h2, header, input, label, main_, p, section, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onCheck, onClick, onInput)
import Json.Decode as D
import Json.Encode as E
import MrJam
import MrJam.Disposition as Disposition
import MrJam.Identite as Identite
import Survey.Model as S exposing (Answer, Point, Production, Question)


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
    | Receive E.Value
    | Grade String
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
            \_ ->
                Sub.batch
                    [ incoming Receive
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
    , Cmd.none
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


openQuestion : Int -> Model -> Model
openQuestion idx m =
    let
        q =
            List.drop idx m.questions |> List.head |> Maybe.withDefault practice

        first =
            List.head q.productions |> Maybe.map .id |> Maybe.withDefault ""
    in
    { m | index = idx, selected = first, reader = True, closing = False, compare = False, message = "", quitterQuestion = Nothing, exposed = Dict.insert q.id (List.length q.productions) m.exposed }


avancer : Model -> ( Model, Cmd Msg )
avancer m =
    if m.index + 1 < List.length m.questions then
        updateCore (GoQuestion (m.index + 1)) m

    else
        updateCore Finish m


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    let
        ( next, command ) =
            updateCore msg m

        persist =
            case msg of
                Receive raw ->
                    D.decodeValue (D.field "type" D.string) raw |> Result.map (\kind -> List.member kind [ "session", "closed", "orbit" ]) |> Result.withDefault False

                Place _ _ _ committed ->
                    committed

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
                ( { m | closing = True, answers = Dict.insert m.selected rated m.answers }, emit "close" [ ( "id", E.string m.selected ) ] )

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
                    next =
                        { m
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


rich : String -> Html Msg
rich content =
    Html.node "rich-text" [ attribute "content" content ] []


repere : String -> Interface.Attribute message
repere nom =
    Interface.htmlAttribute (class nom)


blocRiche : String -> Interface.Element Msg
blocRiche contenu =
    Interface.el [ Interface.width Interface.fill ] (Interface.html (rich contenu))


view : Model -> Html Msg
view m =
    Disposition.cadre []
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
                        [ Disposition.boutonMenu "help-menu" m.menuOpen ToggleMenu ]
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

              else
                Interface.column [ Interface.width Interface.fill, Interface.spacing 8, repere "save-status", Interface.htmlAttribute (attribute "role" "status"), Interface.htmlAttribute (attribute "aria-live" "polite"), Interface.htmlAttribute (attribute "data-status" m.saveStatus), Interface.htmlAttribute (attribute "data-mrjam-compagnon" "") ]
                    [ MrJam.texteSecondaire
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
                        MrJam.boutonSecondaire "Réessayer l’enregistrement" RetrySave

                      else
                        Interface.none
                    ]
            , if m.menuOpen then
                viewMenu m

              else
                Interface.none
            , if m.informations then
                Disposition.dialogue "informations"
                    "Ma participation"
                    "Fermer"
                    Informations
                    [ MrJam.paragraphe "Ce questionnaire fonctionne sans compte personnel, sans mot de passe et sans adresse électronique."
                    , MrJam.paragraphe ("Niveaux sélectionnés : " ++ String.join ", " m.levels)
                    , MrJam.paragraphe "Les notes, les positions et les interactions sont conservées sous un identifiant aléatoire. La reprise est mémorisée sur cet appareil."
                    , MrJam.boutonSecondaire "Télécharger mes réponses" (Receive (E.object [ ( "type", E.string "export" ) ]))
                    ]

              else
                Interface.none
            , case m.quitterQuestion of
                Just _ ->
                    Disposition.dialogue "question-incomplete"
                        "Évaluations incomplètes"
                        "Rester"
                        AnnulerQuestion
                        [ MrJam.paragraphe "Certaines rédactions n’ont pas de note ou leurs trois repères n’ont pas tous été évalués. Voulez-vous passer à la suite ? Vous pourrez revenir."
                        , MrJam.bouton "Passer quand même" ConfirmerQuestion
                        ]

                Nothing ->
                    Interface.none
            , Identite.piedDePage
            , if m.reader && m.mode == Running then
                Interface.html (viewReader m)

              else
                Interface.none
            , if m.compare && m.mode == Running then
                viewCompare m (current m).productions

              else
                Interface.none
            , if m.mode /= Setup then
                viewHelp m

              else
                Interface.none
            ]
        )


viewMenu : Model -> Interface.Element Msg
viewMenu _ =
    Disposition.dialogue "help-menu"
        "Menu"
        "Fermer"
        ToggleMenu
        [ MrJam.boutonSecondaire "Accueil" Accueil
        , MrJam.boutonSecondaire "Ma participation et mes informations" Informations
        , MrJam.lien "Mon compte administrateur" "admin/"
        , MrJam.boutonSecondaire "Accéder à l’aide" (ShowHelp WelcomeHelp)
        , MrJam.boutonSecondaire "Réinitialiser l’aide" ResetHelp
        ]


viewSetup : Model -> Interface.Element Msg
viewSetup m =
    MrJam.pile
        [ MrJam.paragraphe "Ce sondage fait partie d’un projet de recherche qui cherche à mettre en lumière les critères que les enseignantes et enseignants de mathématiques exploitent pour noter leurs élèves."
        , MrJam.avis MrJam.Information "Vos réponses et vos interactions sont enregistrées pour cette recherche sous un identifiant aléatoire, sans compte personnel. Vous pouvez reprendre sur ce navigateur. Les résultats sont accessibles uniquement à l’équipe de recherche."
        , if not (List.isEmpty m.questions) then
            MrJam.bouton "Reprendre ma participation" Return

          else
            MrJam.section "Quels niveaux avez-vous enseignés ?"
                (List.map
                    (\niveau ->
                        MrJam.caseACocher
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
                    ++ [ MrJam.bouton "Commencer" Begin
                       , if m.message == "" then
                            Interface.none

                         else
                            MrJam.avis MrJam.Erreur m.message
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
    Interface.column [ Interface.width Interface.fill, Interface.spacing 12, repere "workspace" ]
        [ Disposition.panneau [ repere "question-panel", Interface.htmlAttribute (id "question-panel") ]
            [ Interface.wrappedRow [ Interface.spacing 12, repere "question-meta" ]
                [ MrJam.texteSecondaire ("Question " ++ String.fromInt (m.index + 1) ++ " / " ++ String.fromInt (List.length m.questions)), Disposition.etiquette q.level ]
            , blocRiche q.statement
            , Disposition.progression "Progression de la session" (100 * toFloat done / toFloat (Basics.max 1 (List.length m.questions)))
            ]
        , Interface.wrappedRow [ Interface.width Interface.fill, Interface.spacing 8, repere "production-strip", Interface.htmlAttribute (attribute "aria-label" "Toutes les rédactions") ]
            (List.map (\v -> Disposition.boutonSelection (v.id == m.selected) ("Rédaction " ++ String.fromInt (number v.id m)) (Open v.id)) shown)
        , Interface.html
            (div [ class "evaluation-layout" ]
                [ Disposition.fragment
                    (Disposition.panneau [ repere "axes-panel", Interface.htmlAttribute (id "axes-panel"), Interface.htmlAttribute (attribute "aria-label" "Placer les rédactions sur les trois axes") ]
                        [ Interface.el [ repere "axes-heading" ] (MrJam.texteSecondaire ("Vos repères · Rédaction " ++ String.fromInt (number m.selected m)))
                        , Interface.column [ Interface.width Interface.fill, Interface.spacing 4, repere "axis-sliders" ]
                            (List.map
                                (\( axis, _, _ ) ->
                                    Interface.html
                                        (Html.node "axis-slider"
                                            [ id ("axis-" ++ axis)
                                            , attribute "axis" axis
                                            , attribute "payload" (spacePayload m shown)
                                            , on "placement" (D.map4 Place (D.at [ "detail", "id" ] D.string) (D.at [ "detail", "axis" ] D.string) (D.at [ "detail", "value" ] D.float) (D.at [ "detail", "committed" ] D.bool))
                                            , on "read" (D.map Open (D.at [ "detail", "id" ] D.string))
                                            ]
                                            []
                                        )
                                )
                                S.axes
                            )
                        , Interface.el [ Interface.width Interface.fill, Interface.height (Interface.minimum 44 Interface.shrink) ]
                            (if List.length a.judged < 3 then
                                Disposition.boutonIdentifie "confirm-position"
                                    "Conserver cette position"
                                    (Just Confirm)

                             else
                                Interface.el [ Interface.centerY ] (MrJam.texteSecondaire "Les trois repères sont placés")
                            )
                        ]
                    )
                , Html.node "evaluation-space"
                    [ id "space"
                    , attribute "payload" (spacePayload m shown)
                    , on "read" (D.map Open (D.at [ "detail", "id" ] D.string))
                    , on "orbit" (D.succeed (Receive (E.object [ ( "type", E.string "orbit" ) ])))
                    ]
                    []
                ]
            )
        , MrJam.actions
            [ if List.length shown > 1 then
                MrJam.boutonSecondaire "Comparer" Compare

              else
                Interface.none
            , Disposition.boutonIdentifie "next-production" nomSuivant (Just NextProduction)
            ]
        , MrJam.actions
            [ if m.index == 0 then
                MrJam.boutonInactif "← Question précédente"

              else
                MrJam.boutonSecondaire "← Question précédente" (GoQuestion (m.index - 1))
            ]
        , Interface.el [ Interface.htmlAttribute (attribute "role" "status") ]
            (MrJam.texteSecondaire
                (if m.message /= "" then
                    m.message

                 else
                    ""
                )
            )
        ]


spacePayload : Model -> List Production -> String
spacePayload m shown =
    E.encode 0
        (E.object
            [ ( "selected", E.string m.selected )
            , ( "reader", E.bool m.reader )
            , ( "question", E.string (current m).id )
            , ( "points"
              , E.list
                    (\v ->
                        let
                            a =
                                getAnswer v.id m
                        in
                        E.object [ ( "id", E.string v.id ), ( "number", E.int (number v.id m) ), ( "content", E.string v.content ), ( "point", S.encodePoint a.point ), ( "judged", E.list E.string a.judged ), ( "graded", E.bool (a.note /= Nothing) ) ]
                    )
                    shown
              )
            ]
        )


viewReader : Model -> Html Msg
viewReader m =
    let
        a =
            getAnswer m.selected m
    in
    div [ class "reader-layer" ]
        [ div [ class "reader-backdrop", onClick Close ] []
        , Html.node "reading-card"
            [ class "reader", id "reading-card", attribute "production-id" m.selected, attribute "role" "dialog", attribute "aria-modal" "true", attribute "aria-labelledby" "reader-title", attribute "data-mrjam-dialogue" "", tabindex -1 ]
            [ Disposition.fragment
                (Interface.wrappedRow [ Interface.width Interface.fill, Interface.spacing 8, repere "reader-header" ]
                    [ Interface.el [ Interface.width Interface.fill, Interface.htmlAttribute (id "reader-title") ] (MrJam.sousTitre ("Rédaction " ++ String.fromInt (number m.selected m)))
                    , Interface.row [ Interface.width Interface.shrink, Interface.spacing 8 ]
                        [ Interface.el [ Interface.htmlAttribute (id "reader-help-button") ] (Disposition.boutonIcone "Aide sur la fiche de rédaction" "?" (ShowHelp ReaderHelp))
                        , Disposition.boutonIcone "Fermer la rédaction" "×" Close
                        ]
                    ]
                )
            , div [ class "reader-content", onClick Close ] [ rich (chosen m).content ]
            , Disposition.fragment
                (Interface.column [ Interface.width Interface.fill, Interface.spacing 8, repere "reader-footer" ]
                    [ Interface.column [ Interface.width (Interface.maximum 640 Interface.fill), Interface.spacing 4, Interface.htmlAttribute (id "rating") ]
                        [ MrJam.paragraphe "Quelle note lui donneriez-vous ?"
                        , Interface.html
                            (div [ class "grade-track" ]
                                [ span [] [ text "0" ]
                                , Html.node "grade-slider"
                                    [ attribute "value" (Maybe.withDefault 1.5 a.note |> String.fromFloat)
                                    , attribute "ungraded"
                                        (if a.note == Nothing then
                                            "true"

                                         else
                                            "false"
                                        )
                                    ]
                                    [ input [ id "grade", type_ "range", Html.Attributes.min "0", Html.Attributes.max "3", step "0.25", value (Maybe.withDefault 1.5 a.note |> String.fromFloat), onInput Grade, on "change" (D.map Grade (D.at [ "target", "value" ] D.string)), classList [ ( "ungraded", a.note == Nothing ) ], attribute "aria-label" "Note sur 3", attribute "aria-describedby" "grade-help" ] [] ]
                                , span [] [ text "3" ]
                                ]
                            )
                        , Interface.el [ Interface.htmlAttribute (id "grade-help") ]
                            (MrJam.texteSecondaire
                                (if a.note == Nothing then
                                    "Note facultative. Vous pouvez fermer et revenir."

                                 else
                                    "Vous pourrez revenir sur cette note."
                                )
                            )
                        ]
                    , Disposition.boutonIdentifie "validate-reading"
                        "Fermer"
                        (if m.closing then
                            Nothing

                         else
                            Just Close
                        )
                    , if m.message == "" then
                        Interface.none

                      else
                        MrJam.avis MrJam.Erreur m.message
                    ]
                )
            ]
        ]


viewCompare : Model -> List Production -> Interface.Element Msg
viewCompare m shown =
    let
        other =
            List.filter (\v -> v.id == m.compareId) shown |> List.head |> Maybe.withDefault (chosen m)
    in
    Disposition.dialogue "comparison"
        "Comparer les rédactions"
        "Fermer la comparaison"
        Close
        [ Interface.wrappedRow [ Interface.width Interface.fill, Interface.spacing 20, repere "comparison-columns" ]
            [ Interface.column [ Interface.width (Interface.minimum 240 Interface.fill), Interface.spacing 16 ] [ MrJam.sousTitre ("Rédaction " ++ String.fromInt (number m.selected m)), blocRiche (chosen m).content ]
            , Interface.column [ Interface.width (Interface.minimum 240 Interface.fill), Interface.spacing 16 ]
                [ MrJam.selecteur "Choisir la rédaction à comparer" (List.map (\v -> ( v.id, "Rédaction " ++ String.fromInt (number v.id m) )) shown) other.id CompareWith
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
            Disposition.dialogue "help-dialog"
                "Comment se déroule l’évaluation ?"
                "Fermer l’aide"
                DismissHelp
                [ MrJam.texteSecondaire "Une aide quand vous en avez besoin"
                , MrJam.paragraphe "Vous allez être amené à juger des rédactions mathématiques, à leur attribuer une note, puis à les situer sur trois axes : lisibilité, précision et validité."
                , MrJam.texteSecondaire "Vous pourrez revenir sur vos choix à tout moment."
                , MrJam.actions
                    [ MrJam.boutonSecondaire "Passer l’aide" SkipHelp
                    , MrJam.bouton
                        (if m.helpContinue then
                            "Suivant"

                         else
                            "Fermer"
                        )
                        HelpNext
                    ]
                ]

        Just ReaderHelp ->
            contextHelp "reader-help-button" "Lire et noter" "Lisez les rédactions dans l’ordre de votre choix. Vous pouvez noter, fermer et revenir à tout moment. Les trois axes s’évaluent indépendamment de la note." "Fermer"

        Just RatingHelp ->
            contextHelp "rating" "Attribuer une note" "Déplacez ce curseur pour évaluer la production." "Compris"

        Just AxesHelp ->
            contextHelp "axis-x" "Placer la rédaction" "Déplacez les trois curseurs pour situer cette rédaction sur les trois axes." "Compris"


contextHelp : String -> String -> String -> String -> Interface.Element Msg
contextHelp cible titre contenu fermeture =
    Interface.html
        (Html.node "context-help"
            [ class "context-help", attribute "target" ("#" ++ cible), attribute "data-mrjam-compagnon" "" ]
            [ Disposition.fragment (Disposition.panneau [ repere "context-help-card" ] [ MrJam.sousTitre titre, MrJam.paragraphe contenu, MrJam.boutonSecondaire fermeture DismissHelp ]) ]
        )


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
        [ Interface.el [ Interface.htmlAttribute (class "finish-panel-mrjam") ]
            (MrJam.section "Merci pour votre regard"
                [ MrJam.paragraphe (String.fromInt done ++ " question" ++ pluriel ++ " entièrement évaluée" ++ pluriel ++ " sur " ++ String.fromInt (List.length m.questions) ++ ".")
                , MrJam.texteSecondaire
                    (if m.saveStatus == "completed" then
                        "Vos réponses ont bien été reçues. Merci pour votre participation."

                     else
                        "Vous pouvez encore revoir vos réponses, puis valider votre participation."
                    )
                , if m.saveStatus == "completed" then
                    MrJam.boutonSecondaire "Nouvelle participation" Restart

                  else
                    MrJam.actions
                        [ if m.saveStatus == "submitting" then
                            MrJam.boutonEnCours "Validation en cours…"

                          else
                            MrJam.bouton "Valider ma participation" Submit
                        , if m.saveStatus == "submitting" || m.saveStatus == "submit-error" then
                            MrJam.boutonInactif "Revenir aux questions"

                          else
                            MrJam.boutonSecondaire "Revenir aux questions" Return
                        ]
                ]
            )
        ]
