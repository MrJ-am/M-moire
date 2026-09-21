from pathlib import Path
import hashlib, subprocess
r = Path(__file__).resolve().parents[1]
def verifier(empreintes):
    for nom, attendu in empreintes.items():
        obtenu = hashlib.sha256((r.parent / nom).read_bytes()).hexdigest()
        if obtenu != attendu:
            raise SystemExit(f"Empreinte inattendue : {nom} ({obtenu})")
verifier({'docs/src/Main.elm': 'b3382735d4cfa7d53b17d974b4962338c1729f88a1a3dd355020daf5cb051e50', 'docs/src/Survey.elm': '8fef2705bb8c462f18cdd9bdc60bfb888e44273b555232205714aaa831deeced', 'docs/site/admin/admin.js': '6a4abd2bc1022fdddad77a462242a3ed4c4c076b48b7c31229479c16efea2783', 'docs/tests/e2e/collection-admin.spec.js': '61850f0ec359457dc84cef96cc8a8cf7ee670e193148cb6a6b097a335879d37c', 'docs/tests/e2e/survey.spec.js': '7b9b0a1660cf9f93c07a955dd64dea7d0736836bc65150cbcdcbf660a459d052', 'docs/tests/e2e/survey-gestures.spec.js': '6280c5d46df7e91740d8a378e17aeb348d14f5c81822ff676f9e88ec4d3edd46'})
p=r/'src/Survey.elm'; s=p.read_text().replace('import Dict exposing (Dict)','import Dict exposing (Dict)\nimport Element as Interface\nimport MrJam')
start=s.index('viewSetup :'); end=s.index('\n\nviewWorkspace :',start)
s=s[:start]+'''viewSetup : Model -> Html Msg
viewSetup m =
    MrJam.page "Critères d’évaluations en mathématiques"
        [ MrJam.paragraphe "Ce sondage fait partie d’un projet de recherche qui cherche à mettre en lumière les critères que les enseignantes et enseignants de mathématiques exploitent pour noter leurs élèves."
        , MrJam.avis MrJam.Information "Vos réponses et vos interactions sont enregistrées pour cette recherche sous un identifiant aléatoire, sans compte personnel. Vous pouvez reprendre sur ce navigateur. Les résultats sont accessibles uniquement à l’équipe de recherche."
        , MrJam.section "Quels niveaux avez-vous enseignés ?"
            (List.map
                (\\niveau ->
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
''' + s[end:]
start=s.index('viewFinish :')
s=s[:start]+'''viewFinish : Model -> Html Msg
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
    MrJam.page "Chaque nuance compte."
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
'''
# Garder les identifiants et transitions ; les styles historiques ne ciblent pas les nouveaux panneaux.
s=s.replace('main_ [ class "experience" ]', 'main_ [ class (if m.mode == Running then "experience" else "experience-mrjam") ]')
p.write_text(s)
p=r/'src/Main.elm'; s=p.read_text().replace('import Dict exposing (Dict)','import Dict exposing (Dict)\nimport Element as Interface\nimport MrJam')
a=s.index('topHeader :'); b=s.index('\n\nplacedCount :',a)
s=s[:a]+'''topHeader : Model -> Html msg
topHeader model =
    Interface.layout
        [ Interface.width Interface.fill
        , Interface.height Interface.shrink
        , Interface.htmlAttribute (style "flex-shrink" "0")
        , Interface.htmlAttribute (attribute "data-testid" "header")
        ]
        (MrJam.carte
            (case model.exercise of
                Just exercise ->
                    [ MrJam.sousTitre exercise.title
                    , Interface.html (richText exercise.statement)
                    , MrJam.texteSecondaire
                        ("Selection : "
                            ++ selectedBadgeLabel model.selectedPropositionId model.propositions
                            ++ " | Placees : "
                            ++ String.fromInt (placedCount model.propositions)
                            ++ "/"
                            ++ String.fromInt (List.length model.propositions)
                        )
                    ]

                Nothing ->
                    [ MrJam.sousTitre "Evaluation de productions d'eleves"
                    , MrJam.texteSecondaire (Maybe.withDefault "Chargement des productions..." model.contentError)
                    ]
            )
        )
''' + s[b:]; p.write_text(s)

p=r/"site/admin/admin.js";s=p.read_text()
s=s.replace("function login() {\n","// Le pont conserve le contrat HTTP ; ElmUI construit réellement les contrôles.\nfunction ouvrirConnexion() {\n  const noeud = document.createElement('div');\n  root.replaceChildren(noeud);\n  const application = Elm.Administration.init({ node: noeud });\n  application.ports.connexion.subscribe(async saisie => {\n    try {\n      const data = await request('login', { method: 'POST', body: JSON.stringify(saisie) });\n      username = data.username;\n      await initialize();\n    } catch (erreur) {\n      application.ports.retourConnexion.send(erreur.message);\n    }\n  });\n}\nfunction login() {\n  if (!setupToken) { ouvrirConnexion(); return; }\n")
p.write_text(s)
for nom in ['docs/tests/e2e/collection-admin.spec.js', 'docs/tests/e2e/survey.spec.js', 'docs/tests/e2e/survey-gestures.spec.js']:
    p=r.parent/nom
    p.write_text(p.read_text().replace(".finish-panel", ".finish-panel-mrjam"))
subprocess.run([str(r/"node_modules/.bin/elm-format"),str(r/"src/Main.elm"),str(r/"src/Survey.elm"),"--yes"],check=True)
verifier({'docs/src/Main.elm': 'e8a0470920ef80dfdfa5b69e8ccb0bf088245027549e560212f94feea76a2334', 'docs/src/Survey.elm': 'c06451b17f62e1ea9b89e705c0fa1e63497c02bca5da286d1f930bd49a5d7a59', 'docs/site/admin/admin.js': '231c475e5b6b670f9a05daf5a6e3a1ac26c29b1e151b57b2f7c6cdad4d2adfdb', 'docs/tests/e2e/collection-admin.spec.js': '2d220521db2662ae6a996fa753cdd6a33776cf0c3f57bdb30f5ea438153afcdf', 'docs/tests/e2e/survey.spec.js': 'e873a7afafe54681638fd9065ae1a13bed04024f4b9ba4ee4c5c1b6115e000d5', 'docs/tests/e2e/survey-gestures.spec.js': 'fdc420f332566d37f96096bee24f6efbe8b229f7accca7f3fddb046c19aeb6db'})
