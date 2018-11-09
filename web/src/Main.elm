module Main exposing (Model, Msg(..), init, main, update, view)

import Basics exposing (..)
import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : List Unit -> ( Model, Cmd Msg )
init data =
    ( Model data 0.0 0.0, Cmd.none )



-- MODEL


type alias Unit =
    { shortCoursePoolTime : Float
    , longCoursePoolTime : Float
    }


type alias Weight =
    Float


type alias Bias =
    Float


type Model
    = Model (List Unit) Weight Bias



-- UPDATE


type Msg
    = Reset
    | Step


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ((Model data weight bias) as model) =
    case msg of
        Reset ->
            ( Model data 0.0 0.0, Cmd.none )

        Step ->
            let
                ( newWeight, newBias ) =
                    descentGradient 0.001 ( weight, bias ) data
            in
            ( Model data newWeight newBias, Cmd.none )



-- Learning mechanism


descentGradient : Float -> ( Weight, Bias ) -> List Unit -> ( Weight, Bias )
descentGradient step ( weight, bias ) unitList =
    let
        newWeight =
            weight - step * meanSquareErrorWeight ( weight, bias ) unitList

        newBias =
            bias - step * meanSquareErrorBias ( weight, bias ) unitList
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
view ((Model data weight bias) as model) =
    Document "Maths IA"
        [ div [] [ text "weight:", text <| String.fromFloat weight ]
        , div [] [ text "bias:", text <| String.fromFloat bias ]
        , button [ onClick Step ] [ text "Step" ]
        ]
