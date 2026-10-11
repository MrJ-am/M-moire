port module Main exposing (main)

import BoardLogic
import Browser
import Browser.Dom as Dom
import Browser.Events
import Dict exposing (Dict)
import Element as Interface
import Html exposing (Html)
import Http
import Json.Decode as Decode
import MrJam
import MrJam.Manipulation as Reperes
import MrJam.Mathematiques as Math
import MrJam.TableSpatiale as Table
import MrJam.Transitions as T
import Presentation as P
import Process
import Task
import Time


port reductionAnimations : (Bool -> message) -> Sub message


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
    , zoomTimeline : T.Transition ExpandedState
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
    | TransitionTick Time.Posix
    | ReduireAnimations Bool


miniatureWidth : Float
miniatureWidth =
    320


miniatureHeight : Float
miniatureHeight =
    206


miniScale : Float
miniScale =
    0.33


expandedMargin : Float
expandedMargin =
    12


main : Program Bool Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : Bool -> ( Model, Cmd Msg )
init reduite =
    ( { exercise = Nothing
      , propositions = []
      , contentError = Nothing
      , selectedPropositionId = Nothing
      , expandedPropositionId = Nothing
      , zoomTimeline = T.initialiser AllMini |> T.reduire reduite
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
        [ T.abonnement TransitionTick model.zoomTimeline
        , reductionAnimations ReduireAnimations
        , Browser.Events.onResize WindowResized
        , Browser.Events.onMouseMove mouseMoveDecoder
        , Browser.Events.onMouseUp (Decode.succeed PointerUp)
        ]


animateExpanded : ExpandedState -> T.Transition ExpandedState -> T.Transition ExpandedState
animateExpanded target timeline =
    T.aller 220 target timeline


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

        TransitionTick now ->
            ( { model | zoomTimeline = T.mettreAJour now model.zoomTimeline }, Cmd.none )

        ReduireAnimations reduite ->
            ( { model | zoomTimeline = T.reduire reduite model.zoomTimeline }, Cmd.none )


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
    Table.cadre P.marque
        { largeur = model.viewport.width, hauteur = model.viewport.height }
        [ topHeader model
        , boardView model
        ]


topHeader : Model -> Interface.Element msg
topHeader model =
    P.disposition.panneau [ Reperes.test "header" ]
        (case model.exercise of
            Just exercise ->
                [ MrJam.sousTitre exercise.title
                , Math.document exercise.statement
                , P.commun.texteSecondaire ("Sélection : " ++ selectedBadgeLabel model.selectedPropositionId model.propositions ++ " | Placées : " ++ String.fromInt (placedCount model.propositions) ++ "/" ++ String.fromInt (List.length model.propositions))
                ]

            Nothing ->
                [ MrJam.sousTitre "Évaluation de productions d’élèves", P.commun.texteSecondaire (Maybe.withDefault "Chargement des productions…" model.contentError) ]
        )


placedCount : List Proposition -> Int
placedCount propositions =
    propositions |> List.filter (\item -> item.pos /= Nothing) |> List.length


boardView : Model -> Interface.Element Msg
boardView model =
    let
        dimensions =
            model.boardRect
                |> Maybe.map (\rect -> { largeur = round rect.width, hauteur = round rect.height })
                |> Maybe.withDefault { largeur = model.viewport.width - 24, hauteur = model.viewport.height - 160 }
    in
    Table.plan dimensions
        (Just ( "Precision faible", "Rigueur elevee" ))
        (model.dragging /= Nothing)
        PointerMove
        PointerUp
        CloseCard
        (List.map (\item -> ( String.fromInt item.id, viewCard model item )) model.propositions)


stateContainsCard : Int -> ExpandedState -> Bool
stateContainsCard propositionId expandedState =
    case expandedState of
        Expanded expandedId ->
            expandedId == propositionId

        AllMini ->
            False


cardIsZooming : Model -> Int -> Bool
cardIsZooming model propositionId =
    stateContainsCard propositionId (T.courant model.zoomTimeline)
        || stateContainsCard propositionId (T.arrive model.zoomTimeline)


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


cardValue : Model -> Int -> Float -> Float -> Float
cardValue model propositionId miniValue expandedValue =
    T.nombre
        (\etat ->
            if stateContainsCard propositionId etat then
                expandedValue

            else
                miniValue
        )
        model.zoomTimeline


viewCard : Model -> Proposition -> Interface.Element Msg
viewCard model item =
    case item.pos of
        Nothing ->
            Interface.none

        Just pos ->
            let
                centre =
                    expandedCenter model

                dimensions =
                    model.boardRect |> Maybe.withDefault { x = 0, y = 0, width = toFloat (model.viewport.width - 24), height = toFloat (model.viewport.height - 160) }
            in
            Table.carte
                { repere = item.badge
                , x = cardValue model item.id (pos.x * dimensions.width) (centre.x * dimensions.width)
                , y = cardValue model item.id (pos.y * dimensions.height) (centre.y * dimensions.height)
                , largeur = cardValue model item.id miniatureWidth (expandedCardWidth model)
                , hauteur = cardValue model item.id miniatureHeight (expandedCardHeight model)
                , echelle = cardValue model item.id miniScale 1
                , ouverte = model.expandedPropositionId == Just item.id
                , mouvement = cardIsZooming model item.id
                , commencer = StartDrag item.id
                , ouvrir = OpenCard item.id
                , fermer = CloseCard
                , contenu = viewCardContent item
                }


viewCardContent : Proposition -> Interface.Element msg
viewCardContent item =
    P.disposition.panneau [ Interface.height Interface.fill ]
        [ MrJam.actions [ P.disposition.etiquette item.badge, MrJam.sousTitre item.title ]
        , P.commun.texteSecondaire item.subtitle
        , Math.document item.preview
        , Math.document item.content
        ]


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


mouseMoveDecoder : Decode.Decoder Msg
mouseMoveDecoder =
    Decode.map2 PointerMove
        (Decode.field "clientX" Decode.float)
        (Decode.field "clientY" Decode.float)
