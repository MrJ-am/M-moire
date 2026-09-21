port module Administration exposing (main)

{-| L’interface complète est en ElmUI. Le pont JavaScript transporte les
requêtes ; le serveur conserve sessions, autorisations et protection CSRF.
Les clés JSON ci-dessous appartiennent au contrat de collecte existant.
-}

import Browser
import Element as UI exposing (Element)
import Html exposing (Html)
import Html.Attributes as A
import Html.Events as Evenements
import Json.Decode as D
import Json.Encode as E
import MrJam as M
import MrJam.Disposition as Disposition
import MrJam.Tableaux as Tableaux
import Url


port connexion : { username : String, password : String } -> Cmd message


port retourConnexion : (String -> message) -> Sub message


port requeteAdministration : { identifiant : String, contexte : Int, chemin : String, methode : String, corps : E.Value } -> Cmd message


port retourAdministration : (E.Value -> message) -> Sub message


type Vue
    = TableauDeBord
    | Corpus
    | Question String
    | Reponses String String
    | Participations
    | Participation String


type alias Filtres =
    { version : String, statut : String, niveau : String, depuis : String, jusque : String }


type alias Modele =
    { identifiant : String
    , secret : String
    , confirmation : String
    , activation : Bool
    , enCours : Bool
    , erreur : String
    , compte : Maybe String
    , vue : Vue
    , filtres : Filtres
    , appliques : Filtres
    , versions : List String
    , corpus : E.Value
    , statistiques : E.Value
    , details : E.Value
    , reponses : List E.Value
    , numeroPage : Int
    , recherche : String
    , contexte : Int
    , attente : Int
    }


type Message
    = ModifierIdentifiant String
    | ModifierSecret String
    | ModifierConfirmation String
    | SeConnecter
    | Refus String
    | Recevoir E.Value
    | Naviguer Vue
    | ModifierFiltre String String
    | Appliquer
    | Rechercher String
    | ChangerPage Int
    | SeDeconnecter
    | ConnexionOrdinaire


vide : E.Value
vide =
    E.object []


main : Program { activation : Bool } Modele Message
main =
    Browser.element
        { init =
            \flags ->
                let
                    filtres =
                        Filtres "" "" "" "" ""
                in
                ( { identifiant = "admin"
                  , secret = ""
                  , confirmation = ""
                  , activation = flags.activation
                  , enCours = False
                  , erreur = ""
                  , compte = Nothing
                  , vue = TableauDeBord
                  , filtres = filtres
                  , appliques = filtres
                  , versions = []
                  , corpus = vide
                  , statistiques = vide
                  , details = vide
                  , reponses = []
                  , numeroPage = 1
                  , recherche = ""
                  , contexte = 0
                  , attente = 0
                  }
                , demander 0 "compte" "me"
                )
        , update = actualiser
        , view = afficher
        , subscriptions = \_ -> Sub.batch [ retourConnexion Refus, retourAdministration Recevoir ]
        }


demander : Int -> String -> String -> Cmd Message
demander contexte identifiant chemin =
    requeteAdministration { identifiant = identifiant, contexte = contexte, chemin = chemin, methode = "GET", corps = vide }


parametres : Filtres -> String
parametres filtres =
    [ ( "version", filtres.version ), ( "status", filtres.statut ), ( "level", filtres.niveau ), ( "from", filtres.depuis ), ( "to", filtres.jusque ) ]
        |> List.filter (\( _, v ) -> v /= "")
        |> List.map (\( k, v ) -> k ++ "=" ++ Url.percentEncode v)
        |> String.join "&"


charger : Vue -> Modele -> ( Modele, Cmd Message )
charger vue modele =
    let
        suivant =
            modele.contexte + 1

        requetes =
            case vue of
                Participation identifiant ->
                    [ demander suivant "details" ("participations/" ++ Url.percentEncode identifiant) ]

                Reponses _ production ->
                    [ demander suivant "reponses" ("productions/" ++ Url.percentEncode production ++ "/answers?" ++ parametres modele.appliques) ]

                _ ->
                    [ demander suivant "corpus" ("corpus/" ++ Url.percentEncode modele.appliques.version)
                    , demander suivant "statistiques" ("statistics?" ++ parametres modele.appliques)
                    ]
                        ++ (if vue == Participations then
                                [ demander suivant "details" ("participations?" ++ parametres modele.appliques ++ "&page=" ++ String.fromInt modele.numeroPage) ]

                            else
                                []
                           )
    in
    ( { modele | vue = vue, contexte = suivant, attente = List.length requetes, erreur = "", details = vide, reponses = [] }, Cmd.batch requetes )


actualiser : Message -> Modele -> ( Modele, Cmd Message )
actualiser message modele =
    case message of
        ModifierIdentifiant valeur ->
            ( { modele | identifiant = valeur }, Cmd.none )

        ModifierSecret valeur ->
            ( { modele | secret = valeur }, Cmd.none )

        ModifierConfirmation valeur ->
            ( { modele | confirmation = valeur }, Cmd.none )

        ConnexionOrdinaire ->
            ( { modele | activation = False, erreur = "" }, Cmd.none )

        Refus erreur ->
            ( { modele | erreur = erreur, enCours = False }, Cmd.none )

        SeConnecter ->
            if modele.enCours then
                ( modele, Cmd.none )

            else if String.length modele.identifiant < 3 || String.length modele.identifiant > 80 then
                actualiser (Refus "L’identifiant doit comporter de 3 à 80 caractères.") modele

            else if
                String.length modele.secret
                    < (if modele.activation then
                        14

                       else
                        1
                      )
                    || String.length modele.secret
                    > 256
            then
                actualiser
                    (Refus
                        (if modele.activation then
                            "Choisissez un mot de passe de 14 à 256 caractères."

                         else
                            "Saisissez un mot de passe de 1 à 256 caractères."
                        )
                    )
                    modele

            else if modele.activation && modele.secret /= modele.confirmation then
                actualiser (Refus "Les mots de passe ne correspondent pas.") modele

            else
                ( { modele | enCours = True, erreur = "" }
                , if modele.activation then
                    requeteAdministration { identifiant = "connexion", contexte = modele.contexte, chemin = "setup", methode = "POST", corps = E.object [ ( "username", E.string modele.identifiant ), ( "password", E.string modele.secret ) ] }

                  else
                    connexion { username = modele.identifiant, password = modele.secret }
                )

        SeDeconnecter ->
            ( modele, requeteAdministration { identifiant = "deconnexion", contexte = modele.contexte, chemin = "logout", methode = "POST", corps = vide } )

        Naviguer vue ->
            charger vue { modele | numeroPage = 1 }

        ChangerPage page ->
            charger Participations { modele | numeroPage = page }

        Rechercher recherche ->
            ( { modele | recherche = recherche }, Cmd.none )

        ModifierFiltre cle valeur ->
            let
                f =
                    modele.filtres

                suivant =
                    case cle of
                        "version" ->
                            { f | version = valeur }

                        "status" ->
                            { f | statut = valeur }

                        "level" ->
                            { f | niveau = valeur }

                        "from" ->
                            { f | depuis = valeur }

                        _ ->
                            { f | jusque = valeur }
            in
            ( { modele | filtres = suivant }, Cmd.none )

        Appliquer ->
            charger modele.vue { modele | appliques = modele.filtres, numeroPage = 1 }

        Recevoir retour ->
            let
                identifiant =
                    chaine "identifiant" retour

                contexte =
                    entier "contexte" retour

                donnees =
                    objet "donnees" retour

                reussi =
                    D.decodeValue (D.field "reussi" D.bool) retour |> Result.withDefault False
            in
            if identifiant /= "connexion" && contexte /= modele.contexte then
                ( modele, Cmd.none )

            else if not reussi then
                if identifiant == "compte" || entier "statut" retour == 401 && modele.compte /= Nothing then
                    ( { modele
                        | compte = Nothing
                        , enCours = False
                        , attente = 0
                        , corpus = vide
                        , statistiques = vide
                        , details = vide
                        , reponses = []
                        , secret = ""
                        , confirmation = ""
                        , erreur =
                            if identifiant == "compte" then
                                ""

                            else
                                "Votre session a expiré. Reconnectez-vous."
                      }
                    , Cmd.none
                    )

                else
                    ( { modele | enCours = False, attente = Basics.max 0 (modele.attente - 1), erreur = chaine "erreur" retour }, Cmd.none )

            else
                case identifiant of
                    "deconnexion" ->
                        ( { modele | compte = Nothing, activation = False, secret = "", confirmation = "", corpus = vide, statistiques = vide, details = vide, reponses = [], erreur = "", contexte = modele.contexte + 1, attente = 0 }, Cmd.none )

                    "compte" ->
                        ouvrirSession donnees modele

                    "connexion" ->
                        ouvrirSession donnees modele

                    "versions" ->
                        let
                            versions =
                                elements donnees |> List.map (chaine "version")

                            version =
                                if modele.filtres.version == "" then
                                    List.head versions |> Maybe.withDefault ""

                                else
                                    modele.filtres.version

                            f =
                                modele.filtres
                        in
                        charger TableauDeBord { modele | versions = versions, filtres = { f | version = version }, appliques = { f | version = version } }

                    "corpus" ->
                        ( { modele | corpus = donnees, attente = Basics.max 0 (modele.attente - 1) }, Cmd.none )

                    "statistiques" ->
                        ( { modele | statistiques = donnees, attente = Basics.max 0 (modele.attente - 1) }, Cmd.none )

                    "details" ->
                        ( { modele | details = donnees, attente = Basics.max 0 (modele.attente - 1) }, Cmd.none )

                    "reponses" ->
                        ( { modele | reponses = elements donnees, attente = Basics.max 0 (modele.attente - 1) }, Cmd.none )

                    _ ->
                        ( modele, Cmd.none )


ouvrirSession : E.Value -> Modele -> ( Modele, Cmd Message )
ouvrirSession donnees modele =
    ( { modele | compte = Just (chaine "username" donnees), activation = False, enCours = False, erreur = "", secret = "", confirmation = "" }, demander modele.contexte "versions" "corpora" )


chaine : String -> E.Value -> String
chaine cle valeur =
    D.decodeValue (D.field cle D.string) valeur |> Result.withDefault ""


objet : String -> E.Value -> E.Value
objet cle valeur =
    D.decodeValue (D.field cle D.value) valeur |> Result.withDefault E.null


elements : E.Value -> List E.Value
elements valeur =
    D.decodeValue (D.list D.value) valeur |> Result.withDefault []


liste : String -> E.Value -> List E.Value
liste cle valeur =
    elements (objet cle valeur)


nombre : E.Value -> Float
nombre valeur =
    D.decodeValue D.float valeur |> Result.withDefault 0


entier : String -> E.Value -> Int
entier cle valeur =
    round (nombre (objet cle valeur))


paires : E.Value -> List ( String, E.Value )
paires valeur =
    D.decodeValue (D.keyValuePairs D.value) valeur |> Result.withDefault []


texteValeur : E.Value -> String
texteValeur valeur =
    case D.decodeValue D.string valeur of
        Ok valeurTexte ->
            valeurTexte

        Err _ ->
            case D.decodeValue D.float valeur of
                Ok n ->
                    String.fromFloat (toFloat (round (n * 100)) / 100) |> String.replace "." ","

                Err _ ->
                    if E.encode 0 valeur == "null" then
                        "—"

                    else
                        E.encode 0 valeur


jointure : List E.Value -> String
jointure valeurs =
    String.join ", " (List.map texteValeur valeurs)


repere : String -> UI.Attribute message
repere nom =
    UI.htmlAttribute (A.class nom)


riche : String -> Element Message
riche contenu =
    UI.el [ UI.width UI.fill ] (UI.html (Html.node "rich-text" [ A.attribute "content" contenu ] []))


texte : String -> Element Message
texte =
    M.paragraphe


chiffre : String -> E.Value -> Element Message
chiffre cle valeur =
    texte (texteValeur (objet cle valeur))


boutonVue : String -> Vue -> Element Message
boutonVue libelle vue =
    M.boutonSecondaire libelle (Naviguer vue)


questions : Modele -> List E.Value
questions modele =
    liste "questions" (objet "bank" modele.corpus)


question : String -> Modele -> E.Value
question identifiant modele =
    questions modele |> List.filter (\q -> chaine "id" q == identifiant) |> List.head |> Maybe.withDefault vide


statProduction : String -> Modele -> E.Value
statProduction identifiant modele =
    objet (modele.appliques.version ++ ":" ++ identifiant) (objet "productions" modele.statistiques)


validerAuClavier : D.Decoder ( Message, Bool )
validerAuClavier =
    D.map2 Tuple.pair (D.field "key" D.string) (D.at [ "target", "tagName" ] D.string)
        |> D.andThen
            (\( touche, cible ) ->
                if touche == "Enter" && cible == "INPUT" then
                    D.succeed ( SeConnecter, True )

                else
                    D.fail "Autre touche"
            )


afficher : Modele -> Html Message
afficher modele =
    case modele.compte of
        Nothing ->
            M.page "Matheval · Administration"
                [ UI.el [ UI.width UI.fill, UI.htmlAttribute (Evenements.preventDefaultOn "keydown" validerAuClavier) ]
                    (M.section
                        (if modele.activation then
                            "Bienvenue dans votre administration."

                         else
                            "Retrouver les regards."
                        )
                        [ M.texteSecondaire
                            (if modele.activation then
                                "Choisissez votre identifiant et un mot de passe d’au moins 14 caractères. Ce lien d’activation ne fonctionne qu’une fois."

                             else
                                "Connectez-vous pour consulter le corpus et les réponses des enseignants."
                            )
                        , M.identifiant "Identifiant" modele.identifiant ModifierIdentifiant
                        , (if modele.activation then
                            M.nouveauMotDePasse

                           else
                            M.motDePasse
                          )
                            "Mot de passe"
                            modele.secret
                            ModifierSecret
                        , if modele.activation then
                            M.nouveauMotDePasse "Confirmer le mot de passe" modele.confirmation ModifierConfirmation

                          else
                            UI.none
                        , afficherErreur modele
                        , if modele.enCours then
                            M.boutonEnCours "Connexion en cours…"

                          else
                            M.bouton
                                (if modele.activation then
                                    "Créer mon accès"

                                 else
                                    "Se connecter"
                                )
                                SeConnecter
                        , if modele.activation then
                            M.boutonSecondaire "J’ai déjà un compte" ConnexionOrdinaire

                          else
                            UI.none
                        , M.lien "Accéder au questionnaire" "../"
                        ]
                    )
                ]

        Just compte ->
            M.page (titre modele)
                [ M.actions [ boutonVue "Vue d’ensemble" TableauDeBord, boutonVue "Énoncés et rédactions" Corpus, boutonVue "Participations" Participations, M.boutonSecondaire "Déconnexion" SeDeconnecter ]
                , M.texteSecondaire ("Connecté : " ++ compte)
                , M.actions [ M.lienExterne "Ouvrir le questionnaire ↗" "../", M.lien "Exporter les réponses CSV" ("../api/admin/exports/responses.csv?" ++ parametres modele.appliques) ]
                , if List.member modele.vue [ TableauDeBord, Corpus, Participations ] then
                    afficherFiltres modele

                  else
                    UI.none
                , afficherErreur modele
                , if modele.attente > 0 then
                    M.texteSecondaire "Chargement des résultats…"

                  else
                    afficherContenu modele
                ]


afficherErreur : Modele -> Element Message
afficherErreur modele =
    if modele.erreur == "" then
        UI.none

    else
        M.avis M.Erreur modele.erreur


titre : Modele -> String
titre modele =
    case modele.vue of
        TableauDeBord ->
            "Vue d’ensemble"

        Corpus ->
            "Énoncés et rédactions"

        Participations ->
            "Participations"

        Question identifiant ->
            identifiant ++ " · " ++ chaine "title" (question identifiant modele)

        Reponses _ identifiant ->
            "Évaluations de " ++ identifiant

        Participation identifiant ->
            "Participation " ++ String.left 8 identifiant


afficherFiltres : Modele -> Element Message
afficherFiltres modele =
    let
        f =
            modele.filtres

        niveaux =
            List.foldl
                (\q acc ->
                    let
                        n =
                            chaine "level" q
                    in
                    if List.member n acc then
                        acc

                    else
                        acc ++ [ n ]
                )
                []
                (questions modele)
    in
    M.carte
        [ UI.wrappedRow [ UI.width UI.fill, UI.spacing 12 ]
            (List.map (UI.el [ UI.width (UI.minimum 150 UI.fill) ])
                [ M.selecteur "Version du corpus" (List.map (\v -> ( v, v )) modele.versions) f.version (ModifierFiltre "version")
                , M.selecteur "Participations" [ ( "", "Toutes" ), ( "completed", "Validées" ), ( "incomplete", "Non validées" ) ] f.statut (ModifierFiltre "status")
                , M.selecteur "Niveaux enseignés" (( "", "Tous" ) :: List.map (\v -> ( v, v )) niveaux) f.niveau (ModifierFiltre "level")
                , Disposition.date "Depuis" f.depuis (ModifierFiltre "from")
                , Disposition.date "Jusqu’au" f.jusque (ModifierFiltre "to")
                ]
            )
        , M.bouton "Appliquer" Appliquer
        ]


afficherContenu : Modele -> Element Message
afficherContenu modele =
    case modele.vue of
        TableauDeBord ->
            tableauDeBord modele

        Corpus ->
            catalogue modele

        Question identifiant ->
            detailQuestion (question identifiant modele) modele

        Reponses questionId productionId ->
            reponsesProduction questionId productionId modele

        Participations ->
            participations modele

        Participation _ ->
            participation modele.details


table : String -> List String -> List (List (Element Message)) -> Element Message
table libelle entetes lignes =
    Tableaux.tableau libelle (List.indexedMap (\i nom -> Tableaux.colonne nom (\ligne -> List.drop i ligne |> List.head |> Maybe.withDefault UI.none)) entetes) lignes


mesures : E.Value -> Element Message
mesures donnees =
    M.texteSecondaire ("n = " ++ String.fromInt (entier "n" donnees) ++ " · Moyenne " ++ texteValeur (objet "mean" donnees) ++ " · Médiane " ++ texteValeur (objet "median" donnees) ++ " · Quartiles " ++ texteValeur (objet "q1" donnees) ++ " · " ++ texteValeur (objet "q3" donnees))


distribution : String -> E.Value -> Element Message
distribution libelle donnees =
    Disposition.histogramme libelle (List.map (\d -> ( texteValeur (objet "value" d), nombre (objet "count" d) )) (liste "distribution" donnees))


tableauDeBord : Modele -> Element Message
tableauDeBord modele =
    let
        s =
            modele.statistiques
    in
    M.pile
        [ UI.wrappedRow [ UI.width UI.fill, UI.spacing 12 ]
            (List.map (\( nom, cle ) -> UI.el [ UI.width (UI.minimum 210 UI.fill) ] (M.section nom [ chiffre cle s ])) [ ( "Participations commencées", "started" ), ( "Avec des réponses", "answered" ), ( "Participations validées", "completed" ), ( "Rédactions évaluées", "evaluations" ) ])
        , M.texteSecondaire (texteValeur (E.float (100 * nombre (objet "completionRate" s))) ++ " % validées · " ++ String.fromInt (entier "incomplete" s) ++ " participation(s) non validée(s)")
        , M.section "Participations dans le temps" [ Disposition.histogramme "Participations commencées par jour" (liste "daily" s |> List.reverse |> List.take 30 |> List.reverse |> List.map (\d -> ( String.dropLeft 5 (chaine "date" d), nombre (objet "started" d) ))), M.texteSecondaire "Les 30 derniers jours comportant des participations dans la sélection." ]
        , M.section "Niveaux enseignés" [ Disposition.histogramme "Niveaux enseignés" (List.map (\( n, v ) -> ( n, nombre v )) (paires (objet "levels" s))) ]
        , M.section "Distribution des notes" [ mesures (objet "grades" (objet "summary" s)), distribution "Notes sur trois points" (objet "grades" (objet "summary" s)), M.texteSecondaire "Une note zéro compte comme une réponse. Les notes manquantes sont exclues." ]
        , M.texteSecondaire "Les effectifs comptent des participations, pas des personnes identifiées. Un enseignant peut participer plusieurs fois et déclarer plusieurs niveaux. Les filtres s’appliquent à tous les résultats et à l’export."
        ]


catalogue : Modele -> Element Message
catalogue modele =
    let
        visibles =
            questions modele |> List.filter (\q -> String.contains (String.toLower modele.recherche) (String.toLower (String.join " " (List.map (\k -> chaine k q) [ "id", "title", "level", "domain", "statement" ]))))
    in
    M.pile
        (M.recherche "Rechercher dans le corpus" modele.recherche Rechercher
            :: (if List.isEmpty visibles then
                    [ M.texteSecondaire "Aucun énoncé ne correspond à cette recherche." ]

                else
                    List.map
                        (\q ->
                            Disposition.panneau [ repere "question-card" ]
                                [ Disposition.etiquette (chaine "id" q ++ " · " ++ chaine "level" q)
                                , M.sousTitre (chaine "title" q)
                                , M.texteSecondaire (chaine "domain" q)
                                , M.texteSecondaire (String.fromInt (List.length (liste "productions" q)) ++ " rédactions · " ++ String.fromInt (List.sum (List.map (\p -> entier "n" (objet "grades" (statProduction (chaine "id" p) modele))) (liste "productions" q))) ++ " évaluations")
                                , boutonVue "Consulter l’énoncé et les résultats →" (Question (chaine "id" q))
                                ]
                        )
                        visibles
               )
        )


axes : E.Value -> Element Message
axes donnees =
    M.pile
        (List.map
            (\( cle, libelle ) ->
                let
                    a =
                        objet cle (objet "axes" donnees)
                in
                M.section libelle [ mesures a, distribution libelle a, M.texteSecondaire "Valeurs regroupées par pas de 2 ; seuls les axes évalués sont comptés." ]
            )
            [ ( "x", "Confus → Lisible" ), ( "y", "Vague → Précis" ), ( "z", "Fautif → Valide" ) ]
        )


detailQuestion : E.Value -> Modele -> Element Message
detailQuestion q modele =
    M.pile
        ([ boutonVue "← Tous les énoncés" Corpus, M.section "Énoncé" [ riche (chaine "statement" q) ], M.section "Réponse de référence" [ riche (chaine "referenceAnswer" q) ] ]
            ++ List.map
                (\p ->
                    let
                        identifiant =
                            chaine "id" p

                        s =
                            statProduction identifiant modele

                        recherche =
                            objet "research" p
                    in
                    Disposition.panneau [ repere "production" ]
                        [ M.sousTitre identifiant
                        , boutonVue "Réponses individuelles" (Reponses (chaine "id" q) identifiant)
                        , riche (chaine "content" p)
                        , M.section "Analyse de conception" [ riche (chaine "analysis" recherche), M.texteSecondaire ("Cibles : " ++ jointure (liste "targets" recherche)), table "Contrats examinés" [ "Contrat", "Codage de conception" ] (List.map (\( k, v ) -> [ texte k, texte (texteValeur v) ]) (paires (objet "contracts" recherche))) ]
                        , M.sousTitre "Notes attribuées"
                        , mesures (objet "grades" s)
                        , distribution ("Notes " ++ identifiant) (objet "grades" s)
                        , M.texteSecondaire ("Note initiale moyenne : " ++ texteValeur (objet "mean" (objet "initialGrades" s)) ++ " · Révisions : " ++ String.fromInt (entier "changed" (objet "revisions" s)) ++ " · Écart moyen final − initial : " ++ texteValeur (objet "mean" (objet "revisions" s)))
                        , axes s
                        ]
                )
                (liste "productions" q)
        )


valeursAxes : String -> E.Value -> E.Value -> List (Element Message)
valeursAxes cle reponse coordonnees =
    List.map
        (\axe ->
            if List.member axe (List.map texteValeur (liste cle reponse)) then
                chiffre axe coordonnees

            else
                texte "Non évalué"
        )
        [ "x", "y", "z" ]


reponsesProduction : String -> String -> Modele -> Element Message
reponsesProduction questionId productionId modele =
    let
        p =
            liste "productions" (question questionId modele) |> List.filter (\v -> chaine "id" v == productionId) |> List.head |> Maybe.withDefault vide
    in
    M.pile
        [ boutonVue "← Énoncé et statistiques" (Question questionId)
        , M.carte [ riche (chaine "content" p) ]
        , M.section (String.fromInt (List.length modele.reponses) ++ " réponses enregistrées")
            [ table "Réponses individuelles"
                [ "Participation", "Validation", "Note initiale", "Note", "Lisibilité", "Précision", "Validité" ]
                (List.map
                    (\r ->
                        [ boutonVue (String.left 8 (chaine "participation_id" r)) (Participation (chaine "participation_id" r))
                        , texte
                            (if chaine "completed_at" r == "" then
                                "En cours"

                             else
                                "Validée"
                            )
                        , chiffre "initial_note" r
                        , chiffre "note" r
                        ]
                            ++ valeursAxes "evaluated_axes" r r
                    )
                    modele.reponses
                )
            ]
        ]


participations : Modele -> Element Message
participations modele =
    let
        d =
            modele.details
    in
    M.section (String.fromInt (entier "total" d) ++ " participations")
        [ table "Participations enregistrées"
            [ "Participation", "Début", "Niveaux", "Évaluations", "Statut" ]
            (List.map
                (\p ->
                    [ boutonVue (String.left 8 (chaine "id" p)) (Participation (chaine "id" p))
                    , texte (chaine "started_at" p)
                    , texte (jointure (liste "levels" p))
                    , chiffre "answers" p
                    , Disposition.etiquette
                        (if chaine "completed_at" p == "" then
                            "Non validée"

                         else
                            "Validée"
                        )
                    ]
                )
                (liste "rows" d)
            )
        , if entier "pages" d > 1 then
            M.actions
                [ if modele.numeroPage <= 1 then
                    M.boutonInactif "← Précédent"

                  else
                    M.boutonSecondaire "← Précédent" (ChangerPage (modele.numeroPage - 1))
                , texte (String.fromInt modele.numeroPage ++ " / " ++ String.fromInt (entier "pages" d))
                , if modele.numeroPage >= entier "pages" d then
                    M.boutonInactif "Suivant →"

                  else
                    M.boutonSecondaire "Suivant →" (ChangerPage (modele.numeroPage + 1))
                ]

          else
            UI.none
        ]


participation : E.Value -> Element Message
participation p =
    let
        instantane =
            objet "snapshot" p
    in
    M.pile
        ([ boutonVue "← Toutes les participations" Participations
         , M.carte [ texte ("Début : " ++ chaine "startedAt" p ++ " · Validation : " ++ texteValeur (objet "completedAt" p)), texte ("Corpus : " ++ chaine "bankVersion" p ++ " · Niveaux : " ++ jointure (liste "levels" p)), texte (chaine "id" p), M.texteSecondaire ("Graine du tirage : " ++ texteValeur (objet "seed" p) ++ " · " ++ String.fromInt (List.length (liste "events" p)) ++ " interactions · Questions passées : " ++ jointure (liste "skippedQuestions" instantane)) ]
         ]
            ++ List.map
                (\q ->
                    M.section (chaine "id" q ++ " · " ++ chaine "level" q)
                        (riche (chaine "statement" q)
                            :: List.map
                                (\v ->
                                    let
                                        a =
                                            objet (chaine "id" v) (objet "answers" instantane)
                                    in
                                    Disposition.panneau [ repere "production" ]
                                        [ M.sousTitre (chaine "id" v)
                                        , riche (chaine "content" v)
                                        , if E.encode 0 a == "null" then
                                            M.texteSecondaire "Aucune réponse enregistrée."

                                          else
                                            table "Évaluation enregistrée" [ "Note initiale", "Note", "Lisibilité", "Précision", "Validité" ] [ [ chiffre "initialNote" a, chiffre "note" a ] ++ valeursAxes "evaluatedAxes" a (objet "coordinates" a) ]
                                        ]
                                )
                                (liste "productions" q)
                        )
                )
                (liste "questions" p)
            ++ [ M.section "Journal du parcours"
                    [ M.texteSecondaire "Les durées décrivent les interactions du navigateur ; elles ne mesurent pas le temps de réflexion."
                    , table "Interactions"
                        [ "Depuis le début", "Événement", "Question", "Rédaction", "Détail" ]
                        (List.map
                            (\v ->
                                [ texte (texteValeur (E.float (nombre (objet "elapsedMs" v) / 1000)) ++ " s")
                                , texte (chaine "event" v)
                                , texte (chaine "questionId" v)
                                , texte (chaine "productionId" v)
                                , texte
                                    (if E.encode 0 (objet "coordinates" v) /= "null" then
                                        String.join " · " (List.map (\a -> a ++ " " ++ texteValeur (objet a (objet "coordinates" v))) [ "x", "y", "z" ])

                                     else
                                        texteValeur (objet "value" v)
                                    )
                                ]
                            )
                            (liste "events" p)
                        )
                    ]
               ]
        )
