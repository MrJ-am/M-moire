port module Survey exposing (main)

import Browser
import Browser.Events
import Dict exposing (Dict)
import Html exposing (Html, button, div, h1, h2, header, input, label, main_, p, section, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onCheck, onClick, onInput)
import Json.Decode as D
import Json.Encode as E
import Survey.Model as S exposing (Answer, Point, Production, Question)


port action : E.Value -> Cmd msg


port incoming : (E.Value -> msg) -> Sub msg


type Mode
    = Setup
    | Training
    | Running
    | Finished


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
    , tour : Int
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
    | Help
    | TourNext
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
                                    Close

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
      , tour = -1
      , message = ""
      , skipped = []
      , version = D.decodeValue (D.field "version" D.string) flags |> Result.withDefault ""
      , saveStatus = "idle"
      , saveMessage = ""
      }
    , Cmd.none
    )


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
    if m.mode == Training then
        practice

    else
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
    { m | index = idx, selected = first, reader = True, closing = False, compare = False, message = "", exposed = Dict.update q.id (\old -> Just (Maybe.withDefault 1 old)) m.exposed }


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
                [ ( "mode", E.string (if m.mode == Training then "training" else if m.mode == Finished then "finished" else "running") )
                , ( "index", E.int m.index )
                , ( "selected", E.string m.selected )
                , ( "exposed", E.object (Dict.toList m.exposed |> List.map (Tuple.mapSecond E.int)) )
                , ( "reader", E.bool m.reader )
                , ( "tour", E.int m.tour )
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
                    in
                    ( { m
                        | questions = qs
                        , levels = D.decodeValue (D.field "levels" (D.list D.string)) raw |> Result.withDefault []
                        , version = D.decodeValue (D.field "bankVersion" D.string) raw |> Result.withDefault m.version
                        , answers = field "answers" (D.dict S.decodeAnswer) |> Result.withDefault Dict.empty
                        , skipped = field "skippedQuestions" (D.list D.string) |> Result.withDefault []
                        , index = progress "index" D.int 0
                        , selected = if restoredMode == "training" then "practice-1" else progress "selected" D.string ""
                        , exposed = progress "exposed" (D.dict D.int) Dict.empty
                        , reader = if restoredMode == "training" then True else progress "reader" D.bool False
                        , mode = if restoredMode == "training" then Training else if restoredMode == "finished" then Finished else Running
                        , tour = if restoredMode == "training" then 0 else -1
                        , saveStatus = D.decodeValue (D.field "saveStatus" D.string) raw |> Result.withDefault "saved"
                      }
                    , Cmd.none
                    )

                Ok "session" ->
                    case D.decodeValue (D.field "questions" (D.list S.decodeQuestion)) raw of
                        Ok qs ->
                            if List.isEmpty qs then
                                ( { m | message = "Aucune question disponible pour cette sélection." }, Cmd.none )

                            else
                                ( { m | questions = qs, mode = Training, tour = 0, selected = "practice-1", exposed = Dict.singleton "practice" 1, answers = Dict.empty, reader = True, closing = False, index = 0, skipped = [], version = D.decodeValue (D.field "bankVersion" D.string) raw |> Result.withDefault m.version }, Cmd.none )

                        Err _ ->
                            ( { m | message = "Impossible de préparer les questions." }, Cmd.none )

                Ok "closed" ->
                    updateCore Closed m

                Ok "orbit" ->
                    ( { m
                        | tour =
                            if m.tour == 5 then
                                6

                            else
                                m.tour
                      }
                    , event m "orbit" []
                    )

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
                            , tour =
                                if m.tour == 0 then
                                    1

                                else
                                    m.tour
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

            else if (getAnswer m.selected m).note == Nothing then
                ( { m | message = "Donnez d’abord une note à cette rédaction." }, Cmd.none )

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
            ( { m
                | reader = False
                , closing = False
                , message = ""
                , tour =
                    if m.tour == 1 then
                        2

                    else
                        m.tour
              }
            , event m "close" []
            )

        Place id axis value committed ->
            let
                a =
                    getAnswer id m

                valid =
                    List.any (\v -> v.id == id) (List.take (Dict.get (current m).id m.exposed |> Maybe.withDefault 1) (current m).productions)

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
            if valid && List.member axis [ "x", "y", "z" ] && a.note /= Nothing && not m.reader then
                ( { m
                    | answers = Dict.insert id next m.answers
                    , selected = id
                    , message = ""
                    , tour =
                        if committed && ((m.tour == 2 && axis == "x") || (m.tour == 3 && axis == "y") || (m.tour == 4 && axis == "z")) then
                            m.tour + 1

                        else
                            m.tour
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
            if a.note /= Nothing && not m.reader && m.mode /= Training then
                ( { m | answers = Dict.insert m.selected { a | judged = [ "x", "y", "z" ] } m.answers, message = "" }
                , event m "confirm-position" [ ( "coordinates", S.encodePoint a.point ) ]
                )

            else
                ( m, Cmd.none )

        Open id ->
            if List.any (\v -> v.id == id) (List.take (Dict.get (current m).id m.exposed |> Maybe.withDefault 1) (current m).productions) then
                ( { m
                    | selected = id
                    , reader = True
                    , closing = False
                    , message = ""
                    , tour =
                        if m.tour == 6 then
                            7

                        else
                            m.tour
                  }
                , event { m | selected = id } "open" []
                )

            else
                ( m, Cmd.none )

        NextProduction ->
            let
                q =
                    current m

                count =
                    Dict.get q.id m.exposed |> Maybe.withDefault 1

                a =
                    getAnswer m.selected m

                confirmed =
                    { m | answers = Dict.insert m.selected { a | judged = [ "x", "y", "z" ] } m.answers }

                confirmation =
                    if List.length a.judged < 3 then
                        event m "confirm-position" [ ( "coordinates", S.encodePoint a.point ), ( "source", E.string "next-production" ) ]

                    else
                        Cmd.none
            in
            if m.mode == Training || m.reader || m.closing then
                ( m, Cmd.none )

            else if a.note == Nothing then
                ( { m | reader = True, message = "Donnez d’abord une note à cette rédaction." }, Cmd.none )

            else if count < List.length q.productions then
                let
                    id =
                        List.drop count q.productions |> List.head |> Maybe.map .id |> Maybe.withDefault ""
                in
                ( { confirmed | selected = id, reader = True, closing = False, exposed = Dict.insert q.id (count + 1) m.exposed, message = "" }, Cmd.batch [ confirmation, event { m | selected = id } "reveal" [] ] )

            else if S.complete confirmed.answers q then
                let
                    ( advanced, command ) =
                        if m.index + 1 < List.length m.questions then
                            updateCore (GoQuestion (m.index + 1)) confirmed

                        else
                            updateCore Finish confirmed
                in
                ( advanced, Cmd.batch [ confirmation, command ] )

            else
                let
                    remaining =
                        List.filter
                            (\p ->
                                let
                                    answer =
                                        getAnswer p.id confirmed
                                in
                                answer.note == Nothing || List.length answer.judged < 3
                            )
                            q.productions

                    id =
                        List.head remaining |> Maybe.map .id |> Maybe.withDefault m.selected
                in
                ( { confirmed | selected = id, reader = True, closing = False, message = "Terminez l’évaluation de cette rédaction pour poursuivre." }, Cmd.batch [ confirmation, event { m | selected = id } "open" [] ] )

        GoQuestion idx ->
            if idx >= 0 && idx < List.length m.questions then
                let
                    next =
                        openQuestion idx m
                in
                ( next, event next "question" [] )

            else
                ( m, Cmd.none )

        Skip ->
            let
                next =
                    { m
                        | skipped =
                            if List.member (current m).id m.skipped then
                                m.skipped

                            else
                                (current m).id :: m.skipped
                    }
            in
            if m.index + 1 < List.length m.questions then
                let
                    following =
                        openQuestion (m.index + 1) next
                in
                ( following, Cmd.batch [ event m "skip" [], event following "question" [] ] )

            else
                ( { next | mode = Finished, reader = False }, event m "skip" [] )

        Finish ->
            ( { m | mode = Finished, reader = False }, event m "finish" [] )

        Return ->
            ( { m | mode = Running, reader = False }, Cmd.none )

        Restart ->
            ( { m | mode = Setup, reader = False, message = "", saveStatus = "idle", saveMessage = "" }, emit "restart" [] )

        Submit ->
            ( { m | saveStatus = "submitting", saveMessage = "" }, emit "submit" [ ( "snapshot", encodeSnapshot m ) ] )

        RetrySave ->
            ( m, emit "retry-save" [] )

        Help ->
            ( { m | mode = Training, tour = 0, selected = "practice-1", reader = True, closing = False, answers = Dict.remove "practice-1" m.answers, exposed = Dict.insert "practice" 1 m.exposed, message = "" }, Cmd.none )

        TourNext ->
            let
                next =
                    openQuestion m.index { m | mode = Running, tour = -1, answers = Dict.remove "practice-1" m.answers }
            in
            ( next, event next "question" [] )

        Compare ->
            let
                other =
                    List.take (Dict.get (current m).id m.exposed |> Maybe.withDefault 1) (current m).productions |> List.filter (\v -> v.id /= m.selected) |> List.head |> Maybe.map .id |> Maybe.withDefault m.selected
            in
            ( { m | compare = True, compareId = other }, event m "compare" [] )

        CompareWith id ->
            ( { m | compareId = id }, Cmd.none )

        NoOp ->
            ( m, Cmd.none )


rich : String -> Html Msg
rich content =
    Html.node "rich-text" [ attribute "content" content ] []


icon : String -> Html Msg
icon name =
    Html.node "ui-icon" [ attribute "name" name, attribute "aria-hidden" "true" ] []


brand : Html Msg
brand =
    div [ class "brand" ] [ span [ class "brand-mark" ] [ icon "layers" ], text "Regards", span [ class "brand-dot" ] [ text "." ] ]


btn : String -> String -> Msg -> Html Msg
btn cls txt msg =
    button [ class cls, onClick msg ] [ text txt ]


view : Model -> Html Msg
view m =
    main_ [ class "experience" ]
        [ if m.mode == Setup then
            text ""

          else
            header [ class "topbar" ]
                [ brand
                , if m.mode == Running || m.mode == Training then
                    button [ class "quiet help-button", onClick Help, disabled (m.mode == Training) ] [ icon "help", text "Mode d’emploi" ]

                  else
                    span [ class "topbar-caption" ] [ text "Rédactions mathématiques" ]
                ]
        , case m.mode of
            Setup ->
                viewSetup m

            Finished ->
                viewFinish m

            _ ->
                viewWorkspace m
        , if m.mode /= Setup then
            div [ class "save-status", attribute "role" "status", attribute "aria-live" "polite", attribute "data-status" m.saveStatus ]
                [ text (if m.saveMessage /= "" then m.saveMessage else if m.saveStatus == "completed" then "Participation enregistrée et validée." else if m.saveStatus == "saved" then "Réponses enregistrées." else if (m.saveStatus == "error" || m.saveStatus == "submit-error") then "Enregistrement en attente. Vos réponses sont conservées sur cet appareil." else "Enregistrement en cours…")
                , if (m.saveStatus == "error" || m.saveStatus == "submit-error") then button [ class "quiet", onClick RetrySave ] [ text "Réessayer l’enregistrement" ] else text ""
                ]

          else
            text ""
        ]


viewSetup : Model -> Html Msg
viewSetup m =
    section [ class "welcome" ]
        [ div [ class "welcome-copy" ]
            [ h1 [] [ text "Critères d’évaluations ", span [] [ text "en mathématiques" ] ]
            , p [ class "intro" ] [ text "Ce sondage fait partie d’un projet de recherche qui cherche à mettre en lumière les critères que les enseignantes et enseignants de mathématiques exploitent pour noter leurs élèves." ]
            , div [ class "local-note" ] [ icon "info", p [] [ text "Vos réponses et vos interactions sont enregistrées pour cette recherche sous un identifiant aléatoire, sans compte personnel. Vous pouvez reprendre sur ce navigateur. Les résultats sont accessibles uniquement à l’équipe de recherche." ] ]
            ]
        , div [ class "level-panel" ]
            [ h2 [] [ text "Quels niveaux avez-vous enseignés ?" ]
            , div [ class "levels" ]
                (List.map
                    (\l ->
                        label [ classList [ ( "level-option", True ), ( "checked", List.member l m.levels ) ] ]
                            [ input [ type_ "checkbox", checked (List.member l m.levels), onCheck (ToggleLevel l) ] []
                            , span []
                                [ text
                                    (case l of
                                        "Sup 1" ->
                                            "Études supérieures"

                                        "1re spé" ->
                                            "1re"

                                        "Tle spé" ->
                                            "Tle"

                                        _ ->
                                            l
                                    )
                                ]
                            , icon "check"
                            ]
                    )
                    m.available
                )
            , button [ class "primary start-button", onClick Begin ] [ text "Commencer", icon "arrow" ]
            , p [ class "error", attribute "role" "alert" ] [ text m.message ]
            ]
        ]


viewWorkspace : Model -> Html Msg
viewWorkspace m =
    let
        q =
            current m

        shown =
            List.take (Dict.get q.id m.exposed |> Maybe.withDefault 1) q.productions

        a =
            getAnswer m.selected m

        done =
            List.filter (S.complete m.answers) m.questions |> List.length

        isLast =
            List.length shown == List.length q.productions
    in
    section [ class "workspace" ]
        [ header [ class "question-panel", id "question-panel" ]
            [ div [ class "question-meta" ]
                [ span [ class "eyebrow" ]
                    [ text
                        (if m.mode == Training then
                            "Essai guidé"

                         else
                            "Question " ++ String.fromInt (m.index + 1) ++ " / " ++ String.fromInt (List.length m.questions)
                        )
                    ]
                , span [ class "question-level" ] [ text q.level ]
                ]
            , rich q.statement
            , div [ class "question-progress", attribute "aria-label" "Progression de la session" ] [ div [ style "width" (String.fromFloat (100 * toFloat done / toFloat (Basics.max 1 (List.length m.questions))) ++ "%") ] [] ]
            ]
        , div [ class "production-strip", attribute "aria-label" "Rédactions déjà lues" ]
            (List.map
                (\v ->
                    button [ classList [ ( "production-chip", True ), ( "selected", v.id == m.selected ) ], onClick (Open v.id), attribute "aria-label" ("Relire la rédaction " ++ String.fromInt (number v.id m)) ]
                        [ span [] [ text (String.fromInt (number v.id m)) ]
                        , text "Rédaction"
                        , if List.length (getAnswer v.id m).judged == 3 then
                            icon "check"

                          else
                            text ""
                        ]
                )
                shown
            )
        , div [ class "evaluation-layout" ]
            [ section [ class "axes-panel", id "axes-panel", attribute "aria-label" "Placer les rédactions sur les trois axes" ]
                [ div [ class "axes-heading" ] [ icon "sliders", span [] [ text "Vos repères" ], span [ class "selected-label" ] [ text ("Rédaction " ++ String.fromInt (number m.selected m)) ] ]
                , div [ class "axis-sliders" ]
                    (List.map
                        (\( axis, _, _ ) ->
                            Html.node "axis-slider"
                                [ id ("axis-" ++ axis)
                                , attribute "axis" axis
                                , attribute "payload" (spacePayload m shown)
                                , on "placement" (D.map4 Place (D.at [ "detail", "id" ] D.string) (D.at [ "detail", "axis" ] D.string) (D.at [ "detail", "value" ] D.float) (D.at [ "detail", "committed" ] D.bool))
                                , on "read" (D.map Open (D.at [ "detail", "id" ] D.string))
                                ]
                                []
                        )
                        S.axes
                    )
                , if List.length a.judged < 3 then
                    button [ class "quiet confirm-position", id "confirm-position", onClick Confirm, disabled (a.note == Nothing || m.mode == Training) ] [ icon "check", text "Conserver cette position" ]

                  else
                    span [ class "position-ready" ] [ icon "check", text "Les trois repères sont placés" ]
                ]
            , Html.node "evaluation-space"
                [ id "space"
                , attribute "payload" (spacePayload m shown)
                , on "read" (D.map Open (D.at [ "detail", "id" ] D.string))
                , on "orbit" (D.succeed (Receive (E.object [ ( "type", E.string "orbit" ) ])))
                ]
                []
            ]
        , div [ class "production-navigation" ]
            [ div [ class "next-group" ]
                [ if List.length shown > 1 then
                    button [ class "quiet", onClick Compare ] [ icon "compare", text "Comparer" ]

                  else
                    text ""
                , button [ class "primary next-production", id "next-production", onClick NextProduction, disabled (m.mode == Training) ]
                    [ text
                        (if isLast then
                            if m.index + 1 == List.length m.questions then
                                "Terminer la session"

                            else
                                "Question suivante"

                         else
                            "Rédaction suivante"
                        )
                    , icon "arrow"
                    ]
                ]
            ]
        , div [ class "question-navigation" ]
            [ button [ class "quiet", onClick (GoQuestion (m.index - 1)), disabled (m.index == 0 || m.mode == Training) ] [ text "← Question précédente" ]
            , span [ class "navigation-message", attribute "role" "status" ]
                [ text
                    (if m.message /= "" then
                        m.message

                     else if m.mode == Training then
                        "Cet essai ne fait pas partie de vos réponses."

                     else
                        "Passer à la suite valide la position affichée, y compris les repères restés au centre. Vous pourrez la modifier."
                    )
                ]
            , button [ class "quiet", onClick Skip, disabled (m.mode == Training) ] [ text "Passer cette question" ]
            ]
        , if m.reader then
            viewReader m

          else
            text ""
        , if m.compare then
            viewCompare m shown

          else
            text ""
        , if m.mode == Training then
            viewTour m

          else
            text ""
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
            [ class "reader", id "reading-card", attribute "production-id" m.selected, attribute "role" "dialog", attribute "aria-modal" "true", attribute "aria-labelledby" "reader-title", tabindex -1 ]
            [ header [ class "reader-header" ] [ div [] [ span [ class "step-tag" ] [ text "Prenez le temps de lire" ], h2 [ id "reader-title" ] [ text ("Rédaction " ++ String.fromInt (number m.selected m)) ] ], button [ class "icon-button", onClick Close, attribute "aria-label" "Réduire la rédaction" ] [ icon "close" ] ]
            , div [ class "reader-content", onClick Close ] [ rich (chosen m).content ]
            , div [ class "reader-footer" ]
                [ div [ class "rating", id "rating" ]
                    [ label [ for "grade" ] [ text "Quelle note lui donneriez-vous ?" ]
                    , div [ class "grade-track" ]
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
                    , p [ id "grade-help", class "rating-help" ]
                        [ text
                            (if a.note == Nothing then
                                "Choisissez une note pour poursuivre."

                             else
                                "Vous pourrez revenir sur cette note."
                            )
                        ]
                    ]
                , button [ class "primary place-button", id "place-button", onClick Close, disabled (a.note == Nothing || m.closing) ] [ text "Placer cette rédaction", icon "shrink" ]
                , p [ class "error", attribute "role" "status" ] [ text m.message ]
                ]
            ]
        ]


viewCompare : Model -> List Production -> Html Msg
viewCompare m shown =
    let
        other =
            List.filter (\v -> v.id == m.compareId) shown |> List.head |> Maybe.withDefault (chosen m)
    in
    div [ class "comparison-layer" ] [ div [ class "reader-backdrop", onClick Close ] [], section [ class "comparison", attribute "role" "dialog", attribute "aria-modal" "true", attribute "aria-label" "Comparer les rédactions" ] [ header [] [ h2 [] [ text "Deux regards côte à côte" ], button [ class "icon-button", onClick Close, attribute "aria-label" "Fermer la comparaison" ] [ icon "close" ] ], div [ class "comparison-columns" ] [ Html.article [] [ h2 [] [ text ("Rédaction " ++ String.fromInt (number m.selected m)) ], rich (chosen m).content ], Html.article [] [ Html.select [ onInput CompareWith, attribute "aria-label" "Choisir la rédaction à comparer" ] (List.map (\v -> Html.option [ value v.id, selected (v.id == other.id) ] [ text ("Rédaction " ++ String.fromInt (number v.id m)) ]) shown), rich other.content ] ] ] ]


viewTour : Model -> Html Msg
viewTour m =
    let
        ( target, heading, body ) =
            case m.tour of
                0 ->
                    ( "#reading-card", "D’abord, votre note", "Lisez cette rédaction, puis attrapez la bille pour lui donner une note. Les deux traits intermédiaires marquent un et deux points. Le déplacement avance par quarts de point, indépendamment des trois axes." )

                1 ->
                    ( "#place-button", "La fiche devient une bille", "Appuyez sur ce bouton. La rédaction se réduit pour rejoindre l’espace de comparaison. Son aperçu vous permettra de la reconnaître." )

                2 ->
                    ( "#axis-x", "Un premier repère", "Attrapez la bille numérotée et faites-la glisser entre Confus et Lisible. Elle part de sa position actuelle, sans saut. Seule la lisibilité change." )

                3 ->
                    ( "#axis-y", "Ajustez la précision", "Déplacez cette bille entre Vague et Précis. Le trait du milieu représente ce que vous attendriez ici, pas forcément un idéal. Plus précis peut aussi être trop précis : vous décidez." )

                4 ->
                    ( "#axis-z", "Puis la validité", "Placez enfin la bille entre Fautif et Valide. Chaque barre règle un seul axe ; les deux autres restent exactement en place. Votre note reste indépendante." )

                5 ->
                    ( "#space", "Tournez autour", "Faites glisser le fond avec le doigt ou la souris. Seul votre point de vue change. Les pointillés relient la bille aux faces et situent la rédaction dans le volume." )

                6 ->
                    ( "#axis-x", "La même bille, la même rédaction", "Touchez le numéro sur cette barre pour relire la rédaction. Les billes proches se dégageront au-dessus de la barre ; leurs traits indiqueront leur position exacte." )

                _ ->
                    ( "#reading-card", "Vous avez la main", "Notez chaque rédaction, placez ses billes, puis utilisez « Rédaction suivante » pour valider la position affichée. Vous pouvez garder un repère au centre et revenir modifier vos choix. L’ordre des questions et des rédactions varie à chaque session." )
    in
    Html.node "spotlight-guide"
        [ attribute "target" target, attribute "step" (String.fromInt m.tour) ]
        [ div [ class "coach-card" ]
            [ div [ class "coach-progress" ] [ span [] [ text ("PRISE EN MAIN · " ++ String.fromInt (m.tour + 1) ++ " / 8") ], div [] (List.range 0 7 |> List.map (\i -> span [ classList [ ( "done", i <= m.tour ) ] ] [])) ]
            , h2 [] [ text heading ]
            , p [] [ text body ]
            , if m.tour == 7 then
                btn "primary" "Commencer mes questions" TourNext

              else
                p [ class "coach-action" ] [ icon "hand", text "Essayez directement dans la zone éclairée" ]
            ]
        ]


viewFinish : Model -> Html Msg
viewFinish m =
    let
        done =
            List.filter (S.complete m.answers) m.questions |> List.length
    in
    section [ class "finish-panel" ]
        [ div [ class "finish-icon" ] [ icon "check" ]
        , span [ class "eyebrow" ] [ text "Merci pour votre regard" ]
        , h1 [] [ text "Chaque nuance compte." ]
        , p [ class "intro" ]
            [ text
                (String.fromInt done
                    ++ " question"
                    ++ (if done > 1 then
                            "s"

                        else
                            ""
                       )
                    ++ " entièrement évaluée"
                    ++ (if done > 1 then
                            "s"

                        else
                            ""
                       )
                    ++ " sur "
                    ++ String.fromInt (List.length m.questions)
                    ++ "."
                )
            ]
        , p [ class "muted" ] [ text (if m.saveStatus == "completed" then "Vos réponses ont bien été reçues. Merci pour votre participation." else "Vous pouvez encore revoir vos réponses, puis valider votre participation.") ]
        , if m.saveStatus == "completed" then
            btn "quiet" "Nouvelle participation" Restart

          else
            div [ class "finish-actions" ]
                [ button [ class "primary", onClick Submit, disabled (m.saveStatus == "submitting") ] [ icon "check", text (if m.saveStatus == "submitting" then "Validation en cours…" else "Valider ma participation") ]
                , button [ class "secondary", onClick Return, disabled (m.saveStatus == "submitting" || m.saveStatus == "submit-error") ] [ text "Revenir aux questions" ]
                ]
        ]
