module Main exposing (main)

import Animator
import Animator.Inline
import BoardLogic
import Browser
import Browser.Dom as Dom
import Browser.Events
import Dict exposing (Dict)
import Element as Interface
import Html exposing (Html, div, h1, h2, h3, p, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, preventDefaultOn, stopPropagationOn)
import Http
import Json.Decode as Decode
import MrJam
import MrJam.Disposition as Disposition
import Process
import Task
import Time


type alias Position =
    { x : Float
    , y : Float
    }


type alias Exercise =
    { title : String
    , statement : String
    }


type alias Proposition =
    { id : Int
    , badge : String
    , title : String
    , subtitle : String
    , preview : String
    , content : String
    , pos : Maybe Position
    }


type alias ContentData =
    { exercise : Exercise
    , productions : List Proposition
    }


type alias BoardRect =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }


type alias DragState =
    { propositionId : Int
    , startMouseX : Float
    , startMouseY : Float
    , startCardX : Float
    , startCardY : Float
    , moved : Bool
    }


type alias Viewport =
    { width : Int
    , height : Int
    }


type ExpandedState
    = AllMini
    | Expanded Int


type alias Model =
    { exercise : Maybe Exercise
    , propositions : List Proposition
    , contentError : Maybe String
    , selectedPropositionId : Maybe Int
    , expandedPropositionId : Maybe Int
    , zoomTimeline : Animator.Timeline ExpandedState
    , dragging : Maybe DragState
    , suppressNextOpen : Bool
    , boardRect : Maybe BoardRect
    , viewport : Viewport
    }


type Msg
    = GotContent (Result Http.Error ContentData)
    | StartDrag Int Float Float
    | PointerMove Float Float
    | PointerUp
    | OpenCard Int
    | CloseCard
    | ClearSuppressNextOpen
    | RefreshBoardRect
    | GotBoardRect (Result Dom.Error Dom.Element)
    | GotViewport (Result Dom.Error Dom.Viewport)
    | WindowResized Int Int
    | AnimatorTick Time.Posix


miniatureWidth : Float
miniatureWidth =
    320


miniatureHeight : Float
miniatureHeight =
    206


miniScale : Float
miniScale =
    0.33


miniCardWidth : Float
miniCardWidth =
    miniatureWidth * miniScale


miniCardHeight : Float
miniCardHeight =
    miniatureHeight * miniScale


expandedMargin : Float
expandedMargin =
    12


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { exercise = Nothing
      , propositions = []
      , contentError = Nothing
      , selectedPropositionId = Nothing
      , expandedPropositionId = Nothing
      , zoomTimeline = Animator.init AllMini
      , dragging = Nothing
      , suppressNextOpen = False
      , boardRect = Nothing
      , viewport = { width = 1200, height = 800 }
      }
    , Cmd.batch
        [ loadContent
        , Task.perform (\_ -> RefreshBoardRect) (Process.sleep 60)
        , Task.attempt GotViewport Dom.getViewport
        ]
    )


loadContent : Cmd Msg
loadContent =
    Http.get
        { url = "data/exercise-001.json"
        , expect = Http.expectJson GotContent contentDecoder
        }


contentDecoder : Decode.Decoder ContentData
contentDecoder =
    Decode.map2 ContentData
        (Decode.field "exercise" exerciseDecoder)
        (Decode.field "productions" (Decode.list propositionDecoder))


exerciseDecoder : Decode.Decoder Exercise
exerciseDecoder =
    Decode.map2 Exercise
        (Decode.field "title" Decode.string)
        (Decode.field "statement" Decode.string)


propositionDecoder : Decode.Decoder Proposition
propositionDecoder =
    Decode.map6 propositionFromData
        (Decode.field "id" Decode.int)
        (Decode.field "badge" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "subtitle" Decode.string)
        (Decode.field "preview" Decode.string)
        (Decode.field "content" Decode.string)


propositionFromData : Int -> String -> String -> String -> String -> String -> Proposition
propositionFromData id badge title subtitle preview content =
    { id = id
    , badge = badge
    , title = title
    , subtitle = subtitle
    , preview = preview
    , content = content
    , pos = Nothing
    }


withInitialPositions : List Proposition -> List Proposition
withInitialPositions propositions =
    let
        layout : Dict Int Position
        layout =
            Dict.fromList
                [ ( 1, { x = 0.18, y = 0.14 } )
                , ( 2, { x = 0.38, y = 0.14 } )
                , ( 3, { x = 0.58, y = 0.14 } )
                , ( 4, { x = 0.78, y = 0.14 } )
                ]
    in
    List.map
        (\item ->
            { item | pos = Dict.get item.id layout }
        )
        propositions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Animator.toSubscription AnimatorTick model animator
        , Browser.Events.onResize WindowResized
        , Browser.Events.onMouseMove mouseMoveDecoder
        , Browser.Events.onMouseUp (Decode.succeed PointerUp)
        ]


animator : Animator.Animator Model
animator =
    Animator.animator
        |> Animator.watching .zoomTimeline
            (\newTimeline currentModel ->
                { currentModel | zoomTimeline = newTimeline }
            )


animateExpanded : ExpandedState -> Animator.Timeline ExpandedState -> Animator.Timeline ExpandedState
animateExpanded target timeline =
    Animator.go (Animator.millis 220) target timeline


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotContent result ->
            case result of
                Ok contentData ->
                    let
                        seeded =
                            withInitialPositions contentData.productions

                        firstId =
                            seeded
                                |> List.head
                                |> Maybe.map .id
                    in
                    ( { model
                        | exercise = Just contentData.exercise
                        , propositions = seeded
                        , contentError = Nothing
                        , selectedPropositionId = firstId
                      }
                    , Task.perform (\_ -> RefreshBoardRect) (Process.sleep 24)
                    )

                Err _ ->
                    ( { model | contentError = Just "Impossible de charger les données de l'exercice." }
                    , Cmd.none
                    )

        StartDrag propositionId clientX clientY ->
            let
                startPosition =
                    propositionPosition propositionId model.propositions
                        |> Maybe.withDefault { x = 0.5, y = 0.5 }
            in
            ( { model
                | dragging =
                    Just
                        { propositionId = propositionId
                        , startMouseX = clientX
                        , startMouseY = clientY
                        , startCardX = startPosition.x
                        , startCardY = startPosition.y
                        , moved = False
                        }
                , selectedPropositionId = Just propositionId
                , suppressNextOpen = False
              }
            , Task.attempt GotBoardRect (Dom.getElement "board")
            )

        PointerMove clientX clientY ->
            case ( model.dragging, model.boardRect ) of
                ( Just dragState, Just rect ) ->
                    let
                        nextPos =
                            BoardLogic.nextClampedPosition
                                miniatureWidth
                                miniatureHeight
                                miniScale
                                rect
                                dragState.startMouseX
                                dragState.startMouseY
                                dragState.startCardX
                                dragState.startCardY
                                clientX
                                clientY

                        movedNow =
                            dragState.moved || BoardLogic.movedBeyond 4 dragState.startMouseX dragState.startMouseY clientX clientY
                    in
                    ( { model
                        | propositions = updatePropositionPosition dragState.propositionId nextPos model.propositions
                        , dragging = Just { dragState | moved = movedNow }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        PointerUp ->
            case model.dragging of
                Nothing ->
                    ( model, Cmd.none )

                Just dragState ->
                    ( { model
                        | dragging = Nothing
                        , suppressNextOpen = dragState.moved
                      }
                    , if dragState.moved then
                        Task.perform (\_ -> ClearSuppressNextOpen) (Process.sleep 120)

                      else
                        Cmd.none
                    )

        OpenCard propositionId ->
            if model.suppressNextOpen then
                ( { model | suppressNextOpen = False }, Cmd.none )

            else if model.expandedPropositionId == Just propositionId then
                ( model, Cmd.none )

            else
                ( { model
                    | selectedPropositionId = Just propositionId
                    , expandedPropositionId = Just propositionId
                    , zoomTimeline = animateExpanded (Expanded propositionId) model.zoomTimeline
                  }
                , Cmd.none
                )

        CloseCard ->
            case model.expandedPropositionId of
                Nothing ->
                    ( model, Cmd.none )

                Just _ ->
                    ( { model
                        | expandedPropositionId = Nothing
                        , zoomTimeline = animateExpanded AllMini model.zoomTimeline
                      }
                    , Cmd.none
                    )

        ClearSuppressNextOpen ->
            ( { model | suppressNextOpen = False }, Cmd.none )

        RefreshBoardRect ->
            ( model, Task.attempt GotBoardRect (Dom.getElement "board") )

        GotBoardRect result ->
            case result of
                Ok element ->
                    ( { model
                        | boardRect =
                            Just
                                { x = element.element.x
                                , y = element.element.y
                                , width = element.element.width
                                , height = element.element.height
                                }
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        GotViewport result ->
            case result of
                Ok viewport ->
                    ( { model
                        | viewport =
                            { width = round viewport.viewport.width
                            , height = round viewport.viewport.height
                            }
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        WindowResized width height ->
            ( { model | viewport = { width = width, height = height } }
            , Task.perform (\_ -> RefreshBoardRect) (Process.sleep 24)
            )

        AnimatorTick now ->
            ( Animator.update now animator model, Cmd.none )


updatePropositionPosition : Int -> Position -> List Proposition -> List Proposition
updatePropositionPosition propositionId newPos propositions =
    List.map
        (\item ->
            if item.id == propositionId then
                { item | pos = Just newPos }

            else
                item
        )
        propositions


propositionPosition : Int -> List Proposition -> Maybe Position
propositionPosition propositionId propositions =
    propositions
        |> List.filter (\item -> item.id == propositionId)
        |> List.head
        |> Maybe.andThen .pos


view : Model -> Html Msg
view model =
    Disposition.cadre
        [ Interface.htmlAttribute (attribute "data-testid" "app-root")
        , Interface.htmlAttribute (style "height" "100dvh")
        , Interface.htmlAttribute (style "max-height" "100dvh")
        , Interface.htmlAttribute (style "overflow" "hidden")
        ]
        (Interface.column [ Interface.width Interface.fill, Interface.height Interface.fill, Interface.padding 12, Interface.spacing 12 ]
            [ topHeader model
            , Interface.el [ Interface.width Interface.fill, Interface.height Interface.fill, Interface.htmlAttribute (style "min-height" "0") ] (Interface.html (boardView model))
            ]
        )


topHeader : Model -> Interface.Element msg
topHeader model =
    Disposition.panneau [ Interface.htmlAttribute (attribute "data-testid" "header") ]
        (case model.exercise of
            Just exercise ->
                [ MrJam.sousTitre exercise.title
                , Interface.html (richText exercise.statement)
                , MrJam.texteSecondaire ("Sélection : " ++ selectedBadgeLabel model.selectedPropositionId model.propositions ++ " | Placées : " ++ String.fromInt (placedCount model.propositions) ++ "/" ++ String.fromInt (List.length model.propositions))
                ]

            Nothing ->
                [ MrJam.sousTitre "Évaluation de productions d’élèves", MrJam.texteSecondaire (Maybe.withDefault "Chargement des productions…" model.contentError) ]
        )


placedCount : List Proposition -> Int
placedCount propositions =
    propositions
        |> List.filter (\item -> item.pos /= Nothing)
        |> List.length


boardView : Model -> Html Msg
boardView model =
    let
        touchMoveAttributes =
            case model.dragging of
                Just _ ->
                    [ onBoardTouchMove ]

                Nothing ->
                    []
    in
    div
        ([ id "board"
         , attribute "data-testid" "board"
         , onBoardTouchEnd
         , onBoardTouchCancel
         , onClick CloseCard
         , style "position" "relative"
         , style "z-index" "2"
         , style "height" "100%"
         , style "min-height" "0"
         , style "width" "100%"
         , style "overflow"
            (if boardHasZoomingCard model then
                "visible"

             else
                "hidden"
            )
         , style "touch-action"
            (case model.dragging of
                Just _ ->
                    "none"

                Nothing ->
                    "auto"
            )
         ]
            ++ touchMoveAttributes
        )
        ([ axisLines ]
            ++ List.map (viewCard model) model.propositions
            ++ [ boardLegend ]
        )


boardLegend : Html msg
boardLegend =
    div
        [ style "position" "absolute"
        , style "left" "10px"
        , style "right" "10px"
        , style "bottom" "8px"
        , style "display" "flex"
        , style "justify-content" "space-between"
        , style "font-size" "12px"
        , style "color" "#4c5d7f"
        ]
        [ span [] [ text "Precision faible" ]
        , span [] [ text "Rigueur elevee" ]
        ]


axisLines : Html msg
axisLines =
    div []
        [ div
            [ style "position" "absolute"
            , style "left" "0"
            , style "right" "0"
            , style "top" "50%"
            , style "height" "1px"
            , style "background" "#b9c9e6"
            ]
            []
        , div
            [ style "position" "absolute"
            , style "top" "0"
            , style "bottom" "0"
            , style "left" "50%"
            , style "width" "1px"
            , style "background" "#b9c9e6"
            ]
            []
        ]


stateContainsCard : Int -> ExpandedState -> Bool
stateContainsCard propositionId expandedState =
    case expandedState of
        Expanded expandedId ->
            expandedId == propositionId

        AllMini ->
            False


cardIsZooming : Model -> Int -> Bool
cardIsZooming model propositionId =
    stateContainsCard propositionId (Animator.current model.zoomTimeline)
        || stateContainsCard propositionId (Animator.arrived model.zoomTimeline)


boardHasZoomingCard : Model -> Bool
boardHasZoomingCard model =
    Animator.current model.zoomTimeline
        /= AllMini
        || Animator.arrived model.zoomTimeline
        /= AllMini


expandedCenter : Model -> Position
expandedCenter model =
    case model.boardRect of
        Just rect ->
            if rect.width > 0 && rect.height > 0 then
                { x = (toFloat model.viewport.width / 2 - rect.x) / rect.width
                , y = (toFloat model.viewport.height / 2 - rect.y) / rect.height
                }

            else
                { x = 0.5, y = 0.5 }

        Nothing ->
            { x = 0.5, y = 0.5 }


expandedCardWidth : Model -> Float
expandedCardWidth model =
    Basics.max miniatureWidth (toFloat model.viewport.width - 2 * expandedMargin)


expandedCardHeight : Model -> Float
expandedCardHeight model =
    Basics.max miniatureHeight (toFloat model.viewport.height - 2 * expandedMargin)


cardMovement : Int -> Float -> Float -> ExpandedState -> Animator.Movement
cardMovement propositionId miniValue expandedValue expandedState =
    if stateContainsCard propositionId expandedState then
        Animator.at expandedValue |> Animator.arriveSmoothly 0.75

    else
        Animator.at miniValue |> Animator.arriveSmoothly 0.75


viewCard : Model -> Proposition -> Html Msg
viewCard model item =
    case item.pos of
        Nothing ->
            text ""

        Just pos ->
            let
                isExpanded =
                    model.expandedPropositionId == Just item.id

                isSelected =
                    model.selectedPropositionId == Just item.id

                isDragging =
                    case model.dragging of
                        Just dragState ->
                            dragState.propositionId == item.id

                        Nothing ->
                            False

                isZooming =
                    cardIsZooming model item.id

                targetCenter =
                    expandedCenter model

                cursorStyle =
                    if isExpanded then
                        "zoom-out"

                    else if isZooming then
                        "default"

                    else if isDragging then
                        "grabbing"

                    else
                        "grab"

                interactionAttributes =
                    if isExpanded || isZooming then
                        [ stopPropagationOn "click" (Decode.succeed ( CloseCard, True )) ]

                    else
                        [ preventDefaultOn "mousedown"
                            (Decode.map
                                (\( x, y ) -> ( StartDrag item.id x y, True ))
                                mousePointDecoder
                            )
                        , onMiniTouchStart item.id
                        , stopPropagationOn "click" (Decode.succeed ( OpenCard item.id, True ))
                        ]
            in
            div
                [ style "position" "absolute"
                , Animator.Inline.style model.zoomTimeline
                    "left"
                    (\value -> String.fromFloat value ++ "%")
                    (cardMovement item.id (pos.x * 100) (targetCenter.x * 100))
                , Animator.Inline.style model.zoomTimeline
                    "top"
                    (\value -> String.fromFloat value ++ "%")
                    (cardMovement item.id (pos.y * 100) (targetCenter.y * 100))
                , style "width" "0"
                , style "height" "0"
                , style "display" "flex"
                , style "align-items" "center"
                , style "justify-content" "center"
                , style "overflow" "visible"
                , style "pointer-events" "none"
                , style "z-index"
                    (if isZooming then
                        "100"

                     else if isDragging then
                        "80"

                     else if isSelected then
                        "40"

                     else
                        "30"
                    )
                , attribute "data-testid" ("anchor-" ++ item.badge)
                ]
                [ div
                    (interactionAttributes
                        ++ [ Animator.Inline.scale model.zoomTimeline
                                (cardMovement item.id miniScale 1)
                           , Animator.Inline.style model.zoomTimeline
                                "width"
                                (\value -> String.fromFloat value ++ "px")
                                (cardMovement item.id miniatureWidth (expandedCardWidth model))
                           , Animator.Inline.style model.zoomTimeline
                                "height"
                                (\value -> String.fromFloat value ++ "px")
                                (cardMovement item.id miniatureHeight (expandedCardHeight model))
                           , style "transform-origin" "center center"
                           , style "flex" "0 0 auto"
                           , style "position" "relative"
                           , style "overflow"
                                (if isZooming then
                                    "auto"

                                 else
                                    "hidden"
                                )
                           , style "cursor" cursorStyle
                           , style "user-select"
                                (if isExpanded then
                                    "text"

                                 else
                                    "none"
                                )
                           , style "touch-action"
                                (if isExpanded then
                                    "pan-y"

                                 else
                                    "none"
                                )
                           , style "outline" "none"
                           , style "pointer-events" "auto"
                           , attribute "data-testid" ("card-" ++ item.badge)
                           , attribute "data-state"
                                (if isExpanded then
                                    "expanded"

                                 else
                                    "mini"
                                )
                           , attribute "data-zooming"
                                (if isZooming then
                                    "true"

                                 else
                                    "false"
                                )
                           ]
                    )
                    [ viewCardContent item ]
                ]


viewCardContent : Proposition -> Html msg
viewCardContent item =
    Disposition.fragment
        (Disposition.panneau [ Interface.height Interface.fill ]
            [ MrJam.actions [ Disposition.etiquette item.badge, MrJam.sousTitre item.title ]
            , MrJam.texteSecondaire item.subtitle
            , Interface.html (richText item.preview)
            , Interface.html (richText item.content)
            ]
        )


richText : String -> Html msg
richText source =
    Html.node "rich-text"
        [ attribute "content" source
        , style "display" "block"
        ]
        []


selectedBadgeLabel : Maybe Int -> List Proposition -> String
selectedBadgeLabel maybeId propositions =
    maybeId
        |> Maybe.andThen (\propositionId -> propositionById propositionId propositions)
        |> Maybe.map .badge
        |> Maybe.withDefault "aucune"


propositionById : Int -> List Proposition -> Maybe Proposition
propositionById propositionId propositions =
    propositions
        |> List.filter (\item -> item.id == propositionId)
        |> List.head


onMiniTouchStart : Int -> Html.Attribute Msg
onMiniTouchStart propositionId =
    on "touchstart"
        (Decode.map
            (\( clientX, clientY ) -> StartDrag propositionId clientX clientY)
            touchPointDecoder
        )


onBoardTouchMove : Html.Attribute Msg
onBoardTouchMove =
    preventDefaultOn "touchmove"
        (Decode.map
            (\( clientX, clientY ) -> ( PointerMove clientX clientY, True ))
            touchPointDecoder
        )


onBoardTouchEnd : Html.Attribute Msg
onBoardTouchEnd =
    on "touchend" (Decode.succeed PointerUp)


onBoardTouchCancel : Html.Attribute Msg
onBoardTouchCancel =
    on "touchcancel" (Decode.succeed PointerUp)


mouseMoveDecoder : Decode.Decoder Msg
mouseMoveDecoder =
    Decode.map2 PointerMove
        (Decode.field "clientX" Decode.float)
        (Decode.field "clientY" Decode.float)


mousePointDecoder : Decode.Decoder ( Float, Float )
mousePointDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "clientX" Decode.float)
        (Decode.field "clientY" Decode.float)


touchPointDecoder : Decode.Decoder ( Float, Float )
touchPointDecoder =
    Decode.oneOf
        [ Decode.map2 Tuple.pair
            (Decode.at [ "touches", "0", "clientX" ] Decode.float)
            (Decode.at [ "touches", "0", "clientY" ] Decode.float)
        , Decode.map2 Tuple.pair
            (Decode.at [ "changedTouches", "0", "clientX" ] Decode.float)
            (Decode.at [ "changedTouches", "0", "clientY" ] Decode.float)
        ]
