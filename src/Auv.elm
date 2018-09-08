-- Copyright (c) 2017-2018 Auric Systems International. All rights reserved.
-- License: 3-Clause BSD License. See accompanying LICENSE file.


module Auv
    exposing
        ( DetokenizeResponsePayload
        , DetokenizeResult
        , TargetEnvironment(..)
        , TokenizeResponsePayload
        , TokenizeResult
        , deTokenResultDecoder
        , deTokenizeResponsePayloadDecoder
        , httpErrorToString
        , mapEnvironment
        , post
        , toSeconds
        , tokenResultDecoder
        , tokenizeResponsePayloadDecoder
        , vault_url
        )

import Http
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import Time
import Url


type TargetEnvironment
    = Dev
    | Test
    | Prod


mapEnvironment : Maybe String -> TargetEnvironment
mapEnvironment target =
    case target of
        Nothing ->
            Prod

        Just env ->
            if String.trim env == "dev" then
                Dev
            else if String.trim env == "test" then
                Test
            else
                Prod



-- Talk to the vault from which we were loaded.
-- Talk to sandbox if running outside a vault (probably dev environment).


vault_url : Url.Url -> String
vault_url location =
    let
        url_fragment =
            "/vault/v2/"
    in
    if String.startsWith "vault0" location.host then
        "https://" ++ location.host ++ url_fragment
    else
        "https://vault01-sb.auricsystems.com" ++ url_fragment


type alias DetokenizeResult =
    { version : String
    , lastActionSucceeded : Int
    , plaintextValue : String
    , elapsedTime : String
    }


type alias DetokenizeResponsePayload =
    { id : Int
    , result : DetokenizeResult
    , error : String
    }


deTokenResultDecoder : JD.Decoder DetokenizeResult
deTokenResultDecoder =
    JD.succeed DetokenizeResult
        |> JDP.required "version" JD.string
        |> JDP.required "lastActionSucceeded" JD.int
        |> JDP.optional "plaintextValue" JD.string ""
        |> JDP.required "elapsedTime" JD.string


deTokenizeResponsePayloadDecoder : JD.Decoder DetokenizeResponsePayload
deTokenizeResponsePayloadDecoder =
    JD.succeed DetokenizeResponsePayload
        |> JDP.required "id" JD.int
        |> JDP.required "result" deTokenResultDecoder
        |> JDP.optional "error" JD.string ""


type alias TokenizeResult =
    { version : String
    , lastActionSucceeded : Int
    , token : String
    , elapsedTime : String
    }


type alias TokenizeResponsePayload =
    { id : Int
    , result : TokenizeResult
    , error : String
    }


tokenResultDecoder : JD.Decoder TokenizeResult
tokenResultDecoder =
    JD.succeed TokenizeResult
        |> JDP.required "version" JD.string
        |> JDP.required "lastActionSucceeded" JD.int
        |> JDP.optional "token" JD.string ""
        |> JDP.required "elapsedTime" JD.string


tokenizeResponsePayloadDecoder : JD.Decoder TokenizeResponsePayload
tokenizeResponsePayloadDecoder =
    JD.succeed TokenizeResponsePayload
        |> JDP.required "id" JD.int
        |> JDP.required "result" tokenResultDecoder
        |> JDP.optional "error" JD.string ""


post : String -> List Http.Header -> Http.Body -> JD.Decoder a -> Http.Request a
post url headers body decoder =
    Http.request
        { method = "POST"
        , headers = headers
        , url = url
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Just 10000
        , withCredentials = False
        }


{-| Just return the raw error string
-}
httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            url

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus response ->
            response.body

        Http.BadPayload str1 _ ->
            str1


toSeconds : Time.Posix -> Int
toSeconds time =
    Time.posixToMillis time // 1000
