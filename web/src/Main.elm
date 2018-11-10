module Main exposing (Learning, Msg(..), init, main, update, view)

import Basics exposing (..)
import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json
import LineChart
import LineChart.Area as Area
import LineChart.Axis as Axis
import LineChart.Axis.Intersection as Intersection
import LineChart.Colors as Colors
import LineChart.Container as Container
import LineChart.Dots as Dots
import LineChart.Events as Events
import LineChart.Grid as Grid
import LineChart.Interpolation as Interpolation
import LineChart.Junk as Junk
import LineChart.Legends as Legends
import LineChart.Line as Line
import Process
import Task


main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : List Unit -> ( Model, Cmd Msg )
init data =
    ( { input = 0.0
      , learning = Learning data ( 0.0, 0.0 ) 0
      }
    , Cmd.none
    )



-- MODEL


type alias Unit =
    { shortCoursePoolTime : Float
    , longCoursePoolTime : Float
    }


type alias Weight =
    Float


type alias Bias =
    Float


type alias Step =
    Int


type Learning
    = Learning (List Unit) ( Weight, Bias ) Step


type alias Model =
    { learning : Learning
    , input : Float
    }



-- UPDATE


type Msg
    = Reset
    | Step
    | Learn
    | ChangeInput String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ input, learning } as model) =
    let
        (Learning data ( weight, bias ) step) =
            learning
    in
    case msg of
        Reset ->
            ( { model | learning = Learning data ( 0.0, 0.0 ) 0 }
            , Cmd.none
            )

        Step ->
            let
                ( newWeight, newBias ) =
                    descentGradient ( weight, bias ) data

                newStep =
                    step + 1
            in
            ( { model | learning = Learning data ( newWeight, newBias ) newStep }
            , Cmd.none
            )

        ChangeInput str ->
            case Json.decodeString Json.float str of
                Ok newInput ->
                    ( { model | input = newInput }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        Learn ->
            let
                ( newWeight, newBias ) =
                    descentGradient ( weight, bias ) data

                newStep =
                    step + 1

                reachedCrest =
                    abs (newWeight - weight) < 0.001 && abs (newBias - bias) < 0.001

                task =
                    case reachedCrest of
                        True ->
                            Cmd.none

                        False ->
                            Process.sleep 150
                                |> Task.perform (\_ -> Learn)
            in
            ( { model | learning = Learning data ( newWeight, newBias ) newStep }
            , task
            )



-- Learning mechanism


descentGradient : ( Weight, Bias ) -> List Unit -> ( Weight, Bias )
descentGradient ( weight, bias ) unitList =
    let
        newWeight =
            weight - 0.001 * meanSquareErrorWeight ( weight, bias ) unitList

        newBias =
            bias - 0.001 * meanSquareErrorBias ( weight, bias ) unitList
    in
    ( newWeight, newBias )


meanSquareErrorWeight : ( Weight, Bias ) -> List Unit -> Float
meanSquareErrorWeight ( weight, bias ) unitList =
    let
        m =
            toFloat <| List.length unitList

        squareError =
            unitList
                |> List.map (\unit -> (weight * unit.longCoursePoolTime + bias - unit.shortCoursePoolTime) * unit.longCoursePoolTime)
                |> List.sum
    in
    2 / m * squareError


meanSquareErrorBias : ( Weight, Bias ) -> List Unit -> Float
meanSquareErrorBias ( weight, bias ) unitList =
    let
        m =
            toFloat <| List.length unitList

        squareError =
            unitList
                |> List.map (\unit -> weight * unit.longCoursePoolTime + bias - unit.shortCoursePoolTime)
                |> List.sum
    in
    2 / m * squareError



-- VIEW


view : Model -> Document Msg
view { input, learning } =
    Document "Maths IA"
        [ viewPrediction learning input
        , viewLearningFormula learning
        , viewLearningChart learning
        ]


viewPrediction : Learning -> Float -> Html Msg
viewPrediction (Learning _ ( weight, bias ) _) x =
    let
        prediction =
            (weight * x + bias)
                |> String.fromFloat
                |> String.left 5
    in
    div []
        [ div []
            [ label [] [ text "Long course time: " ]
            , input
                [ onInput ChangeInput
                , placeholder "Try the algorithm..."
                ]
                []
            ]
        , div [] [ label [] [ text "Predicted short course time: " ], text prediction ]
        ]



-- Learning charts


viewLearningFormula : Learning -> Html Msg
viewLearningFormula (Learning _ ( weight, bias ) step) =
    let
        w =
            String.left 4 <| String.fromFloat <| weight

        b =
            String.left 5 <| String.fromFloat bias

        formula =
            String.join " " [ "h(x)", "=", w, "*", "x", "+", b ]

        steps =
            String.join " " [ "After", String.fromInt step, "steps." ]
    in
    div []
        [ div []
            [ button [ onClick Step ] [ text "Step" ]
            , button [ onClick Reset ] [ text "Reset" ]
            , button [ onClick Learn ] [ text "Learn" ]
            ]
        , div [] [ text formula ]
        , div [] [ text steps ]
        ]


viewLearningChart : Learning -> Html msg
viewLearningChart (Learning data ( weight, bias ) _) =
    let
        config =
            { y = Axis.default 450 "y" .shortCoursePoolTime
            , x = Axis.default 700 "x" .longCoursePoolTime
            , container = Container.styled "line-chart" [ ( "font-family", "monospace" ) ]
            , interpolation = Interpolation.linear
            , intersection = Intersection.default
            , legends = Legends.default
            , events = Events.default
            , junk = Junk.default
            , grid = Grid.default
            , area = Area.default
            , line = Line.default
            , dots = Dots.custom (Dots.full 1)
            }

        plot =
            LineChart.dash Colors.pink Dots.diamond "50m fly time" [ 0, 1 ] data

        bestFitLine =
            let
                minimumLongCourseTime =
                    data
                        |> List.map .longCoursePoolTime
                        |> List.minimum
                        |> Maybe.withDefault 0

                maximumLongCourseTime =
                    data
                        |> List.map .longCoursePoolTime
                        |> List.maximum
                        |> Maybe.withDefault 0

                ( bottom, top ) =
                    ( minimumLongCourseTime - 0.5, maximumLongCourseTime + 0.5 )

                firstPoint =
                    { shortCoursePoolTime = weight * bottom + bias
                    , longCoursePoolTime = bottom
                    }

                lastPoint =
                    { shortCoursePoolTime = weight * top + bias
                    , longCoursePoolTime = top
                    }
            in
            LineChart.line Colors.cyan Dots.none "Best fit line" [ firstPoint, lastPoint ]
    in
    LineChart.viewCustom config
        [ plot, bestFitLine ]
